//
//  HomeService.swift
//  mindora
//
//  Created by GitHub Copilot.
//

import Foundation

struct HomeData: Codable {
    // Metrics (from HealthKit)
    let heartRate: String?
    let totalSleep: String?
    let sleepOnset: String?
    let deepSleep: String?

    // Cards (from API)
    let comfortAudioName: String?
    let usedTimes: Int?
    let comfortAudioScore: Int?
    let overallScore: Int?
    let insightTitle: String?
    let insightDescription: String?
}

class HomeService {
    static let shared = HomeService()
    private let logTag = "HomeService"
    
    private init() {}

    private let debugDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private struct LocalMetricsSnapshot {
        let heartRate: String?
        /// 实际睡眠时长（Core + Deep + REM + 未分期「睡着」，不含 Awake），
        /// 与睡眠日视图大字的时长同一数据源。首页「Sleep」格显示的就是它，不是卧床时间。
        let totalSleep: String?
        let sleepOnset: String?
        let deepSleep: String?
    }

    /// 入睡用时的统一格式化。本地值和服务端估算值都走它——同一个格子两种来源，
    /// 显示口径必须一致。不足 1 分钟显示 "<1min"：不能四舍五入成 "1min"（那是假的），
    /// 也不能当成无数据（用户确实几乎沾枕就睡）。
    private static func formatOnsetMinutes(_ minutes: Double?) -> String? {
        guard let minutes else { return nil }
        let rounded = Int(minutes.rounded())
        return rounded < 1 ? UnitDisplay.underOneMinute : UnitDisplay.minutes(rounded)
    }

    private func debugMetricString(_ metric: HealthMetrics.MetricValue?) -> String {
        guard let metric else { return "nil" }
        let timestamp = debugDateFormatter.string(from: metric.date)
        return String(format: "%.2f @ %@", metric.value, timestamp)
    }

    private func debugSleepSummaryString(_ summary: HealthMetrics.SleepValue?) -> String {
        guard let summary else { return "nil" }
        let timestamp = debugDateFormatter.string(from: summary.date)
        let deep = summary.deepSleepHours.map { String($0) } ?? "nil"
        let rem = summary.remSleepHours.map { String($0) } ?? "nil"
        let light = summary.lightSleepHours.map { String($0) } ?? "nil"
        let inBed = summary.timeInBed.map { String($0) } ?? "nil"
        return "total=\(summary.totalSleepHours), deep=\(deep), rem=\(rem), light=\(light), inBed=\(inBed), date=\(timestamp)"
    }

    private func debugDailyAggregateString(_ aggregate: HealthDataManager.SleepDailyAggregate?) -> String {
        guard let aggregate else { return "nil" }
        let timestamp = debugDateFormatter.string(from: aggregate.date)
        let onset = aggregate.sleepOnsetMinutes.map { String($0) } ?? "nil"
        return "date=\(timestamp), total=\(aggregate.totalSleepHours), deep=\(aggregate.deepSleepHours), rem=\(aggregate.remSleepHours), core=\(aggregate.coreSleepHours), awakeMinutes=\(aggregate.awakeMinutes), inBed=\(aggregate.timeInBedHours), onset=\(onset)"
    }

    private struct AnalysisOverviewRequest: Encodable {
        let requestType = "analysis_overview"
        let version = "1.0"
        let timestamp: Int
        let data: Payload

        struct Payload: Encodable {
            let uid: String
            let jwtToken: String
            let language: String
            let date: String
            let timezone: String
            let modules: [String]

            enum CodingKeys: String, CodingKey {
                case uid
                case jwtToken = "jwt_token"
                case language
                case date
                case timezone
                case modules
            }
        }

        enum CodingKeys: String, CodingKey {
            case requestType = "request_type"
            case version
            case timestamp
            case data
        }
    }

    private struct HomeDashboardResponse: Decodable {
        let code: Int
        let msg: String?
        let data: DashboardData?
    }

