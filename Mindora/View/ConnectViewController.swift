import UIKit

final class ConnectViewController: UIViewController {
    private let logoLabel: UILabel = {
        let l = Theme.label(.bold, size: 28)
        l.text = "MINDORA"
        return l
    }()

    private let devicePreview: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = Theme.surface
        v.layer.cornerRadius = 16
        v.layer.masksToBounds = true

        let img = UIImageView(image: UIImage(systemName: "cube.box.fill"))
        img.translatesAutoresizingMaskIntoConstraints = false
        img.tintColor = Theme.secondary
        img.contentMode = .scaleAspectFit
        v.addSubview(img)
        NSLayoutConstraint.activate([
            img.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            img.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            img.widthAnchor.constraint(equalTo: v.widthAnchor, multiplier: 0.35),
            img.heightAnchor.constraint(equalTo: img.widthAnchor)
        ])
        return v
    }()

    private lazy var helpButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        b.tintColor = Theme.secondary
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(didTapHelp), for: .touchUpInside)
        return b
    }()

    private lazy var connectButton: UIButton = {
        let b = Theme.filledButton(title: "开始扫描设备")
        b.addTarget(self, action: #selector(didTapConnect), for: .touchUpInside)
        return b
    }()

    private let discovery = UnifiedDeviceDiscovery.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        view.addSubview(logoLabel)
        view.addSubview(helpButton)
        view.addSubview(devicePreview)
        view.addSubview(connectButton)

        layout()
    }

    private func layout() {
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            logoLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            logoLabel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),

            helpButton.centerYAnchor.constraint(equalTo: logoLabel.centerYAnchor),
            helpButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            devicePreview.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 24),
            devicePreview.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            devicePreview.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            devicePreview.heightAnchor.constraint(equalTo: devicePreview.widthAnchor, multiplier: 0.6),

            connectButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            connectButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            connectButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -24)
        ])
    }

    @objc private func didTapHelp() {
        let vc = HelpCardsViewController()
        vc.modalPresentationStyle = .formSheet
        present(vc, animated: true)
    }

    @objc private func didTapConnect() {
        Log.info("Connect", "tap connect: start scanning (Bonjour + BLE)")
        discovery.startContinuous()
        let selector = LiveDeviceSelectionViewController { [weak self] selected in
            guard let self else { return }
            Log.info("Connect", "selected device=\(selected.displayName) transport=\(selected.transportLabel) device_id=\(selected.deviceID ?? "nil")")
            self.dismiss(animated: true) {
                // Bonjour service (if any) is already resolved by LiveDeviceSelectionViewController.
                DeviceSession.shared.connect(
                    bonjour: selected.bonjour,
                    bleIdentifier: selected.ble?.identifier,
                    deviceID: selected.deviceID,
                    displayName: selected.displayName
                )
                // UI 立即跳转，不等待任何健康数据上传完成
                self.switchToMainTab()
                Task.detached(priority: .background) {
                    Log.info("Connect", "trigger background health sync after device connect")
                    HealthSyncService.shared.performManualSync()
                }
            }
        }
        let nav = UINavigationController(rootViewController: selector)
        if #available(iOS 15.0, *), let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        present(nav, animated: true)
    }

    deinit {
        discovery.stop()
    }

    private func switchToMainTab() {
        let tab = MainTabBarController()
        if let window = view.window ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first {
            window.rootViewController = tab
            window.makeKeyAndVisible()
        } else {
            navigationController?.setViewControllers([tab], animated: true)
        }
    }
}
