import Foundation
import CoreBluetooth

/// Scans for Mindora BLE peripherals and reads their device_id characteristic.
///
/// Workflow per discovered peripheral:
///   1. scanForPeripherals(withServices:) returns a peripheral advertising our service UUID
///   2. connect(peripheral) → discoverServices → discoverCharacteristics → readValue
///   3. UTF-8 decode of the read value becomes the device's canonical `device_id`
///   4. cancelPeripheralConnection (transient connection per spec — App doesn't talk over BLE for data)
///
/// Devices stay in `devices` once seen; if the read failed (transient connection error etc.)
/// the next didDiscover event retries connect-and-read.
///
/// Notifications are posted on the main queue (CBCentralManager queue is main here).
final class BLEDiscovery: NSObject {
    static let shared = BLEDiscovery()

    /// Posted whenever the visible `devices` list changes (debounced).
    /// `object` is the `BLEDiscovery` instance.
    static let didUpdateNotification = Notification.Name("BLEDiscovery.didUpdate")
    /// Posted on permission denied / hardware unavailable. `object` is a `CBManagerState` rawValue (Int).
    static let didFailNotification = Notification.Name("BLEDiscovery.didFail")
    /// 检测到「本机残留配对信息已失效」时发出，`object` 是设备广播名（可能为 nil）。
    /// 这个状态用户不自己去系统设置里「忽略此设备」就永远好不了，App 侧无法自愈，
    /// 所以必须浮到 UI 上告诉他怎么做 —— 只打日志的话用户看到的仍然是「设备不在线」。
    static let didDetectStalePairingNotification = Notification.Name("BLEDiscovery.didDetectStalePairing")

    /// Mindora BLE service / characteristic UUIDs。必须与固件 `Tools/user_server/iot_server.py` 完全一致。
    ///
    /// 这些是**产品级协议常量**：全网所有 Mindora 设备取值相同，标识「这是 Mindora 协议」；
    /// 每台设备的身份由 device_id 特征的 value 承载。绝不能按 MAC / device_id 逐台派生 ——
    /// `scanForPeripherals(withServices:)` 必须拿着已知常量去过滤，逐台不同就一台也扫不到。
    /// 2026-08-04 已从示例占位值换成 uuidgen 真随机值（固件 + iOS 同步）。
    static let serviceUUID = CBUUID(string: "9fcc2fbe-a190-4ee9-96db-68e82f5f15cc")
    /// device_id 只读特征（本类只用这一个；数据通道的两个见 BLEDataChannel）。
    static let characteristicUUID = CBUUID(string: "6a50d363-d2de-4bd9-b66f-7b02947e7a9c")

    struct Device {
        /// Strong reference; CoreBluetooth reaps unreferenced peripherals.
        let peripheral: CBPeripheral
        /// Local name from advertisement data (preferred) or `peripheral.name` fallback.
        var advertisedName: String?
        /// device_id read from characteristic. Nil until read completes.
        var deviceID: String?
        var lastSeen: Date
    }

    private(set) var devices: [Device] = []

    private var central: CBCentralManager?
    /// True after `startContinuous()` was called and we haven't been told to stop.
    private var startRequested = false
    private var isScanning = false

    /// Peripheral identifiers we're currently mid-handshake on (connecting → discovering → reading).
    /// Prevents re-triggering connect for a peripheral that's already in flight.
    private var pendingReads: Set<UUID> = []
    /// 每台外设的握手超时任务（连接 → 发现服务 → 读特征 全程共用一个 deadline）。
    private var handshakeTimeouts: [UUID: DispatchWorkItem] = [:]
    /// 握手超时时长：BLE 连接 + 发现 + 读一个短特征，正常 1–3s，10s 足够宽松。
    private let handshakeTimeout: TimeInterval = 10.0
    /// 每台外设连续握手失败次数（超时 + 建连失败都算；成功读到 device_id 即清零）。
    private var handshakeFailures: [UUID: Int] = [:]
    /// 连续失败到这个次数时打一条排查提示；之后每 10 次再提醒一次。
    /// 只在第 3 次打的话，连续失败上百次的现场只会留下一条提示，翻日志时极易漏掉。
    private static let busyHintThreshold = 3
    private static let hintRepeatEvery = 10
    /// 连续失败后的重连退避截止时刻：在此之前收到的 didDiscover 一律不重连。
    /// 没有它时，AllowDuplicates 扫描会让每一条广告都触发一次 connect —— 实测一台连不上的
    /// 设备一天打了 248 次 connect、每次占用 10s 握手窗口，纯属空耗射频和电量。
    private var retryNotBefore: [UUID: Date] = [:]
    /// 每台外设上一次抛出「配对信息失效」提示的时刻。提示会打断用户，必须自带去重 + 冷却：
    /// 同一台设备在冷却期内只提醒一次，绝不反复弹。
    private var stalePairingNotifiedAt: [UUID: Date] = [:]
    private static let stalePairingCooldown: TimeInterval = 30 * 60
    /// 纯超时（没报明确错误）时，连续这么多次才怀疑是配对信息失效。
    /// 设成比 busyHintThreshold 高不少，避免把「设备正忙于音频串流」误判成配对问题。
    private static let stalePairingSuspectThreshold = 8
    /// 退避曲线：5s → 10 → 20 → 40 → 80 → 封顶 120s。
    private static func retryDelay(afterFailures n: Int) -> TimeInterval {
        min(5.0 * pow(2.0, Double(max(0, n - 1))), 120.0)
    }

