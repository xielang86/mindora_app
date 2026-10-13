import Foundation
import UIKit

final class BonjourDiscovery: NSObject {
    static let shared = BonjourDiscovery(serviceType: "_mindora._tcp.")

    /// Posted on main queue whenever the visible `services` list changes (debounced).
    /// `object` is the `BonjourDiscovery` instance.
    static let didUpdateNotification = Notification.Name("BonjourDiscovery.didUpdate")
    /// Posted when the browser reports a search error (e.g. -72000 local-network permission denied).
    /// `object` is the `Int` NetService error code.
    static let didFailNotification = Notification.Name("BonjourDiscovery.didFail")

    private let browser = NetServiceBrowser()
    private let serviceType: String
    private(set) var services: [NetService] = []

    /// uniqueKey → index in `services`. Key prefers (device_id + ip), then device_id, then ip,
    /// then service.name as a stable fallback.
    private var indexByUniqueKey: [String: Int] = [:]

    /// True while the underlying NetServiceBrowser is actively searching.
    /// NetServiceBrowser has no public `isSearching` query, so we track it.
    private var isSearching = false
    private var isContinuous = false

    /// One-shot scan auto-stops after this many seconds. Continuous mode ignores it.
    private let oneShotTimeout: TimeInterval = 3.0
    private var scanTimer: Timer?

    /// Coalesce bursts of didFind/didRemove/TXT-update into one notification.
    private var notifyScheduled = false
    private let debounceInterval: TimeInterval = 0.2

    init(serviceType: String) {
        self.serviceType = serviceType
        super.init()
        browser.delegate = self
    }

    // MARK: - Public API

    /// Run a single bounded scan. Clears any previously discovered services.
    func start() {
        Log.info("Bonjour", "start one-shot search type=\(serviceType)")
        cancelTimer()
        if isSearching {
            browser.stop()
            isSearching = false
        }
        // Explicit one-shot semantics: cancel any continuous mode so the timeout
        // actually stops the browser.
        isContinuous = false
        clearServices()
        beginSearch()
        scheduleOneShotTimeout()
    }

    /// Run a continuous scan. Safe to call repeatedly — no-ops if already running.
    /// mDNS pushes Hello/Goodbye automatically, so we don't restart the browser periodically.
    func startContinuous() {
        if isContinuous && isSearching {
            return
        }
        Log.info("Bonjour", "start continuous search type=\(serviceType)")
        cancelTimer()
        isContinuous = true
        if isSearching {
            // One-shot was already running, just upgrade to continuous semantics.
            return
        }
        // Transitioning from "stopped" → "searching": purge stale services left over
        // from a previous session. Otherwise devices that went offline during the
        // stopped window stay ghosted in the list (no didRemove will ever fire).
        clearServices()
        beginSearch()
    }

    /// Stop all searching. Does not clear discovered services so the list survives a stop/start.
    func stop() {
        guard isSearching || isContinuous else { return }
        Log.info("Bonjour", "stop search services=\(services.count)")
        cancelTimer()
        isContinuous = false
        if isSearching {
            for service in services { service.stopMonitoring() }
            browser.stop()
            isSearching = false
        }
        postUpdate()
    }

    /// Alias of `stop()`, kept for call-site clarity.
    func stopContinuous() { stop() }

    /// 返回某 device_id 对应服务「已解析」的可拨号 host：优先 mDNS hostName（去尾点），
    /// 退回 IPv4。未解析到则 nil（调用方应等下一次 discovery 更新后重试）。
    /// 必须在主线程调用（services 由主线程的 browser 回调维护）。
    func resolvedHost(forDeviceID did: String) -> String? {
        guard let svc = services.first(where: { $0.deviceID == did }) else {
            let known = services.map { "\($0.name)[did=\($0.deviceID ?? "nil") host=\($0.hostName ?? "nil") ip=\($0.firstIPv4Address ?? "nil")]" }
            Log.info("Bonjour", "resolvedHost miss did=\(did) known=\(known.joined(separator: ", "))")
            return nil
        }
        if let hn = svc.hostName, !hn.isEmpty {
            return hn.hasSuffix(".") ? String(hn.dropLast()) : hn
        }
        return svc.firstIPv4Address
    }

    // MARK: - Internals

    private func beginSearch() {
        isSearching = true
        browser.searchForServices(ofType: serviceType, inDomain: "local.")
    }

    private func clearServices() {
        for service in services { service.stopMonitoring() }
        services.removeAll()
        indexByUniqueKey.removeAll()
        postUpdate()
    }

    private func scheduleOneShotTimeout() {
        cancelTimer()
        scanTimer = Timer.scheduledTimer(withTimeInterval: oneShotTimeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            if !self.isContinuous {
                Log.info("Bonjour", "one-shot timeout reached")
                self.stop()
            }
        }
    }

    private func cancelTimer() {
        scanTimer?.invalidate()
        scanTimer = nil
    }

