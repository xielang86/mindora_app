//
//  AppNotificationCenter.swift
//  mindora
//
//  站内「消息通知」的数据生成 + 存储中枢。
//
//  取代 NotificationsViewController 里写死的 DEBUG mock：根据 App 的真实运行状态
//  （订阅到期/开通/兑换、通知权限、睡眠评分、佩戴断签）动态生成消息，落地本地后
//  喂给消息列表；同时驱动 UnreadBadgeCenter 的未读红点。
//
//  设计核心 —— 静默 / 冷却机制（避免重复打扰）：
//  每条消息在写入前都要过两道闸：
//    1. 去重（dedupKey）：同一事件只生成一次。store 里已存在相同 dedupKey 就直接丢弃。
//    2. 冷却（per-category cooldown）：持续性提醒（权限关闭/评分低/佩戴断签）只有在
//       「距上次同类触发 ≥ 冷却窗口」时才允许再次生成。
//  两道闸叠加 → 绝不会一直循环产生重复消息。
//

import Foundation
import UIKit
import UserNotifications

// MARK: - 分类

/// 消息分类。新增一类通知 = 加一个 case + 一条规则（Engine）+ 几条译文，即可扩展。
enum AppNotificationCategory: String, Codable, CaseIterable {
    // —— 订阅 / 会员（离散状态跃迁，dedupKey 幂等即可） ——
    case subscriptionExpiring   // 即将到期（到期前 7 天内）
    case subscriptionExpired    // 已到期
    case subscriptionActivated  // 购买 / 续订成功（含续订，用 params["renewed"] 区分文案）
    case redeemSuccess          // 兑换码兑换成功

    // —— 持续性提醒（必须冷却，见文件头） ——
    case permissionDisabled     // 系统通知权限被关闭
    case sleepScoreLow          // 最近一晚睡眠评分偏低
    case wearGap                // 已连续多日无睡眠数据（未佩戴 / 未同步）

    // —— 运营 ——
    case survey                 // 参与调研邀请（服务端下发，点击进入问卷）
    case promo                  // 商城活动 / 广告等运营弹窗（服务端 push_message 控制是否落地）

    /// 点击消息后的跳转路由。
    var route: NotificationType {
        switch self {
        case .subscriptionExpiring, .subscriptionExpired, .subscriptionActivated, .redeemSuccess:
            return .subscription
        case .permissionDisabled:
            return .settings
        case .sleepScoreLow, .wearGap:
            return .health
        case .survey:
            return .survey
        case .promo:
            return .promo
        }
    }

    /// 是否是服务端 `query_popups` 下发的消息。
    ///
    /// 只有这两类需要跨登出保留状态（收到过、读没读）—— 它们的内容在服务端，
    /// 本地清掉后要靠 AccountVault 的清单去要回来。
    ///
    /// 其余几类是引擎按 App 当前运行状态**重新生成**的（订阅还有几天到期、昨晚评分多少、
    /// 连续几天没佩戴、通知权限关没关），本地没了就该重新评估一遍，把它们的已读状态
    /// 记进清单反而会出错：登出后引擎重新生成的是一条新事件，却因为 dedupKey 撞上
    /// 旧记录被判成已读，用户就永远看不到红点了。
    var isServerPopup: Bool {
        switch self {
        case .survey, .promo: return true
        default: return false
        }
    }

    /// 图标旁的来源标签（会员消息 / 系统消息 / 睡眠提醒 / 参与调研）。
    var sourceLabelKey: String {
        switch self {
        case .subscriptionExpiring, .subscriptionExpired, .subscriptionActivated, .redeemSuccess:
            return "notifications.source.membership"
        case .permissionDisabled:
            return "notifications.source.system"
        case .sleepScoreLow, .wearGap:
            return "notifications.source.health"
        case .survey:
            return "notifications.source.survey"
        case .promo:
            return "notifications.source.promo"
        }
    }
}

// MARK: - 数据模型

