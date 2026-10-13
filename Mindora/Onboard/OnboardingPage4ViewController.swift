//
//  OnboardingPage4ViewController.swift
//  mindora
//
//  Created by gao chao on 2025/10/20.
//
//  开机引导页4控制器 - 扫描设备页面
//  设计稿尺寸: 1242 × 2688 px (@3x, iPhone X/XS Max)
//  换算方式: 使用百分比适配不同屏幕
//  特点：顶部三行文字 + 设备列表 + 灰色禁用的底部按钮
//

import UIKit

final class OnboardingPage4ViewController: UIViewController {
    
    // MARK: - Device Discovery
    private let discovery = UnifiedDeviceDiscovery.shared
    private var hasFoundDevice = false
    private var searchTimeout: Timer?
    private var isSearching = false
    private let searchTimeoutDuration: TimeInterval = 6.0
    /// Unified device picked from discovery list. Cleared once we move to confirmedDevice.
    private var candidateDevice: UnifiedDevice?
    /// Resolved device awaiting user confirmation. Set after a successful resolve (Wi-Fi)
    /// or immediately for BLE-only devices. Consumed when user taps Connect. We deliberately
    /// do NOT write DeviceSession until the user confirms, to avoid auto-binding the wrong device.
    private var confirmedDevice: UnifiedDevice?
    /// Found device display name, persisted so the searching-label animation can re-render
    /// "<name> Found" instead of just "Mindora Found" after the timer tick.
    private var foundDeviceName: String?
    
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 设计稿中的像素值 - 顶部文字区域
    private let designTitleTop: CGFloat = DesignConstants.titleTopMargin  // "扫描附近设备" 距离顶部
    private let designTitleFontSize: CGFloat = DesignConstants.titleFontSize  // "扫描附近设备" 字体大小（设计稿是77pt）
    
    private let designSearchingTop: CGFloat = 34           // "持续自动搜索中..." 距离标题的距离
    private let designSearchingFontSize: CGFloat = DesignConstants.subtitleFontSize  // "持续自动搜索中..." 字体大小（设计稿是54pt）
    
    private let designDescriptionTop: CGFloat = 107        // 描述文字距离搜索文字的距离
    private let designDescriptionFontSize: CGFloat = DesignConstants.bodyFontSize  // 描述文字字体大小（设计稿是45pt）
    private let designDescriptionLineSpacing: CGFloat = 22 // 描述文字行间距
    private let designTextLeading: CGFloat = 116           // 文字距离屏幕左边的边距
    private let designDescriptionTrailing: CGFloat = 160   // 描述文字距离屏幕右边的边距（让宽度变小）
    
    // 设计稿中的像素值 - Mindora 文字
    // 设计稿中的像素值 - 底部按钮容器
    private let designButtonWidth: CGFloat = 1129          // 按钮宽度
    private let designButtonHeight: CGFloat = 187          // 按钮高度
    private let designButtonCornerRadius: CGFloat = 88     // 按钮圆角
    private let designButtonBottomMargin: CGFloat = 160    // 按钮距离底部
    
    // 设计稿中的像素值 - 问号图标
    private let designQuestionIconSize: CGFloat = 90       // 问号图标尺寸
    private let designQuestionIconLeading: CGFloat = 108   // 问号图标距离按钮左边
    
    // 设计稿中的像素值 - 按钮文字
    private let designButtonTextFontSize: CGFloat = DesignConstants.subtitleFontSize  // "连接 Mindora" 字体大小
    private let designButtonTextTrailing: CGFloat = 108    // 文字距离按钮右边
    
    // 设计稿中的像素值 - 退出按钮
    private let designExitButtonTop: CGFloat = 186         // 退出按钮距离屏幕顶部
    private let designExitButtonTrailing: CGFloat = 80     // 退出按钮距离屏幕右边 (避免被圆角屏幕切掉)
    private let designExitButtonWidth: CGFloat = 54        // 退出按钮图标宽度
    private let designExitButtonHeight: CGFloat = DesignConstants.subtitleFontSize  // 退出按钮图标高度
    
