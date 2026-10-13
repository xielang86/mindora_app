//
//  PopupService.swift
//  mindora
//
//  首页弹窗（活动 / 广告 / 参与调研）的下发拉取 + 本地频控 + 事件回传。
//  对齐 Tools/doc/弹窗与调查问卷接口.md。
//
//  设计要点（沿用站内消息「绝不重复打扰」的理念）：
//  服务端下发候选弹窗 + display_rule；客户端在本地再过一道频控闸（去重 / 冷却 /
//  最多展示次数 / 关闭后不再弹），一次首页会话最多展示一条。
//

import Foundation

// MARK: - 数据模型

struct HomePopup {
    enum PopupType: String { case survey, mall, ad, unknown }
    enum ActionType: String { case survey, url, route, dismiss, unknown }

    let popupId: String
    let type: PopupType
    let badge: String?
    let badgeStyle: String?      // purple / orange / blue
    let title: String
    let subtitle: String?
    let imageURL: String?
    let actionText: String
    let actionType: ActionType
    let surveyId: String?
    let linkURL: String?
    let route: String?
    let startAt: Date?
    let endAt: Date?
    /// 服务端首次对该 uid 下发本条的时间。恢复历史消息时用它当消息的生成时间，
    /// 否则重登后旧消息全变成「刚刚」，一股脑挤进「当前消息」分组。
    let deliveredAt: Date?
    let priority: Int
    let maxShowCount: Int?
    let cooldownSeconds: TimeInterval?
    let dismissStops: Bool
    /// 内置本地图（Assets 名）。imageURL 为空时用它兜底——内置问卷弹窗即用此展示内置图。
    var localImageName: String? = nil
    /// 是否同步落一条站内消息（由服务端逐条控制）。调研类恒落、不看此字段；
    /// 商城活动一般置 true、纯广告一般置 false，运营可按需覆盖。
    var pushMessage: Bool = false
}

// MARK: - 服务

final class PopupService {
    static let shared = PopupService()
    private let logTag = "PopupService"
    private let defaults = UserDefaults.standard
    private init() {}

    // 本地频控簿记 key 前缀
    private let shownCountPrefix = "popup.shownCount."
    private let lastShownPrefix = "popup.lastShown."
    private let dismissedPrefix = "popup.dismissed."
    /// 登出 / 注销时清理所有弹窗频控记录用的索引（记录见过的 popupId）。
    private let knownIdsKey = "popup.knownIds"

    // MARK: 同步

    /// 服务端没下发 `next_query_after` 时的默认最小间隔。
    private let defaultFetchInterval: TimeInterval = 5 * 60
    /// 服务端可调区间：下限防止配置失误把客户端打成轮询；上限避免配得过大变成「永不刷新」。
    private let minAllowedFetchInterval: TimeInterval = 60          // 1 分钟
    private let maxAllowedFetchInterval: TimeInterval = 24 * 60 * 60 // 24 小时
    /// 服务端下发的间隔（响应 `data.next_query_after`，秒）。**调大调小都听服务端的**：
    /// 大促期间想让客户端更快感知就调小（最小 60s），压力大时调大（最大 24h）。
    private var serverSuggestedInterval: TimeInterval?
    /// 随机抖动：避免同一时刻一起被唤醒的一批设备之后每轮都撞在同一秒。
    /// 幅度按间隔的 20% 取（间隔调小时抖动同步变小，不会把 60s 的节奏拖成 2 分钟）。
    private var fetchJitter: TimeInterval = 0

