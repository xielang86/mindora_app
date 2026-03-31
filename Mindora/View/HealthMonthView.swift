import UIKit

class HealthMonthView: UIView {
    
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
    private static func currentMonthDateString() -> String {
        let now = Date()
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: monthAgo)) – \(formatter.string(from: now))"
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
        label.text = L("health.week.avg_score") // Reusing key or create new
        label.font = UIFont.systemFont(ofSize: 11, weight: .light)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    // "70"
    private let scoreValueLabel: UILabel = {
        let label = UILabel()
        label.text = "--"
        label.font = UIFont.systemFont(ofSize: 45, weight: .semibold)
        label.textColor = UIColor(red: 28/255.0, green: 216/255.0, blue: 112/255.0, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    // "Optimal"
    private let scoreStateLabel: UILabel = {
        let label = UILabel()
        label.text = "--"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = UIColor(red: 28/255.0, green: 216/255.0, blue: 112/255.0, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    private let chartView = HealthMonthChartView()
    
    // Box 2: Sleep Trends
    private let insightsContainer: UIView = {
        let view = UIView()
        // Mocking gradient or background
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        view.layer.cornerRadius = 24
        view.layer.masksToBounds = true
        return view
    }()
    
    private let insightsBgImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleToFill
        iv.image = UIImage(named: "sleep_month_sleep_bg")
        return iv
    }()
    
    private let insightsIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = UIImage(named: "home_sleep_insights")
        return iv
    }()
    
    private let insightsTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.month.trends_title")
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        return label
    }()
    
    private let insightsSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.month.trends_subtitle")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(white: 0.7, alpha: 1.0)
        return label
    }()
    
    private let insightsBodyLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.month.trends_body")
        label.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()
    
    private let insightsDescLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.month.trends_desc")
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(white: 0.8, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()
    
    private let trendChartView = HealthMonthTrendsChartView()

    // Box 3: Onset Efficiency
    private let bestContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        view.layer.cornerRadius = 24
        view.layer.masksToBounds = true
        return view
    }()
    
    private let bestBgImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleToFill
        iv.image = UIImage(named: "sleep_week_onset_bg")
        return iv
    }()
    
    private let bestIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = UIImage(named: "home_best")
        return iv
    }()
    
    private let bestTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.month.best_title")
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        return label
    }()
    
    private let bestSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.month.best_subtitle")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(white: 0.7, alpha: 1.0)
        return label
    }()
    
    private let bestListLabel: UILabel = {
        let label = UILabel()
        label.text = "Sedona Desert Calm\nMaldives Drift Sleep\nCanadian Forest Solace"
        label.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        // Increase line height
        let attrString = NSMutableAttributedString(string: label.text!)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        style.alignment = .center
        attrString.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: attrString.length))
        label.attributedText = attrString
        return label
    }()

    private let bestContentLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.month.best_desc")
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(white: 0.8, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()
    
    // Expandable Cards
    // Group 1: Avg Heart Rate
    private let vitalsContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    // Group 2: Total Sleep
    private let trendsContainer: UIView = {
        let view = UIView()
        return view
    }()

    // Group 3: Avg Time In Bed
    private let efficiencyContainer: UIView = {
        let view = UIView()
        return view
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
        reloadData()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        reloadData()
    }
    
    // MARK: - Reload Data
    func reloadData() {
        let showMock = Constants.Config.showMockData
        if showMock {
            let mockLocal = HealthMockDataService.shared.monthLocalData()
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let startDay = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            let analysis = HealthAnalysisService.shared.mockMonthAnalysis(startDate: startDay, endDate: today)

            dateLabel.text = mockLocal.dateText
            scoreValueLabel.text = analysis.scoreSummary?.score.map(String.init) ?? "--"
            scoreStateLabel.text = analysis.scoreSummary?.label ?? "--"
            insightsBodyLabel.text = analysis.sleepTrends?.body ?? ""
            insightsDescLabel.text = analysis.sleepTrends?.description ?? ""
            if let scoreSeries = analysis.sleepTrends?.scoreSeries {
                trendChartView.setMockScoreSeries(scoreSeries)
            }
            if let scenarioList = analysis.onsetEfficiency?.scenarioList {
                setBestListText(scenarioList.joined(separator: "\n"))
            }
            bestContentLabel.text = analysis.onsetEfficiency?.description ?? ""
            chartView.setMockValues(mockLocal.chartValues)
        } else {
            dateLabel.text = HealthMonthView.currentMonthDateString()
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
                let today = calendar.startOfDay(for: Date())
                let startDay = calendar.date(byAdding: .day, value: -29, to: today) ?? today

                async let metricsTask = HealthDataManager.shared.fetchLatestMetrics(forceLive: true)
                async let aggregatesTask = HealthDataManager.shared.fetchSleepDailyAggregates(startingFrom: startDay, days: 30)
                async let analysisTask = HealthAnalysisService.shared.fetchMonthAnalysis(startDate: startDay, endDate: today)

                let metrics = try await metricsTask
                let aggregates = try await aggregatesTask
                let analysis = try? await analysisTask

                applyRealMonthData(metrics: metrics, aggregates: aggregates, analysis: analysis)
            } catch {
                scoreValueLabel.text = "--"
                scoreStateLabel.text = "--"
            }
        }
    }

    private func applyRealMonthData(metrics: HealthMetrics, aggregates: [HealthDataManager.SleepDailyAggregate], analysis: HealthAnalysisService.MonthAnalysis?) {
        let tracked = aggregates.filter(\.hasData)
        scoreValueLabel.text = analysis?.scoreSummary?.score.map(String.init) ?? "--"
        scoreStateLabel.text = analysis?.scoreSummary?.label ?? "--"

        chartView.setRealValues(aggregates.map { CGFloat(min(max($0.totalSleepHours, 0), 10)) })
        if let scoreSeries = analysis?.sleepTrends?.scoreSeries {
            trendChartView.setScoreSeries(scoreSeries)
        }

        let avgTotal = average(tracked.map(\.totalSleepHours)) ?? 0
        let avgAwake = average(tracked.map(\.awakeMinutes)) ?? 0
        let avgDeep = average(tracked.map(\.deepSleepHours)) ?? 0
        let deepRatio = avgTotal > 0 ? (avgDeep / avgTotal) * 100.0 : 0

        insightsBodyLabel.text = analysis?.sleepTrends?.body ?? String(format: "Average sleep %@ this month", formatHours(avgTotal))
        insightsDescLabel.text = analysis?.sleepTrends?.description ?? String(format: "Deep sleep averaged %.0f%% of total sleep, with %@ awake time per night.", deepRatio, formatMinutesText(avgAwake))

        if let scenarioList = analysis?.onsetEfficiency?.scenarioList, !scenarioList.isEmpty {
            setBestListText(scenarioList.joined(separator: "\n"))
        } else {
            setBestListText("\(tracked.count) tracked nights")
        }
        if let description = analysis?.onsetEfficiency?.description, !description.isEmpty {
            bestContentLabel.text = description
        } else if let avgOnset = average(tracked.compactMap(\.sleepOnsetMinutes)) {
            bestContentLabel.text = "Average sleep onset this month was \(formatMinutesText(avgOnset))."
        } else {
            bestContentLabel.text = "Sleep onset will appear here after Apple Health provides enough time in bed records."
        }

        rebuildContent(showMock: false, aggregates: tracked, metrics: metrics)
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
        scrollView.addSubview(contentView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.clipsToBounds = true
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
        
        contentView.addSubview(headerContainer)
        contentView.addSubview(contentStackView)
        
        setupHeader()
        
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            // Removed fixed height to allow dynamic sizing based on content
            // headerContainer.heightAnchor.constraint(equalToConstant: 320),
            
            contentStackView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -40),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -100)
        ])
        
        setupContent()
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
            chartView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 10),
            chartView.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -10),
            chartView.heightAnchor.constraint(equalToConstant: 250),
            // Pin bottom to headerContainer bottom to push contentStackView down
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
            mask.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 10),
            mask.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -20),
            mask.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 20),
            mask.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            prompt.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 47),
            prompt.centerXAnchor.constraint(equalTo: centerXAnchor),
            prompt.widthAnchor.constraint(equalToConstant: 214)
        ])
        
        // Ensure mask covers everything
        bringSubviewToFront(mask)
        bringSubviewToFront(prompt)
    }
    
    private func removeNonMemberOverlay() {
        overlayMaskView?.removeFromSuperview()
        overlayMaskView = nil
        subscriptionPromptView?.removeFromSuperview()
        subscriptionPromptView = nil
        clipsToBounds = true
        scrollView.clipsToBounds = true
    }
    
    private func setupContent() {
        setupInsights()
        setupBest()
        setupExpandableCards()
        
        contentStackView.addArrangedSubview(insightsContainer)
        contentStackView.addArrangedSubview(bestContainer)
        contentStackView.addArrangedSubview(vitalsContainer)
        contentStackView.addArrangedSubview(trendsContainer)
        contentStackView.addArrangedSubview(efficiencyContainer)
    }
    
    private func rebuildContent(showMock: Bool, aggregates: [HealthDataManager.SleepDailyAggregate] = [], metrics: HealthMetrics? = nil) {
        let mockLocal = HealthMockDataService.shared.monthLocalData()
        insightsContainer.isHidden = false
        bestContainer.isHidden = false
        vitalsContainer.isHidden = false
        trendsContainer.isHidden = false
        efficiencyContainer.isHidden = false

        let trackedDays = aggregates.count
        let totalSleep = aggregates.map(\.totalSleepHours).reduce(0, +)
        let avgAwake = average(aggregates.map(\.awakeMinutes)) ?? 0
        let avgRem = average(aggregates.map(\.remSleepHours)) ?? 0
        let avgCore = average(aggregates.map(\.coreSleepHours)) ?? 0
        let avgDeep = average(aggregates.map(\.deepSleepHours)) ?? 0
        let avgTotal = average(aggregates.map(\.totalSleepHours)) ?? 0
        let avgOnset = average(aggregates.compactMap(\.sleepOnsetMinutes))
        let avgTimeInBed = average(aggregates.map(\.timeInBedHours)) ?? 0
        let heartRateValue = metrics?.heartRate.map { "\(Int($0.value.rounded()))bpm" } ?? "--"
        let respiratoryValue = metrics?.respiratoryRate.map { "\(Int($0.value.rounded()))bpm" } ?? "--"
        let restingHeartRateValue = metrics?.restingHeartRate.map { "\(Int($0.value.rounded()))bpm" } ?? "--"
        let wristTemperatureMetric = metrics?.sleepingWristTemperature ?? metrics?.bodyTemperature
        let wristTemperatureValue = wristTemperatureMetric.map { String(format: "%.1f°C", $0.value) } ?? "--"
        let vitalsDetailRows: [(String, String, String?)] = showMock ? [
            (L("health.week.respiratory_rate"), mockLocal.respiratoryRangeText, nil),
            (L("health.week.avg_heart_rate"), mockLocal.averageHeartRateRangeText, nil),
            (L("health.week.avg_skin_temp"), mockLocal.skinTemperatureDeltaText, L("health.week.metric.from_baseline"))
        ] : [
            (L("health.week.respiratory_rate"), respiratoryValue, nil),
            (L("health.week.avg_heart_rate"), restingHeartRateValue, nil),
            (L("health.week.avg_skin_temp"), wristTemperatureValue, L("health.week.metric.from_baseline"))
        ]

        let vitalsCard = WeekExpandableCard(
            icon: "sleep_week_heartrate",
            title: L("health.month.avg_heart_rate"),
            value: showMock ? mockLocal.heartRateText : heartRateValue,
            detailRows: vitalsDetailRows
        )
        configureCard(vitalsCard, in: vitalsContainer)

        let trendsCard = WeekExpandableCard(
            icon: "sleep_week_sleep",
            title: L("health.month.total_sleep"),
            value: showMock ? mockLocal.totalSleepText : formatHours(totalSleep),
            detailRows: showMock ? [
                (L("health.week.avg_awake"), mockLocal.averageAwakeText, nil),
                (L("health.week.avg_rem"), mockLocal.averageRemText, nil),
                (L("health.week.avg_core"), mockLocal.averageCoreText, nil),
                (L("health.week.avg_deep"), mockLocal.averageDeepText, nil)
            ] : [
                (L("health.week.avg_awake"), formatMinutesText(avgAwake), nil),
                (L("health.week.avg_rem"), formatHours(avgRem), nil),
                (L("health.week.avg_core"), formatHours(avgCore), nil),
                (L("health.week.avg_deep"), formatHours(avgDeep), nil)
            ]
        )
        configureCard(trendsCard, in: trendsContainer)

        let efficiencyCard = WeekExpandableCard(
            icon: "sleep_week_timeinbed",
            title: L("health.week.header.time_in_bed"),
            value: showMock ? mockLocal.timeInBedText : formatHours(avgTimeInBed),
            detailRows: showMock ? [
                (L("health.month.days_tracked"), mockLocal.trackedDaysText, nil),
                (L("health.week.avg_total"), mockLocal.averageTotalText, nil),
                (L("health.week.avg_onset"), mockLocal.averageOnsetText, nil)
            ] : [
                (L("health.month.days_tracked"), "\(trackedDays)/30days", nil),
                (L("health.week.avg_total"), formatHours(avgTotal), nil),
                (L("health.week.avg_onset"), avgOnset.map(formatMinutesText) ?? "--", nil)
            ]
        )
        configureCard(efficiencyCard, in: efficiencyContainer)
    }

    private func configureCard(_ card: UIView, in container: UIView) {
        container.subviews.forEach { $0.removeFromSuperview() }
        container.addSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.pinToSuperview()
    }
    
    private func setupInsights() {
        insightsContainer.addSubview(insightsBgImageView)
        insightsContainer.addSubview(insightsIcon)
        insightsContainer.addSubview(insightsTitleLabel)
        insightsContainer.addSubview(insightsSubtitleLabel)
        insightsContainer.addSubview(insightsBodyLabel)
        insightsContainer.addSubview(trendChartView)
        insightsContainer.addSubview(insightsDescLabel)
        
        var imgView = UIImageView(image: UIImage(named: "icon_arrow_right"))
        imgView.contentMode = .scaleAspectFit
        insightsContainer.addSubview(imgView)
        
        insightsBgImageView.translatesAutoresizingMaskIntoConstraints = false
        insightsIcon.translatesAutoresizingMaskIntoConstraints = false
        insightsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        insightsSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        insightsBodyLabel.translatesAutoresizingMaskIntoConstraints = false
        trendChartView.translatesAutoresizingMaskIntoConstraints = false
        insightsDescLabel.translatesAutoresizingMaskIntoConstraints = false
        imgView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            insightsBgImageView.topAnchor.constraint(equalTo: insightsContainer.topAnchor),
            insightsBgImageView.leadingAnchor.constraint(equalTo: insightsContainer.leadingAnchor),
            insightsBgImageView.trailingAnchor.constraint(equalTo: insightsContainer.trailingAnchor),
            insightsBgImageView.bottomAnchor.constraint(equalTo: insightsContainer.bottomAnchor),
            
            insightsIcon.leadingAnchor.constraint(equalTo: insightsContainer.leadingAnchor, constant: 22),
            insightsIcon.topAnchor.constraint(equalTo: insightsContainer.topAnchor, constant: 20),
            insightsIcon.widthAnchor.constraint(equalToConstant: 32),
            insightsIcon.heightAnchor.constraint(equalToConstant: 32),
            
            insightsTitleLabel.leadingAnchor.constraint(equalTo: insightsIcon.trailingAnchor, constant: 12),
            insightsTitleLabel.centerYAnchor.constraint(equalTo: insightsIcon.centerYAnchor, constant: -8),
            insightsTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: imgView.leadingAnchor, constant: -10),
            
            insightsSubtitleLabel.leadingAnchor.constraint(equalTo: insightsTitleLabel.leadingAnchor),
            insightsSubtitleLabel.topAnchor.constraint(equalTo: insightsTitleLabel.bottomAnchor, constant: 2),
            insightsSubtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: imgView.leadingAnchor, constant: -10),
            
            imgView.centerYAnchor.constraint(equalTo: insightsIcon.centerYAnchor),
            imgView.trailingAnchor.constraint(equalTo: insightsContainer.trailingAnchor, constant: -22),
            imgView.widthAnchor.constraint(equalToConstant: 16),
            imgView.heightAnchor.constraint(equalToConstant: 16),

            insightsBodyLabel.topAnchor.constraint(equalTo: insightsIcon.bottomAnchor, constant: 16),
            insightsBodyLabel.leadingAnchor.constraint(equalTo: insightsTitleLabel.leadingAnchor),
            insightsBodyLabel.trailingAnchor.constraint(equalTo: insightsContainer.trailingAnchor, constant: -22),
            
            trendChartView.topAnchor.constraint(equalTo: insightsBodyLabel.bottomAnchor, constant: 20),
            trendChartView.leadingAnchor.constraint(equalTo: insightsContainer.leadingAnchor, constant: 0),
            trendChartView.trailingAnchor.constraint(equalTo: insightsContainer.trailingAnchor, constant: 0),
            trendChartView.heightAnchor.constraint(equalToConstant: 172),
            
            insightsDescLabel.topAnchor.constraint(equalTo: trendChartView.bottomAnchor, constant: 16),
            insightsDescLabel.leadingAnchor.constraint(equalTo: insightsIcon.leadingAnchor),
            insightsDescLabel.trailingAnchor.constraint(equalTo: insightsContainer.trailingAnchor, constant: -22),
            insightsDescLabel.bottomAnchor.constraint(equalTo: insightsContainer.bottomAnchor, constant: -30)
        ])
    }
    
    private func setupBest() {
        bestContainer.addSubview(bestBgImageView)
        bestContainer.addSubview(bestIcon)
        bestContainer.addSubview(bestTitleLabel)
        bestContainer.addSubview(bestSubtitleLabel)
        bestContainer.addSubview(bestListLabel)
        bestContainer.addSubview(bestContentLabel)
        
        var imgView = UIImageView(image: UIImage(named: "icon_arrow_right"))
        imgView.contentMode = .scaleAspectFit
        bestContainer.addSubview(imgView)
        
        bestBgImageView.translatesAutoresizingMaskIntoConstraints = false
        bestIcon.translatesAutoresizingMaskIntoConstraints = false
        bestTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        bestSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        bestListLabel.translatesAutoresizingMaskIntoConstraints = false
        bestContentLabel.translatesAutoresizingMaskIntoConstraints = false
        imgView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            bestBgImageView.topAnchor.constraint(equalTo: bestContainer.topAnchor),
            bestBgImageView.leadingAnchor.constraint(equalTo: bestContainer.leadingAnchor),
            bestBgImageView.trailingAnchor.constraint(equalTo: bestContainer.trailingAnchor),
            bestBgImageView.bottomAnchor.constraint(equalTo: bestContainer.bottomAnchor),
            
            bestIcon.leadingAnchor.constraint(equalTo: bestContainer.leadingAnchor, constant: 22),
            bestIcon.topAnchor.constraint(equalTo: bestContainer.topAnchor, constant: 20),
            bestIcon.widthAnchor.constraint(equalToConstant: 32),
            bestIcon.heightAnchor.constraint(equalToConstant: 32),
            
            bestTitleLabel.leadingAnchor.constraint(equalTo: bestIcon.trailingAnchor, constant: 12),
            bestTitleLabel.centerYAnchor.constraint(equalTo: bestIcon.centerYAnchor, constant: -8),
            bestTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: imgView.leadingAnchor, constant: -10),
            
            bestSubtitleLabel.leadingAnchor.constraint(equalTo: bestTitleLabel.leadingAnchor),
            bestSubtitleLabel.topAnchor.constraint(equalTo: bestTitleLabel.bottomAnchor, constant: 2),
            bestSubtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: imgView.leadingAnchor, constant: -10),
            
            imgView.centerYAnchor.constraint(equalTo: bestIcon.centerYAnchor),
            imgView.trailingAnchor.constraint(equalTo: bestContainer.trailingAnchor, constant: -22),
            imgView.widthAnchor.constraint(equalToConstant: 16),
            imgView.heightAnchor.constraint(equalToConstant: 16),
            
            bestListLabel.topAnchor.constraint(equalTo: bestIcon.bottomAnchor, constant: 16),
            bestListLabel.centerXAnchor.constraint(equalTo: bestContainer.centerXAnchor),
            bestListLabel.leadingAnchor.constraint(greaterThanOrEqualTo: bestContainer.leadingAnchor, constant: 20),
            bestListLabel.trailingAnchor.constraint(lessThanOrEqualTo: bestContainer.trailingAnchor, constant: -22),
            
            bestContentLabel.topAnchor.constraint(equalTo: bestListLabel.bottomAnchor, constant: 16),
            bestContentLabel.leadingAnchor.constraint(equalTo: bestIcon.leadingAnchor),
            bestContentLabel.trailingAnchor.constraint(equalTo: bestContainer.trailingAnchor, constant: -22),
            bestContentLabel.bottomAnchor.constraint(equalTo: bestContainer.bottomAnchor, constant: -30)
        ])
    }

    private func setBestListText(_ text: String) {
        let attrString = NSMutableAttributedString(string: text)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        style.alignment = .center
        attrString.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: attrString.length))
        bestListLabel.attributedText = attrString
    }
    
    private func setupExpandableCards() {
        // Card 1
        let card1 = WeekExpandableCard(
            icon: "sleep_week_heartrate",
            title: L("health.month.avg_heart_rate"),
            value: "92bpm",
            detailRows: [
                (L("health.week.respiratory_rate"), "9-27bpm", nil),
                (L("health.week.avg_heart_rate"), "49-84bpm", nil),
                (L("health.week.avg_skin_temp"), "+0.06°C", L("health.week.metric.from_baseline"))
            ]
        )
        vitalsContainer.addSubview(card1)
        card1.translatesAutoresizingMaskIntoConstraints = false
        card1.pinToSuperview()
        
        // Card 2
        let card2 = WeekExpandableCard(
            icon: "sleep_week_sleep",
            title: L("health.month.total_sleep"),
            value: "240hrs",
            detailRows: [
                (L("health.week.avg_awake"), "18min", nil),
                (L("health.week.avg_rem"), "1hr 50min", nil),
                (L("health.week.avg_core"), "4hr 3min", nil),
                (L("health.week.avg_deep"), "51min", nil)
            ]
        )
        trendsContainer.addSubview(card2)
        card2.translatesAutoresizingMaskIntoConstraints = false
        card2.pinToSuperview()
        
        // Card 3
        let card3 = WeekExpandableCard(
            icon: "sleep_week_timeinbed",
            title: L("health.week.header.time_in_bed"),
            value: "7hr 45min",
            detailRows: [
                (L("health.month.days_tracked"), "15/30days", nil),
                (L("health.week.avg_total"), "7hr 2min", nil),
                (L("health.week.avg_onset"), "5–10min", nil)
            ]
        )
        efficiencyContainer.addSubview(card3)
        card3.translatesAutoresizingMaskIntoConstraints = false
        card3.pinToSuperview()
    }
}

