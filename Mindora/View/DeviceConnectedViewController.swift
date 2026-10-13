//
//  DeviceConnectedViewController.swift
//  mindora
//
//  配对成功页。设计稿：侧边栏 4「设备已连接」（lanhu_cebianlan .text_67~.text_70）。
//  扫描页点选一台设备绑定成功后进入：顶部设备名 + 设备图 + ✓ 已连接 + 「继续」「连接其他设备」。
//  按钮、标题字号与设备管理页（DeviceManagementViewController）同一套，两页在设计稿里是同一版式。
//

import UIKit

final class DeviceConnectedViewController: UIViewController {

    private let deviceName: String
    private let mode: DeviceScanViewController.Mode

    init(deviceName: String, mode: DeviceScanViewController.Mode) {
        self.deviceName = deviceName
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // .text_67：设备名，48px→24pt，居中（与设备管理页标题同字号）
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont(name: "PingFangSC-Regular", size: 24) ?? .systemFont(ofSize: 24)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // .group_60：设备图 380×340px → 190×170pt
    private let deviceImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "device"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // .group_62：#ECECEC 圆 52px→26pt，内含对勾
    private let checkCircle: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 236/255, green: 236/255, blue: 236/255, alpha: 1)
        v.layer.cornerRadius = 13
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let checkIcon: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let iv = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: config))
        iv.tintColor = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // .text_68：「已连接」48px→24pt Medium，与圆间距 20px→10pt
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = L("device_manage.status.connected")
        label.textColor = .white
        label.font = UIFont(name: "PingFangSC-Medium", size: 24) ?? .systemFont(ofSize: 24, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // .text-wrapper_29：白底「继续」
    private let continueButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.setTitle(L("register.button.continue"), for: .normal)
        button.setTitleColor(UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0), for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15)
        button.layer.cornerRadius = 24
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // .text-wrapper_30：#464646 底「连接其他设备」
    private let connectAnotherButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(red: 70/255.0, green: 70/255.0, blue: 70/255.0, alpha: 1.0)
        button.setTitle(L("device_manage.button.connect_other_device"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15)
        button.layer.cornerRadius = 24
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        titleLabel.text = deviceName

        let statusRow = UIView()
        statusRow.translatesAutoresizingMaskIntoConstraints = false
        checkCircle.addSubview(checkIcon)
        statusRow.addSubview(checkCircle)
        statusRow.addSubview(statusLabel)
        [titleLabel, deviceImageView, statusRow, continueButton, connectAnotherButton].forEach { view.addSubview($0) }

        // 设备图中心约在屏高 44.5%（设计稿 1624px 高里约 722px 处）
        let imageCenterY = NSLayoutConstraint(item: deviceImageView, attribute: .centerY, relatedBy: .equal,
                                              toItem: view, attribute: .centerY, multiplier: 0.89, constant: 0)
        NSLayoutConstraint.activate([
            // 标题与设备管理页同位置（那页是返回键下方 36pt，即安全区下 70pt）
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 70),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -30),

            imageCenterY,
            deviceImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deviceImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 190.0 / 375.0),
            deviceImageView.heightAnchor.constraint(equalTo: deviceImageView.widthAnchor, multiplier: 170.0 / 190.0),

            checkCircle.leadingAnchor.constraint(equalTo: statusRow.leadingAnchor),
            checkCircle.centerYAnchor.constraint(equalTo: statusRow.centerYAnchor),
            checkCircle.widthAnchor.constraint(equalToConstant: 26),
            checkCircle.heightAnchor.constraint(equalToConstant: 26),
            checkIcon.centerXAnchor.constraint(equalTo: checkCircle.centerXAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: checkCircle.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: checkCircle.trailingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: statusRow.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: statusRow.topAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: statusRow.bottomAnchor),
            statusRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            // .group_63 margin-top 89px：状态行与「继续」间距约 44pt
            statusRow.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -44),

            // 按钮：底部留白 200px→100pt，间距 36px→18pt；宽高圆角同设备管理页
            connectAnotherButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
            connectAnotherButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 33),
            connectAnotherButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -33),
            connectAnotherButton.heightAnchor.constraint(equalToConstant: 48),

            continueButton.bottomAnchor.constraint(equalTo: connectAnotherButton.topAnchor, constant: -18),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 33),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -33),
            continueButton.heightAnchor.constraint(equalToConstant: 48)
        ])

        continueButton.addTarget(self, action: #selector(didTapContinue), for: .touchUpInside)
        connectAnotherButton.addTarget(self, action: #selector(didTapConnectAnother), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    /// 继续：引导流程进主 App；设备管理入口回到设备管理页。
    @objc private func didTapContinue() {
        continueButton.animateButtonTap { [weak self] in
            guard let self else { return }
            switch self.mode {
            case .onboarding:
                OnboardingExitButton.completeOnboarding()
            case .management:
                if let nav = self.navigationController,
                   let dm = nav.viewControllers.last(where: { $0 is DeviceManagementViewController }) {
                    nav.popToViewController(dm, animated: true)
                } else {
                    self.dismiss(animated: true)
                }
            }
        }
    }

    /// 连接其他设备：回到扫描列表继续选。
    @objc private func didTapConnectAnother() {
        connectAnotherButton.animateButtonTap { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
}
