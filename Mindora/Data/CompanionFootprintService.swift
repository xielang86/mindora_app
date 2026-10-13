//
//  CompanionFootprintService.swift
//  mindora
//
//  陪伴足迹：上传每日使用足迹 + 拉取月份 / 全年汇总。对齐 Tools/doc/陪伴足迹接口.md。
//

import Foundation

// MARK: - 数据模型

/// 单日足迹标记。
struct FootprintDay {
    let day: Int              // 1...31
    let appActive: Bool       // App 活跃（日历实心紫底）
    let sleepCompanion: Bool  // 助眠陪伴（标记点）
    let planCompleted: Bool   // 完成计划 / 连续陪伴（金色标记）
}

/// 三项统计。
struct FootprintStats {
    let sleepCompanionMonth: Int   // 助眠陪伴·本月累计
    let appActiveMonth: Int        // App 活跃·本月累计
    let continuousUseYear: Int     // 连续使用·全年累计
}

/// 里程碑记录。
struct FootprintMilestone {
    let title: String
    let dateRange: String
    let desc: String
    let completed: Bool
}

/// 月视图汇总。
struct FootprintMonth {
    let year: Int
    let month: Int
    let anchorDate: Date?
    let weekday: Int?          // 1=周一 ... 7=周日
    let stats: FootprintStats?
    let days: [FootprintDay]
    let milestones: [FootprintMilestone]
}

// MARK: - 服务

final class CompanionFootprintService {
    static let shared = CompanionFootprintService()
    private let logTag = "Footprint"
    private init() {}

    enum FootprintError: Error { case message(String) }

    // MARK: 拉取单月

    func fetchMonth(year: Int, month: Int, completion: @escaping (Result<FootprintMonth, Error>) -> Void) {
        if Constants.Config.showMockData {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion(.success(Self.mockMonth(year: year, month: month)))
            }
            return
        }
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let token = AuthStorage.shared.token, !token.isEmpty,
              let url = URL(string: Constants.Network.companionFootprintURL) else {
            completion(.success(Self.emptyMonth(year: year, month: month)))
            return
        }

