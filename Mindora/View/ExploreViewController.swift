import UIKit

final class ExploreViewController: UIViewController {

    // MARK: - UI Components
    private let headerView = UIView()
    private let topBgImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "explore_top_bg"))
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.alpha = 0.6
        return iv
    }()
    private let bottomRightBgImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "explore_bottom_right_bg"))
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.alpha = 0.4
        return iv
    }()
    private let sideBarButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "home_side_bar"), for: .normal)
        return button
    }()
    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "logo_dream"))
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    // 右上角消息通知入口（红点跟随全局未读状态）
    private let notificationButton = NotificationBellButton()

    // 未开通会员遮罩：非订阅用户在洞察页看到「您还不是会员 / 前往订阅」（设计稿 洞察-未开通会员）
    private let subscriptionGate: SubscriptionPromptView = {
        let v = SubscriptionPromptView(copy: .insights)
        v.isHidden = true
        return v
    }()

    // 会员磨砂遮罩（非会员时盖在数据区之上，与睡眠周/月一致）。
    private var overlayMaskView: UIView?

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.backgroundColor = .clear
        return sv
    }()
    
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 32 // More spacing between main sections
        stack.alignment = .fill
        return stack
    }()
    
    // Greeting Section
    private let greetingContainer = UIView()
    private let scoreHeaderView = ExploreScoreHeaderView()
    private let greetingPrefixLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "Kano-Regular", size: 30) ?? UIFont.systemFont(ofSize: 30)
        label.textColor = .white
        return label
    }()

    private let greetingNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Medium", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .medium)
        label.textColor = .white
        return label
    }()
    
    private let introLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private let introDetailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    // Cards
    private let efficiencyCard = ExploreDetailedCardView()
    private let structureCard = ExploreDetailedCardView()
    private let fluctuationCard = ExploreDetailedCardView()
    private let preferenceView = ExplorePreferenceView()
    private let adviceView = ExploreAdviceView()
    private let articlesView = ExploreArticlesView()
    private let emptyStateView = ExploreEmptyStateView()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0) // Dark background
        setupBackgrounds()
        setupHeader()
        setupScrollView()
        setupContent()
        
        // Listen for language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: LocalizationManager.languageDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProfileChange),
            name: .userProfileDidUpdate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHealthAuthorizationChanged),
            name: HealthDataManager.authorizationDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        // 订阅状态变化时刷新（订阅成功后遮罩消失、展示内容）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSubscriptionStatusChanged),
            name: NSNotification.Name("SubscriptionStatusChanged"),
            object: nil
        )

        setupDebugInteractions()
        fetchData()
    }

    @objc private func handleSubscriptionStatusChanged() {
        fetchData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleLanguageChange() {
        fetchData()
    }

    @objc private func handleProfileChange() {
        updateGreetingLabels()
    }

    @objc private func handleHealthAuthorizationChanged() {
        fetchData()
    }

    @objc private func handleAppWillEnterForeground() {
        fetchData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        // 立即按当前会员状态上/撤遮罩，不等数据/StoreKit 解析，避免非会员开 App 后迟迟看不到订阅遮罩。
        updateGreetingLabels()
        updateMembershipOverlay(gated: SubscriptionManager.shared.shouldGatePremiumContent)
        fetchData()
    }
    
    private func fetchData() {
        ExploreManager.shared.fetchExploreData { [weak self] data in
            self?.updateUI(with: data)
        }
    }
    
    private func updateUI(with data: ExploreData) {
        updateGreetingLabels()
        
        // Intro with line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        let attrString = NSAttributedString(
            string: data.introText,
            attributes: [
                .font: UIFont(name: "PingFangSC-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
        )
        introLabel.attributedText = attrString

        let detailText = data.introDetailText
        if detailText.isEmpty {
            introDetailLabel.isHidden = true
        } else {
            introDetailLabel.isHidden = false
            let detailStyle = NSMutableParagraphStyle()
            detailStyle.lineSpacing = 6
            
            let lines = detailText.components(separatedBy: "\n")
            let attributedText = NSMutableAttributedString()
            
            for (index, line) in lines.enumerated() {
                let font: UIFont
                if index == 0 {
                    // First line Normal (Regular)
                    font = UIFont(name: "PingFangSC-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .regular)
                } else {
                    // Second line Medium
                    font = UIFont(name: "PingFangSC-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
                }
                
                let lineText = line + (index < lines.count - 1 ? "\n" : "")
                let lineAttr = NSAttributedString(
                    string: lineText,
                    attributes: [
                        .font: font,
                        .foregroundColor: UIColor.white,
                        .paragraphStyle: detailStyle
                    ]
                )
                attributedText.append(lineAttr)
            }
            introDetailLabel.attributedText = attributedText
        }
        
        // 数据区始终正常渲染；未开通会员时由磨砂遮罩盖住 + 居中订阅弹窗浮于其上
        // （与睡眠「周/月」的 setupNonMemberOverlay 一致，不再隐藏数据区/内嵌卡片）。
        // 遮罩开/关由 shouldGatePremiumContent 决定：非会员立即上遮罩（不等 StoreKit 异步解析），
        // 老会员靠 lastKnownSubscribed 不闪遮罩，解析完成会经 SubscriptionStatusChanged 再刷新一次。
        [efficiencyCard, structureCard, fluctuationCard, preferenceView, adviceView, articlesView]
            .forEach { $0.isHidden = false }

        let allGradients = [ExploreGradients.efficiency, ExploreGradients.structure, ExploreGradients.fluctuation]

        if data.hasData {
            scoreHeaderView.isHidden = false

            scoreHeaderView.configure(
                score: data.scoreValue,
                title: data.scoreTitle,
                gradients: allGradients,
                values: [data.efficiencyRingValue, data.structureRingValue, data.fluctuationRingValue]
            )
        } else {
            scoreHeaderView.isHidden = true
        }
        
        // Efficiency
        efficiencyCard.configure(
            title: L("explore.section.efficiency"),
            score: data.efficiencyScore,
            status: data.efficiencyStatus,
            chartHeight: 14,
            mainStat: String(format: L("explore.metric.onset_time"), data.efficiencyOnsetTime),
            details: [
                (L("explore.efficiency.first_sleep"), data.efficiencyFirstSleepTime),
                (L("explore.efficiency.pre_hr"), data.efficiencyBeforeHr),
                (L("explore.efficiency.pre_resp"), data.efficiencyBeforeRespiration)
            ],
            description: data.efficiencyDesc,
            hasData: data.hasData,
            gradientColors: ExploreGradients.efficiency
        )
        
        // Structure
        structureCard.configure(
            title: L("explore.section.structure"),
            score: data.structureScore,
            status: data.structureStatus,
            chartHeight: 14,
            mainStat: String(format: L("explore.metric.continuous_sleep"), data.structureContinuous),
            details: [
                (L("explore.structure.rem"), data.structureRem),
                (L("explore.structure.deep"), data.structureDeep),
                (L("explore.structure.light"), data.structureLight)
            ],
            description: data.structureDesc,
            hasData: data.hasData,
            gradientColors: ExploreGradients.structure
        )
        
        // Fluctuation
        fluctuationCard.configure(
            title: L("explore.section.fluctuation"),
            score: data.fluctuationScore,
            status: data.fluctuationStatus,
            chartHeight: 14,
            mainStat: String(format: L("explore.metric.smart_intervention"), data.fluctuationIntervention),
            details: [
                (L("explore.fluctuation.awake_count"), data.fluctuationAwakeCount),
                (L("explore.fluctuation.awake_duration"), data.fluctuationAwakeDuration),
                (L("explore.fluctuation.awake_type"), data.fluctuationAwakeType),
                (L("explore.fluctuation.hr_range"), data.fluctuationHrRange),
                (L("explore.fluctuation.resp_range"), data.fluctuationRespRange)
            ],
            description: data.fluctuationDesc,
            hasData: data.hasData,
            gradientColors: ExploreGradients.fluctuation
        )
        
        // Preference
        preferenceView.configure(
            sceneId: data.sceneId,
            sceneName: data.sceneName,
            sceneType: data.sceneType,
            badgeText: data.hasData ? L("explore.preference.recent") : "",
            text: data.preferenceDesc,
            hasData: data.hasData
        )
        
        // Advice
        adviceView.configure(text: data.adviceDesc, hasData: data.hasData)

        // Articles
        articlesView.configure(quote: data.quoteText, articles: data.articles)

        // Empty State
        emptyStateView.configure(
            scoreText: data.emptyStateScore,
            title: data.emptyStateTitle,
            message: data.emptyStateMessage,
            isHidden: data.hasData,
            ringGradients: [ExploreGradients.efficiency, ExploreGradients.structure, ExploreGradients.fluctuation]
        )

        // 会员遮罩：深色磨砂层 + 居中订阅弹窗（与睡眠周/月一致；权益解析完成前不遮罩）。
        updateMembershipOverlay(gated: SubscriptionManager.shared.shouldGatePremiumContent)
    }

    // MARK: - 会员磨砂遮罩（与睡眠周/月 setupNonMemberOverlay 一致）

    private func updateMembershipOverlay(gated: Bool) {
        if gated {
            setupNonMemberOverlay()
            scrollView.isScrollEnabled = false
        } else {
            removeNonMemberOverlay()
            scrollView.isScrollEnabled = true
        }
    }

    private func setupNonMemberOverlay() {
        guard overlayMaskView == nil else { return }
        view.layoutIfNeeded()

        // 深色磨砂玻璃遮罩（与睡眠周/月 setupNonMemberOverlay 完全一致：UIBlurEffect(.dark) + alpha 0.9）。
        let mask = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        mask.alpha = 0.9
        mask.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mask)
        overlayMaskView = mask

        // 订阅弹窗：宽 214，居中浮于磨砂层之上（与睡眠一致：textStack/greeting 底部下方 47pt）。
        subscriptionGate.translatesAutoresizingMaskIntoConstraints = false
        subscriptionGate.isHidden = false
        view.addSubview(subscriptionGate)

        NSLayoutConstraint.activate([
            // 磨砂层从问候/简介底部下方 10pt 起，铺满到屏幕底部与左右边缘
            mask.topAnchor.constraint(equalTo: greetingContainer.bottomAnchor, constant: 10),
            mask.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mask.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mask.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // 弹窗位置（与睡眠周/月一致：greeting 底部下方 47pt）
            subscriptionGate.topAnchor.constraint(equalTo: greetingContainer.bottomAnchor, constant: 47),
            subscriptionGate.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subscriptionGate.widthAnchor.constraint(equalToConstant: 214)
        ])

        view.bringSubviewToFront(mask)
        view.bringSubviewToFront(subscriptionGate)
    }

    private func removeNonMemberOverlay() {
        overlayMaskView?.removeFromSuperview()
        overlayMaskView = nil
        if subscriptionGate.superview != nil {
            subscriptionGate.removeFromSuperview()
        }
    }

    private func updateGreetingLabels() {
        greetingPrefixLabel.text = L("explore.greeting.hi")
        greetingNameLabel.text = resolvedGreetingName()
    }

    private func resolvedGreetingName() -> String {
        let draft = UserProfileStore.shared.load(accountEmail: AuthStorage.shared.email)

        let nickname = draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nickname.isEmpty {
            return nickname
        }

        let email = (AuthStorage.shared.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.isEmpty {
            let prefix = email.split(separator: "@").first.map(String.init) ?? email
            if !prefix.isEmpty {
                return prefix
            }
        }

        let uid = (AuthStorage.shared.uid ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !uid.isEmpty {
            return uid
        }

        return L("user_profile.username_default")
    }

    private func setupBackgrounds() {
        view.addSubview(topBgImageView)
        view.addSubview(bottomRightBgImageView)
        topBgImageView.translatesAutoresizingMaskIntoConstraints = false
        bottomRightBgImageView.translatesAutoresizingMaskIntoConstraints = false

        let topRatio: CGFloat
        if let image = topBgImageView.image, image.size.width > 0 {
            topRatio = image.size.height / image.size.width
        } else {
            topRatio = 0.6
        }

        let bottomRatio: CGFloat
        if let image = bottomRightBgImageView.image, image.size.width > 0 {
            bottomRatio = image.size.height / image.size.width
        } else {
            bottomRatio = 1.0
        }

        NSLayoutConstraint.activate([
            topBgImageView.topAnchor.constraint(equalTo: view.topAnchor),
            topBgImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBgImageView.widthAnchor.constraint(equalTo: view.widthAnchor),
            topBgImageView.heightAnchor.constraint(equalTo: topBgImageView.widthAnchor, multiplier: topRatio),

            bottomRightBgImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomRightBgImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomRightBgImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),
            bottomRightBgImageView.heightAnchor.constraint(equalTo: bottomRightBgImageView.widthAnchor, multiplier: bottomRatio)
        ])
    }
    
    // MARK: - UI Setup
    private func setupHeader() {
        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(sideBarButton)
        headerView.addSubview(logoImageView)
        headerView.addSubview(notificationButton)
        sideBarButton.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        notificationButton.translatesAutoresizingMaskIntoConstraints = false

        sideBarButton.addTarget(self, action: #selector(handleSideBarBtnTapped), for: .touchUpInside)
        notificationButton.addTarget(self, action: #selector(handleNotificationTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),

            sideBarButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            sideBarButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            sideBarButton.widthAnchor.constraint(equalToConstant: 24),
            sideBarButton.heightAnchor.constraint(equalToConstant: 24),

            logoImageView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            logoImageView.heightAnchor.constraint(equalToConstant: 30),
            logoImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 153),

            notificationButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            notificationButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            notificationButton.widthAnchor.constraint(equalToConstant: 28),
            notificationButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func handleNotificationTapped() {
        let vc = NotificationsViewController()
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        scrollView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -50),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }
    
    private func setupContent() {
        // Greeting container - two labels in justify-between layout
        greetingContainer.addSubview(greetingPrefixLabel)
        greetingContainer.addSubview(greetingNameLabel)
        greetingContainer.addSubview(introLabel)
        greetingContainer.addSubview(introDetailLabel)
        
        greetingPrefixLabel.translatesAutoresizingMaskIntoConstraints = false
        greetingNameLabel.translatesAutoresizingMaskIntoConstraints = false
        introLabel.translatesAutoresizingMaskIntoConstraints = false
        introDetailLabel.translatesAutoresizingMaskIntoConstraints = false

        greetingPrefixLabel.setContentHuggingPriority(.required, for: .horizontal)
        greetingPrefixLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        greetingNameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        greetingNameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        // Fill the greeting container's width by default (iPhone always satisfies this,
        // since it's narrower than maxTextWidth below). On iPad, the required max-width
        // constraint wins instead, keeping these two paragraphs at a readable line length —
        // left-aligned under the "Hi, name" line — rather than stretching edge-to-edge
        // across the whole screen. Only these text labels are capped; greetingContainer
        // itself (and therefore contentStack and the full-width cards below it) is untouched.
        let introTrailingFill = introLabel.trailingAnchor.constraint(equalTo: greetingContainer.trailingAnchor)
        let introDetailTrailingFill = introDetailLabel.trailingAnchor.constraint(equalTo: greetingContainer.trailingAnchor)
        introTrailingFill.priority = .defaultHigh
        introDetailTrailingFill.priority = .defaultHigh
        let maxTextWidth: CGFloat = 700

        NSLayoutConstraint.activate([
            greetingPrefixLabel.topAnchor.constraint(equalTo: greetingContainer.topAnchor),
            greetingPrefixLabel.leadingAnchor.constraint(equalTo: greetingContainer.leadingAnchor),

            greetingNameLabel.firstBaselineAnchor.constraint(equalTo: greetingPrefixLabel.firstBaselineAnchor),
            greetingNameLabel.leadingAnchor.constraint(equalTo: greetingPrefixLabel.trailingAnchor, constant: 4),
            greetingNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: greetingContainer.trailingAnchor),

            introLabel.topAnchor.constraint(equalTo: greetingPrefixLabel.bottomAnchor, constant: 16),
            introLabel.leadingAnchor.constraint(equalTo: greetingContainer.leadingAnchor),
            introTrailingFill,
            // 填满约束与标签的抗压缩同为 750，长段落时会把标签撑出屏幕；右边界必须是硬约束
            introLabel.trailingAnchor.constraint(lessThanOrEqualTo: greetingContainer.trailingAnchor),
            introLabel.widthAnchor.constraint(lessThanOrEqualToConstant: maxTextWidth),

            introDetailLabel.topAnchor.constraint(equalTo: introLabel.bottomAnchor, constant: 12),
            introDetailLabel.leadingAnchor.constraint(equalTo: greetingContainer.leadingAnchor),
            introDetailTrailingFill,
            introDetailLabel.trailingAnchor.constraint(lessThanOrEqualTo: greetingContainer.trailingAnchor),
            introDetailLabel.widthAnchor.constraint(lessThanOrEqualToConstant: maxTextWidth),
            introDetailLabel.bottomAnchor.constraint(equalTo: greetingContainer.bottomAnchor)
        ])
        
        contentStack.addArrangedSubview(greetingContainer)
        // subscriptionGate 不再内嵌进流式布局：改为非会员时作为浮层弹窗叠加在磨砂遮罩之上
        // （见 setupNonMemberOverlay，对齐睡眠周/月设计）。
        contentStack.addArrangedSubview(scoreHeaderView)
        contentStack.addArrangedSubview(emptyStateView)
        subscriptionGate.onSubscribeTap = { [weak self] in
            let vc = SubscriptionViewController()
            if let nav = self?.navigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                vc.modalPresentationStyle = .fullScreen
                self?.present(vc, animated: true)
            }
        }
        contentStack.addArrangedSubview(efficiencyCard)
        contentStack.addArrangedSubview(structureCard)
        contentStack.addArrangedSubview(fluctuationCard)
        contentStack.addArrangedSubview(preferenceView)
        contentStack.addArrangedSubview(adviceView)
        // 文章推荐卡片暂时隐藏（不加入布局）。需要恢复时取消注释本行即可。
        // contentStack.addArrangedSubview(articlesView)
    }

    @objc private func handleSideBarBtnTapped() {
        let sideMenuVC = SideMenuViewController()
        sideMenuVC.modalPresentationStyle = .overFullScreen
        self.present(sideMenuVC, animated: false, completion: nil)
    }
    
    private func setupDebugInteractions() {
        #if DEBUG
        // Triple tap on logo to toggle mock data
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDebugToggle))
        tapGesture.numberOfTapsRequired = 3
        logoImageView.addGestureRecognizer(tapGesture)
        logoImageView.isUserInteractionEnabled = true
        #endif
    }
    
    @objc private func handleDebugToggle() {
        #if DEBUG
        Constants.Config.showMockData.toggle()
        fetchData()
        #endif
    }
}

