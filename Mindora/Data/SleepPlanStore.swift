//
//  SleepPlanStore.swift
//  mindora
//
//  「睡眠计划」数据模型 + 本地持久化仓库。
//
//  与 AppNotificationStore 同一套路：内存数组 + UserDefaults(JSON) 落地 + NotificationCenter
//  广播刷新。入睡提醒由 SleepReminderScheduler 按 didChangeNotification 增量调度真实本地通知。
//
//  本地这份是**缓存 + 乐观更新**，不是事实源 —— 事实源在服务端（见 SleepPlanSyncService
//  与 Tools/doc/睡眠计划同步接口.md）。所以这里有两样东西不能少：
//    1. 墓碑（`SleepPlan.deleted`）：直接从数组里删掉的话，服务端下次同步会把它原样发回来。
//    2. 脏集合（`dirtyIDs`）：记住哪些改动还没上报，断网时照常本地生效、联网后补传。
//

import Foundation

// MARK: - 数据模型

/// 计划类型。官方三套预设的名称/周期/助眠方案固定，仅 custom 全字段可编辑（会员等级门禁见
/// SleepPlanViewController / SleepPlanEditorViewController）。
enum SleepPlanKind: String, Codable, CaseIterable, Equatable {
    case custom
    case habitFormation   // 睡眠习惯养成 · 21 天 · 每天
    case jetLag            // 时差矫正 · 7 天 · 每天
    case anxietyRelief     // 焦虑修复 · 14 天 · 每天

    /// 官方预设固定周期天数；自定义计划走 SleepPlanCycle.weekdays。
    var fixedCycleDays: Int? {
        switch self {
        case .custom: return nil
        case .habitFormation: return 21
        case .jetLag: return 7
        case .anxietyRelief: return 14
        }
    }

    var isOfficial: Bool { self != .custom }

    var nameKey: String {
        switch self {
        case .custom: return "sleepplan.kind.custom.default_name"
        case .habitFormation: return "sleepplan.kind.habit_formation.name"
        case .jetLag: return "sleepplan.kind.jet_lag.name"
        case .anxietyRelief: return "sleepplan.kind.anxiety_relief.name"
        }
    }

    var summaryKey: String {
        switch self {
        case .custom: return ""
        case .habitFormation: return "sleepplan.kind.habit_formation.summary"
        case .jetLag: return "sleepplan.kind.jet_lag.summary"
        case .anxietyRelief: return "sleepplan.kind.anxiety_relief.summary"
        }
    }

    var descriptionKey: String {
        switch self {
        case .custom: return ""
        case .habitFormation: return "sleepplan.kind.habit_formation.description"
        case .jetLag: return "sleepplan.kind.jet_lag.description"
        case .anxietyRelief: return "sleepplan.kind.anxiety_relief.description"
        }
    }
}

/// 执行周期。官方计划固定按天数每天执行；自定义计划按周几多选（至少 3 天连续）+ 是否每周重复。
enum SleepPlanCycle: Codable, Equatable {
    case fixedDaily(days: Int)
    /// weekdays: 1=周一...7=周日
    case weekdays(days: Set<Int>, repeatsWeekly: Bool)

