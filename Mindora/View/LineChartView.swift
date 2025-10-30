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

/// 折线图视图，支持月度和年度数据展示
/// 采用带圆角的柱状图样式，包含标题、Y轴刻度和X轴标签
final class LineChartView: UIView {
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    private let designMetricNameFontSize: CGFloat = 54         // 指标名称字体大小（如"心率"）
    private let designMetricContainerWidth: CGFloat = 1128     // 指标名称容器宽度
    private let designMetricContainerHeight: CGFloat = 90      // 指标名称容器高度
    private let designMetricContainerCornerRadius: CGFloat = 45 // 指标名称容器圆角
    private let designMetricContainerTopMargin: CGFloat = -48   // 指标名称容器距离顶部的距离
    private let designIconTextSpacing: CGFloat = 30            // 图标和文字之间的距离
    
    // 垂直间距（设计稿尺寸）
    private let designPeriodLabelTopMargin: CGFloat = 30       // 日均/月均标签距离容器底部的距离
    private let designValueLabelTopMargin: CGFloat = 1        // 数值行距离日均/月均的距离
    private let designDateRangeTopMargin: CGFloat = 3         // 日期范围距离数值的距离
    private let designChartTopMargin: CGFloat = -25            // 图表容器距离日期范围的距离（设计稿精确值）
    private let designChartHeight: CGFloat = 950               // 图表容器的高度（设计稿尺寸）
    
    // 字体大小
    private let designPeriodLabelFontSize: CGFloat = 42        // 日均/月均字体大小
    private let designValueNumberFontSize: CGFloat = 108       // 数值字体大小（如"76"）
    private let designValueUnitFontSize: CGFloat = 54          // 单位字体大小（如"次/分"）
    private let designDateRangeFontSize: CGFloat = 54          // 日期范围字体大小
    private let designAxisLabelFontSize: CGFloat = 42          // 坐标轴标签字体大小 - 从54减小到42
    
    // 水平间距（设计稿尺寸）
    private let designContentLeading: CGFloat = 60           // 内容左边距
    private let designChartHorizontalMargin: CGFloat = 30      // 图表左右边距
    
    // 图标尺寸（设计稿尺寸）
    private let designHealthIconWidth: CGFloat = 43
    private let designHealthIconHeight: CGFloat = 40
    private let designHRVIconWidth: CGFloat = 47
    private let designHRVIconHeight: CGFloat = 42
    private let designSleepIconWidth: CGFloat = 56
    private let designSleepIconHeight: CGFloat = 36
    
    // 计算实际尺寸的辅助方法
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    enum ChartType {
        case heartRate
        case hrv
        case sleep
        
        var color: UIColor {
            switch self {
            case .heartRate: return DesignConstants.chartColorHeartRate
            case .hrv: return DesignConstants.chartColorHRV
            case .sleep: return DesignConstants.chartColorSleep
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
    
    enum Period {
        case monthly
        case yearly
    }
    
    private let chartType: ChartType
    private var period: Period = .monthly
    private var dataPoints: [Double] = []
    
    // 柱状图尺寸常量（从 DesignConstants 复制过来）
    private let designMonthlyBarWidth: CGFloat = 17
    private let designMonthlyBarCornerRadius: CGFloat = 5
    private let designYearlyBarWidth: CGFloat = 57
    private let designYearlyBarCornerRadius: CGFloat = 15
    
    // UI Components
    // 指标名称容器（包含图标和文字的圆角矩形背景）
    private let metricNameContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 58/255.0, green: 58/255.0, blue: 58/255.0, alpha: 1.0)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 指标图标
    private let metricIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        // 不使用自动布局，因为我们在 layoutSubviews 中手动设置 frame
        imageView.translatesAutoresizingMaskIntoConstraints = true
        return imageView
    }()
    
    // 指标名称标签（如"心率"、"心率变异性"、"睡眠"）
    private let metricNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        // 不使用自动布局，因为我们在 layoutSubviews 中手动设置 frame
        label.translatesAutoresizingMaskIntoConstraints = true
        return label
    }()
    
