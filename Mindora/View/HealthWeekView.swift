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
        // .scaleToFill would stretch this non-uniformly: the container's width tracks
        // screen width (much wider on iPad) while its height stays content-driven.
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
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
        // .scaleToFill would stretch this non-uniformly: the container's width tracks
        // screen width (much wider on iPad) while its height stays content-driven.
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
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
    /// 自增代号：异步回来只认最新一号，防止并发 reloadData 的旧任务中间态把新评分覆盖回 "--"。
    private var realLoadGeneration = 0

    /// 同步取锚点：优先「最近睡眠日」缓存，没有则退回今天。
    private func currentAnchor() -> Date {
        HealthDataManager.shared.cachedMostRecentSleepDay ?? Calendar.current.startOfDay(for: Date())
    }

    func reloadData() {
        let showMock = Constants.Config.showMockData
        if showMock {
            let mockLocal = HealthMockDataService.shared.weekLocalData()
            // 假数据以今天收尾，走的仍是同一个窗口定义。
            let window = HealthChartWindow.week(anchor: Date())
            let analysis = HealthAnalysisService.shared.mockWeekAnalysis(startDate: window.start, endDate: window.end)

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
            // 用同步缓存的锚点先算区间 + 填日期标签 + 用缓存评分即时渲染；loadRealData 再用最新锚点刷新。
            let window = HealthChartWindow.week(anchor: currentAnchor())
            dateLabel.text = window.displayText
            if let cached = HealthAnalysisService.shared.cachedWeekAnalysis(startDate: window.start, endDate: window.end) {
                scoreValueLabel.text = cached.scoreSummary?.score.map(String.init) ?? "--"
                scoreStateLabel.text = cached.scoreSummary?.label ?? "--"
                cachedSleepMetrics = cached.sleepMetrics
            }
        }
        chartView.showMockData = showMock
        rebuildContent(showMock: showMock, sleepMetrics: cachedSleepMetrics)
        if !showMock {
            loadRealData()
        }
    }

    private func loadRealData() {
        realLoadGeneration += 1
        let gen = realLoadGeneration
        Task { @MainActor in
            // 解析「最近睡眠日」作为锚点（拿不到就用今天），把周窗口对齐到那一周（周一→周日）。
            // 用 do/catch 而不是 `try?`：要区分「查询报错」和「真的一条睡眠样本都没有」，
            // 后面的权限引导判定全靠这个区分（报错时绝不能提醒用户去开权限）。
            var recentSleepDay: Date?
            var localQueryFailed = false
            do {
                recentSleepDay = try await HealthDataManager.shared.fetchMostRecentSleepDay(forceLive: true)
            } catch {
                localQueryFailed = true
                Log.error("HealthWeekView", "最近睡眠日解析失败：\(error)")
            }
            let anchor = recentSleepDay ?? self.currentAnchor()
            guard gen == self.realLoadGeneration else { return }
            let window = HealthChartWindow.week(anchor: anchor)
            dateLabel.text = window.displayText
            let cachedAnalysis = HealthAnalysisService.shared.cachedWeekAnalysis(startDate: window.start, endDate: window.end)
            if let cachedAnalysis {
                scoreValueLabel.text = cachedAnalysis.scoreSummary?.score.map(String.init) ?? scoreValueLabel.text
                scoreStateLabel.text = cachedAnalysis.scoreSummary?.label ?? scoreStateLabel.text
                self.cachedSleepMetrics = cachedAnalysis.sleepMetrics
            }

            // 三态统一走 resolve（见 ServerDataResolution.swift）。
            let analysisTask = Task {
                await HealthAnalysisService.shared.resolveWeekAnalysis(startDate: window.start, endDate: window.end)
            }

            // 用非结构化 Task 而不是 `async let`：优化构建下 async let 的子任务栈回收
            // 顺序会与内联后的调用帧错位，作用域一旦带着错误退出就撞上
            // swift_task_dealloc 的致命断言直接 abort（见 HealthDataManager 里的说明）。
            let metricsTask = Task { try await HealthDataManager.shared.fetchLatestSleepVitalsMetrics(forceLive: true) }
            let aggregatesTask = Task { try await HealthDataManager.shared.fetchSleepDailyAggregates(startingFrom: window.start, days: window.dayCount) }

            // 每项本地数据独立成败：读到什么就展示什么。以前这几行套在一个 do 块里连着
            // `try await`，生命体征一抛错就整体跳进 catch —— 明明已经取到的睡眠聚合
            // 连读都没读，图表因此整块空白，而 catch 里又不打日志，故障在日志里是隐形的。
            var metrics = HealthMetrics.empty
            do {
                metrics = try await metricsTask.value
            } catch {
                Log.error("HealthWeekView", "生命体征读取失败，降级后继续渲染睡眠数据：\(error)")
            }
            var aggregates: [HealthDataManager.SleepDailyAggregate] = []
            do {
                aggregates = try await aggregatesTask.value
            } catch {
                localQueryFailed = true
                Log.error("HealthWeekView", "睡眠日聚合读取失败：\(error)")
            }
            // 生命体征卡按「睡眠期间 + 按晚等权平均」取，不再用最新一条样本。
            let vitals = try? await HealthDataManager.shared.fetchSleepVitalsAverages(days: window.dayCount, endingAt: window.end)
            guard gen == self.realLoadGeneration else { return }

            // 第一遍带上缓存兜底值：本地读不到 Time in Bed 时，先用上次服务端估算顶着，
            // 等下面拿到最新 analysis 再覆盖。传 nil 会让这一格先空一下再填。
            applyRealWeekData(window: window, metrics: metrics, aggregates: aggregates, vitals: vitals, analysis: nil, fallbackSleepMetrics: self.cachedSleepMetrics)

            // 一条本地睡眠数据都没有 → 走「读不到健康数据」引导。
            // 具体弹不弹由 PermissionManager 判：查询是否报过错、45 天内是否真的没有样本、
            // 以及去重与冷却。这里只负责报告「这个窗口是空的」。
            if !aggregates.contains(where: { $0.hasData }) {
                PermissionManager.shared.promptIfHealthDataUnreadable(
                    from: self,
                    queryFailed: localQueryFailed,
                    hasRecentSleepSamples: recentSleepDay != nil
                )
            }

            let analysis = await analysisTask.value.displayValue
            guard gen == self.realLoadGeneration else { return }
            if let analysis { self.cachedSleepMetrics = analysis.sleepMetrics }
            applyRealWeekData(window: window, metrics: metrics, aggregates: aggregates, vitals: vitals, analysis: analysis, fallbackSleepMetrics: self.cachedSleepMetrics)
            // 评分以最终分析为准：拿到分数就显示；分析缺失时保留已渲染的缓存评分，没缓存才回退 "--"。
            if let analysis {
                scoreValueLabel.text = analysis.scoreSummary?.score.map(String.init) ?? "--"
                scoreStateLabel.text = analysis.scoreSummary?.label ?? "--"
            } else if HealthAnalysisService.shared.cachedWeekAnalysis(startDate: window.start, endDate: window.end) == nil {
                scoreValueLabel.text = "--"
                scoreStateLabel.text = "--"
            }
        }
    }

    private func applyRealWeekData(window: HealthChartWindow, metrics: HealthMetrics, aggregates: [HealthDataManager.SleepDailyAggregate], vitals: HealthDataManager.SleepVitalsAverages?, analysis: HealthAnalysisService.WeekAnalysis?, fallbackSleepMetrics: HealthAnalysisService.PeriodSleepMetrics? = nil) {
        let tracked = aggregates.filter(\.hasData)
        let sleepValues = aggregates.map { CGFloat(min(max($0.totalSleepHours, 0), 10)) }
        // 值和日期出自同一个窗口：aggregates 就是按 window 取的，横轴与气泡也用 window.days。
        chartView.setRealValues(sleepValues, days: window.days)

        // 评分不在这里设置：中间态（analysis==nil）会把已显示的评分清成 "--" 造成闪烁。
        // 由 loadRealData 在最终拿到 analysis 后统一设置。

        // 服务端返回空串 = 明确说「这段没有分析内容」，不是「没带这个字段」。
        // 客户端不再拿本地数字凑一段叙述顶上去：那既占了服务端字段的位置，
        // 又让用户以为读到的是分析结论。缺失一律显示 "--"，与本页其余缺失项一致。
        insightsBodyLabel.text = analysis?.sleepTrends?.body.nonBlank ?? "--"
        insightsDescLabel.text = analysis?.sleepTrends?.description.nonBlank ?? "--"

        bestTitleLabel.text = L("health.week.best_title")
        bestSubtitleLabel.text = L("health.week.best_sub")
        bestContentLabel.text = analysis?.onsetEfficiency?.scenarioName.nonBlank ?? "--"
        rebuildBestStats(
            trackedDays: analysis?.onsetEfficiency?.usedTimes ?? tracked.count,
            score: analysis?.onsetEfficiency?.score.map(Double.init)
        )

        rebuildContent(showMock: false, aggregates: tracked, metrics: metrics, vitals: vitals, sleepMetrics: analysis?.sleepMetrics ?? fallbackSleepMetrics)
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

    /// 上一次拿到的服务端日均兜底值。本地读不到、服务端这次还没应答时先用它顶着，
    /// 否则 Time in Bed 卡会先闪一下 "--" 再填上（见 `feedback_cache_async_data_avoid_flicker`）。
    private var cachedSleepMetrics: HealthAnalysisService.PeriodSleepMetrics?

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func formatHours(_ hours: Double) -> String {
        UnitDisplay.duration(hours: hours)
    }

    private func formatMinutesText(_ minutes: Double) -> String {
        UnitDisplay.minutes(Int(minutes.rounded()))
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
    
    private func rebuildContent(showMock: Bool, aggregates: [HealthDataManager.SleepDailyAggregate] = [], metrics: HealthMetrics? = nil, vitals: HealthDataManager.SleepVitalsAverages? = nil, sleepMetrics: HealthAnalysisService.PeriodSleepMetrics? = nil) {
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
            // 不可测的夜晚 sleepOnsetMinutes 已是 nil，compactMap 直接跳过，不参与平均
            let avgOnset = average(aggregates.compactMap(\.sleepOnsetMinutes))
            // Apple Watch 不写 inBed 样本，只戴表的用户这两项本地恒空（不是「卧床 0 分钟」）。
            // 本地求得出就用本地的，一晚都求不出才用服务端估算的日均值，两者都没有才显示 --。
            // 口径见 Tools/doc/服务端分析接口.md「睡眠指标估算（sleep_metrics）」。
            let localAvgTimeInBed = average(aggregates.map(\.timeInBedHours)).flatMap { $0 > 0 ? $0 : nil }
            let avgTimeInBedText = (localAvgTimeInBed ?? sleepMetrics?.avgTimeInBedMinutes.map { Double($0) / 60.0 })
                .map(formatHours) ?? "--"
            let avgOnsetText = (avgOnset ?? sleepMetrics?.avgSleepOnsetMinutes.map(Double.init))
                .map(formatMinutesText) ?? "--"

            // 生命体征卡：全部取自 fetchSleepVitalsAverages —— 限定睡眠期间、按晚等权平均。
            // 心率是周期内的平均值（单值），不是某一晚的区间；区间只在日视图展示。
            let vitalsCard = WeekExpandableCard(
                icon: "home_heart_rate",
                title: L("health.sleep.sleep_heart_rate"),
                value: vitals?.sleepHeartRate.map { UnitDisplay.bpm($0) } ?? "--",
                detailRows: [
                    (L("health.week.respiratory_rate"), vitals?.respiratoryRate.map { UnitDisplay.breathsPerMinute($0) } ?? "--", nil),
                    (L("health.sleep.resting_heart_rate"), vitals?.restingHeartRate.map { UnitDisplay.bpm($0) } ?? "--", nil),
                    (L("health.week.avg_wrist_temp"), vitals?.wristTemperature.map { UnitDisplay.temperature(celsius: $0) } ?? "--", nil)
                ]
            )
            contentStackView.addArrangedSubview(vitalsCard)

            let trendsCard = WeekExpandableCard(
                icon: "sleep_week_sleep",
                title: L("health.week.header.total_sleep"),
                // 苹果健康周视图给的是「日均」，这里跟它对齐；卡片里的明细行本来就是均值
                value: formatHours(avgTotal),
                detailRows: [
                    (L("health.week.avg_awake"), formatMinutesText(avgAwake), nil),
                    (L("health.week.avg_rem"), avgRem > 0 ? formatHours(avgRem) : "--", nil),
                    (L("health.week.avg_core"), avgCore > 0 ? formatHours(avgCore) : "--", nil),
                    (L("health.week.avg_deep"), avgDeep > 0 ? formatHours(avgDeep) : "--", nil)
                ]
            )
            contentStackView.addArrangedSubview(trendsCard)

            let efficiencyCard = WeekExpandableCard(
                icon: "sleep_week_timeinbed",
                title: L("health.week.header.time_in_bed"),
                value: avgTimeInBedText,
                detailRows: [
                    (L("health.week.days_tracked"), UnitDisplay.daysTracked(trackedDays, of: 7), nil),
                    (L("health.week.avg_total"), formatHours(avgTotal), nil),
                    (L("health.week.avg_onset"), avgOnsetText, nil)
                ]
            )
            contentStackView.addArrangedSubview(efficiencyCard)
            return
        }
        
        // Group 1: Vitals
        let vitalsCard = WeekExpandableCard(
            icon: "home_heart_rate",
            title: L("health.sleep.sleep_heart_rate"),
            value: mockLocal.heartRateText,
            detailRows: [
                (L("health.week.respiratory_rate"), mockLocal.respiratoryRateText, nil),
                (L("health.sleep.resting_heart_rate"), mockLocal.restingHeartRateText, nil),
                (L("health.week.avg_wrist_temp"), mockLocal.wristTemperatureText, nil)
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
        // .scaleToFill would stretch this non-uniformly: headerWrapper's width tracks
        // screen width (much wider on iPad) while its height is a fixed >=74pt constant.
        let bgImageView = UIImageView(image: UIImage(named: "sleep_detail_bg"))
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.clipsToBounds = true
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
    /// 一根柱子。`date` 是它对应的那一天 —— 横轴的星期名和气泡里的日期都由它算，
    /// **不再按索引去固定数组里取**：窗口是滚动的（右端贴着锚点），第 0 格不恒是周一。
    struct BarData {
        let value: CGFloat // 0-10
        let date: Date
        var label: String { DateDisplay.weekdayShort(date) }
    }

    /// 假数据以今天收尾。`Date()` 只允许出现在这一条路径上：真实数据的日期一律由
    /// 外部把窗口传进来（`setRealValues(_:days:)`），图表自己不许现算 —— 页头按锚点、
    /// 图表按今天，两个基准一漂移，柱子就被标上错误甚至未来的日期。
    private static var mockDays: [Date] { HealthChartWindow.week(anchor: Date()).days }

    private lazy var mockItems: [BarData] = zip(
        [7.2, 9.0, 5.2, 3.8, 7.5, 7.2, 0.0] as [CGFloat],
        Self.mockDays
    ).map { BarData(value: $0.0, date: $0.1) }

    private static func emptyItems(days: [Date]) -> [BarData] {
        days.map { BarData(value: 0.0, date: $0) }
    }

    private var items: [BarData] = []
    private var realItems: [BarData] = HealthWeekChartView.emptyItems(days: HealthWeekChartView.mockDays)

    func setMockValues(_ values: [CGFloat]) {
        let days = Self.mockDays
        guard values.count == days.count else { return }
        mockItems = zip(values, days).map { BarData(value: $0.0, date: $0.1) }
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

    /// - Parameters:
    ///   - values: 每天的睡眠小时数，与 `days` 一一对应。
    ///   - days: 页头窗口的那几天（`HealthChartWindow.week(anchor:).days`）。
    ///           柱子、横轴星期名、气泡日期全部由它推导，保证三者与页头区间恒等。
    func setRealValues(_ values: [CGFloat], days: [Date]) {
        guard values.count == days.count else {
            realItems = HealthWeekChartView.emptyItems(days: days)
            if !showMockData {
                items = realItems
                rebuildChart()
            }
            return
        }

        realItems = zip(values, days).map { BarData(value: $0.0, date: $0.1) }
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
        titleLabel.text = String(format: L("health.chart.tooltip.duration"), "\(hours)", "\(minutes)")
        
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .left
        
        let dateSubtitle = UILabel()
        // 日期直接取这根柱子自己的那一天，不做任何索引推算。
        let targetDate = item.date
        // 原来是手拼 "Wed, 6th Aug 2026"：序数后缀 st/nd/rd/th 和「星期, 日 月 年」的
        // 顺序都是英文写死的，中日韩下会出现「周三, 6th 8月 2026」。改成让 ICU 按语言
        // 排语序 —— dateFormat(fromTemplate:) 会给出该语言正确的字段顺序和分隔符。
        let locale = LocalizationManager.shared.currentLocale
        let subtitleFormatter = DateFormatter()
        subtitleFormatter.locale = locale
        subtitleFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "EEEdMMMy", options: 0, locale: locale)
            ?? "EEE, d MMM yyyy"
        dateSubtitle.text = subtitleFormatter.string(from: targetDate)
        
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
