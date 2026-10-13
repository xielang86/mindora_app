//
//  SleepPlanTheme.swift
//  mindora
//
//  睡眠计划设计稿的精确取值（来自 dev/20260812_睡眠计划/HTML/*/index.css，设计稿宽度
//  750px = 375pt，比例 2:1，故 pt = px / 2）。所有睡眠计划相关视图统一从这里取色/取值，
//  不再各自估算。
//
//  字体说明：设计稿标注字体为 SourceHanSansCN-Medium/Regular/Normal/Light，
//  App 未内置该字体（无 .ttf/.otf 资源、Info.plist 也未注册 UIAppFonts），
//  只能退回使用 App 现有的系统字体 PingFangSC 对应字重（与全 App 其余页面一致的字体）。
//  这是唯一没有做到"逐像素"的地方——不是简化，是没有字体文件可用。
//
import UIKit

enum SleepPlanTheme {
    // MARK: - 颜色（均取自 CSS rgba 精确值）

    /// 页面背景 rgba(24,24,24,1)
    static let pageBackground = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1)
    /// 卡片/弹层背景 rgba(44,44,44,1)
    static let cardBackground = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1)
    /// 分割线 rgba(255,255,255,0.4)
    static let divider = UIColor.white.withAlphaComponent(0.4)
    /// 强调紫（沿用 App 既有 #8054FE，蓝湖里同一枚强调色，如 tabbar 选中态指示条）
    static let accentPurple = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1)
    /// 可点击数值/选项文字的默认强调蓝 rgba(151,178,246,1)（执行周期/入睡提醒/助眠方案/闹钟方案数值统一用这个色）
    static let valueBlue = UIColor(red: 151/255, green: 178/255, blue: 246/255, alpha: 1)
    /// 入睡（月亮）端点色 rgba(102,117,242,1)
    static let sleepBlue = UIColor(red: 102/255, green: 117/255, blue: 242/255, alpha: 1)
    /// 起床（太阳）端点色 rgba(242,182,106,1)
    static let wakeOrange = UIColor(red: 242/255, green: 182/255, blue: 106/255, alpha: 1)
    /// 色带中间过渡色 rgba(160,125,202,1)，270deg 渐变的 63.744792% 位置
    static let bandMid = UIColor(red: 160/255, green: 125/255, blue: 202/255, alpha: 1)
    /// 禁用态按钮背景 rgba(70,70,70,1)
    static let disabledButtonBackground = UIColor(red: 70/255, green: 70/255, blue: 70/255, alpha: 1)
    /// 弹窗正文文字 rgba(205,205,205,1)
    static let dialogMessage = UIColor(red: 205/255, green: 205/255, blue: 205/255, alpha: 1)
    /// 弹窗遮罩 rgba(0,0,0,0.6)
    static let dialogOverlay = UIColor.black.withAlphaComponent(0.6)
    /// 二级/次要文字（说明性文字，浅灰白）
    static let secondaryText = UIColor.white.withAlphaComponent(0.6)
    /// 官方预设详情页「高级会员」角标文字色 rgba(172,143,255,1)
    static let premiumTagText = UIColor(red: 172/255, green: 143/255, blue: 255/255, alpha: 1)
    /// 官方预设详情页「睡眠训练」胶囊标签渐变：314deg，rgba(173,110,223,1) → rgba(166,118,255,1)
    static let trainingBadgeGradientColors: [CGColor] = [
        UIColor(red: 173/255, green: 110/255, blue: 223/255, alpha: 1).cgColor,
        UIColor(red: 166/255, green: 118/255, blue: 255/255, alpha: 1).cgColor
    ]

    // MARK: - 圆角 / 间距（design px / 2 = pt）

    /// 卡片圆角 36px → 18pt
    static let cardCornerRadius: CGFloat = 18
    /// 弹窗卡片圆角 36px → 18pt
    static let dialogCornerRadius: CGFloat = 18
    /// 按钮胶囊圆角 60px → 30pt（弹窗按钮）/ 48px → 24pt（保存设置按钮）
    // CSS 的 border-radius 48px/60px 都大于按钮高度的一半，浏览器会自动收敛成胶囊；
    // CALayer 不收敛，圆角超过高度一半会让两端圆弧交叠、渲染成梭形。这里直接按「高度的一半」
    // 取值（弹窗按钮 40pt 高 → 20pt；主按钮同为 40pt 高 → 20pt），效果与设计稿的胶囊一致。
    static let dialogButtonCornerRadius: CGFloat = 20
    static let primaryButtonCornerRadius: CGFloat = 20

    // MARK: - 字号（design px / 2 = pt）

    static let fontSizePlanName: CGFloat = 24        // 48px
    static let fontSizeCardTitle: CGFloat = 18        // 36px（睡眠目标/计划选项/弹窗标题）
    static let fontSizeOptionTitle: CGFloat = 14      // 28px（执行周期/入睡提醒等行标题）
    static let fontSizeOptionValue: CGFloat = 12      // 24px（行右侧数值/弹窗按钮文字）
    static let fontSizeDialogMessage: CGFloat = 11    // 22px
    static let fontSizeHint: CGFloat = 10             // 20px（说明性文字/入睡时间数字说明）
    static let fontSizeTick: CGFloat = 9              // 18px（刻度数字）

    // MARK: - 字体（PingFangSC 替代 SourceHanSansCN，见文件头说明）

    static func fontMedium(_ size: CGFloat) -> UIFont {
        UIFont(name: "PingFangSC-Medium", size: size) ?? .boldSystemFont(ofSize: size)
    }
    static func fontRegular(_ size: CGFloat) -> UIFont {
        UIFont(name: "PingFangSC-Regular", size: size) ?? .systemFont(ofSize: size)
    }
    static func fontLight(_ size: CGFloat) -> UIFont {
        UIFont(name: "PingFangSC-Light", size: size) ?? .systemFont(ofSize: size, weight: .light)
    }

    /// 按 CSS `line-height` 设置多行文本行高（设计稿 line-height 普遍 1.5 倍，系统默认约 1.19 倍，
    /// 不设的话多行段落会明显比设计稿紧）。
    static func applyLineHeight(_ lineHeight: CGFloat, to label: UILabel) {
        guard let text = label.text, let font = label.font else { return }
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        style.alignment = label.textAlignment
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: label.textColor ?? UIColor.white,
            .paragraphStyle: style,
            .baselineOffset: (lineHeight - font.lineHeight) / 4
        ])
    }

    // MARK: - 渐变色带（.group_34：linear-gradient(270deg, #F2B66A 0%, #A07DCA 63.744792%, #6675F2 100%)）
    // CSS 270deg 指向左：0% 落在渲染框右端(橙)、100% 落在左端(蓝)。
    // 换算成"从早到晚、左到右"的自然时间顺序（左=入睡/蓝，右=起床/橙）：
    // location = 1 - CSS百分比，故左端(0)=蓝、0.3626=中间紫、右端(1)=橙。
    static let bandGradientColorsLTR: [CGColor] = [sleepBlue.cgColor, bandMid.cgColor, wakeOrange.cgColor]
    static let bandGradientLocationsLTR: [NSNumber] = [0.0, 0.3626, 1.0]
}
