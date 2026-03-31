import UIKit

class HealthWeekView: UIView {
    
    // MARK: - Subviews
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let contentView = UIView()
    
    // Box 1: Header & Chart
    private let headerContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    // Add textStack as property
    private var textStack: UIStackView!
    
    // Non-member UI elements
    private var overlayMaskView: UIView?
    private var subscriptionPromptView: SubscriptionPromptView?
    
    var onSubscribeTap: (() -> Void)?
    var isMember: Bool = true {
        didSet {
            updateMembershipState()
        }
    }
    
    // MARK: - Date Helpers
    private static func currentWeekDateString() -> String {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        // Monday = 2 in Gregorian calendar
        let daysToMonday = (weekday == 1) ? -6 : (2 - weekday)
        let monday = calendar.date(byAdding: .day, value: daysToMonday, to: now)!
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d"
        let startDay = formatter.string(from: monday)
        formatter.dateFormat = "d MMM yyyy"
        let endStr = formatter.string(from: sunday)
        return "\(startDay) - \(endStr)"
    }
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.text = "--"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    // "Avg. sleep score"
    private let scoreTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.week.avg_score")
        // text_7: 22px (@2x) -> 11pt
        label.font = UIFont.systemFont(ofSize: 11, weight: .light)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    // "60"
    private let scoreValueLabel: UILabel = {
        let label = UILabel()
        label.text = "--"
        // text_8: 90px (@2x) -> 45pt, Color: #F8AD34 (Orange)
        label.font = UIFont.systemFont(ofSize: 45, weight: .semibold)
        label.textColor = UIColor(red: 248/255.0, green: 173/255.0, blue: 52/255.0, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    // "Good"
    private let scoreStateLabel: UILabel = {
        let label = UILabel()
        label.text = "--"
        // text_9: 36px (@2x) -> 18pt, Color: #F8AD34 (Orange)
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = UIColor(red: 248/255.0, green: 173/255.0, blue: 52/255.0, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    private let chartView = HealthWeekChartView()
    
    // Box 2: Sleep Insights
    private let insightsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private let insightsIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "home_sleep_insights"))
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private let insightsTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.week.insights_title")
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        return label
    }()
    
    private let insightsSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.week.insights_sub")
        // Design has smaller font for subtitle
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(white: 1.0, alpha: 0.6)
        return label
    }()
    
    private let insightsBodyLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.week.insights.body")
        label.font = UIFont.systemFont(ofSize: 30, weight: .regular) // Valid system font fallback
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()
    