// MARK: - Components

// Better matched Card View
class ExploreDetailedCardView: UIView {
    private let cardBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 44/255.0, green: 44/255.0, blue: 44/255.0, alpha: 1.0)
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor(white: 1.0, alpha: 0.08).cgColor
        view.clipsToBounds = true
        view.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 20, right: 20)
        return view
    }()
    private let titleLabel: UILabel = {
        let label = UILabel()
        // CSS: 36px -> 18pt, SourceHanSansCN-Bold
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white 
        return label
    }()
    
    private let scoreLabel: UILabel = {
        let label = UILabel()
        // CSS: 36px -> 18pt, HKGrotesk-SemiBold
        label.font = UIFont(name: "HKGrotesk-SemiBold", size: 18) ?? UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        // CSS: 24px -> 12pt, SourceHanSansCN-Medium, white
        label.font = UIFont(name: "PingFangSC-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.6)
        return label
    }()
    
    private let chartPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 60/255.0, green: 60/255.0, blue: 60/255.0, alpha: 1.0)
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        return view
    }()
    
    private let progressView: ExploreGradientView = {
        let view = ExploreGradientView()
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        return view
    }()
    
    private var progressWidthConstraint: NSLayoutConstraint?
    
    private let mainStatLabel: UILabel = {
        let label = UILabel()
        // CSS: 24px -> 12pt, SourceHanSansCN-Medium, white
        label.font = UIFont(name: "PingFangSC-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.6)
        return label
    }()
    
    // Details Container (The dark block at bottom)
    private let detailsContainer: UIView = {
        let view = UIView()
        // CSS: box_2, background color rgba(24, 24, 24, 1)
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        view.layer.cornerRadius = 12
        return view
    }()
    
    private let detailsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        // CSS: 22px -> 11pt, SourceHanSansCN-Normal, white
        label.font = UIFont(name: "PingFangSC-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) { nil }
    
    private func setup() {
        addSubview(cardBackgroundView)
        cardBackgroundView.addSubview(titleLabel)
        cardBackgroundView.addSubview(scoreLabel)
        cardBackgroundView.addSubview(statusLabel)
        cardBackgroundView.addSubview(chartPlaceholder)
        chartPlaceholder.addSubview(progressView)
        cardBackgroundView.addSubview(mainStatLabel)
        cardBackgroundView.addSubview(detailsContainer)
        
        detailsContainer.addSubview(detailsStack)
        
        cardBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        chartPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        mainStatLabel.translatesAutoresizingMaskIntoConstraints = false
        detailsContainer.translatesAutoresizingMaskIntoConstraints = false
        detailsStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            cardBackgroundView.topAnchor.constraint(equalTo: topAnchor),
            cardBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: cardBackgroundView.layoutMarginsGuide.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: cardBackgroundView.layoutMarginsGuide.leadingAnchor),
            
            // CSS: margin-top: 42px -> 21pt
            scoreLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 21),
            scoreLabel.leadingAnchor.constraint(equalTo: cardBackgroundView.layoutMarginsGuide.leadingAnchor),
            
            statusLabel.centerYAnchor.constraint(equalTo: scoreLabel.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: cardBackgroundView.layoutMarginsGuide.trailingAnchor),
            
            // CSS: margin-top: 16px -> 8pt
            chartPlaceholder.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 8),
            chartPlaceholder.leadingAnchor.constraint(equalTo: cardBackgroundView.layoutMarginsGuide.leadingAnchor),
            chartPlaceholder.trailingAnchor.constraint(equalTo: cardBackgroundView.layoutMarginsGuide.trailingAnchor),
            chartPlaceholder.heightAnchor.constraint(equalToConstant: 28), // Default, updated in configure
            
            progressView.topAnchor.constraint(equalTo: chartPlaceholder.topAnchor),
            progressView.bottomAnchor.constraint(equalTo: chartPlaceholder.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: chartPlaceholder.leadingAnchor),
            
            // CSS: margin-top: 20px -> 10pt
            mainStatLabel.topAnchor.constraint(equalTo: chartPlaceholder.bottomAnchor, constant: 10),
            mainStatLabel.leadingAnchor.constraint(equalTo: cardBackgroundView.layoutMarginsGuide.leadingAnchor),
            
            // CSS: margin-top: 42px -> 21pt
            detailsContainer.topAnchor.constraint(equalTo: mainStatLabel.bottomAnchor, constant: 16),
            detailsContainer.leadingAnchor.constraint(equalTo: cardBackgroundView.layoutMarginsGuide.leadingAnchor),
            detailsContainer.trailingAnchor.constraint(equalTo: cardBackgroundView.layoutMarginsGuide.trailingAnchor),
            detailsContainer.bottomAnchor.constraint(equalTo: cardBackgroundView.layoutMarginsGuide.bottomAnchor),
            
            // CSS: padding: 48px 30px -> Top 24pt, Side 15pt
            detailsStack.topAnchor.constraint(equalTo: detailsContainer.topAnchor, constant: 16),
            detailsStack.leadingAnchor.constraint(equalTo: detailsContainer.leadingAnchor, constant: 16),
            detailsStack.trailingAnchor.constraint(equalTo: detailsContainer.trailingAnchor, constant: -16),
            detailsStack.bottomAnchor.constraint(equalTo: detailsContainer.bottomAnchor, constant: -16)
        ])
    }
    
    func configure(title: String, score: String, status: String, chartHeight: CGFloat, mainStat: String, details: [(String, String)], description: String, hasData: Bool, gradientColors: [UIColor]? = nil) {
        titleLabel.text = title
        scoreLabel.text = score
        statusLabel.text = status
        mainStatLabel.text = mainStat
        
        // Update Chart placeholder
        for constraint in chartPlaceholder.constraints where constraint.firstAttribute == .height {
            constraint.constant = chartHeight
        }
        
        if let colors = gradientColors {
            progressView.colors = colors
        } else {
            progressView.colors = [UIColor(red: 60/255.0, green: 60/255.0, blue: 60/255.0, alpha: 1.0), UIColor(red: 60/255.0, green: 60/255.0, blue: 60/255.0, alpha: 1.0)]
        }
        
        let numericScore = Double(score.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
        let ratio = CGFloat(min(max(numericScore, 0), 100) / 100.0)
        
        if let constraint = progressWidthConstraint {
            constraint.isActive = false
        }
        progressWidthConstraint = progressView.widthAnchor.constraint(equalTo: chartPlaceholder.widthAnchor, multiplier: ratio)
        progressWidthConstraint?.isActive = true
        
        // Clear details
        detailsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add detail rows
        for (label, value) in details {
            let row = createDetailRow(title: label, value: value)
            detailsStack.addArrangedSubview(row)
        }
        
        // Add divider if needed, or spacing
        if !description.isEmpty {
            let spacer = UIView()
            spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
            detailsStack.addArrangedSubview(spacer)
            
            descriptionLabel.text = description
            // Improve paragraph spacing for description
            let paragraphStyle = NSMutableParagraphStyle()
            // CSS: line-height: 32px (font 22px) -> line spacing ~ 10px -> 5pt? 
            // Or typically lineSpacing in iOS is extra space. 
            // 32px line height for 22px font = 1.45x. 
            // 16pt line height for 11pt font.
            // Minimum line height 16pt.
            paragraphStyle.minimumLineHeight = 16
            paragraphStyle.maximumLineHeight = 16
            
            let attrString = NSAttributedString(string: description, attributes: [
                .font: UIFont(name: "PingFangSC-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .paragraphStyle: paragraphStyle
            ])
            descriptionLabel.attributedText = attrString
            
            detailsStack.addArrangedSubview(descriptionLabel)
        }
    }
    
    private func createDetailRow(title: String, value: String) -> UIView {
        let view = UIView()
        let titleLbl = UILabel()
        titleLbl.text = title
        // CSS: 24px -> 12pt, SourceHanSansCN-Medium, white
        titleLbl.font = UIFont(name: "PingFangSC-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLbl.textColor = .white
        
        let valueLbl = UILabel()
        valueLbl.text = value
        // CSS: 24px -> 12pt, SourceHanSansCN-Bold, white
        valueLbl.font = UIFont(name: "PingFangSC-Semibold", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .semibold)
        valueLbl.textColor = .white
        valueLbl.textAlignment = .left // Align left for values column
        
        view.addSubview(titleLbl)
        view.addSubview(valueLbl)
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        valueLbl.translatesAutoresizingMaskIntoConstraints = false
        
        // 英文标签较长（如 "Respiratory Rate Before Sleep"），左列放不下时折行而不是截断；
        // 单行时行高仍是 20pt，与原设计一致。
        titleLbl.numberOfLines = 0
        let singleLineHeight = view.heightAnchor.constraint(equalToConstant: 20) // Reduced height from 24
        singleLineHeight.priority = .defaultLow

        NSLayoutConstraint.activate([
            singleLineHeight,
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            titleLbl.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor),
            titleLbl.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),

            titleLbl.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleLbl.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            titleLbl.trailingAnchor.constraint(lessThanOrEqualTo: valueLbl.leadingAnchor, constant: -10),
            
            valueLbl.widthAnchor.constraint(equalToConstant: 140), // Fixed width for alignment
            valueLbl.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            valueLbl.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }
}

class ExplorePreferenceView: UIView {
    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()
    
    // The main container for the entire preference card (Dark background)
    // Coresponds to .group_7 in CSS
    private let mainContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 44/255.0, green: 44/255.0, blue: 44/255.0, alpha: 1.0)
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor(white: 1.0, alpha: 0.08).cgColor
        view.clipsToBounds = true
        return view
    }()

    private let badgeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        return view
    }()

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Regular", size: 9) ?? UIFont.systemFont(ofSize: 9)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    // Coresponds to .box_4 in CSS (Image container)
    private let imageContainerView: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        view.layer.cornerRadius = 12
        return view
    }()
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    private let sceneTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private let sceneSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.white
        label.numberOfLines = 2
        return label
    }()
    
    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(white: 0.8, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let emptyDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(white: 0.8, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let emptyCardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 44/255.0, green: 44/255.0, blue: 44/255.0, alpha: 1.0)
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor(white: 1.0, alpha: 0.08).cgColor
        view.clipsToBounds = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) { nil }
    
    private func setup() {
        addSubview(containerStack)
        containerStack.addArrangedSubview(titleLabel)
        containerStack.addArrangedSubview(mainContainerView)
        containerStack.addArrangedSubview(emptyCardView)

        containerStack.translatesAutoresizingMaskIntoConstraints = false
        mainContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        mainContainerView.addSubview(imageContainerView)
        mainContainerView.addSubview(contentLabel)
        
        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        imageContainerView.addSubview(imageView)
        imageContainerView.addSubview(badgeContainer)
        badgeContainer.addSubview(badgeLabel)
        imageContainerView.addSubview(sceneTitleLabel)
        imageContainerView.addSubview(sceneSubtitleLabel)
        
        emptyCardView.addSubview(emptyDescriptionLabel)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        sceneTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        sceneSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Main Container Layout
            // CSS: .group_7 padding: 39.5px 35.5px 59.5px 35.5px -> ~20pt top/sides, ~30pt bottom
            imageContainerView.topAnchor.constraint(equalTo: mainContainerView.topAnchor, constant: 20),
            imageContainerView.leadingAnchor.constraint(equalTo: mainContainerView.leadingAnchor, constant: 18),
            imageContainerView.trailingAnchor.constraint(equalTo: mainContainerView.trailingAnchor, constant: -18),
            imageContainerView.heightAnchor.constraint(equalToConstant: 200), // Fixed height for image area
            
            contentLabel.topAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: 24), // margin-top: 48px -> 24pt
            contentLabel.leadingAnchor.constraint(equalTo: mainContainerView.leadingAnchor, constant: 18),
            contentLabel.trailingAnchor.constraint(equalTo: mainContainerView.trailingAnchor, constant: -18),
            contentLabel.bottomAnchor.constraint(equalTo: mainContainerView.bottomAnchor, constant: -30),

            // Image Container Content
            imageView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),
            
            badgeContainer.topAnchor.constraint(equalTo: imageContainerView.topAnchor, constant: 12),
            badgeContainer.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor, constant: -16),
            
            badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 4.5),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -4.5),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 11.5),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -11.5),
            
            sceneSubtitleLabel.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: -24),
            sceneSubtitleLabel.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor, constant: 17),
            
            sceneTitleLabel.bottomAnchor.constraint(equalTo: sceneSubtitleLabel.topAnchor, constant: -8),
            sceneTitleLabel.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor, constant: 17),
            
            emptyDescriptionLabel.topAnchor.constraint(equalTo: emptyCardView.topAnchor, constant: 20),
            emptyDescriptionLabel.leadingAnchor.constraint(equalTo: emptyCardView.leadingAnchor, constant: 16),
            emptyDescriptionLabel.trailingAnchor.constraint(equalTo: emptyCardView.trailingAnchor, constant: -16),
            emptyDescriptionLabel.bottomAnchor.constraint(equalTo: emptyCardView.bottomAnchor, constant: -20)
        ])
    }
    
    func configure(sceneId: String?, sceneName: String?, sceneType: String?, badgeText: String, text: String, hasData: Bool) {
        titleLabel.text = L("explore.section.preference")

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        let attrString = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor(white: 0.8, alpha: 1.0),
                .paragraphStyle: paragraphStyle
            ]
        )

        if hasData {
            mainContainerView.isHidden = false
            emptyCardView.isHidden = true
            contentLabel.attributedText = attrString
        } else {
            mainContainerView.isHidden = true
            emptyCardView.isHidden = false
            emptyDescriptionLabel.attributedText = attrString
        }

        if let name = resolveImageName(sceneId: sceneId, sceneName: sceneName),
           let img = UIImage(named: name) {
            imageView.image = img
            imageView.isHidden = false
        } else {
            imageView.isHidden = true
        }

        badgeLabel.text = badgeText
        badgeContainer.isHidden = badgeText.isEmpty

        sceneTitleLabel.text = sceneName
        sceneSubtitleLabel.text = sceneType
        sceneTitleLabel.isHidden = (sceneName ?? "").isEmpty
        sceneSubtitleLabel.isHidden = (sceneType ?? "").isEmpty
    }

    private func resolveImageName(sceneId: String?, sceneName: String?) -> String? {
        let localAssetMap = [
            "cocos_island_moonlight": "sleep.scene.cocos_island_moonlight",
            "sedona_red_rock_peace": "sleep.scene.sedona_red_rock_peace",
            "bhutan_misty_forest": "sleep.scene.bhutan_misty_forest",
            "kyoto_forest": "sleep.scene.kyoto_forest",
            "taupo_mist_valley": "sleep.music.taupo_mist_valley",
            "fogo_island_cookie_box": "sleep.scene.fogo_island_cookie_box",
            "golden_dune_fantasy": "sleep.music.golden_dune_fantasy",
            "amalfi_breeze": "sleep.scene.amalfi_breeze",
            "andaman_rainforest_sanctuary": "sleep.scene.andaman_rainforest_sanctuary"
        ]

        if let sceneId,
           let mapped = localAssetMap[normalizeSceneKey(sceneId)] {
            return mapped
        }

        if let sceneName {
            let normalizedName = normalizeSceneKey(sceneName)
            if let mapped = localAssetMap[normalizedName] {
                return mapped
            }

            let generatedAssetName = "sleep.scene.\(normalizedName)"
            if UIImage(named: generatedAssetName) != nil {
                return generatedAssetName
            }
        }

        return nil
    }

    private func normalizeSceneKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}

