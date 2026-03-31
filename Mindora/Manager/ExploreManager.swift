import Foundation

enum ExploreStatus {
    case initial
    case loaded(ExploreData)
    case error(Error)
}

struct ExploreData {
    let hasData: Bool

    let introText: String
    let introDetailText: String

    let scoreValue: String
    let scoreTitle: String
    let efficiencyRingValue: Double
    let structureRingValue: Double
    let fluctuationRingValue: Double

    let efficiencyScore: String
    let efficiencyStatus: String
    let efficiencyOnsetTime: String
    let efficiencyFirstSleepTime: String
    let efficiencyBeforeHr: String
    let efficiencyBeforeRespiration: String
    let efficiencyDesc: String

    let structureScore: String
    let structureStatus: String
    let structureContinuous: String
    let structureRem: String
    let structureDeep: String
    let structureLight: String
    let structureDesc: String

    let fluctuationScore: String
    let fluctuationStatus: String
    let fluctuationIntervention: String
    let fluctuationAwakeCount: String
    let fluctuationAwakeDuration: String
    let fluctuationAwakeType: String
    let fluctuationHrRange: String
    let fluctuationRespRange: String
    let fluctuationDesc: String

    let sceneId: String
    let sceneName: String
    let sceneType: String
    let preferenceDesc: String

    let adviceDesc: String
    let quoteText: String
    let articles: [ExploreArticle]

    let emptyStateScore: String
    let emptyStateTitle: String
    let emptyStateMessage: String
}

struct ExploreArticle {
    let imageName: String
    let title: String
    let subtitle: String
}

final class ExploreManager {
    static let shared = ExploreManager()

    private struct AnalysisRequest: Encodable {
        let requestType: String
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

    private struct ResponseEnvelope<Payload: Decodable>: Decodable {
        let code: Int
        let msg: String?
        let data: Payload?
    }

    private struct ExploreAnalysisPayload: Decodable {
        let dataReady: Bool?
        let headerSummary: HeaderSummary?
        let scoreSummary: ScoreSummary?
        let onsetEfficiency: OnsetEfficiency?
        let sleepStructure: SleepStructure?
        let nightFluctuation: NightFluctuation?
        let scenePreference: ScenePreference?
        let sleepAdvice: SleepAdvice?

        enum CodingKeys: String, CodingKey {
            case dataReady = "data_ready"
            case headerSummary = "header_summary"
            case scoreSummary = "score_summary"
            case onsetEfficiency = "onset_efficiency"
            case sleepStructure = "sleep_structure"
            case nightFluctuation = "night_fluctuation"
            case scenePreference = "scene_preference"
            case sleepAdvice = "sleep_advice"
        }
    }

    private struct HeaderSummary: Decodable {
        let introText: String?
        let introDetailText: String?

        enum CodingKeys: String, CodingKey {
            case introText = "intro_text"
            case introDetailText = "intro_detail_text"
        }
    }

    private struct ScoreSummary: Decodable {
        let score: Int?
        let title: String?
        let efficiencyScore: Int?
        let structureScore: Int?
        let fluctuationScore: Int?

        enum CodingKeys: String, CodingKey {
            case score
            case title
            case efficiencyScore = "efficiency_score"
            case structureScore = "structure_score"
            case fluctuationScore = "fluctuation_score"
        }
    }

    private struct OnsetEfficiency: Decodable {
        let score: Int?
        let label: String?
        let onsetMinutes: Int?
        let firstSleepTime: String?
        let preSleepHeartRate: String?
        let preSleepRespiratoryRate: String?
        let description: String?

        enum CodingKeys: String, CodingKey {
            case score
            case label
            case onsetMinutes = "onset_minutes"
            case firstSleepTime = "first_sleep_time"
            case preSleepHeartRate = "pre_sleep_heart_rate"
            case preSleepRespiratoryRate = "pre_sleep_respiratory_rate"
            case description
        }
    }

    private struct SleepStructure: Decodable {
        let score: Int?
        let label: String?
        let continuousSleepMinutes: Int?
        let remPercent: String?
        let deepPercent: String?
        let corePercent: String?
        let description: String?

        enum CodingKeys: String, CodingKey {
            case score
            case label
            case continuousSleepMinutes = "continuous_sleep_minutes"
            case remPercent = "rem_percent"
            case deepPercent = "deep_percent"
            case corePercent = "core_percent"
            case description
        }
    }

