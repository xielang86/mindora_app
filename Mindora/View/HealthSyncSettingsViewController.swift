//
//  HealthSyncSettingsViewController.swift
//  mindora
//
//  重构日期: 2025/10/21
//
//  健康同步设置页面控制器 - 严格按照设计图实现
//  设计稿尺寸: 1242 × 2688 px (@3x, iPhone X/XS Max)
//  换算方式: 使用百分比适配不同屏幕
//

import UIKit

final class HealthSyncSettingsViewController: UIViewController {
    
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 设计稿中的像素值 - 顶部标题
    private let designTitleTop: CGFloat = DesignConstants.titleTopMargin  // "健康数据同步设置" 距离顶部
    private let designTitleFontSize: CGFloat = DesignConstants.titleFontSize  // 标题字体大小
    private let designTitleLeading: CGFloat = 116       // 标题距离屏幕左边
    
    // 设计稿中的像素值 - 返回按钮
    private let designBackButtonTop: CGFloat = 186      // 返回按钮距离屏幕顶部
    private let designBackButtonLeading: CGFloat = 85   // 返回按钮距离左边
    private let designBackButtonSize: CGFloat = 27      // 返回按钮图标宽度
    private let designBackButtonHeight: CGFloat = DesignConstants.subtitleFontSize  // 返回按钮图标高度
    
    // 设计稿中的像素值 - 开启同步项
    private let designEnableSyncTop: CGFloat = 85       // 开启同步项距离标题底部
    private let designEnableSyncHeight: CGFloat = 265   // 开启同步项高度
    private let designEnableSyncTextLeading: CGFloat = 116  // 文字距离左边
    private let designEnableSyncTextFontSize: CGFloat = 52  // 文字字体大小
    private let designEnableSyncIconSize: CGFloat = DesignConstants.subtitleFontSize  // checkmark图标尺寸
    private let designEnableSyncIconTrailing: CGFloat = 119 // checkmark距离右边
    
    // 设计稿中的像素值 - 同步周期部分
    private let designIntervalTop: CGFloat = 0          // 同步周期距离开启同步底部
    private let designIntervalHeight: CGFloat = 363     // 同步周期区域高度
    private let designIntervalVerticalPadding: CGFloat = 74  // "同步周期"文字距离容器顶部（上下边距相等）
    private let designIntervalTextLeading: CGFloat = 116    // "同步周期"文字距离左边
    private let designIntervalTextFontSize: CGFloat = 52   // "同步周期"文字字体大小
    private let designSegmentTop: CGFloat = 52          // 分段控件距离"同步周期"文字底部
    private let designSegmentWidth: CGFloat = 999       // 分段控件宽度（外层大圆角矩形）
    private let designSegmentHeight: CGFloat = 111      // 分段控件高度（外层大圆角矩形）
    private let designSegmentCornerRadius: CGFloat = 55 // 分段控件圆角（外层大圆角矩形）
    private let designSegmentFontSize: CGFloat = 42     // 分段控件字体大小
    
    // 设计稿中的像素值 - 指标项
    private let designMetricItemHeight: CGFloat = 265   // 每个指标项高度
    private let designMetricTextLeading: CGFloat = 116  // 指标名称距离左边
    private let designMetricTextFontSize: CGFloat = 52  // 指标名称字体大小
    private let designMetricIconSize: CGFloat = DesignConstants.subtitleFontSize  // 指标右侧图标尺寸
    private let designMetricIconTrailing: CGFloat = 119 // 指标右侧图标距离右边
    
    // 计算实际尺寸的辅助方法
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    // MARK: - Properties
    private var lastProgress: HealthSyncService.SyncProgress? { didSet { updateStatus() } }
    
    // MARK: - UI Components
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.showsVerticalScrollIndicator = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 返回按钮
    private let backButton: UIButton = {
        let button = ExpandedTouchButton(type: .custom)
        button.setImage(UIImage(named: "back_icon"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.contentHorizontalAlignment = .left
        button.contentVerticalAlignment = .center
        button.translatesAutoresizingMaskIntoConstraints = false
        // 设置扩展的点击区域（不影响视觉大小）
        button.touchAreaInsets = UIEdgeInsets(top: -10, left: 0, bottom: -10, right: -20)
        return button
    }()
    
    // 标题
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.sync.title")
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 开启同步容器
    private let enableSyncContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let enableSyncLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.sync.enable")
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let enableSyncIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "small_checkmark")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.alpha = 0.3  // 默认未选中状态
        return imageView
    }()
    
