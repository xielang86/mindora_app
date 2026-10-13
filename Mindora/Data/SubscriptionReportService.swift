//
//  SubscriptionReportService.swift
//  mindora
//
//  订阅上报（Tools/doc/订阅状态服务端化-改造方案.md §3.1，兼容 高级会员体验期接口.md §4）：
//  POST /auth，request_type=report_subscription，带 StoreKit 2 的 JWS 凭据。
//
//  服务端离线验签（Apple 根证书）后把这笔订阅落库并绑定到当前账号，再算出 effective_user_level 下发。
//  三个时机都报：购买成功、Transaction.updates（续费 / 退款）、每账号每天一次全量 currentEntitlements
//  （存量订阅 / 换机恢复 / 重装靠这一步补进服务端）。老字段 product_id / original_transaction_id / purchased_at
//  仍一起带上，老服务端照旧能处理。
//
//  幂等与乱序由服务端保证（同一订阅链按 signedDate 只接受更新的写入），所以这里重复上报无害——
//  这也是「失败就攒着、以后反复重试」的前提。
//

import Foundation
import StoreKit

final class SubscriptionReportService {

    static let shared = SubscriptionReportService()
    private let logTag = "SubReport"
    private init() {}

    // MARK: - 待上报队列

    /// 一笔待上报的交易。
    ///
    /// 必须持久化：购买是一次性事件，请求超时不补上的话服务端永远不知道他买过。
    /// `signedTransaction` 为 nil 的是老版本留下的队列项，按老字段发。
    private struct PendingReport: Codable, Equatable {
        let productID: String
        let originalTransactionID: String
        let purchasedAt: TimeInterval
        var transactionID: String? = nil
        var signedTransaction: String? = nil
        var signedRenewalInfo: String? = nil
        /// 撤销（退款）时刻；同一笔交易退款后会再来一次，要当作新事件报。
        var revokedAt: TimeInterval? = nil

        /// 服务端已确认过的事件键：交易 + 是否已撤销。
        var reportedKey: String { dedupKey + (revokedAt.map { "|revoked@\(Int($0))" } ?? "") }

        /// 去重键：有 transactionID 用它（续费每期不同，不能再按 originalID 去重），老项回退到 originalID。
        var dedupKey: String { transactionID ?? originalTransactionID }
    }

    private let pendingKey = "subscription.pendingReports.v1"
    /// 服务端已确认的事件键（最近 200 个）。StoreKit 在购买后约 20 秒会把同一笔交易再从
    /// Transaction.updates 送一次（真机沙盒稳定复现），没有这份记录就会原样再报一遍。
    private let reportedKey = "subscription.reportedKeys.v1"
    private let defaults = UserDefaults.standard

    private func loadReported() -> [String] { defaults.stringArray(forKey: reportedKey) ?? [] }

    private func markReported(_ key: String) {
        var list = loadReported().filter { $0 != key }
        list.append(key)
        if list.count > 200 { list.removeFirst(list.count - 200) }
        defaults.set(list, forKey: reportedKey)
    }

    /// 正在飞行中的上报（dedupKey）。flush 会被购买回调、Transaction.updates、回前台、登录多路
    /// 同时触发，没有这层守卫时同一笔交易会在几毫秒内发出好几份；启动时若 Transaction.updates
    /// 一口气吐出十几笔历史续费，每笔都触发一次整队重发，请求数按 1+2+3… 叠加，真机实测一分钟
    /// 84 个请求把服务端排队排到超时。
    private var inFlight = Set<String>()
    private let inFlightLock = NSLock()

    private func markInFlight(_ key: String) -> Bool {
        inFlightLock.lock(); defer { inFlightLock.unlock() }
        return inFlight.insert(key).inserted
    }

    private func clearInFlight(_ key: String) {
        inFlightLock.lock(); defer { inFlightLock.unlock() }
        inFlight.remove(key)
    }

    private func loadPending() -> [PendingReport] {
        guard let data = defaults.data(forKey: pendingKey),
              let list = try? JSONDecoder().decode([PendingReport].self, from: data) else { return [] }
        return list
    }

