import Foundation
import HealthKit

// MARK: - Internal wrappers to avoid declaring global Sendable conformances on imported Foundation classes
#if swift(>=5.7)
private struct _SendablePredicate: @unchecked Sendable { let value: NSPredicate }
private struct _SendableSortDescriptor: @unchecked Sendable { let value: NSSortDescriptor }
#endif

/// Struct holding fetched health metrics (latest values or summaries)
struct HealthMetrics {
    var heartRate: Double?            // bpm
    var heartRateVariability: Double? // ms (SDNN)
    var sleepSummary: SleepSummary?

    struct SleepSummary {
        let totalSleepHours: Double      // 实际睡眠时间（睡着的时间）
        let deepSleepHours: Double?
        let remSleepHours: Double?
        let lightSleepHours: Double?
        let timeInBed: Double?           // 在床上的总时间（包括睡眠和清醒时间）
    }
}

final class HealthDataManager {
    static let shared = HealthDataManager()
    private let healthStore = HKHealthStore()

    private init() {}

    enum HealthError: Error {
        case notAvailable
        case authorizationDenied
    }

    // MARK: - Authorization
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.notAvailable }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if let error = error { cont.resume(throwing: error); return }
                if success { cont.resume(); } else { cont.resume(throwing: HealthError.authorizationDenied) }
            }
        }
    }

    // MARK: - Public fetch
    func fetchLatestMetrics() async throws -> HealthMetrics {
        // Debug 模式：返回虚假数据用于测试
        if DesignConstants.isDebugMode {
            let debugSleepSummary = HealthMetrics.SleepSummary(
                totalSleepHours: DesignConstants.DebugHealthData.totalSleepHours,
                deepSleepHours: nil,
                remSleepHours: nil,
                lightSleepHours: nil,
                timeInBed: DesignConstants.DebugHealthData.timeInBed
            )
            
            return HealthMetrics(
                heartRate: DesignConstants.DebugHealthData.heartRate,
                heartRateVariability: DesignConstants.DebugHealthData.heartRateVariability,
                sleepSummary: debugSleepSummary
            )
        }
        
        // 正常模式：从 HealthKit 获取真实数据
        async let hr = fetchLatestQuantity(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let hrv = fetchLatestQuantity(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli))
        async let sleep = fetchSleepSummary()

        let metrics = HealthMetrics(
            heartRate: try await hr,
            heartRateVariability: try await hrv,
            sleepSummary: try await sleep
        )
        return metrics
    }
    
    // MARK: - Sleep Stage Data (for Sleep Graph)
    /// 睡眠阶段详细数据（用于睡眠图表展示）
    struct SleepStageDetail {
        enum Stage {
            case awake, rem, core, deep
        }
        let stage: Stage
        let startTime: Date
        let endTime: Date
    }
    
    /// 获取最近一次睡眠的详细阶段数据
    func fetchLatestSleepStages() async throws -> [SleepStageDetail] {
        // Debug 模式：返回模拟数据
        if DesignConstants.isDebugMode {
            return generateDebugSleepStages()
        }
        
        // 正常模式：从 HealthKit 获取真实数据
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let roughWindowStart = now.addingTimeInterval(-48 * 3600)
        
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[SleepStageDetail], Error>) in
            #if swift(>=5.7)
            let roughPredicateSendable = _SendablePredicate(value: HKQuery.predicateForSamples(withStart: roughWindowStart, end: now, options: []))
            #else
            let roughPredicateSendable = HKQuery.predicateForSamples(withStart: roughWindowStart, end: now, options: [])
            #endif
            let localPredicate = roughPredicateSendable.value
            
            let query = HKSampleQuery(sampleType: type, predicate: localPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let rawSamples = samples as? [HKCategorySample], !rawSamples.isEmpty else { cont.resume(returning: []); return }
                
                // 筛选出最近一次主睡眠的阶段数据
                let sleepStageValues: Set<Int>
                if #available(iOS 16.0, *) {
                    sleepStageValues = [
                        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                        HKCategoryValueSleepAnalysis.awake.rawValue,
                        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    ]
                } else {
                    sleepStageValues = [
                        HKCategoryValueSleepAnalysis.asleep.rawValue,
                        HKCategoryValueSleepAnalysis.awake.rawValue
                    ]
                }
                
                // 找到最近一次睡眠的结束时间
                guard let latestSample = rawSamples.filter({ sleepStageValues.contains($0.value) }).max(by: { $0.endDate < $1.endDate }) else {
                    cont.resume(returning: [])
                    return
                }
                
                // 计算该睡眠的窗口（18:00 -> 次日 18:00）
                func dayWindow(for endDate: Date) -> (start: Date, end: Date) {
                    let dayStartCandidate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.startOfDay(for: endDate))!
                    if endDate >= dayStartCandidate {
                        return (dayStartCandidate, dayStartCandidate.addingTimeInterval(24 * 3600))
                    } else {
                        let start = dayStartCandidate.addingTimeInterval(-24 * 3600)
                        return (start, start.addingTimeInterval(24 * 3600))
                    }
                }
                
                let window = dayWindow(for: latestSample.endDate)
                
                // 过滤并转换为 SleepStageDetail
                var stageDetails: [SleepStageDetail] = []
                
                for sample in rawSamples {
                    // 与窗口无交集跳过
                    if sample.endDate <= window.start || sample.startDate >= window.end { continue }
                    
                    let clippedStart = max(sample.startDate, window.start)
                    let clippedEnd = min(sample.endDate, window.end)
                    
                    let stage: SleepStageDetail.Stage
                    if #available(iOS 16.0, *) {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            stage = .deep
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            stage = .rem
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                            stage = .core
                        case HKCategoryValueSleepAnalysis.awake.rawValue:
                            stage = .awake
                        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                            stage = .core  // 默认当作核心睡眠
                        default:
                            continue  // 跳过 inBed 等其他状态
                        }
                    } else {
                        // iOS 16 之前的版本只有 asleep 和 awake
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleep.rawValue:
                            stage = .core  // 旧系统全部当作核心睡眠
                        case HKCategoryValueSleepAnalysis.awake.rawValue:
                            stage = .awake
                        default:
                            continue
                        }
                    }
                    
                    stageDetails.append(SleepStageDetail(stage: stage, startTime: clippedStart, endTime: clippedEnd))
                }
                
                // 按开始时间排序
                stageDetails.sort { $0.startTime < $1.startTime }
                
                cont.resume(returning: stageDetails)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    /// 生成 Debug 模式的模拟睡眠阶段数据
    /// 与 DesignConstants.DebugHealthData 保持一致：
    /// - 总睡眠时间（实际睡着）：7小时57分钟 = 477分钟
    /// - 在床上的总时间：8小时30分钟 = 510分钟
    /// - 清醒时间：33分钟
    private func generateDebugSleepStages() -> [SleepStageDetail] {
        let calendar = Calendar.current
        let now = Date()
        
        // 模拟昨晚 22:30 上床，今早 7:00 起床（8.5小时）
        let bedTime = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now)!)!
        
        // 创建一个真实的睡眠周期模式，确保总时长匹配：
        // 实际睡着时间：477分钟（深度+核心+REM）
        // 清醒时间：33分钟
        // 总时长：510分钟（8.5小时）
        //
        // 睡眠周期分布：
        // 22:30-22:45: 清醒（入睡前）15分钟
        // 22:45-23:45: 核心睡眠 60分钟
        // 23:45-01:15: 深度睡眠 90分钟
        // 01:15-01:30: 核心睡眠 15分钟
        // 01:30-02:15: REM 睡眠 45分钟
        // 02:15-02:20: 清醒（短暂醒来）5分钟
        // 02:20-03:20: 核心睡眠 60分钟
        // 03:20-04:30: 深度睡眠 70分钟
        // 04:30-04:50: 核心睡眠 20分钟
        // 04:50-05:40: REM 睡眠 50分钟
        // 05:40-05:45: 清醒（短暂醒来）5分钟
        // 05:45-06:30: 核心睡眠 45分钟
        // 06:30-06:52: REM 睡眠 22分钟
        // 06:52-07:00: 清醒（准备起床）8分钟
        //
        // 总计检查：
        // 核心睡眠：60+15+60+20+45 = 200分钟
        // 深度睡眠：90+70 = 160分钟
        // REM睡眠：45+50+22 = 117分钟
        // 总睡眠：200+160+117 = 477分钟 ✓
        // 清醒：15+5+5+8 = 33分钟 ✓
        // 总时长：477+33 = 510分钟 = 8.5小时 ✓
        
        var stages: [SleepStageDetail] = []
        
        func addStage(_ stage: SleepStageDetail.Stage, fromMinutes: Int, toMinutes: Int) {
            let start = bedTime.addingTimeInterval(TimeInterval(fromMinutes * 60))
            let end = bedTime.addingTimeInterval(TimeInterval(toMinutes * 60))
            stages.append(SleepStageDetail(stage: stage, startTime: start, endTime: end))
        }
        
        // 入睡前清醒 (15分钟)
        addStage(.awake, fromMinutes: 0, toMinutes: 15)
        
        // 第一个睡眠周期
        addStage(.core, fromMinutes: 15, toMinutes: 75)      // 60分钟
        addStage(.deep, fromMinutes: 75, toMinutes: 165)     // 90分钟
        addStage(.core, fromMinutes: 165, toMinutes: 180)    // 15分钟
        addStage(.rem, fromMinutes: 180, toMinutes: 225)     // 45分钟
        
        // 短暂醒来 (5分钟)
        addStage(.awake, fromMinutes: 225, toMinutes: 230)
        
        // 第二个睡眠周期
        addStage(.core, fromMinutes: 230, toMinutes: 290)    // 60分钟
        addStage(.deep, fromMinutes: 290, toMinutes: 360)    // 70分钟
        addStage(.core, fromMinutes: 360, toMinutes: 380)    // 20分钟
        addStage(.rem, fromMinutes: 380, toMinutes: 430)     // 50分钟
        
        // 短暂醒来 (5分钟)
        addStage(.awake, fromMinutes: 430, toMinutes: 435)
        
        // 第三个睡眠周期（早晨更多 REM）
        addStage(.core, fromMinutes: 435, toMinutes: 480)    // 45分钟
        addStage(.rem, fromMinutes: 480, toMinutes: 502)     // 22分钟
        
        // 起床前清醒 (8分钟)
        addStage(.awake, fromMinutes: 502, toMinutes: 510)
        
        return stages
    }

    // MARK: - Series (bulk) fetch for uploading
    struct HealthSeriesData {
        struct SamplePoint { let timestamp: Int; let value: Double }
        var heartRate: [SamplePoint] = []            // bpm
        var hrv: [SamplePoint] = []                  // ms
        // 睡眠阶段：用区间表示；为了复用 behaviors 的 [timestamp,value] 结构，后续上传时会采用 [startTs, durationSeconds]
        struct SleepStagePoint { let startTs: Int; let endTs: Int; let duration: Double }
        var deepSleep: [SleepStagePoint] = []
        var remSleep: [SleepStagePoint] = []
        var lightSleep: [SleepStagePoint] = []       // core/light
        // 可以按需扩展其它指标
    }

    /// 批量抓取最近 hoursBack 小时内的数据（简单方式：普通 sampleQuery）
    /// - Parameters:
    ///   - hoursBack: 回溯的小时数 (默认 24)
    ///   - maxSamples: 每个指标最大样本数 (默认 100)
    func fetchRecentSeries(hoursBack: Int = 24, maxSamples: Int = 100) async throws -> HealthSeriesData {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.notAvailable }
        var result = HealthSeriesData()
        let endDate = Date()
        let startDate = Date(timeIntervalSinceNow: TimeInterval(-hoursBack * 3600))
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        async let hrSamples = fetchSeries(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), predicate: predicate, limit: maxSamples)
        async let hrvSamples = fetchSeries(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), predicate: predicate, limit: maxSamples)

        result.heartRate = try await hrSamples
        result.hrv = try await hrvSamples
        if let stages = try await fetchSleepStages(start: startDate, end: endDate) {
            result.deepSleep = stages.deep
            result.remSleep = stages.rem
            result.lightSleep = stages.light
        }
        return result
    }

    private func fetchSeries(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate, limit: Int) async throws -> [HealthSeriesData.SamplePoint] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        // 为避免在 @Sendable 闭包中直接捕获非 Sendable 的 Foundation 对象(NSPredicate / NSSortDescriptor)，
        // 先在外层用 @unchecked Sendable 包装或复制，再在闭包内解包使用。
        #if swift(>=5.7)
        let sendablePredicate = _SendablePredicate(value: predicate)
        let sendableSort = _SendableSortDescriptor(value: NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false))
        #else
        let predicateRef = predicate
        let sortDescriptorsRef = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        #endif
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HealthSeriesData.SamplePoint], Error>) in
            #if swift(>=5.7)
            let localPredicate = sendablePredicate.value
            let localSort = [sendableSort.value]
            #else
            let localPredicate = predicateRef
            let localSort = sortDescriptorsRef
            #endif
            let query = HKSampleQuery(sampleType: type, predicate: localPredicate, limit: limit, sortDescriptors: localSort) { _, samples, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let qSamples = samples as? [HKQuantitySample], !qSamples.isEmpty else { cont.resume(returning: []); return }
                let mapped: [HealthSeriesData.SamplePoint] = qSamples.map { s in
                    let ts = Int(s.endDate.timeIntervalSince1970)
                    let v = s.quantity.doubleValue(for: unit)
                    return .init(timestamp: ts, value: v)
                }.sorted { $0.timestamp < $1.timestamp } // 按时间升序
                cont.resume(returning: mapped)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Helpers
    private func fetchLatestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Double?, Error>) in
            #if swift(>=5.7)
            let sp = _SendablePredicate(value: HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: []))
            let sd = _SendableSortDescriptor(value: NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false))
            #else
            let sp = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: [])
            let sd = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            #endif
            let localPredicate = sp.value
            let localSort = [sd.value]
            let query = HKSampleQuery(sampleType: type, predicate: localPredicate, limit: 1, sortDescriptors: localSort) { _, samples, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let quantitySample = samples?.first as? HKQuantitySample else { cont.resume(returning: nil); return }
                let value = quantitySample.quantity.doubleValue(for: unit)
                cont.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSleepSummary() async throws -> HealthMetrics.SleepSummary? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let now = Date()
        // 第一步：先抓取最近 48 小时所有睡眠样本（包含主睡眠与可能的小睡），用于定位“最近一次主睡眠”的结束时间。
        // 主睡眠的结束时间(早晨醒来)决定其归属的“日历日”（采用 18:00 → 次日 18:00 的日界）。
        let roughWindowStart = now.addingTimeInterval(-48 * 3600)
        #if swift(>=5.7)
        let roughPredicateSendable = _SendablePredicate(value: HKQuery.predicateForSamples(withStart: roughWindowStart, end: now, options: []))
        #else
        let roughPredicateSendable = HKQuery.predicateForSamples(withStart: roughWindowStart, end: now, options: [])
        #endif

        // 辅助函数：根据一个结束时间计算它所属“苹果日”窗口（18:00 ~ 次日 18:00）
        func dayWindow(for endDate: Date) -> (start: Date, end: Date) {
            let dayStartCandidate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.startOfDay(for: endDate))!
            if endDate >= dayStartCandidate { // 结束时间在当日 18:00 之后 => 属于下一个“苹果日”窗口的前半段
                return (dayStartCandidate, dayStartCandidate.addingTimeInterval(24 * 3600))
            } else {
                let start = dayStartCandidate.addingTimeInterval(-24 * 3600)
                return (start, start.addingTimeInterval(24 * 3600))
            }
        }

        // 第二步：查询后在本地计算窗口并汇总
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HealthMetrics.SleepSummary?, Error>) in
            let localPredicate = roughPredicateSendable.value
            let query = HKSampleQuery(sampleType: type, predicate: localPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let rawSamples = samples as? [HKCategorySample], !rawSamples.isEmpty else { cont.resume(returning: nil); return }

                // 仅选择真正代表睡眠阶段的样本（排除 inBed）用于决定最近一次主睡眠结束时间
                let sleepStageValues: Set<Int>
                if #available(iOS 16.0, *) {
                    sleepStageValues = [
                        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue // 兜底
                    ]
                } else {
                    sleepStageValues = [HKCategoryValueSleepAnalysis.asleep.rawValue]
                }

                // 最近一次“主睡眠”简单近似：最近一段连续睡眠阶段中结束时间最晚的那个阶段的 endDate。
                // 我们取所有阶段样本里 endDate 最大者。
                guard let latestStageSample = rawSamples.filter({ sleepStageValues.contains($0.value) }).max(by: { $0.endDate < $1.endDate }) else {
                    cont.resume(returning: nil); return
                }
                let window = dayWindow(for: latestStageSample.endDate)

                // 过滤到该 18:00→18:00 窗口内（与窗口有交集即可），并按阶段汇总时长（截断到窗口边界以防越界）。
                var total: TimeInterval = 0
                var deep: TimeInterval = 0
                var rem: TimeInterval = 0
                var light: TimeInterval = 0
                var inBed: TimeInterval = 0  // 卧床时间

                for s in rawSamples {
                    // 与窗口无交集跳过
                    if s.endDate <= window.start || s.startDate >= window.end { continue }
                    let clippedStart = max(s.startDate, window.start)
                    let clippedEnd = min(s.endDate, window.end)
                    let dur = clippedEnd.timeIntervalSince(clippedStart)
                    if dur <= 0 { continue }

                    if #available(iOS 16.0, *) {
                        switch s.value {
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            deep += dur; total += dur
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            rem += dur; total += dur
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                            light += dur; total += dur
                        case HKCategoryValueSleepAnalysis.inBed.rawValue:
                            inBed += dur  // 统计卧床时间
                        default:
                            break
                        }
                    } else {
                        if s.value == HKCategoryValueSleepAnalysis.asleep.rawValue { light += dur; total += dur }
                        else if s.value == HKCategoryValueSleepAnalysis.inBed.rawValue { inBed += dur }
                    }
                }

                let summary = HealthMetrics.SleepSummary(
                    totalSleepHours: total / 3600.0,
                    deepSleepHours: deep > 0 ? deep / 3600.0 : nil,
                    remSleepHours: rem > 0 ? rem / 3600.0 : nil,
                    lightSleepHours: light > 0 ? light / 3600.0 : nil,
                    timeInBed: inBed > 0 ? inBed / 3600.0 : nil
                )
                cont.resume(returning: summary)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Sleep Stages (interval samples)
    private func fetchSleepStages(start: Date, end: Date) async throws -> (deep: [HealthSeriesData.SleepStagePoint], rem: [HealthSeriesData.SleepStagePoint], light: [HealthSeriesData.SleepStagePoint])? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(deep: [HealthSeriesData.SleepStagePoint], rem: [HealthSeriesData.SleepStagePoint], light: [HealthSeriesData.SleepStagePoint])?, Error>) in
            #if swift(>=5.7)
            let sp = _SendablePredicate(value: HKQuery.predicateForSamples(withStart: start, end: end, options: []))
            #else
            let sp = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            #endif
            let localPredicate = sp.value
            let query = HKSampleQuery(sampleType: type, predicate: localPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else { cont.resume(returning: nil); return }
                var deep: [HealthSeriesData.SleepStagePoint] = []
                var rem: [HealthSeriesData.SleepStagePoint] = []
                var light: [HealthSeriesData.SleepStagePoint] = []
                for s in samples {
                    let startTs = Int(s.startDate.timeIntervalSince1970)
                    let endTs = Int(s.endDate.timeIntervalSince1970)
                    let dur = s.endDate.timeIntervalSince(s.startDate)
                    if #available(iOS 16.0, *) {
                        switch s.value {
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            deep.append(.init(startTs: startTs, endTs: endTs, duration: dur))
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            rem.append(.init(startTs: startTs, endTs: endTs, duration: dur))
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                            light.append(.init(startTs: startTs, endTs: endTs, duration: dur))
                        default:
                            break
                        }
                    } else {
                        if s.value == HKCategoryValueSleepAnalysis.asleep.rawValue { // 旧系统：全部归为 light
                            light.append(.init(startTs: startTs, endTs: endTs, duration: dur))
                        }
                    }
                }
                cont.resume(returning: (deep: deep, rem: rem, light: light))
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Monthly & Yearly Data
    /// 月度和年度健康数据
    struct PeriodHealthData {
        var heartRate: [Double] = []
        var hrv: [Double] = []
        var sleep: [Double] = []
    }
    
    /// 获取月度数据（最近30天）
    func fetchMonthlyData() async throws -> PeriodHealthData {
        // Debug 模式：返回模拟数据
        if DesignConstants.isDebugMode {
            return PeriodHealthData(
                heartRate: DesignConstants.DebugHealthData.monthlyHeartRate,
                hrv: DesignConstants.DebugHealthData.monthlyHRV,
                sleep: DesignConstants.DebugHealthData.monthlySleep
            )
        }
        
        // 真实模式：从 HealthKit 获取最近30天的平均数据
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate)!
        
        var result = PeriodHealthData()
        
        // 获取每天的平均心率
        result.heartRate = try await fetchDailyAverages(
            .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            startDate: startDate,
            endDate: endDate,
            days: 30
        )
        
        // 获取每天的平均HRV
        result.hrv = try await fetchDailyAverages(
            .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            startDate: startDate,
            endDate: endDate,
            days: 30
        )
        
        // 获取每天的睡眠时长
        result.sleep = try await fetchDailySleepHours(
            startDate: startDate,
            endDate: endDate,
            days: 30
        )
        
        return result
    }
    
    /// 获取年度数据（最近12个月）
    func fetchYearlyData() async throws -> PeriodHealthData {
        // Debug 模式：返回模拟数据
        if DesignConstants.isDebugMode {
            return PeriodHealthData(
                heartRate: DesignConstants.DebugHealthData.yearlyHeartRate,
                hrv: DesignConstants.DebugHealthData.yearlyHRV,
                sleep: DesignConstants.DebugHealthData.yearlySleep
            )
        }
        
        // 真实模式：从 HealthKit 获取最近12个月的平均数据
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -12, to: endDate)!
        
        var result = PeriodHealthData()
        
        // 获取每月的平均心率
        result.heartRate = try await fetchMonthlyAverages(
            .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            startDate: startDate,
            endDate: endDate,
            months: 12
        )
        
        // 获取每月的平均HRV
        result.hrv = try await fetchMonthlyAverages(
            .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            startDate: startDate,
            endDate: endDate,
            months: 12
        )
        
        // 获取每月的睡眠时长
        result.sleep = try await fetchMonthlySleepHours(
            startDate: startDate,
            endDate: endDate,
            months: 12
        )
        
        return result
    }
    
    // MARK: - Helper methods for statistics
    /// 获取指定时间段内每天的平均值
    private func fetchDailyAverages(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date,
        days: Int
    ) async throws -> [Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }
        
        let calendar = Calendar.current
        var results: [Double] = []
        
        for dayOffset in 0..<days {
            guard let dayStart = calendar.date(byAdding: .day, value: -days + dayOffset, to: endDate),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                results.append(0)
                continue
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            
            let average = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Double, Error>) in
                let query = HKStatisticsQuery(
                    quantityType: quantityType,
                    quantitySamplePredicate: predicate,
                    options: .discreteAverage
                ) { _, statistics, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    
                    let avg = statistics?.averageQuantity()?.doubleValue(for: unit) ?? 0
                    cont.resume(returning: avg)
                }
                
                healthStore.execute(query)
            }
            
            results.append(average)
        }
        
        return results
    }
    
    /// 获取指定时间段内每月的平均值
    private func fetchMonthlyAverages(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date,
        months: Int
    ) async throws -> [Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }
        
        let calendar = Calendar.current
        var results: [Double] = []
        
        for monthOffset in 0..<months {
            guard let monthStart = calendar.date(byAdding: .month, value: -months + monthOffset, to: endDate),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                results.append(0)
                continue
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: monthStart, end: monthEnd, options: .strictStartDate)
            
            let average = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Double, Error>) in
                let query = HKStatisticsQuery(
                    quantityType: quantityType,
                    quantitySamplePredicate: predicate,
                    options: .discreteAverage
                ) { _, statistics, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    
                    let avg = statistics?.averageQuantity()?.doubleValue(for: unit) ?? 0
                    cont.resume(returning: avg)
                }
                
                healthStore.execute(query)
            }
            
            results.append(average)
        }
        
        return results
    }
    
    /// 获取指定时间段内每天的睡眠时长
    private func fetchDailySleepHours(
        startDate: Date,
        endDate: Date,
        days: Int
    ) async throws -> [Double] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }
        
        let calendar = Calendar.current
        var results: [Double] = []
        
        for dayOffset in 0..<days {
            guard let dayStart = calendar.date(byAdding: .day, value: -days + dayOffset, to: endDate),
                  let _ = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                results.append(0)
                continue
            }
            
            // 使用 18:00 作为一天的开始
            let sleepDayStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayStart)!
            let sleepDayEnd = calendar.date(byAdding: .day, value: 1, to: sleepDayStart)!
            
            let predicate = HKQuery.predicateForSamples(withStart: sleepDayStart, end: sleepDayEnd, options: [])
            
            let sleepHours = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Double, Error>) in
                let query = HKSampleQuery(
                    sampleType: sleepType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    
                    guard let sleepSamples = samples as? [HKCategorySample] else {
                        cont.resume(returning: 0)
                        return
                    }
                    
                    // 计算实际睡眠时间（不包括清醒时间）
                    var totalSeconds: TimeInterval = 0
                    let sleepStageValues: Set<Int>
                    if #available(iOS 16.0, *) {
                        sleepStageValues = [
                            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                            HKCategoryValueSleepAnalysis.asleepREM.rawValue
                        ]
                    } else {
                        sleepStageValues = [HKCategoryValueSleepAnalysis.asleep.rawValue]
                    }
                    
                    for sample in sleepSamples {
                        if sleepStageValues.contains(sample.value) {
                            totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                        }
                    }
                    
                    cont.resume(returning: totalSeconds / 3600.0)
                }
                
                healthStore.execute(query)
            }
            
            results.append(sleepHours)
        }
        
        return results
    }
    
    /// 获取指定时间段内每月的睡眠时长
    private func fetchMonthlySleepHours(
        startDate: Date,
        endDate: Date,
        months: Int
    ) async throws -> [Double] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }
        
        let calendar = Calendar.current
        var results: [Double] = []
        
        for monthOffset in 0..<months {
            guard let monthStart = calendar.date(byAdding: .month, value: -months + monthOffset, to: endDate),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                results.append(0)
                continue
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: monthStart, end: monthEnd, options: [])
            
            let avgSleepHours = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Double, Error>) in
                let query = HKSampleQuery(
                    sampleType: sleepType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    
                    guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                        cont.resume(returning: 0)
                        return
                    }
                    
                    // 按天分组并计算每天的睡眠时间，然后求平均
                    var dailySleepHours: [String: TimeInterval] = [:]
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    let sleepStageValues: Set<Int>
                    if #available(iOS 16.0, *) {
                        sleepStageValues = [
                            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                            HKCategoryValueSleepAnalysis.asleepREM.rawValue
                        ]
                    } else {
                        sleepStageValues = [HKCategoryValueSleepAnalysis.asleep.rawValue]
                    }
                    
                    for sample in sleepSamples {
                        if sleepStageValues.contains(sample.value) {
                            let dateKey = dateFormatter.string(from: sample.startDate)
                            let duration = sample.endDate.timeIntervalSince(sample.startDate)
                            dailySleepHours[dateKey, default: 0] += duration
                        }
                    }
                    
                    // 计算平均睡眠时长
                    let totalHours = dailySleepHours.values.reduce(0, +) / 3600.0
                    let avgHours = dailySleepHours.isEmpty ? 0 : totalHours / Double(dailySleepHours.count)
                    
                    cont.resume(returning: avgHours)
                }
                
                healthStore.execute(query)
            }
            
            results.append(avgSleepHours)
        }
        
        return results
    }
}
