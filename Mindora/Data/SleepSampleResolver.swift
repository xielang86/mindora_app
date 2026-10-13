import Foundation
import HealthKit

/// 把 HealthKit 的睡眠样本解析成「同一时刻只归属一个阶段」的时间轴。
///
/// 为什么需要：同一晚 HealthKit 里常有多个来源同时写入 —— Apple Watch 写 core/deep/REM，
/// iPhone 的「睡眠专注」写 asleepUnspecified 覆盖整晚，装了第三方睡眠 App 还会再来一份。
/// 这些样本在时间上互相重叠，把每条样本的时长直接相加会把一晚算成两三晚（真机实测
/// 苹果健康 5h51m 的一晚被算成 11h33m）。苹果健康 App 的做法是同一时段只认一个优先来源，
/// 这里用等价方式实现：先把所有样本切成互不重叠的基本区间，再给每个区间选出唯一胜出的阶段。
///
/// 优先级规则（高者胜出）：
/// 1. 来源：写出过分期数据（deep/REM/core）的来源 > 只写 asleepUnspecified 的来源；
///    同级再按窗口内覆盖时长长者优先，最后按 bundleId 定序保证结果稳定。
/// 2. 同一来源内若仍有重叠：deep > REM > core > awake > unspecified。
enum SleepSampleResolver {

    enum Stage {
        case awake, rem, core, deep, unspecified

        var isAsleep: Bool { self != .awake }
    }

    struct Segment {
        let stage: Stage
        let start: Date
        let end: Date
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    struct Resolved {
        /// 按时间升序、互不重叠的阶段区间（不含 inBed）
        var segments: [Segment] = []
        var deep: TimeInterval = 0
        var rem: TimeInterval = 0
        var core: TimeInterval = 0
        /// asleepUnspecified：不分期的来源（iPhone 睡眠专注、部分第三方 App）写的「睡着」。
        /// 苹果健康把它计入 Duration 但**不计入 Core**，这里保持一致，单独一档。
        var unspecified: TimeInterval = 0
        var awake: TimeInterval = 0
        /// inBed 独立成轨：它按设计就与睡眠阶段重叠，只在自身内部做并集去重
        var inBed: TimeInterval = 0
        var firstInBedStart: Date?
        /// 并集去重后的 inBed 区间。上传给服务端时要用原始片段，
        /// 只给总时长的话服务端还原不出 Time in Bed / 睡眠效率 / 入睡用时。
        var inBedSegments: [(start: Date, end: Date)] = []
        var firstAsleepStart: Date?
        /// 第一个阶段区间的起点（含 awake），inBed 缺失时作为入睡用时的参照起点
        var firstStageStart: Date?

        var totalAsleep: TimeInterval { deep + rem + core + unspecified }
        var hasAny: Bool { totalAsleep > 0 || awake > 0 || inBed > 0 }

        // MARK: 分钟口径（对外展示用）
        //
        // 上面那组是精确秒数，用于分析和上传；下面这组是**按苹果健康的算法**数出来的分钟数，
        // UI 一律用它。两者不能互相换算，详见 fillMinuteCounts。
        var deepMinutes = 0
        var remMinutes = 0
        var coreMinutes = 0
        var unspecifiedMinutes = 0
        var awakeMinutes = 0
        var totalAsleepMinutes: Int { deepMinutes + remMinutes + coreMinutes + unspecifiedMinutes }
    }

    // MARK: - Public

    /// 解析 [window.start, window.end) 内的睡眠样本。样本会先裁剪到窗口再参与计算。
    static func resolve(samples: [HKCategorySample], window: (start: Date, end: Date)) -> Resolved {
        var result = Resolved()
        guard window.end > window.start else { return result }

        var stageSamples: [(stage: Stage, start: Date, end: Date, source: String)] = []
        var inBedIntervals: [(start: Date, end: Date)] = []

        for sample in samples {
            let start = max(sample.startDate, window.start)
            let end = min(sample.endDate, window.end)
            guard end > start else { continue }

            guard let kind = kind(of: sample) else { continue }
            switch kind {
            case .inBed:
                inBedIntervals.append((start, end))
            case .stage(let stage):
                stageSamples.append((stage, start, end, sample.sourceRevision.source.bundleIdentifier))
            }
        }

        // inBed：只做并集，不与阶段互斥
        let mergedInBed = union(inBedIntervals)
        result.inBed = mergedInBed.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
        result.firstInBedStart = mergedInBed.first?.start
        result.inBedSegments = mergedInBed

        guard !stageSamples.isEmpty else { return result }

        let sourceRank = rankSources(stageSamples)

        // 切成互不重叠的基本区间，逐段选出胜出阶段
        var boundaries = Set<Date>()
        for s in stageSamples {
            boundaries.insert(s.start)
            boundaries.insert(s.end)
        }
        let points = boundaries.sorted()

        var segments: [Segment] = []
        for index in 0..<max(0, points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            guard end > start else { continue }

            var winner: Stage?
            var winnerPriority: (Int, Int) = (Int.min, Int.min)
            for s in stageSamples where s.start <= start && s.end >= end {
                let priority = (sourceRank[s.source] ?? 0, stageRank(s.stage))
                if priority > winnerPriority {
                    winnerPriority = priority
                    winner = s.stage
                }
            }
            guard let stage = winner else { continue }

            // 与上一段同阶段且首尾相接就合并，避免图表出现大量碎片
            if let last = segments.last, last.stage == stage, last.end == start {
                segments[segments.count - 1] = Segment(stage: stage, start: last.start, end: end)
            } else {
                segments.append(Segment(stage: stage, start: start, end: end))
            }
        }

        result.segments = segments
        for segment in segments {
            switch segment.stage {
            case .deep: result.deep += segment.duration
            case .rem: result.rem += segment.duration
            case .core: result.core += segment.duration
            case .unspecified: result.unspecified += segment.duration
            case .awake: result.awake += segment.duration
            }
        }
        result.firstStageStart = segments.first?.start
        result.firstAsleepStart = segments.first(where: { $0.stage.isAsleep })?.start
        fillMinuteCounts(&result)

        return result
    }