    /// Coalesce bursts of didDiscover / didUpdateValueFor into one notification.
    private var notifyScheduled = false
    private let debounceInterval: TimeInterval = 0.2

    /// 设备最近一次广告被探测到的时间窗。超过这个时间没再看见就当做"已离开范围"，从 devices
    /// 里 prune 掉，让上层（DM 心跳 / DeviceScan 列表）能正确感知"out of range"。
    /// 配合 AllowDuplicatesKey = true 让 didDiscover 持续刷新 lastSeen——iOS BLE 没有
    /// "didDisappear" 回调，只能靠这种被动 timeout 检测。
    private let staleWindow: TimeInterval = 15.0
    private let pruneInterval: TimeInterval = 5.0
    private var pruneTimer: Timer?
    /// 每台外设上一次打 didDiscover 日志的时刻，见 shouldLogDiscover。
    private var lastDiscoverLogAt: [UUID: Date] = [:]

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Start scanning. Idempotent — repeated calls before stop() are no-ops.
    /// If Bluetooth permission hasn't been granted yet, this triggers the system prompt.
    func startContinuous() {
        if startRequested && isScanning { return }
        startRequested = true
        Log.info("BLE", "startContinuous requested")
        if central == nil {
            // queue: nil → main queue. Delegate callbacks run on main, consistent with BonjourDiscovery.
            central = CBCentralManager(delegate: self, queue: nil)
        } else if central?.state == .poweredOn && !isScanning {
            beginScan()
        }
        startPruneTimer()
    }

    /// Stop scanning. Discovered `devices` array is preserved so consumers can keep using it
    /// after a stop/start round-trip; the next scan will refresh on its own.
    func stop() {
        guard startRequested else { return }
        Log.info("BLE", "stop requested")
        startRequested = false
        stopPruneTimer()
        if isScanning {
            central?.stopScan()
            isScanning = false
        }
        for id in pendingReads {
            if let dev = devices.first(where: { $0.peripheral.identifier == id }) {
                central?.cancelPeripheralConnection(dev.peripheral)
            }
        }
        pendingReads.removeAll()
        postUpdate()
    }

    /// 强制清空 devices 缓存并重启扫描——DeviceScan 进页面时调用，避免显示上次会话留下的
    /// "鬼影"设备。stop() 默认保留 devices 是为了支持 stop/start 短暂往返的"暂停"语义，
    /// reset() 是显式的"重新探测"语义。
    func reset() {
        Log.info("BLE", "reset (clear cache + rescan)")
        let wasRequested = startRequested
        stop()
        devices.removeAll()
        // 用户主动重扫是明确的「立刻再试一次」意图，不该被上一轮的连续失败退避压住。
        handshakeFailures.removeAll()
        retryNotBefore.removeAll()
        // stalePairingNotifiedAt 故意不清：重扫是用户看完提示后的自然动作，
        // 清掉就会在同一次排查里把同一条提示反复弹给他。
        postUpdate()
        if wasRequested {
            startContinuous()
        }
    }

    // MARK: - Internals

    private func beginScan() {
        guard let central, central.state == .poweredOn, !isScanning else { return }
        Log.info("BLE", "scanForPeripherals withServices=[\(Self.serviceUUID)]")
        // AllowDuplicates = true 让 didDiscover 持续给同一台设备回调，从而能不断刷新
        // lastSeen——配合 prune timer 实现 BLE 层的"心跳"。代价是回调数量增加，但
        // Mindora 设备广告频率不高（1-10Hz），实际成本可控。
        central.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
        // 扫描扫不到已经连着的设备，必须另外捞一次，见下。
        absorbConnectedPeripherals()
    }

