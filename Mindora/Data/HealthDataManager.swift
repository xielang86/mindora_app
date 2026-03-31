import Foundation
import HealthKit

final class HealthDataManager {
    static let shared = HealthDataManager()
    let healthStore = HKHealthStore()

    private init() {}

    enum HealthError: Error {
        case notAvailable
        case authorizationDenied
    }

    // MARK: - Authorization
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.notAvailable }

        var readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        if #available(iOS 16.0, *), let sleepingWristTemperature = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
            readTypes.insert(sleepingWristTemperature)
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if let error = error { cont.resume(throwing: error); return }
                if success { cont.resume(); } else { cont.resume(throwing: HealthError.authorizationDenied) }
            }
        }
    }

    // MARK: - Public fetch
    /// - Parameter forceLive: 当为 true 时跳过 debug mock 数据，直接从 HealthKit 获取真实数据
    func fetchLatestMetrics(forceLive: Bool = false) async throws -> HealthMetrics {
        // Debug 模式：返回虚假数据用于测试
        if !forceLive && DesignConstants.isDebugMode {
            let now = Date()
            let debugSleepSummary = HealthMetrics.SleepValue(
                totalSleepHours: DesignConstants.DebugHealthData.totalSleepHours,
                deepSleepHours: nil,
                remSleepHours: nil,
                lightSleepHours: nil,
                timeInBed: DesignConstants.DebugHealthData.timeInBed,
                date: now
            )
            
            let debugHR = HealthMetrics.MetricValue(
                value: DesignConstants.DebugHealthData.heartRate,
                date: now
            )
            
            let debugHRV = HealthMetrics.MetricValue(
                value: DesignConstants.DebugHealthData.heartRateVariability,
                date: now
            )
            
            return HealthMetrics(
                heartRate: debugHR,
                heartRateVariability: debugHRV,
                respiratoryRate: nil,
                restingHeartRate: nil,
                sleepingWristTemperature: nil,
                bodyTemperature: nil,
                sleepSummary: debugSleepSummary,
                lastUpdated: now
            )
        }
        
        // 正常模式：从 HealthKit 获取真实数据
        async let hr = fetchLatestQuantity(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let hrv = fetchLatestQuantity(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli))
        async let respiratory = fetchLatestQuantity(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let restingHeartRate = fetchLatestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let bodyTemperature = fetchLatestQuantity(.bodyTemperature, unit: .degreeCelsius())
        async let sleep = fetchSleepSummary()

        let hrResult = try await hr
        let hrvResult = try await hrv
        let respiratoryResult = try await respiratory
        let restingHeartRateResult = try await restingHeartRate
        let bodyTemperatureResult = try await bodyTemperature
        let sleepResult = try await sleep

        let sleepingWristTemperatureResult: (value: Double?, date: Date?)
        if #available(iOS 16.0, *) {
            sleepingWristTemperatureResult = try await fetchLatestQuantity(.appleSleepingWristTemperature, unit: .degreeCelsius())
        } else {
            sleepingWristTemperatureResult = (nil, nil)
        }
        
        // 转换为 MetricValue 结构
        let hrMetric: HealthMetrics.MetricValue?
        if let value = hrResult.value, let date = hrResult.date {
            hrMetric = HealthMetrics.MetricValue(value: value, date: date)
        } else {
            hrMetric = nil
        }
        
        let hrvMetric: HealthMetrics.MetricValue?
        if let value = hrvResult.value, let date = hrvResult.date {
            hrvMetric = HealthMetrics.MetricValue(value: value, date: date)
        } else {
            hrvMetric = nil
        }

        let respiratoryMetric: HealthMetrics.MetricValue?
        if let value = respiratoryResult.value, let date = respiratoryResult.date {
            respiratoryMetric = HealthMetrics.MetricValue(value: value, date: date)
        } else {
            respiratoryMetric = nil
        }

        let restingHeartRateMetric: HealthMetrics.MetricValue?
        if let value = restingHeartRateResult.value, let date = restingHeartRateResult.date {
            restingHeartRateMetric = HealthMetrics.MetricValue(value: value, date: date)
        } else {
            restingHeartRateMetric = nil
        }

        let sleepingWristTemperatureMetric: HealthMetrics.MetricValue?
        if let value = sleepingWristTemperatureResult.value, let date = sleepingWristTemperatureResult.date {
            sleepingWristTemperatureMetric = HealthMetrics.MetricValue(value: value, date: date)
        } else {
            sleepingWristTemperatureMetric = nil
        }

        let bodyTemperatureMetric: HealthMetrics.MetricValue?
        if let value = bodyTemperatureResult.value, let date = bodyTemperatureResult.date {
            bodyTemperatureMetric = HealthMetrics.MetricValue(value: value, date: date)
        } else {
            bodyTemperatureMetric = nil
        }
        
        // 计算最后更新时间：取所有数据中最新的时间
        let dates = [
            hrResult.date,
            hrvResult.date,
            respiratoryResult.date,
            restingHeartRateResult.date,
            sleepingWristTemperatureResult.date,
            bodyTemperatureResult.date,
            sleepResult?.date
        ].compactMap { $0 }
        let latestDate = dates.max()
        
        let metrics = HealthMetrics(
            heartRate: hrMetric,
            heartRateVariability: hrvMetric,
            respiratoryRate: respiratoryMetric,
            restingHeartRate: restingHeartRateMetric,
            sleepingWristTemperature: sleepingWristTemperatureMetric,
            bodyTemperature: bodyTemperatureMetric,
            sleepSummary: sleepResult,
            lastUpdated: latestDate
        )
        return metrics
    }

    // MARK: - Series (bulk) fetch for uploading

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
        async let respiratorySamples = fetchSeries(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), predicate: predicate, limit: maxSamples)
        async let restingHeartRateSamples = fetchSeries(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), predicate: predicate, limit: maxSamples)
        async let bodyTemperatureSamples = fetchSeries(.bodyTemperature, unit: .degreeCelsius(), predicate: predicate, limit: maxSamples)

        result.heartRate = try await hrSamples
        result.hrv = try await hrvSamples
        result.respiratoryRate = try await respiratorySamples
        result.restingHeartRate = try await restingHeartRateSamples
        result.bodyTemperature = try await bodyTemperatureSamples

        if #available(iOS 16.0, *) {
            result.sleepingWristTemperature = try await fetchSeries(.appleSleepingWristTemperature, unit: .degreeCelsius(), predicate: predicate, limit: maxSamples)
        }

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
    private func fetchLatestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> (value: Double?, date: Date?) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return (nil, nil) }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(value: Double?, date: Date?), Error>) in
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
                guard let quantitySample = samples?.first as? HKQuantitySample else { cont.resume(returning: (nil, nil)); return }
                let value = quantitySample.quantity.doubleValue(for: unit)
                cont.resume(returning: (value, quantitySample.endDate))
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Debug Mode Helpers
    
    /// Debug 模式下的数据有效期限制（天数）
    /// 只能查看最近这么多天的数据，超出范围返回空数据
    /// 3年 = 365 * 3 = 1095 天
    private static let debugDataMaxDaysBack: Int = 1095
    
    /// 检查 anchorDate 是否在 debug 数据的有效范围内
    /// - Parameter anchorDate: 锚点日期
    /// - Returns: 是否在有效范围内
    private func isDebugDataAvailable(for anchorDate: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let anchor = calendar.startOfDay(for: anchorDate)
        
        // 不能查看未来的数据
        if anchor > today { return false }
        
        // 计算距今天数
        guard let daysDiff = calendar.dateComponents([.day], from: anchor, to: today).day else {
            return false
        }
        
        // 超过最大天数限制则无数据
        return daysDiff <= Self.debugDataMaxDaysBack
    }
    
    /// 根据 anchorDate 生成可重复的随机种子
    /// 确保同一日期生成的数据是一致的
    private func debugRandomSeed(for anchorDate: Date) -> UInt64 {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: anchorDate)
        let year = UInt64(components.year ?? 2025)
        let month = UInt64(components.month ?? 1)
        let day = UInt64(components.day ?? 1)
        return year * 10000 + month * 100 + day
    }
    
    /// 使用种子生成伪随机数（简单的 LCG 算法）
    private func seededRandom(seed: inout UInt64, min: Double, max: Double) -> Double {
        seed = (seed &* 6364136223846793005) &+ 1442695040888963407
        let normalized = Double(seed % 10000) / 10000.0
        return min + normalized * (max - min)
    }
    
    /// 生成 debug 模式下基于日期的心率范围数据
    private func generateDebugHeartRateRange(for anchorDate: Date, count: Int) -> [HeartRateRangePoint] {
        var seed = debugRandomSeed(for: anchorDate)
        return (0..<count).map { index in
            // 约 15% 的概率没有数据
            let hasData = seededRandom(seed: &seed, min: 0, max: 1) > 0.15
            if !hasData { return HeartRateRangePoint.empty }
            
            let minHR = seededRandom(seed: &seed, min: 50, max: 70)
            let maxHR = seededRandom(seed: &seed, min: 85, max: 130)
            return HeartRateRangePoint(min: minHR, max: maxHR)
        }
    }
    
    /// 生成 debug 模式下基于日期的 HRV 数据
    private func generateDebugHRV(for anchorDate: Date, count: Int) -> [Double] {
        var seed = debugRandomSeed(for: anchorDate) + 1000 // 偏移种子，确保与心率数据不同
        return (0..<count).map { _ in
            seededRandom(seed: &seed, min: 15, max: 45)
        }
    }
    
    /// 生成 debug 模式下基于日期的睡眠范围数据
    private func generateDebugSleepRange(for anchorDate: Date, count: Int) -> [SleepRangePoint] {
        var seed = debugRandomSeed(for: anchorDate) + 2000
        return (0..<count).map { index in
            // 约 15% 的概率没有数据
            let hasData = seededRandom(seed: &seed, min: 0, max: 1) > 0.15
            if !hasData { return SleepRangePoint.empty }
            
            // 卧床开始：22:00-00:00 (120-240分钟，相对于20:00)
            let bedStart = seededRandom(seed: &seed, min: 120, max: 240)
            // 入睡时间：卧床后15-45分钟
            let sleepStart = bedStart + seededRandom(seed: &seed, min: 15, max: 45)
            // 睡眠时长：5-9小时
            let sleepDuration = seededRandom(seed: &seed, min: 300, max: 540)
            let sleepEnd = sleepStart + sleepDuration
            // 起床时间：醒后5-20分钟
            let bedEnd = sleepEnd + seededRandom(seed: &seed, min: 5, max: 20)
            
            return SleepRangePoint(
                bedStartMinutes: bedStart,
                bedEndMinutes: bedEnd,
                sleepStartMinutes: sleepStart,
                sleepEndMinutes: sleepEnd
            )
        }
    }
    
    // MARK: - Monthly & Yearly Data
    
    /// 获取月度数据（最近30天，以 anchorDate 结尾）
    /// - Parameter anchorDate: 作为时间窗口结束的日期（默认为当前时间）
    func fetchMonthlyData(anchorDate: Date = Date()) async throws -> PeriodHealthData {
        // Debug 模式：返回基于 anchorDate 的模拟数据
        if DesignConstants.isDebugMode {
            // 检查日期是否在有效范围内
            guard isDebugDataAvailable(for: anchorDate) else {
                // 超出范围，返回空数据
                return PeriodHealthData()
            }
            
            // 生成基于 anchorDate 的随机数据
            let heartRateRange = generateDebugHeartRateRange(for: anchorDate, count: 30)
            let hrvData = generateDebugHRV(for: anchorDate, count: 30)
            let sleepRange = generateDebugSleepRange(for: anchorDate, count: 30)
            
            // 从心率范围数据生成普通心率数据（取平均值）
            let heartRate = heartRateRange.map { $0.isValid ? ($0.min + $0.max) / 2 : 0 }
            // 从睡眠范围数据生成普通睡眠数据（睡眠时长，单位：小时）
            let sleep = sleepRange.map { $0.isValid ? ($0.sleepEndMinutes - $0.sleepStartMinutes) / 60.0 : 0 }
            
            return PeriodHealthData(
                heartRate: heartRate,
                heartRateRange: heartRateRange,
                hrv: hrvData,
                sleep: sleep,
                sleepRange: sleepRange
            )
        }
        
        // 真实模式：从 HealthKit 获取最近30天的平均数据
        let calendar = Calendar.current
        // 以 anchorDate 当天 23:59:59 作为窗口结束，向前取30天
        let endOfAnchorDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: anchorDate))!
        let startDate = calendar.date(byAdding: .day, value: -30, to: endOfAnchorDay)!
        
        var result = PeriodHealthData()
        
        // 获取每天的平均心率
        result.heartRate = try await fetchDailyAverages(
            .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            startDate: startDate,
            endDate: endOfAnchorDay,
            days: 30
        )
        
        // 获取每天的心率范围（最小/最大值）
        result.heartRateRange = try await fetchDailyHeartRateRanges(
            startDate: startDate,
            endDate: endOfAnchorDay,
            days: 30
        )
        
        // 获取每天的平均HRV
        result.hrv = try await fetchDailyAverages(
            .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            startDate: startDate,
            endDate: endOfAnchorDay,
            days: 30
        )
        
        // 获取每天的睡眠时长
        result.sleep = try await fetchDailySleepHours(
            startDate: startDate,
            endDate: endOfAnchorDay,
            days: 30
        )
        
        return result
    }
    
    /// 获取年度数据（最近12个月，以 anchorDate 所在月结尾）
    /// - Parameter anchorDate: 作为时间窗口结束的日期（默认为当前时间）
    func fetchYearlyData(anchorDate: Date = Date()) async throws -> PeriodHealthData {
        // Debug 模式：返回基于 anchorDate 的模拟数据
        if DesignConstants.isDebugMode {
            // 检查日期是否在有效范围内
            guard isDebugDataAvailable(for: anchorDate) else {
                // 超出范围，返回空数据
                return PeriodHealthData()
            }
            
            // 年度数据用不同的种子偏移，避免与月度数据相同
            var seed = debugRandomSeed(for: anchorDate) + 5000
            
            // 生成12个月的数据
            let heartRateRange = (0..<12).map { _ -> HeartRateRangePoint in
                let hasData = seededRandom(seed: &seed, min: 0, max: 1) > 0.1
                if !hasData { return HeartRateRangePoint.empty }
                let minHR = seededRandom(seed: &seed, min: 48, max: 65)
                let maxHR = seededRandom(seed: &seed, min: 90, max: 140)
                return HeartRateRangePoint(min: minHR, max: maxHR)
            }
            
            let hrvData = (0..<12).map { _ -> Double in
                seededRandom(seed: &seed, min: 18, max: 42)
            }
            
            let sleepRange = (0..<12).map { _ -> SleepRangePoint in
                let hasData = seededRandom(seed: &seed, min: 0, max: 1) > 0.1
                if !hasData { return SleepRangePoint.empty }
                let bedStart = seededRandom(seed: &seed, min: 120, max: 240)
                let sleepStart = bedStart + seededRandom(seed: &seed, min: 15, max: 45)
                let sleepDuration = seededRandom(seed: &seed, min: 300, max: 540)
                let sleepEnd = sleepStart + sleepDuration
                let bedEnd = sleepEnd + seededRandom(seed: &seed, min: 5, max: 20)
                return SleepRangePoint(
                    bedStartMinutes: bedStart, bedEndMinutes: bedEnd,
                    sleepStartMinutes: sleepStart, sleepEndMinutes: sleepEnd
                )
            }
            
            let heartRate = heartRateRange.map { $0.isValid ? ($0.min + $0.max) / 2 : 0 }
            let sleep = sleepRange.map { $0.isValid ? ($0.sleepEndMinutes - $0.sleepStartMinutes) / 60.0 : 0 }
            
            return PeriodHealthData(
                heartRate: heartRate,
                heartRateRange: heartRateRange,
                hrv: hrvData,
                sleep: sleep,
                sleepRange: sleepRange
            )
        }
        
        // 真实模式：从 HealthKit 获取最近12个月的平均数据
        let calendar = Calendar.current
        // 以 anchorDate 所在月的月末为窗口结束，向前取12个月
        let endOfAnchorMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: anchorDate)) ?? anchorDate
        let endDate = calendar.date(byAdding: .month, value: 1, to: endOfAnchorMonthStart) ?? anchorDate
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
        
        // 获取每月的心率范围（最小/最大值）
        result.heartRateRange = try await fetchMonthlyHeartRateRanges(
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
    
    /// 获取周数据（最近7天，以 anchorDate 结尾）
    /// - Parameter anchorDate: 作为时间窗口结束的日期（默认为当前时间）
    func fetchWeeklyData(anchorDate: Date = Date()) async throws -> PeriodHealthData {
        // Debug 模式：返回基于 anchorDate 的模拟数据
        if DesignConstants.isDebugMode {
            // 检查日期是否在有效范围内
            guard isDebugDataAvailable(for: anchorDate) else {
                return PeriodHealthData()
            }
            
            // 周数据用不同的种子偏移
            var seed = debugRandomSeed(for: anchorDate) + 3000
            
            // 生成7天的数据
            let heartRateRange = (0..<7).map { _ -> HeartRateRangePoint in
                let hasData = seededRandom(seed: &seed, min: 0, max: 1) > 0.12
                if !hasData { return HeartRateRangePoint.empty }
                let minHR = seededRandom(seed: &seed, min: 52, max: 68)
                let maxHR = seededRandom(seed: &seed, min: 85, max: 125)
                return HeartRateRangePoint(min: minHR, max: maxHR)
            }
            
            let hrvData = (0..<7).map { _ -> Double in
                seededRandom(seed: &seed, min: 18, max: 45)
            }
            
            let sleepRange = (0..<7).map { _ -> SleepRangePoint in
                let hasData = seededRandom(seed: &seed, min: 0, max: 1) > 0.12
                if !hasData { return SleepRangePoint.empty }
                let bedStart = seededRandom(seed: &seed, min: 120, max: 240)
                let sleepStart = bedStart + seededRandom(seed: &seed, min: 15, max: 45)
                let sleepDuration = seededRandom(seed: &seed, min: 300, max: 540)
                let sleepEnd = sleepStart + sleepDuration
                let bedEnd = sleepEnd + seededRandom(seed: &seed, min: 5, max: 20)
                return SleepRangePoint(
                    bedStartMinutes: bedStart, bedEndMinutes: bedEnd,
                    sleepStartMinutes: sleepStart, sleepEndMinutes: sleepEnd
                )
            }
            
            let heartRate = heartRateRange.map { $0.isValid ? ($0.min + $0.max) / 2 : 0 }
            let sleep = sleepRange.map { $0.isValid ? ($0.sleepEndMinutes - $0.sleepStartMinutes) / 60.0 : 0 }
            
            return PeriodHealthData(
                heartRate: heartRate,
                heartRateRange: heartRateRange,
                hrv: hrvData,
                sleep: sleep,
                sleepRange: sleepRange
            )
        }
        
        // 真实模式：从 HealthKit 获取最近7天的数据（从今天往前推7天）
        let calendar = Calendar.current
        let anchorStart = calendar.startOfDay(for: anchorDate)
        // 往前推7天（包含 anchor 当天）
        let startDate = calendar.date(byAdding: .day, value: -6, to: anchorStart)!
        let endDate = calendar.date(byAdding: .day, value: 1, to: anchorStart)!
        
        var result = PeriodHealthData()
        
        // 获取每天的平均心率
        result.heartRate = try await fetchDailyAverages(
            .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            startDate: startDate,
            endDate: endDate,
            days: 7
        )
        
        // 获取每天的心率范围（最小/最大值）
        result.heartRateRange = try await fetchDailyHeartRateRanges(
            startDate: startDate,
            endDate: endDate,
            days: 7
        )
        
        // 获取每天的平均HRV
        result.hrv = try await fetchDailyAverages(
            .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            startDate: startDate,
            endDate: endDate,
            days: 7
        )
        
        // 获取每天的睡眠时长
        result.sleep = try await fetchDailySleepHours(
            startDate: startDate,
            endDate: endDate,
            days: 7
        )
        
        return result
    }
    
    /// 获取日数据（指定日期0-23时，每小时一个数据点）
    /// X轴固定显示0-23时，若 anchorDate 为今天，未来时间为0
    /// - Parameter anchorDate: 作为时间窗口结束的日期（默认为当前时间）
    func fetchDailyData(anchorDate: Date = Date()) async throws -> PeriodHealthData {
        // Debug 模式：返回基于 anchorDate 的模拟数据
        if DesignConstants.isDebugMode {
            // 检查日期是否在有效范围内
            guard isDebugDataAvailable(for: anchorDate) else {
                return PeriodHealthData()
            }
            
            let calendar = Calendar.current
            let isToday = calendar.isDateInToday(anchorDate)
            let currentHour = isToday ? calendar.component(.hour, from: Date()) : 23
            
            // 日数据用不同的种子偏移
            var seed = debugRandomSeed(for: anchorDate) + 4000
            
            // 生成24小时的数据
            let hourlyHeartRateRange = (0..<24).map { hour -> HeartRateRangePoint in
                // 今天的未来时间没有数据
                if isToday && hour > currentHour { return HeartRateRangePoint.empty }
                
                // 约 20% 概率没有数据
                let hasData = seededRandom(seed: &seed, min: 0, max: 1) > 0.2
                if !hasData { return HeartRateRangePoint.empty }
                
                let minHR = seededRandom(seed: &seed, min: 55, max: 72)
                let maxHR = seededRandom(seed: &seed, min: 80, max: 120)
                return HeartRateRangePoint(min: minHR, max: maxHR)
            }
            
            let hourlyHRV = (0..<24).map { hour -> Double in
                if isToday && hour > currentHour { return 0 }
                return seededRandom(seed: &seed, min: 20, max: 75)
            }
            
            // 睡眠范围数据（单条数据，表示昨晚的睡眠）
            let bedStart = seededRandom(seed: &seed, min: 120, max: 200)
            let sleepStart = bedStart + seededRandom(seed: &seed, min: 15, max: 40)
            let sleepDuration = seededRandom(seed: &seed, min: 330, max: 510)
            let sleepEnd = sleepStart + sleepDuration
            let bedEnd = sleepEnd + seededRandom(seed: &seed, min: 5, max: 15)
            let sleepRange = [SleepRangePoint(
                bedStartMinutes: bedStart,
                bedEndMinutes: bedEnd,
                sleepStartMinutes: sleepStart,
                sleepEndMinutes: sleepEnd
            )]
            
            let heartRate = hourlyHeartRateRange.map { $0.isValid ? ($0.min + $0.max) / 2 : 0 }
            // 每小时睡眠数据（0-6点睡眠）
            let hourlySleep = (0..<24).map { hour -> Double in
                if isToday && hour > currentHour { return 0 }
                if hour >= 0 && hour < 7 {
                    return seededRandom(seed: &seed, min: 0.7, max: 1.0)
                }
                return 0
            }
            
            return PeriodHealthData(
                heartRate: heartRate,
                heartRateRange: hourlyHeartRateRange,
                hrv: hourlyHRV,
                sleep: hourlySleep,
                sleepRange: sleepRange
            )
        }
        
        // 真实模式：从 HealthKit 获取今天0-23时的数据（每小时一个数据点）
        // X轴固定显示0-23时，未来时间的数据将为0
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: anchorDate)
        let isToday = calendar.isDateInToday(anchorDate)

        // 获取 anchorDate 当天0时作为起始时间
        let startOfDay = calendar.startOfDay(for: anchorDate)
        
        var result = PeriodHealthData()
        
        // 获取每小时的平均心率（0-23时，但只有到当前小时有数据）
        if isToday {
            result.heartRate = try await fetchHourlyAveragesForToday(
                .heartRate,
                unit: HKUnit.count().unitDivided(by: .minute()),
                startDate: startOfDay,
                currentHour: currentHour
            )
        } else {
            result.heartRate = try await fetchHourlyAverages(
                .heartRate,
                unit: HKUnit.count().unitDivided(by: .minute()),
                startDate: startOfDay,
                hours: 24
            )
        }
        
        // 获取每小时的心率范围（最小/最大值）
        if isToday {
            result.heartRateRange = try await fetchHourlyHeartRateRangesForToday(
                startDate: startOfDay,
                currentHour: currentHour
            )
        } else {
            result.heartRateRange = try await fetchHourlyHeartRateRanges(
                startDate: startOfDay,
                hours: 24
            )
        }
        
        // 获取每小时的平均HRV
        if isToday {
            result.hrv = try await fetchHourlyAveragesForToday(
                .heartRateVariabilitySDNN,
                unit: HKUnit.secondUnit(with: .milli),
                startDate: startOfDay,
                currentHour: currentHour
            )
        } else {
            result.hrv = try await fetchHourlyAverages(
                .heartRateVariabilitySDNN,
                unit: HKUnit.secondUnit(with: .milli),
                startDate: startOfDay,
                hours: 24
            )
        }
        
        // 获取每小时的睡眠时长（小时内睡眠的分钟数/60）
        if isToday {
            result.sleep = try await fetchHourlySleepHoursForToday(
                startDate: startOfDay,
                currentHour: currentHour
            )
        } else {
            result.sleep = try await fetchHourlySleepHours(
                startDate: startOfDay,
                hours: 24
            )
        }
        
        return result
    }
    
    /// 获取6个月数据（按周聚合，周日到周六为一个周期，以 anchorDate 所在周为末尾）
    /// - Parameter anchorDate: 作为时间窗口结束的日期（默认为当前时间）
    func fetchSixMonthsData(anchorDate: Date = Date()) async throws -> PeriodHealthData {
        // Debug 模式：返回基于 anchorDate 的模拟数据
        if DesignConstants.isDebugMode {
            // 检查日期是否在有效范围内
            guard isDebugDataAvailable(for: anchorDate) else {
                return PeriodHealthData()
            }
            
            // 6个月数据用不同的种子偏移
            var seed = debugRandomSeed(for: anchorDate) + 6000
            
            // 生成约26周的数据
            let weeklyHeartRateRange = (0..<26).map { _ -> HeartRateRangePoint in
                let hasData = seededRandom(seed: &seed, min: 0, max: 1) > 0.12
                if !hasData { return HeartRateRangePoint.empty }
                let minHR = seededRandom(seed: &seed, min: 48, max: 65)
                let maxHR = seededRandom(seed: &seed, min: 92, max: 135)
                return HeartRateRangePoint(min: minHR, max: maxHR)
            }
            
            let weeklyHRV = (0..<26).map { _ -> Double in
                seededRandom(seed: &seed, min: 25, max: 55)
            }
            
            let sleepRange = (0..<26).map { _ -> SleepRangePoint in
                let hasData = seededRandom(seed: &seed, min: 0, max: 1) > 0.12
                if !hasData { return SleepRangePoint.empty }
                let bedStart = seededRandom(seed: &seed, min: 120, max: 240)
                let sleepStart = bedStart + seededRandom(seed: &seed, min: 15, max: 45)
                let sleepDuration = seededRandom(seed: &seed, min: 300, max: 540)
                let sleepEnd = sleepStart + sleepDuration
                let bedEnd = sleepEnd + seededRandom(seed: &seed, min: 5, max: 20)
                return SleepRangePoint(
                    bedStartMinutes: bedStart, bedEndMinutes: bedEnd,
                    sleepStartMinutes: sleepStart, sleepEndMinutes: sleepEnd
                )
            }
            
            let weeklyHeartRate = weeklyHeartRateRange.map { $0.isValid ? ($0.min + $0.max) / 2 : 0 }
            let weeklySleep = sleepRange.map { $0.isValid ? ($0.sleepEndMinutes - $0.sleepStartMinutes) / 60.0 : 0 }
            
            return PeriodHealthData(
                heartRate: weeklyHeartRate,
                heartRateRange: weeklyHeartRateRange,
                hrv: weeklyHRV,
                sleep: weeklySleep,
                sleepRange: sleepRange
            )
        }
        
        // 真实模式：从 HealthKit 获取最近6个月的周平均数据
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchorDate)

        // 找到 anchor 所在周的周六结束（次日0点）
        let weekday = calendar.component(.weekday, from: anchorDay)
        let daysUntilSaturday = (7 - weekday + 7) % 7
        let currentWeekEnd = calendar.date(byAdding: .day, value: daysUntilSaturday + 1, to: anchorDay)!

        // 往前推6个月
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: anchorDay)!

        // 找到6个月前那周的周日开始时间
        let sixMonthsAgoWeekday = calendar.component(.weekday, from: sixMonthsAgo)
        let daysToSunday = (sixMonthsAgoWeekday - 1 + 7) % 7
        let startSunday = calendar.date(byAdding: .day, value: -daysToSunday, to: calendar.startOfDay(for: sixMonthsAgo))!
        
        // 计算周数
        let weeks = calendar.dateComponents([.weekOfYear], from: startSunday, to: currentWeekEnd).weekOfYear ?? 26
        
        var result = PeriodHealthData()
        
        // 获取每周的平均心率（周日到周六）
        result.heartRate = try await fetchWeeklyAveragesSundayToSaturday(
            .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            startSunday: startSunday,
            weeks: weeks
        )
        
        // 获取每周的心率范围（最小/最大值）
        result.heartRateRange = try await fetchWeeklyHeartRateRangesSundayToSaturday(
            startSunday: startSunday,
            weeks: weeks
        )
        
        // 获取每周的平均HRV
        result.hrv = try await fetchWeeklyAveragesSundayToSaturday(
            .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            startSunday: startSunday,
            weeks: weeks
        )
        
        // 获取每周的睡眠时长
        result.sleep = try await fetchWeeklySleepHoursSundayToSaturday(
            startSunday: startSunday,
            weeks: weeks
        )
        
        return result
    }
    
    // MARK: - Helper methods for statistics
    
    /// 获取今天0-23时每小时的平均值（用于日视图）
    /// 只获取到当前小时的数据，未来时间返回0
    private func fetchHourlyAveragesForToday(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        currentHour: Int
    ) async throws -> [Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return Array(repeating: 0, count: 24)
        }
        
        let calendar = Calendar.current
        var results: [Double] = []
        
        for hour in 0..<24 {
            // 未来的小时返回0
            if hour > currentHour {
                results.append(0)
                continue
            }
            
            guard let hourStart = calendar.date(byAdding: .hour, value: hour, to: startDate),
                  let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else {
                results.append(0)
                continue
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: hourStart, end: hourEnd, options: .strictStartDate)
            
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
                
                self.healthStore.execute(query)
            }
            
            results.append(average)
        }
        
        return results
    }
    
    /// 获取每小时的平均值（用于日视图，24小时数据）
    private func fetchHourlyAverages(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        hours: Int
    ) async throws -> [Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }
        
        let calendar = Calendar.current
        var results: [Double] = []
        
        for hourOffset in 0..<hours {
            guard let hourStart = calendar.date(byAdding: .hour, value: hourOffset, to: startDate),
                  let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else {
                results.append(0)
                continue
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: hourStart, end: hourEnd, options: .strictStartDate)
            
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
                
                self.healthStore.execute(query)
            }
            
            results.append(average)
        }
        
        return results
    }
    
    /// 获取每周的平均值（周日到周六为一个周期，用于6个月视图）
    private func fetchWeeklyAveragesSundayToSaturday(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startSunday: Date,
        weeks: Int
    ) async throws -> [Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }
        
        let calendar = Calendar.current
        var results: [Double] = []
        
        for weekOffset in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .day, value: weekOffset * 7, to: startSunday),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                results.append(0)
                continue
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: weekStart, end: weekEnd, options: .strictStartDate)
            
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
                
                self.healthStore.execute(query)
            }
            
            results.append(average)
        }
        
        return results
    }
    
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
    
    /// 获取指定时间段内每周的平均值
    private func fetchWeeklyAverages(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date,
        weeks: Int
    ) async throws -> [Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }
        
        let calendar = Calendar.current
        var results: [Double] = []
        
        for weekOffset in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeks + weekOffset, to: endDate),
                  let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else {
                results.append(0)
                continue
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: weekStart, end: weekEnd, options: .strictStartDate)
            
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
}
