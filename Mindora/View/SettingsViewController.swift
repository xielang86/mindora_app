//
//  SettingsViewController.swift
//  mindora
//
//  设置页控制器 - 严格按照设计图实现
//  设计稿尺寸: 1242 × 2688 px (@3x, iPhone X/XS Max)
//  换算方式: 使用百分比适配不同屏幕，参考 OnboardingPage2ViewController
//

import UIKit

final class SettingsViewController: UIViewController {
    
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 设计稿中的像素值 - 列表项
    private let designItemHeight: CGFloat = 265         // 每个选项的高度（按设计稿测量）
    private let designItemLeading: CGFloat = 84         // 选项距离左边
    private let designItemTrailing: CGFloat = 84        // 选项距离右边
    private let designItemTitleFontSize: CGFloat = 52   // 选项标题字体大小（参考设计稿实际像素）
    private let designItemSubtitleFontSize: CGFloat = 42 // 选项副标题字体大小（参考设计稿实际像素）
    private let designItemTitleTop: CGFloat = 78        // 标题距离分隔线顶部
    private let designItemSubtitleTop: CGFloat = 18     // 副标题距离标题
    private let designArrowWidth: CGFloat = 18          // 箭头图标宽度
    private let designArrowHeight: CGFloat = 36         // 箭头图标高度
    private let designArrowTrailing: CGFloat = 119      // 箭头距离屏幕右边
    
    private let designFirstItemTop: CGFloat = 296       // 第一个选项距离顶部（从屏幕顶部开始）
    
    // 计算实际尺寸的辅助方法
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
        // MARK: - Properties
    
    // 版本检查器 - 需要替换为实际的 App Store ID
    private lazy var versionChecker = AppVersionChecker(appStoreID: "YOUR_APP_STORE_ID")
    
    // MARK: - UI Components
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.showsVerticalScrollIndicator = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never  // 禁用自动内容插入调整
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 选项容器
    private var settingItems: [UIView] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        createSettingItems()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 确保导航栏设置在每次显示时都正确
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    // MARK: - Setup
    
