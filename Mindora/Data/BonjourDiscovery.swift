import Foundation
import UIKit

protocol BonjourDiscoveryDelegate: AnyObject {
    func discoveryDidUpdate(_ discovery: BonjourDiscovery)
}

final class BonjourDiscovery: NSObject {
    static let shared = BonjourDiscovery(serviceType: "_mindora._tcp.")
    private let browser = NetServiceBrowser()
    private(set) var services: [NetService] = []
    private let serviceType: String
    weak var delegate: BonjourDiscoveryDelegate?

    // 设备唯一性索引： uniqueKey -> index in services
    // uniqueKey 优先使用 (device_id + ip)；其次 (ip)；最后 fallback 根名称
    private var indexByUniqueKey: [String: Int] = [:]
    
    // 扫描超时（避免无结果时卡住 UI 状态）
    private var scanTimer: Timer?
    private let defaultTimeout: TimeInterval = 3.0

    // 连续扫描
    private var isContinuous: Bool = false
    private var rescanTimer: Timer?
    private var rescanInterval: TimeInterval = 15.0

    // 通知节流，避免频繁刷新导致 UI 抖动
    private var lastNotifyAt: Date?
    private let throttleInterval: TimeInterval = 0.3
    private var pendingNotifyWork: DispatchWorkItem?
    // 上次记录的服务签名（按名称排序后用","连接），用于抑制重复日志
    private var lastServicesSignature: String = ""
    // 记录各 service.name 最近一次已输出的 uniqueKey，避免重复刷屏
    private var lastLoggedUniqueKeyByName: [String: String] = [:]
    // 上次输出 timeout reached 的时间
    private var lastTimeoutLogAt: Date = .distantPast

    init(serviceType: String) {
        self.serviceType = serviceType
        super.init()
        browser.delegate = self
    }

    func start() {
        let signature = services.map { $0.name }.sorted().joined(separator: ",")
        if signature != lastServicesSignature {
            Log.info("Bonjour", "start search: type=\(serviceType) continuous=\(isContinuous) prevServices=\(services.count) signature=\(signature)")
        }
        browser.stop()
        // 在连续模式下，不主动清空已有列表，避免 UI 闪烁；单次扫描则清空
        if !isContinuous {
            services.removeAll()
            indexByUniqueKey.removeAll()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.discoveryDidUpdate(self)
            }
        } else {
            // 连续模式：仅重置索引（避免旧 key 残留），保留当前 services，用增量事件修正
            indexByUniqueKey.removeAll()
            for (i, s) in services.enumerated() { indexByUniqueKey[computeUniqueKey(s)] = i }
        }
        scanTimer?.invalidate()
        browser.searchForServices(ofType: serviceType, inDomain: "local.")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scanTimer = Timer.scheduledTimer(withTimeInterval: self.defaultTimeout, repeats: false) { [weak self] _ in
                guard let self else { return }
                let now = Date()
                let sig = self.services.map { $0.name }.sorted().joined(separator: ",")
                // 60 秒内且签名未变，不重复打印 timeout
                if now.timeIntervalSince(self.lastTimeoutLogAt) > 60 || sig != self.lastServicesSignature {
                    Log.info("Bonjour", "timeout reached, stop search currentServices=\(self.services.count)")
                    self.lastTimeoutLogAt = now
                }
                self.stop()
            }
        }
    }

    func stop() {
        let signature = services.map { $0.name }.sorted().joined(separator: ",")
        if signature != lastServicesSignature {
            Log.info("Bonjour", "stop search services=\(services.count) indexedKeys=\(indexByUniqueKey.count) signature=\(signature)")
        }
        scanTimer?.invalidate()
        scanTimer = nil
        if !isContinuous { // 如果外部显式 stop（非连续循环中的 timeout），则清理重扫定时
            rescanTimer?.invalidate()
            rescanTimer = nil
        }
        browser.stop()
        // 即使没有发现/移除事件，也要通知外界更新 UI（如结束“正在扫描”）
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.discoveryDidUpdate(self)
        }
    }

    // 连续后台扫描：以周期性“短扫 + 暂停”方式保持目录新鲜，期间节流 UI 更新
    func startContinuous(rescanInterval: TimeInterval = 15.0) {
        self.isContinuous = true
        self.rescanInterval = rescanInterval
        let signature = services.map { $0.name }.sorted().joined(separator: ",")
        if signature != lastServicesSignature {
            Log.info("Bonjour", "start continuous search: interval=\(rescanInterval)s existingServices=\(services.count) signature=\(signature)")
        }
        // 立即开启一次短扫
        start()
        // 后续按间隔重复
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.rescanTimer?.invalidate()
            self.rescanTimer = Timer.scheduledTimer(withTimeInterval: rescanInterval, repeats: true) { [weak self] _ in
                guard let self else { return }
                if self.isContinuous {
                    self.start()
                }
            }
        }
    }

    func stopContinuous() {
    Log.info("Bonjour", "stop continuous mode")
        isContinuous = false
        rescanTimer?.invalidate()
        rescanTimer = nil
        stop()
    }
}

