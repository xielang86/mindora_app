//
//  HelpManualUnifiedViewController.swift
//  mindora
//
//  Created by gao chao on 2025/10/23.
//
//

import UIKit
import SafariServices

final class HelpManualUnifiedViewController: UIViewController {
    
    // MARK: - Design Constants
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    private let designTitleTop: CGFloat = DesignConstants.titleTopMargin
    private let designTitleFontSize: CGFloat = DesignConstants.titleFontSize
    private let designTextLeading: CGFloat = 116
    
    private let designDescriptionTop: CGFloat = 190
    private let designDescriptionFontSize: CGFloat = DesignConstants.bodyFontSize
    private let designDescriptionLineSpacing: CGFloat = 22
    private let designDescriptionTrailing: CGFloat = 160
    
    private let designIconsTop: CGFloat = 1689
    private let designIconToLineSpacing: CGFloat = 47
    
    private let designQRCodeBottom: CGFloat = 1194
    private let designQRCodeSize: CGFloat = 295
    
    private let designPageControlBottom: CGFloat = 632
    private let designPageControlDotSize: CGFloat = 14
    private let designPageControlDotWidth: CGFloat = 35
    private let designPageControlSpacing: CGFloat = 16
    
    private let designButtonWidth: CGFloat = 1129
    private let designButtonHeight: CGFloat = 187
    private let designButtonCornerRadius: CGFloat = 88
    private let designButtonBottomMargin: CGFloat = 160
    
    private let designQuestionIconSize: CGFloat = 90
    private let designQuestionIconLeading: CGFloat = 108
    
    private let designButtonTextFontSize: CGFloat = DesignConstants.subtitleFontSize
    private let designButtonTextTrailing: CGFloat = 108
    
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    // MARK: - Properties
    
    private let pageData: [HelpManualPageData]
    private var currentPageIndex: Int = 0 {
        didSet {
            updatePageIndicators()
        }
    }
    
    weak var delegate: HelpManualUnifiedViewControllerDelegate?
    
    // MARK: - UI Components (Static Elements)
    
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-p2")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // 自定义分页控件容器
    private let customPageControlContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var pageIndicators: [UIView] = []
    
