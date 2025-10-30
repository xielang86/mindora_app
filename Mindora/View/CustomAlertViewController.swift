//
//  CustomAlertViewController.swift
//  mindora
//
//  Created by gao chao on 2025/10/21.
//
//  自定义警告弹出页 - 严格按照设计图实现
//  设计稿尺寸: 1242 × 2688 px (@3x, iPhone X/XS Max)
//  换算方式: 使用百分比适配不同屏幕
//

import UIKit

final class CustomAlertViewController: UIViewController {
    
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 设计稿中的像素值 - 弹出页容器
    private let designAlertWidth: CGFloat = 1100           // 弹出页宽度
    private let designAlertHeight: CGFloat = 707           // 弹出页高度
    private let designAlertCornerRadius: CGFloat = 20      // 弹出页圆角
    private let designAlertBottomMargin: CGFloat = 405     // 弹出页距离底部
    
    // 设计稿中的像素值 - 标题和内容
    private let designTitleTopMargin: CGFloat = 100        // 标题距离弹出页顶部
    private let designTitleFontSize: CGFloat = DesignConstants.subtitleFontSize  // 标题字体大小 (Semibold)
    private let designDescriptionFontSize: CGFloat = DesignConstants.bodyFontSize  // 描述文字字体大小 (Regular)
    private let designDescriptionLineSpacing: CGFloat = 21 // 描述文字行间距
    private let designTextHorizontalMargin: CGFloat = 80   // 文字左右边距（估算）
    
    // 设计稿中的像素值 - 底部按钮
    private let designButtonWidth: CGFloat = 345           // 按钮宽度
    private let designButtonHeight: CGFloat = 128          // 按钮高度
    private let designButtonCornerRadius: CGFloat = 64     // 按钮圆角
    private let designButtonBottomMargin: CGFloat = 102    // 按钮距离弹出页底部
    private let designButtonFontSize: CGFloat = 47         // 按钮字体大小 (Medium)
    private let designButtonSpacing: CGFloat = 100         // 两个按钮之间的间距（进一步增加间距）
    
    // 设计稿中的颜色
    private let alertBackgroundColor = UIColor(red: 21/255, green: 21/255, blue: 21/255, alpha: 1.0)  // 背景色 RGB(21, 21, 21)
    
    // 计算实际尺寸的辅助方法
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    // MARK: - Properties
    
    private var titleText: String
    private var descriptionText: String
    private var confirmButtonTitle: String
    private var cancelButtonTitle: String
    private var onConfirm: (() -> Void)?
    private var onCancel: (() -> Void)?
    
    // MARK: - UI Components
    
    // 半透明背景遮罩
    private let dimmedBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 弹出页容器
    private let alertContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 标题标签
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 描述标签
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 确认按钮（右侧）
    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .clear
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // 取消按钮（左侧）
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .clear
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Initialization
    
    init(title: String,
         description: String,
         confirmButtonTitle: String,
         cancelButtonTitle: String,
         onConfirm: (() -> Void)? = nil,
         onCancel: (() -> Void)? = nil) {
        self.titleText = title
        self.descriptionText = description
        self.confirmButtonTitle = confirmButtonTitle
        self.cancelButtonTitle = cancelButtonTitle
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
        
        // 设置为透明背景的模态展示
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        // 添加所有子视图(按照层级顺序)
        view.addSubview(dimmedBackgroundView)
        view.addSubview(alertContainerView)
        alertContainerView.addSubview(titleLabel)
        alertContainerView.addSubview(descriptionLabel)
        alertContainerView.addSubview(confirmButton)
        alertContainerView.addSubview(cancelButton)
        
        setupStyles()
        setupConstraints()
    }
    
