//
//  RedeemService.swift
//  mindora
//
//  兑换码兑换（对齐 doc/duihuan.md）：POST /auth，request_type=redeem_redemption_code，
//  data 必填 jwt_token + redemption_code（uid 可选，服务端从 token 解析）。
//  成功：HTTP 2xx + {code:0/200, data:{effective_user_level/user_level, level_end_at, ...}}。
//  失败：HTTP 非 2xx + FastAPI {detail: "..."} 或 {detail:[{msg:...}]}。
//

import Foundation

final class RedeemService {
    static let shared = RedeemService()
    private let logTag = "Redeem"
    private init() {}

    enum RedeemError: Error { case message(String) }

    struct Success {
        let level: String        // pro / premium
        let endAt: Date?         // 服务端返回的到期时间（可能解析不到，按 nil 处理）
        let durationDays: Int?   // 本次兑换的会员天数（365≈年卡 / 30≈月卡），用于本地累加到期
        /// 服务端下发的高级会员体验期结束时刻（见《订阅权益与定价方案》待确认第 2 条）。
        /// 服务端未下发该字段 → nil，客户端保留已有值不动。
        let premiumTrialEndAt: Date?
    }

    func redeem(code: String) async throws -> Success {
        guard let token = AuthStorage.shared.token, !token.isEmpty else {
            throw RedeemError.message(L("redeem.error.not_logged_in"))
        }
        guard let url = URL(string: Constants.Network.authURL) else {
            throw RedeemError.message(L("redeem.error.generic"))
        }

        var dataDict: [String: Any] = [
            "jwt_token": token,
            "redemption_code": code,
            // 失败提示由服务端按这个语言翻译
            "language": LocalizationManager.shared.currentLanguage.rawValue
        ]
        if let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty {
            dataDict["uid"] = uid
        }
        let body: [String: Any] = [
            "request_type": "redeem_redemption_code",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": dataDict
        ]

        var req = URLRequest(url: url)

        RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = Constants.Network.timeoutInterval
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw RedeemError.message(L("redeem.error.generic"))
        }
        SessionExpirationCenter.handle(httpResponse: http, data: data)

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        // 失败：HTTP 非 2xx → FastAPI {detail}
        if !(200..<300).contains(http.statusCode) {
            Log.error(logTag, "redeem http=\(http.statusCode) body=\(String(data: data, encoding: .utf8) ?? "")")
            throw RedeemError.message(ServerError.parse(json)?.displayMessage ?? L("redeem.error.generic"))
        }
        // 业务码（与登录一致：0/200 成功）
        if let code = json?["code"] as? Int, code != 0 && code != 200 {
            throw RedeemError.message(ServerError.parse(json)?.displayMessage ?? L("redeem.error.generic"))
        }

        let payload = (json?["data"] as? [String: Any]) ?? json ?? [:]
        let level = (payload["effective_user_level"] as? String)
            ?? (payload["user_level"] as? String)
            ?? "pro"
        let endAt = parseDate(payload["level_end_at"])
        let durationDays = (payload["duration_days"] as? Int) ?? (payload["duration_days"] as? NSNumber)?.intValue
        let trialEndAt = SubscriptionManager.parseServerDate(payload["premium_trial_end_at"])
        let membershipName = level.capitalized   // pro -> Pro, premium -> Premium
        Log.info(logTag, "redeem success membership=\(membershipName) (level=\(level)) durationDays=\(String(describing: durationDays)) endAt=\(String(describing: endAt)) trialEndAt=\(String(describing: trialEndAt))")
        return Success(level: level, endAt: endAt, durationDays: durationDays, premiumTrialEndAt: trialEndAt)
    }

    private func parseDate(_ value: Any?) -> Date? {
        guard let s = value as? String, !s.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}
