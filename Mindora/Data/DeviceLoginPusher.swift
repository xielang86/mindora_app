import Foundation
import CryptoKit

/// 设备端用户身份激活：把 App 当前的 JWT 通过设备 user_server 的 /login 接口推过去，
/// 让设备知道"现在是哪个账号在用"——这是 iot_server.py 端启动用户画像同步、按 uid 落
/// 本地存储等下游逻辑的前提。详细契约见 Tools/doc/设备端接口契约.md §1.5。
///
/// 两层重试机制：
///   - 内层"突发重试"：单次 push 内做 3 次指数退避（1s → 2s → 4s ≈ 7s），处理网络瞬时抖
///     动。401 / 400 立刻放弃（重试也救不了）。
///   - 外层"心跳驱动重试"：订阅 UnifiedDeviceDiscovery.didUpdateNotification，每次 discovery
///     更新时检查持久化 entries——只要 token 指纹跟当前 JWT 对不上且设备此刻可达就重试。
///     带 60s per-deviceID cooldown 防止鬼畜重试。
///
/// 成功去重：成功的 push 把当前 JWT 指纹（SHA256 前 16 hex 字符）写进 Entry。下次同 token
/// 不重推；用户换账号 / token 刷新 → 指纹不匹配 → 自动重推。
final class DeviceLoginPusher {

