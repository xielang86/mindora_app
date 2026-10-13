//
//  FootprintTracker.swift
//  mindora
//
//  陪伴足迹的本地采集与上报（对齐 Tools/doc/陪伴足迹接口.md 的 upload_footprint）：
//  - App 活跃：App 变 active 即记当天 1 次（app_open_count 累加、first_active_at 首次记录）。
//  - 助眠陪伴：前台会话期间已绑设备「可达且未被用户断开」→ 记当天助眠陪伴，
//    companion_minutes 累加该会话时长（进入后台时结算）。
//  - 完成睡眠计划：预留 recordPlanCompleted() 入口，睡眠计划功能接入后调用。
//  按自然日聚合，App 变 active / 进后台时批量补传；服务端按 date 幂等合并，
//  今天的记录允许重复上报（数据只增不减），昨天及更早成功后标记 final 不再传。
//
//  存储为账号级缓存：登出 / 注销时由 CompanionFootprintService.clearCache() 一并清除。
//

import UIKit

final class FootprintTracker {

    static let shared = FootprintTracker()
    private init() {}

    private let logTag = "FootprintTracker"
    private let defaults = UserDefaults.standard
    static let storeKey = "footprint.tracker.days.v1"

    /// 单日聚合记录（direct Codable → UserDefaults）。
    private struct DayRecord: Codable {
        var appActive = false
        var sleepCompanion = false
        var planCompleted = false
        var appOpenCount = 0
        var companionMinutes = 0
        var firstActiveAt: Int?
        /// 已成功上传且日期已过（不会再变化），后续不再重复上报。
        var final = false
    }

    /// 前台会话起点 + 会话内是否见过可达设备。
    private var sessionStart: Date?
    private var sessionSawDevice = false
    private var uploading = false
    /// 上报失败退避（30s 起翻倍，封顶 30 分钟）。
    private var backoff = NetworkBackoff()

    // MARK: - 生命周期事件（SceneDelegate 调用）

    /// App 变 active（冷启动 / 回前台）。
    func handleAppBecameActive() {
        let key = Self.dayKey(Date())
        var days = loadDays()
        var rec = days[key] ?? DayRecord()
        rec.appActive = true
        rec.appOpenCount += 1
        if rec.firstActiveAt == nil { rec.firstActiveAt = Int(Date().timeIntervalSince1970) }
        days[key] = rec
        saveDays(days)

        sessionStart = Date()
        sessionSawDevice = boundDeviceReachable()
        // 会话中设备上线也算：监听 discovery 更新。
        NotificationCenter.default.addObserver(self, selector: #selector(handleDiscoveryUpdate),
                                               name: UnifiedDeviceDiscovery.didUpdateNotification, object: nil)
        // 回前台是大批设备同时触发的时刻；足迹是纯后台上报，随机错峰几秒再发。
        NetworkPacing.afterSpread(upTo: 30) { [weak self] in self?.flush() }
    }

    /// App 进后台：结算本次前台会话的助眠陪伴时长，并尝试补传。
    func handleAppEnteredBackground() {
        NotificationCenter.default.removeObserver(self, name: UnifiedDeviceDiscovery.didUpdateNotification, object: nil)
        defer { sessionStart = nil; sessionSawDevice = false }
        guard let start = sessionStart else { return }
        if !sessionSawDevice { sessionSawDevice = boundDeviceReachable() }   // 末次采样
        guard sessionSawDevice else { flush(); return }

        let minutes = Int(Date().timeIntervalSince(start) / 60)
        let key = Self.dayKey(Date())
        var days = loadDays()
        var rec = days[key] ?? DayRecord()
        rec.sleepCompanion = true
        rec.companionMinutes += max(0, minutes)
        days[key] = rec
        saveDays(days)
        flush()
    }

    /// 睡眠计划节点完成时调用（预留；当前无调用方）。
    func recordPlanCompleted(on date: Date = Date()) {
        let key = Self.dayKey(date)
        var days = loadDays()
        var rec = days[key] ?? DayRecord()
        rec.planCompleted = true
        days[key] = rec
        saveDays(days)
        flush()
    }

