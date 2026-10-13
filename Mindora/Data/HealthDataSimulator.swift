import Foundation

/// 构造健康数据的档位。
enum HealthSimulationQuality: String, CaseIterable {
    case good
    case fair
    case poor

    var displayName: String {
        switch self {
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        }
    }
}

/// 只替换「本地健康数据」这一层 —— 也就是 HealthKit 的读取结果。
///
/// 与三击 logo 的 `Constants.Config.showMockData` **完全是两回事**，两者互不影响：
///   * `showMockData`：把整屏（含服务端下发的卡片、评分、文案）换成一套静态假数据，用来看排版；
///   * 本模拟器：只伪造 HealthKit，分析接口 / 首页 dashboard / 健康数据上传**全部照常走服务端**。
///
/// 目的是测试机上往往一条健康数据都没有，服务端就拿不到东西可算。打开它之后
/// `HealthSyncService` 上传的就是这里构造出来的序列，服务端即可正常联调。
///
/// 一切都从 `night(for:)` 这一个生成器派生：日/周/月视图看到的、和上传给服务端的，
/// 是同一份数据，不会出现「界面显示 8 小时、上传上去 4 小时」。
final class HealthDataSimulator {
    static let shared = HealthDataSimulator()

    /// 档位切换（含开关）时发出，首页与健康页据此立即重刷。
    static let didChangeNotification = Notification.Name("HealthDataSimulator.didChange")

    private static let timelineDefaultsKey = "debug.health_simulation_timeline"

    /// 首次开启时铺多少天历史。够月视图（30 天）用即可 —— 半年/年视图会因此偏空，
    /// 那两个视图本来也不是这套构造数据要覆盖的重点。
    private static let historyDays = 30

    /// 往回找「最近一晚」时的回溯上限。比 historyDays 宽一些，
    /// 好跨过「关闭过一段时间」在时间线上留下的空洞。
    private static let lookbackDays = 60

    private init() {}

    // MARK: - 档位时间线

    /// 「从某天起用哪个档位」。存成时间线而不是单个当前值，是因为真实的人本来就有好有坏：
    /// 切换档位只影响生效日往后，更早的日子保持切换前的档位，于是能攒出一段
    /// 「前一阵睡得好、最近变差」的混合历史。
    ///
    /// 副作用同样重要：历史值不再被改写，也就不会给服务端对同一天先后送两个不同的值。
    private struct Segment: Codable {
        /// 生效起始日（local 00:00 的 Unix 秒）
        let startDayTs: Int
        /// nil 表示这段时间是关闭状态（读真实 HealthKit）
        let quality: String?
    }

    /// 按 startDayTs 升序。
    private lazy var segments: [Segment] = {
        #if DEBUG
        guard let data = UserDefaults.standard.data(forKey: Self.timelineDefaultsKey),
              let decoded = try? JSONDecoder().decode([Segment].self, from: data) else { return [] }
        return decoded.sorted { $0.startDayTs < $1.startDayTs }
        #else
        return []
        #endif
    }()

    // MARK: - App 审核演示账号

    /// 演示账号固定用「良好」档：审核员看的是功能完整性，不是数据好坏，
    /// 档位恒定也让每次审核看到的画面一致，便于复现问题。
    private static let appReviewDemoQuality: HealthSimulationQuality = .good

    /// 当前登录的是不是 App 审核演示账号。
    ///
    /// 刻意做成**从 AuthStorage 派生的只读属性**而不是存一个开关：没有状态要同步，
    /// 杀进程重启后自动恢复，登出即自动失效 —— `clearLoginInfoKeepingEmail` 会保留
    /// 邮箱但清掉 isLoggedIn，所以退到登录页时这里就是 false 了。
    ///
    /// 与上面 `#if DEBUG` 的档位时间线是两套独立机制：这里不落盘、不复用那份
    /// UserDefaults、也没有任何 UI 入口，唯一触发条件就是登录了写死的那个邮箱。
    var isAppReviewDemoAccount: Bool {
        guard UserDefaults.standard.bool(forKey: Constants.Storage.UserDefaults.isLoggedIn) else { return false }
        guard let email = AuthStorage.shared.email?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !email.isEmpty else { return false }
        return email == Constants.Network.appReviewDemoEmail.lowercased()
    }

    /// 上一次已生效的演示态。只用来识别翻转，不作为判据 —— 判据永远是上面那个派生属性。
    private var lastAppReviewDemoState = false

    /// 启动时调用：只把「上次已生效的演示态」对齐，**不作废任何缓存**。
    ///
    /// lastAppReviewDemoState 是内存态，每次冷启动都从 false 开始。若启动时直接走
    /// refresh，演示账号每启动一次就会把 SyncSliceRecord / UploadStateStore 清空、
    /// 把 30 天数据重传一遍。而冷启动本来就没有内存缓存，磁盘上的上传进度又是上次
    /// 真实上传的结果，本就该沿用。
    func primeAppReviewDemoState() {
        lastAppReviewDemoState = isAppReviewDemoAccount
        if lastAppReviewDemoState {
            Log.info("HealthDataSimulator", "app-review demo simulation active on launch")
        }
    }

