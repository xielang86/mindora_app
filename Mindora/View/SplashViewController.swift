//
//  SplashViewController.swift
//  mindora
//
//  Created by gao chao on 2025/9/19.
//
//  启动过渡界面，显示全屏背景图和标语文本
//

import UIKit

final class SplashViewController: UIViewController {
    
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 设计稿中的像素值 - 文字部分
    private let designTopMargin: CGFloat = 560      // 距离顶部
    private let designLeadingMargin: CGFloat = 80   // 左边距
    private let designFontSize: CGFloat = DesignConstants.titleFontSize  // 字体大小
    private let designLineSpacing: CGFloat = 26     // 行间距
    
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
    
    // 全屏背景图
    private let imageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "boot-p1"))
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
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

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = Theme.background
        
        // 添加子视图（背景图在最底层）
        view.addSubview(imageView)
        view.addSubview(taglineLabel)
        
        // 设置文本样式
        setupTextStyle()
        
        // 设置约束
        setupConstraints()
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
        
        NSLayoutConstraint.activate([
            // 背景图片 - 完全填充整个屏幕
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 主标语（三行文本）
            taglineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingMargin),
            taglineLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -leadingMargin),
            taglineLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: topMargin)
        ])
    }

    // MARK: - Transition
    
    func transition(to root: UIViewController, in window: UIWindow, duration: TimeInterval = 0.35) {
        // 平滑淡出 & 缩放动画
        UIView.transition(with: window, duration: duration, options: [.transitionCrossDissolve]) {
            window.rootViewController = root
        } completion: { _ in }
    }
}