final class ExploreArticlesView: UIView {
    private let quoteContainer = UIView()
    private let openQuote: UILabel = {
        let label = UILabel()
        label.text = "“"
        label.font = UIFont(name: "Kano-Regular", size: 80) ?? UIFont.systemFont(ofSize: 80, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.2)
        label.textAlignment = .center
        return label
    }()

    private let closeQuote: UILabel = {
        let label = UILabel()
        label.text = "”"
        label.font = UIFont(name: "Kano-Regular", size: 80) ?? UIFont.systemFont(ofSize: 80, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.2)
        label.textAlignment = .center
        return label
    }()

    private let quoteLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let articlesStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        addSubview(quoteContainer)
        addSubview(articlesStack)

        quoteContainer.translatesAutoresizingMaskIntoConstraints = false
        articlesStack.translatesAutoresizingMaskIntoConstraints = false

        // Z-order: Quotes behind text
        quoteContainer.addSubview(openQuote)
        quoteContainer.addSubview(closeQuote)
        quoteContainer.addSubview(quoteLabel)
        
        openQuote.translatesAutoresizingMaskIntoConstraints = false
        closeQuote.translatesAutoresizingMaskIntoConstraints = false
        quoteLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            quoteContainer.topAnchor.constraint(equalTo: topAnchor),
            quoteContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            quoteContainer.trailingAnchor.constraint(equalTo: trailingAnchor),