    private struct NightFluctuation: Decodable {
        let score: Int?
        let label: String?
        let intervention: String?
        let awakeCount: Int?
        let awakeDurationMinutes: Int?
        let awakeType: String?
        let heartRateRange: String?
        let respiratoryFluctuation: String?
        let description: String?

        enum CodingKeys: String, CodingKey {
            case score
            case label
            case intervention
            case awakeCount = "awake_count"
            case awakeDurationMinutes = "awake_duration_minutes"
            case awakeType = "awake_type"
            case heartRateRange = "heart_rate_range"
            case respiratoryFluctuation = "respiratory_fluctuation"
            case description
        }
    }

    private struct ScenePreference: Decodable {
        let sceneId: String?
        let sceneName: String?
        let sceneType: String?
        let description: String?

        enum CodingKeys: String, CodingKey {
            case sceneId = "scene_id"
            case sceneName = "scene_name"
            case sceneType = "scene_type"
            case description
        }
    }

    private struct SleepAdvice: Decodable {
        let description: String?
    }

    private enum ServiceError: Error {
        case invalidURL
        case missingCredentials
        case invalidResponse
        case apiError(code: Int, message: String?)
    }

    private init() {}

    func fetchExploreData(completion: @escaping (ExploreData) -> Void) {
        if Constants.Config.showMockData {
            Log.info("ExploreManager", "Using mock explore data")
            completion(mockData())
            return
        }

        fetchRealData(completion: completion)
    }

    private func fetchRealData(completion: @escaping (ExploreData) -> Void) {
        Task {
            do {
                let payload = try await fetchExploreAnalysis()
                let data = buildData(from: payload)
                Log.info("ExploreManager", "Explore analysis completed. hasData=\(data.hasData), sceneId=\(data.sceneId.isEmpty ? "<empty>" : data.sceneId)")
                DispatchQueue.main.async {
                    completion(data)
                }
            } catch {
                Log.error("ExploreManager", "Explore analysis failed, fallback to default data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(self.defaultData())
                }
            }
        }
    }

    private func fetchExploreAnalysis() async throws -> ExploreAnalysisPayload? {
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let jwtToken = AuthStorage.shared.token, !jwtToken.isEmpty else {
            throw ServiceError.missingCredentials
        }

        guard let url = URL(string: Constants.Network.analysisURL) else {
            throw ServiceError.invalidURL
        }

        let payload = AnalysisRequest(
            requestType: "analysis_explore",
            timestamp: Int(Date().timeIntervalSince1970),
            data: .init(
                uid: uid,
                jwtToken: jwtToken,
                language: LocalizationManager.shared.currentLanguage.rawValue,
                date: formatDate(Date()),
                timezone: TimeZone.current.identifier,
                modules: [
                    "header_summary",
                    "score_summary",
                    "onset_efficiency",
                    "sleep_structure",
                    "night_fluctuation",
                    "scene_preference",
                    "sleep_advice"
                ]
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.Network.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")

        let body = try JSONEncoder().encode(payload)
        if Constants.Config.enableNetworkLogging,
           let bodyString = String(data: body, encoding: .utf8) {
            Log.info("ExploreManager", "analysis_explore request url=\(url.absoluteString)")
            Log.info("ExploreManager", "analysis_explore request body=\(bodyString)")
        }

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                Log.error("ExploreManager", "analysis_explore invalid HTTP status=\(httpResponse.statusCode)")
            } else {
                Log.error("ExploreManager", "analysis_explore invalid HTTP response")
            }
            throw ServiceError.invalidResponse
        }

        if Constants.Config.enableNetworkLogging {
            Log.info("ExploreManager", "analysis_explore response status=\(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                Log.info("ExploreManager", "analysis_explore response body=\(responseString)")
            }
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope<ExploreAnalysisPayload>.self, from: data)
        guard decoded.code == 0 else {
            Log.error("ExploreManager", "analysis_explore business error code=\(decoded.code), msg=\(decoded.msg ?? "")")
            throw ServiceError.apiError(code: decoded.code, message: decoded.msg)
        }

        return decoded.data
    }