    private enum CodingKeys: String, CodingKey { case type, days, repeatsWeekly }
    private enum Kind: String, Codable { case fixedDaily, weekdays }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .type)
        switch kind {
        case .fixedDaily:
            self = .fixedDaily(days: try c.decode(Int.self, forKey: .days))
        case .weekdays:
            let days = try c.decode(Set<Int>.self, forKey: .days)
            let repeats = try c.decode(Bool.self, forKey: .repeatsWeekly)
            self = .weekdays(days: days, repeatsWeekly: repeats)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .fixedDaily(let days):
            try c.encode(Kind.fixedDaily, forKey: .type)
            try c.encode(days, forKey: .days)
        case .weekdays(let days, let repeatsWeekly):
            try c.encode(Kind.weekdays, forKey: .type)
            try c.encode(days, forKey: .days)
            try c.encode(repeatsWeekly, forKey: .repeatsWeekly)
        }
    }

    /// 展开为本轮需要调度提醒的周几集合（1=周一...7=周日）。
    var scheduledWeekdays: Set<Int> {
        switch self {
        case .fixedDaily: return Set(1...7)
        case .weekdays(let days, _): return days
        }
    }

    /// 关闭「每周重复」时，这一轮实际会执行的入睡日（从 `anchor` 起 7 天窗口内，
    /// 每个所选星期各出现一次）。调度提醒与「跑完自动收尾」共用这份推导，避免两处算法走偏。
    func roundSleepDays(anchor: Date, calendar: Calendar = .current) -> [Date] {
        let days = scheduledWeekdays
        guard !days.isEmpty else { return [] }
        let startOfAnchor = calendar.startOfDay(for: anchor)
        var result: [Date] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfAnchor) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            // Foundation 的 weekday 是 1=周日…7=周六，这里用的是 1=周一…7=周日。
            let normalized = weekday == 1 ? 7 : weekday - 1
            if days.contains(normalized) { result.append(day) }
        }
        return result
    }

    /// 自定义计划的连续性校验：所选星期须形成至少 3 天连续（周六/周日/周一按实际日期视为连续）。
    static func hasConsecutiveRun(_ days: Set<Int>, minLength: Int = 3) -> Bool {
        guard days.count >= minLength else { return false }
        // 把 1...7 复制一份接到末尾（7+1...7+7）以处理跨周边界（周六=6,周日=7,周一=1→8）。
        let extended = days.union(Set(days.map { $0 + 7 }))
        var run = 0
        for d in 1...14 {
            if extended.contains(d) {
                run += 1
                if run >= minLength { return true }
            } else {
                run = 0
            }
        }
        return false
    }
}

/// 计划状态。列表排序 & 「今晚已开始不可关闭」判断都靠它。
/// ⚠️ 这些 rawValue 已落在用户本地 UserDefaults 里，**不能改**。服务端协议用的是下划线形式
/// （`not_enabled` 等），两者的映射见《睡眠计划同步接口》§5「枚举取值映射」，同步层必须显式转换，
/// 不要直接把本模型 encode 上传。`SleepPlanKind` / `SleepPlanCycle.Kind` 同理。
enum SleepPlanStatus: String, Codable, Equatable {
    case notEnabled   // 已保存，未开启
    case active       // 当前开启执行中
    case completed    // 周期跑满（官方固定天数 / 自定义关闭「每周重复」跑完一轮）
    /// 保留值：客户端**不再产生**这个状态（切换计划时被顶下来的计划回到 notEnabled，见 enable(_:)）。
    /// 仅为兼容历史本地数据与服务端可能下发的值而保留。
    case stopped
}

struct SleepPlan: Codable, Identifiable, Equatable {
    var id: UUID
    var kind: SleepPlanKind
    /// 官方计划：忽略此字段，展示用 kind.nameKey；自定义计划：用户可编辑名称，≤10 字符。
    var customName: String
    var targetMinutes: Int          // 目标睡眠时长（分钟），>= 60
    var sleepTime: Int              // 入睡时间，0...1439（当天分钟数）
    var wakeTime: Int               // 起床时间，0...1439；早于 sleepTime 视为次日
    var cycle: SleepPlanCycle
    var reminderEnabled: Bool
    var reminderMinutesBefore: Int  // 15 / 30 / 60 / 90
    var alarmSoundId: String
    var sleepAidCategory: String    // "smart" / "preference" / "trending"
    var sleepAidItemId: String
    var status: SleepPlanStatus
    var createdAt: Date
    var updatedAt: Date
    /// 计划本轮（开启时）起算日，用于「今晚已开始」判断 & 官方计划周期完成判断。
    var activatedAt: Date?

    /// 墓碑标记。删除**不再是**从数组里抹掉，而是打这个标记 —— 只有墓碑能把「A 设备删了某条」
    /// 同步到 B 设备（《睡眠计划同步接口》§1.3）。直接移除的话，下次同步时服务端仍会把它下发回来，
    /// 表现为「删了又自己长回来」。同步成功后由 SleepPlanSyncService 真正清理。
    var deleted: Bool
    var deletedAt: Date?
    /// 该计划最后一次保存时所在时区。**仅作审计，不参与执行**：触发时刻一律按最近一次同步上报的
    /// 设备当前时区换算（§6⑥ / §11①）。用户飞到别的时区，计划跟着新时区走。
    var timezone: String?