    /// 由登录/登出/启动这三个收口调用，在演示态翻转时作废缓存与上传进度。
    ///
    /// 不这么做的话：HealthDataManager 的查询缓存还是切换前的结果，SyncSliceRecord
    /// 又把那些天记成「已上传」，构造出来的数据根本不会发给服务端，分析页仍然是空的。
    func refreshAppReviewDemoMode() {
        let active = isAppReviewDemoAccount
        guard active != lastAppReviewDemoState else { return }
        lastAppReviewDemoState = active
        // 开 = 整段历史是新造的；关 = 整段都要换回真机数据。两个方向都必须全量重来。
        Task { await HealthDataManager.shared.queryCache.removeAll() }
        HealthDataManager.shared.clearMostRecentSleepDayCache()
        SyncSliceRecord.shared.reset()
        UploadStateStore.shared.reset()
        Log.info("HealthDataSimulator", "app-review demo simulation => \(active ? "on" : "off")")
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// 某一天用哪个档位。nil = 那天没有构造数据。
    func quality(for day: Date) -> HealthSimulationQuality? {
        // App 审核演示账号：这一条是 Release 包里唯一能走到构造数据的路径。
        // 优先于下面的调试时间线判断，且铺满固定窗口，档位恒定。
        if isAppReviewDemoAccount {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let earliest = calendar.date(byAdding: .day, value: -Self.historyDays, to: today) else { return nil }
            let target = calendar.startOfDay(for: day)
            // 只铺最近 historyDays 天：够日/周/月视图，也让上传量有界 ——
            // 开启时会整段作废上传进度全量重传，铺一整年会白白推几百天数据上去。
            guard target >= earliest, target <= today else { return nil }
            return Self.appReviewDemoQuality
        }
        let ts = Int(Calendar.current.startOfDay(for: day).timeIntervalSince1970)
        guard let segment = segments.last(where: { $0.startDayTs <= ts }) else { return nil }
        return segment.quality.flatMap(HealthSimulationQuality.init(rawValue:))
    }

    /// 当前档位（今天生效的那一档）；nil 表示关闭，走真实 HealthKit。
    var quality: HealthSimulationQuality? { quality(for: Date()) }

    var isEnabled: Bool { quality != nil }

    #if DEBUG
    func enable(_ quality: HealthSimulationQuality) {
        applySegment(quality: quality.rawValue)
    }

    func disable() {
        applySegment(quality: nil)
    }

    /// 切换生效日取「最近一晚有数据的那一天」，而不是今天。
    ///
    /// 今天这一晚往往还没生成（比如现在是晚上，或最近一晚其实是昨天），若从今天起生效，
    /// 日视图仍然锚定在最近一晚、显示的还是旧档位 —— 切了看不出变化，没法测。
    /// 锚到最近一晚，切完立刻就能看到新档位。
    private func applySegment(quality: String?) {
        let calendar = Calendar.current
        let effectiveDay = mostRecentNight()?.day ?? calendar.startOfDay(for: Date())
        let ts = Int(effectiveDay.timeIntervalSince1970)

        let isFirstEnable = segments.isEmpty && quality != nil
        // 同一天反复切就地覆盖，不要在时间线上堆一串同日的段。
        segments.removeAll { $0.startDayTs >= ts }
        if isFirstEnable {
            // 首次开启：把整段历史一并铺上，否则周/月视图和服务端都没有历史可用。
            let historyStart = calendar.date(byAdding: .day, value: -Self.historyDays, to: effectiveDay) ?? effectiveDay
            segments.append(Segment(startDayTs: Int(historyStart.timeIntervalSince1970), quality: quality))
        }
        segments.append(Segment(startDayTs: ts, quality: quality))
        segments.sort { $0.startDayTs < $1.startDayTs }
        persistTimeline()

        notifyChanged(effectiveDay: effectiveDay, rebuiltHistory: isFirstEnable)
    }

    private func persistTimeline() {
        guard let data = try? JSONEncoder().encode(segments) else { return }
        UserDefaults.standard.set(data, forKey: Self.timelineDefaultsKey)
    }

    private func notifyChanged(effectiveDay: Date, rebuiltHistory: Bool) {
        // HealthDataManager 的查询缓存里可能还是切换前的数据，不清会看到上一档位的残留。
        // 睡眠日锚点同理：它是同步缓存，不重置的话视图会对齐到旧的那一天。
        Task { await HealthDataManager.shared.queryCache.removeAll() }
        HealthDataManager.shared.clearMostRecentSleepDayCache()

        // 上传进度要作废，否则新构造的数据发不出去 —— 这会直接让整套机制失效：
        //   * SyncSliceRecord 把「那天已上传」记成完成态，之后连数据都不会去拉；
        //     测试机没有健康数据时，那些天恰恰是以「空切片」被标记完成的（见 HealthSyncService）；
        //   * UploadStateStore 的 lastTs 会把时间戳更早的样本当成重复丢掉。
        //
        // 但只作废生效日往后：更早的历史这次没变，整段重传等于给服务端送一遍重复数据。
        // 首次开启是例外 —— 那次整段历史都是新造出来的，必须全部重传。
        if rebuiltHistory {
            SyncSliceRecord.shared.reset()
        } else {
            SyncSliceRecord.shared.invalidateDays(from: effectiveDay)
        }
        UploadStateStore.shared.reset()

        Log.info("HealthDataSimulator", "simulation => \(quality?.rawValue ?? "off") effectiveFrom=\(effectiveDay) rebuiltHistory=\(rebuiltHistory)")
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
    #endif

    // MARK: - 档位参数

    struct Profile {
        /// 上床时刻，以「起床日前一天 20:00」为零点的分钟偏移。
        let bedTimeOffsetMinutes: Double
        let totalSleepHours: Double
        let onsetMinutes: Double
        let awakeMinutes: Double
        /// 三个睡眠阶段占「睡着时长」的比例，三者相加为 1。
        let remRatio: Double
        let coreRatio: Double
        let deepRatio: Double
        let restingHeartRate: Double
        let hrv: Double
        let respiratoryRate: Double
        let wristTemperature: Double
        /// 一晚拆成几个睡眠周期。
        let sleepCycles: Int
        /// 有数据的天数占比。只用来制造「偶尔没戴表」的少量空档 —— 不能缺太多，
        /// 缺口一多周/月视图和服务端的统计就没样本可算了，反而测不出东西。
        let coverage: Double
        /// 白天清醒时的心率基准。
        let daytimeHeartRate: Double
    }

    /// 某一天生效的档位参数。时间线上不同日子可能是不同档位，取值一律按天问。
    func profile(on day: Date) -> Profile { Self.profile(for: quality(for: day) ?? .good) }

    static func profile(for quality: HealthSimulationQuality) -> Profile {
        switch quality {
        case .good:
            // 22:30 上床，8 分钟入睡，睡足 7.9 小时，夜醒 12 分钟。
            return Profile(
                bedTimeOffsetMinutes: 150,
                totalSleepHours: 7.9, onsetMinutes: 8, awakeMinutes: 12,
                remRatio: 0.23, coreRatio: 0.55, deepRatio: 0.22,
                restingHeartRate: 54, hrv: 62, respiratoryRate: 14, wristTemperature: 36.4,
                sleepCycles: 5, coverage: 1.0, daytimeHeartRate: 72
            )
        case .fair:
            // 23:40 上床，22 分钟入睡，睡 6.4 小时，夜醒 34 分钟。
            return Profile(
                bedTimeOffsetMinutes: 220,
                totalSleepHours: 6.4, onsetMinutes: 22, awakeMinutes: 34,
                remRatio: 0.19, coreRatio: 0.65, deepRatio: 0.16,
                restingHeartRate: 64, hrv: 38, respiratoryRate: 16, wristTemperature: 36.6,
                sleepCycles: 4, coverage: 0.95, daytimeHeartRate: 82
            )
        case .poor:
            // 01:10 才上床，48 分钟入睡，只睡 4.6 小时，夜醒 72 分钟。
            return Profile(
                bedTimeOffsetMinutes: 310,
                totalSleepHours: 4.6, onsetMinutes: 48, awakeMinutes: 72,
                remRatio: 0.15, coreRatio: 0.74, deepRatio: 0.11,
                restingHeartRate: 76, hrv: 21, respiratoryRate: 19, wristTemperature: 36.9,
                sleepCycles: 3, coverage: 0.92, daytimeHeartRate: 92
            )
        }
    }

    // MARK: - 一晚睡眠

    struct Night {
        struct Stage {
            enum Kind { case awake, core, deep, rem }
            let kind: Kind
            let start: Date
            let end: Date
            var duration: TimeInterval { end.timeIntervalSince(start) }
        }

        /// 起床日（按 HealthDataManager 的 6pm 归属规则）。
        let day: Date
        let inBedStart: Date
        let sleepStart: Date
        let sleepEnd: Date
        let inBedEnd: Date
        let stages: [Stage]

        let restingHeartRate: Double
        let hrv: Double
        let respiratoryRate: Double
        let wristTemperature: Double

        func hours(of kind: Stage.Kind) -> Double {
            stages.filter { $0.kind == kind }.reduce(0) { $0 + $1.duration } / 3600.0
        }

        var totalSleepHours: Double { hours(of: .core) + hours(of: .deep) + hours(of: .rem) }

        /// 夜间清醒：**不含**入睡前那段。那一段已经由 `onsetMinutes` 表达，
        /// 一并计入的话日视图上「入睡耗时」和「Awake」会把同一段时间数两遍。
        var awakeMinutes: Double {
            stages
                .filter { $0.kind == .awake && $0.start >= sleepStart }
                .reduce(0) { $0 + $1.duration } / 60.0
        }
        var timeInBedHours: Double { inBedEnd.timeIntervalSince(inBedStart) / 3600.0 }
        var onsetMinutes: Double { sleepStart.timeIntervalSince(inBedStart) / 60.0 }
    }

    /// 生成起床日为 `day` 的那一晚。返回 nil 表示这天没有数据
    /// （未来的日期，或按 coverage 抽中的「没戴表」的一天）。
    func night(for day: Date) -> Night? {
        // 当前关闭时一律不给数据：关闭的含义就是「读这台真机的健康数据」，
        // 时间线上的历史档位不该在关闭状态下还冒出来。
        guard isEnabled else { return nil }
        let calendar = Calendar.current
        let displayDay = calendar.startOfDay(for: day)
        // 用这一天自己的档位，而不是当前档位 —— 时间线的意义就在这里。
        guard let dayQuality = quality(for: displayDay) else { return nil }
        let dayIndex = Self.dayIndex(of: displayDay)

        var seed = UInt64(bitPattern: Int64(dayIndex)) &+ Self.qualitySeed(for: dayQuality)
        let p = Self.profile(for: dayQuality)
        // coverage 抽签必须第一个消费随机数，保证同一天在任何调用点得到同样的结论。
        let covered = random(&seed, 0, 1) <= p.coverage
        guard covered else { return nil }
        // 零点：起床日前一天 20:00。
        let previousDay = calendar.date(byAdding: .day, value: -1, to: displayDay) ?? displayDay
        guard let base = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: previousDay) else { return nil }

        let inBedStart = base.addingTimeInterval((p.bedTimeOffsetMinutes + random(&seed, -25, 25)) * 60)
        let onset = max(2, p.onsetMinutes + random(&seed, -5, 5))
        let sleepStart = inBedStart.addingTimeInterval(onset * 60)

        let totalSleepMinutes = max(60, p.totalSleepHours * 60 + random(&seed, -50, 50))
        let awakeTotal = max(0, p.awakeMinutes + random(&seed, -8, 8))

        var stages: [Night.Stage] = []
        stages.append(.init(kind: .awake, start: inBedStart, end: sleepStart))

        // 深睡集中在前半夜、REM 集中在后半夜 —— 与真实睡眠结构一致。
        let cycles = p.sleepCycles
        let deepWeights = (0..<cycles).map { Double(cycles - $0) }
        let remWeights = (0..<cycles).map { Double($0 + 1) }
        let deepWeightSum = deepWeights.reduce(0, +)
        let remWeightSum = remWeights.reduce(0, +)

        let deepMinutes = totalSleepMinutes * p.deepRatio
        let remMinutes = totalSleepMinutes * p.remRatio
        let coreMinutes = totalSleepMinutes * p.coreRatio
        let awakePerCycle = awakeTotal / Double(cycles)

        var cursor = sleepStart
        func append(_ kind: Night.Stage.Kind, minutes: Double) {
            guard minutes >= 0.5 else { return }
            let end = cursor.addingTimeInterval(minutes * 60)
            stages.append(.init(kind: kind, start: cursor, end: end))
            cursor = end
        }

        for i in 0..<cycles {
            let core = coreMinutes / Double(cycles)
            append(.core, minutes: core * 0.6)
            append(.deep, minutes: deepMinutes * deepWeights[i] / deepWeightSum)
            append(.core, minutes: core * 0.4)
            append(.rem, minutes: remMinutes * remWeights[i] / remWeightSum)
            // 最后一个周期的清醒放到起床前，不再算作夜间片段之间的觉醒。
            if i < cycles - 1 { append(.awake, minutes: awakePerCycle) }
        }

        let sleepEnd = cursor
        // 醒来到真正下床之间还赖一会儿。
        let linger = max(1, awakePerCycle + random(&seed, -3, 5))
        append(.awake, minutes: linger)
        let inBedEnd = cursor

        // 已经生成到未来去了（比如今天还没睡）：这一晚不存在。
        guard inBedEnd <= Date() else { return nil }

        return Night(
            day: displayDay,
            inBedStart: inBedStart,
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            inBedEnd: inBedEnd,
            stages: stages,
            restingHeartRate: (p.restingHeartRate + random(&seed, -3, 3)).rounded(),
            hrv: (p.hrv + random(&seed, -6, 6)).rounded(),
            respiratoryRate: (p.respiratoryRate + random(&seed, -1.5, 1.5)).rounded(),
            wristTemperature: p.wristTemperature + random(&seed, -0.2, 0.2)
        )
    }

    /// 最近一晚有数据的睡眠。往回找 historyDays 天。
    func mostRecentNight(before reference: Date = Date()) -> Night? {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: reference)
        for _ in 0...Self.lookbackDays {
            if let night = night(for: day) { return night }
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return nil
    }

    /// 与某个时间区间有重叠的所有夜晚。
    func nights(from start: Date, to end: Date) -> [Night] {
        let calendar = Calendar.current
        // 一晚可能从前一天晚上开始，往前多取一天。
        var day = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: start)) ?? start
        let lastDay = calendar.startOfDay(for: end)
        var result: [Night] = []
        while day <= lastDay {
            if let night = night(for: day), night.inBedEnd > start, night.inBedStart < end {
                result.append(night)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    // MARK: - 派生：指标 / 阶段 / 聚合

    func latestMetrics() -> HealthMetrics {
        guard let night = mostRecentNight() else {
            return HealthMetrics(lastUpdated: nil)
        }
        return HealthMetrics(
            heartRate: .init(value: latestDaytimeHeartRate(), date: Date()),
            heartRateVariability: .init(value: night.hrv, date: night.sleepEnd),
            respiratoryRate: .init(value: night.respiratoryRate, date: night.sleepEnd),
            restingHeartRate: .init(value: night.restingHeartRate, date: night.sleepEnd),
            sleepingWristTemperature: .init(value: night.wristTemperature, date: night.sleepEnd),
            bodyTemperature: .init(value: night.wristTemperature, date: night.sleepEnd),
            sleepSummary: sleepValue(from: night),
            lastUpdated: Date(),
            sleepHeartRateRange: sleepHeartRateRange()
        )
    }

    func sleepValue(from night: Night) -> HealthMetrics.SleepValue {
        HealthMetrics.SleepValue(
            totalSleepHours: night.totalSleepHours,
            deepSleepHours: night.hours(of: .deep),
            remSleepHours: night.hours(of: .rem),
            lightSleepHours: night.hours(of: .core),
            timeInBed: night.timeInBedHours,
            date: night.sleepEnd
        )
    }

    /// 最近一晚睡眠期间的心率区间。直接复用 series() 生成的样本，
    /// 保证 UI 上显示的区间和上传给服务端的心率序列同源。
    func sleepHeartRateRange() -> HealthDataManager.HeartRateRangePoint {
        guard let night = mostRecentNight() else { return .empty }
        let values = series(from: night.sleepStart, to: night.sleepEnd, maxSamples: Int.max).heartRate.map(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else { return .empty }
        return .init(min: minValue, max: maxValue)
    }

    /// 包含 `date` 那一晚的整晚睡眠心率区间。与真机路径同口径：
    /// 跨午夜被切成两片时，两片算出的是同一个区间。
    func sleepHeartRateRange(forNightContaining date: Date) -> (sessionStart: Date, sessionEnd: Date, min: Double, max: Double)? {
        let probeStart = date.addingTimeInterval(-36 * 3600)
        let probeEnd = date.addingTimeInterval(36 * 3600)
        guard let night = nights(from: probeStart, to: probeEnd)
            .first(where: { $0.inBedStart <= date && date <= $0.inBedEnd }) else { return nil }
        let values = series(from: night.sleepStart, to: night.sleepEnd, maxSamples: Int.max).heartRate.map(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else { return nil }
        return (night.sleepStart, night.sleepEnd, minValue, maxValue)
    }

    /// 周/月生命体征卡的构造数据，与真机 fetchSleepVitalsAverages 同口径：
    /// 心率取每晚睡眠跨度内的均值再按晚等权平均；其余三项每晚本就是标量，直接平均。
    func sleepVitalsAverages(days: Int, endingAt anchorDate: Date) -> HealthDataManager.SleepVitalsAverages {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchorDate)
        let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: anchorDay) ?? anchorDay
        let probeStart = calendar.date(byAdding: .day, value: -1, to: startDay) ?? startDay
        let probeEnd = calendar.date(byAdding: .day, value: 1, to: anchorDay) ?? anchorDay

        let selected = nights(from: probeStart, to: probeEnd).filter { $0.day >= startDay && $0.day <= anchorDay }
        guard !selected.isEmpty else { return HealthDataManager.SleepVitalsAverages() }

        var result = HealthDataManager.SleepVitalsAverages()
        result.nights = selected.count

        var nightlyHeartRates: [Double] = []
        for night in selected {
            // 与真机口径一致：睡眠期间 = 所有阶段区间（含 awake）的并集，
            // 而不是 sleepStart…sleepEnd（那会漏掉入睡前和醒来前的 awake 段）
            guard let first = night.stages.first?.start, let last = night.stages.last?.end else { continue }
            let values = series(from: first, to: last, maxSamples: Int.max).heartRate.map(\.value)
            guard !values.isEmpty else { continue }
            nightlyHeartRates.append(values.reduce(0, +) / Double(values.count))
            result.sleepHeartRateMin = Swift.min(result.sleepHeartRateMin ?? .greatestFiniteMagnitude, values.min() ?? .greatestFiniteMagnitude)
            result.sleepHeartRateMax = Swift.max(result.sleepHeartRateMax ?? -.greatestFiniteMagnitude, values.max() ?? -.greatestFiniteMagnitude)
        }
        func mean(_ v: [Double]) -> Double? { v.isEmpty ? nil : v.reduce(0, +) / Double(v.count) }
        result.sleepHeartRate = mean(nightlyHeartRates)
        result.restingHeartRate = mean(selected.map(\.restingHeartRate))
        result.respiratoryRate = mean(selected.map(\.respiratoryRate))
        result.wristTemperature = mean(selected.map(\.wristTemperature))
        return result
    }

    func latestSleepSummary() -> HealthMetrics.SleepValue? {
        mostRecentNight().map { sleepValue(from: $0) }
    }

    func latestSleepStages() -> [HealthDataManager.SleepStageDetail] {
        guard let night = mostRecentNight() else { return [] }
        return night.stages.map {
            HealthDataManager.SleepStageDetail(
                stage: {
                    switch $0.kind {
                    case .awake: return .awake
                    case .core: return .core
                    case .deep: return .deep
                    case .rem: return .rem
                    }
                }($0),
                startTime: $0.start,
                endTime: $0.end
            )
        }
    }

    func sleepDailyAggregates(startingFrom startDay: Date, days: Int) -> [HealthDataManager.SleepDailyAggregate] {
        let calendar = Calendar.current
        let normalized = calendar.startOfDay(for: startDay)
        return (0..<days).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: normalized) ?? normalized
            guard let night = night(for: day) else {
                return HealthDataManager.SleepDailyAggregate(
                    date: day, totalSleepHours: 0, deepSleepHours: 0, remSleepHours: 0,
                    coreSleepHours: 0, awakeMinutes: 0, timeInBedHours: 0, sleepOnsetMinutes: nil
                )
            }
            return HealthDataManager.SleepDailyAggregate(
                date: day,
                totalSleepHours: night.totalSleepHours,
                deepSleepHours: night.hours(of: .deep),
                remSleepHours: night.hours(of: .rem),
                coreSleepHours: night.hours(of: .core),
                awakeMinutes: night.awakeMinutes,
                timeInBedHours: night.timeInBedHours,
                sleepOnsetMinutes: night.onsetMinutes
            )
        }
    }

