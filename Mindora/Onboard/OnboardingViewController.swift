//
//  OnboardingViewController.swift
//  mindora
//
//  Created by gao chao on 2025/10/20.
//
//  开机引导页控制器 - 严格按照设计图实现
//  设计稿尺寸: 1242 × 2688 px (@3x, iPhone X/XS Max)
//  换算方式: 使用百分比适配不同屏幕
//

import UIKit
import SafariServices

final class OnboardingViewController: UIViewController {
    
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 设计稿中的像素值 - 文字部分
    private let designTopMargin: CGFloat = 560      // 距离顶部
    private let designLeadingMargin: CGFloat = 80   // 左边距
    private let designFontSize: CGFloat = DesignConstants.titleFontSize  // 字体大小
    private let designLineSpacing: CGFloat = 26     // 行间距
    
    // 设计稿中的像素值 - 按钮部分
    private let designButtonWidth: CGFloat = 1089       // 开始按钮宽度
    private let designButtonHeight: CGFloat = 164       // 开始按钮高度
    private let designButtonCornerRadius: CGFloat = 82  // 开始按钮圆角
    private let designButtonFontSize: CGFloat = DesignConstants.subtitleFontSize  // 开始按钮字体
    private let designButtonBorderWidth: CGFloat = 0    // 开始按钮无边框
    
    private let designNoDeviceWidth: CGFloat = 1089     // 底部按钮宽度（假设与开始按钮相同）
    private let designNoDeviceHeight: CGFloat = 164     // 底部按钮高度（假设与开始按钮相同）
    private let designNoDeviceCornerRadius: CGFloat = 82  // 底部按钮圆角
    private let designNoDeviceFontSize: CGFloat = DesignConstants.subtitleFontSize  // 底部文字字体
    private let designNoDeviceBorderWidth: CGFloat = 1  // 底部按钮边框宽度
    private let designNoDeviceBottomMargin: CGFloat = 370  // 底部文字距离底部
    
    // 计算实际尺寸的辅助方法
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    private var actualFontSize: CGFloat {
        // 基于屏幕高度计算字体大小
        return scale(designFontSize, basedOn: view.bounds.height, designDimension: designHeight)
    }
    
    private var actualTopMargin: CGFloat {
        // 基于屏幕高度计算顶部距离
        return scale(designTopMargin, basedOn: view.bounds.height, designDimension: designHeight)
    }
    
    private var actualLeadingMargin: CGFloat {
        // 基于屏幕宽度计算左边距
        return scale(designLeadingMargin, basedOn: view.bounds.width, designDimension: designWidth)
    }
    
    // MARK: - UI Components
    
