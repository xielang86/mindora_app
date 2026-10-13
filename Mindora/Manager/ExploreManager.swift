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

    private struct LocalExploreSnapshot {
        let hasData: Bool
        let efficiencyScore: Int?
        let efficiencyOnsetTime: String?
        let efficiencyFirstSleepTime: String?
        let efficiencyBeforeHr: String?
        let efficiencyBeforeRespiration: String?
        let structureScore: Int?
        let structureContinuous: String?
        let structureRem: String?
        let structureDeep: String?
        let structureLight: String?
        let fluctuationScore: Int?
        let fluctuationAwakeCount: String?
        let fluctuationAwakeDuration: String?
        let fluctuationHrRange: String?
        let fluctuationRespRange: String?
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

    // Codable（而非 Decodable）：payload 要落进 ServerBackedStore 供断网时回显。
    private struct ExploreAnalysisPayload: Codable {
        // data_ready 有意不解析：服务端不下发，且它曾被当成「整份 payload 作废」的开关，
        // 留着字段迟早又有人拿去做判断。版面判据看真实分值，见 buildData。
        let headerSummary: HeaderSummary?
        let scoreSummary: ScoreSummary?
        let onsetEfficiency: OnsetEfficiency?
        let sleepStructure: SleepStructure?
        let nightFluctuation: NightFluctuation?
        let scenePreference: ScenePreference?
        let sleepAdvice: SleepAdvice?

        enum CodingKeys: String, CodingKey {
            case headerSummary = "header_summary"
            case scoreSummary = "score_summary"
            case onsetEfficiency = "onset_efficiency"
            case sleepStructure = "sleep_structure"
            case nightFluctuation = "night_fluctuation"
            case scenePreference = "scene_preference"
            case sleepAdvice = "sleep_advice"
        }
    }

    private struct HeaderSummary: Codable {
        let introText: String?
        let introDetailText: String?

        enum CodingKeys: String, CodingKey {
            case introText = "intro_text"
            case introDetailText = "intro_detail_text"
        }
    }

    private struct ScoreSummary: Codable {
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

    private struct OnsetEfficiency: Codable {
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

    private struct SleepStructure: Codable {
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

    private struct NightFluctuation: Codable {
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

    private struct ScenePreference: Codable {
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

    private struct SleepAdvice: Codable {
        let description: String?
    }

    private enum ServiceError: Error {
        case invalidURL
        case missingCredentials
        case invalidResponse
        case apiError(code: Int, message: String?)
    }

    // 服务端分析结果缓存：断网/超时时沿用上一份，避免整页掉回默认版面。
    // 单账号单份即可（内容随账号走，登出时由 clearCache 清掉）。
    private static let analysisCacheKey = "current"
    private let analysisStore = ServerBackedStore<ExploreAnalysisPayload>(namespace: "explore.analysis")

    /// 清空探索页服务端缓存。登出 / 注销时调用。
    func clearCache() { analysisStore.clearAll() }

    private init() {}

    func fetchExploreData(completion: @escaping (ExploreData) -> Void) {
        if Constants.Config.showMockData {
            Log.info("ExploreManager", "Using mock explore data")
            completion(mockData())
            return
        }

        fetchRealData(completion: completion)
    }

    // MARK: - 在途请求合并
    //
    // ExploreViewController 的 fetchData 挂在 viewWillAppear、进前台、健康授权变更、
    // 订阅状态变更、语言切换五个触发点上，它们经常在同一瞬间连着来。真机日志实测
    // 一次会话发了 40 条 analysis_explore，其中多组是**同一毫秒**的完全重复请求
    // （最多一次三连）。这里把后到的调用并到正在跑的那次上，只发一次网络请求，
    // 结果广播给所有等待者。
    private let pendingLock = NSLock()
    private var pendingCompletions: [(ExploreData) -> Void] = []
    private var isFetching = false

    private func fetchRealData(completion: @escaping (ExploreData) -> Void) {
        pendingLock.lock()
        pendingCompletions.append(completion)
        let alreadyFetching = isFetching
        isFetching = true
        pendingLock.unlock()

        if alreadyFetching {
            Log.info("ExploreManager", "Explore fetch already in flight, joining it")
            return
        }

        Task {
            async let localSnapshotTask = fetchLocalSnapshot()

            // 三态统一走 ServerBackedStore（见 ServerDataResolution.swift）：
            // 应答有内容 → 新内容；应答说没有 → 清缓存并展示空；没应答 → 沿用上次缓存。
            // 探索页此前**完全没有缓存**，断网即掉回默认版面，把上一份正确内容整份丢掉。
            //
            // ⚠️ 必须用非结构化 `Task` 而不是 `async let`：`resolve` 是泛型 async 函数，
            // 内部 `try await fetch()` 的错误要跨函数边界回卷。`async let` 在这种
            // 「子任务作用域带着错误退出」的形态下会撞上 swift_task_dealloc 的致命断言
            // 直接 abort —— 与 HealthDataManager / 日周月视图里记录的是同一个坑。
            // 真机实测：用 async let 时在 GPhone 上来回切 tab 连续崩溃多次，两份崩溃日志
            // 都终止在 Explore 取数过程中；换回 Task 后同样操作不再复现。
            let resolutionTask = Task { [analysisStore] in
                await analysisStore.resolve(key: Self.analysisCacheKey) {
                    try await self.fetchExploreAnalysis()
                }
            }

            let localSnapshot = await localSnapshotTask

            // 首屏：先用上次缓存的服务端内容 + 本地指标渲染，没缓存才退到纯本地/默认版面
            let seed = analysisStore.cached(Self.analysisCacheKey)
            let localData = (seed != nil || localSnapshot.hasData)
                ? buildData(from: seed, local: localSnapshot)
                : defaultData()
            broadcast(localData, isFinal: false)

            let payload = await resolutionTask.value.displayValue
            let finalData = buildData(from: payload, local: localSnapshot)
            Log.info("ExploreManager", "Explore data completed. hasData=\(finalData.hasData), sceneId=\(finalData.sceneId.isEmpty ? "<empty>" : finalData.sceneId)")
            broadcast(finalData, isFinal: true)
        }
    }

    /// 把结果发给所有等待者。isFinal 时清空队列并放开下一轮。
    /// 中途加入的调用方会错过 local 那次回调，但一定能收到 final。
    private func broadcast(_ data: ExploreData, isFinal: Bool) {
        pendingLock.lock()
        let targets = pendingCompletions
        if isFinal {
            pendingCompletions.removeAll()
            isFetching = false
        }
        pendingLock.unlock()

        DispatchQueue.main.async {
            targets.forEach { $0(data) }
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
        let requestID = Log.requestID()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.Network.analysisTimeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        RequestTrace.apply(&request, requestID: requestID)

        let body = try JSONEncoder().encode(payload)
        if Constants.Config.enableNetworkLogging,
           let bodyString = String(data: body, encoding: .utf8) {
            Log.info("ExploreManager", "[req:\(requestID)] analysis_explore request url=\(url.absoluteString)")
            Log.info("ExploreManager", "[req:\(requestID)] analysis_explore request body=\(bodyString)")
        }

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        SessionExpirationCenter.handle(httpResponse: response, data: data, requestID: requestID)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                Log.error("ExploreManager", "[req:\(requestID)] analysis_explore invalid HTTP status=\(httpResponse.statusCode)")
                if Constants.Config.enableNetworkLogging {
                    Log.error("ExploreManager", "[req:\(requestID)] analysis_explore error response body=\(Log.prettyJSON(data))")
                }
            } else {
                Log.error("ExploreManager", "[req:\(requestID)] analysis_explore invalid HTTP response")
            }
            throw ServiceError.invalidResponse
        }

        if Constants.Config.enableNetworkLogging {
            Log.info("ExploreManager", "[req:\(requestID)] analysis_explore response status=\(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                Log.info("ExploreManager", "[req:\(requestID)] analysis_explore response body=\(responseString)")
            }
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope<ExploreAnalysisPayload>.self, from: data)
        guard decoded.code == 0 else {
            Log.error("ExploreManager", "[req:\(requestID)] analysis_explore business error code=\(decoded.code), msg=\(decoded.msg ?? "")")
            throw ServiceError.apiError(code: decoded.code, message: decoded.msg)
        }

        return decoded.data
    }

    private func buildData(from payload: ExploreAnalysisPayload?, local: LocalExploreSnapshot) -> ExploreData {
        let quoteText = L("explore.quote.text")
        let articles = defaultArticles()

        guard let payload else {
            if local.hasData {
                Log.info("ExploreManager", "Explore payload is nil, using local HealthKit data")
                return localData(snapshot: local)
            }

            Log.info("ExploreManager", "Explore payload is nil, using default data")
            return defaultData()
        }

        // **data_ready 一律忽略**：服务端从来不下发这个字段，按它判断等于 `?? false` 恒成立，
        // 服务端算好的分值被整份丢弃、改用本地重算——真机上就出现过服务端明明返回
        // score=55/efficiency=52/structure=100/fluctuation=29，屏幕上却是本地算的
        // 39%/14% 且入睡效率恒为「- -%」（本地效率分要 inBed 样本，只戴表的用户永远没有）。
        // 判据换成「服务端真给了分值」或「本地有数据」，两者任一成立就正常出版面；
        // 具体到每个字段本来就是「服务端优先 → 本地兜底 → 占位符垫底」，不必再分流。
        let serverHasScores = payload.scoreSummary?.score != nil
            || payload.scoreSummary?.efficiencyScore != nil
            || payload.scoreSummary?.structureScore != nil
            || payload.scoreSummary?.fluctuationScore != nil
            || payload.onsetEfficiency?.score != nil
            || payload.sleepStructure?.score != nil
            || payload.nightFluctuation?.score != nil
        let hasData = serverHasScores || local.hasData
        let header = payload.headerSummary
        // 服务端文案字段一律按服务端返回显示：空就空着，不用本地文案顶替
        let introText = nonEmpty(header?.introText) ?? ""
        let introDetailText = nonEmpty(header?.introDetailText) ?? ""

        if !hasData {
            Log.info("ExploreManager", "Explore payload has no scores and no local data, using empty-state data")
            // 首次记录前的空状态：设计稿（洞察 2）给每块都配了固定的说明文案。服务端给了就用服务端的，
            // 没给才用这套 —— 只限无数据的空状态；有数据时服务端空就空着（见 d8a8a3d，免得被当成分析结论）。
            return ExploreData(
                hasData: false,
                introText: nonEmpty(introText) ?? L("explore.empty.intro"),
                introDetailText: nonEmpty(introDetailText) ?? L("explore.empty.intro_detail"),
                scoreValue: L("explore.empty.score"),
                scoreTitle: nonEmpty(payload.scoreSummary?.title) ?? L("explore.empty.title"),
                efficiencyRingValue: 0,
                structureRingValue: 0,
                fluctuationRingValue: 0,
                efficiencyScore: L("explore.placeholder.efficiency"),
                efficiencyStatus: nonEmpty(payload.onsetEfficiency?.label) ?? L("explore.placeholder.label"),
                efficiencyOnsetTime: L("explore.placeholder.number"),
                efficiencyFirstSleepTime: L("explore.placeholder.time"),
                efficiencyBeforeHr: L("explore.placeholder.hr"),
                efficiencyBeforeRespiration: L("explore.placeholder.resp"),
                efficiencyDesc: nonEmpty(payload.onsetEfficiency?.description) ?? L("explore.empty.desc.efficiency"),
                structureScore: L("explore.placeholder.efficiency"),
                structureStatus: nonEmpty(payload.sleepStructure?.label) ?? L("explore.placeholder.label"),
                structureContinuous: L("explore.placeholder.number"),
                structureRem: L("explore.placeholder.duration"),
                structureDeep: L("explore.placeholder.duration"),
                structureLight: L("explore.placeholder.duration"),
                structureDesc: nonEmpty(payload.sleepStructure?.description) ?? L("explore.empty.desc.structure"),
                fluctuationScore: L("explore.placeholder.efficiency"),
                fluctuationStatus: nonEmpty(payload.nightFluctuation?.label) ?? L("explore.placeholder.label"),
                fluctuationIntervention: L("explore.placeholder.text"),
                fluctuationAwakeCount: L("explore.placeholder.count"),
                fluctuationAwakeDuration: L("explore.placeholder.duration"),
                fluctuationAwakeType: L("explore.placeholder.text"),
                fluctuationHrRange: L("explore.placeholder.hr_fluctuation"),
                fluctuationRespRange: L("explore.placeholder.percent"),
                fluctuationDesc: nonEmpty(payload.nightFluctuation?.description) ?? L("explore.empty.desc.fluctuation"),
                sceneId: "",
                sceneName: "",
                sceneType: "",
                preferenceDesc: nonEmpty(payload.scenePreference?.description) ?? L("explore.empty.desc.preference"),
                adviceDesc: nonEmpty(payload.sleepAdvice?.description) ?? L("explore.empty.desc.advice"),
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
            efficiencyRingValue: Double(payload.scoreSummary?.efficiencyScore ?? local.efficiencyScore ?? 0),
            structureRingValue: Double(payload.scoreSummary?.structureScore ?? local.structureScore ?? 0),
            fluctuationRingValue: Double(payload.scoreSummary?.fluctuationScore ?? local.fluctuationScore ?? 0),
            efficiencyScore: percentageString(payload.onsetEfficiency?.score ?? local.efficiencyScore),
            efficiencyStatus: nonEmpty(payload.onsetEfficiency?.label) ?? L("explore.placeholder.label"),
            efficiencyOnsetTime: payload.onsetEfficiency?.onsetMinutes.map(String.init) ?? local.efficiencyOnsetTime ?? L("explore.placeholder.number"),
            efficiencyFirstSleepTime: nonEmpty(payload.onsetEfficiency?.firstSleepTime) ?? local.efficiencyFirstSleepTime ?? L("explore.placeholder.time"),
            efficiencyBeforeHr: nonEmpty(payload.onsetEfficiency?.preSleepHeartRate) ?? local.efficiencyBeforeHr ?? L("explore.placeholder.hr"),
            efficiencyBeforeRespiration: nonEmpty(payload.onsetEfficiency?.preSleepRespiratoryRate) ?? local.efficiencyBeforeRespiration ?? L("explore.placeholder.resp"),
            efficiencyDesc: nonEmpty(payload.onsetEfficiency?.description) ?? "--",
            structureScore: percentageString(payload.sleepStructure?.score ?? local.structureScore),
            structureStatus: nonEmpty(payload.sleepStructure?.label) ?? L("explore.placeholder.label"),
            structureContinuous: payload.sleepStructure?.continuousSleepMinutes.map(String.init) ?? local.structureContinuous ?? L("explore.placeholder.number"),
            structureRem: nonEmpty(payload.sleepStructure?.remPercent) ?? local.structureRem ?? L("explore.placeholder.duration"),
            structureDeep: nonEmpty(payload.sleepStructure?.deepPercent) ?? local.structureDeep ?? L("explore.placeholder.duration"),
            structureLight: nonEmpty(payload.sleepStructure?.corePercent) ?? local.structureLight ?? L("explore.placeholder.duration"),
            structureDesc: nonEmpty(payload.sleepStructure?.description) ?? "--",
            fluctuationScore: percentageString(payload.nightFluctuation?.score ?? local.fluctuationScore),
            fluctuationStatus: nonEmpty(payload.nightFluctuation?.label) ?? L("explore.placeholder.label"),
            fluctuationIntervention: nonEmpty(payload.nightFluctuation?.intervention) ?? L("explore.placeholder.text"),
            fluctuationAwakeCount: payload.nightFluctuation?.awakeCount != nil ? formattedCount(payload.nightFluctuation?.awakeCount) : (local.fluctuationAwakeCount ?? L("explore.placeholder.count")),
            fluctuationAwakeDuration: payload.nightFluctuation?.awakeDurationMinutes != nil ? formattedDuration(payload.nightFluctuation?.awakeDurationMinutes) : (local.fluctuationAwakeDuration ?? L("explore.placeholder.duration")),
            fluctuationAwakeType: nonEmpty(payload.nightFluctuation?.awakeType) ?? L("explore.placeholder.text"),
            fluctuationHrRange: nonEmpty(payload.nightFluctuation?.heartRateRange) ?? local.fluctuationHrRange ?? L("explore.placeholder.hr_fluctuation"),
            fluctuationRespRange: nonEmpty(payload.nightFluctuation?.respiratoryFluctuation) ?? local.fluctuationRespRange ?? L("explore.placeholder.percent"),
            fluctuationDesc: nonEmpty(payload.nightFluctuation?.description) ?? "--",
            sceneId: nonEmpty(payload.scenePreference?.sceneId) ?? "",
            sceneName: nonEmpty(payload.scenePreference?.sceneName) ?? "",
            sceneType: nonEmpty(payload.scenePreference?.sceneType) ?? "",
            preferenceDesc: nonEmpty(payload.scenePreference?.description) ?? "--",
            adviceDesc: nonEmpty(payload.sleepAdvice?.description) ?? "--",
            quoteText: quoteText,
            articles: articles,
            emptyStateScore: L("explore.empty.score"),
            emptyStateTitle: L("explore.empty.title"),
            emptyStateMessage: L("explore.empty.message")
        )
    }

    /// 纯本地兜底：只在**完全拿不到 payload**（网络失败、业务码非 0）时走这条。
    /// 服务端只要有响应就一律走 buildData 的主分支，那里每个字段都是
    /// 「服务端优先 → 本地兜底 → 占位符垫底」，服务端文案不会再被丢掉。
    private func localData(snapshot: LocalExploreSnapshot) -> ExploreData {
        return ExploreData(
            hasData: snapshot.hasData,
            introText: "",
            introDetailText: "",
            // 总分是服务端独有的口径，本地算不出来 —— 原来这里填的是**入睡效率分**，
            // 等于把效率分挂在「睡眠评分」下面显示。首页的综合评分也是没有就 `--`，保持一致。
            scoreValue: "--",
            scoreTitle: L("explore.empty.title"),
            efficiencyRingValue: Double(snapshot.efficiencyScore ?? 0),
            structureRingValue: Double(snapshot.structureScore ?? 0),
            fluctuationRingValue: Double(snapshot.fluctuationScore ?? 0),
            efficiencyScore: percentageString(snapshot.efficiencyScore),
            efficiencyStatus: localStatusText(for: snapshot.efficiencyScore, inverted: false),
            efficiencyOnsetTime: snapshot.efficiencyOnsetTime ?? L("explore.placeholder.number"),
            efficiencyFirstSleepTime: snapshot.efficiencyFirstSleepTime ?? L("explore.placeholder.time"),
            efficiencyBeforeHr: snapshot.efficiencyBeforeHr ?? L("explore.placeholder.hr"),
            efficiencyBeforeRespiration: snapshot.efficiencyBeforeRespiration ?? L("explore.placeholder.resp"),
            efficiencyDesc: "--",
            structureScore: percentageString(snapshot.structureScore),
            structureStatus: localStatusText(for: snapshot.structureScore, inverted: false),
            structureContinuous: snapshot.structureContinuous ?? L("explore.placeholder.number"),
            structureRem: snapshot.structureRem ?? L("explore.placeholder.duration"),
            structureDeep: snapshot.structureDeep ?? L("explore.placeholder.duration"),
            structureLight: snapshot.structureLight ?? L("explore.placeholder.duration"),
            structureDesc: "--",
            fluctuationScore: percentageString(snapshot.fluctuationScore),
            fluctuationStatus: localStatusText(for: snapshot.fluctuationScore, inverted: true),
            fluctuationIntervention: L("explore.placeholder.text"),
            fluctuationAwakeCount: snapshot.fluctuationAwakeCount ?? L("explore.placeholder.count"),
            fluctuationAwakeDuration: snapshot.fluctuationAwakeDuration ?? L("explore.placeholder.duration"),
            fluctuationAwakeType: L("explore.placeholder.text"),
            fluctuationHrRange: snapshot.fluctuationHrRange ?? L("explore.placeholder.hr_fluctuation"),
            fluctuationRespRange: snapshot.fluctuationRespRange ?? L("explore.placeholder.percent"),
            fluctuationDesc: "--",
            sceneId: "",
            sceneName: "",
            sceneType: "",
            preferenceDesc: "--",
            adviceDesc: "--",
            quoteText: L("explore.quote.text"),
            articles: defaultArticles(),
            emptyStateScore: L("explore.empty.score"),
            emptyStateTitle: L("explore.empty.title"),
            emptyStateMessage: L("explore.empty.message")
        )
    }

    private func fetchLocalSnapshot() async -> LocalExploreSnapshot {
        // 用非结构化 Task 而不是 `async let`：对 async let 变量做 `try? await`
        // 会打乱任务分配器的栈序，触发 asyncLet_finish_after_task_completion
        // 里的致命断言，真机必崩（见 HealthDataManager 里的说明）。
        let metricsTask = Task { try? await HealthDataManager.shared.fetchLatestSleepVitalsMetrics(forceLive: true) }
        let aggregateTask = Task { try? await HealthDataManager.shared.fetchSleepDailyAggregates(days: 1) }
        let stagesTask = Task { try? await HealthDataManager.shared.fetchLatestSleepStages(forceLive: true) }
        let dayDataTask = Task { try? await HealthDataManager.shared.fetchDailyData(anchorDate: Date()) }

        let metrics = await metricsTask.value
        let aggregate = await aggregateTask.value?.last
        let stages = (await stagesTask.value) ?? []
        let dayData = await dayDataTask.value

        let asleepStages = stages.filter { stage in
            switch stage.stage {
            case .awake:
                return false
            case .rem, .core, .deep:
                return true
            }
        }

        let firstSleepTime = asleepStages.first.map { formatTime($0.startTime) }
        let longestContinuousMinutes = longestContinuousSleepMinutes(in: stages)
        let awakeStages = stages.filter { if case .awake = $0.stage { return true } else { return false } }
        let awakeCount = awakeStages.count
        let awakeDurationMinutes = Int(awakeStages.reduce(0.0) { partial, stage in
            partial + stage.endTime.timeIntervalSince(stage.startTime) / 60.0
        }.rounded())

        let totalSleepHours = aggregate?.totalSleepHours ?? metrics?.sleepSummary?.totalSleepHours ?? 0
        let deepSleepHours = aggregate?.deepSleepHours ?? metrics?.sleepSummary?.deepSleepHours ?? 0
        let remSleepHours = aggregate?.remSleepHours ?? metrics?.sleepSummary?.remSleepHours ?? 0
        let lightSleepHours = aggregate?.coreSleepHours ?? metrics?.sleepSummary?.lightSleepHours ?? 0

        let remPercent = percentString(part: remSleepHours, total: totalSleepHours)
        let deepPercent = percentString(part: deepSleepHours, total: totalSleepHours)
        let lightPercent = percentString(part: lightSleepHours, total: totalSleepHours)

        let validHeartRateRanges = dayData?.heartRateRange.filter(\.isValid) ?? []
        let heartRateRangeText: String?
        if let minValue = validHeartRateRanges.map(\.min).min(),
           let maxValue = validHeartRateRanges.map(\.max).max() {
            heartRateRangeText = String(format: L("explore.value.hr_range_format"), "\(Int(minValue.rounded()))-\(Int(maxValue.rounded()))")
        } else {
            heartRateRangeText = nil
        }

        let respirationText = metrics?.respiratoryRate.map { String(format: L("explore.value.resp_rate_format"), "\(Int($0.value.rounded()))") }
        let heartRateText = metrics?.heartRate.map { String(format: L("explore.value.hr_format"), "\(Int($0.value.rounded()))") }

        let efficiencyScore = aggregate?.efficiencyScore.map { Int($0.rounded()) }
        let structureScore: Int?
        if totalSleepHours > 0 {
            structureScore = Int((((deepSleepHours + remSleepHours) / totalSleepHours) * 100.0).rounded())
        } else {
            structureScore = nil
        }

        let fluctuationScore: Int?
        if awakeDurationMinutes > 0 || awakeCount > 0 {
            let penalty = min(100.0, Double(awakeDurationMinutes) * 1.2 + Double(max(awakeCount - 1, 0)) * 10.0)
            fluctuationScore = Int(max(0.0, 100.0 - penalty).rounded())
        } else if totalSleepHours > 0 {
            fluctuationScore = 100
        } else {
            fluctuationScore = nil
        }

        let onsetText = aggregate?.sleepOnsetMinutes.map { String(Int($0.rounded())) }

        let hasData = (aggregate?.hasData == true) || metrics?.heartRate != nil || metrics?.sleepSummary != nil || !stages.isEmpty

        return LocalExploreSnapshot(
            hasData: hasData,
            efficiencyScore: efficiencyScore,
            efficiencyOnsetTime: onsetText,
            efficiencyFirstSleepTime: firstSleepTime,
            efficiencyBeforeHr: heartRateText,
            efficiencyBeforeRespiration: respirationText,
            structureScore: structureScore,
            structureContinuous: longestContinuousMinutes > 0 ? "\(longestContinuousMinutes)" : nil,
            structureRem: remPercent,
            structureDeep: deepPercent,
            structureLight: lightPercent,
            fluctuationScore: fluctuationScore,
            fluctuationAwakeCount: awakeCount > 0 ? String(format: L("explore.value.count_format"), "\(awakeCount)") : nil,
            fluctuationAwakeDuration: awakeDurationMinutes > 0 ? String(format: L("explore.value.duration_format"), "\(awakeDurationMinutes)") : nil,
            fluctuationHrRange: heartRateRangeText,
            fluctuationRespRange: respirationText
        )
    }

    private func longestContinuousSleepMinutes(in stages: [HealthDataManager.SleepStageDetail]) -> Int {
        var longest: TimeInterval = 0
        var current: TimeInterval = 0

        for stage in stages.sorted(by: { $0.startTime < $1.startTime }) {
            switch stage.stage {
            case .awake:
                longest = max(longest, current)
                current = 0
            case .rem, .core, .deep:
                current += stage.endTime.timeIntervalSince(stage.startTime)
            }
        }

        longest = max(longest, current)
        return Int((longest / 60.0).rounded())
    }

    private func percentString(part: Double?, total: Double) -> String? {
        guard let part, total > 0, part >= 0 else { return nil }
        return "\(Int(((part / total) * 100.0).rounded()))%"
    }

    private func formatTime(_ date: Date) -> String {
        // 按 locale 显示：en `10:29 PM` / zh `22:29`
        DateDisplay.time(date)
    }

    private func localStatusText(for score: Int?, inverted: Bool) -> String {
        guard let score else { return L("explore.placeholder.label") }
        if inverted {
            if score >= 70 { return L("explore.status.health_range") }
            if score >= 40 { return L("explore.status.average") }
            return L("explore.status.fluctuation_high")
        }

        if score >= 70 { return L("explore.status.health_range") }
        if score >= 40 { return L("explore.status.average") }
        return L("explore.placeholder.label")
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

    /// 无缓存、无本地数据、服务端也没应答时的空状态，文案与 buildData 的无数据分支同一套（设计稿 洞察 2）。
    private func defaultData() -> ExploreData {
        ExploreData(
            hasData: false,
            introText: L("explore.empty.intro"),
            introDetailText: L("explore.empty.intro_detail"),
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
            efficiencyDesc: L("explore.empty.desc.efficiency"),
            structureScore: L("explore.placeholder.efficiency"),
            structureStatus: L("explore.placeholder.label"),
            structureContinuous: L("explore.placeholder.number"),
            structureRem: L("explore.placeholder.duration"),
            structureDeep: L("explore.placeholder.duration"),
            structureLight: L("explore.placeholder.duration"),
            structureDesc: L("explore.empty.desc.structure"),
            fluctuationScore: L("explore.placeholder.efficiency"),
            fluctuationStatus: L("explore.placeholder.label"),
            fluctuationIntervention: L("explore.placeholder.text"),
            fluctuationAwakeCount: L("explore.placeholder.count"),
            fluctuationAwakeDuration: L("explore.placeholder.duration"),
            fluctuationAwakeType: L("explore.placeholder.text"),
            fluctuationHrRange: L("explore.placeholder.hr_fluctuation"),
            fluctuationRespRange: L("explore.placeholder.percent"),
            fluctuationDesc: L("explore.empty.desc.fluctuation"),
            sceneId: "",
            sceneName: "",
            sceneType: "",
            preferenceDesc: L("explore.empty.desc.preference"),
            adviceDesc: L("explore.empty.desc.advice"),
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
