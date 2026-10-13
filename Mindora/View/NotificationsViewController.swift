//
//  NotificationsViewController.swift
//  mindora
//
//  Created by AI on 2026/01/29.
//

import UIKit
import UserNotifications
import SafariServices

class NotificationsViewController: UIViewController {

    // MARK: - Properties

    private var notifications: [NotificationModel] = []        // 当前消息
    private var historyNotifications: [NotificationModel] = []  // 历史消息

    // MARK: - UI Components
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L("notifications.title")
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let backButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton()
        button.setImage(UIImage(named: "sub_back"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Permission View Container
    private let permissionViewContainer: UIView = {
        let view = UIView()
        // Darkened background to simulate overlay/modal environment from screenshot
        view.backgroundColor = UIColor(white: 0, alpha: 0.5) 
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    // List View Container
    private let listContainerView: UIView = {
        let view = UIView()
        // CSS: background-color: rgba(24, 24, 24, 1);
        // Correct Background Color: UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
        view.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1.0)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    // Explicit view for separator to ensure it participates in View hierarchy and layout
    private let navSeparatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    // 空态：没有任何消息时居中显示「暂无消息」
    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = L("notifications.empty")
        label.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        label.textColor = UIColor(white: 1.0, alpha: 0.4)
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Correct Background Color: UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
        view.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1.0)
        
        setupUI()
        setupActions()
        loadData()
        
        // Observe app becoming active to re-check permissions
        NotificationCenter.default.addObserver(self, selector: #selector(checkPermission), name: UIApplication.willEnterForegroundNotification, object: nil)
        // 消息数据变化（后台生成新消息）时实时刷新列表
        NotificationCenter.default.addObserver(self, selector: #selector(reloadNotifications), name: AppNotificationStore.didChangeNotification, object: nil)
        // 语言切换后重新本地化文案与日期
        NotificationCenter.default.addObserver(self, selector: #selector(reloadNotifications), name: LocalizationManager.languageDidChangeNotification, object: nil)
        // 问卷提交后把「填写问卷」按钮切成已完成态
        NotificationCenter.default.addObserver(self, selector: #selector(reloadNotifications), name: SurveyService.didSubmitNotification, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update separator layer frame if needed, but we used a UIView with sublayer pattern below.
        if let layer = navSeparatorView.layer.sublayers?.first {
             // bgLayer1: UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1).cgColor
             // borderLayer1: UIColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor
             // The separator view itself should have the border color if it represents the line.
             // If the user meant "bgLayer1" is the container and "borderLayer1" is the line:
             
             layer.frame = navSeparatorView.bounds
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkPermission()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Background for the overall view controller
        view.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1.0)
        
        view.addSubview(listContainerView) // List at back
        listContainerView.addSubview(titleLabel)
        listContainerView.addSubview(backButton)
        listContainerView.addSubview(navSeparatorView) // Add Separator View
        listContainerView.addSubview(tableView)
        listContainerView.addSubview(emptyLabel)
        
        // Setup Separator Layer Pattern inside navSeparatorView
        let borderLayer = CALayer()
        // Color: #E4E4E4 (RGB 228, 228, 228) with 20% opacity
        borderLayer.backgroundColor = UIColor(red: 228/255, green: 228/255, blue: 228/255, alpha: 0.2).cgColor
        navSeparatorView.layer.addSublayer(borderLayer)
        
        // Permission View is an overlay
        view.addSubview(permissionViewContainer)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(NotificationCell.self, forCellReuseIdentifier: "NotificationCell")
        tableView.register(SurveyNotificationCell.self, forCellReuseIdentifier: "SurveyNotificationCell")
        
        setupPermissionView()
        setupConstraints()
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            // List Container (Full Screen)
            listContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            listContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Header parts inside List Container
            backButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: listContainerView.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 24),
            backButton.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: listContainerView.centerXAnchor),
            
            // Nav Separator (image_1)
            // CSS: image_1 margin-top 27px -> 13.5pt from header
            navSeparatorView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 13.5),
            navSeparatorView.leadingAnchor.constraint(equalTo: listContainerView.leadingAnchor),
            navSeparatorView.trailingAnchor.constraint(equalTo: listContainerView.trailingAnchor),
            navSeparatorView.heightAnchor.constraint(equalToConstant: 0.5), // Corrected to 0.5pt from design specs
            
            // TableView starts after separator
            tableView.topAnchor.constraint(equalTo: navSeparatorView.bottomAnchor, constant: 0),
            tableView.leadingAnchor.constraint(equalTo: listContainerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: listContainerView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: listContainerView.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -40),
            
            // Permission View Overlay
            permissionViewContainer.topAnchor.constraint(equalTo: view.topAnchor),
            permissionViewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            permissionViewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            permissionViewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupPermissionView() {
        // Bottom Sheet Container (White)
        let bottomSheet = UIView()
        bottomSheet.backgroundColor = .white
        bottomSheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomSheet.layer.cornerRadius = 18 // CSS 36px/2 = 18pt
        bottomSheet.translatesAutoresizingMaskIntoConstraints = false
        
        permissionViewContainer.addSubview(bottomSheet)
        
        // Close Button (group_4 / notify_close)
        // Positioned relative to top right of sheet
        let closeButton = UIButton()
        closeButton.setImage(UIImage(named: "notify_close"), for: .normal)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        
        bottomSheet.addSubview(closeButton)
        
        // 1. Title Row: "Allow Notifications" + Toggle Image inside a BOX
        // box_15 style
        let boxView = UIView()
        boxView.backgroundColor = .white
        boxView.layer.cornerRadius = 13 // 26px/2 = 13pt
        // Border: 1px solid rgba(237, 237, 237, 1);
        boxView.layer.borderWidth = 1
        boxView.layer.borderColor = UIColor(red: 237/255, green: 237/255, blue: 237/255, alpha: 1.0).cgColor
        // Shadow: 0px 2px 10px 0px rgba(0, 0, 0, 0.1);
        boxView.layer.shadowColor = UIColor.black.cgColor
        boxView.layer.shadowOpacity = 0.1
        boxView.layer.shadowOffset = CGSize(width: 0, height: 1) // 2px/2 = 1pt
        boxView.layer.shadowRadius = 5 // 10px/2 = 5pt
        boxView.translatesAutoresizingMaskIntoConstraints = false
        
        let permTitleLabel = UILabel()
        permTitleLabel.text = L("notifications.permission.title")
        // text_31: 24px/2 = 12pt, Regular, Black
        permTitleLabel.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        permTitleLabel.textColor = .black
        permTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let notifyIcon = UIImageView(image: UIImage(named: "notify_on"))
        notifyIcon.translatesAutoresizingMaskIntoConstraints = false
        notifyIcon.contentMode = .scaleAspectFit
        
        bottomSheet.addSubview(boxView)
        boxView.addSubview(permTitleLabel)
        boxView.addSubview(notifyIcon)
        
        // 2. Desc Labels
        let descLabel1 = UILabel()
        descLabel1.text = L("notifications.permission.desc")
        // text_32: 28px/2 = 14pt, Medium, Black.
        descLabel1.font = UIFont(name: "PingFangSC-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        descLabel1.textColor = .black
        descLabel1.translatesAutoresizingMaskIntoConstraints = false
        descLabel1.numberOfLines = 0
        descLabel1.textAlignment = .center
        
        let descLabel2 = UILabel()
        descLabel2.text = L("notifications.permission.status")
        // text_33: 22px/2 = 11pt, Regular, Black
        descLabel2.font = UIFont(name: "PingFangSC-Regular", size: 11) ?? .systemFont(ofSize: 11)
        descLabel2.textColor = UIColor(white: 0, alpha: 0.6)
        descLabel2.translatesAutoresizingMaskIntoConstraints = false
        descLabel2.numberOfLines = 0
        descLabel2.textAlignment = .center
        
        bottomSheet.addSubview(descLabel1)
        bottomSheet.addSubview(descLabel2)
        
        // 3. Action Buttons
        // Container box_16 width 750px (actually full width minus margins maybe?) 
        // CSS says box_16 width 692px -> 346pt.
        let buttonsContainer = UIView()
        buttonsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Buttons
        let keepButton = createButton(title: L("notifications.permission.keep"), isPrimary: false)
        keepButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        
        let openButton = createButton(title: L("notifications.permission.open"), isPrimary: true)
        openButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        
        // Using StackView to manage two distinct buttons with spacing
        // Wait, design might have specific widths.
        // text-wrapper_5 padding 26px 115px -> 13pt 57.5pt.
        // text_34 font 28px -> 14pt.
        // Keep button width = text width + 115pt.
        // Open button width = text width + 128pt.
        // Let's use stackview with distribution fillEqually to simulate "two main buttons".
        // CSS also says justify-between on box_16 which is 692px wide.
        
        let buttonsStack = UIStackView(arrangedSubviews: [keepButton, openButton])
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 15 // Arbitrary gap, maybe adjust?
        buttonsStack.distribution = .fillEqually
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        
        bottomSheet.addSubview(buttonsStack)
        
        NSLayoutConstraint.activate([
            // Bottom Sheet anchored to bottom
            bottomSheet.leadingAnchor.constraint(equalTo: permissionViewContainer.leadingAnchor),
            bottomSheet.trailingAnchor.constraint(equalTo: permissionViewContainer.trailingAnchor),
            bottomSheet.bottomAnchor.constraint(equalTo: permissionViewContainer.bottomAnchor),
            
            // Close Button
            // Standard close button placement relative to sheet top
            closeButton.topAnchor.constraint(equalTo: bottomSheet.topAnchor, constant: 15),
            closeButton.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor, constant: -15),
            closeButton.widthAnchor.constraint(equalToConstant: 24), // Approx
            closeButton.heightAnchor.constraint(equalToConstant: 24),

            // Toggle Box (box_15)
            // CSS: padding-top of group_4 is 109px/2 = 54.5pt. This is distance from top of sheet to box.
            boxView.topAnchor.constraint(equalTo: bottomSheet.topAnchor, constant: 54.5),
            boxView.centerXAnchor.constraint(equalTo: bottomSheet.centerXAnchor),
            // Width 434px/2 = 217pt
            boxView.widthAnchor.constraint(equalToConstant: 217),
            // Height: content 12pt + padding 43px/2 = 21.5pt = 33.5pt? No.
            // Toggle image 42px/2 = 21pt.
            // Let's rely on vertical padding. 20px top(10pt) + 23px bottom(11.5pt) + content height.
            // Let's assume content (toggle) drives height. 21pt.
            // Total height = 10 + 11.5 + 21 = 42.5pt.
            // Let's set a fixed height or constraint to content.
            boxView.heightAnchor.constraint(equalToConstant: 42.5),
            
            // Box Content
            permTitleLabel.centerYAnchor.constraint(equalTo: boxView.centerYAnchor),
            permTitleLabel.leadingAnchor.constraint(equalTo: boxView.leadingAnchor, constant: 10), // padding 20px -> 10pt
            
            notifyIcon.centerYAnchor.constraint(equalTo: boxView.centerYAnchor),
            notifyIcon.trailingAnchor.constraint(equalTo: boxView.trailingAnchor, constant: -10), // padding 20px -> 10pt
            notifyIcon.widthAnchor.constraint(equalToConstant: 37.5), // 75px/2
            notifyIcon.heightAnchor.constraint(equalToConstant: 21), // 42px/2
            
            // Labels
            // text_32 margin-top 48px/2 = 24pt
            descLabel1.topAnchor.constraint(equalTo: boxView.bottomAnchor, constant: 24),
            descLabel1.centerXAnchor.constraint(equalTo: bottomSheet.centerXAnchor),
            
            // text_33 margin-top 24px/2 = 12pt
            descLabel2.topAnchor.constraint(equalTo: descLabel1.bottomAnchor, constant: 12),
            descLabel2.centerXAnchor.constraint(equalTo: bottomSheet.centerXAnchor),
            
            // Buttons
            // box_16 margin-top 48px/2 = 24pt
            buttonsStack.topAnchor.constraint(equalTo: descLabel2.bottomAnchor, constant: 24),
            // box_16 width 692px/2 = 346pt.
            buttonsStack.widthAnchor.constraint(equalToConstant: 346),
            buttonsStack.centerXAnchor.constraint(equalTo: bottomSheet.centerXAnchor),
            // Height: text-wrapper_5. Text 14pt + V Padding (26px*2)/2 = 26pt. Total 40pt.
            buttonsStack.heightAnchor.constraint(equalToConstant: 40),
            
            // Bottom Padding (from group_4 padding-bottom 44px/2 = 22pt)
            // Safe area? Usually bottom sheets respect safe area.
            // Let's use 22pt from bottom anchor (which includes safe area usually or needs guide).
            // Using safeAreaLayoutGuide.bottomAnchor just in case.
            buttonsStack.bottomAnchor.constraint(equalTo: bottomSheet.safeAreaLayoutGuide.bottomAnchor, constant: -22)
            
        ])
    }
    
    private func createButton(title: String, isPrimary: Bool) -> UIButton {
        let button = UIButton()
        button.setTitle(title, for: .normal)
        // font 28px/2 = 14pt
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14)
        // border-radius 20px/2 = 10pt
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        
        if isPrimary {
            button.backgroundColor = .black
            button.setTitleColor(.white, for: .normal)
        } else {
            // "Keep" button: light grey bg
            // text-wrapper_5 background-color: rgba(229, 229, 229, 1);
            button.backgroundColor = UIColor(red: 229/255, green: 229/255, blue: 229/255, alpha: 1.0)
            button.setTitleColor(.black, for: .normal)
        }
        return button
    }
    
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
    }
    
    @objc private func handleBack() {
        // 栈底时 pop 无处可退、静默失败，返回按钮会彻底失效（订阅页踩过这个坑）
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            (navigationController ?? self).dismiss(animated: true, completion: nil)
        }
    }
    
