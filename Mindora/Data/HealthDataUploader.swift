import Foundation

struct HealthBehavior: Codable {
    let timestamp: Int
    let value: Double
}

// 内部用户画像载体（对应 Python 端 UserProfile dataclass）
struct UpdateProfilePayload: Codable {
    let uid: String
    let uid_emb: [Double]
    let long_term_profile: [[AnyCodable]]
    let behaviors: [String: [[AnyCodable]]]

    init(uid: String, uid_emb: [Double], long_term_profile: [[AnyCodable]], behaviors: [String: [[AnyCodable]]]) {
        self.uid = uid
        self.uid_emb = uid_emb
        self.long_term_profile = long_term_profile
        self.behaviors = behaviors
    }
}

// 新的顶层请求封装：与服务端 Python UpdateProfileRequest(action, user_profile) 对齐
struct UpdateProfileRequestEnvelope: Codable {
    let action: String
    let user_profile: UpdateProfilePayload
    init(action: String = "update_profile", user_profile: UpdateProfilePayload) {
        self.action = action
        self.user_profile = user_profile
    }
}

// {"action":"update_profile","user_profile":{...画像字段...}}。
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

enum HealthDataUploaderError: Error { case invalidURL, requestFailed, badStatus(code: Int), serverRejected(message: String?) }

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
        let ltp: [[AnyCodable]] = [[AnyCodable("baseline_hr"), AnyCodable(78.0)]]
        Log.info("Uploader", "payload behaviors=\(behaviors.keys.joined(separator: ",")) heartCount=\(heart.count)")
        return UpdateProfilePayload(uid: uid, uid_emb: [], long_term_profile: ltp, behaviors: behaviors)
    }

    /// 使用真实 HealthKit 数据构建 payload
    /// - Parameters:
    ///   - uid: 用户唯一 ID
    ///   - series: HealthSeriesData （来自 HealthDataManager.fetchRecentSeries）
    ///   - includeBaseline: 是否计算并写入 long_term_profile 基线数据（平均心率等）
    static func buildPayload(uid: String, series: HealthDataManager.HealthSeriesData, includeBaseline: Bool = true) -> UpdateProfilePayload {
        var behaviors: [String: [[AnyCodable]]] = [:]

        func mapPoints(_ points: [HealthDataManager.HealthSeriesData.SamplePoint]) -> [[AnyCodable]] {
            points.map { [AnyCodable($0.timestamp), AnyCodable($0.value)] }
        }

        if !series.heartRate.isEmpty { behaviors["heart_rate"] = mapPoints(series.heartRate) }
        if !series.hrv.isEmpty { behaviors["heart_rate_variability_sdnn"] = mapPoints(series.hrv) }
        // 睡眠阶段：编码为 [startTimestamp, durationSeconds]
        func mapSleep(_ arr: [HealthDataManager.HealthSeriesData.SleepStagePoint]) -> [[AnyCodable]] {
            arr.map { [AnyCodable($0.startTs), AnyCodable($0.duration)] }
        }
        if !series.deepSleep.isEmpty { behaviors["sleep_stage_deep"] = mapSleep(series.deepSleep) }
        if !series.remSleep.isEmpty { behaviors["sleep_stage_rem"] = mapSleep(series.remSleep) }
        if !series.lightSleep.isEmpty { behaviors["sleep_stage_light"] = mapSleep(series.lightSleep) }

        var ltp: [[AnyCodable]] = []
        if includeBaseline {
            if !series.heartRate.isEmpty {
                let avg = series.heartRate.map { $0.value }.reduce(0, +) / Double(series.heartRate.count)
                ltp.append([AnyCodable("avg_heart_rate"), AnyCodable(avg)])
            }
            if !series.hrv.isEmpty {
                let avg = series.hrv.map { $0.value }.reduce(0, +) / Double(series.hrv.count)
                ltp.append([AnyCodable("avg_hrv_sdnn"), AnyCodable(avg)])
            }
            // 睡眠总时长（近24h内区间合计）
            let totalSleepSeconds = series.deepSleep.reduce(0){$0+$1.duration} + series.remSleep.reduce(0){$0+$1.duration} + series.lightSleep.reduce(0){$0+$1.duration}
            if totalSleepSeconds > 0 {
                ltp.append([AnyCodable("total_sleep_hours"), AnyCodable(totalSleepSeconds / 3600.0)])
            }
        }

        if behaviors.isEmpty {
            Log.info("Uploader", "buildPayload: no real data collected, fallback to empty behaviors")
        } else {
            Log.info("Uploader", "buildPayload: metrics=\(behaviors.keys.joined(separator: ",")) points=\(behaviors.values.reduce(0){ $0 + $1.count })")
        }

        return UpdateProfilePayload(uid: uid, uid_emb: [], long_term_profile: ltp, behaviors: behaviors)
    }

    static func postUpdateProfile(host: String, port: Int = 9102, payload: UpdateProfilePayload, timeout: TimeInterval = 5.0) async throws -> Data {
        guard let url = URL(string: "http://\(host):\(port)/update_profile") else {
            Log.error("Uploader", "invalid URL host=\(host) port=\(port)")
            throw HealthDataUploaderError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
    // 新格式：封装为 { action: "update_profile", user_profile: { uid, uid_emb, long_term_profile, behaviors } }
    // 若需回退旧格式：直接 encoder.encode(payload) 并去除 envelope。
        let envelope = UpdateProfileRequestEnvelope(user_profile: payload)
        let body = try encoder.encode(envelope)
        Log.info("Uploader", "REQUEST JSON (envelope):\n\(prettyJSONString(from: body))")
        Log.info("Uploader", "POST \(url.absoluteString) body=\(body.count) bytes timeout=\(timeout)s")
        req.httpBody = body
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
        // 解析服务端响应，只有 {"status":"success"} 才视为成功
        if let resp = try? JSONDecoder().decode(ServerAck.self, from: data) {
            if resp.status.lowercased() == "success" {
                return data
            } else {
                Log.error("Uploader", "server rejected: status=\(resp.status) message=\(resp.message ?? "-")")
                throw HealthDataUploaderError.serverRejected(message: resp.message)
            }
        }
        // 未能解析时，保守起见也认为失败，避免错误地标记为已上传
        Log.error("Uploader", "invalid ack json, refusing to mark success")
        throw HealthDataUploaderError.requestFailed
    }
}

// 服务端通用响应
struct ServerAck: Codable { let status: String; let message: String? }