    private let insightsDescLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.week.insights.desc")
        label.font = UIFont.systemFont(ofSize: 14, weight: .light)
        label.textColor = UIColor(white: 1.0, alpha: 0.8)
        label.numberOfLines = 0
        return label
    }()
    
    // ... arrow ...

    // Box 3: Weekly Best
    private let bestContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private let bestBgImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "sleep_week_onset_bg"))
        iv.contentMode = .scaleToFill
        return iv
    }()
    
    private let bestIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "home_best"))
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private let bestTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.week.best_title")
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        return label
    }()
    
    private let bestSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.week.best_sub")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(white: 1.0, alpha: 0.6)
        return label
    }()

    private let bestContentLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.week.sedona")
        label.font = UIFont.systemFont(ofSize: 30, weight: .regular)
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 0
        return label
    }()
    
    // Best Stats Row
    private let bestStatsContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 82
        return stack
    }()

    
    // Group 1: Vitals (Respiratory Rate, Heart Rate ...)
    private let vitalsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private let vitalsBgImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "sleep_detail_bg"))
        iv.contentMode = .scaleToFill
        return iv
    }()
    
    // Group 2: Sleep Trends (Total Sleep ...)
    private let trendsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private let trendsBgImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "sleep_detail_bg"))
        iv.contentMode = .scaleToFill
        return iv
    }()

    // Group 3: Onset Efficiency (Time in Bed ...)
    private let efficiencyContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private let efficiencyBgImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "sleep_detail_bg"))
        iv.contentMode = .scaleToFill
        return iv
    }()
    
    private let insightsBgImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "sleep_week_sleep_bg"))
        iv.contentMode = .scaleToFill
        return iv
    }()
    
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()
    
    // MARK: - Initializer
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupContent()
        reloadData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Reload Data
    func reloadData() {
        let showMock = Constants.Config.showMockData
        if showMock {
            let mockLocal = HealthMockDataService.shared.weekLocalData()
            let calendar = Calendar.current
            let now = Date()
            let weekday = calendar.component(.weekday, from: now)
            let daysToMonday = (weekday == 1) ? -6 : (2 - weekday)
            let monday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: daysToMonday, to: now) ?? now)
            let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? now
            let analysis = HealthAnalysisService.shared.mockWeekAnalysis(startDate: monday, endDate: sunday)

            dateLabel.text = mockLocal.dateText
            scoreValueLabel.text = analysis.scoreSummary?.score.map(String.init) ?? "--"
            scoreStateLabel.text = analysis.scoreSummary?.label ?? "--"
            insightsBodyLabel.text = analysis.sleepTrends?.body ?? ""
            insightsDescLabel.text = analysis.sleepTrends?.description ?? ""
            bestContentLabel.text = analysis.onsetEfficiency?.scenarioName ?? ""
            rebuildBestStats(
                trackedDays: analysis.onsetEfficiency?.usedTimes ?? 0,
                score: analysis.onsetEfficiency?.score.map(Double.init)
            )
            chartView.setMockValues(mockLocal.chartValues)
        } else {
            dateLabel.text = HealthWeekView.currentWeekDateString()
            scoreValueLabel.text = "--"
            scoreStateLabel.text = "--"
        }
        chartView.showMockData = showMock
        rebuildContent(showMock: showMock)
        if !showMock {
            loadRealData()
        }
    }

    private func loadRealData() {
        Task { @MainActor in
            do {
                let calendar = Calendar.current
                let now = Date()
                let weekday = calendar.component(.weekday, from: now)
                let daysToMonday = (weekday == 1) ? -6 : (2 - weekday)
                let monday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: daysToMonday, to: now) ?? now)
                let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? now

                async let metricsTask = HealthDataManager.shared.fetchLatestMetrics(forceLive: true)
                async let aggregatesTask = HealthDataManager.shared.fetchSleepDailyAggregates(startingFrom: monday, days: 7)
                async let analysisTask = HealthAnalysisService.shared.fetchWeekAnalysis(startDate: monday, endDate: sunday)

                let metrics = try await metricsTask
                let aggregates = try await aggregatesTask
                let analysis = try? await analysisTask

                applyRealWeekData(metrics: metrics, aggregates: aggregates, analysis: analysis)
            } catch {
                scoreValueLabel.text = "--"
                scoreStateLabel.text = "--"
            }
        }
    }

    private func applyRealWeekData(metrics: HealthMetrics, aggregates: [HealthDataManager.SleepDailyAggregate], analysis: HealthAnalysisService.WeekAnalysis?) {
        let tracked = aggregates.filter(\.hasData)
        let sleepValues = aggregates.map { CGFloat(min(max($0.totalSleepHours, 0), 10)) }
        chartView.setRealValues(sleepValues)

        scoreValueLabel.text = analysis?.scoreSummary?.score.map(String.init) ?? "--"
        scoreStateLabel.text = analysis?.scoreSummary?.label ?? "--"

        let averageDeep = average(tracked.map(\.deepSleepHours)) ?? 0
        let averageTotal = average(tracked.map(\.totalSleepHours)) ?? 0
        let deepRatio = averageTotal > 0 ? (averageDeep / averageTotal) * 100.0 : 0
        insightsBodyLabel.text = analysis?.sleepTrends?.body ?? String(format: "Deep sleep %.0f%% of total", deepRatio)
        insightsDescLabel.text = analysis?.sleepTrends?.description ?? "Average sleep this week was \(formatHours(averageTotal)) across \(tracked.count) tracked nights."

        bestTitleLabel.text = L("health.week.best_title")
        bestSubtitleLabel.text = L("health.week.best_sub")
        if let scenarioName = analysis?.onsetEfficiency?.scenarioName, !scenarioName.isEmpty {
            bestContentLabel.text = scenarioName
        } else if let averageOnset = average(tracked.compactMap(\.sleepOnsetMinutes)) {
            bestContentLabel.text = "Your average sleep onset this week was \(formatMinutesText(averageOnset))."
        } else {
            bestContentLabel.text = "Sleep onset will appear here after Apple Health records time in bed and sleep start."
        }
        rebuildBestStats(
            trackedDays: analysis?.onsetEfficiency?.usedTimes ?? tracked.count,
            score: analysis?.onsetEfficiency?.score.map(Double.init)
        )

        rebuildContent(showMock: false, aggregates: tracked, metrics: metrics)
    }

    private func rebuildBestStats(trackedDays: Int, score: Double?) {
        bestStatsContainer.arrangedSubviews.forEach {
            bestStatsContainer.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let trackedView = createStatView(value: "\(trackedDays)", label: L("health.week.best.used_times"))
        let scoreValue = score.map { "\(Int($0.rounded()))" } ?? "--"
        let scoreView = createStatView(value: scoreValue, label: L("health.week.best.score"))

        bestStatsContainer.addArrangedSubview(trackedView)
        bestStatsContainer.addArrangedSubview(scoreView)
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func formatHours(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60.0).rounded())
        let hourPart = totalMinutes / 60
        let minutePart = totalMinutes % 60
        if minutePart == 0 {
            return "\(hourPart)hr"
        }
        return "\(hourPart)hr \(minutePart)min"
    }

    private func formatMinutesText(_ minutes: Double) -> String {
        "\(Int(minutes.rounded()))min"
    }

    // MARK: - Setup UI
    private func setupUI() {
        clipsToBounds = true
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.clipsToBounds = true
        
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Add Subsections
        contentView.addSubview(headerContainer)
        contentView.addSubview(insightsContainer)
        contentView.addSubview(bestContainer)
        contentView.addSubview(contentStackView)
        
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        insightsContainer.translatesAutoresizingMaskIntoConstraints = false
        bestContainer.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        setupHeader()
        setupInsights()
        setupBest()
        
        NSLayoutConstraint.activate([
            // Header Content
            headerContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            headerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // Insights
            insightsContainer.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -40),
            insightsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            insightsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            // Height determined by content interactions
            
            // Best
            bestContainer.topAnchor.constraint(equalTo: insightsContainer.bottomAnchor, constant: 16),
            bestContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            bestContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            // Height determined by content interactions
            
            // Metrics Stack
            contentStackView.topAnchor.constraint(equalTo: bestContainer.bottomAnchor, constant: 24),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -50)
        ])
        
        // Setup Container Backgrounds
        insightsContainer.addSubview(insightsBgImageView)
        insightsBgImageView.translatesAutoresizingMaskIntoConstraints = false
        insightsContainer.sendSubviewToBack(insightsBgImageView)
        NSLayoutConstraint.activate([
            insightsBgImageView.topAnchor.constraint(equalTo: insightsContainer.topAnchor),
            insightsBgImageView.leadingAnchor.constraint(equalTo: insightsContainer.leadingAnchor),
            insightsBgImageView.trailingAnchor.constraint(equalTo: insightsContainer.trailingAnchor),
            insightsBgImageView.bottomAnchor.constraint(equalTo: insightsContainer.bottomAnchor)
        ])
        
        bestContainer.addSubview(bestBgImageView)
        bestBgImageView.translatesAutoresizingMaskIntoConstraints = false
        bestContainer.sendSubviewToBack(bestBgImageView)
        NSLayoutConstraint.activate([
            bestBgImageView.topAnchor.constraint(equalTo: bestContainer.topAnchor),
            bestBgImageView.leadingAnchor.constraint(equalTo: bestContainer.leadingAnchor),
            bestBgImageView.trailingAnchor.constraint(equalTo: bestContainer.trailingAnchor),
            bestBgImageView.bottomAnchor.constraint(equalTo: bestContainer.bottomAnchor)
        ])
        
        vitalsContainer.addSubview(vitalsBgImageView)
        vitalsBgImageView.translatesAutoresizingMaskIntoConstraints = false
        vitalsContainer.sendSubviewToBack(vitalsBgImageView)
        NSLayoutConstraint.activate([
            vitalsBgImageView.topAnchor.constraint(equalTo: vitalsContainer.topAnchor),
            vitalsBgImageView.leadingAnchor.constraint(equalTo: vitalsContainer.leadingAnchor),
            vitalsBgImageView.trailingAnchor.constraint(equalTo: vitalsContainer.trailingAnchor),
            vitalsBgImageView.bottomAnchor.constraint(equalTo: vitalsContainer.bottomAnchor)
        ])
        
        trendsContainer.addSubview(trendsBgImageView)
        trendsBgImageView.translatesAutoresizingMaskIntoConstraints = false
        trendsContainer.sendSubviewToBack(trendsBgImageView)
        NSLayoutConstraint.activate([
            trendsBgImageView.topAnchor.constraint(equalTo: trendsContainer.topAnchor),
            trendsBgImageView.leadingAnchor.constraint(equalTo: trendsContainer.leadingAnchor),
            trendsBgImageView.trailingAnchor.constraint(equalTo: trendsContainer.trailingAnchor),
            trendsBgImageView.bottomAnchor.constraint(equalTo: trendsContainer.bottomAnchor)
        ])
        
        efficiencyContainer.addSubview(efficiencyBgImageView)
        efficiencyBgImageView.translatesAutoresizingMaskIntoConstraints = false
        efficiencyContainer.sendSubviewToBack(efficiencyBgImageView)
        NSLayoutConstraint.activate([
            efficiencyBgImageView.topAnchor.constraint(equalTo: efficiencyContainer.topAnchor),
            efficiencyBgImageView.leadingAnchor.constraint(equalTo: efficiencyContainer.leadingAnchor),
            efficiencyBgImageView.trailingAnchor.constraint(equalTo: efficiencyContainer.trailingAnchor),
            efficiencyBgImageView.bottomAnchor.constraint(equalTo: efficiencyContainer.bottomAnchor)
        ])
    }
    
    private func setupHeader() {
        // Organize labels in a stack for consistent spacing group
        textStack = UIStackView(arrangedSubviews: [dateLabel, scoreTitleLabel, scoreValueLabel, scoreStateLabel])
        textStack.axis = .vertical
        textStack.alignment = .center
        textStack.spacing = 4
        textStack.setCustomSpacing(12, after: dateLabel)
        
        headerContainer.addSubview(textStack)
        headerContainer.addSubview(chartView)
        
        textStack.translatesAutoresizingMaskIntoConstraints = false
        chartView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
            textStack.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            textStack.leadingAnchor.constraint(greaterThanOrEqualTo: headerContainer.leadingAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: headerContainer.trailingAnchor),
            
            chartView.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 28),
            chartView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            chartView.heightAnchor.constraint(equalToConstant: 250),
            chartView.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor)
        ])
    }
    
    private func updateMembershipState() {
        if isMember {
            removeNonMemberOverlay()
            scrollView.isScrollEnabled = true
        } else {
            setupNonMemberOverlay()
            scrollView.isScrollEnabled = false
        }
    }
    
    private func setupNonMemberOverlay() {
        guard overlayMaskView == nil, let textStack = textStack else { return }
        
        // Mask View - Frosted Glass Effect
        let blurEffect = UIBlurEffect(style: .dark)
        let mask = UIVisualEffectView(effect: blurEffect)
        mask.alpha = 0.9
        
        // Add to self and use negative margins to extend beyond the container's padding
        addSubview(mask)
        mask.translatesAutoresizingMaskIntoConstraints = false
        self.overlayMaskView = mask
        
        // Prompt View
        let prompt = SubscriptionPromptView()
        prompt.onSubscribeTap = { [weak self] in
            self?.onSubscribeTap?()
        }
        addSubview(prompt)
        prompt.translatesAutoresizingMaskIntoConstraints = false
        self.subscriptionPromptView = prompt
        
        // Disable clipping on parent views to allow the mask to extend beyond bounds
        clipsToBounds = false
        scrollView.clipsToBounds = false
        
        NSLayoutConstraint.activate([
            // Mask covers from textStack bottom to the end, extending 20pt on each side
            mask.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 10),
            mask.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -20),
            mask.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 20),
            mask.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Prompt position
            prompt.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 47),
            prompt.centerXAnchor.constraint(equalTo: centerXAnchor),
            prompt.widthAnchor.constraint(equalToConstant: 214)
        ])
        
        // Ensure mask covers everything
        bringSubviewToFront(mask)
        bringSubviewToFront(prompt)
        
        layoutIfNeeded()
    }
    
    private func removeNonMemberOverlay() {
        overlayMaskView?.removeFromSuperview()
        overlayMaskView = nil
        subscriptionPromptView?.removeFromSuperview()
        subscriptionPromptView = nil
        clipsToBounds = true
        scrollView.clipsToBounds = true
    }
    
    private func setupInsights() {
        insightsContainer.addSubview(insightsIcon)
        insightsContainer.addSubview(insightsTitleLabel)
        insightsContainer.addSubview(insightsSubtitleLabel)
        insightsContainer.addSubview(insightsBodyLabel)
        insightsContainer.addSubview(insightsDescLabel)
        
        insightsIcon.translatesAutoresizingMaskIntoConstraints = false
        insightsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        insightsSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        insightsBodyLabel.translatesAutoresizingMaskIntoConstraints = false
        insightsDescLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Image at top right corner
        let rightImage = UIImageView(image: UIImage(named: "info")) // Using general info icon placeholder as specific image name unknown, user said 'label_6' in html is SketchPng...
        // Actually html says "label_6" src="...SketchPng..."
        // I'll stick to insightsIcon being the 'home_sleep_insights' on top left.
        
        NSLayoutConstraint.activate([
            insightsIcon.leadingAnchor.constraint(equalTo: insightsContainer.leadingAnchor, constant: 20),
            insightsIcon.topAnchor.constraint(equalTo: insightsContainer.topAnchor, constant: 20),
            insightsIcon.widthAnchor.constraint(equalToConstant: 32),
            insightsIcon.heightAnchor.constraint(equalToConstant: 32),
            
            insightsTitleLabel.leadingAnchor.constraint(equalTo: insightsIcon.trailingAnchor, constant: 12),
            insightsTitleLabel.topAnchor.constraint(equalTo: insightsContainer.topAnchor, constant: 20),
            
            insightsSubtitleLabel.leadingAnchor.constraint(equalTo: insightsTitleLabel.leadingAnchor),
            insightsSubtitleLabel.topAnchor.constraint(equalTo: insightsTitleLabel.bottomAnchor, constant: 4),
            
            insightsBodyLabel.leadingAnchor.constraint(equalTo: insightsTitleLabel.leadingAnchor),
            insightsBodyLabel.topAnchor.constraint(equalTo: insightsSubtitleLabel.bottomAnchor, constant: 24),
            insightsBodyLabel.trailingAnchor.constraint(equalTo: insightsContainer.trailingAnchor, constant: -30),
            
            insightsDescLabel.leadingAnchor.constraint(equalTo: insightsTitleLabel.leadingAnchor),
            insightsDescLabel.topAnchor.constraint(equalTo: insightsBodyLabel.bottomAnchor, constant: 16),
            insightsDescLabel.trailingAnchor.constraint(equalTo: insightsContainer.trailingAnchor, constant: -30),
            insightsDescLabel.bottomAnchor.constraint(equalTo: insightsContainer.bottomAnchor, constant: -30)
        ])
        
        // Remove height constraint on insightsContainer from setupUI as it needs to grow
        if let constraints = insightsContainer.constraints.first(where: { $0.firstAttribute == .height }) {
            insightsContainer.removeConstraint(constraints)
        }
    }
    
    private func setupBest() {
        bestContainer.addSubview(bestIcon)
        bestContainer.addSubview(bestTitleLabel)
        bestContainer.addSubview(bestSubtitleLabel)
        bestContainer.addSubview(bestContentLabel)
        bestContainer.addSubview(bestStatsContainer)
        
        bestIcon.translatesAutoresizingMaskIntoConstraints = false
        bestTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        bestSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        bestContentLabel.translatesAutoresizingMaskIntoConstraints = false
        bestStatsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Create Stats: Used times & Score
        let usedTimesView = createStatView(value: "5", label: L("health.week.best.used_times"))
        let scoreView = createStatView(value: "88", label: L("health.week.best.score"))
        
        bestStatsContainer.addArrangedSubview(usedTimesView)
        bestStatsContainer.addArrangedSubview(scoreView)
        
        NSLayoutConstraint.activate([
            bestIcon.leadingAnchor.constraint(equalTo: bestContainer.leadingAnchor, constant: 20),
            bestIcon.topAnchor.constraint(equalTo: bestContainer.topAnchor, constant: 20),
            bestIcon.widthAnchor.constraint(equalToConstant: 32),
            bestIcon.heightAnchor.constraint(equalToConstant: 32),
            
            bestTitleLabel.leadingAnchor.constraint(equalTo: bestIcon.trailingAnchor, constant: 12),
            bestTitleLabel.topAnchor.constraint(equalTo: bestContainer.topAnchor, constant: 20),
            
            bestSubtitleLabel.leadingAnchor.constraint(equalTo: bestTitleLabel.leadingAnchor),
            bestSubtitleLabel.topAnchor.constraint(equalTo: bestTitleLabel.bottomAnchor, constant: 4),
            
            bestContentLabel.leadingAnchor.constraint(equalTo: bestTitleLabel.leadingAnchor),
            bestContentLabel.trailingAnchor.constraint(equalTo: bestContainer.trailingAnchor, constant: -20),
            bestContentLabel.topAnchor.constraint(equalTo: bestSubtitleLabel.bottomAnchor, constant: 24),
            
            bestStatsContainer.topAnchor.constraint(equalTo: bestContentLabel.bottomAnchor, constant: 24),
            bestStatsContainer.centerXAnchor.constraint(equalTo: bestContainer.centerXAnchor),
            bestStatsContainer.bottomAnchor.constraint(equalTo: bestContainer.bottomAnchor, constant: -30)
        ])
         
        // Remove height constraint on bestContainer
        if let constraints = bestContainer.constraints.first(where: { $0.firstAttribute == .height }) {
            bestContainer.removeConstraint(constraints)
        }
    }
    
    private func createStatView(value: String, label: String) -> UIView {
        let view = UIView()
        let valLabel = UILabel()
        valLabel.text = value
        valLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        valLabel.textColor = .white
        
        let subLabel = UILabel()
        subLabel.text = label
        subLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        subLabel.textColor = UIColor(white: 1.0, alpha: 0.6)
        
        view.addSubview(valLabel)
        view.addSubview(subLabel)
        valLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            valLabel.topAnchor.constraint(equalTo: view.topAnchor),
            valLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            subLabel.topAnchor.constraint(equalTo: valLabel.bottomAnchor, constant: 4),
            subLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            view.widthAnchor.constraint(equalToConstant: 80)
        ])
        return view
    }
    
    private func rebuildContent(showMock: Bool, aggregates: [HealthDataManager.SleepDailyAggregate] = [], metrics: HealthMetrics? = nil) {
        let mockLocal = HealthMockDataService.shared.weekLocalData()
        // Clear existing subviews
        for view in contentStackView.arrangedSubviews {
            contentStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        guard showMock else {
            let trackedDays = aggregates.count
            let avgAwake = average(aggregates.map(\.awakeMinutes)) ?? 0
            let avgRem = average(aggregates.map(\.remSleepHours)) ?? 0
            let avgCore = average(aggregates.map(\.coreSleepHours)) ?? 0
            let avgDeep = average(aggregates.map(\.deepSleepHours)) ?? 0
            let avgTotal = average(aggregates.map(\.totalSleepHours)) ?? 0
            let avgOnset = average(aggregates.compactMap(\.sleepOnsetMinutes))
            let avgTimeInBed = average(aggregates.map(\.timeInBedHours)) ?? 0

            let vitalsCard = WeekExpandableCard(
                icon: "home_heart_rate",
                title: L("health.week.header.heart_rate"),
                value: metrics?.heartRate.map { "\(Int($0.value.rounded()))bpm" } ?? "--",
                detailRows: [
                    (L("health.week.respiratory_rate"), metrics?.respiratoryRate.map { "\(Int($0.value.rounded()))bpm" } ?? "--", nil),
                    (L("health.week.avg_heart_rate"), metrics?.restingHeartRate.map { "\(Int($0.value.rounded()))bpm" } ?? "--", nil),
                    (L("health.week.avg_skin_temp"), (metrics?.sleepingWristTemperature ?? metrics?.bodyTemperature).map { String(format: "%.1f°C", $0.value) } ?? "--", L("health.week.metric.from_baseline"))
                ]
            )
            contentStackView.addArrangedSubview(vitalsCard)

            let trendsCard = WeekExpandableCard(
                icon: "sleep_week_sleep",
                title: L("health.week.header.total_sleep"),
                value: formatHours(aggregates.map(\.totalSleepHours).reduce(0, +)),
                detailRows: [
                    (L("health.week.avg_awake"), formatMinutesText(avgAwake), nil),
                    (L("health.week.avg_rem"), formatHours(avgRem), nil),
                    (L("health.week.avg_core"), formatHours(avgCore), nil),
                    (L("health.week.avg_deep"), formatHours(avgDeep), nil)
                ]
            )
            contentStackView.addArrangedSubview(trendsCard)

            let efficiencyCard = WeekExpandableCard(
                icon: "sleep_week_timeinbed",
                title: L("health.week.header.time_in_bed"),
                value: formatHours(avgTimeInBed),
                detailRows: [
                    (L("health.week.days_tracked"), "\(trackedDays)/7days", nil),
                    (L("health.week.avg_total"), formatHours(avgTotal), nil),
                    (L("health.week.avg_onset"), avgOnset.map(formatMinutesText) ?? "--", nil)
                ]
            )
            contentStackView.addArrangedSubview(efficiencyCard)
            return
        }
        
        // Group 1: Vitals
        let vitalsCard = WeekExpandableCard(
            icon: "home_heart_rate",
            title: L("health.week.header.heart_rate"),
            value: mockLocal.heartRateText,
            detailRows: [
                (L("health.week.respiratory_rate"), mockLocal.respiratoryRangeText, nil),
                (L("health.week.avg_heart_rate"), mockLocal.averageHeartRateRangeText, nil),
                (L("health.week.avg_skin_temp"), mockLocal.skinTemperatureDeltaText, L("health.week.metric.from_baseline"))
            ]
        )
        contentStackView.addArrangedSubview(vitalsCard)
        
        // Group 2: Sleep Trends
        let trendsCard = WeekExpandableCard(
            icon: "sleep_week_sleep",
            title: L("health.week.header.total_sleep"),
            value: mockLocal.totalSleepText,
            detailRows: [
                (L("health.week.avg_awake"), mockLocal.averageAwakeText, nil),
                (L("health.week.avg_rem"), mockLocal.averageRemText, nil),
                (L("health.week.avg_core"), mockLocal.averageCoreText, nil),
                (L("health.week.avg_deep"), mockLocal.averageDeepText, nil)
            ]
        )
        contentStackView.addArrangedSubview(trendsCard)
        
        // Group 3: Onset Efficiency
        let efficiencyCard = WeekExpandableCard(
            icon: "sleep_week_timeinbed",
            title: L("health.week.header.time_in_bed"),
            value: mockLocal.timeInBedText,
            detailRows: [
                (L("health.week.days_tracked"), mockLocal.trackedDaysText, nil),
                (L("health.week.avg_total"), mockLocal.averageTotalText, nil),
                (L("health.week.avg_onset"), mockLocal.averageOnsetText, nil)
            ]
        )
        contentStackView.addArrangedSubview(efficiencyCard)
    }
    
    private func setupContent() {
        // Initial content setup - will be rebuilt by reloadData()
    }
    
    // Removed old setup methods as they are replaced by WeekExpandableCard logic
    // ...
}

