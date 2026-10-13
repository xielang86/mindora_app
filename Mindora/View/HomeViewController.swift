import UIKit
import SafariServices

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
    private let logoImageView = UIImageView(image: UIImage(named: "logo_dream"))
    
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
    // 顶部 4 个指标的标题。字号在 fitMetricTitleFonts() 里统一计算，四个始终一致。
    private var metricTitleLabels: [UILabel] = []
    /// 标题基准字号（设计稿 28px）。放不下时四个一起等比缩小，绝不各缩各的。
    private static let metricTitleBaseFontSize: CGFloat = 14
    /// 缩到这个字号还放不下就允许换行 —— 再小就看不清了
    private static let metricTitleMinFontSize: CGFloat = 9
    // 请求代次：丢弃过期的 fetchHomeData 回调，避免乱序覆盖（见 fetchData）
    private var fetchGeneration = 0
    private let metricKeys = ["heartRate", "totalSleep", "sleepOnset", "deepSleep"]
    
    // Cards Stack
    private let cardsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()

    // 底部设备状态卡片容器（随 DeviceSession 动态重建）
    private let deviceCardsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 24 // 设计稿卡片间距 48px
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
        Log.info("HomeVC", "viewDidLoad")
        setupUI()
        setupObservers()
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(handleHomeScrollPan(_:)))
        
        // Hide nav bar
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        fetchData()
        // 仅在已绑定设备时启动发现。
        //
        // 发现会同时拉起 Bonjour 与 BLE，各自触发「本地网络」和「蓝牙」系统权限弹窗。
        // 未绑定设备的用户一进首页就连收两个弹窗，而此刻他既没有硬件、也不知道这两个
        // 权限用来干嘛——转化率和观感都很差。未绑定时首页那张卡本来就是写死的占位卡
        // （默认名 + 未连接），不依赖任何扫描结果。
        //
        // 已绑定的用户在绑定流程里早已授权，这里启动发现不会再弹窗，卡片仍能实时显示
        // 在线状态。用户点卡片进设备页时，DeviceManagement / DeviceScan 会自行启动发现，
        // 权限也在那一刻才申请——用户此时明确知道为什么需要它。
        if !DeviceSession.shared.entries.isEmpty {
            UnifiedDeviceDiscovery.shared.startContinuous()
        }
        rebuildDeviceCards()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        openDeviceCard?.setOpen(false, animated: false)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let w = view.window
        Log.info("HomeVC", "viewDidAppear frame=\(view.frame) alpha=\(view.alpha) hidden=\(view.isHidden) window=\(w != nil ? "exists" : "nil") windowAlpha=\(w?.alpha ?? -1) isKey=\(w?.isKeyWindow ?? false)")
        checkBluetoothPermissionAndShowReminder()
        // 蜂窝数据被禁（国行「无线数据」设为关闭/仅 WLAN）时，首页评分等在线内容会全空，
        // 而系统不会替 App 解释。自查一次并引导去设置，内部带冷却，联网正常时不弹。
        CellularDataGuide.checkAndRemindIfNeeded(from: self)
        // 首页弹窗（含参与调研）全部由服务端下发；客户端不内置任何问卷。
        maybeShowHomePopup()
    }

    // MARK: - 首页弹窗（活动 / 广告 / 参与调研）

    /// 每次「回到前台」最多展示一条；是否真正展示还要过 PopupService 的本地频控。
    /// 站内消息与问卷预拉由 PopupService.sync 负责，与首页是否可见无关。
    private var didShowPopupThisForeground = false

    private func maybeShowHomePopup() {
        PopupService.shared.sync(reason: "home") { [weak self] popup in
            guard let self, self.viewIfLoaded?.window != nil else { return }
            guard !self.didShowPopupThisForeground else { return }
            guard let popup else { return }
            self.didShowPopupThisForeground = true
            // 先确认真的挂上了 window 再记曝光（present 取不到 keyWindow 会返回 nil）。
            let shown = HomePopupView.present(popup: popup, onAction: { [weak self] p in
                PopupService.shared.markClicked(p)
                self?.handlePopupAction(p)
            }, onClose: { p in
                PopupService.shared.markDismissed(p)
            })
            if shown != nil { PopupService.shared.markShown(popup) }
        }
    }

    private func handlePopupAction(_ popup: HomePopup) {
        switch popup.actionType {
        case .survey:
            let vc = SurveyViewController(surveyId: popup.surveyId ?? popup.popupId)
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        case .url:
            // SFSafariViewController 仅接受 http/https，其余 scheme 会抛异常崩溃。
            if let s = popup.linkURL, let url = URL(string: s),
               let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                present(SFSafariViewController(url: url), animated: true)
            }
        case .route:
            // App 内路由：候选常量见 AppRoute / Tools/doc/弹窗与调查问卷接口.md，
            // 未知值回落到商城 Tab。
            AppRouter.open(rawRoute: popup.route, from: self, fallback: .store)
        case .dismiss, .unknown:
            // 商城活动 / 广告未配置具体动作时，默认进入商城 Tab；调研等其他类型则不跳转。
            if popup.type == .mall || popup.type == .ad {
                AppRouter.open(.store, from: self)
            }
        }
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

    private func setupObservers() {
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceSessionChanged),
            name: DeviceSession.didChangeNotification,
            object: nil
        )

        // 设备发现结果变化时刷新设备卡片连接状态（已连接/离线 实时更新）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDiscoveryUpdate),
            name: UnifiedDeviceDiscovery.didUpdateNotification,
            object: nil
        )

        // 切换「构造健康数据」档位后立即重刷首页指标。
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHealthSimulationChanged),
            name: HealthDataSimulator.didChangeNotification,
            object: nil
        )
    }

    @objc private func handleHealthSimulationChanged() {
        fetchData()
    }

    @objc private func handleDeviceSessionChanged() {
        rebuildDeviceCards()
    }

    @objc private func handleDiscoveryUpdate() {
        rebuildDeviceCards()
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
            
            // Design: 306px * 22px -> 153pt * 11pt
            logoImageView.widthAnchor.constraint(equalToConstant: 153),
            logoImageView.heightAnchor.constraint(equalToConstant: 11),
            
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
        metricTitleLabels.removeAll()
        let metrics = [
            ("--", L("health.sleep.sleep_heart_rate"), "home_heart_rate"),
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fitMetricTitleFonts()
    }

    /// 让顶部 4 个指标标题**共用同一个字号**并尽量单行显示。
    ///
    /// 按最长的那个标题算缩放比再套用到全部四个，而不是各自 adjustsFontSizeToFitWidth ——
    /// 那样每个标题字号都不一样，一眼就能看出来。缩到 metricTitleMinFontSize 还放不下
    /// （法语/西语这类特别长的译文）才退回两行。
    private func fitMetricTitleFonts() {
        guard metricTitleLabels.count > 1 else { return }

        // 用**标签自己布局后的实际宽度**，不靠 stack 宽度反推 —— 反推出来的值和真实
        // 可用宽度有出入，之前就是因此仍然被截断成了 "Sleep Heart Ra..."。
        // 首次 layout 时 bounds 还是 0，退回按 stack 几何估算。
        let measured = metricTitleLabels.map(\.bounds.width).filter { $0 > 0 }.min()
        let count = CGFloat(metricTitleLabels.count)
        let estimated = (metricsStackView.bounds.width - metricsStackView.spacing * (count - 1)) / count
        let available = (measured ?? estimated) - 2  // 留 2pt 余量，避免卡在临界值上被截断
        guard available > 1 else { return }

        func widestWidth(at size: CGFloat) -> CGFloat {
            let font = UIFont.systemFont(ofSize: size, weight: .regular)
            return metricTitleLabels
                .compactMap { $0.text }
                .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
                .max() ?? 0
        }

        // 从基准字号按 0.5pt 逐档往下试，第一个真正量得下的就是答案。
        // 不用线性外推：字宽随字号并非严格线性，外推出来的值会差一点点。
        var fontSize = Self.metricTitleBaseFontSize
        while fontSize > Self.metricTitleMinFontSize, widestWidth(at: fontSize) > available {
            fontSize -= 0.5
        }

        // 缩到下限还放不下（法语/西语这类特别长的译文）才退回两行
        let lines = widestWidth(at: fontSize) <= available ? 1 : 2
        let font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        for label in metricTitleLabels {
            // 只在真的变了才写回，否则会和 layout 相互触发
            if label.font.pointSize != fontSize { label.font = font }
            if label.numberOfLines != lines { label.numberOfLines = lines }
        }
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
        
        // Value —— 固定字号，所有指标统一大小（设计稿 text_3：HKGrotesk-SemiBold 20px=10pt，
        // 按本页圆圈放大比例换算约 13pt）。不再随文案长短自动缩放。
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.textColor = .white
        valueLabel.font = UIFont(name: "HKGrotesk-SemiBold", size: 11) ?? .systemFont(ofSize: 11, weight: .semibold)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.textAlignment = .center
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = false
        valueLabel.lineBreakMode = .byClipping
        
        // Title —— 字号不写死：四个标题在 fitMetricTitleFonts() 里统一按最长的那个缩放，
        // 保证彼此字号一致且都能单行显示（"Sleep Heart Rate" 在 14pt 下会换行）。
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: Self.metricTitleBaseFontSize, weight: .regular) // 28px
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        metricTitleLabels.append(titleLabel)

        // Layout inside circle
        circleView.addSubview(iconView)
        circleView.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            // Icon centered roughly upper part
            iconView.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: circleView.centerYAnchor, constant: -10),
            iconView.widthAnchor.constraint(equalToConstant: 16), // 32px
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            // Value below icon。固定 11pt，左右留出与圆边的间距（设计稿有明显留白）。
            valueLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            valueLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            valueLabel.widthAnchor.constraint(lessThanOrEqualTo: circleView.widthAnchor, constant: -8)
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
        if let mainTab = self.mindoraMainTab {
            mainTab.switchToSleepTab(scrollTarget: scrollTarget)
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
        let activityCenterX = activityStack.centerXAnchor.constraint(equalTo: legendView.trailingAnchor, constant: -10)
        activityCenterX.priority = .defaultHigh
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
            // 英文 "Sleep Activity" 较长，窄屏上居中对齐弧线端点会超出屏幕：此时向左让位，贴屏幕右边距。
            activityCenterX,
            activityStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -12),
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

        // 设备状态卡片（位于洞察卡之后）
        cardsStackView.addArrangedSubview(deviceCardsStack)
        rebuildDeviceCards()
    }

    // MARK: - 设备状态卡片

    // 上次构建设备卡片用的签名（名称+连接态）。discovery 前台常开、更新频繁，只有内容真正
    // 变化时才重建——否则在用户触摸时反复销毁/重建卡片会导致 layer use-after-free 崩溃。
    private var lastDeviceCardsSignature: String?
    /// 当前处于左滑展开状态的设备卡（同一时刻最多一张）
    private weak var openDeviceCard: SwipeableDeviceCard?
    /// 卡片展开/拖动期间推迟的重建，收起后补做——避免用户手指还在卡上时销毁视图
    private var pendingDeviceCardsRebuild = false

    /// 根据 DeviceSession + discovery 重建底部设备状态卡片。
    private func rebuildDeviceCards() {
        // 先算出目标卡片列表（名称, 是否连接）
        // entry 为 nil 表示未绑定时的占位卡（不可左滑删除）
        var cards: [(name: String, connected: Bool, entry: DeviceSession.Entry?)] = []
        let entries = DeviceSession.shared.entries
        if !entries.isEmpty {
            let reachableIDs = Set(UnifiedDeviceDiscovery.shared.devices.compactMap { $0.deviceID })
            cards = entries.map { entry in
                let reachable = entry.deviceID.map { reachableIDs.contains($0) } ?? false
                let connected = reachable && !(entry.isUserDisconnected ?? false)
                return (entry.displayName ?? L("device_manage.default_name"), connected, entry)
            }
        } else {
            // 未绑定任何设备时也展示一张占位卡：默认名 + 未连接，点击进入设备页的连接流程。
            cards = [(L("device_manage.default_name"), false, nil)]
        }

        // 签名不变就跳过重建，避免无谓的视图销毁/重建（崩溃根因）
        let signature = cards.map { "\($0.name)|\($0.connected)|\($0.entry != nil)" }.joined(separator: "/")
        if signature == lastDeviceCardsSignature { return }
        // 有卡片正展开或正被拖动：推迟到收起后再重建
        let isSwiping = deviceCardsStack.arrangedSubviews.contains { ($0 as? SwipeableDeviceCard)?.isTracking == true }
        if openDeviceCard != nil || isSwiping {
            pendingDeviceCardsRebuild = true
            return
        }
        pendingDeviceCardsRebuild = false
        lastDeviceCardsSignature = signature

        deviceCardsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        deviceCardsStack.isHidden = cards.isEmpty
        for (idx, c) in cards.enumerated() {
            let cardView = makeDeviceCard(name: c.name, connected: c.connected, deletable: c.entry != nil)
            // 点哪台带哪台进设备页
            cardView.onTap = { [weak self] in self?.openDeviceManagement(at: idx) }
            cardView.onOpenStateChange = { [weak self, weak cardView] isOpen in
                guard let self, let cardView else { return }
                self.deviceCardOpenStateChanged(cardView, isOpen: isOpen)
            }
            if let entry = c.entry {
                cardView.onDelete = { [weak self, weak cardView] in
                    DeviceDeletePrompt.present(
                        entry: entry,
                        onCancel: { cardView?.setOpen(false, animated: true) },
                        beforeDelete: {
                            // 先解除展开态，remove 触发的重建才能立即执行
                            self?.openDeviceCard = nil
                        }
                    )
                }
            }
            deviceCardsStack.addArrangedSubview(cardView)
        }
    }

    private func deviceCardOpenStateChanged(_ card: SwipeableDeviceCard, isOpen: Bool) {
        if isOpen {
            if let other = openDeviceCard, other !== card { other.setOpen(false, animated: true) }
            openDeviceCard = card
        } else if openDeviceCard === card {
            openDeviceCard = nil
        }
        if openDeviceCard == nil && pendingDeviceCardsRebuild {
            rebuildDeviceCards()
        }
    }

    /// 首页上下滚动时收起已展开的设备卡
    @objc private func handleHomeScrollPan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            openDeviceCard?.setOpen(false, animated: true)
        }
    }

    private func makeDeviceCard(name: String, connected: Bool, deletable: Bool) -> SwipeableDeviceCard {
        // iPad 上卡片是整行宽（~1000pt），若仍用 iPhone 的固定 112pt 高就成了又宽又扁的
        // 长条、很不协调。仅在 iPad 上把卡片加高、内容垂直居中、设备图按比例放大；
        // iPhone 全部保持 112pt 原尺寸不变。
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let cardH: CGFloat = isPad ? 156 : 112       // 卡片高度
        let nameTopInset: CGFloat = isPad ? 48 : 27  // 名称距顶（iPad 增大使「名称+胶囊」整体居中）
        let deviceImgW: CGFloat = isPad ? 174 : 125  // 设备图宽（保持素材 ~1.12 宽高比）
        let deviceImgH: CGFloat = isPad ? 156 : 112  // 设备图高（撑满卡片高度）
        let deviceImgTop: CGFloat = isPad ? -8 : -6  // 设备图顶部溢出量

        // 外层容器不裁剪，让设备图可以溢出卡片顶部（设计稿设备图突出卡片）。
        // 卡片内容全部放在 host（可左滑的内容层）上，删除按钮垫在它下面。
        let card = SwipeableDeviceCard(deletable: deletable)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.heightAnchor.constraint(equalToConstant: cardH).isActive = true
        let host = card.contentView

        // 背景：纯色 #232323，圆角 18pt，裁剪以保证圆角。
        // （设计稿是 #292929→#212121 的极细微渐变，肉眼几乎不可分；用纯色避免自定义
        //   layerClass 视图在频繁重建时出现 layer use-after-free 崩溃。）
        let bg = UIView()
        bg.backgroundColor = UIColor(red: 35/255, green: 35/255, blue: 35/255, alpha: 1.0)
        bg.layer.cornerRadius = 18
        bg.clipsToBounds = true
        bg.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(bg)
        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: host.topAnchor),
            bg.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            bg.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])

        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.textColor = .white
        // text_16: PingFangSC-Regular 32px=16pt
        nameLabel.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // 状态胶囊 group_21：bg #373737，宽 76pt，高 25pt，全圆角
        let badge = UIView()
        badge.backgroundColor = UIColor(red: 55/255, green: 55/255, blue: 55/255, alpha: 1.0) // #373737
        badge.layer.cornerRadius = 12.5
        badge.translatesAutoresizingMaskIntoConstraints = false

        // box_24 圆点：5pt，已连接 #1CDB71 / 已离线 #878787
        let dot = UIView()
        dot.backgroundColor = connected
            ? UIColor(red: 28/255, green: 219/255, blue: 113/255, alpha: 1.0)   // #1CDB71
            : UIColor(red: 135/255, green: 135/255, blue: 135/255, alpha: 1.0)  // #878787
        dot.layer.cornerRadius = 2.5
        dot.translatesAutoresizingMaskIntoConstraints = false

        // text_17：12pt，已连接白 / 已离线 #878787
        let statusLabel = UILabel()
        statusLabel.text = connected ? L("home.device.status.connected") : L("home.device.status.offline")
        statusLabel.textColor = connected ? .white : UIColor(red: 135/255, green: 135/255, blue: 135/255, alpha: 1.0)
        statusLabel.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        // 两种状态（已连接/已离线、Connected/Offline）胶囊宽度保持一致：
        // 取两段文案中较宽者 + 圆点 + 间距 + 左右内边距，所有卡片用同一固定宽度。
        let statusFont = statusLabel.font ?? .systemFont(ofSize: 12)
        let connectedW = (L("home.device.status.connected") as NSString)
            .size(withAttributes: [.font: statusFont]).width
        let offlineW = (L("home.device.status.offline") as NSString)
            .size(withAttributes: [.font: statusFont]).width
        let badgeWidth = ceil(max(connectedW, offlineW)) + 14 + 5 + 6 + 14 // 左内边距+圆点+间距+右内边距

        // 设备图：大图靠右、顶部溢出卡片（设计稿设备图突出卡片区域），不被裁剪
        let deviceImage = UIImageView(image: UIImage(named: "device"))
        deviceImage.contentMode = .scaleAspectFit
        deviceImage.clipsToBounds = false
        deviceImage.translatesAutoresizingMaskIntoConstraints = false

        badge.addSubview(dot)
        badge.addSubview(statusLabel)
        host.addSubview(nameLabel)
        host.addSubview(badge)
        host.addSubview(deviceImage)

        NSLayoutConstraint.activate([
            // 左侧内边距 22pt（padding-left 44px），name margin-top 27pt（54px）
            nameLabel.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 22),
            nameLabel.topAnchor.constraint(equalTo: host.topAnchor, constant: nameTopInset),

            // badge margin-top 14pt（28px）。固定宽度 = 两种状态较宽者，保证两张卡片胶囊等宽。
            badge.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 22),
            badge.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 14),
            badge.widthAnchor.constraint(equalToConstant: badgeWidth),
            badge.heightAnchor.constraint(equalToConstant: 25),

            // 圆点 + 文字：左内边距 14pt，点与文字间距 6pt（文字左对齐，短文案右侧留白）
            dot.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 14),
            dot.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 5),
            dot.heightAnchor.constraint(equalToConstant: 5),

            statusLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            statusLabel.centerYAnchor.constraint(equalTo: badge.centerYAnchor),

            // 设备图：大图靠右，顶部仅小幅溢出卡片 ~6pt（设计稿设备顶尖略高出卡片），
            // 高度约等于卡片高、底部留少量间距；宽高比贴近素材 1.12 避免留白
            deviceImage.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -14),
            deviceImage.topAnchor.constraint(equalTo: host.topAnchor, constant: deviceImgTop),
            deviceImage.widthAnchor.constraint(equalToConstant: deviceImgW),
            deviceImage.heightAnchor.constraint(equalToConstant: deviceImgH)
        ])

        return card
    }

    /// 点击设备卡 → 设备管理页，并定位到对应设备（与侧边栏 Devices 入口一致，只是多带了序号）
    private func openDeviceManagement(at index: Int) {
        let dm = DeviceManagementViewController()
        dm.initialDeviceIndex = index   // 进设备页直接翻到点中的那台
        let nav = UINavigationController(rootViewController: dm)
        nav.setNavigationBarHidden(true, animated: false)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
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
            // .scaleToFill would stretch this non-uniformly: view's width tracks screen
            // width (much wider on iPad) while its height is either a fixed constant or
            // content-driven, independent of width.
            bgImageView.contentMode = .scaleAspectFill
            bgImageView.clipsToBounds = true

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
        // 每次请求自增 generation；只有最新一次请求的回调才会更新 UI。
        // 否则切换 mock/真实数据时，之前在途的请求（HealthKit + dashboard 分两次回调，
        // 且 mock 还有 1s 延时）会乱序回来覆盖掉刚切换的数据。
        fetchGeneration += 1
        let gen = fetchGeneration
        HomeService.shared.fetchHomeData { [weak self] result in
            guard let self = self else { return }
            guard gen == self.fetchGeneration else { return } // 丢弃过期回调
            switch result {
            case .success(let data):
                self.updateData(data)
            case .failure(let error):
                print("Failed to fetch home data: \(error)")
                self.clearData()
            }
        }
    }

    @objc private func handleHealthAuthorizationChanged() {
        fetchData()
    }

    @objc private func handleAppWillEnterForeground() {
        fetchData()
        // 回前台重新允许展示一条弹窗；实际是否展示仍由本地频控（冷却 / 次数 / 已关闭）决定。
        didShowPopupThisForeground = false
        maybeShowHomePopup()
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
        // Long press on logo to open the notification/popup simulator menu.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleDebugSimulator(_:)))
        logoImageView.addGestureRecognizer(longPress)
        #endif
    }

    @objc private func handleDebugSimulator(_ gesture: UILongPressGestureRecognizer) {
        #if DEBUG
        guard gesture.state == .began else { return }
        // 当前档位直接写进标题：构造数据会真的上传给服务端，
        // 误以为在用真实数据是要出事的，不该逼人去菜单里找那个 ✓。
        let simulator = HealthDataSimulator.shared
        let healthState = simulator.quality.map { "构造 · \($0.displayName)" } ?? "真实数据"
        let sheet = UIAlertController(
            title: "调试 · 健康数据：\(healthState)",
            message: "选择要模拟的站内消息或首页弹窗",
            preferredStyle: .actionSheet
        )

        // 放在最上方：构造健康数据。测试机往往一条 HealthKit 数据都没有，服务端就收不到任何
        // 可供联调的数据；打开后 App 读到的健康数据全部由本地构造，并照常上传给服务端。
        // 与三击 logo 的整屏 UI 预览假数据是两套独立机制，互不影响。
        for quality in HealthSimulationQuality.allCases {
            let checked = simulator.quality == quality ? " ✓" : ""
            sheet.addAction(UIAlertAction(title: "构造健康数据 · \(quality.displayName)\(checked)", style: .default) { [weak self] _ in
                let isFirst = !simulator.isEnabled
                simulator.enable(quality)
                guard let self else { return }
                // 切换只影响最近一晚及之后，更早的日子保留原档位 —— 这样能攒出
                // 「前一阵睡得好、最近变差」这种混合历史，不用来回换账号。
                let hint = isFirst ? "已生成历史并上传" : "最近一晚起改为此档位，历史保留"
                Toast.show("「\(quality.displayName)」\(hint)", in: self.view)
                HealthSyncService.shared.performManualSync()
            })
        }
        let realChecked = simulator.isEnabled ? "" : " ✓"
        sheet.addAction(UIAlertAction(title: "读取真实健康数据（关闭构造）\(realChecked)", style: .default) { [weak self] _ in
            simulator.disable()
            guard let self else { return }
            Toast.show("已切回真实健康数据", in: self.view)
            // 切回来之后立刻按真实数据重新同步一次，免得服务端那边还停留在构造数据上。
            HealthSyncService.shared.performManualSync()
        })

        for item in DebugNotificationSimulator.messageItems {
            sheet.addAction(UIAlertAction(title: item.name, style: .default) { [weak self] _ in
                item.seed()
                guard let self else { return }
                Toast.show("已模拟：\(item.name)", in: self.view)
            })
        }

        let popupTypes: [(String, HomePopup.PopupType)] = [
            ("弹窗 · 参与调研", .survey), ("弹窗 · 商城活动", .mall), ("弹窗 · 纯广告", .ad)
        ]
        for (name, type) in popupTypes {
            sheet.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                guard let self else { return }
                let popup = DebugNotificationSimulator.samplePopup(type)
                PopupService.shared.recordMessage(for: popup)   // 与正式一致：同步落站内消息
                HomePopupView.present(popup: popup,
                                      onAction: { [weak self] p in self?.handlePopupAction(p) },
                                      onClose: { _ in })
            })
        }

        // 直接预览问卷 + 礼品领取页（分别看虚拟 / 实体两种领取界面）。
        let surveyPreviews: [(String, String)] = [
            ("问卷 · 虚拟礼品", "demo_survey_virtual"),
            ("问卷 · 实体礼品", "demo_survey_physical")
        ]
        for (name, sid) in surveyPreviews {
            sheet.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                let vc = SurveyViewController(surveyId: sid)
                vc.modalPresentationStyle = .fullScreen
                self?.present(vc, animated: true)
            })
        }

        sheet.addAction(UIAlertAction(title: "重置弹窗频控", style: .default) { [weak self] _ in
            PopupService.shared.clearCache()
            guard let self else { return }
            self.didShowPopupThisForeground = false
            Toast.show("已重置弹窗频控", in: self.view)
        })
        sheet.addAction(UIAlertAction(title: "立即重新同步弹窗", style: .default) { [weak self] _ in
            guard let self else { return }
            self.didShowPopupThisForeground = false
            PopupService.shared.sync(reason: "debug", force: true) { [weak self] popup in
                guard let self else { return }
                Toast.show(popup == nil ? "同步完成：无可展示弹窗" : "同步完成：\(popup!.title)", in: self.view)
                self.maybeShowHomePopup()
            }
        })
        sheet.addAction(UIAlertAction(title: "导出运行日志", style: .default) { [weak self] _ in
            guard let self else { return }
            guard let url = LogFileWriter.shared.exportCombined() else {
                Toast.show("暂无日志文件", in: self.view)
                return
            }
            let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let pop = share.popoverPresentationController {   // iPad 需锚点
                pop.sourceView = self.logoImageView
                pop.sourceRect = self.logoImageView.bounds
            }
            self.present(share, animated: true)
        })
        sheet.addAction(UIAlertAction(title: "清空所有站内消息", style: .destructive) { [weak self] _ in
            AppNotificationStore.shared.clear()
            guard let self else { return }
            Toast.show("已清空站内消息", in: self.view)
        })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))

        // iPad：actionSheet 需锚点。
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = logoImageView
            pop.sourceRect = logoImageView.bounds
        }
        present(sheet, animated: true)
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

