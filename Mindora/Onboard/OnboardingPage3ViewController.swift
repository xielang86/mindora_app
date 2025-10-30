//
//  OnboardingPage3ViewController.swift
//  mindora
//
//  Created by gao chao on 2025/10/20.
//
//  开机引导页3控制器 - 严格按照设计图实现
//  设计稿尺寸: 1242 × 2688 px (@3x, iPhone X/XS Max)
//  换算方式: 使用百分比适配不同屏幕
//  与引导页2相比，增加了两个独立的提示卡片（健康数据 + 蓝牙）
//

import UIKit
import HealthKit
import CoreBluetooth

final class OnboardingPage3ViewController: UIViewController {
    
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 设计稿中的像素值 - 底部按钮容器（与引导页2完全相同）
    private let designButtonWidth: CGFloat = 1129          // 按钮宽度
    private let designButtonHeight: CGFloat = 187          // 按钮高度
    private let designButtonCornerRadius: CGFloat = 88     // 按钮圆角（完整的圆角矩形）
    private let designButtonBottomMargin: CGFloat = 160    // 按钮距离底部
    
    // 设计稿中的像素值 - 问号图标
    private let designQuestionIconSize: CGFloat = 90       // 问号图标尺寸
    private let designQuestionIconLeading: CGFloat = 108   // 问号图标距离按钮左边
    
    // 设计稿中的像素值 - 按钮文字
    private let designButtonTextFontSize: CGFloat = DesignConstants.subtitleFontSize  // "连接 Mindora" 字体大小
    private let designButtonTextTrailing: CGFloat = 108    // 文字距离按钮右边
    
    // 设计稿中的像素值 - 中间提示卡片（两个独立的卡片）
    private let designCardWidth: CGFloat = 1100            // 卡片宽度
    private let designCardHeight: CGFloat = 250            // 卡片高度
    private let designCardCornerRadius: CGFloat = 20       // 卡片圆角
    private let designCardSpacing: CGFloat = 50            // 两个卡片之间的间距
    private let designHealthCardTop: CGFloat = 1735        // 健康数据卡片距离页面顶部的距离
    
    // 设计稿中的像素值 - 卡片内图标
    private let designCardIconWidth: CGFloat = 59          // 左侧图标宽度（健康/蓝牙图标）
    private let designCardIconHeight: CGFloat = 55         // 左侧图标高度
    private let designCardIconLeading: CGFloat = 67        // 左侧图标距离卡片左边
    
    // 设计稿中的像素值 - 卡片内箭头
    private let designArrowIconWidth: CGFloat = 18         // 右侧箭头宽度
    private let designArrowIconHeight: CGFloat = 36        // 右侧箭头高度
    private let designArrowIconTrailing: CGFloat = 36      // 右侧箭头距离卡片右边
    
    // 设计稿中的像素值 - 卡片内文字
    private let designCardTextFontSize: CGFloat = DesignConstants.bodyFontSize  // 卡片内文字大小
    private let designCardTextLineSpacing: CGFloat = 10    // 行间距
    private let designCardTextLeading: CGFloat = 190       // 文字距离卡片左边（图标右侧）
    private let designCardTextTrailing: CGFloat = 80       // 文字距离箭头的间距
    
    // 计算实际尺寸的辅助方法
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    // MARK: - UI Components
    