            // QuoteLabel constraints (centered, determining container height)
            // Remove fixed leading/trailing to allow intrinsic width for the text block (up to a max width)
            quoteLabel.topAnchor.constraint(equalTo: quoteContainer.topAnchor, constant: 60),
            quoteLabel.bottomAnchor.constraint(equalTo: quoteContainer.bottomAnchor, constant: -60),
            quoteLabel.centerXAnchor.constraint(equalTo: quoteContainer.centerXAnchor),
            quoteLabel.widthAnchor.constraint(lessThanOrEqualTo: quoteContainer.widthAnchor, constant: -64),
            
            // Open Quote: 
            // Right edge touches Text Left edge
            openQuote.trailingAnchor.constraint(equalTo: quoteLabel.leadingAnchor, constant: 12),
            // Bottom edge touches Text Top edge (Move down significantly to close visual gap)
            openQuote.bottomAnchor.constraint(equalTo: quoteLabel.topAnchor, constant: 65),

            // Close Quote:
            // Left edge touches Text Right edge (Move right to avoid obscuring text)
            closeQuote.leadingAnchor.constraint(equalTo: quoteLabel.trailingAnchor, constant: 2),
            // Top edge touches Text Bottom edge
            closeQuote.topAnchor.constraint(equalTo: quoteLabel.bottomAnchor, constant: -23),