    /// 把「本机已经连着的 Mindora 设备」补进 devices。
    ///
    /// **扫描这条路发现不了它们**：BLE 外设一旦接受连接就会停止广播，didDiscover 从此不再来。
    /// 而 iOS 的连接是系统级的 —— App 调了 cancelPeripheralConnection，只要系统里还有别的
    /// 持有者，链路就还在。实测现象：设备端 `hcitool con` 明明挂着一条到本机的 LE 连接，
    /// App 在前台连扫 7 分钟 didDiscover 零条，扫描页全空 —— 用户看到的是「设备不在线」，
    /// 而它其实就连在手上。这条路径是常态，不是边角：只要 App 成功连过一次就可能进入。
    ///
    /// 每轮 prune 也调一次，而不是只在开扫时调一次：Device.lastSeen 靠 didDiscover 刷新，
    /// 这些设备永远等不到，只补一次的话 15s 后就被 prune 当成"已离开范围"清掉了。
    /// 反过来，设备真断开后 retrieve 不再返回它，lastSeen 自然过期，prune 照常回收。
    private func absorbConnectedPeripherals() {
        guard let central, central.state == .poweredOn else { return }
        let connected = central.retrieveConnectedPeripherals(withServices: [Self.serviceUUID])
        guard !connected.isEmpty else { return }
        for peripheral in connected {
            let isNew = !devices.contains { $0.peripheral.identifier == peripheral.identifier }
            if isNew {
                // 没有广告包，拿不到 CBAdvertisementDataLocalNameKey，只能退回 peripheral.name
                Log.info("BLE", "已连接设备（扫描看不到）name=\(peripheral.name ?? "nil") id=\(peripheral.identifier)")
            }
            touchDevice(peripheral, name: peripheral.name)
        }
        scheduleNotify()
    }

