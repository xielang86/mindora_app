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
    let userProfile: UpdateProfilePayload

    enum CodingKeys: String, CodingKey {
        case uid
        case jwtToken = "jwt_token"
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

    private static func prettyJSONString(from data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data, options: []),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
           let str = String(data: pretty, encoding: .utf8) {
            return truncate(str)
        }
        if let str = String(data: data, encoding: .utf8) { return truncate(str) }
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

        if !series.heartRate.isEmpty { behaviors["heart_rate"] = mapPoints(series.heartRate) }
        if !series.hrv.isEmpty { behaviors["heart_rate_variability_sdnn"] = mapPoints(series.hrv) }
        if !series.respiratoryRate.isEmpty { behaviors["respiratory_rate"] = mapPoints(series.respiratoryRate) }
        if !series.restingHeartRate.isEmpty { behaviors["resting_heart_rate"] = mapPoints(series.restingHeartRate) }
        if !series.sleepingWristTemperature.isEmpty { behaviors["sleeping_wrist_temperature"] = mapPoints(series.sleepingWristTemperature) }
        if !series.bodyTemperature.isEmpty { behaviors["body_temperature"] = mapPoints(series.bodyTemperature) }
        // 睡眠阶段：编码为 [startTimestamp, durationSeconds]
        func mapSleep(_ arr: [HealthDataManager.HealthSeriesData.SleepStagePoint]) -> [[AnyCodable]] {
            arr.map { [AnyCodable($0.startTs), AnyCodable($0.duration)] }
        }
        if !series.deepSleep.isEmpty { behaviors["sleep_stage_deep"] = mapSleep(series.deepSleep) }
        if !series.remSleep.isEmpty { behaviors["sleep_stage_rem"] = mapSleep(series.remSleep) }
        if !series.lightSleep.isEmpty { behaviors["sleep_stage_light"] = mapSleep(series.lightSleep) }

        if behaviors.isEmpty {
            Log.info("Uploader", "buildPayload: no real data collected, fallback to empty behaviors")
        } else {
            Log.info("Uploader", "buildPayload: metrics=\(behaviors.keys.joined(separator: ",")) points=\(behaviors.values.reduce(0){ $0 + $1.count })")
        }

        return UpdateProfilePayload(uid_emb: [], behaviors: behaviors)
    }

    static func postUpdateProfile(payload: UpdateProfilePayload, endpointURL: String = Constants.Network.healthSyncURL, timeout: TimeInterval = Constants.Network.timeoutInterval) async throws -> Data {
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
                userProfile: payload
            )
        )
        let body = try encoder.encode(envelope)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        Log.info("Uploader", "REQUEST JSON (envelope):\n\(prettyJSONString(from: body))")
        Log.info("Uploader", "POST \(url.absoluteString) body=\(body.count) bytes timeout=\(timeout)s")

        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = timeout
        let (data, resp) = try await URLSession(configuration: cfg).data(for: req)
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

    static func postUpdateProfile(host: String, port: Int = 9001, payload: UpdateProfilePayload, timeout: TimeInterval = Constants.Network.timeoutInterval) async throws -> Data {
        let endpointURL = "http://\(host):\(port)/user_profile"
        return try await postUpdateProfile(payload: payload, endpointURL: endpointURL, timeout: timeout)
    }
}

// 服务端通用响应
struct ServerAck: Codable {
    let code: Int?
    let msg: String?
    let status: String?
    let message: String?
}