// MARK: - Week Expandable Card
class WeekExpandableCard: UIView {
    private var isExpanded = false
    private let arrowBtn = UIButton()
    private let expandedStack = UIStackView()
    
    init(icon: String, title: String, value: String, detailRows: [(String, String, String?)]) {
        super.init(frame: .zero)
        setupUI(icon: icon, title: title, value: value, detailRows: detailRows)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(icon: String, title: String, value: String, detailRows: [(String, String, String?)]) {
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // 1. Header Wrapper
        let headerWrapper = UIView()
        headerWrapper.layer.cornerRadius = 16
        headerWrapper.clipsToBounds = true
        headerWrapper.translatesAutoresizingMaskIntoConstraints = false
        headerWrapper.heightAnchor.constraint(greaterThanOrEqualToConstant: 74).isActive = true
        
        mainStack.addArrangedSubview(headerWrapper)
        
        // Header Background
        let bgImageView = UIImageView(image: UIImage(named: "sleep_detail_bg"))
        bgImageView.contentMode = .scaleToFill
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        headerWrapper.addSubview(bgImageView)
        
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: headerWrapper.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: headerWrapper.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: headerWrapper.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: headerWrapper.bottomAnchor)
        ])
        
        // Icon
        let iconView = UIImageView(image: UIImage(named: icon))
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        headerWrapper.addSubview(iconView)
        
        // Text Stack (Title + Value)
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false
        headerWrapper.addSubview(textStack)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = UIColor(white: 1.0, alpha: 0.7)
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        valueLabel.textColor = .white
        
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(valueLabel)
        
        // Arrow Button
        arrowBtn.setImage(UIImage(named: "arrow_down"), for: .normal)
        arrowBtn.translatesAutoresizingMaskIntoConstraints = false
        arrowBtn.addTarget(self, action: #selector(toggleExpand), for: .touchUpInside)
        headerWrapper.addSubview(arrowBtn)
        
        // Tap Gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleExpand))
        headerWrapper.addGestureRecognizer(tap)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: headerWrapper.leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: headerWrapper.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            textStack.centerYAnchor.constraint(equalTo: headerWrapper.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: arrowBtn.leadingAnchor, constant: -10),
            
            arrowBtn.trailingAnchor.constraint(equalTo: headerWrapper.trailingAnchor, constant: -20),
            arrowBtn.centerYAnchor.constraint(equalTo: headerWrapper.centerYAnchor),
            arrowBtn.widthAnchor.constraint(equalToConstant: 24),
            arrowBtn.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // 2. Expanded Content
        expandedStack.axis = .vertical
        expandedStack.spacing = 20
        expandedStack.isHidden = true
        expandedStack.alpha = 0
        mainStack.addArrangedSubview(expandedStack)
        
        // Rows
        for (rowTitle, rowValue, rowSub) in detailRows {
            let rowBox = UIView()
            
            let tLabel = UILabel()
            tLabel.text = rowTitle
            tLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            tLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
            tLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let vStack = UIStackView()
            vStack.axis = .vertical
            vStack.alignment = .trailing
            vStack.translatesAutoresizingMaskIntoConstraints = false
            
            let vLabel = UILabel()
            vLabel.text = rowValue
            vLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            vLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
            
            vStack.addArrangedSubview(vLabel)
            
            if let s = rowSub {
                let sLabel = UILabel()
                sLabel.text = s
                sLabel.font = UIFont.systemFont(ofSize: 10, weight: .regular)
                sLabel.textColor = UIColor(white: 1.0, alpha: 0.4)
                vStack.addArrangedSubview(sLabel)
            }
            
            rowBox.addSubview(tLabel)
            rowBox.addSubview(vStack)
            
            NSLayoutConstraint.activate([
                rowBox.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
                
                tLabel.leadingAnchor.constraint(equalTo: rowBox.leadingAnchor, constant: 20),
                tLabel.topAnchor.constraint(equalTo: rowBox.topAnchor),
                tLabel.bottomAnchor.constraint(equalTo: rowBox.bottomAnchor),
                
                vStack.trailingAnchor.constraint(equalTo: rowBox.trailingAnchor, constant: -20),
                vStack.centerYAnchor.constraint(equalTo: rowBox.centerYAnchor)
            ])
            
            expandedStack.addArrangedSubview(rowBox)
        }
        
        // Bottom spacer for expanded stack
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 10).isActive = true
        expandedStack.addArrangedSubview(spacer)
    }
    
    @objc private func toggleExpand() {
        isExpanded.toggle()
        
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            guard let self = self else { return }
            self.expandedStack.isHidden = !self.isExpanded
            self.expandedStack.alpha = self.isExpanded ? 1 : 0
            self.arrowBtn.transform = self.isExpanded ? CGAffineTransform(rotationAngle: .pi) : .identity
            self.layoutIfNeeded()
            // Force parent layout update if needed?
            // Usually stackview will auto-resize, but animation inside stackview might be jerky without layoutIfNeeded on parent
        })
    }
}

