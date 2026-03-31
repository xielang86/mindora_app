import Foundation
import HealthKit

/// 健康数据管理器
final class HealthDataManager {
    static let shared = HealthDataManager()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    /// 请求健康数据权限
    func requestAuthorization() async throws {
        let typesToShare: Set = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .sleepAnalysis)!
        ]
        
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .sleepAnalysis)!
        ]
        
        // 请求权限
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
    
    /// 获取最新的健康指标数据
    func fetchLatestMetrics() async throws -> HealthMetrics {
        // 查询心率
        let heartRate = try await fetchLatestHeartRate()
        
        // 查询心率变异性
        let hrv = try await fetchLatestHRV()
        
        // 查询睡眠数据
        let sleep = try await fetchLatestSleep()
        
        return HealthMetrics(heartRate: heartRate, heartRateVariability: hrv, sleepSummary: sleep)
    }
    
    /// 获取最新的心率数据
    private func fetchLatestHeartRate() async throws -> HKQuantitySample? {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, results, error in
            if let error = error {
                print("Error fetching heart rate: \(error)")
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            query.resultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results?.first as? HKQuantitySample)
                }
            }
            HKHealthStore().execute(query)
        }
    }
    
    /// 获取最新的心率变异性数据
    private func fetchLatestHRV() async throws -> HKQuantitySample? {
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, results, error in
            if let error = error {
                print("Error fetching HRV: \(error)")
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            query.resultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results?.first as? HKQuantitySample)
                }
            }
            HKHealthStore().execute(query)
        }
    }
    
    /// 获取最新的睡眠数据
    private func fetchLatestSleep() async throws -> SleepSummary? {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, results, error in
            if let error = error {
                print("Error fetching sleep data: \(error)")
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            query.resultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results?.first as? SleepSummary)
                }
            }
            HKHealthStore().execute(query)
        }
    }
    
    // MARK: - 周度数据获取
    
    /// 获取过去7天的健康数据
    func fetchWeeklyData() async throws -> PeriodHealthData {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
            throw HealthDataError.invalidDateRange
        }
        
        // 按天聚合数据
        async let heartRateTask = fetchPeriodData(
            for: HKQuantityType(.heartRate),
            from: startDate,
            to: endDate,
            intervalDays: 1
        )
        async let hrvTask = fetchPeriodData(
            for: HKQuantityType(.heartRateVariabilitySDNN),
            from: startDate,
            to: endDate,
            intervalDays: 1
        )
        async let sleepTask = fetchPeriodSleepData(from: startDate, to: endDate, intervalDays: 1)
        
        let (heartRate, hrv, sleep) = try await (heartRateTask, hrvTask, sleepTask)
        
        return PeriodHealthData(heartRate: heartRate, hrv: hrv, sleep: sleep)
    }
    
    // MARK: - 6个月数据获取
    
    /// 获取过去6个月的健康数据
    func fetchSixMonthsData() async throws -> PeriodHealthData {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .month, value: -6, to: endDate) else {
            throw HealthDataError.invalidDateRange
        }
        
        // 按周聚合数据（7天一个数据点）
        async let heartRateTask = fetchPeriodData(
            for: HKQuantityType(.heartRate),
            from: startDate,
            to: endDate,
            intervalDays: 7
        )
        async let hrvTask = fetchPeriodData(
            for: HKQuantityType(.heartRateVariabilitySDNN),
            from: startDate,
            to: endDate,
            intervalDays: 7
        )
        async let sleepTask = fetchPeriodSleepData(from: startDate, to: endDate, intervalDays: 7)
        
        let (heartRate, hrv, sleep) = try await (heartRateTask, hrvTask, sleepTask)
        
        return PeriodHealthData(heartRate: heartRate, hrv: hrv, sleep: sleep)
    }
    
    /// 获取指定时间段内的数据
    private func fetchPeriodData(from startDate: Date, to endDate: Date, days: Int) async throws -> PeriodHealthData {
        // 查询心率
        let heartRate = try await fetchHeartRateData(from: startDate, to: endDate, days: days)
        
        // 查询心率变异性
        let hrv = try await fetchHRVData(from: startDate, to: endDate, days: days)
        
        // 查询睡眠数据
        let sleep = try await fetchSleepData(from: startDate, to: endDate, days: days)
        
        return PeriodHealthData(heartRate: heartRate, hrv: hrv, sleep: sleep)
    }
}