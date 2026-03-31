import UIKit

// MARK: - 时间段枚举
enum HealthPeriod: Int, CaseIterable {
    case day = 0
    case week = 1
    case month = 2
    case sixMonths = 3
    case year = 4
    
    var localizedKey: String {
        switch self {
        case .day: return "health.period.day"
        case .week: return "health.period.week"
        case .month: return "health.period.month"
        case .sixMonths: return "health.period.six_months"
        case .year: return "health.period.year"
        }
    }
    
    var title: String {
        return L(localizedKey)
    }
}

// MARK: - 健康数据类型
enum HealthMetricType {
    case heartRate
    case hrv
    case sleep
    
    var titleKey: String {
        switch self {
        case .heartRate: return "health.metric.heart_rate"
        case .hrv: return "health.metric.hrv"
        case .sleep: return "health.metric.sleep"
        }
    }
}

// MARK: - CustomSegmentControlDelegate
protocol HealthDetailSegmentControlDelegate: AnyObject {
    func segmentControl(_ control: HealthDetailSegmentControl, didSelectIndex index: Int)
}

// MARK: - CustomSegmentControl
final class HealthDetailSegmentControl: UIView {
    
    // MARK: - Design Constants
    // 外层大圆角矩形设计稿尺寸：1146 x 88，圆角44
    private let designContainerWidth: CGFloat = 1146
    private let designContainerHeight: CGFloat = 88
    private let designContainerCornerRadius: CGFloat = 44
    // 内层选择框设计稿尺寸：217 x 78，圆角39
    private let designIndicatorWidth: CGFloat = 217
    private let designIndicatorHeight: CGFloat = 78
    private let designIndicatorCornerRadius: CGFloat = 39
    // 设计稿基准尺寸
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    weak var delegate: HealthDetailSegmentControlDelegate?
    
    private var buttons: [UIButton] = []
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = DesignConstants.grayColor
        return view
    }()
    
    private var selectedIndex: Int = 0
    
    init(titles: [String], initialIndex: Int = 0) {
        self.selectedIndex = initialIndex
        super.init(frame: .zero)
        setupView(titles: titles)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView(titles: [String]) {
        // 外层大圆角矩形：使用 TabBar 背景色（与 HealthSyncSettingsViewController 一致）
        backgroundColor = DesignConstants.tabBarBackgroundColor
        clipsToBounds = true
        
        addSubview(indicatorView)
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        for (index, title) in titles.enumerated() {
            let button = UIButton(type: .custom)
            button.setTitle(title, for: .normal)
            button.setTitleColor(.white.withAlphaComponent(0.6), for: .normal)
            button.setTitleColor(.black, for: .selected)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            button.tag = index
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            
            if index == selectedIndex {
                button.isSelected = true
            }
            
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 根据设计稿计算外层圆角
        let containerCornerRadius = designContainerCornerRadius * (bounds.height / designContainerHeight)
        layer.cornerRadius = containerCornerRadius
        
        updateIndicatorPosition(animated: false)
    }
    
    private func updateIndicatorPosition(animated: Bool) {
        guard !buttons.isEmpty else { return }
        
        let buttonWidth = bounds.width / CGFloat(buttons.count)
        
        // 计算内层选择框的尺寸和圆角
        // 选择框高度按设计稿比例计算
        let indicatorHeight = designIndicatorHeight * (bounds.height / designContainerHeight)
        let indicatorCornerRadius = designIndicatorCornerRadius * (bounds.height / designContainerHeight)
        
        // 选择框垂直居中
        let verticalPadding = (bounds.height - indicatorHeight) / 2
        
        // 选择框宽度：按比例计算，但不超过按钮宽度减去边距
        let indicatorWidth = min(designIndicatorWidth * (bounds.width / designContainerWidth), buttonWidth - 4)
        
        // 选择框水平居中于当前选中的按钮
        let indicatorX = CGFloat(selectedIndex) * buttonWidth + (buttonWidth - indicatorWidth) / 2
        
        let indicatorFrame = CGRect(
            x: indicatorX,
            y: verticalPadding,
            width: indicatorWidth,
            height: indicatorHeight
        )
        
        indicatorView.layer.cornerRadius = indicatorCornerRadius
        
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                self.indicatorView.frame = indicatorFrame
            }
        } else {
            indicatorView.frame = indicatorFrame
        }
    }
    
    @objc private func buttonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedIndex else { return }
        
        buttons[selectedIndex].isSelected = false
        buttons[index].isSelected = true
        selectedIndex = index
        
        updateIndicatorPosition(animated: true)
        delegate?.segmentControl(self, didSelectIndex: index)
    }
}