    @objc private func openSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    // 第一次请求权限
                    PermissionManager.shared.requestNotificationPermission { status in
                        if status == .authorized {
                            self?.showList()
                        }
                    }
                case .denied:
                    // 已经被拒绝，跳转设置页
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                default:
                    // 已经是授权状态
                    self?.showList()
                }
            }
        }
    }
    
    @objc private func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                    self?.showList()
                } else {
                    self?.showPermissionRequest()
                }
            }
        }
    }
    
    private func showList() {
        permissionViewContainer.isHidden = true
        listContainerView.isHidden = false
        // 用户已看到消息列表 → 清未读，三处红点（Sleep/洞察铃铛 + 侧边栏）一起消失
        UnreadBadgeCenter.shared.markAllRead()
        AppNotificationStore.shared.markAllRead()
    }
    
    private func showPermissionRequest() {
        permissionViewContainer.isHidden = false
        listContainerView.isHidden = true
    }
    
    private func loadData() {
        // 动态生成的真实消息：当前 / 历史两组，展示时按当前语言本地化。
        let sections = AppNotificationStore.shared.sections()
        notifications = sections.current.map { $0.displayModel() }
        historyNotifications = sections.history.map { $0.displayModel() }
        emptyLabel.isHidden = !(notifications.isEmpty && historyNotifications.isEmpty)
        tableView.reloadData()
    }

    @objc private func reloadNotifications() {
        loadData()
    }

    // MARK: - 跳转到睡眠 Tab（健康类消息）

    /// 关闭消息页并切到睡眠 Tab。消息页多为模态呈现，parent 链拿不到 Tab，需从呈现链 / 窗口根查找。
    private func navigateToSleepTab() {
        // 先切好睡眠 Tab（此时它还被模态盖着）。
        resolveMainTab()?.switchToSleepTab(scrollTarget: .top)
        // 再把「Tab 之上的整条模态栈」一次性关掉才能露出来。只依赖 presentingViewController 链
        // （UIKit 始终维护一致）：上溯到「最底层模态」，dismiss 它的呈现者 → 连带关掉其上所有模态
        // （消息页 + 可能还压着的侧栏）。不依赖 parent/child 层级，避免子控制器呈现时的边界情况。
        var bottomModal: UIViewController = self
        while let presenter = bottomModal.presentingViewController, presenter.presentingViewController != nil {
            bottomModal = presenter
        }
        if let presenter = bottomModal.presentingViewController {
            presenter.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func navigateToStoreTab() {
        // 商城 Tab（与首页弹窗 route=="store" 一致），切完关掉整条模态栈露出。
        AppRouter.open(.store, from: self)
    }

    private func resolveMainTab() -> MainTabBarController? {
        // 1) 呈现链（模态呈现时向上找）
        var presenter = presentingViewController
        while let cur = presenter {
            if let t = Self.findMainTab(in: cur) { return t }
            presenter = cur.presentingViewController
        }
        // 2) 窗口根
        let root = view.window?.rootViewController
            ?? UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
        return Self.findMainTab(in: root)
    }

    private static func findMainTab(in vc: UIViewController?) -> MainTabBarController? {
        guard let vc else { return nil }
        if let t = vc as? MainTabBarController { return t }
        if let nav = vc as? UINavigationController { return findMainTab(in: nav.viewControllers.first) }
        for child in vc.children { if let t = findMainTab(in: child) { return t } }
        return findMainTab(in: vc.presentedViewController)
    }
}

// MARK: - TableView Delegate & DataSource

extension NotificationsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return historyNotifications.isEmpty ? 1 : 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? notifications.count : historyNotifications.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = indexPath.section == 0 ? notifications[indexPath.row] : historyNotifications[indexPath.row]

        // 参与调研用专属卡片样式（问卷图标 + 填写问卷紫色按钮 + 有效期）。
        if model.type == .survey {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SurveyNotificationCell", for: indexPath) as? SurveyNotificationCell else {
                return UITableViewCell()
            }
            cell.configure(with: model)
            cell.didTapAction = { [weak self] in self?.handleNotificationAction(model) }
            return cell
        }

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath) as? NotificationCell else {
            return UITableViewCell()
        }
        cell.configure(with: model)
        cell.didTapAction = { [weak self] in
            self?.handleNotificationAction(model)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    // 历史消息分隔符 "————— 以下为历史消息 —————"
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 1 else { return nil }
        return HistoryDividerView(text: L("notifications.history.divider"))
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 1 ? 60 : 0
    }

    // 左滑删除。删除是纯本地行为：从 store 移除，并把对应的 popup_id 从账号清单里摘掉
    // （见 AppNotificationStore.remove），下次登录恢复时自然不会再拉回来。
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let model = indexPath.section == 0 ? notifications[indexPath.row] : historyNotifications[indexPath.row]
        let action = UIContextualAction(style: .destructive,
                                        title: L("notifications.delete")) { _, _, done in
            // 不在这里手动删行：remove 会发 didChangeNotification，
            // reloadNotifications 统一重建两个 section，避免两处各删一次对不上。
            AppNotificationStore.shared.remove(id: model.id)
            done(true)
        }
        action.backgroundColor = UIColor(red: 255/255, green: 59/255, blue: 48/255, alpha: 1.0)
        return UISwipeActionsConfiguration(actions: [action])
    }

    private func handleNotificationAction(_ model: NotificationModel) {
        switch model.type {
        case .subscription:
            let vc = SubscriptionViewController()
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true, completion: nil)
        case .settings:
            PermissionManager.shared.openAppSettings()
        case .health:
            navigateToSleepTab()
        case .survey:
            let surveyId = model.routePayload?["surveyId"] ?? ""
            guard !surveyId.isEmpty else { break }
            // 已提交过的问卷不再进入，避免重复填写后提交报错。
            guard !SurveyService.shared.hasSubmitted(surveyId: surveyId) else {
                Toast.show(L("survey.already_submitted"), in: view)
                break
            }
            let vc = SurveyViewController(surveyId: surveyId)
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true, completion: nil)
        case .promo:
            handlePromoAction(model.routePayload)
        case .other:
            break
        }
    }

    /// 运营消息点击：复用弹窗 action 语义（问卷 / URL / 路由）。
    private func handlePromoAction(_ payload: [String: String]?) {
        let actionType = payload?["actionType"] ?? ""
        switch actionType {
        case "survey":
            let surveyId = payload?["surveyId"] ?? ""
            guard !surveyId.isEmpty else { break }
            let vc = SurveyViewController(surveyId: surveyId)
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        case "url":
            // SFSafariViewController 仅接受 http/https，其余 scheme 会抛异常崩溃。
            if let s = payload?["url"], let url = URL(string: s),
               let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                present(SFSafariViewController(url: url), animated: true)
            }
        case "route":
            // App 内路由：候选常量见 AppRoute / Tools/doc/弹窗与调查问卷接口.md，
            // 未知值回落到商城 Tab。
            AppRouter.open(rawRoute: payload?["route"], from: self, fallback: .store)
        default:
            // 商城活动 / 广告未配置具体动作（dismiss / unknown / 空）→ 默认进入商城 Tab。
            navigateToStoreTab()
        }
    }
}

