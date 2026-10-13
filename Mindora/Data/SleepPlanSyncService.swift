//
//  SleepPlanSyncService.swift
//  mindora
//
//  睡眠计划云同步（对齐 Tools/doc/睡眠计划同步接口.md）：
//  POST /user_server/sleep_plan，request_type = sync_plans / query_plans。
//
//  分工（接口文档 §1）：**服务端是唯一事实源**。额度校验、「同一时间只开启 1 条」、
//  官方计划周期完成判定都以服务端为准；客户端做乐观更新，同步后以服务端返回整体覆盖本地。
//
//  ⚠️ 枚举必须显式转换，**不要直接把 SleepPlan encode 上传**：
//  本地模型的 rawValue 是驼峰（`habitFormation` / `notEnabled` / `fixedDaily`），
//  且这些值已经落在老用户的 UserDefaults 里改不动；协议一律用下划线。
//  转换表见接口文档 §5「枚举取值映射」，也就是本文件下面那几组 mapping。
//

import Foundation
import UIKit

final class SleepPlanSyncService {

    static let shared = SleepPlanSyncService()
    private let logTag = "SleepPlanSync"
    private init() {}

    /// 同步失败（含被拒条目）时广播，携带 `[RejectedItem]`。界面据此提示用户。
    static let didRejectNotification = Notification.Name("SleepPlanSync.didReject")

    struct RejectedItem {
        let planID: UUID?
        let reason: String
    }

    /// 一次只允许有一个请求在飞：进 Tab / 保存 / 回前台三条路很容易在同一秒撞在一起，
    /// 并发上报同一批脏数据时，后回来的那个响应会拿旧快照覆盖新快照。
    private var inFlight = false
    private var backoff = NetworkBackoff()

    // MARK: - 设备标识

    private let deviceIDKey = "sleepplan.deviceID.v1"