// MARK: - Components
class HealthMonthChartView: UIView {
    
    // UI Constants
    private let chartBoxHeight: CGFloat = 151
    private let chartBoxLeading: CGFloat = 16.0
    private let chartBoxTrailing: CGFloat = 24.0
    private let barWidth: CGFloat = 6.0
    
    // Data
    private struct BarData {
        let value: CGFloat // 0-10
        let label: String
        let dateString: String
    }
    
    private var items: [BarData] = []
    private var realValues: [CGFloat] = []
    
    private var chartContainer: UIView!
    private var tooltipView: UIView?
    private var dotView: UIView?
    private let connectorLayer = CAShapeLayer()
    
    // Track selected index
    private var selectedIndex: Int?

    private static func weekdayText(for text: String) -> String? {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "MMM d, yyyy"

        guard let date = parser.date(from: text) else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var showMockData: Bool = true {
        didSet {
            buildItems()
            rebuildChart()
        }
    }

    func setRealValues(_ values: [CGFloat]) {
        realValues = values
        if !showMockData {
            buildItems()
            rebuildChart()
        }
    }
    
    private var mockValues: [CGFloat] = [
        7.8, 6.2, 5.3, 4.4, 6.7, 3.2, 7.2, 3.5, 4.2, 7.8,
        5.2, 7.1, 5.5, 2.7, 4.0, 6.2, 7.5, 8.0, 6.5, 5.5,
        4.8, 6.0, 7.2, 8.5, 7.0, 6.2, 5.8, 4.5, 6.8, 7.4
    ]

    func setMockValues(_ values: [CGFloat]) {
        guard values.count == 30 else { return }
        mockValues = values
        if showMockData {
            buildItems()
            rebuildChart()
        }
    }
    
    private func buildItems() {
        items.removeAll()
        let now = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, yyyy"
        
        let values: [CGFloat]
        if showMockData {
            values = mockValues
        } else if realValues.count == 30 {
            values = realValues
        } else {
            values = Array(repeating: 0.0, count: 30)
        }
        
        for (i, val) in values.enumerated() {
            let date = calendar.date(byAdding: .day, value: -(29 - i), to: now)!
            let day = calendar.component(.day, from: date)
            let showLabel = (i) % 4 == 0
            let labelText = showLabel ? String(format: "%02d", day) : ""
            items.append(BarData(value: val, label: labelText, dateString: formatter.string(from: date)))
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        buildItems()
        
        backgroundColor = .clear
        
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
            path.move(to: CGPoint(x: tooltipFrame.minX, y: localTooltipMidY))
            path.addLine(to: CGPoint(x: dotFrame.midX, y: localTooltipMidY))
        } else {
            // Tooltip is on the Left
            path.move(to: CGPoint(x: tooltipFrame.maxX, y: localTooltipMidY))
            path.addLine(to: CGPoint(x: dotFrame.midX, y: localTooltipMidY))
        }
        
        // Vertical Line to Dot Center
        path.addLine(to: CGPoint(x: dotFrame.midX, y: dotFrame.midY))
        
        connectorLayer.path = path.cgPath
    }
    
    private func setupChart() {
        // 1. Chart Container Box
        chartContainer = UIView()
        chartContainer.backgroundColor = .clear
        chartContainer.layer.borderWidth = 0.5
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
            let yOffset = round(chartBoxHeight * normalize)
            
            // Reusing ChartGuideLineView from WeekView context
            let guideLine = ChartGuideLineView()
            guideLine.color = UIColor(red: 146/255, green: 146/255, blue: 146/255, alpha: 0.6)
            guideLine.isDashed = (val == 6)
            guideLine.translatesAutoresizingMaskIntoConstraints = false
            chartContainer.addSubview(guideLine)
            
            NSLayoutConstraint.activate([
                guideLine.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor),
                guideLine.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor),
                guideLine.heightAnchor.constraint(equalToConstant: 1),
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
                label.trailingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: -4),
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
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor, constant: -8),
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
            // Reusing GradientBarView from WeekView context
            let barView = GradientBarView(colors: getColors(for: item.value))
            barView.layer.cornerRadius = barWidth / 2.0
            barView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            barView.tag = index
            
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
            
