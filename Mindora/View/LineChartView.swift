//
//  LineChartView.swift
//  mindora
//
//  Created by gao chao on 2025/10/23.
//
//  折线图视图组件
//  支持月度和年度数据展示，采用带圆角的柱状图样式
//

import UIKit

enum ChartSwipeDirection {
    case previous
    case next
}

protocol LineChartViewNavigationDelegate: AnyObject {
    func chartViewDidRequestNavigation(_ chartView: LineChartView, direction: ChartSwipeDirection)
}

/// 折线图视图，支持月度和年度数据展示
/// 采用带圆角的柱状图样式，包含标题、Y轴刻度和X轴标签
final class LineChartView: UIView {
    // MARK: - Design Constants (设计稿尺寸)
    let designWidth: CGFloat = 1242
    let designHeight: CGFloat = 2688
    
    // 垂直间距（设计稿尺寸）
    // 调整间距使正常状态与选中信息框内的布局保持一致
    // 选中框内顶部间距为 periodLabelTopMargin + infoPadding/2，其中 infoPadding = 30
    let designPeriodLabelTopMargin: CGFloat = 30       // 日均/月均标签距离顶部的距离（与选中框内效果一致）
    let designValueLabelTopMargin: CGFloat = 10        // 数值行距离日均/月均的距离（与选中框一致）
    let designDateRangeTopMargin: CGFloat = 10         // 日期范围距离数值的距离（与选中框一致）
    let designChartTopMargin: CGFloat = 2             // 图表容器距离日期范围的距离
    let designChartHeight: CGFloat = 950               // 图表容器的高度（设计稿尺寸）
    
    // 字体大小
    let designPeriodLabelFontSize: CGFloat = 42        // 日均/月均字体大小
    let designValueNumberFontSize: CGFloat = 108       // 数值字体大小（如"76"）
    let designValueUnitFontSize: CGFloat = 54          // 单位字体大小（如"次/分")
    let designDateRangeFontSize: CGFloat = 54          // 日期范围字体大小
    let designAxisLabelFontSize: CGFloat = 42          // 坐标轴标签字体大小 - 从54减小到42
    
    // 水平间距（设计稿尺寸）
    let designContentLeading: CGFloat = 60           // 内容左边距
    let designChartHorizontalMargin: CGFloat = 30      // 图表左右边距
    
    // 计算实际尺寸的辅助方法
    func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    enum ChartType {
        case heartRate
        case hrv
        case sleep
        
        var color: UIColor {
            switch self {
            case .sleep: return DesignConstants.lightGreen
            case .heartRate: return DesignConstants.midiumGreen
            case .hrv: return DesignConstants.darkGreen
            }
        }
        
        var unit: String {
            switch self {
            case .heartRate: return L("health.unit.bpm")
            case .hrv: return L("health.unit.ms")
            case .sleep: return L("health.unit.hour")
            }
        }
        
        var title: String {
            switch self {
            case .heartRate: return L("health.metric.heart_rate")
            case .hrv: return L("health.metric.hrv")
            case .sleep: return L("health.metric.sleep")
            }
        }
        
        var iconName: String {
            switch self {
            case .heartRate: return "health_data_icon"
            case .hrv: return "heart_rate_variability_icon"
            case .sleep: return "sleep_icon"
            }
        }
    }

    // 在 Period 枚举中添加新的时间段
    enum Period {
        case daily
        case weekly
        case monthly
        case sixMonths
        case yearly
    }
    
    /// 心率范围数据点结构体
    struct HeartRateRangePoint {
        let min: Double
        let max: Double
        
        /// 数据是否有效（非零）
        var isValid: Bool {
            return min > 0 && max > 0
        }
        
        /// 空数据点
        static let empty = HeartRateRangePoint(min: 0, max: 0)
    }
    
    /// 睡眠范围数据点结构体
    /// 用于周/月/年视图的垂直范围柱状图，Y轴代表时间点
    /// 也用于日视图的水平条形图，X轴代表时间点
    struct SleepRangePoint {
        /// 卧床开始时间（以分钟表示，相对于20:00基准点）
        /// 例如：20:00 = 0, 22:30 = 150, 次日01:00 = 300, 次日10:00 = 840
        let bedStartMinutes: Double
        /// 卧床结束时间（以分钟表示）
        let bedEndMinutes: Double
        /// 睡眠开始时间（以分钟表示）
        let sleepStartMinutes: Double
        /// 睡眠结束时间（以分钟表示）
        let sleepEndMinutes: Double
        
        /// 数据是否有效
        var isValid: Bool {
            return bedEndMinutes > bedStartMinutes && sleepEndMinutes > sleepStartMinutes
        }
        
        /// 空数据点
        static let empty = SleepRangePoint(bedStartMinutes: 0, bedEndMinutes: 0, sleepStartMinutes: 0, sleepEndMinutes: 0)
    }
    
    /// 日视图睡眠数据点结构体（已弃用，保留兼容性）
    /// 用于日视图的水平条形图
    struct DailySleepPoint {
        /// 小时（0-23）
        let hour: Int
        /// 该小时内卧床的分钟数（0-60）
        let bedMinutes: Double
        /// 该小时内睡眠的分钟数（0-60）
        let sleepMinutes: Double
        
        /// 数据是否有效
        var isValid: Bool {
            return bedMinutes > 0 || sleepMinutes > 0
        }
    }
    
    let chartType: ChartType
    var period: Period = .monthly
    /// 作为时间轴参考的日期（结束点），用于日期范围和标签计算
    var referenceDate: Date = Date()
    var dataPoints: [Double] = []
    var heartRateRangeData: [HeartRateRangePoint] = []  // 心率范围数据（用于范围条形图）
    var sleepRangeData: [SleepRangePoint] = []  // 睡眠范围数据（用于周/月/年垂直范围柱状图）
    var dailySleepData: [DailySleepPoint] = []  // 日视图睡眠数据（用于水平条形图）
    
    // 柱状图尺寸常量（从 DesignConstants 复制过来）
    // 日、月、6个月的宽度为17px
    let designDailyBarWidth: CGFloat = 17
    let designDailyBarCornerRadius: CGFloat = 5
    let designMonthlyBarWidth: CGFloat = 17
    let designMonthlyBarCornerRadius: CGFloat = 5
    let designSixMonthsBarWidth: CGFloat = 17
    let designSixMonthsBarCornerRadius: CGFloat = 5
    // 周的宽度为100px
    let designWeeklyBarWidth: CGFloat = 100
    let designWeeklyBarCornerRadius: CGFloat = 15
    // 年的宽度为60px
    let designYearlyBarWidth: CGFloat = 60
    let designYearlyBarCornerRadius: CGFloat = 15
    
    // UI Components
    // 日均/月均标签（第一行）
    let periodLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left  // 左对齐
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 数值标签（第二行 - 数值部分）
    let valueNumberLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left  // 左对齐
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 单位标签（第二行 - 单位部分）
    let valueUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left  // 左对齐
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 日期范围标签（第三行）
    let dateRangeLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left  // 左对齐
        // 字体大小会在 setupUI 中设置
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - 睡眠图表专用UI组件（两列布局）
    