// MARK: - Models

enum NotificationType {
    case subscription   // 会员 / 兑换 → 订阅页
    case settings       // 权限提醒 → 系统设置
    case health         // 睡眠评分 / 佩戴断签 → 睡眠 Tab
    case survey         // 参与调研 → 问卷页
    case promo          // 运营弹窗（商城活动 / 广告）→ 按 payload 内 action 跳转
    case other
}

struct NotificationModel {
    let id: String
    let type: NotificationType
    let date: String
    let title: String
    let subtitle: String
    let body: String
    let actionText: String
    /// 跳转所需附加参数（如 survey 的 surveyId）。
    var routePayload: [String: String]? = nil
}

// MARK: - History Divider

final class HistoryDividerView: UIView {
    init(text: String) {
        super.init(frame: .zero)
        // 设计稿：分割线与文字同为 #656565
        let lineColor = UIColor(red: 101/255, green: 101/255, blue: 101/255, alpha: 1.0)

        let label = UILabel()
        label.text = text
        label.font = UIFont(name: "PingFangSC-Light", size: 11) ?? .systemFont(ofSize: 11, weight: .light)
        label.textColor = UIColor(red: 101/255, green: 101/255, blue: 101/255, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false

        let leftLine = UIView()
        leftLine.backgroundColor = lineColor
        leftLine.translatesAutoresizingMaskIntoConstraints = false

        let rightLine = UIView()
        rightLine.backgroundColor = lineColor
        rightLine.translatesAutoresizingMaskIntoConstraints = false

        addSubview(leftLine)
        addSubview(label)
        addSubview(rightLine)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            leftLine.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftLine.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 36),
            leftLine.trailingAnchor.constraint(equalTo: label.leadingAnchor, constant: -12),
            leftLine.heightAnchor.constraint(equalToConstant: 0.5),

            rightLine.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightLine.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            rightLine.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -36),
            rightLine.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Cells

class NotificationCell: UITableViewCell {
    