    init(id: UUID = UUID(), kind: SleepPlanKind, customName: String = "",
         targetMinutes: Int, sleepTime: Int, wakeTime: Int, cycle: SleepPlanCycle,
         reminderEnabled: Bool = false, reminderMinutesBefore: Int = 30,
         alarmSoundId: String = "sunlit_coast", sleepAidCategory: String = "smart",
         sleepAidItemId: String = "smart_recommend", status: SleepPlanStatus = .notEnabled,
         createdAt: Date = Date(), updatedAt: Date = Date(), activatedAt: Date? = nil,
         deleted: Bool = false, deletedAt: Date? = nil, timezone: String? = nil) {
        self.id = id
        self.kind = kind
        self.customName = customName
        self.targetMinutes = targetMinutes
        self.sleepTime = sleepTime
        self.wakeTime = wakeTime
        self.cycle = cycle
        self.reminderEnabled = reminderEnabled
        self.reminderMinutesBefore = reminderMinutesBefore
        self.alarmSoundId = alarmSoundId
        self.sleepAidCategory = sleepAidCategory
        self.sleepAidItemId = sleepAidItemId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.activatedAt = activatedAt
        self.deleted = deleted
        self.deletedAt = deletedAt
        self.timezone = timezone
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case id, kind, customName, targetMinutes, sleepTime, wakeTime, cycle
        case reminderEnabled, reminderMinutesBefore, alarmSoundId
        case sleepAidCategory, sleepAidItemId, status, createdAt, updatedAt, activatedAt
        case deleted, deletedAt, timezone
    }

    /// 手写解码只为一件事：新加的三个字段在**老用户的本地 JSON 里不存在**。
    /// `deleted` 是非可选 Bool，交给合成的 Codable 会因为缺键直接抛错 —— 而 `load()` 那边
    /// 是整个数组一起 decode 的，一条报错等于**老用户升级后计划全没了**。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(SleepPlanKind.self, forKey: .kind)
        customName = try c.decodeIfPresent(String.self, forKey: .customName) ?? ""
        targetMinutes = try c.decode(Int.self, forKey: .targetMinutes)
        sleepTime = try c.decode(Int.self, forKey: .sleepTime)
        wakeTime = try c.decode(Int.self, forKey: .wakeTime)
        cycle = try c.decode(SleepPlanCycle.self, forKey: .cycle)
        reminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderMinutesBefore = try c.decodeIfPresent(Int.self, forKey: .reminderMinutesBefore) ?? 30
        alarmSoundId = try c.decodeIfPresent(String.self, forKey: .alarmSoundId) ?? "sunlit_coast"
        sleepAidCategory = try c.decodeIfPresent(String.self, forKey: .sleepAidCategory) ?? "smart"
        sleepAidItemId = try c.decodeIfPresent(String.self, forKey: .sleepAidItemId) ?? "smart_recommend"
        status = try c.decode(SleepPlanStatus.self, forKey: .status)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        activatedAt = try c.decodeIfPresent(Date.self, forKey: .activatedAt)
        deleted = try c.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        timezone = try c.decodeIfPresent(String.self, forKey: .timezone)
    }

    /// 展示用名称：官方计划用固定本地化名，自定义用用户命名（为空则回退默认名）。
    var displayName: String {
        if kind.isOfficial { return L(kind.nameKey) }
        return customName.isEmpty ? L(kind.nameKey) : customName
    }

    /// 「今晚计划已开始」——当前时刻落在本轮入睡→起床的执行窗口内，禁止关闭/编辑/切换。
    ///
    /// 注意跨日：22:00→07:00 这种作息，凌晨 1 点仍在窗口内。早期实现只比较「今天的入睡时刻」，
    /// 过了 0 点就判成未开始，开关又能随便关了。
    func isLockedForTonight(now: Date = Date()) -> Bool {
        guard status == .active, let activatedAt, activatedAt <= now else { return false }
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if sleepTime <= wakeTime {
            return nowMinutes >= sleepTime && nowMinutes < wakeTime
        }
        return nowMinutes >= sleepTime || nowMinutes < wakeTime
    }
}

