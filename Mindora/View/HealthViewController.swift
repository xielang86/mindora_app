import UIKit

final class HealthViewController: UIViewController {
    // MARK: - Design Constants (设计稿尺寸)
    fileprivate let designWidth: CGFloat = 1242
    fileprivate let designHeight: CGFloat = 2688
    fileprivate let designPeriodControlTop: CGFloat = 380      // 时间段控件距离顶部
    fileprivate let designPeriodControlWidth: CGFloat = 1128   // 时间段控件宽度
    fileprivate let designPeriodControlHeight: CGFloat = 110   // 时间段控件高度
    fileprivate let designPeriodControlCornerRadius: CGFloat = 55  // 时间段控件圆角
    fileprivate let designPeriodButtonWidth: CGFloat = 358     // 选中按钮宽度
    fileprivate let designPeriodButtonHeight: CGFloat = 89     // 选中按钮高度
    fileprivate let designPeriodButtonCornerRadius: CGFloat = 44.5  // 选中按钮圆角
    fileprivate let designPeriodFontSize: CGFloat = 42         // 字体大小
    
    // 睡眠圆弧视图设计稿尺寸
    fileprivate let designSleepArcTop: CGFloat = 640           // 圆弧距离顶部
    fileprivate let designSleepValueTop: CGFloat = 842         // 睡眠数值距离顶部
    fileprivate let designSleepValueFontSize: CGFloat = 172    // 睡眠数值字体大小
    fileprivate let designSleepUnitFontSize: CGFloat = 42      // 睡眠单位字体大小
    fileprivate let designSleepTotalFontSize: CGFloat = 72     // 总时长字体大小
    fileprivate let designSleepArcStrokeWidth: CGFloat = 12    // 圆弧描边宽度
    
    // 数据卡片设计稿尺寸
    fileprivate let designItemHeight: CGFloat = 285            // 每个数据卡片的高度
    fileprivate let designItemTitleFontSize: CGFloat = 52      // 标题字体大小（如"心率"）
    fileprivate let designItemValueFontSize: CGFloat = 107     // 数值字体大小（如"54-84"）
    fileprivate let designItemUnitFontSize: CGFloat = 33       // 单位字体大小（如"次/分"）
    fileprivate let designIconWidth: CGFloat = 80              // 图标宽度
    fileprivate let designItemLeading: CGFloat = 107           // 文字距离左边
    fileprivate let designIconTrailing: CGFloat = 120          // 图标距离右边
    fileprivate let designSeparatorMargin: CGFloat = 84        // 分隔线左右边距
    fileprivate let designFirstItemTop: CGFloat = 120          // 第一个数据卡片距离时间段控件的距离
    fileprivate let designValueBottomMargin: CGFloat = 30      // 数值距离底部的距离
    