    private func setupNavigationBar() {
        // 隐藏导航栏,避免顶部出现灰色区域
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // ScrollView - 从顶部开始,让背景色填充整个屏幕
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func createSettingItems() {
        let items: [(title: String, subtitle: String, action: Selector)] = [
            (L("settings.profile"), L("settings.profile_subtitle"), #selector(profileTapped)),
            (L("settings.sync"), L("settings.sync_subtitle"), #selector(syncTapped)),
            (L("permission.title"), "", #selector(permissionTapped)),
            (String(format: L("settings.version_with_number"), versionChecker.getCurrentVersion()), L("settings.version_subtitle"), #selector(versionTapped)),
            (L("settings.reset"), L("settings.reset_subtitle"), #selector(resetTapped)),
            (L("settings.show_onboarding"), "", #selector(onboardingTapped))
        ]
        
        let itemHeight = scale(designItemHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let firstItemTop = scale(designFirstItemTop, basedOn: view.bounds.height, designDimension: designHeight)
        
        var previousItem: UIView?
        
        for (index, item) in items.enumerated() {
            let itemView = createSettingItem(
                title: item.title,
                subtitle: item.subtitle,
                action: item.action,
                showTopSeparator: index != 0  // 第一个选项不显示上边分隔线
            )
            contentView.addSubview(itemView)
            settingItems.append(itemView)
            
            NSLayoutConstraint.activate([
                itemView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                itemView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                itemView.heightAnchor.constraint(equalToConstant: itemHeight)
            ])
            
            if index == 0 {
                itemView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: firstItemTop).isActive = true
            } else if let previous = previousItem {
                itemView.topAnchor.constraint(equalTo: previous.bottomAnchor).isActive = true
            }
            
            previousItem = itemView
        }
        
        // 设置 contentView 的底部约束
        if let lastItem = previousItem {
            contentView.bottomAnchor.constraint(equalTo: lastItem.bottomAnchor, constant: 100).isActive = true
        }
    }
    
    private func createSettingItem(title: String, subtitle: String, action: Selector, showTopSeparator: Bool = true) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 分隔线（可选）
        var separatorLine: UIView?
        if showTopSeparator {
            let line = UIView()
            line.backgroundColor = DesignConstants.separatorColor
            line.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(line)
            separatorLine = line
        }
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // 副标题（如果有）
        var subtitleLabel: UILabel?
        if !subtitle.isEmpty {
            let label = UILabel()
            label.text = subtitle
            label.textColor = .white
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(label)
            subtitleLabel = label
        }
        
        // 箭头图标
        let arrowImageView = UIImageView()
        arrowImageView.image = UIImage(named: "enter_icon")
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(arrowImageView)
        
        // 设置字体 - 按设计稿比例计算
        let titleFontSize = scale(designItemTitleFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = UIFont.systemFont(ofSize: titleFontSize, weight: .regular)
        
        if let subtitleLabel = subtitleLabel {
            let subtitleFontSize = scale(designItemSubtitleFontSize, basedOn: view.bounds.height, designDimension: designHeight)
            subtitleLabel.font = UIFont.systemFont(ofSize: subtitleFontSize, weight: .regular)
        }
        
        let itemLeading = scale(designItemLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let separatorMargin = scale(DesignConstants.separatorHorizontalMargin, basedOn: view.bounds.width, designDimension: designWidth)
        let arrowWidth = scale(designArrowWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let arrowHeight = scale(designArrowHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let arrowTrailing = scale(designArrowTrailing, basedOn: view.bounds.width, designDimension: designWidth)
        let titleTop = scale(designItemTitleTop, basedOn: view.bounds.height, designDimension: designHeight)
        let subtitleTop = scale(designItemSubtitleTop, basedOn: view.bounds.height, designDimension: designHeight)
        
        var constraints: [NSLayoutConstraint] = []
        
        // 分隔线约束（如果有）
        if let separatorLine = separatorLine {
            constraints += [
                separatorLine.topAnchor.constraint(equalTo: containerView.topAnchor),
                separatorLine.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: separatorMargin),
                separatorLine.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -separatorMargin),
                separatorLine.heightAnchor.constraint(equalToConstant: 1)
            ]
        }
        
        // 箭头约束
        constraints += [
            arrowImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            arrowImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -arrowTrailing),
            arrowImageView.widthAnchor.constraint(equalToConstant: arrowWidth),
            arrowImageView.heightAnchor.constraint(equalToConstant: arrowHeight)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        // 标题位置
        if let subtitleLabel = subtitleLabel {
            let topAnchor = separatorLine?.bottomAnchor ?? containerView.topAnchor
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: titleTop),
                titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: itemLeading),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: arrowImageView.leadingAnchor, constant: -20),
                
                subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: subtitleTop),
                subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                subtitleLabel.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -20)
            ])
        } else {
            NSLayoutConstraint.activate([
                titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: itemLeading),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: arrowImageView.leadingAnchor, constant: -20)
            ])
        }
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: action)
        containerView.addGestureRecognizer(tapGesture)
        containerView.isUserInteractionEnabled = true
        
        return containerView
    }
    
    // MARK: - Actions
    
    @objc private func profileTapped() {
        print("个人资料修改 tapped")
        Toast.show(L("settings.profile"), in: self.view)
    }
    
    @objc private func syncTapped() {
        print("健康信息同步 tapped")
        let syncVC = HealthSyncSettingsViewController()
        navigationController?.pushViewController(syncVC, animated: true)
    }
    
    @objc private func permissionTapped() {
        print("权限管理 tapped")
        let permissionVC = PermissionViewController()
        navigationController?.pushViewController(permissionVC, animated: true)
    }
    
    @objc private func versionTapped() {
        print("软件版本 tapped")
        checkForUpdates()
    }
    
    @objc private func resetTapped() {
        print("恢复出厂设置 tapped")
        
        let customAlert = CustomAlertViewController(
            title: L("settings.reset_confirm_title"),
            description: L("settings.reset_confirm_message"),
            confirmButtonTitle: L("settings.reset_confirm"),
            cancelButtonTitle: L("settings.reset_cancel"),
            onConfirm: { [weak self] in
                guard let self = self else { return }
                Toast.show(L("settings.reset_done_message"), in: self.view)
            },
            onCancel: nil
        )
        
        present(customAlert, animated: true)
    }
    
    @objc private func onboardingTapped() {
        print("重新查看引导页 tapped")
        showOnboarding()
    }
    
    private func showOnboarding() {
        let onboarding = OnboardingViewController()
        onboarding.modalPresentationStyle = .fullScreen
        present(onboarding, animated: true)
    }
    
    // MARK: - Version Check
    
    /// 检查 App Store 版本更新
    private func checkForUpdates() {
        Toast.show(L("settings.version_checking"), in: self.view)
        
        versionChecker.checkForUpdates { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .upToDate(let currentVersion):
                self.showLatestVersionAlert(currentVersion: currentVersion)
                
            case .updateAvailable(let currentVersion, let appStoreVersion):
                self.showUpdateAlert(currentVersion: currentVersion, appStoreVersion: appStoreVersion)
                
            case .error(let message):
                print("版本检查错误: \(message)")
                Toast.show(L("settings.version_check_failed"), in: self.view)
            }
        }
    }
    
    /// 显示最新版本提示
    private func showLatestVersionAlert(currentVersion: String) {
        let message = String(format: L("settings.version_latest_message"), currentVersion)
        let customAlert = CustomAlertViewController(
            title: L("settings.version_latest_title"),
            description: message,
            confirmButtonTitle: L("common.ok"),
            cancelButtonTitle: L("common.cancel"),
            onConfirm: nil,
            onCancel: nil
        )
        
        present(customAlert, animated: true)
    }
    
    /// 显示更新提示
    private func showUpdateAlert(currentVersion: String, appStoreVersion: String) {
        let message = String(format: L("settings.version_update_message"), appStoreVersion, currentVersion)
        let customAlert = CustomAlertViewController(
            title: L("settings.version_update_title"),
            description: message,
            confirmButtonTitle: L("settings.version_update_button"),
            cancelButtonTitle: L("common.cancel"),
            onConfirm: { [weak self] in
                self?.versionChecker.openAppStore()
            },
            onCancel: nil
        )
        
        present(customAlert, animated: true)
    }
}
    