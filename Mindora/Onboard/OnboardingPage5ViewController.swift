//
//  OnboardingPage5ViewController.swift
//  mindora
//
//  Created by gao chao on 2025/10/20.
//
//  开机引导页5控制器 - 连接成功页面
//  设计稿尺寸: 1242 × 2688 px (@3x, iPhone X/XS Max)
//  换算方式: 使用百分比适配不同屏幕
//  特点：boot-p2 背景图 + 顶部"Mindora连接成功"文字 + 对号图标 + "完成"按钮 + 底部自定义 Tab Bar
//

import UIKit

final class OnboardingPage5ViewController: UIViewController {
    
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 设计稿中的像素值 - 顶部标题
    private let designTitleTop: CGFloat = DesignConstants.titleTopMargin  // 标题距离顶部
    private let designTitleFontSize: CGFloat = DesignConstants.titleFontSize  // 字体大小
    private let designTextLeading: CGFloat = 116           // 文字距离屏幕左边的边距
    
    // 设计稿中的像素值 - 对号图标
    private let designCheckmarkTop: CGFloat = 1693         // 对号图标距离顶部
    private let designCheckmarkWidth: CGFloat = 133        // 对号图标宽度
    private let designCheckmarkHeight: CGFloat = 100       // 对号图标高度
    
    // 设计稿中的像素值 - 完成按钮
    private let designCompleteButtonTop: CGFloat = 2119    // 完成按钮距离顶部
    private let designCompleteButtonWidth: CGFloat = 1089  // 完成按钮宽度
    private let designCompleteButtonHeight: CGFloat = 164  // 完成按钮高度
    private let designCompleteButtonCornerRadius: CGFloat = 82  // 完成按钮圆角
    
    // 设计稿中的像素值 - Tab Bar（参考 MainTabBarController）
    private let designTabBarHeight: CGFloat = 176
    private let designTabBarFontSize: CGFloat = DesignConstants.subtitleFontSize
    private let designTabBarCornerRadius: CGFloat = 88
    private let designTabBarBottom: CGFloat = 60
    private let designTabBarWidth: CGFloat = 1129
    private let designTabBarHorizontalPadding: CGFloat = 30
    
    // 颜色
    private let selectedColor = UIColor(red: 10/255, green: 137/255, blue: 0/255, alpha: 1.0)  // Tab 选中颜色
    private let normalColor = UIColor.white  // Tab 未选中颜色
    private let tabBarBackgroundColor = UIColor(red: 21/255, green: 21/255, blue: 21/255, alpha: 1.0)  // Tab Bar 背景色
    
    // 计算实际尺寸的辅助方法
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    // MARK: - UI Components
    
