import Foundation
import HealthKit

final class HealthDataManager {
    static let shared = HealthDataManager()
    static let authorizationDidChangeNotification = Notification.Name("HealthDataManager.authorizationDidChange")
    let healthStore = HKHealthStore()

    actor QueryCache {
        struct Entry<Value> {
            let value: Value
            let timestamp: Date
            let ttl: TimeInterval

            func isValid(at now: Date = Date()) -> Bool {
                now.timeIntervalSince(timestamp) <= ttl
            }
        }

        private var metricsEntries: [String: Entry<HealthMetrics>] = [:]
        private var sleepSummaryEntries: [String: Entry<HealthMetrics.SleepValue?>] = [:]
        private var sleepStagesEntries: [String: Entry<[SleepStageDetail]>] = [:]
        private var sleepAggregateEntries: [String: Entry<[SleepDailyAggregate]>] = [:]
        private var periodEntries: [String: Entry<PeriodHealthData>] = [:]

        func metrics(for key: String) -> HealthMetrics? {
            guard let entry = metricsEntries[key], entry.isValid() else {
                metricsEntries[key] = nil
                return nil
            }
            return entry.value
        }

        func store(metrics: HealthMetrics, for key: String, ttl: TimeInterval) {
            metricsEntries[key] = Entry(value: metrics, timestamp: Date(), ttl: ttl)
        }

        func sleepSummary(for key: String) -> HealthMetrics.SleepValue?? {
            guard let entry = sleepSummaryEntries[key], entry.isValid() else {
                sleepSummaryEntries[key] = nil
                return nil
            }
            return entry.value
        }

        func store(sleepSummary: HealthMetrics.SleepValue?, for key: String, ttl: TimeInterval) {
            sleepSummaryEntries[key] = Entry(value: sleepSummary, timestamp: Date(), ttl: ttl)
        }

        func sleepStages(for key: String) -> [SleepStageDetail]? {
            guard let entry = sleepStagesEntries[key], entry.isValid() else {
                sleepStagesEntries[key] = nil
                return nil
            }
            return entry.value
        }

        func store(sleepStages: [SleepStageDetail], for key: String, ttl: TimeInterval) {
            sleepStagesEntries[key] = Entry(value: sleepStages, timestamp: Date(), ttl: ttl)
        }

        func sleepAggregates(for key: String) -> [SleepDailyAggregate]? {
            guard let entry = sleepAggregateEntries[key], entry.isValid() else {
                sleepAggregateEntries[key] = nil
                return nil
            }
            return entry.value
        }

        func store(sleepAggregates: [SleepDailyAggregate], for key: String, ttl: TimeInterval) {
            sleepAggregateEntries[key] = Entry(value: sleepAggregates, timestamp: Date(), ttl: ttl)
        }

        func periodData(for key: String) -> PeriodHealthData? {
            guard let entry = periodEntries[key], entry.isValid() else {
                periodEntries[key] = nil
                return nil
            }
            return entry.value
        }

        func store(periodData: PeriodHealthData, for key: String, ttl: TimeInterval) {
            periodEntries[key] = Entry(value: periodData, timestamp: Date(), ttl: ttl)
        }

        func removeAll() {
            metricsEntries.removeAll()
            sleepSummaryEntries.removeAll()
            sleepStagesEntries.removeAll()
            sleepAggregateEntries.removeAll()
            periodEntries.removeAll()
        }
    }

    enum CacheTTL {
        static let latestMetrics: TimeInterval = 8
        static let sleepSummary: TimeInterval = 8
        static let sleepStages: TimeInterval = 8
        static let dailyAggregates: TimeInterval = 12
        static let periodData: TimeInterval = 15
    }

    let queryCache = QueryCache()

    /// 「最近睡眠」类查询的回溯天数。Apple 健康的日/周/月不是死锚在「今天」，而是对齐到最近一次
    /// 有数据的日期。我们用统一的回溯窗口找「最近一晚」，让锚点解析、睡眠汇总、睡眠阶段三者
    /// 看到的是同一晚，彼此一致。
    static let recentSleepLookbackDays = 45