    /// 苹果健康的分钟口径：把时间轴切成整分钟的格子，每格判给**在这一分钟里占用最久**的
    /// 那个阶段，再数格子数。
    ///
    /// 不能简单地「把秒数加起来再四舍五入」—— 真机逐秒核对 8/13 那晚：
    /// awake / REM / core / 总时长两种算法结果相同，但 deep 秒数是 45分16秒，
    /// 求和取整得 45，而苹果显示 46。原因是 deep 那 4 段都压在分钟边界的有利一侧
    /// （如 02:30:15 起，02:30 这一格里 deep 占 45 秒、core 只占 15 秒，整格判给 deep）。
    /// 换成分钟格后四项与苹果逐项一致，且各阶段分钟数相加正好等于总时长的分钟数。
    private static func fillMinuteCounts(_ result: inout Resolved) {
        guard let first = result.segments.first, let last = result.segments.last else { return }

        let startSecond = (first.start.timeIntervalSince1970 / 60).rounded(.down) * 60
        let endSecond = (last.end.timeIntervalSince1970 / 60).rounded(.up) * 60

        var bucketStart = startSecond
        while bucketStart < endSecond {
            let bucketEnd = bucketStart + 60
            var winner: Stage?
            var longestOverlap: TimeInterval = 0

            for segment in result.segments {
                let segmentStart = segment.start.timeIntervalSince1970
                let segmentEnd = segment.end.timeIntervalSince1970
                if segmentEnd <= bucketStart { continue }
                if segmentStart >= bucketEnd { break }   // segments 按时间升序，后面的更不可能相交
                let overlap = min(segmentEnd, bucketEnd) - max(segmentStart, bucketStart)
                // 严格大于：并列时保留时间靠前的那个阶段，结果才稳定
                if overlap > longestOverlap {
                    longestOverlap = overlap
                    winner = segment.stage
                }
            }

            switch winner {
            case .deep: result.deepMinutes += 1
            case .rem: result.remMinutes += 1
            case .core: result.coreMinutes += 1
            case .unspecified: result.unspecifiedMinutes += 1
            case .awake: result.awakeMinutes += 1
            case nil: break
            }

            bucketStart = bucketEnd
        }
    }

    /// 「睡眠期间」的唯一权威定义：所有阶段区间（含 awake）合并后的并集。
    ///
    /// 不能用 segments.first.start…segments.last.end 这个总跨度代替 —— 一晚里
    /// 若有傍晚小睡再夜间入睡，总跨度会把中间几小时清醒时段也圈进来；按自然日
    /// 切片时更严重，一天里既有昨晚的尾巴又有今晚的开头，总跨度直接变成一整天。
    static func sleepIntervals(from resolved: Resolved) -> [(start: Date, end: Date)] {
        var merged: [(start: Date, end: Date)] = []
        for segment in resolved.segments.sorted(by: { $0.start < $1.start }) {
            if let last = merged.last, segment.start <= last.end {
                merged[merged.count - 1].end = Swift.max(last.end, segment.end)
            } else {
                merged.append((segment.start, segment.end))
            }
        }
        return merged
    }

    /// 「持续睡着」的门槛：连续睡够这么久才算真的睡着了
    private static let sustainedSleepThreshold: TimeInterval = 5 * 60
    /// 睡眠段之间允许的碎醒：不超过这么长就不算打断连续睡眠
    private static let sleepInterruptionTolerance: TimeInterval = 60
    /// 入睡用时上限：inBed 来自 iPhone「睡眠时间表」时是**计划**就寝时刻，
    /// 离真实躺下可能差几个小时，超过这个数就不再是有意义的入睡用时了
    private static let maximumOnsetMinutes: Double = 180