    @objc private func handleDiscoveryUpdate() {
        if !sessionSawDevice, boundDeviceReachable() { sessionSawDevice = true }
    }

    // MARK: - 上报

    /// 把所有未 final 的日记录批量上传；成功后将「今天之前」的标记 final 并裁剪历史。
    private func flush() {
        guard !uploading else { return }
        guard !backoff.isBlocked else {
            Log.info(logTag, "flush 跳过：处于失败退避期（还剩 \(backoff.remainingSeconds)s）")
            return
        }
        let todayKey = Self.dayKey(Date())
        let days = loadDays()
        let pending = days.filter { !$0.value.final }
        guard !pending.isEmpty else { return }

        let payload: [[String: Any]] = pending
            .sorted { $0.key < $1.key }
            .map { key, rec in
                var d: [String: Any] = [
                    "date": key,
                    "app_active": rec.appActive,
                    "sleep_companion": rec.sleepCompanion,
                    "plan_completed": rec.planCompleted,
                    "app_open_count": rec.appOpenCount,
                    "companion_minutes": rec.companionMinutes
                ]
                if let t = rec.firstActiveAt { d["first_active_at"] = t }
                return d
            }

        uploading = true
        CompanionFootprintService.shared.uploadDays(payload) { [weak self] ok in
            guard let self else { return }
            self.uploading = false
            guard ok else {
                // 「未登录 / mock 模式」在 uploadDays 里也返回 false，但那不是服务端故障，
                // 不能计入退避 —— 否则登录后第一次上报会被自己造出来的退避挡最多 30 分钟。
                // 这跟设备推送那个「前置条件没就绪被当成结果」的坑是同一类，务必分清。
                guard AuthStorage.shared.token?.isEmpty == false else {
                    Log.info(self.logTag, "上报跳过：未登录（不计入退避）")
                    return
                }
                // 真失败才退避，避免服务端故障时每次前后台切换都重试。
                self.backoff.recordFailure()
                Log.info(self.logTag, "上报失败，退避 \(self.backoff.remainingSeconds)s 后再试")
                return
            }
            self.backoff.recordSuccess()
            var days = self.loadDays()
            for (key, var rec) in days where !rec.final && key < todayKey {
                rec.final = true
                days[key] = rec
            }
            // 裁剪：只保留最近 30 天，防无限增长。
            if days.count > 30 {
                let keep = Set(days.keys.sorted().suffix(30))
                days = days.filter { keep.contains($0.key) }
            }
            self.saveDays(days)
            Log.info(self.logTag, "uploaded \(payload.count) day(s)")
        }
    }

    // MARK: - 设备可达性

    /// 已绑设备中，存在「discovery 当前可达且未被用户主动断开」的 → 视为设备与 App 同时使用。
    private func boundDeviceReachable() -> Bool {
        let reachableIDs = Set(UnifiedDeviceDiscovery.shared.devices.compactMap { $0.deviceID })
        guard !reachableIDs.isEmpty else { return false }
        return DeviceSession.shared.entries.contains { entry in
            guard let id = entry.deviceID, reachableIDs.contains(id) else { return false }
            return !(entry.isUserDisconnected ?? false)
        }
    }

    // MARK: - 存取

    private func loadDays() -> [String: DayRecord] {
        guard let data = defaults.data(forKey: Self.storeKey),
              let decoded = try? JSONDecoder().decode([String: DayRecord].self, from: data) else { return [:] }
        return decoded
    }

    private func saveDays(_ days: [String: DayRecord]) {
        if let data = try? JSONEncoder().encode(days) {
            defaults.set(data, forKey: Self.storeKey)
        }
    }

    /// 自然日 key（yyyy-MM-dd，当前时区 —— 与请求 data.timezone 一致）。
    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        // 存储/协议格式必须钉死 POSIX：跟系统 locale 走的话，佛历(泰)、和历(日)用户会
        // 格式化出 "2569-08-06" 这种 key，跟服务端和历史数据全对不上。
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: date)
    }
}
