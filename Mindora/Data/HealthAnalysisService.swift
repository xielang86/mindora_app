import Foundation

final class HealthAnalysisService {
    static let shared = HealthAnalysisService()
    private let logTag = "HealthAnalysisService"

    // MARK: - 分析结果缓存
    // 统一走 ServerBackedStore（见 ServerDataResolution.swift）：内存 + UserDefaults 双层，
    // 并把「应答为空」与「请求失败」分成两种结果。namespace 与历史持久化键一致，老缓存不失效。
    private let dayStore = ServerBackedStore<DayAnalysis>(namespace: "health.analysis.day")
    private let weekStore = ServerBackedStore<WeekAnalysis>(namespace: "health.analysis.week")
    private let monthStore = ServerBackedStore<MonthAnalysis>(namespace: "health.analysis.month")

    private func periodKey(_ start: Date, _ end: Date) -> String {
        let cal = Calendar.current
        return "\(Int(cal.startOfDay(for: start).timeIntervalSince1970))_\(Int(cal.startOfDay(for: end).timeIntervalSince1970))"
    }
    private func dayKey(_ date: Date) -> String {
        "\(Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970))"
    }

    /// 同步返回上次缓存的当天分析（无则 nil）。供视图进入时即时渲染，避免等网络白屏。
    func cachedDayAnalysis(date: Date) -> DayAnalysis? { dayStore.cached(dayKey(date)) }
    /// 同步返回上次缓存的本周分析（无则 nil）。
    func cachedWeekAnalysis(startDate: Date, endDate: Date) -> WeekAnalysis? {
        weekStore.cached(periodKey(startDate, endDate))
    }
    /// 同步返回上次缓存的本月分析（无则 nil）。
    func cachedMonthAnalysis(startDate: Date, endDate: Date) -> MonthAnalysis? {
        monthStore.cached(periodKey(startDate, endDate))
    }

    /// 清空全部分析缓存（内存 + 磁盘）。用于登出 / 注销账号，避免上一账号数据残留。
    func clearCache() {
        dayStore.clearAll()
        weekStore.clearAll()
        monthStore.clearAll()
    }

    struct DayAnalysis: Codable {
        let scoreSummary: ScoreSummary?
        let sleepScenarios: SleepScenario?
        let stageInsights: StageInsights?
        /// 服务端估算的睡眠指标，**只在本地 HealthKit 读不到时**兜底，见 `SleepMetrics`。
        let sleepMetrics: SleepMetrics?

        struct ScoreSummary: Codable {
            let score: Int?
            let date: String?
        }

        /// 服务端估算的入睡用时 / 卧床时间。
        ///
        /// 为什么需要：只戴 Apple Watch、不开 iPhone「睡眠专注」、不装第三方睡眠 App 的用户，
        /// HealthKit 里**完全没有 inBed 样本**（真机日志实测 inBed 恒为 0），于是
        /// Time in Bed 恒空；没有 inBed 时入睡用时又退回首个阶段区间起点作参照，
        /// 而 Watch 往往第一段就直接是睡眠阶段，Sleep Onset 也恒空。这是该类数据源的
        /// 固定结果，客户端本地无法自救，只能由服务端按已上传的睡眠数据估算。
        ///
        /// 单位是**分钟数值**而非格式化字符串：同一个格子可能一次显示本地值、一次显示
        /// 服务端值，必须用同一套 formatter 才不会两次长得不一样（入睡用时不足 1 分钟
        /// 显示 "<1min" 这类口径服务端也无法预知）。
        ///
        /// `nil` 与 `0` 是两回事：nil = 估算不出来，0 = 确实沾枕就睡。服务端约定估算
        /// 不出时返回 null 而非 0。
        struct SleepMetrics: Codable {
            let sleepOnsetMinutes: Int?
            let timeInBedMinutes: Int?
            /// `measured` = 由真实 inBed 样本得出；`estimated` = 服务端估算。当前仅用于排查。
            let source: String?
            let date: String?

            enum CodingKeys: String, CodingKey {
                case sleepOnsetMinutes = "sleep_onset_minutes"
                case timeInBedMinutes = "time_in_bed_minutes"
                case source
                case date
            }
        }

        struct SleepScenario: Codable {
            let title: String?
            let description: String?
            let date: String?
        }