    private func buildData(from payload: ExploreAnalysisPayload?) -> ExploreData {
        let quoteText = L("explore.quote.text")
        let articles = defaultArticles()

        guard let payload else {
            Log.info("ExploreManager", "Explore payload is nil, using default data")
            return defaultData()
        }

        let hasData = payload.dataReady ?? false
        let header = payload.headerSummary
        let introText = nonEmpty(header?.introText) ?? (hasData ? L("explore.intro.data") : L("explore.intro.default"))
        let introDetailText = nonEmpty(header?.introDetailText) ?? (hasData ? "" : L("explore.intro.default_detail"))

        if !hasData {
            Log.info("ExploreManager", "Explore payload reports data_ready=false, using empty-state data")
            return ExploreData(
                hasData: false,
                introText: introText,
                introDetailText: introDetailText,
                scoreValue: L("explore.empty.score"),
                scoreTitle: nonEmpty(payload.scoreSummary?.title) ?? L("explore.empty.title"),
                efficiencyRingValue: 0,
                structureRingValue: 0,
                fluctuationRingValue: 0,
                efficiencyScore: L("explore.placeholder.efficiency"),
                efficiencyStatus: L("explore.placeholder.label"),
                efficiencyOnsetTime: L("explore.placeholder.number"),
                efficiencyFirstSleepTime: L("explore.placeholder.time"),
                efficiencyBeforeHr: L("explore.placeholder.hr"),
                efficiencyBeforeRespiration: L("explore.placeholder.resp"),
                efficiencyDesc: L("explore.default.efficiency_desc"),
                structureScore: L("explore.placeholder.efficiency"),
                structureStatus: L("explore.placeholder.label"),
                structureContinuous: L("explore.placeholder.number"),
                structureRem: L("explore.placeholder.duration"),
                structureDeep: L("explore.placeholder.duration"),
                structureLight: L("explore.placeholder.duration"),
                structureDesc: L("explore.default.structure_desc"),
                fluctuationScore: L("explore.placeholder.efficiency"),
                fluctuationStatus: L("explore.placeholder.label"),
                fluctuationIntervention: L("explore.placeholder.text"),
                fluctuationAwakeCount: L("explore.placeholder.count"),
                fluctuationAwakeDuration: L("explore.placeholder.duration"),
                fluctuationAwakeType: L("explore.placeholder.text"),
                fluctuationHrRange: L("explore.placeholder.hr_fluctuation"),
                fluctuationRespRange: L("explore.placeholder.percent"),
                fluctuationDesc: L("explore.default.fluctuation_desc"),
                sceneId: "",
                sceneName: "",
                sceneType: "",
                preferenceDesc: L("explore.default.preference_desc"),
                adviceDesc: nonEmpty(payload.sleepAdvice?.description) ?? L("explore.bottom.description"),
                quoteText: quoteText,
                articles: articles,
                emptyStateScore: L("explore.empty.score"),
                emptyStateTitle: L("explore.empty.title"),
                emptyStateMessage: L("explore.empty.message")
            )
        }

        return ExploreData(
            hasData: true,
            introText: introText,
            introDetailText: introDetailText,
            scoreValue: payload.scoreSummary?.score.map(String.init) ?? "--",
            scoreTitle: nonEmpty(payload.scoreSummary?.title) ?? L("explore.empty.title"),
            efficiencyRingValue: Double(payload.scoreSummary?.efficiencyScore ?? 0),
            structureRingValue: Double(payload.scoreSummary?.structureScore ?? 0),
            fluctuationRingValue: Double(payload.scoreSummary?.fluctuationScore ?? 0),
            efficiencyScore: percentageString(payload.onsetEfficiency?.score),
            efficiencyStatus: nonEmpty(payload.onsetEfficiency?.label) ?? L("explore.placeholder.label"),
            efficiencyOnsetTime: payload.onsetEfficiency?.onsetMinutes.map(String.init) ?? L("explore.placeholder.number"),
            efficiencyFirstSleepTime: nonEmpty(payload.onsetEfficiency?.firstSleepTime) ?? L("explore.placeholder.time"),
            efficiencyBeforeHr: nonEmpty(payload.onsetEfficiency?.preSleepHeartRate) ?? L("explore.placeholder.hr"),
            efficiencyBeforeRespiration: nonEmpty(payload.onsetEfficiency?.preSleepRespiratoryRate) ?? L("explore.placeholder.resp"),
            efficiencyDesc: nonEmpty(payload.onsetEfficiency?.description) ?? L("explore.default.efficiency_desc"),
            structureScore: percentageString(payload.sleepStructure?.score),
            structureStatus: nonEmpty(payload.sleepStructure?.label) ?? L("explore.placeholder.label"),
            structureContinuous: payload.sleepStructure?.continuousSleepMinutes.map(String.init) ?? L("explore.placeholder.number"),
            structureRem: nonEmpty(payload.sleepStructure?.remPercent) ?? L("explore.placeholder.duration"),
            structureDeep: nonEmpty(payload.sleepStructure?.deepPercent) ?? L("explore.placeholder.duration"),
            structureLight: nonEmpty(payload.sleepStructure?.corePercent) ?? L("explore.placeholder.duration"),
            structureDesc: nonEmpty(payload.sleepStructure?.description) ?? L("explore.default.structure_desc"),
            fluctuationScore: percentageString(payload.nightFluctuation?.score),
            fluctuationStatus: nonEmpty(payload.nightFluctuation?.label) ?? L("explore.placeholder.label"),
            fluctuationIntervention: nonEmpty(payload.nightFluctuation?.intervention) ?? L("explore.placeholder.text"),
            fluctuationAwakeCount: formattedCount(payload.nightFluctuation?.awakeCount),
            fluctuationAwakeDuration: formattedDuration(payload.nightFluctuation?.awakeDurationMinutes),
            fluctuationAwakeType: nonEmpty(payload.nightFluctuation?.awakeType) ?? L("explore.placeholder.text"),
            fluctuationHrRange: nonEmpty(payload.nightFluctuation?.heartRateRange) ?? L("explore.placeholder.hr_fluctuation"),
            fluctuationRespRange: nonEmpty(payload.nightFluctuation?.respiratoryFluctuation) ?? L("explore.placeholder.percent"),
            fluctuationDesc: nonEmpty(payload.nightFluctuation?.description) ?? L("explore.default.fluctuation_desc"),
            sceneId: nonEmpty(payload.scenePreference?.sceneId) ?? "",
            sceneName: nonEmpty(payload.scenePreference?.sceneName) ?? "",
            sceneType: nonEmpty(payload.scenePreference?.sceneType) ?? "",
            preferenceDesc: nonEmpty(payload.scenePreference?.description) ?? L("explore.default.preference_desc"),
            adviceDesc: nonEmpty(payload.sleepAdvice?.description) ?? L("explore.bottom.description"),
            quoteText: quoteText,
            articles: articles,
            emptyStateScore: L("explore.empty.score"),
            emptyStateTitle: L("explore.empty.title"),
            emptyStateMessage: L("explore.empty.message")
        )
    }

