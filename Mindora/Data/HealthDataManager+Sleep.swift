import Foundation
import HealthKit

extension HealthDataManager {
    
    // MARK: - Sleep Summary
    
    func fetchSleepSummary() async throws -> HealthMetrics.SleepValue? {
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
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HealthMetrics.SleepValue?, Error>) in
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

                let summary = HealthMetrics.SleepValue(
                    totalSleepHours: total / 3600.0,
                    deepSleepHours: deep > 0 ? deep / 3600.0 : nil,
                    remSleepHours: rem > 0 ? rem / 3600.0 : nil,
                    lightSleepHours: light > 0 ? light / 3600.0 : nil,
                    timeInBed: inBed > 0 ? inBed / 3600.0 : nil,
                    date: latestStageSample.endDate
                )
                cont.resume(returning: summary)
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Sleep Stage Data (for Sleep Graph)
    
    /// 获取最近一次睡眠的详细阶段数据
    func fetchLatestSleepStages(forceLive: Bool = false) async throws -> [SleepStageDetail] {
        // Debug 模式：返回模拟数据
        if DesignConstants.isDebugMode && !forceLive {
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

    func fetchSleepDailyAggregates(startingFrom startDay: Date, days: Int) async throws -> [SleepDailyAggregate] {
        guard days > 0, let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }

        let calendar = Calendar.current
        let normalizedStartDay = calendar.startOfDay(for: startDay)
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

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[SleepDailyAggregate], Error>) in
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

                    func earliest(_ lhs: Date?, _ rhs: Date) -> Date {
                        guard let lhs else { return rhs }
                        return min(lhs, rhs)
                    }

                    var totalSleep: TimeInterval = 0
                    var deepSleep: TimeInterval = 0
                    var remSleep: TimeInterval = 0
                    var coreSleep: TimeInterval = 0
                    var awake: TimeInterval = 0
                    var inBed: TimeInterval = 0
                    var firstInBedStart: Date?
                    var firstAwakeOrStageStart: Date?
                    var firstAsleepStart: Date?

                    for sample in rawSamples {
                        if sample.endDate <= windowStart || sample.startDate >= windowEnd {
                            continue
                        }

                        let clippedStart = max(sample.startDate, windowStart)
                        let clippedEnd = min(sample.endDate, windowEnd)
                        let duration = clippedEnd.timeIntervalSince(clippedStart)
                        if duration <= 0 { continue }

                        if #available(iOS 16.0, *) {
                            switch sample.value {
                            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                                inBed += duration
                                firstInBedStart = earliest(firstInBedStart, clippedStart)
                            case HKCategoryValueSleepAnalysis.awake.rawValue:
                                awake += duration
                                firstAwakeOrStageStart = earliest(firstAwakeOrStageStart, clippedStart)
                            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                                deepSleep += duration
                                totalSleep += duration
                                firstAsleepStart = earliest(firstAsleepStart, clippedStart)
                                firstAwakeOrStageStart = earliest(firstAwakeOrStageStart, clippedStart)
                            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                                remSleep += duration
                                totalSleep += duration
                                firstAsleepStart = earliest(firstAsleepStart, clippedStart)
                                firstAwakeOrStageStart = earliest(firstAwakeOrStageStart, clippedStart)
                            case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                 HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                                coreSleep += duration
                                totalSleep += duration
                                firstAsleepStart = earliest(firstAsleepStart, clippedStart)
                                firstAwakeOrStageStart = earliest(firstAwakeOrStageStart, clippedStart)
                            default:
                                break
                            }
                        } else {
                            switch sample.value {
                            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                                inBed += duration
                                firstInBedStart = earliest(firstInBedStart, clippedStart)
                            case HKCategoryValueSleepAnalysis.awake.rawValue:
                                awake += duration
                                firstAwakeOrStageStart = earliest(firstAwakeOrStageStart, clippedStart)
                            case HKCategoryValueSleepAnalysis.asleep.rawValue:
                                coreSleep += duration
                                totalSleep += duration
                                firstAsleepStart = earliest(firstAsleepStart, clippedStart)
                                firstAwakeOrStageStart = earliest(firstAwakeOrStageStart, clippedStart)
                            default:
                                break
                            }
                        }
                    }

                    let onsetReference = firstInBedStart ?? firstAwakeOrStageStart
                    let sleepOnsetMinutes: Double?
                    if let onsetReference, let firstAsleepStart, firstAsleepStart >= onsetReference {
                        sleepOnsetMinutes = firstAsleepStart.timeIntervalSince(onsetReference) / 60.0
                    } else {
                        sleepOnsetMinutes = nil
                    }