    private func setupStyles() {
        // 弹出页容器背景色和圆角
        alertContainerView.backgroundColor = alertBackgroundColor
        let alertCornerRadius = scale(designAlertCornerRadius, basedOn: view.bounds.width, designDimension: designWidth)
        alertContainerView.layer.cornerRadius = alertCornerRadius
        alertContainerView.clipsToBounds = true
        
        // 标题字体 - 按设计稿比例计算 (54pt Semibold)
        let titleFontSize = scale(designTitleFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = UIFont.systemFont(ofSize: titleFontSize, weight: .semibold)
        titleLabel.text = titleText
        
        // 描述文字样式 - 按设计稿比例计算 (45pt Regular, 行间距 21px)
        let descriptionFontSize = scale(designDescriptionFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        let lineSpacing = scale(designDescriptionLineSpacing, basedOn: view.bounds.height, designDimension: designHeight)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.alignment = .left
        
        let attributedString = NSMutableAttributedString(string: descriptionText)
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: descriptionFontSize, weight: .regular), range: NSRange(location: 0, length: descriptionText.count))
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: descriptionText.count))
        attributedString.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(location: 0, length: descriptionText.count))
        
        descriptionLabel.attributedText = attributedString
        
        // 按钮字体 - 按设计稿比例计算 (47pt Medium)
        let buttonFontSize = scale(designButtonFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: buttonFontSize, weight: .medium)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: buttonFontSize, weight: .medium)
        
        confirmButton.setTitle(confirmButtonTitle, for: .normal)
        cancelButton.setTitle(cancelButtonTitle, for: .normal)
        
        // 按钮圆角 - 按设计稿比例计算
        let buttonCornerRadius = scale(designButtonCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        confirmButton.layer.cornerRadius = buttonCornerRadius
        cancelButton.layer.cornerRadius = buttonCornerRadius
        
        // 两个按钮都使用白色边框，样式一致
        let borderWidth = scale(1, basedOn: view.bounds.height, designDimension: designHeight)
        confirmButton.layer.borderWidth = borderWidth
        cancelButton.layer.borderWidth = borderWidth
    }
    
    private func setupConstraints() {
        // 弹出页尺寸 - 按设计稿比例计算
        let alertWidth = scale(designAlertWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let alertHeight = scale(designAlertHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let alertBottomMargin = scale(designAlertBottomMargin, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 标题距离顶部 - 按设计稿比例计算
        let titleTopMargin = scale(designTitleTopMargin, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 文字左右边距 - 按设计稿比例计算
        let textHorizontalMargin = scale(designTextHorizontalMargin, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 按钮尺寸 - 按设计稿比例计算
        let buttonWidth = scale(designButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonHeight = scale(designButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let buttonBottomMargin = scale(designButtonBottomMargin, basedOn: view.bounds.height, designDimension: designHeight)
        let buttonSpacing = scale(designButtonSpacing, basedOn: view.bounds.width, designDimension: designWidth)
        
        NSLayoutConstraint.activate([
            // 半透明背景遮罩 - 完全填充整个屏幕
            dimmedBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmedBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 弹出页容器 - 居中显示，距离底部固定距离
            alertContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alertContainerView.widthAnchor.constraint(equalToConstant: alertWidth),
            alertContainerView.heightAnchor.constraint(equalToConstant: alertHeight),
            alertContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -alertBottomMargin),
            
            // 标题 - 距离弹出页顶部固定距离，水平居中
            titleLabel.topAnchor.constraint(equalTo: alertContainerView.topAnchor, constant: titleTopMargin),
            titleLabel.leadingAnchor.constraint(equalTo: alertContainerView.leadingAnchor, constant: textHorizontalMargin),
            titleLabel.trailingAnchor.constraint(equalTo: alertContainerView.trailingAnchor, constant: -textHorizontalMargin),
            
            // 描述 - 在标题下方，水平居中
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            descriptionLabel.leadingAnchor.constraint(equalTo: alertContainerView.leadingAnchor, constant: textHorizontalMargin),
            descriptionLabel.trailingAnchor.constraint(equalTo: alertContainerView.trailingAnchor, constant: -textHorizontalMargin),
            
            // 取消按钮（左侧）- 距离底部固定距离
            cancelButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            cancelButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            cancelButton.bottomAnchor.constraint(equalTo: alertContainerView.bottomAnchor, constant: -buttonBottomMargin),
            cancelButton.trailingAnchor.constraint(equalTo: alertContainerView.centerXAnchor, constant: -buttonSpacing / 2),
            
            // 确认按钮（右侧）- 距离底部固定距离
            confirmButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            confirmButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            confirmButton.bottomAnchor.constraint(equalTo: alertContainerView.bottomAnchor, constant: -buttonBottomMargin),
            confirmButton.leadingAnchor.constraint(equalTo: alertContainerView.centerXAnchor, constant: buttonSpacing / 2)
        ])
    }
    
    private func setupActions() {
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
        // 点击背景关闭弹出页
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        dimmedBackgroundView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Actions
    
    @objc private func confirmButtonTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onConfirm?()
        }
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onCancel?()
        }
    }
    
    @objc private func backgroundTapped() {
        // 点击背景等同于取消
        cancelButtonTapped()
    }
}
