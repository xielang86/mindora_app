//
//  DateDisplay.swift
//  mindora
//
//  面向用户展示的日期/时间格式化。全 App 只此一套，不允许各页面自己拼。
//
//  ## 为什么不能写死 dateFormat
//
//  `formatter.dateFormat = "d MMM yyyy"` 是**固定模板**：换 locale 只会换月份的语言，
//  **不会重排顺序**。中文下于是得到「9 9月 2026」这种日-月-年的英式语序，
//  而中文习惯是年-月-日。反过来，把「\(year)年\(month)月\(day)日」硬拼进代码，
//  英文/日文用户就会看到中文格式。两个方向都出现过。
//
//  正确做法是给出**模板**（骨架），由 `setLocalizedDateFormatFromTemplate` 按当前
//  locale 重排：
//
//  | 模板 | en_US | zh-Hans | ja |
//  | --- | --- | --- | --- |
//  | `yMMMd` | Sep 9, 2026 | 2026年9月9日 | 2026年9月9日 |
//  | `MMMd` | Sep 9 | 9月9日 | 9月9日 |
//  | `yMMM` | Sep 2026 | 2026年9月 | 2026年9月 |
//  | `jm` | 9:41 PM | 21:41 | 21:41 |
//
//  `j` 是「locale 自己的时制」，还会跟随系统「24 小时制」开关 —— 写死 `h:mm a`
//  会让所有语言都变成 12 小时制。
//
//  日期**区间**用 `DateIntervalFormatter`：它按 locale 省略公共部分，
//  en 得到 `Sep 7 – 13, 2026`，中文得到 `2026年9月7日至13日`，自己拼做不到这个。
//
//  ## 语言切换
//
//  formatter 按 (locale, 模板) 缓存。切语言后 `currentLocale` 变化 → 命中新的
//  缓存键，无需手动失效。
//

import Foundation

enum DateDisplay {

    private static let lock = NSLock()
    private static var formatters: [String: DateFormatter] = [:]
    private static var intervalFormatters: [String: DateIntervalFormatter] = [:]

    private static func formatter(template: String) -> DateFormatter {
        let locale = LocalizationManager.shared.currentLocale
        let key = "\(locale.identifier)|\(template)"
        lock.lock(); defer { lock.unlock() }
        if let cached = formatters[key] { return cached }
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate(template)
        formatters[key] = f
        return f
    }

    // MARK: - 单个日期 / 时间

    /// 年月日，如 `Sep 9, 2026` / `2026年9月9日`。
    static func date(_ date: Date) -> String { formatter(template: "yMMMd").string(from: date) }

    /// 月日，如 `Sep 9` / `9月9日`。用于同年内已知年份的场合。
    static func monthDay(_ date: Date) -> String { formatter(template: "MMMd").string(from: date) }

    /// 年月，如 `Sep 2026` / `2026年9月`。
    static func yearMonth(_ date: Date) -> String { formatter(template: "yMMM").string(from: date) }

    /// 年，如 `2026` / `2026年`。
    static func year(_ date: Date) -> String { formatter(template: "y").string(from: date) }

    /// 日，如 `9` / `9日`。仅用于区间起点这类已有上下文的场合。
    static func day(_ date: Date) -> String { formatter(template: "d").string(from: date) }

    /// 时刻，如 `9:41 PM` / `21:41`。12/24 制跟随 locale 与系统设置。
    static func time(_ date: Date) -> String { formatter(template: "jm").string(from: date) }

    /// 一天中的分钟数（0..<1440）→ 时刻，如 `10:00 PM` / `22:00`。用于睡眠计划的入睡/起床时间。
    static func clock(minutesOfDay: Int) -> String {
        var comps = DateComponents()
        comps.year = 2000; comps.month = 1; comps.day = 1
        comps.hour = (minutesOfDay / 60) % 24
        comps.minute = minutesOfDay % 60
        guard let date = Calendar(identifier: .gregorian).date(from: comps) else {
            return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
        }
        return time(date)
    }

    /// 带星期的年月日，如 `Thu, Jul 23, 2026` / `2026年7月23日 周四`。
    static func dateWithWeekday(_ date: Date) -> String { formatter(template: "yMMMdEEE").string(from: date) }

    /// 年 + 完整月名，如 `July 2026` / `2026年7月`。
    static func yearMonthFull(_ date: Date) -> String { formatter(template: "yMMMM").string(from: date) }

    /// 月名缩写，如 `Jan` / `1月`。
    static func monthShort(_ date: Date) -> String { formatter(template: "MMM").string(from: date) }

    /// 完整月名，如 `January` / `1月`。
    static func monthName(_ date: Date) -> String { formatter(template: "MMMM").string(from: date) }

    /// 星期缩写，如 `Sat` / `周六` / `土`。用于图表横轴。
    /// 由**日期**算，不要用固定数组按索引取 —— 窗口是滚动的，第 0 格不恒是周一。
    static func weekdayShort(_ date: Date) -> String { formatter(template: "EEE").string(from: date) }

    // MARK: - 区间

    /// 用 `dateTemplate` 而不是 `dateStyle`：中文的 `.medium` 是数字式 `2026/9/7`，
    /// 与单个日期的 `2026年9月13日` 风格不一致；模板则两处一致。
    private static func intervalFormatter(template: String) -> DateIntervalFormatter {
        let locale = LocalizationManager.shared.currentLocale
        let key = "\(locale.identifier)|\(template)"
        lock.lock(); defer { lock.unlock() }
        if let cached = intervalFormatters[key] { return cached }
        let f = DateIntervalFormatter()
        f.locale = locale
        f.dateTemplate = template
        intervalFormatters[key] = f
        return f
    }

    /// 日期区间。公共部分由系统按 locale 省略，不要自己拼「起 - 止」：
    /// zh `2026年9月7日至13日` / en `Sep 7 – 13, 2026` / de `7.–13. Sept. 2026`。
    static func dateRange(from start: Date, to end: Date) -> String {
        intervalFormatter(template: "yMMMd").string(from: start, to: end)
    }

    /// 时刻区间：zh `21:41 – 22:05` / en `9:41 – 10:05 PM`。
    /// 用 `jm` 模板而不是 `timeStyle`：后者在跨天时会把日期一起带出来。
    static func timeRange(from start: Date, to end: Date) -> String {
        intervalFormatter(template: "jm").string(from: start, to: end)
    }
}
