//
//  BLEDataChannel.swift
//  Mindora
//
//  通过 BLE GATT 调设备 user_server 的 HTTP 接口 —— Wi-Fi 不通时的回落通道。
//
//  设备端实现见 Tools/user_server/iot_server.py 的 BleDataChannel：
//  它把 BLE 收到的请求原样 POST 给本机 user_server，再把响应经 notify 发回来。
//  所以这里的 body 跟 HTTP 直连时**完全一样**，只是外面套了一层 {path, body} 信封。
//
//  分片协议（两个方向一致，小端）：
//      [2 字节 total_length][1 字节 chunk_index][1 字节 final_flag][payload]
//  total_length 是**整个 JSON 的字节数**（不是本片长度）；final_flag 只有最后一片为 1。
//
//  连接策略：用完即断。BLE 常驻连接会占着设备的连接槽位，而这里的调用都是低频的
//  （推 JWT / 兜底重推），连一次 200ms 级别，不值得为它维持长连接。
//

import Foundation
import CoreBluetooth

final class BLEDataChannel: NSObject, @unchecked Sendable {
    // @unchecked：所有可变状态（session / central）只在 self.queue 这条串行队列上读写，
    // CoreBluetooth 的回调也指定了同一队列，因此实际是串行安全的，编译器看不出来。

    static let shared = BLEDataChannel()

    /// 请求特征（write）/ 响应特征（notify）。service 与 device_id 特征复用 BLEDiscovery 的常量。
    static let requestCharUUID = CBUUID(string: "a733eb73-3985-4e22-a536-d5de7342e5b4")
    static let responseCharUUID = CBUUID(string: "65a042cb-42b5-4a58-8bff-68c614336f14")

    enum ChannelError: LocalizedError {
        case bluetoothUnavailable(CBManagerState)
        case peripheralNotFound(String)
        case connectFailed(String)
        case characteristicMissing
        case writeFailed(String)
        case timeout
        case badResponse(String)
        case busy

        var errorDescription: String? {
            switch self {
            case .bluetoothUnavailable(let s): return "蓝牙不可用 state=\(s.rawValue)"
            case .peripheralNotFound(let did): return "未找到外设 device_id=\(did)"
            case .connectFailed(let m): return "连接失败: \(m)"
            case .characteristicMissing: return "设备缺少数据通道特征（固件版本过旧？）"
            case .writeFailed(let m): return "写入失败: \(m)"
            case .timeout: return "BLE 请求超时"
            case .badResponse(let m): return "响应异常: \(m)"
            case .busy: return "已有 BLE 请求在进行中"
            }
        }
    }

    private let logTag = "BLEChannel"
    private let queue = DispatchQueue(label: "com.mindora.ble.datachannel")
    private var central: CBCentralManager?

    /// 同一时刻只跑一条会话。调用方（推送心跳）本来就会重试，不值得为并发把状态机复杂化。
    private var session: Session?

    private final class Session {
        let deviceID: String
        let peripheralID: UUID
        let payload: Data
        let timeout: TimeInterval
        let completion: (Result<[String: Any], Error>) -> Void

        var peripheral: CBPeripheral?
        var requestChar: CBCharacteristic?
        var chunks: [Data] = []
        var nextChunk = 0
        /// 响应重组
        var expectedTotal: Int?
        var received: [Int: Data] = [:]
        var receivedLength = 0
        var timeoutItem: DispatchWorkItem?
        var finished = false

