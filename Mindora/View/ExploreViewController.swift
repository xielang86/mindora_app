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
        let iv = UIImageView(image: UIImage(named: "logo"))
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
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
        
        setupDebugInteractions()
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
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
        sideBarButton.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        sideBarButton.addTarget(self, action: #selector(handleSideBarBtnTapped), for: .touchUpInside)
        
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
            logoImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 200)
        ])
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
        
        NSLayoutConstraint.activate([
            greetingPrefixLabel.topAnchor.constraint(equalTo: greetingContainer.topAnchor),
            greetingPrefixLabel.leadingAnchor.constraint(equalTo: greetingContainer.leadingAnchor),
            
            greetingNameLabel.firstBaselineAnchor.constraint(equalTo: greetingPrefixLabel.firstBaselineAnchor),
            greetingNameLabel.leadingAnchor.constraint(equalTo: greetingPrefixLabel.trailingAnchor, constant: 4),
            greetingNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: greetingContainer.trailingAnchor),
            
            introLabel.topAnchor.constraint(equalTo: greetingPrefixLabel.bottomAnchor, constant: 16),
            introLabel.leadingAnchor.constraint(equalTo: greetingContainer.leadingAnchor),
            introLabel.trailingAnchor.constraint(equalTo: greetingContainer.trailingAnchor),
            
            introDetailLabel.topAnchor.constraint(equalTo: introLabel.bottomAnchor, constant: 12),
            introDetailLabel.leadingAnchor.constraint(equalTo: greetingContainer.leadingAnchor),
            introDetailLabel.trailingAnchor.constraint(equalTo: greetingContainer.trailingAnchor),
            introDetailLabel.bottomAnchor.constraint(equalTo: greetingContainer.bottomAnchor)
        ])
        
        contentStack.addArrangedSubview(greetingContainer)
        contentStack.addArrangedSubview(scoreHeaderView)
        contentStack.addArrangedSubview(emptyStateView)
        contentStack.addArrangedSubview(efficiencyCard)
        contentStack.addArrangedSubview(structureCard)
        contentStack.addArrangedSubview(fluctuationCard)
        contentStack.addArrangedSubview(preferenceView)
        contentStack.addArrangedSubview(adviceView)
        contentStack.addArrangedSubview(articlesView)
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
        
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 20), // Reduced height from 24
            
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
        label.font = UIFont(name: "HKGrotesk-SemiBold", size: 60) ?? UIFont.systemFont(ofSize: 60, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(white: 0.7, alpha: 1.0)
        label.textAlignment = .center
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
            titleLabel.trailingAnchor.constraint(equalTo: ringView.trailingAnchor, constant: -8),

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

    override func layoutSubviews() {
        super.layoutSubviews()
        // Remove existing sublayers and subviews (labels)
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        subviews.forEach { $0.removeFromSuperview() }

        let lineWidth: CGFloat = 12 
        let spacing: CGFloat = 20   
        let startAngle: CGFloat = .pi / 2
        let maxAngle: CGFloat = .pi * 1.5 // Total 270 degrees
        
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
    
    private func addLabel(at angle: CGFloat, radius: CGFloat, center: CGPoint, value: Int) {
        let label = UILabel()
        label.text = "\(value)%"
        label.font = UIFont(name: "PingFangSC-Semibold", size: 12)
        label.textColor = .white
        label.sizeToFit()
        
        // Position: On the ring track, extending beyond the end of the colored arc
        // Calculate angular offset to create a gap between arc end and text
        // Arc length = r * theta -> theta = arc / r
        // We want about 16pt gap + half label width (increased gap)
        let gap: CGFloat = 16.0
        let labelHalfWidth = label.bounds.width / 2.0
        let angleOffset = (gap + labelHalfWidth) / radius
        
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
        
        let displayText: String
        if hasData {
            displayText = text
            backgroundImageView.isHidden = false
        } else {
            displayText = L("explore.bottom.description")
            backgroundImageView.isHidden = true
        }

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
        label.font = UIFont(name: "HKGrotesk-SemiBold", size: 60) ?? UIFont.systemFont(ofSize: 60, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(white: 0.7, alpha: 1.0)
        label.textAlignment = .center
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
            titleLabel.trailingAnchor.constraint(equalTo: ringView.trailingAnchor, constant: -8),

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