    private func defaultArticles() -> [ExploreArticle] {
        [
            ExploreArticle(
                imageName: "explore_article_1",
                title: L("explore.article.1.title"),
                subtitle: L("explore.article.1.subtitle")
            ),
            ExploreArticle(
                imageName: "explore_article_2",
                title: L("explore.article.2.title"),
                subtitle: L("explore.article.2.subtitle")
            ),
            ExploreArticle(
                imageName: "explore_article_3",
                title: L("explore.article.3.title"),
                subtitle: L("explore.article.3.subtitle")
            ),
            ExploreArticle(
                imageName: "explore_article_4",
                title: L("explore.article.4.title"),
                subtitle: L("explore.article.4.subtitle")
            )
        ]
    }

    private func mockData() -> ExploreData {
        ExploreData(
            hasData: true,
            introText: L("explore.intro.data"),
            introDetailText: "",
            scoreValue: "82",
            scoreTitle: L("explore.empty.title"),
            efficiencyRingValue: 82,
            structureRingValue: 49,
            fluctuationRingValue: 34,
            efficiencyScore: "82%",
            efficiencyStatus: L("explore.status.health_range"),
            efficiencyOnsetTime: "12",
            efficiencyFirstSleepTime: "23:45",
            efficiencyBeforeHr: String(format: L("explore.value.hr_format"), "68"),
            efficiencyBeforeRespiration: String(format: L("explore.value.resp_rate_format"), "15"),
            efficiencyDesc: L("explore.mock.efficiency_desc"),
            structureScore: "49%",
            structureStatus: L("explore.status.average"),
            structureContinuous: "365",
            structureRem: "22%",
            structureDeep: "29.8%",
            structureLight: "48.2%",
            structureDesc: L("explore.mock.structure_desc"),
            fluctuationScore: "34%",
            fluctuationStatus: L("explore.status.fluctuation_high"),
            fluctuationIntervention: L("explore.mock.intervention"),
            fluctuationAwakeCount: String(format: L("explore.value.count_format"), "2"),
            fluctuationAwakeDuration: String(format: L("explore.value.duration_format"), "5"),
            fluctuationAwakeType: L("explore.mock.awake_type"),
            fluctuationHrRange: String(format: L("explore.value.hr_range_format"), "55-85"),
            fluctuationRespRange: "25%",
            fluctuationDesc: L("explore.mock.fluctuation_desc"),
            sceneId: "cocos_island_moonlight",
            sceneName: L("explore.preference.cocos_island.title"),
            sceneType: L("explore.preference.cocos_island.subtitle"),
            preferenceDesc: L("explore.mock.preference_desc"),
            adviceDesc: L("explore.mock.advice_desc"),
            quoteText: L("explore.quote.text"),
            articles: defaultArticles(),
            emptyStateScore: L("explore.empty.score"),
            emptyStateTitle: L("explore.empty.title"),
            emptyStateMessage: L("explore.empty.message")
        )
    }