/// 一条落地消息。存原始 category + params，展示时再本地化 —— 语言切换后仍能正确重渲染。
struct AppNotification: Codable, Equatable {
    let id: String
    let category: AppNotificationCategory
    let createdAt: Date
    /// 去重键：同一事件实例唯一。store 已含相同键则不再写入。
    let dedupKey: String
    /// 渲染参数（如 days / score / expiryEpoch），文案在展示时 String(format:) 填充。
    let params: [String: String]
    var isRead: Bool
}

// MARK: - 存储 + 冷却簿记

/// 消息的持久化仓库 + 冷却/去重簿记。全部在主线程访问（Engine 是 @MainActor）。
final class AppNotificationStore {
    static let shared = AppNotificationStore()

    /// 列表 / 红点据此刷新。
    static let didChangeNotification = Notification.Name("AppNotificationStore.didChange")

    /// 「当前消息」窗口：createdAt 在最近 3 天内算当前，其余归入「历史消息」。
    private let currentWindow: TimeInterval = 3 * 86400
    /// 最多保留条数，超出丢弃最旧的。
    private let maxCount = 60

    private let storeKey = "app.notifications.v1"
    private let cooldownKeyPrefix = "app.notifications.cooldown."
    private let defaults = UserDefaults.standard

    private(set) var all: [AppNotification] = []

    private init() {
        load()
    }

    // MARK: 读写

