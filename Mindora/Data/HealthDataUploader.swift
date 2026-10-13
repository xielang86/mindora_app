import Foundation

struct HealthBehavior: Codable {
    let timestamp: Int
    let value: Double
}

// 内部用户画像载体（对应 Python 端 UserProfile dataclass）
struct UpdateProfilePayload: Codable {
    let uid_emb: [Double]
    let behaviors: [String: [[AnyCodable]]]

    init(uid_emb: [Double], behaviors: [String: [[AnyCodable]]]) {
        self.uid_emb = uid_emb
        self.behaviors = behaviors
    }
}

private struct UpdateProfileRequestData: Codable {
    let uid: String
    let jwtToken: String
    let language: String
    /// 客户端时区。服务端必须用它在**入库时**把本批数据归到自然日——
    /// behaviors 里只有 Unix 时间戳，按 UTC 或服务器时区归日会与客户端切片错位半天。
    let timezone: String
    /// 健康数据口径版本，见 Constants.Network.healthDataSchemaVersion
    let healthSchemaVersion: Int
    let userProfile: UpdateProfilePayload

    enum CodingKeys: String, CodingKey {
        case uid
        case jwtToken = "jwt_token"
        case language
        case timezone
        case healthSchemaVersion = "health_schema_version"
        case userProfile = "user_profile"
    }
}

// 新的顶层请求封装：与服务端 Python UpdateProfileRequest(request_type, timestamp, version, data) 对齐
private struct UpdateProfileRequestEnvelope: Codable {
    let requestType: String
    let timestamp: Int
    let version: String
    let data: UpdateProfileRequestData

    init(requestType: String = "update_profile", timestamp: Int = Int(Date().timeIntervalSince1970), version: String = "1.0", data: UpdateProfileRequestData) {
        self.requestType = requestType
        self.timestamp = timestamp
        self.version = version
        self.data = data
    }

    enum CodingKeys: String, CodingKey {
        case requestType = "request_type"
        case timestamp
        case version
        case data
    }
}

// {"request_type":"update_profile","timestamp":...,"version":"1.0","data":{"uid":...,"jwt_token":...,"user_profile":{...画像字段...}}}。
// 轻量 AnyCodable，用于编码 [Tuple] 这类动态结构
struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let i = try? container.decode(Int.self) { value = i; return }
        if let d = try? container.decode(Double.self) { value = d; return }
        if let s = try? container.decode(String.self) { value = s; return }
        if let b = try? container.decode(Bool.self) { value = b; return }
        if let arr = try? container.decode([AnyCodable].self) { value = arr.map { $0.value }; return }
        if let dict = try? container.decode([String: AnyCodable].self) { value = dict.mapValues { $0.value }; return }
        throw DecodingError.typeMismatch(AnyCodable.self, .init(codingPath: container.codingPath, debugDescription: "Unsupported type"))
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let i as Int: try container.encode(i)
        case let d as Double: try container.encode(d)
        case let s as String: try container.encode(s)
        case let b as Bool: try container.encode(b)
        case let arr as [Any]: try container.encode(arr.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            let ctx = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type")
            throw EncodingError.invalidValue(value, ctx)
        }
    }
}

enum HealthDataUploaderError: Error { case invalidURL, missingCredentials, requestFailed, badStatus(code: Int), serverRejected(message: String?) }

final class HealthDataUploader {
    private static let maxLogChars = 4000

