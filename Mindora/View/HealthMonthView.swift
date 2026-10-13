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
        // .scaleToFill would stretch this non-uniformly: the container's width tracks
        // screen width (much wider on iPad) while its height stays content-driven.
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
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
        // .scaleToFill would stretch this non-uniformly: the container's width tracks
        // screen width (much wider on iPad) while its height stays content-driven.
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
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
        label.text = "Sedona Red Rocks\nMaldives Moonlit Drift\nCanadian Forest Solace"
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
    
    /// 自增代号：每次 loadRealData 领号，异步回来只认最新一号。
    /// 防止两次 reloadData（切 tab / 重新出现 / 订阅变化）并发时，旧任务的中间态把新任务
    /// 已写好的真实评分覆盖回 "--"，造成「平均睡眠评分一会显示一会不显示」的闪烁。
    private var realLoadGeneration = 0

    // MARK: - Reload Data
    func reloadData() {
        let showMock = Constants.Config.showMockData
        if showMock {
            let mockLocal = HealthMockDataService.shared.monthLocalData()
            // 假数据以今天收尾，走的仍是同一个窗口定义。
            let window = HealthChartWindow.month(anchor: Date())
            let analysis = HealthAnalysisService.shared.mockMonthAnalysis(startDate: window.start, endDate: window.end)

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
            // 用同步缓存的锚点先算区间 + 填日期标签 + 用缓存评分即时渲染；loadRealData 再用最新锚点刷新。
            let window = HealthChartWindow.month(anchor: currentAnchor())
            dateLabel.text = window.displayText
            if let cached = HealthAnalysisService.shared.cachedMonthAnalysis(startDate: window.start, endDate: window.end) {
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

    /// 同步取锚点：优先「最近睡眠日」缓存，没有则退回今天（首启或确无数据时）。
    private func currentAnchor() -> Date {
        HealthDataManager.shared.cachedMostRecentSleepDay ?? Calendar.current.startOfDay(for: Date())
    }

    private func loadRealData() {
        realLoadGeneration += 1
        let gen = realLoadGeneration
        Task { @MainActor in
            // 解析「最近睡眠日」作为锚点（拿不到就用今天），把月窗口对齐过去——像 Apple 那样
            // 显示最近一段有数据的区间，而不是死锚今天导致全空。
            // 用 do/catch 而不是 `try?`：要区分「查询报错」和「真的一条睡眠样本都没有」，
            // 后面的权限引导判定全靠这个区分（报错时绝不能提醒用户去开权限）。
            var recentSleepDay: Date?
            var localQueryFailed = false
            do {
                recentSleepDay = try await HealthDataManager.shared.fetchMostRecentSleepDay(forceLive: true)
            } catch {
                localQueryFailed = true
                Log.error("HealthMonthView", "最近睡眠日解析失败：\(error)")
            }
            let anchor = recentSleepDay ?? self.currentAnchor()
            guard gen == self.realLoadGeneration else { return }
            let window = HealthChartWindow.month(anchor: anchor)
            dateLabel.text = window.displayText
            // 锚点确定后，先用对齐后的缓存评分即时刷新。
            let cachedAnalysis = HealthAnalysisService.shared.cachedMonthAnalysis(startDate: window.start, endDate: window.end)
            if let cachedAnalysis {
                scoreValueLabel.text = cachedAnalysis.scoreSummary?.score.map(String.init) ?? scoreValueLabel.text
                scoreStateLabel.text = cachedAnalysis.scoreSummary?.label ?? scoreStateLabel.text
                self.cachedSleepMetrics = cachedAnalysis.sleepMetrics
            }

            // 三态统一走 resolve（见 ServerDataResolution.swift）。
            let analysisTask = Task {
                await HealthAnalysisService.shared.resolveMonthAnalysis(startDate: window.start, endDate: window.end)
            }

            // 用非结构化 Task 而不是 `async let`：优化构建下 async let 的子任务栈回收
            // 顺序会与内联后的调用帧错位，作用域一旦带着错误退出就撞上
            // swift_task_dealloc 的致命断言直接 abort（见 HealthDataManager 里的说明）。
            let metricsTask = Task { try await HealthDataManager.shared.fetchLatestSleepVitalsMetrics(forceLive: true) }
            let aggregatesTask = Task { try await HealthDataManager.shared.fetchSleepDailyAggregates(startingFrom: window.start, days: window.dayCount) }

            // 每项本地数据独立成败：读到什么就展示什么（原来一个 do 块连着 try，
            // 生命体征一抛错，已取到的睡眠聚合连读都没读，月图整块空白）。
            var metrics = HealthMetrics.empty
            do {
                metrics = try await metricsTask.value
            } catch {
                Log.error("HealthMonthView", "生命体征读取失败，降级后继续渲染睡眠数据：\(error)")
            }
            var aggregates: [HealthDataManager.SleepDailyAggregate] = []
            do {
                aggregates = try await aggregatesTask.value
            } catch {
                localQueryFailed = true
                Log.error("HealthMonthView", "睡眠日聚合读取失败：\(error)")
            }
            let vitals = try? await HealthDataManager.shared.fetchSleepVitalsAverages(days: window.dayCount, endingAt: window.end)
            guard gen == self.realLoadGeneration else { return }

            // 第一遍带上缓存兜底值：本地读不到 Time in bed 时，先用上次服务端估算顶着，
            // 等下面拿到最新 analysis 再覆盖。传 nil 会让这一格先空一下再填。
            applyRealMonthData(window: window, metrics: metrics, aggregates: aggregates, vitals: vitals, analysis: nil, fallbackSleepMetrics: self.cachedSleepMetrics)

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
            applyRealMonthData(window: window, metrics: metrics, aggregates: aggregates, vitals: vitals, analysis: analysis, fallbackSleepMetrics: self.cachedSleepMetrics)
            // 评分以最终分析为准：拿到分数就显示；分析缺失时保留已渲染的缓存评分，没缓存才回退 "--"。
            if let analysis {
                scoreValueLabel.text = analysis.scoreSummary?.score.map(String.init) ?? "--"
                scoreStateLabel.text = analysis.scoreSummary?.label ?? "--"
            } else if HealthAnalysisService.shared.cachedMonthAnalysis(startDate: window.start, endDate: window.end) == nil {
                scoreValueLabel.text = "--"
                scoreStateLabel.text = "--"
            }
        }
    }

    private func applyRealMonthData(window: HealthChartWindow, metrics: HealthMetrics, aggregates: [HealthDataManager.SleepDailyAggregate], vitals: HealthDataManager.SleepVitalsAverages?, analysis: HealthAnalysisService.MonthAnalysis?, fallbackSleepMetrics: HealthAnalysisService.PeriodSleepMetrics? = nil) {
        let tracked = aggregates.filter(\.hasData)
        // 评分不在这里设置：中间态（analysis==nil）会把已显示的评分清成 "--" 造成闪烁。
        // 由 loadRealData 在最终拿到 analysis 后统一设置。

        // 值和日期出自同一个窗口：aggregates 就是按 window 取的，横轴与气泡也用 window.days。
        chartView.setRealValues(aggregates.map { CGFloat(min(max($0.totalSleepHours, 0), 10)) }, days: window.days)
        if let scoreSeries = analysis?.sleepTrends?.scoreSeries {
            trendChartView.setScoreSeries(scoreSeries)
        }

        // 同 Week：服务端返回空串 = 明确没有分析内容，客户端不再用本地数字凑一段顶上，
        // 缺失一律 "--"。空串≠缺字段，所以仍要先过 nonBlank 再判断。
        insightsBodyLabel.text = analysis?.sleepTrends?.body.nonBlank ?? "--"
        insightsDescLabel.text = analysis?.sleepTrends?.description.nonBlank ?? "--"

        if let scenarioList = analysis?.onsetEfficiency?.scenarioList, !scenarioList.isEmpty {
            setBestListText(scenarioList.joined(separator: "\n"))
        } else {
            setBestListText("--")
        }
        bestContentLabel.text = analysis?.onsetEfficiency?.description.nonBlank ?? "--"

        rebuildContent(showMock: false, aggregates: tracked, metrics: metrics, vitals: vitals, sleepMetrics: analysis?.sleepMetrics ?? fallbackSleepMetrics)
    }

    /// 上一次拿到的服务端日均兜底值。本地读不到、服务端这次还没应答时先用它顶着，
    /// 否则 Time in bed 卡会先闪一下 "--" 再填上（见 `feedback_cache_async_data_avoid_flicker`）。
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
    
    private func rebuildContent(showMock: Bool, aggregates: [HealthDataManager.SleepDailyAggregate] = [], metrics: HealthMetrics? = nil, vitals: HealthDataManager.SleepVitalsAverages? = nil, sleepMetrics: HealthAnalysisService.PeriodSleepMetrics? = nil) {
        let mockLocal = HealthMockDataService.shared.monthLocalData()
        insightsContainer.isHidden = false
        bestContainer.isHidden = false
        vitalsContainer.isHidden = false
        trendsContainer.isHidden = false
        efficiencyContainer.isHidden = false

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
        let sleepHeartRateValue = vitals?.sleepHeartRate.map { UnitDisplay.bpm($0) } ?? "--"
        let respiratoryValue = vitals?.respiratoryRate.map { UnitDisplay.breathsPerMinute($0) } ?? "--"
        let restingHeartRateValue = vitals?.restingHeartRate.map { UnitDisplay.bpm($0) } ?? "--"
        let wristTemperatureValue = vitals?.wristTemperature.map { UnitDisplay.temperature(celsius: $0) } ?? "--"
        let vitalsDetailRows: [(String, String, String?)] = showMock ? [
            (L("health.week.respiratory_rate"), mockLocal.respiratoryRateText, nil),
            (L("health.sleep.resting_heart_rate"), mockLocal.restingHeartRateText, nil),
            (L("health.week.avg_wrist_temp"), mockLocal.wristTemperatureText, nil)
        ] : [
            (L("health.week.respiratory_rate"), respiratoryValue, nil),
            (L("health.sleep.resting_heart_rate"), restingHeartRateValue, nil),
            (L("health.week.avg_wrist_temp"), wristTemperatureValue, nil)
        ]

        let vitalsCard = WeekExpandableCard(
            icon: "sleep_week_heartrate",
            title: L("health.sleep.sleep_heart_rate"),
            value: showMock ? mockLocal.heartRateText : sleepHeartRateValue,
            detailRows: vitalsDetailRows
        )
        configureCard(vitalsCard, in: vitalsContainer)

        let trendsCard = WeekExpandableCard(
            icon: "sleep_week_sleep",
            title: L("health.month.total_sleep"),
            // 苹果健康月视图给的是「日均」，这里跟它对齐；卡片里的明细行本来就是均值
            value: showMock ? mockLocal.totalSleepText : formatHours(avgTotal),
            detailRows: showMock ? [
                (L("health.week.avg_awake"), mockLocal.averageAwakeText, nil),
                (L("health.week.avg_rem"), mockLocal.averageRemText, nil),
                (L("health.week.avg_core"), mockLocal.averageCoreText, nil),
                (L("health.week.avg_deep"), mockLocal.averageDeepText, nil)
            ] : [
                (L("health.week.avg_awake"), formatMinutesText(avgAwake), nil),
                (L("health.week.avg_rem"), avgRem > 0 ? formatHours(avgRem) : "--", nil),
                (L("health.week.avg_core"), avgCore > 0 ? formatHours(avgCore) : "--", nil),
                (L("health.week.avg_deep"), avgDeep > 0 ? formatHours(avgDeep) : "--", nil)
            ]
        )
        configureCard(trendsCard, in: trendsContainer)

        let efficiencyCard = WeekExpandableCard(
            icon: "sleep_week_timeinbed",
            title: L("health.week.header.time_in_bed"),
            value: showMock ? mockLocal.timeInBedText : avgTimeInBedText,
            detailRows: showMock ? [
                (L("health.month.days_tracked"), mockLocal.trackedDaysText, nil),
                (L("health.week.avg_total"), mockLocal.averageTotalText, nil),
                (L("health.week.avg_onset"), mockLocal.averageOnsetText, nil)
            ] : [
                (L("health.month.days_tracked"), UnitDisplay.daysTracked(trackedDays, of: 30), nil),
                (L("health.week.avg_total"), formatHours(avgTotal), nil),
                (L("health.week.avg_onset"), avgOnsetText, nil)
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
        
        let imgView = UIImageView(image: UIImage(named: "icon_arrow_right"))
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
        
        let imgView = UIImageView(image: UIImage(named: "icon_arrow_right"))
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
        // 数据加载前的占位。口径必须与加载后一致：睡眠心率/呼吸/静息心率都是
        // 周期平均的单值，不是区间，否则加载完成的一瞬间数字形态会跳变。
        let card1 = WeekExpandableCard(
            icon: "sleep_week_heartrate",
            title: L("health.sleep.sleep_heart_rate"),
            value: UnitDisplay.bpm(92),
            detailRows: [
                (L("health.week.respiratory_rate"), UnitDisplay.breathsPerMinute(14), nil),
                (L("health.sleep.resting_heart_rate"), UnitDisplay.bpm(58), nil),
                (L("health.week.avg_wrist_temp"), UnitDisplay.temperature(celsius: 34.1), nil)
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
                (L("health.week.avg_awake"), UnitDisplay.duration(minutes: 18), nil),
                (L("health.week.avg_rem"), UnitDisplay.duration(minutes: 110), nil),
                (L("health.week.avg_core"), UnitDisplay.duration(minutes: 243), nil),
                (L("health.week.avg_deep"), UnitDisplay.duration(minutes: 51), nil)
            ]
        )
        trendsContainer.addSubview(card2)
        card2.translatesAutoresizingMaskIntoConstraints = false
        card2.pinToSuperview()
        
        // Card 3
        let card3 = WeekExpandableCard(
            icon: "sleep_week_timeinbed",
            title: L("health.week.header.time_in_bed"),
            value: UnitDisplay.duration(minutes: 465),
            detailRows: [
                (L("health.month.days_tracked"), UnitDisplay.daysTracked(15, of: 30), nil),
                (L("health.week.avg_total"), UnitDisplay.duration(minutes: 422), nil),
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
        /// 原始日期。星期几从它直接取，不再拿 `dateString` 反解 ——
        /// dateString 现在按 App 语言渲染（「8月6日」/「Aug 6, 2026」），
        /// 固定格式的 parser 一换语言就解不出来了。
        let date: Date
    }
    
    private var items: [BarData] = []
    private var realValues: [CGFloat] = []

    /// 本图这一个月的每一天，来自页头窗口。**必须由外部传进来。**
    ///
    /// 原来 `buildItems()` 用 `Date()` 往前推 30 天，而页头区间和取数窗口都锚在
    /// 「最近睡眠日」。今天 9/9、最近数据在 9/5 时，页头显示 8/7–9/5，柱子却被标成
    /// 8/11–9/9：整条曲线的日期集体偏了 4 天，末尾还落到了未来。
    ///
    /// 长度不再是定值 30 ——「一个月」是日历运算，2 月只有 28 格（见 HealthChartWindow）。
    private var realDays: [Date] = []

    /// 假数据以今天收尾。`Date()` 只允许出现在这一条路径上。
    private static var mockDays: [Date] { HealthChartWindow.month(anchor: Date()).days }
    
    private var chartContainer: UIView!
    private var tooltipView: UIView?
    private var dotView: UIView?
    private let connectorLayer = CAShapeLayer()
    
    // Track selected index
    private var selectedIndex: Int?

    /// 星期几缩写。是给用户看的，跟着 App 语言走（「周三」/「Wed」/「水」）。
    private static func weekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var showMockData: Bool = true {
        didSet {
            buildItems()
            rebuildChart()
        }
    }

    /// - Parameters:
    ///   - values: 每天的睡眠小时数，与 `days` 一一对应。
    ///   - days: 页头窗口的那些天（`HealthChartWindow.month(anchor:).days`）。
    func setRealValues(_ values: [CGFloat], days: [Date]) {
        realValues = values
        realDays = days
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
        guard !values.isEmpty else { return }
        mockValues = values
        if showMockData {
            buildItems()
            rebuildChart()
        }
    }
    
    private func buildItems() {
        items.removeAll()
        let calendar = Calendar.current

        let days = showMockData ? Self.mockDays : realDays
        guard !days.isEmpty else { return }

        // 值与日期必须等长：拿不到真实值时铺 0，格子数仍按窗口走。
        let values: [CGFloat]
        if showMockData {
            values = mockValues.count == days.count ? mockValues : Array(repeating: 0.0, count: days.count)
        } else if realValues.count == days.count {
            values = realValues
        } else {
            values = Array(repeating: 0.0, count: days.count)
        }

        // 刻度**从最后一格往回**每 7 天一个，而不是从头 `i % 4`：
        // 窗口右端贴着锚点，从头数会让最后一个刻度落在随机位置，和页头终点对不上；
        // 从尾数则末刻度恒等于页头终点，且每个刻度都落在同一个星期几上。
        let tickIndices = Set(stride(from: days.count - 1, through: 0, by: -7))

        for (i, date) in days.enumerated() {
            let day = calendar.component(.day, from: date)
            let labelText = tickIndices.contains(i) ? String(format: "%02d", day) : ""
            items.append(BarData(value: values[i], label: labelText, dateString: DateDisplay.date(date), date: date))
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
        titleLabel.text = String(format: L("health.chart.tooltip.duration"), "\(hours)", "\(minutes)")
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .left
        
        let dateSubtitle = UILabel()
        dateSubtitle.text = "\(Self.weekdayText(for: item.date)), \(item.dateString)"
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

    /// tooltip 上的日期，是给用户看的 → 跟 App 语言。
    /// （下面的 `parsedDate` 解析的是服务端的 `yyyy-MM-dd`，那个必须留 POSIX。）
    private static func tooltipDateText(for date: Date) -> String {
        DateDisplay.date(date)
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

