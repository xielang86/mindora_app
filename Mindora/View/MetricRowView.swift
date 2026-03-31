import UIKit

class MetricRowView: UIView {
    let imageName: String
    weak var viewController: HealthViewController?
    
    // UI Elements
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let timeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let thumbnailChartView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()
    
    var thumbnailBarLayers: [CAShapeLayer] = []
    
    init(imageName: String, viewController: HealthViewController) {
        self.imageName = imageName
        self.viewController = viewController
        super.init(frame: .zero)
        setupBaseUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupBaseUI() {
        backgroundColor = DesignConstants.tabBarBackgroundColor
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        addSubview(titleLabel)
        addSubview(iconImageView)
        addSubview(arrowImageView)
        addSubview(timeLabel)
        addSubview(thumbnailChartView)
        
        iconImageView.image = UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate)
        iconImageView.tintColor = DesignConstants.lightGreen
        
        arrowImageView.image = UIImage(named: "boot-right-angle-bracket")?.withRenderingMode(.alwaysTemplate)
        arrowImageView.tintColor = DesignConstants.grayColor
        
        titleLabel.textColor = DesignConstants.lightGreen
        timeLabel.textColor = DesignConstants.grayColor
        
        setupBaseConstraints()
    }
    
    func setupBaseConstraints() {
        guard let vc = viewController else { return }
        
        // 设置圆角
        layer.cornerRadius = vc.scale(vc.designItemCornerRadius, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        
        // 字体设置
        let titleFontSizeScaled = vc.scale(58, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        titleLabel.font = UIFont(name: "PingFangSC-Medium", size: titleFontSizeScaled) ?? UIFont.systemFont(ofSize: titleFontSizeScaled, weight: .medium)
        
        let timeFontSize = vc.scale(48, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        timeLabel.font = UIFont(name: "PingFangSC-Regular", size: timeFontSize) ?? UIFont.systemFont(ofSize: timeFontSize, weight: .regular)
        
        // 布局参数
        let iconLeading = vc.scale(50, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        let iconTop = vc.scale(45, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        let spacingAfterIcon = vc.scale(26, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        
        // 图标尺寸 (默认尺寸，子类可以覆盖或重新约束，但这里我们需要一个默认值)
        // 原始代码中根据 kind 动态计算。这里我们可能需要子类提供尺寸，或者在子类中更新约束。
        // 暂时使用一个默认值，子类 setupUI 时会更新。
        
        let arrowWidth = vc.scale(21, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        let arrowHeight = vc.scale(42, basedOn: vc.view.bounds.height, designDimension: vc.designHeight)
        let arrowTrailing = vc.scale(50, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        let timeToArrowSpacing = vc.scale(40, basedOn: vc.view.bounds.width, designDimension: vc.designWidth)
        
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: iconTop),
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: iconLeading),
            // width/height constraints will be added by subclasses or helper
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: spacingAfterIcon),
            titleLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            
            arrowImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -arrowTrailing),
            arrowImageView.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: arrowWidth),
            arrowImageView.heightAnchor.constraint(equalToConstant: arrowHeight),
            
            timeLabel.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -timeToArrowSpacing),
            timeLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor)
        ])
    }
    
    func configureValue(metrics: HealthMetrics) {
        // Override in subclass
    }
    
    func loadWeeklyThumbnailData() {
        // Override in subclass
    }
    
    @objc private func handleTap() {
        let originalColor = backgroundColor
        backgroundColor = DesignConstants.grayColor
        UIView.animate(withDuration: 0.2, delay: 0.1, options: [], animations: {
            self.backgroundColor = originalColor
        }, completion: { [weak self] _ in
            self?.navigateToDetail()
        })
    }
    
    func navigateToDetail() {
        // Override in subclass
    }
    
    func formatDataTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            formatter.dateFormat = "M月d日"
        } else {
            formatter.dateFormat = "yyyy年M月"
        }
        return formatter.string(from: date)
    }
    
    func showPlaceholder() {
        // Override
    }
    
    // Shared helper for simple bar chart
    func drawSimpleBarThumbnail(chartWidth: CGFloat, chartHeight: CGFloat, data: [Double]) {
        guard !data.isEmpty else { return }
        
        let maxValue = data.max() ?? 1
        let minValue: Double = 0
        let range = maxValue - minValue
        guard range > 0 else { return }
        
        let barCount = data.count
        let barSpacing: CGFloat = 4
        let totalSpacing = CGFloat(barCount - 1) * barSpacing
        let barWidth = (chartWidth - totalSpacing) / CGFloat(barCount)
        let cornerRadius = barWidth / 2
        
        for (index, value) in data.enumerated() {
            let normalizedValue = (value - minValue) / range
            let barHeight = max(chartHeight * CGFloat(normalizedValue), cornerRadius * 2)
            
            let x = CGFloat(index) * (barWidth + barSpacing)
            let y = chartHeight - barHeight
            
            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let barPath = UIBezierPath(roundedRect: barRect, cornerRadius: cornerRadius)
            
            let barLayer = CAShapeLayer()
            barLayer.path = barPath.cgPath
            
            if index == barCount - 1 {
                barLayer.fillColor = DesignConstants.lightGreen.cgColor
            } else {
                barLayer.fillColor = UIColor(red: 60/255.0, green: 60/255.0, blue: 60/255.0, alpha: 1.0).cgColor
            }
            
            thumbnailChartView.layer.addSublayer(barLayer)
            thumbnailBarLayers.append(barLayer)
        }
    }
}
