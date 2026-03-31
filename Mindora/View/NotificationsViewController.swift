//
//  NotificationsViewController.swift
//  mindora
//
//  Created by AI on 2026/01/29.
//

import UIKit
import UserNotifications

class NotificationsViewController: UIViewController {

    // MARK: - Properties

    private var notifications: [NotificationModel] = []
    
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
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
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
    }
    
    private func showPermissionRequest() {
        permissionViewContainer.isHidden = false
        listContainerView.isHidden = true
    }
    
    private func loadData() {
        #if DEBUG
        // Mock Data
        let mockNotification = NotificationModel(
            id: "1",
            type: .subscription,
            date: "01月17日 05:03", // Ideally dynamic, but user provided hardcoded mock string in sample
            title: L("notifications.mock.system"),
            subtitle: L("notifications.mock.title"),
            body: L("notifications.mock.body"),
            actionText: L("notifications.mock.action")
        )
        notifications = [mockNotification]
        tableView.reloadData()
        #else
        // Load real data if any (Empty for now as requested task is focused on mock)
        notifications = []
        tableView.reloadData()
        #endif
    }
}

// MARK: - TableView Delegate & DataSource

extension NotificationsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath) as? NotificationCell else {
            return UITableViewCell()
        }
        let model = notifications[indexPath.row]
        cell.configure(with: model)
        cell.didTapAction = { [weak self] in
            self?.handleNotificationAction(model)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    private func handleNotificationAction(_ model: NotificationModel) {
        if model.type == .subscription {
            let vc = SubscriptionViewController()
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true, completion: nil)
        }
    }
}

// MARK: - Models

enum NotificationType {
    case subscription
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