    // 日均/月均标签（第一行）
    private let periodLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(white: 1.0, alpha: 0.8)
        label.textAlignment = .left  // 左对齐
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 数值标签（第二行 - 数值部分）
    private let valueNumberLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left  // 左对齐
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 单位标签（第二行 - 单位部分）
    private let valueUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left  // 左对齐
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 日期范围标签（第三行）
    private let dateRangeLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(white: 1.0, alpha: 0.6)
        label.textAlignment = .left  // 左对齐
        // 字体大小会在 setupUI 中设置
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let chartContainerView = UIView()
    private var barLayers: [CAShapeLayer] = []
    private var yAxisLabels: [UILabel] = []
    private var xAxisLabels: [UILabel] = []
    
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
        let metricNameFontSize = scale(designMetricNameFontSize, basedOn: screenHeight, designDimension: designHeight)
        let periodLabelFontSize = scale(designPeriodLabelFontSize, basedOn: screenHeight, designDimension: designHeight)
        let valueNumberFontSize = scale(designValueNumberFontSize, basedOn: screenHeight, designDimension: designHeight)
        let valueUnitFontSize = scale(designValueUnitFontSize, basedOn: screenHeight, designDimension: designHeight)
        let dateRangeFontSize = scale(designDateRangeFontSize, basedOn: screenHeight, designDimension: designHeight)
        
        // 计算指标名称容器的尺寸
        let containerWidth = scale(designMetricContainerWidth, basedOn: screenWidth, designDimension: designWidth)
        let containerHeight = scale(designMetricContainerHeight, basedOn: screenHeight, designDimension: designHeight)
        let cornerRadius = scale(designMetricContainerCornerRadius, basedOn: screenHeight, designDimension: designHeight)
        
        // 设置容器圆角
        metricNameContainer.layer.cornerRadius = cornerRadius
        metricNameContainer.layer.masksToBounds = true
        
        // 设置字体
        metricNameLabel.font = UIFont.systemFont(ofSize: metricNameFontSize, weight: .medium)
        periodLabel.font = UIFont.systemFont(ofSize: periodLabelFontSize, weight: .regular)
        valueNumberLabel.font = UIFont.systemFont(ofSize: valueNumberFontSize, weight: .semibold)
        valueUnitLabel.font = UIFont.systemFont(ofSize: valueUnitFontSize, weight: .regular)
        dateRangeLabel.font = UIFont.systemFont(ofSize: dateRangeFontSize, weight: .regular)
        
        // 设置指标名称和图标
        metricNameLabel.text = chartType.title
        metricIconView.image = UIImage(named: chartType.iconName)
        
        // 添加子视图
        metricNameContainer.addSubview(metricIconView)
        metricNameContainer.addSubview(metricNameLabel)
        
        addSubview(metricNameContainer)
        addSubview(periodLabel)
        addSubview(valueNumberLabel)
        addSubview(valueUnitLabel)
        addSubview(dateRangeLabel)
        addSubview(chartContainerView)
        chartContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 计算所有缩放后的间距
        let containerTopMargin = scale(designMetricContainerTopMargin, basedOn: screenHeight, designDimension: designHeight)
        let contentLeading = scale(designContentLeading, basedOn: screenWidth, designDimension: designWidth)
        let chartHorizontalMargin = scale(designChartHorizontalMargin, basedOn: screenWidth, designDimension: designWidth)
        let periodLabelTopMargin = scale(designPeriodLabelTopMargin, basedOn: screenHeight, designDimension: designHeight)
        let valueLabelTopMargin = scale(designValueLabelTopMargin, basedOn: screenHeight, designDimension: designHeight)
        let dateRangeTopMargin = scale(designDateRangeTopMargin, basedOn: screenHeight, designDimension: designHeight)
        let chartTopMargin = scale(designChartTopMargin, basedOn: screenHeight, designDimension: designHeight)
        let chartHeight = scale(designChartHeight, basedOn: screenHeight, designDimension: designHeight)
        