            articlesStack.topAnchor.constraint(equalTo: quoteContainer.bottomAnchor, constant: 20),
            articlesStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            articlesStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            articlesStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func configure(quote: String, articles: [ExploreArticle]) {
        openQuote.text = "“"
        closeQuote.text = "”"
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.alignment = .center
        
        // Font: "思源黑体CNMedium" -> System Medium 14
        let font = UIFont(name: "PingFangSC-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        
        quoteLabel.attributedText = NSAttributedString(
            string: quote,
            attributes: [
                .font: font,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
        )

        articlesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for article in articles {
            let card = ExploreArticleCardView()
            card.configure(article: article)
            articlesStack.addArrangedSubview(card)
        }
    }
}

final class ExploreArticleCardView: UIView {
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 35/255.0, green: 35/255.0, blue: 35/255.0, alpha: 1.0)
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()

    private let thumbnailView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(white: 0.7, alpha: 1.0)
        label.numberOfLines = 2
        return label
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        addSubview(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(thumbnailView)
        cardView.addSubview(textStack)
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        textStack.translatesAutoresizingMaskIntoConstraints = false

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96),

            thumbnailView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            thumbnailView.topAnchor.constraint(equalTo: cardView.topAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 120),

            textStack.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 16),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    func configure(article: ExploreArticle) {
        thumbnailView.image = UIImage(named: article.imageName)
        titleLabel.text = article.title
        subtitleLabel.text = article.subtitle
    }
}

