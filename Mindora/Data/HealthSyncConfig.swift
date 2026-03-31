import Foundation

/// 支持的健康指标键（与 HealthDataUploader.buildPayload 中 behaviors key 对应的语义）
enum HealthMetricKey: String, CaseIterable, Codable, Hashable {
    case heartRate              // heart_rate
    case hrv                    // heart_rate_variability_sdnn
    case respiratoryRate        // respiratory_rate
    case restingHeartRate       // resting_heart_rate
    case sleepingWristTemperature // sleeping_wrist_temperature
    case bodyTemperature        // body_temperature
    case sleepStages            // sleep_stage_*

    var localizedName: String {
        switch self {
        case .heartRate: return L("health.metric.heart_rate")
        case .hrv: return L("health.metric.hrv")
        case .respiratoryRate: return "Respiratory Rate"
        case .restingHeartRate: return "Resting Heart Rate"
        case .sleepingWristTemperature: return "Sleeping Wrist Temperature"
        case .bodyTemperature: return "Body Temperature"
        case .sleepStages: return L("health.metric.sleep")
        }
    }
}

/// 同步周期枚举（秒）
enum HealthSyncInterval: Int, CaseIterable, Codable {
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600

    var localizedName: String {
        switch self {
        case .fifteenMinutes: return "15 Min"
        case .thirtyMinutes: return "30 Min"
        case .oneHour: return "1 Hour"
        }
    }
}

/// 健康同步配置
struct HealthSyncConfig: Codable, Equatable {
    var enabled: Bool
    var interval: HealthSyncInterval
    var metrics: Set<HealthMetricKey>

    static func `default`() -> HealthSyncConfig { .init(enabled: true, interval: Constants.Network.healthSyncInterval, metrics: Set(HealthMetricKey.allCases)) }
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
