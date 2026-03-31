//
//  OnboardingPage2ViewController.swift
//  mindora
//
//  Created by gao chao on 2025/10/20.
//
//  开机引导页2控制器 - 严格按照设计图实现
//  设计稿尺寸: 1242 × 2688 px (@3x, iPhone X/XS Max)
//  换算方式: 使用百分比适配不同屏幕
//

import UIKit

final class OnboardingPage2ViewController: UIViewController {
    
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 设计稿中的像素值 - 底部按钮容器（类似引导页1的按钮风格）
    private let designButtonWidth: CGFloat = 1129          // 按钮宽度
    private let designButtonHeight: CGFloat = 187          // 按钮高度（增加以更好容纳内容）
    private let designButtonCornerRadius: CGFloat = 88     // 按钮圆角（完整的圆角矩形）
    private let designButtonBottomMargin: CGFloat = 160    // 按钮距离底部
    
    // 设计稿中的像素值 - 问号图标
    private let designQuestionIconSize: CGFloat = 90       // 问号图标尺寸
    private let designQuestionIconLeading: CGFloat = 108   // 问号图标距离按钮左边
    
    // 设计稿中的像素值 - 按钮文字
    private let designTextFontSize: CGFloat = DesignConstants.subtitleFontSize  // "连接 Mindora" 字体大小
    private let designTextTrailing: CGFloat = 108          // 文字距离按钮右边
    
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
        imageView.image = UIImage(named: "boot-p2")
        imageView.contentMode = .scaleAspectFill  // 全屏填充
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // 底部白色按钮容器（类似引导页1的按钮风格 - 完整圆角矩形）
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
    
    // 退出按钮
    private let exitButton: OnboardingExitButton = {
        let button = OnboardingExitButton()
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 添加所有子视图(按照层级顺序)
        view.addSubview(backgroundImageView)
        view.addSubview(bottomContainerView)
        bottomContainerView.addSubview(questionIconView)
        bottomContainerView.addSubview(connectLabel)
        view.addSubview(exitButton)
        
        setupStyles()
        setupConstraints()
    }
    
    private func setupStyles() {
        // 文字字体 - 按设计稿比例计算
        let textFontSize = scale(designTextFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        connectLabel.font = UIFont(name: "Kano-regular", size: textFontSize) ?? UIFont.systemFont(ofSize: textFontSize, weight: .medium)
        
        // 按钮容器圆角 - 按设计稿比例计算（完整圆角，类似引导页1）
        let cornerRadius = scale(designButtonCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        bottomContainerView.layer.cornerRadius = cornerRadius
        // 不需要 maskedCorners，使用完整的圆角
    }
    
    private func setupConstraints() {
        // 按钮尺寸 - 按设计稿比例计算
        let buttonWidth = scale(designButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonHeight = scale(designButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let buttonBottomMargin = scale(designButtonBottomMargin, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 问号图标尺寸和位置 - 按设计稿比例计算
        let questionIconSize = scale(designQuestionIconSize, basedOn: view.bounds.width, designDimension: designWidth)
        let questionIconLeading = scale(designQuestionIconLeading, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 文字位置 - 按设计稿比例计算
        let textTrailing = scale(designTextTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 退出按钮尺寸 - 按设计稿比例计算
        let exitButtonTop = scale(designExitButtonTop, basedOn: view.bounds.height, designDimension: designHeight)
        let exitButtonTrailing = scale(designExitButtonTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        let exitButtonWidth = scale(designExitButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let exitButtonHeight = scale(designExitButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        
        NSLayoutConstraint.activate([
            // 背景图片 - 完全填充整个屏幕（包括安全区域外）
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 底部白色按钮容器 - 居中显示，类似引导页1的按钮
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
            connectLabel.trailingAnchor.constraint(equalTo: bottomContainerView.trailingAnchor, constant: -textTrailing),
            connectLabel.centerYAnchor.constraint(equalTo: bottomContainerView.centerYAnchor),
            
            // 退出按钮
            exitButton.topAnchor.constraint(equalTo: view.topAnchor, constant: exitButtonTop),
            exitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -exitButtonTrailing),
            exitButton.widthAnchor.constraint(equalToConstant: exitButtonWidth),
            exitButton.heightAnchor.constraint(equalToConstant: exitButtonHeight)
        ])
    }
    
    private func setupActions() {
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
    
    @objc private func bottomContainerTapped() {
        // 点击整个底部容器时，检查点击位置
        // 如果点击的是左侧问号区域，打开用户手册
        // 如果点击的是其他区域，跳转到引导页3
    }
    
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
    
    @objc private func connectAreaTapped() {
        self.bottomContainerView.animateButtonTap { [weak self] in
            // 跳转到引导页3
            print("Connect Mindora tapped - Navigate to Page 3")
            let page3VC = OnboardingPage3ViewController()
            page3VC.modalPresentationStyle = .fullScreen
            page3VC.modalTransitionStyle = .crossDissolve
            self?.present(page3VC, animated: true)
        }
    }
}
