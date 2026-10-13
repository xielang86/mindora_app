//
//  iPadAdaptiveScale.swift
//  mindora
//
//  Every screen in this app lays itself out with a private `scale(_:basedOn:designDimension:)`
//  helper that scales phone-design pixel values against the device's own `view.bounds`.
//  That's correct across iPhones (they cluster around the same aspect ratio), but on iPad
//  `view.bounds.width/height` is far larger than any iPhone design canvas assumed, so every
//  font/spacing/frame computed from it balloons (and additive top-to-bottom layouts can even
//  overflow off the bottom of the screen).
//
//  `iPadCapped` clamps the raw dimension fed into those scale() calls so iPad never scales
//  past what the largest supported iPhone would produce. On iPhone this is always a no-op
//  (every iPhone's width/height already sits at or below these caps), so iPhone layouts are
//  byte-for-byte unaffected.
//
import UIKit

enum iPadAdaptiveScale {
    /// iPhone 16/15 Pro Max point width — the largest width any shipping iPhone reports.
    static let maxPhoneWidth: CGFloat = 430
    /// iPhone 16/15 Pro Max point height — the largest height any shipping iPhone reports.
    static let maxPhoneHeight: CGFloat = 932

    /// Clamps `dimension` (a raw `view.bounds.width` or `.height`) so legacy phone-design
    /// scale factors don't balloon on iPad. `referenceAxis` should be the same view's
    /// `bounds.width` (to detect a width-based call) — pass it as-is from the call site.
    static func capped(_ dimension: CGFloat, widthReference: CGFloat) -> CGFloat {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return dimension }
        let isWidthAxis = dimension == widthReference
        return min(dimension, isWidthAxis ? maxPhoneWidth : maxPhoneHeight)
    }
}

/// 顶部横幅图（如 register_bg）下沿的「渐隐到背景色」过渡视图。
///
/// 素材图底部烘焙了一段淡出到黑的渐变，用来跟下方纯色背景无缝衔接。在 iPhone 上
/// 容器宽高比≈素材宽高比，`.scaleAspectFill` 不裁剪，烘焙的渐变自然显示；但 iPad
/// 屏幕更宽，同样高度的容器宽高比远大于素材，`.scaleAspectFill` 会把上下裁掉一大截，
/// 恰好把底部烘焙的渐变裁没，留下一条生硬的分界线。
///
/// 这个视图盖在横幅图底部，用一层「透明→背景色」的 CAGradientLayer 重新造出淡出效果，
/// 无论图片被怎么裁剪，底边都能平滑融进背景。只在 iPad 上加它，iPhone 保持原样不变。
final class BottomFadeView: UIView {
    private let gradient = CAGradientLayer()

    init(color: UIColor) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        gradient.colors = [color.withAlphaComponent(0).cgColor, color.cgColor]
        gradient.locations = [0.0, 1.0]
        layer.addSublayer(gradient)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}
