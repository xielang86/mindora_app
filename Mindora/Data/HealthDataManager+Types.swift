import Foundation
import HealthKit

// MARK: - Internal wrappers to avoid declaring global Sendable conformances on imported Foundation classes
#if swift(>=5.7)
struct _SendablePredicate: @unchecked Sendable { let value: NSPredicate }
struct _SendableSortDescriptor: @unchecked Sendable { let value: NSSortDescriptor }
#endif

// MARK: - Data Types

/// Struct holding fetched health metrics (latest values or summaries)
struct HealthMetrics {
    var heartRate: MetricValue?            // bpm
    var heartRateVariability: MetricValue? // ms (SDNN)
    var respiratoryRate: MetricValue?      // breaths/min
    var restingHeartRate: MetricValue?     // bpm
    var sleepingWristTemperature: MetricValue? // degC, delta from baseline when available
    var bodyTemperature: MetricValue?      // degC
    var sleepSummary: SleepValue?
    var lastUpdated: Date?            // 最后一次采集数据的时间
    
    struct MetricValue {
        let value: Double
        let date: Date
    }

    struct SleepValue {
        let totalSleepHours: Double      // 实际睡眠时间（睡着的时间）
        let deepSleepHours: Double?
        let remSleepHours: Double?
        let lightSleepHours: Double?
        let timeInBed: Double?           // 在床上的总时间（包括睡眠和清醒时间）
        let date: Date                   // 睡眠数据的日期
    }
}

extension HealthDataManager {
    
    /// 睡眠阶段详细数据（用于睡眠图表展示）
    struct SleepStageDetail {
        enum Stage {
            case awake, rem, core, deep
        }
        let stage: Stage
        let startTime: Date
        let endTime: Date
    }

    struct SleepDailyAggregate {
        let date: Date
        let totalSleepHours: Double
        let deepSleepHours: Double
        let remSleepHours: Double
        let coreSleepHours: Double
        let awakeMinutes: Double
        let timeInBedHours: Double
        let sleepOnsetMinutes: Double?

        var hasData: Bool {
            totalSleepHours > 0 || timeInBedHours > 0
        }

        var efficiencyScore: Double? {
            guard timeInBedHours > 0 else { return nil }
            return max(0, min(100, (totalSleepHours / timeInBedHours) * 100.0))
        }
    }

    struct HealthSeriesData {
        struct SamplePoint { let timestamp: Int; let value: Double }
        var heartRate: [SamplePoint] = []            // bpm
        var hrv: [SamplePoint] = []                  // ms
        var respiratoryRate: [SamplePoint] = []      // breaths/min
        var restingHeartRate: [SamplePoint] = []     // bpm
        var sleepingWristTemperature: [SamplePoint] = [] // degC
        var bodyTemperature: [SamplePoint] = []      // degC
        // 睡眠阶段：用区间表示；为了复用 behaviors 的 [timestamp,value] 结构，后续上传时会采用 [startTs, durationSeconds]
        struct SleepStagePoint { let startTs: Int; let endTs: Int; let duration: Double }
        var deepSleep: [SleepStagePoint] = []
        var remSleep: [SleepStagePoint] = []
        var lightSleep: [SleepStagePoint] = []       // core/light
        // 可以按需扩展其它指标
    }

    /// 心率范围数据点结构体
    struct HeartRateRangePoint {
        let min: Double
        let max: Double
        
        /// 数据是否有效（非零）
        var isValid: Bool {
            return min > 0 && max > 0
        }
        
        /// 空数据点
        static let empty = HeartRateRangePoint(min: 0, max: 0)
    }

    /// 睡眠范围数据点结构体
    /// 用于周/月/年视图的垂直范围柱状图，Y轴代表时间点
    struct SleepRangePoint {
        /// 卧床开始时间（以分钟表示，相对于22:00，例如22:30 = 30，次日01:00 = 180）
        let bedStartMinutes: Double
        /// 卧床结束时间（以分钟表示）
        let bedEndMinutes: Double
        /// 睡眠开始时间（以分钟表示）
        let sleepStartMinutes: Double
        /// 睡眠结束时间（以分钟表示）
        let sleepEndMinutes: Double
        
        /// 数据是否有效
        var isValid: Bool {
            return bedEndMinutes > bedStartMinutes && sleepEndMinutes > sleepStartMinutes
        }
        
        /// 空数据点
        static let empty = SleepRangePoint(bedStartMinutes: 0, bedEndMinutes: 0, sleepStartMinutes: 0, sleepEndMinutes: 0)
    }

    /// 日视图睡眠数据点结构体
    /// 用于日视图的水平条形图
    struct DailySleepPoint {
        /// 小时（0-23）
        let hour: Int
        /// 该小时内卧床的分钟数（0-60）
        let bedMinutes: Double
        /// 该小时内睡眠的分钟数（0-60）
        let sleepMinutes: Double
        
        /// 数据是否有效
        var isValid: Bool {
            return bedMinutes > 0 || sleepMinutes > 0
        }
    }

    /// 月度和年度健康数据
    struct PeriodHealthData {
        var heartRate: [Double] = []
        var heartRateRange: [HeartRateRangePoint] = []  // 心率范围数据（最小/最大值）
        var hrv: [Double] = []
        var sleep: [Double] = []
        var sleepRange: [SleepRangePoint] = []  // 睡眠范围数据（卧床/睡眠时间段）
        var dailySleep: [DailySleepPoint] = []  // 日视图每小时睡眠数据
    }
}