    /// 本次生效的最小间隔：服务端值（限幅后）优先，无下发时用默认值，再叠加随机抖动。
    private var effectiveFetchInterval: TimeInterval {
        let base = serverSuggestedInterval.map {
            min(max($0, minAllowedFetchInterval), maxAllowedFetchInterval)
        } ?? defaultFetchInterval
        return base + fetchJitter
    }
    private var lastFetchAt: Date?
    /// 前台周期同步定时器：`effectiveFetchInterval` 只是「最小间隔闸门」，没有它就只有
    /// 冷启动 / 回前台两个触发点 —— App 一直挂在前台时服务端新配的弹窗永远拉不到。
    private var periodicTimer: Timer?
    /// 失败退避：服务端异常时不再每次回前台都重试（30s 起翻倍，封顶 30 分钟）。
    private var backoff = NetworkBackoff()
    private var cachedCandidates: [HomePopup] = []
    /// 候选缓存的最长可用时长。超过就当没有 —— 拿一份几小时前的下发配置继续弹窗，
    /// 比不弹更糟：运营下线一条活动后，断网的客户端会一直弹到重启。
    private static let candidateTTL: TimeInterval = 2 * 60 * 60
    private var isFetching = false
    /// 拉取进行中时排队的回调，避免并发触发多次请求。
    private var pendingCompletions: [(HomePopup?) -> Void] = []

    /// 前台周期同步：按当前生效间隔（服务端 `next_query_after` → 限幅 → 加抖动）反复 sync。
    /// 与 `DeviceLoginPusher.startPeriodicSync()` 同一套语义：前台开、进后台停。
    /// 每次触发后按最新间隔重排，服务端中途调大 / 调小都能在下一轮生效。
    func startPeriodicSync() {
        stopPeriodicSync()
        scheduleNextTick()
    }

    func stopPeriodicSync() {
        periodicTimer?.invalidate()
        periodicTimer = nil
    }