// MARK: - Week Chart Components
class HealthWeekChartView: UIView {
    
    // UI Constants
    private let chartBoxHeight: CGFloat = 151
    private let chartBoxLeading: CGFloat = 32.0
    private let chartBoxTrailing: CGFloat = 40.0
    private let barWidth: CGFloat = 14.5
    
    // Data
    struct BarData {
        let value: CGFloat // 0-10
        let label: String
    }
    
    private var mockItems: [BarData] = [
        BarData(value: 7.2, label: "Mon."),
        BarData(value: 9.0, label: "Tue."),
        BarData(value: 5.2, label: "Wed."),
        BarData(value: 3.8, label: "Thu."),
        BarData(value: 7.5, label: "Fri."),
        BarData(value: 7.2, label: "Sat."),
        BarData(value: 0.0, label: "Sun.")
    ]
    
    private static let emptyItems: [BarData] = [
        BarData(value: 0.0, label: "Mon."),
        BarData(value: 0.0, label: "Tue."),
        BarData(value: 0.0, label: "Wed."),
        BarData(value: 0.0, label: "Thu."),
        BarData(value: 0.0, label: "Fri."),
        BarData(value: 0.0, label: "Sat."),
        BarData(value: 0.0, label: "Sun.")
    ]
    
    private var items: [BarData] = []
    private var realItems: [BarData] = HealthWeekChartView.emptyItems