// MARK: - 会员等级配额

/// 睡眠计划的槽位配额：普通会员(basic) 1 条，高级会员(premium) 5 条；免费用户整页遮罩，不适用。
enum SleepPlanQuota {
    static func slots(for tier: MembershipTier) -> Int {
        switch tier {
        case .free: return 0
        case .basic: return 1
        case .premium: return 5
        }
    }

    /// 「睡眠计划已满」弹窗正文：普通会员写明只能 1 条（设计稿 睡眠计划 8），其余为通用上限文案。
    static func fullMessage(for tier: MembershipTier) -> String {
        L(tier == .basic ? "sleepplan.alert.plan_full.basic_message" : "sleepplan.alert.plan_full.message")
    }
}

// MARK: - 存储仓库

/// 睡眠计划的持久化仓库。全部在主线程访问。
final class SleepPlanStore {
    static let shared = SleepPlanStore()

    static let didChangeNotification = Notification.Name("SleepPlanStore.didChange")

    private let storeKey = "sleepplan.plans.v1"
    private let dirtyKey = "sleepplan.dirtyIDs.v1"
    private let lastSyncKey = "sleepplan.lastSyncAt.v1"
    private let pendingDropKey = "sleepplan.pendingDropIDs.v1"
    private let archiveKey = "sleepplan.archive.v1"
    private let defaults = UserDefaults.standard

    /// 全部本地记录，**含墓碑**。只有同步层该看到墓碑，界面一律走 `all`。
    private var records: [SleepPlan] = []

    /// 界面可见的计划（不含墓碑）。
    ///
    /// 之所以让 `all` 变成过滤后的计算属性、把原始数组降为私有 `records`：加墓碑之后，
    /// 任何一个忘记过滤的调用点都会把「已删除」的计划画到列表上、或者让它继续占额度。
    /// 与其在十几处各写一遍 `filter { !$0.deleted }`，不如让外部**根本拿不到**墓碑。
    var all: [SleepPlan] { records.filter { !$0.deleted } }

    /// 自上次同步成功以来有本地变更的计划 id（含墓碑）。同步层据此决定上报哪些。
    private var dirtyIDs: Set<UUID> = []

    /// 上次同步成功时服务端返回的 `server_time`，下次同步作为 `last_sync_at` 回传。
    var lastSyncAt: Int? {
        get { let v = defaults.integer(forKey: lastSyncKey); return v > 0 ? v : nil }
        set {
            if let newValue { defaults.set(newValue, forKey: lastSyncKey) }
            else { defaults.removeObject(forKey: lastSyncKey) }
        }
    }

    private init() {
        load()
    }

    private func load() {
        if let data = defaults.data(forKey: storeKey),
           let decoded = try? JSONDecoder().decode([SleepPlan].self, from: data) {
            records = decoded
        } else {
            records = []
        }
        if let raw = defaults.array(forKey: dirtyKey) as? [String] {
            dirtyIDs = Set(raw.compactMap { UUID(uuidString: $0) })
        }
        if let raw = defaults.array(forKey: pendingDropKey) as? [String] {
            pendingDropIDs = Set(raw.compactMap { UUID(uuidString: $0) })
        }
        refreshCompletionStates()
    }

    // MARK: - 变更追踪

    private func markDirty(_ id: UUID) {
        dirtyIDs.insert(id)
        defaults.set(dirtyIDs.map { $0.uuidString }, forKey: dirtyKey)
    }

    /// 待上报的变更（含墓碑）。
    func pendingChanges() -> [SleepPlan] {
        records.filter { dirtyIDs.contains($0.id) }
    }

    // MARK: - 服务端删除的两次确认 & 存档

    /// 上一轮同步中「服务端全量里缺失」的计划 id。见 applyServerPlans 里的两次确认规则。
    private var pendingDropIDs: Set<UUID> = []

    private func savePendingDrops() {
        if pendingDropIDs.isEmpty {
            defaults.removeObject(forKey: pendingDropKey)
        } else {
            defaults.set(pendingDropIDs.map { $0.uuidString }, forKey: pendingDropKey)
        }
    }

