import Foundation

/// 记录各指标最近一次成功上传的时间戳（按上传 payload 的 behaviors 键）
/// 键采用与服务端一致的 wire key，例如：
/// - "heart_rate"
/// - "heart_rate_variability_sdnn"
/// - "sleep_stage_deep" | "sleep_stage_rem" | "sleep_stage_light"
final class UploadStateStore {
    static let shared = UploadStateStore()
    private init() { load() }

    private let userDefaultsKey = "health.upload.lastTs.v1"
    private var lastTs: [String: Int] = [:]

    func get(_ key: String) -> Int? { lastTs[key] }
    func getAll() -> [String: Int] { lastTs }

    /// 批量更新：仅当新的时间戳更大时才覆盖
    func update(maxTimestamps: [String: Int]) {
        var changed = false
        for (k, v) in maxTimestamps {
            if let old = lastTs[k] {
                if v > old { lastTs[k] = v; changed = true }
            } else {
                lastTs[k] = v; changed = true
            }
        }
        if changed { save() }
    }

    /// 清除所有记录（调试或用户重置）
    func reset() { lastTs.removeAll(); save() }

    private func save() {
        do {
            let data = try JSONSerialization.data(withJSONObject: lastTs, options: [])
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            // 不影响主流程
            Log.error("UploadState", "save failed: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Int] {
                lastTs = dict
            }
        } catch {
            Log.error("UploadState", "load failed: \(error)")
        }
    }
}