    /// 这里是本文件自己的 pretty 打印（不走 Log.prettyJSON），所以必须自己打码：
    /// 上传体里带着 `jwt_token`，原样写进去等于把长期凭证留在 LogFileWriter 的滚动文件里。
    private static func prettyJSONString(from data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data, options: []),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
           let str = String(data: pretty, encoding: .utf8) {
            return truncate(Log.redactSecrets(str))
        }
        if let str = String(data: data, encoding: .utf8) { return truncate(Log.redactSecrets(str)) }
        return "<non-utf8 body: \(data.count) bytes>"
    }

    private static func truncate(_ s: String) -> String {
        if s.count <= maxLogChars { return s }
        let endIdx = s.index(s.startIndex, offsetBy: maxLogChars)
        return String(s[..<endIdx]) + "…(truncated)"
    }

    static func makeFakePayload(uid: String) -> UpdateProfilePayload {
        Log.info("Uploader", "makeFakePayload uid=\(uid)")
        // 假数据：心率（bpm）
        let now = Int(Date().timeIntervalSince1970)
        let heart: [[AnyCodable]] = [
            [AnyCodable(now - 60), AnyCodable(78)],
            [AnyCodable(now - 30), AnyCodable(82)],
            [AnyCodable(now), AnyCodable(80)]
        ]
        let behaviors: [String: [[AnyCodable]]] = [
            "heart_rate": heart
        ]
        Log.info("Uploader", "payload behaviors=\(behaviors.keys.joined(separator: ",")) heartCount=\(heart.count)")
        return UpdateProfilePayload(uid_emb: [], behaviors: behaviors)
    }

    /// 使用真实 HealthKit 数据构建 payload
    /// - Parameters:
    ///   - uid: 用户唯一 ID
    ///   - series: HealthSeriesData （来自 HealthDataManager.fetchRecentSeries）
    static func buildPayload(uid: String, series: HealthDataManager.HealthSeriesData) -> UpdateProfilePayload {
        var behaviors: [String: [[AnyCodable]]] = [:]

        func mapPoints(_ points: [HealthDataManager.HealthSeriesData.SamplePoint]) -> [[AnyCodable]] {
            points.map { [AnyCodable($0.timestamp), AnyCodable($0.value)] }
        }

        // 心率序列不再上传；改为上传睡眠心率区间的 min / max 两条，
        // 沿用 [timestamp, value] 结构，时间戳统一取该晚睡眠会话的起点。
        if let range = series.sleepHeartRateRange {
            behaviors["sleep_heart_rate_min"] = [[AnyCodable(range.startTs), AnyCodable(range.min)]]
            behaviors["sleep_heart_rate_max"] = [[AnyCodable(range.startTs), AnyCodable(range.max)]]
        }
        if !series.hrv.isEmpty { behaviors["sleep_heart_rate_variability_sdnn"] = mapPoints(series.hrv) }
        if !series.respiratoryRate.isEmpty { behaviors["sleep_respiratory_rate"] = mapPoints(series.respiratoryRate) }
        if !series.restingHeartRate.isEmpty { behaviors["resting_heart_rate"] = mapPoints(series.restingHeartRate) }
        if !series.sleepingWristTemperature.isEmpty { behaviors["sleeping_wrist_temperature"] = mapPoints(series.sleepingWristTemperature) }
        if !series.bodyTemperature.isEmpty { behaviors["sleep_body_temperature"] = mapPoints(series.bodyTemperature) }
        // 睡眠阶段：编码为 [startTimestamp, durationSeconds]
        func mapSleep(_ arr: [HealthDataManager.HealthSeriesData.SleepStagePoint]) -> [[AnyCodable]] {
            arr.map { [AnyCodable($0.startTs), AnyCodable($0.duration)] }
        }
        if !series.deepSleep.isEmpty { behaviors["sleep_stage_deep"] = mapSleep(series.deepSleep) }
        if !series.remSleep.isEmpty { behaviors["sleep_stage_rem"] = mapSleep(series.remSleep) }
        if !series.lightSleep.isEmpty { behaviors["sleep_stage_light"] = mapSleep(series.lightSleep) }
        // awake 与 inBed：新增。缺了这两条服务端还原不出 Time in Bed / 睡眠效率 / 入睡用时
        if !series.unspecifiedSleep.isEmpty { behaviors["sleep_stage_unspecified"] = mapSleep(series.unspecifiedSleep) }
        if !series.awakeSleep.isEmpty { behaviors["sleep_stage_awake"] = mapSleep(series.awakeSleep) }
        if !series.inBed.isEmpty { behaviors["sleep_in_bed"] = mapSleep(series.inBed) }

        if behaviors.isEmpty {
            Log.info("Uploader", "buildPayload: no real data collected, fallback to empty behaviors")
        } else {
            Log.info("Uploader", "buildPayload: metrics=\(behaviors.keys.joined(separator: ",")) points=\(behaviors.values.reduce(0){ $0 + $1.count })")
        }

        return UpdateProfilePayload(uid_emb: [], behaviors: behaviors)
    }

    // MARK: - 对账：服务端已有哪些天、分别什么版本

    private struct SyncStateRequestData: Codable {
        let uid: String
        let jwtToken: String
        let timezone: String
        let startDate: String
        let endDate: String

        enum CodingKeys: String, CodingKey {
            case uid
            case jwtToken = "jwt_token"
            case timezone
            case startDate = "start_date"
            case endDate = "end_date"
        }
    }

    private struct SyncStateRequestEnvelope: Codable {
        let requestType = "query_health_sync_state"
        let timestamp: Int
        let version = "1.0"
        let data: SyncStateRequestData

        enum CodingKeys: String, CodingKey {
            case requestType = "request_type"
            case timestamp
            case version
            case data
        }
    }

    private struct SyncStateResponse: Decodable {
        let code: Int
        let data: Payload?

        struct Payload: Decodable {
            let days: [Day]?

            struct Day: Decodable {
                let date: String
                let healthSchemaVersion: Int?

                enum CodingKeys: String, CodingKey {
                    case date
                    case healthSchemaVersion = "health_schema_version"
                }
            }
        }
    }

    /// 查询服务端在 [start, end] 内已有哪些自然日的数据、各是什么口径版本。
    ///
    /// 返回 `日期字符串 -> 版本号`。**接口不可用时抛错**，调用方据此退到兜底路径——
    /// 不能把"查不到"当成"服务端什么都没有"，否则每次同步都会全量重传。
    static func queryHealthSyncState(
        startDate: String,
        endDate: String,
        endpointURL: String = Constants.Network.profileURL,
        timeout: TimeInterval = Constants.Network.healthSyncTimeoutInterval
    ) async throws -> [String: Int] {
        guard let url = URL(string: endpointURL) else { throw HealthDataUploaderError.invalidURL }
        guard let jwtToken = AuthStorage.shared.token, !jwtToken.isEmpty else {
            throw HealthDataUploaderError.missingCredentials
        }

        let envelope = SyncStateRequestEnvelope(
            timestamp: Int(Date().timeIntervalSince1970),
            data: SyncStateRequestData(
                uid: AuthStorage.shared.preferredUserIdentifier ?? "",
                jwtToken: jwtToken,
                timezone: TimeZone.current.identifier,
                startDate: startDate,
                endDate: endDate
            )
        )

        var req = URLRequest(url: url)

        RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(envelope)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw HealthDataUploaderError.requestFailed }
        guard (200..<300).contains(http.statusCode) else {
            throw HealthDataUploaderError.badStatus(code: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(SyncStateResponse.self, from: data)
        guard decoded.code == 0 else {
            throw HealthDataUploaderError.serverRejected(message: "code=\(decoded.code)")
        }

        // 响应里没出现的天 = 服务端没有数据；版本缺省按 v1
        var result: [String: Int] = [:]
        for day in decoded.data?.days ?? [] {
            result[day.date] = day.healthSchemaVersion ?? 1
        }
        Log.info("Uploader", "queryHealthSyncState \(startDate)~\(endDate)：服务端已有 \(result.count) 天")
        return result
    }

    static func postUpdateProfile(payload: UpdateProfilePayload, endpointURL: String = Constants.Network.profileURL, timeout: TimeInterval = Constants.Network.healthSyncTimeoutInterval) async throws -> Data {
        guard let url = URL(string: endpointURL) else {
            Log.error("Uploader", "invalid URL endpoint=\(endpointURL)")
            throw HealthDataUploaderError.invalidURL
        }
        guard let jwtToken = AuthStorage.shared.token, !jwtToken.isEmpty else {
            Log.error("Uploader", "missing jwt token for health sync")
            throw HealthDataUploaderError.missingCredentials
        }

        let encoder = JSONEncoder()
        let envelope = UpdateProfileRequestEnvelope(
            data: UpdateProfileRequestData(
                uid: AuthStorage.shared.preferredUserIdentifier ?? "",
                jwtToken: jwtToken,
                language: LocalizationManager.shared.currentLanguage.rawValue,
                timezone: TimeZone.current.identifier,
                healthSchemaVersion: Constants.Network.healthDataSchemaVersion,
                userProfile: payload
            )
        )
        let body = try encoder.encode(envelope)

        var req = URLRequest(url: url)

        RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        Log.info("Uploader", "REQUEST JSON (envelope):\n\(prettyJSONString(from: body))")
        Log.info("Uploader", "POST \(url.absoluteString) body=\(body.count) bytes timeout=\(timeout)s")

        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = timeout
        let (data, resp) = try await URLSession(configuration: cfg).data(for: req)
        SessionExpirationCenter.handle(httpResponse: resp, data: data)
        guard let http = resp as? HTTPURLResponse else { throw HealthDataUploaderError.requestFailed }
        Log.info("Uploader", "HTTP status=\(http.statusCode) resp=\(data.count) bytes")
        Log.info("Uploader", "RESPONSE BODY:\n\(prettyJSONString(from: data))")
        guard (200..<300).contains(http.statusCode) else {
            Log.error("Uploader", "bad status=\(http.statusCode)")
            throw HealthDataUploaderError.badStatus(code: http.statusCode)
        }

        if let resp = try? JSONDecoder().decode(ServerAck.self, from: data) {
            if resp.code == 0 || resp.status?.lowercased() == "success" {
                return data
            } else {
                let serverMessage = resp.msg ?? resp.message
                Log.error("Uploader", "server rejected: code=\(resp.code.map(String.init) ?? "-") status=\(resp.status ?? "-") message=\(serverMessage ?? "-")")
                throw HealthDataUploaderError.serverRejected(message: serverMessage)
            }
        }

        Log.error("Uploader", "invalid ack json, refusing to mark success")
        throw HealthDataUploaderError.requestFailed
    }

}

// 服务端通用响应
struct ServerAck: Codable {
    let code: Int?
    let msg: String?
    let status: String?
    let message: String?
}