    /// 本机设备标识，用于多端冲突排查与「哪台设备最后改的」审计（接口文档 §4）。
    ///
    /// ⚠️ 这是 DEVICE_ID（每台唯一），**与 DEVICE_MODEL（型号常量）是两个完全独立的字段**，
    /// 不要用型号去派生它、也不要把两者拼成一串。
    ///
    /// 取 identifierForVendor 并落一份到本地：IDFV 在「本厂商的 App 全部卸载后」会换一个新值，
    /// 不落地的话同一台设备在服务端的审计记录会莫名其妙断成两台。
    private var deviceID: String {
        if let saved = UserDefaults.standard.string(forKey: deviceIDKey), !saved.isEmpty { return saved }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceIDKey)
        return id
    }

    // MARK: - 对外入口

    /// 上报本地变更并拉取合并后的全量计划。保存/开关/删除计划、进 Tab、回前台都走这条。
    func sync(reason: String) {
        request(type: "sync_plans", reason: reason)
    }

    /// 仅拉取全量。登录成功后 / 本地没有 `last_sync_at` 时用。
    func query(reason: String) {
        request(type: "query_plans", reason: reason)
    }

    /// 登录成功后调用：本地没同步过就全量拉，否则正常同步一次。
    func syncAfterLogin() {
        if SleepPlanStore.shared.lastSyncAt == nil {
            query(reason: "login")
        } else {
            sync(reason: "login")
        }
    }

    // MARK: - 请求

    private func request(type: String, reason: String) {
        // 统一切到主线程再往下走。触发点里有两个是**在 URLSession 回调线程上**调进来的
        // （登录成功后的 syncAfterLogin、以及别的服务的完成回调），而下面要碰的
        // `inFlight` / `backoff` 是裸的可变状态，`SleepPlanStore` 更是明确按「只在主线程访问」
        // 写的。不收口的话，登录那一路和用户手点那一路可能同时读改 inFlight，
        // 去重形同虚设，还会跟界面并发改同一个 records 数组。
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.request(type: type, reason: reason) }
            return
        }

        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let token = AuthStorage.shared.token, !token.isEmpty else {
            Log.info(logTag, "\(type)(\(reason)) 跳过：未登录")
            return
        }
        guard let url = URL(string: Constants.Network.sleepPlanURL) else { return }
        guard !inFlight else {
            Log.info(logTag, "\(type)(\(reason)) 跳过：已有请求在飞")
            return
        }
        // 退避只挡「不是用户点出来的」那些触发点。用户刚保存完计划却因为上一次失败
        // 被退避挡掉，等于他的修改凭空不上传，这个代价比多打一次服务端大得多。
        let userInitiated = (reason != "foreground")
        if backoff.isBlocked && !userInitiated {
            Log.info(logTag, "\(type)(\(reason)) 跳过：退避中，还剩 \(backoff.remainingSeconds)s")
            return
        }

        let isSync = (type == "sync_plans")
        let pending = isSync ? SleepPlanStore.shared.pendingChanges() : []
        let pendingIDs = pending.map { $0.id }

        var payload: [String: Any] = [
            "uid": uid,
            "jwt_token": token,
            "language": LocalizationManager.shared.currentLanguage.rawValue,
            // 计划里存的是「本地一天内的分钟数」，服务端要算出绝对触发时刻**必须**靠这个时区。
            // 且执行时区一律取最近一次上报的设备当前时区（§11①）：用户飞到别处，计划跟着走。
            "timezone": TimeZone.current.identifier,
            "device_id": deviceID
        ]
        if isSync {
            payload["plans"] = pending.map { Self.encodePlan($0) }
            if let last = SleepPlanStore.shared.lastSyncAt { payload["last_sync_at"] = last }
        }

        let body: [String: Any] = [
            "request_type": type,
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": payload
        ]

        var req = URLRequest(url: url)

        RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = Constants.Network.timeoutInterval
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        req.httpBody = data

        inFlight = true
        if Constants.Config.enableNetworkLogging {
            let text = String(data: data, encoding: .utf8) ?? "-"
            Log.info(logTag, "\(type)(\(reason)) request url=\(url) 上报\(pending.count)条 body=\(AuthService.redactToken(text))")
        }

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.inFlight = false
                self.handleResponse(type: type, reason: reason, requestUID: uid, uploadedIDs: pendingIDs,
                                    data: data, response: response, error: error)
            }
        }.resume()
    }

    @MainActor
    private func handleResponse(type: String, reason: String, requestUID: String, uploadedIDs: [UUID],
                                data: Data?, response: URLResponse?, error: Error?) {
        // ★ 账号没换过才允许落地。
        //
        // 请求是异步的，飞行途中用户完全可能登出并换账号登录：登出会 clear() 清空本地，
        // 紧接着上一个账号的响应回来，就把 A 的计划整份写进了 B 的账号 —— 而且还会标上
        // B 的 last_sync_at，之后每一轮同步都在拿 A 的数据跟 B 的服务端对。
        // 这是串号，比丢数据更糟。
        let currentUID = AuthStorage.shared.preferredUserIdentifier ?? ""
        guard currentUID == requestUID else {
            Log.info(logTag, "\(type)(\(reason)) 响应丢弃：请求发出后账号已变更（请求账号≠当前账号）")
            return
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if Constants.Config.enableNetworkLogging {
            let text = data.map { Log.prettyJSON($0) } ?? "-"
            Log.info(logTag, "\(type)(\(reason)) response status=\(status) body=\(text)")
        }

        if let error {
            // 网络失败：本地照常生效（乐观更新），变更留在脏队列里等下次同步（§9）。
            backoff.recordFailure()
            Log.error(logTag, "\(type)(\(reason)) 网络失败：\(error.localizedDescription)，本地变更保留待重试")
            return
        }
        _ = SessionExpirationCenter.handle(httpResponse: response, data: data)

        guard (200..<300).contains(status), let data else {
            backoff.recordFailure()
            Log.error(logTag, "\(type)(\(reason)) HTTP \(status)，本地变更保留待重试")
            return
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if let code = json?["code"] as? Int, code != 0 && code != 200 {
            backoff.recordFailure()
            Log.error(logTag, "\(type)(\(reason)) 业务失败 code=\(code) msg=\(json?["msg"] as? String ?? "-")")
            return
        }
        let payload = (json?["data"] as? [String: Any]) ?? [:]

        // ⚠️ 必须区分「plans 是空数组」和「响应里根本没有 plans 这个键」。
        // 前者是服务端明确告诉我们「你名下一条计划都没有」，该照做清空；
        // 后者是服务端漏传 / 结构变了 —— 按空数组处理会把用户本地的计划**全部抹掉**，
        // 而且抹完还会更新 last_sync_at，下次同步都补不回来。
        //
        // 这种响应按失败处理（走退避 + 保留脏队列），不能 recordSuccess ——
        // 结构都不对了，没有任何理由认为这次同步是成功的。
        guard let rawPlans = payload["plans"] as? [[String: Any]] else {
            backoff.recordFailure()
            Log.error(logTag, "\(type)(\(reason)) 响应缺少 plans 字段，判为失败：不覆盖本地、不更新 last_sync_at、保留待上报队列")
            return
        }
        let quotaUsed = ((payload["quota"] as? [String: Any])?["used"] as? Int) ?? -1
        let quotaLimit = ((payload["quota"] as? [String: Any])?["limit"] as? Int) ?? -1

        // quota.used 与 plans 是服务端**分别算出来的**两个值，正常必然自洽。
        // 对不上（说还占着 N 条、却一条都没下发）说明这次响应本身有问题，
        // 拿它去覆盖本地就是拿一份坏数据删用户的东西。判失败、原地不动。
        if quotaUsed > 0 && rawPlans.isEmpty {
            backoff.recordFailure()
            Log.error(logTag, "\(type)(\(reason)) 响应自相矛盾：quota.used=\(quotaUsed) 却下发 0 条计划，判为失败不覆盖本地")
            return
        }

        backoff.recordSuccess()

        // 被拒条目：先取出来，因为下面 markSynced 会把这些 id 一并出队 ——
        // 留在脏队列里每次同步都重报一次、每次都被拒，是个打不完的死循环。
        let rejected: [RejectedItem] = ((payload["rejected"] as? [[String: Any]]) ?? []).map {
            RejectedItem(planID: ($0["plan_id"] as? String).flatMap { s in UUID(uuidString: s) },
                         reason: ($0["reason"] as? String) ?? "unknown")
        }

        let serverPlans = rawPlans.compactMap { Self.decodePlan($0) }
        let tier = (payload["membership_tier"] as? String) ?? "-"

        // ★ 服务端的会员等级比本地低 → 这次响应里的额度判定一律不可信。
        //
        // 订阅是用户跟 Apple 之间的交易，服务端只能通过 report_subscription 得知，而它
        // 目前还没落库（ASSN V2 也没接）。于是沙盒购买、换机恢复、重装、自动续费之后，
        // 本地 StoreKit 明明有有效的 premium 凭证，服务端那边却仍是 free。
        //
        // 服务端按 free 算额度（0 条）的后果有两个，都直接砸在用户脸上：
        //   ① 新建计划被 tier_not_allowed 拒掉，弹一个「升级高级会员」——可他已经是最高档了；
        //   ② 全量下发里没有这些计划，applyServerPlans 连续两轮确认后把它们删掉，
        //      用户眼睁睁看着自己建的计划消失。
        //
        // 所以这里认本地：服务端等级偏低时，本次响应只用来「合并服务端有的」，
        // 绝不拿它删本地的东西，也不拿它的额度判定去打扰用户。
        let localTier = SubscriptionManager.shared.membershipTier
        let serverTierStale = Self.tierRank(tier) < Self.tierRank(localTier)

        // 被拒的条目在这种情况下**保持脏**，不出队：服务端补上会员记录后，下一轮同步
        // 会把它们重新报上去，用户不需要手动重建。反复被拒也只是多一次请求——
        // 提示已经按下不表，不会变成打不完的弹窗。
        let rejectedIDs = Set(rejected.compactMap { $0.planID })
        let syncedIDs = serverTierStale ? uploadedIDs.filter { !rejectedIDs.contains($0) } : uploadedIDs

        // 顺序要紧：先 markSynced 把这批已上报的移出脏队列，再 applyServerPlans。
        // 反过来的话，applyServerPlans 里「保留仍然脏的记录」会把刚上报成功的这批
        // 全部当成未同步而保留下来，服务端的合并结果一条都盖不进去。
        SleepPlanStore.shared.markSynced(ids: syncedIDs)
        SleepPlanStore.shared.applyServerPlans(serverPlans, allowDrops: !serverTierStale)

        if let serverTime = payload["server_time"] as? Int, serverTime > 0 {
            SleepPlanStore.shared.lastSyncAt = serverTime
        }

        Log.info(logTag, "\(type)(\(reason)) 成功：服务端下发\(serverPlans.count)条 tier=\(tier) quota=\(quotaUsed)/\(quotaLimit) 被拒\(rejected.count)条")

        if serverTierStale {
            Log.error(logTag, "服务端会员等级偏低（server=\(tier) local=\(Self.tierName(localTier)))：本次不按服务端额度删本地计划、不提示升级，被拒的\(rejectedIDs.count)条保持待上报")
            // 之前已经被误删的，这里捞回来——中招的用户升不升级都该看到自己的计划。
            let restored = SleepPlanStore.shared.restoreArchivedPlans()
            if restored > 0 {
                Log.info(logTag, "服务端等级偏低，已从存档恢复 \(restored) 条被误删的计划")
            }
        }

        if !rejected.isEmpty {
            for item in rejected {
                Log.error(logTag, "上报被拒 plan=\(item.planID?.uuidString ?? "-") reason=\(item.reason)")
            }
            // 等级判定不可信时，额度类的拒绝不给用户看：他已经是付费会员，
            // 弹「升级高级会员」纯属误导。其余 reason（时长/周期/命名非法）照常提示。
            let visible = serverTierStale
                ? rejected.filter { $0.reason != "tier_not_allowed" && $0.reason != "quota_exceeded" }
                : rejected
            if !visible.isEmpty {
                NotificationCenter.default.post(name: Self.didRejectNotification, object: visible)
            }
        }
    }

    /// 会员等级排序，用于比较服务端与本地谁更高。
    /// 服务端 `level` 历史上用 "pro" 表示普通会员，睡眠计划接口用 "basic"，两种都认。
    private static func tierRank(_ server: String) -> Int {
        switch server {
        case "premium": return 2
        case "basic", "pro": return 1
        default: return 0
        }
    }

    private static func tierRank(_ local: MembershipTier) -> Int {
        switch local {
        case .premium: return 2
        case .basic: return 1
        case .free: return 0
        }
    }

    private static func tierName(_ local: MembershipTier) -> String {
        switch local {
        case .premium: return "premium"
        case .basic: return "basic"
        case .free: return "free"
        }
    }

    // MARK: - 枚举映射（本地驼峰 ↔ 协议下划线）

    private static func wireKind(_ kind: SleepPlanKind) -> String {
        switch kind {
        case .custom: return "custom"
        case .habitFormation: return "habit_formation"
        case .jetLag: return "jet_lag"
        case .anxietyRelief: return "anxiety_relief"
        }
    }

    private static func localKind(_ wire: String) -> SleepPlanKind? {
        switch wire {
        case "custom": return .custom
        case "habit_formation": return .habitFormation
        case "jet_lag": return .jetLag
        case "anxiety_relief": return .anxietyRelief
        default: return nil
        }
    }

    private static func wireStatus(_ status: SleepPlanStatus) -> String {
        switch status {
        case .notEnabled: return "not_enabled"
        case .active: return "active"
        case .completed: return "completed"
        case .stopped: return "stopped"
        }
    }

    private static func localStatus(_ wire: String) -> SleepPlanStatus {
        switch wire {
        case "active": return .active
        case "completed": return .completed
        case "stopped": return .stopped
        default: return .notEnabled
        }
    }

    // MARK: - 序列化

    private static func encodePlan(_ plan: SleepPlan) -> [String: Any] {
        // 墓碑只需要四个字段（接口文档 §7）。其余字段对已删除的计划没有意义，
        // 也免得把一条用户已经删掉的计划的完整内容再传一遍。
        if plan.deleted {
            return [
                "plan_id": plan.id.uuidString,
                "deleted": true,
                "deleted_at": Int((plan.deletedAt ?? plan.updatedAt).timeIntervalSince1970),
                "updated_at": Int(plan.updatedAt.timeIntervalSince1970)
            ]
        }

        var cycle: [String: Any]
        switch plan.cycle {
        case .fixedDaily(let days):
            cycle = ["type": "fixed_daily", "days_count": days]
        case .weekdays(let days, let repeatsWeekly):
            cycle = ["type": "weekdays",
                     "weekdays": days.sorted(),
                     "repeats_weekly": repeatsWeekly]
        }

        var dict: [String: Any] = [
            "plan_id": plan.id.uuidString,
            "kind": wireKind(plan.kind),
            "custom_name": plan.kind == .custom ? plan.customName : "",
            "target_minutes": plan.targetMinutes,
            "sleep_time": plan.sleepTime,
            "wake_time": plan.wakeTime,
            "cycle": cycle,
            "reminder_enabled": plan.reminderEnabled,
            "reminder_minutes_before": plan.reminderMinutesBefore,
            "alarm_sound_id": plan.alarmSoundId,
            // sleep_aid_item_id 已从协议移除：推哪条内容由服务端按策略决定，客户端只传策略。
            "sleep_aid_category": plan.sleepAidCategory,
            "status": wireStatus(plan.status),
            "created_at": Int(plan.createdAt.timeIntervalSince1970),
            "updated_at": Int(plan.updatedAt.timeIntervalSince1970),
            "deleted": false
        ]
        if let tz = plan.timezone { dict["timezone"] = tz }
        // 不变式：status != active 时 activated_at 必须为 null（§6③）。
        //
        // ⚠️ 这里必须显式落到 NSNull，不能写成 `plan.activatedAt.map { … } as Any`：
        // activatedAt 为 nil 时那个写法会把一个 Optional.none 装箱成 Any 塞进字典，
        // JSONSerialization 直接抛错 → httpBody 建不出来 → 整个同步**静默不发**。
        if plan.status == .active, let activatedAt = plan.activatedAt {
            dict["activated_at"] = Int(activatedAt.timeIntervalSince1970)
        } else {
            dict["activated_at"] = NSNull()
        }
        return dict
    }

    private static func decodePlan(_ dict: [String: Any]) -> SleepPlan? {
        guard let idString = dict["plan_id"] as? String, let id = UUID(uuidString: idString),
              let kindString = dict["kind"] as? String, let kind = localKind(kindString) else {
            Log.error("SleepPlanSync", "下发计划解析失败（plan_id/kind 无效）：\(dict)")
            return nil
        }

        let cycleDict = (dict["cycle"] as? [String: Any]) ?? [:]
        let cycle: SleepPlanCycle
        if (cycleDict["type"] as? String) == "weekdays" {
            let days = Set((cycleDict["weekdays"] as? [Int]) ?? [])
            let repeats = (cycleDict["repeats_weekly"] as? Bool) ?? true
            cycle = .weekdays(days: days, repeatsWeekly: repeats)
        } else {
            // 官方预设的天数以本地常量兜底：服务端漏传 days_count 时，落成 0 天会让
            // refreshCompletionStates 立刻把计划判成「已完成」。
            let days = (cycleDict["days_count"] as? Int) ?? kind.fixedCycleDays ?? 21
            cycle = .fixedDaily(days: days)
        }

        let status = localStatus((dict["status"] as? String) ?? "not_enabled")
        let activatedAt = (status == .active) ? parseSeconds(dict["activated_at"]) : nil

        return SleepPlan(
            id: id,
            kind: kind,
            customName: (dict["custom_name"] as? String) ?? "",
            targetMinutes: (dict["target_minutes"] as? Int) ?? 480,
            sleepTime: (dict["sleep_time"] as? Int) ?? 1320,
            wakeTime: (dict["wake_time"] as? Int) ?? 420,
            cycle: cycle,
            reminderEnabled: (dict["reminder_enabled"] as? Bool) ?? false,
            reminderMinutesBefore: (dict["reminder_minutes_before"] as? Int) ?? 30,
            alarmSoundId: (dict["alarm_sound_id"] as? String) ?? "sunlit_coast",
            sleepAidCategory: (dict["sleep_aid_category"] as? String) ?? "smart",
            status: status,
            createdAt: parseSeconds(dict["created_at"]) ?? Date(),
            updatedAt: parseSeconds(dict["updated_at"]) ?? Date(),
            activatedAt: activatedAt,
            deleted: false,
            deletedAt: nil,
            timezone: dict["timezone"] as? String)
    }

    private static func parseSeconds(_ value: Any?) -> Date? {
        guard let n = value as? NSNumber, n.doubleValue > 0 else { return nil }
        return Date(timeIntervalSince1970: n.doubleValue)
    }
}