    private func defaultData() -> ExploreData {
        ExploreData(
            hasData: false,
            introText: L("explore.intro.default"),
            introDetailText: L("explore.intro.default_detail"),
            scoreValue: L("explore.empty.score"),
            scoreTitle: L("explore.empty.title"),
            efficiencyRingValue: 0,
            structureRingValue: 0,
            fluctuationRingValue: 0,
            efficiencyScore: L("explore.placeholder.efficiency"),
            efficiencyStatus: L("explore.placeholder.label"),
            efficiencyOnsetTime: L("explore.placeholder.number"),
            efficiencyFirstSleepTime: L("explore.placeholder.time"),
            efficiencyBeforeHr: L("explore.placeholder.hr"),
            efficiencyBeforeRespiration: L("explore.placeholder.resp"),
            efficiencyDesc: L("explore.default.efficiency_desc"),
            structureScore: L("explore.placeholder.efficiency"),
            structureStatus: L("explore.placeholder.label"),
            structureContinuous: L("explore.placeholder.number"),
            structureRem: L("explore.placeholder.duration"),
            structureDeep: L("explore.placeholder.duration"),
            structureLight: L("explore.placeholder.duration"),
            structureDesc: L("explore.default.structure_desc"),
            fluctuationScore: L("explore.placeholder.efficiency"),
            fluctuationStatus: L("explore.placeholder.label"),
            fluctuationIntervention: L("explore.placeholder.text"),
            fluctuationAwakeCount: L("explore.placeholder.count"),
            fluctuationAwakeDuration: L("explore.placeholder.duration"),
            fluctuationAwakeType: L("explore.placeholder.text"),
            fluctuationHrRange: L("explore.placeholder.hr_fluctuation"),
            fluctuationRespRange: L("explore.placeholder.percent"),
            fluctuationDesc: L("explore.default.fluctuation_desc"),
            sceneId: "",
            sceneName: "",
            sceneType: "",
            preferenceDesc: L("explore.default.preference_desc"),
            adviceDesc: L("explore.bottom.description"),
            quoteText: L("explore.quote.text"),
            articles: defaultArticles(),
            emptyStateScore: L("explore.empty.score"),
            emptyStateTitle: L("explore.empty.title"),
            emptyStateMessage: L("explore.empty.message")
        )
    }

    private func percentageString(_ value: Int?) -> String {
        guard let value else { return L("explore.placeholder.efficiency") }
        return "\(max(0, value))%"
    }

    private func formattedCount(_ value: Int?) -> String {
        guard let value else { return L("explore.placeholder.count") }
        return String(format: L("explore.value.count_format"), String(value))
    }

    private func formattedDuration(_ value: Int?) -> String {
        guard let value else { return L("explore.placeholder.duration") }
        return String(format: L("explore.value.duration_format"), String(value))
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