    /// 新增或刷新一台设备（didDiscover 与已连接设备两条路径共用）。
    /// device_id 还没读到就顺带发起一次读取；已在进行中的会被 connectAndRead 自行挡掉。
    private func touchDevice(_ peripheral: CBPeripheral, name: String?) {
        if let idx = devices.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
            var existing = devices[idx]
            if let name, existing.advertisedName != name {
                existing.advertisedName = name
            }
            existing.lastSeen = Date()
            devices[idx] = existing
            if existing.deviceID == nil {
                connectAndRead(peripheral)
            }
        } else {
            devices.append(Device(peripheral: peripheral, advertisedName: name, deviceID: nil, lastSeen: Date()))
            connectAndRead(peripheral)
        }
    }

    /// 启动周期性 prune，每 5 秒检查一次：把 lastSeen 老于 15 秒的设备从 devices 里移除。
    /// CoreBluetooth 没有"didDisappear" 回调，必须靠这套被动 timeout 才能感知设备离开范围。
    private func startPruneTimer() {
        guard pruneTimer == nil else { return }
        pruneTimer = Timer.scheduledTimer(withTimeInterval: pruneInterval, repeats: true) { [weak self] _ in
            self?.pruneStaleDevices()
        }
    }

    private func stopPruneTimer() {
        pruneTimer?.invalidate()
        pruneTimer = nil
    }

    private func pruneStaleDevices() {
        // 先刷新已连接设备的 lastSeen，再判过期 —— 顺序反了会把它们误清掉。
        absorbConnectedPeripherals()
        let now = Date()
        let before = devices.count
        let pruned = devices.filter { now.timeIntervalSince($0.lastSeen) > staleWindow }
        devices.removeAll { now.timeIntervalSince($0.lastSeen) > staleWindow }
        // 掉出范围的设备一并清掉日志节流记录，下次再出现能立刻打一条「又看见了」。
        for device in pruned { lastDiscoverLogAt.removeValue(forKey: device.peripheral.identifier) }
        if devices.count != before {
            Log.info("BLE", "pruned \(before - devices.count) stale device(s) (>\(Int(staleWindow))s)")
            scheduleNotify()
        }
    }

    private func connectAndRead(_ peripheral: CBPeripheral) {
        guard let central, central.state == .poweredOn else { return }
        if pendingReads.contains(peripheral.identifier) { return }
        if let notBefore = retryNotBefore[peripheral.identifier], Date() < notBefore { return }
        Log.info("BLE", "connect peripheral=\(peripheral.identifier)")
        pendingReads.insert(peripheral.identifier)
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        armHandshakeTimeout(peripheral)
    }

    /// CoreBluetooth 的 `connect` **没有超时**：对端不响应时 didConnect / didFailToConnect
    /// 都不会来，identifier 会永远留在 pendingReads 里，后续每次 didDiscover 都被
    /// 「已在进行中」挡掉 —— 表现为广告一直收得到、device_id 却永远读不出来，
    /// 设备在 App 里永远显示不可用。必须自己兜一个超时把状态释放掉。
    private func armHandshakeTimeout(_ peripheral: CBPeripheral) {
        let id = peripheral.identifier
        handshakeTimeouts[id]?.cancel()
        let item = DispatchWorkItem { [weak self, weak peripheral] in
            guard let self else { return }
            guard self.pendingReads.contains(id) else { return }
            let fails = self.recordHandshakeFailure(id)
            Log.error("BLE", "握手超时（\(Int(self.handshakeTimeout))s 内没读到 device_id）→ 断开重来 peripheral=\(id) 连续第 \(fails) 次")
            if self.shouldEmitHint(fails) {
                // 广播收得到、建连却始终无响应，是「射频被占」的典型特征：BR/EDR（A2DP 音乐）
                // 与 BLE 共用同一套射频靠时分复用，音频串流会把 BLE 的时间片挤没，广播是单向的
                // 还能发出去，建连需要双向握手就完不成。嵌入式板子上 Wi-Fi 还要再抢一份。
                // 另一个同样常见的成因见 didFailToConnect 里的配对信息失效提示。
                Log.error("BLE", "⚠️ 已连续 \(fails) 次握手超时但广告正常 —— 设备可能正忙（蓝牙音频串流？）导致 BLE 抢不到射频时间片；也可能是本机残留的配对信息已失效。优先确认 Wi-Fi 通道是否可用，并在 iOS 设置→蓝牙里「忽略此设备」后重试")
            }
            // 配对信息失效不总是报 peerRemovedPairingInformation —— 实测同一台设备会在
            // 「明确报错」和「connect 无响应直到超时」之间来回切换。连续这么多次都拿不下来时，
            // 无论根因是哪一种，用户唯一能做的补救都是去系统设置里忽略这台设备。
            if fails >= Self.stalePairingSuspectThreshold, let peripheral {
                self.notifyStalePairing(peripheral)
            }
            if let peripheral { self.central?.cancelPeripheralConnection(peripheral) }
            self.clearHandshake(id)   // 释放占位，退避到期后的 didDiscover 会重连
        }
        handshakeTimeouts[id] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + handshakeTimeout, execute: item)
    }

    /// 记一次握手失败并按次数排下一次可重连的时刻，返回累计连续失败次数。
    @discardableResult
    private func recordHandshakeFailure(_ id: UUID) -> Int {
        let fails = (handshakeFailures[id] ?? 0) + 1
        handshakeFailures[id] = fails
        retryNotBefore[id] = Date().addingTimeInterval(Self.retryDelay(afterFailures: fails))
        return fails
    }

    /// 抛出「配对信息失效」提示（带去重 + 冷却）。
    private func notifyStalePairing(_ peripheral: CBPeripheral) {
        let id = peripheral.identifier
        if let last = stalePairingNotifiedAt[id], Date().timeIntervalSince(last) < Self.stalePairingCooldown { return }
        stalePairingNotifiedAt[id] = Date()
        let name = devices.first(where: { $0.peripheral.identifier == id })?.advertisedName ?? peripheral.name
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didDetectStalePairingNotification, object: name)
        }
    }

    private func shouldEmitHint(_ fails: Int) -> Bool {
        fails == Self.busyHintThreshold || (fails > Self.busyHintThreshold && fails % Self.hintRepeatEvery == 0)
    }

    private func clearHandshake(_ id: UUID) {
        handshakeTimeouts[id]?.cancel()
        handshakeTimeouts.removeValue(forKey: id)
        pendingReads.remove(id)
    }

    /// didDiscover 日志节流：每台外设在 staleWindow 内最多记一条。
    /// 设备被 prune 掉之后再出现会重新算「第一次看见」，所以上下线仍然看得出来。
    private func shouldLogDiscover(_ id: UUID) -> Bool {
        let now = Date()
        if let last = lastDiscoverLogAt[id], now.timeIntervalSince(last) < staleWindow {
            return false
        }
        lastDiscoverLogAt[id] = now
        return true
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

// MARK: - CBCentralManagerDelegate
extension BLEDiscovery: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Log.info("BLE", "central state changed: \(central.state.rawValue)")
        switch central.state {
        case .poweredOn:
            if startRequested && !isScanning {
                beginScan()
            }
        case .unauthorized, .unsupported, .poweredOff:
            isScanning = false
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.didFailNotification, object: central.state.rawValue)
            }
        case .resetting, .unknown:
            isScanning = false
        @unknown default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let localName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        // AllowDuplicates 扫描下这个回调是「每收到一个广播包一次」（设备 1-10Hz）。
        // Log.info 会同时写 os_log 和滚动日志文件、Release 也写，逐包打就是持续磁盘 IO。
        // 按设备节流：第一次看见必打（排查要靠它），之后每台最多每 staleWindow 打一条。
        if shouldLogDiscover(peripheral.identifier) {
            Log.info("BLE", "didDiscover name=\(localName ?? "nil") id=\(peripheral.identifier) rssi=\(RSSI)")
        }

        touchDevice(peripheral, name: localName)
        scheduleNotify()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Log.info("BLE", "didConnect \(peripheral.identifier) -> discoverServices")
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let fails = recordHandshakeFailure(peripheral.identifier)
        Log.error("BLE", "didFailToConnect \(peripheral.identifier) err=\(error?.localizedDescription ?? "nil") 连续第 \(fails) 次")
        // `peerRemovedPairingInformation`：本机还存着这台设备的配对密钥，设备侧的绑定记录却没了
        // （设备重刷 / 蓝牙栈重置 / 有人在设备上删了绑定都会造成）。链路层加密协商直接失败，
        // GATT 根本没机会建立 —— 表现就是广告一直扫得到、device_id 永远读不出来。
        // 我们的特征本身不要求加密，所以只要**在 iOS 设置里忽略这台设备**、把残留密钥清掉即可。
        // 这条必须显式打出来：只报 localizedDescription 的话，排查时极易与「设备正忙」混为一谈。
        if let err = error as? CBError, err.code == .peerRemovedPairingInformation {
            Log.error("BLE", "⚠️ 配对信息失效：本机保存的配对密钥在设备侧已不存在，BLE 永远连不上。"
                      + "处理：iOS 设置 → 蓝牙 → 找到该设备 → ⓘ →「忽略此设备」，然后重新扫描")
            notifyStalePairing(peripheral)
        } else if shouldEmitHint(fails) {
            Log.error("BLE", "⚠️ 已连续 \(fails) 次建连失败 peripheral=\(peripheral.identifier)，已退避 \(Int(Self.retryDelay(afterFailures: fails)))s 后再试")
        }
        clearHandshake(peripheral.identifier)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Log.info("BLE", "didDisconnect \(peripheral.identifier) err=\(error?.localizedDescription ?? "nil")")
        clearHandshake(peripheral.identifier)
    }
}