    private static func brief(_ ids: Set<UUID>) -> String {
        ids.map { String($0.uuidString.prefix(8)) }.sorted().joined(separator: ",")
    }

    /// 被服务端删掉的计划的存档。**只增不减**（按 plan_id 去重），上限 20 条。
    ///
    /// 存在的意义只有一个：服务端出错把用户计划删光时，数据还在设备上捞得回来。
    /// 所以绝不能在「本轮存档」时覆盖掉上一轮的 —— 抖动式的连环误删里，
    /// 第二次覆盖时本地已经是空的，一覆盖就等于把第一次存的档也丢了。
    private func archive(_ plans: [SleepPlan]) {
        guard !plans.isEmpty else { return }
        var existing = archivedPlans()
        let existingIDs = Set(existing.map { $0.id })
        existing.append(contentsOf: plans.filter { !existingIDs.contains($0.id) })
        if existing.count > 20 { existing = Array(existing.suffix(20)) }
        if let data = try? JSONEncoder().encode(existing) {
            defaults.set(data, forKey: archiveKey)
        }
    }

    /// 读存档。给调试入口 / 将来的「恢复」用。
    func archivedPlans() -> [SleepPlan] {
        guard let data = defaults.data(forKey: archiveKey),
              let list = try? JSONDecoder().decode([SleepPlan].self, from: data) else { return [] }
        return list
    }

    /// 把存档里的计划恢复回本地并标脏（下次同步会重新上报给服务端）。
    /// 恢复回来一律是「未开启」：本轮开启状态早就失效了，直接复活成 active 会跟
    /// 服务端当前真正开启的那条冲突，违反「同时只有 1 条 active」。
    @discardableResult
    func restoreArchivedPlans() -> Int {
        let archived = archivedPlans()
        guard !archived.isEmpty else { return 0 }
        let known = Set(records.map { $0.id })
        var restored = 0
        for var plan in archived where !known.contains(plan.id) {
            plan.status = .notEnabled
            plan.activatedAt = nil
            plan.deleted = false
            plan.deletedAt = nil
            plan.updatedAt = Date()
            records.append(plan)
            markDirty(plan.id)
            restored += 1
        }
        defaults.removeObject(forKey: archiveKey)
        pendingDropIDs = []
        savePendingDrops()
        if restored > 0 { persist() }
        Log.info("SleepPlanStore", "从存档恢复 \(restored) 条睡眠计划（已标脏，将重新上报）")
        return restored
    }

    /// 上报成功后调用：把这批 id 移出脏集合，并把其中的墓碑**真正**从本地清掉。
    /// 墓碑一直留着的话，`records` 会随着删除次数无限膨胀。
    func markSynced(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let set = Set(ids)
        dirtyIDs.subtract(set)
        defaults.set(dirtyIDs.map { $0.uuidString }, forKey: dirtyKey)
        records.removeAll { $0.deleted && set.contains($0.id) }
        persistOnly()
    }