    // 顶部分隔线
    private let topSeparator: UIView = {
        let view = UIView()
        view.backgroundColor = DesignConstants.separatorColor
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true  // 不显示第一个单元格顶部的分割线
        return view
    }()
    
    // 同步周期容器
    private let intervalContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let intervalLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.sync.interval")
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 自定义分段控件容器（外层大圆角矩形）
    private let intervalControl: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 三个选项按钮
    private var intervalButtons: [UIButton] = []
    private var selectedIntervalIndex: Int = 0
    
    // 底部分隔线
    private let bottomSeparator: UIView = {
        let view = UIView()
        view.backgroundColor = DesignConstants.separatorColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 同步周期底部分隔线
    private let intervalBottomSeparator: UIView = {
        let view = UIView()
        view.backgroundColor = DesignConstants.separatorColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 指标项容器
    private var metricItems: [UIView] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        loadConfigIntoUI()
        registerNotifications()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 检查健康权限并显示提醒（如果需要）
        checkHealthPermissionAndShowReminder()
    }

    deinit { NotificationCenter.default.removeObserver(self) }
    
    @objc override func languageDidChange() {
        titleLabel.text = L("health.sync.title")
        enableSyncLabel.text = L("health.sync.enable")
        intervalLabel.text = L("health.sync.interval")
        
        // 更新按钮标题
        let intervals = HealthSyncInterval.allCases.sorted { $0.rawValue < $1.rawValue }
        for (index, button) in intervalButtons.enumerated() {
            if intervals.indices.contains(index) {
                button.setTitle(intervals[index].localizedName, for: .normal)
            }
        }
        
        loadConfigIntoUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 添加所有子视图
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(backButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(topSeparator)
        contentView.addSubview(enableSyncContainer)
        enableSyncContainer.addSubview(enableSyncLabel)
        enableSyncContainer.addSubview(enableSyncIcon)
        contentView.addSubview(bottomSeparator)
        contentView.addSubview(intervalContainer)
        intervalContainer.addSubview(intervalLabel)
        intervalContainer.addSubview(intervalControl)
        contentView.addSubview(intervalBottomSeparator)
        
        setupStyles()
        createMetricItems()
        setupConstraints()
    }
    
    private func setupStyles() {
        // 标题字体 - 按设计稿比例计算
        let titleFontSize = scale(designTitleFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = UIFont.systemFont(ofSize: titleFontSize, weight: .regular)
        
        // 开启同步文字字体
        let enableSyncFontSize = scale(designEnableSyncTextFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        enableSyncLabel.font = UIFont.systemFont(ofSize: enableSyncFontSize, weight: .regular)
        
        // 同步周期文字字体
        let intervalFontSize = scale(designIntervalTextFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        intervalLabel.font = UIFont.systemFont(ofSize: intervalFontSize, weight: .regular)
        
        // 创建自定义分段控件
        setupCustomSegmentControl()
    }
    
    private func setupCustomSegmentControl() {
        let segmentFontSize = scale(designSegmentFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        let segmentCornerRadius = scale(designSegmentCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 外层大圆角矩形：透明背景 + 白色描边
        intervalControl.backgroundColor = .clear
        intervalControl.layer.cornerRadius = segmentCornerRadius
        intervalControl.layer.borderWidth = 0.5  // 白色描边宽度（根据设计稿0.5pt）
        intervalControl.layer.borderColor = UIColor.white.cgColor
        intervalControl.clipsToBounds = true
        
        // 创建三个按钮
        let intervals = HealthSyncInterval.allCases.sorted { $0.rawValue < $1.rawValue }
        intervalButtons.removeAll()
        
        for (index, interval) in intervals.enumerated() {
            let button = UIButton(type: .custom)
            button.setTitle(interval.localizedName, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: segmentFontSize, weight: .regular)
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTarget(self, action: #selector(intervalButtonTapped(_:)), for: .touchUpInside)
            
            intervalControl.addSubview(button)
            intervalButtons.append(button)
        }
        
        // 布局三个按钮（均匀分布在大圆角矩形内，左右对称）
        let buttonWidth = 310.0  // 设计稿中的按钮宽度
        let containerWidth = 999.0  // 外层大圆角矩形宽度
        
        // 三个按钮均匀分布：
        // 容器分成3等份，每个按钮在各自区域内居中
        // 每个区域宽度 = 999 / 3 = 333px
        let sectionWidth = containerWidth / 3
        
        let scaledButtonWidth = scale(buttonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let scaledSectionWidth = scale(sectionWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonHeight = scale(89, basedOn: view.bounds.height, designDimension: designHeight)
        let buttonCornerRadius = scale(44.5, basedOn: view.bounds.height, designDimension: designHeight)
        
        for (index, button) in intervalButtons.enumerated() {
            button.layer.cornerRadius = buttonCornerRadius
            button.clipsToBounds = true
            
            NSLayoutConstraint.activate([
                button.centerYAnchor.constraint(equalTo: intervalControl.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: scaledButtonWidth),
                button.heightAnchor.constraint(equalToConstant: buttonHeight)
            ])
            
            // 均匀分布：每个按钮在各自的1/3区域内居中
            // 左侧按钮：第一个区域的中心 = -333
            // 中间按钮：第二个区域的中心 = 0
            // 右侧按钮：第三个区域的中心 = +333
            
            if index == 0 {
                // 左侧按钮：在左侧1/3区域居中
                button.centerXAnchor.constraint(equalTo: intervalControl.centerXAnchor, constant: -scaledSectionWidth).isActive = true
            } else if index == 1 {
                // 中间按钮：在中间1/3区域居中
                button.centerXAnchor.constraint(equalTo: intervalControl.centerXAnchor).isActive = true
            } else {
                // 右侧按钮：在右侧1/3区域居中
                button.centerXAnchor.constraint(equalTo: intervalControl.centerXAnchor, constant: scaledSectionWidth).isActive = true
            }
        }
    }
    
    private func createMetricItems() {
        // 为每个指标创建UI项
        let totalCount = HealthMetricKey.allCases.count
        for (index, key) in HealthMetricKey.allCases.enumerated() {
            let isFirst = (index == 0)
            let isLast = (index == totalCount - 1)
            let itemView = createMetricItem(key: key, showTopSeparator: !isFirst, showBottomSeparator: !isLast)
            contentView.addSubview(itemView)
            metricItems.append(itemView)
        }
    }
    
    private func createMetricItem(key: HealthMetricKey, showTopSeparator: Bool, showBottomSeparator: Bool) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.translatesAutoresizingMaskIntoConstraints = false
        container.tag = tagForMetricKey(key)
        
        // 顶部分隔线（如果需要）
        if showTopSeparator {
            let separator = UIView()
            separator.backgroundColor = DesignConstants.separatorColor
            separator.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(separator)
            
            let separatorMargin = scale(DesignConstants.separatorHorizontalMargin, basedOn: view.bounds.width, designDimension: designWidth)
            let separatorHeight: CGFloat = 1
            NSLayoutConstraint.activate([
                separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: separatorMargin),
                separator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -separatorMargin),
                separator.topAnchor.constraint(equalTo: container.topAnchor),
                separator.heightAnchor.constraint(equalToConstant: separatorHeight)
            ])
        }
        
        // 指标名称
        let nameLabel = UILabel()
        nameLabel.text = key.localizedName
        nameLabel.textColor = .white
        let metricFontSize = scale(designMetricTextFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        nameLabel.font = UIFont.systemFont(ofSize: metricFontSize, weight: .regular)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)
        
        // 右侧圆形选择图标
        let iconView = CircleSelectionView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isSelected = false  // 默认未选中状态
        iconView.tag = 100  // 用于后续查找
        container.addSubview(iconView)
        
        // 底部分隔线（如果需要）
        if showBottomSeparator {
            let bottomSeparator = UIView()
            bottomSeparator.backgroundColor = DesignConstants.separatorColor
            bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(bottomSeparator)
        }
        
        // 计算实际尺寸
        let textLeading = scale(designMetricTextLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let iconSize = scale(designMetricIconSize, basedOn: view.bounds.width, designDimension: designWidth)
        let iconTrailing = scale(designMetricIconTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        let separatorHeight: CGFloat = 1
        
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: textLeading),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),
            iconView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -iconTrailing),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        // 底部分隔线约束（如果需要）
        if showBottomSeparator, let bottomSeparator = container.subviews.last(where: { $0 != nameLabel && $0 != iconView }) {
            let separatorMargin = scale(DesignConstants.separatorHorizontalMargin, basedOn: view.bounds.width, designDimension: designWidth)
            NSLayoutConstraint.activate([
                bottomSeparator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: separatorMargin),
                bottomSeparator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -separatorMargin),
                bottomSeparator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                bottomSeparator.heightAnchor.constraint(equalToConstant: separatorHeight)
            ])
        }
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(metricItemTapped(_:)))
        container.addGestureRecognizer(tapGesture)
        container.isUserInteractionEnabled = true
        
        return container
    }
    
    private func tagForMetricKey(_ key: HealthMetricKey) -> Int {
        return 1000 + HealthMetricKey.allCases.firstIndex(of: key)!
    }
    
    private func metricKeyForTag(_ tag: Int) -> HealthMetricKey? {
        let index = tag - 1000
        guard index >= 0 && index < HealthMetricKey.allCases.count else { return nil }
        return HealthMetricKey.allCases[index]
    }

    private func setupConstraints() {
        // 计算实际尺寸
        let backButtonTop = scale(designBackButtonTop, basedOn: view.bounds.height, designDimension: designHeight)
        let backButtonLeading = scale(designBackButtonLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let backButtonSize = scale(designBackButtonSize, basedOn: view.bounds.width, designDimension: designWidth)
        let backButtonHeight = scale(designBackButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        
        let titleTop = scale(designTitleTop, basedOn: view.bounds.height, designDimension: designHeight)
        let titleLeading = scale(designTitleLeading, basedOn: view.bounds.width, designDimension: designWidth)
        
        let enableSyncTop = scale(designEnableSyncTop, basedOn: view.bounds.height, designDimension: designHeight)
        let enableSyncHeight = scale(designEnableSyncHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let enableSyncTextLeading = scale(designEnableSyncTextLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let enableSyncIconSize = scale(designEnableSyncIconSize, basedOn: view.bounds.width, designDimension: designWidth)
        let enableSyncIconTrailing = scale(designEnableSyncIconTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        
        let intervalTop = scale(designIntervalTop, basedOn: view.bounds.height, designDimension: designHeight)
        let intervalHeight = scale(designIntervalHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let intervalVerticalPadding = scale(designIntervalVerticalPadding, basedOn: view.bounds.height, designDimension: designHeight)
        let intervalTextLeading = scale(designIntervalTextLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let segmentTop = scale(designSegmentTop, basedOn: view.bounds.height, designDimension: designHeight)
        let segmentWidth = scale(designSegmentWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let segmentHeight = scale(designSegmentHeight, basedOn: view.bounds.height, designDimension: designHeight)
        
        let metricItemHeight = scale(designMetricItemHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let separatorHeight: CGFloat = 1
        
        // ScrollView 和 ContentView
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // 返回按钮（保持原始视觉尺寸，点击区域通过 ExpandedTouchButton 扩展）
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: backButtonTop),
            backButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: backButtonLeading),
            backButton.widthAnchor.constraint(equalToConstant: backButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: backButtonHeight)
        ])
        
        // 标题
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: titleTop),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: titleLeading)
        ])
        
        // 顶部分隔线
        let separatorMargin = scale(DesignConstants.separatorHorizontalMargin, basedOn: view.bounds.width, designDimension: designWidth)
        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: enableSyncTop),
            topSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: separatorMargin),
            topSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -separatorMargin),
            topSeparator.heightAnchor.constraint(equalToConstant: separatorHeight)
        ])
        