    // MARK: - 最近睡眠日锚点（同步缓存）
    // 「最近有睡眠数据的那一天」（按 6pm 归属规则得到的 displayDay，即起床日）。日/周/月视图据此
    // 把窗口对齐到最近一次有数据的日期，避免死锚「今天」导致全空。内存 + UserDefaults 双写，
    // App 重启后也能立即拿到上次锚点先渲染。
    private static let mostRecentSleepDayDefaultsKey = "health.mostRecentSleepDay"
    private var _cachedMostRecentSleepDay: Date?

    /// 同步返回上次解析到的「最近睡眠日」（startOfDay）。无则 nil。
    var cachedMostRecentSleepDay: Date? {
        if let d = _cachedMostRecentSleepDay { return d }
        let t = UserDefaults.standard.double(forKey: Self.mostRecentSleepDayDefaultsKey)
        guard t > 0 else { return nil }
        let d = Date(timeIntervalSince1970: t)
        _cachedMostRecentSleepDay = d
        return d
    }

    func storeMostRecentSleepDay(_ day: Date) {
        _cachedMostRecentSleepDay = day
        UserDefaults.standard.set(day.timeIntervalSince1970, forKey: Self.mostRecentSleepDayDefaultsKey)
    }

    /// 作废锚点缓存。切换「构造健康数据」档位时必须调用：锚点是同步缓存，
    /// 不清的话日/周/月会继续对齐到切换前那一天。
    func clearMostRecentSleepDayCache() {
        _cachedMostRecentSleepDay = nil
        UserDefaults.standard.removeObject(forKey: Self.mostRecentSleepDayDefaultsKey)
    }

