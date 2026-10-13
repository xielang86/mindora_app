//
//  MembershipStatusService.swift
//  mindora
//
//  服务端会员状态（订阅状态服务端化-改造方案.md §3.2 / §3.3）：
//  POST /auth request_type=query_user_rights，把服务端算好的会员状态按 uid 落到 Keychain。
//
//  服务端是事实源：兑换码等级 + 两段体验期 + Apple 订阅（客户端上报的 JWS 凭据 / ASSN 推送 / 每日对账）
//  在服务端合并成 effective_user_level。这里只是缓存下发值，SubscriptionManager 按
//  `entitlement_authority` 决定信它还是信本地 StoreKit。
//
//  拉取时机：登录成功、冷启动已登录、回前台（10 分钟冷却）、购买 / 兑换成功后。
//

import Foundation

/// 服务端下发的一份会员状态快照（query_user_rights / report_subscription 的 data）。
struct ServerMembershipState: Codable, Equatable {

    /// 服务端对同一份 Apple 订阅的描述（`subscription` 对象，无有效记录时为 nil）。
    struct AppleSubscription: Codable, Equatable {
        var originalTransactionID: String
        var productID: String?
        var tier: String?               // pro / premium
        var environment: String?        // Sandbox / Production
        var active: Bool
        var purchasedAt: Date?
        var expiresAt: Date?
        var autoRenew: Bool
        var autoRenewProductID: String?
        var inBillingRetry: Bool
        var gracePeriodExpiresAt: Date?
        var revokedAt: Date?

        /// 服务端答复里的 active 是应答那一刻的判断，快照在本机可能放到 10 分钟以后还在用；
        /// 订阅到点后这段时间里不能再拿它当「仍有效」——按到期时间 / 宽限期在本机重判一次。
        var isActiveNow: Bool {
            guard active, revokedAt == nil else { return false }
            let now = Date()
            if let e = expiresAt, e > now { return true }
            if inBillingRetry, let g = gracePeriodExpiresAt, g > now { return true }
            return expiresAt == nil
        }
    }

    /// 库里记录的等级（兑换码 / 后台赠送），配合 levelEndAt 判有效。
    var storedLevel: String
    /// 当前生效等级：含体验期与 Apple 订阅，服务端算好的。free / pro / premium。
    var effectiveLevel: String
    var levelEndAt: Date?
    var premiumTrialEndAt: Date?
    /// Apple 订阅档位（服务端按 apple_subscription 判定；无有效订阅为 nil）。
    var subscriptionLevel: String?
    var membershipActive: Bool
    var subscription: AppleSubscription?
    /// "client" / "server"：App 会员判定信谁（服务端下发，默认 client）。
    var entitlementAuthority: String
    var serverTime: Date?
    /// 首次成为会员（不含体验期）的时刻，服务端跨设备、跨订阅记录；订阅页「累计天数」的起点。老服务端没有 → nil。
    var memberSince: Date? = nil
    /// 服务端按会员时段台账算出的累计会员天数（各段并集，不含体验期，断掉的不算）。老服务端没有 → nil。
    var memberDays: Int? = nil
    var fetchedAt: Date

    var authorityIsServer: Bool { entitlementAuthority == "server" }

    /// 「真金白银 / 服务端授予」的等级，不含体验期：Apple 订阅档位与未过期的库内等级取高者。
    var paidLevel: String {
        let stored: String
        if storedLevel == "pro" || storedLevel == "premium" {
            if let end = levelEndAt { stored = end > Date() ? storedLevel : "free" } else { stored = storedLevel }
        } else {
            stored = "free"
        }
        return Self.higher(stored, subscriptionLevel ?? "free")
    }

    static func rank(_ level: String) -> Int {
        switch level { case "premium": return 2; case "pro": return 1; default: return 0 }
    }
    static func higher(_ a: String, _ b: String) -> String { rank(a) >= rank(b) ? a : b }

    // MARK: 解析

    /// 从服务端 data 字典解析。`stored_user_level` / `effective_user_level` 缺失时视为「本次没带」→ nil，
    /// 调用方保留旧值（与《高级会员体验期接口》的规则一致：只有服务端**明确**下发才覆盖）。
    static func parse(_ payload: [String: Any]) -> ServerMembershipState? {
        guard let effective = payload["effective_user_level"] as? String, !effective.isEmpty else { return nil }
        let stored = (payload["stored_user_level"] as? String) ?? (payload["user_level"] as? String) ?? "free"
        var sub: AppleSubscription? = nil
        if let s = payload["subscription"] as? [String: Any], let otid = s["original_transaction_id"] as? String {
            sub = AppleSubscription(
                originalTransactionID: otid,
                productID: s["product_id"] as? String,
                tier: s["tier"] as? String,
                environment: s["environment"] as? String,
                active: (s["active"] as? Bool) ?? false,
                purchasedAt: SubscriptionManager.parseServerDate(s["purchased_at"]),
                expiresAt: SubscriptionManager.parseServerDate(s["expires_at"]),
                autoRenew: (s["auto_renew"] as? Bool) ?? false,
                autoRenewProductID: s["auto_renew_product_id"] as? String,
                inBillingRetry: (s["in_billing_retry"] as? Bool) ?? false,
                gracePeriodExpiresAt: SubscriptionManager.parseServerDate(s["grace_period_expires_at"]),
                revokedAt: SubscriptionManager.parseServerDate(s["revoked_at"]))
        }
        return ServerMembershipState(
            storedLevel: stored,
            effectiveLevel: effective,
            levelEndAt: SubscriptionManager.parseServerDate(payload["level_end_at"]),
            premiumTrialEndAt: SubscriptionManager.parseServerDate(payload["premium_trial_end_at"]),
            subscriptionLevel: payload["subscription_level"] as? String,
            membershipActive: (payload["membership_active"] as? Bool) ?? (rank(effective) > 0),
            subscription: sub,
            entitlementAuthority: ((payload["entitlement_authority"] as? String) ?? "client").lowercased(),
            serverTime: SubscriptionManager.parseServerDate(payload["server_time"]),
            memberSince: SubscriptionManager.parseServerDate(payload["member_since"]),
            memberDays: payload["member_days"] as? Int,
            fetchedAt: Date())
    }