    private func scheduleNotify() {
        if notifyScheduled { return }
        notifyScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval) { [weak self] in
            guard let self else { return }
            self.notifyScheduled = false
            self.postUpdate()
        }
    }

    private func postUpdate() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
        }
    }
}

// MARK: - NetServiceBrowserDelegate
extension BonjourDiscovery: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Log.info("Bonjour", "didFind name=\(service.name) more=\(moreComing) count=\(services.count)")
        service.delegate = self
        service.startMonitoring() // listen for TXT updates
        // 同时解析地址/hostname（本类即 delegate，TXT 与解析回调可并存）。否则 hostName /
        // firstIPv4Address 永远为空，上层（DeviceLoginPusher）就拿不到可拨号 host。
        if service.hostName == nil {
            service.resolve(withTimeout: 5.0)
        }

        // service.name is unique per (serviceType, domain) by Bonjour spec — safe as provisional key.
        if let idx = services.firstIndex(where: { $0.name == service.name }) {
            services[idx] = service
            indexByUniqueKey[service.name] = idx
        } else {
            services.append(service)
            indexByUniqueKey[service.name] = services.count - 1
        }

        if !moreComing { scheduleNotify() }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        Log.info("Bonjour", "didRemove name=\(service.name) more=\(moreComing) count=\(services.count)")
        service.stopMonitoring()
        if let idx = services.firstIndex(of: service) {
            services.remove(at: idx)
            rebuildIndex()
        }
        if !moreComing { scheduleNotify() }
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        postUpdate()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        let code = errorDict[NetService.errorCode]?.intValue ?? -1
        Log.error("Bonjour", "didNotSearch code=\(code) err=\(errorDict)")
        // Browser failed to start; both flags must reset so a later stop() / start()
        // sees consistent state.
        isSearching = false
        isContinuous = false
        cancelTimer()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
            NotificationCenter.default.post(name: Self.didFailNotification, object: code)
        }
    }
}

// MARK: - NetServiceDelegate (TXT / resolution → stable unique key)
//
// Known limitation: `NetService.delegate` is a single slot. When a selection UI calls
// `service.resolve(withTimeout:)` it re-points `service.delegate = self` to receive the
// resolve callback, which permanently steals TXT-update callbacks from this discovery.
// In the current flows (selection → bind → done) the hijacked service is consumed
// immediately, so we accept the trade-off rather than reference-count the delegate.
extension BonjourDiscovery: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        Log.info("Bonjour", "didResolve name=\(sender.name) host=\(sender.hostName ?? "nil") ip=\(sender.firstIPv4Address ?? "nil") did=\(sender.deviceID ?? "nil")")
        updateUniqueKey(for: sender)
    }
    func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        Log.info("Bonjour", "TXT update name=\(sender.name) did=\(sender.deviceID ?? "nil")")
        updateUniqueKey(for: sender)
    }
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        // 解析失败要留痕：拿不到 host 时上层永远发不出 /login，静默会让问题很难查。
        Log.error("Bonjour", "didNotResolve name=\(sender.name) err=\(errorDict)")
    }

    private func updateUniqueKey(for service: NetService) {
        guard let idx = services.firstIndex(of: service) else { return }
        let newKey = computeUniqueKey(service)
        if indexByUniqueKey[newKey] == idx { return }

        // Conflict: the new key already points elsewhere. Do NOT delete the other service
        // (it may be mid-resolve from a selection UI). We simply overwrite the dict entry;
        // both services stay in `services`. Worst case the UI shows two cells for one
        // physical device until the duplicate disappears via didRemove.
        if let otherIdx = indexByUniqueKey[newKey], otherIdx != idx {
            Log.info("Bonjour", "uniqueKey conflict key=\(newKey) prevIdx=\(otherIdx) newIdx=\(idx)")
        }

        // Drop our previous key so the index stays consistent.
        if let oldKey = indexByUniqueKey.first(where: { $0.value == idx })?.key {
            indexByUniqueKey.removeValue(forKey: oldKey)
        }
        indexByUniqueKey[newKey] = idx
        scheduleNotify()
    }

    private func computeUniqueKey(_ service: NetService) -> String {
        var deviceID: String?
        if let txtData = service.txtRecordData() {
            let dict = NetService.dictionary(fromTXTRecord: txtData)
            if let v = dict["device_id"], let s = String(data: v, encoding: .utf8), !s.isEmpty {
                deviceID = s.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        let ip = service.firstIPv4Address
        if let deviceID, let ip { return "did=\(deviceID)|ip=\(ip)" }
        if let deviceID { return "did=\(deviceID)" }
        if let ip { return "ip=\(ip)" }
        return service.name // stable fallback (unique per service type)
    }

    private func rebuildIndex() {
        indexByUniqueKey.removeAll(keepingCapacity: true)
        for (i, s) in services.enumerated() {
            indexByUniqueKey[computeUniqueKey(s)] = i
        }
    }
}