    static let shared = DeviceLoginPusher()

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(discoveryDidUpdate),
            name: UnifiedDeviceDiscovery.didUpdateNotification, object: nil
        )
        // token 变化（登录/重新登录/换账号）统一在此响应：立即补推给所有已绑定设备。
        // 配合 AuthStorage 在 saveLoginInfo 里广播，任何写 token 的路径都不会漏推。
        NotificationCenter.default.addObserver(
            self, selector: #selector(tokenDidChange),
            name: AuthStorage.tokenDidChangeNotification, object: nil
        )
    }

    @objc private func tokenDidChange() {
        Log.info("DeviceLogin", "token changed → push to all bound devices")
        pushPendingForAllEntries(force: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        periodicTimer?.invalidate()
    }

    /// 周期同步定时器（仅前台运行）
    private var periodicTimer: Timer?
    /// 本进程是否已经做过「启动强制重推」。
    private var didForceOnLaunch = false

    // MARK: - Constants

    /// user_server HTTP 端口，跟 iot_server.py 里 USER_SERVER_PORT 对齐
    private let port = 9001
    /// 单次请求超时
    private let requestTimeout: TimeInterval = 6.0
    /// 内层突发重试序列（短，给瞬时网络抖动一次机会；持续失败靠外层心跳兜底）
    private let retryDelays: [TimeInterval] = [1, 2, 4]
    /// 外层心跳重试 cooldown：同一 deviceID 失败后至少等 60s 才再来一次，防止 discovery 频繁
    /// update 触发鬼畜重试
    private let retryCooldown: TimeInterval = 60.0
    /// 周期同步间隔：前台每隔这么久，对所有「已绑定 + 当前可达」的设备无条件重推一次当前 token，
    /// 兜底指纹判据无法察觉的情况（设备重启丢 token、某次推送实际未生效等）。
    /// 取小时级——即时触发（绑定/登录/回前台/心跳）已覆盖常规场景，这里只是长周期兜底。
    private let periodicSyncInterval: TimeInterval = 3600.0  // 1 小时
    /// 指纹记忆的保质期。指纹只能证明「客户端推成功过」，证明不了「设备现在还持有这个 token」；
    /// 超过这个时长就当作没推过，重推一次，避免设备侧丢 token 后被客户端记忆永久卡住。
    private let memoryTTL: TimeInterval = 6 * 3600  // 6 小时

    // MARK: - State

    /// 当前正在推送的 deviceID 集合。避免 connect + 心跳并发触发对同一台机器的重复推送。
    private var inFlight: Set<String> = []
    /// 上一次失败时间表，按 deviceID 限频。
    private var lastFailureAt: [String: Date] = [:]
    /// 待强制重推的 deviceID（忽略指纹）。App 启动 / 用户重连 / 设备从不可达变可达时写入，
    /// 推成功后清除 —— 这样即使触发那一刻 discovery 还没就绪，心跳也会把这次强制推补上，
    /// 不会因为「当时找不到 host」就把这次人为干预吞掉。
    private var needsForcePush: Set<String> = []
    /// 每台设备的强制重推入队时刻，用于「排队太久还没落地」的告警。
    private var forcePushQueuedAt: [String: Date] = [:]
    /// 超过这个时长仍未推成功就打告警日志。
    private let forcePushStaleThreshold: TimeInterval = 120
    /// 上一轮 discovery 的可达 deviceID 集合，用来识别「不可达 → 可达」跃迁（设备重启的典型特征）。
    private var lastReachableIDs: Set<String> = []
    private let lock = NSLock()

    // MARK: - Public API

    /// 异步把当前 JWT 推到这台设备的 /login。指纹匹配则跳过。失败按 retryDelays 内层重试，
    /// 仍失败则记录 lastFailureAt 等心跳重试。
    ///
    /// - Parameter force: 来自 DeviceSession.connect 的直接调用传 true 跳过 cooldown
    ///   （用户刚操作完，必须立刻试一下）；来自心跳的自动重试传 false 走 cooldown。
    /// - Parameter ignoreFingerprint: true 时即使指纹已匹配也照样重推。周期同步用，
    ///   兜底「设备端丢了 token / 某次推送实际没生效」等指纹判据无法察觉的情况。
    func pushLogin(for entry: DeviceSession.Entry, force: Bool = true, ignoreFingerprint: Bool = false) {
        guard let did = entry.deviceID, !did.isEmpty else {
            Log.info("DeviceLogin", "skip: no device_id name=\(entry.displayName ?? "nil")")
            return
        }
        guard let token = AuthStorage.shared.token, !token.isEmpty else {
            Log.error("DeviceLogin", "skip: no JWT in AuthStorage, can't activate device user")
            return
        }

        let currentFp = Self.fingerprint(of: token)
        // 排队中的强制重推（启动 / 重连 / 设备刚上线）无视指纹。
        let forced = ignoreFingerprint || isForcePushPending(did)
        if !forced, entry.lastLoginPushedTokenFingerprint == currentFp {
            if let at = entry.lastLoginPushedAt, Date().timeIntervalSince(at) < memoryTTL {
                Log.info("DeviceLogin", "skip: token fp already pushed to \(did) (\(entry.displayName ?? "?")) age=\(Int(Date().timeIntervalSince(at)))s")
                return
            }
            // 指纹相同但记忆过期（或老存档没有时间戳）→ 重推一次，防止设备侧丢 token 卡死。
            Log.info("DeviceLogin", "memory expired → repush device_id=\(did) (\(entry.displayName ?? "?"))")
        }

        // 心跳来的非强制调用要遵守 cooldown，避免 didUpdate 频繁触发把网络打爆
        if !force {
            lock.lock()
            if let lastFail = lastFailureAt[did], Date().timeIntervalSince(lastFail) < retryCooldown {
                lock.unlock()
                Log.info("DeviceLogin", "skip: in cooldown device_id=\(did) name=\(entry.displayName ?? "?")")
                return
            }
            lock.unlock()
        }

        // 占座：同一 device_id 同时只跑一条
        lock.lock()
        if inFlight.contains(did) {
            lock.unlock()
            Log.info("DeviceLogin", "skip: 已有推送在进行中(inFlight) device_id=\(did) name=\(entry.displayName ?? "?")")
            return
        }
        inFlight.insert(did)
        lock.unlock()

        Log.info("DeviceLogin", "queued push device_id=\(did) name=\(entry.displayName ?? "?") force=\(force) ignoreFp=\(ignoreFingerprint)")
        Task.detached { [weak self] in
            guard let self else { return }
            // 在线解析可拨号 host（mDNS hostname / IPv4）。设备只在 mDNS 里广播 hostname，
            // 存档里的 host 可能只是服务名（带空格、不可拨号），所以这里按需解析最新地址。
            var success = false
            var didAttempt = false      // 是否真正发起过请求（连 host 都没有、BLE 也不可达时不算）
            var deviceRejected = false  // 设备明确拒绝（401/400）——换条通道也是一样的结果，不再回落

            Log.info("DeviceLogin", "resolving host… device_id=\(did) name=\(entry.displayName ?? "?")")
            // BLE 兜得住时不做内层突发重试：整条重试链要 30s 左右，白等不如早点换通道。
            let bleBackup = await self.bleReachable(did)
            if let host = await self.resolveDialableHost(for: entry) {
                Log.info("DeviceLogin", "resolved host=\(host) device_id=\(did) bleBackup=\(bleBackup)")
                didAttempt = true
                let r = await self.runWithRetry(host: host, token: token, deviceID: did,
                                                name: entry.displayName ?? "?",
                                                maxAttempts: bleBackup ? 1 : retryDelays.count + 1)
                success = r.success
                deviceRejected = r.deviceRejected
            }

            // Wi-Fi 走不通就回落 BLE。注意**不能只在「解析不到 host」时才回落**：
            // 存档里的 host 形如 xxx.local 看着可拨号，设备一旦离开该局域网就只会超时，
            // 这时 resolveDialableHost 照样返回它，永远轮不到 BLE。所以以「HTTP 有没有
            // 真的推成功」为准，而不是以「有没有 host」为准。
            if !success, !deviceRejected, await self.bleReachable(did) {
                Log.info("DeviceLogin", "Wi-Fi 不通 → 回落 BLE 通道 device_id=\(did)")
                didAttempt = true
                success = await self.pushOverBLE(token: token, deviceID: did, name: entry.displayName ?? "?")
            }

            if !didAttempt {
                // 没有 host、BLE 也没扫到：通常是 discovery 还没就绪（如冷启动瞬间）。
                // 这不是"推送失败"，不进 cooldown——等 discovery 就绪后心跳要能立刻重试。
                Log.info("DeviceLogin", "defer: 暂未解析到 host、BLE 也不可达 device_id=\(did) name=\(entry.displayName ?? "?")")
                self.warnIfStale(did)   // 排队太久还落不了地要吵出来，别再静默卡死
            }

            self.finishInFlight(did, success: success, didAttempt: didAttempt)

            if success {
                self.clearForcePush(did)
                await MainActor.run {
                    DeviceSession.shared.markLoginPushed(deviceID: did, tokenFingerprint: currentFp)
                }
            }
        }
    }

    /// 推送结束后更新 inFlight / cooldown 状态。封进非 async 方法：NSLock.lock/unlock 不能直接出现
    /// 在 async 闭包体内（Swift 6 禁止跨挂起点持锁）；这里全程同步、无挂起点，合法。
    private func finishInFlight(_ did: String, success: Bool, didAttempt: Bool) {
        lock.lock(); defer { lock.unlock() }
        inFlight.remove(did)
        if success {
            lastFailureAt.removeValue(forKey: did)
        } else if didAttempt {
            // 仅"真正请求过且失败"才进 cooldown，避免一次过早的解析失败把心跳重试卡 60s
            lastFailureAt[did] = Date()
        }
    }

    // MARK: - 强制重推队列

    /// 把某台设备标记为「下次可达时无条件重推」。真正的推送交给心跳，
    /// 因此触发那一刻 discovery 没就绪也不会丢掉这次干预。
    private func markForcePush(_ did: String) {
        lock.lock()
        needsForcePush.insert(did)
        if forcePushQueuedAt[did] == nil { forcePushQueuedAt[did] = Date() }
        lock.unlock()
    }

    /// 排队太久还没推成功 → 打一条显眼日志。这类「意图被排队但一直落不了地」的问题
    /// 静默时极难查（上一版就是这么卡死的），宁可日志吵一点。
    private func warnIfStale(_ did: String) {
        lock.lock()
        let queuedAt = forcePushQueuedAt[did]
        lock.unlock()
        guard let queuedAt, Date().timeIntervalSince(queuedAt) > forcePushStaleThreshold else { return }
        Log.error("DeviceLogin", "⚠️ 强制重推已排队 \(Int(Date().timeIntervalSince(queuedAt)))s 仍未成功 device_id=\(did)（设备不可达？host 解析不到？）")
    }

    private func isForcePushPending(_ did: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return needsForcePush.contains(did)
    }

    private func clearForcePush(_ did: String) {
        lock.lock()
        needsForcePush.remove(did)
        forcePushQueuedAt.removeValue(forKey: did)
        lock.unlock()
    }

    /// 单台设备强制重推（用户点「重新连接」等人为干预入口）。
    func forceRepush(for entry: DeviceSession.Entry, reason: String) {
        guard let did = entry.deviceID, !did.isEmpty else { return }
        Log.info("DeviceLogin", "force repush queued device_id=\(did) reason=\(reason)")
        markForcePush(did)
        // 清掉失败 cooldown：人为干预不该被上一次失败挡住。
        lock.lock(); lastFailureAt.removeValue(forKey: did); lock.unlock()
        pushLogin(for: entry, force: true, ignoreFingerprint: true)
    }

    /// App 启动时对所有已绑设备强制重推一次（每个进程仅一次）。
    /// 冷启动瞬间 discovery 往往还没扫到设备，push 会 defer；标记留在 needsForcePush 里，
    /// 等心跳发现设备可达时补上。
    func forceRepushAllOnLaunch() {
        guard !didForceOnLaunch else { return }
        didForceOnLaunch = true
        let entries = DeviceSession.shared.entries
        guard !entries.isEmpty else { return }
        Log.info("DeviceLogin", "launch force repush: \(entries.count) entries")
        for entry in entries {
            forceRepush(for: entry, reason: "app launch")
        }
    }

    // MARK: - Heartbeat-driven retry

    /// 心跳：每次 UnifiedDeviceDiscovery 更新都检查一遍 entries。三种情况会推：
    ///   1. 指纹不匹配（换了 token）；
    ///   2. 该设备排队中有强制重推（启动 / 用户重连）；
    ///   3. 该设备刚从「不可达」变「可达」—— 设备重启的典型特征，此时它很可能已经丢了 token。
    @objc private func discoveryDidUpdate() {
        guard let token = AuthStorage.shared.token, !token.isEmpty else { return }
        let currentFp = Self.fingerprint(of: token)
        let reachableIDs = Set(UnifiedDeviceDiscovery.shared.devices.compactMap { $0.deviceID })

        lock.lock()
        let justCameOnline = reachableIDs.subtracting(lastReachableIDs)
        lastReachableIDs = reachableIDs
        lock.unlock()
        for did in justCameOnline {
            Log.info("DeviceLogin", "device came online device_id=\(did) → 强制重推")
            markForcePush(did)
        }

        for entry in DeviceSession.shared.entries {
            guard let did = entry.deviceID else { continue }
            guard reachableIDs.contains(did) else { continue }
            let forcePending = isForcePushPending(did)
            guard forcePending || entry.lastLoginPushedTokenFingerprint != currentFp else { continue }
            pushLogin(for: entry, force: false, ignoreFingerprint: forcePending)
        }
    }

    /// 显式触发：遍历当前所有持久化 entries，对指纹不匹配的尝试推送一次。
    /// 这是为"用户已经绑过设备 + 没有走 connect 路径"的场景准备的——典型触发点：
    ///   - DM 页 viewWillAppear（用户打开设备页时主动推一次）
    ///   - DeviceScan 页 viewDidLoad（搜索页同理）
    ///   - AuthService 登录成功保存 token 后（token 刚换，所有 entry 指纹都失效）
    ///
    /// force=true：忽略 cooldown，用户主动操作不能等。指纹匹配仍然跳过，所以不会
    /// 浪费请求。
    func pushPendingForAllEntries(force: Bool = true) {
        let entries = DeviceSession.shared.entries
        guard !entries.isEmpty else { return }
        Log.info("DeviceLogin", "pushPendingForAllEntries: scanning \(entries.count) entries, force=\(force)")
        for entry in entries {
            pushLogin(for: entry, force: force)
        }
    }

    // MARK: - 周期同步（前台常驻，最高可靠性兜底）

    /// 启动周期同步。前台 active 时由 SceneDelegate 调用；幂等（重复调用先停旧的）。
    func startPeriodicSync() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.periodicTimer?.invalidate()
            let t = Timer(timeInterval: self.periodicSyncInterval, repeats: true) { [weak self] _ in
                self?.syncReachableNow(ignoreFingerprint: true)
            }
            // tolerance 让系统合并定时器、省电；common modes 保证滚动时也触发
            t.tolerance = self.periodicSyncInterval * 0.2
            RunLoop.main.add(t, forMode: .common)
            self.periodicTimer = t
            Log.info("DeviceLogin", "periodic sync started, interval=\(self.periodicSyncInterval)s")
        }
    }

    /// 停止周期同步。进入后台时由 SceneDelegate 调用。
    func stopPeriodicSync() {
        DispatchQueue.main.async { [weak self] in
            self?.periodicTimer?.invalidate()
            self?.periodicTimer = nil
            Log.info("DeviceLogin", "periodic sync stopped")
        }
    }

    /// 立即对所有「已绑定 + 当前可达」的设备推一次当前 token。
    /// - Parameter ignoreFingerprint: true 时无视指纹强制重推（周期同步用）。
    ///   只推可达设备，避免对不在网的设备做无谓的失败请求。
    func syncReachableNow(ignoreFingerprint: Bool = false) {
        guard AuthStorage.shared.token?.isEmpty == false else { return }
        let reachableIDs = Set(UnifiedDeviceDiscovery.shared.devices.compactMap { $0.deviceID })
        guard !reachableIDs.isEmpty else { return }
        for entry in DeviceSession.shared.entries {
            guard let did = entry.deviceID, reachableIDs.contains(did) else { continue }
            // force=false 走 cooldown，避免失败时每个周期都硬打；指纹按需忽略
            pushLogin(for: entry, force: false, ignoreFingerprint: ignoreFingerprint)
        }
    }

    // MARK: - Internals

    private static func fingerprint(of token: String) -> String {
        let digest = SHA256.hash(data: Data(token.utf8))
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }

    /// 一个字符串能否直接当作 URL host 拨号：非空、无空格、且含 "."（hostname 以 .local 结尾、
    /// IPv4 含点）。设备的「服务名」如 "Mindora 2026-2" 带空格 → 不可拨号，必须解析。
    private func isDialable(_ host: String) -> Bool {
        return !host.isEmpty && !host.contains(" ") && host.contains(".")
    }

    private func normalizeHost(_ host: String) -> String {
        host.hasSuffix(".") ? String(host.dropLast()) : host
    }

    /// 解析这台设备「当前可拨号」的 host。顺序：
    ///   1) 存档里的 host / hostFallback——若本身就是合法 hostname / IPv4 直接用（快路径）
    ///   2) 读取 BonjourDiscovery 已解析的 host（discovery 在 didFind 时已对服务做 resolve，
    ///      hostName/IPv4 缓存在 NetService 上）。未解析到则 nil，等下次 discovery 更新后重试。
    private func resolveDialableHost(for entry: DeviceSession.Entry) async -> String? {
        if let h = entry.host, isDialable(h) { return normalizeHost(h) }
        if let h = entry.hostFallback, isDialable(h) { return normalizeHost(h) }
        Log.info("DeviceLogin", "存档 host 不可拨号 host=\(entry.host ?? "nil") fallback=\(entry.hostFallback ?? "nil") → 查 discovery")
        guard let did = entry.deviceID else { return nil }
        // services 由主线程的 NetServiceBrowser 回调维护，读取放主线程，避免数据竞争
        return await MainActor.run {
            BonjourDiscovery.shared.resolvedHost(forDeviceID: did)
        }
    }

    /// 这台设备当前是否被 BLE 扫到（有可用外设）。
    private func bleReachable(_ did: String) async -> Bool {
        await MainActor.run {
            BLEDiscovery.shared.devices.contains { $0.deviceID == did }
        }
    }

    /// 经 BLE 数据通道推 JWT。设备端把请求转发给本机 user_server /login，响应经 notify 回来。
    /// 不做内层突发重试：BLE 连接本身就慢且独占，失败交给心跳重试更稳。
    private func pushOverBLE(token: String, deviceID: String, name: String) async -> Bool {
        let envelope = LoginEnvelope(data: .init(
            jwtToken: token,
            language: LocalizationManager.shared.currentLanguage.rawValue
        ))
        guard let data = try? JSONEncoder().encode(envelope),
              let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            Log.error("DeviceLogin", "BLE: 请求体编码失败 device_id=\(deviceID)")
            return false
        }
        Log.info("DeviceLogin", "→ BLE 发送 /login request_type=\(envelope.requestType) jwtFp=\(Self.fingerprint(of: token)) len=\(token.count) name=\(name)")
        do {
            let resp = try await BLEDataChannel.shared.send(path: "/login", body: body, toDeviceID: deviceID)
            let code = resp["code"] as? Int
            if code == 0 {
                Log.info("DeviceLogin", "BLE OK device_id=\(deviceID) name=\(name)")
                return true
            }
            Log.error("DeviceLogin", "BLE 被设备拒绝 code=\(code.map(String.init) ?? "nil") msg=\(resp["msg"] as? String ?? "") device_id=\(deviceID)")
            return false
        } catch {
            Log.error("DeviceLogin", "BLE 推送失败 device_id=\(deviceID) err=\(error.localizedDescription)")
            return false
        }
    }

    /// - Returns: `deviceRejected` 为 true 表示设备明确拒绝（401/400），换 BLE 通道结果一样，
    ///   调用方不应再回落；false 表示网络层没打通，值得换条通道试试。
    private func runWithRetry(host: String, token: String, deviceID: String, name: String,
                              maxAttempts: Int = 0) async -> (success: Bool, deviceRejected: Bool) {
        let attemptCap = maxAttempts > 0 ? maxAttempts : retryDelays.count + 1
        var attempt = 0
        while true {
            let outcome = await singleAttempt(host: host, token: token, name: name, attempt: attempt)
            switch outcome {
            case .success:
                Log.info("DeviceLogin", "OK after attempt=\(attempt+1) device_id=\(deviceID) name=\(name)")
                return (true, false)
            case .doNotRetry(let reason):
                Log.error("DeviceLogin", "give up (no retry) reason=\(reason) device_id=\(deviceID) name=\(name)")
                return (false, true)
            case .retry:
                if attempt + 1 >= attemptCap || attempt >= retryDelays.count {
                    Log.error("DeviceLogin", "burst exhausted after \(attempt+1) attempts device_id=\(deviceID); 有 BLE 兜底则立即回落，否则等心跳重试")
                    return (false, false)
                }
                let delay = retryDelays[attempt]
                Log.info("DeviceLogin", "retry attempt=\(attempt+1) in \(delay)s device_id=\(deviceID)")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                attempt += 1
            }
        }
    }

    private enum Outcome {
        case success
        case retry
        case doNotRetry(String)
    }

    private func singleAttempt(host: String, token: String, name: String, attempt: Int) async -> Outcome {
        guard let url = URL(string: "http://\(host):\(port)/login") else {
            return .doNotRetry("invalid URL host=\(host) port=\(port)")
        }
        var req = URLRequest(url: url)
        RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = requestTimeout

        let envelope = LoginEnvelope(data: .init(
            jwtToken: token,
            language: LocalizationManager.shared.currentLanguage.rawValue
        ))
        do {
            req.httpBody = try JSONEncoder().encode(envelope)
        } catch {
            return .doNotRetry("encode error: \(error.localizedDescription)")
        }

        // 发送日志：打目标、request_type、token 指纹与长度（不输出 JWT 原文，避免泄露）
        Log.info("DeviceLogin", "→ 发送 POST \(url.absoluteString) request_type=\(envelope.requestType) jwtFp=\(Self.fingerprint(of: token)) len=\(token.count) attempt=\(attempt+1) name=\(name)")
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = requestTimeout
        let session = URLSession(configuration: cfg)
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return .retry }
            switch http.statusCode {
            case 200..<300:
                if let ack = try? JSONDecoder().decode(ServerAck.self, from: data), ack.code == 0 {
                    return .success
                }
                let body = String(data: data, encoding: .utf8) ?? "<binary>"
                return .doNotRetry("200 but body rejected: \(body.prefix(200))")
            case 401:
                return .doNotRetry("401 token rejected by device")
            case 400:
                return .doNotRetry("400 bad request (likely client bug)")
            case 500..<600:
                return .retry
            default:
                return .retry
            }
        } catch {
            Log.error("DeviceLogin", "network error: \(error.localizedDescription)")
            return .retry
        }
    }

    // MARK: - Payload types

    private struct LoginEnvelope: Codable {
        let requestType: String
        let version: String
        let timestamp: Int
        let data: LoginData

        init(data: LoginData) {
            // 设备端解析要求 request_type 为 login_with_jwt（不是 login），否则判定错误
            self.requestType = "login_with_jwt"
            self.version = "1.0"
            self.timestamp = Int(Date().timeIntervalSince1970)
            self.data = data
        }

        enum CodingKeys: String, CodingKey {
            case requestType = "request_type"
            case version
            case timestamp
            case data
        }
    }

    private struct LoginData: Codable {
        let jwtToken: String
        /// 顺带把 App 语言告诉硬件——设备侧是这条链路上唯一能知道用户语种的地方。
        /// 设备端 pydantic 模型默认忽略多余字段，旧固件收到也不会报错。
        let language: String
        enum CodingKeys: String, CodingKey {
            case jwtToken = "jwt_token"
            case language
        }
    }
}
