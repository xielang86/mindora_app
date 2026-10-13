import Foundation
import HealthKit

extension HealthDataManager {
    
    // MARK: - Sleep Summary
    
    func fetchSleepSummary() async throws -> HealthMetrics.SleepValue? {
        if HealthDataSimulator.shared.isEnabled {
            return HealthDataSimulator.shared.latestSleepSummary()
        }
        let cacheKey = "sleepSummary"
        if let cached = await queryCache.sleepSummary(for: cacheKey) {
            Log.info("HealthDataManager", "fetchSleepSummary cache hit")
            return cached
        }

        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let now = Date()
        // 回溯足够多天去找「最近一晚」，而不是只看 48h——否则数据停在几天前时日视图就全空了。
        // 内部仍按 endDate 取最近一晚，所以窗口大只影响找得到，不影响汇总的是哪一晚。
        let roughWindowStart = calendar.date(byAdding: .day, value: -Self.recentSleepLookbackDays, to: now) ?? now.addingTimeInterval(-48 * 3600)
        #if swift(>=5.7)
        let roughPredicateSendable = _SendablePredicate(value: HKQuery.predicateForSamples(withStart: roughWindowStart, end: now, options: []))
        #else
        let roughPredicateSendable = HKQuery.predicateForSamples(withStart: roughWindowStart, end: now, options: [])
        #endif

        func dayWindow(for endDate: Date) -> (start: Date, end: Date) {
            let dayStartCandidate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.startOfDay(for: endDate))!
            if endDate >= dayStartCandidate {
                return (dayStartCandidate, dayStartCandidate.addingTimeInterval(24 * 3600))
            }
            let start = dayStartCandidate.addingTimeInterval(-24 * 3600)
            return (start, start.addingTimeInterval(24 * 3600))
        }