                    return SleepDailyAggregate(
                        date: displayDay,
                        totalSleepHours: totalSleep / 3600.0,
                        deepSleepHours: deepSleep / 3600.0,
                        remSleepHours: remSleep / 3600.0,
                        coreSleepHours: coreSleep / 3600.0,
                        awakeMinutes: awake / 60.0,
                        timeInBedHours: inBed / 3600.0,
                        sleepOnsetMinutes: sleepOnsetMinutes
                    )
                }

                cont.resume(returning: aggregates)
            }

            self.healthStore.execute(query)
        }
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
    
    func fetchSleepStages(start: Date, end: Date) async throws -> (deep: [HealthSeriesData.SleepStagePoint], rem: [HealthSeriesData.SleepStagePoint], light: [HealthSeriesData.SleepStagePoint])? {
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
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Sleep Statistics
    
    /// 获取指定时间段内每天的睡眠时长
    func fetchDailySleepHours(
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
                
                self.healthStore.execute(query)
            }
            
            results.append(sleepHours)
        }
        
        return results
    }
    
    /// 获取指定时间段内每周的睡眠时长（平均每天）
    func fetchWeeklySleepHours(
        startDate: Date,
        endDate: Date,
        weeks: Int
    ) async throws -> [Double] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
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
            
            let predicate = HKQuery.predicateForSamples(withStart: weekStart, end: weekEnd, options: [])
            
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
                
                self.healthStore.execute(query)
            }
            
            results.append(avgSleepHours)
        }
        
        return results
    }
    
    /// 获取指定时间段内每月的睡眠时长
    func fetchMonthlySleepHours(
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
                
                self.healthStore.execute(query)
            }
            
            results.append(avgSleepHours)
        }
        
        return results
    }
    
    /// 获取今天0-23时每小时的睡眠时长（用于日视图）
    /// 只获取到当前小时的数据，未来时间返回0
    func fetchHourlySleepHoursForToday(
        startDate: Date,
        currentHour: Int
    ) async throws -> [Double] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
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
            
            let predicate = HKQuery.predicateForSamples(withStart: hourStart, end: hourEnd, options: [])
            
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
                            let sampleStart = max(sample.startDate, hourStart)
                            let sampleEnd = min(sample.endDate, hourEnd)
                            if sampleEnd > sampleStart {
                                totalSeconds += sampleEnd.timeIntervalSince(sampleStart)
                            }
                        }
                    }
                    
                    // 返回该小时内的睡眠时长（小时）
                    cont.resume(returning: totalSeconds / 3600.0)
                }
                
                self.healthStore.execute(query)
            }
            
            results.append(sleepHours)
        }
        
        return results
    }
    
    /// 获取每小时的睡眠时长（用于日视图）
    func fetchHourlySleepHours(
        startDate: Date,
        hours: Int
    ) async throws -> [Double] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
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
            
            let predicate = HKQuery.predicateForSamples(withStart: hourStart, end: hourEnd, options: [])
            
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
                            // 计算该小时内的睡眠时间
                            let overlapStart = max(sample.startDate, hourStart)
                            let overlapEnd = min(sample.endDate, hourEnd)
                            if overlapEnd > overlapStart {
                                totalSeconds += overlapEnd.timeIntervalSince(overlapStart)
                            }
                        }
                    }
                    
                    cont.resume(returning: totalSeconds / 3600.0)
                }
                
                self.healthStore.execute(query)
            }
            
            results.append(sleepHours)
        }
        
        return results
    }
    
    /// 获取每周的睡眠时长（周日到周六为一个周期，用于6个月视图）
    func fetchWeeklySleepHoursSundayToSaturday(
        startSunday: Date,
        weeks: Int
    ) async throws -> [Double] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
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
            
            let predicate = HKQuery.predicateForSamples(withStart: weekStart, end: weekEnd, options: [])
            
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
                    
                    let totalHours = dailySleepHours.values.reduce(0, +) / 3600.0
                    let avgHours = dailySleepHours.isEmpty ? 0 : totalHours / Double(dailySleepHours.count)
                    
                    cont.resume(returning: avgHours)
                }
                
                self.healthStore.execute(query)
            }
            
            results.append(avgSleepHours)
        }
        
        return results
    }
}
