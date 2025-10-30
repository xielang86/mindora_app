//
//  PermissionViewController.swift
//  mindora
//
//  Created by GitHub Copilot on 2025/10/14.
//  重构日期: 2025/10/21
//
//  权限管理页面控制器 - 严格按照设计图实现
//  设计稿尺寸: 1242 × 2688 px (@3x, iPhone X/XS Max)
//  换算方式: 使用百分比适配不同屏幕
//

import UIKit
import HealthKit

final class PermissionViewController: UIViewController {
    
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 设计稿中的像素值 - 标题部分
    private let designTitleBottom: CGFloat = 436        // 标题文字底部距离屏幕顶部 436px（根据设计稿要求）
    private let designTitleLeading: CGFloat = 116       // 标题距离左边（根据设计稿）
    private let designTitleFontSize: CGFloat = DesignConstants.titleFontSize  // 标题字体大小（根据设计稿）
    
    // 设计稿中的像素值 - 返回按钮
    private let designBackButtonTop: CGFloat = 186      // 返回按钮距离屏幕顶部
    private let designBackButtonLeading: CGFloat = 116  // 返回按钮距离屏幕左边
    private let designBackButtonWidth: CGFloat = 54     // 返回按钮图标宽度
    private let designBackButtonHeight: CGFloat = DesignConstants.subtitleFontSize  // 返回按钮图标高度（改为与宽度相同，形成正方形点击区域）
    
    // 设计稿中的像素值 - 权限卡片容器
    private let designFirstItemTop: CGFloat = 85        // 第一个权限项距离标题底部
    private let designItemHeight: CGFloat = 265         // 每个权限项的高度
    private let designIconLeading: CGFloat = 116         // 图标距离左边（根据截图实际测量）
    private let designTextLeading: CGFloat = 40         // 文字距离图标右边
    private let designTextFontSize: CGFloat = 52        // 权限名称字体大小
    private let designStatusFontSize: CGFloat = 42      // 状态文字字体大小
    private let designArrowSize: CGFloat = 18           // 箭头宽度
    private let designArrowHeight: CGFloat = 36         // 箭头高度
    private let designArrowTrailing: CGFloat = 119      // 箭头距离右边
    
    // 设计稿中的像素值 - 图标统一高度
    private let designIconHeight: CGFloat = 59              // 所有图标统一高度，宽度由原始比例自动调整
    
    // 设计稿中的像素值 - 底部说明文字
    private let designFooterTop: CGFloat = 59           // 第一行文字顶部距离表格底部
    private let designFooterLeading: CGFloat = 85       // 说明文字距离左边和右边
    private let designFooterLine1ToLine2: CGFloat = 40  // 第二行距离第一行的间距
    private let designFooterFontSize: CGFloat = 42      // 说明文字字体大小
    private let designFooterLine2Spacing: CGFloat = 12  // 第二段文字内部的行间距
    
    // 计算实际尺寸的辅助方法
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    // MARK: - Properties
    private var networkStatuses: [PermissionType: PermissionStatus] = [:]
    private var healthStatus: PermissionStatus = .notDetermined
    private var bluetoothStatus: PermissionStatus = .notDetermined
    
    private enum PermissionType {
        case bluetooth
        case localNetwork
        case cellularData
        case health
    }
    
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
        label.text = L("permission.title")
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 权限项容器
    private var permissionItems: [UIView] = []
    
    // 底部说明文字 - 第一部分
    private let footerLabel1: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(white: 1.0, alpha: 0.3)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 底部说明文字 - 第二部分
    private let footerLabel2: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(white: 1.0, alpha: 0.3)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        reloadPermissionStates(force: true)
        
