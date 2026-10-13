import Foundation
import HealthKit

extension HealthDataManager {

    // MARK: - Sleep Heart Rate

    /// 睡眠期间的心率区间（min–max），对应苹果健康「睡眠 → 比较 → 心率」那一栏。
    ///
    /// 取的是**最近一晚实际入睡到醒来的跨度**，不是整个 6pm–6pm 睡眠日窗口 ——
    /// 后者会把白天清醒时的心率也算进来，区间会被拉得毫无意义。
    func fetchSleepHeartRateRange(forceLive: Bool = false) async throws -> HeartRateRangePoint {
        if HealthDataSimulator.shared.isEnabled {
            return HealthDataSimulator.shared.sleepHeartRateRange()
        }
        guard let span = try await fetchMostRecentSleepSessionSpan() else { return .empty }
        return try await fetchHeartRateRange(start: span.start, end: span.end)
    }

    /// 指定区间内的心率 min–max。区间内无样本返回 `.empty`。
    func fetchHeartRateRange(start: Date, end: Date) async throws -> HeartRateRangePoint {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate), end > start else {
            return .empty
        }
        let unit = HKUnit.count().unitDivided(by: .minute())
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HeartRateRangePoint, Error>) in
            #if swift(>=5.7)
            let predicateSendable = _SendablePredicate(value: HKQuery.predicateForSamples(withStart: start, end: end, options: []))
            #else
            let predicateSendable = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            #endif
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicateSendable.value,
                options: [.discreteMin, .discreteMax]
            ) { _, statistics, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let minValue = statistics?.minimumQuantity()?.doubleValue(for: unit),
                      let maxValue = statistics?.maximumQuantity()?.doubleValue(for: unit) else {
                    cont.resume(returning: .empty)
                    return
                }
                cont.resume(returning: HeartRateRangePoint(min: minValue, max: maxValue))
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Heart Rate Range Data

    /// 获取每天的心率范围（最小/最大值）
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    ///   - days: 天数
    /// - Returns: 心率范围数据数组
    func fetchDailyHeartRateRanges(
        startDate: Date,
        endDate: Date,
        days: Int
    ) async throws -> [HeartRateRangePoint] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return Array(repeating: HeartRateRangePoint.empty, count: days)
        }
        
        let calendar = Calendar.current
        let unit = HKUnit.count().unitDivided(by: .minute())
        var results: [HeartRateRangePoint] = []
        
        for dayOffset in 0..<days {
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: startDate),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                results.append(HeartRateRangePoint.empty)
                continue
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: [])
            
            let rangePoint = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HeartRateRangePoint, Error>) in
                let query = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    
                    guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
                        cont.resume(returning: HeartRateRangePoint.empty)
                        return
                    }
                    
                    let values = quantitySamples.map { $0.quantity.doubleValue(for: unit) }
                    let minValue = values.min() ?? 0
                    let maxValue = values.max() ?? 0
                    
                    cont.resume(returning: HeartRateRangePoint(min: minValue, max: maxValue))
                }
                
                self.healthStore.execute(query)
            }
            
            results.append(rangePoint)
        }
        
        return results
    }
    
    /// 获取每月的心率范围（最小/最大值）
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    ///   - months: 月数
    /// - Returns: 心率范围数据数组
    func fetchMonthlyHeartRateRanges(
        startDate: Date,
        endDate: Date,
        months: Int
    ) async throws -> [HeartRateRangePoint] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return Array(repeating: HeartRateRangePoint.empty, count: months)
        }
        
        let calendar = Calendar.current
        let unit = HKUnit.count().unitDivided(by: .minute())
        var results: [HeartRateRangePoint] = []
        
        for monthOffset in 0..<months {
            guard let monthStart = calendar.date(byAdding: .month, value: -months + monthOffset, to: endDate),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                results.append(HeartRateRangePoint.empty)
                continue
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: monthStart, end: monthEnd, options: [])
            
            let rangePoint = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HeartRateRangePoint, Error>) in
                let query = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    
                    guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
                        cont.resume(returning: HeartRateRangePoint.empty)
                        return
                    }
                    
                    let values = quantitySamples.map { $0.quantity.doubleValue(for: unit) }
                    let minValue = values.min() ?? 0
                    let maxValue = values.max() ?? 0
                    
                    cont.resume(returning: HeartRateRangePoint(min: minValue, max: maxValue))
                }
                
                self.healthStore.execute(query)
            }
            
            results.append(rangePoint)
        }
        
        return results
    }
    
    /// 获取今天每小时的心率范围（最小/最大值）
    /// - Parameters:
    ///   - startDate: 今天0时的开始时间
    ///   - currentHour: 当前小时
    /// - Returns: 心率范围数据数组（24个元素，未来时间为空数据点）
    func fetchHourlyHeartRateRangesForToday(
        startDate: Date,
        currentHour: Int
    ) async throws -> [HeartRateRangePoint] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return Array(repeating: HeartRateRangePoint.empty, count: 24)
        }
        
        let calendar = Calendar.current
        let unit = HKUnit.count().unitDivided(by: .minute())
        var results: [HeartRateRangePoint] = []
        
        for hour in 0..<24 {
            // 未来时间返回空数据点
            guard hour <= currentHour else {
                results.append(HeartRateRangePoint.empty)
                continue
            }
            
            guard let hourStart = calendar.date(byAdding: .hour, value: hour, to: startDate),
                  let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else {
                results.append(HeartRateRangePoint.empty)
                continue
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: hourStart, end: hourEnd, options: [])
            
            let rangePoint = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HeartRateRangePoint, Error>) in
                let query = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    
                    guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
                        cont.resume(returning: HeartRateRangePoint.empty)
                        return
                    }
                    
                    let values = quantitySamples.map { $0.quantity.doubleValue(for: unit) }
                    let minValue = values.min() ?? 0
                    let maxValue = values.max() ?? 0
                    
                    cont.resume(returning: HeartRateRangePoint(min: minValue, max: maxValue))
                }
                
                self.healthStore.execute(query)
            }
            
            results.append(rangePoint)
        }
        
        return results
    }

    /// 获取指定日期的每小时心率范围（支持历史日期）
    /// - Parameters:
    ///   - startDate: 当天0时
    ///   - hours: 需要查询的小时数（通常为24）
    /// - Returns: 心率范围数据数组
    func fetchHourlyHeartRateRanges(
        startDate: Date,
        hours: Int
    ) async throws -> [HeartRateRangePoint] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return Array(repeating: HeartRateRangePoint.empty, count: hours)
        }

        let calendar = Calendar.current
        let unit = HKUnit.count().unitDivided(by: .minute())
        var results: [HeartRateRangePoint] = []
        results.reserveCapacity(hours)

        for hour in 0..<hours {
            guard let hourStart = calendar.date(byAdding: .hour, value: hour, to: startDate),
                  let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else {
                results.append(HeartRateRangePoint.empty)
                continue
            }

            let predicate = HKQuery.predicateForSamples(withStart: hourStart, end: hourEnd, options: [])

            let rangePoint = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HeartRateRangePoint, Error>) in
                let query = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error); return
                    }

                    guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
                        cont.resume(returning: HeartRateRangePoint.empty)
                        return
                    }

                    let values = quantitySamples.map { $0.quantity.doubleValue(for: unit) }
                    let minValue = values.min() ?? 0
                    let maxValue = values.max() ?? 0
                    cont.resume(returning: HeartRateRangePoint(min: minValue, max: maxValue))
                }

                self.healthStore.execute(query)
            }

            results.append(rangePoint)
        }

        return results
    }
    
    /// 获取每周的心率范围（周日到周六）
    /// - Parameters:
    ///   - startSunday: 开始周日的日期
    ///   - weeks: 周数
    /// - Returns: 心率范围数据数组
    func fetchWeeklyHeartRateRangesSundayToSaturday(
        startSunday: Date,
        weeks: Int
    ) async throws -> [HeartRateRangePoint] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return Array(repeating: HeartRateRangePoint.empty, count: weeks)
        }
        
        let calendar = Calendar.current
        let unit = HKUnit.count().unitDivided(by: .minute())
        var results: [HeartRateRangePoint] = []
        
        for weekOffset in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .day, value: weekOffset * 7, to: startSunday),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                results.append(HeartRateRangePoint.empty)
                continue
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: weekStart, end: weekEnd, options: [])
            
            let rangePoint = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HeartRateRangePoint, Error>) in
                let query = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    
                    guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
                        cont.resume(returning: HeartRateRangePoint.empty)
                        return
                    }
                    
                    let values = quantitySamples.map { $0.quantity.doubleValue(for: unit) }
                    let minValue = values.min() ?? 0
                    let maxValue = values.max() ?? 0
                    
                    cont.resume(returning: HeartRateRangePoint(min: minValue, max: maxValue))
                }
                
                self.healthStore.execute(query)
            }
            
            results.append(rangePoint)
        }
        
        return results
    }
}