    private func load() {
        guard let data = defaults.data(forKey: storeKey),
              let decoded = try? JSONDecoder().decode([AppNotification].self, from: data) else {
            all = []
            return
        }
        // 清掉历史遗留的 DEBUG 样例（dedupKey 以 "debug." 开头），以及早期客户端内置的
        // mock 参与调研消息（"survey.mock_survey"）—— 问卷现全部由服务端下发。真实消息不受影响。
        let filtered = decoded.filter {
            !$0.dedupKey.hasPrefix("debug.") && $0.dedupKey != "survey.mock_survey"
        }
        all = filtered.sorted { $0.createdAt > $1.createdAt }
        if filtered.count != decoded.count { persist() }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: storeKey)
        }
    }

    /// 已存在该去重键？
    func contains(dedupKey: String) -> Bool {
        all.contains { $0.dedupKey == dedupKey }
    }

    /// 本地现存的、来自服务端弹窗的 popup_id 集合。
    /// 恢复时用它跟 Keychain 清单做差集，只向服务端要缺的那几条。
    func presentPopupIds() -> Set<String> {
        Set(all.compactMap { $0.category.isServerPopup ? $0.params["popupId"] : nil })
    }

    /// 生成并写入一条消息。命中去重则返回 false（不写、不亮红点）。
    ///
    /// - Parameters:
    ///   - createdAt: 消息的生成时间，缺省「现在」。**恢复历史消息时必须传服务端的 `delivered_at`**：
    ///     否则重新登录后恢复出来的旧消息时间全变成「刚刚」，几个月前的活动会一股脑挤进
    ///     「当前消息」分组（分组阈值见 `currentWindow`）。
    ///   - markUnread: 是否按未读写入，缺省 true。注意**已读清单优先** ——
    ///     这条消息若在 `AccountVault.readMessages` 里（用户登出前读过），一律写成已读、不亮红点。
    /// - Returns: 是否真的写入。
    @discardableResult
    func add(_ category: AppNotificationCategory,
             dedupKey: String,
             params: [String: String] = [:],
             createdAt: Date = Date(),
             markUnread: Bool = true) -> Bool {
        guard !contains(dedupKey: dedupKey) else { return false }

        // 已读状态存 AccountVault（按账号邮箱隔离、登出不清），所以「登出前读过的消息」
        // 重新登录恢复回来时仍是已读，不会重新亮红点打扰用户。
        // 只对服务端下发的两类生效，原因见 AppNotificationCategory.isServerPopup。
        let isRead = !markUnread
            || (category.isServerPopup && AccountVault.readMessages.contains(dedupKey))

        let item = AppNotification(
            id: UUID().uuidString,
            category: category,
            createdAt: createdAt,
            dedupKey: dedupKey,
            params: params,
            isRead: isRead
        )
        all.insert(item, at: 0)
        // createdAt 可能来自服务端（历史恢复），插到队首不再天然有序，必须重排。
        all.sort { $0.createdAt > $1.createdAt }
        // 超上限淘汰最旧的。**不动 AccountVault 清单** —— 那里存的只是 ID（一条几十字节），
        // 而 maxCount 限的是消息体的显示条数，两回事。因为消息体被挤掉就把 ID 永久删了，
        // 等于拿廉价资源去迁就昂贵资源的限制，而且不可逆：用户清掉几条腾出位置后，
        // 这些消息本该还能恢复回来。只有用户主动删除才摘 ID。
        if all.count > maxCount { all.removeLast(all.count - maxCount) }
        persist()

        // 有新消息 → 三处红点亮起（Sleep / 洞察铃铛 / 侧边栏）。
        if !isRead { UnreadBadgeCenter.shared.markUnread() }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        return true
    }

    /// 用户在消息列表里删除一条。
    ///
    /// 运营类消息（survey / promo）还要把对应的 popup_id 从清单里移除，
    /// 否则下次登录「按 popup_id 拉」会把用户刚删掉的这条又拉回来。
    /// 删除是纯本地行为，不通知服务端。
    func remove(id: String) {
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        let item = all.remove(at: index)
        if item.category.isServerPopup {
            if let popupId = item.params["popupId"] {
                AccountVault.popupIds.remove(popupId)
            }
            // 已读清单里的对应项也摘掉，免得清单随使用无限增长。
            AccountVault.readMessages.remove(item.dedupKey)
        }
        persist()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        Log.info("AppNotificationStore", "删除消息 dedupKey=\(item.dedupKey)")
    }

    /// 清空全部站内消息 + 冷却记录 + 红点。用于登出 / 注销账号，避免上一账号消息残留。
    func clear() {
        all = []
        defaults.removeObject(forKey: storeKey)
        for category in AppNotificationCategory.allCases {
            defaults.removeObject(forKey: cooldownKeyPrefix + category.rawValue)
        }
        UnreadBadgeCenter.shared.markAllRead()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// 用户浏览过消息列表后：把落地消息全部标记已读（红点由 UnreadBadgeCenter 单独清）。
    ///
    /// 已读状态同时写进 Keychain 清单，这样登出重登、换设备恢复回来的消息仍是已读。
    func markAllRead() {
        guard all.contains(where: { !$0.isRead }) else { return }
        // 只记服务端下发的那两类；本地生成的消息状态不进 Keychain。
        for item in all where !item.isRead && item.category.isServerPopup {
            AccountVault.readMessages.insert(item.dedupKey)
        }
        all = all.map { var m = $0; m.isRead = true; return m }
        persist()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }


    /// 当前消息 / 历史消息分组（均按时间倒序）。
    func sections() -> (current: [AppNotification], history: [AppNotification]) {
        let threshold = Date().addingTimeInterval(-currentWindow)
        let current = all.filter { $0.createdAt >= threshold }
        let history = all.filter { $0.createdAt < threshold }
        return (current, history)
    }

    // MARK: 冷却簿记（静默机制）

    /// 距上次某类触发是否已过冷却窗口。无记录视为可触发。
    func canFire(_ category: AppNotificationCategory, cooldown: TimeInterval) -> Bool {
        guard let last = lastFired(category) else { return true }
        return Date().timeIntervalSince(last) >= cooldown
    }

    /// 记录某类刚刚触发（仅在真正写入消息后调用）。
    func recordFired(_ category: AppNotificationCategory) {
        defaults.set(Date().timeIntervalSince1970, forKey: cooldownKeyPrefix + category.rawValue)
    }

    private func lastFired(_ category: AppNotificationCategory) -> Date? {
        let t = defaults.double(forKey: cooldownKeyPrefix + category.rawValue)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
}

// MARK: - 生成引擎（规则）

/// 观察 App 运行事件 → 依规则生成消息。所有规则都经 store 的去重 + 冷却双闸。
@MainActor
final class AppNotificationEngine {
    static let shared = AppNotificationEngine()

    // —— 可调阈值 ——
    private let expiringWindowDays = 7           // 到期前几天开始提醒
    private let lowScoreThreshold = 60           // 睡眠评分低于此值算「偏低」
    private let wearGapDays = 3                   // 连续无数据达到几天算「断签」
    private let permissionCooldown: TimeInterval = 7 * 86400   // 通知权限提醒：最快 7 天一次
    private let nudgeCooldown: TimeInterval = 3 * 86400        // 评分低 / 断签：最快 3 天一次

    // —— 订阅快照（检测状态跃迁）——
    private let snapHasKey = "app.notifications.sub.hasSnapshot"
    private let snapSubKey = "app.notifications.sub.wasSubscribed"
    private let snapExpiryKey = "app.notifications.sub.lastExpiryEpoch"
    private let launchedBeforeKey = "app.notifications.launchedBefore"

    private let store = AppNotificationStore.shared
    private let defaults = UserDefaults.standard
    private var started = false

    private init() {}

    /// 清空消息生成引擎的账号态快照（订阅快照 / 首启标记）。用于登出 / 注销账号，
    /// 避免用上一账号的订阅状态误判、误发提醒。
    func reset() {
        defaults.removeObject(forKey: snapHasKey)
        defaults.removeObject(forKey: snapSubKey)
        defaults.removeObject(forKey: snapExpiryKey)
        defaults.removeObject(forKey: launchedBeforeKey)
    }

    /// 在 AppDelegate.didFinishLaunching 调用一次。
    func start() {
        guard !started else { return }
        started = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(onSubscriptionChanged),
            name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(onDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(onHealthAuthChanged),
            name: HealthDataManager.authorizationDidChangeNotification, object: nil)

        evaluateAll()

        // 首次启动结束：之后的会话才允许弹「持续性提醒」，避免刚装就被打扰。
        defaults.set(true, forKey: launchedBeforeKey)
    }

    // MARK: 事件入口

    @objc private func onSubscriptionChanged() { evaluateSubscription() }
    @objc private func onDidBecomeActive() { evaluateAll() }
    @objc private func onHealthAuthChanged() { evaluateNudges() }

    private func evaluateAll() {
        evaluateSubscription()
        evaluateNudges()
    }

    // MARK: 调研邀请入口（由 PopupService 在下发调研弹窗时调用）

    /// 记录一条「参与调研」站内消息，点击可进入问卷。按 surveyId 去重，避免重复冒泡。
    /// - Parameters:
    ///   - surveyId: 问卷 ID，点击消息据此打开对应问卷。
    ///   - title/subtitle: 展示文案（服务端下发，直接落地存储）。
    ///   - expiry: 有效期（可空），展示「有效期至 …」。
    /// - Parameter isRestore: 是否来自「登录后从服务端恢复历史消息」。
    ///   这个区分很重要：常规下发时，已答过的问卷不该再邀请一次（拦掉）；
    ///   但恢复时必须放行 —— 用户答过的那条消息本来就在消息篮里躺着（按钮显示为
    ///   「已完成」置灰），登出重登后应该原样回来，而不是整条凭空消失。
    func recordSurveyInvite(popupId: String, surveyId: String, title: String, subtitle: String,
                            expiry: Date?, deliveredAt: Date? = nil, isRestore: Bool = false) {
        // 已提交过的问卷不再主动邀请；恢复历史消息除外，见上。
        if !isRestore, SurveyService.shared.hasSubmitted(surveyId: surveyId) { return }
        // popupId 必须落进 params：用户删这条消息时要凭它把 ID 从 Keychain 清单里摘掉。
        var params: [String: String] = [
            "popupId": popupId, "surveyId": surveyId, "title": title, "subtitle": subtitle
        ]
        if let expiry { params["expiryEpoch"] = String(Int(expiry.timeIntervalSince1970)) }
        store.add(.survey, dedupKey: "survey.\(surveyId)", params: params,
                  createdAt: deliveredAt ?? Date())
    }

    // MARK: 运营弹窗入口（商城活动 / 广告等，由 PopupService 在 push_message=true 时调用）

    /// 记录一条「运营活动」站内消息，点击按弹窗自身的 action 跳转（URL / 路由 / 问卷）。
    /// 按 popupId 去重，避免同一弹窗重复落地。文案与跳转参数全部来自服务端弹窗下发。
    func recordPromo(popupId: String, title: String, subtitle: String,
                     actionText: String, actionType: String,
                     url: String?, route: String?, surveyId: String?,
                     deliveredAt: Date? = nil) {
        var params: [String: String] = [
            "popupId": popupId,
            "title": title,
            "subtitle": subtitle,
            "actionText": actionText,
            "actionType": actionType
        ]
        if let url, !url.isEmpty { params["url"] = url }
        if let route, !route.isEmpty { params["route"] = route }
        if let surveyId, !surveyId.isEmpty { params["surveyId"] = surveyId }
        store.add(.promo, dedupKey: "promo.\(popupId)", params: params,
                  createdAt: deliveredAt ?? Date())
    }

    // MARK: 兑换码入口（由 SubscriptionManager.applyServerMembership 调用）

    /// 兑换码兑换成功后生成一条消息，并同步订阅快照 —— 这样随后的 SubscriptionStatusChanged
    /// 不会再把同一次变化重复识别为「购买成功」。
    func recordRedeemSuccess(durationDays: Int?) {
        let mgr = SubscriptionManager.shared
        // 展示与判定统一用 displayExpiryDate：正式环境它就等于真实到期日；
        // 测试环境（沙盒/StoreKit 配置文件）下则是按名义周期折算的日期——否则
        // 消息里「有效期至」显示的还是被压缩的当天日期（同订阅页 8185f6b 修复）。
        let expiry = mgr.displayExpiryDate ?? mgr.expiryDate
        let days = durationDays ?? 0
        var params = expiryParam(expiry)
        if days > 0 { params["days"] = String(days) }
        store.add(.redeemSuccess, dedupKey: "redeem.\(dayEpoch(expiry)).\(days)", params: params)

        // 兑换即已把快照对齐到最新，避免评估订阅时又冒一条「已开通」。
        seedSnapshot(isSubscribed: mgr.isSubscribed, expiry: expiry)
    }

    // MARK: 订阅规则

    private func evaluateSubscription() {
        let mgr = SubscriptionManager.shared
        // StoreKit 权益首解析完成前不评估，避免把「尚未解析」误判成到期/未开通。
        guard mgr.hasResolvedStatus else { return }

        let isSub = mgr.isSubscribed
        // 同 recordRedeemSuccess：用展示口径的到期日。正式环境等于真实值；测试环境下
        // 避免两个假象——消息里「有效期至今天」、以及年订刚买就误报「即将到期」
        // （沙盒把年订压成 1 小时，真实到期永远落在 7 天窗口内）。
        // 快照存的也是同一口径，前后比较自洽。
        let expiry = mgr.displayExpiryDate ?? mgr.expiryDate
        let now = Date()

        // 首次运行只播种快照，不生成消息（升级安装不该凭空冒一条）。
        guard defaults.bool(forKey: snapHasKey) else {
            seedSnapshot(isSubscribed: isSub, expiry: expiry)
            return
        }

        let wasSub = defaults.bool(forKey: snapSubKey)
        let lastExpiry = Date(timeIntervalSince1970: defaults.double(forKey: snapExpiryKey))

        // ① 即将到期：会员有效且到期在窗口内。dedupKey 含到期日 → 每个到期周期只提醒一次。
        if isSub, expiry > now, expiry.timeIntervalSince(now) <= Double(expiringWindowDays) * 86400 {
            let days = max(1, Int(ceil(expiry.timeIntervalSince(now) / 86400)))
            store.add(.subscriptionExpiring,
                      dedupKey: "sub.expiring.\(dayEpoch(expiry))",
                      params: ["days": String(days),
                               "expiryEpoch": String(Int(expiry.timeIntervalSince1970))])
        }

        // ② 开通 / 续订成功
        if !wasSub, isSub {
            store.add(.subscriptionActivated,
                      dedupKey: "sub.activated.\(dayEpoch(expiry))",
                      params: expiryParam(expiry))
        } else if wasSub, isSub, expiry.timeIntervalSince(lastExpiry) > 86400 {
            // 仍是会员但到期日往后延 → 续订。
            store.add(.subscriptionActivated,
                      dedupKey: "sub.renewed.\(dayEpoch(expiry))",
                      params: expiryParam(expiry).merging(["renewed": "1"]) { a, _ in a })
        }

        // ③ 已到期：之前是会员，现在不是。dedupKey 含刚过去的到期日 → 只提醒一次。
        if wasSub, !isSub {
            store.add(.subscriptionExpired,
                      dedupKey: "sub.expired.\(dayEpoch(lastExpiry))")
        }

        seedSnapshot(isSubscribed: isSub, expiry: expiry)
    }

    private func seedSnapshot(isSubscribed: Bool, expiry: Date) {
        defaults.set(true, forKey: snapHasKey)
        defaults.set(isSubscribed, forKey: snapSubKey)
        defaults.set(expiry.timeIntervalSince1970, forKey: snapExpiryKey)
    }

    // MARK: 持续性提醒规则（冷却把守）

    private func evaluateNudges() {
        // 首次启动不打扰。
        guard defaults.bool(forKey: launchedBeforeKey) else { return }
        evaluatePermissionNudge()
        evaluateSleepScoreNudge()
        evaluateWearGapNudge()
    }

    /// 通知权限被用户主动关闭（.denied）→ 温和提醒。7 天冷却。
    /// （.notDetermined「从未询问」不算 —— 交给消息页自带的权限请求 UI 处理。
    ///   健康读取权限 iOS 无法可靠探测，改由「佩戴断签」这一实际症状覆盖。）
    private func evaluatePermissionNudge() {
        guard store.canFire(.permissionDisabled, cooldown: permissionCooldown) else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .denied else { return }
            DispatchQueue.main.async {
                guard let self = self,
                      self.store.canFire(.permissionDisabled, cooldown: self.permissionCooldown) else { return }
                if self.store.add(.permissionDisabled, dedupKey: "perm.off.\(self.dayEpoch(Date()))") {
                    self.store.recordFired(.permissionDisabled)
                }
            }
        }
    }

    /// 最近一晚睡眠评分偏低 → 提醒查看。按当晚去重（同一晚只一次）+ 3 天冷却（连续低分也不连轰）。
    private func evaluateSleepScoreNudge() {
        guard store.canFire(.sleepScoreLow, cooldown: nudgeCooldown) else { return }
        guard let anchor = HealthDataManager.shared.cachedMostRecentSleepDay,
              let score = HealthAnalysisService.shared.cachedDayAnalysis(date: anchor)?.scoreSummary?.score,
              score < lowScoreThreshold else { return }
        if store.add(.sleepScoreLow, dedupKey: "sleep.low.\(dayEpoch(anchor))", params: ["score": String(score)]) {
            store.recordFired(.sleepScoreLow)
        }
    }

    /// 已连续多日无睡眠数据 → 提醒佩戴。按该段缺口的最后有数据日去重（每段缺口只一次）+ 3 天冷却。
    private func evaluateWearGapNudge() {
        guard store.canFire(.wearGap, cooldown: nudgeCooldown) else { return }
        // 从未解析出最近睡眠日（全新用户）→ 不打扰。
        guard let last = HealthDataManager.shared.cachedMostRecentSleepDay else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let days = Calendar.current.dateComponents([.day], from: last, to: today).day ?? 0
        guard days >= wearGapDays else { return }
        if store.add(.wearGap, dedupKey: "weargap.\(dayEpoch(last))", params: ["days": String(days)]) {
            store.recordFired(.wearGap)
        }
    }

    // MARK: 工具

    /// 归一到「当天 0 点」的 epoch 秒，作为 dedupKey 的稳定日期部件。
    private func dayEpoch(_ date: Date) -> Int {
        Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970)
    }

    /// 到期日参数：仅当到期在未来时才带上，避免服务端会员无到期日（distantPast）时展示成 1970/元年乱码。
    private func expiryParam(_ expiry: Date) -> [String: String] {
        expiry > Date() ? ["expiryEpoch": String(Int(expiry.timeIntervalSince1970))] : [:]
    }
}