    // MARK: - 派生：上传给服务端的原始序列

    /// `HealthSyncService` 走的就是这个 —— 打开模拟后上传给服务端的即是这里构造的样本。
    /// 采样密度刻意贴近 Apple Watch：夜间心率 5 分钟一个点、HRV 30 分钟、呼吸 15 分钟。
    func series(from startDate: Date, to endDate: Date, maxSamples: Int) -> HealthDataManager.HealthSeriesData {
        var result = HealthDataManager.HealthSeriesData()
        guard isEnabled, endDate > startDate else { return result }

        var heartRate: [HealthDataManager.HealthSeriesData.SamplePoint] = []
        var hrv: [HealthDataManager.HealthSeriesData.SamplePoint] = []
        var respiratory: [HealthDataManager.HealthSeriesData.SamplePoint] = []
        var resting: [HealthDataManager.HealthSeriesData.SamplePoint] = []
        var wristTemp: [HealthDataManager.HealthSeriesData.SamplePoint] = []
        var bodyTemp: [HealthDataManager.HealthSeriesData.SamplePoint] = []
        var deep: [HealthDataManager.HealthSeriesData.SleepStagePoint] = []
        var rem: [HealthDataManager.HealthSeriesData.SleepStagePoint] = []
        var light: [HealthDataManager.HealthSeriesData.SleepStagePoint] = []
        var awake: [HealthDataManager.HealthSeriesData.SleepStagePoint] = []
        var inBed: [HealthDataManager.HealthSeriesData.SleepStagePoint] = []

        func inRange(_ date: Date) -> Bool { date >= startDate && date <= endDate }

        for night in nights(from: startDate, to: endDate) {
            // inBed 与阶段重叠，单独一轨；同样要按切片裁剪
            let bedStart = max(night.inBedStart, startDate)
            let bedEnd = min(night.inBedEnd, endDate)
            if bedEnd > bedStart {
                inBed.append(.init(
                    startTs: Int(bedStart.timeIntervalSince1970),
                    endTs: Int(bedEnd.timeIntervalSince1970),
                    duration: bedEnd.timeIntervalSince(bedStart)
                ))
            }
            let nightProfile = profile(on: night.day)
            var seed = UInt64(bitPattern: Int64(Self.dayIndex(of: night.day)))
                &+ Self.qualitySeed(for: quality(for: night.day) ?? .good) &+ 7777

            for stage in night.stages {
                // 阶段区间：睡着三种 + awake，与真实 fetchSleepStages 的口径一致。
                // 跨切片边界的阶段要裁剪后保留，不能整段丢掉 —— 上传是按自然日切片的，
                // 而一晚必然跨过午夜，整段丢弃会让每晚睡前那半截阶段永远传不上去。
                let clippedStart = max(stage.start, startDate)
                let clippedEnd = min(stage.end, endDate)
                if clippedEnd > clippedStart {
                    let point = HealthDataManager.HealthSeriesData.SleepStagePoint(
                        startTs: Int(clippedStart.timeIntervalSince1970),
                        endTs: Int(clippedEnd.timeIntervalSince1970),
                        duration: clippedEnd.timeIntervalSince(clippedStart)
                    )
                    switch stage.kind {
                    case .deep: deep.append(point)
                    case .rem: rem.append(point)
                    case .core: light.append(point)
                    case .awake: awake.append(point)
                    }
                }

                // 夜间心率：每 5 分钟一个点，值随阶段走（深睡最低、清醒最高）。
                let offset: Double
                switch stage.kind {
                case .deep: offset = -6
                case .core: offset = 0
                case .rem: offset = 5
                case .awake: offset = 13
                }
                var t = stage.start
                while t < stage.end {
                    if inRange(t) {
                        let value = (night.restingHeartRate + offset + random(&seed, -3, 3)).rounded()
                        heartRate.append(.init(timestamp: Int(t.timeIntervalSince1970), value: value))
                    }
                    t = t.addingTimeInterval(5 * 60)
                }
            }

            // HRV / 呼吸：睡着的时间段内定频采样。
            var t = night.sleepStart
            while t < night.sleepEnd {
                if inRange(t) {
                    hrv.append(.init(timestamp: Int(t.timeIntervalSince1970), value: (night.hrv + random(&seed, -8, 8)).rounded()))
                }
                t = t.addingTimeInterval(30 * 60)
            }
            t = night.sleepStart
            while t < night.sleepEnd {
                if inRange(t) {
                    // 保留一位小数：先加随机量再整体 ×10 取整。原来写成
                    // (rate + random * 10).rounded() / 10，等于把整个和除以 10，
                    // 生成出来的是 -0.1~2.9 而不是 12.5~15.5，还可能是负数。
                    let value = ((night.respiratoryRate + random(&seed, -1.5, 1.5)) * 10).rounded() / 10
                    respiratory.append(.init(timestamp: Int(t.timeIntervalSince1970), value: value))
                }
                t = t.addingTimeInterval(15 * 60)
            }

            // 静息心率 / 体温：每晚各一个点，落在起床时刻。
            if inRange(night.sleepEnd) {
                resting.append(.init(timestamp: Int(night.sleepEnd.timeIntervalSince1970), value: night.restingHeartRate))
                wristTemp.append(.init(timestamp: Int(night.sleepEnd.timeIntervalSince1970), value: (night.wristTemperature * 100).rounded() / 100))
                bodyTemp.append(.init(timestamp: Int(night.sleepEnd.timeIntervalSince1970), value: ((night.wristTemperature + 0.2) * 100).rounded() / 100))
            }

            // 白天心率：起床后到当晚上床前，每 30 分钟一个点。没有它服务端只有夜间数据。
            var dayTime = night.inBedEnd
            let dayEnd = min(endDate, night.inBedEnd.addingTimeInterval(14 * 3600))
            var daySeed = seed &+ 31
            while dayTime < dayEnd {
                if inRange(dayTime) {
                    let value = (nightProfile.daytimeHeartRate + random(&daySeed, -12, 22)).rounded()
                    heartRate.append(.init(timestamp: Int(dayTime.timeIntervalSince1970), value: value))
                }
                dayTime = dayTime.addingTimeInterval(30 * 60)
            }
        }

        // 真实实现用 endDate 倒序 + limit 取最近 maxSamples 条，再升序返回。这里保持一致。
        func trim(_ points: [HealthDataManager.HealthSeriesData.SamplePoint]) -> [HealthDataManager.HealthSeriesData.SamplePoint] {
            Array(points.sorted { $0.timestamp < $1.timestamp }.suffix(maxSamples))
        }

        result.heartRate = trim(heartRate)
        result.hrv = trim(hrv)
        result.respiratoryRate = trim(respiratory)
        result.restingHeartRate = trim(resting)
        result.sleepingWristTemperature = trim(wristTemp)
        result.bodyTemperature = trim(bodyTemp)
        result.deepSleep = deep
        result.remSleep = rem
        result.lightSleep = light
        result.awakeSleep = awake
        result.inBed = inBed
        return result
    }

