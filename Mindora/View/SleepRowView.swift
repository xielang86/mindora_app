import UIKit

class SleepRowView: MetricRowView {
    private let sleepStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 1
        stack.alignment = .lastBaseline
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
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
    
    private var weeklySleepRange: [HealthDataManager.SleepRangePoint] = []
    private var weeklyData: [Double] = []
    
    override init(imageName: String, viewController: HealthViewController) {
        super.init(imageName: imageName, viewController: viewController)
        setupSpecificUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupSpecificUI() {
        guard let vc = viewController else { return }
        
        addSubview(sleepStackView)
        sleepStackView.addArrangedSubview(sleepHoursLabel)
        sleepStackView.addArrangedSubview(sleepHoursUnitLabel)
        sleepStackView.addArrangedSubview(sleepMinutesLabel)
        sleepStackView.addArrangedSubview(sleepMinutesUnitLabel)
        
        // Fonts
        let valueFontSize = vc.scale(104, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        let unitFontSize = vc.scale(58, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        
        sleepHoursLabel.font = UIFont(name: "PingFangSC-Medium", size: valueFontSize) ?? UIFont.systemFont(ofSize: valueFontSize, weight: .medium)
        sleepHoursUnitLabel.font = UIFont(name: "PingFangSC-Medium", size: unitFontSize) ?? UIFont.systemFont(ofSize: unitFontSize, weight: .medium)
        sleepMinutesLabel.font = UIFont(name: "PingFangSC-Medium", size: valueFontSize) ?? UIFont.systemFont(ofSize: valueFontSize, weight: .medium)
        sleepMinutesUnitLabel.font = UIFont(name: "PingFangSC-Medium", size: unitFontSize) ?? UIFont.systemFont(ofSize: unitFontSize, weight: .medium)
        
        sleepHoursUnitLabel.textColor = DesignConstants.grayColor
        sleepMinutesUnitLabel.textColor = DesignConstants.grayColor
        
        // Icon Size
        let iconDesignSize = CGSize(width: 70, height: 45)
        let iconWidthScaled = vc.scale(iconDesignSize.width, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        let iconHeightScaled = vc.scale(iconDesignSize.height, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: iconWidthScaled),
            iconImageView.heightAnchor.constraint(equalToConstant: iconHeightScaled)
        ])
        
        // Layout
        let valueLeading = vc.scale(50, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        let valueBottom = vc.scale(26, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        let thumbnailWidth = vc.scale(200, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        let thumbnailHeight = vc.scale(120, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        let thumbnailTrailing = vc.scale(50, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        
        sleepStackView.spacing = vc.scale(30, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        
        NSLayoutConstraint.activate([
            sleepStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: valueLeading),
            sleepStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -valueBottom),
            sleepStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: sleepStackView.topAnchor, constant: -vc.scale(10, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)),
            
            thumbnailChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -thumbnailTrailing),
            thumbnailChartView.bottomAnchor.constraint(equalTo: sleepStackView.bottomAnchor),
            thumbnailChartView.widthAnchor.constraint(equalToConstant: thumbnailWidth),
            thumbnailChartView.heightAnchor.constraint(equalToConstant: thumbnailHeight)
        ])
        
        titleLabel.text = L("health.metric.sleep")
    }
    
    override func configureValue(metrics: HealthMetrics) {
        if let s = metrics.sleepSummary {
            let totalMinutes = Int((s.totalSleepHours * 60.0).rounded(.down))
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            
            sleepHoursLabel.text = String(hours)
            sleepHoursUnitLabel.text = L("health.unit.hours")
            sleepMinutesLabel.text = String(minutes)
            sleepMinutesUnitLabel.text = L("health.unit.minutes")
            timeLabel.text = formatDataTime(s.date)
        } else {
            showPlaceholder()
            timeLabel.text = ""
        }
        loadWeeklyThumbnailData()
    }
    
    override func showPlaceholder() {
        sleepHoursLabel.text = "--"
        sleepHoursUnitLabel.text = ""
        sleepMinutesLabel.text = ""
        sleepMinutesUnitLabel.text = ""
    }
    
    override func navigateToDetail() {
        guard let vc = viewController else { return }
        let detailVC = HealthDetailViewController(metricType: .sleep)
        vc.navigationController?.pushViewController(detailVC, animated: true)
    }
    
    override func loadWeeklyThumbnailData() {
        Task { @MainActor in
            do {
                let data = try await HealthDataManager.shared.fetchWeeklyData()
                self.weeklySleepRange = data.sleepRange
                self.weeklyData = data.sleep
                self.drawThumbnailChart()
            } catch {
                Log.error("SleepRowView", "Failed to load weekly data: \(error)")
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
        
        guard !weeklySleepRange.isEmpty else {
            drawSimpleBarThumbnail(chartWidth: chartWidth, chartHeight: chartHeight, data: weeklyData)
            return
        }
        
        let validData = weeklySleepRange.filter { $0.isValid }
        guard !validData.isEmpty else { return }
        
        let allMinutes = validData.flatMap { [$0.bedStartMinutes, $0.bedEndMinutes, $0.sleepStartMinutes, $0.sleepEndMinutes] }
        let dataMin = allMinutes.min() ?? 0
        let dataMax = allMinutes.max() ?? 840
        
        let yMinMinutes = max(0, floor(dataMin / 60) * 60 - 60)
        let yMaxMinutes = min(840, ceil(dataMax / 60) * 60 + 60)
        let yRange = yMaxMinutes - yMinMinutes
        guard yRange > 0 else { return }
        
        let barCount = weeklySleepRange.count
        let barSpacing: CGFloat = 6
        let totalSpacing = CGFloat(barCount - 1) * barSpacing
        let barWidth = (chartWidth - totalSpacing) / CGFloat(barCount)
        let lineWidth = barWidth * 0.5
        let cornerRadius = lineWidth / 2
        
        for (index, point) in weeklySleepRange.enumerated() {
            let x = CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
            
            guard point.isValid else { continue }
            
            func yForMinutes(_ minutes: Double) -> CGFloat {
                let normalized = (minutes - yMinMinutes) / yRange
                return chartHeight * (1 - CGFloat(normalized))
            }
            
            let isLastDay = index == barCount - 1
            
            let bedTop = yForMinutes(point.bedEndMinutes)
            let bedBottom = yForMinutes(point.bedStartMinutes)
            let bedHeight = bedBottom - bedTop
            
            if bedHeight > 0 {
                let bedRect = CGRect(x: x - lineWidth / 2, y: bedTop, width: lineWidth, height: bedHeight)
                let bedPath = UIBezierPath(roundedRect: bedRect, cornerRadius: cornerRadius)
                let bedLayer = CAShapeLayer()
                bedLayer.path = bedPath.cgPath
                bedLayer.fillColor = isLastDay ? DesignConstants.darkGreen.cgColor : UIColor(red: 40/255.0, green: 40/255.0, blue: 40/255.0, alpha: 1.0).cgColor
                thumbnailChartView.layer.addSublayer(bedLayer)
                thumbnailBarLayers.append(bedLayer)
            }
            
            let sleepTop = yForMinutes(point.sleepEndMinutes)
            let sleepBottom = yForMinutes(point.sleepStartMinutes)
            let sleepHeight = sleepBottom - sleepTop
            
            if sleepHeight > 0 {
                let sleepRect = CGRect(x: x - lineWidth / 2, y: sleepTop, width: lineWidth, height: sleepHeight)
                let sleepPath = UIBezierPath(roundedRect: sleepRect, cornerRadius: cornerRadius)
                let sleepLayer = CAShapeLayer()
                sleepLayer.path = sleepPath.cgPath
                sleepLayer.fillColor = isLastDay ? DesignConstants.lightGreen.cgColor : UIColor(red: 60/255.0, green: 60/255.0, blue: 60/255.0, alpha: 1.0).cgColor
                thumbnailChartView.layer.addSublayer(sleepLayer)
                thumbnailBarLayers.append(sleepLayer)
            }
        }
    }
}
