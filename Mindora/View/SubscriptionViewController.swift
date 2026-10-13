import UIKit
import MessageUI
import SafariServices

class SubscriptionViewController: UIViewController, MFMailComposeViewControllerDelegate {

    // MARK: - Properties
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Background Image
    private let backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        // Use sub_bg normally, maybe switch if Pro? User provided sub_pro_bg.
        iv.image = UIImage(named: "sub_bg")
        return iv
    }()
    
    /// 正在跑的恢复购买任务，用户点取消时用它中止等待
    private var restoreTask: Task<Void, Never>?

    /// 上一次 updateUI 时的订阅状态快照，用来挡掉状态没变的重复重建（见 subscriptionChanged）
    private var renderedSignature: String?

    /// 订阅卡实例。全程复用，不随 updateUI 重建 —— 详见 updateUI 里的说明。
    private var planCard: SubscriptionPlanCardView?

    // Navigation Bar
    private let navBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    private let backButton: EnlargedHitAreaButton = {
        let btn = EnlargedHitAreaButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(named: "sub_back"), for: .normal)
        return btn
    }()
    
    private let navTitleLabel: UILabel = {
        let lb = UILabel()
        lb.translatesAutoresizingMaskIntoConstraints = false
        lb.text = L("subscription.nav.title")
        lb.font = UIFont(name: "PingFangSC-Semibold", size: 18)
        lb.textColor = .white
        return lb
    }()
    
    private let emailIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "sub_email"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        // iv.isHidden = true // Always visible
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    // Stack for dynamic content
    private let mainStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20
        return stack
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 进订阅页就把服务端会员状态刷一遍（1 分钟内不重复）：这页最讲究准，回前台那 10 分钟冷却太长，
        // 订阅刚到期 / 服务端刚续费时用户进来看到的还是上一份快照。
        MembershipStatusService.shared.refresh(reason: "subscription-page", minInterval: 60)
        setupBaseUI()
        updateUI()
        
        NotificationCenter.default.addObserver(self, selector: #selector(subscriptionChanged), name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(purchaseFailed(_:)), name: NSNotification.Name("SubscriptionPurchaseFailed"), object: nil)

        Task {
            await SubscriptionManager.shared.loadProducts()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    @objc private func subscriptionChanged() {
        // "SubscriptionStatusChanged" 被当成通用刷新广播用，一次进页面就会来好几发（loadProducts
        // 拿到价格发一次、权益解析完再发一次、回前台还发）。updateUI 是把整个 mainStack 拆了重建，
        // 每发一次都会把订阅卡换成新的一张 —— 状态没变也重建，就是白闪一次，还会把用户已经手动
        // 切到的等级/周期打回默认。这里按「页面真正依赖的那几项」比对，没变就不重建。
        let signature = currentStateSignature()
        guard signature != renderedSignature else { return }
        updateUI()
    }

    /// updateUI 渲染结果所依赖的全部订阅状态。任何一项变了才需要重建页面。
    private func currentStateSignature() -> String {
        let m = SubscriptionManager.shared
        return [
            String(describing: m.paidMembershipTier),
            String(describing: m.membershipTier),
            String(m.isSubscribed),
            String(m.hasResolvedStatus),
            String(describing: m.currentPlan),
            m.activeProductID ?? "-",
            m.pendingRenewalProductID ?? "-",
            String(describing: m.renewalState),
            String(m.products.count)
        ].joined(separator: "|")
    }
    
    // MARK: - UI Setup
    
    private func setupBaseUI() {
        view.backgroundColor = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0) // #181818
        
        // view.addSubview(backgroundImageView) // Removing background image to show solid color
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(navBar)
        navBar.addSubview(backButton)
        navBar.addSubview(navTitleLabel)
        navBar.addSubview(emailIcon)
        
        contentView.addSubview(mainStack)
        
        // Email Action
        emailIcon.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleEmailTap))
        emailIcon.addGestureRecognizer(tap)
        
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            // backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            // backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            // backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor), // Full screen bg
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Nav Bar
            navBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 44), // Safe area approx
            navBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 44),
            
            backButton.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 20),
            backButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            
            navTitleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            navTitleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            
            emailIcon.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -20),
            emailIcon.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            emailIcon.widthAnchor.constraint(equalToConstant: 20), // 40px
            emailIcon.heightAnchor.constraint(equalToConstant: 15), // 30px
            
            // Main Stack
            mainStack.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    private func updateUI() {
        renderedSignature = currentStateSignature()
        // Clear stack
        mainStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let manager = SubscriptionManager.shared
        
        // 1. Profile / Header Info
        let profile = createProfileSection(isSubscribed: manager.isSubscribed)
        mainStack.addArrangedSubview(profile)
        mainStack.setCustomSpacing(36, after: profile)   // 设计稿 72px

        // 2. 会员订阅卡（等级分段器 + 周期卡 + 权益 + 订阅按钮，20260818 设计）
        //
        // 三档都要展示这张卡，包括已经买了最高档的高级会员——早先的做法是高级会员直接不渲染，
        // 结果付了最贵的钱的人反而看不到自己买了什么、也看不到哪天续费，页面上一个可点的
        // 订阅操作都没有。现在改成卡内切「当前套餐」态：权益照常显示，按钮位换成续费信息 +
        // 管理订阅，另一档仍可点（升级/降级/换时长）。
        //
        // 已订阅普通会员：卡内默认停在「AI 高级会员」页，**必须留出升级入口**——否则普通会员
        //   在 App 内根本没有升到高级的路径（曾经就是这么漏的）。
        // ★ 这里一律用 paidMembershipTier（不含体验期），不能用 isSubscribed / membershipTier：
        //   体验期内那两个值分别是 true / .premium，会让「注册即送 7 天」的用户看不到任何购买入口，
        //   7 天里想付费都没地方付。
        let header = createPlanSectionHeader()
        mainStack.addArrangedSubview(header)
        mainStack.setCustomSpacing(19, after: header)   // 设计稿 38px
        //
        // 初始默认停在哪一档，用的是「已确认 → 实时值，未确认 → 上次已知值」：StoreKit 权益解析
        // 完成前 purchasedProductIDs 还是空的，paidMembershipTier 恒为 .free，直接拿它摆默认会让
        // 已订阅用户第一次进页面时先看到「普通会员」、解析完成刷新后再跳到「AI 高级会员」——
        // 用户报的「第一次进会自己跳一下、第二次不跳」就是这个（第二次内存里已有解析结果）。
        // ★ 订阅卡只建一次，之后一律复用同一个实例（updateUI 会把整个 mainStack 拆了重建，
        //   每次都新建一张卡的话，卡上选中的档位就会按「当时的订阅状态」重摆一遍 —— 页面已经
        //   在屏幕上了还重摆，用户看到的就是分段器自己跳一下）。订阅状态是分好几路异步到的
        //   （StoreKit 权益解析、服务端资料里的兑换/赠送会员、体验期），每到一路都广播一次刷新，
        //   所以这里必须复用：丸子只能由用户的手指挪。
        let card: SubscriptionPlanCardView
        if let existing = planCard {
            existing.update(paidTier: manager.paidMembershipTier)
            card = existing
        } else {
            let resolved = manager.hasResolvedStatus
            let initialTier = resolved ? manager.paidMembershipTier : manager.lastKnownPaidTier
            let initialYearly = resolved ? (manager.currentPlan == .yearly) : manager.lastKnownYearly
            card = SubscriptionPlanCardView(paidTier: manager.paidMembershipTier,
                                            initialTier: initialTier,
                                            initialYearly: initialYearly) { tier, period in
                SubscriptionManager.shared.purchase(type: period, tier: tier)
            }
            planCard = card
        }
        mainStack.addArrangedSubview(card)
        mainStack.setCustomSpacing(30, after: card) // 设计稿 60px

        // 3. 礼品卡和兑换码入口
        mainStack.addArrangedSubview(createGiftCardSection())

        // 4. Footer Links
        mainStack.addArrangedSubview(createFooterSection())
        
        // Update BG and Icon
        if manager.isSubscribed {
            // backgroundImageView.image = UIImage(named: "sub_pro_bg") // Handled in profile section
            // emailIcon.isHidden = false // Fixed: Always visible
        } else {
            // backgroundImageView.image = UIImage(named: "sub_bg")
            // emailIcon.isHidden = true
        }
    }
    
    // MARK: - Sections
    
    private func createProfileSection(isSubscribed: Bool) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        // The banner artwork is designed at a phone-card aspect ratio; this container's
        // width tracks the full available width (much wider on iPad) while its height stays
        // text-content-driven, so a plain .scaleToFill would stretch the artwork out of
        // proportion on wide screens. Round the container via its own layer instead of
        // relying on corners baked into the image, then let the image crop-to-fill.
        container.layer.cornerRadius = 18   // 设计稿 36px
        container.clipsToBounds = true

        let bgImageView = UIImageView()
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.clipsToBounds = true
        container.addSubview(bgImageView)
        
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentStack)
        
        // Title: My MIDORA
        let titleLabel = UILabel()
        titleLabel.text = L("subscription.my_midora") // Font: Kano-regular (36px -> 18pt)
        titleLabel.font = UIFont(name: "PingFangSC-Regular", size: 18) 
        titleLabel.textColor = .white
        
        if isSubscribed {
            bgImageView.image = UIImage(named: "sub_pro_bg")
            
            // Subscribed Layout
            // 1. Title
            contentStack.addArrangedSubview(titleLabel)
            contentStack.setCustomSpacing(20, after: titleLabel) // spacing 52px approx 26pt
            
            // 2. Mindora Days Container (sub_pro_bg2)
            let daysContainer = UIView()
            daysContainer.translatesAutoresizingMaskIntoConstraints = false
            
            let daysBg = UIImageView(image: UIImage(named: "sub_pro_bg2"))
            daysBg.translatesAutoresizingMaskIntoConstraints = false
            daysBg.contentMode = .scaleToFill
            daysContainer.addSubview(daysBg)
            
            let daysStack = UIStackView()
            daysStack.axis = .vertical
            daysStack.alignment = .center
            daysStack.spacing = 5
            daysStack.translatesAutoresizingMaskIntoConstraints = false
            
            let numLabel = UILabel()
            numLabel.text = "\(SubscriptionManager.shared.tideDays)" // 94
            numLabel.font = UIFont(name: "PingFangSC-Semibold", size: 45) // 90px -> 45pt
            numLabel.textColor = .white
            
            let descLabel = UILabel()
            descLabel.text = L("subscription.tide_days")
            descLabel.font = UIFont(name: "PingFangSC-Regular", size: 11) // 22px -> 11pt
            descLabel.textColor = .white
            
            daysStack.addArrangedSubview(numLabel)
            daysStack.addArrangedSubview(descLabel)
            daysContainer.addSubview(daysStack)
            
            NSLayoutConstraint.activate([
                daysBg.topAnchor.constraint(equalTo: daysContainer.topAnchor),
                daysBg.leadingAnchor.constraint(equalTo: daysContainer.leadingAnchor),
                daysBg.trailingAnchor.constraint(equalTo: daysContainer.trailingAnchor),
                daysBg.bottomAnchor.constraint(equalTo: daysContainer.bottomAnchor),
                
                daysStack.centerXAnchor.constraint(equalTo: daysContainer.centerXAnchor),
                daysStack.centerYAnchor.constraint(equalTo: daysContainer.centerYAnchor),
                
                // Constraints for size if needed, or let content determine. 
                // Design padding: top 17, bottom 22, left 132, right 106. 
                // We'll set a min height/width or padding constraints
                daysStack.topAnchor.constraint(equalTo: daysContainer.topAnchor, constant: 10),
                daysStack.bottomAnchor.constraint(equalTo: daysContainer.bottomAnchor, constant: -10),
                daysStack.leadingAnchor.constraint(equalTo: daysContainer.leadingAnchor, constant: 40),
                daysStack.trailingAnchor.constraint(equalTo: daysContainer.trailingAnchor, constant: -40),
            ])
            
            contentStack.addArrangedSubview(daysContainer)
            contentStack.setCustomSpacing(25, after: daysContainer) // margin-top 48px -> 24pt
            
            // 3. Info Row (Active... Expires...)
            let infoRow = UIStackView()
            infoRow.axis = .horizontal
            infoRow.distribution = .equalSpacing // justify-between
            infoRow.spacing = 20
            infoRow.translatesAutoresizingMaskIntoConstraints = false
            
            let statusLabel = UILabel()
            statusLabel.text = Self.membershipStatusText()
            statusLabel.font = UIFont(name: "PingFangSC-Regular", size: 11) // 22px -> 11pt
            statusLabel.textColor = .white
            // 加了等级之后这一行会明显变长（德/法尤其），和右边的到期日挤在一行里，
            // 允许小幅缩字号，别让任何一边被截成「…」。
            statusLabel.adjustsFontSizeToFitWidth = true
            statusLabel.minimumScaleFactor = 0.75
            
            // 「标题 + 日期」统一走 SubscriptionManager.expiryStatusText()：标题随续订状态变，
            // 全 App 只用「下次扣费日 / 到期日」两个词（原来这里是「有效期至」、套餐卡是
            // 「续费/到期」、续订管理页是「续期时间」，同一个事实三种说法）。
            let expiryLabel = UILabel()
            expiryLabel.text = SubscriptionManager.shared.expiryStatusText()
            expiryLabel.font = UIFont(name: "PingFangSC-Regular", size: 11)
            expiryLabel.textColor = .white
            
            infoRow.addArrangedSubview(statusLabel)
            infoRow.addArrangedSubview(expiryLabel)
            
            // Info Row needs to be wide
            contentStack.addArrangedSubview(infoRow)
            infoRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -40).isActive = true
            
        } else {
            bgImageView.image = UIImage(named: "sub_bg")
            
            // Not Subscribed Layout
            // Centered Title and Paragraph
            
            contentStack.addArrangedSubview(titleLabel)
            contentStack.setCustomSpacing(27, after: titleLabel) // 设计稿 54px

            let subtitleLabel = UILabel()
            subtitleLabel.numberOfLines = 0
            subtitleLabel.textAlignment = .center
            // Use attributed string for "You are not a member\nSubscribe..."
            let text = L("subscription.not_member") + "\n" + L("subscription.not_member_desc")
            subtitleLabel.font = UIFont(name: "PingFangSC-Light", size: 12) // 24px -> 12pt
            subtitleLabel.textColor = .white
            // 行高 38px -> 19pt：两行之间明显比默认松，设计稿的卡片高度是按这个撑出来的。
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.minimumLineHeight = 19
            paragraph.maximumLineHeight = 19
            subtitleLabel.attributedText = NSAttributedString(
                string: text,
                attributes: [.paragraphStyle: paragraph])

            contentStack.addArrangedSubview(subtitleLabel)
            // 左右各留出麦穗的位置，长语言（德/法）折行也不会压到装饰上。
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualTo: contentStack.widthAnchor, constant: -80).isActive = true
        }
        
        // 未订阅态的麦穗是整张背景图的一部分，卡片高度必须锁在设计稿的 335×150，
        // 否则高度被文字撑出来后 scaleAspectFill 会把两侧的穗子裁掉半截。
        let bottomConstraint = contentStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -25)
        if !isSubscribed {
            bottomConstraint.priority = .defaultLow
            container.heightAnchor.constraint(
                equalTo: container.widthAnchor,
                multiplier: 150.0 / 335.0).isActive = true
        }

        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: container.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            bottomConstraint,
            contentStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            contentStack.widthAnchor.constraint(equalTo: container.widthAnchor)
        ])

        // 右上角的进入箭头：卡片整块可点，但没有任何视觉提示时用户不知道能点，
        // 设计稿补了这个箭头。它只是标识，点击仍走整卡的手势。
        let enterArrow = UIImageView(image: UIImage(named: "sub_card_enter"))
        enterArrow.translatesAutoresizingMaskIntoConstraints = false
        enterArrow.contentMode = .scaleAspectFit
        container.addSubview(enterArrow)
        NSLayoutConstraint.activate([
            enterArrow.widthAnchor.constraint(equalToConstant: 7),   // 设计稿 13px
            enterArrow.heightAnchor.constraint(equalToConstant: 13), // 设计稿 25px
            enterArrow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20), // 设计稿 40px
            enterArrow.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
        ])

        // 点击顶部会员卡 → 进入「陪伴足迹」（订阅与否都可进入，无数据时展示空态）。
        // 系统订阅管理仍可从页脚「续费管理」进入。
        container.isUserInteractionEnabled = true
        container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleFootprintTap)))

        return container
    }

    /// 顶部资料卡左下角那行会员状态。
    ///
    /// 原来只写「生效中 · 月度订阅」，分了普通/高级两档之后光看周期分不出等级——
    /// 高级年度和普通年度在卡上长得一模一样。现在统一带上等级。
    ///
    /// 另外三种非购买途径的会员也得说清楚，否则文案会撒谎：
    ///  - 注册即送的体验期：不是「生效中」，也没有月度/年度可言；
    ///  - 服务端兑换（礼品卡/兑换码）：有等级但没有 StoreKit 周期，写「月度/年度」是编的；
    ///    原来的三元判断会把它一律落到「年度订阅」上。
    private static func membershipStatusText() -> String {
        let manager = SubscriptionManager.shared
        let tierKey = manager.membershipTier == .premium ? "subscription.plan.tier.premium"
                                                         : "subscription.plan.tier.basic"
        let tierName = L(tierKey)

        if manager.paidMembershipTier == .free {
            // 没有真实购买：体验期 / 兑换会员
            if manager.isPremiumTrialActive {
                return String(format: L("subscription.status.trial"), tierName)
            }
            return String(format: L("subscription.status.granted"), tierName)
        }

        let periodName = L(manager.currentPlan == .yearly ? "subscription.plan_name.yearly"
                                                          : "subscription.plan_name.monthly")
        return String(format: L("subscription.status.active"), tierName, periodName)
    }

    @objc private func handleFootprintTap() {
        let vc = CompanionFootprintViewController()
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true, completion: nil)
    }
    
    /// 「会员订阅 / 选择会员等级与付费周期」两行标题（在订阅卡外面，不在卡里）。
    private func createPlanSectionHeader() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = L("subscription.section.title")
        title.font = UIFont(name: "PingFangSC-Regular", size: 18)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = L("subscription.plan.subheader")
        subtitle.font = UIFont(name: "PingFangSC-Regular", size: 9.5)
        subtitle.textColor = UIColor(white: 1, alpha: 0.8)
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(title)
        container.addSubview(subtitle)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            title.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 5),
            subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subtitle.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            subtitle.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }


    private func createGiftCardSection() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0) // #2C2C2C
        container.layer.cornerRadius = 12

        let btn = UIButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(handleGiftCardTap), for: .touchUpInside)

        let label = UILabel()
        label.text = L("subscription.giftcard.entry")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        let arrow = UIImageView(image: UIImage(named: "enter_icon"))
        arrow.contentMode = .scaleAspectFit
        arrow.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(label)
        btn.addSubview(arrow)
        container.addSubview(btn)

        NSLayoutConstraint.activate([
            btn.topAnchor.constraint(equalTo: container.topAnchor),
            btn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            btn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            btn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            btn.heightAnchor.constraint(equalToConstant: 50),

            label.leadingAnchor.constraint(equalTo: btn.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: btn.centerYAnchor),

            arrow.trailingAnchor.constraint(equalTo: btn.trailingAnchor),
            arrow.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 12),
            arrow.heightAnchor.constraint(equalToConstant: 12)
        ])

        return container
    }

    @objc private func handleGiftCardTap() {
        let vc = RedeemCodeViewController()
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true, completion: nil)
    }

    private func createFooterSection() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0) // #2C2C2C
        container.layer.cornerRadius = 12
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0 // Using separators manually
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let itemKeys = [
            "subscription.help.faq",
            "subscription.help.message",
            "subscription.help.renewal",
            "subscription.help.restore",
            "subscription.help.community",
            "subscription.help.contact",
            // App Store 订阅合规：订阅页必须提供隐私政策 + 用户协议入口（App 内浏览器打开）。隐私优先。
            "sidemenu.privacy_policy",
            "sidemenu.terms"
        ]
        
        for (index, key) in itemKeys.enumerated() {
            let btn = UIButton()
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
            btn.tag = index
            btn.addTarget(self, action: #selector(handleHelpItemTap(_:)), for: .touchUpInside)
            
            let label = UILabel()
            label.text = L(key)
            label.font = UIFont.systemFont(ofSize: 14)
            label.textColor = .white
            label.translatesAutoresizingMaskIntoConstraints = false
            
            let arrow = UIImageView(image: UIImage(named: "enter_icon")) // or system chevron
            arrow.contentMode = .scaleAspectFit
            arrow.translatesAutoresizingMaskIntoConstraints = false
            
            btn.addSubview(label)
            btn.addSubview(arrow)
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: btn.leadingAnchor),
                label.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
                
                arrow.trailingAnchor.constraint(equalTo: btn.trailingAnchor),
                arrow.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
                arrow.widthAnchor.constraint(equalToConstant: 12),
                arrow.heightAnchor.constraint(equalToConstant: 12)
            ])
            
            stack.addArrangedSubview(btn)
            
            // Add Separator below item (except last?) Use solid separator.
            if index != itemKeys.count - 1 {
                let sep = SubscriptionLineSeparatorView(style: .solid)
                sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stack.addArrangedSubview(sep)
            }
        }
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])
        
        return container
    }

    @objc private func handleHelpItemTap(_ sender: UIButton) {
        // 0: faq, 1: message, 2: renewal, 3: restore, 4: community, 5: contact
        switch sender.tag {
        case 0:
            let vc = FAQViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        case 1:
            // Message - Same as Notifications in SideMenu
            let vc = NotificationsViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        case 2:
            let vc = RenewalManagementViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        case 3:
            handleRestore()
        case 4:
            // Community - Same as noDeviceButtonTapped in StartViewController
            guard let url = URL(string: Constants.Network.mindoraWebURL) else { return }
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .pageSheet
            self.present(safariVC, animated: true)
        case 5:
            let vc = HelpViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        case 6:
            // 隐私政策：App 内浏览器打开（无自定义标题）。
            if let url = URL(string: Constants.Network.privacyPolicyURL) {
                self.present(SFSafariViewController(url: url), animated: true, completion: nil)
            }
        case 7:
            // 用户协议：App 内浏览器打开（无自定义标题）。
            if let url = URL(string: Constants.Network.termsOfUseURL) {
                self.present(SFSafariViewController(url: url), animated: true, completion: nil)
            }
        default:
            break
        }
    }

    /// 恢复购买的超时上限。AppStore.sync() 会弹系统登录框，
    /// 遇到网络/账号异常时可能迟迟不返回。
    private static let restoreTimeout: TimeInterval = 30

    private func handleRestore() {
        let alert = UIAlertController(title: nil, message: L("subscription.restore.loading"), preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        indicator.hidesWhenStopped = true
        indicator.style = .medium
        indicator.startAnimating()
        alert.view.addSubview(indicator)

        // 必须给出口。这个 alert 盖住整页，原来既没有按钮也没有超时：
        // 只要 AppStore.sync() 不返回，用户连返回按钮都点不到，只能杀 App。
        alert.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel) { [weak self] _ in
            self?.restoreTask?.cancel()
            self?.restoreTask = nil
        })

        present(alert, animated: true) { [weak self] in
            guard let self else { return }
            self.restoreTask = Task { [weak self] in
                await Self.restoreWithTimeout()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.restoreTask != nil else { return }
                    self.restoreTask = nil
                    // 用户已按取消的话 alert 早被系统收走了，这里 dismiss 是空操作
                    alert.dismiss(animated: true) {
                        self.showRestoreResult()
                    }
                }
            }
        }
    }

    /// 恢复购买跑到超时就放弃等待，让 UI 能继续往下走。
    /// AppStore.sync() 本身不保证响应取消，所以这里只是不再等它，而不是真的中止它。
    private static func restoreWithTimeout() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await SubscriptionManager.shared.restore() }
            group.addTask { try? await Task.sleep(nanoseconds: UInt64(restoreTimeout * 1_000_000_000)) }
            await group.next()
            group.cancelAll()
        }
    }
    
    /// 购买失败（非用户取消）：把 StoreKit 的错误原样弹出来，用户至少知道这单没成。
    @objc private func purchaseFailed(_ note: Notification) {
        let message = (note.userInfo?["message"] as? String) ?? ""
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.ok"), style: .default))
        // StoreKit 的购买页可能还没收干净：从最上层的控制器弹，不然 present 会被系统丢掉、用户什么都看不到。
        var presenter: UIViewController = self
        while let top = presenter.presentedViewController, !(top is UIAlertController) { presenter = top }
        guard !(presenter.presentedViewController is UIAlertController) else { return }
        presenter.present(alert, animated: true)
    }

    private func showRestoreResult() {
        let isSubscribed = SubscriptionManager.shared.isSubscribed
        let message = isSubscribed ? L("subscription.restore.success") : L("subscription.restore.no_purchases")
        
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.ok"), style: .default))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func handleEmailTap() {
        emailIcon.animateButtonTap {
            self.sendEmail()
        }
    }
    
    private func sendEmail() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients([Constants.Contact.supportEmail])
            mail.setSubject(L("subscription.email.subject"))
            
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let osVersion = UIDevice.current.systemVersion
            let deviceModel = UIDevice.current.model
            
            let appVerTitle = L("subscription.email.app_version")
            let iosVerTitle = L("subscription.email.ios_version")
            let deviceTitle = L("subscription.email.device")
            
            let body = """
            
            
            -------------------
            \(appVerTitle): \(appVersion)
            \(iosVerTitle): \(osVersion)
            \(deviceTitle): \(deviceModel)
            """
            
            mail.setMessageBody(body, isHTML: false)
            present(mail, animated: true)
        } else {
            let alert = UIAlertController(title: L("subscription.email.error.title"), message: L("subscription.email.error.message"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("common.ok"), style: .default))
            present(alert, animated: true)
        }
    }
    
    // MARK: - MFMailComposeViewControllerDelegate
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

    @objc private func handleBack() {
        // 只有栈里确实有上一页时才 pop。
        //
        // 睡眠计划的升级入口（SleepPlanUpsellPresenter）会把本页包进一个新建的
        // UINavigationController 当根视图再模态弹出：那时 navigationController 非 nil，
        // 但本页就是栈底，popViewController 无处可退、静默失败 —— 返回按钮看着能点却
        // 毫无反应，加上 viewWillAppear 藏掉了系统返回栏，用户只能杀 App 才出得去。
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            // 被 nav 包着时要连 nav 一起收掉，否则只关自己会留下空壳
            (navigationController ?? self).dismiss(animated: true)
        }
    }
}

// MARK: - LineSeparatorView

class SubscriptionLineSeparatorView: UIView {
    enum Style {
        case solid
        case dashed
    }
    
    private var style: Style
    private let calendarLayer = CALayer()
    
    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        self.style = .solid
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        if style == .dashed {
            let shapeLayer = CAShapeLayer()
            shapeLayer.strokeColor = UIColor(white: 1, alpha: 0.2).cgColor // Slightly transparent for subtle effect
            shapeLayer.lineWidth = 1
            shapeLayer.lineDashPattern = [4, 4] 
            layer.addSublayer(shapeLayer)
        } else {
            calendarLayer.backgroundColor = UIColor(white: 1, alpha: 0.1).cgColor // Faint separator
            layer.addSublayer(calendarLayer)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if style == .dashed {
            if let shapeLayer = layer.sublayers?.first as? CAShapeLayer {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: bounds.height / 2))
                path.addLine(to: CGPoint(x: bounds.width, y: bounds.height / 2))
                shapeLayer.path = path.cgPath
            }
        } else {
            calendarLayer.frame = bounds
        }
    }
}