final class HealthDetailViewController: UIViewController {
    
    // MARK: - Design Constants
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 返回按钮设计稿尺寸
    private let designBackButtonTop: CGFloat = 186      // 返回按钮距离屏幕顶部
    private let designBackButtonLeading: CGFloat = 58   // 返回按钮距离屏幕左边（与 HealthPeriod 左侧对齐）
    private let designBackButtonWidth: CGFloat = 27     // 返回按钮图标宽度（调小）
    private let designBackButtonHeight: CGFloat = 58    // 返回按钮图标高度（调小）
    
    // Segment 控件设计稿尺寸
    private let designSegmentTop: CGFloat = 307         // 距离页面顶部 307px
    private let designSegmentHeight: CGFloat = 88       // Segment 高度（与 HealthDetailSegmentControl 中的 designContainerHeight 一致）
    private let designSegmentLeading: CGFloat = 48      // 左右边距
    
    // MARK: - Properties
    private let metricType: HealthMetricType
    private var selectedPeriod: HealthPeriod = .week
    private var anchorDate: Date = Calendar.current.startOfDay(for: Date())
    private var lastSwipeDirection: ChartSwipeDirection?
    
    /// 锚点管理器引用
    private let anchorManager = HealthTimeAnchorManager.shared
    
    /// 将 HealthMetricType 转换为 AnchorManager 的 MetricType
    private var managerMetricType: HealthTimeAnchorManager.MetricType {
        switch metricType {
        case .heartRate: return .heartRate
        case .hrv: return .hrv
        case .sleep: return .sleep
        }
    }
    
    /// 将 HealthPeriod 转换为 AnchorManager 的 Period
    private func managerPeriod(from period: HealthPeriod) -> HealthTimeAnchorManager.Period {
        switch period {
        case .day: return .day
        case .week: return .week
        case .month: return .month
        case .sixMonths: return .sixMonths
        case .year: return .year
        }
    }
    