final class ExploreEmptyStateView: UIView {
    private let tipCardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 35/255.0, green: 35/255.0, blue: 35/255.0, alpha: 1.0)
        view.layer.cornerRadius = 16
        return view
    }()

    private let tipLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(white: 0.85, alpha: 1.0)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let scoreContainer = UIView()

    private let ringView = ExploreScoreRingView()

    private let scoreLabel: UILabel = {
        let label = UILabel()
        // 39 而非设计稿的 60：总分压在圆环 270° 缺口那一象限里，满环时末端的百分比标签
        // 必然转到这里来，两者只能靠字号让位 —— 标签要留在轨道上顺着圆环，不能沿半径躲。
        // 实测 100% 那圈（字号每减 1pt 约让出 1.2pt）：60 时被压 25.8pt，44 时只差 2.9pt。
        label.font = UIFont(name: "HKGrotesk-SemiBold", size: 39) ?? UIFont.systemFont(ofSize: 39, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(white: 0.7, alpha: 1.0)
        label.textAlignment = .center
        // 这行字右对齐在圆环右缘，左边缘由文案长度决定：中文「睡眠评分」56pt 富余，
        // 但 Sleep Score 79.7 / Schlafbewertung 111.4 / Puntuación de sueño 139.7pt
        // 会一路顶到圆环起点图标上。**必须保持一行**，靠下面的约束让路：
        // 先整体右移出圆环（环右侧到内容区边缘还有空白），实在不够再缩字号。
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        addSubview(tipCardView)
        addSubview(scoreContainer)

        tipCardView.translatesAutoresizingMaskIntoConstraints = false
        scoreContainer.translatesAutoresizingMaskIntoConstraints = false
        tipCardView.addSubview(tipLabel)
        tipLabel.translatesAutoresizingMaskIntoConstraints = false

        scoreContainer.addSubview(ringView)
        scoreContainer.addSubview(scoreLabel)
        scoreContainer.addSubview(titleLabel)
        ringView.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 「贴齐圆环右缘 8pt」是常态排版，但它得给长文案让路：降一级优先级，
        // 顶不住时由 Auto Layout 打破它、把整行右移出圆环，而不是折行。
        let titleRightInset = titleLabel.trailingAnchor.constraint(
            equalTo: ringView.trailingAnchor, constant: -8)
        titleRightInset.priority = .required - 1

        NSLayoutConstraint.activate([
            tipCardView.topAnchor.constraint(equalTo: topAnchor),
            tipCardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tipCardView.trailingAnchor.constraint(equalTo: trailingAnchor),

            tipLabel.topAnchor.constraint(equalTo: tipCardView.topAnchor, constant: 16),
            tipLabel.leadingAnchor.constraint(equalTo: tipCardView.leadingAnchor, constant: 16),
            tipLabel.trailingAnchor.constraint(equalTo: tipCardView.trailingAnchor, constant: -16),
            tipLabel.bottomAnchor.constraint(equalTo: tipCardView.bottomAnchor, constant: -16),

            scoreContainer.topAnchor.constraint(equalTo: tipCardView.bottomAnchor, constant: 56), // Increased spacing top
            scoreContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            scoreContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            scoreContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24), // Increased spacing bottom

            // Ring Constraint: 
            // Design Layout: Screen Width 375pt, Ring Diameter 230pt.
            // But ExploreEmptyStateView acts inside a container with 40pt total horizontal padding (375 - 40 = 335).
            // So we need to calculate the multiplier based on the content width (335) not screen width (375).
            // Multiplier = 230 / 335 ≈ 0.686
            ringView.centerXAnchor.constraint(equalTo: scoreContainer.centerXAnchor),
            ringView.widthAnchor.constraint(equalTo: scoreContainer.widthAnchor, multiplier: 230.0 / (375.0 - 40.0)),
            ringView.topAnchor.constraint(equalTo: scoreContainer.topAnchor),
            ringView.bottomAnchor.constraint(equalTo: scoreContainer.bottomAnchor),
            // Maintain 1:1 Aspect Ratio
            ringView.heightAnchor.constraint(equalTo: ringView.widthAnchor),

            // Title Label Position:
            // "Bottom and Arc Bottom Tangent Aligned" -> titleLabel.bottom = ringView.bottom
            // "Right and Arc Right Tangent Distance 8pt" -> titleLabel.trailing = ringView.trailing - 8
            titleLabel.bottomAnchor.constraint(equalTo: ringView.bottomAnchor),
            titleRightInset,
            // 左边界不许越过起点图标：图标右缘在圆心 +24.5pt，再留 8pt 呼吸。
            // 中文用不到这条（天然还差 18pt），只有拉丁语系的长文案会被它拦下来。
            titleLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: ringView.centerXAnchor, constant: 32.5),
            // 让路的去处：圆环右侧到内容区边缘还有空白，长文案先整体右移出圆环，
            // 顶到这条才轮到 adjustsFontSizeToFitWidth 缩字号 —— 任何情况都不折行。
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: scoreContainer.trailingAnchor),

            // Score Label Position:
            // "Above Title, Vertically Centered Aligned" -> centerX aligned, stacked
            scoreLabel.centerXAnchor.constraint(equalTo: titleLabel.centerXAnchor),
            scoreLabel.bottomAnchor.constraint(equalTo: titleLabel.topAnchor)
        ])
    }

    func configure(scoreText: String, title: String, message: String, isHidden: Bool, ringGradients: [[UIColor]]? = nil) {
        self.isHidden = isHidden
        scoreLabel.text = scoreText
        titleLabel.text = title
        ringView.segmentGradients = ringGradients

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.alignment = .center
        tipLabel.attributedText = NSAttributedString(
            string: message,
            attributes: [
                .font: UIFont(name: "PingFangSC-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor(white: 0.85, alpha: 1.0),
                .paragraphStyle: paragraphStyle
            ]
        )
    }
}

final class ExploreScoreRingView: UIView {
    var segmentGradients: [[UIColor]]? {
        didSet {
            setNeedsLayout()
        }
    }
    
    var values: [Double] = [0, 0, 0] {
        didSet {
            setNeedsLayout()
        }
    }
    
    private let defaultRingColor = UIColor(red: 44/255.0, green: 44/255.0, blue: 44/255.0, alpha: 1.0).cgColor