// MARK: - CBPeripheralDelegate
extension BLEDiscovery: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            Log.error("BLE", "didDiscoverServices err=\(error.localizedDescription)")
            central?.cancelPeripheralConnection(peripheral)
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            Log.error("BLE", "service \(Self.serviceUUID) not found on \(peripheral.identifier) — aborting handshake")
            central?.cancelPeripheralConnection(peripheral)
            return
        }
        peripheral.discoverCharacteristics([Self.characteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            Log.error("BLE", "didDiscoverChars err=\(error.localizedDescription)")
            central?.cancelPeripheralConnection(peripheral)
            return
        }
        guard let char = service.characteristics?.first(where: { $0.uuid == Self.characteristicUUID }) else {
            Log.error("BLE", "characteristic \(Self.characteristicUUID) not found on \(peripheral.identifier)")
            central?.cancelPeripheralConnection(peripheral)
            return
        }
        peripheral.readValue(for: char)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        defer { central?.cancelPeripheralConnection(peripheral) }
        if let error {
            Log.error("BLE", "didUpdateValue err=\(error.localizedDescription)")
            return
        }
        guard
            let data = characteristic.value,
            let raw = String(data: data, encoding: .utf8)
        else {
            Log.error("BLE", "char value missing or non-utf8 on \(peripheral.identifier)")
            return
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Log.error("BLE", "char value empty on \(peripheral.identifier)")
            return
        }
        Log.info("BLE", "device_id read from \(peripheral.identifier): \(trimmed)")
        handshakeFailures.removeValue(forKey: peripheral.identifier)   // 成功即清零连续失败计数
        retryNotBefore.removeValue(forKey: peripheral.identifier)      // 一并解除重连退避
        stalePairingNotifiedAt.removeValue(forKey: peripheral.identifier)

        if let idx = devices.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
            var existing = devices[idx]
            existing.deviceID = trimmed
            devices[idx] = existing
        }
        scheduleNotify()
    }
}
