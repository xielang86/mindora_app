//
//  LineChartView+Drawing.swift
//  mindora
//
//  Created by GitHub Copilot split on 2025/12/04.
//

import UIKit

// Drawing and data-sampling helpers for LineChartView.
extension LineChartView {
    func drawChart() {
        // 清除旧的图层和标签
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers.removeAll()
        yAxisLabels.forEach { $0.removeFromSuperview() }
        yAxisLabels.removeAll()
        xAxisLabels.forEach { $0.removeFromSuperview() }
        xAxisLabels.removeAll()

        guard chartContainerView.bounds.width > 0 else { return }
        
        // 睡眠图表使用特殊的绘制逻辑
        if chartType == .sleep {
            if !sleepRangeData.isEmpty {
                if period == .daily {
                    // 日视图：水平条形图，X轴为时间（20:00-10:00）
                    drawDailySleepHorizontalBarChart()
                } else {
                    // 周/月/年视图：垂直范围柱状图，Y轴为时间点
                    drawSleepVerticalRangeChart()
                }
            } else if !dataPoints.isEmpty {
                // 回退到默认柱状图
                drawDefaultChart()
            }
            return
        }
        
        // 其他图表类型使用默认绘制逻辑
        guard !dataPoints.isEmpty else { return }
        drawDefaultChart()
    }
    