        struct StageInsights: Codable {
            let awake: StageInsight?
            let rem: StageInsight?
            let core: StageInsight?
            let deep: StageInsight?
        }

        struct StageInsight: Codable {
            let description: String?
            let date: String?
        }
    }

    /// 服务端估算的**区间日均**入睡用时 / 卧床时间，Week 和 Month 共用。
    ///
    /// 和 `DayAnalysis.SleepMetrics` 是同一件事的两种口径，缺失原因也完全一样：
    /// 只戴 Apple Watch 的用户 HealthKit 里没有 `inBed` 样本，于是 Week / Month
    /// 那张 Time in Bed 卡的卡头数值和展开后的 Avg. Onset 行整段恒空。
    ///
    /// 字段名带 `avg_` 前缀是刻意的：单日值和日均值混用一个名字，服务端和客户端
    /// 两头都容易把「某一天」当成「一周平均」。
    struct PeriodSleepMetrics: Codable {
        let avgSleepOnsetMinutes: Int?
        let avgTimeInBedMinutes: Int?
        /// 参与求均值的天数。不展示（Days Tracked 那一行用的是本地统计），只为排查均值按几天算的。
        let trackedDays: Int?
        /// `measured` = 由真实 inBed 样本得出；`estimated` = 服务端估算。当前仅用于排查。
        let source: String?
        let startDate: String?
        let endDate: String?

        enum CodingKeys: String, CodingKey {
            case avgSleepOnsetMinutes = "avg_sleep_onset_minutes"
            case avgTimeInBedMinutes = "avg_time_in_bed_minutes"
            case trackedDays = "tracked_days"
            case source
            case startDate = "start_date"
            case endDate = "end_date"
        }
    }

    struct WeekAnalysis: Codable {
        let scoreSummary: ScoreSummary?
        let sleepTrends: SleepTrends?
        let onsetEfficiency: OnsetEfficiency?
        /// 服务端估算的日均睡眠指标，**只在本地 HealthKit 读不到时**兜底，见 `PeriodSleepMetrics`。
        let sleepMetrics: PeriodSleepMetrics?

        struct ScoreSummary: Codable {
            let score: Int?
            let label: String?
            let startDate: String?
            let endDate: String?

            enum CodingKeys: String, CodingKey {
                case score
                case label
                case startDate = "start_date"
                case endDate = "end_date"
            }
        }

        struct SleepTrends: Codable {
            let body: String?
            let description: String?
            let startDate: String?
            let endDate: String?

            enum CodingKeys: String, CodingKey {
                case body
                case description
                case startDate = "start_date"
                case endDate = "end_date"
            }
        }

        struct OnsetEfficiency: Codable {
            let scenarioName: String?
            let usedTimes: Int?
            let score: Int?
            let startDate: String?
            let endDate: String?

            enum CodingKeys: String, CodingKey {
                case scenarioName = "scenario_name"
                case usedTimes = "used_times"
                case score
                case startDate = "start_date"
                case endDate = "end_date"
            }
        }
    }

    struct MonthAnalysis: Codable {
        let scoreSummary: ScoreSummary?
        let sleepTrends: SleepTrends?
        let onsetEfficiency: OnsetEfficiency?
        /// 服务端估算的日均睡眠指标，**只在本地 HealthKit 读不到时**兜底，见 `PeriodSleepMetrics`。
        let sleepMetrics: PeriodSleepMetrics?

        struct ScoreSummary: Codable {
            let score: Int?
            let label: String?
            let startDate: String?
            let endDate: String?

            enum CodingKeys: String, CodingKey {
                case score
                case label
                case startDate = "start_date"
                case endDate = "end_date"
            }
        }

        struct SleepTrends: Codable {
            struct ScorePoint: Codable {
                let date: String
                let score: Int
            }

            let body: String?
            let description: String?
            let scoreSeries: [ScorePoint]?
            let startDate: String?
            let endDate: String?

            enum CodingKeys: String, CodingKey {
                case body
                case description
                case scoreSeries = "score_series"
                case startDate = "start_date"
                case endDate = "end_date"
            }
        }

        struct OnsetEfficiency: Codable {
            let scenarioList: [String]?
            let description: String?
            let startDate: String?
            let endDate: String?

