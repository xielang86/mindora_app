//
//  SleepTimeRangeView.swift
//  mindora
//
//  「睡眠目标」直线拖拽控件（不是圆环）。精确对齐 dev/20260812_睡眠计划/HTML/
//  lanhu_03xinjianshuimianjihuazhuyemianv04/index.css 的 .group_34/.box_31/.box_32：
//   - 00:00–24:00 单条水平轴，00:00 与 24:00 是同一循环边界；
//   - 两个可拖拽端点：入睡=蓝色月亮(rgba(102,117,242,1))、起床=橙色太阳(rgba(242,182,106,1))，
//     端点圆 54px→27pt、白色 1px 描边；
//   - 中间三色渐变色带（.group_34 linear-gradient(270deg, #F2B66A 0%, #A07DCA 63.74%, #6675F2 100%)），
//     跨午夜时色带在轨道左右两端各显示一段（同一区间的两截，用两枚沿轨道整宽偏移的同一渐变层实现，
//     而不是简单二色近似——见 setup() 注释）；
//   - 拖动步长 30 分钟，松手吸附整/半点；
//   - 拖动单个端点：只改该端时间，时长跟着变，另一端不动；
//   - 拖动色带本体：两端同步平移，时长不变。
//
import UIKit

final class SleepTimeRangeView: UIView {

    /// 分钟数，均落在 0...1439。回调频率：拖拽过程中持续回调（供上方数字实时刷新），
    /// 松手时的最终值等同最后一次回调值（已按 30 分钟吸附）。
    var onChange: ((_ sleepMinutes: Int, _ wakeMinutes: Int) -> Void)?

    private(set) var sleepMinutes: Int = 22 * 60
    private(set) var wakeMinutes: Int = 7 * 60

    private let trackLayer = CAShapeLayer()
    // 同一份三色渐变，沿轨道整宽复制一份并左移 trackWidth，两者叠加后再用当前选区路径做遮罩——
    // 这样跨午夜时左右两截色带拼接起来仍是同一条连续渐变的两头，而不是各自独立的二色近似。
    private let bandGradientPrimary = CAGradientLayer()
    private let bandGradientWrapped = CAGradientLayer()
    private let bandMaskPrimary = CAShapeLayer()
    private let bandMaskWrapped = CAShapeLayer()
    private let tickContainer = UIView()

    private let sleepHandle = SleepTimeHandleView(symbol: "moon.fill", tint: SleepPlanTheme.sleepBlue, iconSize: 14)
    private let wakeHandle = SleepTimeHandleView(symbol: "sun.max.fill", tint: SleepPlanTheme.wakeOrange, iconSize: 8)
    private let bandHitArea = UIView()

