//
//  HealthGuideAlertViewController.swift
//  mindora
//
//  Created by GitHub Copilot on 2025/12/01.
//
//  健康权限设置指引弹窗 - 带步骤圆圈装饰
//

import UIKit

final class HealthGuideAlertViewController: UIViewController {
    
    // MARK: - Design Constants (设计稿尺寸 @3x)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 弹出页容器
    private let designAlertWidth: CGFloat = 1100
    private let designAlertCornerRadius: CGFloat = 20
    private let designAlertBottomMargin: CGFloat = 405
    
    // 标题和内容
    private let designTitleTopMargin: CGFloat = 100
    private let designTitleFontSize: CGFloat = DesignConstants.subtitleFontSize
    private let designStepFontSize: CGFloat = DesignConstants.bodyFontSize
    private let designTextHorizontalMargin: CGFloat = 80
    
    // 步骤圆圈设计
    private let designOuterCircleSize: CGFloat = 40    // 外部圆圈尺寸
    private let designInnerCircleSize: CGFloat = 20    // 内部圆圈尺寸
    private let designCircleLeftMargin: CGFloat = 94   // 圆圈距离弹出框左侧
    private let designStepSpacing: CGFloat = 30        // 步骤之间的垂直间距
    private let designCircleToTextSpacing: CGFloat = 37 // 圆圈与文字的水平间距
    
    // 底部按钮
    private let designButtonWidth: CGFloat = 345
    private let designButtonHeight: CGFloat = 128
    private let designButtonCornerRadius: CGFloat = 64
    private let designButtonBottomMargin: CGFloat = 102
    private let designButtonFontSize: CGFloat = 47
    private let designButtonSpacing: CGFloat = 100
    
    // 颜色
    private let alertBackgroundColor = UIColor(red: 21/255, green: 21/255, blue: 21/255, alpha: 1.0)
    
    // MARK: - Properties
    
    private var titleText: String
    private var steps: [String]
    private var confirmButtonTitle: String
    private var cancelButtonTitle: String
    private var onConfirm: (() -> Void)?
    private var onCancel: (() -> Void)?
    
    // MARK: - UI Components
    
    private let dimmedBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let alertContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let stepsContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .clear
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .clear
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Helper
    
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    // MARK: - Initialization
    
    /// 初始化健康权限指引弹窗
    /// - Parameters:
    ///   - title: 标题
    ///   - message: 多行消息，用换行符分隔的步骤
    ///   - confirmButtonTitle: 确认按钮标题
    ///   - cancelButtonTitle: 取消按钮标题
    ///   - onConfirm: 确认回调
    ///   - onCancel: 取消回调
    init(title: String,
         message: String,
         confirmButtonTitle: String,
         cancelButtonTitle: String,
         onConfirm: (() -> Void)? = nil,
         onCancel: (() -> Void)? = nil) {
        self.titleText = title
        self.steps = message.components(separatedBy: "\n").filter { !$0.isEmpty }
        self.confirmButtonTitle = confirmButtonTitle
        self.cancelButtonTitle = cancelButtonTitle
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
        
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
        
        view.addSubview(dimmedBackgroundView)
        view.addSubview(alertContainerView)
        alertContainerView.addSubview(titleLabel)
        alertContainerView.addSubview(stepsContainerView)
        alertContainerView.addSubview(confirmButton)
        alertContainerView.addSubview(cancelButton)
        
        setupStyles()
        setupSteps()
        setupConstraints()
    }
    