// MARK: - 可左滑删除的设备卡

/// 首页设备卡：左滑露出右侧红色删除按钮（设计稿 block_21 左移 120px → 60pt，露出 group_23）。
/// 卡片内容放在 `contentView` 上随手指平移，删除按钮固定垫在底层；未绑定的占位卡不可滑动。
final class SwipeableDeviceCard: UIView {
    /// 露出宽度 = 删除按钮 30pt + 与卡片间距 14pt + 距卡片原右缘 16pt
    private static let revealWidth: CGFloat = 60

    let contentView = UIView()
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?
    /// 每次展开/收起动画结束后回调（即使状态未变也回调，用于补做推迟的重建）
    var onOpenStateChange: ((Bool) -> Void)?
    /// 手指正在拖动
    private(set) var isTracking = false
    private(set) var isOpen = false

    private let deletable: Bool
    private let deleteButton = UIButton(type: .custom)
    private var contentLeading: NSLayoutConstraint!
    private var panStartOffset: CGFloat = 0

    init(deletable: Bool) {
        self.deletable = deletable
        super.init(frame: .zero)
        clipsToBounds = false

        if deletable {
            // group_23：#FF5A59，圆角 18px=9pt，padding 28px/14px 包住 32px 图标 → 30×44pt
            deleteButton.backgroundColor = UIColor(red: 255/255, green: 90/255, blue: 89/255, alpha: 1.0)
            deleteButton.layer.cornerRadius = 9
            deleteButton.alpha = 0
            deleteButton.accessibilityLabel = L("device_manage.button.delete_device")
            deleteButton.translatesAutoresizingMaskIntoConstraints = false
            deleteButton.addTarget(self, action: #selector(handleDeleteTap), for: .touchUpInside)
            let icon = UIImageView(image: UIImage(named: "device_delete"))
            icon.contentMode = .scaleAspectFit
            icon.isUserInteractionEnabled = false
            icon.translatesAutoresizingMaskIntoConstraints = false
            deleteButton.addSubview(icon)
            addSubview(deleteButton)
            NSLayoutConstraint.activate([
                deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                deleteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
                deleteButton.widthAnchor.constraint(equalToConstant: 30),
                deleteButton.heightAnchor.constraint(equalToConstant: 44),
                icon.centerXAnchor.constraint(equalTo: deleteButton.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: deleteButton.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 16),
                icon.heightAnchor.constraint(equalToConstant: 16)
            ])

            addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        }

        contentView.clipsToBounds = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        contentLeading = contentView.leadingAnchor.constraint(equalTo: leadingAnchor)
        NSLayoutConstraint.activate([
            contentLeading,
            contentView.widthAnchor.constraint(equalTo: widthAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setOpen(_ open: Bool, animated: Bool) {
        isOpen = open
        contentLeading.constant = open ? -Self.revealWidth : 0
        let apply = {
            self.deleteButton.alpha = open ? 1 : 0
            self.layoutIfNeeded()
        }
        let finish = { self.onOpenStateChange?(open) }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .allowUserInteraction],
                           animations: apply, completion: { _ in finish() })
        } else {
            apply()
            finish()
        }
    }

    @objc private func handleTap() {
        // 展开状态下点卡片只收起，不跳转
        if isOpen {
            setOpen(false, animated: true)
        } else {
            onTap?()
        }
    }

    @objc private func handleDeleteTap() {
        onDelete?()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let reveal = Self.revealWidth
        switch gesture.state {
        case .began:
            isTracking = true
            panStartOffset = contentLeading.constant
        case .changed:
            var offset = panStartOffset + gesture.translation(in: self).x
            // 超出 [−reveal, 0] 的部分加阻尼
            if offset > 0 { offset *= 0.2 }
            if offset < -reveal { offset = -reveal + (offset + reveal) * 0.3 }
            contentLeading.constant = offset
            deleteButton.alpha = min(1, max(0, -offset / reveal))
        case .ended, .cancelled, .failed:
            isTracking = false
            let vx = gesture.velocity(in: self).x
            let open: Bool
            if gesture.state != .ended { open = isOpen }
            else if vx < -300 { open = true }
            else if vx > 300 { open = false }
            else { open = contentLeading.constant < -reveal / 2 }
            setOpen(open, animated: true)
        default:
            break
        }
    }

    // 只接管横向拖动，纵向交给外层 ScrollView
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let v = pan.velocity(in: self)
        return deletable && abs(v.x) > abs(v.y)
    }
}