    // .box_29 轨道 598px→299pt，卡片内容宽 607px→303.5pt，两侧各留 2.25pt
    private let sideInset: CGFloat = 2.25
    /// .box_31/.box_32: 54px → 27pt
    private let handleDiameter: CGFloat = 27
    /// .block_3: 轨道底槽 rgba(60,60,60,1)，高 28+4×2=36px→18pt，圆角 6px→3pt
    private let trackHeight: CGFloat = 18
    private let trackCornerRadius: CGFloat = 3
    /// .box_14: 色带高 28px→14pt，圆角 8px→4pt
    private let bandHeight: CGFloat = 14
    private let bandCornerRadius: CGFloat = 4
    /// 轨道竖直中心（端点圆 27pt 上下各溢出轨道 4.5pt）
    private var trackMidY: CGFloat { handleDiameter / 2 }
    private var trackWidth: CGFloat { bounds.width - sideInset * 2 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = .clear

        trackLayer.fillColor = UIColor(red: 60/255, green: 60/255, blue: 60/255, alpha: 1).cgColor
        trackLayer.strokeColor = nil
        layer.addSublayer(trackLayer)

        for (gradient, mask) in [(bandGradientPrimary, bandMaskPrimary), (bandGradientWrapped, bandMaskWrapped)] {
            gradient.colors = SleepPlanTheme.bandGradientColorsLTR
            gradient.locations = SleepPlanTheme.bandGradientLocationsLTR
            // 实际方向在 layoutBandAndHandles 里按当前 sleep/wake 位置逐帧设置。
            mask.fillColor = UIColor.black.cgColor
            mask.strokeColor = nil
            gradient.mask = mask
            layer.addSublayer(gradient)
        }

        addSubview(tickContainer)
        tickContainer.isUserInteractionEnabled = false

        addSubview(bandHitArea)
        addSubview(sleepHandle)
        addSubview(wakeHandle)

        let bandPan = UIPanGestureRecognizer(target: self, action: #selector(handleBandPan(_:)))
        bandHitArea.addGestureRecognizer(bandPan)
        let sleepPan = UIPanGestureRecognizer(target: self, action: #selector(handleSleepPan(_:)))
        sleepHandle.addGestureRecognizer(sleepPan)
        let wakePan = UIPanGestureRecognizer(target: self, action: #selector(handleWakePan(_:)))
        wakeHandle.addGestureRecognizer(wakePan)
    }

    func configure(sleepMinutes: Int, wakeMinutes: Int) {
        self.sleepMinutes = Self.normalize(sleepMinutes)
        self.wakeMinutes = Self.normalize(wakeMinutes)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let midY = trackMidY

        trackLayer.path = UIBezierPath(
            roundedRect: CGRect(x: sideInset, y: midY - trackHeight / 2, width: trackWidth, height: trackHeight),
            cornerRadius: trackCornerRadius).cgPath

        layoutTicks(midY: midY)
        layoutBandAndHandles(midY: midY)
    }

    private func layoutTicks(midY: CGFloat) {
        tickContainer.subviews.forEach { $0.removeFromSuperview() }
        tickContainer.frame = bounds
        // 刻度按设计稿 02｜Screen.png 原样：0,22,20,18,…,4,2,0，从左到右每 2 小时一格。
        // 配合下面的 xPosition：入睡（较晚的时刻）落在左侧、起床落在右侧，色带在两者之间连续。
        // .block_18 主刻度 15px→7.5pt 高、1px 宽、纯白；.box_24 次刻度 6px→3pt 高、白 40%，
        // 每格均分 5 段（4 根次刻度）。刻度画在底槽与色带之上。
        for i in 0...60 where i % 5 != 0 {
            addTick(x: sideInset + trackWidth * CGFloat(i) / 60, midY: midY, height: 3,
                    color: UIColor.white.withAlphaComponent(0.4))
        }

        for i in 0...12 {
            let x = sideInset + trackWidth * CGFloat(i) / 12
            addTick(x: x, midY: midY, height: 7.5, color: .white)

            let hour = (24 - 2 * i + 24) % 24
            let label = UILabel()
            label.text = String(hour)
            label.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeTick)
            label.textColor = .white
            label.sizeToFit()
            // .text-wrapper_16 margin-top 21px→10.5pt（相对轨道底边）
            label.center = CGPoint(x: x, y: midY + trackHeight / 2 + 10.5 + label.bounds.height / 2)
            tickContainer.addSubview(label)
        }
    }

    private func addTick(x: CGFloat, midY: CGFloat, height: CGFloat, color: UIColor) {
        let tick = UIView(frame: CGRect(x: x - 0.5, y: midY - height / 2, width: 1, height: height))
        tick.backgroundColor = color
        tickContainer.addSubview(tick)
    }

    private func layoutBandAndHandles(midY: CGFloat) {
        let sleepX = xPosition(for: sleepMinutes)
        let wakeX = xPosition(for: wakeMinutes)
        sleepHandle.bounds = CGRect(x: 0, y: 0, width: handleDiameter, height: handleDiameter)
        sleepHandle.center = CGPoint(x: sleepX, y: midY)
        wakeHandle.bounds = CGRect(x: 0, y: 0, width: handleDiameter, height: handleDiameter)
        wakeHandle.center = CGPoint(x: wakeX, y: midY)

        // 色带永远画在两个端点之间这一段（设计确认：左边入睡、右边起床，中间连续一条）。
        // 渐变以「入睡→起床」为 0%~100%，铺满这一段；哪一端在左由 sleepX/wakeX 决定。
        let left = min(sleepX, wakeX)
        let right = max(sleepX, wakeX)
        bandGradientPrimary.frame = CGRect(x: left, y: 0, width: right - left, height: bounds.height)
        bandGradientWrapped.frame = .zero
        bandGradientPrimary.startPoint = CGPoint(x: sleepX <= wakeX ? 0 : 1, y: 0.5)
        bandGradientPrimary.endPoint = CGPoint(x: sleepX <= wakeX ? 1 : 0, y: 0.5)

        let path1 = bandRectPath(from: left, to: right, midY: midY)
        let path2 = UIBezierPath()
        applyLocalMask(bandMaskPrimary, layer: bandGradientPrimary, path1: path1, path2: path2)
        applyLocalMask(bandMaskWrapped, layer: bandGradientWrapped, path1: UIBezierPath(), path2: UIBezierPath())

        bandHitArea.frame = CGRect(x: min(sleepX, wakeX) - 10, y: midY - 20,
                                    width: abs(wakeX - sleepX) + 20, height: 40)
    }

    /// 色带矩形（.box_14：高 14pt、圆角 4pt，垂直居中于轨道）。
    private func bandRectPath(from x0: CGFloat, to x1: CGFloat, midY: CGFloat) -> UIBezierPath {
        let rect = CGRect(x: min(x0, x1), y: midY - bandHeight / 2, width: max(0, abs(x1 - x0)), height: bandHeight)
        guard rect.width > 0 else { return UIBezierPath() }
        return UIBezierPath(roundedRect: rect, cornerRadius: min(bandCornerRadius, rect.width / 2))
    }

    /// 把「相对 view 的选区路径」平移进目标渐变层自己的局部坐标系（减去 layer.frame.origin）。
    private func applyLocalMask(_ mask: CAShapeLayer, layer: CAGradientLayer, path1: UIBezierPath, path2: UIBezierPath) {
        let combined = UIBezierPath()
        combined.append(path1)
        combined.append(path2)
        var t = CGAffineTransform(translationX: -layer.frame.origin.x, y: -layer.frame.origin.y)
        if let localPath = combined.cgPath.copy(using: &t) {
            mask.path = localPath
        }
    }

    // MARK: - Coordinate mapping

    /// 轴按设计稿 02｜Screen.png：左端 24:00、右端 00:00，刻度 0,22,20,…,2,0。
    /// 这样默认的过夜作息（入睡 22:00 / 起床 07:00）就是「左边入睡、右边起床」，
    /// 色带在两个端点之间连续显示——这是设计确认过的读法。
    private func xPosition(for minutes: Int) -> CGFloat {
        sideInset + trackWidth * (1 - CGFloat(minutes) / 1440)
    }

    private func minutes(for x: CGFloat) -> Int {
        let clamped = max(sideInset, min(bounds.width - sideInset, x))
        let raw = (1 - Double((clamped - sideInset) / trackWidth)) * 1440
        return Self.normalize(Int(raw.rounded()))
    }

    /// 30 分钟吸附。
    private static func snap(_ minutes: Int) -> Int {
        let step = 30
        return normalize(Int((Double(minutes) / Double(step)).rounded()) * step)
    }

    private static func normalize(_ minutes: Int) -> Int {
        let m = minutes % 1440
        return m < 0 ? m + 1440 : m
    }

    // MARK: - Gestures

    @objc private func handleSleepPan(_ gr: UIPanGestureRecognizer) {
        let x = gr.location(in: self).x
        sleepMinutes = Self.snap(minutes(for: x))
        setNeedsLayout()
        onChange?(sleepMinutes, wakeMinutes)
    }

    @objc private func handleWakePan(_ gr: UIPanGestureRecognizer) {
        let x = gr.location(in: self).x
        wakeMinutes = Self.snap(minutes(for: x))
        setNeedsLayout()
        onChange?(sleepMinutes, wakeMinutes)
    }

    private var bandDragStartSleep = 0
    private var bandDragStartWake = 0

    @objc private func handleBandPan(_ gr: UIPanGestureRecognizer) {
        switch gr.state {
        case .began:
            bandDragStartSleep = sleepMinutes
            bandDragStartWake = wakeMinutes
        case .changed, .ended:
            // 轴是「左晚右早」（xPosition 用的是 1 - m/1440），所以屏幕上向右平移 = 时间变早，
            // 这里必须取负号。改轴方向时这一处要跟着改。
            let dxMinutes = -Int((gr.translation(in: self).x / trackWidth) * 1440)
            sleepMinutes = Self.snap(Self.normalize(bandDragStartSleep + dxMinutes))
            // 保持原时长，起床时间跟随平移（不重新从 x 坐标算，避免时长在吸附时漂移）。
            let duration = Self.normalize(bandDragStartWake - bandDragStartSleep)
            wakeMinutes = Self.normalize(sleepMinutes + duration)
            setNeedsLayout()
            onChange?(sleepMinutes, wakeMinutes)
        default: break
        }
    }
}

/// 拖拽端点：圆形色块 + SF Symbol 图标（月亮/太阳），.box_31/.box_32：54px→27pt，白色 1px 描边。
private final class SleepTimeHandleView: UIView {
    init(symbol: String, tint: UIColor, iconSize: CGFloat) {
        super.init(frame: .zero)
        backgroundColor = tint
        isUserInteractionEnabled = true
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: iconSize),
            icon.heightAnchor.constraint(equalToConstant: iconSize)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }
}