    private func setupStyles() {
        alertContainerView.backgroundColor = alertBackgroundColor
        let alertCornerRadius = scale(designAlertCornerRadius, basedOn: view.bounds.width, designDimension: designWidth)
        alertContainerView.layer.cornerRadius = alertCornerRadius
        alertContainerView.clipsToBounds = true
        
        let titleFontSize = scale(designTitleFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = UIFont.systemFont(ofSize: titleFontSize, weight: .semibold)
        titleLabel.text = titleText
        
        let buttonFontSize = scale(designButtonFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: buttonFontSize, weight: .medium)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: buttonFontSize, weight: .medium)
        
        confirmButton.setTitle(confirmButtonTitle, for: .normal)
        cancelButton.setTitle(cancelButtonTitle, for: .normal)
        
        let buttonCornerRadius = scale(designButtonCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        confirmButton.layer.cornerRadius = buttonCornerRadius
        cancelButton.layer.cornerRadius = buttonCornerRadius
        
        let borderWidth = scale(1, basedOn: view.bounds.height, designDimension: designHeight)
        confirmButton.layer.borderWidth = borderWidth
        cancelButton.layer.borderWidth = borderWidth
    }
    
    private func setupSteps() {
        let outerCircleSize = scale(designOuterCircleSize, basedOn: view.bounds.width, designDimension: designWidth)
        let innerCircleSize = scale(designInnerCircleSize, basedOn: view.bounds.width, designDimension: designWidth)
        let circleLeftMargin = scale(designCircleLeftMargin, basedOn: view.bounds.width, designDimension: designWidth)
        let stepSpacing = scale(designStepSpacing, basedOn: view.bounds.height, designDimension: designHeight)
        let circleToTextSpacing = scale(designCircleToTextSpacing, basedOn: view.bounds.width, designDimension: designWidth)
        let stepFontSize = scale(designStepFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        let textHorizontalMargin = scale(designTextHorizontalMargin, basedOn: view.bounds.width, designDimension: designWidth)
        
        var previousStepView: UIView?
        
        for (index, stepText) in steps.enumerated() {
            // 创建步骤容器
            let stepView = UIView()
            stepView.translatesAutoresizingMaskIntoConstraints = false
            stepsContainerView.addSubview(stepView)
            
            // 创建外部圆圈（白色透明度20%）
            let outerCircle = UIView()
            outerCircle.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            outerCircle.layer.cornerRadius = outerCircleSize / 2
            outerCircle.translatesAutoresizingMaskIntoConstraints = false
            stepView.addSubview(outerCircle)
            
            // 创建内部圆圈（白色）
            let innerCircle = UIView()
            innerCircle.backgroundColor = UIColor.white
            innerCircle.layer.cornerRadius = innerCircleSize / 2
            innerCircle.translatesAutoresizingMaskIntoConstraints = false
            outerCircle.addSubview(innerCircle)
            
            // 创建步骤文字标签
            let stepLabel = UILabel()
            stepLabel.text = stepText
            stepLabel.textColor = .white
            stepLabel.font = UIFont.systemFont(ofSize: stepFontSize, weight: .regular)
            stepLabel.numberOfLines = 0
            stepLabel.translatesAutoresizingMaskIntoConstraints = false
            stepView.addSubview(stepLabel)
            
            // 设置约束
            NSLayoutConstraint.activate([
                // 步骤容器约束
                stepView.leadingAnchor.constraint(equalTo: stepsContainerView.leadingAnchor),
                stepView.trailingAnchor.constraint(equalTo: stepsContainerView.trailingAnchor),
                
                // 外部圆圈约束
                outerCircle.leadingAnchor.constraint(equalTo: stepView.leadingAnchor, constant: circleLeftMargin),
                outerCircle.centerYAnchor.constraint(equalTo: stepView.centerYAnchor),
                outerCircle.widthAnchor.constraint(equalToConstant: outerCircleSize),
                outerCircle.heightAnchor.constraint(equalToConstant: outerCircleSize),
                
                // 内部圆圈约束（居中于外部圆圈）
                innerCircle.centerXAnchor.constraint(equalTo: outerCircle.centerXAnchor),
                innerCircle.centerYAnchor.constraint(equalTo: outerCircle.centerYAnchor),
                innerCircle.widthAnchor.constraint(equalToConstant: innerCircleSize),
                innerCircle.heightAnchor.constraint(equalToConstant: innerCircleSize),
                
                // 步骤文字约束
                stepLabel.leadingAnchor.constraint(equalTo: outerCircle.trailingAnchor, constant: circleToTextSpacing),
                stepLabel.trailingAnchor.constraint(equalTo: stepView.trailingAnchor, constant: -textHorizontalMargin),
                stepLabel.topAnchor.constraint(equalTo: stepView.topAnchor),
                stepLabel.bottomAnchor.constraint(equalTo: stepView.bottomAnchor),
                
                // 确保步骤容器高度至少等于外部圆圈高度
                stepView.heightAnchor.constraint(greaterThanOrEqualToConstant: outerCircleSize)
            ])
            
            // 设置步骤之间的垂直位置
            if let previous = previousStepView {
                stepView.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: stepSpacing).isActive = true
            } else {
                stepView.topAnchor.constraint(equalTo: stepsContainerView.topAnchor).isActive = true
            }
            
            // 最后一个步骤连接到容器底部
            if index == steps.count - 1 {
                stepView.bottomAnchor.constraint(equalTo: stepsContainerView.bottomAnchor).isActive = true
            }
            
            previousStepView = stepView
        }
    }
    
    private func setupConstraints() {
        let alertWidth = scale(designAlertWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let alertBottomMargin = scale(designAlertBottomMargin, basedOn: view.bounds.height, designDimension: designHeight)
        let titleTopMargin = scale(designTitleTopMargin, basedOn: view.bounds.height, designDimension: designHeight)
        let textHorizontalMargin = scale(designTextHorizontalMargin, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonWidth = scale(designButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonHeight = scale(designButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let buttonBottomMargin = scale(designButtonBottomMargin, basedOn: view.bounds.height, designDimension: designHeight)
        let buttonSpacing = scale(designButtonSpacing, basedOn: view.bounds.width, designDimension: designWidth)
        let descriptionToButtonSpacing = scale(60, basedOn: view.bounds.height, designDimension: designHeight)
        
        NSLayoutConstraint.activate([
            // 半透明背景遮罩
            dimmedBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmedBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 弹出页容器
            alertContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alertContainerView.widthAnchor.constraint(equalToConstant: alertWidth),
            alertContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -alertBottomMargin),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: alertContainerView.topAnchor, constant: titleTopMargin),
            titleLabel.leadingAnchor.constraint(equalTo: alertContainerView.leadingAnchor, constant: textHorizontalMargin),
            titleLabel.trailingAnchor.constraint(equalTo: alertContainerView.trailingAnchor, constant: -textHorizontalMargin),
            
            // 步骤容器
            stepsContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            stepsContainerView.leadingAnchor.constraint(equalTo: alertContainerView.leadingAnchor),
            stepsContainerView.trailingAnchor.constraint(equalTo: alertContainerView.trailingAnchor),
            
            // 取消按钮（左侧）
            cancelButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            cancelButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            cancelButton.topAnchor.constraint(equalTo: stepsContainerView.bottomAnchor, constant: descriptionToButtonSpacing),
            cancelButton.trailingAnchor.constraint(equalTo: alertContainerView.centerXAnchor, constant: -buttonSpacing / 2),
            
            // 确认按钮（右侧）
            confirmButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            confirmButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            confirmButton.topAnchor.constraint(equalTo: stepsContainerView.bottomAnchor, constant: descriptionToButtonSpacing),
            confirmButton.leadingAnchor.constraint(equalTo: alertContainerView.centerXAnchor, constant: buttonSpacing / 2),
            
            // 弹出页底部约束
            alertContainerView.bottomAnchor.constraint(equalTo: confirmButton.bottomAnchor, constant: buttonBottomMargin)
        ])
    }
    
    private func setupActions() {
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
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
        cancelButtonTapped()
    }
}