    /// 三圈起点旁的说明图标，由外到内依次是 入睡效率 / 睡眠结构 / 夜间波动，
    /// 顺序必须和 values 一致（configure 传进来的就是这个顺序）。
    private static let segmentIconNames = ["explore_ring_efficiency", "explore_ring_structure", "explore_ring_fluctuation"]
    /// 设计稿 24×24px @2x
    private static let segmentIconSize: CGFloat = 12
    /// 图标左边缘与圆环外沿的空隙，设计稿 13px
    private static let segmentIconGap: CGFloat = 6.5

    /// 圆环几何：三条轨道共用，addLabel 摆百分比标签时也要用同一套数
    private static let trackLineWidth: CGFloat = 12
    private static let trackSpacing: CGFloat = 20
    /// 从正下方起画
    private static let trackStartAngle: CGFloat = .pi / 2
    /// 共 270°，缺口落在右下象限（总分就摆在那儿）
    private static let trackMaxAngle: CGFloat = .pi * 1.5

    // 上次渲染签名（尺寸 + 数值 + 渐变）。仅在真正变化时重建图层——否则每次 layoutSubviews
    // 都销毁重建 CAShape/CAGradient 图层并增删 label 子视图，而增删子视图又会再次触发布局，
    // 反复重建过程中图层被释放却仍被引用 → OS_dispatch_queue sublayers 崩溃。
    private var lastRenderKey: String?

    override func layoutSubviews() {
        super.layoutSubviews()

        let gradientKey = (segmentGradients ?? []).map { seg in seg.map { $0.hashValue }.map(String.init).joined(separator: ",") }.joined(separator: ";")
        let renderKey = "\(bounds.size.width)x\(bounds.size.height)|\(values)|\(gradientKey)"
        if renderKey == lastRenderKey { return }
        lastRenderKey = renderKey

        // 清理顺序不能反：子视图（% 标签、起点图标）的 backing layer 也在 layer.sublayers 里，
        // 先把 sublayers 全摘掉，再 removeFromSuperview 时 UIKit 会去读那个已经悬空的 layer，
        // 直接 EXC_BAD_ACCESS（CALayerGetSuperlayer 崩在 0x8）。
        // 必须先让 UIKit 按正规流程移除子视图（它会连带摘掉自己的 layer），
        // 剩下的 sublayers 才只有本方法自己 addSublayer 上去的 CAShape/CAGradient。
        subviews.forEach { $0.removeFromSuperview() }
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let lineWidth = Self.trackLineWidth
        let spacing = Self.trackSpacing
        let startAngle = Self.trackStartAngle
        let maxAngle = Self.trackMaxAngle
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let maxDiameter = min(bounds.width, bounds.height)
        
        // Draw 3 rings from outer to inner
        for i in 0..<3 {
            let currentRadius = (maxDiameter / 2.0) - (lineWidth / 2.0) - CGFloat(i) * (lineWidth + spacing)
            if currentRadius <= 0 { break }
            
            // 1. Draw Background Track (Full 270 degrees)
            let bgPath = UIBezierPath(
                arcCenter: center,
                radius: currentRadius,
                startAngle: startAngle,
                endAngle: startAngle + maxAngle,
                clockwise: true
            )
            
            let bgLayer = CAShapeLayer()
            bgLayer.frame = bounds
            bgLayer.path = bgPath.cgPath
            bgLayer.fillColor = UIColor.clear.cgColor
            bgLayer.strokeColor = defaultRingColor
            bgLayer.lineWidth = lineWidth
            bgLayer.lineCap = .round
            layer.addSublayer(bgLayer)
            
            // 起点图标：环从正下方（startAngle = π/2）起画，那里的切线是水平的，
            // 所以图标就沿切线往右平移，和 cap 保持同一水平线——设计稿就是这么放的，
            // 不能按角度绕着圆挪，那样会比 cap 高出一截。
            addSegmentIcon(index: i, radius: currentRadius, lineWidth: lineWidth, center: center)

            // 2. Draw Progress Track (Gradient)
            // Ensure value is between 0 and 1
            let rawValue = i < values.count ? values[i] : 0
            let value = CGFloat(min(max(rawValue, 0), 100)) / 100.0
            
            if value > 0 && segmentGradients != nil && i < (segmentGradients?.count ?? 0) {
                let progressAngle = maxAngle * value
                let endAngle = startAngle + progressAngle

                let progressPath = UIBezierPath(
                    arcCenter: center,
                    radius: currentRadius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: true
                )
                
                let progressLayer = CAShapeLayer()
                progressLayer.frame = bounds
                progressLayer.path = progressPath.cgPath
                progressLayer.fillColor = UIColor.clear.cgColor
                progressLayer.strokeColor = UIColor.black.cgColor // Mask needs to be opaque
                progressLayer.lineWidth = lineWidth
                progressLayer.lineCap = .round
                
                let gradientLayer = CAGradientLayer()
                gradientLayer.frame = bounds
                gradientLayer.colors = segmentGradients![i].map { $0.cgColor }
                gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
                gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
                gradientLayer.mask = progressLayer // Use mask to shape the gradient
                layer.addSublayer(gradientLayer)
                
                // 3. Draw Label at End of Progress
                // Only show label if there is some progress
                if value > 0 {
                     addLabel(at: endAngle, radius: currentRadius, center: center, value: Int(rawValue))
                }
            }
        }
    }
    
    private func addSegmentIcon(index: Int, radius: CGFloat, lineWidth: CGFloat, center: CGPoint) {
        guard index < Self.segmentIconNames.count,
              let image = UIImage(named: Self.segmentIconNames[index]) else { return }
        let size = Self.segmentIconSize
        let iconView = UIImageView(image: image)
        iconView.contentMode = .scaleAspectFit
        iconView.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        iconView.center = CGPoint(
            x: center.x + lineWidth / 2.0 + Self.segmentIconGap + size / 2.0,
            y: center.y + radius
        )
        addSubview(iconView)
    }

    private func addLabel(at angle: CGFloat, radius: CGFloat, center: CGPoint, value: Int) {
        let label = UILabel()
        label.text = "\(value)%"
        label.font = UIFont(name: "PingFangSC-Semibold", size: 12)
        label.textColor = .white
        label.sizeToFit()
        
        // Position: On the ring track, extending beyond the end of the colored arc
        // Calculate angular offset to create a gap between arc end and text
        // Arc length = r * theta -> theta = arc / r
        //
        // gap 是从**弧线末端的角度**量起的，而末端的圆头 cap 还要再往外鼓 lineWidth/2 = 6pt，
        // 所以肉眼看到的间隙是 gap − 6，这里 10 即视觉 4pt。
        // 原来是 16（视觉 10pt），在 100% 时会出事：满环的末端正好收在 3 点钟，
        // 再顺时针偏就转进右下缺口象限，一头扎进总分数字里。
        // 每放宽 1pt，满环时标签就沿弧线往总分那边多转约 1pt —— 这个数和下面
        // scoreLabel 的字号是绑在一起定的，不能单独调。
        let gap: CGFloat = 10.0
        let labelHalfWidth = label.bounds.width / 2.0
        let angleOffset = (gap + labelHalfWidth) / radius
        
        // 标签**必须留在自己那条轨道上**，按切线方向旋转 —— 顺着圆环走是这个组件的基本观感。
        // 曾经试过满环时把它沿半径让进两条轨道之间的空档来躲总分，结果就是「缩到两个圆环
        // 中间」，一眼就不对。不要再走这条路：满环时它必然转进右下缺口象限（总分就摆在
        // 那儿），只能靠缩小末端间隙 + 收总分字号腾地方，见上面的 gap 与 scoreLabel 字号。
        let labelAngle = angle + angleOffset

        let x = center.x + radius * cos(labelAngle)
        let y = center.y + radius * sin(labelAngle)
        label.center = CGPoint(x: x, y: y)
        
        // Rotate text to follow the curve
        // Tangent angle is labelAngle + pi/2
        label.transform = CGAffineTransform(rotationAngle: labelAngle + .pi / 2)
        
        addSubview(label)
    }
}