    // 计算实际尺寸的辅助方法
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        let capped = iPadAdaptiveScale.capped(dimension, widthReference: view.bounds.width)
        return designValue * (capped / designDimension)
    }
    
    // MARK: - UI Components
    
    // 全屏背景图
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-p4")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // "扫描附近设备" 标题
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L("onboarding.page4.scanning_title")
        label.textColor = .white
        label.textAlignment = .left  // 左对齐
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // "持续自动搜索中..." 搜索状态文字
    private let searchingLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left  // 左对齐
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 描述文字
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = L("onboarding.page4.description")
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .left  // 左对齐
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 内嵌设备选择列表：扫到 ≥2 台 Mindora 时显示在 description 和底部按钮之间。
    /// 单台 / 零台时 isHidden = true。点击行直接 confirmedDevice + onDeviceFound。
    private lazy var deviceListView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorColor = UIColor(white: 1.0, alpha: 0.12)
        tv.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        tv.rowHeight = 56
        tv.dataSource = self
        tv.delegate = self
        tv.register(InlineDeviceCell.self, forCellReuseIdentifier: InlineDeviceCell.identifier)
        tv.isHidden = true
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    /// 当前给 deviceListView 渲染的可绑设备快照。
    private var bindableDevices: [UnifiedDevice] = []

    // 底部白色按钮容器（灰色禁用状态）
    private let bottomContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 左侧问号图标
    private let questionIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-manual")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // "连接 Mindora" 文字标签（灰色禁用状态）
    private let connectLabel: UILabel = {
        let label = UILabel()
        label.text = L("onboarding.connect_mindora")
        label.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)  // 灰色
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 退出按钮
    private let exitButton: OnboardingExitButton = {
        let button = OnboardingExitButton()
        return button
    }()
    
    // 动画相关
    private var animationTimer: Timer?
    private var dotCount = 0
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        NotificationCenter.default.addObserver(self, selector: #selector(discoveryDidUpdate), name: UnifiedDeviceDiscovery.didUpdateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(discoveryDidFail(_:)), name: BonjourDiscovery.didFailNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(bleDidFail(_:)), name: BLEDiscovery.didFailNotification, object: nil)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopScanning()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 添加所有子视图
        view.addSubview(backgroundImageView)
        view.addSubview(titleLabel)
        view.addSubview(searchingLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(deviceListView)
        view.addSubview(bottomContainerView)
        bottomContainerView.addSubview(questionIconView)
        bottomContainerView.addSubview(connectLabel)
        view.addSubview(exitButton)
        
        setupStyles()
        setupConstraints()
    }
    
    private func setupStyles() {
        // 标题字体 - Medium 字重
        let titleFontSize = scale(designTitleFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = UIFont.systemFont(ofSize: titleFontSize, weight: .medium)
        
        // 搜索中字体
        let searchingFontSize = scale(designSearchingFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        searchingLabel.font = UIFont.systemFont(ofSize: searchingFontSize, weight: .regular)
        
        // 描述文字字体和行间距
        let descriptionFontSize = scale(designDescriptionFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        let lineSpacing = scale(designDescriptionLineSpacing, basedOn: view.bounds.height, designDimension: designHeight)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.alignment = .left  // 左对齐
        let attributedString = NSMutableAttributedString(string: descriptionLabel.text ?? "")
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedString.length))
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: descriptionFontSize, weight: .regular), range: NSRange(location: 0, length: attributedString.length))
        descriptionLabel.attributedText = attributedString
        
        // 按钮文字字体
        let buttonTextFontSize = scale(designButtonTextFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        connectLabel.font = UIFont.systemFont(ofSize: buttonTextFontSize, weight: .medium)
        
        // 按钮容器圆角
        let buttonCornerRadius = scale(designButtonCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        bottomContainerView.layer.cornerRadius = buttonCornerRadius
    }
    
    private func setupConstraints() {
        // 计算实际尺寸
        let titleTop = scale(designTitleTop, basedOn: view.bounds.height, designDimension: designHeight)
        let searchingTop = scale(designSearchingTop, basedOn: view.bounds.height, designDimension: designHeight)
        let descriptionTop = scale(designDescriptionTop, basedOn: view.bounds.height, designDimension: designHeight)
        let textLeading = scale(designTextLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let descriptionTrailing = scale(designDescriptionTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        
        let buttonWidth = scale(designButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonHeight = scale(designButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let buttonBottomMargin = scale(designButtonBottomMargin, basedOn: view.bounds.height, designDimension: designHeight)

        let questionIconSize = scale(designQuestionIconSize, basedOn: view.bounds.width, designDimension: designWidth)
        let questionIconLeading = scale(designQuestionIconLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonTextTrailing = scale(designButtonTextTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        
        NSLayoutConstraint.activate([
            // 背景图片 - 完全填充整个屏幕
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // "扫描附近设备" 标题 - 左对齐，距离左边116px
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: titleTop),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: textLeading),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -textLeading),
            
            // "持续自动搜索中..." 搜索状态 - 左对齐，距离左边116px
            searchingLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: searchingTop),
            searchingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: textLeading),
            searchingLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -textLeading),
            
            // 描述文字 - 左对齐，距离左边116px，右边距离200px（让宽度变小）
            descriptionLabel.topAnchor.constraint(equalTo: searchingLabel.bottomAnchor, constant: descriptionTop),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: textLeading),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -descriptionTrailing),

            // 内嵌设备选择列表（仅多设备时显示）
            // 用 equalTo 而不是 lessThanOrEqualTo 给一个 concrete 的 frame，否则 UITableView
            // 没自带 intrinsicContentSize 时会被收成 0 高度看不见。列表内容超过这个高度自带滚动。
            deviceListView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 32),
            deviceListView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: textLeading),
            deviceListView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -textLeading),
            deviceListView.bottomAnchor.constraint(equalTo: bottomContainerView.topAnchor, constant: -32),

            // 底部白色按钮容器
            bottomContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomContainerView.widthAnchor.constraint(equalToConstant: buttonWidth),
            bottomContainerView.heightAnchor.constraint(equalToConstant: buttonHeight),
            bottomContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -buttonBottomMargin),
            
            // 问号图标
            questionIconView.leadingAnchor.constraint(equalTo: bottomContainerView.leadingAnchor, constant: questionIconLeading),
            questionIconView.centerYAnchor.constraint(equalTo: bottomContainerView.centerYAnchor),
            questionIconView.widthAnchor.constraint(equalToConstant: questionIconSize),
            questionIconView.heightAnchor.constraint(equalToConstant: questionIconSize),
            
            // "连接 Mindora" 文字
            connectLabel.trailingAnchor.constraint(equalTo: bottomContainerView.trailingAnchor, constant: -buttonTextTrailing),
            connectLabel.centerYAnchor.constraint(equalTo: bottomContainerView.centerYAnchor),
            
            // 退出按钮
            exitButton.topAnchor.constraint(equalTo: view.topAnchor, constant: scale(designExitButtonTop, basedOn: view.bounds.height, designDimension: designHeight)),
            exitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -scale(designExitButtonTrailing, basedOn: view.bounds.width, designDimension: designWidth)),
            exitButton.widthAnchor.constraint(equalToConstant: scale(designExitButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)),
            exitButton.heightAnchor.constraint(equalToConstant: scale(designExitButtonHeight, basedOn: view.bounds.height, designDimension: designHeight))
        ])
    }
    
    private func setupActions() {
        // 为问号图标单独添加点击手势（始终可用）
        let questionTapGesture = UITapGestureRecognizer(target: self, action: #selector(questionIconTapped))
        questionIconView.addGestureRecognizer(questionTapGesture)
        questionIconView.isUserInteractionEnabled = true
        
        // 添加点击手势到底部按钮
        let bottomTapGesture = UITapGestureRecognizer(target: self, action: #selector(bottomContainerTapped))
        bottomContainerView.addGestureRecognizer(bottomTapGesture)
        bottomContainerView.isUserInteractionEnabled = false  // 初始禁用交互
    }
    
    // MARK: - Scanning Management
    
    /// 开始扫描设备
    private func startScanning() {
        isSearching = true
        hasFoundDevice = false

        // 重置UI状态
        connectLabel.text = L("onboarding.connect_mindora")
        connectLabel.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
        bottomContainerView.isUserInteractionEnabled = false

        // 开始动画
        startSearchingAnimation()

        // 开始扫描设备（Bonjour + BLE，订阅在 viewDidLoad 已建立）
        candidateDevice = nil
        confirmedDevice = nil
        hideInlineDeviceList()
        discovery.startContinuous()
        
        // 启动超时计时器
        searchTimeout?.invalidate()
        searchTimeout = Timer.scheduledTimer(withTimeInterval: searchTimeoutDuration, repeats: false) { [weak self] _ in
            self?.onSearchTimeout()
        }
    }
    
    /// 停止扫描
    private func stopScanning() {
        isSearching = false
        stopSearchingAnimation()
        searchTimeout?.invalidate()
        searchTimeout = nil
        discovery.stop()
    }
    
    // MARK: - Animation
    
    /// 开始搜索动画（省略号动画）
    private func startSearchingAnimation() {
        // 初始文字
        updateSearchingText()
        
        // 每0.5秒更新一次
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateSearchingText()
        }
    }
    
    /// 停止搜索动画
    private func stopSearchingAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    /// 更新搜索文字（循环显示 1-3 个点）
    private func updateSearchingText() {
        // 如果已经找到设备，显示具体设备名（"Mindora 2026 Found"），不再显示动画
        if hasFoundDevice {
            let name = foundDeviceName ?? "Mindora"
            searchingLabel.text = String(format: L("onboarding.page4.device_found"), name)
            return
        }

        // 如果不在搜索状态，显示未找到
        if !isSearching {
            searchingLabel.text = L("onboarding.page4.no_device_found")
            return
        }

        dotCount = (dotCount % 3) + 1
        let dots = String(repeating: ".", count: dotCount)
        searchingLabel.text = L("onboarding.page4.searching") + dots
    }
    
    /// 搜索超时处理
    private func onSearchTimeout() {
        guard !hasFoundDevice else { return }
        
        isSearching = false
        
        // 停止动画和扫描
        stopSearchingAnimation()
        discovery.stop()
        
        // 更新文案
        searchingLabel.text = L("onboarding.page4.no_device_found")
        
        // 启用连接按钮（文案保持"连接 Mindora"，点击后重新扫描）
        enableConnectButton()
    }
    
    /// 设备被找到时的 UI 更新。`displayName` 是用户可读的设备名（来自 Bonjour `service.name`），
    /// 让用户在按"连接"前看清自己要绑哪一台。
    private func onDeviceFound(displayName: String) {
        guard !hasFoundDevice else { return }
        hasFoundDevice = true
        isSearching = false
        foundDeviceName = displayName

        searchTimeout?.invalidate()
        searchTimeout = nil

        stopSearchingAnimation()
        hideInlineDeviceList()

        // 搜索状态行直接显示具体设备名："Mindora 2026 Found" / "已搜索到 Mindora 2026"
        searchingLabel.text = String(format: L("onboarding.page4.device_found"), displayName)

        enableConnectButton()
        // No auto-navigate. User must explicitly tap "Connect Mindora" to confirm binding.
    }
    
    /// 跳转到 Page5（连接成功页面）
    private func navigateToPage5() {
        let page5 = OnboardingPage5ViewController()
        if let nav = self.navigationController {
            nav.pushViewController(page5, animated: true)
        } else {
            page5.modalPresentationStyle = .fullScreen
            page5.modalTransitionStyle = .crossDissolve
            self.present(page5, animated: true)
        }
    }
        // MARK: - Actions
    
    @objc private func questionIconTapped() {
        self.questionIconView.animateButtonTap { [weak self] in
            // 打开用户手册
            print("Question icon tapped - Open help manual")
            let helpManualVC = HelpManualPagesViewController()
            helpManualVC.modalPresentationStyle = .fullScreen
            helpManualVC.modalTransitionStyle = .crossDissolve
            self?.present(helpManualVC, animated: true)
        }
    }
    
    @objc private func bottomContainerTapped() {
        self.bottomContainerView.animateButtonTap { [weak self] in
            guard let self = self else { return }
            if self.hasFoundDevice, let dev = self.confirmedDevice {
                // Bind happens HERE, only after explicit user confirmation. Pass through
                // whatever transport(s) the discovery layer collected for this device.
                DeviceSession.shared.connect(
                    bonjour: dev.bonjour,
                    bleIdentifier: dev.ble?.identifier,
                    deviceID: dev.deviceID,
                    displayName: dev.displayName
                )
                self.confirmedDevice = nil
                self.navigateToPage5()
            } else if !self.isSearching {
                // Timed out with no device — tapping restarts the scan.
                self.startScanning()
            }
        }
    }
    
    // MARK: - Button State Management
    
    /// 启用连接按钮（找到设备或超时后调用）
    private func enableConnectButton() {
        connectLabel.text = L("onboarding.connect_mindora")
        bottomContainerView.isUserInteractionEnabled = true
        connectLabel.textColor = UIColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1.0)  // 恢复深色
    }
    
    /// 禁用连接按钮
    private func disableConnectButton() {
        bottomContainerView.isUserInteractionEnabled = false
        connectLabel.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)  // 灰色
    }
}

