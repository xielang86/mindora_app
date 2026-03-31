import UIKit

class HRVRowView: MetricRowView {
    let valueLabel = UILabel()
    let unitLabel = UILabel()
    
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
        let iconDesignSize = CGSize(width: 66, height: 60)
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
        let thumbnailTrailing = vc.scale(50, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        
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
        
        titleLabel.text = L("health.metric.hrv")
    }
    
    override func configureValue(metrics: HealthMetrics) {
        if let hrv = metrics.heartRateVariability {
            valueLabel.text = String(format: "%.0f", hrv.value)
            unitLabel.text = L("health.unit.ms")
            timeLabel.text = formatDataTime(hrv.date)
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
        let detailVC = HealthDetailViewController(metricType: .hrv)
        vc.navigationController?.pushViewController(detailVC, animated: true)
    }
    
    override func loadWeeklyThumbnailData() {
        Task { @MainActor in
            do {
                let data = try await HealthDataManager.shared.fetchWeeklyData()
                self.weeklyData = data.hrv
                self.drawThumbnailChart()
            } catch {
                Log.error("HRVRowView", "Failed to load weekly data: \(error)")
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
        
        guard !weeklyData.isEmpty else { return }
        
        let maxValue = weeklyData.max() ?? 1
        let minValue: Double = 0
        let range = maxValue - minValue
        guard range > 0 else { return }
        
        let barCount = weeklyData.count
        let barSpacing: CGFloat = 6
        let totalSpacing = CGFloat(barCount - 1) * barSpacing
        let barWidth = (chartWidth - totalSpacing) / CGFloat(barCount)
        let circleRadius: CGFloat = barWidth * 0.35
        let circleLineWidth: CGFloat = 1.5
        let lineWidth: CGFloat = 1.5
        
        var points: [CGPoint] = []
        for (index, value) in weeklyData.enumerated() {
            let normalizedValue = (value - minValue) / range
            let x = CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
            let y = chartHeight * (1 - CGFloat(normalizedValue))
            points.append(CGPoint(x: x, y: y))
        }
        
        var validIndices: [Int] = []
        for (index, value) in weeklyData.enumerated() {
            if value > 0 { validIndices.append(index) }
        }
        
        for i in 0..<(validIndices.count - 1) {
            let currentIndex = validIndices[i]
            let nextIndex = validIndices[i + 1]
            
            var isContinuous = true
            for j in (currentIndex + 1)..<nextIndex {
                if weeklyData[j] == 0 {
                    isContinuous = false
                    break
                }
            }
            if !isContinuous { continue }
            
            let startCenter = points[currentIndex]
            let endCenter = points[nextIndex]
            
            let dx = endCenter.x - startCenter.x
            let dy = endCenter.y - startCenter.y
            let distance = sqrt(dx * dx + dy * dy)
            guard distance > 2 * circleRadius else { continue }
            
            let unitX = dx / distance
            let unitY = dy / distance
            
            let startEdge = CGPoint(x: startCenter.x + unitX * circleRadius, y: startCenter.y + unitY * circleRadius)
            let endEdge = CGPoint(x: endCenter.x - unitX * circleRadius, y: endCenter.y - unitY * circleRadius)
            
            let linePath = UIBezierPath()
            linePath.move(to: startEdge)
            linePath.addLine(to: endEdge)
            
            let lineLayer = CAShapeLayer()
            lineLayer.path = linePath.cgPath
            lineLayer.strokeColor = UIColor(red: 60/255.0, green: 60/255.0, blue: 60/255.0, alpha: 1.0).cgColor
            lineLayer.fillColor = nil
            lineLayer.lineWidth = lineWidth
            lineLayer.lineCap = .round
            
            thumbnailChartView.layer.addSublayer(lineLayer)
            thumbnailBarLayers.append(lineLayer)
        }
        
        for (index, value) in weeklyData.enumerated() {
            if value > 0 {
                let point = points[index]
                let circlePath = UIBezierPath(
                    arcCenter: point,
                    radius: circleRadius,
                    startAngle: 0,
                    endAngle: CGFloat.pi * 2,
                    clockwise: true
                )
                
                let circleLayer = CAShapeLayer()
                circleLayer.path = circlePath.cgPath
                circleLayer.fillColor = DesignConstants.tabBarBackgroundColor.cgColor
                let color = index == barCount - 1 ? DesignConstants.lightGreen : UIColor(red: 60/255.0, green: 60/255.0, blue: 60/255.0, alpha: 1.0)
                circleLayer.strokeColor = color.cgColor
                circleLayer.lineWidth = circleLineWidth
                
                thumbnailChartView.layer.addSublayer(circleLayer)
                thumbnailBarLayers.append(circleLayer)
            }
        }
    }
}