    var didTapAction: (() -> Void)?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Header (Icon + Title + Date)
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "notify")
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
         // CSS text-group_1: font-size 24px -> 12pt
        label.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        // CSS text_4: font-size 22px -> 11pt, Light
        label.font = UIFont(name: "PingFangSC-Light", size: 11) ?? .systemFont(ofSize: 11, weight: .light)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Content Card
    private let cardView: UIView = {
        let view = UIView()
        // Card Background: User specified 2C2C2C -> RGB(44, 44, 44)
        view.backgroundColor = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0)
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        // CSS text_5: font-size 24px -> 12pt
        label.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let bodyLabel: UILabel = {
        let label = UILabel()
        // CSS text_6: font-size 20px -> 10pt, Light
        label.font = UIFont(name: "PingFangSC-Light", size: 10) ?? .systemFont(ofSize: 10, weight: .light)
        label.textColor = .white 
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let separatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let actionButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let actionLabel: UILabel = {
        let label = UILabel()
        // CSS text_7: font-size 20px -> 10pt
        label.font = UIFont(name: "PingFangSC-Regular", size: 10) ?? .systemFont(ofSize: 10)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let arrowImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "enter_icon")
        iv.contentMode = .scaleAspectFit
        iv.alpha = 0.6 // Opacity 60%
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(containerView)
        
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(dateLabel)
        containerView.addSubview(cardView)
        
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(bodyLabel)
        cardView.addSubview(separatorView)
        cardView.addSubview(actionButton)
        
        actionButton.addSubview(actionLabel)
        actionButton.addSubview(arrowImageView)
        
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Header (Section 3) - Top Margin 27.5pt, Left 18pt
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 27.5),
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            iconImageView.widthAnchor.constraint(equalToConstant: 21),
            iconImageView.heightAnchor.constraint(equalToConstant: 21),
            
            titleLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            
            // Date (Section 3) - Right 24pt
            dateLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Card (Section 4) - Top 9.5pt, Left 48pt, Right 24pt
            cardView.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 9.5),
            cardView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 48),
            cardView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            cardView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            
            // Card Padding: Top 18pt, Left 20pt, Right 20pt
            subtitleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            
            // Body: Top 12pt
            bodyLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            bodyLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            bodyLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            
            // Separator: Top 17.5pt, Width 262.75pt (from specs)
            separatorView.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 17.5),
            separatorView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            separatorView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            separatorView.heightAnchor.constraint(equalToConstant: 0.25), // Adjusted to 0.25pt (Stroke width) to reduce brightness
            
            // Action Button: Top 10pt, Bottom 12.5pt
            actionButton.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 10),
            actionButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            actionButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            actionButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12.5),
            actionButton.heightAnchor.constraint(equalToConstant: 30),
            
            actionLabel.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor),
            actionLabel.leadingAnchor.constraint(equalTo: actionButton.leadingAnchor),
            
            arrowImageView.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor),
            arrowImageView.trailingAnchor.constraint(equalTo: actionButton.trailingAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 14),
            arrowImageView.heightAnchor.constraint(equalToConstant: 14)
        ])
        
        setupSeparatorLayer()
    }
    
    private func setupSeparatorLayer() {
        let borderLayer1 = CALayer()
        // Separator Color: #FFFFFF with 40% opacity
        borderLayer1.backgroundColor = UIColor(white: 1.0, alpha: 0.4).cgColor
        separatorView.layer.addSublayer(borderLayer1)
        self.separatorLayer = borderLayer1
    }
    
    private var separatorLayer: CALayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        separatorLayer?.frame = separatorView.bounds
    }
    
    func configure(with model: NotificationModel) {
        titleLabel.text = model.title
        dateLabel.text = model.date
        subtitleLabel.text = model.subtitle
        
        // CSS line-height: 28px -> 14pt
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.05 // Adjustment for font
        paragraphStyle.minimumLineHeight = 14
        paragraphStyle.maximumLineHeight = 14
        
        let attrString = NSMutableAttributedString(string: model.body)
        attrString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attrString.length))
        
        bodyLabel.attributedText = attrString
        actionLabel.text = model.actionText
    }
    
    @objc private func actionTapped() {
        didTapAction?()
    }
}

