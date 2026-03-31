import UIKit

class HeartRateRowView: MetricRowView {
    let valueLabel = UILabel()
    let unitLabel = UILabel()
    
    private var weeklyHeartRateRange: [HealthDataManager.HeartRateRangePoint] = []
    private var weeklyData: [Double] = []
    
    override init(imageName: String, viewController: HealthViewController) {
        super.init(imageName: imageName, viewController: viewController)
        setupSpecificUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupSpecificUI() {
        guard let vc = viewController else { return }
        
        addSubview(valueLabel)
        addSubview(unitLabel)
        
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        unitLabel.translatesAutoresizingMaskIntoConstraints = false
        
        valueLabel.textColor = .white
        unitLabel.textColor = DesignConstants.grayColor
        
        // Fonts
        let valueFontSize = vc.scale(104, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        let unitFontSize = vc.scale(58, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        
        valueLabel.font = UIFont(name: "PingFangSC-Medium", size: valueFontSize) ?? UIFont.systemFont(ofSize: valueFontSize, weight: .medium)
        unitLabel.font = UIFont(name: "PingFangSC-Medium", size: unitFontSize) ?? UIFont.systemFont(ofSize: unitFontSize, weight: .medium)
        
        unitLabel.setContentHuggingPriority(.required, for: .horizontal)
        unitLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        // Icon Size
        let iconDesignSize = CGSize(width: 66, height: 61)
        let iconWidthScaled = vc.scale(iconDesignSize.width, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        let iconHeightScaled = vc.scale(iconDesignSize.height, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: iconWidthScaled),
            iconImageView.heightAnchor.constraint(equalToConstant: iconHeightScaled)
        ])
        
        // Layout
        let valueLeading = vc.scale(50, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        let valueBottom = vc.scale(26, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        let baselineOffset = vc.scale(28, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        let thumbnailWidth = vc.scale(200, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        let thumbnailHeight = vc.scale(120, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        let thumbnailTrailing = vc.scale(50, basedOn: vc.view.bounds.width, designDimension: vc.designWidth) // Same as arrowTrailing
        
        NSLayoutConstraint.activate([
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: valueLeading),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -valueBottom),
            
            unitLabel.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: vc.scale(30, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)),
            unitLabel.lastBaselineAnchor.constraint(equalTo: valueLabel.lastBaselineAnchor),
            unitLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            
            thumbnailChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -thumbnailTrailing),
            thumbnailChartView.bottomAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: baselineOffset),
            thumbnailChartView.widthAnchor.constraint(equalToConstant: thumbnailWidth),
            thumbnailChartView.heightAnchor.constraint(equalToConstant: thumbnailHeight)
        ])
        
        titleLabel.text = L("health.metric.heart_rate")
    }
    
    override func configureValue(metrics: HealthMetrics) {
        if let hr = metrics.heartRate {
            valueLabel.text = String(format: "%.0f", hr.value)
            unitLabel.text = L("health.unit.bpm")
            timeLabel.text = formatDataTime(hr.date)
        } else {
            showPlaceholder()
            timeLabel.text = ""
        }
        loadWeeklyThumbnailData()
    }
    
    override func showPlaceholder() {
        valueLabel.text = "--"
        unitLabel.text = ""
    }
    
    override func navigateToDetail() {
        guard let vc = viewController else { return }
        let detailVC = HealthDetailViewController(metricType: .heartRate)
        vc.navigationController?.pushViewController(detailVC, animated: true)
    }
    
    override func loadWeeklyThumbnailData() {
        Task { @MainActor in
            do {
                let data = try await HealthDataManager.shared.fetchWeeklyData()
                self.weeklyHeartRateRange = data.heartRateRange
                self.weeklyData = data.heartRate
                self.drawThumbnailChart()
            } catch {
                Log.error("HeartRateRowView", "Failed to load weekly data: \(error)")
            }
        }
    }
    
    private func drawThumbnailChart() {
        thumbnailBarLayers.forEach { $0.removeFromSuperlayer() }
        thumbnailBarLayers.removeAll()
        
        let chartWidth = thumbnailChartView.bounds.width
        let chartHeight = thumbnailChartView.bounds.height
        
        guard chartWidth > 0, chartHeight > 0 else {
            DispatchQueue.main.async { [weak self] in
                self?.drawThumbnailChart()
            }
            return
        }
        
        guard !weeklyHeartRateRange.isEmpty else {
            drawSimpleBarThumbnail(chartWidth: chartWidth, chartHeight: chartHeight, data: weeklyData)
            return
        }
        
        let validData = weeklyHeartRateRange.filter { $0.isValid }
        guard !validData.isEmpty else { return }
        
        let maxValue = validData.map { $0.max }.max() ?? 1
        
        let barCount = weeklyHeartRateRange.count
        let barSpacing: CGFloat = 6
        let totalSpacing = CGFloat(barCount - 1) * barSpacing
        let barWidth = (chartWidth - totalSpacing) / CGFloat(barCount)
        let lineWidth = barWidth * 0.5
        let circleRadius = lineWidth / 2
        
        for (index, point) in weeklyHeartRateRange.enumerated() {
            let x = CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
            let color = index == barCount - 1 ? DesignConstants.lightGreen : UIColor(red: 60/255.0, green: 60/255.0, blue: 60/255.0, alpha: 1.0)
            
            guard point.isValid else { continue }
            
            let normalizedMax = point.max / maxValue
            let normalizedMin = point.min / maxValue
            let yTop = chartHeight * (1 - CGFloat(normalizedMax))
            let yBottom = chartHeight * (1 - CGFloat(normalizedMin))
            let barHeight = yBottom - yTop
            
            if barHeight < circleRadius * 2 {
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
                circleLayer.fillColor = color.cgColor
                thumbnailChartView.layer.addSublayer(circleLayer)
                thumbnailBarLayers.append(circleLayer)
            } else {
                let barRect = CGRect(x: x - lineWidth / 2, y: yTop, width: lineWidth, height: barHeight)
                let barPath = UIBezierPath(roundedRect: barRect, cornerRadius: circleRadius)
                let barLayer = CAShapeLayer()
                barLayer.path = barPath.cgPath
                barLayer.fillColor = color.cgColor
                thumbnailChartView.layer.addSublayer(barLayer)
                thumbnailBarLayers.append(barLayer)
            }
        }
    }
}