    // 卧床时间圆点（第一列）
    let bedTimeDot: UIView = {
        let view = UIView()
        // 卧床时间点使用 darkGreen（深绿色）表示，以便与睡眠时间的 lightGreen 区分
        view.backgroundColor = DesignConstants.darkGreen
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    // 卧床时间标签（第一行第一列）
    let bedTimePeriodLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // 卧床时间数值标签（第二行第一列）
    let bedTimeValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // 卧床时间小时单位标签（第二行第一列）
    let bedTimeHourUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // 卧床时间分钟数值标签（第二行第一列）
    let bedTimeMinValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // 卧床时间分钟单位标签（第二行第一列）
    let bedTimeMinUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // 睡眠时间圆点（第二列）
    let sleepTimeDot: UIView = {
        let view = UIView()
        view.backgroundColor = DesignConstants.lightGreen
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    // 睡眠时间标签（第一行第二列）
    let sleepTimePeriodLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // 睡眠时间小时数值标签（第二行第二列）
    let sleepTimeValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // 睡眠时间小时单位标签（第二行第二列）
    let sleepTimeHourUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // 睡眠时间分钟数值标签（第二行第二列）
    let sleepTimeMinValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // 睡眠时间分钟单位标签（第二行第二列）
    let sleepTimeMinUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    let chartContainerView = UIView()
    var barLayers: [CAShapeLayer] = []
    var yAxisLabels: [UILabel] = []
    var xAxisLabels: [UILabel] = []
    
    // 动态约束（用于睡眠模式切换）
    var dateRangeLabelTopConstraint: NSLayoutConstraint?
    var dateRangeLabelTopToSleepConstraint: NSLayoutConstraint?
    
    // 选中信息框日期标签的动态约束
    var selectionDateLabelTopConstraint: NSLayoutConstraint?
    var selectionDateLabelTopToSleepConstraint: NSLayoutConstraint?
    
    // 选中信息框的动态约束（用于根据点击位置调整）
    var selectionInfoContainerCenterXConstraint: NSLayoutConstraint?
    var selectionInfoContainerWidthConstraint: NSLayoutConstraint?

    // MARK: - Navigation
    weak var navigationDelegate: LineChartViewNavigationDelegate?
    
    // MARK: - 交互状态
    /// 当前选中的数据点索引（nil 表示未选中）
    var selectedIndex: Int? = nil
    
    /// 选中指示线图层
    var selectionLineLayer: CAShapeLayer?
    
    /// 选中信息框容器视图（带圆角背景的浮动框）
    let selectionInfoContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DesignConstants.tabBarBackgroundColor
        view.layer.cornerRadius = 18
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    // 选中信息框内的标签（与默认布局一致）
    // 普通模式（心率、HRV）
    let selectionPeriodLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let selectionValueNumberLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let selectionValueUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let selectionDateLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 睡眠模式选中信息框组件
    let selectionBedTimeDot: UIView = {
        let view = UIView()
        view.backgroundColor = DesignConstants.darkGreen
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    let selectionBedTimePeriodLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let selectionBedTimeValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let selectionBedTimeHourUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let selectionBedTimeMinValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let selectionBedTimeMinUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let selectionSleepTimeDot: UIView = {
        let view = UIView()
        view.backgroundColor = DesignConstants.lightGreen
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    let selectionSleepTimePeriodLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let selectionSleepTimeValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let selectionSleepTimeHourUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let selectionSleepTimeMinValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let selectionSleepTimeMinUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = DesignConstants.grayColor
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init(type: ChartType) {
        self.chartType = type
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // 计算实际尺寸
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let periodLabelFontSize = scale(designPeriodLabelFontSize, basedOn: screenHeight, designDimension: designHeight)
        let valueNumberFontSize = scale(designValueNumberFontSize, basedOn: screenHeight, designDimension: designHeight)
        let valueUnitFontSize = scale(designValueUnitFontSize, basedOn: screenHeight, designDimension: designHeight)
        let dateRangeFontSize = scale(designDateRangeFontSize, basedOn: screenHeight, designDimension: designHeight)
        
        // 设置字体
        periodLabel.font = UIFont.systemFont(ofSize: periodLabelFontSize, weight: .regular)
        valueNumberLabel.font = UIFont.systemFont(ofSize: valueNumberFontSize, weight: .semibold)
        valueUnitLabel.font = UIFont.systemFont(ofSize: valueUnitFontSize, weight: .regular)
        dateRangeLabel.font = UIFont.systemFont(ofSize: dateRangeFontSize, weight: .regular)
        
        // 睡眠专用字体设置
        bedTimePeriodLabel.font = UIFont.systemFont(ofSize: periodLabelFontSize, weight: .regular)
        bedTimeValueLabel.font = UIFont.systemFont(ofSize: valueNumberFontSize, weight: .semibold)
        bedTimeHourUnitLabel.font = UIFont.systemFont(ofSize: valueUnitFontSize, weight: .regular)
        bedTimeMinValueLabel.font = UIFont.systemFont(ofSize: valueNumberFontSize, weight: .semibold)
        bedTimeMinUnitLabel.font = UIFont.systemFont(ofSize: valueUnitFontSize, weight: .regular)
        sleepTimePeriodLabel.font = UIFont.systemFont(ofSize: periodLabelFontSize, weight: .regular)
        sleepTimeValueLabel.font = UIFont.systemFont(ofSize: valueNumberFontSize, weight: .semibold)
        sleepTimeHourUnitLabel.font = UIFont.systemFont(ofSize: valueUnitFontSize, weight: .regular)
        sleepTimeMinValueLabel.font = UIFont.systemFont(ofSize: valueNumberFontSize, weight: .semibold)
        sleepTimeMinUnitLabel.font = UIFont.systemFont(ofSize: valueUnitFontSize, weight: .regular)
        
        // 选中信息框字体设置
        selectionPeriodLabel.font = UIFont.systemFont(ofSize: periodLabelFontSize, weight: .regular)
        selectionValueNumberLabel.font = UIFont.systemFont(ofSize: valueNumberFontSize, weight: .semibold)
        selectionValueUnitLabel.font = UIFont.systemFont(ofSize: valueUnitFontSize, weight: .regular)
        selectionDateLabel.font = UIFont.systemFont(ofSize: dateRangeFontSize, weight: .regular)
        
        // 选中信息框睡眠模式字体设置
        selectionBedTimePeriodLabel.font = UIFont.systemFont(ofSize: periodLabelFontSize, weight: .regular)
        selectionBedTimeValueLabel.font = UIFont.systemFont(ofSize: valueNumberFontSize, weight: .semibold)
        selectionBedTimeHourUnitLabel.font = UIFont.systemFont(ofSize: valueUnitFontSize, weight: .regular)
        selectionBedTimeMinValueLabel.font = UIFont.systemFont(ofSize: valueNumberFontSize, weight: .semibold)
        selectionBedTimeMinUnitLabel.font = UIFont.systemFont(ofSize: valueUnitFontSize, weight: .regular)
        selectionSleepTimePeriodLabel.font = UIFont.systemFont(ofSize: periodLabelFontSize, weight: .regular)
        selectionSleepTimeValueLabel.font = UIFont.systemFont(ofSize: valueNumberFontSize, weight: .semibold)
        selectionSleepTimeHourUnitLabel.font = UIFont.systemFont(ofSize: valueUnitFontSize, weight: .regular)
        selectionSleepTimeMinValueLabel.font = UIFont.systemFont(ofSize: valueNumberFontSize, weight: .semibold)
        selectionSleepTimeMinUnitLabel.font = UIFont.systemFont(ofSize: valueUnitFontSize, weight: .regular)
        
        // 添加子视图
        addSubview(periodLabel)
        addSubview(valueNumberLabel)
        addSubview(valueUnitLabel)
        addSubview(dateRangeLabel)
        addSubview(chartContainerView)
        chartContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加睡眠专用子视图
        addSubview(bedTimeDot)
        addSubview(bedTimePeriodLabel)
        addSubview(bedTimeValueLabel)
        addSubview(bedTimeHourUnitLabel)
        addSubview(bedTimeMinValueLabel)
        addSubview(bedTimeMinUnitLabel)
        addSubview(sleepTimeDot)
        addSubview(sleepTimePeriodLabel)
        addSubview(sleepTimeValueLabel)
        addSubview(sleepTimeHourUnitLabel)
        addSubview(sleepTimeMinValueLabel)
        addSubview(sleepTimeMinUnitLabel)
        
        // 添加选中信息框及其子视图
        addSubview(selectionInfoContainer)
        selectionInfoContainer.addSubview(selectionPeriodLabel)
        selectionInfoContainer.addSubview(selectionValueNumberLabel)
        selectionInfoContainer.addSubview(selectionValueUnitLabel)
        selectionInfoContainer.addSubview(selectionDateLabel)
        selectionInfoContainer.addSubview(selectionBedTimeDot)
        selectionInfoContainer.addSubview(selectionBedTimePeriodLabel)
        selectionInfoContainer.addSubview(selectionBedTimeValueLabel)
        selectionInfoContainer.addSubview(selectionBedTimeHourUnitLabel)
        selectionInfoContainer.addSubview(selectionBedTimeMinValueLabel)
        selectionInfoContainer.addSubview(selectionBedTimeMinUnitLabel)
        selectionInfoContainer.addSubview(selectionSleepTimeDot)
        selectionInfoContainer.addSubview(selectionSleepTimePeriodLabel)
        selectionInfoContainer.addSubview(selectionSleepTimeValueLabel)
        selectionInfoContainer.addSubview(selectionSleepTimeHourUnitLabel)
        selectionInfoContainer.addSubview(selectionSleepTimeMinValueLabel)
        selectionInfoContainer.addSubview(selectionSleepTimeMinUnitLabel)
        
        // 添加点击手势识别器
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleChartTap(_:)))
        chartContainerView.addGestureRecognizer(tapGesture)
        chartContainerView.isUserInteractionEnabled = true

        // 添加左右滑动手势，用于时间导航
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        chartContainerView.addGestureRecognizer(swipeLeft)
        chartContainerView.addGestureRecognizer(swipeRight)
        
        // 计算所有缩放后的间距
        let contentLeading = scale(designContentLeading, basedOn: screenWidth, designDimension: designWidth)
        let chartHorizontalMargin = scale(designChartHorizontalMargin, basedOn: screenWidth, designDimension: designWidth)
        let periodLabelTopMargin = scale(designPeriodLabelTopMargin, basedOn: screenHeight, designDimension: designHeight)
        let valueLabelTopMargin = scale(designValueLabelTopMargin, basedOn: screenHeight, designDimension: designHeight)
        let dateRangeTopMargin = scale(designDateRangeTopMargin, basedOn: screenHeight, designDimension: designHeight)
        let chartTopMargin = scale(designChartTopMargin, basedOn: screenHeight, designDimension: designHeight)
        let chartHeight = scale(designChartHeight, basedOn: screenHeight, designDimension: designHeight)
        
        // 选中信息框专用间距（保持原始值，不受正常状态间距修改的影响）
        let selectionPeriodLabelTopMargin = scale(0, basedOn: screenHeight, designDimension: designHeight)
        let selectionValueLabelTopMargin = scale(20, basedOn: screenHeight, designDimension: designHeight)
        let selectionDateRangeTopMargin = scale(20, basedOn: screenHeight, designDimension: designHeight)
        
        // 圆点尺寸
        let dotSize: CGFloat = scale(24, basedOn: screenHeight, designDimension: designHeight)
        let dotSpacing: CGFloat = scale(12, basedOn: screenWidth, designDimension: designWidth)
        let columnSpacing: CGFloat = scale(120, basedOn: screenWidth, designDimension: designWidth)  // 80 * 3 = 240
        let valueUnitSpacing: CGFloat = scale(30, basedOn: screenWidth, designDimension: designWidth)  // 数值和单位之间的间距，与心率一致
        
        NSLayoutConstraint.activate([
            // 日均/月均标签（第一行）在顶部，左对齐
            periodLabel.topAnchor.constraint(equalTo: topAnchor, constant: periodLabelTopMargin),
            periodLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentLeading),
            periodLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentLeading),
            
            // 数值标签（第二行）在日均/月均下方，距离10px（设计稿尺寸），左对齐
            valueNumberLabel.topAnchor.constraint(equalTo: periodLabel.bottomAnchor, constant: valueLabelTopMargin),
            valueNumberLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentLeading),
            
            // 单位标签与数值标签在同一基线上，紧跟在数值后面
            valueUnitLabel.leadingAnchor.constraint(equalTo: valueNumberLabel.trailingAnchor, constant: 8),
            valueUnitLabel.firstBaselineAnchor.constraint(equalTo: valueNumberLabel.firstBaselineAnchor),
            
            // 日期范围标签（第三行）- 约束稍后单独设置
            dateRangeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentLeading),
            dateRangeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentLeading),
            