    private struct DashboardData: Decodable {
        let overallScore: OverallScorePayload?
        let weeklyBest: WeeklyBestPayload?
        let sleepInsight: SleepInsightPayload?
        let sleepMetrics: SleepMetricsPayload?

        enum CodingKeys: String, CodingKey {
            case overallScore = "overall_score"
            case weeklyBest = "weekly_best"
            case sleepInsight = "sleep_insight"
            case sleepMetrics = "sleep_metrics"
        }
    }

    /// 服务端估算的睡眠指标，**只在本地 HealthKit 读不到时**兜底。
    ///
    /// 为什么需要：只戴 Apple Watch、不开 iPhone「睡眠专注」、不装第三方睡眠 App 的用户，
    /// HealthKit 里完全没有 inBed 样本，入睡用时算不出参照起点，Sleep Onset 恒空
    /// （真机日志实测 onset 一次都没有过值）。这是该类数据源的固定结果，只能由服务端估算。
    ///
    /// 单位是分钟数值而非格式化字符串：本地值和服务端值会出现在同一个格子里，
    /// 必须走同一个 formatter 才不会两次长得不一样。
    private struct SleepMetricsPayload: Decodable {
        let sleepOnsetMinutes: Double?
        /// 首页不展示（首页 Sleep 格是实际睡眠时长），Day 页的 Time in Bed 用它；两个接口同结构，服务端只实现一份估算逻辑。
        let timeInBedMinutes: Double?
        let source: String?

        enum CodingKeys: String, CodingKey {
            case sleepOnsetMinutes = "sleep_onset_minutes"
            case timeInBedMinutes = "time_in_bed_minutes"
            case source
        }
    }

    private struct OverallScorePayload: Decodable {
        let score: Int?
    }

    private struct WeeklyBestPayload: Decodable {
        let audioName: String?
        let usedTimes: Int?
        let score: Int?

        enum CodingKeys: String, CodingKey {
            case audioName = "audio_name"
            case usedTimes = "used_times"
            case score
        }
    }

    private struct SleepInsightPayload: Decodable {
        let title: String?
        let description: String?
    }

    private enum HomeServiceError: Error {
        case invalidURL
        case invalidResponse
        case apiError(code: Int, message: String?)
    }
    
    func fetchHomeData(completion: @escaping (Result<HomeData, Error>) -> Void) {
        if Constants.Config.showMockData {
            // Mock data for UI preview (DEBUG only)
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                let mockData = HomeData(
                    heartRate: "80",
                    totalSleep: "12h44min",
                    sleepOnset: "5min",
                    deepSleep: "5h",
                    comfortAudioName: "Sedona Red Rocks",
                    usedTimes: 5,
                    comfortAudioScore: 92,
                    overallScore: 88,
                    insightTitle: "Excellent Deep Sleep Performance",
                    insightDescription: "Your deep sleep accounts for 29.8% of your total sleep, above the standard level. Keep maintaining a regular sleep schedule."
                )
                DispatchQueue.main.async {
                    completion(.success(mockData))
                }
            }
            return
        }
        