    // 计算实际尺寸的辅助方法
    fileprivate func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    // MARK: - UI
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never  // 禁用自动内容插入调整
        scrollView.backgroundColor = .black
        return scrollView
    }()
    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private var metricViews: [MetricRowView] = []
    private let refreshControl = UIRefreshControl()
    
    // 加载指示器
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // 睡眠圆弧视图
    private let sleepArcView = SleepArcView()
    
    // 睡眠图表视图（替代静态图片）
    private let sleepGraphView: SleepGraphView = {
        let view = SleepGraphView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 时间段控件
    private let periodControl: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private var periodButtons: [UIButton] = []
    private var selectedPeriodIndex: Int = 0  // 0=日, 1=月, 2=年
    
    // 折线图视图（月度和年度）
    private var heartRateChartView: LineChartView!
    private var hrvChartView: LineChartView!
    private var sleepChartView: LineChartView!
    private let chartsContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        return view
    }()
    
    // 用于控制contentView底部约束的变量
    private var contentBottomConstraintForDayView: NSLayoutConstraint?
    private var contentBottomConstraintForChartView: NSLayoutConstraint?

    // MARK: - State
    private var isLoading = false
    private var hasLoadedData = false  // 标记是否已加载过数据
    private var lastMetrics: HealthMetrics?
    private var lastSleepStages: [HealthDataManager.SleepStageDetail] = []
    private var monthlyData: HealthDataManager.PeriodHealthData?
    private var yearlyData: HealthDataManager.PeriodHealthData?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("health.title")
        setupUI()
        registerNotifications()
        
        // 提前开始加载数据,不等到 viewDidAppear
        if !hasLoadedData {
            authorizeAndLoadIfNeeded()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 确保导航栏设置在每次显示时都正确
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
        // 如果数据已经过期(比如超过5分钟),重新加载
        if hasLoadedData && shouldRefreshData() {
            authorizeAndLoadIfNeeded()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 不在这里加载数据了,已经在 viewDidLoad 中加载
        
        // 检查健康权限并显示提醒（如果需要）
        checkHealthPermissionAndShowReminder()
    }
    
    // 上次数据加载时间
    private var lastDataLoadTime: Date?
    
    // 判断是否应该刷新数据(5分钟过期)
    private func shouldRefreshData() -> Bool {
        guard let lastLoad = lastDataLoadTime else { return true }
        return Date().timeIntervalSince(lastLoad) > 300 // 5分钟
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 将 ScrollView 添加到主视图，占据整个屏幕
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // 添加加载指示器到主视图(不是scrollView)
        view.addSubview(loadingIndicator)
        
        // 将所有内容添加到 contentView
        contentView.addSubview(periodControl)
        setupCustomPeriodControl()
        
        contentView.addSubview(sleepArcView)
        sleepArcView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(sleepGraphView)
        
        // 计算实际尺寸
        let periodControlTop = scale(designPeriodControlTop, basedOn: view.bounds.height, designDimension: designHeight)
        let periodControlWidth = scale(designPeriodControlWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let periodControlHeight = scale(designPeriodControlHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let sleepArcTop = scale(designSleepArcTop, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 计算睡眠圆弧视图的高度
        let sleepArcHeight = scale(500, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 计算图片的位置和尺寸
        let graphTopSpacing = scale(138, basedOn: view.bounds.height, designDimension: designHeight)
        let graphWidth = scale(968, basedOn: view.bounds.width, designDimension: designWidth)
        let graphHeight = scale(337, basedOn: view.bounds.height, designDimension: designHeight)
        
        NSLayoutConstraint.activate([
            // ScrollView 约束 - 占据整个视图
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView 约束
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 时间段控件约束 - 从 contentView 顶部开始
            periodControl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: periodControlTop),
            periodControl.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            periodControl.widthAnchor.constraint(equalToConstant: periodControlWidth),
            periodControl.heightAnchor.constraint(equalToConstant: periodControlHeight),
            
            // 睡眠圆弧视图约束 - 距离 contentView 顶部 640
            sleepArcView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: sleepArcTop),
            sleepArcView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sleepArcView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            sleepArcView.heightAnchor.constraint(equalToConstant: sleepArcHeight),
            
            // 睡眠图表视图 - 在睡眠圆弧视图底部下方，宽度固定为968（设计稿尺寸）
            sleepGraphView.topAnchor.constraint(equalTo: sleepArcView.bottomAnchor, constant: graphTopSpacing),
            sleepGraphView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            sleepGraphView.widthAnchor.constraint(equalToConstant: graphWidth),
            sleepGraphView.heightAnchor.constraint(equalToConstant: graphHeight),
            
            // 加载指示器 - 在睡眠圆弧区域中心
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: sleepArcTop + sleepArcHeight / 2)
        ])

        // Pull to refresh
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        scrollView.refreshControl = refreshControl
        
        // 设置折线图视图
        setupChartViews()

        // Metrics rows (styled like Settings view)
        setupMetricViews()

        applyTheme()
        reloadLocalizedTexts()
    }
    
    private func setupChartViews() {
        // 创建折线图视图
        heartRateChartView = LineChartView(type: .heartRate)
        hrvChartView = LineChartView(type: .hrv)
        sleepChartView = LineChartView(type: .sleep)
        
        // 添加到容器
        contentView.addSubview(chartsContainerView)
        chartsContainerView.addSubview(heartRateChartView)
        chartsContainerView.addSubview(hrvChartView)
        chartsContainerView.addSubview(sleepChartView)
        
        heartRateChartView.translatesAutoresizingMaskIntoConstraints = false
        hrvChartView.translatesAutoresizingMaskIntoConstraints = false
        sleepChartView.translatesAutoresizingMaskIntoConstraints = false
        
        // 计算图表尺寸和位置
        // 图表容器从顶部640px开始（与睡眠圆弧视图位置相同）
        let chartsTopOffset = scale(640, basedOn: view.bounds.height, designDimension: designHeight)
        // 图表宽度占屏幕宽度的95%，左右各留2.5%边距
        let graphWidth = view.bounds.width * 0.95

        // 每个图表的高度：包含标题区域(~400) + 图表绘制区域(~950) = 1350px
        let chartHeight = scale(1350, basedOn: view.bounds.height, designDimension: designHeight)
        let chartSpacing = scale(90, basedOn: view.bounds.height, designDimension: designHeight)
        
        NSLayoutConstraint.activate([
            // 容器视图约束 - 完全独立，从顶部640px开始
            chartsContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: chartsTopOffset),
            chartsContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            chartsContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            chartsContainerView.heightAnchor.constraint(equalToConstant: chartHeight * 3 + chartSpacing * 2),
            
            // 心率图表
            heartRateChartView.topAnchor.constraint(equalTo: chartsContainerView.topAnchor),
            heartRateChartView.centerXAnchor.constraint(equalTo: chartsContainerView.centerXAnchor),
            heartRateChartView.widthAnchor.constraint(equalToConstant: graphWidth),
            heartRateChartView.heightAnchor.constraint(equalToConstant: chartHeight),
            
            // HRV图表
            hrvChartView.topAnchor.constraint(equalTo: heartRateChartView.bottomAnchor, constant: chartSpacing),
            hrvChartView.centerXAnchor.constraint(equalTo: chartsContainerView.centerXAnchor),
            hrvChartView.widthAnchor.constraint(equalToConstant: graphWidth),
            hrvChartView.heightAnchor.constraint(equalToConstant: chartHeight),
            
            // 睡眠图表
            sleepChartView.topAnchor.constraint(equalTo: hrvChartView.bottomAnchor, constant: chartSpacing),
            sleepChartView.centerXAnchor.constraint(equalTo: chartsContainerView.centerXAnchor),
            sleepChartView.widthAnchor.constraint(equalToConstant: graphWidth),
            sleepChartView.heightAnchor.constraint(equalToConstant: chartHeight)
        ])
        
        // 初始隐藏折线图（只在月度和年度显示）
        chartsContainerView.isHidden = true
    }
    
    private func setupMetricViews() {
        let itemHeight = scale(designItemHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let firstItemTop = scale(designFirstItemTop, basedOn: view.bounds.height, designDimension: designHeight)
        
        let metrics: [(kind: MetricRowView.Kind, imageName: String)] = [
            (.heartRate, "health_data_icon"),
            (.hrv, "heart_rate_variability_icon"),
            (.sleep, "sleep_icon")
        ]
        
        var previousView: UIView?
        var firstMetricViewTopConstraint: NSLayoutConstraint?
        
        for (index, metric) in metrics.enumerated() {
            let metricView = MetricRowView(
                kind: metric.kind,
                imageName: metric.imageName,
                viewController: self
            )
            contentView.addSubview(metricView)
            metricViews.append(metricView)
            
            NSLayoutConstraint.activate([
                metricView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                metricView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                metricView.heightAnchor.constraint(equalToConstant: itemHeight)
            ])
            
            if index == 0 {
                // 第一个项目默认在睡眠图表下方（日视图）
                // 当切换到月/年视图时，会在折线图下方
                firstMetricViewTopConstraint = metricView.topAnchor.constraint(equalTo: sleepGraphView.bottomAnchor, constant: firstItemTop)
                firstMetricViewTopConstraint?.isActive = true
            } else if let previous = previousView {
                metricView.topAnchor.constraint(equalTo: previous.bottomAnchor).isActive = true
            }
            
            previousView = metricView
        }
        
        // 设置 contentView 的底部约束
        if let lastView = previousView {
            // 日视图的底部约束（基于最后一个metric view）
            contentBottomConstraintForDayView = contentView.bottomAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 100)
            contentBottomConstraintForDayView?.isActive = true
            
            // 月度/年度视图的底部约束（基于图表容器）
            contentBottomConstraintForChartView = contentView.bottomAnchor.constraint(equalTo: chartsContainerView.bottomAnchor, constant: 100)
            contentBottomConstraintForChartView?.isActive = false
        }
    }

    private func registerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Theme.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LocalizationManager.languageDidChangeNotification, object: nil)
    }
    
    // MARK: - Custom Period Control
    private func setupCustomPeriodControl() {
        let periodFontSize = scale(designPeriodFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        let periodCornerRadius = scale(designPeriodControlCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 外层大圆角矩形：透明背景 + 白色描边
        periodControl.backgroundColor = .clear
        periodControl.layer.cornerRadius = periodCornerRadius
        periodControl.layer.borderWidth = 0.5
        periodControl.layer.borderColor = UIColor.white.cgColor
        periodControl.clipsToBounds = true
        
        // 创建三个按钮：日、月、年
        let periods = [L("health.period.day"), L("health.period.month"), L("health.period.year")]
        periodButtons.removeAll()
        
        for (index, title) in periods.enumerated() {
            let button = UIButton(type: .custom)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: periodFontSize, weight: .regular)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tag = index
            button.addTarget(self, action: #selector(periodButtonTapped(_:)), for: .touchUpInside)
            periodControl.addSubview(button)
            periodButtons.append(button)
        }
        
        // 布局三个按钮（均匀分布）
        let buttonWidth = designPeriodButtonWidth
        let containerWidth = designPeriodControlWidth
        let sectionWidth = containerWidth / 3
        
        let scaledButtonWidth = scale(buttonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let scaledSectionWidth = scale(sectionWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonHeight = scale(designPeriodButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let buttonCornerRadius = scale(designPeriodButtonCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        
        for (index, button) in periodButtons.enumerated() {
            button.layer.cornerRadius = buttonCornerRadius
            button.clipsToBounds = true
            
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: scaledButtonWidth),
                button.heightAnchor.constraint(equalToConstant: buttonHeight),
                button.centerYAnchor.constraint(equalTo: periodControl.centerYAnchor)
            ])
            
            // 计算每个按钮在其区域内的居中位置
            let sectionCenterX = (CGFloat(index) + 0.5) * scaledSectionWidth
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: periodControl.leadingAnchor, constant: sectionCenterX)
            ])
        }
        
        // 设置初始选中状态
        updatePeriodButtonsAppearance()
    }
    
    private func updatePeriodButtonsAppearance() {
        for (index, button) in periodButtons.enumerated() {
            if index == selectedPeriodIndex {
                button.backgroundColor = UIColor(red: 59/255.0, green: 58/255.0, blue: 58/255.0, alpha: 1.0)
                button.setTitleColor(.white, for: .normal)
            } else {
                button.backgroundColor = .clear
                button.setTitleColor(.white, for: .normal)
            }
        }
    }
    
    @objc private func periodButtonTapped(_ sender: UIButton) {
        let newIndex = sender.tag
        guard newIndex != selectedPeriodIndex else { return }
        selectedPeriodIndex = newIndex
        updatePeriodButtonsAppearance()
        
        // 切换视图显示
        switchPeriodView(to: selectedPeriodIndex)
    }
    
    private func switchPeriodView(to index: Int) {
        switch index {
        case 0: // 日视图
            // 显示睡眠圆弧和睡眠图表
            sleepArcView.isHidden = false
            sleepGraphView.isHidden = false
            // 隐藏折线图
            chartsContainerView.isHidden = true
            // 显示数据卡片（但不显示具体数值）
            metricViews.forEach { $0.isHidden = false }
            // 切换底部约束
            contentBottomConstraintForChartView?.isActive = false
            contentBottomConstraintForDayView?.isActive = true
            
        case 1: // 月视图
            // 隐藏睡眠圆弧和睡眠图表
            sleepArcView.isHidden = true
            sleepGraphView.isHidden = true
            // 显示折线图
            chartsContainerView.isHidden = false
            // 隐藏数据卡片
            metricViews.forEach { $0.isHidden = true }
            // 切换底部约束
            contentBottomConstraintForDayView?.isActive = false
            contentBottomConstraintForChartView?.isActive = true
            // 加载并显示月度数据
            loadMonthlyData()
            
        case 2: // 年视图
            // 隐藏睡眠圆弧和睡眠图表
            sleepArcView.isHidden = true
            sleepGraphView.isHidden = true
            // 显示折线图
            chartsContainerView.isHidden = false
            // 隐藏数据卡片
            metricViews.forEach { $0.isHidden = true }
            // 切换底部约束
            contentBottomConstraintForDayView?.isActive = false
            contentBottomConstraintForChartView?.isActive = true
            // 加载并显示年度数据
            loadYearlyData()
            
        default:
            break
        }
        
        // 强制更新布局
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    private func loadMonthlyData() {
        guard monthlyData == nil else {
            updateChartsWithMonthlyData()
            return
        }
        
        Task { @MainActor in
            do {
                let data = try await HealthDataManager.shared.fetchMonthlyData()
                monthlyData = data
                updateChartsWithMonthlyData()
            } catch {
                Log.error("HealthViewController", "Failed to load monthly data: \(error)")
            }
        }
    }
    
    private func loadYearlyData() {
        guard yearlyData == nil else {
            updateChartsWithYearlyData()
            return
        }
        
        Task { @MainActor in
            do {
                let data = try await HealthDataManager.shared.fetchYearlyData()
                yearlyData = data
                updateChartsWithYearlyData()
            } catch {
                Log.error("HealthViewController", "Failed to load yearly data: \(error)")
            }
        }
    }
    
    private func updateChartsWithMonthlyData() {
        guard let data = monthlyData else { return }
        heartRateChartView.configure(period: .monthly, data: data.heartRate)
        hrvChartView.configure(period: .monthly, data: data.hrv)
        sleepChartView.configure(period: .monthly, data: data.sleep)
    }
    
    private func updateChartsWithYearlyData() {
        guard let data = yearlyData else { return }
        heartRateChartView.configure(period: .yearly, data: data.heartRate)
        hrvChartView.configure(period: .yearly, data: data.hrv)
        sleepChartView.configure(period: .yearly, data: data.sleep)
    }

    // MARK: - Data Loading
    private func authorizeAndLoadIfNeeded() {
        guard !isLoading else { return }
        isLoading = true
        
        // 首次加载时显示加载指示器
        if !hasLoadedData {
            loadingIndicator.startAnimating()
            // 隐藏内容视图,避免显示空数据
            sleepArcView.alpha = 0.3
            sleepGraphView.alpha = 0.3
        }
        
        Task { @MainActor in
            do {
                try await HealthDataManager.shared.requestAuthorization()
                
                // 并行加载数据以提高速度
                async let metricsTask = HealthDataManager.shared.fetchLatestMetrics()
                async let stagesTask = HealthDataManager.shared.fetchLatestSleepStages()
                
                let (m, stages) = try await (metricsTask, stagesTask)
                
                // 先存储数据
                lastMetrics = m
                lastSleepStages = stages
                hasLoadedData = true
                lastDataLoadTime = Date()
                
                // 批量更新UI,避免分别触发didSet导致的多次布局
                updateHealthUI()
                
                // 恢复视图透明度
                UIView.animate(withDuration: 0.2) {
                    self.sleepArcView.alpha = 1.0
                    self.sleepGraphView.alpha = 1.0
                }
                
            } catch {
                Log.error("HealthViewController", "Failed to load: \(error.localizedDescription)")
                // 即使失败也恢复透明度
                sleepArcView.alpha = 1.0
                sleepGraphView.alpha = 1.0
            }
            
            isLoading = false
            loadingIndicator.stopAnimating()
            refreshControl.endRefreshing()
        }
    }
    
    // 统一的UI更新方法,一次性更新所有健康数据视图
    private func updateHealthUI() {
        // 更新数据卡片
        if let m = lastMetrics {
            for mv in metricViews { 
                mv.configureValue(metrics: m) 
            }
            
            // 更新睡眠圆弧视图
            if let sleepSummary = m.sleepSummary {
                sleepArcView.configure(
                    sleepHours: sleepSummary.totalSleepHours,
                    timeInBed: sleepSummary.timeInBed ?? sleepSummary.totalSleepHours,
                    viewController: self
                )
            }
        }
        
        // 更新睡眠图表
        if !lastSleepStages.isEmpty {
            let graphData = lastSleepStages.map { detail -> SleepStageData in
                let stage: SleepStage
                switch detail.stage {
                case .awake:
                    stage = .awake
                case .rem:
                    stage = .rem
                case .core:
                    stage = .core
                case .deep:
                    stage = .deep
                }
                return SleepStageData(stage: stage, startTime: detail.startTime, endTime: detail.endTime)
            }
            sleepGraphView.configure(with: graphData)
        }
    }

    @objc private func didPullToRefresh() {
        authorizeAndLoadIfNeeded()
    }
    
    // MARK: - Permission Check
    
    /// 检查健康权限并显示提醒（如果需要）
    private func checkHealthPermissionAndShowReminder() {
        Task { @MainActor in
            // 检查是否应该显示提醒（异步，避免阻塞主线程）
            guard await PermissionManager.shared.shouldShowHealthReminder() else { return }

            // 延迟显示，避免与页面加载动画冲突
            try? await Task.sleep(nanoseconds: 500_000_000)
            PermissionManager.shared.showHealthPermissionReminder(from: self) { [weak self] in
                // 权限授权后重新加载数据
                self?.authorizeAndLoadIfNeeded()
            }
        }
    }

    // MARK: - Theme & Localization
    @objc private func themeDidChange() { applyTheme() }

    private func applyTheme() {
        view.backgroundColor = .black
        metricViews.forEach { $0.applyTheme() }
    }

    @objc override func languageDidChange() {
        title = L("health.title")
        
        // 更新时间段按钮标题
        let periods = [L("health.period.day"), L("health.period.month"), L("health.period.year")]
        for (index, button) in periodButtons.enumerated() {
            if index < periods.count {
                button.setTitle(periods[index], for: .normal)
            }
        }
        
        reloadLocalizedTexts()
    }

    private func reloadLocalizedTexts() {
        metricViews.forEach { $0.reloadTexts() }
    }
}