        NSLayoutConstraint.activate([
            // 指标名称容器在顶部，距离顶部82px（设计稿尺寸）
            metricNameContainer.topAnchor.constraint(equalTo: topAnchor, constant: containerTopMargin),
            metricNameContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            metricNameContainer.widthAnchor.constraint(equalToConstant: containerWidth),
            metricNameContainer.heightAnchor.constraint(equalToConstant: containerHeight),
            
            // 日均/月均标签（第一行）在容器下方，距离30px（设计稿尺寸），左对齐
            periodLabel.topAnchor.constraint(equalTo: metricNameContainer.bottomAnchor, constant: periodLabelTopMargin),
            periodLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentLeading),
            periodLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentLeading),
            
            // 数值标签（第二行）在日均/月均下方，距离10px（设计稿尺寸），左对齐
            valueNumberLabel.topAnchor.constraint(equalTo: periodLabel.bottomAnchor, constant: valueLabelTopMargin),
            valueNumberLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentLeading),
            
            // 单位标签与数值标签在同一基线上，紧跟在数值后面
            valueUnitLabel.leadingAnchor.constraint(equalTo: valueNumberLabel.trailingAnchor, constant: 8),
            valueUnitLabel.firstBaselineAnchor.constraint(equalTo: valueNumberLabel.firstBaselineAnchor),
            
            // 日期范围标签（第三行）在数值下方，距离10px（设计稿尺寸），左对齐
            dateRangeLabel.topAnchor.constraint(equalTo: valueNumberLabel.bottomAnchor, constant: dateRangeTopMargin),
            dateRangeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentLeading),
            dateRangeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentLeading),
            
            // 图表容器在日期范围下方，距离30px（设计稿尺寸），设置较大的固定高度，并延伸到底部
            chartContainerView.topAnchor.constraint(equalTo: dateRangeLabel.bottomAnchor, constant: chartTopMargin),
            chartContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: chartHorizontalMargin),
            chartContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -chartHorizontalMargin),
            chartContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: chartHeight),
            chartContainerView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: 0)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 在布局时，将图标和文字组合居中
        // 使用frame方式手动布局，确保居中对齐
        let screenWidth = UIScreen.main.bounds.width
        let _ = UIScreen.main.bounds.height
        let iconTextSpacing = scale(designIconTextSpacing, basedOn: screenWidth, designDimension: designWidth)
        
        // 重新计算图标尺寸（每次布局时都重新计算）
        // 注意：图标的宽度和高度都基于宽度转换，保持图标的原始宽高比
        let iconWidth: CGFloat
        let iconHeight: CGFloat
        switch chartType {
        case .heartRate:
            iconWidth = scale(designHealthIconWidth, basedOn: screenWidth, designDimension: designWidth)
            iconHeight = scale(designHealthIconHeight, basedOn: screenWidth, designDimension: designWidth)
        case .hrv:
            iconWidth = scale(designHRVIconWidth, basedOn: screenWidth, designDimension: designWidth)
            iconHeight = scale(designHRVIconHeight, basedOn: screenWidth, designDimension: designWidth)
        case .sleep:
            iconWidth = scale(designSleepIconWidth, basedOn: screenWidth, designDimension: designWidth)
            iconHeight = scale(designSleepIconHeight, basedOn: screenWidth, designDimension: designWidth)
        }
        
        // 计算文字大小
        metricNameLabel.sizeToFit()
        let textWidth = metricNameLabel.bounds.width
        let textHeight = metricNameLabel.bounds.height
        
        // 计算总宽度（图标宽度 + 间距 + 文字宽度）
        let totalWidth = iconWidth + iconTextSpacing + textWidth
        
        // 计算起始X位置（居中）
        let startX = (metricNameContainer.bounds.width - totalWidth) / 2
        
        // 设置图标位置（垂直居中）
        let iconY = (metricNameContainer.bounds.height - iconHeight) / 2
        metricIconView.frame = CGRect(x: startX, y: iconY, width: iconWidth, height: iconHeight)
        
        // 设置文字位置（垂直居中）
        let textX = startX + iconWidth + iconTextSpacing
        let textY = (metricNameContainer.bounds.height - textHeight) / 2
        metricNameLabel.frame = CGRect(x: textX, y: textY, width: textWidth, height: textHeight)
        
        drawChart()
    }
    
    func configure(period: Period, data: [Double]) {
        self.period = period
        self.dataPoints = data
        updateTitle()
        setNeedsLayout()
    }
    
    private func updateTitle() {
        guard !dataPoints.isEmpty else { return }
        
        // 计算平均值
        let average = dataPoints.reduce(0, +) / Double(dataPoints.count)
        let avgString = String(format: "%.0f", average)
        
        // 设置第一行：日均/月均
        switch period {
        case .monthly:
            periodLabel.text = L("health.period.daily_average")
        case .yearly:
            periodLabel.text = L("health.period.monthly_average")
        }
        
        // 设置第二行：数值和单位
        valueNumberLabel.text = avgString
        valueUnitLabel.text = chartType.unit
        
        // 生成日期范围（第三行）
        let calendar = Calendar.current
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年M月d日"
        
        let startDate: Date
        let endDate = now
        
        switch period {
        case .monthly:
            startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .yearly:
            startDate = calendar.date(byAdding: .month, value: -12, to: now) ?? now
        }
        
        dateRangeLabel.text = "\(dateFormatter.string(from: startDate))至\(dateFormatter.string(from: endDate))"
    }
    
    private func drawChart() {
        // 清除旧的图层和标签
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers.removeAll()
        yAxisLabels.forEach { $0.removeFromSuperview() }
        yAxisLabels.removeAll()
        xAxisLabels.forEach { $0.removeFromSuperview() }
        xAxisLabels.removeAll()
        
        guard !dataPoints.isEmpty, chartContainerView.bounds.width > 0 else { return }
        
        // 智能采样数据点，避免柱子过密
        let sampledData = sampleDataPoints(dataPoints, for: period)
        let sampledIndices = calculateSampledIndices(totalPoints: dataPoints.count, for: period)
        
        guard !sampledData.isEmpty else { return }
        
        // 计算数据范围
        let minValue: Double = 0  // 从0开始
        let maxValue = dataPoints.max() ?? 1  // 使用原始数据的最大值
        let range = maxValue - minValue
        guard range > 0 else { return }
        
        // 计算合适的Y轴最大值（向上取整到10的倍数）
        let yMax = ceil(maxValue / 10) * 10
        
        // 计算边距 - 使图表区域的左右边距与上方文字的左边距保持一致
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let contentLeading = scale(designContentLeading, basedOn: screenWidth, designDimension: designWidth)
        
        // 图表绘制区域（左右边距与文字对齐，留出底部X轴标签和顶部Y轴标签的空间）
        let leftMargin: CGFloat = contentLeading-10  // 左侧边距与文字对齐
        let rightMargin: CGFloat = contentLeading+10 // 右侧边距与左侧相同
        let bottomMargin: CGFloat = 40  // 底部X轴标签空间
        let topMargin: CGFloat = 20     // 顶部Y轴标签空间（为最大值标签留出空间）
        
        let chartHeight = chartContainerView.bounds.height - bottomMargin - topMargin
        let chartWidth = chartContainerView.bounds.width - leftMargin - rightMargin
        
        // 计算坐标轴标签字体大小
        let axisLabelFontSize = scale(designAxisLabelFontSize, basedOn: screenHeight, designDimension: designHeight)
        
        // 计算柱体间距和总宽度
        let barWidth: CGFloat
        let cornerRadius: CGFloat
        
        switch period {
        case .monthly:
            barWidth = scale(designMonthlyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            cornerRadius = scale(designMonthlyBarCornerRadius, basedOn: screenWidth, designDimension: designWidth)
        case .yearly:
            barWidth = scale(designYearlyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            cornerRadius = scale(designYearlyBarCornerRadius, basedOn: screenWidth, designDimension: designWidth)
        }
        
        let totalBarsWidth = CGFloat(sampledData.count) * barWidth
        // 第一个柱子从leftMargin开始，柱子之间平均分配剩余空间
        let spacing = sampledData.count > 1 ? (chartWidth - totalBarsWidth) / CGFloat(sampledData.count - 1) : 0
        
        // 绘制背景网格线（在柱子之前绘制）
        drawGridLines(chartWidth: chartWidth, 
                     chartHeight: chartHeight, 
                     leftMargin: leftMargin, 
                     topMargin: topMargin,
                     bottomMargin: bottomMargin,
                     yMax: yMax,
                     sampledDataCount: sampledData.count,
                     sampledIndices: sampledIndices,
                     barWidth: barWidth,
                     spacing: spacing,
                     period: period)
        
        // 根据周期类型确定Y轴刻度值
        let yAxisValues: [Double]
        switch period {
        case .monthly:
            // 月度：3条线（0, yMax/2, yMax）
            yAxisValues = [0, yMax / 2, yMax]
        case .yearly:
            // 年度：4条线（0, yMax/3, 2*yMax/3, yMax）
            yAxisValues = [0, yMax / 3, 2 * yMax / 3, yMax]
        }
                
        // 绘制Y轴刻度标签（右侧）
        for (index, value) in yAxisValues.enumerated() {
            let label = UILabel()
            label.text = String(format: "%.0f", value)
            label.textColor = UIColor(white: 1.0, alpha: 0.4)
            label.font = UIFont.systemFont(ofSize: axisLabelFontSize, weight: .regular)
            label.textAlignment = .right
            chartContainerView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            
            // 使用与网格线相同的Y位置计算方式
            let normalizedPosition = CGFloat(index) / CGFloat(yAxisValues.count - 1)
            let yPosition = topMargin + chartHeight * (1 - normalizedPosition)
            
            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(equalTo: chartContainerView.trailingAnchor),
                label.centerYAnchor.constraint(equalTo: chartContainerView.topAnchor, constant: yPosition),
                label.widthAnchor.constraint(equalToConstant: rightMargin)
            ])
            
            yAxisLabels.append(label)
        }
        
        // 绘制每个采样后的数据点
        for (index, value) in sampledData.enumerated() {
            let normalizedValue = (value - minValue) / yMax
            let barHeight = chartHeight * normalizedValue
            
            let x = leftMargin + CGFloat(index) * (barWidth + spacing)
            let y = topMargin + chartHeight - barHeight
            
            // 创建圆角矩形路径
            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let barPath = UIBezierPath(
                roundedRect: barRect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
            )
            
            // 创建图层
            let barLayer = CAShapeLayer()
            barLayer.path = barPath.cgPath
            barLayer.fillColor = chartType.color.cgColor
            barLayer.strokeColor = nil
            
            chartContainerView.layer.addSublayer(barLayer)
            barLayers.append(barLayer)
        }
        
        // 绘制X轴标签（底部）- 使用采样后的索引
        drawXAxisLabels(sampledIndices: sampledIndices, 
                       barWidth: barWidth, 
                       spacing: spacing, 
                       chartHeight: chartHeight,
                       leftMargin: leftMargin,
                       topMargin: topMargin,
                       axisLabelFontSize: axisLabelFontSize)
    }
    
    /// 绘制背景网格线
    private func drawGridLines(chartWidth: CGFloat, 
                              chartHeight: CGFloat, 
                              leftMargin: CGFloat, 
                              topMargin: CGFloat,
                              bottomMargin: CGFloat,
                              yMax: Double,
                              sampledDataCount: Int,
                              sampledIndices: [Int],
                              barWidth: CGFloat,
                              spacing: CGFloat,
                              period: Period) {
        // 根据周期类型确定Y轴刻度值
        let yAxisValues: [Double]
        switch period {
        case .monthly:
            // 月度：3条线（0, yMax/2, yMax）
            yAxisValues = [0, yMax / 2, yMax]
        case .yearly:
            // 年度：4条线（0, yMax/3, 2*yMax/3, yMax）
            yAxisValues = [0, yMax / 3, 2 * yMax / 3, yMax]
        }
        
        // 绘制横向网格线（实线）- 对应Y轴刻度
        for (index, _) in yAxisValues.enumerated() {
            // 计算Y位置：index=0 对应底部(chartHeight)，最后一个index 对应顶部(0)
            let normalizedPosition = CGFloat(index) / CGFloat(yAxisValues.count - 1)
            let yPosition = topMargin + chartHeight * (1 - normalizedPosition)
            
            let horizontalLine = CAShapeLayer()
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: leftMargin, y: yPosition))
            linePath.addLine(to: CGPoint(x: leftMargin + chartWidth, y: yPosition))
            
            horizontalLine.path = linePath.cgPath
            // 底部横线（index=0）使用更高的不透明度和更粗的线条
            if index == 0 {
                horizontalLine.strokeColor = UIColor(white: 1.0, alpha: 0.5).cgColor
                horizontalLine.lineWidth = 2.0
            } else {
                horizontalLine.strokeColor = UIColor(white: 1.0, alpha: 0.1).cgColor
                horizontalLine.lineWidth = 1.0
            }
            horizontalLine.lineCap = .butt
            
            chartContainerView.layer.insertSublayer(horizontalLine, at: 0)
            barLayers.append(horizontalLine)
        }
        
        // 绘制竖向网格线（虚线）- 智能排列，根据X轴标签位置和重要性
        drawVerticalGridLines(sampledDataCount: sampledDataCount,
                             sampledIndices: sampledIndices,
                             barWidth: barWidth,
                             spacing: spacing,
                             chartWidth: chartWidth,
                             chartHeight: chartHeight,
                             leftMargin: leftMargin,
                             topMargin: topMargin,
                             bottomMargin: bottomMargin,
                             period: period)
    }
    
    /// 绘制竖向网格线（虚线）- 智能排列，有强弱区分
    private func drawVerticalGridLines(sampledDataCount: Int,
                                      sampledIndices: [Int],
                                      barWidth: CGFloat,
                                      spacing: CGFloat,
                                      chartWidth: CGFloat,
                                      chartHeight: CGFloat,
                                      leftMargin: CGFloat,
                                      topMargin: CGFloat,
                                      bottomMargin: CGFloat,
                                      period: Period) {
        // 确定哪些位置显示X轴标签（这些位置显示虚线）
        var labelIndices: Set<Int> = []
        
        switch period {
        case .monthly:
            // 月度：找出所有周日的位置
            let calendar = Calendar.current
            let now = Date()
            guard let startDate = calendar.date(byAdding: .day, value: -30, to: now) else { return }
            
            // 遍历30天，找出所有周日
            for index in 0..<sampledDataCount {
                if let date = calendar.date(byAdding: .day, value: index, to: startDate) {
                    let weekday = calendar.component(.weekday, from: date)
                    // weekday == 1 表示周日
                    if weekday == 1 {
                        labelIndices.insert(index)
                    }
                }
            }
            
        case .yearly:
            // 年度：显示全部12个月份
            labelIndices = Set(Array(0..<min(12, sampledDataCount)))
            // 添加第13个位置，在最后一列的右侧显示虚线
            labelIndices.insert(sampledDataCount)
        }
        
        // 确定哪些位置显示竖实线（自然月/年分割）
        var solidLineIndices: Set<Int> = []
        // 记录哪些位置有X轴标签（需要延伸到标签区域）
        let positionsWithLabels: Set<Int> = labelIndices
        
        switch period {
        case .monthly:
            // 月度：标记每个月的1号（自然月分割）
            let calendar = Calendar.current
            let now = Date()
            guard let startDate = calendar.date(byAdding: .day, value: -30, to: now) else { return }
            
            // 遍历30天，找出所有1号
            for index in 0..<sampledDataCount {
                if let date = calendar.date(byAdding: .day, value: index, to: startDate) {
                    let day = calendar.component(.day, from: date)
                    // day == 1 表示每月1号
                    if day == 1 {
                        // 如果1号正好是周日（已有虚线标签），则不显示实线，只显示虚线
                        if !labelIndices.contains(index) {
                            solidLineIndices.insert(index)
                        }
                    }
                }
            }
            
        case .yearly:
            // 年度：标记每年的1月（自然年分割）
            let calendar = Calendar.current
            let now = Date()
            guard let startDate = calendar.date(byAdding: .month, value: -12, to: now) else { return }
            
            // 遍历12个月，找出所有1月
            for index in 0..<sampledDataCount {
                if let date = calendar.date(byAdding: .month, value: index, to: startDate) {
                    let month = calendar.component(.month, from: date)
                    // month == 1 表示1月
                    if month == 1 {
                        solidLineIndices.insert(index)
                        // 1月位置改为显示实线，但保留X轴标签
                        // 从虚线索引中移除，但保留在标签索引中
                        labelIndices.remove(index)
                        // positionsWithLabels 已经包含了这个位置
                    }
                }
            }
        }
        
        // 绘制所有竖线
        // 遍历所有标签和实线位置（可能超过sampledDataCount，用于年度图右边界）
        let allIndices = labelIndices.union(solidLineIndices)
        for index in allIndices {
            // 计算虚线位置：
            // 年度图：虚线在柱子左侧（柱子开始位置向左偏移一点）
            // 月度图：虚线在柱子之间（柱子右边缘 + 间距/2）
            let xPosition: CGFloat
            switch period {
            case .yearly:
                // 年度：虚线在柱子左侧，向左偏移5个点留出间距
                xPosition = leftMargin + CGFloat(index) * (barWidth + spacing) - 5
            case .monthly:
                // 月度：虚线在柱子之间的中间位置
                xPosition = leftMargin + CGFloat(index) * (barWidth + spacing) + barWidth + spacing / 2
            }
            
            let verticalLine = CAShapeLayer()
            let linePath = UIBezierPath()
            
            if labelIndices.contains(index) {
                // 有X轴标签的位置：显示虚线，延伸到底部X轴标签区域
                let bottomExtension: CGFloat = 20  // 延伸20个点，穿过X轴标签
                linePath.move(to: CGPoint(x: xPosition, y: topMargin))
                linePath.addLine(to: CGPoint(x: xPosition, y: topMargin + chartHeight + bottomExtension))
                
                verticalLine.path = linePath.cgPath
                verticalLine.strokeColor = UIColor(white: 1.0, alpha: 0.3).cgColor
                verticalLine.lineWidth = 1.0
                verticalLine.lineDashPattern = [4, 4]  // 虚线样式
            } else if solidLineIndices.contains(index) {
                // 整月/年分割位置：显示实线
                // 如果该位置有X轴标签，则延伸到标签区域
                if positionsWithLabels.contains(index) {
                    // 有X轴标签：延伸到底部
                    let bottomExtension: CGFloat = 20
                    linePath.move(to: CGPoint(x: xPosition, y: topMargin))
                    linePath.addLine(to: CGPoint(x: xPosition, y: topMargin + chartHeight + bottomExtension))
                } else {
                    // 没有X轴标签：不延伸
                    linePath.move(to: CGPoint(x: xPosition, y: topMargin))
                    linePath.addLine(to: CGPoint(x: xPosition, y: topMargin + chartHeight))
                }
                
                verticalLine.path = linePath.cgPath
                verticalLine.strokeColor = UIColor(white: 1.0, alpha: 0.2).cgColor
                verticalLine.lineWidth = 1.0
                verticalLine.lineDashPattern = nil  // 实线
            } else {
                // 其他位置：不显示线条，直接跳过
                continue
            }
            verticalLine.lineCap = .butt
            
            chartContainerView.layer.insertSublayer(verticalLine, at: 0)
            barLayers.append(verticalLine)
        }
    }
    
    /// 智能采样数据点
    /// - Parameters:
    ///   - data: 原始数据数组
    ///   - period: 时间周期
    /// - Returns: 采样后的数据数组
    private func sampleDataPoints(_ data: [Double], for period: Period) -> [Double] {
        switch period {
        case .monthly:
            // 月度数据：显示全部30根柱子
            return data
        case .yearly:
            // 年度数据：显示全部12根柱子
            return data
        }
    }
    
    /// 计算采样后的原始索引
    /// - Parameters:
    ///   - totalPoints: 原始数据总点数
    ///   - period: 时间周期
    /// - Returns: 采样后的索引数组
    private func calculateSampledIndices(totalPoints: Int, for period: Period) -> [Int] {
        switch period {
        case .monthly:
            // 月度数据：显示全部30个数据点
            return Array(0..<totalPoints)
        case .yearly:
            // 年度数据：显示全部12个数据点
            return Array(0..<totalPoints)
        }
    }
    
    /// 绘制X轴标签
    private func drawXAxisLabels(sampledIndices: [Int], 
                                 barWidth: CGFloat, 
                                 spacing: CGFloat, 
                                 chartHeight: CGFloat,
                                 leftMargin: CGFloat,
                                 topMargin: CGFloat,
                                 axisLabelFontSize: CGFloat) {
        let calendar = Calendar.current
        let now = Date()
        
        // 计算显示标签的索引和日期
        var labelIndices: [Int] = []
        var labelDates: [Date] = []
        
        switch period {
        case .monthly:
            // 月度：找出所有周日的位置
            // 起点日期是30天前
            guard let startDate = calendar.date(byAdding: .day, value: -30, to: now) else { return }
            
            // 遍历30天，找出所有周日
            for index in 0..<30 {
                if let date = calendar.date(byAdding: .day, value: index, to: startDate) {
                    let weekday = calendar.component(.weekday, from: date)
                    // weekday == 1 表示周日
                    if weekday == 1 {
                        labelIndices.append(index)
                        labelDates.append(date)
                    }
                }
            }
            
        case .yearly:
            // 年度：显示全部12个月份（1-12月）
            labelIndices = Array(0..<min(12, sampledIndices.count))
            
            // 计算每个月的日期
            for index in labelIndices {
                let daysAgo = (11 - index) * 30
                if let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) {
                    labelDates.append(date)
                }
            }
        }
        
        // 绘制标签
        for (i, displayIndex) in labelIndices.enumerated() {
            guard displayIndex < sampledIndices.count else { continue }
            guard i < labelDates.count else { continue }
            
            let label = UILabel()
            label.textColor = UIColor(white: 1.0, alpha: 0.6)
            label.font = UIFont.systemFont(ofSize: axisLabelFontSize, weight: .regular)
            label.textAlignment = .left  // 左对齐，因为标签显示在虚线右侧
            chartContainerView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            
            let date = labelDates[i]
            
            switch period {
            case .monthly:
                // 月度：显示"X日"（例如："28日"、"5日"）
                let day = calendar.component(.day, from: date)
                label.text = "\(day)\(L("health.period.day"))"
            case .yearly:
                // 年度：只显示数字（例如："1"、"2"...）
                let month = calendar.component(.month, from: date)
                label.text = "\(month)"
            }
            
            // X轴标签位置 - 显示在虚线的右侧，紧挨着虚线
            // 年度：虚线在柱子左侧 leftMargin + displayIndex * (barWidth + spacing) - 5
            // 月度：虚线在柱子之间 leftMargin + displayIndex * (barWidth + spacing) + barWidth + spacing/2
            // 标签在虚线右侧紧挨着：+2个点（相对于虚线）
            let labelX: CGFloat
            switch period {
            case .yearly:
                labelX = leftMargin + CGFloat(displayIndex) * (barWidth + spacing) - 5 + 2
            case .monthly:
                labelX = leftMargin + CGFloat(displayIndex) * (barWidth + spacing) + barWidth + spacing / 2 + 2
            }
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: chartContainerView.leadingAnchor, constant: labelX),
                label.topAnchor.constraint(equalTo: chartContainerView.topAnchor, constant: topMargin + chartHeight + 5),
                label.widthAnchor.constraint(equalToConstant: 60)
            ])
            
            xAxisLabels.append(label)
        }
    }
}