    private func savePending(_ list: [PendingReport]) {
        if list.isEmpty {
            defaults.removeObject(forKey: pendingKey)
        } else if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: pendingKey)
        }
    }

    // MARK: - 对外入口

    /// 购买成功 / Transaction.updates 收到一笔交易时调用。先入队再发送——顺序不能反：
    /// 先发送后入队的话，App 在请求飞行途中被杀掉，这笔购买就没有任何痕迹了。
    func report(transaction: Transaction, signedTransaction: String, signedRenewalInfo: String?) {
        let item = PendingReport(productID: transaction.productID,
                                 originalTransactionID: String(transaction.originalID),
                                 purchasedAt: transaction.purchaseDate.timeIntervalSince1970,
                                 transactionID: String(transaction.id),
                                 signedTransaction: signedTransaction,
                                 signedRenewalInfo: signedRenewalInfo,
                                 revokedAt: transaction.revocationDate?.timeIntervalSince1970)
        if loadReported().contains(item.reportedKey) {
            Log.info(logTag, "交易已上报过，跳过 txn=\(item.transactionID ?? "-") revoked=\(item.revokedAt != nil)")
            return
        }
        enqueue(item)
        Log.info(logTag, "交易入队待上报 product=\(item.productID) txn=\(item.transactionID ?? "-") originalTxn=\(item.originalTransactionID)")
        flush(reason: "purchase")
    }

    /// 每账号每天最多一次：把当前全部权益的凭据报上去（§2.5 存量迁移 / 换机恢复）。
    /// 由 SubscriptionManager 在 StoreKit 解析完成后调用。
    func syncEntitlementsIfDue(_ entitlements: [(Transaction, String, String?)], uid: String) {
        let key = "subscription.entitlementSync.lastAt.\(uid)"
        let last = defaults.double(forKey: key)
        guard Date().timeIntervalSince1970 - last > 24 * 3600 else { return }
        guard let token = AuthStorage.shared.token, !token.isEmpty else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: key)
        for (t, jws, renewal) in entitlements {
            enqueue(PendingReport(productID: t.productID, originalTransactionID: String(t.originalID),
                                  purchasedAt: t.purchaseDate.timeIntervalSince1970, transactionID: String(t.id),
                                  signedTransaction: jws, signedRenewalInfo: renewal))
        }
        Log.info(logTag, "全量权益同步入队 \(entitlements.count) 条 uid=\(uid)")
        flush(reason: "entitlement-sync")
    }

    private func enqueue(_ item: PendingReport) {
        var list = loadPending()
        if let i = list.firstIndex(where: { $0.dedupKey == item.dedupKey }) {
            list[i] = item          // 同一笔交易只留最新一份（凭据可能带上了更新的续订信息）
        } else if let newer = list.first(where: { $0.originalTransactionID == item.originalTransactionID
                                                    && $0.transactionID != nil && $0.purchasedAt > item.purchasedAt }) {
            // 同一订阅链已经排了更新的一期：老的那期服务端只会判 stale，不用再报。
            Log.info(logTag, "跳过更早一期的上报 txn=\(item.transactionID ?? "-")，队列里已有 txn=\(newer.transactionID ?? "-")")
            return
        } else {
            // 反过来：新来的这期更新，把同链里更早的都换掉，一条订阅链只报最新一期。
            list.removeAll { $0.originalTransactionID == item.originalTransactionID && $0.transactionID != nil }
            list.append(item)
        }
        savePending(list)
    }

    /// 把队列里积压的上报冲一遍。登录成功后 / 回前台各调一次。
    ///
    /// ⚠️ 未登录时**不能丢弃队列**：用户完全可以先买后登录（或买完就被登录态过期踢了），
    /// 那时 uid/token 都没有，只能攒着等登录后再发。
    func flush(reason: String) {
        let list = loadPending()
        guard !list.isEmpty else { return }
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let token = AuthStorage.shared.token, !token.isEmpty else {
            Log.info(logTag, "flush(\(reason)) 跳过：未登录，\(list.count) 条上报继续留在队列里")
            return
        }
        let ready = list.filter { markInFlight($0.dedupKey) }
        if ready.isEmpty {
            Log.info(logTag, "flush(\(reason)) 跳过：\(list.count) 条都在发送中")
            return
        }
        Log.info(logTag, "flush(\(reason)) 开始，待上报 \(ready.count) 条（发送中 \(list.count - ready.count) 条）")
        for item in ready {
            send(item, uid: uid, token: token)
        }
    }

    // MARK: - 发送

    private func send(_ item: PendingReport, uid: String, token: String) {
        guard let url = URL(string: Constants.Network.authURL) else {
            clearInFlight(item.dedupKey)
            return
        }

        var data: [String: Any] = [
            "uid": uid,
            "jwt_token": token,
            "language": LocalizationManager.shared.currentLanguage.rawValue,
            "platform": "ios",
            "product_id": item.productID,
            "original_transaction_id": item.originalTransactionID,
            "purchased_at": Int(item.purchasedAt)
        ]
        if let jws = item.signedTransaction {
            data["signed_transaction"] = jws
            if let renewal = item.signedRenewalInfo { data["signed_renewal_info"] = renewal }
        }
        let body: [String: Any] = [
            "request_type": "report_subscription",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": data
        ]

        var req = URLRequest(url: url)
        let requestID = RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = Constants.Network.timeoutInterval
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else {
            clearInFlight(item.dedupKey)
            return
        }
        req.httpBody = payload

        Log.info(logTag, "report_subscription req=\(requestID) product=\(item.productID) txn=\(item.transactionID ?? "-") jws=\(item.signedTransaction != nil)")

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            defer { self.clearInFlight(item.dedupKey) }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if Constants.Config.enableNetworkLogging {
                let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? "-"
                Log.info(self.logTag, "report_subscription response status=\(status) body=\(AuthService.redactToken(text))")
            }

            if let error {
                // 网络失败：**保留队列**，等下次 flush。
                Log.error(self.logTag, "report_subscription 网络失败，保留队列待重试 req=\(requestID)：\(error.localizedDescription)")
                return
            }
            _ = SessionExpirationCenter.handle(httpResponse: response, data: data)

            guard let data else {
                Log.error(self.logTag, "report_subscription 无响应体，保留队列待重试 req=\(requestID)")
                return
            }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

            // 5xx / 超时类：服务端自己的问题，留着重试。
            // 4xx：请求本身有问题（参数错、token 废了），重试多少次都一样，直接出队免得
            //      每次回前台都对着服务端撞一遍。
            guard (200..<300).contains(status) else {
                if (400..<500).contains(status) {
                    Log.error(self.logTag, "report_subscription 客户端错误 status=\(status)，出队不再重试 txn=\(item.dedupKey) req=\(requestID)")
                    self.dequeue(item)
                } else {
                    Log.error(self.logTag, "report_subscription 服务端错误 status=\(status)，保留队列待重试 req=\(requestID)")
                }
                return
            }
            let payload = (json?["data"] as? [String: Any]) ?? [:]
            if let code = json?["code"] as? Int, code != 0 && code != 200 {
                // 403 = 服务端验签说这份凭据不是 Apple 签的 / 不是本 App 的：不会因重试而变真，出队；
                // 同时关掉「先信本地」的窗口，让服务端结论生效。
                Log.error(self.logTag, "report_subscription 业务失败 code=\(code) msg=\(json?["msg"] as? String ?? "-")，出队不再重试 txn=\(item.dedupKey) req=\(requestID)")
                self.dequeue(item)
                if code == 403 {
                    Task { @MainActor in SubscriptionManager.shared.clearPendingLocalPurchase(reason: "服务端拒绝凭据 txn=\(item.dedupKey)") }
                }
                return
            }

            // 成功。
            self.dequeue(item)
            self.markReported(item.reportedKey)
            let verified = (payload["verified"] as? Bool) ?? false
            let level = (payload["effective_user_level"] as? String) ?? "-"
            Log.info(self.logTag, "report_subscription 成功 product=\(item.productID) verified=\(verified) effective_user_level=\(level) req=\(requestID)")

            Task { @MainActor in
                if let state = ServerMembershipState.parse(payload) {
                    // 响应就是一份完整的服务端会员状态（含 subscription / entitlement_authority），直接落地。
                    SubscriptionManager.shared.applyServerState(state, source: "report_subscription")
                } else {
                    // 老服务端：只带 premium_trial_end_at，沿用旧规矩只落体验期。
                    SubscriptionManager.shared.applyPremiumTrial(endAt: SubscriptionManager.parseServerDate(payload["premium_trial_end_at"]))
                }
                if verified {
                    SubscriptionManager.shared.clearPendingLocalPurchase(reason: "服务端已确认 txn=\(item.dedupKey)")
                }
            }
        }.resume()
    }

    private func dequeue(_ item: PendingReport) {
        var list = loadPending()
        list.removeAll { $0.dedupKey == item.dedupKey }
        savePending(list)
    }
}