        // Real mode: fetch data from HealthKit + API
        fetchRealData(completion: completion)
    }
    
    private func fetchRealData(completion: @escaping (Result<HomeData, Error>) -> Void) {
        Task {
            // 上次成功的首页数据。进入即先回显（综合评分/心率等不再先空着干等 API），
            // 之后用新数据「逐字段」覆盖：新值有就用新值，新值为空则保留缓存，避免某次接口空了就变 "--"。
            let cached = Self.loadCachedHomeData()
            if let cached {
                DispatchQueue.main.async { completion(.success(cached)) }
            }

            // 像 Apple 一样：把首页对齐到「最近有数据的那一晚」，而不是死锚今天导致睡眠/入睡/深睡/评分全空。
            let anchorDay = (try? await HealthDataManager.shared.fetchMostRecentSleepDay(forceLive: true))
                ?? HealthDataManager.shared.cachedMostRecentSleepDay
                ?? Calendar.current.startOfDay(for: Date())

            // 用非结构化 Task 而不是 `async let`：理由见 HealthDataManager 里的说明
            let dashboardTask = Task { try await self.fetchDashboardData(anchorDate: anchorDay) }

            let localMetrics: LocalMetricsSnapshot
            do {
                localMetrics = try await fetchLocalMetrics(anchorDate: anchorDay)
            } catch {
                Log.error(logTag, "Failed to fetch HealthKit metrics: \(error)")
                localMetrics = LocalMetricsSnapshot(
                    heartRate: nil,
                    totalSleep: nil,
                    sleepOnset: nil,
                    deepSleep: nil
                )
            }

            // 本地指标先合并缓存回显（卡片类还没拿到，先用缓存值占位）。
            let localOnlyData = HomeData(
                heartRate: localMetrics.heartRate ?? cached?.heartRate,
                totalSleep: localMetrics.totalSleep ?? cached?.totalSleep,
                sleepOnset: localMetrics.sleepOnset ?? cached?.sleepOnset,
                deepSleep: localMetrics.deepSleep ?? cached?.deepSleep,
                comfortAudioName: cached?.comfortAudioName,
                usedTimes: cached?.usedTimes,
                comfortAudioScore: cached?.comfortAudioScore,
                overallScore: cached?.overallScore,
                insightTitle: cached?.insightTitle,
                insightDescription: cached?.insightDescription
            )

            DispatchQueue.main.async {
                completion(.success(localOnlyData))
            }

            let dashboardData: DashboardData?
            do {
                dashboardData = try await dashboardTask.value
            } catch {
                Log.error(logTag, "Failed to fetch analysis overview data: \(error)")
                dashboardData = nil
            }

            // 服务端字段的合并要区分两种「空」：
            // - 请求失败/未登录（dashboardData == nil）→ 偶发不可用，回退缓存，避免闪 "--"；
            // - 请求成功但模块为空 → 服务端明确说「没有内容」，必须清掉旧值，
            //   否则接口早就不返回了，UI 还一直显示缓存里的陈旧数据。
            // 本地 HealthKit 指标是「取不到」而非「不存在」，仍保留缓存回退。
            let serverAnswered = dashboardData != nil

            // Sleep Onset 是唯一「本地优先 + 服务端兜底」的指标：
            // 本地读到就用本地；本地读不到才用服务端估算值；服务端应答了但也没有估算出来，
            // 就得让它空着并清掉缓存旧值（那多半是别的日期的残留）；服务端没应答才回退缓存。
            let serverOnset = Self.formatOnsetMinutes(dashboardData?.sleepMetrics?.sleepOnsetMinutes)
            let mergedSleepOnset = localMetrics.sleepOnset
                ?? (serverAnswered ? serverOnset : cached?.sleepOnset)
            if localMetrics.sleepOnset == nil {
                Log.info(logTag, "Home sleepOnset 本地缺失 => serverAnswered=\(serverAnswered), server=\(serverOnset ?? "nil"), merged=\(mergedSleepOnset ?? "nil")")
            }

            // 首页「Sleep」格显示实际睡眠时长（去掉 Awake），只认本地 HealthKit。
            // 服务端的 time_in_bed_minutes 是卧床时间、含清醒，量不对，不能拿来兜底。
            let mergedTotalSleep = localMetrics.totalSleep ?? cached?.totalSleep

            let data = HomeData(
                heartRate: localMetrics.heartRate ?? cached?.heartRate,
                totalSleep: mergedTotalSleep,
                sleepOnset: mergedSleepOnset,
                deepSleep: localMetrics.deepSleep ?? cached?.deepSleep,
                comfortAudioName: serverAnswered ? dashboardData?.weeklyBest?.audioName : cached?.comfortAudioName,
                usedTimes: serverAnswered ? dashboardData?.weeklyBest?.usedTimes : cached?.usedTimes,
                comfortAudioScore: serverAnswered ? dashboardData?.weeklyBest?.score : cached?.comfortAudioScore,
                overallScore: serverAnswered ? dashboardData?.overallScore?.score : cached?.overallScore,
                insightTitle: serverAnswered ? dashboardData?.sleepInsight?.title : cached?.insightTitle,
                insightDescription: serverAnswered ? dashboardData?.sleepInsight?.description : cached?.insightDescription
            )

            Self.storeCachedHomeData(data)

            DispatchQueue.main.async {
                completion(.success(data))
            }
        }
    }

    // MARK: - 首页数据缓存（跨启动暂存上次成功结果，进入即回显）
    private static let homeCacheKey = "home.lastData.v1"

    private static func loadCachedHomeData() -> HomeData? {
        guard let raw = UserDefaults.standard.data(forKey: homeCacheKey) else { return nil }
        return try? JSONDecoder().decode(HomeData.self, from: raw)
    }

    private static func storeCachedHomeData(_ data: HomeData) {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        UserDefaults.standard.set(raw, forKey: homeCacheKey)
    }

    /// 清空首页缓存。用于登出 / 注销账号，避免上一账号数据残留。
    static func clearCache() {
        UserDefaults.standard.removeObject(forKey: homeCacheKey)
    }

    private func fetchLocalMetrics(anchorDate: Date = Date()) async throws -> LocalMetricsSnapshot {
        var heartRate: String?
        var totalSleep: String?
        var sleepOnset: String?
        var deepSleep: String?

        let metrics = try? await HealthDataManager.shared.fetchLatestHomeMetrics(forceLive: true)
        // 入睡用时等取「最近睡眠日」那一晚的聚合，而不是今天（今天往往还没数据 → 空）。
        let dailySleep = try? await HealthDataManager.shared.fetchSleepDailyAggregates(days: 1, endingAt: anchorDate).last

        let rawMetricsLog = [
            "latestHeartRate=\(debugMetricString(metrics?.heartRate))",
            "latestSleepSummary=\(debugSleepSummaryString(metrics?.sleepSummary))",
            "latestDailyAggregate=\(debugDailyAggregateString(dailySleep))"
        ].joined(separator: ", ")
        Log.info(logTag, "Home raw local metrics => \(rawMetricsLog)")

        // 首页顶部显示「Sleep Heart Rate」区间（如 56-79），与点进去的睡眠日视图
        // Sleep Performance 卡用同一数据源、保持一致。
        if let range = metrics?.sleepHeartRateRange {
            heartRate = "\(Int(range.min.rounded()))-\(Int(range.max.rounded()))"
        }

        // 首页「Sleep」显示实际睡眠时长（不含 Awake），与睡眠日视图大字同源（sleepSummary.totalSleepHours）
        if let sleepSummary = metrics?.sleepSummary {
            if sleepSummary.totalSleepHours > 0 {
                totalSleep = formatHoursAndMinutes(sleepSummary.totalSleepHours)
            }

            if let deepValue = sleepSummary.deepSleepHours {
                deepSleep = formatHoursAndMinutes(deepValue)
            }
        }

        if totalSleep == nil, let totalHours = dailySleep?.totalSleepHours, totalHours > 0 {
            totalSleep = formatHoursAndMinutes(totalHours)
        }

        if deepSleep == nil, let deepSleepHours = dailySleep?.deepSleepHours, deepSleepHours > 0 {
            deepSleep = formatHoursAndMinutes(deepSleepHours)
        }

        // 不可测的情况 sleepOnsetMinutes 已经返回 nil（见 SleepSampleResolver），
        // 这里拿到值就一定是真实的入睡用时。本地拿不到时由服务端估算值兜底，
        // 合并在 fetchRealData 里做（那里才拿得到接口应答）。
        sleepOnset = Self.formatOnsetMinutes(dailySleep?.sleepOnsetMinutes)

        let formattedHeartRate = heartRate ?? "nil"
        let formattedTotalSleep = totalSleep ?? "nil"
        let formattedSleepOnset = sleepOnset ?? "nil"
        let formattedDeepSleep = deepSleep ?? "nil"
        let formattedMetricsLog = "Home formatted local metrics => heartRate=\(formattedHeartRate), totalSleep=\(formattedTotalSleep), sleepOnset=\(formattedSleepOnset), deepSleep=\(formattedDeepSleep)"

        Log.info(logTag, formattedMetricsLog)

        return LocalMetricsSnapshot(
            heartRate: heartRate,
            totalSleep: totalSleep,
            sleepOnset: sleepOnset,
            deepSleep: deepSleep
        )
    }

    private func fetchDashboardData(anchorDate: Date = Date()) async throws -> DashboardData? {
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let jwtToken = AuthStorage.shared.token, !jwtToken.isEmpty else {
            return nil
        }

        guard let url = URL(string: Constants.Network.analysisURL) else {
            throw HomeServiceError.invalidURL
        }

        let payload = AnalysisOverviewRequest(
            timestamp: Int(Date().timeIntervalSince1970),
            data: .init(
                uid: uid,
                jwtToken: jwtToken,
                language: LocalizationManager.shared.currentLanguage.rawValue,
                date: currentLocalDateString(for: anchorDate),
                timezone: TimeZone.current.identifier,
                modules: ["overall_score", "weekly_best", "sleep_insight", "sleep_metrics"]
            )
        )
        let requestID = Log.requestID()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.Network.analysisTimeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        RequestTrace.apply(&request, requestID: requestID)

        if let token = AuthStorage.shared.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = try JSONEncoder().encode(payload)
        request.httpBody = body

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "[req:\(requestID)] analysis_overview request url=\(url.absoluteString)")
            Log.info(logTag, "[req:\(requestID)] analysis_overview request body=\(Log.prettyJSON(body))")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        SessionExpirationCenter.handle(httpResponse: response, data: data, requestID: requestID)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                Log.error(logTag, "[req:\(requestID)] analysis_overview invalid HTTP status=\(httpResponse.statusCode)")
                if Constants.Config.enableNetworkLogging {
                    Log.error(logTag, "[req:\(requestID)] analysis_overview error response body=\(Log.prettyJSON(data))")
                }
            } else {
                Log.error(logTag, "[req:\(requestID)] analysis_overview invalid HTTP response")
            }
            throw HomeServiceError.invalidResponse
        }

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "[req:\(requestID)] analysis_overview response status=\(httpResponse.statusCode)")
            Log.info(logTag, "[req:\(requestID)] analysis_overview response body=\(Log.prettyJSON(data))")
        }

        let decoded = try JSONDecoder().decode(HomeDashboardResponse.self, from: data)
        guard decoded.code == 0 else {
            Log.error(logTag, "[req:\(requestID)] analysis_overview business error code=\(decoded.code), msg=\(decoded.msg ?? "")")
            throw HomeServiceError.apiError(code: decoded.code, message: decoded.msg)
        }

        Log.info(logTag, "[req:\(requestID)] analysis_overview completed successfully")

        // code==0 但 data 为 null 也是服务端的明确应答（= 各模块都没有内容），
        // 映射成空 DashboardData 而不是 nil，nil 只留给「未登录 / 请求失败」→ 回退缓存。
        return decoded.data ?? DashboardData(overallScore: nil, weeklyBest: nil, sleepInsight: nil, sleepMetrics: nil)
    }

    private func formatHoursAndMinutes(_ hoursValue: Double) -> String {
        // 先化成分钟再四舍五入：分开截断会比苹果健康少 1 分钟，也会算出「1h60min」。
        // 首页圆圈固定字号，放不下 `8 hr 20 min`，用紧凑写法。
        UnitDisplay.compactDuration(hours: hoursValue)
    }

    private func currentLocalDateString(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