            // X Label - only if not empty
            if !item.label.isEmpty {
                let xLabel = UILabel()
                xLabel.text = item.label
                xLabel.font = UIFont.systemFont(ofSize: 10, weight: .light)
                xLabel.textColor = UIColor(white: 1.0, alpha: 0.8)
                xLabel.textAlignment = .center
                addSubview(xLabel)
                xLabel.translatesAutoresizingMaskIntoConstraints = false
                
                NSLayoutConstraint.activate([
                    xLabel.topAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: 8),
                    xLabel.centerXAnchor.constraint(equalTo: column.centerXAnchor)
                ])
            }
        }
    }
    
    private func getColors(for value: CGFloat) -> [CGColor] {
        if value >= 7.0 {
            return [UIColor(red: 28/255, green: 219/255, blue: 113/255, alpha: 1).cgColor,
                    UIColor(red: 33/255, green: 149/255, blue: 83/255, alpha: 1).cgColor]
        } else if value >= 5.0 {
             return [UIColor(red: 248/255, green: 173/255, blue: 52/255, alpha: 1).cgColor,
                     UIColor(red: 193/255, green: 133/255, blue: 37/255, alpha: 1).cgColor]
        } else {
             return [UIColor(red: 243/255, green: 86/255, blue: 117/255, alpha: 1).cgColor,
                     UIColor(red: 178/255, green: 66/255, blue: 88/255, alpha: 1).cgColor]
        }
    }
    
    @objc private func barTapped(_ sender: Any) {
        if let tap = sender as? UITapGestureRecognizer, let column = tap.view, let barView = column.subviews.first(where: { $0 is GradientBarView }) {
            let index = barView.tag
            
            if selectedIndex == index {
                hideTooltip(animated: true)
            } else {
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
            self.connectorLayer.opacity = 1
            
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
    
    private func showTooltip(for index: Int, sourceView: UIView, animated: Bool = true) {
        selectedIndex = index
        guard index < items.count else { return }
        let item = items[index]
        
        // 1. Tooltip Box
        let tooltip = UIView()
        tooltip.backgroundColor = UIColor(red: 87/255, green: 87/255, blue: 87/255, alpha: 0.7)
        tooltip.layer.cornerRadius = 3
        tooltip.layer.borderWidth = 1
        tooltip.layer.borderColor = UIColor.white.cgColor // Match week style
        
        let initialAlpha: CGFloat = animated ? 0.0 : 1.0
        tooltip.alpha = initialAlpha
        
        addSubview(tooltip)
        tooltip.translatesAutoresizingMaskIntoConstraints = false
        
        // Content
        let titleLabel = UILabel()
        let hours = Int(item.value)
        let minutes = Int((item.value - CGFloat(hours)) * 60)
        titleLabel.text = String(format: "%dhr %dm", hours, minutes)
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .left
        
        let dateSubtitle = UILabel()
        let dayName = Self.weekdayText(for: item.dateString)
        dateSubtitle.text = dayName.map { "\($0), \(item.dateString)" } ?? item.dateString
        dateSubtitle.textColor = .lightGray
        dateSubtitle.font = UIFont.systemFont(ofSize: 10)
        dateSubtitle.textAlignment = .left
        
        let labelStack = UIStackView(arrangedSubviews: [titleLabel, dateSubtitle])
        labelStack.axis = .vertical
        labelStack.spacing = 2
        labelStack.alignment = .leading
        
        tooltip.addSubview(labelStack)
        labelStack.translatesAutoresizingMaskIntoConstraints = false
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
        // Check index
        if index < 15 {
            // Right
             NSLayoutConstraint.activate([
                tooltip.bottomAnchor.constraint(equalTo: dot.centerYAnchor),
                tooltip.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10)
            ])
        } else {
            // Left
            NSLayoutConstraint.activate([
                tooltip.bottomAnchor.constraint(equalTo: dot.centerYAnchor),
                tooltip.trailingAnchor.constraint(equalTo: dot.leadingAnchor, constant: -10)
            ])
        }
        
        self.tooltipView = tooltip
        self.dotView = dot
        self.connectorLayer.opacity = Float(initialAlpha)
        
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

class HealthMonthTrendsChartView: UIView {
    // 月度逐日评分趋势图
    
    // UI Constants - 设计稿高度172pt，左边距22pt (Label start)，右边距30pt
    private let chartHeight: CGFloat = 130  // 减去X轴标签高度
    private let labelHeight: CGFloat = 24
    // Increase leading to 46 so that Y-axis labels (width 20 + gap 4) start at 22pt from edge
    private let chartLeading: CGFloat = 56
    private let chartTrailing: CGFloat = 30
    
    // Data - 0-100 score scale
    struct DataPoint {
        let label: String
        let fullDate: String
        let value: CGFloat // 0-100 scale
    }

    private static func xAxisLabel(for date: Date, index: Int, total: Int) -> String {
        let day = Calendar.current.component(.day, from: date)
        if index == 0 || index == total - 1 || index % 5 == 0 {
            return "\(day)"
        }
        return ""
    }

    private static func tooltipDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private static func parsedDate(from text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text)
    }
    
    private var dataPoints: [DataPoint] = []
    private weak var xLabelStack: UIStackView?

    func setMockScoreSeries(_ values: [HealthAnalysisService.MonthAnalysis.SleepTrends.ScorePoint]) {
        setScoreSeries(values)
    }

    func setScoreSeries(_ values: [HealthAnalysisService.MonthAnalysis.SleepTrends.ScorePoint]) {
        guard !values.isEmpty else {
            dataPoints = []
            renderXLabels()
            tooltipView?.removeFromSuperview()
            dotView?.removeFromSuperview()
            tooltipView = nil
            dotView = nil
            selectedIndex = nil
            connectorLayer.path = nil
            setNeedsLayout()
            return
        }
        dataPoints = values.enumerated().map { index, point in
            let date = Self.parsedDate(from: point.date)
            return DataPoint(
                label: date.map { Self.xAxisLabel(for: $0, index: index, total: values.count) } ?? "",
                fullDate: date.map(Self.tooltipDateText(for:)) ?? point.date,
                value: CGFloat(point.score)
            )
        }
        renderXLabels()
        tooltipView?.removeFromSuperview()
        dotView?.removeFromSuperview()
        tooltipView = nil
        dotView = nil
        selectedIndex = nil
        connectorLayer.path = nil
        setNeedsLayout()
    }
    
    private var selectedIndex: Int? = nil // Default: no selection
    
    private var chartContainer: UIView!
    private var tooltipView: UIView?
    private var dotView: UIView?
    private let connectorLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCurve()
    }
    
    private func setup() {
        // Chart Container with margins and border (matching HealthMonthChartView)
        chartContainer = UIView()
        chartContainer.backgroundColor = .clear
        chartContainer.layer.borderWidth = 0.5
        chartContainer.layer.borderColor = UIColor(red: 146/255, green: 146/255, blue: 146/255, alpha: 0.6).cgColor
        addSubview(chartContainer)
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: chartLeading),
            chartContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -chartTrailing),
            chartContainer.topAnchor.constraint(equalTo: topAnchor),
            chartContainer.heightAnchor.constraint(equalToConstant: chartHeight)
        ])
        
        // Grid Lines
        setupGridLines()
        
        // Connector Layer
        connectorLayer.strokeColor = UIColor.white.cgColor
        connectorLayer.lineWidth = 1
        connectorLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(connectorLayer)
        
        // X Labels
        setupXLabels()
        
        // Add tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }
    
    private func setupGridLines() {
        // Grid lines at 0, 2, 4, 6, 8, 10 (matching HealthMonthChartView)
        let yValues: [Int] = [0, 20, 40, 60, 80, 100]
        for val in yValues {
            let yOffset = chartHeight * (CGFloat(val) / 100.0)
            
            // Use ChartGuideLineView to match HealthMonthChartView style
            let guideLine = ChartGuideLineView()
            guideLine.color = UIColor(red: 146/255, green: 146/255, blue: 146/255, alpha: 0.6)
            guideLine.isDashed = (val == 60)
            guideLine.translatesAutoresizingMaskIntoConstraints = false
            chartContainer.addSubview(guideLine)
            
            NSLayoutConstraint.activate([
                guideLine.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor),
                guideLine.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor),
                guideLine.heightAnchor.constraint(equalToConstant: 1),
                guideLine.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: -yOffset)
            ])
            
            // Y Label (matching HealthMonthChartView)
            let label = UILabel()
            label.text = "\(val)"
            label.font = UIFont.systemFont(ofSize: 11, weight: .light)
            label.textColor = UIColor(white: 1.0, alpha: 0.8)
            label.textAlignment = .center
            addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: -4),
                label.centerYAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: -yOffset),
                label.widthAnchor.constraint(equalToConstant: 28)
            ])
        }
    }
    
    private func setupXLabels() {
        let labelContainer = UIView()
        addSubview(labelContainer)
        labelContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            labelContainer.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor),
            labelContainer.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor),
            labelContainer.topAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: 8),
            labelContainer.heightAnchor.constraint(equalToConstant: labelHeight)
        ])
        
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        labelContainer.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: labelContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: labelContainer.trailingAnchor),
            stack.topAnchor.constraint(equalTo: labelContainer.topAnchor),
            stack.bottomAnchor.constraint(equalTo: labelContainer.bottomAnchor)
        ])

        xLabelStack = stack
        renderXLabels()
    }

    private func renderXLabels() {
        guard let stack = xLabelStack else { return }
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for point in dataPoints {
            let label = UILabel()
            label.text = point.label
            label.font = UIFont.systemFont(ofSize: 11, weight: .regular)
            label.textColor = UIColor(white: 0.6, alpha: 1.0)
            label.textAlignment = .center
            stack.addArrangedSubview(label)
        }
    }
    
    private func updateCurve() {
        guard chartContainer.bounds.width > 0, dataPoints.count > 1 else { return }
        
        // Remove old gradient layers
        chartContainer.layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
        
        let width = chartContainer.bounds.width
        let height = chartContainer.bounds.height
        let count = dataPoints.count
        let spacing = width / CGFloat(count - 1)
        
        // Build points
        var points: [CGPoint] = []
        for (i, data) in dataPoints.enumerated() {
            let x = CGFloat(i) * spacing
            let y = height - (height * data.value / 100.0)
            points.append(CGPoint(x: x, y: y))
        }
        
        // Create smooth curve path for the entire curve
        let path = UIBezierPath()
        path.move(to: points[0])
        
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let midX = (prev.x + curr.x) / 2
            
            path.addCurve(to: curr, controlPoint1: CGPoint(x: midX, y: prev.y), controlPoint2: CGPoint(x: midX, y: curr.y))
        }
        
        // Create a single gradient layer for the entire curve with smooth color transitions
        // Colors based on x-position matching data values
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = chartContainer.bounds
        
        // Build gradient colors and locations based on data values
        var gradientColors: [CGColor] = []
        var locations: [NSNumber] = []
        
        for (i, data) in dataPoints.enumerated() {
            let location = CGFloat(i) / CGFloat(count - 1)
            locations.append(NSNumber(value: Float(location)))
            
            // Get color based on value
            let color = getSingleColor(for: data.value)
            gradientColors.append(color)
        }
        
        gradientLayer.colors = gradientColors
        gradientLayer.locations = locations
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        
        // Use the curve path as mask
        let shapeMask = CAShapeLayer()
        shapeMask.path = path.cgPath
        shapeMask.strokeColor = UIColor.white.cgColor
        shapeMask.fillColor = UIColor.clear.cgColor
        shapeMask.lineWidth = 2.5
        shapeMask.lineCap = .round
        shapeMask.lineJoin = .round
        
        gradientLayer.mask = shapeMask
        chartContainer.layer.addSublayer(gradientLayer)
    }
    
    // Get single color for a value (used for smooth gradient)
    private func getSingleColor(for value: CGFloat) -> CGColor {
        if value >= 85.0 {
            // Green
            return UIColor(red: 28/255, green: 219/255, blue: 113/255, alpha: 1).cgColor
        } else if value >= 70.0 {
            // Orange/Yellow
            return UIColor(red: 248/255, green: 173/255, blue: 52/255, alpha: 1).cgColor
        } else {
            // Red/Pink
            return UIColor(red: 243/255, green: 86/255, blue: 117/255, alpha: 1).cgColor
        }
    }
    
    private func updateConnectorLine() {
        guard let tooltip = tooltipView, let dot = dotView else {
            connectorLayer.path = nil
            return
        }
        
        let tooltipFrame = tooltip.convert(tooltip.bounds, to: self)
        let dotFrame = dot.convert(dot.bounds, to: self)
        
        if tooltipFrame.isEmpty || dotFrame.isEmpty { return }
        
        let path = UIBezierPath()
        let localTooltipMidY = tooltipFrame.midY
        
        // 根据 tooltip 位置决定连接线方向 (matching HealthMonthChartView style)
        if tooltipFrame.minX > dotFrame.maxX {
            // Tooltip is on the Right
            path.move(to: CGPoint(x: tooltipFrame.minX, y: localTooltipMidY))
            path.addLine(to: CGPoint(x: dotFrame.midX, y: localTooltipMidY))
        } else {
            // Tooltip is on the Left
            path.move(to: CGPoint(x: tooltipFrame.maxX, y: localTooltipMidY))
            path.addLine(to: CGPoint(x: dotFrame.midX, y: localTooltipMidY))
        }
        
        // Vertical Line to Dot Center
        path.addLine(to: CGPoint(x: dotFrame.midX, y: dotFrame.midY))
        
        connectorLayer.path = path.cgPath
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: chartContainer)
        let width = chartContainer.bounds.width
        let count = dataPoints.count
        let spacing = width / CGFloat(count - 1)
        
        // Find closest point
        var closestIndex = 0
        var minDistance: CGFloat = .greatestFiniteMagnitude
        
        for i in 0..<count {
            let x = CGFloat(i) * spacing
            let distance = abs(location.x - x)
            if distance < minDistance {
                minDistance = distance
                closestIndex = i
            }
        }
        
        // Toggle: if same index clicked, hide; otherwise show new
        if selectedIndex == closestIndex {
            hideTooltip(animated: true)
        } else {
            hideTooltip(animated: false)
            showTooltip(for: closestIndex, animated: true)
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
            self.connectorLayer.opacity = 1
            
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
    
    private func showTooltip(for index: Int, animated: Bool = true) {
        selectedIndex = index
        guard chartContainer.bounds.width > 0 else { return }
        
        let width = chartContainer.bounds.width
        let height = chartContainer.bounds.height
        let count = dataPoints.count
        let spacing = width / CGFloat(count - 1)
        
        let data = dataPoints[index]
        let x = CGFloat(index) * spacing
        let y = height - (height * data.value / 100.0)
        
        let initialAlpha: CGFloat = animated ? 0.0 : 1.0
        
        // ===== Dot - 完全照搬 HealthMonthChartView 样式 =====
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
        
        chartContainer.addSubview(dot)
        dot.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 6.5),
            dot.heightAnchor.constraint(equalToConstant: 6.5),
            dot.centerXAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: x),
            dot.centerYAnchor.constraint(equalTo: chartContainer.topAnchor, constant: y)
        ])
        dotView = dot
        
        // ===== Tooltip - 完全照搬 HealthMonthChartView 样式 =====
        let tooltip = UIView()
        tooltip.backgroundColor = UIColor(red: 87/255, green: 87/255, blue: 87/255, alpha: 0.7)
        tooltip.layer.cornerRadius = 3
        tooltip.layer.borderWidth = 1
        tooltip.layer.borderColor = UIColor.white.cgColor
        tooltip.alpha = initialAlpha
        
        addSubview(tooltip)
        tooltip.translatesAutoresizingMaskIntoConstraints = false
        
        // Content - 显示分数值和月份
        let titleLabel = UILabel()
        titleLabel.text = "\(Int(data.value))"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .left
        
        let dateSubtitle = UILabel()
        dateSubtitle.text = data.fullDate
        dateSubtitle.textColor = .lightGray
        dateSubtitle.font = UIFont.systemFont(ofSize: 10)
        dateSubtitle.textAlignment = .left
        
        let labelStack = UIStackView(arrangedSubviews: [titleLabel, dateSubtitle])
        labelStack.axis = .vertical
        labelStack.spacing = 2
        labelStack.alignment = .leading
        
        tooltip.addSubview(labelStack)
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            labelStack.topAnchor.constraint(equalTo: tooltip.topAnchor, constant: 6),
            labelStack.leadingAnchor.constraint(equalTo: tooltip.leadingAnchor, constant: 6),
            labelStack.trailingAnchor.constraint(equalTo: tooltip.trailingAnchor, constant: -6),
            labelStack.bottomAnchor.constraint(equalTo: tooltip.bottomAnchor, constant: -6)
        ])
        
        // Position tooltip - 根据位置决定左侧还是右侧，底部与圆点中心对齐
        if index < max(1, count / 2) {
            // Right side
            NSLayoutConstraint.activate([
                tooltip.bottomAnchor.constraint(equalTo: chartContainer.topAnchor, constant: y),
                tooltip.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: x + 12)
            ])
        } else {
            // Left side
            NSLayoutConstraint.activate([
                tooltip.bottomAnchor.constraint(equalTo: chartContainer.topAnchor, constant: y),
                tooltip.trailingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: x - 12)
            ])
        }
        
        tooltipView = tooltip
        connectorLayer.opacity = Float(initialAlpha)
        
        setNeedsLayout()
        layoutIfNeeded()
        
        // Update connector line
        updateConnectorLine()
        
        if animated {
            UIView.animate(withDuration: 0.25) {
                tooltip.alpha = 1.0
                dot.alpha = 1.0
                self.connectorLayer.opacity = 1.0
            }
        }
    }
}

extension UIView {
    func pinToSuperview() {
        guard let superview = superview else { return }
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview.topAnchor),
            leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor)
        ])
    }
}

