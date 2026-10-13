//
//  HealthChartWindow.swift
//  mindora
//
//  周/月图表的**时间窗口**。全 App 只此一套定义，不允许各页面自己算。
//
//  ## 规则（对齐苹果健康）
//
//  窗口右端永远是**最后有数据的那一天**（锚点），从它往回推一周 / 一个自然月：
//
//  | | 定义 | 锚点 = 9/5 时 | 格子数 |
//  | --- | --- | --- | --- |
//  | 周 | (锚点 − 1 周, 锚点] | 8/30 – 9/5 | 7 |
//  | 月 | (锚点 − 1 月, 锚点] | 8/6 – 9/5 | 31 |
//
//  月的格子数**随自然月长度 28~31 变**，不是定值 30 ——「一个月」是日历运算，
//  不是「30 天」。2 月的月视图只有 28 格。
//
//  ## 为什么不吸附自然周
//
//  吸附自然周（无论周一还是 locale 的 `firstWeekday`）会在右侧留出没有数据的空格子：
//  锚点落在周三时，窗口画到本周日，页头终点跟着写成一个还没有数据的日期。
//  滚动窗口右端永远贴着锚点，于是恒有：
//
//      页头终点 == 最后一根柱子 == 最后有数据的一天
//
//  也因此 `firstWeekday` 在这里完全不相干 —— 不吸附日历，就没有「周几开头」的问题。
//
//  ## 用法约定
//
//  取数、缓存 key、页头文案、柱子、横坐标**必须全部从同一个 Window 推导**。
//  叶子视图（图表）不许自己调 `Date()` 算日期：页头按锚点算、图表按今天算，
//  两个基准一漂移，柱子就被标上错误甚至未来的日期 —— 这个 bug 真实发生过
//  （今天 9/9、锚点 9/5 时，月图整排日期偏 4 天，周图气泡标出 9/12、9/13）。
//

import Foundation

struct HealthChartWindow {

    /// 窗口第一天（含）。
    let start: Date

    /// 窗口最后一天（含）＝锚点＝最后有数据的那一天。
    let end: Date

    /// 窗口内天数。周恒为 7；月随自然月长度 28~31。
    var dayCount: Int {
        (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    /// 窗口内每一天，start → end。柱子、横坐标、气泡日期都按它铺，一一对应。
    var days: [Date] {
        let calendar = Calendar.current
        return (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// 页头区间文案。区间的两端就是首尾两根柱子的日期，不做任何偏移。
    var displayText: String { DateDisplay.dateRange(from: start, to: end) }

    /// (锚点 − 1 周, 锚点]，共 7 天。
    static func week(anchor: Date) -> HealthChartWindow {
        make(anchor: anchor, unit: .weekOfYear)
    }

    /// (锚点 − 1 月, 锚点]，天数随自然月长度变。
    static func month(anchor: Date) -> HealthChartWindow {
        make(anchor: anchor, unit: .month)
    }

    /// 半开区间 (end − 1 单位, end]：往回推一个单位后**再进一天**。
    /// 少了这一天就变成闭区间，9/5 往回一个月会得到 8/5…9/5 共 32 天 —— 多出一格，
    /// 且首尾同为 5 号，看着像「一个月」其实不是。
    private static func make(anchor: Date, unit: Calendar.Component) -> HealthChartWindow {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: anchor)
        let exclusiveStart = calendar.date(byAdding: unit, value: -1, to: end) ?? end
        let start = calendar.date(byAdding: .day, value: 1, to: exclusiveStart) ?? end
        return HealthChartWindow(start: start, end: end)
    }
}