    private func scheduleNextTick() {
        let interval = effectiveFetchInterval
        periodicTimer?.invalidate()
        periodicTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.sync(reason: "periodic")
            self.scheduleNextTick()   // 用刷新后的间隔重排下一轮
        }
    }

    /// 同步服务端弹窗配置。**不依赖首页是否可见**：App 启动 / 回前台就会调，
    /// 保证服务端刚配的弹窗与站内消息能及时到达，而不是等用户切到首页才拉。
    ///
    /// 每次同步的副作用（与是否展示弹窗无关）：
    /// 1. 时间窗内的候选全部落站内消息（去重由消息层负责）；
    /// 2. 其中的调研类立即预拉题目，用户点开时无需等待网络。
    ///
    /// 回调返回「当前可展示的一条弹窗」（过完本地频控 + 优先级最高），无则 nil。
    /// `force = true` 跳过最小间隔限制（调试用）。
    func sync(reason: String, force: Bool = false, completion: ((HomePopup?) -> Void)? = nil) {
        let now = Date()
        if !force, let last = lastFetchAt, now.timeIntervalSince(last) < effectiveFetchInterval {
            Log.info(logTag, "sync(\(reason)) 命中缓存，跳过网络（\(Int(now.timeIntervalSince(last)))s 前拉过）")
            completion?(displayable(from: cachedCandidates, now: now))
            return
        }
        if !force, backoff.isBlocked {
            Log.info(logTag, "sync(\(reason)) 处于失败退避期，跳过（还剩 \(backoff.remainingSeconds)s）")
            completion?(displayable(from: cachedCandidates, now: now))
            return
        }
        // 缓存过期就丢掉。以前只要拉取一直失败（服务端挂了、断网），cachedCandidates
        // 会被无限期复用 —— 一条早该下线的活动能在退避期里一直被拿出来展示。
        if let last = lastFetchAt, now.timeIntervalSince(last) > Self.candidateTTL, !cachedCandidates.isEmpty {
            Log.info(logTag, "候选缓存已过期（\(Int(now.timeIntervalSince(last)))s），丢弃")
            cachedCandidates = []
        }
        if isFetching {
            Log.info(logTag, "sync(\(reason)) 已有请求在途，排队等待")
            if let completion { pendingCompletions.append(completion) }
            return
        }
        isFetching = true
        Log.info(logTag, "sync(\(reason)) 开始拉取")
        fetchCandidates { [weak self] result in
            guard let self else { completion?(nil); return }
            self.isFetching = false
            // 失败 / 未登录不更新时间戳与缓存；但要进退避，避免服务端故障时被全网反复重试打爆。
            guard let popups = result else {
                if AuthStorage.shared.token?.isEmpty == false {
                    self.backoff.recordFailure()   // 只有「真的请求失败」才退避，未登录不算
                    Log.info(self.logTag, "sync 失败，进入退避 \(self.backoff.remainingSeconds)s")
                } else {
                    // 未登录也走 nil 分支。不打这条日志的话，它和「网络失败」在日志里长得一模一样，
                    // 事后排查完全分不清是没登录还是服务端挂了。
                    Log.info(self.logTag, "sync(\(reason)) 跳过：未登录（不计失败、不退避）")
                }
                let queued = self.pendingCompletions
                self.pendingCompletions = []
                completion?(nil)
                queued.forEach { $0(nil) }
                return
            }
            self.backoff.recordSuccess()
            self.lastFetchAt = Date()
            // 每轮重新抽一次抖动：同一时刻一起启动的设备会逐轮散开，不会一直撞在同一秒。
            // 幅度取当前基准间隔的 20%（最多 60s），间隔调小时抖动也跟着变小。
            let base = self.serverSuggestedInterval ?? self.defaultFetchInterval
            self.fetchJitter = NetworkPacing.spreadDelay(upTo: min(base * 0.2, 60))
            self.cachedCandidates = popups
            let now = Date()
            let inWindow = popups.filter { self.withinWindow($0, now: now) }
            // 成功路径也要留痕：以前只有失败才打日志，事后只能靠下一条「命中缓存 0s 前拉过」
            // 反推本次成功，拿回来几条、有没有问卷、服务端给的间隔是多少全都看不见。
            let surveyCount = inWindow.filter { $0.type == .survey || $0.actionType == .survey }.count
            let intervalDesc = self.serverSuggestedInterval.map { "\(Int($0))s(服务端)" }
                ?? "\(Int(self.defaultFetchInterval))s(默认)"
            Log.info(self.logTag,
                     "sync(\(reason)) 成功：候选 \(popups.count) 条，时间窗内 \(inWindow.count) 条（问卷 \(surveyCount)），"
                     + "下次间隔 \(intervalDesc)+抖动 \(Int(self.fetchJitter))s")
            // 落站内消息 + 预拉问卷：对全部有效候选执行，不看展示优先级与频控。
            // 消息引擎是 @MainActor 隔离的，这里显式跳到主 actor。
            Task { @MainActor in
                inWindow.forEach {
                    self.recordMessageIfNeeded($0)
                    self.prefetchSurveyIfNeeded($0)
                }
            }
            let display = self.displayable(from: popups, now: now)
            let queued = self.pendingCompletions
            self.pendingCompletions = []
            completion?(display)
            queued.forEach { $0(display) }
        }
    }

    /// 过本地频控 + 按优先级取第一条。
    private func displayable(from popups: [HomePopup], now: Date) -> HomePopup? {
        popups
            .filter { withinWindow($0, now: now) }
            .filter { isEligible($0, now: now) }
            .sorted { $0.priority > $1.priority }
            .first
    }

    /// 供 DEBUG 预览用：手工构造的弹窗也走同一套落消息逻辑。
    /// 但**不记进账号清单** —— 那些 debug_* 的 id 服务端根本不认识，
    /// 记下来只会让每次登录恢复时白白带上几个必被忽略的 ID。
    @MainActor
    func recordMessage(for popup: HomePopup) {
        recordMessageIfNeeded(popup, rememberInVault: false)
    }

    /// 落站内消息：调研恒落；商城活动 / 广告看服务端 push_message。消息层按 id 去重。
    ///
    /// 真的落了消息就把 popup_id 记进账号清单（`AccountVault.popupIds`），
    /// 登出不清 —— 下次登录凭它向服务端要回内容重建。没落消息的（纯广告）不记，
    /// 免得恢复时凭空多出用户从没见过的条目。
    @MainActor
    private func recordMessageIfNeeded(_ popup: HomePopup,
                                       deliveredAt: Date? = nil,
                                       rememberInVault: Bool = true,
                                       isRestore: Bool = false) {
        var landed = false
        if popup.type == .survey, let surveyId = popup.surveyId {
            AppNotificationEngine.shared.recordSurveyInvite(
                popupId: popup.popupId,
                surveyId: surveyId,
                title: popup.title,
                subtitle: popup.subtitle ?? "",
                expiry: popup.endAt,
                deliveredAt: deliveredAt,
                isRestore: isRestore)
            landed = true
        } else if popup.pushMessage {
            AppNotificationEngine.shared.recordPromo(
                popupId: popup.popupId,
                title: popup.title,
                subtitle: popup.subtitle ?? "",
                actionText: popup.actionText,
                actionType: popup.actionType.rawValue,
                url: popup.linkURL,
                route: popup.route,
                surveyId: popup.surveyId,
                deliveredAt: deliveredAt)
            landed = true
        }
        // 注意用 popup.popupId 而不是 surveyId：清单是给 query_popups 用的，
        // 服务端认的是 popup_id。
        if landed, rememberInVault { AccountVault.popupIds.insert(popup.popupId) }
    }

    // MARK: 历史消息恢复

    /// 登录成功后调用：把该账号的站内消息从服务端要回来重建。
    ///
    /// 站内消息此前只在下发那一瞬落地一次，之后纯靠本地存储；而登出必须清本地（防串号），
    /// 服务端又不会重复下发，消息就永久消失了。改成「服务端存内容、客户端存状态」后，
    /// 这里就是把内容取回来的那一步。
    ///
    /// 两种取法（见 Tools/doc/弹窗与调查问卷接口.md 2.1）：
    /// - **按 ID 拉**：本地清单已经建立起来，以清单为准，逐条恢复；
    /// - **拉全量**：这个账号在本机压根没有过清单（新设备 / 重装 /
    ///   全新账号）→ 向服务端要回完整状态。
    ///
    /// 判据是 `isInitialized` 而**不是**「清单空不空」。空清单有两种含义：从没收到过，
    /// 以及用户把消息一条条删光了。只看空不空的话，后者会被当成前者去拉全量，
    /// 用户刚删干净的消息下次登录就全回来了。
    ///
    /// 不受 `next_query_after` 间隔限制：这不是轮询，登录即发一次。
    ///
    /// - Parameter onlyIfLocalEmpty: 只在本地一条服务端消息都没有时才发起。
    ///   冷启动传 true（本地消息通常好好的，不该每次启动都请求一遍），
    ///   登录传 false（刚被 performFullReset 清空，必须整份拉回来）。
    func restoreHistory(reason: String, onlyIfLocalEmpty: Bool = false) {
        guard AuthStorage.shared.token?.isEmpty == false else {
            Log.info(logTag, "restoreHistory(\(reason)) 跳过：未登录")
            return
        }
        let vault = AccountVault.popupIds
        let isFullFetch = !vault.isInitialized
        let ids = vault.all

        // 清单建立过、但现在是空的。两种情况都走这里，都无需向服务端要任何东西：
        //   - 拉过全量、服务端本来就没有这个账号的消息；
        //   - 用户把消息一条条删光了。
        // 关键是**不能**因为空就去拉全量 —— 后者会让用户刚删干净的消息原地复活。
        if !isFullFetch, ids.isEmpty {
            Log.info(logTag, "restoreHistory(\(reason)) 跳过：清单已建立且为空，无需恢复")
            return
        }

        // 冷启动时只在本地真的丢了才拉。
        //
        // 判据是「一条服务端消息都没有」，不是「清单与本地的差集非空」—— 后者不成立：
        // 清单记的是这个账号收到过的全部 ID，而消息体有 maxCount 上限，被挤掉的会永远
        // 算作「缺失」，于是每次启动都去拉、拉回来又被挤掉，白白打转。
        //
        // 登录路径不受此限：那时本地刚被 performFullReset 清空，本来就该整份拉回来。
        if onlyIfLocalEmpty, !AppNotificationStore.shared.presentPopupIds().isEmpty {
            Log.info(logTag, "restoreHistory(\(reason)) 跳过：本地消息在，无需恢复")
            return
        }

        let mode = isFullFetch ? "拉全量（本机首次）" : "按 ID 拉 \(ids.count) 条"
        Log.info(logTag, "restoreHistory(\(reason)) 开始：\(mode)")

        fetchCandidates(scope: .history, popupIds: isFullFetch ? nil : ids) { [weak self] result in
            guard let self else { return }
            guard let popups = result else {
                Log.info(self.logTag, "restoreHistory(\(reason)) 失败或未登录，本地消息保持不变")
                return
            }
            Log.info(self.logTag, "restoreHistory(\(reason)) 成功：服务端返回 \(popups.count) 条")
            // 拉全量成功即标记已初始化 —— 哪怕返回 0 条也算：这个账号在本机的清单
            // 从此有了确定状态，之后一律走按 ID 拉。失败不标记，下次启动会重试。
            if isFullFetch { vault.markInitialized() }
            Task { @MainActor in
                for popup in popups {
                    // 恢复出来的一律只落消息、绝不弹窗，也不预拉问卷题目——
                    // 用户刚登录，不该被一堆历史活动糊一脸。
                    self.recordMessageIfNeeded(popup,
                                               deliveredAt: Self.restoredCreatedAt(for: popup),
                                               isRestore: true)
                }
            }
        }
    }

    /// 恢复出来的消息该用什么时间。
    ///
    /// 优先服务端的 `delivered_at`（首次下发时刻），其次 `start_at`。
    /// **两个都没有时不能退回「现在」** —— 那会让一堆几个月前的旧消息假装成刚收到的，
    /// 一股脑挤进「当前消息」分组、排在真正的新消息前面。
    /// 这种情况一律归入「历史消息」：时间未知时，说它是旧的比说它是新的更接近事实。
    private static func restoredCreatedAt(for popup: HomePopup) -> Date {
        if let t = popup.deliveredAt ?? popup.startAt { return t }
        // 比「当前消息」窗口（3 天）再早一点，确保落进历史分组。
        return Date().addingTimeInterval(-(3 * 86400 + 3600))
    }

    /// 同步到调研类弹窗就立即预拉题目（未提交过才拉），用户点开时直接用缓存渲染。
    private func prefetchSurveyIfNeeded(_ popup: HomePopup) {
        let surveyId = popup.surveyId ?? (popup.type == .survey ? popup.popupId : nil)
        guard popup.type == .survey || popup.actionType == .survey, let surveyId, !surveyId.isEmpty else { return }
        SurveyService.shared.prefetch(surveyId: surveyId)
    }

    /// 查询范围。见 Tools/doc/弹窗与调查问卷接口.md 2.1。
    enum QueryScope: String {
        /// 投放查询：现在该不该弹一个窗。服务端照常做投放定向、按优先级裁剪，过滤已过期。
        case active
        /// 历史消息恢复：这个账号有哪些消息。服务端不做定向 / 频控 / 优先级裁剪。
        case history
    }

    /// 回调 nil 表示「本次没拿到结果」（未登录 / 网络失败 / 解析失败），调用方不应据此更新缓存。
    private func fetchCandidates(scope: QueryScope = .active,
                                 popupIds: [String]? = nil,
                                 completion: @escaping ([HomePopup]?) -> Void) {
        if Constants.Config.showMockData {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                completion(Self.mockPopups())
            }
            return
        }
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let token = AuthStorage.shared.token, !token.isEmpty,
              let url = URL(string: Constants.Network.popupURL) else {
            completion(nil); return
        }

        var data: [String: Any] = [
            "uid": uid,
            "jwt_token": token,
            "language": LocalizationManager.shared.currentLanguage.rawValue,
            "timezone": TimeZone.current.identifier,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "platform": "ios",
            "placement": "home",
            "scope": scope.rawValue
        ]
        // 按 ID 拉：清单非空才带；空清单要走「拉全量」，带个空数组会让服务端以为要 0 条。
        if scope == .history, let ids = popupIds, !ids.isEmpty {
            data["popup_ids"] = ids
        }
        let body: [String: Any] = [
            "request_type": "query_popups",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": data
        ]

        var req = URLRequest(url: url)

        RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = Constants.Network.timeoutInterval
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // 请求/响应留痕。这里长期是个盲区：以前只打「拿回来几条」，一旦条数不对，
        // 分不清是客户端没带对参数、还是服务端没按契约返回。jwt_token 不打（太长且敏感）。
        let reqID = String(UUID().uuidString.prefix(8))
        if Constants.Config.enableNetworkLogging {
            var redacted = data
            redacted["jwt_token"] = "<redacted>"
            let desc = (try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys]))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "-"
            Log.info(logTag, "[req:\(reqID)] query_popups → \(url.absoluteString) data=\(desc)")
        }

        URLSession.shared.dataTask(with: req) { [weak self] respData, response, error in
            guard let self else { return }
            if let http = response as? HTTPURLResponse, let respData {
                SessionExpirationCenter.handle(httpResponse: http, data: respData)
            }
            if let error {
                Log.error(self.logTag, "[req:\(reqID)] query_popups error=\(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            if Constants.Config.enableNetworkLogging {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let bodyText = respData.flatMap { String(data: $0, encoding: .utf8) } ?? "-"
                Log.info(self.logTag, "[req:\(reqID)] query_popups ← status=\(status) body=\(bodyText)")
            }
            let json = (respData.flatMap { try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any]
            // 业务码要看。以前只取 data，服务端返回 code!=0（参数错、限流、内部错）时
            // data 往往是 null，于是被笼统记成「响应无 data 字段」，排查时分不清是
            // 协议问题还是服务端拒绝了请求。
            if let code = json?["code"] as? Int, code != 0 {
                let msg = json?["msg"] as? String ?? "-"
                Log.error(self.logTag, "[req:\(reqID)] query_popups 业务失败 code=\(code) msg=\(msg)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard let payload = json?["data"] as? [String: Any] else {
                // 走到这儿 data 缺失/为 null，要分两种：
                // - JSON 解析成功且 code==0 → 服务端明确应答「当前没有弹窗」，按成功空列表处理
                //   （覆盖候选缓存、不进失败退避）。以前笼统当失败：旧候选被复用到 TTL，还误触发退避。
                // - 响应体压根解析不出来 / 没有 code → 协议或网络问题，仍按失败处理。
                if let json, json["code"] as? Int == 0 {
                    Log.info(self.logTag, "[req:\(reqID)] query_popups 成功但 data 为空，按 0 条处理")
                    DispatchQueue.main.async { completion([]) }
                } else {
                    Log.error(self.logTag, "[req:\(reqID)] query_popups 响应无法解析（无 code/data）")
                    DispatchQueue.main.async { completion(nil) }
                }
                return
            }
            // 服务端建议的下次拉取间隔（秒）：压力大时可临时调大，客户端据此全局降频。
            // **不下发时要恢复默认**，否则服务端某次临时调到 24h、之后不再下发，
            // 客户端会一直用着那个 24h 直到杀进程 —— 等于新配置一天才生效一次。
            DispatchQueue.main.async {
                if let next = Self.intValue(payload["next_query_after"]), next > 0 {
                    self.serverSuggestedInterval = TimeInterval(next)
                } else {
                    self.serverSuggestedInterval = nil
                }
            }
            let rawList = (payload["popups"] as? [[String: Any]]) ?? []
            let popups = rawList.compactMap { Self.parse($0) }
            DispatchQueue.main.async { completion(popups) }
        }.resume()
    }

    // MARK: 本地频控

    /// 基础有效性（时间窗 + 问卷未提交）：展示与落站内消息共用。
    private func withinWindow(_ popup: HomePopup, now: Date) -> Bool {
        if let start = popup.startAt, now < start { return false }
        if let end = popup.endAt, now > end { return false }
        // 调研弹窗：若该问卷已提交则不再展示 / 不再落消息。
        if popup.type == .survey, let sid = popup.surveyId, SurveyService.shared.hasSubmitted(surveyId: sid) { return false }
        return true
    }

    private func isEligible(_ popup: HomePopup, now: Date) -> Bool {
        if popup.dismissStops, defaults.bool(forKey: dismissedPrefix + popup.popupId) { return false }
        if let maxCount = popup.maxShowCount,
           defaults.integer(forKey: shownCountPrefix + popup.popupId) >= maxCount { return false }
        if let cooldown = popup.cooldownSeconds {
            let last = defaults.double(forKey: lastShownPrefix + popup.popupId)
            if last > 0, now.timeIntervalSince1970 - last < cooldown { return false }
        }
        return true
    }

    /// 弹窗真正展示后调用：记展示次数 + 时间，并上报曝光。
    func markShown(_ popup: HomePopup) {
        rememberId(popup.popupId)
        defaults.set(defaults.integer(forKey: shownCountPrefix + popup.popupId) + 1,
                     forKey: shownCountPrefix + popup.popupId)
        defaults.set(Date().timeIntervalSince1970, forKey: lastShownPrefix + popup.popupId)
        report(popupId: popup.popupId, event: "impression")
    }

    /// 用户关闭弹窗：按 dismiss_stops 记「不再展示」，并上报关闭。
    func markDismissed(_ popup: HomePopup) {
        if popup.dismissStops {
            defaults.set(true, forKey: dismissedPrefix + popup.popupId)
        }
        report(popupId: popup.popupId, event: "dismiss")
    }

    /// 用户点击主按钮：上报点击。
    func markClicked(_ popup: HomePopup) {
        report(popupId: popup.popupId, event: "click")
    }

    private func rememberId(_ id: String) {
        var ids = Set(defaults.stringArray(forKey: knownIdsKey) ?? [])
        ids.insert(id)
        defaults.set(Array(ids), forKey: knownIdsKey)
    }

    /// 只丢掉已拉取的弹窗内容，保留频控/已忽略状态。用于语言切换：
    /// 弹窗正文是服务端按 `language` 渲染的，但「用户已经关过这条」是与语言无关的事实，
    /// 一起清掉会让已忽略的弹窗换个语言又弹出来。
    func invalidateContentCache() {
        cachedCandidates = []
        lastFetchAt = nil
    }

    /// 清空全部弹窗频控记录。用于登出 / 注销账号，避免上一账号的频控状态残留。
    func clearCache() {
        for id in defaults.stringArray(forKey: knownIdsKey) ?? [] {
            defaults.removeObject(forKey: shownCountPrefix + id)
            defaults.removeObject(forKey: lastShownPrefix + id)
            defaults.removeObject(forKey: dismissedPrefix + id)
        }
        defaults.removeObject(forKey: knownIdsKey)
        // 内存缓存也要清：否则换账号后仍会用上一账号拉到的候选。
        cachedCandidates = []
        lastFetchAt = nil
        pendingCompletions = []
    }


    // MARK: 事件回传

    private func report(popupId: String, event: String) {
        if Constants.Config.showMockData { return }
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let token = AuthStorage.shared.token, !token.isEmpty,
              let url = URL(string: Constants.Network.popupURL) else { return }

        let body: [String: Any] = [
            "request_type": "report_popup",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": [
                "uid": uid,
                "jwt_token": token,
                "popup_id": popupId,
                "event": event,
                "event_at": Int(Date().timeIntervalSince1970)
            ]
        ]
        var req = URLRequest(url: url)
        RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = Constants.Network.timeoutInterval
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        // 埋点是 fire-and-forget，但不能连失败都看不见：运营发现曝光数对不上时，
        // 得能从客户端日志判断是「没发出去」还是「发了但服务端没记」。
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                Log.error(self.logTag, "report_popup(\(event)) 失败 popup=\(popupId) error=\(error.localizedDescription)")
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let json = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any]
            let code = json?["code"] as? Int
            if status != 200 || (code != nil && code != 0) {
                Log.error(self.logTag,
                          "report_popup(\(event)) 被拒 popup=\(popupId) status=\(status) code=\(code.map(String.init) ?? "-")")
            }
        }.resume()
    }

    // MARK: 解析

    /// 数字 / 字符串数字都接受。服务端在不同接口上对秒级时间戳、间隔秒数的序列化方式
    /// 并不一致（有的给 int，有的给 "1719705600" 这样的字符串），只认一种会静默丢字段。
    static func intValue(_ raw: Any?) -> Int? {
        if let i = raw as? Int { return i }
        if let n = raw as? NSNumber { return n.intValue }
        if let s = raw as? String { return Int(s.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    private static func parse(_ dict: [String: Any]) -> HomePopup? {
        guard let popupId = dict["popup_id"] as? String,
              let title = dict["title"] as? String,
              let actionText = dict["action_text"] as? String else { return nil }

        let payload = dict["action_payload"] as? [String: Any]
        let rule = dict["display_rule"] as? [String: Any]

        // 时间戳容错：服务端有时把秒级时间戳序列化成字符串（"1719705600"）。
        // 原来只认数字，遇到字符串会静默当成「没有时间窗」—— 一条早已过期的弹窗
        // 会因此被判定为永远有效，一直弹。
        func date(_ key: String) -> Date? {
            guard let t = Self.intValue(dict[key]) else { return nil }
            return Date(timeIntervalSince1970: TimeInterval(t))
        }

        return HomePopup(
            popupId: popupId,
            type: HomePopup.PopupType(rawValue: dict["type"] as? String ?? "") ?? .unknown,
            badge: dict["badge"] as? String,
            badgeStyle: dict["badge_style"] as? String,
            title: title,
            subtitle: dict["subtitle"] as? String,
            imageURL: dict["image_url"] as? String,
            actionText: actionText,
            actionType: HomePopup.ActionType(rawValue: dict["action_type"] as? String ?? "") ?? .unknown,
            surveyId: payload?["survey_id"] as? String,
            linkURL: payload?["url"] as? String,
            route: payload?["route"] as? String,
            startAt: date("start_at"),
            endAt: date("end_at"),
            deliveredAt: date("delivered_at"),
            priority: dict["priority"] as? Int ?? 0,
            maxShowCount: rule?["max_show_count"] as? Int,
            cooldownSeconds: (rule?["cooldown_seconds"] as? NSNumber)?.doubleValue,
            dismissStops: rule?["dismiss_stops"] as? Bool ?? true,
            pushMessage: dict["push_message"] as? Bool ?? false
        )
    }

    // MARK: Mock（DEBUG 预览）

    /// 开机不再内置任何弹窗/问卷 —— 正式问卷全部由服务端下发。
    /// 需要预览弹窗 / 问卷时走首页 Logo 长按的 DEBUG 菜单（DebugNotificationSimulator）。
    private static func mockPopups() -> [HomePopup] { [] }
}