    // 全屏背景图（与引导页2相同）
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-p2")
        imageView.contentMode = .scaleAspectFill  // 全屏填充
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // 第一个卡片容器 - 健康数据
    private let healthCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear  // 透明背景
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 健康数据卡片 - 左侧图标
    private let healthIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-health")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // 健康数据卡片 - 文字
    private let healthTextLabel: UILabel = {
        let label = UILabel()
        label.text = L("onboarding.page3.health_card_text")
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 健康数据卡片 - 右侧箭头
    private let healthArrowView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-right-angle-bracket")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // 第二个卡片容器 - 蓝牙
    private let bluetoothCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear  // 透明背景
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 蓝牙卡片 - 左侧图标
    private let bluetoothIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-bluetooth")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // 蓝牙卡片 - 文字
    private let bluetoothTextLabel: UILabel = {
        let label = UILabel()
        label.text = L("onboarding.page3.bluetooth_card_text")
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 蓝牙卡片 - 右侧箭头
    private let bluetoothArrowView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-right-angle-bracket")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // 底部白色按钮容器（与引导页2完全相同）
    private let bottomContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 左侧问号图标（在白色容器内）
    private let questionIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-manual")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // "连接 Mindora" 文字标签
    private let connectLabel: UILabel = {
        let label = UILabel()
        label.text = L("onboarding.connect_mindora")
        label.textColor = UIColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1.0)  // 深色文字
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // 动态切换布局所需的约束引用
    private var _bluetoothTopToViewConstraint: NSLayoutConstraint?
    private var _healthTopToBluetoothBottomConstraint: NSLayoutConstraint?
    private var _healthTopToViewConstraint: NSLayoutConstraint?
    private var _healthTopToViewLowerConstraint: NSLayoutConstraint?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        // 监听应用回到前台，返回设置或健康App后自动刷新卡片显示与布局
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // 主动触发健康和蓝牙权限申请，确保用户在相应设置中能看到Mindora的权限设置
        requestHealthPermissionIfNeeded()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 确保卡片在视图出现时可见
        healthCardView.alpha = 1.0
        bluetoothCardView.alpha = 1.0
        updateCardVisibilityAndLayout()
        print("Page3 viewWillAppear - Cards should be visible")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("Page3 viewDidAppear")
        print("Health card frame: \(healthCardView.frame)")
        print("Bluetooth card frame: \(bluetoothCardView.frame)")
        print("View bounds: \(view.bounds)")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 添加所有子视图(按照层级顺序)
        view.addSubview(backgroundImageView)
        
        // 健康数据卡片
        view.addSubview(healthCardView)
        healthCardView.addSubview(healthIconView)
        healthCardView.addSubview(healthTextLabel)
        healthCardView.addSubview(healthArrowView)
        
        // 蓝牙卡片
        view.addSubview(bluetoothCardView)
        bluetoothCardView.addSubview(bluetoothIconView)
        bluetoothCardView.addSubview(bluetoothTextLabel)
        bluetoothCardView.addSubview(bluetoothArrowView)
        
        // 底部按钮
        view.addSubview(bottomContainerView)
        bottomContainerView.addSubview(questionIconView)
        bottomContainerView.addSubview(connectLabel)
        
        setupStyles()
        setupConstraints()
    }
    
    private func setupStyles() {
        // 按钮文字字体 - 按设计稿比例计算
        let buttonTextFontSize = scale(designButtonTextFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        connectLabel.font = UIFont.systemFont(ofSize: buttonTextFontSize, weight: .medium)
        
        // 卡片文字字体和行间距 - 按设计稿比例计算
        let cardTextFontSize = scale(designCardTextFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        let lineSpacing = scale(designCardTextLineSpacing, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 设置健康数据文字样式
        let healthParagraphStyle = NSMutableParagraphStyle()
        healthParagraphStyle.lineSpacing = lineSpacing
        healthParagraphStyle.alignment = .left
        let healthAttributedString = NSMutableAttributedString(string: healthTextLabel.text ?? "")
        healthAttributedString.addAttribute(.paragraphStyle, value: healthParagraphStyle, range: NSRange(location: 0, length: healthAttributedString.length))
        healthAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: cardTextFontSize, weight: .regular), range: NSRange(location: 0, length: healthAttributedString.length))
        healthTextLabel.attributedText = healthAttributedString
        
        // 设置蓝牙文字样式
        let bluetoothParagraphStyle = NSMutableParagraphStyle()
        bluetoothParagraphStyle.lineSpacing = lineSpacing
        bluetoothParagraphStyle.alignment = .left
        let bluetoothAttributedString = NSMutableAttributedString(string: bluetoothTextLabel.text ?? "")
        bluetoothAttributedString.addAttribute(.paragraphStyle, value: bluetoothParagraphStyle, range: NSRange(location: 0, length: bluetoothAttributedString.length))
        bluetoothAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: cardTextFontSize, weight: .regular), range: NSRange(location: 0, length: bluetoothAttributedString.length))
        bluetoothTextLabel.attributedText = bluetoothAttributedString
        
        // 按钮容器圆角 - 按设计稿比例计算
        let buttonCornerRadius = scale(designButtonCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        bottomContainerView.layer.cornerRadius = buttonCornerRadius
        
        // 卡片容器边框和圆角 - 按设计稿比例计算
        let cardCornerRadius = scale(designCardCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 健康数据卡片 - 白色边框，透明背景
        healthCardView.layer.cornerRadius = cardCornerRadius
        healthCardView.layer.borderWidth = 0.5
        healthCardView.layer.borderColor = UIColor.white.cgColor
        
        // 蓝牙卡片 - 白色边框，透明背景
        bluetoothCardView.layer.cornerRadius = cardCornerRadius
        bluetoothCardView.layer.borderWidth = 0.5
        bluetoothCardView.layer.borderColor = UIColor.white.cgColor
    }
    
    private func setupConstraints() {
        // 按钮尺寸 - 按设计稿比例计算
        let buttonWidth = scale(designButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonHeight = scale(designButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let buttonBottomMargin = scale(designButtonBottomMargin, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 问号图标尺寸和位置 - 按设计稿比例计算
        let questionIconSize = scale(designQuestionIconSize, basedOn: view.bounds.width, designDimension: designWidth)
        let questionIconLeading = scale(designQuestionIconLeading, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 按钮文字位置 - 按设计稿比例计算
        let buttonTextTrailing = scale(designButtonTextTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 卡片尺寸和位置 - 按设计稿比例计算
        let cardWidth = scale(designCardWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let cardHeight = scale(designCardHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let cardSpacing = scale(designCardSpacing, basedOn: view.bounds.height, designDimension: designHeight)
        let healthCardTop = scale(designHealthCardTop, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 卡片内图标尺寸和位置 - 按设计稿比例计算
        let cardIconWidth = scale(designCardIconWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let cardIconHeight = scale(designCardIconHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let cardIconLeading = scale(designCardIconLeading, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 卡片内箭头尺寸和位置 - 按设计稿比例计算
        let arrowIconWidth = scale(designArrowIconWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let arrowIconHeight = scale(designArrowIconHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let arrowIconTrailing = scale(designArrowIconTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 卡片内文字位置 - 按设计稿比例计算
        let cardTextLeading = scale(designCardTextLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let cardTextTrailing = scale(designCardTextTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 缓存用于动态切换的关键约束
        // 布局策略：蓝牙卡片始终显示在上方，健康卡片在下方，根据权限状态更新卡片文案

    // 顶部定位相关约束
    let bluetoothTopToViewConstraint = bluetoothCardView.topAnchor.constraint(equalTo: view.topAnchor, constant: healthCardTop)
    let healthTopToBluetoothBottomConstraint = healthCardView.topAnchor.constraint(equalTo: bluetoothCardView.bottomAnchor, constant: cardSpacing)
    // 健康卡片贴顶（备用约束，当前不使用）
    let healthTopToViewConstraint = healthCardView.topAnchor.constraint(equalTo: view.topAnchor, constant: healthCardTop)
    // 健康卡片"下方"位置：等同于蓝牙卡片高度 + 间距后的位置（备用约束，当前不使用）
    let healthLowerTopConstant = healthCardTop + cardHeight + cardSpacing
    let healthTopToViewLowerConstraint = healthCardView.topAnchor.constraint(equalTo: view.topAnchor, constant: healthLowerTopConstant)

        NSLayoutConstraint.activate([
            // 背景图片 - 完全填充整个屏幕（包括安全区域外）
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 默认布局：蓝牙卡片在上，健康卡片在下
            bluetoothTopToViewConstraint,
            
            // 健康数据卡片在蓝牙卡片下方
            healthTopToBluetoothBottomConstraint,
            healthCardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            healthCardView.widthAnchor.constraint(equalToConstant: cardWidth),
            healthCardView.heightAnchor.constraint(equalToConstant: cardHeight),
            
            // 健康数据卡片 - 左侧图标
            healthIconView.leadingAnchor.constraint(equalTo: healthCardView.leadingAnchor, constant: cardIconLeading),
            healthIconView.centerYAnchor.constraint(equalTo: healthCardView.centerYAnchor),
            healthIconView.widthAnchor.constraint(equalToConstant: cardIconWidth),
            healthIconView.heightAnchor.constraint(equalToConstant: cardIconHeight),
            
            // 健康数据卡片 - 右侧箭头
            healthArrowView.trailingAnchor.constraint(equalTo: healthCardView.trailingAnchor, constant: -arrowIconTrailing),
            healthArrowView.centerYAnchor.constraint(equalTo: healthCardView.centerYAnchor),
            healthArrowView.widthAnchor.constraint(equalToConstant: arrowIconWidth),
            healthArrowView.heightAnchor.constraint(equalToConstant: arrowIconHeight),
            
            // 健康数据卡片 - 文字
            healthTextLabel.leadingAnchor.constraint(equalTo: healthCardView.leadingAnchor, constant: cardTextLeading),
            healthTextLabel.trailingAnchor.constraint(equalTo: healthArrowView.leadingAnchor, constant: -cardTextTrailing),
            healthTextLabel.centerYAnchor.constraint(equalTo: healthCardView.centerYAnchor),
            
            // 蓝牙卡片 - 顶部卡片（默认）
            bluetoothCardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bluetoothCardView.widthAnchor.constraint(equalToConstant: cardWidth),
            bluetoothCardView.heightAnchor.constraint(equalToConstant: cardHeight),
            
            // 蓝牙卡片 - 左侧图标
            bluetoothIconView.leadingAnchor.constraint(equalTo: bluetoothCardView.leadingAnchor, constant: cardIconLeading),
            bluetoothIconView.centerYAnchor.constraint(equalTo: bluetoothCardView.centerYAnchor),
            bluetoothIconView.widthAnchor.constraint(equalToConstant: cardIconWidth),
            bluetoothIconView.heightAnchor.constraint(equalToConstant: cardIconHeight),
            
            // 蓝牙卡片 - 右侧箭头
            bluetoothArrowView.trailingAnchor.constraint(equalTo: bluetoothCardView.trailingAnchor, constant: -arrowIconTrailing),
            bluetoothArrowView.centerYAnchor.constraint(equalTo: bluetoothCardView.centerYAnchor),
            bluetoothArrowView.widthAnchor.constraint(equalToConstant: arrowIconWidth),
            bluetoothArrowView.heightAnchor.constraint(equalToConstant: arrowIconHeight),
            
            // 蓝牙卡片 - 文字
            bluetoothTextLabel.leadingAnchor.constraint(equalTo: bluetoothCardView.leadingAnchor, constant: cardTextLeading),
            bluetoothTextLabel.trailingAnchor.constraint(equalTo: bluetoothArrowView.leadingAnchor, constant: -cardTextTrailing),
            bluetoothTextLabel.centerYAnchor.constraint(equalTo: bluetoothCardView.centerYAnchor),
            
            // 底部白色按钮容器 - 居中显示
            bottomContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomContainerView.widthAnchor.constraint(equalToConstant: buttonWidth),
            bottomContainerView.heightAnchor.constraint(equalToConstant: buttonHeight),
            bottomContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -buttonBottomMargin),
            
            // 问号图标 - 在按钮内左侧，垂直居中
            questionIconView.leadingAnchor.constraint(equalTo: bottomContainerView.leadingAnchor, constant: questionIconLeading),
            questionIconView.centerYAnchor.constraint(equalTo: bottomContainerView.centerYAnchor),
            questionIconView.widthAnchor.constraint(equalToConstant: questionIconSize),
            questionIconView.heightAnchor.constraint(equalToConstant: questionIconSize),
            
            // "连接 Mindora" 文字 - 在按钮内右侧，垂直居中
            connectLabel.trailingAnchor.constraint(equalTo: bottomContainerView.trailingAnchor, constant: -buttonTextTrailing),
            connectLabel.centerYAnchor.constraint(equalTo: bottomContainerView.centerYAnchor)
        ])

        // 将可切换的约束存储到属性，供运行时修改
        self._bluetoothTopToViewConstraint = bluetoothTopToViewConstraint
        self._healthTopToBluetoothBottomConstraint = healthTopToBluetoothBottomConstraint
    self._healthTopToViewConstraint = healthTopToViewConstraint
    self._healthTopToViewLowerConstraint = healthTopToViewLowerConstraint
    }
    
    private func setupActions() {
        // 添加点击手势到健康数据卡片
        let healthTapGesture = UITapGestureRecognizer(target: self, action: #selector(healthCardTapped))
        healthCardView.addGestureRecognizer(healthTapGesture)
        healthCardView.isUserInteractionEnabled = true
        
        // 添加点击手势到蓝牙卡片
        let bluetoothTapGesture = UITapGestureRecognizer(target: self, action: #selector(bluetoothCardTapped))
        bluetoothCardView.addGestureRecognizer(bluetoothTapGesture)
        bluetoothCardView.isUserInteractionEnabled = true
        
        // 为问号图标单独添加点击手势
        let questionTapGesture = UITapGestureRecognizer(target: self, action: #selector(questionIconTapped))
        questionIconView.addGestureRecognizer(questionTapGesture)
        questionIconView.isUserInteractionEnabled = true
        
        // 为底部容器添加点击手势（点击连接区域）
        let connectTapGesture = UITapGestureRecognizer(target: self, action: #selector(connectAreaTapped))
        bottomContainerView.addGestureRecognizer(connectTapGesture)
        bottomContainerView.isUserInteractionEnabled = true
    }
    
    // MARK: - Actions
    
    @objc private func healthCardTapped() {
        print("Health card tapped - Open health settings")
        // 跳转到健康 App
        PermissionManager.shared.openHealthApp { success in
            if !success {
                print("Failed to open Health app, opening app settings instead")
            }
        }
    }
    
    @objc private func bluetoothCardTapped() {
        let btAuth = BluetoothManager.shared.checkBluetoothAuthorization()
        let isBluetoothAuthorized = (btAuth == .allowedAlways)
        
        if isBluetoothAuthorized {
            print("Bluetooth card tapped - Permission already granted, navigate to settings")
            // 蓝牙权限已开启，直接跳转到设置页面
            openAppSettings()
        } else {
            print("Bluetooth card tapped - Request bluetooth permission")
            // 先请求蓝牙权限（这会触发系统权限弹窗）
            BluetoothManager.shared.requestBluetoothAuthorization { [weak self] authorization in
                print("Bluetooth authorization status: \(authorization.rawValue)")
                
                DispatchQueue.main.async {
                    // 刷新卡片文案
                    self?.updateCardVisibilityAndLayout()
                    
                    // 延迟一下再跳转到设置，让用户有时间看到权限弹窗或处理结果
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // 跳转到应用的设置页面
                        self?.openAppSettings()
                    }
                }
            }
        }
    }
    
    @objc private func questionIconTapped() {
        // 打开用户手册
        print("Question icon tapped - Open help manual")
        let helpManualVC = HelpManualPagesViewController()
        helpManualVC.modalPresentationStyle = .fullScreen
        helpManualVC.modalTransitionStyle = .crossDissolve
        present(helpManualVC, animated: true)
    }
    
    @objc private func connectAreaTapped() {
        // 跳转到引导页4（扫描设备页面）
        print("Connect Mindora tapped - Navigate to Page 4")
        
        let page4VC = OnboardingPage4ViewController()
        
        // 如果当前在导航控制器中，使用 push
        if let navigationController = self.navigationController {
            navigationController.pushViewController(page4VC, animated: true)
        } else {
            // 否则使用模态展示
            page4VC.modalPresentationStyle = .fullScreen
            page4VC.modalTransitionStyle = .crossDissolve
            present(page4VC, animated: true)
        }
    }
    
    // MARK: - Private Helpers
    
    /// 主动请求健康和蓝牙权限，确保用户在系统设置中能看到Mindora的权限设置
    private func requestHealthPermissionIfNeeded() {
        // 检查健康权限状态
        Task {
            // 首先检查 HealthKit 是否可用
            guard HKHealthStore.isHealthDataAvailable() else {
                print("[OnboardingPage3] HealthKit 不可用，跳过健康权限申请")
                // 即使 HealthKit 不可用，仍然申请蓝牙权限
                requestBluetoothPermissionIfNeeded()
                return
            }
            
            let healthStatus = await PermissionManager.shared.getHealthPermissionStatus()
            
            // 如果是 notDetermined（从未请求过），则主动触发权限申请
            if healthStatus == .notDetermined {
                print("[OnboardingPage3] 检测到健康权限从未申请过，主动触发权限申请")
                do {
                    try await HealthDataManager.shared.requestAuthorization()
                    print("[OnboardingPage3] 健康权限申请完成，用户现在可以在健康App中看到Mindora设置")
                } catch {
                    print("[OnboardingPage3] 健康权限申请失败: \(error.localizedDescription)")
                }
            } else {
                print("[OnboardingPage3] 健康权限状态: \(healthStatus.localizedDescription)")
            }
            
            // 申请蓝牙权限
            await MainActor.run {
                requestBluetoothPermissionIfNeeded()
            }
        }
    }
    
    /// 主动请求蓝牙权限，确保用户在系统设置中能看到Mindora的蓝牙权限设置
    private func requestBluetoothPermissionIfNeeded() {
        let bluetoothStatus = BluetoothManager.shared.checkBluetoothAuthorization()
        
        // 如果是 notDetermined（从未请求过），则主动触发权限申请
        if bluetoothStatus == .notDetermined {
            print("[OnboardingPage3] 检测到蓝牙权限从未申请过，主动触发权限申请")
            BluetoothManager.shared.requestBluetoothAuthorization { [weak self] authorization in
                print("[OnboardingPage3] 蓝牙权限申请完成，状态: \(authorization.rawValue)")
                print("[OnboardingPage3] 用户现在可以在系统设置中看到Mindora的蓝牙权限设置")
                
                // 权限申请完成后，刷新卡片文案
                DispatchQueue.main.async {
                    self?.updateCardVisibilityAndLayout()
                }
            }
        } else {
            print("[OnboardingPage3] 蓝牙权限状态: \(bluetoothStatus.rawValue)")
        }
    }
    
    /// 打开应用设置页面
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url) { success in
                    if success {
                        print("Successfully opened app settings")
                    } else {
                        print("Failed to open app settings")
                    }
                }
            }
        }
    }
}

// MARK: - Dynamic Layout Helpers
private extension OnboardingPage3ViewController {
    @objc func appWillEnterForeground() {
        // 应用从后台返回前台后，可能在系统设置或健康App中修改了权限；此处刷新布局
        updateCardVisibilityAndLayout()
    }

    func updateCardVisibilityAndLayout() {
        let btAuth = BluetoothManager.shared.checkBluetoothAuthorization()
        let isBluetoothAuthorized = (btAuth == .allowedAlways)

        // 始终显示蓝牙卡片，但根据权限状态更新文案
        bluetoothCardView.isHidden = false
        updateBluetoothCardText(isAuthorized: isBluetoothAuthorized)
        
        // 布局约束保持不变：蓝牙卡片在上，健康卡片在下
        _healthTopToViewConstraint?.isActive = false
        _healthTopToViewLowerConstraint?.isActive = false
        _bluetoothTopToViewConstraint?.isActive = true
        _healthTopToBluetoothBottomConstraint?.isActive = true

        view.layoutIfNeeded()
    }
    
    /// 根据蓝牙权限状态更新卡片文案
    private func updateBluetoothCardText(isAuthorized: Bool) {
        let cardTextFontSize = scale(designCardTextFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        let lineSpacing = scale(designCardTextLineSpacing, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 根据权限状态选择对应的文案
        let textKey = isAuthorized ? "onboarding.page3.bluetooth_card_text_authorized" : "onboarding.page3.bluetooth_card_text"
        let newText = L(textKey)
        
        // 设置新的文案样式
        let bluetoothParagraphStyle = NSMutableParagraphStyle()
        bluetoothParagraphStyle.lineSpacing = lineSpacing
        bluetoothParagraphStyle.alignment = .left
        let bluetoothAttributedString = NSMutableAttributedString(string: newText)
        bluetoothAttributedString.addAttribute(.paragraphStyle, value: bluetoothParagraphStyle, range: NSRange(location: 0, length: bluetoothAttributedString.length))
        bluetoothAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: cardTextFontSize, weight: .regular), range: NSRange(location: 0, length: bluetoothAttributedString.length))
        bluetoothTextLabel.attributedText = bluetoothAttributedString
    }
}
