import Foundation
import CoreBluetooth

/// One physical Mindora device as seen by the App, merged across both discovery channels
/// (Bonjour and BLE). Cells in the device selection UI render one of these per row.
///
/// The `bonjour` and `ble` references describe **which transports saw this device**:
///   - Both non-nil: Wi-Fi + BLE saw the same `device_id` → merged into a single entry
///   - `bonjour` only: Only mDNS picked it up (likely user on different LAN or BLE out of range)
///   - `ble` only: Only BLE picked it up (likely Wi-Fi off / mDNS blocked / device_id matches no Bonjour entry yet)
struct UnifiedDevice {
    /// Stable identifier for table cell identity / diffing. Prefers `device_id` when known;
    /// falls back to a per-source key so an "anonymous" entry (no device_id yet) doesn't
    /// collide with others.
    let id: String

    /// User-facing name shown in scan list. Prefers Bonjour `service.name`, falls back to BLE
    /// advertised name, finally `"Mindora"`. 扫描阶段还没绑定，所以这就是用户能看到的型号。
    /// 绑定后 DeviceSession.Entry 才会引入"用户可改昵称 displayName"的概念。
    let displayName: String

    /// 设备型号常量（如 "Mindora 2026"）。当前实现里 = displayName，独立出来是为了：
    /// 1. 语义清晰：绑定时把它存进 Entry.model（永远是设备型号，不可被用户重命名覆盖）
    /// 2. 未来 BLE manufacturer data 里有独立 model 字段时可以拆开
    let model: String

    /// Bonjour NetService, when this device was discovered via mDNS. Resolve it (`resolve(withTimeout:)`)
    /// before passing to `DeviceSession.connect(...)` so hostName/addresses are populated.
    let bonjour: NetService?

    /// BLE peripheral, when this device was discovered via Core Bluetooth.
    let ble: CBPeripheral?

    /// Canonical device_id — present iff at least one source published it. The join key
    /// that proved two channels are looking at the same physical device.
    let deviceID: String?

    /// IPv4 address harvested from Bonjour at scan time (if any). Used as a fallback host
    /// when mDNS hostname resolution fails on the device side.
    let hostFallbackIPv4: String?

    var hasWifi: Bool { bonjour != nil }
    var hasBle: Bool { ble != nil }

    var transportLabel: String {
        switch (hasWifi, hasBle) {
        case (true, true):  return "Wi-Fi · BLE"
        case (true, false): return "Wi-Fi"
        case (false, true): return "BLE"
        default:            return ""
        }
    }
}

/// Merges `BonjourDiscovery` and `BLEDiscovery` outputs into a single deduplicated list.
///
/// The merge key is `device_id`: when a Bonjour service's TXT and a BLE peripheral's
/// characteristic both publish the same value, they collapse into one row. Devices whose
/// `device_id` hasn't materialized yet (BLE typically lags by 1–3s because it requires
/// connect + read) appear as separate rows until the value arrives, then collapse on
/// the next refresh.
final class UnifiedDeviceDiscovery {
    static let shared = UnifiedDeviceDiscovery()

    /// Posted on main queue whenever the merged `devices` list may have changed.
    /// `object` is the `UnifiedDeviceDiscovery` instance.
    static let didUpdateNotification = Notification.Name("UnifiedDeviceDiscovery.didUpdate")

    private(set) var devices: [UnifiedDevice] = []

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh),
            name: BonjourDiscovery.didUpdateNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh),
            name: BLEDiscovery.didUpdateNotification, object: nil
        )
    }

    // MARK: - Convenience: start both sources

    /// Start both Bonjour and BLE scans. Idempotent at each source.
    func startContinuous() {
        BonjourDiscovery.shared.startContinuous()
        BLEDiscovery.shared.startContinuous()
    }

    /// Stop both sources.
    func stop() {
        BonjourDiscovery.shared.stop()
        BLEDiscovery.shared.stop()
    }

    /// 强制刷新——清空两路的缓存再重新开始扫描。DeviceScan 进页面时调用，保证用户看到
    /// 的就是"当前真实可达"的设备，不会混入上次会话遗留的鬼影条目。
    ///
    /// 实现：
    ///   - Bonjour：stop → startContinuous（其 startContinuous 在 stopped→searching 转换时
    ///     自带 clearServices，无需显式清）
    ///   - BLE：reset() 显式 clear devices 数组再重启
    func reset() {
        Log.info("UnifiedDiscovery", "reset (fresh scan)")
        BonjourDiscovery.shared.stop()
        BLEDiscovery.shared.reset()
        BonjourDiscovery.shared.startContinuous()
        // Bonjour 的 startContinuous 内部已经发了 update 通知；这里再触发一次合并
        refresh()
    }

    // MARK: - Internals

    @objc private func refresh() {
        devices = mergeSources()
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
    }

    // 同型号多台不在 App 层加 device_id 短后缀做区分——污染显示名不友好。跟 iPhone 蓝牙
    // 处理同款 AirPods 一样：两行同名照常显示，用户通过点 ⓘ 看 device_id 区分；绑过一台
    // 之后用户改个昵称（"卧室的"/"书房的"）就再也不混了。Bonjour 路径上 zeroconf 设备端
    // 自动加的 " (2)" 后缀仍然有效（设备端处理，App 不用管）。

    private func mergeSources() -> [UnifiedDevice] {
        var result: [UnifiedDevice] = []
        // device_id → index in `result`. Lets BLE merge into an existing Bonjour entry.
        var indexByDeviceID: [String: Int] = [:]

        // 1) Add Bonjour services first. They typically have device_id immediately
        //    available via TXT, so they form the "anchor" entries.
        for service in BonjourDiscovery.shared.services {
            let did = service.deviceID
            let id = did ?? "bonjour:\(service.name)"
            let entry = UnifiedDevice(
                id: id,
                displayName: service.name,
                model: service.name,
                bonjour: service,
                ble: nil,
                deviceID: did,
                hostFallbackIPv4: service.firstIPv4Address
            )
            result.append(entry)
            if let did {
                indexByDeviceID[did] = result.count - 1
            }
        }

        // 2) Walk BLE devices. If a BLE device's device_id matches an existing Bonjour
        //    entry, merge into that entry; otherwise append as a BLE-only row.
        for bleDev in BLEDiscovery.shared.devices {
            let did = bleDev.deviceID
            if let did, let idx = indexByDeviceID[did] {
                let existing = result[idx]
                result[idx] = UnifiedDevice(
                    id: existing.id,
                    displayName: existing.displayName,
                    model: existing.model,
                    bonjour: existing.bonjour,
                    ble: bleDev.peripheral,
                    deviceID: did,
                    hostFallbackIPv4: existing.hostFallbackIPv4
                )
            } else {
                let id = did ?? "ble:\(bleDev.peripheral.identifier.uuidString)"
                let displayName = bleDev.advertisedName ?? bleDev.peripheral.name ?? "Mindora"
                let entry = UnifiedDevice(
                    id: id,
                    displayName: displayName,
                    model: displayName,
                    bonjour: nil,
                    ble: bleDev.peripheral,
                    deviceID: did,
                    hostFallbackIPv4: nil
                )
                result.append(entry)
                if let did {
                    indexByDeviceID[did] = result.count - 1
                }
            }
        }

        return result
    }
}