        init(deviceID: String, peripheralID: UUID, payload: Data, timeout: TimeInterval,
             completion: @escaping (Result<[String: Any], Error>) -> Void) {
            self.deviceID = deviceID
            self.peripheralID = peripheralID
            self.payload = payload
            self.timeout = timeout
            self.completion = completion
        }
    }

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// 经 BLE 调设备本机 user_server 的某个接口。
    /// - Parameters:
    ///   - path: user_server 路由，如 `/login`
    ///   - body: 与 HTTP 直连时完全相同的请求体
    ///   - deviceID: 目标设备的 device_id（用 BLEDiscovery 已扫到的外设做映射）
    /// - Returns: 设备返回的 JSON（即 user_server 的响应体）
    func send(path: String,
              body: [String: Any],
              toDeviceID deviceID: String,
              timeout: TimeInterval = 20) async throws -> [String: Any] {
        // BLEDiscovery.devices 由主线程维护，映射放主线程做。
        let peripheralID: UUID? = await MainActor.run {
            BLEDiscovery.shared.devices.first(where: { $0.deviceID == deviceID })?.peripheral.identifier
        }
        guard let peripheralID else { throw ChannelError.peripheralNotFound(deviceID) }

        let envelope: [String: Any] = ["path": path, "body": body]
        let payload = try JSONSerialization.data(withJSONObject: envelope)
        guard payload.count <= 0xFFFF else {
            throw ChannelError.badResponse("请求体超过 65535 字节，分片头装不下")
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.start(Session(deviceID: deviceID,
                                   peripheralID: peripheralID,
                                   payload: payload,
                                   timeout: timeout,
                                   completion: { continuation.resume(with: $0) }))
            }
        }
    }

    // MARK: - Session lifecycle（全部在 self.queue 上跑）

    private func start(_ new: Session) {
        guard session == nil else {
            new.completion(.failure(ChannelError.busy))
            return
        }
        session = new

        let item = DispatchWorkItem { [weak self] in self?.finish(.failure(ChannelError.timeout)) }
        new.timeoutItem = item
        queue.asyncAfter(deadline: .now() + new.timeout, execute: item)

        if central == nil {
            central = CBCentralManager(delegate: self, queue: queue)
            // 状态就绪后由 centralManagerDidUpdateState 接着走
            return
        }
        connectIfReady()
    }

    private func connectIfReady() {
        guard let session, let central else { return }
        guard central.state == .poweredOn else {
            if central.state != .unknown && central.state != .resetting {
                finish(.failure(ChannelError.bluetoothUnavailable(central.state)))
            }
            return   // unknown / resetting：等下一次 didUpdateState
        }
        guard let peripheral = central.retrievePeripherals(withIdentifiers: [session.peripheralID]).first else {
            finish(.failure(ChannelError.peripheralNotFound(session.deviceID)))
            return
        }
        session.peripheral = peripheral
        peripheral.delegate = self
        Log.info(logTag, "connect device_id=\(session.deviceID)")
        central.connect(peripheral, options: nil)
    }

    private func finish(_ result: Result<[String: Any], Error>) {
        guard let session, !session.finished else { return }
        session.finished = true
        session.timeoutItem?.cancel()
        if let peripheral = session.peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        self.session = nil
        switch result {
        case .success:
            Log.info(logTag, "done device_id=\(session.deviceID)")
        case .failure(let e):
            Log.error(logTag, "failed device_id=\(session.deviceID) err=\(e.localizedDescription)")
        }
        session.completion(result)
    }

    // MARK: - 分片

    private func makeChunks(payload: Data, mtu: Int) -> [Data] {
        let headerSize = 4
        let chunkSize = max(16, min(mtu, 512) - headerSize)
        let total = UInt16(payload.count)
        var result: [Data] = []
        var offset = 0
        var index = 0
        while offset < payload.count {
            let end = min(offset + chunkSize, payload.count)
            let slice = payload[offset..<end]
            var frame = Data()
            frame.append(UInt8(total & 0xFF))
            frame.append(UInt8(total >> 8))
            frame.append(UInt8(index & 0xFF))
            frame.append(end >= payload.count ? 1 : 0)
            frame.append(contentsOf: slice)
            result.append(frame)
            offset = end
            index += 1
        }
        return result
    }

    private func writeNextChunk() {
        guard let session, let peripheral = session.peripheral, let char = session.requestChar else { return }
        guard session.nextChunk < session.chunks.count else { return }
        let frame = session.chunks[session.nextChunk]
        peripheral.writeValue(frame, for: char, type: .withResponse)
    }

    /// 收到一片响应：按 header 重组，完整后解析 JSON 收尾。
    private func feedResponse(_ frame: Data) {
        guard let session else { return }
        guard frame.count >= 4 else {
            finish(.failure(ChannelError.badResponse("响应分片头不完整")))
            return
        }
        let bytes = [UInt8](frame)
        let total = Int(bytes[0]) | (Int(bytes[1]) << 8)
        let index = Int(bytes[2])
        let isFinal = bytes[3] == 1
        let payload = frame.subdata(in: 4..<frame.count)

        if let expected = session.expectedTotal, expected != total {
            // 设备端换了一条新响应（上一条没收全）→ 丢掉旧的重新攒
            session.received.removeAll()
            session.receivedLength = 0
        }
        session.expectedTotal = total
        if session.received[index] == nil {
            session.received[index] = payload
            session.receivedLength += payload.count
        }

        guard isFinal, session.receivedLength >= total else { return }
        let assembled = session.received.keys.sorted().compactMap { session.received[$0] }
            .reduce(into: Data()) { $0.append($1) }
        let trimmed = assembled.prefix(total)
        guard let json = (try? JSONSerialization.jsonObject(with: trimmed)) as? [String: Any] else {
            finish(.failure(ChannelError.badResponse("响应不是合法 JSON")))
            return
        }
        finish(.success(json))
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEDataChannel: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Log.info(logTag, "central state=\(central.state.rawValue)")
        connectIfReady()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Log.info(logTag, "connected → discover service")
        peripheral.discoverServices([BLEDiscovery.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finish(.failure(ChannelError.connectFailed(error?.localizedDescription ?? "unknown")))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // 正常收尾时 session 已经清空；这里只处理「还没拿到响应就断开」。
        guard session != nil else { return }
        finish(.failure(ChannelError.connectFailed("提前断开: \(error?.localizedDescription ?? "peer closed")")))
    }
}

// MARK: - CBPeripheralDelegate

extension BLEDataChannel: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            finish(.failure(ChannelError.connectFailed("discoverServices: \(error.localizedDescription)")))
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == BLEDiscovery.serviceUUID }) else {
            finish(.failure(ChannelError.characteristicMissing))
            return
        }
        peripheral.discoverCharacteristics([Self.requestCharUUID, Self.responseCharUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            finish(.failure(ChannelError.connectFailed("discoverCharacteristics: \(error.localizedDescription)")))
            return
        }
        guard let session else { return }
        guard let request = service.characteristics?.first(where: { $0.uuid == Self.requestCharUUID }),
              let response = service.characteristics?.first(where: { $0.uuid == Self.responseCharUUID }) else {
            // 老固件只有 device_id 特征 —— 明确报错，别让调用方以为发出去了。
            finish(.failure(ChannelError.characteristicMissing))
            return
        }
        session.requestChar = request
        // 先订阅再写，避免响应比订阅先到。
        peripheral.setNotifyValue(true, for: response)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.responseCharUUID else { return }
        if let error {
            finish(.failure(ChannelError.connectFailed("setNotify: \(error.localizedDescription)")))
            return
        }
        guard let session else { return }
        let mtu = peripheral.maximumWriteValueLength(for: .withResponse)
        session.chunks = makeChunks(payload: session.payload, mtu: mtu)
        Log.info(logTag, "写请求 bytes=\(session.payload.count) chunks=\(session.chunks.count) mtu=\(mtu)")
        writeNextChunk()
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            finish(.failure(ChannelError.writeFailed(error.localizedDescription)))
            return
        }
        guard let session else { return }
        session.nextChunk += 1
        if session.nextChunk < session.chunks.count {
            writeNextChunk()
        }
        // 全部写完 → 等 notify 回响应（超时由 timeoutItem 兜底）
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.responseCharUUID else { return }
        if let error {
            finish(.failure(ChannelError.badResponse(error.localizedDescription)))
            return
        }
        guard let data = characteristic.value else { return }
        feedResponse(data)
    }
}