    // 底部白色按钮容器
    private let bottomContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private let questionIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-manual")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.alpha = 0.3
        return imageView
    }()
    
    private let connectLabel: UILabel = {
        let label = UILabel()
        label.text = L("onboarding.connect_mindora")
        label.textColor = UIColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1.0)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = true
        return label
    }()
    
    // MARK: - UI Components (Dynamic Content)
    
    // 标题 - 静态不动画
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 描述 - 静态不动画
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = true
        return label
    }()
    
    // 图标容器 - 用于动画
    private let contentContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false // 不拦截点击事件
        return view
    }()
    
    // 连接示意图容器
    private let connectionDiagramContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let leftIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let dashedLineView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "dashed_line")
        imageView.contentMode = .scaleToFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let rightIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // 二维码
    private let qrCodeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "qr_code")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.alpha = 0
        return imageView
    }()
    
    // 约束引用 - 用于动态调整
    private var leftIconWidthConstraint: NSLayoutConstraint?
    private var leftIconHeightConstraint: NSLayoutConstraint?
    private var rightIconWidthConstraint: NSLayoutConstraint?
    private var rightIconHeightConstraint: NSLayoutConstraint?
    private var dashedLineWidthConstraint: NSLayoutConstraint?
    
    // MARK: - Initialization
    
    init(pageData: [HelpManualPageData] = HelpManualPageData.createAllPages()) {
        self.pageData = pageData
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        setupActions()
        
        // 显示第一页内容
        updateContent(for: 0, animated: false)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 添加静态元素
        view.addSubview(backgroundImageView)
        view.addSubview(titleLabel)  // 标题静态
        view.addSubview(descriptionLabel)  // 描述静态
        view.addSubview(customPageControlContainer)
        view.addSubview(bottomContainerView)
        bottomContainerView.addSubview(questionIconView)
        bottomContainerView.addSubview(connectLabel)
        
        // 添加动画容器(只包含图标)
        view.addSubview(contentContainer)
        contentContainer.addSubview(connectionDiagramContainer)
        connectionDiagramContainer.addSubview(leftIconView)
        connectionDiagramContainer.addSubview(dashedLineView)
        connectionDiagramContainer.addSubview(rightIconView)
        contentContainer.addSubview(qrCodeImageView)
        
        // 创建分页指示器
        for i in 0..<pageData.count {
            let indicator = UIView()
            indicator.backgroundColor = .white
            indicator.alpha = i == 0 ? 1.0 : 0.6
            indicator.translatesAutoresizingMaskIntoConstraints = false
            customPageControlContainer.addSubview(indicator)
            pageIndicators.append(indicator)
        }
        
        setupStyles()
        setupConstraints()
    }
    
    private func setupStyles() {
        let titleFontSize = scale(designTitleFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = UIFont.systemFont(ofSize: titleFontSize, weight: .medium)
        
        let buttonTextFontSize = scale(designButtonTextFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        connectLabel.font = UIFont.systemFont(ofSize: buttonTextFontSize, weight: .medium)
        
        let buttonCornerRadius = scale(designButtonCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        bottomContainerView.layer.cornerRadius = buttonCornerRadius
        
        let dotSize = scale(designPageControlDotSize, basedOn: view.bounds.height, designDimension: designHeight)
        for indicator in pageIndicators {
            indicator.layer.cornerRadius = dotSize / 2
        }
    }
    
    private func setupConstraints() {
        let titleTop = scale(designTitleTop, basedOn: view.bounds.height, designDimension: designHeight)
        let textLeading = scale(designTextLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let descriptionTop = scale(designDescriptionTop, basedOn: view.bounds.height, designDimension: designHeight)
        let descriptionTrailing = scale(designDescriptionTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        
        let iconsTop = scale(designIconsTop, basedOn: view.bounds.height, designDimension: designHeight)
        // 图标应该相对于view顶部，减去标题和描述的距离
        let _ = iconsTop - titleTop - descriptionTop
        let iconToLineSpacing = scale(designIconToLineSpacing, basedOn: view.bounds.width, designDimension: designWidth)
        
        let qrCodeBottom = scale(designQRCodeBottom, basedOn: view.bounds.height, designDimension: designHeight)
        let qrCodeSize = scale(designQRCodeSize, basedOn: view.bounds.width, designDimension: designWidth)
        
        let pageControlBottom = scale(designPageControlBottom, basedOn: view.bounds.height, designDimension: designHeight)
        let dotSize = scale(designPageControlDotSize, basedOn: view.bounds.height, designDimension: designHeight)
        let dotWidth = scale(designPageControlDotWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let dotSpacing = scale(designPageControlSpacing, basedOn: view.bounds.width, designDimension: designWidth)
        
        let buttonWidth = scale(designButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonHeight = scale(designButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let buttonBottomMargin = scale(designButtonBottomMargin, basedOn: view.bounds.height, designDimension: designHeight)
        let questionIconSize = scale(designQuestionIconSize, basedOn: view.bounds.width, designDimension: designWidth)
        let questionIconLeading = scale(designQuestionIconLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonTextTrailing = scale(designButtonTextTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 背景图
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 标题 - 静态不动画
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: titleTop),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: textLeading),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -textLeading)
        ])
        
        // 描述 - 静态不动画
        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: descriptionTop),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: textLeading),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -descriptionTrailing)
        ])
        
        // 内容容器(只包含图标,用于动画)
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 连接示意图容器
        NSLayoutConstraint.activate([
            connectionDiagramContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: iconsTop),
            connectionDiagramContainer.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor)
        ])
        
        // 左图标
        leftIconWidthConstraint = leftIconView.widthAnchor.constraint(equalToConstant: 0)
        leftIconHeightConstraint = leftIconView.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            leftIconView.leadingAnchor.constraint(equalTo: connectionDiagramContainer.leadingAnchor),
            leftIconView.centerYAnchor.constraint(equalTo: connectionDiagramContainer.centerYAnchor),
            leftIconWidthConstraint!,
            leftIconHeightConstraint!
        ])
        
        // 虚线
        dashedLineWidthConstraint = dashedLineView.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            dashedLineView.leadingAnchor.constraint(equalTo: leftIconView.trailingAnchor, constant: iconToLineSpacing),
            dashedLineView.centerYAnchor.constraint(equalTo: connectionDiagramContainer.centerYAnchor),
            dashedLineView.heightAnchor.constraint(equalToConstant: 1),
            dashedLineWidthConstraint!
        ])
        
        // 右图标
        rightIconWidthConstraint = rightIconView.widthAnchor.constraint(equalToConstant: 0)
        rightIconHeightConstraint = rightIconView.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            rightIconView.leadingAnchor.constraint(equalTo: dashedLineView.trailingAnchor, constant: iconToLineSpacing),
            rightIconView.centerYAnchor.constraint(equalTo: connectionDiagramContainer.centerYAnchor),
            rightIconView.trailingAnchor.constraint(equalTo: connectionDiagramContainer.trailingAnchor),
            rightIconWidthConstraint!,
            rightIconHeightConstraint!
        ])
        
        NSLayoutConstraint.activate([
            connectionDiagramContainer.topAnchor.constraint(equalTo: leftIconView.topAnchor),
            connectionDiagramContainer.bottomAnchor.constraint(equalTo: leftIconView.bottomAnchor)
        ])
        
        // 二维码
        NSLayoutConstraint.activate([
            qrCodeImageView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -qrCodeBottom),
            qrCodeImageView.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            qrCodeImageView.widthAnchor.constraint(equalToConstant: qrCodeSize),
            qrCodeImageView.heightAnchor.constraint(equalToConstant: qrCodeSize)
        ])
        
        // 分页控件
        let totalWidth = dotWidth + CGFloat(pageData.count - 1) * (dotSize + dotSpacing)
        var previousIndicator: UIView?
        
        for (index, indicator) in pageIndicators.enumerated() {
            let isSelected = index == 0
            let width = isSelected ? dotWidth : dotSize
            
            NSLayoutConstraint.activate([
                indicator.widthAnchor.constraint(equalToConstant: width),
                indicator.heightAnchor.constraint(equalToConstant: dotSize),
                indicator.bottomAnchor.constraint(equalTo: customPageControlContainer.bottomAnchor)
            ])
            
            if let previous = previousIndicator {
                NSLayoutConstraint.activate([
                    indicator.leadingAnchor.constraint(equalTo: previous.trailingAnchor, constant: dotSpacing)
                ])
            } else {
                NSLayoutConstraint.activate([
                    indicator.leadingAnchor.constraint(equalTo: customPageControlContainer.leadingAnchor)
                ])
            }
            
            previousIndicator = indicator
        }
        
        NSLayoutConstraint.activate([
            customPageControlContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -pageControlBottom),
            customPageControlContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            customPageControlContainer.widthAnchor.constraint(equalToConstant: totalWidth),
            customPageControlContainer.heightAnchor.constraint(equalToConstant: dotSize)
        ])
        
        // 底部按钮
        NSLayoutConstraint.activate([
            bottomContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -buttonBottomMargin),
            bottomContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomContainerView.widthAnchor.constraint(equalToConstant: buttonWidth),
            bottomContainerView.heightAnchor.constraint(equalToConstant: buttonHeight)
        ])
        
        NSLayoutConstraint.activate([
            questionIconView.leadingAnchor.constraint(equalTo: bottomContainerView.leadingAnchor, constant: questionIconLeading),
            questionIconView.centerYAnchor.constraint(equalTo: bottomContainerView.centerYAnchor),
            questionIconView.widthAnchor.constraint(equalToConstant: questionIconSize),
            questionIconView.heightAnchor.constraint(equalToConstant: questionIconSize)
        ])
        
        NSLayoutConstraint.activate([
            connectLabel.trailingAnchor.constraint(equalTo: bottomContainerView.trailingAnchor, constant: -buttonTextTrailing),
            connectLabel.centerYAnchor.constraint(equalTo: bottomContainerView.centerYAnchor)
        ])
    }
    
    private func setupGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
    }
    
    private func setupActions() {
        // 整个按钮容器可以点击
        let containerTapGesture = UITapGestureRecognizer(target: self, action: #selector(connectLabelTapped))
        bottomContainerView.addGestureRecognizer(containerTapGesture)
        
        // 右侧文字也可以单独点击
        let labelTapGesture = UITapGestureRecognizer(target: self, action: #selector(connectLabelTapped))
        connectLabel.addGestureRecognizer(labelTapGesture)
        
        // 描述文本的点击手势(用于点击网站链接)
        let descriptionTapGesture = UITapGestureRecognizer(target: self, action: #selector(descriptionLabelTapped(_:)))
        descriptionLabel.addGestureRecognizer(descriptionTapGesture)
    }
    
    // MARK: - Content Update
    
    func updateContent(for pageIndex: Int, animated: Bool = true) {
        guard pageIndex >= 0 && pageIndex < pageData.count else { return }
        
        let page = pageData[pageIndex]
        
        if animated {
            // 使用更丝滑的弹簧动画
            let direction: CGFloat = pageIndex > currentPageIndex ? 1 : -1
            
            // 淡出 + 轻微位移 - 使用更快的速度
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn], animations: {
                self.contentContainer.alpha = 0
                self.contentContainer.transform = CGAffineTransform(translationX: -15 * direction, y: 0)
            }) { _ in
                // 更新内容
                self.applyPageData(page)
                
                // 从另一侧准备淡入
                self.contentContainer.transform = CGAffineTransform(translationX: 15 * direction, y: 0)
                
                // 使用弹簧动画淡入 - 更丝滑自然
                UIView.animate(
                    withDuration: 0.5,
                    delay: 0,
                    usingSpringWithDamping: 0.85,  // 轻微回弹
                    initialSpringVelocity: 0.8,     // 初始速度
                    options: [.curveEaseOut],
                    animations: {
                        self.contentContainer.alpha = 1
                        self.contentContainer.transform = .identity
                    }
                )
            }
        } else {
            applyPageData(page)
            contentContainer.alpha = 1
            contentContainer.transform = .identity
        }
        
        currentPageIndex = pageIndex
    }
    
    private func applyPageData(_ page: HelpManualPageData) {
        // 更新标题和描述 - 直接更新不带动画
        UIView.performWithoutAnimation {
            titleLabel.text = page.title
            updateDescriptionText(page.description, isPage5: page.hasQRCode)
        }
        
        // 更新背景
        backgroundImageView.alpha = page.hasBackgroundImage ? 1.0 : 0.0
        
        // 更新二维码
        qrCodeImageView.alpha = page.hasQRCode ? 1.0 : 0.0
        
        // 更新图标
        if page.icons.isEmpty {
            connectionDiagramContainer.alpha = 0
        } else {
            connectionDiagramContainer.alpha = 1
            
            for iconData in page.icons {
                let scaledWidth = scale(iconData.width, basedOn: view.bounds.width, designDimension: designWidth)
                let scaledHeight = scale(iconData.height, basedOn: view.bounds.height, designDimension: designHeight)
                
                switch iconData.type {
                case .left:
                    leftIconView.image = UIImage(named: iconData.imageName)
                    leftIconWidthConstraint?.constant = scaledWidth
                    leftIconHeightConstraint?.constant = scaledHeight
                case .middle:
                    dashedLineWidthConstraint?.constant = scaledWidth
                case .right:
                    rightIconView.image = UIImage(named: iconData.imageName)
                    rightIconWidthConstraint?.constant = scaledWidth
                    rightIconHeightConstraint?.constant = scaledHeight
                }
            }
        }
        
        view.layoutIfNeeded()
    }
    
    private func updateDescriptionText(_ text: String, isPage5: Bool) {
        let descriptionFontSize = scale(designDescriptionFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        let lineSpacing = scale(designDescriptionLineSpacing, basedOn: view.bounds.height, designDimension: designHeight)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.alignment = .left
        
        if isPage5 {
            // 第5页需要添加蓝色链接
            let websiteLink = "www.mindora316.com"
            let fullText = text + " " + websiteLink
            let attributedString = NSMutableAttributedString(string: fullText)
            
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedString.length))
            attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: descriptionFontSize, weight: .regular), range: NSRange(location: 0, length: attributedString.length))
            attributedString.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(location: 0, length: attributedString.length))
            
            if let range = fullText.range(of: websiteLink) {
                let nsRange = NSRange(range, in: fullText)
                attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: nsRange)
            }
            
            descriptionLabel.attributedText = attributedString
        } else {
            let attributedString = NSMutableAttributedString(string: text)
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedString.length))
            attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: descriptionFontSize, weight: .regular), range: NSRange(location: 0, length: attributedString.length))
            descriptionLabel.attributedText = attributedString
        }
    }
    
    private func updatePageIndicators() {
        let dotSize = scale(designPageControlDotSize, basedOn: view.bounds.height, designDimension: designHeight)
        let dotWidth = scale(designPageControlDotWidth, basedOn: view.bounds.width, designDimension: designWidth)
        
        for (index, indicator) in pageIndicators.enumerated() {
            let isSelected = index == currentPageIndex
            
            UIView.animate(withDuration: 0.3) {
                indicator.alpha = isSelected ? 1.0 : 0.6
                
                // 更新宽度约束
                indicator.constraints.forEach { constraint in
                    if constraint.firstAttribute == .width {
                        constraint.constant = isSelected ? dotWidth : dotSize
                    }
                }
                
                indicator.layer.cornerRadius = isSelected ? (dotSize / 2) : (dotSize / 2)
                self.view.layoutIfNeeded()
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        switch gesture.direction {
        case .left:
            moveToNextPage()
        case .right:
            moveToPreviousPage()
        default:
            break
        }
    }
    
    @objc private func connectLabelTapped() {
        print("🔵 HelpManualUnifiedViewController: connectLabelTapped 被调用")
        print("🔵 Delegate: \(String(describing: delegate))")
        delegate?.helpManualDidTapConnect(self)
    }
    
    @objc private func descriptionLabelTapped(_ gesture: UITapGestureRecognizer) {
        // 只在第5页(有网站链接)时处理点击
        guard currentPageIndex == 4 else { return }
        
        let websiteLink = "www.mindora316.com"
        guard let attributedText = descriptionLabel.attributedText else { return }
        
        let fullText = attributedText.string
        guard let linkRange = fullText.range(of: websiteLink) else { return }
        
        // 获取点击位置
        let location = gesture.location(in: descriptionLabel)
        
        // 创建 NSTextContainer 和 NSLayoutManager 来计算文字布局
        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: descriptionLabel.bounds.size)
        
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = descriptionLabel.numberOfLines
        textContainer.lineBreakMode = descriptionLabel.lineBreakMode
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // 获取点击的字符索引
        let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        // 检查是否点击了链接范围
        let nsRange = NSRange(linkRange, in: fullText)
        if NSLocationInRange(characterIndex, nsRange) {
            print("🔗 点击了网站链接: \(websiteLink)")
            // 使用 SFSafariViewController 在应用内打开网页
            guard let url = URL(string: "https://\(websiteLink)") else { return }
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .pageSheet
            present(safariVC, animated: true)
        }
    }
    
    // MARK: - Public Methods
    
    func moveToNextPage() {
        let nextIndex = min(currentPageIndex + 1, pageData.count - 1)
        if nextIndex != currentPageIndex {
            updateContent(for: nextIndex, animated: true)
        }
    }
    
    func moveToPreviousPage() {
        let previousIndex = max(currentPageIndex - 1, 0)
        if previousIndex != currentPageIndex {
            updateContent(for: previousIndex, animated: true)
        }
    }
    
    func moveToPage(_ index: Int, animated: Bool = true) {
        guard index >= 0 && index < pageData.count else { return }
        if index != currentPageIndex {
            updateContent(for: index, animated: animated)
        }
    }
    
    func getCurrentPageIndex() -> Int {
        return currentPageIndex
    }
}

// MARK: - Delegate Protocol

protocol HelpManualUnifiedViewControllerDelegate: AnyObject {
    func helpManualDidTapConnect(_ controller: HelpManualUnifiedViewController)
}