    /// 用服务端返回的全量计划覆盖本地（服务端是唯一事实源）。
    ///
    /// 唯一的例外是**仍然是脏的**那些记录：它们是在本次请求飞行途中改的，服务端这一版里
    /// 还没有，直接覆盖等于把用户刚做的修改吞掉。这些保留本地版本，等下一轮同步再上报。
    ///
    /// - Parameter allowDrops: 是否允许「服务端全量里没有」的本地计划被删掉。
    ///   传 `false` 时本条路径完全不删东西（连缓刑记账都不记），只把服务端有的合并进来。
    ///   调用方在**判定服务端这份数据不可信**时传 false —— 目前唯一的场景是服务端的会员
    ///   等级比本地 StoreKit 低（订阅还没同步到服务端，它按 free 算额度，下发的是一份
    ///   少了用户计划的「正确」全量）。详见 SleepPlanSyncService 里的 serverTierStale。
    func applyServerPlans(_ serverPlans: [SleepPlan], allowDrops: Bool = true) {
        let stillDirty = records.filter { dirtyIDs.contains($0.id) }
        let dirtySet = Set(stillDirty.map { $0.id })

        // 「服务端下发的全量里没有、本地也没打墓碑、也不是待上报的脏数据」= 服务端在删我们的东西。
        // 正常情况这是对的（别的设备删的），但这条路径同时也是**服务端一出错就把用户资料删光**
        // 的那条路径 —— 查错 uid、读空库、迁移事故，下发的都是一个合法的空列表。
        let serverIDs = Set(serverPlans.map { $0.id })
        // allowDrops=false：这份全量不可信，一条都不许删，也不记缓刑账
        // （记了的话，等服务端恢复正常那一轮会直接凑满「连续两次」把计划删掉）。
        let droppedIDs = allowDrops ? Set(records.filter {
            !$0.deleted && !serverIDs.contains($0.id) && !dirtySet.contains($0.id)
        }.map { $0.id }) : []

        // ★ 两次确认才真删。
        //
        // 服务端来回抖动（这次空、下次有、再下次又空）在联调期和故障期都很常见。
        // 一次就删的话，用户会看着计划反复消失又出现，更糟的是每一轮都要撤销并重排一遍
        // 本地通知 —— 提醒被反复取消/重建，真到点了很可能一次都不响。
        //
        // 规则：某条计划第一次「消失」时只记账、不动它；只有**连续两次**同步都说它没了，
        // 才真的删。抖动永远凑不齐连续两次，本地就稳住了。
        // 代价是别的设备上删掉的计划，本机要晚一轮同步（进 Tab / 回前台）才消失，这个可以接受。
        let confirmedDrops = droppedIDs.intersection(pendingDropIDs)
        let firstTimeDrops = droppedIDs.subtracting(pendingDropIDs)
        // 只保留「本轮仍然缺失」的记账。服务端把某条又下发回来了 → 它自动掉出这个集合，
        // 计数从头开始，这正是抖动被吃掉的地方。
        pendingDropIDs = droppedIDs
        savePendingDrops()

        if !firstTimeDrops.isEmpty {
            Log.info("SleepPlanStore",
                     "服务端全量里缺少 \(firstTimeDrops.count) 条本地计划，本轮先不删（等下一轮同步确认）：\(Self.brief(firstTimeDrops))")
        }
        if !confirmedDrops.isEmpty {
            // 连续两轮确认了，这些确实要删。删之前存一份档 —— 万一是服务端出错，还能捞回来。
            archive(records.filter { confirmedDrops.contains($0.id) })
            Log.error("SleepPlanStore",
                      "连续两轮同步确认缺失，删除 \(confirmedDrops.count) 条本地计划并已存档：\(Self.brief(confirmedDrops))")
        }

        // 本轮保留的 = 服务端下发的 + 仍然脏的 + 首次缺失（缓刑一轮）的。
        // 缓刑的这批**不标脏**：它们只是本地多显示一轮，不该被重新上传到服务端去复活。
        var merged = serverPlans.filter { !dirtySet.contains($0.id) }
        merged.append(contentsOf: stillDirty)
        merged.append(contentsOf: records.filter { firstTimeDrops.contains($0.id) })
        // allowDrops=false 时，服务端全量里缺的那些本地计划既不删也没进 firstTimeDrops，
        // 必须在这里显式留住 —— 否则它们同样会被 merged 覆盖掉，跟删了没区别。
        if !allowDrops {
            let mergedIDs = Set(merged.map { $0.id })
            merged.append(contentsOf: records.filter { !$0.deleted && !mergedIDs.contains($0.id) })
        }
        records = merged
        persist()
        // 提醒按合并后的结果重排：服务端可能把某条计划改成了 completed（周期跑满），
        // 或者别的设备开启了另一条计划 —— 不重排的话本机还在按旧计划响铃。
        for plan in records {
            if plan.deleted {
                SleepReminderScheduler.shared.cancelReminders(planId: plan.id)
            } else {
                SleepReminderScheduler.shared.reschedule(plan: plan)
            }
        }
    }