            enum CodingKeys: String, CodingKey {
                case scenarioList = "scenario_list"
                case description
                case startDate = "start_date"
                case endDate = "end_date"
            }
        }
    }

    private struct AnalysisRequest: Encodable {
        let requestType: String
        let version = "1.0"
        let timestamp: Int
        let data: Payload

        struct Payload: Encodable {
            let uid: String
            let jwtToken: String
            let language: String
            let date: String?
            let startDate: String?
            let endDate: String?
            let timezone: String
            let modules: [String]

            enum CodingKeys: String, CodingKey {
                case uid
                case jwtToken = "jwt_token"
                case language
                case date
                case startDate = "start_date"
                case endDate = "end_date"
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

    private struct ResponseEnvelope<Payload: Decodable>: Decodable {
        let code: Int
        let msg: String?
        let data: Payload?
    }

    private struct DayAnalysisPayload: Decodable {
        let scoreSummary: DayAnalysis.ScoreSummary?
        let sleepScenarios: DayAnalysis.SleepScenario?
        let stageInsights: DayAnalysis.StageInsights?
        let sleepMetrics: DayAnalysis.SleepMetrics?

        enum CodingKeys: String, CodingKey {
            case scoreSummary = "score_summary"
            case sleepScenarios = "sleep_scenarios"
            case stageInsights = "stage_insights"
            case sleepMetrics = "sleep_metrics"
        }
    }

    private struct WeekAnalysisPayload: Decodable {
        let scoreSummary: WeekAnalysis.ScoreSummary?
        let sleepTrends: WeekAnalysis.SleepTrends?
        let onsetEfficiency: WeekAnalysis.OnsetEfficiency?
        let sleepMetrics: PeriodSleepMetrics?

        enum CodingKeys: String, CodingKey {
            case scoreSummary = "score_summary"
            case sleepTrends = "sleep_trends"
            case onsetEfficiency = "onset_efficiency"
            case sleepMetrics = "sleep_metrics"
        }
    }

    private struct MonthAnalysisPayload: Decodable {
        let scoreSummary: MonthAnalysis.ScoreSummary?
        let sleepTrends: MonthAnalysis.SleepTrends?
        let onsetEfficiency: MonthAnalysis.OnsetEfficiency?
        let sleepMetrics: PeriodSleepMetrics?

        enum CodingKeys: String, CodingKey {
            case scoreSummary = "score_summary"
            case sleepTrends = "sleep_trends"
            case onsetEfficiency = "onset_efficiency"
            case sleepMetrics = "sleep_metrics"
        }
    }

    private enum ServiceError: Error {
        case invalidURL
        case missingCredentials
        case invalidResponse
        case apiError(code: Int, message: String?)
    }

    private init() {}

    func mockDayAnalysis(date: Date) -> DayAnalysis {
        let formattedDate = formatDate(date)
        return DayAnalysis(
            scoreSummary: .init(score: 70, date: formattedDate),
            sleepScenarios: .init(
                title: "Maldives Drift Sleep",
                description: "Last night, you went to bed at 12:00 AM and fell asleep around 12:05 AM. With the support of Cocoa Island Moonlight Drift, your sleep entered a stable rhythm within the first 30 minutes after falling asleep. The combination of pink noise and brown noise in the soundscape gently guided your breathing, helping you transition smoothly into deeper sleep.",
                date: formattedDate
            ),
            stageInsights: .init(
                awake: .init(description: "A brief awakening was detected at 2:15 AM, with a temporary 40% increase in respiratory rate. Mindora helped you return to sleep within 3 minutes.", date: formattedDate),
                rem: .init(description: "Deep, restorative sleep that helps with memory processing.", date: formattedDate),
                core: .init(description: "Essential sleep stage for physical recovery.", date: formattedDate),
                deep: .init(description: "The most restorative stage of sleep.", date: formattedDate)
            ),
            sleepMetrics: .init(
                sleepOnsetMinutes: 12,
                timeInBedMinutes: 462,
                source: "estimated",
                date: formattedDate
            )
        )
    }

