import UIKit

/// Live list of Mindora devices merged from Bonjour + BLE.
///
/// On tap: hand the picked `UnifiedDevice` up via `onSelect` immediately. We deliberately
/// **do not** call `NetService.resolve(withTimeout:)` on Wi-Fi devices — the iOS app uses
/// `DeviceSession.host` only as an identity marker (never dials it), so `service.name`
/// ("Mindora 2026") is good enough. Skipping resolve also avoids -72007 timeouts seen
/// on some networks where mDNS A records take longer than 5s to arrive.
final class LiveDeviceSelectionViewController: UITableViewController {
    private let onSelect: (UnifiedDevice) -> Void

    init(onSelect: @escaping (UnifiedDevice) -> Void) {
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        title = "正在扫描附近的 Mindora 设备"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "停止", style: .plain, target: self, action: #selector(stopScan))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        let footer = UILabel()
        footer.text = "如果未发现设备，请确认手机与 Mindora 设备在同一局域网，蓝牙已开启，并确认设备已开启。"
        footer.textAlignment = .center
        footer.textColor = .secondaryLabel
        footer.font = .systemFont(ofSize: 13)
        footer.numberOfLines = 0
        footer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 80)
        tableView.tableFooterView = footer

        NotificationCenter.default.addObserver(
            self, selector: #selector(discoveryDidUpdate),
            name: UnifiedDeviceDiscovery.didUpdateNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(bonjourDidFail(_:)),
            name: BonjourDiscovery.didFailNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(bleDidFail(_:)),
            name: BLEDiscovery.didFailNotification, object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func stopScan() {
        UnifiedDeviceDiscovery.shared.stop()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "关闭", style: .plain, target: self, action: #selector(close))
    }

    @objc private func close() { dismiss(animated: true) }

    // MARK: - Data source

    private var devices: [UnifiedDevice] { UnifiedDeviceDiscovery.shared.devices }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        devices.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let dev = devices[indexPath.row]
        var cfg = cell.defaultContentConfiguration()
        cfg.text = dev.displayName
        cfg.secondaryText = dev.transportLabel
        cfg.image = UIImage(systemName: "dot.radiowaves.left.and.right")
        cell.contentConfiguration = cfg
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let dev = devices[indexPath.row]
        Log.info("DeviceSelect", "tap device=\(dev.displayName) transport=\(dev.transportLabel) device_id=\(dev.deviceID ?? "nil")")
        onSelect(dev)
    }

    // MARK: - Notifications

    @objc private func discoveryDidUpdate() {
        Log.info("DeviceSelect", "merged list update count=\(devices.count)")
        tableView.reloadData()
    }

    @objc private func bonjourDidFail(_ notification: Notification) {
        let code = (notification.object as? Int) ?? -1
        Log.error("DeviceSelect", "bonjour failed errorCode=\(code)")
        showLocalNetworkPermissionAlert()
    }

    @objc private func bleDidFail(_ notification: Notification) {
        let stateRaw = (notification.object as? Int) ?? -1
        Log.error("DeviceSelect", "ble failed centralState=\(stateRaw)")
        // For unauthorized state (rawValue 3), guide user to Settings.
        // Other BLE failures (.poweredOff / .unsupported / .resetting) silently fall through —
        // Bonjour can still work.
        if stateRaw == 3 {
            showBluetoothPermissionAlert()
        }
    }

    private func showLocalNetworkPermissionAlert() {
        let alert = CustomAlertViewController(
            title: L("permission.local_network.denied_title"),
            description: L("permission.local_network.denied_message"),
            confirmButtonTitle: L("permission.open_settings"),
            cancelButtonTitle: L("common.cancel"),
            onConfirm: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            },
            onCancel: nil
        )
        present(alert, animated: true)
    }

    private func showBluetoothPermissionAlert() {
        let alert = CustomAlertViewController(
            title: L("permission.bluetooth.denied_title"),
            description: L("permission.bluetooth.denied_message"),
            confirmButtonTitle: L("permission.open_settings"),
            cancelButtonTitle: L("common.cancel"),
            onConfirm: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            },
            onCancel: nil
        )
        present(alert, animated: true)
    }
}
