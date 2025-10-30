import Foundation

/// 支持的健康指标键（与 HealthDataUploader.buildPayload 中 behaviors key 对应的语义）
enum HealthMetricKey: String, CaseIterable, Codable, Hashable {
    case heartRate              // heart_rate
    case hrv                    // heart_rate_variability_sdnn
    case sleepStages            // sleep_stage_*

    var localizedName: String {
        switch self {
        case .heartRate: return L("health.metric.heart_rate")
        case .hrv: return L("health.metric.hrv")
        case .sleepStages: return L("health.metric.sleep")
        }
    }
}

/// 同步周期枚举（秒）
enum HealthSyncInterval: Int, CaseIterable, Codable {
    case six = 6
    case twelve = 12
    case thirty = 30

    var localizedName: String {
        switch self {
        case .six: return L("health.sync.interval.6s")
        case .twelve: return L("health.sync.interval.12s")
        case .thirty: return L("health.sync.interval.30s")
        }
    }
}

/// 健康同步配置
struct HealthSyncConfig: Codable, Equatable {
    var enabled: Bool
    var interval: HealthSyncInterval
    var metrics: Set<HealthMetricKey>

    static func `default`() -> HealthSyncConfig { .init(enabled: true, interval: .twelve, metrics: Set(HealthMetricKey.allCases)) }
}

/// 管理配置的存储与通知
final class HealthSyncConfigStore {
    static let shared = HealthSyncConfigStore()
    private init() { load() }

    private let userDefaultsKey = "health.sync.config.v1"
    static let configDidChangeNotification = Notification.Name("health.sync.config.changed")

    private(set) var current: HealthSyncConfig = .default()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func update(_ block: (inout HealthSyncConfig) -> Void) {
        var cfg = current
        block(&cfg)
        save(cfg)
    }

    func save(_ cfg: HealthSyncConfig) {
        current = cfg
        if let data = try? encoder.encode(cfg) { UserDefaults.standard.set(data, forKey: userDefaultsKey) }
        NotificationCenter.default.post(name: Self.configDidChangeNotification, object: cfg)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey), let cfg = try? decoder.decode(HealthSyncConfig.self, from: data) else {
            current = .default(); return
        }
        current = cfg
    }
}