    /// 「每周重复」关闭时，这一轮的收尾时刻 = 最后一个执行日的入睡时刻 + 目标时长。
    /// 过了这个点计划就算跑完了。
    static func oneRoundEnd(for plan: SleepPlan, calendar: Calendar = .current) -> Date? {
        guard case .weekdays(_, let repeatsWeekly) = plan.cycle, !repeatsWeekly,
              let activatedAt = plan.activatedAt,
              let lastDay = plan.cycle.roundSleepDays(anchor: activatedAt, calendar: calendar).last else { return nil }
        var comps = calendar.dateComponents([.year, .month, .day], from: lastDay)
        comps.hour = plan.sleepTime / 60
        comps.minute = plan.sleepTime % 60
        guard let sleepMoment = calendar.date(from: comps) else { return nil }
        return sleepMoment.addingTimeInterval(TimeInterval(plan.targetMinutes) * 60)
    }

    /// 官方预设有固定周期（21/7/14 天），跑满后应转成「已完成」并排到列表末尾
    /// （「训练周期由系统固定配置，完成后可再次开启」）。没有服务端，只能每次读取/刷新时按
    /// activatedAt 推算。自定义计划没有固定终点，不参与。
    @discardableResult
    func refreshCompletionStates(now: Date = Date()) -> Bool {
        var changed = false
        for i in records.indices {
            guard !records[i].deleted, records[i].status == .active else { continue }

            let endDate: Date?
            if let days = records[i].kind.fixedCycleDays, let activatedAt = records[i].activatedAt {
                // 官方预设：固定 21 / 7 / 14 天。
                endDate = Calendar.current.date(byAdding: .day, value: days, to: activatedAt)
            } else {
                // 自定义计划且关闭了「每周重复」：只执行所选日期一轮，跑完自动收尾
                //（方案 A：转「已完成」、开关自动关掉，要再跑一轮得手动重新开启；
                // 保持 active 但不再触发会让开关骗人）。开着「每周重复」的不会有终点。
                endDate = Self.oneRoundEnd(for: records[i])
            }
            guard let endDate, now >= endDate else { continue }

            records[i].status = .completed
            records[i].activatedAt = nil
            records[i].updatedAt = Date()
            changed = true
            // 本地推算出的「跑满」也要上报：服务端虽然自己也会判（§6⑤），但两边的判定时刻
            // 未必同一秒到达，不上报的话下一次同步会被服务端那份仍是 active 的记录覆盖回去，
            // 表现为已完成的计划又变回执行中。
            markDirty(records[i].id)
            SleepReminderScheduler.shared.cancelReminders(planId: records[i].id)
        }
        if changed { persist() }
        return changed
    }

