//
//  SleepGraphView.swift
//  mindora
//
//  睡眠日视图 - 展示从就寝到起床的完整睡眠窗口
//  参考 Apple Health 应用的睡眠展示方式
//

import UIKit

/// 睡眠阶段类型
enum SleepStage {
    case awake      // 清醒
    case rem        // 快速动眼睡眠
    case core       // 核心睡眠
    case deep       // 深度睡眠
    
    var color: UIColor {
        switch self {
        case .awake:
            return UIColor.white
        case .rem:
            return UIColor(red: 86/255.0, green: 239/255.0, blue: 65/255.0, alpha: 1.0)
        case .core:
            return UIColor(red: 21/255.0, green: 178/255.0, blue: 4/255.0, alpha: 1.0)
        case .deep:
            return UIColor(red: 10/255.0, green: 137/255.0, blue: 0/255.0, alpha: 1.0)
        }
    }
    
    // 在纵向堆叠图中的垂直位置（0=底部，3=顶部）
    var verticalLevel: Int {
        switch self {
        case .deep:
            return 0  // 最底部
        case .core:
            return 1
        case .rem:
            return 2
        case .awake:
            return 3  // 最顶部
        }
    }
    
    var localizedName: String {
        switch self {
        case .awake:
            return L("health.sleep.stage.awake")
        case .rem:
            return L("health.sleep.stage.rem")
        case .core:
            return L("health.sleep.stage.core")
        case .deep:
            return L("health.sleep.stage.deep")
        }
    }
}

/// 睡眠阶段数据点
struct SleepStageData {
    let stage: SleepStage
    let startTime: Date
    let endTime: Date
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
}

/// 睡眠图表视图
final class SleepGraphView: UIView {
    
    // MARK: - Properties
    private var sleepData: [SleepStageData] = []
    private var sleepWindowStart: Date?
    private var sleepWindowEnd: Date?
    
    // 时间轴标签容器
    private let timeAxisContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    // 睡眠条容器（纵向堆叠的图表区域）
    private let sleepChartContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    // 背景网格线容器
    private let gridContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear
        
        // 添加背景网格（在最底层）
        addSubview(gridContainer)
        
        // 添加睡眠图表容器
        addSubview(sleepChartContainer)
        
        // 添加时间轴（移到底部）
        addSubview(timeAxisContainer)
        