// MARK: - Metric Row
private final class MetricRowView: UIView {
    enum Kind { case heartRate, hrv, sleep }
    private let kind: Kind
    private let imageName: String
    private weak var viewController: HealthViewController?
    
    // UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let unitLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 睡眠专用的堆栈视图
    private let sleepStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 1
        stack.alignment = .firstBaseline
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // 预创建睡眠时间的标签,避免每次重建
    private lazy var sleepHoursLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        return label
    }()
    
    private lazy var sleepHoursUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        return label
    }()
    
    private lazy var sleepMinutesLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        return label
    }()
    
    private lazy var sleepMinutesUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        return label
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = DesignConstants.separatorColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init(kind: Kind, imageName: String, viewController: HealthViewController) {
        self.kind = kind
        self.imageName = imageName
        self.viewController = viewController
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI() {
        backgroundColor = .black
        translatesAutoresizingMaskIntoConstraints = false
        
        // 添加分隔线
        addSubview(separatorLine)
        
        // 添加标题
        addSubview(titleLabel)
        
        // 根据类型选择不同的布局
        if kind == .sleep {
            // 睡眠使用 StackView - 预先添加所有标签
            addSubview(sleepStackView)
            sleepStackView.addArrangedSubview(sleepHoursLabel)
            sleepStackView.addArrangedSubview(sleepHoursUnitLabel)
            sleepStackView.addArrangedSubview(sleepMinutesLabel)
            sleepStackView.addArrangedSubview(sleepMinutesUnitLabel)
        } else {
            // 其他数据使用普通布局
            addSubview(valueLabel)
            addSubview(unitLabel)
        }
        
        // 添加图标
        addSubview(iconImageView)
        iconImageView.image = UIImage(named: imageName)
        
        guard let vc = viewController else { return }
        
        // 计算实际尺寸
        let titleFontSize = vc.scale(vc.designItemTitleFontSize, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        let valueFontSize = vc.scale(vc.designItemValueFontSize, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        let unitFontSize = vc.scale(vc.designItemUnitFontSize, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        let iconWidth = vc.scale(vc.designIconWidth, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        let itemLeading = vc.scale(vc.designItemLeading, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        let iconTrailing = vc.scale(vc.designIconTrailing, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        let separatorMargin = vc.scale(vc.designSeparatorMargin, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        
        // 标题距离数值的距离
        let titleToValueMargin = vc.scale(10, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        // 数值距离底部分割线的距离
        let valueBottomMargin = vc.scale(vc.designValueBottomMargin, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        
        // 设置字体
        titleLabel.font = UIFont.systemFont(ofSize: titleFontSize, weight: .regular)
        valueLabel.font = UIFont.systemFont(ofSize: valueFontSize, weight: .medium)
        unitLabel.font = UIFont.systemFont(ofSize: unitFontSize, weight: .regular)
        
        // 为睡眠标签设置字体
        if kind == .sleep {
            sleepHoursLabel.font = UIFont.systemFont(ofSize: valueFontSize, weight: .medium)
            sleepHoursUnitLabel.font = UIFont.systemFont(ofSize: unitFontSize, weight: .regular)
            sleepMinutesLabel.font = UIFont.systemFont(ofSize: valueFontSize, weight: .medium)
            sleepMinutesUnitLabel.font = UIFont.systemFont(ofSize: unitFontSize, weight: .regular)
        }
        
        // 设置内容优先级，确保单位标签不被压缩
        unitLabel.setContentHuggingPriority(.required, for: .horizontal)
        unitLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 分隔线
            separatorLine.topAnchor.constraint(equalTo: topAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor, constant: separatorMargin),
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -separatorMargin),
            separatorLine.heightAnchor.constraint(equalToConstant: 1),
            
            // 标题
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: itemLeading),
            
            // 图标在右侧垂直居中
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -iconTrailing),
            iconImageView.widthAnchor.constraint(equalToConstant: iconWidth),
            iconImageView.heightAnchor.constraint(equalToConstant: iconWidth)
        ])
        
        if kind == .sleep {
            // 睡眠数据的特殊布局
            NSLayoutConstraint.activate([
                titleLabel.bottomAnchor.constraint(equalTo: sleepStackView.topAnchor, constant: -titleToValueMargin),
                sleepStackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                sleepStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -valueBottomMargin),
                sleepStackView.trailingAnchor.constraint(lessThanOrEqualTo: iconImageView.leadingAnchor, constant: -20)
            ])
        } else {
            // 普通数据布局
            NSLayoutConstraint.activate([
                titleLabel.bottomAnchor.constraint(equalTo: valueLabel.topAnchor, constant: -titleToValueMargin),
                
                // 数值在标题下方10px，距离底部45px
                valueLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -valueBottomMargin),
                
                // 单位紧跟数值（基线对齐，底部也对齐）
                unitLabel.firstBaselineAnchor.constraint(equalTo: valueLabel.firstBaselineAnchor),
                unitLabel.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 3),
                unitLabel.trailingAnchor.constraint(lessThanOrEqualTo: iconImageView.leadingAnchor, constant: -20)
            ])
        }
        
        reloadTexts()
        showPlaceholder()
    }

    func reloadTexts() {
        titleLabel.text = {
            switch kind {
            case .heartRate: return L("health.metric.heart_rate")
            case .hrv: return L("health.metric.hrv")
            case .sleep: return L("health.metric.sleep")
            }
        }()
    }

    func applyTheme() {
        backgroundColor = .black
        titleLabel.textColor = .white
        valueLabel.textColor = .white
        unitLabel.textColor = .white
    }

    private func showPlaceholder() {
        valueLabel.text = "--"
        unitLabel.text = ""
    }

    func configureValue(metrics: HealthMetrics) {
        guard viewController != nil else { return }
        
        switch kind {
        case .heartRate:
            if let hr = metrics.heartRate {
                // 显示范围 54-84 或单个值
                valueLabel.text = String(format: "%.0f", hr)
                unitLabel.text = L("health.unit.bpm")
            } else {
                showPlaceholder()
            }
        case .hrv:
            if let hrv = metrics.heartRateVariability {
                valueLabel.text = String(format: "%.0f", hrv)
                unitLabel.text = L("health.unit.ms")
            } else {
                showPlaceholder()
            }
        case .sleep:
            if let s = metrics.sleepSummary {
                let totalMinutes = Int((s.totalSleepHours * 60.0).rounded(.down))
                let hours = totalMinutes / 60
                let minutes = totalMinutes % 60
                
                // 直接更新标签内容,不重建视图
                sleepHoursLabel.text = String(hours)
                sleepHoursUnitLabel.text = L("health.unit.hours")
                sleepMinutesLabel.text = String(minutes)
                sleepMinutesUnitLabel.text = L("health.unit.minutes")
            } else {
                showPlaceholder()
            }
        }
    }
}

// MARK: - Sleep Arc View
private final class SleepArcView: UIView {
    private let arcLayer = CAShapeLayer()
    private let backgroundArcLayer = CAShapeLayer()
    
    // 使用StackView来放置睡眠时间（数值和单位）
    private let sleepTimeStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 1
        stack.alignment = .firstBaseline
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let totalDurationLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        return label
    }()
    
    private var sleepHours: Double = 0
    private var timeInBed: Double = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // 先添加圆弧层（在下层）
        layer.addSublayer(backgroundArcLayer)
        backgroundArcLayer.fillColor = UIColor.clear.cgColor
        backgroundArcLayer.strokeColor = UIColor.white.withAlphaComponent(0.28).cgColor
        backgroundArcLayer.lineCap = .round
        
        layer.addSublayer(arcLayer)
        arcLayer.fillColor = UIColor.clear.cgColor
        arcLayer.strokeColor = UIColor.white.cgColor
        arcLayer.lineCap = .round
        
        // 预先添加标签到视图层级，避免后续添加造成延迟
        addSubview(sleepTimeStackView)
        addSubview(totalDurationLabel)
        
        // 初始化为隐藏，等待数据配置后显示
        sleepTimeStackView.alpha = 0
        totalDurationLabel.alpha = 0
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateArcPaths()
    }
    
    // 用于存储约束，避免重复创建
    private var hasConfiguredConstraints = false
    
    func configure(sleepHours: Double, timeInBed: Double, viewController: HealthViewController) {
        self.sleepHours = sleepHours
        self.timeInBed = timeInBed
        
        // 设置字体
        let valueFontSize = viewController.scale(viewController.designSleepValueFontSize, basedOn: viewController.view.bounds.height, designDimension: viewController.designHeight)
        let unitFontSize = viewController.scale(viewController.designSleepUnitFontSize, basedOn: viewController.view.bounds.height, designDimension: viewController.designHeight)
        let totalFontSize = viewController.scale(viewController.designSleepTotalFontSize, basedOn: viewController.view.bounds.height, designDimension: viewController.designHeight)
        let strokeWidth = viewController.scale(viewController.designSleepArcStrokeWidth, basedOn: viewController.view.bounds.width, designDimension: viewController.designWidth)
        
        // 设置圆弧描边宽度
        arcLayer.lineWidth = strokeWidth
        backgroundArcLayer.lineWidth = strokeWidth
        
        // 计算小时和分钟（实际睡眠时间）
        let sleepMinutes = Int((sleepHours * 60.0).rounded(.down))
        let hours = sleepMinutes / 60
        let minutes = sleepMinutes % 60
        
        // 清空 StackView
        sleepTimeStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 创建小时数值
        let hoursLabel = UILabel()
        hoursLabel.text = String(hours)
        hoursLabel.font = UIFont.systemFont(ofSize: valueFontSize, weight: .medium)
        hoursLabel.textColor = .white
        
        // 创建小时单位
        let hoursUnitLabel = UILabel()
        hoursUnitLabel.text = L("health.unit.hours")
        hoursUnitLabel.font = UIFont.systemFont(ofSize: unitFontSize, weight: .regular)
        hoursUnitLabel.textColor = .white
        
        // 创建分钟数值
        let minutesLabel = UILabel()
        minutesLabel.text = String(minutes)
        minutesLabel.font = UIFont.systemFont(ofSize: valueFontSize, weight: .medium)
        minutesLabel.textColor = .white
        
        // 创建分钟单位
        let minutesUnitLabel = UILabel()
        minutesUnitLabel.text = L("health.unit.minutes")
        minutesUnitLabel.font = UIFont.systemFont(ofSize: unitFontSize, weight: .regular)
        minutesUnitLabel.textColor = .white
        
        // 添加到 StackView
        sleepTimeStackView.addArrangedSubview(hoursLabel)
        sleepTimeStackView.addArrangedSubview(hoursUnitLabel)
        sleepTimeStackView.addArrangedSubview(minutesLabel)
        sleepTimeStackView.addArrangedSubview(minutesUnitLabel)
        
        // 设置总时长字体
        totalDurationLabel.font = UIFont.systemFont(ofSize: totalFontSize, weight: .regular)
        
        // 计算总时长 = 在床上的总时间（timeInBed）
        let totalMinutes = Int((timeInBed * 60.0).rounded(.down))
        let totalH = totalMinutes / 60
        let totalM = totalMinutes % 60
        totalDurationLabel.text = L("health.sleep.total_duration") + " \(totalH)" + L("health.unit.hours") + "\(totalM)" + L("health.unit.minutes")
        
        // 只在第一次配置时设置约束
        if !hasConfiguredConstraints {
            // 计算标签位置 - 基于设计稿
            // 睡眠数值距离屏幕顶部 842，圆弧视图距离屏幕顶部 640
            // 所以睡眠数值距离圆弧视图顶部是 842 - 640 = 202
            let sleepValueTop = viewController.scale(viewController.designSleepValueTop - viewController.designSleepArcTop, basedOn: viewController.view.bounds.height, designDimension: viewController.designHeight)
            
            // 总时长距离睡眠时间 28px
            let totalDurationSpacing = viewController.scale(28, basedOn: viewController.view.bounds.height, designDimension: viewController.designHeight)
            
            // 设置约束
            NSLayoutConstraint.activate([
                // 睡眠时间 StackView - 根据设计稿位置
                sleepTimeStackView.topAnchor.constraint(equalTo: topAnchor, constant: sleepValueTop),
                sleepTimeStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
                
                // 总时长（在睡眠时间下方28px）
                totalDurationLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                totalDurationLabel.topAnchor.constraint(equalTo: sleepTimeStackView.bottomAnchor, constant: totalDurationSpacing)
            ])
            
            hasConfiguredConstraints = true
        }
        
        // 立即更新布局
        setNeedsLayout()
        layoutIfNeeded()
        
        updateArcPaths()
        
        // 快速显示标签（移除渐变动画，直接显示）
        sleepTimeStackView.alpha = 1
        totalDurationLabel.alpha = 1
    }
    
    private func updateArcPaths() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        // 计算圆弧的半径（根据视图宽度）
        let radius = bounds.width * 0.35
        let centerX = bounds.width / 2
        // 圆弧的顶部在视图顶部（y=0），所以圆心应该在 y = radius 的位置
        // 这样半圆的顶部（180度位置）就在 y=0
        let centerY: CGFloat = radius
        
        // 半圆：从左侧（180度）到右侧（0度），顺时针绘制
        let startAngle: CGFloat = .pi          // 180度（正左侧）
        let endAngle: CGFloat = 0              // 0度（正右侧）
        
        // 背景圆弧（完整的半圆，灰色28%透明度，代表在床上的总时间）
        let backgroundPath = UIBezierPath(
            arcCenter: CGPoint(x: centerX, y: centerY),
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        backgroundArcLayer.path = backgroundPath.cgPath
        
        // 前景圆弧（白色部分，表示实际睡眠时间占在床上总时间的比例）
        // 睡眠效率 = 睡眠时间 / 在床上的总时间
        let sleepRatio = timeInBed > 0 ? min(sleepHours / timeInBed, 1.0) : 0
        let sweepAngle = startAngle + (.pi * CGFloat(sleepRatio))  // 半圆是π弧度
        
        let foregroundPath = UIBezierPath(
            arcCenter: CGPoint(x: centerX, y: centerY),
            radius: radius,
            startAngle: startAngle,
            endAngle: sweepAngle,
            clockwise: true
        )
        arcLayer.path = foregroundPath.cgPath
    }
}