    func setMockValues(_ values: [CGFloat]) {
        let labels = ["Mon.", "Tue.", "Wed.", "Thu.", "Fri.", "Sat.", "Sun."]
        guard values.count == labels.count else { return }
        mockItems = zip(values, labels).map { BarData(value: $0.0, label: $0.1) }
        if showMockData {
            items = mockItems
            rebuildChart()
        }
    }
    
    var showMockData: Bool = true {
        didSet {
            items = showMockData ? mockItems : realItems
            rebuildChart()
        }
    }

    func setRealValues(_ values: [CGFloat]) {
        guard values.count == 7 else {
            realItems = HealthWeekChartView.emptyItems
            if !showMockData {
                items = realItems
                rebuildChart()
            }
            return
        }

        let labels = ["Mon.", "Tue.", "Wed.", "Thu.", "Fri.", "Sat.", "Sun."]
        realItems = zip(values, labels).map { BarData(value: $0.0, label: $0.1) }
        if !showMockData {
            items = realItems
            rebuildChart()
        }
    }
    
    private var chartContainer: UIView!
    private var tooltipView: UIView?
    private var dotView: UIView?
    private let connectorLayer = CAShapeLayer()
    
    // Track selected index for toggle behavior
    private var selectedIndex: Int?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        items = mockItems
        