// MARK: - 渲染（AppNotification → 列表用的 NotificationModel）

extension AppNotification {

    /// 展示时才本地化 —— 语言切换后重新渲染即得对应语言文案。
    func displayModel() -> NotificationModel {
        let source = L(category.sourceLabelKey)
        let dateText = Self.dateText(createdAt)
        let title: String
        let body: String
        let action: String
        var routePayload: [String: String]? = nil

        switch category {
        case .subscriptionExpiring:
            title = L("notifications.subscription.expiring.title")
            body = String(format: L("notifications.subscription.expiring.body"), intParam("days"))
            action = L("notifications.subscription.expiring.action")

        case .subscriptionExpired:
            title = L("notifications.subscription.expired.title")
            body = L("notifications.subscription.expired.body")
            action = L("notifications.subscription.expired.action")

        case .subscriptionActivated:
            if params["renewed"] == "1" {
                title = L("notifications.subscription.renewed.title")
                body = String(format: L("notifications.subscription.renewed.body"), expiryText())
                action = L("notifications.subscription.renewed.action")
            } else {
                title = L("notifications.subscription.activated.title")
                body = String(format: L("notifications.subscription.activated.body"), expiryText())
                action = L("notifications.subscription.activated.action")
            }

        case .redeemSuccess:
            title = L("notifications.redeem.title")
            if let days = params["days"], let d = Int(days), d > 0 {
                body = String(format: L("notifications.redeem.body_days"), d, expiryText())
            } else {
                body = String(format: L("notifications.redeem.body"), expiryText())
            }
            action = L("notifications.redeem.action")

        case .permissionDisabled:
            title = L("notifications.permission.off.title")
            body = L("notifications.permission.off.body")
            action = L("notifications.permission.off.action")

        case .sleepScoreLow:
            title = L("notifications.sleep.low.title")
            body = String(format: L("notifications.sleep.low.body"), intParam("score"))
            action = L("notifications.sleep.low.action")

        case .wearGap:
            title = String(format: L("notifications.weargap.title"), intParam("days"))
            body = String(format: L("notifications.weargap.body"), intParam("days"))
            action = L("notifications.weargap.action")

        case .survey:
            // 文案由服务端下发并落地存储。参与调研用独立卡片样式（填写问卷按钮 + 有效期），
            // 有效期作为独立字段传给 cell，不再拼进正文。
            title = params["title"] ?? L("notifications.survey.title")
            body = params["subtitle"] ?? ""
            action = L("notifications.survey.action")
            var payload = ["surveyId": params["surveyId"] ?? ""]
            if let s = params["expiryEpoch"], let t = TimeInterval(s) {
                let expiryText = Self.formatted(Date(timeIntervalSince1970: t), template: "MMMdHmm")
                payload["validUntil"] = String(format: L("notifications.survey.valid_until"), expiryText)
            }
            routePayload = payload

        case .promo:
            // 运营弹窗（商城活动 / 广告）文案由服务端下发并落地；点击按存下的 action 跳转。
            title = params["title"] ?? ""
            body = params["subtitle"] ?? ""
            action = params["actionText"] ?? L("notifications.promo.action")
            routePayload = [
                "actionType": params["actionType"] ?? "",
                "url": params["url"] ?? "",
                "route": params["route"] ?? "",
                "surveyId": params["surveyId"] ?? ""
            ]
        }

        return NotificationModel(
            id: id,
            type: category.route,
            date: dateText,
            title: source,
            subtitle: title,
            body: body,
            actionText: action,
            routePayload: routePayload
        )
    }

    private func intParam(_ key: String) -> Int { Int(params[key] ?? "") ?? 0 }

    /// 到期日按当前语言本地化（中长日期）。
    private func expiryText() -> String {
        guard let s = params["expiryEpoch"], let t = TimeInterval(s) else { return "--" }
        return Self.formatted(Date(timeIntervalSince1970: t), template: "yMMMd")
    }

    /// 消息时间：如「6月17日 05:03」/「Jun 17, 5:03 AM」，随语言本地化。
    private static func dateText(_ date: Date) -> String {
        formatted(date, template: "MMMdHmm")
    }

    /// 每次按「当前 App 语言」构造格式器 —— 语言切换后重新渲染即得对应语言（列表短，成本可忽略）。
    private static func formatted(_ date: Date, template: String) -> String {
        let f = DateFormatter()
        f.locale = LocalizationManager.shared.currentLocale
        f.setLocalizedDateFormatFromTemplate(template)
        return f.string(from: date)
    }
}