extension BonjourDiscovery: NetServiceBrowserDelegate {
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        // will search: 不再每次打印，保持安静（如需要调试可恢复）
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        // 仅在“列表中第一次出现这个名称”时打印 found；否则安静替换
        let alreadyExistsByName = services.contains(where: { $0.name == service.name })
        if !alreadyExistsByName {
            Log.info("Bonjour", "found service name=\(service.name) type=\(service.type) more=\(moreComing) beforeCount=\(services.count)")
        }
        service.delegate = self
        service.startMonitoring() // 监听 TXT 变化
        // 先放入，后续解析出更准确唯一键再调整
        let provisionalKey = rootName(of: service.name)
        // 1. 先按名称去重（连续模式可能未清空旧对象）
        if let dupByNameIdx = services.firstIndex(where: { $0.name == service.name }) {
            // duplicate silent
            services[dupByNameIdx] = service
            // 重建索引以确保 key->index 一致
            rebuildIndex()
        } else if let existingIdx = indexByUniqueKey[provisionalKey] {
            // provisional key hit silent
            services[existingIdx] = service
        } else {
            services.append(service)
            indexByUniqueKey[provisionalKey] = services.count - 1
        }
        let newSignature = services.map { $0.name }.sorted().joined(separator: ",")
        if newSignature != lastServicesSignature {
            Log.info("Bonjour", "added provisionalKey=\(provisionalKey) nowCount=\(services.count) signature=\(newSignature)")
            lastServicesSignature = newSignature
        }
        if !moreComing { scheduleThrottledUpdate() }
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
    Log.info("Bonjour", "remove service name=\(service.name) type=\(service.type) more=\(moreComing) beforeCount=\(services.count)")
        // 通过遍历移除（服务对象比较）并同步索引
        if let idx = services.firstIndex(of: service) {
            services.remove(at: idx)
            rebuildIndex()
        }
        let newSignature = services.map { $0.name }.sorted().joined(separator: ",")
        if newSignature != lastServicesSignature {
            Log.info("Bonjour", "after remove nowCount=\(services.count) signature=\(newSignature)")
            lastServicesSignature = newSignature
        }
        if !moreComing { scheduleThrottledUpdate() }
    }
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        // 确保停止时也让外部刷新 UI 状态
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.discoveryDidUpdate(self)
        }
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        let code = errorDict[NetService.errorCode]?.intValue ?? -1
        Log.error("Bonjour", "did not search, code=\(code) err=\(errorDict)")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.discoveryDidUpdate(self)
        }
    }

    private func scheduleThrottledUpdate() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let now = Date()
            let shouldNotifyNow: Bool
            if let last = self.lastNotifyAt {
                shouldNotifyNow = now.timeIntervalSince(last) >= self.throttleInterval
            } else {
                shouldNotifyNow = true
            }
            if shouldNotifyNow {
                self.lastNotifyAt = now
                self.delegate?.discoveryDidUpdate(self)
            } else {
                self.pendingNotifyWork?.cancel()
                let delay = self.throttleInterval - (now.timeIntervalSince(self.lastNotifyAt ?? now))
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.lastNotifyAt = Date()
                    self.delegate?.discoveryDidUpdate(self)
                }
                self.pendingNotifyWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + max(0.05, delay), execute: work)
            }
        }
    }
}

// MARK: - Helper
private func rootName(of name: String) -> String {
    // 取第一个空格或括号前的部分作为根名称，全部小写
    // 例如："Mindora 睡眠助手 (hzhy)"、"Mindora Sleep Assistant"、"Mindora" -> "mindora"
    let separators = CharacterSet(charactersIn: " (\t\n")
    if let range = name.rangeOfCharacter(from: separators) {
        return String(name[..<range.lowerBound]).lowercased()
    }
    return name.lowercased()
}