    // 全屏背景图（包含MINDORA logo）
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-p1")
        imageView.contentMode = .scaleAspectFill  // 全屏填充
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // 主标语文本（三行合并）
    // "Just for you.\nA better night's sleep,\nevery night."
    private let taglineLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 0  // 多行显示
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 开始按钮
    private let startButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L("onboarding.start"), for: .normal)
        button.setTitleColor(UIColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1.0), for: .normal)
        button.backgroundColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // 底部链接 "还没有Mindora吗？"
    private let noDeviceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L("onboarding.no_device"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .clear
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
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
        // 背景色设为黑色（以防背景图加载失败）
        view.backgroundColor = .black
        
        // 添加所有子视图(背景图必须最先添加,作为最底层)
        view.addSubview(backgroundImageView)
        view.addSubview(taglineLabel)
        view.addSubview(startButton)
        view.addSubview(noDeviceButton)
        
        // 设置文本样式（使用 NSAttributedString 精确控制字体、行间距和字符间距）
        setupTextStyle()
        
        // 设置按钮样式
        setupButtonStyles()
        
        setupConstraints()
    }
    
    private func setupButtonStyles() {
        // 开始按钮字体 - 按设计稿比例计算
        let buttonFontSize = scale(designButtonFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        startButton.titleLabel?.font = UIFont.systemFont(ofSize: buttonFontSize, weight: .semibold)
        
        // 开始按钮圆角 - 按设计稿比例计算
        let cornerRadius = scale(designButtonCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        startButton.layer.cornerRadius = cornerRadius
        
        // 开始按钮无边框
        startButton.layer.borderWidth = 0
        
        // 底部按钮字体 - 按设计稿比例计算
        let noDeviceFontSize = scale(designNoDeviceFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        noDeviceButton.titleLabel?.font = UIFont.systemFont(ofSize: noDeviceFontSize, weight: .regular)
        
        // 底部按钮圆角 - 按设计稿比例计算
        let noDeviceCornerRadius = scale(designNoDeviceCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        noDeviceButton.layer.cornerRadius = noDeviceCornerRadius
        
        // 底部按钮描边 - 按设计稿比例计算
        let noDeviceBorderWidth = scale(designNoDeviceBorderWidth, basedOn: view.bounds.height, designDimension: designHeight)
        noDeviceButton.layer.borderWidth = noDeviceBorderWidth
    }
    
    private func setupTextStyle() {
        let fontSize = actualFontSize
        let lineSpacing = scale(designLineSpacing, basedOn: view.bounds.height, designDimension: designHeight)
        let letterSpacing: CGFloat = 2.0  // 字符间距
        
        let text = "Just for you.\nA better night's sleep,\nevery night."
        let attributedString = NSMutableAttributedString(string: text)
        
        // 设置字体
        let font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.count))
        
        // 设置字符间距
        attributedString.addAttribute(.kern, value: letterSpacing, range: NSRange(location: 0, length: text.count))
        
        // 设置行间距（使用 NSParagraphStyle）
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing  // 行间距：文字底部到下一行文字顶部的距离
        paragraphStyle.alignment = .left
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: text.count))
        
        // 设置文本颜色
        attributedString.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(location: 0, length: text.count))
        
        taglineLabel.attributedText = attributedString
    }
    
    private func setupConstraints() {
        let topMargin = actualTopMargin
        let leadingMargin = actualLeadingMargin
        
        // 按钮尺寸 - 按设计稿比例计算
        let buttonWidth = scale(designButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonHeight = scale(designButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let buttonLeadingMargin = (view.bounds.width - buttonWidth) / 2  // 居中
        
        // 底部按钮尺寸 - 按设计稿比例计算
        let noDeviceWidth = scale(designNoDeviceWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let noDeviceHeight = scale(designNoDeviceHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let noDeviceLeadingMargin = (view.bounds.width - noDeviceWidth) / 2  // 居中
        
        // 底部文字距离底部 - 按设计稿比例计算
        let noDeviceBottomMargin = scale(designNoDeviceBottomMargin, basedOn: view.bounds.height, designDimension: designHeight)
        
        NSLayoutConstraint.activate([
            // 背景图片 - 完全填充整个屏幕
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 主标语（三行文本）
            // 百分比计算: 550/2688 = 20.46%（高度），80/1242 = 6.44%（宽度）
            taglineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingMargin),
            taglineLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -leadingMargin),
            taglineLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: topMargin),
            
            // 开始按钮
            // 宽度: 1089/1242 = 87.68%，高度: 164/2688 = 6.10%，圆角: 82/2688 = 3.05%
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: buttonLeadingMargin),
            startButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            startButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            startButton.bottomAnchor.constraint(equalTo: noDeviceButton.topAnchor, constant: -20),
            
            // 底部按钮
            // 宽度、高度、圆角与开始按钮相同，距离底部: 370/2688 = 13.76%
            noDeviceButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: noDeviceLeadingMargin),
            noDeviceButton.widthAnchor.constraint(equalToConstant: noDeviceWidth),
            noDeviceButton.heightAnchor.constraint(equalToConstant: noDeviceHeight),
            noDeviceButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -noDeviceBottomMargin)
        ])
    }
    
    private func setupActions() {
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        noDeviceButton.addTarget(self, action: #selector(noDeviceButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func startButtonTapped() {
        // 跳转到引导页面2
        let page2 = OnboardingPage2ViewController()
        page2.modalPresentationStyle = .fullScreen
        page2.modalTransitionStyle = .crossDissolve
        present(page2, animated: true)
    }
    
    @objc private func noDeviceButtonTapped() {
        // 打开 mindora316.com 网页
        guard let url = URL(string: "https://mindora316.com") else {
            print("Invalid URL")
            return
        }
        
        let safariVC = SFSafariViewController(url: url)
        safariVC.modalPresentationStyle = .pageSheet
        present(safariVC, animated: true)
    }
}