        let summary = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HealthMetrics.SleepValue?, Error>) in
            let localPredicate = roughPredicateSendable.value
            let query = HKSampleQuery(sampleType: type, predicate: localPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let rawSamples = samples as? [HKCategorySample], !rawSamples.isEmpty else { cont.resume(returning: nil); return }

                let sleepStageValues: Set<Int>
                if #available(iOS 16.0, *) {
                    sleepStageValues = [
                        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    ]
                } else {
                    sleepStageValues = [HKCategoryValueSleepAnalysis.asleep.rawValue]
                }

                guard let latestStageSample = rawSamples.filter({ sleepStageValues.contains($0.value) }).max(by: { $0.endDate < $1.endDate }) else {
                    cont.resume(returning: nil)
                    return
                }

                let window = dayWindow(for: latestStageSample.endDate)
                // 多来源重叠必须先归一化再计时长，否则 Watch + iPhone 睡眠专注会把一晚算两遍。
                let resolved = SleepSampleResolver.resolve(samples: rawSamples, window: window)

                // 对外一律用分钟口径（苹果健康算法），不是秒数求和 —— 见 fillMinuteCounts
                cont.resume(returning: HealthMetrics.SleepValue(
                    totalSleepHours: Double(resolved.totalAsleepMinutes) / 60.0,
                    deepSleepHours: resolved.deepMinutes > 0 ? Double(resolved.deepMinutes) / 60.0 : nil,
                    remSleepHours: resolved.remMinutes > 0 ? Double(resolved.remMinutes) / 60.0 : nil,
                    lightSleepHours: resolved.coreMinutes > 0 ? Double(resolved.coreMinutes) / 60.0 : nil,
                    timeInBed: resolved.inBed > 0 ? resolved.inBed / 3600.0 : nil,
                    date: latestStageSample.endDate
                ))
            }
            self.healthStore.execute(query)
        }

        await queryCache.store(sleepSummary: summary, for: cacheKey, ttl: CacheTTL.sleepSummary)
        return summary
    }

    /// 包含 `date` 的那一晚（睡眠日 18:00–18:00 窗口）的**整晚**睡眠心率区间。
    ///
    /// 为什么不能按上传切片算：切片是按自然日午夜对齐的，而多数人 23 点多入睡 ——
    /// 一晚会被拆成 [23:30, 24:00) 和 [00:00, 07:00) 两片，逐片取 min/max 得到的是
    /// 两个残缺区间。这里一律按整晚窗口重算：两片算出的是同一个区间、起点相同，
    /// 第二片会被 UploadStateStore 的水位线去重掉，服务端最终只收到一条。
    func fetchSleepHeartRateRangeForNight(containing date: Date) async throws
        -> (sessionStart: Date, sessionEnd: Date, range: HeartRateRangePoint)? {
        let calendar = Calendar.current
        let day = sleepDay(forSleepEnd: date)
        guard let windowEnd = calendar.date(byAdding: .hour, value: 18, to: day),
              let windowStart = calendar.date(byAdding: .day, value: -1, to: windowEnd) else { return nil }

        let samples = try await fetchSleepSamples(start: windowStart, end: windowEnd)
        guard !samples.isEmpty else { return nil }
        let resolved = SleepSampleResolver.resolve(samples: samples, window: (start: windowStart, end: windowEnd))
        let intervals = SleepSampleResolver.sleepIntervals(from: resolved)
        guard let sessionStart = intervals.first?.start,
              let sessionEnd = intervals.last?.end else { return nil }

        // min/max 只在阶段区间的并集内取。用 sessionStart…sessionEnd 这个总跨度会把
        // 傍晚小睡与夜间入睡之间那几小时清醒时的心率也算进来，区间被拉得没有意义。
        let predicate = HKQuery.predicateForSamples(withStart: sessionStart, end: sessionEnd, options: [])
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let points = (try? await fetchSeries(.heartRate, unit: bpm, predicate: predicate, limit: HKObjectQueryNoLimit)) ?? []
        let values = Self.values(of: points, in: intervals)
        guard let minValue = values.min(), let maxValue = values.max() else { return nil }
        return (sessionStart, sessionEnd, HeartRateRangePoint(min: minValue, max: maxValue))
    }

    /// 最近一晚「实际入睡 → 最后醒来」的跨度。用于把生命体征限定在睡眠期间统计
    /// （如睡眠心率区间），而不是整个 6pm–6pm 睡眠日窗口。没有睡眠数据返回 nil。
    func fetchMostRecentSleepSessionSpan() async throws -> (start: Date, end: Date)? {
        let stages = try await fetchLatestSleepStages(forceLive: true)
        let asleep = stages.filter { $0.stage != .awake }
        guard let start = asleep.map(\.startTime).min(),
              let end = asleep.map(\.endTime).max(),
              end > start else { return nil }
        return (start, end)
    }

    // MARK: - 最近睡眠日锚点

    /// 找「最近有睡眠数据的那一天」（起床日，按 6pm 归属规则）。回溯 recentSleepLookbackDays 天，
    /// 取最近一次「睡着」样本的 endDate 映射得到，供日/周/月视图把窗口对齐到这一天（像 Apple 那样）。
    /// 解析成功会写入同步缓存 cachedMostRecentSleepDay，供下次进入即时计算区间。
    func fetchMostRecentSleepDay(forceLive: Bool = false) async throws -> Date? {
        if !forceLive && Constants.Config.showMockData {
            return Calendar.current.startOfDay(for: Date())
        }
        // 「构造健康数据」：锚点必须落在模拟出来的最近一晚，否则日/周/月会对齐到没有数据的今天。
        if HealthDataSimulator.shared.isEnabled {
            guard let night = HealthDataSimulator.shared.mostRecentNight() else { return nil }
            storeMostRecentSleepDay(night.day)
            return night.day
        }
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let windowStart = calendar.date(byAdding: .day, value: -Self.recentSleepLookbackDays, to: now) ?? now

        let asleepValues: Set<Int>
        if #available(iOS 16.0, *) {
            asleepValues = [
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
            ]
        } else {
            asleepValues = [HKCategoryValueSleepAnalysis.asleep.rawValue]
        }

        #if swift(>=5.7)
        let predicateSendable = _SendablePredicate(value: HKQuery.predicateForSamples(withStart: windowStart, end: now, options: []))
        #else
        let predicateSendable = HKQuery.predicateForSamples(withStart: windowStart, end: now, options: [])
        #endif

        let latestEnd: Date? = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Date?, Error>) in
            let localPredicate = predicateSendable.value
            let query = HKSampleQuery(sampleType: type, predicate: localPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let raw = samples as? [HKCategorySample] else { cont.resume(returning: nil); return }
                let latest = raw.filter { asleepValues.contains($0.value) }.max(by: { $0.endDate < $1.endDate })
                cont.resume(returning: latest?.endDate)
            }
            self.healthStore.execute(query)
        }

        guard let endDate = latestEnd else { return nil }
        let day = sleepDay(forSleepEnd: endDate)
        storeMostRecentSleepDay(day)
        Log.info("HealthDataManager", "fetchMostRecentSleepDay => \(day)")
        return day
    }

    // MARK: - Sleep Stage Data (for Sleep Graph)
    
    /// 获取最近一次睡眠的详细阶段数据
    func fetchLatestSleepStages(forceLive: Bool = false) async throws -> [SleepStageDetail] {
        // Debug 模式：返回模拟数据
        if Constants.Config.showMockData && !forceLive {
            return generateDebugSleepStages()
        }
        if HealthDataSimulator.shared.isEnabled {
            return HealthDataSimulator.shared.latestSleepStages()
        }

        let cacheKey = "latestSleepStages::\(forceLive ? "force" : "default")"
        if let cached = await queryCache.sleepStages(for: cacheKey) {
            Log.info("HealthDataManager", "fetchLatestSleepStages cache hit key=\(cacheKey)")
            return cached
        }
        
        // 正常模式：从 HealthKit 获取真实数据
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        // 同 fetchSleepSummary：回溯足够多天才能找到最近一晚的阶段数据（数据停在几天前时）。
        let roughWindowStart = calendar.date(byAdding: .day, value: -Self.recentSleepLookbackDays, to: now) ?? now.addingTimeInterval(-48 * 3600)

        let stages = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[SleepStageDetail], Error>) in
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

                // 归一化后的区间互不重叠，图表不会因多来源画出叠加的重复条带
                let resolved = SleepSampleResolver.resolve(samples: rawSamples, window: window)
                let stageDetails: [SleepStageDetail] = resolved.segments.map { segment in
                    let stage: SleepStageDetail.Stage
                    switch segment.stage {
                    case .deep: stage = .deep
                    case .rem: stage = .rem
                    case .core, .unspecified: stage = .core  // unspecified 当作核心睡眠
                    case .awake: stage = .awake
                    }
                    return SleepStageDetail(stage: stage, startTime: segment.start, endTime: segment.end)
                }

                cont.resume(returning: stageDetails)
            }
            
            self.healthStore.execute(query)
        }

        await queryCache.store(sleepStages: stages, for: cacheKey, ttl: CacheTTL.sleepStages)
        return stages
    }

    func fetchSleepDailyAggregates(startingFrom startDay: Date, days: Int) async throws -> [SleepDailyAggregate] {
        guard days > 0 else { return [] }
        if HealthDataSimulator.shared.isEnabled {
            return HealthDataSimulator.shared.sleepDailyAggregates(startingFrom: startDay, days: days)
        }
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }

        let calendar = Calendar.current
        let normalizedStartDay = calendar.startOfDay(for: startDay)
        let cacheKey = "sleepDailyAggregates::\(normalizedStartDay.timeIntervalSince1970)::\(days)"
        if let cached = await queryCache.sleepAggregates(for: cacheKey) {
            Log.info("HealthDataManager", "fetchSleepDailyAggregates cache hit key=\(cacheKey)")
            return cached
        }
        let queryStart = calendar.date(byAdding: .hour, value: -6, to: normalizedStartDay) ?? normalizedStartDay
        let lastDisplayDay = calendar.date(byAdding: .day, value: days - 1, to: normalizedStartDay) ?? normalizedStartDay
        let lastWindowEnd = calendar.date(byAdding: .hour, value: 18, to: lastDisplayDay) ?? lastDisplayDay
        let queryEnd = min(lastWindowEnd, Date())

        if queryEnd <= queryStart {
            return (0..<days).map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: normalizedStartDay) ?? normalizedStartDay
                return SleepDailyAggregate(
                    date: date,
                    totalSleepHours: 0,
                    deepSleepHours: 0,
                    remSleepHours: 0,
                    coreSleepHours: 0,
                    awakeMinutes: 0,
                    timeInBedHours: 0,
                    sleepOnsetMinutes: nil
                )
            }
        }

        let aggregates = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[SleepDailyAggregate], Error>) in
            #if swift(>=5.7)
            let predicateSendable = _SendablePredicate(value: HKQuery.predicateForSamples(withStart: queryStart, end: queryEnd, options: []))
            #else
            let predicateSendable = HKQuery.predicateForSamples(withStart: queryStart, end: queryEnd, options: [])
            #endif

            let query = HKSampleQuery(sampleType: type, predicate: predicateSendable.value, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }

                let rawSamples = (samples as? [HKCategorySample]) ?? []
                let aggregates = (0..<days).map { offset -> SleepDailyAggregate in
                    let displayDay = calendar.date(byAdding: .day, value: offset, to: normalizedStartDay) ?? normalizedStartDay
                    let windowEnd = calendar.date(byAdding: .hour, value: 18, to: displayDay) ?? displayDay
                    let windowStart = calendar.date(byAdding: .day, value: -1, to: windowEnd) ?? windowEnd

                    // 多来源重叠必须先归一化再计时长，否则 Watch + iPhone 睡眠专注会把一晚算两遍。
                    let resolved = SleepSampleResolver.resolve(
                        samples: rawSamples,
                        window: (start: windowStart, end: windowEnd)
                    )

                    // 对外一律用分钟口径（苹果健康算法），不是秒数求和 —— 见 fillMinuteCounts
                    return SleepDailyAggregate(
                        date: displayDay,
                        totalSleepHours: Double(resolved.totalAsleepMinutes) / 60.0,
                        deepSleepHours: Double(resolved.deepMinutes) / 60.0,
                        remSleepHours: Double(resolved.remMinutes) / 60.0,
                        coreSleepHours: Double(resolved.coreMinutes) / 60.0,
                        awakeMinutes: Double(resolved.awakeMinutes),
                        timeInBedHours: resolved.inBed / 3600.0,
                        sleepOnsetMinutes: SleepSampleResolver.sleepOnsetMinutes(from: resolved),
                        unspecifiedSleepHours: Double(resolved.unspecifiedMinutes) / 60.0
                    )
                }

                cont.resume(returning: aggregates)
            }

            self.healthStore.execute(query)
        }

        await queryCache.store(sleepAggregates: aggregates, for: cacheKey, ttl: CacheTTL.dailyAggregates)
        return aggregates
    }

    // MARK: - 周/月生命体征（全部按睡眠口径）

    /// 周/月生命体征卡的四个值：睡眠心率、静息心率、呼吸频率、腕温。
    ///
    /// 口径统一为「**限定在睡眠期间** + 按晚等权平均」，而不是取最新一条样本 ——
    /// 卡片标签本来就写着平均，看一周和看一个月理应是不同的数字。
    ///
    /// 性能：整个窗口每类指标只查一次，再在内存里按每晚的睡眠跨度分桶。
    /// 绝不能按天各查一次 —— 月视图会变成几十次 HealthKit 查询。
    func fetchSleepVitalsAverages(days: Int, endingAt anchorDate: Date = Date()) async throws -> SleepVitalsAverages {
        // 「构造健康数据」开关：必须走模拟器，否则调试时这张卡全是 "--"
        if HealthDataSimulator.shared.isEnabled {
            let simulated = HealthDataSimulator.shared.sleepVitalsAverages(days: days, endingAt: anchorDate)
            // 这条日志不能少：早期版本只在真机分支末尾打日志，开着构造数据时这个函数
            // 跑完却一行日志都没有，排查崩溃时会误判成「根本没调用过」。
            Log.info("HealthDataManager", "fetchSleepVitalsAverages(simulated) days=\(days) nights=\(simulated.nights) hr=\(simulated.sleepHeartRate.map { String(format: "%.1f", $0) } ?? "nil")")
            return simulated
        }
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchorDate)
        let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: anchorDay) ?? anchorDay

        // 每一天的睡眠窗口沿用既有规则：前一天 18:00 → 当天 18:00
        var windows: [(start: Date, end: Date)] = []
        for offset in 0..<days {
            let displayDay = calendar.date(byAdding: .day, value: offset, to: startDay) ?? startDay
            guard let end = calendar.date(byAdding: .hour, value: 18, to: displayDay),
                  let start = calendar.date(byAdding: .day, value: -1, to: end) else { continue }
            windows.append((start, end))
        }
        guard let overallStart = windows.first?.start, let overallEnd = windows.last?.end else {
            return SleepVitalsAverages()
        }

        // 一次拉全窗口的睡眠样本，切出每晚「实际入睡 → 最后醒来」的跨度
        let sleepSamples = try await fetchSleepSamples(start: overallStart, end: overallEnd)
        // 每晚的睡眠期间（阶段区间并集），不是总跨度
        var nightIntervals: [[(start: Date, end: Date)]] = []
        // 有睡眠的那些「睡眠日窗口」。静息心率与腕温是日/夜级标量，落不进睡眠跨度，
        // 但也不能拿没睡觉那天的值来平均，所以按睡眠日窗口过滤。
        var sleepDayWindows: [(start: Date, end: Date)] = []
        for window in windows {
            let resolved = SleepSampleResolver.resolve(samples: sleepSamples, window: window)
            let intervals = SleepSampleResolver.sleepIntervals(from: resolved)
            guard !intervals.isEmpty else { continue }
            nightIntervals.append(intervals)
            sleepDayWindows.append(window)
        }
        guard !nightIntervals.isEmpty else { return SleepVitalsAverages() }

        var result = SleepVitalsAverages()
        result.nights = nightIntervals.count

        let predicate = HKQuery.predicateForSamples(withStart: overallStart, end: overallEnd, options: [])
        let bpm = HKUnit.count().unitDivided(by: .minute())

        // 每类指标各一次查询。这里刻意**不用 async let**：
        // 对 async let 变量做 `try? await` 会在子任务收尾时打乱任务分配器的栈序，
        // 触发 swift_Concurrency_fatalError（asyncLet_finish_after_task_completion）。
        // 真机 iPhone 17 Pro 上 100% 复现。顺序 await 慢一点但绝对安全。
        let heartRatePoints = (try? await fetchSeries(.heartRate, unit: bpm, predicate: predicate, limit: HKObjectQueryNoLimit)) ?? []
        let respiratoryPoints = (try? await fetchSeries(.respiratoryRate, unit: bpm, predicate: predicate, limit: HKObjectQueryNoLimit)) ?? []
        let restingPoints = (try? await fetchSeries(.restingHeartRate, unit: bpm, predicate: predicate, limit: HKObjectQueryNoLimit)) ?? []
        let bodyTempPoints = (try? await fetchSeries(.bodyTemperature, unit: .degreeCelsius(), predicate: predicate, limit: HKObjectQueryNoLimit)) ?? []

        var wristTempPoints: [HealthSeriesData.SamplePoint] = []
        if #available(iOS 16.0, *) {
            wristTempPoints = (try? await fetchSeries(.appleSleepingWristTemperature, unit: .degreeCelsius(), predicate: predicate, limit: HKObjectQueryNoLimit)) ?? []
        }

        // 睡眠心率：每晚跨度内求均值，再对晚等权平均；同时记录周期内的最低/最高
        let heartRateNightly = Self.nightlyAverages(of: heartRatePoints, in: nightIntervals)
        result.sleepHeartRate = Self.mean(heartRateNightly.averages)
        result.sleepHeartRateMin = heartRateNightly.minimum
        result.sleepHeartRateMax = heartRateNightly.maximum

        // 呼吸频率：同上
        result.respiratoryRate = Self.mean(Self.nightlyAverages(of: respiratoryPoints, in: nightIntervals).averages)

        // 静息心率：苹果按日算好的基线，不区分睡眠/清醒，落不进睡眠跨度，
        // 因此按「有睡眠的那些睡眠日窗口」过滤后取平均，而不是窗口内所有样本
        result.restingHeartRate = Self.mean(Self.values(of: restingPoints, in: sleepDayWindows))

        // 腕温：appleSleepingWristTemperature 本身就只在睡眠时产出，一晚一个值；
        // 同样按睡眠日窗口过滤。设备不支持时退回体温在睡眠跨度内的均值
        if let wrist = Self.mean(Self.values(of: wristTempPoints, in: sleepDayWindows)) {
            result.wristTemperature = wrist
        } else {
            result.wristTemperature = Self.mean(Self.nightlyAverages(of: bodyTempPoints, in: nightIntervals).averages)
        }

        Log.info("HealthDataManager", "fetchSleepVitalsAverages days=\(days) nights=\(result.nights) hr=\(result.sleepHeartRate.map { String(format: "%.1f", $0) } ?? "nil") resting=\(result.restingHeartRate.map { String(format: "%.1f", $0) } ?? "nil") resp=\(result.respiratoryRate.map { String(format: "%.1f", $0) } ?? "nil") temp=\(result.wristTemperature.map { String(format: "%.2f", $0) } ?? "nil")")
        return result
    }

    /// 把样本按每晚的睡眠跨度分桶，返回每晚的均值，以及所有落在跨度内的样本的最小/最大值。
    private static func nightlyAverages(
        of points: [HealthSeriesData.SamplePoint],
        in nightIntervals: [[(start: Date, end: Date)]]
    ) -> (averages: [Double], minimum: Double?, maximum: Double?) {
        guard !points.isEmpty else { return ([], nil, nil) }
        var averages: [Double] = []
        var minimum: Double?
        var maximum: Double?

        for intervals in nightIntervals {
            let values = Self.values(of: points, in: intervals)
            guard !values.isEmpty else { continue }
            averages.append(values.reduce(0, +) / Double(values.count))
            minimum = min(minimum ?? .greatestFiniteMagnitude, values.min() ?? .greatestFiniteMagnitude)
            maximum = max(maximum ?? -.greatestFiniteMagnitude, values.max() ?? -.greatestFiniteMagnitude)
        }
        return (averages, minimum, maximum)
    }

    /// 取落在给定窗口集合内的样本值。用于日/夜级标量（静息心率、腕温），
    /// 它们不落在睡眠跨度里，但要排除没有睡眠数据的那些天。
    private static func values(
        of points: [HealthSeriesData.SamplePoint],
        in windows: [(start: Date, end: Date)]
    ) -> [Double] {
        guard !points.isEmpty, !windows.isEmpty else { return [] }
        let ranges = windows.map { (Int($0.start.timeIntervalSince1970), Int($0.end.timeIntervalSince1970)) }
        return points
            .filter { point in ranges.contains { point.timestamp >= $0.0 && point.timestamp < $0.1 } }
            .map { $0.value }
    }

    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    func fetchSleepDailyAggregates(days: Int, endingAt anchorDate: Date = Date()) async throws -> [SleepDailyAggregate] {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchorDate)
        let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: anchorDay) ?? anchorDay
        return try await fetchSleepDailyAggregates(startingFrom: startDay, days: days)
    }
    
    /// 生成 Debug 模式的模拟睡眠阶段数据
    private func generateDebugSleepStages() -> [SleepStageDetail] {
        let calendar = Calendar.current
        let now = Date()
        
        // 模拟昨晚 22:30 上床，今早 7:00 起床（8.5小时）
        let bedTime = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now)!)!
        
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

    // MARK: - Sleep Stages (interval samples)
    
    func fetchSleepStages(start: Date, end: Date) async throws -> SleepStageSeries? {
        if HealthDataSimulator.shared.isEnabled {
            return HealthDataSimulator.shared.sleepStagePoints(start: start, end: end)
        }
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<SleepStageSeries?, Error>) in
            #if swift(>=5.7)
            let sp = _SendablePredicate(value: HKQuery.predicateForSamples(withStart: start, end: end, options: []))
            #else
            let sp = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            #endif
            let localPredicate = sp.value
            let query = HKSampleQuery(sampleType: type, predicate: localPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else { cont.resume(returning: nil); return }
                // 上传给服务端的也要先去重，否则服务端侧的分析同样会看到翻倍的睡眠
                let resolved = SleepSampleResolver.resolve(samples: samples, window: (start: start, end: end))
                var deep: [HealthSeriesData.SleepStagePoint] = []
                var rem: [HealthSeriesData.SleepStagePoint] = []
                var light: [HealthSeriesData.SleepStagePoint] = []
                var unspecified: [HealthSeriesData.SleepStagePoint] = []
                var awake: [HealthSeriesData.SleepStagePoint] = []
                for segment in resolved.segments {
                    let point = HealthSeriesData.SleepStagePoint(
                        startTs: Int(segment.start.timeIntervalSince1970),
                        endTs: Int(segment.end.timeIntervalSince1970),
                        duration: segment.duration
                    )
                    switch segment.stage {
                    case .deep: deep.append(point)
                    case .rem: rem.append(point)
                    case .core: light.append(point)
                    // unspecified 以前并进 light 上传，服务端因此拿到的 light 和
                    // App 显示的 Core 对不上（苹果健康不把它算进 Core）
                    case .unspecified: unspecified.append(point)
                    // awake 以前直接丢弃，服务端因此还原不出睡眠效率和入睡用时
                    case .awake: awake.append(point)
                    }
                }
                // inBed 是与阶段重叠的独立一轨，取并集去重后的原始片段
                let inBed = resolved.inBedSegments.map {
                    HealthSeriesData.SleepStagePoint(
                        startTs: Int($0.start.timeIntervalSince1970),
                        endTs: Int($0.end.timeIntervalSince1970),
                        duration: $0.end.timeIntervalSince($0.start)
                    )
                }
                cont.resume(returning: (deep: deep, rem: rem, light: light, unspecified: unspecified, awake: awake, inBed: inBed))
            }
            self.healthStore.execute(query)
        }
    }
    

    // MARK: - Sleep Statistics

    /// 拉取 [start, end) 内的睡眠样本，供下面各统计函数复用。
    /// 不在这里裁剪 / 归类，归一化统一交给 SleepSampleResolver。
    private func fetchSleepSamples(start: Date, end: Date) async throws -> [HKCategorySample] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis), end > start else { return [] }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKCategorySample], Error>) in
            #if swift(>=5.7)
            let predicateSendable = _SendablePredicate(value: HKQuery.predicateForSamples(withStart: start, end: end, options: []))
            #else
            let predicateSendable = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            #endif
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicateSendable.value,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error { cont.resume(throwing: error); return }
                cont.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            self.healthStore.execute(query)
        }
    }

    /// 「睡眠日」窗口：[displayDay 前一天 18:00, displayDay 18:00)。
    /// 与 fetchSleepDailyAggregates / sleepDay(forSleepEnd:) 同一套 6pm 归属规则 ——
    /// 一晚归到**起床日**，跟苹果健康一致。
    private func sleepDayWindow(for displayDay: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .hour, value: 18, to: calendar.startOfDay(for: displayDay)) ?? displayDay
        let start = calendar.date(byAdding: .day, value: -1, to: end) ?? end
        return (start, end)
    }

    /// 按睡眠日逐天解析出实际睡眠时长（小时）。返回值与 displayDays 一一对应。
    private func sleepHoursPerDay(displayDays: [Date]) async throws -> [Double] {
        guard let first = displayDays.first, let last = displayDays.last else { return [] }
        let queryStart = sleepDayWindow(for: first).start
        let queryEnd = sleepDayWindow(for: last).end
        let samples = try await fetchSleepSamples(start: queryStart, end: min(queryEnd, Date()))
        guard !samples.isEmpty else { return Array(repeating: 0, count: displayDays.count) }

        return displayDays.map { day in
            let window = sleepDayWindow(for: day)
            return SleepSampleResolver.resolve(samples: samples, window: window).totalAsleep / 3600.0
        }
    }

    /// 一段区间内「有数据的睡眠日」的日均睡眠时长。没有任何一天有数据返回 0。
    private func averageSleepHours(displayDays: [Date]) async throws -> Double {
        let perDay = try await sleepHoursPerDay(displayDays: displayDays)
        let tracked = perDay.filter { $0 > 0 }
        guard !tracked.isEmpty else { return 0 }
        return tracked.reduce(0, +) / Double(tracked.count)
    }

    private func days(from start: Date, count: Int) -> [Date] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: startDay) }
    }

    /// 获取指定时间段内每天的睡眠时长
    func fetchDailySleepHours(
        startDate: Date,
        endDate: Date,
        days count: Int
    ) async throws -> [Double] {
        let calendar = Calendar.current
        // endDate 是窗口的开区间右端（次日 0 点），最后一个 displayDay 是它的前一天
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: endDate)),
              let firstDay = calendar.date(byAdding: .day, value: -(count - 1), to: lastDay) else {
            return Array(repeating: 0, count: count)
        }
        return try await sleepHoursPerDay(displayDays: days(from: firstDay, count: count))
    }

    /// 获取指定时间段内每周的睡眠时长（该周有数据的夜的日均）
    func fetchWeeklySleepHours(
        startDate: Date,
        endDate: Date,
        weeks: Int
    ) async throws -> [Double] {
        let calendar = Calendar.current
        var results: [Double] = []
        for weekOffset in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeks + weekOffset, to: endDate) else {
                results.append(0)
                continue
            }
            results.append(try await averageSleepHours(displayDays: days(from: weekStart, count: 7)))
        }
        return results
    }

    /// 获取指定时间段内每月的睡眠时长（该月有数据的夜的日均）
    func fetchMonthlySleepHours(
        startDate: Date,
        endDate: Date,
        months: Int
    ) async throws -> [Double] {
        let calendar = Calendar.current
        var results: [Double] = []
        for monthOffset in 0..<months {
            guard let monthStart = calendar.date(byAdding: .month, value: -months + monthOffset, to: endDate),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart),
                  let dayCount = calendar.dateComponents([.day], from: monthStart, to: monthEnd).day else {
                results.append(0)
                continue
            }
            results.append(try await averageSleepHours(displayDays: days(from: monthStart, count: dayCount)))
        }
        return results
    }

    /// 获取每周的睡眠时长（周日到周六为一个周期，用于6个月视图）
    func fetchWeeklySleepHoursSundayToSaturday(
        startSunday: Date,
        weeks: Int
    ) async throws -> [Double] {
        let calendar = Calendar.current
        var results: [Double] = []
        for weekOffset in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .day, value: weekOffset * 7, to: startSunday) else {
                results.append(0)
                continue
            }
            results.append(try await averageSleepHours(displayDays: days(from: weekStart, count: 7)))
        }
        return results
    }

    /// 获取每小时的睡眠时长（用于日视图）。
    /// 先按整段窗口归一化再切小时，避免样本被小时边界截断后各来源排序不一致。
    func fetchHourlySleepHours(
        startDate: Date,
        hours: Int
    ) async throws -> [Double] {
        let calendar = Calendar.current
        guard let windowEnd = calendar.date(byAdding: .hour, value: hours, to: startDate) else {
            return Array(repeating: 0, count: hours)
        }
        let samples = try await fetchSleepSamples(start: startDate, end: windowEnd)
        let resolved = SleepSampleResolver.resolve(samples: samples, window: (start: startDate, end: windowEnd))
        let asleep = resolved.segments.filter { $0.stage.isAsleep }

        return (0..<hours).map { hourOffset in
            guard let hourStart = calendar.date(byAdding: .hour, value: hourOffset, to: startDate),
                  let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else { return 0 }
            let seconds = asleep.reduce(0.0) { partial, segment in
                let overlapStart = max(segment.start, hourStart)
                let overlapEnd = min(segment.end, hourEnd)
                return overlapEnd > overlapStart ? partial + overlapEnd.timeIntervalSince(overlapStart) : partial
            }
            return seconds / 3600.0
        }
    }

    /// 获取今天0-23时每小时的睡眠时长（用于日视图），未来的小时返回 0
    func fetchHourlySleepHoursForToday(
        startDate: Date,
        currentHour: Int
    ) async throws -> [Double] {
        let hourly = try await fetchHourlySleepHours(startDate: startDate, hours: 24)
        return hourly.enumerated().map { index, value in index > currentHour ? 0 : value }
    }
}
