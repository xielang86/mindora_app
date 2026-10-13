import Foundation

/// 记录各指标最近一次成功上传的时间戳（按上传 payload 的 behaviors 键）
/// 键采用与服务端一致的 wire key，例如：
/// - "heart_rate"
/// - "heart_rate_variability_sdnn"
/// - "respiratory_rate"
/// - "resting_heart_rate"
/// - "sleeping_wrist_temperature"
/// - "body_temperature"
/// - "sleep_stage_deep" | "sleep_stage_rem" | "sleep_stage_light" | "sleep_stage_unspecified" | "sleep_stage_awake"
/// - "sleep_in_bed"
/// - "sleep_heart_rate"
final class UploadStateStore {
    static let shared = UploadStateStore()
    private init() { load() }

    private let userDefaultsKey = "health.upload.lastTs.v1"
    private var lastTs: [String: Int] = [:]

    /// 已废弃的 wire key。老用户本地还留着它们的水位线，但已经不会再更新 ——
    /// determineWindowHours() 取 values.min() 决定同步窗口，留着会被越拖越旧，
    /// 最终把窗口永久钉死在 30 天上限。加载时直接剔除。
    private static let obsoleteKeys: Set<String> = [
        "heart_rate",                       // 改为只传睡眠心率区间 sleep_heart_rate
        "heart_rate_variability_sdnn",      // 改名 sleep_heart_rate_variability_sdnn
        "respiratory_rate",                 // 改名 sleep_respiratory_rate
        "body_temperature"                  // 改名 sleep_body_temperature
    ]

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
                lastTs = dict.filter { !Self.obsoleteKeys.contains($0.key) }
                if lastTs.count != dict.count {
                    Log.info("UploadState", "pruned obsolete keys: \(dict.keys.filter(Self.obsoleteKeys.contains))")
                    save()
                }
            }
        } catch {
            Log.error("UploadState", "load failed: \(error)")
        }
    }
}
