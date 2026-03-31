import Foundation
import HealthKit

extension HealthDataManager {
    
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