// MARK: - UnifiedDeviceDiscovery notifications
extension OnboardingPage4ViewController {
    @objc fileprivate func discoveryDidUpdate() {
        // 用户已经选定后不再处理后续 discovery 更新
        guard !hasFoundDevice, candidateDevice == nil else { return }

        // 仅看实际可绑定的（至少有一条信道）
        let bindable = discovery.devices.filter { $0.hasWifi || $0.hasBle }
        guard !bindable.isEmpty else { return }

        // 多台设备：在页面内展示列表让用户选
        if bindable.count >= 2 {
            showInlineDeviceList(bindable)
            return
        }

        // 单台设备（常见路径）：自动选并展示 Found 状态
        hideInlineDeviceList()
        let dev = bindable[0]
        Log.info("Onboarding", "device picked name=\(dev.displayName) transport=\(dev.transportLabel)")
        confirmedDevice = dev
        onDeviceFound(displayName: dev.displayName)
    }

    /// 扫到 ≥2 台时把列表显示在 descriptionLabel 和底部按钮之间。
    /// discovery 更新会重复调本方法刷新列表内容，所以重入安全。
    fileprivate func showInlineDeviceList(_ devices: [UnifiedDevice]) {
        bindableDevices = devices
        // 用户已选过一台后不再覆盖 searchingLabel（保留 "Mindora 2026 Found" 状态）
        if confirmedDevice == nil {
            searchingLabel.text = String(format: L("onboarding.page4.multiple_found"), devices.count)
            stopSearchingAnimation()
        }
        deviceListView.isHidden = false
        deviceListView.reloadData()
    }