    // 全屏背景图（boot-p2）
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-p2")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // "Mindora连接成功" 标题
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L("onboarding.page5.success_title")
        label.textColor = .white
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 对号图标
    private let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "large_checkmark")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // "完成"按钮容器
    private let completeButtonView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear  // 透明背景
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // "完成"文字标签
    private let completeLabel: UILabel = {
        let label = UILabel()
        label.text = L("onboarding.page5.complete")
        label.textColor = .white  // 白色字体
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 自定义 Tab Bar 容器
    private let customTabBarContainer = UIView()
    private var tabButtons: [UIButton] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 添加所有子视图
        view.addSubview(backgroundImageView)
        view.addSubview(titleLabel)
        view.addSubview(checkmarkImageView)
        view.addSubview(completeButtonView)
        completeButtonView.addSubview(completeLabel)
        
        setupStyles()
        setupConstraints()
        setupCustomTabBar()
    }
    
    private func setupStyles() {
        // 标题字体 - Medium 字重（与 Page4 titleLabel 一致）
        let titleFontSize = scale(designTitleFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = UIFont.systemFont(ofSize: titleFontSize, weight: .medium)
        
        // 完成按钮文字字体（与 Tab 字体一致）
        let completeFontSize = scale(designTabBarFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        completeLabel.font = UIFont.systemFont(ofSize: completeFontSize, weight: .medium)
        
        // 完成按钮圆角和白色描边
        let completeCornerRadius = scale(designCompleteButtonCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        completeButtonView.layer.cornerRadius = completeCornerRadius
        completeButtonView.layer.borderWidth = 0.5  // 描边宽度 0.5
        completeButtonView.layer.borderColor = UIColor.white.cgColor  // 白色描边
    }
    
    private func setupConstraints() {
        // 计算实际尺寸
        let titleTop = scale(designTitleTop, basedOn: view.bounds.height, designDimension: designHeight)
        let textLeading: CGFloat = 116 // 使用与 Page4 相同的左边距
        let scaledTextLeading = scale(textLeading, basedOn: view.bounds.width, designDimension: designWidth)
        
        let checkmarkTop = scale(designCheckmarkTop, basedOn: view.bounds.height, designDimension: designHeight)
        let checkmarkWidth = scale(designCheckmarkWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let checkmarkHeight = scale(designCheckmarkHeight, basedOn: view.bounds.height, designDimension: designHeight)
        
        let completeButtonTop = scale(designCompleteButtonTop, basedOn: view.bounds.height, designDimension: designHeight)
        let completeButtonWidth = scale(designCompleteButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let completeButtonHeight = scale(designCompleteButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        
        NSLayoutConstraint.activate([
            // 背景图片 - 完全填充整个屏幕
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 标题 - "Mindora连接成功"
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: titleTop),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: scaledTextLeading),
            
            // 对号图标
            checkmarkImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: checkmarkTop),
            checkmarkImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: checkmarkWidth),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: checkmarkHeight),
            
            // 完成按钮
            completeButtonView.topAnchor.constraint(equalTo: view.topAnchor, constant: completeButtonTop),
            completeButtonView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            completeButtonView.widthAnchor.constraint(equalToConstant: completeButtonWidth),
            completeButtonView.heightAnchor.constraint(equalToConstant: completeButtonHeight),
            
            // 完成文字
            completeLabel.centerXAnchor.constraint(equalTo: completeButtonView.centerXAnchor),
            completeLabel.centerYAnchor.constraint(equalTo: completeButtonView.centerYAnchor)
        ])
    }
    
    private func setupActions() {
        // 添加完成按钮点击手势
        let completeTapGesture = UITapGestureRecognizer(target: self, action: #selector(completeButtonTapped))
        completeButtonView.addGestureRecognizer(completeTapGesture)
        completeButtonView.isUserInteractionEnabled = true
    }
    
    // MARK: - Setup Custom Tab Bar
    
    /// 创建自定义 Tab Bar（与 MainTabBarController 一致）
    private func setupCustomTabBar() {
        // 配置容器样式
        customTabBarContainer.backgroundColor = tabBarBackgroundColor
        customTabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customTabBarContainer)
        
        // 计算实际尺寸
        let tabBarHeight = scale(designTabBarHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let tabBarWidth = scale(designTabBarWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let cornerRadius = scale(designTabBarCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        let bottomMargin = scale(designTabBarBottom, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 设置圆角
        customTabBarContainer.layer.cornerRadius = cornerRadius
        customTabBarContainer.clipsToBounds = true
        
        // 布局约束
        NSLayoutConstraint.activate([
            customTabBarContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            customTabBarContainer.widthAnchor.constraint(equalToConstant: tabBarWidth),
            customTabBarContainer.heightAnchor.constraint(equalToConstant: tabBarHeight),
            customTabBarContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -bottomMargin)
        ])
        
        // 创建三个 Tab 按钮
        let titles = [L("tab.home"), L("tab.health"), L("tab.settings")]
        let fontSize = scale(designTabBarFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        
        for (index, title) in titles.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false
            customTabBarContainer.addSubview(button)
            tabButtons.append(button)
        }
        
        // 计算水平边距
        let horizontalPadding = scale(designTabBarHorizontalPadding, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 水平均分三个按钮
        let stackView = UIStackView(arrangedSubviews: tabButtons)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        customTabBarContainer.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: customTabBarContainer.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: customTabBarContainer.leadingAnchor, constant: horizontalPadding),
            stackView.trailingAnchor.constraint(equalTo: customTabBarContainer.trailingAnchor, constant: -horizontalPadding),
            stackView.bottomAnchor.constraint(equalTo: customTabBarContainer.bottomAnchor)
        ])
        
        // 默认选中第一个（首页）
        updateTabSelection(index: 0)
    }
    
    /// 更新 Tab 选中状态
    private func updateTabSelection(index: Int) {
        for (i, button) in tabButtons.enumerated() {
            if i == index {
                button.setTitleColor(selectedColor, for: .normal)
            } else {
                button.setTitleColor(normalColor, for: .normal)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func completeButtonTapped() {
        // 点击完成后，进入主应用界面
        enterMainApp()
    }
    
    /// 进入主应用界面（切换到 MainTabBarController，默认显示 Home 页面）
    private func enterMainApp() {
        // 标记引导页已完成
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // 获取 SceneDelegate 并切换到 MainTabBarController
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate {
            let mainTabBarController = MainTabBarController()
            mainTabBarController.selectedIndex = 0  // 默认选中第一个 tab（Home）
            sceneDelegate.window?.rootViewController = mainTabBarController
            sceneDelegate.window?.makeKeyAndVisible()
        }
    }
}