        let body: [String: Any] = [
            "request_type": "query_footprint",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": [
                "uid": uid,
                "jwt_token": token,
                "language": LocalizationManager.shared.currentLanguage.rawValue,
                "timezone": TimeZone.current.identifier,
                "scope": "month",
                "year": year,
                "month": month
            ]
        ]
        post(url: url, body: body) { [weak self] json in
            guard let self else { return }
            guard let payload = json?["data"] as? [String: Any] else {
                completion(.success(Self.emptyMonth(year: year, month: month))); return
            }
            completion(.success(Self.parseMonth(payload, year: year, month: month)))
        } onError: { _ in
            completion(.success(Self.emptyMonth(year: year, month: month)))
        }
    }

    // MARK: 拉取全年

    func fetchYear(year: Int, completion: @escaping (Result<[FootprintMonth], Error>) -> Void) {
        if Constants.Config.showMockData {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion(.success((1...12).map { Self.mockMonth(year: year, month: $0) }))
            }
            return
        }
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let token = AuthStorage.shared.token, !token.isEmpty,
              let url = URL(string: Constants.Network.companionFootprintURL) else {
            completion(.success((1...12).map { Self.emptyMonth(year: year, month: $0) }))
            return
        }
        let body: [String: Any] = [
            "request_type": "query_footprint",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": [
                "uid": uid,
                "jwt_token": token,
                "language": LocalizationManager.shared.currentLanguage.rawValue,
                "timezone": TimeZone.current.identifier,
                "scope": "year",
                "year": year
            ]
        ]
        post(url: url, body: body) { json in
            guard let payload = json?["data"] as? [String: Any],
                  let rawMonths = payload["months"] as? [[String: Any]] else {
                completion(.success((1...12).map { Self.emptyMonth(year: year, month: $0) })); return
            }
            // 服务端可能只下发有数据的月份：按 month 建索引后补齐 1...12，保证全年 12 张卡片。
            var byMonth: [Int: FootprintMonth] = [:]
            for raw in rawMonths {
                guard let m = raw["month"] as? Int, (1...12).contains(m) else { continue }
                byMonth[m] = Self.parseMonth(raw, year: year, month: m)
            }
            let months = (1...12).map { byMonth[$0] ?? Self.emptyMonth(year: year, month: $0) }
            completion(.success(months))
        } onError: { _ in
            completion(.success((1...12).map { Self.emptyMonth(year: year, month: $0) }))
        }
    }

    // MARK: 上传足迹

    /// 上传每日使用足迹（客户端按自然日聚合后调用；服务端幂等合并）。
    func uploadDays(_ days: [[String: Any]], completion: ((Bool) -> Void)? = nil) {
        guard !Constants.Config.showMockData,
              let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let token = AuthStorage.shared.token, !token.isEmpty,
              let url = URL(string: Constants.Network.companionFootprintURL) else {
            completion?(false); return
        }
        let body: [String: Any] = [
            "request_type": "upload_footprint",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": [
                "uid": uid,
                "jwt_token": token,
                "language": LocalizationManager.shared.currentLanguage.rawValue,
                "timezone": TimeZone.current.identifier,
                "days": days
            ]
        ]
        // 校验业务 code：只有 code=0/200 才算成功（调用方据此决定是否把本地待传标记 final）。
        post(url: url, body: body) { json in
            let code = json?["code"] as? Int
            completion?(code == 0 || code == 200)
        } onError: { _ in completion?(false) }
    }

    /// 陪伴足迹本地缓存清理（登出 / 注销时调用）：清掉 FootprintTracker 的待传日记录。
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: FootprintTracker.storeKey)
    }

    // MARK: 网络工具

    private func post(url: URL,
                      body: [String: Any],
                      onSuccess: @escaping ([String: Any]?) -> Void,
                      onError: @escaping (Error) -> Void) {
        var req = URLRequest(url: url)
        RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = Constants.Network.timeoutInterval
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            if let http = response as? HTTPURLResponse, let data {
                SessionExpirationCenter.handle(httpResponse: http, data: data)
            }
            if let error {
                Log.error(self.logTag, "footprint error=\(error.localizedDescription)")
                DispatchQueue.main.async { onError(error) }
                return
            }
            let json = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any]
            DispatchQueue.main.async { onSuccess(json) }
        }.resume()
    }

    // MARK: 解析

    private static func parseMonth(_ dict: [String: Any], year: Int, month: Int) -> FootprintMonth {
        let rawDays = dict["days"] as? [[String: Any]] ?? []
        let days: [FootprintDay] = rawDays.compactMap { d in
            guard let day = d["day"] as? Int else { return nil }
            return FootprintDay(day: day,
                                appActive: d["app_active"] as? Bool ?? false,
                                sleepCompanion: d["sleep_companion"] as? Bool ?? false,
                                planCompleted: d["plan_completed"] as? Bool ?? false)
        }
        var stats: FootprintStats?
        if let s = dict["stats"] as? [String: Any] {
            stats = FootprintStats(
                sleepCompanionMonth: s["sleep_companion_month"] as? Int ?? 0,
                appActiveMonth: s["app_active_month"] as? Int ?? 0,
                continuousUseYear: s["continuous_use_year"] as? Int ?? 0)
        }
        let milestones: [FootprintMilestone] = (dict["milestones"] as? [[String: Any]] ?? []).map {
            FootprintMilestone(title: $0["title"] as? String ?? "",
                               dateRange: $0["date_range"] as? String ?? "",
                               desc: $0["desc"] as? String ?? "",
                               completed: $0["completed"] as? Bool ?? false)
        }
        var anchor: Date?
        if let s = dict["anchor_date"] as? String {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
            anchor = f.date(from: s)
        }
        return FootprintMonth(year: dict["year"] as? Int ?? year,
                              month: dict["month"] as? Int ?? month,
                              anchorDate: anchor,
                              weekday: dict["weekday"] as? Int,
                              stats: stats,
                              days: days,
                              milestones: milestones)
    }

    // MARK: 空态（无服务端时不编造数据，展示 0 / 空日历 / 无里程碑）

    static func emptyMonth(year: Int, month: Int) -> FootprintMonth {
        // 顶部卡片始终显示日期：无数据时锚定到今天（若查询月即当月）或该月 1 号。
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let anchor: Date
        if cal.component(.year, from: now) == year, cal.component(.month, from: now) == month {
            anchor = cal.startOfDay(for: now)
        } else {
            anchor = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? now
        }
        let weekday = (cal.component(.weekday, from: anchor) + 5) % 7 + 1  // 1=周一
        return FootprintMonth(year: year, month: month,
                              anchorDate: anchor, weekday: weekday,
                              stats: FootprintStats(sleepCompanionMonth: 0, appActiveMonth: 0, continuousUseYear: 0),
                              days: [], milestones: [])
    }

    // MARK: Mock（仅 DEBUG showMockData 预览用）

    static func mockMonth(year: Int, month: Int) -> FootprintMonth {
        var comps = DateComponents(); comps.year = year; comps.month = month
        let cal = Calendar(identifier: .gregorian)
        let daysInMonth = cal.range(of: .day, in: .month, for: cal.date(from: comps) ?? Date())?.count ?? 30

        // 生成一批「活跃」的日期（伪随机但确定，不依赖 Date.now/random）。
        var days: [FootprintDay] = []
        for d in 1...daysInMonth {
            let active = (d * 7 + month) % 3 != 0
            let companion = active && (d % 2 == 0)
            let plan = (d % 11 == 0)
            if active || companion || plan {
                days.append(FootprintDay(day: d, appActive: active, sleepCompanion: companion, planCompleted: plan))
            }
        }
        let anchor = cal.date(from: DateComponents(year: year, month: month, day: min(23, daysInMonth)))
        let weekday = anchor.map { (cal.component(.weekday, from: $0) + 5) % 7 + 1 }  // 1=周一
        return FootprintMonth(
            year: year, month: month,
            anchorDate: anchor, weekday: weekday,
            stats: FootprintStats(sleepCompanionMonth: 12, appActiveMonth: 18, continuousUseYear: 94),
            days: days,
            milestones: [
                FootprintMilestone(title: L("footprint.milestone.sleep_plan"),
                                   dateRange: "2027.5.25-2027.5.30",
                                   desc: String(format: L("footprint.milestone.days_completed"), 5),
                                   completed: true),
                FootprintMilestone(title: L("footprint.milestone.sleep_plan"),
                                   dateRange: "2027.4.10-2027.4.13",
                                   desc: String(format: L("footprint.milestone.days_completed"), 3),
                                   completed: true)
            ])
    }
}