    func mockWeekAnalysis(startDate: Date, endDate: Date) -> WeekAnalysis {
        let start = formatDate(startDate)
        let end = formatDate(endDate)
        return WeekAnalysis(
            scoreSummary: .init(score: 60, label: L("health.week.good"), startDate: start, endDate: end),
            sleepTrends: .init(
                body: "Excellent Deep Sleep Performance",
                description: "Your deep sleep accounted for a healthy proportion of total sleep this week.",
                startDate: start,
                endDate: end
            ),
            onsetEfficiency: .init(
                scenarioName: L("health.week.sedona"),
                usedTimes: 5,
                score: 88,
                startDate: start,
                endDate: end
            ),
            sleepMetrics: .init(
                avgSleepOnsetMinutes: 14,
                avgTimeInBedMinutes: 455,
                trackedDays: 6,
                source: "estimated",
                startDate: start,
                endDate: end
            )
        )
    }

    func mockMonthAnalysis(startDate: Date, endDate: Date) -> MonthAnalysis {
        let start = formatDate(startDate)
        let end = formatDate(endDate)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: endDate)
        let seriesStart = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        let scores = [62, 64, 61, 66, 68, 70, 67, 72, 75, 73, 71, 74, 76, 78, 80, 77, 79, 81, 83, 82, 84, 85, 86, 84, 87, 88, 86, 89, 90, 89]
        let scoreSeries = (0..<scores.count).compactMap { index -> MonthAnalysis.SleepTrends.ScorePoint? in
            guard let date = calendar.date(byAdding: .day, value: index, to: seriesStart) else { return nil }
            return .init(date: formatDate(date), score: scores[index])
        }

        return MonthAnalysis(
            scoreSummary: .init(score: 70, label: L("health.month.optimal"), startDate: start, endDate: end),
            sleepTrends: .init(
                body: L("health.month.trends_body"),
                description: L("health.month.trends_desc"),
                scoreSeries: scoreSeries,
                startDate: start,
                endDate: end
            ),
            onsetEfficiency: .init(
                scenarioList: ["Sedona Desert Calm", "Maldives Drift Sleep", "Canadian Forest Solace"],
                description: L("health.month.best_desc"),
                startDate: start,
                endDate: end
            ),
            sleepMetrics: .init(
                avgSleepOnsetMinutes: 16,
                avgTimeInBedMinutes: 448,
                trackedDays: 24,
                source: "estimated",
                startDate: start,
                endDate: end
            )
        )
    }

    /// 取当天分析并按三态归类（见 `ServerDataResolution.swift`）。
    /// 视图一律用它，**不要**自己 `try?` —— 那会把「服务端说没有」和「断网」揉成同一个 nil。
    func resolveDayAnalysis(date: Date) async -> ServerResolution<DayAnalysis> {
        await dayStore.resolve(key: dayKey(date)) { try await self.fetchDayAnalysis(date: date) }
    }
    /// 取本周分析并按三态归类。
    func resolveWeekAnalysis(startDate: Date, endDate: Date) async -> ServerResolution<WeekAnalysis> {
        await weekStore.resolve(key: periodKey(startDate, endDate)) {
            try await self.fetchWeekAnalysis(startDate: startDate, endDate: endDate)
        }
    }
    /// 取本月分析并按三态归类。
    func resolveMonthAnalysis(startDate: Date, endDate: Date) async -> ServerResolution<MonthAnalysis> {
        await monthStore.resolve(key: periodKey(startDate, endDate)) {
            try await self.fetchMonthAnalysis(startDate: startDate, endDate: endDate)
        }
    }

    // 以下三个 fetch 只负责「取 + 解码」：成功但服务端说没内容时返回 nil，失败一律 throw。
    // 缓存的写入/清除交给 ServerBackedStore.resolve，这里不再自行落盘。
    private func fetchDayAnalysis(date: Date) async throws -> DayAnalysis? {
        let payload: DayAnalysisPayload? = try await post(
            requestType: "analysis_sleep_day",
            date: formatDate(date),
            startDate: nil,
            endDate: nil,
            modules: ["score_summary", "sleep_scenarios", "stage_insights", "sleep_metrics"]
        )

        // post 只在「code==0 但 data 为 null」时返回 nil（失败都走 throw）——这是服务端
        // 明确说「这天没有分析内容」，往上返回 nil 让 store 清掉旧值；否则下次进入
        // 还会回显早已不存在的旧分析。
        guard let payload else { return nil }
        return DayAnalysis(
            scoreSummary: payload.scoreSummary,
            sleepScenarios: payload.sleepScenarios,
            stageInsights: payload.stageInsights,
            sleepMetrics: payload.sleepMetrics
        )
    }

