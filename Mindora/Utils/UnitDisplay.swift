//
//  UnitDisplay.swift
//  mindora
//
//  面向用户展示的数值+单位格式化（时长、心率、呼吸频率、体温、体重/身高、记录天数）。
//
//  格式串全部走本地化 key（unit.*）：英文按设计校对表写成 `8 hr 12 min` / `80 bpm` /
//  `20 breaths/min` / `6 of 7`，其他语言保留原来的紧凑写法。
//  体温、体重、身高：英文界面按设计稿用英制（°F、lb、ft/in），其他语言仍是公制；
//  数据本身始终按 °C / kg / cm 存取。
//

import Foundation

enum UnitDisplay {

    // MARK: - 时长

    /// 总分钟数 → `8 hr 12 min` / `45 min` / `5 hr`。不足 1 小时只显示分钟，整点不带「0 min」。
    static func duration(minutes totalMinutes: Int) -> String {
        let total = max(0, totalMinutes)
        let h = total / 60
        let m = total % 60
        if h == 0 { return String(format: L("unit.duration.min"), m) }
        if m == 0 { return String(format: L("unit.duration.hr"), h) }
        return String(format: L("unit.duration.hr_min"), h, m)
    }

    /// 小时（可带小数）→ 先化成分钟再四舍五入，避免「1 hr 60 min」。
    static func duration(hours: Double) -> String {
        duration(minutes: Int((hours * 60.0).rounded()))
    }

    /// 紧凑时长，用于首页指标圆圈（固定字号、宽度有限）：`8h 20m` / `45 min`。
    static func compactDuration(hours: Double) -> String {
        let total = max(0, Int((hours * 60.0).rounded()))
        let h = total / 60
        let m = total % 60
        if h == 0 { return String(format: L("unit.duration.min"), m) }
        if m == 0 { return String(format: L("unit.duration.compact.hr"), h) }
        return String(format: L("unit.duration.compact.hr_min"), h, m)
    }

    /// 纯分钟（不进位成小时），如入睡用时 `12 min`。
    static func minutes(_ minutes: Int) -> String {
        String(format: L("unit.duration.min"), minutes)
    }

    /// 不足 1 分钟（几乎沾枕就睡）。
    static var underOneMinute: String { L("unit.duration.under_1_min") }

    // MARK: - 生命体征

    static func bpm(_ value: Double) -> String {
        String(format: L("unit.bpm"), Int(value.rounded()))
    }

    static func bpmRange(min: Double, max: Double) -> String {
        String(format: L("unit.bpm_range"), Int(min.rounded()), Int(max.rounded()))
    }

    static func breathsPerMinute(_ value: Double) -> String {
        String(format: L("unit.breaths_per_min"), Int(value.rounded()))
    }

    /// 体温（入参恒为摄氏度）。英文界面显示华氏度。
    static func temperature(celsius: Double) -> String {
        if usesFahrenheit {
            return String(format: "%.1f°F", celsius * 9.0 / 5.0 + 32.0)
        }
        return String(format: "%.1f°C", celsius)
    }

    private static var usesFahrenheit: Bool { usesImperial }

    // MARK: - 体重 / 身高

    /// 英文界面按设计校对表用英制（lb、ft/in），其他语言仍是 kg/cm；数据始终按 kg/cm 存取。
    static var usesImperial: Bool {
        LocalizationManager.shared.currentLanguage == .english
    }

    static let poundsPerKilogram = 2.20462
    static let centimetersPerInch = 2.54

    static func pounds(kilograms: Double) -> Int { Int((kilograms * poundsPerKilogram).rounded()) }

    /// 厘米 → (英尺, 英寸)，按总英寸四舍五入后再拆，避免出现「5 ft 12 in」。
    static func feetInches(centimeters: Double) -> (feet: Int, inches: Int) {
        let total = Int((centimeters / centimetersPerInch).rounded())
        return (total / 12, total % 12)
    }

    /// 个人资料里的体重，入参为 kg 数字串：`165 lb` / `75kg`。
    static func weight(kilogramsText: String) -> String {
        guard usesImperial, let kg = Double(kilogramsText) else { return "\(kilogramsText)kg" }
        return "\(pounds(kilograms: kg)) lb"
    }

    /// 个人资料里的身高，入参为 cm 数字串：`5 ft 9 in` / `175cm`。
    static func height(centimetersText: String) -> String {
        guard usesImperial, let cm = Double(centimetersText) else { return "\(centimetersText)cm" }
        let (ft, inch) = feetInches(centimeters: cm)
        return "\(ft) ft \(inch) in"
    }

    // MARK: - 其他

    /// 记录天数，如 `6 of 7`。
    static func daysTracked(_ tracked: Int, of total: Int) -> String {
        String(format: L("unit.days_tracked"), tracked, total)
    }
}