    private func persist() {
        persistOnly()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// 只落盘、不广播。用于同步层的内部整理（清墓碑等），避免触发一轮无谓的界面重建。
    private func persistOnly() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: storeKey)
        }
    }

    /// 排序规则：当前开启置顶 → 其余未开启按更新时间倒序 → 已完成/已停止排在末尾。
    var sortedPlans: [SleepPlan] {
        all.sorted { a, b in
            func rank(_ p: SleepPlan) -> Int {
                switch p.status {
                case .active: return 0
                case .notEnabled: return 1
                case .completed, .stopped: return 2
                }
            }
            let ra = rank(a), rb = rank(b)
            if ra != rb { return ra < rb }
            return a.updatedAt > b.updatedAt
        }
    }

    /// 占用额度的计划数（未开启/开启中都占用，完成/停止但未删除也占用——与设计稿一致）。
    ///
    /// ⚠️ 走 `all` 而不是 `records`：墓碑**不占额度**（服务端口径也是 `deleted=false` 才计数）。
    /// 用 `records.count` 的话，普通会员删掉唯一那条计划后仍然建不了新的 —— 额度被一条
    /// 用户已经看不见的记录占着。
    var occupiedSlotCount: Int { all.count }

    @discardableResult
    func save(_ plan: SleepPlan) -> SleepPlan {
        var plan = plan
        plan.updatedAt = Date()
        plan.timezone = TimeZone.current.identifier      // 审计字段：记下这次保存时人在哪个时区
        if let idx = records.firstIndex(where: { $0.id == plan.id }) {
            records[idx] = plan
        } else {
            records.append(plan)
        }
        markDirty(plan.id)
        persist()
        // 编辑的是当前开启中的计划：提醒设置可能变了（分钟数/开关），重新按最新配置排一遍。
        if plan.status == .active {
            SleepReminderScheduler.shared.reschedule(plan: plan)
        }
        SleepPlanSyncService.shared.sync(reason: "save")
        return plan
    }

    /// 删除 = 打墓碑，不是移除。见 `SleepPlan.deleted` 的说明。
    func delete(id: UUID) {
        guard let idx = records.firstIndex(where: { $0.id == id }),
              !records[idx].deleted, records[idx].status != .active else { return }
        records[idx].deleted = true
        records[idx].deletedAt = Date()
        records[idx].updatedAt = Date()
        markDirty(id)
        persist()
        SleepReminderScheduler.shared.cancelReminders(planId: id)
        SleepPlanSyncService.shared.sync(reason: "delete")
    }

    /// 开启计划：互斥停用其他所有已开启计划。调用方需先完成「切换执行计划？」二次确认。
    func enable(id: UUID) {
        guard let idx = all.firstIndex(where: { $0.id == id }) else { return }
        // 被顶下来的那条回到「未开启」，而不是「已停止」——与 disable() 以及服务端
        // 《睡眠计划同步接口》§6③「多余的 active 降为 not_enabled」保持一致。
        // 早期这里置的是 .stopped：同一个切换动作，本地排到列表最末显示「已停止」，
        // 服务端却是「未开启」排在中间，同步一次列表顺序和状态文案就会跳变。
        // activatedAt 也必须清掉，否则违反「status != active 时 activated_at 为 null」的约定，
        // 上传即脏数据（还会让 isLockedForTonight 拿着旧起算日误判）。
        for i in records.indices where !records[i].deleted && records[i].status == .active {
            records[i].status = .notEnabled
            records[i].activatedAt = nil
            records[i].updatedAt = Date()
            markDirty(records[i].id)
            SleepReminderScheduler.shared.cancelReminders(planId: records[i].id)
        }
        records[idx].status = .active
        records[idx].activatedAt = Date()
        records[idx].updatedAt = Date()
        markDirty(records[idx].id)
        persist()
        SleepReminderScheduler.shared.reschedule(plan: records[idx])
        SleepPlanSyncService.shared.sync(reason: "enable")
    }

    /// 关闭计划（今晚已开始时调用方需先拦截，见 SleepPlan.isLockedForTonight）。
    func disable(id: UUID) {
        guard let idx = records.firstIndex(where: { $0.id == id }), !records[idx].deleted else { return }
        records[idx].status = .notEnabled
        records[idx].activatedAt = nil
        records[idx].updatedAt = Date()
        markDirty(id)
        persist()
        SleepReminderScheduler.shared.cancelReminders(planId: id)
        SleepPlanSyncService.shared.sync(reason: "disable")
    }

    func plan(id: UUID) -> SleepPlan? { all.first { $0.id == id } }

    var activePlan: SleepPlan? { all.first { $0.status == .active } }

    /// 清空全部计划 + 取消所有已排的提醒。用于登出 / 注销账号。
    ///
    /// 脏集合与 `last_sync_at` 一起清掉：留着的话，下一个登录的账号会把**上一个账号**的
    /// 变更当成自己的上报出去，而且带着别人的 `last_sync_at` 去做增量对比。
    /// 服务端不因登出删数据，重新登录时由 `query_plans` 拉回（接口文档 §9）。
    func clear() {
        for plan in records { SleepReminderScheduler.shared.cancelReminders(planId: plan.id) }
        records = []
        dirtyIDs = []
        pendingDropIDs = []
        defaults.removeObject(forKey: storeKey)
        defaults.removeObject(forKey: dirtyKey)
        defaults.removeObject(forKey: lastSyncKey)
        defaults.removeObject(forKey: pendingDropKey)
        // 存档也一并清掉。它是**账号级**数据，留到下一个账号手里既可能被恢复成别人的计划，
        // 也违反「登出必须清掉所有账号级本地缓存」这条既定约束。
        // 代价是登出即失去这一层兜底 —— 但服务端本来就还留着数据，重新登录会拉回来。
        defaults.removeObject(forKey: archiveKey)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}