    func sleepStagePoints(start: Date, end: Date) -> HealthDataManager.SleepStageSeries? {
        var deep: [HealthDataManager.HealthSeriesData.SleepStagePoint] = []
        var rem: [HealthDataManager.HealthSeriesData.SleepStagePoint] = []
        var light: [HealthDataManager.HealthSeriesData.SleepStagePoint] = []
        var awake: [HealthDataManager.HealthSeriesData.SleepStagePoint] = []
        var inBed: [HealthDataManager.HealthSeriesData.SleepStagePoint] = []
        for night in nights(from: start, to: end) {
            // inBed 与阶段重叠，单独一轨
            let bedStart = max(night.inBedStart, start)
            let bedEnd = min(night.inBedEnd, end)
            if bedEnd > bedStart {
                inBed.append(.init(
                    startTs: Int(bedStart.timeIntervalSince1970),
                    endTs: Int(bedEnd.timeIntervalSince1970),
                    duration: bedEnd.timeIntervalSince(bedStart)
                ))
            }
            for stage in night.stages {
                let clippedStart = max(stage.start, start)
                let clippedEnd = min(stage.end, end)
                guard clippedEnd > clippedStart else { continue }
                let point = HealthDataManager.HealthSeriesData.SleepStagePoint(
                    startTs: Int(clippedStart.timeIntervalSince1970),
                    endTs: Int(clippedEnd.timeIntervalSince1970),
                    duration: clippedEnd.timeIntervalSince(clippedStart)
                )
                switch stage.kind {
                case .deep: deep.append(point)
                case .rem: rem.append(point)
                case .core: light.append(point)
                case .awake: awake.append(point)
                }
            }
        }
        if deep.isEmpty && rem.isEmpty && light.isEmpty && awake.isEmpty && inBed.isEmpty { return nil }
        // 构造数据只产生 core/deep/rem/awake，没有 unspecified 这一档
        return (deep: deep, rem: rem, light: light, unspecified: [], awake: awake, inBed: inBed)
    }