        // 开启同步容器
        NSLayoutConstraint.activate([
            enableSyncContainer.topAnchor.constraint(equalTo: topSeparator.bottomAnchor),
            enableSyncContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            enableSyncContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            enableSyncContainer.heightAnchor.constraint(equalToConstant: enableSyncHeight),
            
            enableSyncLabel.leadingAnchor.constraint(equalTo: enableSyncContainer.leadingAnchor, constant: enableSyncTextLeading),
            enableSyncLabel.centerYAnchor.constraint(equalTo: enableSyncContainer.centerYAnchor),
            
            enableSyncIcon.widthAnchor.constraint(equalToConstant: enableSyncIconSize),
            enableSyncIcon.heightAnchor.constraint(equalToConstant: enableSyncIconSize),
            enableSyncIcon.trailingAnchor.constraint(equalTo: enableSyncContainer.trailingAnchor, constant: -enableSyncIconTrailing),
            enableSyncIcon.centerYAnchor.constraint(equalTo: enableSyncContainer.centerYAnchor)
        ])
        
        // 底部分隔线
        NSLayoutConstraint.activate([
            bottomSeparator.topAnchor.constraint(equalTo: enableSyncContainer.bottomAnchor),
            bottomSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: separatorMargin),
            bottomSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -separatorMargin),
            bottomSeparator.heightAnchor.constraint(equalToConstant: separatorHeight)
        ])
        
        // 同步周期容器
        NSLayoutConstraint.activate([
            intervalContainer.topAnchor.constraint(equalTo: bottomSeparator.bottomAnchor, constant: intervalTop),
            intervalContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            intervalContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            intervalContainer.heightAnchor.constraint(equalToConstant: intervalHeight),
            
            // "同步周期"文字距离容器顶部 = intervalVerticalPadding（上下边距相等）
            intervalLabel.topAnchor.constraint(equalTo: intervalContainer.topAnchor, constant: intervalVerticalPadding),
            intervalLabel.leadingAnchor.constraint(equalTo: intervalContainer.leadingAnchor, constant: intervalTextLeading),
            
            intervalControl.topAnchor.constraint(equalTo: intervalLabel.bottomAnchor, constant: segmentTop),
            intervalControl.centerXAnchor.constraint(equalTo: intervalContainer.centerXAnchor),
            intervalControl.widthAnchor.constraint(equalToConstant: segmentWidth),
            intervalControl.heightAnchor.constraint(equalToConstant: segmentHeight)
        ])
        
        // 同步周期底部分隔线
        NSLayoutConstraint.activate([
            intervalBottomSeparator.topAnchor.constraint(equalTo: intervalContainer.bottomAnchor),
            intervalBottomSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: separatorMargin),
            intervalBottomSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -separatorMargin),
            intervalBottomSeparator.heightAnchor.constraint(equalToConstant: separatorHeight)
        ])
        
        // 指标项
        var previousView: UIView = intervalBottomSeparator
        for itemView in metricItems {
            NSLayoutConstraint.activate([
                itemView.topAnchor.constraint(equalTo: previousView.bottomAnchor),
                itemView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                itemView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                itemView.heightAnchor.constraint(equalToConstant: metricItemHeight)
            ])
            previousView = itemView
        }
        
        // 设置 contentView 的底部约束
        if let lastItem = metricItems.last {
            NSLayoutConstraint.activate([
                lastItem.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
            ])
        }
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        let enableSyncTap = UITapGestureRecognizer(target: self, action: #selector(enableSyncTapped))
        enableSyncContainer.addGestureRecognizer(enableSyncTap)
        enableSyncContainer.isUserInteractionEnabled = true
    }
    
    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: LocalizationManager.languageDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(progress(_:)),
            name: HealthSyncService.progressNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configExternalChanged(_:)),
            name: HealthSyncConfigStore.configDidChangeNotification,
            object: nil
        )
    }

    private func loadConfigIntoUI() {
        let cfg = HealthSyncConfigStore.shared.current
        
        // 更新开启同步图标状态（使用对勾图标）
        enableSyncIcon.alpha = cfg.enabled ? 1.0 : 0.3
        
        // 更新分段控件选择
        let intervals = HealthSyncInterval.allCases.sorted { $0.rawValue < $1.rawValue }
        if let idx = intervals.firstIndex(of: cfg.interval) {
            selectedIntervalIndex = idx
            updateIntervalButtonsAppearance()
        } else {
            selectedIntervalIndex = 0
            updateIntervalButtonsAppearance()
        }
        
        // 更新指标项图标状态
        for itemView in metricItems {
            guard let key = metricKeyForTag(itemView.tag),
                  let iconView = itemView.viewWithTag(100) as? CircleSelectionView else { continue }
            let isEnabled = cfg.metrics.contains(key)
            iconView.isSelected = isEnabled
        }
        
        // 根据开启状态设置UI可用性
        intervalControl.isUserInteractionEnabled = cfg.enabled
        intervalContainer.alpha = cfg.enabled ? 1.0 : 0.5
        
        for itemView in metricItems {
            itemView.alpha = cfg.enabled ? 1.0 : 0.5
            itemView.isUserInteractionEnabled = cfg.enabled
        }
    }
    
    private func updateIntervalButtonsAppearance() {
        for (index, button) in intervalButtons.enumerated() {
            if index == selectedIntervalIndex {
                // 选中状态：显示背景色 RGB(59, 58, 58)
                button.backgroundColor = UIColor(red: 59/255.0, green: 58/255.0, blue: 58/255.0, alpha: 1.0)
            } else {
                // 未选中状态：透明背景
                button.backgroundColor = .clear
            }
        }
    }

    private func updateStatus() {
        // 状态更新逻辑（如果需要显示状态信息可在此添加）
    }

    // MARK: - Actions
    
    @objc private func backButtonTapped() {
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc private func enableSyncTapped() {
        var cfg = HealthSyncConfigStore.shared.current
        cfg.enabled = !cfg.enabled
        HealthSyncConfigStore.shared.save(cfg)
        HealthSyncService.shared.startIfNeeded()
        loadConfigIntoUI()
    }

    @objc private func intervalButtonTapped(_ sender: UIButton) {
        let newIndex = sender.tag
        guard newIndex != selectedIntervalIndex else { return }
        
        selectedIntervalIndex = newIndex
        updateIntervalButtonsAppearance()
        
        let intervals = HealthSyncInterval.allCases.sorted { $0.rawValue < $1.rawValue }
        guard intervals.indices.contains(newIndex) else { return }
        
        var cfg = HealthSyncConfigStore.shared.current
        cfg.interval = intervals[newIndex]
        HealthSyncConfigStore.shared.save(cfg)
        HealthSyncService.shared.startIfNeeded()
    }

    @objc private func metricItemTapped(_ gesture: UITapGestureRecognizer) {
        guard let itemView = gesture.view,
              let key = metricKeyForTag(itemView.tag),
              let iconView = itemView.viewWithTag(100) as? CircleSelectionView else { return }
        
        var cfg = HealthSyncConfigStore.shared.current
        if cfg.metrics.contains(key) {
            cfg.metrics.remove(key)
            iconView.isSelected = false
        } else {
            cfg.metrics.insert(key)
            iconView.isSelected = true
        }
        HealthSyncConfigStore.shared.save(cfg)
    }

    @objc private func progress(_ note: Notification) {
        guard let p = note.object as? HealthSyncService.SyncProgress else { return }
        lastProgress = p
    }

    @objc private func configExternalChanged(_ note: Notification) {
        loadConfigIntoUI()
    }
    
    // MARK: - Permission Check
    
    /// 检查健康权限并显示提醒（如果需要）
    private func checkHealthPermissionAndShowReminder() {
        Task { @MainActor in
            // 检查是否应该显示提醒（异步，避免阻塞主线程）
            guard await PermissionManager.shared.shouldShowHealthReminder() else { return }

            // 延迟显示，避免与页面加载动画冲突
            try? await Task.sleep(nanoseconds: 500_000_000)
            PermissionManager.shared.showHealthPermissionReminder(from: self) { [weak self] in
                // 权限授权后重新加载配置
                self?.loadConfigIntoUI()
            }
        }
    }
}