    var summary: String {
        "effective=\(effectiveLevel) stored=\(storedLevel) end=\(levelEndAt.map { "\($0)" } ?? "-") "
        + "trial=\(premiumTrialEndAt.map { "\($0)" } ?? "-") apple=\(subscription?.productID ?? "-")"
        + "(\(subscription?.active == true ? "active" : "inactive")) authority=\(entitlementAuthority)"
    }
}

/// 按 uid 持久化服务端会员状态（Keychain，跨重装留存；登出 / 注销时由 SessionResetter 清掉，登录后重拉）。
final class MembershipStateStore {
    static let shared = MembershipStateStore()
    private static let key = "membership.serverState.v2"
    private let kc = KeychainHelper.standard
    private init() {}

    private func loadAll() -> [String: ServerMembershipState] {
        guard let json = kc.read(forKey: Self.key), let data = json.data(using: .utf8),
              let m = try? JSONDecoder().decode([String: ServerMembershipState].self, from: data) else { return [:] }
        return m
    }
    private func saveAll(_ m: [String: ServerMembershipState]) {
        if m.isEmpty { kc.delete(forKey: Self.key); return }
        if let data = try? JSONEncoder().encode(m), let json = String(data: data, encoding: .utf8) {
            kc.save(json, forKey: Self.key)
        }
    }

    func state(forUid uid: String) -> ServerMembershipState? {
        let key = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return loadAll()[key]
    }
    func save(_ state: ServerMembershipState, forUid uid: String) {
        let key = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        var m = loadAll(); m[key] = state; saveAll(m)
    }
    /// 登出 / 注销：整个缓存清掉（登录后会重新拉）。
    func clearAll() { kc.delete(forKey: Self.key) }
}

final class MembershipStatusService {

    static let shared = MembershipStatusService()
    private let logTag = "MemberStatus"
    private init() {}

    /// 回前台 / 冷启动的最短拉取间隔；登录、购买、兑换不受限。
    private let cooldown: TimeInterval = 10 * 60
    // refresh 会从主线程（回前台）和 URLSession 回调线程（登录完成）两边进来，状态用锁护住。
    private let lock = NSLock()
    private var lastFetchAt: Date? = nil
    private var inFlight = false

    /// 拉一次 query_user_rights。`force` 为 false 时受 10 分钟冷却限制。
    /// - Parameter minInterval: 给「进订阅页」这类场景用的更短冷却（默认沿用 10 分钟）。
    func refresh(reason: String, force: Bool = false, minInterval: TimeInterval? = nil) {
        guard let token = AuthStorage.shared.token, !token.isEmpty,
              let uid = AuthStorage.shared.uid?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty else {
            Log.info(logTag, "refresh(\(reason)) 跳过：未登录")
            return
        }
        lock.lock()
        if !force, let last = lastFetchAt, Date().timeIntervalSince(last) < (minInterval ?? cooldown) {
            lock.unlock()
            Log.info(logTag, "refresh(\(reason)) 跳过：冷却中（上次 \(Int(Date().timeIntervalSince(last)))s 前）")
            return
        }
        if inFlight {
            lock.unlock()
            Log.info(logTag, "refresh(\(reason)) 跳过：已有请求在飞")
            return
        }
        inFlight = true
        lock.unlock()
        guard let url = URL(string: Constants.Network.authURL) else { finish(fetched: false); return }

        let body: [String: Any] = [
            "request_type": "query_user_rights",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": ["jwt_token": token, "uid": uid]
        ]
        var req = URLRequest(url: url)
        let requestID = RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = Constants.Network.timeoutInterval
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Log.info(logTag, "query_user_rights(\(reason)) req=\(requestID)")

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            var fetched = false
            defer { self.finish(fetched: fetched) }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if let error {
                Log.error(self.logTag, "query_user_rights 网络失败 req=\(requestID)：\(error.localizedDescription)")
                return
            }
            _ = SessionExpirationCenter.handle(httpResponse: response, data: data)
            guard (200..<300).contains(status), let data,
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                Log.error(self.logTag, "query_user_rights 失败 status=\(status) req=\(requestID)")
                return
            }
            if let code = json["code"] as? Int, code != 0 && code != 200 {
                Log.error(self.logTag, "query_user_rights 业务失败 code=\(code) msg=\(json["msg"] as? String ?? "-") req=\(requestID)")
                return
            }
            guard let payload = json["data"] as? [String: Any], let state = ServerMembershipState.parse(payload) else {
                Log.error(self.logTag, "query_user_rights 响应缺 effective_user_level，保留本地旧值 req=\(requestID)")
                return
            }
            fetched = true
            Task { @MainActor in
                SubscriptionManager.shared.applyServerState(state, source: "query_user_rights(\(reason))")
            }
        }.resume()
    }

    private func finish(fetched: Bool) {
        lock.lock()
        inFlight = false
        if fetched { lastFetchAt = Date() }
        lock.unlock()
    }
}