    // MARK: - UI Elements
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .black
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let backButton: UIButton = {
        let button = ExpandedTouchButton(type: .custom)
        button.setImage(UIImage(named: "back_icon"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.contentHorizontalAlignment = .left
        button.contentVerticalAlignment = .center
        button.translatesAutoresizingMaskIntoConstraints = false
        // 设置扩展的点击区域（不影响视觉大小）
        button.touchAreaInsets = UIEdgeInsets(top: -10, left: 0, bottom: -10, right: -20)
        return button
    }()
    
    private lazy var segmentControl: HealthDetailSegmentControl = {
        let titles = HealthPeriod.allCases.map { $0.title }
        let control = HealthDetailSegmentControl(titles: titles, initialIndex: HealthPeriod.week.rawValue)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.delegate = self
        return control
    }()
    
    // 图表容器
    private let chartContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        return view
    }()
    
    private var chartView: LineChartView?
    
    // 加载指示器
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Init
    init(metricType: HealthMetricType) {
        self.metricType = metricType
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // 从锚点管理器获取初始锚点
        anchorDate = anchorManager.getAnchor(for: managerMetricType, period: managerPeriod(from: selectedPeriod))
        
        // 监听锚点变化通知（用于同类数据联动）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(anchorDidChange(_:)),
            name: HealthTimeAnchorManager.anchorDidChangeNotification,
            object: anchorManager
        )
        
        loadDataForPeriod()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 响应锚点变化通知
    @objc private func anchorDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changedMetricType = userInfo[HealthTimeAnchorManager.metricTypeKey] as? HealthTimeAnchorManager.MetricType,
              let _ = userInfo[HealthTimeAnchorManager.periodKey] as? HealthTimeAnchorManager.Period else {
            return
        }
        
        // 只有当变化的是同类型数据时才响应
        guard changedMetricType == managerMetricType else { return }
        
        // 获取当前时间段的新锚点
        let newAnchor = anchorManager.getAnchor(for: managerMetricType, period: managerPeriod(from: selectedPeriod))
        
        // 如果锚点确实变化了，更新数据
        if !Calendar.current.isDate(newAnchor, inSameDayAs: anchorDate) {
            anchorDate = newAnchor
            // 不需要再同步（已经是联动结果），直接加载数据
            loadDataForPeriod()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        view.addSubview(loadingIndicator)
        
        contentView.addSubview(backButton)
        contentView.addSubview(segmentControl)
        contentView.addSubview(chartContainerView)
        
        setupBackButton()
        setupChartView()
        setupConstraints()
    }
    
    private func setupBackButton() {
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
    }
    
    private func setupChartView() {
        let chartType: LineChartView.ChartType
        switch metricType {
        case .heartRate:
            chartType = .heartRate
        case .hrv:
            chartType = .hrv
        case .sleep:
            chartType = .sleep
        }
        
        chartView = LineChartView(type: chartType)
        chartView?.translatesAutoresizingMaskIntoConstraints = false
        chartView?.navigationDelegate = self
        
        if let chart = chartView {
            chartContainerView.addSubview(chart)
        }
    }
    
    private func setupConstraints() {
        // 返回按钮约束（与 PermissionViewController 完全一致）
        let backButtonTop = scale(designBackButtonTop, basedOn: view.bounds.height, designDimension: designHeight)
        let backButtonLeading = scale(designBackButtonLeading, basedOn: view.bounds.width, designDimension: designWidth)
        let backButtonWidth = scale(designBackButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let backButtonHeight = scale(designBackButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        
        // Segment 控件约束
        let segmentTop = scale(designSegmentTop, basedOn: view.bounds.height, designDimension: designHeight)
        let segmentHeight = scale(designSegmentHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let segmentLeading = scale(designSegmentLeading, basedOn: view.bounds.width, designDimension: designWidth)
        
        let chartTop = scale(23, basedOn: view.bounds.height, designDimension: designHeight)
        let chartHeight = scale(1350, basedOn: view.bounds.height, designDimension: designHeight)
        let chartWidth = view.bounds.width * 0.95
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 返回按钮（保持原始视觉尺寸，点击区域通过 ExpandedTouchButton 扩展）
            backButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: backButtonTop),
            backButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: backButtonLeading),
            backButton.widthAnchor.constraint(equalToConstant: backButtonWidth),
            backButton.heightAnchor.constraint(equalToConstant: backButtonHeight),
            
            // Segment 控件 - 距离页面顶部 307px
            segmentControl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: segmentTop),
            segmentControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: segmentLeading),
            segmentControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -segmentLeading),
            segmentControl.heightAnchor.constraint(equalToConstant: segmentHeight),
            