            // 图表容器在日期范围下方，距离30px（设计稿尺寸），设置较大的固定高度，并延伸到底部
            chartContainerView.topAnchor.constraint(equalTo: dateRangeLabel.bottomAnchor, constant: chartTopMargin),
            chartContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: chartHorizontalMargin),
            chartContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -chartHorizontalMargin),
            chartContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: chartHeight),
            chartContainerView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: 0),
            
            // MARK: - 睡眠专用布局（两列）
            // 卧床时间圆点
            bedTimeDot.widthAnchor.constraint(equalToConstant: dotSize),
            bedTimeDot.heightAnchor.constraint(equalToConstant: dotSize),
            bedTimeDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentLeading),
            bedTimeDot.centerYAnchor.constraint(equalTo: bedTimePeriodLabel.centerYAnchor),
            
            // 卧床时间标签（第一行第一列）
            bedTimePeriodLabel.topAnchor.constraint(equalTo: topAnchor, constant: periodLabelTopMargin),
            bedTimePeriodLabel.leadingAnchor.constraint(equalTo: bedTimeDot.trailingAnchor, constant: dotSpacing),
            
            // 卧床时间小时数值（第二行第一列）
            bedTimeValueLabel.topAnchor.constraint(equalTo: bedTimePeriodLabel.bottomAnchor, constant: valueLabelTopMargin),
            bedTimeValueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentLeading),
            
            // 卧床时间小时单位
            bedTimeHourUnitLabel.leadingAnchor.constraint(equalTo: bedTimeValueLabel.trailingAnchor, constant: valueUnitSpacing),
            bedTimeHourUnitLabel.firstBaselineAnchor.constraint(equalTo: bedTimeValueLabel.firstBaselineAnchor),
            
            // 卧床时间分钟数值
            bedTimeMinValueLabel.leadingAnchor.constraint(equalTo: bedTimeHourUnitLabel.trailingAnchor, constant: valueUnitSpacing),
            bedTimeMinValueLabel.firstBaselineAnchor.constraint(equalTo: bedTimeValueLabel.firstBaselineAnchor),
            
            // 卧床时间分钟单位
            bedTimeMinUnitLabel.leadingAnchor.constraint(equalTo: bedTimeMinValueLabel.trailingAnchor, constant: valueUnitSpacing),
            bedTimeMinUnitLabel.firstBaselineAnchor.constraint(equalTo: bedTimeValueLabel.firstBaselineAnchor),
            
            // 睡眠时间圆点
            sleepTimeDot.widthAnchor.constraint(equalToConstant: dotSize),
            sleepTimeDot.heightAnchor.constraint(equalToConstant: dotSize),
            sleepTimeDot.leadingAnchor.constraint(equalTo: bedTimeMinUnitLabel.trailingAnchor, constant: columnSpacing),
            sleepTimeDot.centerYAnchor.constraint(equalTo: sleepTimePeriodLabel.centerYAnchor),
            
            // 睡眠时间标签（第一行第二列）
            sleepTimePeriodLabel.topAnchor.constraint(equalTo: topAnchor, constant: periodLabelTopMargin),
            sleepTimePeriodLabel.leadingAnchor.constraint(equalTo: sleepTimeDot.trailingAnchor, constant: dotSpacing),
            
            // 睡眠时间小时数值（第二行第二列）
            sleepTimeValueLabel.topAnchor.constraint(equalTo: sleepTimePeriodLabel.bottomAnchor, constant: valueLabelTopMargin),
            sleepTimeValueLabel.leadingAnchor.constraint(equalTo: sleepTimeDot.leadingAnchor),
            
            // 睡眠时间小时单位
            sleepTimeHourUnitLabel.leadingAnchor.constraint(equalTo: sleepTimeValueLabel.trailingAnchor, constant: valueUnitSpacing),
            sleepTimeHourUnitLabel.firstBaselineAnchor.constraint(equalTo: sleepTimeValueLabel.firstBaselineAnchor),
            
            // 睡眠时间分钟数值
            sleepTimeMinValueLabel.leadingAnchor.constraint(equalTo: sleepTimeHourUnitLabel.trailingAnchor, constant: valueUnitSpacing),
            sleepTimeMinValueLabel.firstBaselineAnchor.constraint(equalTo: sleepTimeValueLabel.firstBaselineAnchor),
            
            // 睡眠时间分钟单位
            sleepTimeMinUnitLabel.leadingAnchor.constraint(equalTo: sleepTimeMinValueLabel.trailingAnchor, constant: valueUnitSpacing),
            sleepTimeMinUnitLabel.firstBaselineAnchor.constraint(equalTo: sleepTimeValueLabel.firstBaselineAnchor)
        ])
        
        // 设置圆点的圆角
        bedTimeDot.layer.cornerRadius = dotSize / 2
        sleepTimeDot.layer.cornerRadius = dotSize / 2
        
        // 设置日期范围标签的动态约束
        dateRangeLabelTopConstraint = dateRangeLabel.topAnchor.constraint(equalTo: valueNumberLabel.bottomAnchor, constant: dateRangeTopMargin)
        dateRangeLabelTopToSleepConstraint = dateRangeLabel.topAnchor.constraint(equalTo: bedTimeValueLabel.bottomAnchor, constant: dateRangeTopMargin)
        
        // 默认激活普通模式的约束
        dateRangeLabelTopConstraint?.isActive = true
        dateRangeLabelTopToSleepConstraint?.isActive = false
        
        // 设置选中信息框的约束
        let infoPadding: CGFloat = scale(30, basedOn: screenWidth, designDimension: designWidth)
        
        // 默认宽度（会在点击时动态调整）
        let defaultInfoWidth: CGFloat = screenWidth - 2 * (contentLeading - infoPadding)
        
        NSLayoutConstraint.activate([
            // 选中信息框定位在原来的三行文字区域（使用 centerX 和 width，便于动态调整）
            selectionInfoContainer.topAnchor.constraint(equalTo: topAnchor),
            selectionInfoContainer.bottomAnchor.constraint(equalTo: selectionDateLabel.bottomAnchor, constant: selectionPeriodLabelTopMargin + infoPadding / 2),
            
            // 普通模式标签（心率、HRV）
            selectionPeriodLabel.topAnchor.constraint(equalTo: selectionInfoContainer.topAnchor, constant: selectionPeriodLabelTopMargin + infoPadding / 2),
            selectionPeriodLabel.leadingAnchor.constraint(equalTo: selectionInfoContainer.leadingAnchor, constant: infoPadding),
            selectionPeriodLabel.trailingAnchor.constraint(equalTo: selectionInfoContainer.trailingAnchor, constant: -infoPadding),
            
            selectionValueNumberLabel.topAnchor.constraint(equalTo: selectionPeriodLabel.bottomAnchor, constant: selectionValueLabelTopMargin),
            selectionValueNumberLabel.leadingAnchor.constraint(equalTo: selectionInfoContainer.leadingAnchor, constant: infoPadding),
            
            selectionValueUnitLabel.leadingAnchor.constraint(equalTo: selectionValueNumberLabel.trailingAnchor, constant: 8),
            selectionValueUnitLabel.firstBaselineAnchor.constraint(equalTo: selectionValueNumberLabel.firstBaselineAnchor),
            
            // selectionDateLabel 的 top 约束通过动态约束设置
            selectionDateLabel.leadingAnchor.constraint(equalTo: selectionInfoContainer.leadingAnchor, constant: infoPadding),
            selectionDateLabel.trailingAnchor.constraint(equalTo: selectionInfoContainer.trailingAnchor, constant: -infoPadding),
            
            // 睡眠模式标签
            selectionBedTimeDot.widthAnchor.constraint(equalToConstant: dotSize),
            selectionBedTimeDot.heightAnchor.constraint(equalToConstant: dotSize),
            selectionBedTimeDot.leadingAnchor.constraint(equalTo: selectionInfoContainer.leadingAnchor, constant: infoPadding),
            selectionBedTimeDot.centerYAnchor.constraint(equalTo: selectionBedTimePeriodLabel.centerYAnchor),
            
            selectionBedTimePeriodLabel.topAnchor.constraint(equalTo: selectionInfoContainer.topAnchor, constant: selectionPeriodLabelTopMargin + infoPadding / 2),
            selectionBedTimePeriodLabel.leadingAnchor.constraint(equalTo: selectionBedTimeDot.trailingAnchor, constant: dotSpacing),
            
            selectionBedTimeValueLabel.topAnchor.constraint(equalTo: selectionBedTimePeriodLabel.bottomAnchor, constant: selectionValueLabelTopMargin),
            selectionBedTimeValueLabel.leadingAnchor.constraint(equalTo: selectionInfoContainer.leadingAnchor, constant: infoPadding),
            
            selectionBedTimeHourUnitLabel.leadingAnchor.constraint(equalTo: selectionBedTimeValueLabel.trailingAnchor, constant: valueUnitSpacing),
            selectionBedTimeHourUnitLabel.firstBaselineAnchor.constraint(equalTo: selectionBedTimeValueLabel.firstBaselineAnchor),
            
            selectionBedTimeMinValueLabel.leadingAnchor.constraint(equalTo: selectionBedTimeHourUnitLabel.trailingAnchor, constant: valueUnitSpacing),
            selectionBedTimeMinValueLabel.firstBaselineAnchor.constraint(equalTo: selectionBedTimeValueLabel.firstBaselineAnchor),
            
            selectionBedTimeMinUnitLabel.leadingAnchor.constraint(equalTo: selectionBedTimeMinValueLabel.trailingAnchor, constant: valueUnitSpacing),
            selectionBedTimeMinUnitLabel.firstBaselineAnchor.constraint(equalTo: selectionBedTimeValueLabel.firstBaselineAnchor),
            
            selectionSleepTimeDot.widthAnchor.constraint(equalToConstant: dotSize),
            selectionSleepTimeDot.heightAnchor.constraint(equalToConstant: dotSize),
            selectionSleepTimeDot.leadingAnchor.constraint(equalTo: selectionBedTimeMinUnitLabel.trailingAnchor, constant: columnSpacing),
            selectionSleepTimeDot.centerYAnchor.constraint(equalTo: selectionSleepTimePeriodLabel.centerYAnchor),
            
            selectionSleepTimePeriodLabel.topAnchor.constraint(equalTo: selectionInfoContainer.topAnchor, constant: selectionPeriodLabelTopMargin + infoPadding / 2),
            selectionSleepTimePeriodLabel.leadingAnchor.constraint(equalTo: selectionSleepTimeDot.trailingAnchor, constant: dotSpacing),
            
            selectionSleepTimeValueLabel.topAnchor.constraint(equalTo: selectionSleepTimePeriodLabel.bottomAnchor, constant: selectionValueLabelTopMargin),
            selectionSleepTimeValueLabel.leadingAnchor.constraint(equalTo: selectionSleepTimeDot.leadingAnchor),
            
            selectionSleepTimeHourUnitLabel.leadingAnchor.constraint(equalTo: selectionSleepTimeValueLabel.trailingAnchor, constant: valueUnitSpacing),
            selectionSleepTimeHourUnitLabel.firstBaselineAnchor.constraint(equalTo: selectionSleepTimeValueLabel.firstBaselineAnchor),
            
            selectionSleepTimeMinValueLabel.leadingAnchor.constraint(equalTo: selectionSleepTimeHourUnitLabel.trailingAnchor, constant: valueUnitSpacing),
            selectionSleepTimeMinValueLabel.firstBaselineAnchor.constraint(equalTo: selectionSleepTimeValueLabel.firstBaselineAnchor),
            
            selectionSleepTimeMinUnitLabel.leadingAnchor.constraint(equalTo: selectionSleepTimeMinValueLabel.trailingAnchor, constant: valueUnitSpacing),
            selectionSleepTimeMinUnitLabel.firstBaselineAnchor.constraint(equalTo: selectionSleepTimeValueLabel.firstBaselineAnchor)
        ])
        
        // 设置选中信息框圆点的圆角
        selectionBedTimeDot.layer.cornerRadius = dotSize / 2
        selectionSleepTimeDot.layer.cornerRadius = dotSize / 2
        
        // 设置选中信息框日期标签的动态约束
        selectionDateLabelTopConstraint = selectionDateLabel.topAnchor.constraint(equalTo: selectionValueNumberLabel.bottomAnchor, constant: selectionDateRangeTopMargin)
        selectionDateLabelTopToSleepConstraint = selectionDateLabel.topAnchor.constraint(equalTo: selectionBedTimeValueLabel.bottomAnchor, constant: selectionDateRangeTopMargin)
        
        // 默认激活普通模式的约束
        selectionDateLabelTopConstraint?.isActive = true
        selectionDateLabelTopToSleepConstraint?.isActive = false
        
        // 设置选中信息框的动态约束（centerX 和 width）
        selectionInfoContainerCenterXConstraint = selectionInfoContainer.centerXAnchor.constraint(equalTo: centerXAnchor)
        selectionInfoContainerWidthConstraint = selectionInfoContainer.widthAnchor.constraint(equalToConstant: defaultInfoWidth)
        selectionInfoContainerCenterXConstraint?.isActive = true
        selectionInfoContainerWidthConstraint?.isActive = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        // drawChart is implemented in the drawing extension (LineChartView+Drawing.swift)
        drawChart()
    }
    
    func configure(period: Period, data: [Double], referenceDate: Date = Date()) {
        self.period = period
        self.referenceDate = referenceDate
        self.dataPoints = data
        self.heartRateRangeData = []  // 清空范围数据
        self.sleepRangeData = []  // 清空睡眠范围数据
        self.dailySleepData = []  // 清空日视图睡眠数据
        clearSelection()  // 清除选中状态
        updateTitle()
        setNeedsLayout()
    }
    
    /// 配置心率范围数据（用于范围条形图）
    /// - Parameters:
    ///   - period: 时间周期
    ///   - rangeData: 心率范围数据数组
    func configureHeartRateRange(period: Period, rangeData: [HeartRateRangePoint], referenceDate: Date = Date()) {
        self.period = period
        self.referenceDate = referenceDate
        self.heartRateRangeData = rangeData
        // 同时设置 dataPoints 用于标题计算（使用范围的最大值）
        self.dataPoints = rangeData.map { $0.isValid ? $0.max : 0 }
        clearSelection()  // 清除选中状态
        updateTitle()
        setNeedsLayout()
    }
    
    /// 配置睡眠范围数据（用于所有视图的睡眠图表）
    /// 日视图：水平条形图，X轴为时间（20:00-10:00）
    /// 周/月/年视图：垂直范围柱状图，Y轴为时间点
    /// - Parameters:
    ///   - period: 时间周期
    ///   - rangeData: 睡眠范围数据数组
    func configureSleepRange(period: Period, rangeData: [SleepRangePoint], referenceDate: Date = Date()) {
        self.period = period
        self.referenceDate = referenceDate
        self.sleepRangeData = rangeData
        self.dailySleepData = []  // 清空旧的日视图数据
        // 计算平均睡眠时长用于标题显示
        let validData = rangeData.filter { $0.isValid }
        self.dataPoints = validData.map { ($0.sleepEndMinutes - $0.sleepStartMinutes) / 60.0 }  // 转换为小时
        clearSelection()  // 清除选中状态
        updateTitle()
        setNeedsLayout()
    }
    
    /// 配置日视图睡眠数据（已弃用，请使用 configureSleepRange）
    /// - Parameters:
    ///   - dailyData: 每小时的睡眠数据数组（24个元素）
    func configureDailySleep(dailyData: [DailySleepPoint], referenceDate: Date = Date()) {
        self.period = .daily
        self.referenceDate = referenceDate
        self.dailySleepData = dailyData
        self.sleepRangeData = []  // 清空范围数据
        // 计算总睡眠时长用于标题显示
        let totalSleepMinutes = dailyData.reduce(0.0) { $0 + $1.sleepMinutes }
        self.dataPoints = [totalSleepMinutes / 60.0]  // 转换为小时
        clearSelection()  // 清除选中状态
        updateTitle()
        setNeedsLayout()
    }
    
    private func updateTitle() {
        guard !dataPoints.isEmpty else { return }
        
        // 只计算非零的数据点
        let nonZeroPoints = dataPoints.filter { $0 > 0 }
        
        // 睡眠图表使用特殊的两列布局
        if chartType == .sleep {
            updateSleepTitle()
            return
        }
        
        // 隐藏睡眠专用组件
        hideSleepComponents()
        showDefaultComponents()
        
        // 根据图表类型决定显示方式
        if chartType == .heartRate {
            // 心率：显示范围（最小值-最大值）
            let minValue: Double
            let maxValue: Double
            
            // 优先使用心率范围数据
            if !heartRateRangeData.isEmpty {
                let validRangeData = heartRateRangeData.filter { $0.isValid }
                if validRangeData.isEmpty {
                    minValue = 0
                    maxValue = 0
                } else {
                    minValue = validRangeData.map { $0.min }.min() ?? 0
                    maxValue = validRangeData.map { $0.max }.max() ?? 0
                }
            } else if nonZeroPoints.isEmpty {
                minValue = 0
                maxValue = 0
            } else {
                minValue = nonZeroPoints.min() ?? 0
                maxValue = nonZeroPoints.max() ?? 0
            }
            let rangeString = String(format: "%.0f-%.0f", minValue, maxValue)
            
            // 设置第一行：范围
            periodLabel.text = L("health.period.range")
            
            // 设置第二行：最小值-最大值范围和单位
            valueNumberLabel.text = rangeString
            valueUnitLabel.text = chartType.unit
        } else {
            // 心率变异性：显示平均值
            let average: Double
            if nonZeroPoints.isEmpty {
                average = 0
            } else {
                average = nonZeroPoints.reduce(0, +) / Double(nonZeroPoints.count)
            }
            let avgString = String(format: "%.0f", average)
            
            // 设置第一行：时均/日均/周均/月均
            switch period {
            case .daily:
                periodLabel.text = L("health.period.hourly_average")
            case .weekly:
                periodLabel.text = L("health.period.daily_average")
            case .monthly:
                periodLabel.text = L("health.period.daily_average")
            case .sixMonths:
                periodLabel.text = L("health.period.weekly_average")
            case .yearly:
                periodLabel.text = L("health.period.monthly_average")
            }
            
            // 设置第二行：数值和单位
            valueNumberLabel.text = avgString
            valueUnitLabel.text = chartType.unit
        }
        
        // 生成日期范围（第三行）
        updateDateRangeLabel()
    }
    
    /// 更新睡眠图表标题（两列布局）
    private func updateSleepTitle() {
        // 隐藏默认组件，显示睡眠专用组件
        hideDefaultComponents()
        showSleepComponents()
        
        // 计算卧床时间和睡眠时间
        // 卧床时间 = 入睡前清醒时间（从上床到入睡）
        let validData = sleepRangeData.filter { $0.isValid }
        
        let avgBedMinutes: Double
        let avgSleepMinutes: Double
        
        if validData.isEmpty {
            avgBedMinutes = 0
            avgSleepMinutes = 0
        } else {
            // 卧床时间 = 睡眠开始时间 - 上床时间（入睡前清醒时间）
            let totalBedMinutes = validData.reduce(0.0) { total, point in
                let beforeSleep = max(0, point.sleepStartMinutes - point.bedStartMinutes)
                return total + beforeSleep
            }
            let totalSleepMinutes = validData.reduce(0.0) { $0 + ($1.sleepEndMinutes - $1.sleepStartMinutes) }
            avgBedMinutes = totalBedMinutes / Double(validData.count)
            avgSleepMinutes = totalSleepMinutes / Double(validData.count)
        }
        
        // 转换为小时和分钟格式
        let bedHours = Int(avgBedMinutes / 60)
        let bedMins = Int(avgBedMinutes.truncatingRemainder(dividingBy: 60))
        let sleepHours = Int(avgSleepMinutes / 60)
        let sleepMins = Int(avgSleepMinutes.truncatingRemainder(dividingBy: 60))
        
        // 设置第一行标签
        switch period {
        case .daily:
            bedTimePeriodLabel.text = L("health.sleep.bed_time")
            sleepTimePeriodLabel.text = L("health.sleep.sleep_time")
        case .weekly, .monthly, .sixMonths, .yearly:
            bedTimePeriodLabel.text = L("health.sleep.avg_bed_time")
            sleepTimePeriodLabel.text = L("health.sleep.avg_sleep_time")
        }
        
        // 设置第二行数值和单位
        // 格式：小时数值(大) + 小时单位(小) + 分钟数值(大) + 分钟单位(小)
        bedTimeValueLabel.text = "\(bedHours)"
        bedTimeHourUnitLabel.text = L("health.period.hour")
        bedTimeMinValueLabel.text = String(format: "%02d", bedMins)
        bedTimeMinUnitLabel.text = L("health.unit.minutes")
        
        sleepTimeValueLabel.text = "\(sleepHours)"
        sleepTimeHourUnitLabel.text = L("health.period.hour")
        sleepTimeMinValueLabel.text = String(format: "%02d", sleepMins)
        sleepTimeMinUnitLabel.text = L("health.unit.minutes")
        
        // 更新日期范围（第三行）
        updateDateRangeLabel()
    }
    
    /// 更新日期范围标签
    private func updateDateRangeLabel() {
        let calendar = Calendar.current
        let anchor = referenceDate
        let anchorDayStart = calendar.startOfDay(for: anchor)
        
        switch period {
        case .daily:
            // 日视图：睡眠显示具体日期（昨晚的睡眠）
            if chartType == .sleep {
                let yesterday = calendar.date(byAdding: .day, value: -1, to: anchorDayStart) ?? anchorDayStart
                dateRangeLabel.text = formatSingleDate(yesterday)
            } else {
                dateRangeLabel.text = formatSingleDate(anchorDayStart)
            }
            
        case .weekly:
            // 周视图：显示最近7天 (xxxx年x月x日至x月x日)
            let startDate = calendar.date(byAdding: .day, value: -6, to: anchorDayStart) ?? anchorDayStart
            dateRangeLabel.text = formatDateRange(from: startDate, to: anchorDayStart)
            
        case .monthly:
            // 月视图：显示最近30天 (xxxx年x月x日至x月x日)
            let startDate = calendar.date(byAdding: .day, value: -29, to: anchorDayStart) ?? anchorDayStart
            dateRangeLabel.text = formatDateRange(from: startDate, to: anchorDayStart)
            
        case .sixMonths:
            // 半年视图：显示最近6个月 (xxxx年x月x日至x月x日)
            let startDate = calendar.date(byAdding: .month, value: -6, to: anchorDayStart) ?? anchorDayStart
            dateRangeLabel.text = formatDateRange(from: startDate, to: anchorDayStart)
            
        case .yearly:
            // 年视图：显示年份 (xxxx年)
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"+L("health.period.year")
            dateRangeLabel.text = yearFormatter.string(from: anchorDayStart)
        }
    }
    
    /// 格式化单个日期：xxxx年x月x日
    private func formatSingleDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(year)年\(month)月\(day)日"
    }
    
    /// 隐藏默认组件
    private func hideDefaultComponents() {
        periodLabel.isHidden = true
        valueNumberLabel.isHidden = true
        valueUnitLabel.isHidden = true
        dateRangeLabel.isHidden = true
    }
    
    /// 显示默认组件
    private func showDefaultComponents() {
        periodLabel.isHidden = false
        valueNumberLabel.isHidden = false
        valueUnitLabel.isHidden = false
        dateRangeLabel.isHidden = false
        
        // 切换约束：日期范围标签相对于 valueNumberLabel
        dateRangeLabelTopToSleepConstraint?.isActive = false
        dateRangeLabelTopConstraint?.isActive = true
    }
    
    /// 隐藏睡眠专用组件
    private func hideSleepComponents() {
        bedTimeDot.isHidden = true
        bedTimePeriodLabel.isHidden = true
        bedTimeValueLabel.isHidden = true
        bedTimeHourUnitLabel.isHidden = true
        bedTimeMinValueLabel.isHidden = true
        bedTimeMinUnitLabel.isHidden = true
        sleepTimeDot.isHidden = true
        sleepTimePeriodLabel.isHidden = true
        sleepTimeValueLabel.isHidden = true
        sleepTimeHourUnitLabel.isHidden = true
        sleepTimeMinValueLabel.isHidden = true
        sleepTimeMinUnitLabel.isHidden = true
    }
    
    /// 显示睡眠专用组件
    private func showSleepComponents() {
        bedTimeDot.isHidden = false
        bedTimePeriodLabel.isHidden = false
        bedTimeValueLabel.isHidden = false
        bedTimeHourUnitLabel.isHidden = false
        bedTimeMinValueLabel.isHidden = false
        bedTimeMinUnitLabel.isHidden = false
        sleepTimeDot.isHidden = false
        sleepTimePeriodLabel.isHidden = false
        sleepTimeValueLabel.isHidden = false
        sleepTimeHourUnitLabel.isHidden = false
        sleepTimeMinValueLabel.isHidden = false
        sleepTimeMinUnitLabel.isHidden = false
        
        // 显示日期范围标签（第三行），因为 hideDefaultComponents() 会隐藏它
        dateRangeLabel.isHidden = false
        
        // 切换约束：日期范围标签相对于 bedTimeValueLabel
        dateRangeLabelTopConstraint?.isActive = false
        dateRangeLabelTopToSleepConstraint?.isActive = true
    }
    
    /// 格式化日期范围：xxxx年x月x日至x月x日
    /// 如果跨年则显示完整的年月日
    private func formatDateRange(from startDate: Date, to endDate: Date) -> String {
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: startDate)
        let endYear = calendar.component(.year, from: endDate)
        let startMonth = calendar.component(.month, from: startDate)
        let endMonth = calendar.component(.month, from: endDate)
        let startDay = calendar.component(.day, from: startDate)
        let endDay = calendar.component(.day, from: endDate)
        
        if startYear == endYear {
            // 同一年：xxxx年x月x日至x月x日
            return "\(startYear)年\(startMonth)月\(startDay)日至\(endMonth)月\(endDay)日"
        } else {
            // 跨年：xxxx年x月x日至xxxx年x月x日
            return "\(startYear)年\(startMonth)月\(startDay)日至\(endYear)年\(endMonth)月\(endDay)日"
        }
    }
    
    // MARK: - 图表交互处理

    /// 处理左右滑动手势，通知外部导航
    /// 向右滑 = 时间向前（查看更早的数据）= previous
    /// 向左滑 = 时间向后（查看更新的数据）= next
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        // 右滑 = previous（时间向前，查看更早数据）
        // 左滑 = next（时间向后，查看更新数据）
        let direction: ChartSwipeDirection = gesture.direction == .right ? .previous : .next
        navigationDelegate?.chartViewDidRequestNavigation(self, direction: direction)
    }

    /// 在到达最新数据时给出明显的弹跳反馈动画
    /// - Parameter direction: 滑动方向，用于确定弹跳方向
    func playEdgeFeedback(direction: ChartSwipeDirection) {
        // 增强的弹跳效果：更大的位移和弹簧动画
        let translation: CGFloat = direction == .next ? 20 : -20
        
        // 先快速移动
        UIView.animate(
            withDuration: 0.1,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                self.chartContainerView.transform = CGAffineTransform(translationX: translation, y: 0)
            }
        ) { _ in
            // 使用弹簧动画返回原位
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.5,
                initialSpringVelocity: 0.8,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: {
                    self.chartContainerView.transform = .identity
                }
            )
        }
    }
    
    /// 处理图表点击事件
    @objc func handleChartTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: chartContainerView)
        
        // 计算点击位置对应的数据点索引
        if let tappedIndex = getDataPointIndex(at: location) {
            // 选中数据点
            selectDataPoint(at: tappedIndex)
        } else {
            // 点击空白区域，取消选中
            clearSelection()
        }
    }
    
    /// 根据点击位置获取数据点索引
    /// - Parameter location: 点击位置（在 chartContainerView 坐标系中）
    /// - Returns: 对应的数据点索引，如果没有命中则返回 nil
    private func getDataPointIndex(at location: CGPoint) -> Int? {
        let screenWidth = UIScreen.main.bounds.width
        let contentLeading = scale(designContentLeading, basedOn: screenWidth, designDimension: designWidth)
        
        let leftMargin: CGFloat = contentLeading - 10
        let rightMargin: CGFloat = contentLeading + 10
        let chartWidth = chartContainerView.bounds.width - leftMargin - rightMargin
        
        // 睡眠日视图特殊处理（水平条形图，只有一个数据点）
        if chartType == .sleep && period == .daily && !sleepRangeData.isEmpty {
            // 日视图只有一个数据点，点击图表区域即选中
            if sleepRangeData.first?.isValid == true {
                return 0
            }
            return nil
        }
        
        // 确定数据点数量
        let dataCount: Int
        if chartType == .sleep && !sleepRangeData.isEmpty {
            dataCount = sleepRangeData.count
        } else if chartType == .heartRate && !heartRateRangeData.isEmpty {
            dataCount = heartRateRangeData.count
        } else {
            dataCount = dataPoints.count
        }
        
        guard dataCount > 0 else { return nil }
        
        // 计算柱体宽度
        let barWidth: CGFloat
        switch period {
        case .daily:
            barWidth = scale(designDailyBarWidth, basedOn: screenWidth, designDimension: designWidth)
        case .weekly:
            barWidth = scale(designWeeklyBarWidth, basedOn: screenWidth, designDimension: designWidth)
        case .monthly:
            barWidth = scale(designMonthlyBarWidth, basedOn: screenWidth, designDimension: designWidth)
        case .sixMonths:
            barWidth = scale(designSixMonthsBarWidth, basedOn: screenWidth, designDimension: designWidth)
        case .yearly:
            barWidth = scale(designYearlyBarWidth, basedOn: screenWidth, designDimension: designWidth)
        }
        
        let totalBarsWidth = CGFloat(dataCount) * barWidth
        let spacing = dataCount > 1 ? (chartWidth - totalBarsWidth) / CGFloat(dataCount - 1) : 0
        
        // 增大点击热区（在柱子宽度基础上左右各扩展一定区域）
        let hitAreaExtension: CGFloat = max(spacing / 2, 10)
        
        // 遍历所有数据点，检查点击位置是否在某个数据点的范围内
        for index in 0..<dataCount {
            let barCenterX = leftMargin + CGFloat(index) * (barWidth + spacing) + barWidth / 2
            let hitAreaLeft = barCenterX - barWidth / 2 - hitAreaExtension
            let hitAreaRight = barCenterX + barWidth / 2 + hitAreaExtension
            
            if location.x >= hitAreaLeft && location.x <= hitAreaRight {
                // 检查数据是否有效
                if chartType == .sleep && !sleepRangeData.isEmpty {
                    if sleepRangeData[index].isValid {
                        return index
                    }
                } else if chartType == .heartRate && !heartRateRangeData.isEmpty {
                    if heartRateRangeData[index].isValid {
                        return index
                    }
                } else if dataPoints[index] > 0 {
                    return index
                }
            }
        }
        
        return nil
    }
    
    /// 选中指定索引的数据点
    /// - Parameter index: 数据点索引
    func selectDataPoint(at index: Int) {
        selectedIndex = index
        
        // 隐藏原始的三行文字标签
        hideDefaultComponents()
        hideSleepComponents()
        
        // 显示选中信息框
        selectionInfoContainer.isHidden = false
        
        // 更新选中信息框内容
        updateSelectionInfo(for: index)
        
        // 更新选中信息框位置和宽度
        updateSelectionInfoPosition(for: index)
        
        // 绘制选中指示线
        drawSelectionLine(for: index)
    }
    
    /// 清除选中状态
    func clearSelection() {
        selectedIndex = nil
        
        // 隐藏选中信息框
        selectionInfoContainer.isHidden = true
        
        // 移除选中指示线
        selectionLineLayer?.removeFromSuperlayer()
        selectionLineLayer = nil
        
        // 恢复原始的三行文字标签
        updateTitle()
    }
    
    /// 更新选中信息框的内容
    /// - Parameter index: 选中的数据点索引
    private func updateSelectionInfo(for index: Int) {
        // 根据图表类型显示不同的信息
        if chartType == .sleep {
            // 睡眠模式
            updateSelectionInfoForSleep(index: index)
        } else {
            // 心率或 HRV 模式
            updateSelectionInfoForDefault(index: index)
        }
    }
    
    /// 更新普通模式（心率、HRV）的选中信息
    private func updateSelectionInfoForDefault(index: Int) {
        // 隐藏睡眠模式的组件
        selectionBedTimeDot.isHidden = true
        selectionBedTimePeriodLabel.isHidden = true
        selectionBedTimeValueLabel.isHidden = true
        selectionBedTimeHourUnitLabel.isHidden = true
        selectionBedTimeMinValueLabel.isHidden = true
        selectionBedTimeMinUnitLabel.isHidden = true
        selectionSleepTimeDot.isHidden = true
        selectionSleepTimePeriodLabel.isHidden = true
        selectionSleepTimeValueLabel.isHidden = true
        selectionSleepTimeHourUnitLabel.isHidden = true
        selectionSleepTimeMinValueLabel.isHidden = true
        selectionSleepTimeMinUnitLabel.isHidden = true
        
        // 显示普通模式的组件
        selectionPeriodLabel.isHidden = false
        selectionValueNumberLabel.isHidden = false
        selectionValueUnitLabel.isHidden = false
        selectionDateLabel.isHidden = false
        
        // 切换约束：日期标签相对于 selectionValueNumberLabel
        selectionDateLabelTopToSleepConstraint?.isActive = false
        selectionDateLabelTopConstraint?.isActive = true
        
        if chartType == .heartRate {
            // 心率：显示范围
            if !heartRateRangeData.isEmpty && index < heartRateRangeData.count {
                let point = heartRateRangeData[index]
                selectionPeriodLabel.text = L("health.period.range")
                selectionValueNumberLabel.text = String(format: "%.0f-%.0f", point.min, point.max)
                selectionValueUnitLabel.text = chartType.unit
            }
        } else {
            // HRV：显示数值
            if index < dataPoints.count {
                let value = dataPoints[index]
                selectionPeriodLabel.text = getValueLabel()
                selectionValueNumberLabel.text = String(format: "%.0f", value)
                selectionValueUnitLabel.text = chartType.unit
            }
        }
        
        // 设置日期标签
        selectionDateLabel.text = getDateLabel(for: index)
    }
    
    /// 更新睡眠模式的选中信息
    private func updateSelectionInfoForSleep(index: Int) {
        // 隐藏普通模式的组件
        selectionPeriodLabel.isHidden = true
        selectionValueNumberLabel.isHidden = true
        selectionValueUnitLabel.isHidden = true
        selectionDateLabel.isHidden = false
        
        // 显示睡眠模式的组件
        selectionBedTimeDot.isHidden = false
        selectionBedTimePeriodLabel.isHidden = false
        selectionBedTimeValueLabel.isHidden = false
        selectionBedTimeHourUnitLabel.isHidden = false
        selectionBedTimeMinValueLabel.isHidden = false
        selectionBedTimeMinUnitLabel.isHidden = false
        selectionSleepTimeDot.isHidden = false
        selectionSleepTimePeriodLabel.isHidden = false
        selectionSleepTimeValueLabel.isHidden = false
        selectionSleepTimeHourUnitLabel.isHidden = false
        selectionSleepTimeMinValueLabel.isHidden = false
        selectionSleepTimeMinUnitLabel.isHidden = false
        
        // 切换约束：日期标签相对于 selectionBedTimeValueLabel
        selectionDateLabelTopConstraint?.isActive = false
        selectionDateLabelTopToSleepConstraint?.isActive = true
        
        if !sleepRangeData.isEmpty && index < sleepRangeData.count {
            let point = sleepRangeData[index]
            
            // 计算卧床时间和睡眠时间
            // 卧床时间 = 入睡前清醒时间（从上床到入睡）
            let bedMinutes = max(0, point.sleepStartMinutes - point.bedStartMinutes)
            let sleepMinutes = point.sleepEndMinutes - point.sleepStartMinutes
            
            let bedHours = Int(bedMinutes / 60)
            let bedMins = Int(bedMinutes.truncatingRemainder(dividingBy: 60))
            let sleepHours = Int(sleepMinutes / 60)
            let sleepMins = Int(sleepMinutes.truncatingRemainder(dividingBy: 60))
            
            // 设置标签
            selectionBedTimePeriodLabel.text = L("health.sleep.bed_time")
            selectionBedTimeValueLabel.text = "\(bedHours)"
            selectionBedTimeHourUnitLabel.text = L("health.period.hour")
            selectionBedTimeMinValueLabel.text = String(format: "%02d", bedMins)
            selectionBedTimeMinUnitLabel.text = L("health.unit.minutes")
            
            selectionSleepTimePeriodLabel.text = L("health.sleep.sleep_time")
            selectionSleepTimeValueLabel.text = "\(sleepHours)"
            selectionSleepTimeHourUnitLabel.text = L("health.period.hour")
            selectionSleepTimeMinValueLabel.text = String(format: "%02d", sleepMins)
            selectionSleepTimeMinUnitLabel.text = L("health.unit.minutes")
        }
        
        // 设置日期标签
        selectionDateLabel.text = getDateLabel(for: index)
    }
    
    /// 获取数值标签文本
    private func getValueLabel() -> String {
        switch period {
        case .daily:
            return L("health.period.hourly_average")
        case .weekly:
            return L("health.period.daily_average")
        case .monthly:
            return L("health.period.daily_average")
        case .sixMonths:
            return L("health.period.weekly_average")
        case .yearly:
            return L("health.period.monthly_average")
        }
    }
    
    /// 获取指定索引对应的日期标签
    private func getDateLabel(for index: Int) -> String {
        let calendar = Calendar.current
        let anchor = referenceDate
        let anchorDayStart = calendar.startOfDay(for: anchor)
        
        switch period {
        case .daily:
            // 日视图：如果是睡眠图表，显示昨天日期；否则显示小时
            if chartType == .sleep {
                let yesterday = calendar.date(byAdding: .day, value: -1, to: anchorDayStart) ?? anchorDayStart
                return formatSingleDate(yesterday)
            }
            return "\(index):00"
            
        case .weekly:
            // 周视图：显示日期
            if let date = calendar.date(byAdding: .day, value: index - 6, to: anchorDayStart) {
                return formatSingleDate(date)
            }
            return ""
            
        case .monthly:
            // 月视图：显示日期
            if let date = calendar.date(byAdding: .day, value: index - 29, to: anchorDayStart) {
                return formatSingleDate(date)
            }
            return ""
            
        case .sixMonths:
            // 半年视图：显示周
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: anchorDayStart)!
            let weekday = calendar.component(.weekday, from: sixMonthsAgo)
            let daysToSunday = (weekday - 1 + 7) % 7
            let startSunday = calendar.date(byAdding: .day, value: -daysToSunday, to: calendar.startOfDay(for: sixMonthsAgo))!
            if let date = calendar.date(byAdding: .weekOfYear, value: index, to: startSunday) {
                let month = calendar.component(.month, from: date)
                let day = calendar.component(.day, from: date)
                return "\(month)月\(day)日"
            }
            return ""
            
        case .yearly:
            // 年视图：显示月份
            let monthsAgo = 11 - index
            if let date = calendar.date(byAdding: .month, value: -monthsAgo, to: anchorDayStart) {
                let year = calendar.component(.year, from: date)
                let month = calendar.component(.month, from: date)
                return "\(year)年\(month)月"
            }
            return ""
        }
    }
    
    /// 更新选中信息框的位置和宽度
    /// - Parameter index: 选中的数据点索引
    private func updateSelectionInfoPosition(for index: Int) {
        let screenWidth = UIScreen.main.bounds.width
        let contentLeading = scale(designContentLeading, basedOn: screenWidth, designDimension: designWidth)
        
        let leftMargin: CGFloat = contentLeading - 10
        let rightMargin: CGFloat = contentLeading + 10
        let chartWidth = chartContainerView.bounds.width - leftMargin - rightMargin
        
        // 计算选中数据点的 X 位置（在 chartContainerView 坐标系中）
        let barCenterX: CGFloat
        
        // 睡眠日视图特殊处理
        if chartType == .sleep && period == .daily {
            barCenterX = leftMargin + chartWidth / 2
        } else {
            // 确定数据点数量
            let dataCount: Int
            if chartType == .sleep && !sleepRangeData.isEmpty {
                dataCount = sleepRangeData.count
            } else if chartType == .heartRate && !heartRateRangeData.isEmpty {
                dataCount = heartRateRangeData.count
            } else {
                dataCount = dataPoints.count
            }
            
            guard dataCount > 0, index < dataCount else { return }
            
            // 计算柱体宽度
            let barWidth: CGFloat
            switch period {
            case .daily:
                barWidth = scale(designDailyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            case .weekly:
                barWidth = scale(designWeeklyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            case .monthly:
                barWidth = scale(designMonthlyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            case .sixMonths:
                barWidth = scale(designSixMonthsBarWidth, basedOn: screenWidth, designDimension: designWidth)
            case .yearly:
                barWidth = scale(designYearlyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            }
            
            let totalBarsWidth = CGFloat(dataCount) * barWidth
            let spacing = dataCount > 1 ? (chartWidth - totalBarsWidth) / CGFloat(dataCount - 1) : 0
            barCenterX = leftMargin + CGFloat(index) * (barWidth + spacing) + barWidth / 2
        }
        
        // 将 barCenterX 转换到 self 坐标系
        let barCenterInSelf = chartContainerView.convert(CGPoint(x: barCenterX, y: 0), to: self)
        
        // 计算信息框需要的宽度
        let infoWidth = calculateSelectionInfoWidth()
        
        // 计算信息框的 centerX，尽量以灰线为中心，但不超出屏幕边界
        let minLeading: CGFloat = 10  // 最小左边距
        let minTrailing: CGFloat = 10  // 最小右边距
        let maxCenterX = bounds.width - minTrailing - infoWidth / 2
        let minCenterX = minLeading + infoWidth / 2
        
        // 理想情况下 centerX 等于 barCenterInSelf.x
        var targetCenterX = barCenterInSelf.x
        
        // 限制在可用范围内
        targetCenterX = max(minCenterX, min(maxCenterX, targetCenterX))
        
        // 更新约束
        selectionInfoContainerCenterXConstraint?.constant = targetCenterX - bounds.width / 2
        selectionInfoContainerWidthConstraint?.constant = infoWidth
        
        // 触发布局更新
        layoutIfNeeded()
    }
    
    /// 计算选中信息框需要的宽度
    private func calculateSelectionInfoWidth() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let infoPadding: CGFloat = scale(30, basedOn: screenWidth, designDimension: designWidth)
        
        // 强制更新标签的 intrinsicContentSize
        selectionPeriodLabel.sizeToFit()
        selectionValueNumberLabel.sizeToFit()
        selectionValueUnitLabel.sizeToFit()
        selectionDateLabel.sizeToFit()
        
        if chartType == .sleep {
            // 睡眠模式：计算两列布局的宽度
            selectionBedTimePeriodLabel.sizeToFit()
            selectionBedTimeValueLabel.sizeToFit()
            selectionBedTimeHourUnitLabel.sizeToFit()
            selectionBedTimeMinValueLabel.sizeToFit()
            selectionBedTimeMinUnitLabel.sizeToFit()
            selectionSleepTimePeriodLabel.sizeToFit()
            selectionSleepTimeValueLabel.sizeToFit()
            selectionSleepTimeHourUnitLabel.sizeToFit()
            selectionSleepTimeMinValueLabel.sizeToFit()
            selectionSleepTimeMinUnitLabel.sizeToFit()
            
            let valueUnitSpacing: CGFloat = scale(30, basedOn: screenWidth, designDimension: designWidth)
            let columnSpacing: CGFloat = scale(120, basedOn: screenWidth, designDimension: designWidth)
            let dotSize: CGFloat = scale(24, basedOn: screenHeight, designDimension: designHeight)
            let dotSpacing: CGFloat = scale(12, basedOn: screenWidth, designDimension: designWidth)
            
            // 第一列宽度：圆点 + 间距 + 数值 + 间距 + 小时单位 + 间距 + 分钟数值 + 间距 + 分钟单位
            let bedTimeWidth = dotSize + dotSpacing + selectionBedTimeValueLabel.intrinsicContentSize.width +
                valueUnitSpacing + selectionBedTimeHourUnitLabel.intrinsicContentSize.width +
                valueUnitSpacing + selectionBedTimeMinValueLabel.intrinsicContentSize.width +
                valueUnitSpacing + selectionBedTimeMinUnitLabel.intrinsicContentSize.width
            
            // 第二列宽度
            let sleepTimeWidth = dotSize + dotSpacing + selectionSleepTimeValueLabel.intrinsicContentSize.width +
                valueUnitSpacing + selectionSleepTimeHourUnitLabel.intrinsicContentSize.width +
                valueUnitSpacing + selectionSleepTimeMinValueLabel.intrinsicContentSize.width +
                valueUnitSpacing + selectionSleepTimeMinUnitLabel.intrinsicContentSize.width
            
            // 日期行宽度
            let dateWidth = selectionDateLabel.intrinsicContentSize.width
            
            // 总宽度 = 左边距 + 两列 + 列间距 + 右边距
            let totalContentWidth = bedTimeWidth + columnSpacing + sleepTimeWidth
            let totalWidth = max(totalContentWidth, dateWidth) + 2 * infoPadding
            
            return min(totalWidth, screenWidth - 20)  // 不超过屏幕宽度
        } else {
            // 普通模式（心率、HRV）
            let periodWidth = selectionPeriodLabel.intrinsicContentSize.width
            let valueWidth = selectionValueNumberLabel.intrinsicContentSize.width + 8 + selectionValueUnitLabel.intrinsicContentSize.width
            let dateWidth = selectionDateLabel.intrinsicContentSize.width
            
            let maxContentWidth = max(periodWidth, max(valueWidth, dateWidth))
            let totalWidth = maxContentWidth + 2 * infoPadding
            
            return min(totalWidth, screenWidth - 20)  // 不超过屏幕宽度
        }
    }
    
    /// 绘制选中指示线
    /// - Parameter index: 选中的数据点索引
    private func drawSelectionLine(for index: Int) {
        // 移除旧的指示线
        selectionLineLayer?.removeFromSuperlayer()
        
        let screenWidth = UIScreen.main.bounds.width
        let contentLeading = scale(designContentLeading, basedOn: screenWidth, designDimension: designWidth)
        
        let leftMargin: CGFloat = contentLeading - 10
        // 睡眠图表右边距更大，需要为Y轴时间标签留出空间
        let rightMargin: CGFloat
        if chartType == .sleep {
            rightMargin = contentLeading + 30
        } else {
            rightMargin = contentLeading + 10
        }
        let chartWidth = chartContainerView.bounds.width - leftMargin - rightMargin
        let bottomMargin: CGFloat = 40
        let topMargin: CGFloat = 20
        let chartHeight = chartContainerView.bounds.height - bottomMargin - topMargin
        
        // 睡眠日视图特殊处理（水平条形图，绘制在中心位置）
        if chartType == .sleep && period == .daily {
            // 日视图绘制在图表中心，Y起点为图表顶部
            let barCenterX = leftMargin + chartWidth / 2
            drawSelectionLineAt(x: barCenterX, yStart: topMargin, screenWidth: screenWidth)
            return
        }
        
        // 确定数据点数量和获取数据值
        let dataCount: Int
        let dataTopY: CGFloat
        
        if chartType == .sleep && !sleepRangeData.isEmpty {
            dataCount = sleepRangeData.count
            guard index < dataCount else { return }
            
            // 睡眠范围图的顶端Y坐标（使用卧床开始时间，即柱子顶端）
            let point = sleepRangeData[index]
            if point.isValid {
                // 与 drawSleepVerticalRangeChart 保持一致的Y轴范围计算
                let validData = sleepRangeData.filter { $0.isValid }
                let dataMinMinutes = validData.map { min($0.bedStartMinutes, $0.sleepStartMinutes) }.min() ?? 0
                let dataMaxMinutes = validData.map { max($0.bedEndMinutes, $0.sleepEndMinutes) }.max() ?? 840
                
                // 向下取整到最近的2小时（120分钟）
                let yMinMinutes = max(0, floor(dataMinMinutes / 120) * 120)
                // 向上取整到最近的2小时
                let yMaxMinutes = min(960, ceil(dataMaxMinutes / 120) * 120)
                let yRangeMinutes = yMaxMinutes - yMinMinutes
                
                guard yRangeMinutes > 0 else { return }
                
                // Y轴：bedStartMinutes 对应柱子顶端
                let normalizedStart = (point.bedStartMinutes - yMinMinutes) / yRangeMinutes
                dataTopY = topMargin + chartHeight * CGFloat(normalizedStart)
            } else {
                dataTopY = topMargin + chartHeight
            }
        } else if chartType == .heartRate && !heartRateRangeData.isEmpty {
            dataCount = heartRateRangeData.count
            guard index < dataCount else { return }
            
            // 心率范围图的顶端Y坐标（使用最大值）
            let point = heartRateRangeData[index]
            if point.isValid {
                let maxValue = heartRateRangeData.filter { $0.isValid }.map { $0.max }.max() ?? 1
                let yMax = ceil(maxValue / 10) * 10
                let normalizedMax = point.max / yMax
                dataTopY = topMargin + chartHeight * (1 - normalizedMax)
            } else {
                dataTopY = topMargin + chartHeight
            }
        } else if chartType == .hrv && !dataPoints.isEmpty {
            dataCount = dataPoints.count
            guard index < dataCount else { return }
            
            // HRV折线图的顶端Y坐标（从圆周顶端开始，不是圆心）
            let value = dataPoints[index]
            let maxValue = dataPoints.max() ?? 1
            let yMax = ceil(maxValue / 10) * 10
            let normalizedValue = value / yMax
            let circleRadius: CGFloat = 3.5  // 与绘制时相同的圆圈半径
            // 圆心Y坐标减去半径，得到圆周顶端
            dataTopY = topMargin + chartHeight * (1 - normalizedValue) - circleRadius
        } else {
            dataCount = dataPoints.count
            guard index < dataCount else { return }
            
            // 普通柱状图的顶端Y坐标
            let value = dataPoints[index]
            let maxValue = dataPoints.max() ?? 1
            let yMax = ceil(maxValue / 10) * 10
            let normalizedValue = value / yMax
            dataTopY = topMargin + chartHeight * (1 - normalizedValue)
        }
        
        guard dataCount > 0, index < dataCount else { return }
        
        // 计算柱体宽度
        let barWidth: CGFloat
        switch period {
        case .daily:
            barWidth = scale(designDailyBarWidth, basedOn: screenWidth, designDimension: designWidth)
        case .weekly:
            barWidth = scale(designWeeklyBarWidth, basedOn: screenWidth, designDimension: designWidth)
        case .monthly:
            barWidth = scale(designMonthlyBarWidth, basedOn: screenWidth, designDimension: designWidth)
        case .sixMonths:
            barWidth = scale(designSixMonthsBarWidth, basedOn: screenWidth, designDimension: designWidth)
        case .yearly:
            barWidth = scale(designYearlyBarWidth, basedOn: screenWidth, designDimension: designWidth)
        }
        
        let totalBarsWidth = CGFloat(dataCount) * barWidth
        let spacing = dataCount > 1 ? (chartWidth - totalBarsWidth) / CGFloat(dataCount - 1) : 0
        
        // 计算柱子的 X 坐标（中心位置）
        let barCenterX = leftMargin + CGFloat(index) * (barWidth + spacing) + barWidth / 2
        
        drawSelectionLineAt(x: barCenterX, yStart: dataTopY, screenWidth: screenWidth)
    }
    
    /// 在指定X位置绘制选中指示线
    private func drawSelectionLineAt(x barCenterX: CGFloat, yStart: CGFloat, screenWidth: CGFloat) {
        // 指示线宽度（设计稿 8px）
        let lineWidth = scale(8, basedOn: screenWidth, designDimension: designWidth)
        
        // 指示线起点：从数据点的顶端开始
        // 我们需要将坐标从 chartContainerView 转换到 self
        let lineStartInChart = CGPoint(x: barCenterX, y: yStart)
        let lineStartInSelf = chartContainerView.convert(lineStartInChart, to: self)
        
        // 线条终点是信息框底部
        let lineEndY = selectionInfoContainer.frame.maxY
        
        // 创建指示线路径
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: lineStartInSelf.x, y: lineEndY))
        linePath.addLine(to: CGPoint(x: lineStartInSelf.x, y: lineStartInSelf.y))
        
        // 创建指示线图层
        let lineLayer = CAShapeLayer()
        lineLayer.path = linePath.cgPath
        lineLayer.strokeColor = UIColor(red: 72/255.0, green: 72/255.0, blue: 73/255.0, alpha: 1.0).cgColor  // #484849
        lineLayer.lineWidth = lineWidth
        lineLayer.lineCap = .round
        lineLayer.fillColor = nil
        
        // 添加到视图层级
        layer.insertSublayer(lineLayer, below: selectionInfoContainer.layer)
        selectionLineLayer = lineLayer
    }
    
    // NOTE: chart drawing implementation moved to LineChartView+Drawing.swift
    
    /// 绘制背景网格线
    // NOTE: grid line drawing moved to LineChartView+Drawing.swift
    
    /// 绘制竖向网格线（虚线）- 智能排列，有强弱区分
    // NOTE: vertical grid line drawing moved to LineChartView+Drawing.swift
    
    // NOTE: sampling helpers moved to LineChartView+Drawing.swift
    
    // NOTE: sampling helpers moved to LineChartView+Drawing.swift
    
    // NOTE: X axis label drawing moved to LineChartView+Drawing.swift
}
