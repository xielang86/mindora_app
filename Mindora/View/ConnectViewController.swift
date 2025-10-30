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

    private let discovery = BonjourDiscovery.shared

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
        Log.info("Connect", "tap connect: start scanning")
        discovery.startContinuous(rescanInterval: 20)
        let selector = LiveDeviceSelectionViewController(discovery: discovery) { [weak self] selected in
            guard let self else { return }
            Log.info("Connect", "selected service name=\(selected.name) type=\(selected.type)")
            self.dismiss(animated: true) {
                // 解析后的 NetService 包含主机信息（iOS 会在 resolve 后提供）
                let host = selected.hostName ?? selected.name
                Log.info("Connect", "resolved host=\(host)")
                DeviceSession.shared.host = host
                DeviceSession.shared.port = 9102
                Log.info("Connect", "session saved host=\(host) port=9102, start initial sync")
                // UI 立即跳转，不等待上传完成，上传放在后台异步执行
                self.switchToMainTab()
                Task.detached(priority: .utility) { [weak self] in
                    guard let self else { return }
                    let payload = HealthDataUploader.makeFakePayload(uid: "demo-user")
                    do {
                        _ = try await HealthDataUploader.postUpdateProfile(host: host, port: 9102, payload: payload)
                        Log.info("Connect", "initial background sync success http://\(host):9102/update_profile")
                        await MainActor.run {
                            if let window = self.view.window ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.windows.first,
                               let root = window.rootViewController { Toast.show("APP连接成功，已后台推送健康数据（示例）", in: root.view) }
                        }
                    } catch {
                        Log.error("Connect", "initial background sync failed: \(error.localizedDescription)")
                        await MainActor.run {
                            if let window = self.view.window ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.windows.first,
                               let root = window.rootViewController { Toast.show("已连接，数据上传失败：\(error.localizedDescription)", in: root.view) }
                        }
                    }
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
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        } else {
            navigationController?.setViewControllers([tab], animated: true)
        }
    }
}
