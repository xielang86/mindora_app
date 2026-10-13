//
//  SleepReminderScheduler.swift
//  mindora
//
//  「入睡提醒」真实本地通知调度。
//
//  与 AppNotificationEngine（站内消息，只落库不触系统通知）不同，这里调度的是真正的
//  UNNotificationRequest —— 到点系统会弹出通知。
//
//  去重策略：每个计划每个周几一个稳定 identifier（"sleepPlan.<planId>.<weekday>"）。
//  每次重新调度前先撤销该计划名下的全部旧请求再重排，天然幂等，不会因为反复保存/编辑
//  堆积出重复通知；也不需要额外的冷却簿记 —— UNCalendarNotificationTrigger(repeats: true)
//  本身按「每周固定周几」触发，一天只会响一次。
//

import Foundation
import UserNotifications

final class SleepReminderScheduler {
    static let shared = SleepReminderScheduler()

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "sleepPlan."

    private init() {}

    /// 计划保存/开启/修改提醒设置后调用：先清掉该计划的旧请求，再按最新配置重新排。
    func reschedule(plan: SleepPlan) {
        cancelReminders(planId: plan.id) { [weak self] in
            guard let self else { return }
            guard plan.status == .active, plan.reminderEnabled else { return }

            // 提前量跨过 0 点时（如 00:20 入睡提前 30 分钟 = 前一天 23:50），
            // 不只是时刻要归一，**周几也要往前挪一天**，否则会排到当天 23:50，晚了整整一轮。
            let raw = plan.sleepTime - plan.reminderMinutesBefore
            let reminderMoment = Self.minutesInDay(raw)
            let dayOffset = raw < 0 ? -1 : 0
            let hour = reminderMoment / 60
            let minute = reminderMoment % 60

            PermissionManager.shared.requestNotificationPermission { [weak self] status in
                guard let self, status == .authorized else { return }

                // 关闭「每周重复」= 只执行所选日期一轮：按具体日期排**不重复**的通知，
                // 而不是按星期无限循环（早期实现一律 repeats:true，等于这个开关根本不起作用）。
                if case .weekdays(_, let repeatsWeekly) = plan.cycle, !repeatsWeekly {
                    let anchor = plan.activatedAt ?? Date()
                    let calendar = Calendar.current
                    for sleepDay in plan.cycle.roundSleepDays(anchor: anchor, calendar: calendar) {
                        // 提前量跨 0 点时，提醒落在入睡日的前一天。
                        guard let remindDay = calendar.date(byAdding: .day, value: dayOffset, to: sleepDay) else { continue }
                        var comps = calendar.dateComponents([.year, .month, .day], from: remindDay)
                        comps.hour = hour
                        comps.minute = minute
                        guard let moment = calendar.date(from: comps), moment > Date() else { continue }
                        self.scheduleOnce(planId: plan.id, planName: plan.displayName,
                                           dateComponents: comps, key: Self.dayKey(remindDay, calendar: calendar))
                    }
                    return
                }

                for weekday in plan.cycle.scheduledWeekdays {
                    let shifted = ((weekday - 1 + dayOffset) % 7 + 7) % 7 + 1
                    self.scheduleOne(planId: plan.id, planName: plan.displayName,
                                      weekday: shifted, hour: hour, minute: minute)
                }
            }
        }
    }

    /// 计划停用/删除/关闭提醒时调用：撤销该计划名下全部已排请求。
    func cancelReminders(planId: UUID, completion: (() -> Void)? = nil) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { completion?(); return }
            let prefix = self.identifierPrefix + planId.uuidString + "."
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
            DispatchQueue.main.async { completion?() }
        }
    }

    // MARK: - Private

    private func scheduleOne(planId: UUID, planName: String, weekday: Int, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = L("sleepplan.reminder.notification_title")
        content.body = String(format: L("sleepplan.reminder.notification_body"), planName)
        content.sound = .default

        var dateComponents = DateComponents()
        // Foundation Calendar.weekday: 1=周日...7=周六；我们的 weekday: 1=周一...7=周日，需转换。
        dateComponents.weekday = weekday == 7 ? 1 : weekday + 1
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = identifierPrefix + planId.uuidString + "." + String(weekday)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    /// 「只执行一轮」用的单次通知：按具体年月日排，`repeats: false`，响过即失效。
    private func scheduleOnce(planId: UUID, planName: String, dateComponents: DateComponents, key: String) {
        let content = UNMutableNotificationContent()
        content.title = L("sleepplan.reminder.notification_title")
        content.body = String(format: L("sleepplan.reminder.notification_body"), planName)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let identifier = identifierPrefix + planId.uuidString + "." + key
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 归一到 0...1439，处理提前提醒跨过前一天 0 点的情况（如 00:20 入睡提前 30 分钟 = 前一天 23:50）。
    private static func minutesInDay(_ minutes: Int) -> Int {
        let m = minutes % 1440
        return m < 0 ? m + 1440 : m
    }
}