    // MARK: - 派生：日/周/月/半年/年 图表

    /// 日视图：0-23 时每小时一个点。
    func dailyData(anchorDate: Date) -> HealthDataManager.PeriodHealthData {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: anchorDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let samples = series(from: startOfDay, to: endOfDay, maxSamples: Int.max)

        var heartRate = [Double](repeating: 0, count: 24)
        var heartRateRange = [HealthDataManager.HeartRateRangePoint](repeating: .empty, count: 24)
        var hrv = [Double](repeating: 0, count: 24)
        var sleep = [Double](repeating: 0, count: 24)

        var hourBuckets = [[Double]](repeating: [], count: 24)
        for point in samples.heartRate {
            let date = Date(timeIntervalSince1970: TimeInterval(point.timestamp))
            let hour = calendar.component(.hour, from: date)
            hourBuckets[hour].append(point.value)
        }
        for hour in 0..<24 where !hourBuckets[hour].isEmpty {
            let values = hourBuckets[hour]
            heartRate[hour] = values.reduce(0, +) / Double(values.count)
            heartRateRange[hour] = .init(min: values.min() ?? 0, max: values.max() ?? 0)
        }

        var hrvBuckets = [[Double]](repeating: [], count: 24)
        for point in samples.hrv {
            let hour = calendar.component(.hour, from: Date(timeIntervalSince1970: TimeInterval(point.timestamp)))
            hrvBuckets[hour].append(point.value)
        }
        for hour in 0..<24 where !hrvBuckets[hour].isEmpty {
            hrv[hour] = hrvBuckets[hour].reduce(0, +) / Double(hrvBuckets[hour].count)
        }

        // 每小时睡了多少（小时为单位，0~1）
        for night in nights(from: startOfDay, to: endOfDay) {
            for stage in night.stages where stage.kind != .awake {
                var t = max(stage.start, startOfDay)
                let stageEnd = min(stage.end, endOfDay)
                while t < stageEnd {
                    let hour = calendar.component(.hour, from: t)
                    // 必须用 dateInterval 取「t 所在这个整点的结束」。不能用 date(bySetting:)——
                    // 那个语义是「下一个满足条件的时刻」，会直接跳到下一个整点去，切片就错位了。
                    guard let hourEnd = calendar.dateInterval(of: .hour, for: t)?.end else { break }
                    let sliceEnd = min(stageEnd, hourEnd)
                    guard sliceEnd > t else { break }
                    sleep[hour] += sliceEnd.timeIntervalSince(t) / 3600.0
                    t = sliceEnd
                }
            }
        }

        var data = HealthDataManager.PeriodHealthData(
            heartRate: heartRate, heartRateRange: heartRateRange, hrv: hrv, sleep: sleep
        )
        if let night = night(for: anchorDate) {
            data.sleepRange = [sleepRangePoint(for: night)]
        }
        return data
    }