// MARK: - CircleSelectionView

/// 自定义圆形选择指示器视图
/// 未选中：空心圆圈（白色描边）
/// 选中：内部填充的圆圈
final class CircleSelectionView: UIView {
    
    var isSelected: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2 - 2  // 留出描边空间
        
        if isSelected {
            // 选中状态：绘制外圈（白色描边）+ 内部填充的圆
            
            // 外圈（白色描边，1pt宽度）
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(1.0)
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            context.strokePath()
            
            // 内部填充的圆（根据设计稿，填充半径约为外圈的60%）
            let fillRadius = radius * 0.6
            context.setFillColor(UIColor.white.cgColor)
            context.addArc(center: center, radius: fillRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            context.fillPath()
        } else {
            // 未选中状态：只绘制空心圆圈（白色描边）
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(1.0)
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            context.strokePath()
        }
    }
}

// MARK: - ExpandedTouchButton

/// 自定义按钮，可扩展点击区域而不改变视觉大小
final class ExpandedTouchButton: UIButton {
    /// 扩展的点击区域（负值表示向外扩展）
    var touchAreaInsets: UIEdgeInsets = .zero
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // 如果没有设置扩展区域，使用默认行为
        if touchAreaInsets == .zero {
            return super.point(inside: point, with: event)
        }
        
        // 计算扩展后的点击区域
        let expandedBounds = bounds.inset(by: touchAreaInsets)
        return expandedBounds.contains(point)
    }
}