        NSLayoutConstraint.activate([
            // 背景网格和图表容器在顶部
            gridContainer.topAnchor.constraint(equalTo: topAnchor),
            gridContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            gridContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            gridContainer.heightAnchor.constraint(equalToConstant: 140),
            
            sleepChartContainer.topAnchor.constraint(equalTo: gridContainer.topAnchor),
            sleepChartContainer.leadingAnchor.constraint(equalTo: gridContainer.leadingAnchor),
            sleepChartContainer.trailingAnchor.constraint(equalTo: gridContainer.trailingAnchor),
            sleepChartContainer.heightAnchor.constraint(equalTo: gridContainer.heightAnchor),
            
            // 时间轴在底部
            timeAxisContainer.topAnchor.constraint(equalTo: sleepChartContainer.bottomAnchor, constant: 8),
            timeAxisContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            timeAxisContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            timeAxisContainer.heightAnchor.constraint(equalToConstant: 20),
            timeAxisContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    // MARK: - Configuration
    func configure(with sleepData: [SleepStageData]) {
        self.sleepData = sleepData
        
        guard !sleepData.isEmpty else {
            showPlaceholder()
            return
        }
        
        // 计算睡眠窗口
        sleepWindowStart = sleepData.map { $0.startTime }.min()
        sleepWindowEnd = sleepData.map { $0.endTime }.max()
        
        // 立即布局以获取正确的bounds
        setNeedsLayout()
        layoutIfNeeded()
        
        // 绘制背景网格
        drawBackgroundGrid()
        
        // 绘制睡眠条（纵向堆叠）
        drawSleepBars()
        
        // 绘制时间轴
        drawTimeAxis()
    }
    
    // MARK: - Drawing
    private func drawBackgroundGrid() {
        // 清除之前的网格
        gridContainer.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        // 不再绘制背景网格线
    }
    
    private func drawSleepBars() {
        // 清除之前的视图
        sleepChartContainer.subviews.forEach { $0.removeFromSuperview() }
        sleepChartContainer.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        guard let windowStart = sleepWindowStart,
              let windowEnd = sleepWindowEnd else { return }
        
        let totalDuration = windowEnd.timeIntervalSince(windowStart)
        guard totalDuration > 0 else { return }
        
        let containerWidth = sleepChartContainer.bounds.width
        let containerHeight = sleepChartContainer.bounds.height
        
        // 每个层级的高度（增加间距）
        let verticalSpacing: CGFloat = 8  // 层级之间的间距
        let levelHeight = (containerHeight - 3 * verticalSpacing) / 4  // 4个层级，3个间距
        
        // 先绘制连接线层
        let connectionLayer = CALayer()
        sleepChartContainer.layer.addSublayer(connectionLayer)
        
        // 使用 CAShapeLayer 绘制更平滑的条形图
        var previousData: (stage: SleepStage, endX: CGFloat, level: Int)?
        
        for data in sleepData {
            let startOffset = data.startTime.timeIntervalSince(windowStart)
            let duration = data.duration
            
            let xPosition = CGFloat(startOffset / totalDuration) * containerWidth
            let width = max(CGFloat(duration / totalDuration) * containerWidth, 1.5)
            
            // 根据睡眠阶段确定垂直位置（从底部开始，考虑间距）
            let level = data.stage.verticalLevel
            let yPosition = containerHeight - CGFloat(level + 1) * levelHeight - CGFloat(level) * verticalSpacing
            
            // 如果当前块与上一个块不在同一时间点，绘制连接线
            if let previous = previousData, abs(previous.endX - xPosition) < 2 {
                // 计算上一个块的 Y 位置
                let previousYPosition = containerHeight - CGFloat(previous.level + 1) * levelHeight - CGFloat(previous.level) * verticalSpacing
                let previousYCenter = previousYPosition + levelHeight / 2
                let currentYCenter = yPosition + levelHeight / 2
                
                // 绘制垂直连接线
                let linePath = UIBezierPath()
                linePath.move(to: CGPoint(x: previous.endX, y: previousYCenter))
                linePath.addLine(to: CGPoint(x: xPosition, y: currentYCenter))
                
                let lineLayer = CAShapeLayer()
                lineLayer.path = linePath.cgPath
                lineLayer.strokeColor = data.stage.color.withAlphaComponent(0.6).cgColor
                lineLayer.lineWidth = 1.5
                lineLayer.lineCap = .round
                
                connectionLayer.addSublayer(lineLayer)
            }
            
            // 使用 CAShapeLayer 绘制圆角矩形
            let shapeLayer = CAShapeLayer()
            let rect = CGRect(x: xPosition, y: yPosition, width: width, height: levelHeight)
            
            // 创建圆角矩形路径
            let cornerRadius: CGFloat = min(4, width / 2, levelHeight / 2)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            
            shapeLayer.path = path.cgPath
            shapeLayer.fillColor = data.stage.color.cgColor
            
            // 添加轻微的阴影效果使其更有立体感
            shapeLayer.shadowColor = UIColor.black.cgColor
            shapeLayer.shadowOffset = CGSize(width: 0, height: 1)
            shapeLayer.shadowOpacity = 0.15
            shapeLayer.shadowRadius = 2
            
            sleepChartContainer.layer.addSublayer(shapeLayer)
            
            // 记录当前块的信息，用于下一次绘制连接线
            previousData = (stage: data.stage, endX: xPosition + width, level: level)
        }
    }
    
    private func drawTimeAxis() {
        // 清除之前的标签
        timeAxisContainer.subviews.forEach { $0.removeFromSuperview() }
        
        guard let windowStart = sleepWindowStart,
              let windowEnd = sleepWindowEnd else { return }
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        
        // 获取容器宽度用于计算位置
        let containerWidth = timeAxisContainer.bounds.width
        
        // 创建开始和结束时间标签
        let startLabel = createTimeLabel(text: dateFormatter.string(from: windowStart))
        let endLabel = createTimeLabel(text: dateFormatter.string(from: windowEnd))
        
        timeAxisContainer.addSubview(startLabel)
        timeAxisContainer.addSubview(endLabel)
        
        // 使用frame直接设置位置,避免约束计算延迟
        startLabel.sizeToFit()
        endLabel.sizeToFit()
        startLabel.frame.origin = CGPoint(x: 0, y: (timeAxisContainer.bounds.height - startLabel.bounds.height) / 2)
        endLabel.frame.origin = CGPoint(x: containerWidth - endLabel.bounds.width, y: (timeAxisContainer.bounds.height - endLabel.bounds.height) / 2)
        
        // 计算时间跨度并添加合适的中间时间标记
        let hours = calendar.dateComponents([.hour], from: windowStart, to: windowEnd).hour ?? 0
        
        if hours >= 6 {
            // 对于较长的睡眠时间，添加2-3个中间时间标记
            let interval = windowEnd.timeIntervalSince(windowStart)
            
            // 添加1/3和2/3位置的时间标记
            let time1 = windowStart.addingTimeInterval(interval / 3)
            let time2 = windowStart.addingTimeInterval(interval * 2 / 3)
            
            let label1 = createTimeLabel(text: dateFormatter.string(from: time1))
            let label2 = createTimeLabel(text: dateFormatter.string(from: time2))
            
            timeAxisContainer.addSubview(label1)
            timeAxisContainer.addSubview(label2)
            
            label1.sizeToFit()
            label2.sizeToFit()
            label1.frame.origin = CGPoint(x: containerWidth / 3 - label1.bounds.width / 2, y: (timeAxisContainer.bounds.height - label1.bounds.height) / 2)
            label2.frame.origin = CGPoint(x: containerWidth * 2 / 3 - label2.bounds.width / 2, y: (timeAxisContainer.bounds.height - label2.bounds.height) / 2)
            
        } else if hours >= 4 {
            // 对于中等长度的睡眠时间，添加1个中间时间标记
            let midTime = windowStart.addingTimeInterval((windowEnd.timeIntervalSince(windowStart)) / 2)
            let midLabel = createTimeLabel(text: dateFormatter.string(from: midTime))
            
            timeAxisContainer.addSubview(midLabel)
            
            midLabel.sizeToFit()
            midLabel.frame.origin = CGPoint(x: containerWidth / 2 - midLabel.bounds.width / 2, y: (timeAxisContainer.bounds.height - midLabel.bounds.height) / 2)
        }
    }
    
    private func createTimeLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        label.textColor = UIColor.white
        label.textAlignment = .center
        return label
    }
    
    private func showPlaceholder() {
        sleepChartContainer.subviews.forEach { $0.removeFromSuperview() }
        sleepChartContainer.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        timeAxisContainer.subviews.forEach { $0.removeFromSuperview() }
        gridContainer.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        let placeholderLabel = UILabel()
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.text = L("health.sleep.no_data")
        placeholderLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        placeholderLabel.textColor = UIColor.white.withAlphaComponent(0.4)
        placeholderLabel.textAlignment = .center
        
        sleepChartContainer.addSubview(placeholderLabel)
        
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: sleepChartContainer.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: sleepChartContainer.centerYAnchor)
        ])
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 只在有数据且bounds变化时重新绘制
        if !sleepData.isEmpty && bounds.width > 0 {
            drawBackgroundGrid()
            drawSleepBars()
            // 时间轴使用frame布局,也需要重新计算位置
            drawTimeAxis()
        }
    }
}