            chartContainerView.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: chartTop),
            chartContainerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            chartContainerView.widthAnchor.constraint(equalToConstant: chartWidth),
            chartContainerView.heightAnchor.constraint(equalToConstant: chartHeight),
            
            contentView.bottomAnchor.constraint(equalTo: chartContainerView.bottomAnchor, constant: 100),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        if let chart = chartView {
            NSLayoutConstraint.activate([
                chart.topAnchor.constraint(equalTo: chartContainerView.topAnchor),
                chart.leadingAnchor.constraint(equalTo: chartContainerView.leadingAnchor),
                chart.trailingAnchor.constraint(equalTo: chartContainerView.trailingAnchor),
                chart.bottomAnchor.constraint(equalTo: chartContainerView.bottomAnchor)
            ])
        }
    }
    
    // MARK: - Helper
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Data Loading
    private func loadDataForPeriod(direction: ChartSwipeDirection? = nil) {
        loadingIndicator.startAnimating()
        
        Task { @MainActor in
            do {
                let data: HealthDataManager.PeriodHealthData
                
                switch selectedPeriod {
                case .day:
                    // 日视图：24小时，每小时一个数据点
                    data = try await HealthDataManager.shared.fetchDailyData(anchorDate: anchorDate)
                case .week:
                    // 周视图：7天，每天一个数据点
                    data = try await HealthDataManager.shared.fetchWeeklyData(anchorDate: anchorDate)
                case .month:
                    // 月视图：30天，每天一个数据点
                    data = try await HealthDataManager.shared.fetchMonthlyData(anchorDate: anchorDate)
                case .sixMonths:
                    // 6个月视图：按周聚合（周日到周六）
                    data = try await HealthDataManager.shared.fetchSixMonthsData(anchorDate: anchorDate)
                case .year:
                    // 年视图：12个月，每月一个数据点
                    data = try await HealthDataManager.shared.fetchYearlyData(anchorDate: anchorDate)
                }
                
                updateChart(with: data, direction: direction)
                
            } catch {
                Log.error("HealthDetailViewController", "Failed to load data: \(error)")
            }
            
            loadingIndicator.stopAnimating()
        }
    }

    /// 根据滑动方向移动 anchorDate，并触发数据刷新
    /// 只有目标时间段有数据时才会切换，否则只播放反馈动画
    private func shiftAnchor(for direction: ChartSwipeDirection) {
        let calendar = Calendar.current
        var components = DateComponents()

        switch selectedPeriod {
        case .day:
            components.day = direction == .previous ? -1 : 1
        case .week:
            components.weekOfYear = direction == .previous ? -1 : 1
        case .month:
            components.month = direction == .previous ? -1 : 1
        case .sixMonths:
            components.month = direction == .previous ? -6 : 6
        case .year:
            components.year = direction == .previous ? -1 : 1
        }

        guard let proposed = calendar.date(byAdding: components, to: anchorDate) else { return }

        // 不允许超过当前最新数据
        let latest = Date()
        if proposed > latest {
            // 播放边缘反馈动画
            chartView?.playEdgeFeedback(direction: direction)
            return
        }

        let proposedAnchor = calendar.startOfDay(for: proposed)
        
        // 异步检查目标时间段是否有数据
        Task { @MainActor in
            let hasData = await checkDataAvailability(for: proposedAnchor)
            
            if hasData {
                // 有数据，执行切换
                self.anchorDate = proposedAnchor
                self.lastSwipeDirection = direction
                
                // 更新锚点管理器（会自动同步其他时间段并发送通知）
                self.anchorManager.setAnchor(self.anchorDate, for: self.managerMetricType, period: self.managerPeriod(from: self.selectedPeriod))
                
                self.loadDataForPeriod(direction: direction)
            } else {
                // 没有数据，只播放边缘反馈动画
                self.chartView?.playEdgeFeedback(direction: direction)
            }
        }
    }
    
    /// 检查指定锚点日期是否有数据
    /// - Parameter anchor: 目标锚点日期
    /// - Returns: 是否有数据
    private func checkDataAvailability(for anchor: Date) async -> Bool {
        do {
            let data: HealthDataManager.PeriodHealthData
            
            switch selectedPeriod {
            case .day:
                data = try await HealthDataManager.shared.fetchDailyData(anchorDate: anchor)
            case .week:
                data = try await HealthDataManager.shared.fetchWeeklyData(anchorDate: anchor)
            case .month:
                data = try await HealthDataManager.shared.fetchMonthlyData(anchorDate: anchor)
            case .sixMonths:
                data = try await HealthDataManager.shared.fetchSixMonthsData(anchorDate: anchor)
            case .year:
                data = try await HealthDataManager.shared.fetchYearlyData(anchorDate: anchor)
            }
            
            // 根据数据类型检查是否有有效数据
            switch metricType {
            case .heartRate:
                // 检查心率范围数据或普通心率数据
                if !data.heartRateRange.isEmpty {
                    return data.heartRateRange.contains { $0.isValid }
                }
                return data.heartRate.contains { $0 > 0 }
                
            case .hrv:
                return data.hrv.contains { $0 > 0 }
                
            case .sleep:
                // 检查睡眠范围数据或普通睡眠数据
                if !data.sleepRange.isEmpty {
                    return data.sleepRange.contains { $0.isValid }
                }
                return data.sleep.contains { $0 > 0 }
            }
        } catch {
            Log.error("HealthDetailViewController", "Failed to check data availability: \(error)")
            return false
        }
    }
    
    private func updateChart(with data: HealthDataManager.PeriodHealthData, direction: ChartSwipeDirection?) {
        // 将 HealthPeriod 映射到 LineChartView.Period
        let period: LineChartView.Period
        switch selectedPeriod {
        case .day:
            period = .daily
        case .week:
            period = .weekly
        case .month:
            period = .monthly
        case .sixMonths:
            period = .sixMonths
        case .year:
            period = .yearly
        }
        
        // 1. 创建新的 ChartView
        let chartType: LineChartView.ChartType
        switch metricType {
        case .heartRate: chartType = .heartRate
        case .hrv: chartType = .hrv
        case .sleep: chartType = .sleep
        }
        
        let newChartView = LineChartView(type: chartType)
        newChartView.translatesAutoresizingMaskIntoConstraints = false
        newChartView.navigationDelegate = self
        newChartView.alpha = 0 // 初始透明
        
        // 2. 配置新 View
        switch metricType {
        case .heartRate:
            // 心率使用范围条形图
            if !data.heartRateRange.isEmpty {
                // 将 HealthDataManager.HeartRateRangePoint 转换为 LineChartView.HeartRateRangePoint
                let rangeData = data.heartRateRange.map { point in
                    LineChartView.HeartRateRangePoint(min: point.min, max: point.max)
                }
                newChartView.configureHeartRateRange(period: period, rangeData: rangeData, referenceDate: anchorDate)
            } else {
                // 备用：使用普通数据
                newChartView.configure(period: period, data: data.heartRate, referenceDate: anchorDate)
            }
        case .hrv:
            newChartView.configure(period: period, data: data.hrv, referenceDate: anchorDate)
        case .sleep:
            // 睡眠使用新的图表样式（日视图和周/月/年视图都使用 sleepRange）
            if !data.sleepRange.isEmpty {
                // 所有视图都使用睡眠范围数据
                let sleepRangeData = data.sleepRange.map { point in
                    LineChartView.SleepRangePoint(
                        bedStartMinutes: point.bedStartMinutes,
                        bedEndMinutes: point.bedEndMinutes,
                        sleepStartMinutes: point.sleepStartMinutes,
                        sleepEndMinutes: point.sleepEndMinutes
                    )
                }
                newChartView.configureSleepRange(period: period, rangeData: sleepRangeData, referenceDate: anchorDate)
            } else {
                // 备用：使用普通数据
                newChartView.configure(period: period, data: data.sleep, referenceDate: anchorDate)
            }
        }
        
        // 3. 添加到视图层级并设置约束
        chartContainerView.addSubview(newChartView)
        NSLayoutConstraint.activate([
            newChartView.topAnchor.constraint(equalTo: chartContainerView.topAnchor),
            newChartView.leadingAnchor.constraint(equalTo: chartContainerView.leadingAnchor),
            newChartView.trailingAnchor.constraint(equalTo: chartContainerView.trailingAnchor),
            newChartView.bottomAnchor.constraint(equalTo: chartContainerView.bottomAnchor)
        ])
        
        // 强制布局以确保新 View 渲染
        chartContainerView.layoutIfNeeded()
        newChartView.layoutIfNeeded()

        let containerWidth = chartContainerView.bounds.width
        let shouldSlide = (direction != nil && containerWidth > 0)
        if shouldSlide, let direction = direction {
            // 初始位置：新视图从滑动方向进入
            // previous = 右滑查看更早数据 = 新视图从左边（过去）进入
            // next = 左滑查看更新数据 = 新视图从右边（未来）进入
            let offset = direction == .previous ? -containerWidth : containerWidth
            newChartView.transform = CGAffineTransform(translationX: offset, y: 0)
        }
        
        // 4. 执行流畅的滑动动画
        let animationDuration: TimeInterval = shouldSlide ? 0.35 : 0.25
        
        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                if shouldSlide, let direction = direction {
                    // 旧视图滑出（与新视图相反方向）
                    let offset = direction == .previous ? containerWidth : -containerWidth
                    self.chartView?.transform = CGAffineTransform(translationX: offset, y: 0)
                    // 新视图滑入
                    newChartView.transform = .identity
                }
                self.chartView?.alpha = 0
                newChartView.alpha = 1
            }
        ) { _ in
            self.chartView?.removeFromSuperview()
            self.chartView = newChartView
            self.chartView?.transform = .identity
        }
    }
}

// MARK: - HealthDetailSegmentControlDelegate
extension HealthDetailViewController: HealthDetailSegmentControlDelegate {
    func segmentControl(_ control: HealthDetailSegmentControl, didSelectIndex index: Int) {
        guard let newPeriod = HealthPeriod(rawValue: index), newPeriod != selectedPeriod else { return }
        selectedPeriod = newPeriod
        
        // 从锚点管理器获取该时间段的锚点（实现联动）
        anchorDate = anchorManager.getAnchor(for: managerMetricType, period: managerPeriod(from: selectedPeriod))
        
        loadDataForPeriod()
    }
}

// MARK: - LineChartViewNavigationDelegate
extension HealthDetailViewController: LineChartViewNavigationDelegate {
    func chartViewDidRequestNavigation(_ chartView: LineChartView, direction: ChartSwipeDirection) {
        shiftAnchor(for: direction)
    }
}