        // Setup Connector Layer
        connectorLayer.strokeColor = UIColor.white.cgColor
        connectorLayer.lineWidth = 1
        connectorLayer.fillColor = nil
        layer.addSublayer(connectorLayer)
        
        setupChart()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func rebuildChart() {
        // Remove all subviews and sublayers except connector
        subviews.forEach { $0.removeFromSuperview() }
        tooltipView = nil
        dotView = nil
        selectedIndex = nil
        connectorLayer.path = nil
        setupChart()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateConnector()
    }
    
    private func updateConnector() {
        guard let tooltip = tooltipView, let dot = dotView else {
            connectorLayer.path = nil
            return
        }
        
        layoutIfNeeded()
        
        let tooltipFrame = tooltip.frame
        let dotFrame = dot.frame
        
        if tooltipFrame.isEmpty || dotFrame.isEmpty { return }
        
        let path = UIBezierPath()
        let localTooltipMidY = tooltipFrame.midY
        
        // Determine side based on positions
        if tooltipFrame.minX > dotFrame.maxX {
            // Tooltip is on the Right
            
            // Start: Middle of Tooltip Left Edge
            let startPoint = CGPoint(x: tooltipFrame.minX, y: localTooltipMidY)
            path.move(to: startPoint)
            
            // Go Left to Dot Center X
            let turnPoint = CGPoint(x: dotFrame.midX, y: localTooltipMidY)
            path.addLine(to: turnPoint)
            
        } else {
            // Tooltip is on the Left
            
            // Start: Middle of Tooltip Right Edge
            let startPoint = CGPoint(x: tooltipFrame.maxX, y: localTooltipMidY)
            path.move(to: startPoint)
            
            // Go Right to Dot Center X
            let turnPoint = CGPoint(x: dotFrame.midX, y: localTooltipMidY)
            path.addLine(to: turnPoint)
        }
        
        // Common End: Vertical Line to Dot Center
        let endPoint = CGPoint(x: dotFrame.midX, y: dotFrame.midY)
        path.addLine(to: endPoint)
        
        connectorLayer.path = path.cgPath
    }
    
