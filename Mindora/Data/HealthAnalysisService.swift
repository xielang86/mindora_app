import Foundation

final class HealthAnalysisService {
    static let shared = HealthAnalysisService()
    private let logTag = "HealthAnalysisService"

    struct DayAnalysis {
        let scoreSummary: ScoreSummary?
        let sleepScenarios: SleepScenario?
        let stageInsights: StageInsights?

        struct ScoreSummary: Decodable {
            let score: Int?
            let date: String?
        }

        struct SleepScenario: Decodable {
            let title: String?
            let description: String?
            let date: String?
        }

        struct StageInsights: Decodable {
            let awake: StageInsight?
            let rem: StageInsight?
            let core: StageInsight?
            let deep: StageInsight?
        }

        struct StageInsight: Decodable {
            let description: String?
            let date: String?
        }
    }

    struct WeekAnalysis {
        let scoreSummary: ScoreSummary?
        let sleepTrends: SleepTrends?
        let onsetEfficiency: OnsetEfficiency?

        struct ScoreSummary: Decodable {
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

        struct SleepTrends: Decodable {
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

        struct OnsetEfficiency: Decodable {
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

    struct MonthAnalysis {
        let scoreSummary: ScoreSummary?
        let sleepTrends: SleepTrends?
        let onsetEfficiency: OnsetEfficiency?

        struct ScoreSummary: Decodable {
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

        struct SleepTrends: Decodable {
            struct ScorePoint: Decodable {
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

        struct OnsetEfficiency: Decodable {
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

        enum CodingKeys: String, CodingKey {
            case scoreSummary = "score_summary"
            case sleepScenarios = "sleep_scenarios"
            case stageInsights = "stage_insights"
        }
    }

    private struct WeekAnalysisPayload: Decodable {
        let scoreSummary: WeekAnalysis.ScoreSummary?
        let sleepTrends: WeekAnalysis.SleepTrends?
        let onsetEfficiency: WeekAnalysis.OnsetEfficiency?

        enum CodingKeys: String, CodingKey {
            case scoreSummary = "score_summary"
            case sleepTrends = "sleep_trends"
            case onsetEfficiency = "onset_efficiency"
        }
    }

    private struct MonthAnalysisPayload: Decodable {
        let scoreSummary: MonthAnalysis.ScoreSummary?
        let sleepTrends: MonthAnalysis.SleepTrends?
        let onsetEfficiency: MonthAnalysis.OnsetEfficiency?

        enum CodingKeys: String, CodingKey {
            case scoreSummary = "score_summary"
            case sleepTrends = "sleep_trends"
            case onsetEfficiency = "onset_efficiency"
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
            )
        )
    }

    func fetchDayAnalysis(date: Date) async throws -> DayAnalysis? {
        let payload: DayAnalysisPayload? = try await post(
            requestType: "analysis_sleep_day",
            date: formatDate(date),
            startDate: nil,
            endDate: nil,
            modules: ["score_summary", "sleep_scenarios", "stage_insights"]
        )

        guard let payload else { return nil }
        return DayAnalysis(
            scoreSummary: payload.scoreSummary,
            sleepScenarios: payload.sleepScenarios,
            stageInsights: payload.stageInsights
        )
    }

    func fetchWeekAnalysis(startDate: Date, endDate: Date) async throws -> WeekAnalysis? {
        let payload: WeekAnalysisPayload? = try await post(
            requestType: "analysis_sleep_week",
            date: nil,
            startDate: formatDate(startDate),
            endDate: formatDate(endDate),
            modules: ["score_summary", "sleep_trends", "onset_efficiency"]
        )

        guard let payload else { return nil }
        return WeekAnalysis(
            scoreSummary: payload.scoreSummary,
            sleepTrends: payload.sleepTrends,
            onsetEfficiency: payload.onsetEfficiency
        )
    }

    func fetchMonthAnalysis(startDate: Date, endDate: Date) async throws -> MonthAnalysis? {
        let payload: MonthAnalysisPayload? = try await post(
            requestType: "analysis_sleep_month",
            date: nil,
            startDate: formatDate(startDate),
            endDate: formatDate(endDate),
            modules: ["score_summary", "sleep_trends", "onset_efficiency"]
        )

        guard let payload else { return nil }
        return MonthAnalysis(
            scoreSummary: payload.scoreSummary,
            sleepTrends: payload.sleepTrends,
            onsetEfficiency: payload.onsetEfficiency
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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.Network.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        let body = try JSONEncoder().encode(payload)
        request.httpBody = body

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "\(requestType) request url=\(url.absoluteString)")
            Log.info(logTag, "\(requestType) request body=\(Log.prettyJSON(body))")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                Log.error(logTag, "\(requestType) invalid HTTP status=\(httpResponse.statusCode)")
            } else {
                Log.error(logTag, "\(requestType) invalid HTTP response")
            }
            throw ServiceError.invalidResponse
        }

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "\(requestType) response status=\(httpResponse.statusCode)")
            Log.info(logTag, "\(requestType) response body=\(Log.prettyJSON(data))")
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope<Response>.self, from: data)
        guard decoded.code == 0 else {
            Log.error(logTag, "\(requestType) business error code=\(decoded.code), msg=\(decoded.msg ?? "")")
            throw ServiceError.apiError(code: decoded.code, message: decoded.msg)
        }

        Log.info(logTag, "\(requestType) completed successfully")

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