class ExploreAdviceView: UIView {
    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 44/255.0, green: 44/255.0, blue: 44/255.0, alpha: 1.0)
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor(white: 1.0, alpha: 0.08).cgColor
        view.clipsToBounds = true
        return view
    }()

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "explore_sleep_recomm_bg"))
        imageView.contentMode = .scaleAspectFill
        imageView.alpha = 0.6
        return imageView
    }()

    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.white
        label.numberOfLines = 0
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) { nil }
    
    private func setup() {
        addSubview(containerStack)
        containerStack.addArrangedSubview(titleLabel)
        containerStack.addArrangedSubview(cardView)
        cardView.addSubview(backgroundImageView)
        cardView.addSubview(contentLabel)
        
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        // Prevent image view from determining the card height
        backgroundImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        backgroundImageView.setContentHuggingPriority(.defaultLow, for: .vertical)

        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            backgroundImageView.topAnchor.constraint(equalTo: cardView.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            contentLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 40),
            contentLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            contentLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            contentLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -50)
        ])
    }
    
    func configure(text: String, hasData: Bool) {
        titleLabel.text = L("explore.section.advice")
        
        // 文案一律用服务端下发的那份（ExploreManager 已把「服务端返回空」统一成 "--"），
        // 这里不再按 hasData 换成本地介绍文案。背景图仍跟着 hasData 走。
        let displayText = text
        backgroundImageView.isHidden = !hasData

        let trimmed = displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            cardView.isHidden = true
        } else {
            cardView.isHidden = false
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.alignment = .left
        
        let attrString = NSAttributedString(
            string: displayText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
        )
        contentLabel.attributedText = attrString
    }
}

// MARK: - Helpers

struct ExploreGradients {
    static let efficiency = [
        UIColor(red: 33/255.0, green: 149/255.0, blue: 83/255.0, alpha: 1.0), // #219553
        UIColor(red: 28/255.0, green: 219/255.0, blue: 113/255.0, alpha: 1.0)  // #1CDB71
    ]
    static let structure = [
        UIColor(red: 193/255.0, green: 133/255.0, blue: 37/255.0, alpha: 1.0), // #C18525
        UIColor(red: 248/255.0, green: 173/255.0, blue: 52/255.0, alpha: 1.0)  // #F8AD34
    ]
    static let fluctuation = [
        UIColor(red: 178/255.0, green: 66/255.0, blue: 88/255.0, alpha: 1.0), // #B24258
        UIColor(red: 243/255.0, green: 86/255.0, blue: 117/255.0, alpha: 1.0)  // #F35675
    ]
}

class ExploreGradientView: UIView {
    var colors: [UIColor] = [] {
        didSet {
            updateGradient()
        }
    }
    
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateGradient()
    }
    
    private func updateGradient() {
        guard let layer = self.layer as? CAGradientLayer else { return }
        if colors.count >= 2 {
            layer.colors = colors.map { $0.cgColor }
        } else {
             layer.colors = [UIColor(red: 60/255.0, green: 60/255.0, blue: 60/255.0, alpha: 1.0).cgColor, UIColor(red: 60/255.0, green: 60/255.0, blue: 60/255.0, alpha: 1.0).cgColor]
        }
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
    }
}

class ExploreScoreHeaderView: UIView {
    private let scoreContainer = UIView()
    private let ringView = ExploreScoreRingView()
    private let scoreLabel: UILabel = {
        let label = UILabel()
        // 39 而非设计稿的 60：总分压在圆环 270° 缺口那一象限里，满环时末端的百分比标签
        // 必然转到这里来，两者只能靠字号让位 —— 标签要留在轨道上顺着圆环，不能沿半径躲。
        // 实测 100% 那圈（字号每减 1pt 约让出 1.2pt）：60 时被压 25.8pt，44 时只差 2.9pt。
        label.font = UIFont(name: "HKGrotesk-SemiBold", size: 39) ?? UIFont.systemFont(ofSize: 39, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(white: 0.7, alpha: 1.0)
        label.textAlignment = .center
        // 同空态：右对齐在圆环右缘的一行字，长语言会顶到起点图标上，
        // **必须保持一行**，先右移出圆环再缩字号。
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) { nil }
    
    private func setup() {
        addSubview(scoreContainer)
        scoreContainer.addSubview(ringView)
        scoreContainer.addSubview(scoreLabel)
        scoreContainer.addSubview(titleLabel)
        
        scoreContainer.translatesAutoresizingMaskIntoConstraints = false
        ringView.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 「贴齐圆环右缘 8pt」是常态排版，但它得给长文案让路：降一级优先级，
        // 顶不住时由 Auto Layout 打破它、把整行右移出圆环，而不是折行。
        let titleRightInset = titleLabel.trailingAnchor.constraint(
            equalTo: ringView.trailingAnchor, constant: -8)
        titleRightInset.priority = .required - 1

        NSLayoutConstraint.activate([
            scoreContainer.topAnchor.constraint(equalTo: topAnchor),
            scoreContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            scoreContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            scoreContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            scoreContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 240),
            
            ringView.centerXAnchor.constraint(equalTo: scoreContainer.centerXAnchor),
            ringView.heightAnchor.constraint(equalToConstant: 230),
            ringView.widthAnchor.constraint(equalTo: ringView.heightAnchor),
            ringView.topAnchor.constraint(equalTo: scoreContainer.topAnchor, constant: 10),
            ringView.bottomAnchor.constraint(equalTo: scoreContainer.bottomAnchor, constant: -10),
            
            // Score Label Position:
            // "Bottom and Arc Bottom Tangent Aligned" -> titleLabel.bottom = ringView.bottom
            // "Right and Arc Right Tangent Distance 8pt" -> titleLabel.trailing = ringView.trailing - 8
            titleLabel.bottomAnchor.constraint(equalTo: ringView.bottomAnchor),
            titleRightInset,
            // 左边界不许越过起点图标：图标右缘在圆心 +24.5pt，再留 8pt 呼吸。
            // 中文用不到这条（天然还差 18pt），只有拉丁语系的长文案会被它拦下来。
            titleLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: ringView.centerXAnchor, constant: 32.5),
            // 让路的去处：圆环右侧到内容区边缘还有空白，长文案先整体右移出圆环，
            // 顶到这条才轮到 adjustsFontSizeToFitWidth 缩字号 —— 任何情况都不折行。
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: scoreContainer.trailingAnchor),

            // Score Label Position:
            // "Above Title, Vertically Centered Aligned" -> centerX aligned, stacked
            scoreLabel.centerXAnchor.constraint(equalTo: titleLabel.centerXAnchor),
            scoreLabel.bottomAnchor.constraint(equalTo: titleLabel.topAnchor)
        ])
    }
    
    func configure(score: String, title: String, gradients: [[UIColor]], values: [Double]) {
        scoreLabel.text = score
        titleLabel.text = title
        ringView.segmentGradients = gradients
        ringView.values = values
    }
}
