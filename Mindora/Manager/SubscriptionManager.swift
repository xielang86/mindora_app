import UIKit
import StoreKit
import CryptoKit

enum SubscriptionType {
    case free
    case monthly
    case yearly
}

/// 会员分级（睡眠计划分级会员上线）。普通会员 = 原有单一订阅产品（已改价 $4.99/$49.99）；
/// 高级会员 = 新增的 premium 系列产品（$6.99/$69.99），需与普通会员产品同属一个订阅组。
enum MembershipTier {
    case free
    case basic
    case premium
}

/// 订阅的续订状态。UI 上「日期那一行」说什么，完全由它决定。
enum SubscriptionRenewalState {
    /// 正常续订中 —— 到期日那天会扣款。
    case autoRenewing
    /// 已关闭自动续订 —— 到期日那天失去权限，不再扣款。
    case cancelled
    /// 宽限期：扣款失败但 Apple 仍暂时保留权限，用户需更新付款方式。
    case inGracePeriod
    /// 扣款失败重试中。
    case inBillingRetry
    /// 已过期 / 已退款作废。
    case expired
    /// 没有店内订阅（兑换码会员、体验期、或未订阅）。
    case none
}

@MainActor
class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()
    private let logTag = "Subscription"

    /// 调试用：强制指定会员等级，跳过真实 StoreKit 购买/服务端校验，仅用于本地界面走查。
    /// 仅 DEBUG 生效，正式包不存在这个开关。
    #if DEBUG
    static var debugForceMembershipTier: MembershipTier?

    /// 沙盒退款测试：对当前最新一笔交易弹 StoreKit 退款申请表。沙盒环境提交即退，随后
    /// Apple 推 REFUND 通知、Transaction.updates 再送一次带 revocationDate 的同一笔交易。
    @MainActor
    func debugBeginRefundRequest(in scene: UIWindowScene) async -> String {
        guard let tx = latestTransaction else { return "没有可退款的交易" }
        do {
            let status = try await tx.beginRefundRequest(in: scene)
            Log.info(logTag, "[DEBUG] refund request txn=\(tx.id) status=\(status)")
            return "退款申请 txn=\(tx.id) 结果=\(status)"
        } catch {
            Log.error(logTag, "[DEBUG] refund request failed txn=\(tx.id): \(error)")
            return "退款申请失败：\(error.localizedDescription)"
        }
    }
    #endif
    
    // Published properties
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []

    // Add willAutoRenew property
    @Published var willAutoRenew: Bool = false

    /// 当前实际持有的订阅产品 ID（订阅页据此把对应的那张周期卡标成「当前套餐」）。
    @Published private(set) var activeProductID: String? = nil

    /// 已排期、但要到下个续费日才生效的产品 ID。
    ///
    /// 同一订阅组内「换时长」（月↔年）和「降级」都不是立刻生效的，App Store 会让当前订阅走完，
    /// 到期那天才换成新的。这期间 purchasedProductIDs 仍是旧产品，如果界面上不体现，用户会觉得
    /// 「我明明付了钱切了年度，怎么什么都没变」——这是订阅类 App 最常见的客诉来源。
    /// 值取自 `renewalInfo.autoRenewPreference`（下个周期真正会续订的产品），与当前持有的不同才有值。
    @Published private(set) var pendingRenewalProductID: String? = nil

    /// 当前订阅的续订状态 —— 决定「日期那一行」到底该说什么。
    /// 固定写「续期时间」在用户已关闭自动续订时含义正好相反；宽限期/重试期是用户
    /// 最需要被提醒的时刻（卡过期、余额不足），显示成一切正常等于等着掉权限后来客诉。
    @Published private(set) var renewalState: SubscriptionRenewalState = .none

    /// 宽限期真正失去权限的时刻（`renewalInfo.gracePeriodExpirationDate`）。
    /// 宽限期里 expirationDate 已经过去了，拿它当「到期日」显示会是个过去的日期。
    @Published private(set) var gracePeriodExpiresAt: Date? = nil

    /// 是否已经至少完成过一次 StoreKit 权益解析。首启时权益是异步加载的，解析完成前
    /// purchasedProductIDs 还是空、isSubscribed 假性为 false——此时不能把会员当非会员去上遮罩。
    @Published private(set) var hasResolvedStatus = false
    
    private var latestTransaction: Transaction? = nil

    // MARK: - 服务端会员状态（订阅状态服务端化-改造方案.md §3.2）
    // 服务端把兑换码等级 + 体验期 + Apple 订阅（JWS 上报 / ASSN / 对账）合并成 effective_user_level 下发，
    // 按 uid 缓存在 MembershipStateStore。`entitlement_authority == "server"` 时会员判定以它为准，
    // 本地 StoreKit 只做兜底（没拉到过 / 刚购买服务端还没确认）；为 "client" 时维持原有 StoreKit 逻辑。
    // 开关由服务端下发，不发版就能切换 / 回滚。

    /// 当前账号的服务端会员快照（未登录 / 没拉到过 → nil）。
    var serverState: ServerMembershipState? {
        guard let uid = AuthStorage.shared.uid?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty else { return nil }
        return MembershipStateStore.shared.state(forUid: uid)
    }
    /// 会员判定是否以服务端为准（服务端下发的开关；没拉到过状态时为 false → 走 StoreKit）。
    var entitlementAuthorityIsServer: Bool { serverState?.authorityIsServer ?? false }

    /// 本地刚完成购买、服务端还没确认的窗口截止时刻（购买成功 + 24h）。
    /// 窗口内 StoreKit 与服务端取高者：服务端超时 / 断网也不能把刚付钱的用户挡在门外。
    private static let pendingPurchaseUntilKey = "membership.pendingPurchaseUntil"
    private var pendingPurchaseUntil: Date? {
        let t = kcDouble(Self.pendingPurchaseUntilKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
    var isLocalPurchasePending: Bool { (pendingPurchaseUntil ?? .distantPast) > Date() }

    /// 购买成功：开一个 24h 的「信本地」窗口，等服务端验签确认后关闭。
    private func noteLocalPurchase() {
        kcSetDouble(Date().addingTimeInterval(24 * 3600).timeIntervalSince1970, Self.pendingPurchaseUntilKey)
    }
    /// 服务端已确认（凭据验签通过并落库）或明确拒绝：关闭窗口，此后以服务端为准。
    func clearPendingLocalPurchase(reason: String) {
        guard pendingPurchaseUntil != nil else { return }
        Self.kc.delete(forKey: Self.pendingPurchaseUntilKey)
        Log.info(logTag, "本地购买待确认窗口关闭：\(reason)")
    }

    /// 落地一份服务端会员状态（query_user_rights / report_subscription 响应）。
    /// 同时把体验期同步进旧的 per-uid 记录（applyPremiumTrial 取较晚者），client 模式的判定照常受益。
    func applyServerState(_ state: ServerMembershipState, source: String) {
        guard let uid = AuthStorage.shared.uid?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty else {
            Log.info(logTag, "服务端会员状态落地失败：未登录（\(source)）")
            return
        }
        MembershipStateStore.shared.save(state, forUid: uid)
        applyPremiumTrial(endAt: state.premiumTrialEndAt)
        syncGrantedLevel(fromServer: state, uid: uid)

        // 比对日志：切换到 server 之前靠这行看两边差异（grep "MEMBERSHIP-DIFF"）。
        let localPaid = storeKitPaidTier
        let serverPaid = Self.tier(from: state.paidLevel)
        let diff = localPaid != serverPaid ? "MEMBERSHIP-DIFF" : "same"
        Log.info(logTag, "服务端会员状态(\(source)) \(state.summary) | 本地StoreKit=\(localPaid) 服务端paid=\(serverPaid) → \(diff) pendingLocal=\(isLocalPurchasePending)")

        // 服务端没有店内续订信息时不动 StoreKit 解析出的 renewalState；只在本地没有任何订阅、
        // 而服务端有 Apple 订阅记录时按服务端补一个展示状态。
        if latestTransaction == nil, let sub = state.subscription {
            renewalState = Self.renewalState(fromServer: sub)
            gracePeriodExpiresAt = sub.gracePeriodExpiresAt
            if activeProductID == nil, sub.active { activeProductID = sub.productID }
        }
        lastKnownSubscribed = isSubscribed
        lastKnownPaidTier = paidMembershipTier
        lastKnownYearly = currentPlan == .yearly
        NotificationCenter.default.post(name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
    }

    static func tier(from level: String) -> MembershipTier {
        switch level { case "premium": return .premium; case "pro": return .basic; default: return .free }
    }
    private static func maxTier(_ a: MembershipTier, _ b: MembershipTier) -> MembershipTier {
        func r(_ t: MembershipTier) -> Int { t == .premium ? 2 : (t == .basic ? 1 : 0) }
        return r(a) >= r(b) ? a : b
    }
    private static func renewalState(fromServer sub: ServerMembershipState.AppleSubscription) -> SubscriptionRenewalState {
        if sub.revokedAt != nil { return .expired }
        if sub.inBillingRetry { return (sub.gracePeriodExpiresAt ?? .distantPast) > Date() ? .inGracePeriod : .inBillingRetry }
        if !sub.active { return .expired }
        return sub.autoRenew ? .autoRenewing : .cancelled
    }

    // Cache for checking status
    private var updates: Task<Void, Never>? = nil

    // MARK: - 会员安全存储（Keychain）
    // 会员/订阅归属是「谁付了钱/谁该有权益」的凭据，放 Keychain 而不是 UserDefaults：
    //  ① 抗篡改（越狱下改 plist 比改 Keychain 容易）；② 跨重装留存（Keychain 默认卸载不清，
    //  重装后 StoreKit 恢复购买时归属还在、能正确隔离账号）。
    private static let kc = KeychainHelper.standard
    private func kcString(_ key: String) -> String? { Self.kc.read(forKey: key) }
    private func kcSetString(_ value: String?, _ key: String) {
        if let value, !value.isEmpty { Self.kc.save(value, forKey: key) } else { Self.kc.delete(forKey: key) }
    }
    private func kcBool(_ key: String) -> Bool { Self.kc.read(forKey: key) == "1" }
    private func kcSetBool(_ value: Bool, _ key: String) { Self.kc.save(value ? "1" : "0", forKey: key) }
    private func kcInt(_ key: String) -> Int { Int(Self.kc.read(forKey: key) ?? "") ?? 0 }
    private func kcSetInt(_ value: Int, _ key: String) { Self.kc.save(String(value), forKey: key) }
    private func kcDouble(_ key: String) -> Double { Double(Self.kc.read(forKey: key) ?? "") ?? 0 }
    private func kcSetDouble(_ value: Double, _ key: String) { Self.kc.save(String(value), forKey: key) }

    // MARK: - 服务端授予的会员（兑换码 / 后台赠送，对齐 doc/duihuan.md）
    // 兑换码兑换成功后服务端返回 user_level + level_end_at。
    // ★ 关键：**按账号(uid)分别存**，而不是一个全局槽——否则同一台设备 A、B 都兑换时会互相覆盖/叠加：
    //   B 会叠加到 A 剩余时长、继承 A 的年/月等级；且 B 兑换会覆盖 A，导致 A 切回来后会员丢失。
    //   每个 uid 一条记录，天然隔离，切回原账号仍在。登录不从服务端重拉，故本地必须按 uid 各存各的。
    // 持久化到 Keychain（抗篡改 + 跨重装留存）。
    private static let serverByUidKey = "membership.serverByUid"
    // trialEnd：服务端授予的「高级会员体验期」结束时刻（秒级）。见《订阅权益与定价方案》待确认第 2 条：
    //   ① 注册即送 7 天 Premium（未付费，到期回 free）；② 首次订阅 Basic 再送 7 天（到期回 Basic）。
    //   两段各自独立发放、可叠加（连续 14 天），这是产品有意留的营销口子，不要去堵。
    //   事实源在服务端（按 uid 存两列取 max），这里只是缓存下发值；可选字段，旧 Keychain 数据照常解码。
    private struct ServerRecord: Codable { var level: String; var end: Double?; var max: Int; var trialEnd: Double? = nil }

    private func loadServerMap() -> [String: ServerRecord] {
        guard let json = kcString(Self.serverByUidKey), let data = json.data(using: .utf8),
              let m = try? JSONDecoder().decode([String: ServerRecord].self, from: data) else { return [:] }
        return m
    }
    private func saveServerMap(_ m: [String: ServerRecord]) {
        if let data = try? JSONEncoder().encode(m), let json = String(data: data, encoding: .utf8) {
            kcSetString(json, Self.serverByUidKey)
        }
    }
    /// 当前登录账号的服务端会员记录（未登录 / 无记录 → nil）。
    private func currentServerRecord() -> ServerRecord? {
        guard let uid = AuthStorage.shared.uid?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty else { return nil }
        return loadServerMap()[uid]
    }

    /// 当前账号的服务端会员等级 / 到期 / 最大时长——按 uid 实时读，天然隔离账号（换账号不继承、切回仍在）。
    var serverLevel: String { currentServerRecord()?.level ?? "free" }         // free / pro / premium
    var serverLevelEndAt: Date? { currentServerRecord()?.end.map { Date(timeIntervalSince1970: $0) } }
    /// 本段会员期内兑换过的最大单卡时长（365≈年/30≈月）。用于「年/月」展示且不降级；失效后从新卡时长起算。
    var serverMaxDurationDays: Int { currentServerRecord()?.max ?? 0 }

    /// 服务端授予的高级会员体验期结束时刻（未下发 → nil）。
    var premiumTrialEndAt: Date? { currentServerRecord()?.trialEnd.map { Date(timeIntervalSince1970: $0) } }
    /// 体验期是否仍在有效期内。服务端未下发该字段时恒为 false，行为与接入前完全一致。
    var isPremiumTrialActive: Bool {
        guard let end = premiumTrialEndAt else { return false }
        return end > Date()
    }
    /// 体验期剩余天数（向上取整，至少 1；不在体验期为 0）。用于订阅页/资料卡展示。
    var premiumTrialRemainingDays: Int {
        guard let end = premiumTrialEndAt, end > Date() else { return 0 }
        let seconds = end.timeIntervalSinceNow
        return max(1, Int(ceil(seconds / 86400)))
    }

    // 旧单槽键（仅供一次性迁移到 serverByUid 使用，不再作为主存储）。
    private static let serverLevelKey = "membership.serverLevel"
    private static let serverLevelEndKey = "membership.serverLevelEndAt"
    private static let serverMaxDaysKey = "membership.serverMaxDurationDays"
    private static let ownerUidKey = "membership.ownerUid"

    /// 上一次解析得到的「是否会员」结果，持久化到本地。冷启动时用它即时决定是否上遮罩，
    /// 不必等 StoreKit 首次异步解析——避免非会员开 App 后迟迟不弹订阅遮罩。
    private static let lastKnownSubscribedKey = "membership.lastKnownSubscribed"
    private var lastKnownSubscribed: Bool {
        get { kcBool(Self.lastKnownSubscribedKey) }
        set { kcSetBool(newValue, Self.lastKnownSubscribedKey) }
    }

    /// 上一次解析得到的**付费等级 / 周期**，用途和 `lastKnownSubscribed` 完全一致，只是多了两档信息。
    ///
    /// StoreKit 权益是异步解析的，`purchasedProductIDs` 又只存在内存里：冷启动后第一次进订阅页时
    /// 它还是空的，`paidMembershipTier` 恒为 `.free`、`currentPlan` 恒为 `.monthly`，订阅卡就先按
    /// 非会员摆初始态（分段器停在「普通会员」、周期卡停在「月度」）；等 `updateSubscriptionStatus`
    /// 解析完成广播刷新、卡片重建，才跳到真正该停的那一档 —— 用户看到的就是「第一次进订阅页，
    /// 分段器在普通/高级之间自己跳一下，第二次进就不跳了」（第二次内存里已有解析结果）。
    /// 把上次的结论落地，卡片在解析完成前就能摆一个大概率正确的初始态，不再跳。
    private static let lastKnownPaidTierKey = "membership.lastKnownPaidTier"
    private static let lastKnownYearlyKey = "membership.lastKnownYearly"
    var lastKnownPaidTier: MembershipTier {
        get {
            switch kcString(Self.lastKnownPaidTierKey) {
            case "premium": return .premium
            case "basic":   return .basic
            default:        return .free
            }
        }
        set {
            switch newValue {
            case .premium: kcSetString("premium", Self.lastKnownPaidTierKey)
            case .basic:   kcSetString("basic", Self.lastKnownPaidTierKey)
            case .free:    kcSetString(nil, Self.lastKnownPaidTierKey)
            }
        }
    }
    var lastKnownYearly: Bool {
        get { kcBool(Self.lastKnownYearlyKey) }
        set { kcSetBool(newValue, Self.lastKnownYearlyKey) }
    }

    /// 上一次登录的账号 uid（跨登出保留）。用于识别「换了账号」→ 作废上一账号的 StoreKit 快照并重解析。
    private static let lastAuthedUidKey = "membership.lastAuthedUid"
    /// 店内订阅（StoreKit）归属表：originalTransactionID → ownerUid。换 App 账号不继承。
    /// 存 Keychain、登出不清（切回原账号仍认）。无服务端验签时的过渡方案，只覆盖「同设备换账号」。
    private static let storeKitOwnersKey = "membership.storeKitOwners"

    private func loadStoreKitOwners() -> [String: String] {
        guard let json = kcString(Self.storeKitOwnersKey),
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }

    private func saveStoreKitOwners(_ dict: [String: String]) {
        if let data = try? JSONEncoder().encode(dict), let json = String(data: data, encoding: .utf8) {
            kcSetString(json, Self.storeKitOwnersKey)
        }
    }

    /// 店内订阅「当前账号认领时间」表：originalTransactionID → epoch 秒。
    /// 「累计天数(tideDays)」按此计算——换账号订阅后从新账号认领那天起算，而不是 Apple ID 的原始购买日。
    private static let storeKitClaimDatesKey = "membership.storeKitClaimDates"
    private func loadStoreKitClaimDates() -> [String: Double] {
        guard let json = kcString(Self.storeKitClaimDatesKey), let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        return dict
    }
    private func saveStoreKitClaimDates(_ dict: [String: Double]) {
        if let data = try? JSONEncoder().encode(dict), let json = String(data: data, encoding: .utf8) {
            kcSetString(json, Self.storeKitClaimDatesKey)
        }
    }

    /// 一次性把历史存在 UserDefaults 的会员数据迁移到 Keychain（升级本版本时执行一次）。
    private func migrateMembershipToKeychainIfNeeded() {
        let flagKey = "membership.migratedToKeychain.v1"
        let d = UserDefaults.standard
        guard !d.bool(forKey: flagKey) else { return }
        func moveString(_ key: String) {
            if kcString(key) == nil, let v = d.string(forKey: key), !v.isEmpty { Self.kc.save(v, forKey: key) }
            d.removeObject(forKey: key)
        }
        moveString(Self.serverLevelKey); moveString(Self.ownerUidKey); moveString(Self.lastAuthedUidKey)
        if kcString(Self.lastKnownSubscribedKey) == nil, d.object(forKey: Self.lastKnownSubscribedKey) != nil {
            kcSetBool(d.bool(forKey: Self.lastKnownSubscribedKey), Self.lastKnownSubscribedKey)
        }
        d.removeObject(forKey: Self.lastKnownSubscribedKey)
        if kcString(Self.serverMaxDaysKey) == nil, d.object(forKey: Self.serverMaxDaysKey) != nil {
            kcSetInt(d.integer(forKey: Self.serverMaxDaysKey), Self.serverMaxDaysKey)
        }
        d.removeObject(forKey: Self.serverMaxDaysKey)
        if kcString(Self.serverLevelEndKey) == nil {
            let t = d.double(forKey: Self.serverLevelEndKey)
            if t > 0 { kcSetDouble(t, Self.serverLevelEndKey) }
        }
        d.removeObject(forKey: Self.serverLevelEndKey)
        if kcString(Self.storeKitOwnersKey) == nil, let data = d.data(forKey: Self.storeKitOwnersKey),
           let json = String(data: data, encoding: .utf8) { Self.kc.save(json, forKey: Self.storeKitOwnersKey) }
        d.removeObject(forKey: Self.storeKitOwnersKey)
        d.set(true, forKey: flagKey)
    }

    /// 当前账号的服务端会员是否在有效期内（pro/premium）。按 uid 实时读，天然只认当前账号的记录。
    var isServerMembershipActive: Bool {
        guard let rec = currentServerRecord() else { return false }
        guard rec.level == "pro" || rec.level == "premium" else { return false }
        if let end = rec.end { return end > Date().timeIntervalSince1970 }
        return true
    }

    /// 一次性把「旧单槽」服务端会员迁移到按 uid 存的 map（升级本版本时执行一次）。
    /// 旧数据主人取 ownerUid（没有则取 lastAuthedUid / 当前 uid 兜底）。迁移后清掉旧单槽键。
    private func migrateServerSingleSlotToPerUidIfNeeded() {
        let flag = "membership.serverPerUidMigrated.v1"
        guard !kcBool(flag) else { return }
        if let level = kcString(Self.serverLevelKey), level == "pro" || level == "premium" {
            let owner = [kcString(Self.ownerUidKey), kcString(Self.lastAuthedUidKey),
                         AuthStorage.shared.uid?.trimmingCharacters(in: .whitespacesAndNewlines)]
                .compactMap { $0 }.first(where: { !$0.isEmpty }) ?? ""
            if !owner.isEmpty {
                var m = loadServerMap()
                if m[owner] == nil {
                    let end = kcDouble(Self.serverLevelEndKey)
                    m[owner] = ServerRecord(level: level, end: end > 0 ? end : nil, max: kcInt(Self.serverMaxDaysKey))
                    saveServerMap(m)
                    Log.info(logTag, "迁移旧单槽会员到 per-uid：owner=\(owner) level=\(level)")
                }
            }
        }
        kcSetString(nil, Self.serverLevelKey); kcSetString(nil, Self.serverLevelEndKey)
        kcSetString(nil, Self.serverMaxDaysKey); kcSetString(nil, Self.ownerUidKey)
        kcSetBool(true, flag)
    }

    /// 登录 / 冷启动后调用：识别是否换了账号。服务端会员按 uid 存、天然隔离（无需在此处理）；
    /// 这里只负责在换账号时作废上一账号的 StoreKit 快照并按新账号重新解析（服务端会员每次实时按 uid 读，无缓存问题）。
    func reconcileMembershipOwner() {
        let current = AuthStorage.shared.uid?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !current.isEmpty else {
            Log.info(logTag, "reconcile: 未登录，跳过")
            return
        }
        let previous = kcString(Self.lastAuthedUidKey)
        kcSetString(current, Self.lastAuthedUidKey)
        let changed = (previous != nil && !previous!.isEmpty && previous != current)

        // 换了账号：
        //  ① 立即作废上一账号的店内订阅快照 —— purchasedProductIDs 是上次解析的缓存，App 内换账号
        //     （登出→登录，不经后台）不会自动重算，否则新账号会看到上一账号缓存的已订阅（误判继承）；
        //  ② 重置付费墙优化；③ 异步按新账号重新解析店内订阅归属，回填正确结果。
        if changed {
            purchasedProductIDs = []
            latestTransaction = nil
            willAutoRenew = false
            activeProductID = nil
            pendingRenewalProductID = nil
            renewalState = .none
            gracePeriodExpiresAt = nil
            lastKnownSubscribed = isServerMembershipActive || isPremiumTrialActive
            // 店内快照刚被作废，此刻的 paidMembershipTier 只反映新账号的服务端授予，正是该记下的值
            lastKnownPaidTier = paidMembershipTier
            lastKnownYearly = false
            Log.info(logTag, "reconcile: 换账号 current=\(current) previous=\(previous ?? "-") → 服务端会员(本账号)active=\(isServerMembershipActive)，已作废上一账号 StoreKit 快照并重解析")
            Task { await updateSubscriptionStatus() }
        }
        // 让订阅页 / 遮罩重新按归属判定。
        NotificationCenter.default.post(name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
        // 服务端会员状态：换账号强制拉，否则受 10 分钟冷却。
        MembershipStatusService.shared.refresh(reason: changed ? "account-switch" : "launch", force: changed)
    }

    /// 兑换码兑换成功后调用：落地服务端授予的会员等级，并**累加**到期时间，最后广播刷新（解锁会员内容）。
    /// - 累加规则：从「当前到期时间（若仍有效）或现在」起，叠加本次兑换的 `durationDays`
    ///   （365≈年卡、30≈月卡）。即用户连续兑换 2 张月卡 = +30 +30 = 60 天。
    /// - 若服务端没给 `durationDays` 但给了已累加的 `serverEndAt`，则以服务端为准；都没有则保持原到期。
    /// - premiumTrialEndAt: 服务端下发的体验期结束时刻。传 nil 表示「本次响应没带这个字段」，
    ///   **保留已有值不动**（不要当成"体验期已结束"去清空，否则兑换码一兑换就把体验期抹了）。
    func applyServerMembership(level: String, durationDays: Int?, serverEndAt: Date?, premiumTrialEndAt: Date? = nil) {
        guard let uid = AuthStorage.shared.uid?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty else {
            Log.info(logTag, "兑换落地失败：未登录，无法确定归属账号")
            return
        }
        var map = loadServerMap()
        let existing = map[uid]                                   // ★ 只累加到「当前账号自己」的记录，绝不碰别人的
        let now = Date()
        let existingEnd = existing?.end.map { Date(timeIntervalSince1970: $0) }
        let isActive = existingEnd.map { $0 > now } ?? false
        let base = isActive ? (existingEnd ?? now) : now
        let newEnd: Date?
        if let days = durationDays {
            newEnd = Calendar.current.date(byAdding: .day, value: days, to: base)
        } else if let serverEndAt {
            newEnd = serverEndAt
        } else {
            newEnd = existingEnd
        }
        // 周期不降级：会员仍有效时取「历史最大时长」与本次的较大者；已失效则按本次重置。
        let prevMax = isActive ? (existing?.max ?? 0) : 0
        let newMax = max(prevMax, durationDays ?? 0)

        // 体验期：服务端两列取 max 后下发，这里只做「取较晚者」——本次没带就保留旧值，
        // 带了就与旧值比取晚的（防止某个响应回传了过期的第①段而覆盖掉更晚的第②段）。
        let mergedTrialEnd = [existing?.trialEnd, premiumTrialEndAt?.timeIntervalSince1970]
            .compactMap { $0 }.max()

        map[uid] = ServerRecord(level: level, end: newEnd?.timeIntervalSince1970, max: newMax, trialEnd: mergedTrialEnd)
        saveServerMap(map)
        Log.info(logTag, "兑换会员落地：owner=\(uid) level=\(level) maxDays=\(newMax)")

        // 生成「兑换成功」站内消息（并对齐订阅快照，避免随后又冒一条「已开通」）。
        AppNotificationEngine.shared.recordRedeemSuccess(durationDays: durationDays)
        NotificationCenter.default.post(name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
    }

    /// client 模式下把服务端库里的授予等级（兑换码 / 后台赠送）同步进本机按 uid 存的记录。
    ///
    /// 之前这份记录只有 App 内兑换流程会写：换一台手机登录、或本机 Keychain 记录丢了，
    /// 服务端明明说 premium 到 2027 年，App 却按 free 遮罩——真机实测就是这样。兑换本来就在服务端落库，
    /// 服务端是这份等级的事实源，所以两个方向都同步：服务端有效就写入，服务端说 free / 已过期就清掉。
    /// 只动 level / end，max（周期展示）与体验期保持原值。
    private func syncGrantedLevel(fromServer state: ServerMembershipState, uid: String) {
        var map = loadServerMap()
        let existing = map[uid]
        let serverActive = (state.storedLevel == "pro" || state.storedLevel == "premium")
            && (state.levelEndAt.map { $0 > Date() } ?? true)
        let newLevel = serverActive ? state.storedLevel : "free"
        let newEnd = serverActive ? state.levelEndAt?.timeIntervalSince1970 : nil
        guard existing?.level != newLevel || existing?.end != newEnd else { return }
        map[uid] = ServerRecord(level: newLevel, end: newEnd, max: existing?.max ?? 0, trialEnd: existing?.trialEnd)
        saveServerMap(map)
        Log.info(logTag, "服务端授予等级同步到本机：\(existing?.level ?? "-")→\(newLevel) end=\(state.levelEndAt.map { "\($0)" } ?? "-")")
    }

    /// 只落地「高级会员体验期」，**不碰 level / end / max 任何其它字段**。
    ///
    /// 登录响应里带 `premium_trial_end_at` 时调用。之所以不复用 `applyServerMembership`：
    /// 那个方法是为兑换码设计的，会**累加**到期时间并覆盖 `level`；登录每次都调的话会重复累加，
    /// 而且登录响应若没带会员字段（或返回 free），会把用户兑换来的会员直接抹掉。
    ///
    /// ⚠️ 调用点必须在 `AuthStorage.saveLoginInfo` **之后**——记录是按 uid 存的，uid 还没写入时这里会直接返回。
    func applyPremiumTrial(endAt: Date?) {
        guard let endAt else { return }                       // 没带该字段 → 保留旧值，不做任何事
        guard let uid = AuthStorage.shared.uid?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty else {
            Log.info(logTag, "体验期落地失败：未登录，无法确定归属账号")
            return
        }
        var map = loadServerMap()
        var rec = map[uid] ?? ServerRecord(level: "free", end: nil, max: 0)
        let new = endAt.timeIntervalSince1970
        // 取较晚者：防止某个响应回传了较早的一段而覆盖掉更晚的一段。
        guard new > (rec.trialEnd ?? 0) else { return }
        rec.trialEnd = new
        map[uid] = rec
        saveServerMap(map)
        Log.info(logTag, "体验期落地：owner=\(uid) trialEnd=\(endAt)")
        NotificationCenter.default.post(name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
    }

    /// 解析服务端时间字段：兼容秒级时间戳（数字）与 ISO8601 / 常见日期字符串。
    /// nonisolated：调用点在 URLSession 回调 / async 解析里，不在主线程；本方法是纯函数，无状态可争用。
    nonisolated static func parseServerDate(_ value: Any?) -> Date? {
        if let n = value as? NSNumber, n.doubleValue > 0 { return Date(timeIntervalSince1970: n.doubleValue) }
        guard let s = (value as? String)?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if let epoch = Double(s), epoch > 0 { return Date(timeIntervalSince1970: epoch) }
        if let d = ISO8601DateFormatter().date(from: s) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    /// 清空**当前账号**的服务端会员记录（只动当前 uid，不影响其它账号）。目前无调用方，保留备用。
    func clearCachedMembership() {
        lastKnownSubscribed = false
        lastKnownPaidTier = .free
        lastKnownYearly = false
        if let uid = AuthStorage.shared.uid?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty {
            var map = loadServerMap()
            map[uid] = nil
            saveServerMap(map)
        }
        NotificationCenter.default.post(name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
    }

    private override init() {
        super.init()
        // 会员数据一次性迁移：① UserDefaults→Keychain（旧单槽）；② 旧单槽→按 uid 存的 map。
        migrateMembershipToKeychainIfNeeded()
        migrateServerSingleSlotToPerUidIfNeeded()
        // 服务端会员现在按 uid 实时从 Keychain 读（serverLevel/EndAt/Max 均为计算属性），无需在此加载。

        updates = newTransactionListenerTask()
        // Refresh status when app becomes active (e.g. returning from subscription settings)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

        // 冷启动校正**放到下一拍**执行：reconcile 结尾会同步 post "SubscriptionStatusChanged"，
        // 而首个触达 SubscriptionManager.shared 的往往是已注册该通知观察者的 AppNotificationEngine——
        // 若在 init 里同步 post，观察者回调会重入访问尚未初始化完成的 shared，触发 EXC_BREAKPOINT 崩溃。
        // 延后一拍确保 shared 先初始化完成。
        Task { @MainActor [weak self] in self?.reconcileMembershipOwner() }
    }

    deinit {
        updates?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidBecomeActive() {
        Task {
            await updateSubscriptionStatus()
        }
    }
    
    // MARK: - Legacy / Helper Properties for UI
    
    var isSubscribed: Bool {
        #if DEBUG
        if let forced = Self.debugForceMembershipTier { return forced != .free }
        #endif
        // 服务端为准：effective_user_level 已含体验期与 Apple 订阅；刚购买待确认时本地也算。
        if let s = serverState, s.authorityIsServer {
            return Self.tier(from: s.effectiveLevel) != .free || (isLocalPurchasePending && !purchasedProductIDs.isEmpty)
        }
        // 会员 = StoreKit 已购 或 服务端授予（兑换码/赠送）在有效期内 或 处于高级会员体验期。
        // 体验期必须算进来：第①段（注册即送 7 天）的用户没买过任何东西、服务端等级也还是 free，
        // 不算进来的话会被睡眠计划 / Explore 的非会员遮罩挡住，等于体验期白送。
        return !purchasedProductIDs.isEmpty || isServerMembershipActive || isPremiumTrialActive
    }

    /// 是否应该对会员内容上「订阅遮罩」。
    /// - 已是会员（StoreKit 已购 / 服务端兑换 / 上次已知已订阅）：不遮罩。
    /// - 否则立即遮罩：不再等 StoreKit 首次异步解析完成，避免非会员开 App 后迟迟不弹遮罩。
    /// `lastKnownSubscribed` 让「老会员」冷启动期间也不会闪一下遮罩；解析完成会再刷新一次纠正。
    var shouldGatePremiumContent: Bool {
        #if DEBUG
        if let forced = Self.debugForceMembershipTier { return forced == .free }
        #endif
        if isSubscribed || lastKnownSubscribed { return false }
        return true
    }

    /// 会员分级：Premium 系列产品 / 高级会员体验期内 / 服务端 "premium" 授予 → premium；
    /// 原有系列产品 / 服务端 "pro" 授予 → basic；否则 free。用于「睡眠计划」等按等级门禁的功能，`isSubscribed`/
    /// `shouldGatePremiumContent` 这两个既有的二元判断保持不变（继续视 basic/premium 皆为已订阅）。
    var membershipTier: MembershipTier {
        #if DEBUG
        if let forced = Self.debugForceMembershipTier { return forced }
        #endif
        // 服务端为准：直接用服务端算好的生效等级（含体验期）；刚购买待确认时与本地取高者。
        if let s = serverState, s.authorityIsServer {
            let server = Self.tier(from: s.effectiveLevel)
            return isLocalPurchasePending ? Self.maxTier(server, storeKitPaidTier) : server
        }
        // ★ 体验期判断必须排在「已购 Basic」之前：第②段是「买了 Basic 却享受 Premium 能力」，
        //   放在后面的话，买过 Basic 的用户会在 paidMembershipTier 里就返回 .basic，永远走不到这里。
        if paidMembershipTier == .premium { return .premium }
        if isPremiumTrialActive { return .premium }
        return paidMembershipTier
    }

    /// 「真金白银买到 / 服务端授予」的等级，**不含体验期**。
    ///
    /// 订阅页决定「该展示哪些可购买项」必须用这个，不能用 `membershipTier`：体验期内
    /// `membershipTier` 是 `.premium`，拿它去判断的话，第①段（注册即送、一分钱没花）的用户
    /// 会被当成已是最高档，整个套餐区消失——7 天里根本没法付费订阅，直接掐死转化。
    var paidMembershipTier: MembershipTier {
        #if DEBUG
        if let forced = Self.debugForceMembershipTier { return forced }
        #endif
        // 服务端为准：Apple 订阅档位与未过期的库内等级取高者；刚购买待确认时与本地取高者。
        if let s = serverState, s.authorityIsServer {
            let server = Self.tier(from: s.paidLevel)
            return isLocalPurchasePending ? Self.maxTier(server, storeKitPaidTier) : server
        }
        if storeKitPaidTier != .free { return storeKitPaidTier }
        if isServerMembershipActive {
            return serverLevel == "premium" ? .premium : .basic
        }
        return .free
    }

    /// 本地 StoreKit 权益解析出的付费档位（不看服务端、不看体验期）。
    var storeKitPaidTier: MembershipTier {
        if purchasedProductIDs.contains(Constants.Subscription.premiumMonthlyProductID)
            || purchasedProductIDs.contains(Constants.Subscription.premiumYearlyProductID) {
            return .premium
        }
        if purchasedProductIDs.contains(Constants.Subscription.monthlyProductID)
            || purchasedProductIDs.contains(Constants.Subscription.yearlyProductID) {
            return .basic
        }
        return .free
    }

    var currentPlan: SubscriptionType {
        // 高级会员的两个产品也要认——只判普通档的话，买了高级年度的用户会掉到下面的
        // 服务端分支甚至 .free，订阅页上「当前套餐」就落不到正确的那张周期卡上。
        if purchasedProductIDs.contains(Constants.Subscription.yearlyProductID)
            || purchasedProductIDs.contains(Constants.Subscription.premiumYearlyProductID) {
            return .yearly
        } else if purchasedProductIDs.contains(Constants.Subscription.monthlyProductID)
            || purchasedProductIDs.contains(Constants.Subscription.premiumMonthlyProductID) {
            return .monthly
        }
        // 服务端记录的 Apple 订阅（本地 StoreKit 没解析到时，如换机后还没恢复购买）。
        if let sub = serverState?.subscription, sub.isActiveNow, let pid = sub.productID {
            if pid == Constants.Subscription.yearlyProductID || pid == Constants.Subscription.premiumYearlyProductID { return .yearly }
            if pid == Constants.Subscription.monthlyProductID || pid == Constants.Subscription.premiumMonthlyProductID { return .monthly }
        }
        // 服务端兑换会员：按本段累计的最大时长判定年/月（不降级）；时长未知时按月度兜底。
        if isServerMembershipActive {
            return serverMaxDurationDays >= 365 ? .yearly : .monthly
        }
        if let s = serverState, s.authorityIsServer, Self.tier(from: s.paidLevel) != .free {
            return .monthly
        }
        return .free
    }
    
    /// 真实到期时刻。三个来源都没有 → nil（**不要**编一个日期出来）。
    /// 服务端记录不带 end 时 isServerMembershipActive 视作长期有效，此处就是 nil。
    var expiryDateOrNil: Date? {
        // 取 StoreKit 到期 与 服务端兑换累加到期 中较晚者（让订阅页展示累加后的到期日）。
        let storeKit = latestTransaction?.expirationDate
        let server = isServerMembershipActive ? serverLevelEndAt : nil
        // 体验期也要算进来：第①段（注册即送、没买过任何东西）的用户 isSubscribed 为 true，
        // 资料卡会走「已订阅」布局去读这个到期日——不含体验期的话这里返回 nil，
        // 卡片上会显示 0001 年那种荒谬日期。
        let trial = isPremiumTrialActive ? premiumTrialEndAt : nil
        // 服务端记录：Apple 订阅到期 / 库内等级到期（换机、ASSN 续费后本地 StoreKit 还没刷新时仍能显示）。
        var fromServer: [Date] = []
        if let s = serverState {
            if let sub = s.subscription, sub.isActiveNow, let e = sub.expiresAt { fromServer.append(e) }
            if s.authorityIsServer, Self.tier(from: s.storedLevel) != .free, let e = s.levelEndAt, e > Date() { fromServer.append(e) }
        }
        return ([storeKit, server, trial].compactMap { $0 } + fromServer).max()
    }

    var expiryDate: Date {
        expiryDateOrNil ?? Date.distantPast
    }

    /// 当前订阅来自 Xcode StoreKit 配置文件或 App Store 沙盒（即**测试环境**）。
    var isTestStoreEnvironment: Bool {
        guard #available(iOS 16.0, *), let transaction = latestTransaction else { return false }
        return transaction.environment != .production
    }

    /// StoreKit 的 RenewalState + willAutoRenew → 我们的展示状态。
    /// `.subscribed` 还要再按 willAutoRenew 分「会扣款」和「到期即止」两种，
    /// 这两种在界面上的说法是相反的，不能合并。
    private static func renewalState(from state: Product.SubscriptionInfo.RenewalState,
                                     willAutoRenew: Bool) -> SubscriptionRenewalState {
        switch state {
        case .subscribed:           return willAutoRenew ? .autoRenewing : .cancelled
        case .inGracePeriod:        return .inGracePeriod
        case .inBillingRetryPeriod: return .inBillingRetry
        case .expired, .revoked:    return .expired
        default:                    return willAutoRenew ? .autoRenewing : .cancelled
        }
    }

    /// 产品的名义订阅周期。优先读 StoreKit 加载到的真实配置
    /// （测试环境来自 .storekit、正式环境来自 App Store Connect 的 P1M / P1Y 声明），
    /// 产品列表还没加载到时才退回按产品 ID 硬编码。
    private func nominalPeriod(of productID: String) -> DateComponents? {
        if let period = products.first(where: { $0.id == productID })?.subscription?.subscriptionPeriod {
            switch period.unit {
            case .day:   return DateComponents(day: period.value)
            case .week:  return DateComponents(weekOfYear: period.value)
            case .month: return DateComponents(month: period.value)
            case .year:  return DateComponents(year: period.value)
            @unknown default: break
            }
        }
        switch productID {
        case Constants.Subscription.yearlyProductID, Constants.Subscription.premiumYearlyProductID:
            return DateComponents(year: 1)
        case Constants.Subscription.monthlyProductID, Constants.Subscription.premiumMonthlyProductID:
            return DateComponents(month: 1)
        default:
            return nil
        }
    }

    /// 订阅页 / 续订管理页 / 套餐卡展示用的到期日。
    ///
    /// 测试环境（Xcode StoreKit 配置文件、App Store 沙盒）下 Apple 会把订阅周期压缩：
    /// 沙盒是固定的「年订≈1 小时、月订≈5 分钟」，Xcode 配置文件按 Renewal Rate 走。
    /// 于是买了年订，StoreKit 回给的 expirationDate 本来就落在今天，照实显示就成了
    /// 「年订今天到期」——这是环境行为不是算错，但拿来验收 UI 完全没意义。
    /// 所以按「本期购买时间 + 产品名义周期」折算成正式环境该有的到期日。
    ///
    /// ★ 折算**只在 Debug 包**里生效。TestFlight 走的也是 sandbox，`environment` 同样不是
    ///   `.production`——只按环境判断的话，外部测试员的年订 1 小时后真的掉权限，界面却显示
    ///   「明年到期」，误导比压缩日期本身更严重。真人可能看到的包一律显示真实到期时刻。
    var displayExpiryDate: Date? {
        // 宽限期里 expirationDate 已经是过去时间，真正失去权限的是宽限期结束时刻。
        if renewalState == .inGracePeriod, let grace = gracePeriodExpiresAt {
            return grace
        }
        #if DEBUG
        guard isTestStoreEnvironment,
              let transaction = latestTransaction,
              let period = nominalPeriod(of: transaction.productID),
              let nominal = Calendar.current.date(byAdding: period, to: transaction.purchaseDate)
        else { return expiryDateOrNil }
        // 兑换码累加出来的到期日若更晚，仍以更晚者为准。
        return [nominal, expiryDateOrNil].compactMap { $0 }.max()
        #else
        return expiryDateOrNil
        #endif
    }

    /// 到期日文案（原先订阅页 / 续订管理页 / 套餐卡各抄了一份格式化代码）。
    /// 无明确到期日 → "-"，不再退化成 0001 年。只显示到日，不带时分。
    func expiryDisplayText() -> String {
        guard let date = displayExpiryDate else { return "-" }
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// 「日期那一行」的标题 key —— 随续订状态变，值永远是日期。
    ///
    /// 固定写「续期时间」有两个问题：用户已关闭自动续订时含义正好相反；而且「续期」是个
    /// 中性词，看不出那天要扣钱（审核指南 3.1.2 要求订阅界面明确披露扣费）。
    /// 兑换码会员 / 体验期（.none）没有店内续订，按「到期日」显示。
    func expiryRowTitleKey() -> String {
        switch renewalState {
        case .autoRenewing:     return "subscription.date.next_billing"
        case .inGracePeriod:    return "subscription.date.grace"
        case .inBillingRetry:   return "subscription.date.retry"
        case .expired:          return "subscription.date.expired"
        case .cancelled, .none: return "subscription.date.expiry"
        }
    }

    /// 「标题 + 日期」一行式文案（订阅页头卡用）。
    func expiryStatusText() -> String {
        L(expiryRowTitleKey()) + " " + expiryDisplayText()
    }

    var tideDays: Int {
        // 服务端会员时段台账算出的累计天数优先：真正「有会员的天数」之和，跨设备、跨订阅，
        // 中间断掉的不算，兑换码会员也有数。老服务端没下发时才退回按本机 StoreKit 交易算。
        if let days = serverState?.memberDays {
            return days
        }
        guard let transaction = latestTransaction else { return 0 }
        let origID = String(transaction.originalID)
        // 累计天数按「当前账号认领这笔订阅的时间」算——换账号后从新账号订阅那天起算(从 0/1 起)，
        // 而不是 Apple ID 的原始购买日(那是跨 App 账号共享的)。无认领记录才回退到原始购买日。
        let startDate: Date
        if let epoch = loadStoreKitClaimDates()[origID], epoch > 0 {
            startDate = Date(timeIntervalSince1970: epoch)
        } else {
            startDate = transaction.originalPurchaseDate
        }
        let components = Calendar.current.dateComponents([.day], from: startDate, to: Date())
        // Start counting from 1
        return max(1, (components.day ?? 0) + 1)
    }

    // MARK: - StoreKit API
    
    func loadProducts() async {
        let requestedIDs = [
            Constants.Subscription.monthlyProductID,
            Constants.Subscription.yearlyProductID,
            Constants.Subscription.premiumMonthlyProductID,
            Constants.Subscription.premiumYearlyProductID
        ]
        do {
            let storeProducts = try await Product.products(for: requestedIDs)

            // StoreKit 只返回真实存在且状态有效的产品，缺哪个直接说清楚，
            // 否则购买时只会得到一句 "Product not found"，无从判断是全没加载还是缺某档。
            let returnedIDs = storeProducts.map(\.id)
            let missing = requestedIDs.filter { !returnedIDs.contains($0) }
            Log.info(logTag, "loadProducts: requested=\(requestedIDs.count) returned=\(returnedIDs.count) [\(returnedIDs.joined(separator: ","))]")
            if !missing.isEmpty {
                Log.error(logTag, "loadProducts: MISSING \(missing.joined(separator: ","))")
            }

            self.products = storeProducts
            // Post notification to let UI refresh prices
            NotificationCenter.default.post(name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)

            // Also check current entitlements when loading
            await updateSubscriptionStatus()
        } catch {
            Log.error(logTag, "loadProducts failed: \(error.localizedDescription)")
        }
    }
    
    /// 由 App 账号 uid 派生一个**稳定**的 UUID（UUIDv5 = SHA1(namespace + uid)），作为 StoreKit 购买的
    /// `appAccountToken`。Apple 会把它带进交易和服务端通知里；将来服务端对同一 uid 复算同一 UUID
    /// 即可把这笔交易绑到 App 账号（无服务端时零成本铺路，不影响当前逻辑）。
    private func appAccountToken(forUid uid: String) -> UUID? {
        let name = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        // 固定命名空间（任取一个固定 UUID，服务端用同一个复算）。
        let namespace = UUID(uuidString: "3D2B7A10-9E4C-5F8B-8C1D-2A6E4F0B7C93")!
        var hasher = Insecure.SHA1()
        withUnsafeBytes(of: namespace.uuid) { hasher.update(bufferPointer: $0) }
        hasher.update(data: Data(name.utf8))
        var b = Array(hasher.finalize().prefix(16))
        b[6] = (b[6] & 0x0F) | 0x50   // version 5
        b[8] = (b[8] & 0x3F) | 0x80   // variant RFC4122
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    func purchase(_ product: Product) async throws {
        // 把 App 账号盖进这笔交易（appAccountToken），为将来服务端按账号绑定铺路。
        var options: Set<Product.PurchaseOption> = []
        if let token = appAccountToken(forUid: AuthStorage.shared.uid ?? "") {
            options.insert(.appAccountToken(token))
        }
        let result = try await product.purchase(options: options)

        switch result {
        case .success(let verification):
            // Check whether the transaction is verified.
            let transaction = try checkVerified(verification)

            // The transaction is verified. Deliver content to the user.
            // 先信本地：立即解锁并开 24h 待确认窗口（服务端答复前 StoreKit 与服务端取高者）。
            noteLocalPurchase()
            // 谁主动订阅归谁：主动购买 → 强制把归属记到当前账号（即使之前归别人，即接管）。
            await updateSubscriptionStatus(forceClaimCurrentUser: true)

            // 向服务端上报这笔订阅（见 Tools/doc/高级会员体验期接口.md §4）。
            // 这是体验期第②段「首次订阅 Basic 送 7 天 Premium」的唯一触发信号 ——
            // 服务端跟 Apple 之间没有通道（方案 B 的 Server Notifications 尚未上线），
            // 不上报的话这段体验期永远不会发放。
            //
            // 只在这里上报、不在 Transaction.updates 里报：那条路每次自动续费都会走一遍，
            // 而体验期只认「首次订阅」，反复上报除了刷日志没有意义（服务端幂等会挡住）。
            //
            // 档位不在客户端过滤：Premium 产品不触发体验期是**服务端的判定**（§4 处理第 1 条），
            // 而且服务端还要记 original_transaction_id 与 Apple 对账，Premium 那笔同样要报上去。
            // 新版：把 StoreKit 2 的 JWS 凭据整个报上去，服务端离线验签后落库绑定账号（§2.1）。
            let renewalJWS = await renewalInfoJWS(for: transaction)
            SubscriptionReportService.shared.report(
                transaction: transaction,
                signedTransaction: verification.jwsRepresentation,
                signedRenewalInfo: renewalJWS)

            // Always finish a transaction.
            await transaction.finish()

        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    /// - Parameter tier: 默认 `.basic`（原有单档订阅行为不变）。传 `.premium` 购买高级会员系列产品。
    func purchase(type: SubscriptionType, tier: MembershipTier = .basic) {
        let id: String
        switch (tier, type) {
        case (.premium, .yearly): id = Constants.Subscription.premiumYearlyProductID
        case (.premium, _): id = Constants.Subscription.premiumMonthlyProductID
        case (_, .yearly): id = Constants.Subscription.yearlyProductID
        default: id = Constants.Subscription.monthlyProductID
        }
        guard let product = products.first(where: { $0.id == id }) else {
            Log.error(logTag, "purchase aborted: product \(id) not in loaded list [\(products.map(\.id).joined(separator: ","))] (count=\(products.count))")
            return
        }

        Task {
            do {
                try await purchase(product)
            } catch {
                // 原样打出错误类型：沙盒里「Request Canceled」既可能是用户点了取消，也可能是 App Store 自己把
                // 购买请求掐了（换档确认页加载失败等），只看 localizedDescription 分不清。
                Log.error(logTag, "purchase failed for \(id): \(error.localizedDescription) [\(Swift.type(of: error))] \(error)")
                // 用户主动取消不提示；其余错误（网络 / StoreKit 沙盒抽风 / 支付失败）弹出来，别让用户点了没反应。
                if case StoreKitError.userCancelled = error { return }
                if let purchaseError = error as? Product.PurchaseError {
                    Log.error(logTag, "purchase failed detail: \(purchaseError)")
                }
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("SubscriptionPurchaseFailed"), object: nil,
                                                    userInfo: ["message": error.localizedDescription])
                }
            }
        }
    }
    
    func restorePurchases() {
        Task {
            await restore()
        }
    }
    
    func restore() async {
        try? await AppStore.sync()
        // 恢复购买：用户以当前账号「恢复我的订阅」，强制把归属记到当前账号。
        await updateSubscriptionStatus(forceClaimCurrentUser: true)
    }
    
    // For compatibility with old code that calls cancel (Management is usually outside app for StoreKit)
    func openSubscriptionManagement() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            Task {
                try? await AppStore.showManageSubscriptions(in: scene)
                await updateSubscriptionStatus()
            }
        }
    }
    
    // MARK: - Internal Logic

    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Deliver content to the user.
                    await self.updateSubscriptionStatus()

                    // 续费 / 退款 / 家庭共享等也报给服务端（ASSN 之外的第二条路，幂等，乱序由服务端挡）。
                    // 已经到期、又没被撤销的历史续费不报：App 久未启动时 StoreKit 会把攒下的每一期都
                    // 从这里吐出来（沙盒每小时一期，真机实测一次 19 笔），服务端对每笔都只能判 stale
                    // 还要去 Apple 对账一遍；当前有效的那期会由 currentEntitlements 同步兜底。
                    if let expires = transaction.expirationDate, expires < Date(), transaction.revocationDate == nil {
                        Log.info(self.logTag, "跳过已到期的历史交易上报 txn=\(transaction.id) product=\(transaction.productID) expires=\(expires)")
                    } else {
                        let renewalJWS = await self.renewalInfoJWS(for: transaction)
                        SubscriptionReportService.shared.report(
                            transaction: transaction,
                            signedTransaction: result.jwsRepresentation,
                            signedRenewalInfo: renewalJWS)
                    }
                    
                    // Always finish a transaction.
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }

    /// 该笔订阅当前的续订信息 JWS（服务端据此拿到 autoRenewStatus / 宽限期等，交易 JWS 里没有）。
    nonisolated private func renewalInfoJWS(for transaction: Transaction) async -> String? {
        guard let groupID = transaction.subscriptionGroupID,
              let statuses = try? await Product.SubscriptionInfo.status(for: groupID) else { return nil }
        for status in statuses {
            if case .verified(let t) = status.transaction, t.originalID == transaction.originalID {
                return status.renewalInfo.jwsRepresentation
            }
        }
        return nil
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit's verification.
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    /// - Parameter forceClaimCurrentUser: 主动购买/恢复时传 true —— 把当前有效订阅的归属**强制**记到当前账号
    ///   （即使之前被别的账号认领过）。用户此刻以当前账号主动订阅/恢复，理应归当前账号，否则 UI 不解锁。
    @MainActor
    private func updateSubscriptionStatus(forceClaimCurrentUser: Bool = false) async {
        var purchased: Set<String> = []
        var latestTrans: Transaction? = nil
        var isAutoRenewing = false
        
        // 1. Check Entitlements (Current Access)
        //    店内订阅按「归属账号」本地绑定：originalID → ownerUid。只认归属当前账号的那笔，
        //    换 App 账号不继承（无服务端时的过渡方案，解决同设备换账号）。绑定表登出不清、切回原账号仍有效。
        let currentUid = AuthStorage.shared.uid?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var storeKitOwners = loadStoreKitOwners()
        var storeKitClaimDates = loadStoreKitClaimDates()
        var storeKitOwnersChanged = false
        // 服务端为准时归属由服务端按 appAccountToken / 上报裁决，本地归属表不再参与门禁
        //（改造方案 §3.4：切换稳定后整块删掉）。
        let serverDecidesOwnership = entitlementAuthorityIsServer
        var entitlementsToSync: [(Transaction, String)] = []
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if transaction.productType == .autoRenewable || transaction.productType == .nonRenewable {
                    entitlementsToSync.append((transaction, result.jwsRepresentation))
                    if transaction.revocationDate == nil {
                         let origID = String(transaction.originalID)
                         // 谁主动订阅归谁：
                         //  - 被动解析(冷启动/回前台/换账号登录)**绝不认领** → 新账号登录不会自动继承上一账号订阅；
                         //  - 主动购买/恢复(force)则**强制把归属改到当前账号**（即使之前归别人）→ 当前账号可主动订阅/接管。
                         //  - 交易上的 appAccountToken 就是购买时登录的账号：等于当前账号 → 本来就是本账号买的，直接认领。
                         //    purchase() 偶尔会在 Apple 那边交易已成立后仍抛错（沙盒实测 "Unable to Complete Request"），
                         //    这时 force 那条路走不到，交易只会从 Transaction.updates 被动送来；没这条规则就会被判成
                         //    「不属于当前账号」→ 用户付了钱却没解锁、也没任何提示。
                         let tokenClaim = !currentUid.isEmpty && transaction.appAccountToken != nil
                             && transaction.appAccountToken == appAccountToken(forUid: currentUid)
                         if forceClaimCurrentUser || tokenClaim, !currentUid.isEmpty, storeKitOwners[origID] != currentUid {
                             storeKitOwners[origID] = currentUid
                             // 归属换到当前账号 → 累计天数从此刻起算（新账号订阅后从 0/1 天开始）。
                             storeKitClaimDates[origID] = Date().timeIntervalSince1970
                             storeKitOwnersChanged = true
                             Log.info(logTag, "StoreKit 订阅认领归属(\(forceClaimCurrentUser ? "主动购买" : "appAccountToken 匹配"))：origID=\(origID) owner=\(currentUid) product=\(transaction.productID)")
                         }
                         // **只认归属当前账号的订阅**。未绑定或归属别人 → 跳过、不计入（登录不继承）。
                         guard serverDecidesOwnership || (storeKitOwners[origID] == currentUid && !currentUid.isEmpty) else {
                             Log.info(logTag, "StoreKit 订阅不属于当前账号，跳过：origID=\(origID) owner=\(storeKitOwners[origID] ?? "-") current=\(currentUid)")
                             continue
                         }
                         purchased.insert(transaction.productID)

                         // Keep track of the transaction with the latest expiration date
                         if latestTrans == nil || (transaction.expirationDate ?? Date.distantPast) > (latestTrans?.expirationDate ?? Date.distantPast) {
                             latestTrans = transaction
                         }
                    }
                }
            } catch {
                print("Failed to verify transaction")
            }
        }
        if storeKitOwnersChanged {
            saveStoreKitOwners(storeKitOwners)
            saveStoreKitClaimDates(storeKitClaimDates)
        }
        
        // 2. Check Auto-Renew Status
        // We only care about auto-renew status if user has a valid subscription
        var pendingProductID: String? = nil
        var resolvedRenewalState: SubscriptionRenewalState = .none
        var graceExpiry: Date? = nil
        if let transaction = latestTrans, let groupID = transaction.subscriptionGroupID {
            do {
                let statuses = try await Product.SubscriptionInfo.status(for: groupID)
                for status in statuses {
                    guard case .verified(let renewalInfo) = status.renewalInfo else { continue }
                    // 一个订阅组里可能有多条状态（换过档、家庭共享等），只认当前持有的那笔，
                    // 否则会把别人/旧订阅的续订状态显示到当前订阅上。
                    if case .verified(let statusTrans) = status.transaction,
                       statusTrans.originalID != transaction.originalID {
                        continue
                    }
                    if renewalInfo.willAutoRenew {
                        isAutoRenewing = true
                    }
                    // 下个周期实际会续订的产品。和当前持有的不一致 = 用户换过档但还没到生效时间。
                    if let pref = renewalInfo.autoRenewPreference, pref != transaction.productID {
                        pendingProductID = pref
                    }
                    resolvedRenewalState = Self.renewalState(from: status.state,
                                                             willAutoRenew: renewalInfo.willAutoRenew)
                    graceExpiry = renewalInfo.gracePeriodExpirationDate
                }
            } catch {
                print("Failed to fetch subscription status: \(error)")
            }
        }

        self.purchasedProductIDs = purchased
        self.latestTransaction = latestTrans
        self.willAutoRenew = isAutoRenewing
        self.activeProductID = latestTrans?.productID
        self.pendingRenewalProductID = pendingProductID
        self.renewalState = resolvedRenewalState
        self.gracePeriodExpiresAt = graceExpiry
        self.hasResolvedStatus = true
        // 落地本次解析结果，供下次冷启动即时决定是否上遮罩。
        self.lastKnownSubscribed = !purchased.isEmpty || isServerMembershipActive || isPremiumTrialActive
        self.lastKnownPaidTier = paidMembershipTier
        self.lastKnownYearly = currentPlan == .yearly

        Log.info(logTag, "StoreKit 解析完成 purchased=[\(purchased.sorted().joined(separator: ","))] autoRenew=\(isAutoRenewing) authority=\(entitlementAuthorityIsServer ? "server" : "client") pendingLocal=\(isLocalPurchasePending) next=\(pendingProductID ?? "-") state=\(resolvedRenewalState)")
        NotificationCenter.default.post(name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)

        // 把当前全部权益的 JWS 报给服务端（每账号每天最多一次）：存量订阅 / 换机恢复 / 重装
        // 都靠这一步补进服务端（改造方案 §2.5），不用等 Apple 通知。
        if !currentUid.isEmpty, !entitlementsToSync.isEmpty {
            var renewals: [String: String] = [:]
            for (t, _) in entitlementsToSync where renewals[String(t.originalID)] == nil {
                if let jws = await renewalInfoJWS(for: t) { renewals[String(t.originalID)] = jws }
            }
            SubscriptionReportService.shared.syncEntitlementsIfDue(
                entitlementsToSync.map { (t, jws) in (t, jws, renewals[String(t.originalID)]) }, uid: currentUid)
        }
    }
    
    // Compatibility method for the old 'cancelSubscription' which likely just meant clearing verify status in mock
    // In real StoreKit, you can't cancel from app, only link to management.
    func cancelSubscription() {
        openSubscriptionManagement()
    }
}

enum StoreError: Error {
    case failedVerification
}