    private func fetchWeekAnalysis(startDate: Date, endDate: Date) async throws -> WeekAnalysis? {
        let payload: WeekAnalysisPayload? = try await post(
            requestType: "analysis_sleep_week",
            date: nil,
            startDate: formatDate(startDate),
            endDate: formatDate(endDate),
            modules: ["score_summary", "sleep_trends", "onset_efficiency", "sleep_metrics"]
        )

        // 同 fetchDayAnalysis：服务端明确应答「没有内容」→ 返回 nil，由 store 清掉旧值。
        guard let payload else { return nil }
        return WeekAnalysis(
            scoreSummary: payload.scoreSummary,
            sleepTrends: payload.sleepTrends,
            onsetEfficiency: payload.onsetEfficiency,
            sleepMetrics: payload.sleepMetrics
        )
    }

    private func fetchMonthAnalysis(startDate: Date, endDate: Date) async throws -> MonthAnalysis? {
        let payload: MonthAnalysisPayload? = try await post(
            requestType: "analysis_sleep_month",
            date: nil,
            startDate: formatDate(startDate),
            endDate: formatDate(endDate),
            modules: ["score_summary", "sleep_trends", "onset_efficiency", "sleep_metrics"]
        )

        // 同 fetchDayAnalysis：服务端明确应答「没有内容」→ 返回 nil，由 store 清掉旧值。
        guard let payload else { return nil }
        return MonthAnalysis(
            scoreSummary: payload.scoreSummary,
            sleepTrends: payload.sleepTrends,
            onsetEfficiency: payload.onsetEfficiency,
            sleepMetrics: payload.sleepMetrics
        )
    }

    private func post<Response: Decodable>(
        requestType: String,
        date: String?,
        startDate: String?,
        endDate: String?,
        modules: [String]
    ) async throws -> Response? {
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let jwtToken = AuthStorage.shared.token, !jwtToken.isEmpty else {
            throw ServiceError.missingCredentials
        }

        guard let url = URL(string: Constants.Network.analysisURL) else {
            throw ServiceError.invalidURL
        }

        let payload = AnalysisRequest(
            requestType: requestType,
            timestamp: Int(Date().timeIntervalSince1970),
            data: .init(
                uid: uid,
                jwtToken: jwtToken,
                language: LocalizationManager.shared.currentLanguage.rawValue,
                date: date,
                startDate: startDate,
                endDate: endDate,
                timezone: TimeZone.current.identifier,
                modules: modules
            )
        )
        let requestID = Log.requestID()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.Network.analysisTimeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        RequestTrace.apply(&request, requestID: requestID)
        let body = try JSONEncoder().encode(payload)
        request.httpBody = body

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "[req:\(requestID)] \(requestType) request url=\(url.absoluteString)")
            Log.info(logTag, "[req:\(requestID)] \(requestType) request body=\(Log.prettyJSON(body))")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        SessionExpirationCenter.handle(httpResponse: response, data: data, requestID: requestID)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                Log.error(logTag, "[req:\(requestID)] \(requestType) invalid HTTP status=\(httpResponse.statusCode)")
                if Constants.Config.enableNetworkLogging {
                    Log.error(logTag, "[req:\(requestID)] \(requestType) error response body=\(Log.prettyJSON(data))")
                }
            } else {
                Log.error(logTag, "[req:\(requestID)] \(requestType) invalid HTTP response")
            }
            throw ServiceError.invalidResponse
        }

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "[req:\(requestID)] \(requestType) response status=\(httpResponse.statusCode)")
            Log.info(logTag, "[req:\(requestID)] \(requestType) response body=\(Log.prettyJSON(data))")
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope<Response>.self, from: data)
        guard decoded.code == 0 else {
            Log.error(logTag, "[req:\(requestID)] \(requestType) business error code=\(decoded.code), msg=\(decoded.msg ?? "")")
            throw ServiceError.apiError(code: decoded.code, message: decoded.msg)
        }

        Log.info(logTag, "[req:\(requestID)] \(requestType) completed successfully")

        return decoded.data
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}