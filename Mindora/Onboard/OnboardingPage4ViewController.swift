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
    private let discovery = BonjourDiscovery.shared
    private var hasFoundDevice = false
    private var searchTimeout: Timer?
    private var isSearching = false
    private let searchTimeoutDuration: TimeInterval = 6.0
    
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
    private let designMindoraTextBottom: CGFloat = 609     // Mindora 文字距离底部
    private let designMindoraTextFontSize: CGFloat = 57    // Mindora 字体大小
    
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
        return designValue * (dimension / designDimension)
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
    
    // Mindora 文字（底部按钮上方）
    private let mindoraTextLabel: UILabel = {
        let label = UILabel()
        label.text = "Mindora"
        label.textColor = UIColor(white: 1.0, alpha: 0.4)  // 白色，40%不透明度
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
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
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    deinit {
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
        view.addSubview(mindoraTextLabel)
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
        
        // Mindora 文字字体
        let mindoraTextFontSize = scale(designMindoraTextFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        mindoraTextLabel.font = UIFont.systemFont(ofSize: mindoraTextFontSize, weight: .medium)
        
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
        
        let mindoraTextBottom = scale(designMindoraTextBottom, basedOn: view.bounds.height, designDimension: designHeight)
        
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
            
            // Mindora 文字 - 居中，距离底部609px
            mindoraTextLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mindoraTextLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -mindoraTextBottom),
            
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
        mindoraTextLabel.textColor = UIColor(white: 1.0, alpha: 0.4)
        
        // 开始动画
        startSearchingAnimation()
        
        // 设置 Bonjour 发现代理
        discovery.delegate = self
        
        // 开始扫描设备
        discovery.startContinuous(rescanInterval: 6.0)
        
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
        discovery.stopContinuous()
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
        // 如果已经找到设备，显示静态文案，不再显示动画
        if hasFoundDevice {
            searchingLabel.text = L("onboarding.page4.device_found")
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
        discovery.stopContinuous()
        
        // 更新文案
        searchingLabel.text = L("onboarding.page4.no_device_found")
        
        // 启用连接按钮（文案保持"连接 Mindora"，点击后重新扫描）
        enableConnectButton()
    }
    
    /// 设备被找到时的 UI 更新
    private func onDeviceFound() {
        guard !hasFoundDevice else { return }
        hasFoundDevice = true
        isSearching = false
        
        // 取消超时计时器
        searchTimeout?.invalidate()
        searchTimeout = nil
        
        // 停止动画
        stopSearchingAnimation()
        
        // 更新文案为"已搜索到 Mindora"
        searchingLabel.text = L("onboarding.page4.device_found")
        
        // Mindora 文字去掉不透明度
        mindoraTextLabel.textColor = .white
        
        // 启用连接按钮
        enableConnectButton()
        
        // 3秒后自动跳转到 Page5
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.navigateToPage5()
        }
    }
    
    /// 跳转到 Page5（连接成功页面）
    private func navigateToPage5() {
        let page5 = OnboardingPage5ViewController()
        page5.modalPresentationStyle = .fullScreen
        page5.modalTransitionStyle = .crossDissolve
        self.present(page5, animated: true)
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
            // 如果已找到设备，跳转到 Page5
            if self.hasFoundDevice {
                self.navigateToPage5()
            }
            // 如果未找到设备且不在搜索中（超时状态），重新开始扫描
            else if !self.isSearching {
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

// MARK: - BonjourDiscoveryDelegate
extension OnboardingPage4ViewController: BonjourDiscoveryDelegate {
    func discoveryDidUpdate(_ discovery: BonjourDiscovery) {
        // 当扫描到设备时更新 UI
        if let service = discovery.services.first, !hasFoundDevice {
            // 自动连接第一个发现的设备
            let host = service.hostName ?? service.name
            
            // 保存连接会话
            DeviceSession.shared.host = host
            DeviceSession.shared.port = 9102
            print("[OnboardingPage4] Device found and saved: \(host)")
            
            DispatchQueue.main.async { [weak self] in
                self?.onDeviceFound()
            }
        }
    }
    
    func discoveryDidFail(_ discovery: BonjourDiscovery, errorCode: Int) {
        Log.error("Onboarding", "discovery failed errorCode=\(errorCode)")
        // 本地网络权限被拒绝或其他搜索错误，引导用户去设置
        DispatchQueue.main.async { [weak self] in
            self?.showLocalNetworkPermissionAlert()
        }
    }
    
    private func showLocalNetworkPermissionAlert() {
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
}
