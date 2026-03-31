import UIKit

/// Defines which section to scroll to when navigating from Home to HealthViewController
enum HealthDayScrollTarget: String {
    case top              // Sleep: scroll to top (default)
    case statsSection     // Heart Rate / Sleep Onset: scroll to sleep performance & vitals cards
    case deepSleep        // Deep Sleep: scroll to deep sleep card and expand it
}

final class HomeViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "home_bg")
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Top Bar Buttons
    private let sideBarBtn = UIButton()
    private let shareBtn = UIButton()
    private let logoImageView = UIImageView(image: UIImage(named: "logo"))
    
    // Top Bar
    private let topBarStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        return stack
    }()
    
    // Metrics Row
    private let metricsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 10
        return stack
    }()
    
    // Legend Area
    private let legendView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Score Circle
    private let scoreContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let scoreBackgroundView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "SketchPngbaf502406af060f5ff50d4f3a8c3d8c67393b4fa15b5921dcb27dd0f01d0e36a")
        return imageView
    }()
    
    private var scoreProgressLayer: CAShapeLayer?

    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "--"
        label.font = UIFont.systemFont(ofSize: 60, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    // Metric value labels for dynamic update
    private var metricValueLabels: [UILabel] = []
    private let metricKeys = ["heartRate", "totalSleep", "sleepOnset", "deepSleep"]
    
    // Cards Stack
    private let cardsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()
    
    // Insight Dynamic Labels
    private let insightTitleLabel = UILabel()
    private let insightDescLabel = UILabel()
    
    // Best Dynamic Labels
    private let bestNameLabel = UILabel()
    private let bestUsedCountLabel = UILabel()
    private let bestScoreLabel = UILabel()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchData()
        
        // Hide nav bar
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        fetchData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkBluetoothPermissionAndShowReminder()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        // Dark theme background - rgba(24, 24, 24, 1) from design
        view.backgroundColor = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0)
        
        view.addSubview(backgroundImageView)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        
        // Background image aspect ratio constraint
        if let image = backgroundImageView.image {
            let aspectRatio = image.size.height / image.size.width
            backgroundImageView.heightAnchor.constraint(equalTo: backgroundImageView.widthAnchor, multiplier: aspectRatio).isActive = true
        }
        
        setupTopBar()
        setupMetrics()
        setupTabsAndScore()
        setupCards()
        setupDebugInteractions()
    }
    
    private func setupTopBar() {
        contentView.addSubview(topBarStackView)
        
        sideBarBtn.setImage(UIImage(named: "home_side_bar"), for: .normal)
        sideBarBtn.translatesAutoresizingMaskIntoConstraints = false
        sideBarBtn.addTarget(self, action: #selector(handleSideBarBtnTapped), for: .touchUpInside)
        
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        shareBtn.setImage(UIImage(named: "home_share"), for: .normal)
        shareBtn.translatesAutoresizingMaskIntoConstraints = false
        shareBtn.addTarget(self, action: #selector(handleShareBtnTapped), for: .touchUpInside)
        
        topBarStackView.addArrangedSubview(sideBarBtn)
        topBarStackView.addArrangedSubview(logoImageView)
        topBarStackView.addArrangedSubview(shareBtn)
        
        NSLayoutConstraint.activate([
            // Design: 48px -> 24pt
            sideBarBtn.widthAnchor.constraint(equalToConstant: 24),
            sideBarBtn.heightAnchor.constraint(equalToConstant: 24),
            
            // Design: 267px * 32px -> 133.5pt * 16pt
            logoImageView.widthAnchor.constraint(equalToConstant: 133.5),
            logoImageView.heightAnchor.constraint(equalToConstant: 16),
            
            // Design: 48px -> 24pt
            shareBtn.widthAnchor.constraint(equalToConstant: 24),
            shareBtn.heightAnchor.constraint(equalToConstant: 24),
            
            topBarStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            topBarStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            topBarStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            topBarStackView.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupMetrics() {
        contentView.addSubview(metricsStackView)
        
        // Remove existing subviews if any (not needed for init but good practice)
        metricsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Metrics Data - initialized with "--" placeholder, updated when data arrives
        metricValueLabels.removeAll()
        let metrics = [
            ("--", L("health.metric.heart_rate"), "home_heart_rate"),
            ("--", L("health.metric.sleep"), "home_total_sleep"),
            ("--", L("home.metric.sleep_onset"), "home_sleep_onset"),
            ("--", L("home.metric.deep_sleep"), "home_deep_sleep")
        ]
        
        for (index, (value, title, iconName)) in metrics.enumerated() {
            let (itemView, valueLabel) = createMetricItem(value: value, title: title, icon: iconName, tag: index)
            metricsStackView.addArrangedSubview(itemView)
            metricValueLabels.append(valueLabel)
        }
        
        NSLayoutConstraint.activate([
            metricsStackView.topAnchor.constraint(equalTo: topBarStackView.bottomAnchor, constant: 10),
            metricsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            metricsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    private func createMetricItem(value: String, title: String, icon: String, tag: Int) -> (UIView, UILabel) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.tag = tag
        container.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(metricItemTapped(_:)))
        container.addGestureRecognizer(tap)
        
        // Circle Background: 124px = 62pt
        let circleView = UIView()
        circleView.translatesAutoresizingMaskIntoConstraints = false
        circleView.backgroundColor = UIColor(red: 35/255, green: 35/255, blue: 35/255, alpha: 0.3)
        circleView.layer.cornerRadius = 31
        circleView.layer.borderWidth = 0.5
        circleView.layer.borderColor = UIColor.white.cgColor
        circleView.layer.masksToBounds = true
        
        // Icon
        let iconView = UIImageView(image: UIImage(named: icon))
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        // Value
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.textColor = .white
        valueLabel.font = .systemFont(ofSize: 16, weight: .semibold) // 32px
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.textAlignment = .center
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 14, weight: .regular) // 28px
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Layout inside circle
        circleView.addSubview(iconView)
        circleView.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            // Icon centered roughly upper part
            iconView.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: circleView.centerYAnchor, constant: -10),
            iconView.widthAnchor.constraint(equalToConstant: 16), // 32px
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            // Value below icon
            valueLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            valueLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor)
        ])
        
        container.addSubview(circleView)
        container.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            // Circle
            circleView.topAnchor.constraint(equalTo: container.topAnchor),
            circleView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            circleView.widthAnchor.constraint(equalToConstant: 62),
            circleView.heightAnchor.constraint(equalToConstant: 62),
            
            // Title below circle
            titleLabel.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 8), // 16px
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return (container, valueLabel)
    }
    
    // MARK: - Metric Item Tap → Navigate to HealthViewController
    @objc private func metricItemTapped(_ sender: UITapGestureRecognizer) {
        guard let tag = sender.view?.tag else { return }
        // tag 0 = heartRate, 1 = totalSleep, 2 = sleepOnset, 3 = deepSleep
        let scrollTarget: HealthDayScrollTarget
        switch tag {
        case 0: scrollTarget = .statsSection   // heart rate → sleep performance & vitals
        case 1: scrollTarget = .top            // sleep → day view top
        case 2: scrollTarget = .statsSection   // sleep onset → sleep performance & vitals
        case 3: scrollTarget = .deepSleep      // deep sleep → deep sleep card
        default: return
        }
        
        // Switch to Sleep tab (index 1) via MainTabBarController
        if let tabBarController = self.tabBarController as? MainTabBarController {
            tabBarController.switchToSleepTab(scrollTarget: scrollTarget)
        }
    }
    
    private func setupTabsAndScore() {
        // Layout: Score/Gauge on top, Legend below
        
        contentView.addSubview(scoreContainer)
        contentView.addSubview(legendView)
        
        // 1. Setup Score Gauge (Semi-circle)
        scoreContainer.addSubview(scoreLabel)

        // Draw Layers
        let pathCenter = CGPoint(x: 145, y: 145) // Bottom-center of 290x160 area
        let radius: CGFloat = 135
        let lineWidth: CGFloat = 6
        
        // Track Layer (Gray) - #9A989D
        let trackPath = UIBezierPath(arcCenter: pathCenter, radius: radius, startAngle: .pi, endAngle: 0, clockwise: true)
        let trackLayer = CAShapeLayer()
        trackLayer.path = trackPath.cgPath
        trackLayer.strokeColor = UIColor(red: 154/255, green: 152/255, blue: 157/255, alpha: 1.0).cgColor
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineWidth = lineWidth
        trackLayer.lineCap = .round
        scoreContainer.layer.addSublayer(trackLayer)
        
        // Progress Layer (Purple) - #8054FE
        let progressPath = UIBezierPath(arcCenter: pathCenter, radius: radius, startAngle: .pi, endAngle: 0, clockwise: true)
        let progLayer = CAShapeLayer()
        progLayer.path = progressPath.cgPath
        progLayer.strokeColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0).cgColor
        progLayer.fillColor = UIColor.clear.cgColor
        progLayer.lineWidth = lineWidth
        progLayer.lineCap = .round
        progLayer.strokeEnd = 0 // Init at 0
        scoreContainer.layer.addSublayer(progLayer)
        self.scoreProgressLayer = progLayer
        
        // 2. Setup Legend Elements
        // Clear previous if any
        legendView.subviews.forEach { $0.removeFromSuperview() }

        // Sleep Group
        let sleepStack = UIStackView()
        sleepStack.axis = .horizontal
        sleepStack.spacing = 6
        sleepStack.alignment = .center
        sleepStack.translatesAutoresizingMaskIntoConstraints = false
        
        let dotSleep = UIView()
        dotSleep.translatesAutoresizingMaskIntoConstraints = false
        dotSleep.backgroundColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0)
        dotSleep.layer.cornerRadius = 4.5
        dotSleep.widthAnchor.constraint(equalToConstant: 9).isActive = true
        dotSleep.heightAnchor.constraint(equalToConstant: 9).isActive = true
        
        let labelSleep = UILabel()
        labelSleep.text = L("home.tab.sleep")
        labelSleep.textColor = .white
        labelSleep.font = .systemFont(ofSize: 14)
        
        sleepStack.addArrangedSubview(dotSleep)
        sleepStack.addArrangedSubview(labelSleep)
        
        // Activity Group
        let activityStack = UIStackView()
        activityStack.axis = .horizontal
        activityStack.spacing = 6
        activityStack.alignment = .center
        activityStack.translatesAutoresizingMaskIntoConstraints = false
        
        let dotActivity = UIView()
        dotActivity.translatesAutoresizingMaskIntoConstraints = false
        dotActivity.backgroundColor = UIColor(red: 154/255, green: 152/255, blue: 157/255, alpha: 1.0)
        dotActivity.layer.cornerRadius = 4.5
        dotActivity.widthAnchor.constraint(equalToConstant: 9).isActive = true
        dotActivity.heightAnchor.constraint(equalToConstant: 9).isActive = true
        
        let labelActivity = UILabel()
        labelActivity.text = L("home.tab.activity")
        labelActivity.textColor = .white
        labelActivity.font = .systemFont(ofSize: 14)
        
        activityStack.addArrangedSubview(dotActivity)
        activityStack.addArrangedSubview(labelActivity)
        
        // Score Legend
        let labelScore = UILabel()
        labelScore.translatesAutoresizingMaskIntoConstraints = false
        labelScore.text = L("home.tab.overall_score")
        labelScore.textColor = .white
        labelScore.font = .systemFont(ofSize: 14)
        
        legendView.addSubview(sleepStack)
        legendView.addSubview(labelScore)
        legendView.addSubview(activityStack)
        
        // 3. Constraints
        NSLayoutConstraint.activate([
            // Score Container
            scoreContainer.topAnchor.constraint(equalTo: metricsStackView.bottomAnchor, constant: 15),
            scoreContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            scoreContainer.widthAnchor.constraint(equalToConstant: 290),
            scoreContainer.heightAnchor.constraint(equalToConstant: 160),
            
            // Score Label
            scoreLabel.centerXAnchor.constraint(equalTo: scoreContainer.centerXAnchor),
            scoreLabel.bottomAnchor.constraint(equalTo: scoreContainer.bottomAnchor, constant: 5),
            
            // Legend View Container
            legendView.topAnchor.constraint(equalTo: scoreContainer.bottomAnchor, constant: 5),
            legendView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            legendView.widthAnchor.constraint(equalTo: scoreContainer.widthAnchor),
            legendView.heightAnchor.constraint(equalToConstant: 30),
            
            // Sleep Group Alignment: CenterX = Arc Start (Left Edge + 10)
            sleepStack.centerXAnchor.constraint(equalTo: legendView.leadingAnchor, constant: 10),
            sleepStack.centerYAnchor.constraint(equalTo: legendView.centerYAnchor),
            
            // Activity Group Alignment: CenterX = Arc End (Right Edge - 10)
            activityStack.centerXAnchor.constraint(equalTo: legendView.trailingAnchor, constant: -10),
            activityStack.centerYAnchor.constraint(equalTo: legendView.centerYAnchor),
            
            // Overall Score Center
            labelScore.centerXAnchor.constraint(equalTo: legendView.centerXAnchor),
            labelScore.centerYAnchor.constraint(equalTo: legendView.centerYAnchor)
        ])
    }
    
    private func createTabLabel(text: String, isSelected: Bool) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = isSelected ? .white : .gray
        label.font = isSelected ? .boldSystemFont(ofSize: 16) : .systemFont(ofSize: 14)
        return label
    }
    
    private func setupCards() {
        contentView.addSubview(cardsStackView)
        
        NSLayoutConstraint.activate([
            cardsStackView.topAnchor.constraint(equalTo: legendView.bottomAnchor, constant: 15),
            cardsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        let weeklyBestCard = createCardView(backgroundImageName: "home_best_bg")
        setupWeeklyBestContent(in: weeklyBestCard)
        cardsStackView.addArrangedSubview(weeklyBestCard)
        
        let insightsCard = createCardView(backgroundImageName: "home_sleep_insights_bg")
        setupInsightsContent(in: insightsCard)
        cardsStackView.addArrangedSubview(insightsCard)
    }
    
    private func createCardView(backgroundImageName: String? = nil, height: CGFloat? = nil) -> UIView {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        
        if let h = height {
            view.heightAnchor.constraint(equalToConstant: h).isActive = true
        }
        
        if let bgName = backgroundImageName, let image = UIImage(named: bgName) {
            let bgImageView = UIImageView(image: image)
            bgImageView.translatesAutoresizingMaskIntoConstraints = false
            bgImageView.contentMode = .scaleToFill
            
            // Allow image view to be compressed/stretched to fit content
            bgImageView.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
            bgImageView.setContentCompressionResistancePriority(UILayoutPriority(1), for: .vertical)
            
            view.addSubview(bgImageView)
            
            NSLayoutConstraint.activate([
                bgImageView.topAnchor.constraint(equalTo: view.topAnchor),
                bgImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bgImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                bgImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        } else {
            view.backgroundColor = UIColor(white: 0.1, alpha: 0.6)
        }
        
        return view
    }
    
    // MARK: - Card Contents
    
    private func setupInsightsContent(in card: UIView) {
        // Sleep Insights Card
        // Header
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 5
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        let icon = UIImageView(image: UIImage(named: "home_sleep_insights"))
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 26).isActive = true
        
        let titleBlock = UIStackView()
        titleBlock.axis = .vertical
        titleBlock.spacing = 2
        
        let title = UILabel()
        title.text = L("home.insights.title")
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .white
        
        let subtitle = UILabel()
        subtitle.text = L("home.insights.subtitle")
        subtitle.font = .systemFont(ofSize: 11, weight: .light)
        subtitle.textColor = .white
        
        titleBlock.addArrangedSubview(title)
        titleBlock.addArrangedSubview(subtitle)
        
        headerStack.addArrangedSubview(icon)
        headerStack.addArrangedSubview(titleBlock)
        
        // Content
        insightTitleLabel.font = .systemFont(ofSize: 24, weight: .regular)
        insightTitleLabel.textColor = .white
        insightTitleLabel.numberOfLines = 0
        insightTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        insightDescLabel.font = .systemFont(ofSize: 11, weight: .light)
        insightDescLabel.textColor = .white
        insightDescLabel.numberOfLines = 0
        insightDescLabel.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(headerStack)
        card.addSubview(insightTitleLabel)
        card.addSubview(insightDescLabel)
        
        NSLayoutConstraint.activate([
            // Header at top
            headerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 26),
            headerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            
            // Title below header with small gap and indent
            insightTitleLabel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            insightTitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 52),
            insightTitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            
            // Description below title with small gap
            insightDescLabel.topAnchor.constraint(equalTo: insightTitleLabel.bottomAnchor, constant: 16),
            insightDescLabel.leadingAnchor.constraint(equalTo: insightTitleLabel.leadingAnchor),
            insightDescLabel.trailingAnchor.constraint(equalTo: insightTitleLabel.trailingAnchor),
            insightDescLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -26)
        ])
    }
    
    private func setupWeeklyBestContent(in card: UIView) {
        // Weekly Best Card
        
        // 1. Header (Icon + Title + Spacer)
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 5
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon
        let icon = UIImageView(image: UIImage(named: "home_best"))
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 26).isActive = true
        
        // Title Block
        let titleBlock = UIStackView()
        titleBlock.axis = .vertical
        titleBlock.spacing = 2
        titleBlock.translatesAutoresizingMaskIntoConstraints = false
        
        let title = UILabel()
        title.text = L("home.best.title")
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .white
        
        let subtitle = UILabel()
        subtitle.text = L("home.best.subtitle")
        subtitle.font = .systemFont(ofSize: 11, weight: .light)
        subtitle.textColor = .white
        
        titleBlock.addArrangedSubview(title)
        titleBlock.addArrangedSubview(subtitle)
        
        // Spacer for header
        let headerSpacer = UIView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        headerStack.addArrangedSubview(icon)
        headerStack.addArrangedSubview(titleBlock)
        headerStack.addArrangedSubview(headerSpacer)
        
        // 2. Name
        bestNameLabel.font = .systemFont(ofSize: 24, weight: .regular)
        bestNameLabel.textColor = .white
        bestNameLabel.textAlignment = .center
        bestNameLabel.numberOfLines = 1
        
        // 3. Stats
        // Used Count
        bestUsedCountLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        bestUsedCountLabel.textColor = .white
        
        let usedCaption = UILabel()
        usedCaption.text = L("home.best.used_times")
        usedCaption.font = .systemFont(ofSize: 11, weight: .light)
        usedCaption.textColor = .white
        usedCaption.textAlignment = .center
        
        let usedStack = UIStackView(arrangedSubviews: [bestUsedCountLabel, usedCaption])
        usedStack.axis = .vertical
        usedStack.spacing = 2
        usedStack.alignment = .center
        usedStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Score
        bestScoreLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        bestScoreLabel.textColor = .white
        
        let scoreCaption = UILabel()
        scoreCaption.text = L("home.best.score")
        scoreCaption.font = .systemFont(ofSize: 11, weight: .light)
        scoreCaption.textColor = .white
        scoreCaption.textAlignment = .center
        
        let scoreStack = UIStackView(arrangedSubviews: [bestScoreLabel, scoreCaption])
        scoreStack.axis = .vertical
        scoreStack.spacing = 2
        scoreStack.alignment = .center
        scoreStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Stats Row (Horizontal)
        let statsRow = UIStackView(arrangedSubviews: [usedStack, scoreStack])
        statsRow.axis = .horizontal
        statsRow.spacing = 60
        statsRow.alignment = .center
        statsRow.translatesAutoresizingMaskIntoConstraints = false
        
        // Stats Container
        let statsContainer = UIView()
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        statsContainer.addSubview(statsRow)
        
        NSLayoutConstraint.activate([
            statsRow.topAnchor.constraint(equalTo: statsContainer.topAnchor),
            statsRow.bottomAnchor.constraint(equalTo: statsContainer.bottomAnchor),
            statsRow.centerXAnchor.constraint(equalTo: statsContainer.centerXAnchor)
        ])
        
        // Main Stack
        let contentStack = UIStackView(arrangedSubviews: [headerStack, bestNameLabel, statsContainer])
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 26),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -26),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])
    }
    
    // MARK: - Data
    
    private func fetchData() {
        HomeService.shared.fetchHomeData { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.updateData(data)
            case .failure(let error):
                print("Failed to fetch home data: \(error)")
                self.clearData()
            }
        }
    }
    
    private func updateData(_ data: HomeData) {
        // Update Metrics
        let metricValues = [data.heartRate, data.totalSleep, data.sleepOnset, data.deepSleep]
        for (index, label) in metricValueLabels.enumerated() where index < metricValues.count {
            label.text = metricValues[index] ?? "--"
        }
        
        // Update Insight
        insightTitleLabel.text = data.insightTitle ?? ""
        insightDescLabel.text = data.insightDescription ?? ""
        
        // Update Best
        bestNameLabel.text = data.comfortAudioName ?? ""
        bestUsedCountLabel.text = data.usedTimes != nil ? "\(data.usedTimes!)" : "--"
        bestScoreLabel.text = data.comfortAudioScore != nil ? "\(data.comfortAudioScore!)" : "--"
        
        // Update Main Score
        scoreLabel.text = data.overallScore != nil ? "\(data.overallScore!)" : "--"
        
        // Update Gauge
        if let score = data.overallScore {
            let percentage = CGFloat(score) / 100.0
            let clampedPercentage = min(max(percentage, 0), 1.0)
            animateScoreProgress(to: clampedPercentage)
        } else {
            animateScoreProgress(to: 0)
        }
    }
    
    private func clearData() {
        // Reset metrics to "--"
        for label in metricValueLabels {
            label.text = "--"
        }
        
        // Reset cards
        insightTitleLabel.text = ""
        insightDescLabel.text = ""
        bestNameLabel.text = ""
        bestUsedCountLabel.text = "--"
        bestScoreLabel.text = "--"
        
        // Reset score
        scoreLabel.text = "--"
        animateScoreProgress(to: 0)
    }
    
    private func animateScoreProgress(to value: CGFloat) {
        if let progressLayer = self.scoreProgressLayer {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.strokeEnd
            animation.toValue = value
            animation.duration = 1.0
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            progressLayer.strokeEnd = value
            progressLayer.add(animation, forKey: "progressAnim")
        }
    }
    
    // MARK: - Permission Check
    
    private func checkBluetoothPermissionAndShowReminder() {
        guard PermissionManager.shared.shouldShowBluetoothReminder() else {
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            PermissionManager.shared.showBluetoothPermissionReminder(from: self)
        }
    }
    
    // MARK: - Action Methods
    
    // MARK: - Debug Interactions
    
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
    
    @objc private func handleSideBarBtnTapped() {
        let sideMenuVC = SideMenuViewController()
        sideMenuVC.modalPresentationStyle = .overFullScreen
        self.present(sideMenuVC, animated: false, completion: nil)
    }
    
    @objc private func handleShareBtnTapped() {
        // 1. Hide buttons synchronously (alpha = 0 preserves layout)
        self.sideBarBtn.alpha = 0
        self.shareBtn.alpha = 0
            
        // 2. Capture Screenshot
        if let image = self.captureScreenshot() {
            // 3. Restore buttons immediately
            self.sideBarBtn.alpha = 1
            self.shareBtn.alpha = 1
            
            // 4. Present Share
            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            
            // Add completion handler to show Toast on success
            activityVC.completionWithItemsHandler = { [weak self] (activityType, completed, returnedItems, error) in
                guard let self = self else { return }
                
                if completed {
                    if let type = activityType {
                        if type == .saveToCameraRoll {
                            Toast.show(L("common.saved_to_photos"), in: self.view)
                        } else if type == .copyToPasteboard {
                            Toast.show(L("common.copy_success"), in: self.view)
                        } else if type.rawValue == "com.apple.DocumentManagerUICore.SaveToFiles" {
                            Toast.show(L("common.save_success"), in: self.view)
                        } else {
                            Toast.show(L("common.share_success"), in: self.view)
                        }
                    } else {
                        Toast.show(L("common.share_success"), in: self.view)
                    }
                }
            }
            
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.shareBtn
                popover.sourceRect = self.shareBtn.bounds
            }
            self.present(activityVC, animated: true, completion: nil)
        } else {
             // Restore just in case
             self.sideBarBtn.alpha = 1
             self.shareBtn.alpha = 1
        }
    }
    
    private func captureScreenshot() -> UIImage? {
        let size = contentView.bounds.size
        
        UIGraphicsBeginImageContextWithOptions(size, true, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Fill background
        self.view.backgroundColor?.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        
        // Draw background image
        if let bgImage = backgroundImageView.image {
            let width = size.width
            let height = width * (bgImage.size.height / bgImage.size.width)
            bgImage.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        // Render content
        contentView.layer.render(in: context)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}