    /// 默认图表绘制逻辑（用于心率、HRV等）
    private func drawDefaultChart() {
        // 智能采样数据点，避免柱子过密
        let sampledData = sampleDataPoints(dataPoints, for: period)
        let sampledIndices = calculateSampledIndices(totalPoints: dataPoints.count, for: period)

        guard !sampledData.isEmpty else { return }

        // 计算数据范围
        let minValue: Double = 0  // 从0开始
        // 对于心率范围数据，使用范围的最大值；否则使用原始数据的最大值
        let maxValue: Double
        if chartType == .heartRate && !heartRateRangeData.isEmpty {
            maxValue = heartRateRangeData.filter { $0.isValid }.map { $0.max }.max() ?? 1
        } else {
            maxValue = dataPoints.max() ?? 1
        }
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
        case .daily:
            // 日视图：宽度17px
            barWidth = scale(designDailyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            cornerRadius = scale(designDailyBarCornerRadius, basedOn: screenWidth, designDimension: designWidth)
        case .weekly:
            // 周视图：宽度100px
            barWidth = scale(designWeeklyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            cornerRadius = scale(designWeeklyBarCornerRadius, basedOn: screenWidth, designDimension: designWidth)
        case .monthly:
            // 月视图：宽度17px
            barWidth = scale(designMonthlyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            cornerRadius = scale(designMonthlyBarCornerRadius, basedOn: screenWidth, designDimension: designWidth)
        case .sixMonths:
            // 6个月视图：宽度17px
            barWidth = scale(designSixMonthsBarWidth, basedOn: screenWidth, designDimension: designWidth)
            cornerRadius = scale(designSixMonthsBarCornerRadius, basedOn: screenWidth, designDimension: designWidth)
        case .yearly:
            // 年视图：宽度60px
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
        case .daily, .weekly, .sixMonths:
            // 日报/周报/半年报：与周报相同的处理
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
        if chartType == .hrv {
            // HRV使用折线图和空心圆圈
            drawLineChartWithHollowCircles(sampledData: sampledData,
                                           minValue: minValue,
                                           yMax: yMax,
                                           chartHeight: chartHeight,
                                           leftMargin: leftMargin,
                                           topMargin: topMargin,
                                           barWidth: barWidth,
                                           spacing: spacing)
        } else if chartType == .heartRate && !heartRateRangeData.isEmpty {
            // 心率使用范围条形图（Range Bar Chart）
            drawRangeBarChart(rangeData: heartRateRangeData,
                             yMax: yMax,
                             chartHeight: chartHeight,
                             leftMargin: leftMargin,
                             topMargin: topMargin,
                             barWidth: barWidth,
                             spacing: spacing,
                             cornerRadius: cornerRadius)
        } else {
            // 其他类型使用柱状图
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

    func drawGridLines(chartWidth: CGFloat,
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
        case .daily, .weekly, .sixMonths:
            // 日报/周报/半年报：与周报相同的处理
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

    func drawVerticalGridLines(sampledDataCount: Int,
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
        case .daily:
            // 日视图：每6小时显示一个标签（0, 6, 12, 18）
            for index in stride(from: 0, to: min(24, sampledDataCount), by: 6) {
                labelIndices.insert(index)
            }

        case .weekly:
            // 周视图：显示全部7天
            labelIndices = Set(Array(0..<min(7, sampledDataCount)))

        case .monthly:
            // 月度：找出所有周日的位置
            let calendar = Calendar.current
            let anchor = referenceDate
            let anchorStart = calendar.startOfDay(for: anchor)
            guard let startDate = calendar.date(byAdding: .day, value: -29, to: anchorStart) else { return }

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

        case .sixMonths:
            // 6个月视图：每4周显示一个标签
            for index in stride(from: 0, to: sampledDataCount, by: 4) {
                labelIndices.insert(index)
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
        case .daily, .weekly:
            // 日/周视图：不显示分割线
            break

        case .monthly:
            // 月度：标记每个月的1号（自然月分割）
            let calendar = Calendar.current
            let anchor = referenceDate
            let anchorStart = calendar.startOfDay(for: anchor)
            guard let startDate = calendar.date(byAdding: .day, value: -29, to: anchorStart) else { return }

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

        case .sixMonths:
            // 6个月视图：标记每个月初（约每4周）
            break

        case .yearly:
            // 年度：标记每年的1月（自然年分割）
            let calendar = Calendar.current
            let anchor = referenceDate
            let anchorStart = calendar.startOfDay(for: anchor)
            guard let startDate = calendar.date(byAdding: .month, value: -12, to: anchorStart) else { return }

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
            case .daily, .weekly:
                // 日/周视图：虚线在柱子左侧
                xPosition = leftMargin + CGFloat(index) * (barWidth + spacing) - 5
            case .yearly:
                // 年度：虚线在柱子左侧，向左偏移5个点留出间距
                xPosition = leftMargin + CGFloat(index) * (barWidth + spacing) - 5
            case .monthly:
                // 月度：虚线在柱子之间的中间位置
                xPosition = leftMargin + CGFloat(index) * (barWidth + spacing) + barWidth + spacing / 2
            case .sixMonths:
                // 6个月视图：虚线在柱子左侧
                xPosition = leftMargin + CGFloat(index) * (barWidth + spacing) - 5
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
    func sampleDataPoints(_ data: [Double], for period: Period) -> [Double] {
        switch period {
        case .daily:
            // 日视图：显示24小时数据
            return data
        case .weekly:
            // 周视图：显示7天数据
            return data
        case .monthly:
            // 月度数据：显示全部30根柱子
            return data
        case .sixMonths:
            // 6个月数据：显示约26周数据
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
    func calculateSampledIndices(totalPoints: Int, for period: Period) -> [Int] {
        switch period {
        case .daily:
            // 日视图：显示全部24个数据点
            return Array(0..<totalPoints)
        case .weekly:
            // 周视图：显示全部7个数据点
            return Array(0..<totalPoints)
        case .monthly:
            // 月度数据：显示全部30个数据点
            return Array(0..<totalPoints)
        case .sixMonths:
            // 6个月数据：显示全部数据点
            return Array(0..<totalPoints)
        case .yearly:
            // 年度数据：显示全部12个数据点
            return Array(0..<totalPoints)
        }
    }

    /// 绘制X轴标签
    func drawXAxisLabels(sampledIndices: [Int],
                         barWidth: CGFloat,
                         spacing: CGFloat,
                         chartHeight: CGFloat,
                         leftMargin: CGFloat,
                         topMargin: CGFloat,
                         axisLabelFontSize: CGFloat) {
        let calendar = Calendar.current
        let anchor = referenceDate
        let anchorDayStart = calendar.startOfDay(for: anchor)

        // 计算显示标签的索引和日期/小时
        var labelIndices: [Int] = []
        var labelTexts: [String] = []

        switch period {
        case .daily:
            // 日视图：只显示 0时、6时、12时、18时
            let displayHours = [0, 6, 12, 18]
            for hour in displayHours {
                if hour < sampledIndices.count {
                    labelIndices.append(hour)
                    labelTexts.append("\(hour)\(L("health.period.hour"))")
                }
            }

        case .weekly:
            // 周视图：显示全部7天（周X 到 周Y）
            guard let startDate = calendar.date(byAdding: .day, value: -6, to: anchorDayStart) else { return }
            labelIndices = Array(0..<min(7, sampledIndices.count))
            for index in labelIndices {
                if let date = calendar.date(byAdding: .day, value: index, to: startDate) {
                    let weekday = calendar.component(.weekday, from: date)
                    let weekdayNames = ["", L("health.weekday.sun"), L("health.weekday.mon"), L("health.weekday.tue"), L("health.weekday.wed"), L("health.weekday.thu"), L("health.weekday.fri"), L("health.weekday.sat")]
                    labelTexts.append(weekdayNames[weekday])
                }
            }

        case .monthly:
            // 月度：找出所有周日的位置
            guard let startDate = calendar.date(byAdding: .day, value: -29, to: anchorDayStart) else { return }

            for index in 0..<30 {
                if let date = calendar.date(byAdding: .day, value: index, to: startDate) {
                    let weekday = calendar.component(.weekday, from: date)
                    if weekday == 1 {
                        labelIndices.append(index)
                        let day = calendar.component(.day, from: date)
                        labelTexts.append("\(day)\(L("health.period.day"))")
                    }
                }
            }

        case .sixMonths:
            // 6个月视图：每4周显示一个标签
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: anchorDayStart)!
            let weekday = calendar.component(.weekday, from: sixMonthsAgo)
            let daysToSunday = (weekday - 1 + 7) % 7
            let startSunday = calendar.date(byAdding: .day, value: -daysToSunday, to: calendar.startOfDay(for: sixMonthsAgo))!
            let totalWeeks = sampledIndices.count
            for index in stride(from: 0, to: totalWeeks, by: 4) {
                labelIndices.append(index)
                if let date = calendar.date(byAdding: .weekOfYear, value: index, to: startSunday) {
                    let month = calendar.component(.month, from: date)
                    labelTexts.append("\(month)\(L("health.period.month"))")
                }
            }

        case .yearly:
            // 年度：显示全部12个月份
            labelIndices = Array(0..<min(12, sampledIndices.count))
            for index in labelIndices {
                let monthsAgo = 11 - index
                if let date = calendar.date(byAdding: .month, value: -monthsAgo, to: anchorDayStart) {
                    let month = calendar.component(.month, from: date)
                    labelTexts.append("\(month)")
                }
            }
        }

        // 绘制标签
        for (i, displayIndex) in labelIndices.enumerated() {
            guard displayIndex < sampledIndices.count else { continue }
            guard i < labelTexts.count else { continue }

            let label = UILabel()
            label.textColor = UIColor(white: 1.0, alpha: 0.6)
            label.font = UIFont.systemFont(ofSize: axisLabelFontSize, weight: .regular)
            label.textAlignment = .left
            label.text = labelTexts[i]
            chartContainerView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false

            // X轴标签位置
            let labelX: CGFloat
            switch period {
            case .daily:
                // 日视图：标签在柱子左侧
                labelX = leftMargin + CGFloat(displayIndex) * (barWidth + spacing) - 5 + 2
            case .weekly:
                // 周视图：标签在柱子左侧
                labelX = leftMargin + CGFloat(displayIndex) * (barWidth + spacing) - 5 + 2
            case .yearly:
                labelX = leftMargin + CGFloat(displayIndex) * (barWidth + spacing) - 5 + 2
            case .monthly:
                labelX = leftMargin + CGFloat(displayIndex) * (barWidth + spacing) + barWidth + spacing / 2 + 2
            case .sixMonths:
                // 6个月视图：标签在柱子左侧
                labelX = leftMargin + CGFloat(displayIndex) * (barWidth + spacing) - 5 + 2
            }

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: chartContainerView.leadingAnchor, constant: labelX),
                label.topAnchor.constraint(equalTo: chartContainerView.topAnchor, constant: topMargin + chartHeight + 5),
                label.widthAnchor.constraint(equalToConstant: 60)
            ])

            xAxisLabels.append(label)
        }
    }

    /// 绘制折线图和空心圆圈（用于HRV）
    func drawLineChartWithHollowCircles(sampledData: [Double],
                                         minValue: Double,
                                         yMax: Double,
                                         chartHeight: CGFloat,
                                         leftMargin: CGFloat,
                                         topMargin: CGFloat,
                                         barWidth: CGFloat,
                                         spacing: CGFloat) {
        guard sampledData.count > 0 else { return }

        // 空心圆圈的半径和线宽
        let circleRadius: CGFloat = 3.5
        let circleLineWidth: CGFloat = 2.0
        let lineWidth: CGFloat = 2.0

        // 计算所有数据点的位置
        var points: [CGPoint] = []
        for (index, value) in sampledData.enumerated() {
            let normalizedValue = (value - minValue) / yMax
            let x = leftMargin + CGFloat(index) * (barWidth + spacing) + barWidth / 2
            let y = topMargin + chartHeight * (1 - normalizedValue)
            points.append(CGPoint(x: x, y: y))
        }

        // 收集有效数据点的索引（非零值）
        var validIndices: [Int] = []
        for (index, value) in sampledData.enumerated() {
            if value > 0 {
                validIndices.append(index)
            }
        }

        // 分段绘制线条，每段从一个圆圈边缘到下一个圆圈边缘
        // 计算边缘点时使用两点连线方向，使线条看起来像穿过圆心
        for i in 0..<(validIndices.count - 1) {
            let currentIndex = validIndices[i]
            let nextIndex = validIndices[i + 1]

            // 检查是否连续（中间没有零值断开）
            var isContinuous = true
            for j in (currentIndex + 1)..<nextIndex {
                if sampledData[j] == 0 {
                    isContinuous = false
                    break
                }
            }

            if !isContinuous {
                continue
            }

            let startCenter = points[currentIndex]
            let endCenter = points[nextIndex]

            // 计算两点之间的方向向量
            let dx = endCenter.x - startCenter.x
            let dy = endCenter.y - startCenter.y
            let distance = sqrt(dx * dx + dy * dy)

            guard distance > 2 * circleRadius else { continue }

            // 单位向量
            let unitX = dx / distance
            let unitY = dy / distance

            // 线条从起点圆圈的边缘开始，到终点圆圈的边缘结束
            let startEdge = CGPoint(x: startCenter.x + unitX * circleRadius,
                                    y: startCenter.y + unitY * circleRadius)
            let endEdge = CGPoint(x: endCenter.x - unitX * circleRadius,
                                  y: endCenter.y - unitY * circleRadius)

            let linePath = UIBezierPath()
            linePath.move(to: startEdge)
            linePath.addLine(to: endEdge)

            let lineLayer = CAShapeLayer()
            lineLayer.path = linePath.cgPath
            lineLayer.strokeColor = chartType.color.cgColor
            lineLayer.fillColor = nil
            lineLayer.lineWidth = lineWidth
            lineLayer.lineCap = .round

            chartContainerView.layer.addSublayer(lineLayer)
            barLayers.append(lineLayer)
        }

        // 绘制空心圆圈
        for (index, value) in sampledData.enumerated() {
            if value > 0 {
                let point = points[index]

                // 创建空心圆圈 - 透明填充，彩色描边
                let circlePath = UIBezierPath(arcCenter: point,
                                              radius: circleRadius,
                                              startAngle: 0,
                                              endAngle: CGFloat.pi * 2,
                                              clockwise: true)

                let circleLayer = CAShapeLayer()
                circleLayer.path = circlePath.cgPath
                circleLayer.fillColor = UIColor.black.cgColor
                circleLayer.strokeColor = chartType.color.cgColor
                circleLayer.lineWidth = circleLineWidth

                chartContainerView.layer.addSublayer(circleLayer)
                barLayers.append(circleLayer)
            }
        }
    }
    
    /// 绘制范围条形图（Range Bar Chart）
    /// 每个条形显示数据的最小值到最大值范围
    /// - Parameters:
    ///   - rangeData: 心率范围数据数组
    ///   - yMax: Y轴最大值
    ///   - chartHeight: 图表高度
    ///   - leftMargin: 左边距
    ///   - topMargin: 顶部边距
    ///   - barWidth: 条形宽度
    ///   - spacing: 条形间距
    ///   - cornerRadius: 圆角半径
    func drawRangeBarChart(rangeData: [HeartRateRangePoint],
                           yMax: Double,
                           chartHeight: CGFloat,
                           leftMargin: CGFloat,
                           topMargin: CGFloat,
                           barWidth: CGFloat,
                           spacing: CGFloat,
                           cornerRadius: CGFloat) {
        // 线条宽度（比原始柱状图窄一些，更符合设计图的线条样式）
        let lineWidth: CGFloat = barWidth * 0.6
        // 圆形端点半径
        let circleRadius: CGFloat = lineWidth / 2
        // 最小条形高度（当只有一个点时显示为圆点）
        let minBarHeight: CGFloat = circleRadius * 2
        
        for (index, point) in rangeData.enumerated() {
            let x = leftMargin + CGFloat(index) * (barWidth + spacing) + barWidth / 2
            
            // 如果数据无效，跳过
            guard point.isValid else { continue }
            
            // 计算Y坐标（注意：Y轴是反向的，顶部是最大值）
            let normalizedMax = point.max / yMax
            let normalizedMin = point.min / yMax
            let yTop = topMargin + chartHeight * (1 - normalizedMax)
            let yBottom = topMargin + chartHeight * (1 - normalizedMin)
            
            // 计算条形高度
            let barHeight = yBottom - yTop
            
            // 如果高度太小（min和max很接近），显示为圆点
            if barHeight < minBarHeight {
                // 绘制圆点
                let centerY = (yTop + yBottom) / 2
                let circlePath = UIBezierPath(
                    arcCenter: CGPoint(x: x, y: centerY),
                    radius: circleRadius,
                    startAngle: 0,
                    endAngle: CGFloat.pi * 2,
                    clockwise: true
                )
                
                let circleLayer = CAShapeLayer()
                circleLayer.path = circlePath.cgPath
                circleLayer.fillColor = chartType.color.cgColor
                circleLayer.strokeColor = nil
                
                chartContainerView.layer.addSublayer(circleLayer)
                barLayers.append(circleLayer)
            } else {
                // 绘制带圆角的范围条形（两端都是圆角）
                let barRect = CGRect(x: x - lineWidth / 2, y: yTop, width: lineWidth, height: barHeight)
                let barPath = UIBezierPath(
                    roundedRect: barRect,
                    byRoundingCorners: [.topLeft, .topRight, .bottomLeft, .bottomRight],
                    cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
                )
                
                let barLayer = CAShapeLayer()
                barLayer.path = barPath.cgPath
                barLayer.fillColor = chartType.color.cgColor
                barLayer.strokeColor = nil
                
                chartContainerView.layer.addSublayer(barLayer)
                barLayers.append(barLayer)
            }
        }
    }
    
    // MARK: - 睡眠图表绘制方法
    
    /// 绘制日视图睡眠水平条形图
    /// 一条水平条形图，垂直居中
    /// X轴是时间轴（20:00到次日10:00，共14小时 = 840分钟）
    /// Y轴为空（不需要刻度）
    /// darkGreen 表示卧床时间，lightGreen 表示睡眠时间
    private func drawDailySleepHorizontalBarChart() {
        guard let sleepData = sleepRangeData.first, sleepData.isValid else { return }
        
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let contentLeading = scale(designContentLeading, basedOn: screenWidth, designDimension: designWidth)
        
        // 图表布局参数
        let leftMargin: CGFloat = contentLeading - 10
        let rightMargin: CGFloat = contentLeading - 10
        let bottomMargin: CGFloat = 40  // 底部X轴标签空间
        let topMargin: CGFloat = 20
        
        let chartHeight = chartContainerView.bounds.height - bottomMargin - topMargin
        let chartWidth = chartContainerView.bounds.width - leftMargin - rightMargin
        
        // 计算坐标轴标签字体大小
        let axisLabelFontSize = scale(designAxisLabelFontSize, basedOn: screenHeight, designDimension: designHeight)
        
        // 根据实际数据动态计算X轴时间范围
        // 找到最早开始时间和最晚结束时间
        let dataMinMinutes = min(sleepData.bedStartMinutes, sleepData.sleepStartMinutes)
        let dataMaxMinutes = max(sleepData.bedEndMinutes, sleepData.sleepEndMinutes)
        
        // 向下取整到最近的小时（60分钟），并留出一些边距
        let xMinMinutes = max(0, floor(dataMinMinutes / 60) * 60 - 60)
        // 向上取整到最近的小时，并留出一些边距
        let xMaxMinutes = min(840, ceil(dataMaxMinutes / 60) * 60 + 60)
        let xRangeMinutes = xMaxMinutes - xMinMinutes
        
        // 条形图尺寸（垂直居中的水平条）
        // 调低日视图柱体高度以减少视觉厚重感（从 15% 降到 12%）
        let barHeight: CGFloat = chartHeight * 0.12  // 条形高度为图表高度的12%
        let barCenterY: CGFloat = topMargin + chartHeight / 2  // 垂直居中
        // 原先使用 `barHeight / 2` 会导致在高度较大时圆角过大（尤其日视图柱体宽度很宽时视觉显得过于椭圆）。
        // 这里限制圆角最大值为一个经过设计稿缩放的常量，以保持更自然的圆角视觉。
        // 增大限制值以保证日视图的柱体看起来更圆润（之前 12 过小导致“太方”）
        let maxCornerRadius: CGFloat = scale(24, basedOn: screenHeight, designDimension: designHeight)
        let cornerRadius: CGFloat = min(barHeight / 2, maxCornerRadius)
        let barGap: CGFloat = 4  // 柱子之间的间隙
        
        // 绘制X轴底部的基线
        let baselinePath = UIBezierPath()
        baselinePath.move(to: CGPoint(x: leftMargin, y: topMargin + chartHeight))
        baselinePath.addLine(to: CGPoint(x: leftMargin + chartWidth, y: topMargin + chartHeight))
        
        let baselineLayer = CAShapeLayer()
        baselineLayer.path = baselinePath.cgPath
        baselineLayer.strokeColor = UIColor(white: 1.0, alpha: 0.3).cgColor
        baselineLayer.lineWidth = 1.0
        
        chartContainerView.layer.insertSublayer(baselineLayer, at: 0)
        barLayers.append(baselineLayer)
        
        // 绘制图表顶部的横线（与心率图保持一致的样式）
        let topLinePath = UIBezierPath()
        topLinePath.move(to: CGPoint(x: leftMargin, y: topMargin))
        topLinePath.addLine(to: CGPoint(x: leftMargin + chartWidth, y: topMargin))
        
        let topLineLayer = CAShapeLayer()
        topLineLayer.path = topLinePath.cgPath
        topLineLayer.strokeColor = UIColor(white: 1.0, alpha: 0.1).cgColor
        topLineLayer.lineWidth = 1.0
        
        chartContainerView.layer.insertSublayer(topLineLayer, at: 0)
        barLayers.append(topLineLayer)
        
        // 辅助函数：将分钟转换为X坐标
        func xPositionForMinutes(_ minutes: Double) -> CGFloat {
            let normalizedX = (minutes - xMinMinutes) / xRangeMinutes
            return leftMargin + chartWidth * CGFloat(normalizedX)
        }
        
        // 辅助函数：将分钟转换为时间字符串
        func minutesToTimeString(_ minutes: Double) -> String {
            // 基准是20:00，所以 minutes=0 对应 20:00
            let totalMinutes = Int(minutes) + 20 * 60  // 加上20小时的分钟数
            let hours = (totalMinutes / 60) % 24
            let mins = totalMinutes % 60
            return String(format: "%d:%02d", hours, mins)
        }
        
        // 按时间顺序排列睡眠阶段
        // 结构：[(startMinutes, endMinutes, color, isBed)]
        var sleepSegments: [(start: Double, end: Double, color: UIColor, isBed: Bool)] = []
        
        // 卧床时间段（从上床到入睡）
        if sleepData.bedStartMinutes < sleepData.sleepStartMinutes {
            // 卧床时间使用深绿色表示（darkGreen），睡眠时间使用浅绿色（lightGreen）
            sleepSegments.append((sleepData.bedStartMinutes, sleepData.sleepStartMinutes, DesignConstants.darkGreen, true))
        }
        
        // 睡眠时间段
        sleepSegments.append((sleepData.sleepStartMinutes, sleepData.sleepEndMinutes, DesignConstants.lightGreen, false))
        
        // 绘制每个独立的柱子
        for (index, segment) in sleepSegments.enumerated() {
            var startX = xPositionForMinutes(segment.start)
            var endX = xPositionForMinutes(segment.end)
            
            // 在柱子之间添加间隙
            if index > 0 {
                startX += barGap / 2
            }
            if index < sleepSegments.count - 1 {
                endX -= barGap / 2
            }
            
            let barWidth = endX - startX
            
            if barWidth > 0 {
                let barRect = CGRect(x: startX, y: barCenterY - barHeight / 2, width: barWidth, height: barHeight)
                let barPath = UIBezierPath(roundedRect: barRect, cornerRadius: cornerRadius)
                
                let barLayer = CAShapeLayer()
                barLayer.path = barPath.cgPath
                barLayer.fillColor = segment.color.cgColor
                
                chartContainerView.layer.addSublayer(barLayer)
                barLayers.append(barLayer)
            }
        }
        
        // 动态生成X轴时间标签
        // 根据时间范围决定标签间隔
        let labelIntervalMinutes: Double
        if xRangeMinutes <= 240 {
            labelIntervalMinutes = 60  // 每小时一个标签
        } else if xRangeMinutes <= 480 {
            labelIntervalMinutes = 120  // 每2小时一个标签
        } else {
            labelIntervalMinutes = 180  // 每3小时一个标签
        }
        
        // 生成时间标签
        var currentMinutes = ceil(xMinMinutes / labelIntervalMinutes) * labelIntervalMinutes
        while currentMinutes <= xMaxMinutes {
            let xPosition = xPositionForMinutes(currentMinutes)
            let timeLabel = minutesToTimeString(currentMinutes)
            
            // 绘制垂直虚线（从图表顶部到底部）
            let verticalLinePath = UIBezierPath()
            verticalLinePath.move(to: CGPoint(x: xPosition, y: topMargin))
            verticalLinePath.addLine(to: CGPoint(x: xPosition, y: topMargin + chartHeight))
            
            let verticalLineLayer = CAShapeLayer()
            verticalLineLayer.path = verticalLinePath.cgPath
            verticalLineLayer.strokeColor = UIColor(white: 1.0, alpha: 0.1).cgColor
            verticalLineLayer.lineWidth = 1.0
            verticalLineLayer.lineDashPattern = [4, 4]  // 虚线样式
            
            chartContainerView.layer.insertSublayer(verticalLineLayer, at: 0)
            barLayers.append(verticalLineLayer)
            
            // 绘制刻度竖线（底部短线）
            let tickPath = UIBezierPath()
            tickPath.move(to: CGPoint(x: xPosition, y: topMargin + chartHeight))
            tickPath.addLine(to: CGPoint(x: xPosition, y: topMargin + chartHeight + 5))
            
            let tickLayer = CAShapeLayer()
            tickLayer.path = tickPath.cgPath
            tickLayer.strokeColor = UIColor(white: 1.0, alpha: 0.3).cgColor
            tickLayer.lineWidth = 1.0
            
            chartContainerView.layer.addSublayer(tickLayer)
            barLayers.append(tickLayer)
            
            // 绘制时间标签
            let label = UILabel()
            label.text = timeLabel
            label.textColor = UIColor(white: 1.0, alpha: 0.6)
            label.font = UIFont.systemFont(ofSize: axisLabelFontSize * 0.85, weight: .regular)
            label.textAlignment = .center
            chartContainerView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: chartContainerView.leadingAnchor, constant: xPosition),
                label.topAnchor.constraint(equalTo: chartContainerView.topAnchor, constant: topMargin + chartHeight + 8),
                label.widthAnchor.constraint(equalToConstant: 50)
            ])
            
            xAxisLabels.append(label)
            
            currentMinutes += labelIntervalMinutes
        }
    }
    
    /// 绘制睡眠垂直范围柱状图（周/月/年视图）
    /// Y轴表示时间点（根据实际数据动态调整），X轴表示日期
    /// 每个柱子显示入睡到醒来的时间段范围
    private func drawSleepVerticalRangeChart() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let contentLeading = scale(designContentLeading, basedOn: screenWidth, designDimension: designWidth)
        
        // 图表布局参数
        let leftMargin: CGFloat = contentLeading - 10
        let rightMargin: CGFloat = contentLeading + 30  // 右侧留出Y轴标签空间
        let bottomMargin: CGFloat = 40
        let topMargin: CGFloat = 20
        
        let chartHeight = chartContainerView.bounds.height - bottomMargin - topMargin
        let chartWidth = chartContainerView.bounds.width - leftMargin - rightMargin
        
        // 计算坐标轴标签字体大小
        let axisLabelFontSize = scale(designAxisLabelFontSize, basedOn: screenHeight, designDimension: designHeight)
        
        // 根据实际数据动态计算Y轴时间范围
        // 数据基准：20:00 = 0分钟
        let validData = sleepRangeData.filter { $0.isValid }
        guard !validData.isEmpty else { return }
        
        let dataMinMinutes = validData.map { min($0.bedStartMinutes, $0.sleepStartMinutes) }.min() ?? 0
        let dataMaxMinutes = validData.map { max($0.bedEndMinutes, $0.sleepEndMinutes) }.max() ?? 840
        
        // 向下取整到最近的2小时（120分钟），确保包含所有数据
        // 注意：yMinMinutes 应该小于等于 dataMinMinutes
        let yMinMinutes = max(0, floor(dataMinMinutes / 120) * 120)
        // 向上取整到最近的2小时，确保包含所有数据
        // 注意：yMaxMinutes 应该大于等于 dataMaxMinutes
        let yMaxMinutes = min(960, ceil(dataMaxMinutes / 120) * 120)  // 最大到次日12:00（960分钟）
        let yRangeMinutes = yMaxMinutes - yMinMinutes
        
        // 辅助函数：将分钟转换为时间字符串
        // 基准是20:00，所以 minutes=0 对应 20:00
        func minutesToTimeString(_ minutes: Double) -> String {
            let totalMinutes = Int(minutes) + 20 * 60  // 加上20小时的分钟数
            let hours = (totalMinutes / 60) % 24
            let mins = totalMinutes % 60
            if mins == 0 {
                return String(format: "%d:00", hours)
            }
            return String(format: "%d:%02d", hours, mins)
        }
        
        // 计算柱体宽度
        let barWidth: CGFloat
        let cornerRadius: CGFloat
        
        switch period {
        case .weekly:
            barWidth = scale(designWeeklyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            cornerRadius = scale(designWeeklyBarCornerRadius, basedOn: screenWidth, designDimension: designWidth)
        case .monthly:
            barWidth = scale(designMonthlyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            cornerRadius = scale(designMonthlyBarCornerRadius, basedOn: screenWidth, designDimension: designWidth)
        case .sixMonths:
            barWidth = scale(designSixMonthsBarWidth, basedOn: screenWidth, designDimension: designWidth)
            cornerRadius = scale(designSixMonthsBarCornerRadius, basedOn: screenWidth, designDimension: designWidth)
        case .yearly:
            barWidth = scale(designYearlyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            cornerRadius = scale(designYearlyBarCornerRadius, basedOn: screenWidth, designDimension: designWidth)
        default:
            barWidth = scale(designMonthlyBarWidth, basedOn: screenWidth, designDimension: designWidth)
            cornerRadius = scale(designMonthlyBarCornerRadius, basedOn: screenWidth, designDimension: designWidth)
        }
        
        let dataCount = sleepRangeData.count
        let totalBarsWidth = CGFloat(dataCount) * barWidth
        let spacing = dataCount > 1 ? (chartWidth - totalBarsWidth) / CGFloat(dataCount - 1) : 0
        
        // 动态生成Y轴时间标签
        // 根据时间范围决定标签间隔
        let labelIntervalMinutes: Double
        if yRangeMinutes <= 360 {
            labelIntervalMinutes = 60   // 每小时一个标签
        } else if yRangeMinutes <= 600 {
            labelIntervalMinutes = 120  // 每2小时一个标签
        } else {
            labelIntervalMinutes = 180  // 每3小时一个标签
        }
        
        // 生成Y轴时间刻度
        // 从 yMinMinutes 开始，确保第一条刻度线在图表顶部
        var currentMinutes = yMinMinutes
        var isFirstLine = true
        
        while currentMinutes <= yMaxMinutes {
            let normalizedY = (currentMinutes - yMinMinutes) / yRangeMinutes
            let yPosition = topMargin + chartHeight * CGFloat(normalizedY)
            let timeLabel = minutesToTimeString(currentMinutes)
            
            // 绘制横线
            let horizontalLine = CAShapeLayer()
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: leftMargin, y: yPosition))
            linePath.addLine(to: CGPoint(x: leftMargin + chartWidth, y: yPosition))
            
            horizontalLine.path = linePath.cgPath
            // 所有横线使用统一的样式（与心率图保持一致）
            horizontalLine.strokeColor = UIColor(white: 1.0, alpha: 0.1).cgColor
            horizontalLine.lineWidth = 1.0
            if isFirstLine {
                isFirstLine = false
            }
            
            chartContainerView.layer.insertSublayer(horizontalLine, at: 0)
            barLayers.append(horizontalLine)
            
            // 绘制Y轴标签（右侧）
            let label = UILabel()
            label.text = timeLabel
            label.textColor = UIColor(white: 1.0, alpha: 0.4)
            label.font = UIFont.systemFont(ofSize: axisLabelFontSize, weight: .regular)
            label.textAlignment = .left
            chartContainerView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: chartContainerView.leadingAnchor, constant: leftMargin + chartWidth + 5),
                label.centerYAnchor.constraint(equalTo: chartContainerView.topAnchor, constant: yPosition),
                label.widthAnchor.constraint(equalToConstant: 50)
            ])
            
            yAxisLabels.append(label)
            
            currentMinutes += labelIntervalMinutes
        }
        
        // 绘制每天的睡眠范围柱
        // 线条宽度
        let lineWidth: CGFloat = barWidth * 0.5
        let barGap: CGFloat = 2  // 柱子之间的间隙
        
        for (index, point) in sleepRangeData.enumerated() {
            guard point.isValid else { continue }
            
            let xCenter = leftMargin + CGFloat(index) * (barWidth + spacing) + barWidth / 2
            
            // 计算Y坐标（根据动态范围），并裁剪到图表区域内
            func yPositionForMinutes(_ minutes: Double) -> CGFloat {
                // 将分钟数裁剪到Y轴范围内
                let clampedMinutes = max(yMinMinutes, min(yMaxMinutes, minutes))
                let normalizedY = (clampedMinutes - yMinMinutes) / yRangeMinutes
                return topMargin + chartHeight * CGFloat(normalizedY)
            }
            
            // 按时间顺序排列睡眠阶段（垂直排列）
            // 结构：[(startMinutes, endMinutes, color)]
            var sleepSegments: [(start: Double, end: Double, color: UIColor)] = []
            
            // 卧床时间段（从上床到入睡）
            if point.bedStartMinutes < point.sleepStartMinutes {
                sleepSegments.append((point.bedStartMinutes, point.sleepStartMinutes, DesignConstants.darkGreen))
            }
            
            // 睡眠时间段
            sleepSegments.append((point.sleepStartMinutes, point.sleepEndMinutes, DesignConstants.lightGreen))
            
            // 绘制每个独立的柱子
            for (segmentIndex, segment) in sleepSegments.enumerated() {
                var startY = yPositionForMinutes(segment.start)
                var endY = yPositionForMinutes(segment.end)
                
                // 在柱子之间添加间隙
                if segmentIndex > 0 {
                    startY += barGap / 2
                }
                if segmentIndex < sleepSegments.count - 1 {
                    endY -= barGap / 2
                }
                
                let segmentHeight = endY - startY
                
                if segmentHeight > 0 {
                    let segmentRect = CGRect(x: xCenter - lineWidth / 2, y: startY, width: lineWidth, height: segmentHeight)
                    let segmentPath = UIBezierPath(
                        roundedRect: segmentRect,
                        byRoundingCorners: [.topLeft, .topRight, .bottomLeft, .bottomRight],
                        cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
                    )
                    
                    let segmentLayer = CAShapeLayer()
                    segmentLayer.path = segmentPath.cgPath
                    segmentLayer.fillColor = segment.color.cgColor
                    
                    chartContainerView.layer.addSublayer(segmentLayer)
                    barLayers.append(segmentLayer)
                }
            }
        }
        
        // 绘制X轴标签（底部）
        let sampledIndices = calculateSampledIndices(totalPoints: dataCount, for: period)
        drawXAxisLabels(sampledIndices: sampledIndices,
                       barWidth: barWidth,
                       spacing: spacing,
                       chartHeight: chartHeight,
                       leftMargin: leftMargin,
                       topMargin: topMargin,
                       axisLabelFontSize: axisLabelFontSize)
    }
}