    /// 周（7 天）/ 月（30 天）：每天一个点。
    func periodData(days: Int, anchorDate: Date) -> HealthDataManager.PeriodHealthData {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchorDate)
        var heartRate: [Double] = []
        var heartRateRange: [HealthDataManager.HeartRateRangePoint] = []
        var hrv: [Double] = []
        var sleep: [Double] = []
        var sleepRange: [HealthDataManager.SleepRangePoint] = []

        for offset in stride(from: days - 1, through: 0, by: -1) {
            let day = calendar.date(byAdding: .day, value: -offset, to: anchorDay) ?? anchorDay
            guard let night = night(for: day) else {
                heartRate.append(0)
                heartRateRange.append(.empty)
                hrv.append(0)
                sleep.append(0)
                sleepRange.append(.empty)
                continue
            }
            heartRate.append(night.restingHeartRate + 8)
            heartRateRange.append(.init(min: night.restingHeartRate - 4, max: profile(on: night.day).daytimeHeartRate + 28))
            hrv.append(night.hrv)
            sleep.append(night.totalSleepHours)
            sleepRange.append(sleepRangePoint(for: night))
        }

        return .init(heartRate: heartRate, heartRateRange: heartRateRange, hrv: hrv, sleep: sleep, sleepRange: sleepRange)
    }

    /// 半年（26 周）/ 年（12 个月）：把若干天聚合成一个点。
    func aggregatedData(buckets: Int, daysPerBucket: Int, anchorDate: Date) -> HealthDataManager.PeriodHealthData {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchorDate)
        var heartRate: [Double] = []
        var heartRateRange: [HealthDataManager.HeartRateRangePoint] = []
        var hrv: [Double] = []
        var sleep: [Double] = []
        var sleepRange: [HealthDataManager.SleepRangePoint] = []

        for bucket in stride(from: buckets - 1, through: 0, by: -1) {
            let bucketEnd = calendar.date(byAdding: .day, value: -bucket * daysPerBucket, to: anchorDay) ?? anchorDay
            var nights: [Night] = []
            for offset in 0..<daysPerBucket {
                let day = calendar.date(byAdding: .day, value: -offset, to: bucketEnd) ?? bucketEnd
                if let night = night(for: day) { nights.append(night) }
            }
            guard !nights.isEmpty else {
                heartRate.append(0)
                heartRateRange.append(.empty)
                hrv.append(0)
                sleep.append(0)
                sleepRange.append(.empty)
                continue
            }
            let count = Double(nights.count)
            heartRate.append(nights.reduce(0) { $0 + $1.restingHeartRate + 8 } / count)
            heartRateRange.append(.init(
                min: nights.map { $0.restingHeartRate - 4 }.min() ?? 0,
                max: profile(on: nights[0].day).daytimeHeartRate + 30
            ))
            hrv.append(nights.reduce(0) { $0 + $1.hrv } / count)
            sleep.append(nights.reduce(0) { $0 + $1.totalSleepHours } / count)
            // 区间图用桶内最近一晚代表。
            sleepRange.append(sleepRangePoint(for: nights[0]))
        }

        return .init(heartRate: heartRate, heartRateRange: heartRateRange, hrv: hrv, sleep: sleep, sleepRange: sleepRange)
    }

    /// SleepRangePoint 的分钟数以「起床日前一天 20:00」为零点，与图表约定一致。
    private func sleepRangePoint(for night: Night) -> HealthDataManager.SleepRangePoint {
        let calendar = Calendar.current
        let previousDay = calendar.date(byAdding: .day, value: -1, to: night.day) ?? night.day
        guard let base = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: previousDay) else { return .empty }
        func minutes(_ date: Date) -> Double { date.timeIntervalSince(base) / 60.0 }
        return .init(
            bedStartMinutes: minutes(night.inBedStart),
            bedEndMinutes: minutes(night.inBedEnd),
            sleepStartMinutes: minutes(night.sleepStart),
            sleepEndMinutes: minutes(night.sleepEnd)
        )
    }

    private func latestDaytimeHeartRate() -> Double {
        let today = Date()
        let dayQuality = quality(for: today) ?? .good
        var seed = UInt64(bitPattern: Int64(Self.dayIndex(of: today))) &+ Self.qualitySeed(for: dayQuality) &+ 555
        return (Self.profile(for: dayQuality).daytimeHeartRate + random(&seed, -8, 14)).rounded()
    }

    // MARK: - 确定性随机

    /// 种子只跟「档位 + 日期」有关：同一档位下每次进入看到的曲线完全一样，
    /// 不会因为反复刷新而抖动，也方便和服务端对数。
    private static func qualitySeed(for quality: HealthSimulationQuality) -> UInt64 {
        switch quality {
        case .good: return 1_000_003
        case .fair: return 2_000_029
        case .poor: return 3_000_017
        }
    }

    private static func dayIndex(of date: Date) -> Int {
        Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970 / 86400)
    }

    private func random(_ seed: inout UInt64, _ min: Double, _ max: Double) -> Double {
        seed = (seed &* 6364136223846793005) &+ 1442695040888963407
        let normalized = Double((seed >> 33) % 10000) / 10000.0
        return min + normalized * (max - min)
    }
}