    fileprivate func hideInlineDeviceList() {
        bindableDevices = []
        deviceListView.isHidden = true
    }

    @objc fileprivate func discoveryDidFail(_ notification: Notification) {
        let code = (notification.object as? Int) ?? -1
        Log.error("Onboarding", "bonjour failed errorCode=\(code)")
        // Suppress late failures once the user has a device staged for confirmation —
        // a delayed -72000 from an earlier permission denial shouldn't pop an alert
        // over a green "Found Mindora" state.
        guard !hasFoundDevice else { return }
        showLocalNetworkPermissionAlert()
    }

    @objc fileprivate func bleDidFail(_ notification: Notification) {
        let stateRaw = (notification.object as? Int) ?? -1
        Log.error("Onboarding", "ble failed centralState=\(stateRaw)")
        guard !hasFoundDevice else { return }
        // BLE unauthorized = user explicitly denied; nudge to Settings. Other states
        // (poweredOff / unsupported / resetting) silently fall through — Bonjour may still find the device.
        if stateRaw == 3 { // CBManagerState.unauthorized
            showBluetoothPermissionAlert()
        }
    }

    fileprivate func showLocalNetworkPermissionAlert() {
        let customAlert = CustomAlertViewController(
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
        self.present(customAlert, animated: true)
    }

    fileprivate func showBluetoothPermissionAlert() {
        let customAlert = CustomAlertViewController(
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
        self.present(customAlert, animated: true)
    }
}

// MARK: - Inline device list（多设备时显示在页面中部）
extension OnboardingPage4ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        bindableDevices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: InlineDeviceCell.identifier, for: indexPath) as! InlineDeviceCell
        cell.configure(with: bindableDevices[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < bindableDevices.count else { return }
        let dev = bindableDevices[indexPath.row]
        Log.info("Onboarding", "user picked \(dev.displayName) from inline list")
        confirmedDevice = dev
        onDeviceFound(displayName: dev.displayName)
    }
}

/// 内嵌设备选择列表的单元格：白色名字 + 灰色 transport 副标，深色背景透出。
private final class InlineDeviceCell: UITableViewCell {
    static let identifier = "InlineDeviceCell"

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let transportLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(white: 1.0, alpha: 0.55)
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let chevron: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.right"))
        iv.tintColor = UIColor(white: 1.0, alpha: 0.4)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        // 选中高亮：浅白透明
        let bg = UIView()
        bg.backgroundColor = UIColor(white: 1.0, alpha: 0.08)
        selectedBackgroundView = bg

        contentView.addSubview(nameLabel)
        contentView.addSubview(transportLabel)
        contentView.addSubview(chevron)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),

            transportLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            transportLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            transportLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),

            chevron.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with device: UnifiedDevice) {
        nameLabel.text = device.displayName
        transportLabel.text = device.transportLabel
    }
}