    /// 6pm 归属规则：把一次睡眠的结束时间映射到它所属的 displayDay（起床日）。
    /// 与 fetchSleepDailyAggregates 的窗口 [6pm(D-1), 6pm D] 完全一致。
    func sleepDay(forSleepEnd endDate: Date) -> Date {
        let cal = Calendar.current
        let sixPM = cal.date(bySettingHour: 18, minute: 0, second: 0, of: cal.startOfDay(for: endDate)) ?? endDate
        if endDate > sixPM {
            return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate)) ?? cal.startOfDay(for: endDate)
        }
        return cal.startOfDay(for: endDate)
    }

    private init() {}

    private var shouldUseMockHealthData: Bool {
        Constants.Config.showMockData
    }

    /// 「构造健康数据」是否生效。与上面的 `shouldUseMockHealthData` 是两套独立机制：
    /// 那个是三击 logo 的整屏 UI 预览假数据；这个只替换 HealthKit 这一层，
    /// 让没有健康数据的测试机也能产出可上传给服务端的数据。
    ///
    /// 注意它**不看 forceLive**：视图和同步逻辑一律传 forceLive: true（意思是"别给我 UI 预览假数据"），
    /// 而模拟器扮演的就是 HealthKit 本身，绕过它就没有数据可上传了。
    private var shouldUseSimulatedHealthData: Bool {
        HealthDataSimulator.shared.isEnabled
    }

    enum HealthError: Error {
        case notAvailable
        case authorizationDenied
    }

    private lazy var debugDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func debugMetricString(_ metric: HealthMetrics.MetricValue?) -> String {
        guard let metric else { return "nil" }
        let timestamp = debugDateFormatter.string(from: metric.date)
        return String(format: "%.2f @ %@", metric.value, timestamp)
    }

    private func debugSleepSummaryString(_ summary: HealthMetrics.SleepValue?) -> String {
        guard let summary else { return "nil" }
        let timestamp = debugDateFormatter.string(from: summary.date)
        let deep = summary.deepSleepHours.map { String($0) } ?? "nil"
        let rem = summary.remSleepHours.map { String($0) } ?? "nil"
        let light = summary.lightSleepHours.map { String($0) } ?? "nil"
        let inBed = summary.timeInBed.map { String($0) } ?? "nil"
        return "total=\(summary.totalSleepHours), deep=\(deep), rem=\(rem), light=\(light), inBed=\(inBed), date=\(timestamp)"
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

        await queryCache.removeAll()

        await MainActor.run {
            NotificationCenter.default.post(name: Self.authorizationDidChangeNotification, object: nil)
        }
    }

    // MARK: - 单项降级

    /// 单项 HealthKit 查询失败不该拖垮整次取数：记下原因后降级成「该项为空」。
    /// 之前一路 `try await` 直抛，心率区间一报错就让日/周/月视图的 do 块整体跳进
    /// catch，**已经取到的睡眠聚合根本没被读取**，图表因此全空（catch 里还什么都不打，
    /// 故障在日志里是隐形的）。生命体征只是页面上的附加卡片，不能当渲染前置条件。
    func degrading<T>(_ step: String, fallback: T, _ body: () async throws -> T) async -> T {
        do {
            return try await body()
        } catch {
            Log.error("HealthDataManager", "step=\(step) 查询失败，降级为空值：\(error)")
            return fallback
        }
    }

    // MARK: - Public fetch
    /// - Parameter forceLive: 当为 true 时跳过 debug mock 数据，直接从 HealthKit 获取真实数据
    func fetchLatestMetrics(forceLive: Bool = false) async throws -> HealthMetrics {
        // Debug 模式：返回虚假数据用于测试
        if !forceLive && shouldUseMockHealthData {
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

        if shouldUseSimulatedHealthData {
            return HealthDataSimulator.shared.latestMetrics()
        }

        let cacheKey = "latestMetrics::\(forceLive ? "force" : "default")"
        if let cached = await queryCache.metrics(for: cacheKey) {
            Log.info("HealthDataManager", "fetchLatestMetrics cache hit key=\(cacheKey)")
            return cached
        }
        
        // 正常模式：从 HealthKit 获取真实数据
        let latest = await degrading("latestMetrics.quantities", fallback: [:]) {
            try await fetchLatestQuantitiesConcurrently([
                (.heartRate, HKUnit.count().unitDivided(by: .minute())),
                (.heartRateVariabilitySDNN, HKUnit.secondUnit(with: .milli)),
                (.respiratoryRate, HKUnit.count().unitDivided(by: .minute())),
                (.restingHeartRate, HKUnit.count().unitDivided(by: .minute())),
                (.bodyTemperature, .degreeCelsius()),
            ])
        }
        let hrResult = latest[.heartRate] ?? (nil, nil)
        let hrvResult = latest[.heartRateVariabilitySDNN] ?? (nil, nil)
        let respiratoryResult = latest[.respiratoryRate] ?? (nil, nil)
        let restingHeartRateResult = latest[.restingHeartRate] ?? (nil, nil)
        let bodyTemperatureResult = latest[.bodyTemperature] ?? (nil, nil)
        let sleepResult = await degrading("latestMetrics.sleepSummary", fallback: nil) {
            try await fetchSleepSummary()
        }

        let sleepingWristTemperatureResult: (value: Double?, date: Date?)
        if #available(iOS 16.0, *) {
            sleepingWristTemperatureResult = await degrading("latestMetrics.wristTemperature", fallback: (nil, nil)) {
                try await fetchLatestQuantity(.appleSleepingWristTemperature, unit: .degreeCelsius())
            }
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

        let metricsLog = [
            "forceLive=\(forceLive)",
            "heartRate=\(debugMetricString(hrMetric))",
            "hrv=\(debugMetricString(hrvMetric))",
            "respiratoryRate=\(debugMetricString(respiratoryMetric))",
            "restingHeartRate=\(debugMetricString(restingHeartRateMetric))",
            "bodyTemperature=\(debugMetricString(bodyTemperatureMetric))",
            "sleepSummary=\(debugSleepSummaryString(sleepResult))"
        ].joined(separator: ", ")
        Log.info("HealthDataManager", "fetchLatestMetrics => \(metricsLog)")

        await queryCache.store(metrics: metrics, for: cacheKey, ttl: CacheTTL.latestMetrics)

        return metrics
    }

    /// 首页顶部指标只需要心率和最近一次睡眠汇总，不需要等待其他生命体征查询完成。
    func fetchLatestHomeMetrics(forceLive: Bool = false) async throws -> HealthMetrics {
        if !forceLive && shouldUseMockHealthData {
            return try await fetchLatestMetrics(forceLive: forceLive)
        }

        if shouldUseSimulatedHealthData {
            return HealthDataSimulator.shared.latestMetrics()
        }

        let cacheKey = "latestHomeMetrics::\(forceLive ? "force" : "default")"
        if let cached = await queryCache.metrics(for: cacheKey) {
            Log.info("HealthDataManager", "fetchLatestHomeMetrics cache hit key=\(cacheKey)")
            return cached
        }

        let latest = await degrading("homeMetrics.quantities", fallback: [:]) {
            try await fetchLatestQuantitiesConcurrently([
                (.heartRate, HKUnit.count().unitDivided(by: .minute())),
                (.restingHeartRate, HKUnit.count().unitDivided(by: .minute())),
            ])
        }
        let hrResult = latest[.heartRate] ?? (nil, nil)
        let restingHRResult = latest[.restingHeartRate] ?? (nil, nil)
        let sleepResult = await degrading("homeMetrics.sleepSummary", fallback: nil) {
            try await fetchSleepSummary()
        }
        // 首页顶部展示的是「睡眠心率」区间，不是最新一条心率
        let sleepHeartRateRange = await degrading("homeMetrics.sleepHeartRateRange", fallback: HeartRateRangePoint.empty) {
            try await fetchSleepHeartRateRange(forceLive: forceLive)
        }

        let heartRateMetric: HealthMetrics.MetricValue?
        if let value = hrResult.value, let date = hrResult.date {
            heartRateMetric = HealthMetrics.MetricValue(value: value, date: date)
        } else {
            heartRateMetric = nil
        }

        // 静息心率：与睡眠日视图「Resting Heart Rate」用同一数据源，保证首页点进去数值一致。
        let restingHeartRateMetric: HealthMetrics.MetricValue?
        if let value = restingHRResult.value, let date = restingHRResult.date {
            restingHeartRateMetric = HealthMetrics.MetricValue(value: value, date: date)
        } else {
            restingHeartRateMetric = nil
        }

        let latestDate = [hrResult.date, restingHRResult.date, sleepResult?.date].compactMap { $0 }.max()

        let metrics = HealthMetrics(
            heartRate: heartRateMetric,
            heartRateVariability: nil,
            respiratoryRate: nil,
            restingHeartRate: restingHeartRateMetric,
            sleepingWristTemperature: nil,
            bodyTemperature: nil,
            sleepSummary: sleepResult,
            lastUpdated: latestDate,
            sleepHeartRateRange: sleepHeartRateRange.isValid ? sleepHeartRateRange : nil
        )

        let metricsLog = [
            "forceLive=\(forceLive)",
            "heartRate=\(debugMetricString(heartRateMetric))",
            "sleepHeartRateRange=\(sleepHeartRateRange.isValid ? "\(Int(sleepHeartRateRange.min))-\(Int(sleepHeartRateRange.max))" : "nil")",
            "sleepSummary=\(debugSleepSummaryString(sleepResult))"
        ].joined(separator: ", ")
        Log.info("HealthDataManager", "fetchLatestHomeMetrics => \(metricsLog)")

        await queryCache.store(metrics: metrics, for: cacheKey, ttl: CacheTTL.latestMetrics)

        return metrics
    }

    /// Health 页面与 Explore 本地首屏只需要睡眠相关生命体征，不需要等待 HRV 完成。
    func fetchLatestSleepVitalsMetrics(forceLive: Bool = false) async throws -> HealthMetrics {
        if !forceLive && shouldUseMockHealthData {
            return try await fetchLatestMetrics(forceLive: forceLive)
        }

        if shouldUseSimulatedHealthData {
            return HealthDataSimulator.shared.latestMetrics()
        }

        let cacheKey = "latestSleepVitalsMetrics::\(forceLive ? "force" : "default")"
        if let cached = await queryCache.metrics(for: cacheKey) {
            Log.info("HealthDataManager", "fetchLatestSleepVitalsMetrics cache hit key=\(cacheKey)")
            return cached
        }

        let latest = await degrading("sleepVitals.quantities", fallback: [:]) {
            try await fetchLatestQuantitiesConcurrently([
                (.heartRate, HKUnit.count().unitDivided(by: .minute())),
                (.respiratoryRate, HKUnit.count().unitDivided(by: .minute())),
                (.restingHeartRate, HKUnit.count().unitDivided(by: .minute())),
                (.bodyTemperature, .degreeCelsius()),
            ])
        }
        let heartRateResult = latest[.heartRate] ?? (nil, nil)
        let respiratoryRateResult = latest[.respiratoryRate] ?? (nil, nil)
        let restingHeartRateResult = latest[.restingHeartRate] ?? (nil, nil)
        let bodyTemperatureResult = latest[.bodyTemperature] ?? (nil, nil)
        let sleepResult = await degrading("sleepVitals.sleepSummary", fallback: nil) {
            try await fetchSleepSummary()
        }
        // Sleep Performance 卡展示的是「睡眠心率」区间，不是最新一条静息心率
        let sleepHeartRateRange = await degrading("sleepVitals.sleepHeartRateRange", fallback: HeartRateRangePoint.empty) {
            try await fetchSleepHeartRateRange(forceLive: forceLive)
        }

        let sleepingWristTemperatureResult: (value: Double?, date: Date?)
        if #available(iOS 16.0, *) {
            sleepingWristTemperatureResult = await degrading("sleepVitals.wristTemperature", fallback: (nil, nil)) {
                try await fetchLatestQuantity(.appleSleepingWristTemperature, unit: .degreeCelsius())
            }
        } else {
            sleepingWristTemperatureResult = (nil, nil)
        }

        func metric(from result: (value: Double?, date: Date?)) -> HealthMetrics.MetricValue? {
            guard let value = result.value, let date = result.date else { return nil }
            return HealthMetrics.MetricValue(value: value, date: date)
        }

        let metrics = HealthMetrics(
            heartRate: metric(from: heartRateResult),
            heartRateVariability: nil,
            respiratoryRate: metric(from: respiratoryRateResult),
            restingHeartRate: metric(from: restingHeartRateResult),
            sleepingWristTemperature: metric(from: sleepingWristTemperatureResult),
            bodyTemperature: metric(from: bodyTemperatureResult),
            sleepSummary: sleepResult,
            lastUpdated: [
                heartRateResult.date,
                respiratoryRateResult.date,
                restingHeartRateResult.date,
                sleepingWristTemperatureResult.date,
                bodyTemperatureResult.date,
                sleepResult?.date
            ].compactMap { $0 }.max(),
            sleepHeartRateRange: sleepHeartRateRange.isValid ? sleepHeartRateRange : nil
        )

        let metricsLog = [
            "forceLive=\(forceLive)",
            "heartRate=\(debugMetricString(metrics.heartRate))",
            "sleepHeartRateRange=\(sleepHeartRateRange.isValid ? "\(Int(sleepHeartRateRange.min))-\(Int(sleepHeartRateRange.max))" : "nil")",
            "respiratoryRate=\(debugMetricString(metrics.respiratoryRate))",
            "restingHeartRate=\(debugMetricString(metrics.restingHeartRate))",
            "bodyTemperature=\(debugMetricString(metrics.bodyTemperature))",
            "sleepSummary=\(debugSleepSummaryString(metrics.sleepSummary))"
        ].joined(separator: ", ")
        Log.info("HealthDataManager", "fetchLatestSleepVitalsMetrics => \(metricsLog)")

        await queryCache.store(metrics: metrics, for: cacheKey, ttl: CacheTTL.latestMetrics)

        return metrics
    }

    // MARK: - Series (bulk) fetch for uploading

    /// 批量抓取最近 hoursBack 小时内的数据（简单方式：普通 sampleQuery）
    /// - Parameters:
    ///   - hoursBack: 回溯的小时数 (默认 24)
    ///   - maxSamples: 每个指标最大样本数 (默认 100)
    func fetchRecentSeries(hoursBack: Int = 24, maxSamples: Int = 100) async throws -> HealthSeriesData {
        let endDate = Date()
        let startDate = Date(timeIntervalSinceNow: TimeInterval(-hoursBack * 3600))
        return try await fetchSeries(from: startDate, to: endDate, maxSamples: maxSamples)
    }

    /// 按显式的 [start, end] 时间范围拉取各指标样本。用于切片上传等需要精确控制窗口的场景。
    func fetchSeries(from startDate: Date, to endDate: Date, maxSamples: Int = 100) async throws -> HealthSeriesData {
        // 「构造健康数据」的落点就在这里：HealthSyncService 切片上传走的是本方法，
        // 打开模拟后上传给服务端的即是构造出来的样本 —— 这正是这套机制要解决的问题
        //（测试机没有健康数据，服务端收不到任何东西）。
        if shouldUseSimulatedHealthData {
            var simulated = HealthDataSimulator.shared.series(from: startDate, to: endDate, maxSamples: maxSamples)
            Self.restrictSeriesToSleep(&simulated)
            simulated.heartRate.removeAll()   // 心率序列不上传，只用于推导区间
            if let anchor = Self.sleepAnchorTimestamp(of: simulated),
               let night = HealthDataSimulator.shared.sleepHeartRateRange(forNightContaining: anchor) {
                simulated.sleepHeartRateRange = .init(
                    startTs: Int(night.sessionStart.timeIntervalSince1970),
                    endTs: Int(night.sessionEnd.timeIntervalSince1970),
                    min: night.min,
                    max: night.max
                )
            }
            return simulated
        }
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.notAvailable }
        var result = HealthSeriesData()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        var requests: [(HKQuantityTypeIdentifier, HKUnit)] = [
            (.heartRate, HKUnit.count().unitDivided(by: .minute())),
            (.heartRateVariabilitySDNN, HKUnit.secondUnit(with: .milli)),
            (.respiratoryRate, HKUnit.count().unitDivided(by: .minute())),
            (.restingHeartRate, HKUnit.count().unitDivided(by: .minute())),
            (.bodyTemperature, .degreeCelsius()),
        ]
        if #available(iOS 16.0, *) {
            requests.append((.appleSleepingWristTemperature, .degreeCelsius()))
        }
        let series = try await fetchSeriesConcurrently(requests, predicate: predicate, limit: maxSamples)

        result.heartRate = series[.heartRate] ?? []
        result.hrv = series[.heartRateVariabilitySDNN] ?? []
        result.respiratoryRate = series[.respiratoryRate] ?? []
        result.restingHeartRate = series[.restingHeartRate] ?? []
        result.bodyTemperature = series[.bodyTemperature] ?? []
        if #available(iOS 16.0, *) {
            result.sleepingWristTemperature = series[.appleSleepingWristTemperature] ?? []
        }

        if let stages = try await fetchSleepStages(start: startDate, end: endDate) {
            result.deepSleep = stages.deep
            result.remSleep = stages.rem
            result.lightSleep = stages.light
            result.unspecifiedSleep = stages.unspecified
            result.awakeSleep = stages.awake
            result.inBed = stages.inBed
        }
        // 上传口径：全部数据都只针对睡眠。除静息心率与睡眠腕温外，
        // 其余序列一律裁剪到这一片的睡眠跨度内（见 restrictSeriesToSleep）。
        Self.restrictSeriesToSleep(&result)

        // 心率序列本身不上传，只上传睡眠心率区间（min–max），
        // 与首页 / 日视图展示的 Sleep Heart Rate 同源（见 cb4624b）。
        // 区间按**整晚**算，不按当前切片算 —— 否则跨午夜的一晚会得到两个残缺区间。
        result.heartRate.removeAll()
        if let anchor = Self.sleepAnchorTimestamp(of: result),
           let night = try? await fetchSleepHeartRateRangeForNight(containing: anchor) {
            result.sleepHeartRateRange = .init(
                startTs: Int(night.sessionStart.timeIntervalSince1970),
                endTs: Int(night.sessionEnd.timeIntervalSince1970),
                min: night.range.min,
                max: night.range.max
            )
        }
        return result
    }

    /// 上传口径：把随时间连续产生的序列裁剪到睡眠跨度内。
    ///
    /// 两个例外，它们本身就已经是睡眠/日级数据，裁剪只会把它们清空：
    /// - `restingHeartRate`：苹果按日算好的基线，一天一个值，不存在「睡眠期间」的子集
    /// - `appleSleepingWristTemperature`：苹果本就只在睡眠时产出，一晚一个值
    ///
    /// 这一片没有任何睡眠阶段时，被裁剪的序列一律清空 —— 没有睡眠就没有睡眠期间的数据。
    static func restrictSeriesToSleep(_ series: inout HealthSeriesData) {
        let stages = (series.deepSleep + series.remSleep + series.lightSleep
            + series.unspecifiedSleep + series.awakeSleep)
            .sorted { $0.startTs < $1.startTs }
        guard !stages.isEmpty else {
            series.hrv.removeAll()
            series.respiratoryRate.removeAll()
            series.bodyTemperature.removeAll()
            return
        }

        // 必须按【阶段区间的并集】裁剪，不能用 min(start)…max(end) 这个总跨度。
        // 上传按自然日切片，而一个自然日里通常有两段睡眠：昨晚的尾巴（00:00–07:00）
        // 和今晚的开头（23:30–24:00）。取总跨度会得到 00:00–24:00，整个白天的样本
        // 都会被保留下来，裁剪等于没做。
        var merged: [(start: Int, end: Int)] = []
        for stage in stages {
            if let last = merged.last, stage.startTs <= last.end {
                merged[merged.count - 1].end = Swift.max(last.end, stage.endTs)
            } else {
                merged.append((stage.startTs, stage.endTs))
            }
        }

        func clip(_ points: inout [HealthSeriesData.SamplePoint]) {
            points = points.filter { point in
                merged.contains { point.timestamp >= $0.start && point.timestamp <= $0.end }
            }
        }
        clip(&series.hrv)
        clip(&series.respiratoryRate)
        clip(&series.bodyTemperature)
    }

    /// 这一片里最早的睡眠阶段起点，用来定位它属于哪一晚。没有睡眠阶段就返回 nil。
    private static func sleepAnchorTimestamp(of series: HealthSeriesData) -> Date? {
        let stages = series.deepSleep + series.remSleep + series.lightSleep
            + series.unspecifiedSleep + series.awakeSleep
        guard let earliest = stages.map({ $0.startTs }).min() else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(earliest))
    }

    func fetchSeries(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate, limit: Int) async throws -> [HealthSeriesData.SamplePoint] {
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

    // MARK: - 并发取数

    /// 并发拉取多个「最新一条」指标，按 identifier 归位返回。
    ///
    /// 这里刻意**不用 `async let`**：优化构建（Release / TestFlight）下，
    /// async let 子任务的栈回收顺序会与内联后的调用帧错位，作用域一旦带着错误
    /// 退出就撞上 `swift_task_dealloc` 的致命断言直接 abort。1.2 (4) 一打开
    /// 就闪退即此，崩溃栈顶是
    /// `asyncLet_finish_after_task_completion → swift_task_dealloc → abort`，
    /// Debug 构建复现不出来（只在 -O 下内联后才错位）。
    /// 任务组没有这个问题，并发度与错误语义与原来完全一致：
    /// 任一路抛错就取消其余路并把错误抛给调用方。
    private func fetchLatestQuantitiesConcurrently(
        _ requests: [(HKQuantityTypeIdentifier, HKUnit)]
    ) async throws -> [HKQuantityTypeIdentifier: (value: Double?, date: Date?)] {
        try await withThrowingTaskGroup(
            of: (HKQuantityTypeIdentifier, (value: Double?, date: Date?)).self
        ) { group in
            for (identifier, unit) in requests {
                group.addTask { [self] in
                    (identifier, try await fetchLatestQuantity(identifier, unit: unit))
                }
            }
            var output: [HKQuantityTypeIdentifier: (value: Double?, date: Date?)] = [:]
            for try await (identifier, value) in group { output[identifier] = value }
            return output
        }
    }

    /// 并发拉取多个指标的样本序列。不用 `async let` 的原因同上。
    private func fetchSeriesConcurrently(
        _ requests: [(HKQuantityTypeIdentifier, HKUnit)],
        predicate: NSPredicate,
        limit: Int
    ) async throws -> [HKQuantityTypeIdentifier: [HealthSeriesData.SamplePoint]] {
        let sendablePredicate = _SendablePredicate(value: predicate)
        return try await withThrowingTaskGroup(
            of: (HKQuantityTypeIdentifier, [HealthSeriesData.SamplePoint]).self
        ) { group in
            for (identifier, unit) in requests {
                group.addTask { [self] in
                    (identifier, try await fetchSeries(
                        identifier,
                        unit: unit,
                        predicate: sendablePredicate.value,
                        limit: limit
                    ))
                }
            }
            var output: [HKQuantityTypeIdentifier: [HealthSeriesData.SamplePoint]] = [:]
            for try await (identifier, samples) in group { output[identifier] = samples }
            return output
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
    
    
    
    
    
    
    
    /// 获取日数据（指定日期0-23时，每小时一个数据点）
    /// X轴固定显示0-23时，若 anchorDate 为今天，未来时间为0
    /// - Parameter anchorDate: 作为时间窗口结束的日期（默认为当前时间）
    func fetchDailyData(anchorDate: Date = Date()) async throws -> PeriodHealthData {
        // Debug 模式：返回基于 anchorDate 的模拟数据
        if shouldUseMockHealthData {
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

        if shouldUseSimulatedHealthData {
            return HealthDataSimulator.shared.dailyData(anchorDate: anchorDate)
        }

        let cacheKey = "daily::\(Calendar.current.startOfDay(for: anchorDate).timeIntervalSince1970)"
        if let cached = await queryCache.periodData(for: cacheKey) {
            Log.info("HealthDataManager", "fetchDailyData cache hit key=\(cacheKey)")
            return cached
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
            result.heartRate = await degrading("fetchHourlyAveragesForToday.heartRate", fallback: result.heartRate) {
                try await fetchHourlyAveragesForToday(
                    .heartRate,
                    unit: HKUnit.count().unitDivided(by: .minute()),
                    startDate: startOfDay,
                    currentHour: currentHour
                )
            }
        } else {
            result.heartRate = await degrading("fetchHourlyAverages.heartRate", fallback: result.heartRate) {
                try await fetchHourlyAverages(
                    .heartRate,
                    unit: HKUnit.count().unitDivided(by: .minute()),
                    startDate: startOfDay,
                    hours: 24
                )
            }
        }
        
        // 获取每小时的心率范围（最小/最大值）
        if isToday {
            result.heartRateRange = await degrading("fetchHourlyHeartRateRangesForToday.heartRateRange", fallback: result.heartRateRange) {
                try await fetchHourlyHeartRateRangesForToday(
                    startDate: startOfDay,
                    currentHour: currentHour
                )
            }
        } else {
            result.heartRateRange = await degrading("fetchHourlyHeartRateRanges.heartRateRange", fallback: result.heartRateRange) {
                try await fetchHourlyHeartRateRanges(
                    startDate: startOfDay,
                    hours: 24
                )
            }
        }
        
        // 获取每小时的平均HRV
        if isToday {
            result.hrv = await degrading("fetchHourlyAveragesForToday.hrv", fallback: result.hrv) {
                try await fetchHourlyAveragesForToday(
                    .heartRateVariabilitySDNN,
                    unit: HKUnit.secondUnit(with: .milli),
                    startDate: startOfDay,
                    currentHour: currentHour
                )
            }
        } else {
            result.hrv = await degrading("fetchHourlyAverages.hrv", fallback: result.hrv) {
                try await fetchHourlyAverages(
                    .heartRateVariabilitySDNN,
                    unit: HKUnit.secondUnit(with: .milli),
                    startDate: startOfDay,
                    hours: 24
                )
            }
        }
        
        // 获取每小时的睡眠时长（小时内睡眠的分钟数/60）
        if isToday {
            result.sleep = await degrading("fetchHourlySleepHoursForToday.sleep", fallback: result.sleep) {
                try await fetchHourlySleepHoursForToday(
                    startDate: startOfDay,
                    currentHour: currentHour
                )
            }
        } else {
            result.sleep = await degrading("fetchHourlySleepHours.sleep", fallback: result.sleep) {
                try await fetchHourlySleepHours(
                    startDate: startOfDay,
                    hours: 24
                )
            }
        }

        await queryCache.store(periodData: result, for: cacheKey, ttl: CacheTTL.periodData)
        
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
    
    
    
    
}