    /// 入睡用时：从「躺下打算睡」到「第一次持续睡着」的间隔。算不出来返回 nil。
    ///
    /// **nil 和 0 是两回事**：nil = 数据源根本没记录入睡前那段，不可测；
    /// 接近 0 = 确实几乎沾枕就睡。展示层必须分开处理，不能一律当无数据。
    static func sleepOnsetMinutes(from resolved: Resolved) -> Double? {
        guard let sessionStart = resolved.firstStageStart,
              let asleep = firstSustainedAsleepStart(in: resolved) else { return nil }

        // inBed 只有【严格早于】会话起点时才可信。
        //
        // 很多来源（第三方 App、部分设备配置）把 inBed 写成整段会话的**包络**：
        // 起点正好等于第一段睡眠的起点。真机实测某台 iPhone 17 Pro 那晚，
        // inBed 6.05h 与「睡着 5.842748785h + 清醒 12.435min」相差 3e-12 秒，起点也重合 ——
        // 这种 inBed 不含任何「躺着还没睡着」的信息，拿它当参照只会恒得 0。
        let lightsOut: Date
        if let inBedStart = resolved.firstInBedStart, inBedStart < sessionStart {
            lightsOut = inBedStart
        } else {
            // 退回会话起点：Apple Watch 会把入睡前那段记成 awake，
            // 它才是这类来源唯一真实的「躺着没睡着」信号。
            lightsOut = sessionStart
        }

        // 会话第一秒就是睡着 → 没有可测量的入睡前时段，不是「秒睡」
        guard asleep > lightsOut else { return nil }

        return min(asleep.timeIntervalSince(lightsOut) / 60.0, maximumOnsetMinutes)
    }

    /// 第一次「持续」睡着的时刻：从该点起累计睡够 `sustainedSleepThreshold`，
    /// 中间不超过 `sleepInterruptionTolerance` 的碎醒不算打断。
    ///
    /// 不能直接取第一个 asleep 段的起点 —— 上床后翻个身被写成 1 分钟 asleep，
    /// 就会判定已入睡，入睡用时被严重低估。
    private static func firstSustainedAsleepStart(in resolved: Resolved) -> Date? {
        var runStart: Date?
        var asleepInRun: TimeInterval = 0

        for segment in resolved.segments {
            if segment.stage.isAsleep {
                if runStart == nil { runStart = segment.start }
                asleepInRun += segment.duration
                if asleepInRun >= sustainedSleepThreshold { return runStart }
            } else if segment.duration > sleepInterruptionTolerance {
                runStart = nil
                asleepInRun = 0
            }
        }

        // 整晚都没凑出一段够长的连续睡眠（极短的小睡）：退回第一个睡着点
        return resolved.firstAsleepStart
    }

    // MARK: - Private

    private enum Kind {
        case inBed
        case stage(Stage)
    }

    private static func kind(of sample: HKCategorySample) -> Kind? {
        if #available(iOS 16.0, *) {
            switch sample.value {
            case HKCategoryValueSleepAnalysis.inBed.rawValue: return .inBed
            case HKCategoryValueSleepAnalysis.awake.rawValue: return .stage(.awake)
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue: return .stage(.rem)
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: return .stage(.deep)
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue: return .stage(.core)
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: return .stage(.unspecified)
            default: return nil
            }
        } else {
            switch sample.value {
            case HKCategoryValueSleepAnalysis.inBed.rawValue: return .inBed
            case HKCategoryValueSleepAnalysis.awake.rawValue: return .stage(.awake)
            case HKCategoryValueSleepAnalysis.asleep.rawValue: return .stage(.unspecified)
            default: return nil
            }
        }
    }

    private static func stageRank(_ stage: Stage) -> Int {
        switch stage {
        case .deep: return 5
        case .rem: return 4
        case .core: return 3
        case .awake: return 2
        case .unspecified: return 1
        }
    }

    /// 给每个来源打分：分期来源优先，其次覆盖时长长者优先，最后 bundleId 定序保证稳定。
    private static func rankSources(_ samples: [(stage: Stage, start: Date, end: Date, source: String)]) -> [String: Int] {
        var staged: Set<String> = []
        var coverage: [String: TimeInterval] = [:]
        for s in samples {
            coverage[s.source, default: 0] += s.end.timeIntervalSince(s.start)
            if s.stage == .deep || s.stage == .rem || s.stage == .core {
                staged.insert(s.source)
            }
        }

        let ordered = coverage.keys.sorted { lhs, rhs in
            let lhsStaged = staged.contains(lhs)
            let rhsStaged = staged.contains(rhs)
            if lhsStaged != rhsStaged { return lhsStaged }
            let lhsCoverage = coverage[lhs] ?? 0
            let rhsCoverage = coverage[rhs] ?? 0
            if lhsCoverage != rhsCoverage { return lhsCoverage > rhsCoverage }
            return lhs < rhs
        }

        var ranks: [String: Int] = [:]
        for (index, source) in ordered.enumerated() {
            ranks[source] = ordered.count - index
        }
        return ranks
    }

    private static func union(_ intervals: [(start: Date, end: Date)]) -> [(start: Date, end: Date)] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = [sorted[0]]
        for interval in sorted.dropFirst() {
            if interval.start <= merged[merged.count - 1].end {
                merged[merged.count - 1].end = max(merged[merged.count - 1].end, interval.end)
            } else {
                merged.append(interval)
            }
        }
        return merged
    }
}