    private func setupChart() {
        // 1. Chart Container Box
        chartContainer = UIView()
        chartContainer.backgroundColor = .clear
        chartContainer.layer.borderWidth = 0.5
        // Border: #929292 60% opacity -> 0.6 alpha
        chartContainer.layer.borderColor = UIColor(red: 146/255, green: 146/255, blue: 146/255, alpha: 0.6).cgColor
        addSubview(chartContainer)
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: chartBoxLeading),
            chartContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -chartBoxTrailing),
            chartContainer.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            chartContainer.heightAnchor.constraint(equalToConstant: chartBoxHeight)
        ])
        
        // 2. Grid Lines & Y Labels
        let yValues = [0, 2, 4, 6, 8, 10]
        for val in yValues {
            let normalize = CGFloat(val) / 10.0
            // Align to pixel boundary to prevent blurriness and color inconsistency
            // Use rounding to snap to nearest point
            let yOffset = round(chartBoxHeight * normalize)
            
            // Unified Guide Line View for consistency
            let guideLine = ChartGuideLineView()
            guideLine.color = UIColor(red: 146/255, green: 146/255, blue: 146/255, alpha: 0.6)
            guideLine.isDashed = (val == 6)
            guideLine.translatesAutoresizingMaskIntoConstraints = false
            chartContainer.addSubview(guideLine)
            
            NSLayoutConstraint.activate([
                guideLine.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor),
                guideLine.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor),
                guideLine.heightAnchor.constraint(equalToConstant: 1),
                // Use bottomAnchor offset to ensure the frame sits on exact point coordinates
                // Since height is 1, placing its bottom at yOffset means it occupies (yOffset-1) to yOffset
                guideLine.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: -yOffset)
            ])
            
            // Label
            let label = UILabel()
            label.text = "\(val)"
            label.font = UIFont.systemFont(ofSize: 11, weight: .light)
            label.textColor = UIColor(white: 1.0, alpha: 0.8)
            label.textAlignment = .center
            addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: -8),
                // Center label with the line
                label.centerYAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: -yOffset),
                label.widthAnchor.constraint(equalToConstant: 20)
            ])
        }
        
        // 3. Bars & X Labels
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        
        chartContainer.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        // Add padding to sides to center bars within the space nicely
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: chartContainer.topAnchor),
            stack.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor)
        ])
        
        for (index, item) in items.enumerated() {
            let column = UIView()
            column.translatesAutoresizingMaskIntoConstraints = false
            column.widthAnchor.constraint(equalToConstant: barWidth).isActive = true
            stack.addArrangedSubview(column)
            
            // Bar Calculation
            let barHeight = chartBoxHeight * (item.value / 10.0)
            let barView = GradientBarView(colors: getColors(for: item.value))
            barView.layer.cornerRadius = 3
            barView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            barView.tag = index
            
            // Add tap gesture
            let tap = UITapGestureRecognizer(target: self, action: #selector(barTapped(_:)))
            column.addGestureRecognizer(tap)
            
            column.addSubview(barView)
            barView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                barView.bottomAnchor.constraint(equalTo: column.bottomAnchor),
                barView.leadingAnchor.constraint(equalTo: column.leadingAnchor),
                barView.trailingAnchor.constraint(equalTo: column.trailingAnchor),
                barView.heightAnchor.constraint(equalToConstant: max(barHeight, 1))
            ])
            
            // X Label
            let xLabel = UILabel()
            xLabel.text = item.label
            xLabel.font = UIFont.systemFont(ofSize: 11, weight: .light)
            xLabel.textColor = UIColor(white: 1.0, alpha: 0.8)
            xLabel.textAlignment = .center
            addSubview(xLabel)
            xLabel.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                xLabel.topAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: 8),
                xLabel.centerXAnchor.constraint(equalTo: column.centerXAnchor)
            ])
            
            // Removed default selection as per request
            // if index == 5 { ... }
        }
    }
    
    private func getColors(for value: CGFloat) -> [CGColor] {
        if value >= 7.0 {
            // #1CDB71 -> #219553
            return [UIColor(red: 28/255, green: 219/255, blue: 113/255, alpha: 1).cgColor,
                    UIColor(red: 33/255, green: 149/255, blue: 83/255, alpha: 1).cgColor]
        } else if value >= 5.0 {
            // #F8AD34 -> #C18525
             return [UIColor(red: 248/255, green: 173/255, blue: 52/255, alpha: 1).cgColor,
                     UIColor(red: 193/255, green: 133/255, blue: 37/255, alpha: 1).cgColor]
        } else {
            // #F35675 -> #B24258
             return [UIColor(red: 243/255, green: 86/255, blue: 117/255, alpha: 1).cgColor,
                     UIColor(red: 178/255, green: 66/255, blue: 88/255, alpha: 1).cgColor]
        }
    }
    
    @objc private func barTapped(_ sender: Any) {
        if let tap = sender as? UITapGestureRecognizer, let column = tap.view, let barView = column.subviews.first(where: { $0 is GradientBarView }) {
            let index = barView.tag
            
            if selectedIndex == index {
                // Toggle off with animation
                hideTooltip(animated: true)
            } else {
                // Switch to new bar
                // Remove existing immediately (no animation) to avoid overlapping/ghosting during quick switch
                hideTooltip(animated: false)
                showTooltip(for: index, sourceView: barView, animated: true)
            }
        }
    }
    
    private func hideTooltip(animated: Bool) {
        selectedIndex = nil
        
        let duration = animated ? 0.25 : 0.0
        let currentTooltip = tooltipView
        let currentDot = dotView
        
        let completionBlock: (Bool) -> Void = { _ in
            currentTooltip?.removeFromSuperview()
            currentDot?.removeFromSuperview()
            self.connectorLayer.path = nil
            // Reset opacity for next use
            self.connectorLayer.opacity = 1
            
            // Clear current references only if they match (though logic ensures serial access usually)
            if self.tooltipView == currentTooltip { self.tooltipView = nil }
            if self.dotView == currentDot { self.dotView = nil }
        }
        
        if animated {
            UIView.animate(withDuration: duration, animations: {
                currentTooltip?.alpha = 0
                currentDot?.alpha = 0
                self.connectorLayer.opacity = 0
            }, completion: completionBlock)
        } else {
            completionBlock(true)
        }
    }
    
    // MARK: - Tooltip Logic
    private func showTooltip(for index: Int, sourceView: UIView, animated: Bool = true) {
        // Ensure clean state handled by caller (hideTooltip)
        
        selectedIndex = index
        
        guard index < items.count else { return }
        let item = items[index]
        if item.value == 0 { return }
        
        // 1. Tooltip Box
        let tooltip = UIView()
        // Color #575757 (87,87,87) with 70% opacity
        tooltip.backgroundColor = UIColor(red: 87/255, green: 87/255, blue: 87/255, alpha: 0.7)
        tooltip.layer.cornerRadius = 3
        tooltip.layer.borderWidth = 1
        // Updated: White border color to match connector
        tooltip.layer.borderColor = UIColor.white.cgColor
        
        // Initial alpha for animation
        let initialAlpha: CGFloat = animated ? 0.0 : 1.0
        tooltip.alpha = initialAlpha
        
        addSubview(tooltip)
        tooltip.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        let hours = Int(item.value)
        let minutes = Int((item.value - CGFloat(hours)) * 60)
        titleLabel.text = String(format: "%dhr %dm", hours, minutes)
        
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .left
        
        let dateSubtitle = UILabel()
        // Dynamic Date Logic: Calculate actual date for each weekday
        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: now)
        let daysToMonday = (currentWeekday == 1) ? -6 : (2 - currentWeekday)
        let monday = calendar.date(byAdding: .day, value: daysToMonday, to: now)!
        let targetDate = calendar.date(byAdding: .day, value: index, to: monday)!
        let day = calendar.component(.day, from: targetDate)
        let suffix: String = {
            switch day {
            case 1, 21, 31: return "st"
            case 2, 22: return "nd"
            case 3, 23: return "rd"
            default: return "th"
            }
        }()
        let dayName = item.label.replacingOccurrences(of: ".", with: "")
        let monthYearFormatter = DateFormatter()
        monthYearFormatter.locale = Locale(identifier: "en_US")
        monthYearFormatter.dateFormat = "MMM yyyy"
        let monthYear = monthYearFormatter.string(from: targetDate)
        dateSubtitle.text = "\(dayName), \(day)\(suffix) \(monthYear)"
        
        dateSubtitle.textColor = .lightGray
        dateSubtitle.font = UIFont.systemFont(ofSize: 10)
        dateSubtitle.textAlignment = .left
        
        // Use StackView for padding layout
        let labelStack = UIStackView(arrangedSubviews: [titleLabel, dateSubtitle])
        labelStack.axis = .vertical
        labelStack.spacing = 2
        labelStack.alignment = .leading
        labelStack.distribution = .fill
        
        tooltip.addSubview(labelStack)
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Restore Padding Constraints (6pt) to determine Tooltip size automatically
        NSLayoutConstraint.activate([
            labelStack.topAnchor.constraint(equalTo: tooltip.topAnchor, constant: 6),
            labelStack.leadingAnchor.constraint(equalTo: tooltip.leadingAnchor, constant: 6),
            labelStack.trailingAnchor.constraint(equalTo: tooltip.trailingAnchor, constant: -6),
            labelStack.bottomAnchor.constraint(equalTo: tooltip.bottomAnchor, constant: -6)
        ])
        
        // 2. Connector Dot
        let dot = UIView()
        dot.backgroundColor = .clear
        dot.alpha = initialAlpha
        
        let borderLayer = CALayer()
        borderLayer.frame = CGRect(x: 0, y: 0, width: 6.5, height: 6.5)
        borderLayer.backgroundColor = UIColor.white.cgColor
        borderLayer.cornerRadius = 3.25
        dot.layer.addSublayer(borderLayer)
        
        let fillLayer = CALayer()
        fillLayer.frame = CGRect(x: 1.5, y: 1.5, width: 3.5, height: 3.5)
        fillLayer.backgroundColor = UIColor(red: 0.74, green: 0.64, blue: 0.76, alpha: 1).cgColor
        fillLayer.cornerRadius = 1.75
        dot.layer.addSublayer(fillLayer)
        
        addSubview(dot)
        dot.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 6.5),
            dot.heightAnchor.constraint(equalToConstant: 6.5),
            dot.centerXAnchor.constraint(equalTo: sourceView.centerXAnchor),
            // Updated: Dot Top is 3.5pt from Bar Top (Inside)
            dot.topAnchor.constraint(equalTo: sourceView.topAnchor, constant: 3.5)
        ])
        
        // 3. Position Tooltip
        // Check index to decide position (Left or Right)
        // Indices 0, 1 (Mon, Tue) are close to left edge, show tooltip on Right
        // Others show on Left
        if index <= 1 {
            NSLayoutConstraint.activate([
                // Bottom aligns with CenterY of Dot
                tooltip.bottomAnchor.constraint(equalTo: dot.centerYAnchor),
                // Show on Right: Left edge is 10pt from Dot Right edge
                tooltip.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10)
            ])
        } else {
            NSLayoutConstraint.activate([
                // Bottom aligns with CenterY of Dot
                tooltip.bottomAnchor.constraint(equalTo: dot.centerYAnchor),
                // Show on Left: Right edge is 10pt from Dot Left edge
                tooltip.trailingAnchor.constraint(equalTo: dot.leadingAnchor, constant: -10)
            ])
        }
        
        self.tooltipView = tooltip
        self.dotView = dot
        
        // Init connector opacity
        self.connectorLayer.opacity = Float(initialAlpha)
        
        // Trigger layout update for Connector Path
        setNeedsLayout()
        layoutIfNeeded()
        
        if animated {
            UIView.animate(withDuration: 0.25) {
                tooltip.alpha = 1.0
                dot.alpha = 1.0
                self.connectorLayer.opacity = 1.0
            }
        }
    }
}

class GradientBarView: UIView {
    var gradientLayer = CAGradientLayer()
    
    init(colors: [CGColor]) {
        super.init(frame: .zero)
        gradientLayer.colors = colors
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gradientLayer)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = layer.cornerRadius
        gradientLayer.maskedCorners = layer.maskedCorners
    }
}

class ChartGuideLineView: UIView {
    var color: UIColor = .gray
    var isDashed: Bool = false
    
    override func draw(_ rect: CGRect) {
        let path = UIBezierPath()
        // Draw in middle vertically
        let midY = rect.height / 2
        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: rect.width, y: midY))
        
        if isDashed {
            let dashes: [CGFloat] = [2, 2] // Dashed pattern
            path.setLineDash(dashes, count: dashes.count, phase: 0)
        }
        
        path.lineWidth = 0.5
        color.setStroke()
        path.stroke()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }
}
