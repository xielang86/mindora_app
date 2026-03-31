import UIKit

class HealthDayView: UIView {
    
    // MARK: - Colors
    private struct Colors {
        static let colorAwake = UIColor(red: 183/255.0, green: 220/255.0, blue: 247/255.0, alpha: 1.0) // #B7DCF7
        static let colorREM = UIColor(red: 123/255.0, green: 171/255.0, blue: 206/255.0, alpha: 1.0) // #7BABCE
        static let colorCore = UIColor(red: 69/255.0, green: 126/255.0, blue: 168/255.0, alpha: 1.0) // #457EA8
        static let colorDeep = UIColor(red: 15/255.0, green: 68/255.0, blue: 107/255.0, alpha: 1.0)   // #0F446B
    }

    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        return scrollView
    }()
    
    private let contentView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        return stackView
    }()
    
    // MARK: - Summary Section (Duration, Date, Efficiency, Graph)
    private let summarySectionView = UIView()
    
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.text = "--"
        // text_6: 36px/2 = 18pt SemiBold
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.text = "--"
        // text_7: 22px/2 = 11pt Light
        label.font = UIFont.systemFont(ofSize: 11, weight: .light)
        label.textColor = .white
        return label
    }()
    
    private let efficiencyValueLabel: UILabel = {
        let label = UILabel()
        label.text = "--"
        // text_8: 90px/2 = 45pt SemiBold
        label.font = UIFont.systemFont(ofSize: 45, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .right
        return label
    }()
    
    private let efficiencyTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("health.sleep.efficiency")
        // text_9: 22px/2 = 11pt Light
        label.font = UIFont.systemFont(ofSize: 11, weight: .light)
        label.textColor = .white
        label.textAlignment = .right
        return label
    }()
    
    // Graph
    private let graphView: DaySleepGraphView = {
        let view = DaySleepGraphView()
        view.backgroundColor = .clear
        return view
    }()
    
    private let timeLabelsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        return stack
    }()
    
    // MARK: - Stats Grid (Performance & Vitals)
    private let statsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 15
        return stack
    }()
    
    // MARK: - Scenarios
    private let scenarioView: UIView = {
        let view = UIView()
        // view.backgroundColor = UIColor(red: 44/255.0, green: 44/255.0, blue: 44/255.0, alpha: 1.0) // Dark gray
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    // MARK: - Stages List
    private let stagesStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()
    
    /// Reference to the Deep Sleep stage card for programmatic expansion
    private var deepSleepItem: StageItemView?
    
    private var pendingScrollTarget: HealthDayScrollTarget?
    private var pendingScrollRetryCount: Int = 0
    private let maxScrollRetries = 40
    private let retryInterval: TimeInterval = 0.05
    private var isRetryScheduled = false

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        reloadData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        debugLog("didMoveToWindow window=\(window != nil)")
        if window != nil, pendingScrollTarget != nil {
            scheduleAttemptPendingScroll(delay: 0)
        }
    }
    
    // MARK: - Scroll To Section (Called from HomeViewController navigation)
    /// Scroll to a specific section. If layout is not ready yet,
    /// retry on next run loops until target frames are stable.
    func scrollToSection(_ target: HealthDayScrollTarget) {
        debugLog("scrollToSection target=\(target.rawValue)")
        pendingScrollTarget = target
        pendingScrollRetryCount = 0
        scheduleAttemptPendingScroll(delay: 0)
    }

    private func scheduleAttemptPendingScroll(delay: TimeInterval) {
        guard !isRetryScheduled else { return }
        isRetryScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            self.isRetryScheduled = false
            self.attemptPendingScroll()
        }
    }

    private func attemptPendingScroll() {
        guard let target = pendingScrollTarget else { return }

        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
        contentView.setNeedsLayout()
        contentView.layoutIfNeeded()

        if canExecuteScroll(target) {
            debugLog("scroll ready target=\(target.rawValue), retry=\(pendingScrollRetryCount)")
            pendingScrollTarget = nil
            executeScroll(target)
            return
        }

        pendingScrollRetryCount += 1
        if pendingScrollRetryCount > maxScrollRetries {
            debugLog("scroll force execute target=\(target.rawValue), retry overflow")
            pendingScrollTarget = nil
            executeScroll(target)
            return
        }

        scheduleAttemptPendingScroll(delay: retryInterval)
    }

    private func canExecuteScroll(_ target: HealthDayScrollTarget) -> Bool {
        guard window != nil else {
            debugLog("canExecuteScroll=false reason=no window")
            return false
        }
        guard scrollView.bounds.height > 0 else {
            debugLog("canExecuteScroll=false reason=scroll bounds 0")
            return false
        }

        switch target {
        case .top:
            return true
        case .statsSection:
            let summaryMaxY = summarySectionView.frame.maxY
            let statsFrame = statsStackView.convert(statsStackView.bounds, to: self)
            debugLog("stats check summaryMaxY=\(summaryMaxY), statsMinY=\(statsFrame.minY), statsH=\(statsFrame.height)")
            return summaryMaxY > 0 && statsFrame.height > 0 && statsFrame.minY >= summaryMaxY - 1
        case .deepSleep:
            guard let deepItem = deepSleepItem else { return false }
            let deepFrame = deepItem.convert(deepItem.bounds, to: self)
            debugLog("deep check minY=\(deepFrame.minY), h=\(deepFrame.height)")
            return deepFrame.height > 0 && deepFrame.minY > 0
        }
    }
    
    /// Perform the actual scroll operation
    private func executeScroll(_ target: HealthDayScrollTarget) {
        debugLog("executeScroll target=\(target.rawValue)")
        switch target {
        case .top:
            scrollView.setContentOffset(.zero, animated: true)
            
        case .statsSection:
            scrollView.layoutIfNeeded()
            let targetRect = statsStackView.convert(statsStackView.bounds, to: scrollView)
            scrollToTopAligned(rectInScrollView: targetRect, animated: true)
            
        case .deepSleep:
            if let deepItem = deepSleepItem {
                deepItem.setExpanded(true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    guard let self = self else { return }
                    self.scrollView.layoutIfNeeded()
                    let targetRect = deepItem.convert(deepItem.bounds, to: self.scrollView)
                    self.scrollView.scrollRectToVisible(targetRect, animated: true)
                }
            }
        }
    }

    private func scrollToTopAligned(rectInScrollView rect: CGRect, animated: Bool) {
        let insets = scrollView.adjustedContentInset
        let minY = -insets.top
        let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height + insets.bottom)
        let targetY = min(max(rect.minY - insets.top, minY), maxY)
        scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: animated)
        debugLog("topAlignedScroll targetY=\(targetY), minY=\(minY), maxY=\(maxY), rectMinY=\(rect.minY)")
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[HealthDayView] \(message)")
        #endif
    }
    
    // MARK: - Reload Data
    func reloadData() {
        let showMock = Constants.Config.showMockData
        if showMock {
            let mockLocal = HealthMockDataService.shared.dayLocalData()
            let analysis = HealthAnalysisService.shared.mockDayAnalysis(date: Date())
            durationLabel.text = mockLocal.durationText
            dateLabel.text = mockLocal.dateText
            efficiencyValueLabel.text = analysis.scoreSummary?.score.map(String.init) ?? "--"

            // Rebuild dynamic sections
            rebuildStatsSection(
                sleepSubtitle: L("health.sleep.performance"),
                timeInBed: mockLocal.timeInBedText,
                restingHeartRate: mockLocal.restingHeartRateText,
                vitalsSubtitle: L("health.sleep.overnight_vitals"),
                respiratoryRate: mockLocal.respiratoryRateText,
                bodyTemperature: mockLocal.bodyTemperatureText
            )
            rebuildScenarioSection(
                onsetText: mockLocal.scenarioOnsetText,
                titleText: analysis.sleepScenarios?.title,
                descriptionText: analysis.sleepScenarios?.description
            )
            rebuildStagesSection(
                stageValues: mockLocal.stageValues,
                stageDescriptions: [
                    0: analysis.stageInsights?.awake?.description,
                    1: analysis.stageInsights?.rem?.description,
                    2: analysis.stageInsights?.core?.description,
                    3: analysis.stageInsights?.deep?.description
                ].compactMapValues { $0 },
                stageStats: mockLocal.stageStats,
                graphSegments: mockLocal.graphSegments
            )
            graphView.showMockData = true
            graphView.mockSegments = mockLocal.graphSegments
            graphView.realSegments = []
            graphView.setNeedsDisplay()
        } else {
            durationLabel.text = "--"
            dateLabel.text = "--"
            efficiencyValueLabel.text = "--"
            rebuildStatsSection()
            rebuildScenarioSection()
            rebuildStagesSection()
            graphView.showMockData = false
            graphView.mockSegments = []
            graphView.realSegments = []
            graphView.setNeedsDisplay()
            loadRealSummaryData()
        }
    }

    private func loadRealSummaryData() {
        Task { @MainActor in
            do {
                async let metricsTask = HealthDataManager.shared.fetchLatestMetrics(forceLive: true)
                async let stagesTask = HealthDataManager.shared.fetchLatestSleepStages(forceLive: true)
                async let aggregatesTask = HealthDataManager.shared.fetchSleepDailyAggregates(days: 1)
                async let analysisTask = HealthAnalysisService.shared.fetchDayAnalysis(date: Date())

                let metrics = try await metricsTask
                let stages = try await stagesTask
                let aggregates = try await aggregatesTask
                let analysis = try? await analysisTask
                applyRealMetrics(metrics, analysis: analysis)
                applyRealSleepDetails(aggregates: aggregates, stages: stages, analysis: analysis)
            } catch {
                durationLabel.text = "--"
                dateLabel.text = "--"
                efficiencyValueLabel.text = "--"
            }
        }
    }

    private func applyRealMetrics(_ metrics: HealthMetrics, analysis: HealthAnalysisService.DayAnalysis?) {
        efficiencyValueLabel.text = "--"

        if let sleep = metrics.sleepSummary {
            let totalMinutes = Int((sleep.totalSleepHours * 60.0).rounded(.down))
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            durationLabel.text = minutes > 0 ? "\(hours)h \(minutes)min" : "\(hours)h"

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "d MMM yyyy"
            dateLabel.text = formatter.string(from: sleep.date)

            if let score = analysis?.scoreSummary?.score {
                efficiencyValueLabel.text = "\(score)"
            }
        }

        let timeInBedText: String = {
            guard let timeInBed = metrics.sleepSummary?.timeInBed else { return "--" }
            let hours = Int(timeInBed)
            let minutes = Int(((timeInBed - Double(hours)) * 60.0).rounded())
            return minutes > 0 ? "\(hours)h \(minutes)min" : "\(hours)h"
        }()

        let restingHeartRateText = metrics.restingHeartRate.map { "\(Int($0.value.rounded()))bpm" } ?? "--"
        let respiratoryRateText = metrics.respiratoryRate.map { "\(Int($0.value.rounded()))bpm" } ?? "--"
        let temperatureText = (metrics.sleepingWristTemperature ?? metrics.bodyTemperature).map { String(format: "%.1f°C", $0.value) } ?? "--"

        rebuildStatsSection(
            sleepSubtitle: L("health.sleep.performance"),
            timeInBed: timeInBedText,
            restingHeartRate: restingHeartRateText,
            vitalsSubtitle: L("health.sleep.overnight_vitals"),
            respiratoryRate: respiratoryRateText,
            bodyTemperature: temperatureText
        )
    }

    private func applyRealSleepDetails(
        aggregates: [HealthDataManager.SleepDailyAggregate],
        stages: [HealthDataManager.SleepStageDetail],
        analysis: HealthAnalysisService.DayAnalysis?
    ) {
        guard let aggregate = aggregates.last(where: { $0.hasData }) ?? aggregates.last else { return }

        let onsetText = formatMinutes(aggregate.sleepOnsetMinutes)
        let scenarioDescription: String
        if let onsetMinutes = aggregate.sleepOnsetMinutes {
            scenarioDescription = String(format: "You fell asleep in %d minutes based on the latest sleep session recorded in Apple Health.", Int(onsetMinutes.rounded()))
        } else {
            scenarioDescription = "Latest sleep timing is based on the most recent Apple Health sleep session."
        }

        rebuildScenarioSection(
            onsetText: onsetText,
            titleText: analysis?.sleepScenarios?.title ?? L("home.metric.sleep_onset"),
            descriptionText: analysis?.sleepScenarios?.description ?? scenarioDescription
        )

        let segments = sleepStageSegments(from: stages)
        graphView.realSegments = segments
        graphView.showMockData = false
        graphView.setNeedsDisplay()

        let stageValues: [Int: String] = [
            0: formatMinutes(aggregate.awakeMinutes),
            1: formatDuration(hours: aggregate.remSleepHours),
            2: formatDuration(hours: aggregate.coreSleepHours),
            3: formatDuration(hours: aggregate.deepSleepHours)
        ]

        let stageDescriptions: [Int: String] = [
            0: analysis?.stageInsights?.awake?.description,
            1: analysis?.stageInsights?.rem?.description,
            2: analysis?.stageInsights?.core?.description,
            3: analysis?.stageInsights?.deep?.description
        ].compactMapValues { $0 }

        rebuildStagesSection(stageValues: stageValues, stageDescriptions: stageDescriptions, graphSegments: segments)
    }

    private func sleepStageSegments(from stages: [HealthDataManager.SleepStageDetail]) -> [(Int, Double)] {
        stages.compactMap { stage in
            let minutes = stage.endTime.timeIntervalSince(stage.startTime) / 60.0
            guard minutes > 0 else { return nil }
            return (stageIndex(for: stage.stage), minutes)
        }
    }

    private func stageIndex(for stage: HealthDataManager.SleepStageDetail.Stage) -> Int {
        switch stage {
        case .awake:
            return 0
        case .rem:
            return 1
        case .core:
            return 2
        case .deep:
            return 3
        }
    }

    private func formatDuration(hours: Double) -> String {
        let totalMinutes = Int((hours * 60.0).rounded())
        let hourPart = totalMinutes / 60
        let minutePart = totalMinutes % 60

        if hourPart <= 0 {
            return "\(minutePart)min"
        }
        if minutePart == 0 {
            return "\(hourPart)h"
        }
        return "\(hourPart)h \(minutePart)min"
    }

    private func formatMinutes(_ minutes: Double?) -> String {
        guard let minutes else { return "--" }
        let rounded = Int(minutes.rounded())
        if rounded >= 60 {
            return formatDuration(hours: Double(rounded) / 60.0)
        }
        return "\(rounded)min"
    }
    
    private func setupUI() {
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
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
        
        setupSummarySection()
        
        // Add containers to contentView once; content will be filled by reloadData()
        contentView.addArrangedSubview(statsStackView)
        contentView.addArrangedSubview(scenarioView)
        contentView.addArrangedSubview(stagesStackView)
    }
    
    private func setupSummarySection() {
        summarySectionView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addArrangedSubview(summarySectionView)
        
        // Left Stack (Duration & Date) - Layout: Vertical, Left Aligned
        let leftStack = UIStackView()
        leftStack.axis = .vertical
        leftStack.alignment = .leading
        leftStack.spacing = 7 // 14px -> 7pt
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        
        leftStack.addArrangedSubview(durationLabel)
        leftStack.addArrangedSubview(dateLabel)
        
        summarySectionView.addSubview(leftStack)
        
        // Right Stack (Value & Title) - Layout: Vertical, Center Aligned (Elements centered to each other)
        let rightStack = UIStackView()
        rightStack.axis = .vertical
        rightStack.alignment = .center
        rightStack.spacing = 0 
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Ensure labels are centered text-wise
        efficiencyValueLabel.textAlignment = .center
        efficiencyTitleLabel.textAlignment = .center
        
        rightStack.addArrangedSubview(efficiencyValueLabel)
        rightStack.addArrangedSubview(efficiencyTitleLabel)
        
        summarySectionView.addSubview(rightStack)
        
        summarySectionView.addSubview(graphView)
        summarySectionView.addSubview(timeLabelsStackView)
        
        graphView.translatesAutoresizingMaskIntoConstraints = false
        timeLabelsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Right Stack (Reference height, determines top)
            rightStack.topAnchor.constraint(equalTo: summarySectionView.topAnchor, constant: 10),
            // Container has 20pt margin. User wants 35pt total screen margin. 35 - 20 = 15pt.
            rightStack.trailingAnchor.constraint(equalTo: summarySectionView.trailingAnchor, constant: -15),
            
            // Left Stack (Bottom aligned with Right Stack)
            // Container has 20pt margin. User wants 35pt total screen margin. 35 - 20 = 15pt.
            leftStack.leadingAnchor.constraint(equalTo: summarySectionView.leadingAnchor, constant: 15),
            leftStack.bottomAnchor.constraint(equalTo: rightStack.bottomAnchor),
            
            // Graph
            graphView.topAnchor.constraint(equalTo: rightStack.bottomAnchor, constant: 30),
            // User: "图片的左右分割线距离左右又有19pt"
            // Base margin (coordinates) is 40pt from screen (20pt from container).
            // Graph is indented by another 19pt. 20 + 19 = 39pt from container.
            graphView.leadingAnchor.constraint(equalTo: summarySectionView.leadingAnchor, constant: 39),
            graphView.trailingAnchor.constraint(equalTo: summarySectionView.trailingAnchor, constant: -39),
            graphView.heightAnchor.constraint(equalToConstant: 134.5),
            
            // Time Labels
            // "底部分割线距离底部坐标的文字底部25pt"
            // Graph Bottom (Bottom Divider) -> Text Bottom = 25pt.
            // Text Height is approx 14-15pt. So Graph Bottom -> Text Top should be ~10-11pt.
            // Previous was 14. Adjusting to 10.5pt.
            timeLabelsStackView.topAnchor.constraint(equalTo: graphView.bottomAnchor, constant: 10.5),
            // User: "整个图片区域，包括下面的坐标，距离左右时40PT"
            // Container is 20pt from screen. So add 20pt. 20+20=40.
            timeLabelsStackView.leadingAnchor.constraint(equalTo: summarySectionView.leadingAnchor, constant: 20),
            timeLabelsStackView.trailingAnchor.constraint(equalTo: summarySectionView.trailingAnchor, constant: -20),
            timeLabelsStackView.bottomAnchor.constraint(equalTo: summarySectionView.bottomAnchor, constant: -10)
        ])
        
        // Add time labels
        let times = ["00:00", "02:00", "04:00", "06:00", "08:00"]
        times.forEach { text in
            let label = UILabel()
            label.text = text
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = UIColor(white: 0.5, alpha: 1.0)
            timeLabelsStackView.addArrangedSubview(label)
        }
    }
    
    private func rebuildStatsSection(
        sleepSubtitle: String? = nil,
        timeInBed: String? = nil,
        restingHeartRate: String? = nil,
        vitalsSubtitle: String? = nil,
        respiratoryRate: String? = nil,
        bodyTemperature: String? = nil
    ) {
        // Clear existing content
        statsStackView.arrangedSubviews.forEach {
            statsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let performanceSubtitle = sleepSubtitle ?? "--"
        let timeInBedValue = timeInBed ?? "--"
        let restingHeartRateValue = restingHeartRate ?? "--"
        let vitalsSubtitleValue = vitalsSubtitle ?? "--"
        let respiratoryRateValue = respiratoryRate ?? "--"
        let bodyTemperatureValue = bodyTemperature ?? "--"
        
        let performanceView = createStatsCard(
            backgroundImageName: "sleep_day_sleep_bg",
            icon: "sleep_day_scene_icon",
            title: L("health.sleep.performance"),
            subtitle: performanceSubtitle,
            items: [
                (L("health.sleep.time_in_bed"), timeInBedValue),
                (L("health.sleep.resting_heart_rate"), restingHeartRateValue)
            ]
        )
        
        let vitalsView = createStatsCard(
            backgroundImageName: "sleep_day_vitals_bg",
            icon: "sleep_day_vitals_icon",
            title: L("health.sleep.overnight_vitals"),
            subtitle: vitalsSubtitleValue,
            items: [
                (L("health.sleep.respiratory_rate"), respiratoryRateValue),
                (L("health.sleep.body_temperature"), bodyTemperatureValue)
            ]
        )
        
        statsStackView.addArrangedSubview(performanceView)
        statsStackView.addArrangedSubview(vitalsView)
    }
    
    private func createStatsCard(backgroundImageName: String, icon: String, title: String, subtitle: String, items: [(String, String)]) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        
        let bgImageView = UIImageView(image: UIImage(named: backgroundImageName))
        bgImageView.contentMode = .scaleToFill
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bgImageView)
        
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: card.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        
        // Header: Icon + Text Group (Subtitle Bold, Title Light)
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center // Vertically center icon with text block
        
        let iconView = UIImageView(image: UIImage(named: icon))
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 26).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 26).isActive = true
        
        let textGroup = UIStackView()
        textGroup.axis = .vertical
        textGroup.spacing = 0
        
        // Note: CSS uses text_15 (Sleep) SemiBold 24px/12pt, text_16 (Sleep Perf) Light 22px/11pt
        // mapped to input: subtitle -> "Sleep", title -> "Sleep Perf"
        let topLabel = UILabel()
        topLabel.text = subtitle
        topLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        topLabel.textColor = .white
        
        let bottomLabel = UILabel()
        bottomLabel.text = title
        bottomLabel.font = UIFont.systemFont(ofSize: 11, weight: .light)
        bottomLabel.textColor = .white
        
        textGroup.addArrangedSubview(topLabel)
        textGroup.addArrangedSubview(bottomLabel)
        
        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(textGroup)
        
        card.addSubview(headerStack)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            headerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            headerStack.trailingAnchor.constraint( lessThanOrEqualTo: card.trailingAnchor, constant: -12)
        ])
        
        var previousAnchor = headerStack.bottomAnchor
        
        for (labelTitle, value) in items {
            let itemStack = UIStackView()
            itemStack.axis = .vertical
            itemStack.spacing = 3 
            
            // Value: 36px -> 18pt SemiBold
            let valLabel = UILabel()
            valLabel.text = value
            valLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            valLabel.textColor = .white
            
            // Label: 22px -> 11pt Light
            let keyLabel = UILabel()
            keyLabel.text = labelTitle
            keyLabel.font = UIFont.systemFont(ofSize: 11, weight: .light)
            keyLabel.textColor = .white
            
            itemStack.addArrangedSubview(valLabel)
            itemStack.addArrangedSubview(keyLabel)
            
            card.addSubview(itemStack)
            itemStack.translatesAutoresizingMaskIntoConstraints = false
            
            // Margin top roughly 24pt (48px) for first, 20pt (40px) for second
            NSLayoutConstraint.activate([
                itemStack.topAnchor.constraint(equalTo: previousAnchor, constant: 20),
                itemStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
                itemStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12)
            ])
            previousAnchor = itemStack.bottomAnchor
        }
        
        card.bottomAnchor.constraint(equalTo: previousAnchor, constant: 24).isActive = true
        
        return card
    }
    
    private func rebuildScenarioSection(onsetText: String? = nil, titleText: String? = nil, descriptionText: String? = nil) {
        // Clear existing content
        scenarioView.subviews.forEach { $0.removeFromSuperview() }
        
        let bgImageView = UIImageView(image: UIImage(named: "sleep_day_scene_bg"))
        bgImageView.contentMode = .scaleToFill
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        scenarioView.addSubview(bgImageView)
        
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: scenarioView.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: scenarioView.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: scenarioView.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: scenarioView.bottomAnchor)
        ])
        
        // Header: Icon + VStack(Title, Subtitle)
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        scenarioView.addSubview(headerStack)
        
        let iconView = UIImageView(image: UIImage(named: "sleep_day_scene_icon"))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 26).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 26).isActive = true
        
        // Text Group: "Sleep Scenarios" (12pt Bold), "5min Sleep Onset" (11pt Light)
        let headerTextGroup = UIStackView()
        headerTextGroup.axis = .vertical
        headerTextGroup.spacing = 0
        
        let titleLabel = UILabel()
        titleLabel.text = L("health.sleep.scenarios")
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .white
        
        let tagLabel = UILabel()
        tagLabel.text = (onsetText ?? "--") + " " + L("health.sleep.onset")
        tagLabel.font = UIFont.systemFont(ofSize: 11, weight: .light)
        tagLabel.textColor = .white
        
        headerTextGroup.addArrangedSubview(titleLabel)
        headerTextGroup.addArrangedSubview(tagLabel)
        
        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(headerTextGroup)
        
        // Main Title
        let mainTitle = UILabel()
        mainTitle.text = titleText ?? "--"
        mainTitle.font = UIFont.systemFont(ofSize: 24, weight: .regular)
        mainTitle.textColor = .white
        mainTitle.translatesAutoresizingMaskIntoConstraints = false
        scenarioView.addSubview(mainTitle)
        
        // Description
        let descLabel = UILabel()
        let descText = descriptionText ?? "--"
        descLabel.font = UIFont.systemFont(ofSize: 11, weight: .light)
        descLabel.textColor = .white 
        descLabel.numberOfLines = 0
        
        // Adjust line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        let attrString = NSMutableAttributedString(string: descText)
        attrString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attrString.length))
        descLabel.attributedText = attrString
        
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        scenarioView.addSubview(descLabel)
        
        // Layout
        // CSS block_4 padding: 48px -> 24pt
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: scenarioView.topAnchor, constant: 24),
            headerStack.leadingAnchor.constraint(equalTo: scenarioView.leadingAnchor, constant: 22),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: scenarioView.trailingAnchor, constant: -42),
            
            mainTitle.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 10), // margin reduced
            mainTitle.leadingAnchor.constraint(equalTo: scenarioView.leadingAnchor, constant: 22),
            mainTitle.trailingAnchor.constraint(equalTo: scenarioView.trailingAnchor, constant: -42),
            
            descLabel.topAnchor.constraint(equalTo: mainTitle.bottomAnchor, constant: 12), // margin reduced
            descLabel.leadingAnchor.constraint(equalTo: scenarioView.leadingAnchor, constant: 22),
            descLabel.trailingAnchor.constraint(equalTo: scenarioView.trailingAnchor, constant: -42),
            descLabel.bottomAnchor.constraint(equalTo: scenarioView.bottomAnchor, constant: -24)
        ])
    }
    
    private func rebuildStagesSection(stageValues: [Int: String] = [:], stageDescriptions: [Int: String] = [:], stageStats: [Int: [HealthMockDataService.StageStatRow]] = [:], graphSegments: [(Int, Double)] = []) {
        // Clear existing content
        stagesStackView.arrangedSubviews.forEach {
            stagesStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        
        // Colors updated to match Constants (Graph colors)
        
        let awakeItem = StageItemView(
            title: L("health.sleep.awake_time"),
            value: stageValues[0] ?? "--",
            color: Colors.colorAwake,
            description: stageDescriptions[0] ?? "Awake time detected during your latest sleep session.",
            stats: stageStats[0] ?? [],
            stageIndex: 0,
            graphSegments: graphSegments
        )
        
        let remItem = StageItemView(
            title: L("health.sleep.stage.rem"),
            value: stageValues[1] ?? "--",
            color: Colors.colorREM,
            description: stageDescriptions[1] ?? "REM sleep from your latest Apple Health sleep stages.",
            stats: stageStats[1] ?? [],
            stageIndex: 1,
            graphSegments: graphSegments
        )
        
        let coreItem = StageItemView(
            title: L("health.sleep.stage.core"),
            value: stageValues[2] ?? "--",
            color: Colors.colorCore,
            description: stageDescriptions[2] ?? "Core sleep from your latest Apple Health sleep stages.",
            stats: stageStats[2] ?? [],
            stageIndex: 2,
            graphSegments: graphSegments
        )
        
        let deepItem = StageItemView(
            title: L("health.sleep.stage.deep"),
            value: stageValues[3] ?? "--",
            color: Colors.colorDeep,
            description: stageDescriptions[3] ?? "Deep sleep from your latest Apple Health sleep stages.",
            stats: stageStats[3] ?? [],
            stageIndex: 3,
            graphSegments: graphSegments
        )
        
        stagesStackView.addArrangedSubview(awakeItem)
        stagesStackView.addArrangedSubview(remItem)
        stagesStackView.addArrangedSubview(coreItem)
        stagesStackView.addArrangedSubview(deepItem)
        
        // Keep reference to deep sleep item for programmatic expand
        self.deepSleepItem = deepItem
    }
    
    // MARK: - Stage Item View Class
    private class StageItemView: UIView {
        private var isExpanded = false
        private let arrowBtn = UIButton()
        private let expandedStack = UIStackView()
        
        init(title: String, value: String, color: UIColor, description: String, stats: [(String, String, String)], stageIndex: Int = 0, graphSegments: [(Int, Double)] = []) {
            super.init(frame: .zero)
            setupUI(title: title, value: value, color: color, description: description, stats: stats, stageIndex: stageIndex, graphSegments: graphSegments)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupUI(title: String, value: String, color: UIColor, description: String, stats: [(String, String, String)], stageIndex: Int, graphSegments: [(Int, Double)] = []) {
            // Main Vertical Stack
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
            
            // 1. Header Wrapper (The Colored Card part)
            let headerWrapper = UIView()
            headerWrapper.layer.cornerRadius = 12
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
            
            // Indicator
            let indicator = UIView()
            indicator.backgroundColor = color
            indicator.layer.cornerRadius = 6
            indicator.translatesAutoresizingMaskIntoConstraints = false
            headerWrapper.addSubview(indicator)
            
            // Text Stack
            let textStack = UIStackView()
            textStack.axis = .vertical
            textStack.spacing = 2
            textStack.alignment = .leading
            textStack.translatesAutoresizingMaskIntoConstraints = false
            headerWrapper.addSubview(textStack)
            
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            titleLabel.textColor = .white
            
            let valueLabel = UILabel()
            valueLabel.text = value
            valueLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
            valueLabel.textColor = .white
            
            textStack.addArrangedSubview(titleLabel)
            textStack.addArrangedSubview(valueLabel)
            
            // Arrow Button
            arrowBtn.setImage(UIImage(named: "arrow_down"), for: .normal)
            arrowBtn.translatesAutoresizingMaskIntoConstraints = false
            arrowBtn.addTarget(self, action: #selector(toggleExpand), for: .touchUpInside)
            headerWrapper.addSubview(arrowBtn)
            
            // Header Tap Gesture
            let tap = UITapGestureRecognizer(target: self, action: #selector(toggleExpand))
            headerWrapper.addGestureRecognizer(tap)
            
            NSLayoutConstraint.activate([
                indicator.leadingAnchor.constraint(equalTo: headerWrapper.leadingAnchor, constant: 24),
                indicator.centerYAnchor.constraint(equalTo: headerWrapper.centerYAnchor),
                indicator.widthAnchor.constraint(equalToConstant: 12),
                indicator.heightAnchor.constraint(equalToConstant: 12),
                
                textStack.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 18),
                textStack.centerYAnchor.constraint(equalTo: headerWrapper.centerYAnchor),
                textStack.topAnchor.constraint(greaterThanOrEqualTo: headerWrapper.topAnchor, constant: 16),
                textStack.bottomAnchor.constraint(lessThanOrEqualTo: headerWrapper.bottomAnchor, constant: -16),
                
                arrowBtn.trailingAnchor.constraint(equalTo: headerWrapper.trailingAnchor, constant: -16),
                arrowBtn.centerYAnchor.constraint(equalTo: headerWrapper.centerYAnchor),
                arrowBtn.widthAnchor.constraint(equalToConstant: 44),
                arrowBtn.heightAnchor.constraint(equalToConstant: 44)
            ])
            
            // 2. Expanded Section (Custom Layout instead of simple Stack)
            expandedStack.axis = .vertical
            expandedStack.spacing = 20
            expandedStack.isHidden = true
            expandedStack.alpha = 0
            
            mainStack.addArrangedSubview(expandedStack)
            
            // A. Description Wrapper
            let descWrapper = UIView()
            descWrapper.translatesAutoresizingMaskIntoConstraints = false
            expandedStack.addArrangedSubview(descWrapper)
            
            let descLabel = UILabel()
            descLabel.text = description
            descLabel.numberOfLines = 0
            descLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            descLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            let attrString = NSMutableAttributedString(string: description)
            attrString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attrString.length))
            descLabel.attributedText = attrString
            descLabel.translatesAutoresizingMaskIntoConstraints = false
            
            descWrapper.addSubview(descLabel)
            
            // Constraint: Left/Right 25.5pt
            NSLayoutConstraint.activate([
                descLabel.topAnchor.constraint(equalTo: descWrapper.topAnchor),
                descLabel.bottomAnchor.constraint(equalTo: descWrapper.bottomAnchor),
                descLabel.leadingAnchor.constraint(equalTo: descWrapper.leadingAnchor, constant: 25.5),
                descLabel.trailingAnchor.constraint(equalTo: descWrapper.trailingAnchor, constant: -25.5)
            ])
            
            // B. Graph Wrapper
            let graphWrapper = UIView()
            graphWrapper.translatesAutoresizingMaskIntoConstraints = false
            expandedStack.addArrangedSubview(graphWrapper)
            
            let detailGraph = DetailGraphView(stage: stageIndex, color: color, graphSegments: graphSegments)
            detailGraph.backgroundColor = .clear // Transparent, grid will be drawn
            detailGraph.translatesAutoresizingMaskIntoConstraints = false
            graphWrapper.addSubview(detailGraph)
            
            // Constraint: Width 311.5, Height 172, Left 28.5
            NSLayoutConstraint.activate([
                detailGraph.widthAnchor.constraint(equalToConstant: 311.5),
                detailGraph.heightAnchor.constraint(equalToConstant: 172),
                detailGraph.topAnchor.constraint(equalTo: graphWrapper.topAnchor),
                detailGraph.bottomAnchor.constraint(equalTo: graphWrapper.bottomAnchor),
                detailGraph.leadingAnchor.constraint(equalTo: graphWrapper.leadingAnchor, constant: 28.5),
                // Allow trailing to be flexible (stackview width is determined by parent)
                detailGraph.trailingAnchor.constraint(lessThanOrEqualTo: graphWrapper.trailingAnchor)
            ])
            
            // C. Stats Section
            if !stats.isEmpty {
                let statsWrapper = UIView()
                statsWrapper.translatesAutoresizingMaskIntoConstraints = false
                expandedStack.addArrangedSubview(statsWrapper)
                
                let statsContainer = UIStackView()
                statsContainer.axis = .vertical
                statsContainer.spacing = 13
                statsContainer.alignment = .leading
                statsContainer.translatesAutoresizingMaskIntoConstraints = false
                
                statsWrapper.addSubview(statsContainer)
                
                // Constraint: Icons Left 60pt
                NSLayoutConstraint.activate([
                    statsContainer.topAnchor.constraint(equalTo: statsWrapper.topAnchor),
                    statsContainer.bottomAnchor.constraint(equalTo: statsWrapper.bottomAnchor),
                    statsContainer.leadingAnchor.constraint(equalTo: statsWrapper.leadingAnchor, constant: 60),
                    statsContainer.trailingAnchor.constraint(equalTo: statsWrapper.trailingAnchor)
                ])
                
                for (name, value, iconName) in stats {
                    let row = UIStackView()
                    row.axis = .horizontal
                    row.spacing = 12
                    row.alignment = .center
                    
                    let iconContainer = UIView()
                    iconContainer.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
                    iconContainer.layer.cornerRadius = 12
                    iconContainer.translatesAutoresizingMaskIntoConstraints = false
                    iconContainer.widthAnchor.constraint(equalToConstant: 24).isActive = true
                    iconContainer.heightAnchor.constraint(equalToConstant: 24).isActive = true
                    
                    let icon = UIImageView(image: UIImage(named: iconName))
                    icon.tintColor = UIColor(white: 0.8, alpha: 1.0)
                    icon.contentMode = .scaleAspectFit
                    icon.translatesAutoresizingMaskIntoConstraints = false
                    iconContainer.addSubview(icon)
                    
                    NSLayoutConstraint.activate([
                        icon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
                        icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
                        icon.widthAnchor.constraint(equalToConstant: 14),
                        icon.heightAnchor.constraint(equalToConstant: 14)
                    ])
                    
                    let textLabel = UILabel()
                    textLabel.text = "\(name):  \(value)"
                    textLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
                    textLabel.font = UIFont.systemFont(ofSize: 13, weight: .light)
                    
                    row.addArrangedSubview(iconContainer)
                    row.addArrangedSubview(textLabel)
                    
                    statsContainer.addArrangedSubview(row)
                }
            }
        }
        
        @objc private func toggleExpand() {
            setExpanded(!isExpanded)
        }
        
        /// Programmatically expand (or collapse) this stage card
        func setExpanded(_ expanded: Bool) {
            guard expanded != isExpanded else { return }
            isExpanded = expanded
            
            UIView.animate(withDuration: 0.3, animations: {
                self.expandedStack.isHidden = !self.isExpanded
                self.expandedStack.alpha = self.isExpanded ? 1 : 0
                self.arrowBtn.transform = self.isExpanded ? CGAffineTransform(rotationAngle: .pi) : .identity
                
                if let stack = self.superview as? UIStackView {
                    stack.layoutIfNeeded()
                }
            })
        }
    }
    
    // MARK: - Detail Graph View (For Expanded Card)
    private class DetailGraphView: UIView {
        private let targetStage: Int
        private let barColor: UIColor
        private let graphSegments: [(Int, Double)]
        
        init(stage: Int, color: UIColor, graphSegments: [(Int, Double)] = []) {
            self.targetStage = stage
            self.barColor = color
            self.graphSegments = graphSegments
            super.init(frame: .zero)
            self.backgroundColor = .clear
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            
            // 1. Grid Configuration
            let gridRows = 4
            let gridCols = 4
            
            let gridWidth: CGFloat = 260.0
            let gridHeight: CGFloat = 140.0
            let cellWidth: CGFloat = gridWidth / CGFloat(gridCols)
            let cellHeight: CGFloat = gridHeight / CGFloat(gridRows)
            
            let startX: CGFloat = 35.0
            let startY: CGFloat = 10.0
            let gridRect = CGRect(x: startX, y: startY, width: gridWidth, height: gridHeight)
            
            // Draw Grid
            context.setStrokeColor(UIColor(white: 1.0, alpha: 0.1).cgColor)
            context.setLineWidth(1.0)
            
            // Horizontal Lines
            for i in 0...gridRows {
                let y = startY + CGFloat(i) * cellHeight
                context.move(to: CGPoint(x: startX, y: y))
                context.addLine(to: CGPoint(x: startX + gridWidth, y: y))
            }
            
            // Vertical Lines
            for i in 0...gridCols {
                let x = startX + CGFloat(i) * cellWidth
                context.move(to: CGPoint(x: x, y: startY))
                context.addLine(to: CGPoint(x: x, y: startY + gridHeight))
            }
            context.strokePath()
            
            // 2. Draw Axis Labels (BPM & Time)
            // Using Heart Rate BPM as the Y-axis proxy for the curve visualization
            let yLabels = ["120", "100", "80", "60", "40"]
            let xLabels = ["00:00", "02:00", "04:00", "06:00", "08:00"]
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor(white: 0.6, alpha: 1.0)
            ]
            
            // Y Axis Labels
            let yInterval = gridHeight / CGFloat(yLabels.count - 1)
            for (i, text) in yLabels.enumerated() {
                let yPos = gridRect.minY + CGFloat(i) * yInterval
                let string = NSAttributedString(string: text, attributes: attributes)
                let size = string.size()
                let xPos = gridRect.minX - size.width - 8
                string.draw(at: CGPoint(x: xPos, y: yPos - size.height/2))
            }
            
            // X Axis Labels
            let xInterval = gridRect.width / CGFloat(xLabels.count - 1)
            for (i, text) in xLabels.enumerated() {
                let xPos = gridRect.minX + CGFloat(i) * xInterval
                let string = NSAttributedString(string: text, attributes: attributes)
                let size = string.size()
                string.draw(at: CGPoint(x: xPos - size.width/2, y: gridRect.maxY + 6))
            }
            
            // 3. Draw Curve: Continuous across the whole timeline
            // "Curve needs to be continuous"
            // We generate points for the entire duration context, varying the Y-value based on the stage.
            
            let segments = graphSegments
            
            let totalDuration = segments.reduce(0) { $0 + $1.1 }
            if totalDuration == 0 { return }
            
            // Helper to determine stage at a specific normalized time (0.0 to 1.0)
            func getStage(at normalizedTime: Double) -> Int {
                let time = normalizedTime * totalDuration
                var elapsed: Double = 0
                for (stage, duration) in segments {
                    if time >= elapsed && time < elapsed + duration {
                        return stage
                    }
                    elapsed += duration
                }
                return segments.last?.0 ?? 2
            }

            let numPoints = 130 // Resolution
            let stepX = gridWidth / CGFloat(numPoints - 1)
            var curvePoints: [CGPoint] = []
            var pointStages: [Int] = []
            
            // Parameters for each stage's curve physics (Heart Rate Proxy)
            // Awake(0): High HR, High Volatility
            // REM(1): Medium HR, Medium Volatility
            // Core(2): Low HR, Low Volatility
            // Deep(3): Lowest HR, Stable
            func getPhysics(for stage: Int) -> (base: Double, vol: Double) {
                switch stage {
                case 0: return (100.0, 9.0)
                case 1: return (82.0, 7.0)
                case 2: return (68.0, 5.0)
                case 3: return (52.0, 3.0)
                default: return (60.0, 5.0)
                }
            }
            
            // Generate raw points
            for i in 0..<numPoints {
                let progress = Double(i) / Double(numPoints - 1)
                let x = startX + CGFloat(i) * stepX
                let stage = getStage(at: progress)
                pointStages.append(stage)
                
                let (baseHR, volatility) = getPhysics(for: stage)
                
                // Continuous noise function
                // Using 'i' ensures continuity across stage boundaries
                let noise1 = sin(Double(i) * 0.2) * volatility
                let noise2 = sin(Double(i) * 0.7) * (volatility * 0.4)
                let randomVar = Double.random(in: -1.0...1.0)
                
                let value = baseHR + noise1 + noise2 + randomVar
                let clampedVal = max(40, min(120, value))
                
                // Map to Y
                let yRatio = (clampedVal - 40.0) / 80.0
                let y = startY + gridHeight * (1.0 - CGFloat(yRatio))
                
                curvePoints.append(CGPoint(x: x, y: y))
            }
            
            // Apply smoothing to make the transition between stages seamless
            var smoothedPoints = curvePoints
            let smoothingWindow = 4
            for i in 0..<smoothedPoints.count {
                let start = max(0, i - smoothingWindow)
                let end = min(smoothedPoints.count - 1, i + smoothingWindow)
                var sumY: CGFloat = 0
                for j in start...end {
                    sumY += curvePoints[j].y
                }
                smoothedPoints[i].y = sumY / CGFloat(end - start + 1)
            }
            
            // Draw the Continuous Path
            let path = UIBezierPath()
            if !smoothedPoints.isEmpty {
                path.move(to: smoothedPoints[0])
                for pt in smoothedPoints.dropFirst() {
                    path.addLine(to: pt)
                }
            }
            
            // Glow Effect
            context.saveGState()
            context.setShadow(offset: .zero, blur: 6.0, color: barColor.withAlphaComponent(0.6).cgColor)
            context.setStrokeColor(barColor.cgColor) // Curve colored by the card's theme? Or White? 
            // Reference implies white curve with colored bars, or slightly tinted.
            // Let's use White for the curve to represent the "whole night", 
            // but maybe tint it slightly towards the barColor?
            // Actually user said "Do not show other data". 
            // Maybe we should fade the curve out in non-target areas?
            // "Curve needs to be continuous". 
            // Let's keep the curve fully visible (maybe semi-transparent white) and highlight the target stage with bars.
            // Or solid white curve looks best on dark bg.
            context.setStrokeColor(UIColor.white.cgColor)
            
            context.setLineWidth(2.5)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.addPath(path.cgPath)
            context.strokePath()
            context.restoreGState()
            
            // 4. Draw Bars (Only for Target Data)
            // "Only show ... corresponding data"
            // We interpret this as: The Bars (which represent activity/events) strictly appear only in the target stage.
            
            context.setFillColor(barColor.cgColor)
            let barWidth: CGFloat = 4.0
            
            for (index, point) in smoothedPoints.enumerated() {
                // Check if this point belongs to the target stage
                if pointStages[index] == targetStage {
                    // Draw sparse bars (e.g. every 6th point)
                    if index % 6 == 0 {
                        let barHeight: CGFloat = CGFloat(Int.random(in: 13...43))
                        let barRect = CGRect(x: point.x - barWidth/2, y: point.y - barHeight/2, width: barWidth, height: barHeight)
                        let barPath = UIBezierPath(roundedRect: barRect, cornerRadius: barWidth/2)
                        context.addPath(barPath.cgPath)
                        context.fillPath()
                    }
                }
            }
        }
    }

    // MARK: - Custom Graph View
    private class DaySleepGraphView: UIView {
        
        var showMockData: Bool = true
        var mockSegments: [(Int, Double)] = []
        var realSegments: [(Int, Double)] = []
        
        override func draw(_ rect: CGRect) {
            super.draw(rect)
            
            guard let context = UIGraphicsGetCurrentContext() else { return }
            
            let graphSegments: [(Int, Double)] = showMockData ? mockSegments : realSegments
            guard !graphSegments.isEmpty else { return }
            
            // Layout params
            let width = rect.width
            let height = rect.height
            let paddingVertical: CGFloat = 6.0
            
            // Design calculation:
            // Total height 134.5. Top padding 6, Bottom padding 6.
            // Available height for blocks and gaps = 134.5 - 6 - 6 = 122.5
            // Structure: 4 blocks and 3 gaps.
            // Let block height be h, gap be g.
            // 4h + 3g = 122.5
            // Assume gap is roughly 15-20% of block height or stick to visually pleasing ratio.
            // If we keep gap = 5 (from previous request), then 4h + 15 = 122.5 => 4h = 107.5 => h = 26.875 ~ 27
            // Let's use computed values to be precise.
            
            let availableHeight = 134.5 - (paddingVertical * 2)
            // Let's assume a fixed gap of 4.5 to make numbers rounder? Or just calculate.
            // Let's try to keep gap relatively small, say 5pt.
            let gapCount: CGFloat = 3
            let blockCount: CGFloat = 4
            let verticalGap: CGFloat = 4.5
            let blockHeight = (availableHeight - (verticalGap * gapCount)) / blockCount
            
            let stageYPositions: [CGFloat] = [
                paddingVertical,
                paddingVertical + blockHeight + verticalGap,
                paddingVertical + (blockHeight + verticalGap) * 2,
                paddingVertical + (blockHeight + verticalGap) * 3
            ]
            
            // X-axis mapping
            // Map the full sleep session duration across the chart width.
            
            let totalDuration = graphSegments.reduce(0) { $0 + $1.1 }
            let pointsPerMin = width / CGFloat(totalDuration)
            
            var previousStage: Int? = nil
            
            // Draw connecting lines first (behind blocks)
            let data = graphSegments
            
            // First pass: Draw connections
            // We need to know start/end of each block to draw lines between them.
            
            var xCursor: CGFloat = 0
            var prevRect: CGRect? = nil
            
            for (stageIndex, duration) in data {
                let segmentWidth = CGFloat(duration) * pointsPerMin
                let yPos = stageYPositions[stageIndex]
                let currentRect = CGRect(x: xCursor, y: yPos, width: segmentWidth, height: blockHeight)
                
                // Draw Connection from previous block
                if let prev = prevRect, let prevStage = previousStage, prevStage != stageIndex {
                    // Logic: The vertical line color should match the color of the stage that is visually higher (smaller Y coordinate).
                    // "The color of the connecting line in the graph matches the color of the block above"
                    
                    let usePreviousColor = stageYPositions[prevStage] < stageYPositions[stageIndex]
                    let colorStageIndex = usePreviousColor ? prevStage : stageIndex
                    
                    let color: UIColor
                    switch colorStageIndex {
                    case 0: color = Colors.colorAwake
                    case 1: color = Colors.colorREM
                    case 2: color = Colors.colorCore
                    case 3: color = Colors.colorDeep
                    default: color = .white
                    }
                    
                    context.setStrokeColor(color.cgColor)
                    context.setLineWidth(1.0)
                    context.setLineCap(.butt)
                    
                    // Determine vertical range for the connecting line
                    // The line should only be drawn in the gap between the two blocks.
                    // From the bottom edge of the higher block (smaller Y) to the top edge of the lower block (larger Y).
                    
                    let upperBlockMaxY = prev.minY < currentRect.minY ? prev.maxY : currentRect.maxY
                    let lowerBlockMinY = prev.minY < currentRect.minY ? currentRect.minY : prev.minY
                    
                    // Only draw if there is a gap
                    if upperBlockMaxY < lowerBlockMinY {
                        context.move(to: CGPoint(x: xCursor, y: upperBlockMaxY))
                        context.addLine(to: CGPoint(x: xCursor, y: lowerBlockMinY))
                        context.strokePath()
                    }
                }
                
                prevRect = currentRect
                previousStage = stageIndex
                xCursor += segmentWidth
            }
            
            // Second pass: Draw Blocks (Filled Rects)
            xCursor = 0
            for (stageIndex, duration) in data {
                let segmentWidth = CGFloat(duration) * pointsPerMin
                let yPos = stageYPositions[stageIndex]
                // Extend block by 0.5pt on each side (total 1pt wider) to cover the 1pt connecting line
                // "上下方块都要各自比原来宽1pt...左边，右边都不超过方块边缘"
                let currentRect = CGRect(x: xCursor - 0.5, y: yPos, width: segmentWidth + 1.0, height: blockHeight)
                
                let color: UIColor
                switch stageIndex {
                case 0: color = Colors.colorAwake
                case 1: color = Colors.colorREM
                case 2: color = Colors.colorCore
                case 3: color = Colors.colorDeep
                default: color = .white
                }
                
                context.setFillColor(color.cgColor)
                context.fill(currentRect)
                
                xCursor += segmentWidth
            }
            
            // Draw vertical axis lines (optional/background grid)?
            // Design shows white thin vertical lines at boundaries sometimes? 
            // Or maybe the time grid lines are handled by parent?
            // "这四种颜色要定义为常量...连接线宽度1pt"
            
            // Border lines for the whole graph?
            // "Design draft graph border color is #BCBCBC, width 1pt"
            context.setStrokeColor(UIColor(red: 188/255.0, green: 188/255.0, blue: 188/255.0, alpha: 1.0).cgColor)
            context.setLineWidth(1)
            // Left Axis
            context.move(to: CGPoint(x: 0, y: 0))
            context.addLine(to: CGPoint(x: 0, y: height))
            context.strokePath()
            // Right Axis
            context.move(to: CGPoint(x: width, y: 0))
            context.addLine(to: CGPoint(x: width, y: height))
            context.strokePath()
            // Bottom Axis
            context.move(to: CGPoint(x: 0, y: height))
            context.addLine(to: CGPoint(x: width, y: height))
            context.strokePath()
        }
    }
}