// MARK: - NetService Delegate (unique key extraction)
extension BonjourDiscovery: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        updateUniqueKey(for: sender)
    }
    func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        updateUniqueKey(for: sender)
    }
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        // 忽略解析失败，仍使用临时键
    }

    private func updateUniqueKey(for service: NetService) {
        guard let idx = services.firstIndex(of: service) else { return }
        let oldKey = indexByUniqueKey.first(where: { $0.value == idx })?.key
        let oldIP = extractIP(from: service) // 解析前的 IP（可能已经是新的，但下方会重新算）
        let key = computeUniqueKey(service)
        // 如果 key 已经对应当前 index，无需变动
        if indexByUniqueKey[key] == idx {
        // stable 不再重复打印
            return
        }
        // 如果 key 指向其他 index，采用“保留更早”策略或替换，这里选择替换为最新并移除旧条目
        if let otherIdx = indexByUniqueKey[key], otherIdx != idx, otherIdx < services.count {
            Log.info("Bonjour", "uniqueKey conflict key=\(key) oldIdx=\(otherIdx) newIdx=\(idx) -> replacing old")
            services.remove(at: otherIdx)
            rebuildIndex()
        }
        indexByUniqueKey[key] = services.firstIndex(of: service)
        let name = service.name
        let lastLoggedKey = lastLoggedUniqueKeyByName[name]
        if lastLoggedKey != key {
            Log.info("Bonjour", "uniqueKey updated name=\(name) key=\(key) oldKey=\(oldKey ?? "nil") ip=\(oldIP ?? "nil") total=\(services.count)")
            lastLoggedUniqueKeyByName[name] = key
        }
        scheduleThrottledUpdate()
    }

    private func computeUniqueKey(_ service: NetService) -> String {
        var deviceID: String?
        if let txtData = service.txtRecordData() {
            let dict = NetService.dictionary(fromTXTRecord: txtData)
            if let v = dict["device_id"], let s = String(data: v, encoding: .utf8), !s.isEmpty {
                deviceID = s.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        let ip = firstIPv4Address(of: service)
        if let deviceID, let ip { return "did=" + deviceID + "|ip=" + ip }
        if let deviceID { return "did=" + deviceID }
        if let ip { return "ip=" + ip }
        return rootName(of: service.name) // fallback
    }

    private func firstIPv4Address(of service: NetService) -> String? {
        // 与 extractIP(from:) 相同逻辑，返回第一个 IPv4 字符串
        guard let addresses = service.addresses else { return nil }
        for data in addresses {
            let ip = data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> String? in
                guard let addr = pointer.bindMemory(to: sockaddr.self).baseAddress else { return nil }
                if addr.pointee.sa_family == sa_family_t(AF_INET) {
                    // Use memory rebinding instead of unsafeBitCast to avoid undefined behavior
                    let addrIn = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    var addrCopy = addrIn.sin_addr
                    inet_ntop(AF_INET, &addrCopy, &buffer, socklen_t(INET_ADDRSTRLEN))
                    return String(cString: buffer)
                }
                return nil
            }
            if let ip { return ip }
        }
        return nil
    }

    fileprivate func rebuildIndex() {
        indexByUniqueKey.removeAll(keepingCapacity: true)
        for (i, s) in services.enumerated() {
            indexByUniqueKey[computeUniqueKey(s)] = i
        }
        let newSignature = services.map { $0.name }.sorted().joined(separator: ",")
        if newSignature != lastServicesSignature {
            Log.info("Bonjour", "rebuildIndex done services=\(services.count) keys=\(indexByUniqueKey.count) signature=\(newSignature)")
            lastServicesSignature = newSignature
        }
    }
}

private func extractIP(from service: NetService) -> String? {
    guard let addresses = service.addresses else { return nil }
    for data in addresses {
        let ip = data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> String? in
            guard let addr = pointer.bindMemory(to: sockaddr.self).baseAddress else { return nil }
            if addr.pointee.sa_family == sa_family_t(AF_INET) {
                // Use memory rebinding instead of unsafeBitCast to avoid undefined behavior
                let addrIn = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var addrCopy = addrIn.sin_addr
                inet_ntop(AF_INET, &addrCopy, &buffer, socklen_t(INET_ADDRSTRLEN))
                return String(cString: buffer)
            }
            return nil
        }
        if let ip { return ip }
    }
    return nil
}