// MARK: - 参与调研专属卡片（图标 + 填写问卷紫色按钮 + 有效期）

final class SurveyNotificationCell: UITableViewCell {

    var didTapAction: (() -> Void)?

    private let iconContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0) // #8054FE
        v.layer.cornerRadius = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let iconGlyph: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "square.and.pencil"))
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let dateLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "PingFangSC-Light", size: 11) ?? .systemFont(ofSize: 11, weight: .light)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0) // #2C2C2C
        v.layer.cornerRadius = 12
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let cardTitleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "PingFangSC-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        l.textColor = .white
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let bodyLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        l.textColor = UIColor(white: 1, alpha: 0.6)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let fillButton: UIButton = {
        let b = UIButton(type: .system)
        b.backgroundColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0) // #8054FE
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        b.layer.cornerRadius = 21
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let validityLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "PingFangSC-Light", size: 11) ?? .systemFont(ofSize: 11, weight: .light)
        l.textColor = UIColor(white: 1, alpha: 0.4)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private var validityTopToButton: NSLayoutConstraint!
    private var validityHeight: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setup()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        [iconContainer, titleLabel, dateLabel, cardView].forEach { contentView.addSubview($0) }
        iconContainer.addSubview(iconGlyph)
        [cardTitleLabel, bodyLabel, fillButton, validityLabel].forEach { cardView.addSubview($0) }
        fillButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        validityTopToButton = validityLabel.topAnchor.constraint(equalTo: fillButton.bottomAnchor, constant: 12)
        validityHeight = validityLabel.heightAnchor.constraint(equalToConstant: 16)

        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 27.5),
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            iconContainer.widthAnchor.constraint(equalToConstant: 21),
            iconContainer.heightAnchor.constraint(equalToConstant: 21),
            iconGlyph.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconGlyph.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            titleLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 8),
            dateLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            cardView.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 9.5),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 48),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            cardTitleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            cardTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            cardTitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),

            bodyLabel.topAnchor.constraint(equalTo: cardTitleLabel.bottomAnchor, constant: 10),
            bodyLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            bodyLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),

            fillButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 16),
            fillButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            fillButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            fillButton.heightAnchor.constraint(equalToConstant: 42),

            validityTopToButton,
            validityLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            validityLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            validityLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    func configure(with model: NotificationModel) {
        titleLabel.text = model.title
        dateLabel.text = model.date
        cardTitleLabel.text = model.subtitle
        bodyLabel.text = model.body

        // 已提交过的问卷：按钮置灰 + 文案改「已完成」+ 不可点。
        // 点进去也会被 handleNotificationAction 拦下，但那时用户已经点了才知道 ——
        // 外观上先说清楚。
        let surveyId = model.routePayload?["surveyId"] ?? ""
        let submitted = !surveyId.isEmpty && SurveyService.shared.hasSubmitted(surveyId: surveyId)
        fillButton.setTitle(submitted ? L("survey.completed") : model.actionText, for: .normal)
        fillButton.isEnabled = !submitted
        fillButton.backgroundColor = submitted
            ? UIColor(white: 1, alpha: 0.12)
            : UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0) // #8054FE
        fillButton.setTitleColor(submitted ? UIColor(white: 1, alpha: 0.35) : .white, for: .normal)
        fillButton.setTitleColor(UIColor(white: 1, alpha: 0.35), for: .disabled)

        let validity = model.routePayload?["validUntil"]
        validityLabel.text = validity
        validityLabel.isHidden = (validity?.isEmpty ?? true)
        // 无有效期时收起底部占位，避免留白。
        validityTopToButton.constant = (validity?.isEmpty ?? true) ? 0 : 12
    }

    @objc private func actionTapped() { didTapAction?() }
}
