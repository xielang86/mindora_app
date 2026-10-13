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
    /// 睡眠期间的心率区间（min–max），对应苹果健康「睡眠 → 比较 → 心率」。
    /// 只在需要展示它的入口（首页顶部 / 日视图 Sleep Performance）填充。
    var sleepHeartRateRange: HealthDataManager.HeartRateRangePoint?

    /// 全空的生命体征。视图拿不到生命体征时用它继续渲染睡眠部分 ——
    /// 「读到什么就展示什么」，不允许一项失败拖垮整页。
    static let empty = HealthMetrics()

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
        /// 不分期来源写的「睡着」（asleepUnspecified）。计入 totalSleepHours，
        /// 但**不计入 coreSleepHours** —— 苹果健康的 Core 也只算真正的 asleepCore。
        var unspecifiedSleepHours: Double = 0

        var hasData: Bool {
            totalSleepHours > 0 || timeInBedHours > 0
        }

        var efficiencyScore: Double? {
            guard timeInBedHours > 0 else { return nil }
            return max(0, min(100, (totalSleepHours / timeInBedHours) * 100.0))
        }
    }

    /// 周/月生命体征卡的口径：全部**限定在睡眠期间**，再按「晚」等权平均。
    /// 不按样本数加权 —— 否则睡得久的那晚会被放大。
    struct SleepVitalsAverages {
        /// 每晚睡眠跨度内心率均值的平均
        var sleepHeartRate: Double?
        /// 周期内所有晚的睡眠心率最低/最高
        var sleepHeartRateMin: Double?
        var sleepHeartRateMax: Double?
        /// 各睡眠日的静息心率日值的平均（苹果按日算好的基线，本身不分睡眠/清醒）
        var restingHeartRate: Double?
        /// 每晚睡眠跨度内呼吸频率均值的平均
        var respiratoryRate: Double?
        /// 睡眠腕温（苹果本就只在睡眠时产出，一晚一个值）的平均；无则退回睡眠跨度内的体温
        var wristTemperature: Double?
        /// 参与统计的晚数
        var nights: Int = 0

        var hasData: Bool {
            sleepHeartRate != nil || restingHeartRate != nil || respiratoryRate != nil || wristTemperature != nil
        }
    }

    struct HealthSeriesData {
        struct SamplePoint { let timestamp: Int; let value: Double }
        /// 心率原始序列。**不再上传**，只作为图表和推导睡眠心率区间的中间产物。
        var heartRate: [SamplePoint] = []            // bpm
        /// 睡眠心率区间（min–max），对应苹果健康「睡眠 → 比较 → 心率」。
        /// 上传的是这个区间，不是心率序列本身。
        struct SleepHeartRateRangePoint { let startTs: Int; let endTs: Int; let min: Double; let max: Double }
        var sleepHeartRateRange: SleepHeartRateRangePoint?
        var hrv: [SamplePoint] = []                  // ms
        var respiratoryRate: [SamplePoint] = []      // breaths/min
        var restingHeartRate: [SamplePoint] = []     // bpm
        var sleepingWristTemperature: [SamplePoint] = [] // degC
        var bodyTemperature: [SamplePoint] = []      // degC
        // 睡眠阶段：用区间表示；为了复用 behaviors 的 [timestamp,value] 结构，后续上传时会采用 [startTs, durationSeconds]
        struct SleepStagePoint { let startTs: Int; let endTs: Int; let duration: Double }
        var deepSleep: [SleepStagePoint] = []
        var remSleep: [SleepStagePoint] = []
        var lightSleep: [SleepStagePoint] = []       // core
        /// asleepUnspecified：不分期的来源（iPhone 睡眠专注、部分第三方 App）写的「睡着」。
        /// 苹果健康把它计入 Duration 但**不计入 Core**，所以不能并进 lightSleep。
        var unspecifiedSleep: [SleepStagePoint] = []
        var awakeSleep: [SleepStagePoint] = []       // 夜间清醒片段
        /// 上床区间。和睡眠阶段是重叠的两条轨，服务端要靠它算 Time in Bed / 睡眠效率 / 入睡用时
        var inBed: [SleepStagePoint] = []
        // 可以按需扩展其它指标
    }

    /// fetchSleepStages 的返回。前四条轨互斥（同一时刻只归属一个阶段），
    /// inBed 按设计与它们重叠，单独一条轨。
    typealias SleepStageSeries = (
        deep: [HealthSeriesData.SleepStagePoint],
        rem: [HealthSeriesData.SleepStagePoint],
        light: [HealthSeriesData.SleepStagePoint],
        unspecified: [HealthSeriesData.SleepStagePoint],
        awake: [HealthSeriesData.SleepStagePoint],
        inBed: [HealthSeriesData.SleepStagePoint]
    )

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