        // 监听语言变更
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: LocalizationManager.languageDidChangeNotification,
            object: nil
        )
        
        // 监听应用从后台返回，刷新权限状态
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPermissions),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        // 每次页面即将显示时刷新权限状态
        reloadPermissionStates(force: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc override func languageDidChange() {
        titleLabel.text = L("permission.title")
        
        // 更新底部说明文字
        updateFooterLabels()
        
        // 重新创建权限项以更新文字
        for item in permissionItems {
            item.removeFromSuperview()
        }
        permissionItems.removeAll()
        createPermissionItems()
    }
    
    @objc private func refreshPermissions() {
        reloadPermissionStates(force: true)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(backButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(footerLabel1)
        contentView.addSubview(footerLabel2)
        
        setupStyles()
        setupConstraints()
        createPermissionItems()
    }
    
    private func setupStyles() {
        // 标题字体
        let titleFontSize = scale(designTitleFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = UIFont.systemFont(ofSize: titleFontSize, weight: .medium)
        
        // 底部说明字体
        let footerFontSize = scale(designFooterFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        footerLabel1.font = UIFont.systemFont(ofSize: footerFontSize, weight: .regular)
        
        // 设置底部文字内容
        updateFooterLabels()
    }
    
    private func updateFooterLabels() {
        let footerFontSize = scale(designFooterFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        let line2Spacing = scale(designFooterLine2Spacing, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 第一行文字
        footerLabel1.text = L("permission.section.healthkit_footer_line1")
        
        // 第二行文字（带行间距）
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = line2Spacing
        paragraphStyle.alignment = .left
        
        let attributedText = NSAttributedString(
            string: L("permission.section.healthkit_footer_line2"),
            attributes: [
                .font: UIFont.systemFont(ofSize: footerFontSize, weight: .regular),
                .foregroundColor: UIColor(white: 1.0, alpha: 0.3),
                .paragraphStyle: paragraphStyle
            ]
        )
        footerLabel2.attributedText = attributedText
    }
    
    private func setupConstraints() {
        let titleBottom = scale(designTitleBottom, basedOn: view.bounds.height, designDimension: designHeight)
        let titleFontSize = scale(designTitleFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        // 标题顶部位置 = 标题底部位置 - 字体大小（近似文字高度）
        let titleTop = titleBottom - titleFontSize
        
        let titleLeading = scale(designTitleLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let backButtonTop = scale(designBackButtonTop, basedOn: view.bounds.height, designDimension: designHeight)
        let backButtonLeading = scale(designBackButtonLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let backButtonWidth = scale(designBackButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let backButtonHeight = scale(designBackButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 返回按钮（保持原始视觉尺寸，点击区域通过 ExpandedTouchButton 扩展）
            backButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: backButtonTop),
            backButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: backButtonLeading),
            backButton.widthAnchor.constraint(equalToConstant: backButtonWidth),
            backButton.heightAnchor.constraint(equalToConstant: backButtonHeight),
            
            // 标题 - 通过计算让标题底部距离屏幕顶部 296px
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: titleTop),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: titleLeading)
        ])
    }
    
    private func createPermissionItems() {
        let items: [(type: PermissionType, icon: String, title: String)] = [
            (.bluetooth, "bluetooth_icon", L("permission.bluetooth")),
            (.localNetwork, "local_network", L("permission.local_network")),
            (.cellularData, "wireless_data", L("permission.cellular_data")),
            (.health, "boot-health", L("permission.health.status"))
        ]
        
        let itemHeight = scale(designItemHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let firstItemTop = scale(designFirstItemTop, basedOn: view.bounds.height, designDimension: designHeight)
        
        var previousItem: UIView?
        
        for (index, item) in items.enumerated() {
            let itemView = createPermissionItem(
                type: item.type,
                icon: item.icon,
                title: item.title,
                showTopSeparator: index != 0,
                showBottomSeparator: index == items.count - 1
            )
            contentView.addSubview(itemView)
            permissionItems.append(itemView)
            
            NSLayoutConstraint.activate([
                itemView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                itemView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                itemView.heightAnchor.constraint(equalToConstant: itemHeight)
            ])
            
            if index == 0 {
                itemView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: firstItemTop).isActive = true
            } else if let previous = previousItem {
                itemView.topAnchor.constraint(equalTo: previous.bottomAnchor).isActive = true
            }
            
            previousItem = itemView
        }
        
        // 底部说明文字约束
        let footerTop = scale(designFooterTop, basedOn: view.bounds.height, designDimension: designHeight)
        let footerLeading = scale(designFooterLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let line1ToLine2 = scale(designFooterLine1ToLine2, basedOn: view.bounds.height, designDimension: designHeight)
        
        if let lastItem = previousItem {
            NSLayoutConstraint.activate([
                // 第一部分文字
                footerLabel1.topAnchor.constraint(equalTo: lastItem.bottomAnchor, constant: footerTop),
                footerLabel1.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: footerLeading),
                footerLabel1.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -footerLeading),
                
                // 第二部分文字
                footerLabel2.topAnchor.constraint(equalTo: footerLabel1.bottomAnchor, constant: line1ToLine2),
                footerLabel2.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: footerLeading),
                footerLabel2.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -footerLeading),
                
                // 内容视图底部约束
                contentView.bottomAnchor.constraint(equalTo: footerLabel2.bottomAnchor, constant: 100)
            ])
        }
    }
    
    private func createPermissionItem(type: PermissionType, icon: String, title: String, showTopSeparator: Bool, showBottomSeparator: Bool = false) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 顶部分隔线
        if showTopSeparator {
            let separator = UIView()
            separator.backgroundColor = DesignConstants.separatorColor
            separator.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(separator)
            
            let separatorMargin = scale(DesignConstants.separatorHorizontalMargin, basedOn: view.bounds.width, designDimension: designWidth)
            NSLayoutConstraint.activate([
                separator.topAnchor.constraint(equalTo: containerView.topAnchor),
                separator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: separatorMargin),
                separator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -separatorMargin),
                separator.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        
        // 底部分隔线
        if showBottomSeparator {
            let bottomSeparator = UIView()
            bottomSeparator.backgroundColor = DesignConstants.separatorColor
            bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(bottomSeparator)
            
            let separatorMargin = scale(DesignConstants.separatorHorizontalMargin, basedOn: view.bounds.width, designDimension: designWidth)
            NSLayoutConstraint.activate([
                bottomSeparator.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                bottomSeparator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: separatorMargin),
                bottomSeparator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -separatorMargin),
                bottomSeparator.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        
        // 图标 - 使用容器来精确控制对齐
        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = .clear
        containerView.addSubview(iconContainer)
        
        let iconView = UIImageView()
        iconView.image = UIImage(named: icon)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // 状态标签
        let statusLabel = UILabel()
        statusLabel.textColor = .white
        statusLabel.textAlignment = .right
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.tag = 100  // 用于后续更新
        containerView.addSubview(statusLabel)
        
        // 箭头
        let arrowView = UIImageView()
        arrowView.image = UIImage(named: "enter_icon")
        arrowView.contentMode = .scaleAspectFit
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(arrowView)
        
        // 设置字体
        let textFontSize = scale(designTextFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = UIFont.systemFont(ofSize: textFontSize, weight: .regular)
        
        let statusFontSize = scale(designStatusFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        statusLabel.font = UIFont.systemFont(ofSize: statusFontSize, weight: .regular)
        
        // 获取图标的统一高度
        let scaledIconHeight = scale(designIconHeight, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 设置约束
        let iconLeading = scale(designIconLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let textLeading = scale(designTextLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let arrowWidth = scale(designArrowSize, basedOn: view.bounds.width, designDimension: designWidth)
        let arrowHeight = scale(designArrowHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let arrowTrailing = scale(designArrowTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        
        NSLayoutConstraint.activate([
            // 图标容器 - 精确定位,与页面标题对齐
            iconContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: iconLeading),
            iconContainer.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconContainer.heightAnchor.constraint(equalToConstant: scaledIconHeight),
            iconContainer.widthAnchor.constraint(equalToConstant: scaledIconHeight), // 正方形容器
            
            // 图标在容器内居中或左对齐,确保视觉对齐
            iconView.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.heightAnchor.constraint(lessThanOrEqualTo: iconContainer.heightAnchor),
            iconView.widthAnchor.constraint(lessThanOrEqualTo: iconContainer.widthAnchor),
            
            // 标题 - 相对于图标容器右侧定位
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: textLeading),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // 箭头
            arrowView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -arrowTrailing),
            arrowView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            arrowView.widthAnchor.constraint(equalToConstant: arrowWidth),
            arrowView.heightAnchor.constraint(equalToConstant: arrowHeight),
            
            // 状态标签
            statusLabel.trailingAnchor.constraint(equalTo: arrowView.leadingAnchor, constant: -20),
            statusLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 20)
        ])
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(permissionItemTapped(_:)))
        containerView.addGestureRecognizer(tapGesture)
        containerView.isUserInteractionEnabled = true
        containerView.tag = tagForType(type)
        
        // 更新初始状态
        updateStatusLabel(statusLabel, for: type)
        
        return containerView
    }
    
    private func tagForType(_ type: PermissionType) -> Int {
        switch type {
        case .bluetooth: return 0
        case .localNetwork: return 1
        case .cellularData: return 2
        case .health: return 3
        }
    }
    
    private func typeForTag(_ tag: Int) -> PermissionType? {
        switch tag {
        case 0: return .bluetooth
        case 1: return .localNetwork
        case 2: return .cellularData
        case 3: return .health
        default: return nil
        }
    }
    
    private func updateStatusLabel(_ label: UILabel, for type: PermissionType) {
        // 健康数据读取权限无法被系统精确披露，为避免误导用户，这里不显示“已/未授权”状态，统一显示“去健康App确认”。
        if type == .health {
            label.text = L("permission.health.confirm")
            return
        }

        let status: PermissionStatus
        switch type {
        case .bluetooth:
            status = bluetoothStatus
        case .localNetwork:
            status = networkStatuses[.localNetwork] ?? .notDetermined
        case .cellularData:
            status = networkStatuses[.cellularData] ?? .notDetermined
        case .health:
            status = healthStatus // 不会走到这里，已在上方 return
        }

        label.text = status.localizedDescription
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func backButtonTapped() {
        // 尝试通过导航控制器返回
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            // 如果没有导航控制器，尝试 dismiss
            dismiss(animated: true)
        }
    }
    
    @objc private func permissionItemTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view,
              let type = typeForTag(view.tag) else { return }
        
        switch type {
        case .bluetooth:
            handleBluetoothPermissionTap()
        case .localNetwork, .cellularData:
            // 本地网络和蜂窝数据权限：
            // - 这两个权限由系统在首次网络访问时自动触发授权弹窗
            // - 无法通过代码主动请求授权
            // - 用户只能通过系统设置修改权限状态
            PermissionManager.shared.openAppSettings()
        case .health:
            handleHealthPermissionTap()
        }
    }
    
    // MARK: - Permission Actions
    
    private func handleBluetoothPermissionTap() {
        // 检查当前蓝牙权限状态
        let authorization = BluetoothManager.shared.checkBluetoothAuthorization()
        
        switch authorization {
        case .allowedAlways:
            // 已授权：直接打开系统设置
            PermissionManager.shared.openAppSettings()
            
        case .denied:
            // 已拒绝：直接打开系统设置（再次请求无效，系统不会弹窗）
            PermissionManager.shared.openAppSettings()
            
        case .notDetermined:
            // 未确定：首次请求，触发系统授权弹窗
            BluetoothManager.shared.requestBluetoothAuthorization { [weak self] result in
                print("Bluetooth authorization result: \(result)")
                DispatchQueue.main.async {
                    // 刷新权限状态
                    self?.reloadPermissionStates(force: true)
                    
                    // 如果用户拒绝，引导到设置页面
                    if result == .denied {
                        PermissionManager.shared.openAppSettings()
                    }
                }
            }
            
        case .restricted:
            // 受限制：设备不支持或被家长控制限制，打开系统设置
            PermissionManager.shared.openAppSettings()
            
        @unknown default:
            // 未知状态：打开系统设置
            PermissionManager.shared.openAppSettings()
        }
    }
    
    private func handleHealthPermissionTap() {
        if healthStatus == .unavailable {
            // 健康数据不可用（设备/系统不支持），打开应用设置
            PermissionManager.shared.openAppSettings()
            return
        }

        // 不再尝试通过 API 判断读取授权状态；直接请求（若首次会弹窗，否则快速返回），然后引导用户去健康 App 确认。
        Task {
            do {
                try await HealthDataManager.shared.requestAuthorization()
                await MainActor.run { PermissionManager.shared.openHealthApp() }
            } catch {
                // 无论成功与否，都引导用户去健康 App 确认
                await MainActor.run { PermissionManager.shared.openHealthApp() }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func reloadPermissionStates(force: Bool) {
        print("[PermissionViewController] 刷新权限状态，force=\(force)")
        
        // 更新蓝牙状态
        bluetoothStatus = PermissionManager.shared.checkBluetoothPermissionStatus()
        print("[PermissionViewController] 蓝牙状态: \(bluetoothStatus)")
        updateBluetoothStatusUI()
        
        Task { [weak self] in
            guard let self else { return }
            let status = await PermissionManager.shared.getHealthPermissionStatus()
            self.healthStatus = status
            print("[PermissionViewController] 健康状态: \(status)")
            self.updateHealthStatusUI()
        }
        
        PermissionManager.shared.getLocalNetworkStatus(forceRefresh: force) { [weak self] status in
            print("[PermissionViewController] 本地网络状态: \(status)")
            self?.networkStatuses[.localNetwork] = status
            self?.updateNetworkStatusUI(for: .localNetwork)
        }
        
        PermissionManager.shared.getCellularDataStatus(forceRefresh: force) { [weak self] status in
            print("[PermissionViewController] 蜂窝数据状态: \(status)")
            self?.networkStatuses[.cellularData] = status
            self?.updateNetworkStatusUI(for: .cellularData)
        }
    }
    
    private func updateNetworkStatusUI(for type: PermissionType) {
        guard let itemView = permissionItems.first(where: { $0.tag == tagForType(type) }),
              let statusLabel = itemView.viewWithTag(100) as? UILabel else { return }
        
        DispatchQueue.main.async {
            self.updateStatusLabel(statusLabel, for: type)
        }
    }
    
    private func updateHealthStatusUI() {
        guard let itemView = permissionItems.first(where: { $0.tag == tagForType(.health) }),
              let statusLabel = itemView.viewWithTag(100) as? UILabel else { return }
        
        DispatchQueue.main.async {
            self.updateStatusLabel(statusLabel, for: .health)
        }
    }
    
    private func updateBluetoothStatusUI() {
        guard let itemView = permissionItems.first(where: { $0.tag == tagForType(.bluetooth) }),
              let statusLabel = itemView.viewWithTag(100) as? UILabel else { return }
        
        DispatchQueue.main.async {
            self.updateStatusLabel(statusLabel, for: .bluetooth)
        }
    }
}
