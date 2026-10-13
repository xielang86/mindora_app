import UIKit
import SafariServices

class SideMenuViewController: UIViewController {

    private let avatarStorageKey = "user_profile_avatar"

    // MARK: - UI Components
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        return view
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        // CSS padding-bottom to ensure content is reachable
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        return scrollView
    }()

    private let scrollContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Header
    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("sidemenu.title")
        // CSS text_16: 36px -> 18pt, SourceHanSansCN-Bold -> PingFangSC-Semibold
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .white
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "close"), for: .normal)
        return button
    }()
    
    // Profile
    // CSS box_10: background-color: rgba(128, 84, 254, 1);
    private let profileView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0)
        return view
    }()
    
    // CSS image-wrapper_5: background white, radius 50%
    private let avatarContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerRadius = 45 // 90px / 2 = 45px -> 22.5pt (wait, let's check size)
        view.clipsToBounds = true
        return view
    }()
    
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(named: "default_avatar")
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("sidemenu.user.name")
        // CSS text_17: 36px -> 18pt, PingFangSC-Semibold
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()
    
    private let emailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "emailexample@example.com"
        // CSS text_18: 22px -> 11pt, HKGrotesk-Light
        label.font = UIFont(name: "HKGrotesk-Light", size: 11) ?? .systemFont(ofSize: 11, weight: .light)
        label.textColor = UIColor(white: 1.0, alpha: 1.0)
        return label
    }()
    
    // Menu Items Stack
    private let menuStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0 // Spacing handled by padding/margins in items
        return stack
    }()
    
    // Bottom Section (Logout & Links)
    private let logoutButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("sidemenu.logout"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        // CSS text_28: 28px -> 14pt
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        // CSS text-wrapper_4: background rgba(128, 84, 254, 1), radius 20px (10pt)
        button.backgroundColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0)
        button.layer.cornerRadius = 10
        // CSS padding: 20px 70px -> 10pt 35pt
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 35, bottom: 10, trailing: 35)
            button.configuration = config
        } else {
            button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 35, bottom: 10, right: 35)
        }
        return button
    }()

    // Section 12 Links
    private let linksContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        contentView.transform = CGAffineTransform(translationX: -UIScreen.main.bounds.width, y: 0)

        refreshProfileSummary()
        refreshNotificationsBadge()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            self.contentView.transform = .identity
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        view.addSubview(contentView)
        contentView.addSubview(headerView)
        contentView.addSubview(scrollView)
        scrollView.addSubview(scrollContentView)
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(closeButton)
        
        scrollContentView.addSubview(profileView)
        profileView.addSubview(avatarContainerView)
        avatarContainerView.addSubview(avatarImageView)
        profileView.addSubview(nameLabel)
        profileView.addSubview(emailLabel)
        
        scrollContentView.addSubview(menuStackView)
        
        scrollContentView.addSubview(logoutButton)
        scrollContentView.addSubview(linksContainer)
        setupLinks(in: linksContainer)
        
        setupConstraints()
        setupMenu()
        setupLinks()
        
        // Actions
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        logoutButton.addTarget(self, action: #selector(handleLogout), for: .touchUpInside)

        #if DEBUG
        // 调试：长按 close (X) 1.5s = 把本地 token 标记为过期。杀掉 app 重启即可复现冷启动 re-auth。
        let debugLongPress = UILongPressGestureRecognizer(target: self, action: #selector(debugTriggerExpired(_:)))
        debugLongPress.minimumPressDuration = 1.5
        closeButton.addGestureRecognizer(debugLongPress)

        // 调试：长按标题 1.0s = 把 token 替换成无效串。下一次任意 API 调用 → 服务器 401 → 切 Start。
        titleLabel.isUserInteractionEnabled = true
        let debugCorruptPress = UILongPressGestureRecognizer(target: self, action: #selector(debugTriggerCorruptToken(_:)))
        debugCorruptPress.minimumPressDuration = 1.0
        titleLabel.addGestureRecognizer(debugCorruptPress)
        #endif
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleClose))
        tap.delegate = self
        view.addGestureRecognizer(tap)
        
        let profileTap = UITapGestureRecognizer(target: self, action: #selector(handleProfileTap))
        profileView.isUserInteractionEnabled = true
        profileView.addGestureRecognizer(profileTap)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleAvatarUpdate), name: NSNotification.Name("UserProfileAvatarUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleProfileDataUpdate), name: .userProfileDidUpdate, object: nil)
        // 未读红点变化（浏览消息 markAllRead）→ 侧栏消息行红点同步消除，和铃铛一致。
        NotificationCenter.default.addObserver(self, selector: #selector(refreshNotificationsBadge), name: UnreadBadgeCenter.didChangeNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// 侧栏「消息通知」行的红点引用，供 markAllRead 后实时消除。
    private weak var notificationsRedDot: UIView?

    @objc private func refreshNotificationsBadge() {
        notificationsRedDot?.isHidden = !UnreadBadgeCenter.shared.hasUnread
    }
    
    @objc private func handleAvatarUpdate() {
        if let savedImage = loadAvatarImage() {
            avatarImageView.image = savedImage
        }
    }

    @objc private func handleProfileDataUpdate() {
        refreshProfileSummary()
    }

    private func refreshProfileSummary() {
        let draft = UserProfileStore.shared.load(accountEmail: AuthStorage.shared.email)
        let nickname = draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        nameLabel.text = nickname.isEmpty ? L("user_profile.username_default") : nickname

        if let email = AuthStorage.shared.email, !email.isEmpty {
            emailLabel.text = email
        } else {
            emailLabel.text = L("sidemenu.not_logged_in")
        }

        if let savedImage = loadAvatarImage() {
            avatarImageView.image = savedImage
        }
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        // CSS group_4 width 596px -> 596/750 of screen width
        // Using multiplier to adapt to different screen sizes instead of fixed point width (298pt)
        let widthMultiplier: CGFloat = 596.0 / 750.0
        // On iPad the multiplier alone would produce a ~800pt+ panel; cap it to a normal
        // sidebar width. Never binds on iPhone (widthMultiplier * screen width stays well under this).
        let maxWidth: CGFloat = 400
        let preferredWidthConstraint = contentView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: widthMultiplier)
        preferredWidthConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            preferredWidthConstraint,
            contentView.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            
            // CSS section_2 margin-top: 45px -> 22.5pt
            headerView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 10), // Safe area + slight margin
            
            // Align Header width to contentView to ensure alignment control
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            // Align Title with list items (24pt margin)
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 24),
            
            // Align CloseButton with list arrows (24pt margin)
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -14),
            
            // 改进按钮点击区域（热区放大）
            closeButton.widthAnchor.constraint(equalToConstant: 34),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            
            // CSS section_3 (profile) margin-top: 74px (37pt)
            // But here we use scrollview for the rest
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 0),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            
            scrollContentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            scrollContentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            scrollContentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrollContentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            scrollContentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Profile View
            // Uniform spacing: 24pt
            profileView.topAnchor.constraint(equalTo: scrollContentView.topAnchor, constant: 24),
            profileView.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor),
            profileView.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor),
            // Height determined by content + padding
            
            // Avatar Container
            // CSS image-wrapper_5: padding 20px 25px -> 10pt 12.5pt
            // image_4 (avatar inside): 40px 50px -> 20pt 25pt
            // Total dims: W = 20(pad)+20(img)+25(pad)=65px -> 32.5pt?
            // Let's approximate a 45pt circle based on 90px wrapper
            avatarContainerView.leadingAnchor.constraint(equalTo: profileView.leadingAnchor, constant: 24), // 48px -> 24pt
            avatarContainerView.topAnchor.constraint(equalTo: profileView.topAnchor, constant: 18), // 36px -> 18pt
            avatarContainerView.bottomAnchor.constraint(equalTo: profileView.bottomAnchor, constant: -18),
            avatarContainerView.widthAnchor.constraint(equalToConstant: 45),
            avatarContainerView.heightAnchor.constraint(equalToConstant: 45),
            
            avatarImageView.topAnchor.constraint(equalTo: avatarContainerView.topAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarContainerView.bottomAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarContainerView.leadingAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarContainerView.trailingAnchor),
            
            // Text Group
            // CSS text-group_11 margin 13px 0 -> 6.5pt 0
            nameLabel.leadingAnchor.constraint(equalTo: avatarContainerView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: avatarContainerView.topAnchor),
            
            emailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            emailLabel.bottomAnchor.constraint(equalTo: avatarContainerView.bottomAnchor),
            
            // Menu
            // Uniform spacing: 24pt
            menuStackView.topAnchor.constraint(equalTo: profileView.bottomAnchor, constant: 24),
            menuStackView.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor),
            menuStackView.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor),
            
            // Logout
            // Uniform spacing: 24pt
            logoutButton.topAnchor.constraint(equalTo: menuStackView.bottomAnchor, constant: 24),
            logoutButton.centerXAnchor.constraint(equalTo: scrollContentView.centerXAnchor),
            // CSS width 252px -> 126pt ? Or Text wrapper width?
            // "width: 252px; align-self: center" is for section_11 container.
            // Button itself matches container or text wrapper? Text wrapper has padding.
            // Let's AutoLayout based on content + padding
            // But maybe force minimum width if design requires
            
            // Links
            linksContainer.topAnchor.constraint(equalTo: logoutButton.bottomAnchor, constant: 24),
            linksContainer.centerXAnchor.constraint(equalTo: scrollContentView.centerXAnchor),
            linksContainer.bottomAnchor.constraint(equalTo: scrollContentView.bottomAnchor, constant: -40)
        ])
        
        // Radius fix for avatar container
        avatarContainerView.layer.cornerRadius = 22.5
    }
    
    private func setupMenu() {
         addMenuItem(title: L("sidemenu.subscription"),
                     subtitle: L("sidemenu.upgrade"),
                     isPro: true,
                     tag: 1)
         addSeparator()
         
         addMenuItem(title: L("sidemenu.device"), tag: 2)
         addSeparator()
         
         // 红点跟随全局未读状态（浏览消息后不再显示）；侧边栏每次打开重建，读取即最新。
         addMenuItem(title: L("sidemenu.notifications"), tag: 3, showRedDot: true)
         addSeparator()
         
         // 隐私政策 / 服务条款：两个独立菜单项（替换原「隐私 & 数据」），App 内浏览器打开。隐私优先。
         addMenuItem(title: L("sidemenu.privacy_policy"), tag: 9)
         addSeparator()

         addMenuItem(title: L("sidemenu.terms"), tag: 8)
         addSeparator()

         addMenuItem(title: L("sidemenu.health_link"), tag: 5)
         addSeparator()
         
         addMenuItem(title: L("sidemenu.language"), tag: 6)
         addSeparator()
         
         addMenuItem(title: L("sidemenu.help"), tag: 7)
         addSeparator()
    }
    
    // Updated addMenuItem with strict styling
    private func addMenuItem(title: String, subtitle: String? = nil, isPro: Bool = false, tag: Int, showRedDot: Bool = false) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        // CSS margin-top 46px -> 23pt (between separator and text?)
        // Let's approximate per-item height. section_5 height not set, but text height 28px.
        // Let's give it comfortable tap target, e.g. 50pt
        container.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        
        if let subtitle = subtitle {
            let fullText = "\(title) (\(subtitle))"
            let attributedString = NSMutableAttributedString(string: fullText)
            
            // Title attributes: SourceHanSansCN-Regular 28px (14pt) White
            attributedString.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(location: 0, length: fullText.count))
            attributedString.addAttribute(.font, value: UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14), range: NSRange(location: 0, length: fullText.count))
            
            // Subtitle attributes: 28px (14pt)
            if let range = fullText.range(of: subtitle) {
                let nsRange = NSRange(range, in: fullText)
                // text_20 color? It says color: rgba(255, 255, 255, 1) in CSS?
                // Wait, text_19 (title) white. text_20 (subtitle) white.
                // The snippet said text_21 white.
                // The user PROMPT didn't specify color for subtitle, but usually PRO is Gold.
                // Re-reading CSS line 666: text_20 color rgba(255, 255, 255, 1). So WHITE.
                // Okay, I will keep it white, or maybe lighter weight?
                // text_20 is HKGrotesk-Regular. title is SourceHanSansCN-Regular.
                attributedString.addAttribute(.font, value: UIFont(name: "HKGrotesk-Regular", size: 14) ?? .systemFont(ofSize: 14), range: nsRange)
            }
            label.attributedText = attributedString
        } else {
            label.text = title
            label.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
            label.textColor = .white
        }
        
        let arrow = UIImageView(image: UIImage(named: "enter_icon"))
        arrow.translatesAutoresizingMaskIntoConstraints = false
        arrow.contentMode = .scaleAspectFit
        
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tag = tag
        button.addTarget(self, action: #selector(menuItemTapped), for: .touchUpInside)
        #if DEBUG
        if tag == 1 {
            // 调试：长按「订阅」2s = 弹 StoreKit 退款申请表。沙盒里提交即退，用来验证 REFUND 通知与撤销上报。
            let refundPress = UILongPressGestureRecognizer(target: self, action: #selector(debugTriggerRefund(_:)))
            refundPress.minimumPressDuration = 2.0
            button.addGestureRecognizer(refundPress)
        }
        #endif

        container.addSubview(label)
        container.addSubview(arrow)
        container.addSubview(button)
        // CSS margin-left 48px -> 24pt
        // CSS width 487px -> ~243.5pt content width

        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),

            arrow.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            arrow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24), // Margin right
            // CSS label_21: 28px -> 14pt
            arrow.widthAnchor.constraint(equalToConstant: 14),
            arrow.heightAnchor.constraint(equalToConstant: 14),

            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        // 消息通知红点：位于箭头左侧。始终创建，按未读状态显隐，并留引用供实时刷新
        // （浏览消息 markAllRead 后，即使侧栏还压在消息页下方，也能同步消除，和铃铛状态一致）。
        if showRedDot {
            let redDot = UIView()
            redDot.backgroundColor = UIColor(red: 1.0, green: 59/255, blue: 48/255, alpha: 1.0) // #FF3B30
            redDot.layer.cornerRadius = 3
            redDot.isHidden = !UnreadBadgeCenter.shared.hasUnread
            redDot.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(redDot)
            container.bringSubviewToFront(button)
            NSLayoutConstraint.activate([
                redDot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                redDot.trailingAnchor.constraint(equalTo: arrow.leadingAnchor, constant: -8),
                redDot.widthAnchor.constraint(equalToConstant: 6),
                redDot.heightAnchor.constraint(equalToConstant: 6)
            ])
            if tag == 3 { notificationsRedDot = redDot }
        }

        menuStackView.addArrangedSubview(container)
    }
    
    private func addSeparator() {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        // CSS image-wrapper margin: 46px -1px 0 48px...
        // Let's just put the line. height 1px? CSS image_5 height 1px.
        // We need wrapper to hold the spacing?
        // Actually the design seems to have line BELOW text.
        
        let line = MenuSeparatorView()
        line.translatesAutoresizingMaskIntoConstraints = false
        
        wrapper.addSubview(line)
        
        NSLayoutConstraint.activate([
            wrapper.heightAnchor.constraint(equalToConstant: 1), // Minimal height for the separator slot
            // CSS separation width 533px -> 266.5pt
            line.heightAnchor.constraint(equalToConstant: 0.5),
            line.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 24), // 48px -> 24pt
            line.widthAnchor.constraint(equalToConstant: 266.5),
            line.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor)
        ])
        
        menuStackView.addArrangedSubview(wrapper)
    }

    private func setupLinks(in container: UIView) {
        // 服务条款 / 隐私政策已改为上方独立菜单项，底部链接不再需要（容器收 0 高，保持布局约束完整）。
        container.heightAnchor.constraint(equalToConstant: 0).isActive = true
        container.widthAnchor.constraint(equalToConstant: 0).isActive = true
    }
    
    // remove setupLinks() call duplication (old function)
    private func setupLinks() {} // Stubb to satisfy old call in setupUI if any, but I removed it in new setupUI
    
    // MARK: - Legacy setupUI removed/replaced

    
    @objc private func handleClose() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.backgroundColor = .clear
            self.contentView.transform = CGAffineTransform(translationX: -self.contentView.frame.width, y: 0)
        }) { _ in
            self.dismiss(animated: false, completion: nil)
        }
    }

    #if DEBUG
    @objc private func debugTriggerRefund(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let scene = view.window?.windowScene else { return }
        Log.info("SideMenu", "[DEBUG] long-press on subscription → begin refund request")
        Task { @MainActor in
            let msg = await SubscriptionManager.shared.debugBeginRefundRequest(in: scene)
            if let window = self.view.window { Toast.show("[DEBUG] \(msg)", in: window) }
        }
    }

    @objc private func debugTriggerExpired(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        Log.info("SideMenu", "[DEBUG] long-press on close → mark token expired")
        AuthStorage.shared.debugMarkExpired()
        let presenter = self.view.window
        UIView.animate(withDuration: 0.3, animations: {
            self.view.backgroundColor = .clear
            self.contentView.transform = CGAffineTransform(translationX: -self.contentView.frame.width, y: 0)
        }) { _ in
            self.dismiss(animated: false) {
                if let window = presenter {
                    Toast.show("[DEBUG] Token marked expired. Kill app & relaunch to test re-auth.", in: window)
                }
            }
        }
    }

    @objc private func debugTriggerCorruptToken(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        Log.info("SideMenu", "[DEBUG] long-press on title → corrupt token")
        AuthStorage.shared.debugCorruptToken()
        let presenter = self.view.window
        UIView.animate(withDuration: 0.3, animations: {
            self.view.backgroundColor = .clear
            self.contentView.transform = CGAffineTransform(translationX: -self.contentView.frame.width, y: 0)
        }) { _ in
            self.dismiss(animated: false) {
                if let window = presenter {
                    Toast.show("[DEBUG] Token corrupted. Pull-to-refresh any tab to trigger 401.", in: window)
                }
            }
        }
    }
    #endif
    
    @objc private func handleProfileTap() {
        let profileVC = UserProfileViewController()
        profileVC.modalPresentationStyle = .overFullScreen
        profileVC.modalTransitionStyle = .crossDissolve
        present(profileVC, animated: true, completion: nil)
    }
    
    @objc private func handleLogout() {
        self.logoutButton.animateButtonTap { [weak self] in
            guard let self = self, let window = self.view.window else { return }
            
            let alertView = LogoutAlertView(frame: window.bounds)
            alertView.onConfirm = { [weak self] in
                self?.performLogout()
            }
            
            window.addSubview(alertView)
            
            alertView.alpha = 0
            UIView.animate(withDuration: 0.2) {
                alertView.alpha = 1
            }
        }
    }

    private func performLogout() {
        clearLocalUserData()
        if let window = view.window {
             Toast.show(L("user_profile.logout_success"), in: window)
        }
        navigateToLogin()
    }

    private func clearLocalUserData() {
        // 退出登录：保留邮箱，登录页预填上次账号（注销删除账号才连邮箱一起清）。
        SessionResetter.reset(.logout)
    }

    private func navigateToLogin() {
        let loginVC = StartViewController()
        let nav = UINavigationController(rootViewController: loginVC)
        nav.setNavigationBarHidden(true, animated: false)

        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
        
        if let window = view.window ?? keyWindow {
            UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve, animations: {
                window.rootViewController = nav
            }, completion: nil)
        }
    }
    
    @objc private func menuItemTapped(_ sender: UIButton) {
        switch sender.tag {
        case 1:
            // Subscription
            let vc = SubscriptionViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        case 2:
            // Device：永远进 DM 列表。
            // 已绑过 → 看到设备卡片；没绑过 → 看到 empty state + "搜索设备" 按钮，用户主动
            // tap 按钮才进扫描页。之前的"未绑直接跳扫描页"是把"管理设备"和"添加新设备"两个
            // 动作糅在一起，用户语义上是先进设备列表（即使是空的），再决定要不要添加新设备。
            let nav = UINavigationController(rootViewController: DeviceManagementViewController())
            nav.setNavigationBarHidden(true, animated: false)
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true, completion: nil)
        case 3:
            // Notifications
            let vc = NotificationsViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        case 8:
            // 服务条款
            openTerms()
        case 9:
            // 隐私政策
            openPrivacy()
        case 5:
            // Health Link
            if let window = self.view.window {
                HealthLinkAlertView.show(in: window, onConfirm: {
                    Task {
                        do {
                            try await HealthDataManager.shared.requestAuthorization()
                            
                            await MainActor.run {
                                PermissionManager.shared.openHealthApp(completion: nil)
                            }
                        } catch {
                            print("Health auth error: \(error)")
                        }
                    }
                })
            }
        case 6:
            // Language
            let vc = LanguageSettingsViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        case 7:
            // Help
            let vc = HelpViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        default:
            print("Menu item \(sender.tag) tapped")
        }
    }

    @objc private func openTerms() {
        // 用户协议：App 内浏览器打开（无自定义标题，URL 定义在 Constants）。
        guard let url = URL(string: Constants.Network.termsOfUseURL) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    @objc private func openPrivacy() {
        // 隐私政策：App 内浏览器打开（无自定义标题，URL 定义在 Constants）。
        guard let url = URL(string: Constants.Network.privacyPolicyURL) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }
    
    // MARK: - Avatar Persistence
    private func loadAvatarImage() -> UIImage? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let avatarURL = documentsDirectory.appendingPathComponent("user_avatar.jpg")
        guard let data = try? Data(contentsOf: avatarURL) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Helper Classes

class MenuSeparatorView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private let borderLayer = CALayer()
    
    private func setupLayer() {
        // User requested:
        // borderLayer1.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor
        borderLayer.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.2).cgColor // Adjusted alpha for visibility
        layer.addSublayer(borderLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        borderLayer.frame = bounds
    }
}

// MARK: - UIGestureRecognizerDelegate
extension SideMenuViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let touchView = touch.view, touchView.isDescendant(of: contentView) {
            return false
        }
        return true
    }
}

