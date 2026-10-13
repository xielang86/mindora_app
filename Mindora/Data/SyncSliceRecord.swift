import Foundation

/// 记录每一个"完整日"切片的成功上传状态，用于断点续传：
/// 下次同步时，凡是本地已经标记为上传完成的日期直接跳过，不再去 HealthKit 取数也不发 HTTP。
///
/// 注意：只记录 **完整** 的日切片（24h 跨度）。当天的那一片是 [今日 00:00, now]，
/// 随时间持续有新数据进来，依然走 UploadStateStore.lastTs 的逐样本去重。
final class SyncSliceRecord {
    static let shared = SyncSliceRecord()

    struct Record: Codable {
        /// 该日 local 00:00 的 Unix 秒（作为唯一键）
        let dayStartTs: Int
        /// 上传完成时间
        let uploadedAt: Int
        /// 该片上传到服务端的指标 key（例如 heart_rate / sleep_stage_deep）
        let metrics: [String]
    }

    private let userDefaultsKey = "health.sync.slices.v1"
    /// 最多保留的历史记录数（按 dayStartTs 升序，超限丢最旧）
    private let maxRecords = 200

    private(set) var records: [Record] = []

    private init() { load() }

    /// 标记某"完整日"切片已上传成功。
    /// 只允许以 local 00:00 对齐的 dayStart 作为键，避免边界漂移。
    func markDayUploaded(dayStart: Date, metrics: [String]) {
        let ts = Int(dayStart.timeIntervalSince1970)
        // 已经记录过相同日就覆盖 metrics（避免重复追加）
        if let idx = records.firstIndex(where: { $0.dayStartTs == ts }) {
            records[idx] = Record(
                dayStartTs: ts,
                uploadedAt: Int(Date().timeIntervalSince1970),
                metrics: metrics
            )
        } else {
            records.append(Record(
                dayStartTs: ts,
                uploadedAt: Int(Date().timeIntervalSince1970),
                metrics: metrics
            ))
        }
        records.sort { $0.dayStartTs < $1.dayStartTs }
        if records.count > maxRecords {
            records.removeFirst(records.count - maxRecords)
        }
        save()
        Log.info(
            "SyncSliceRecord",
            "marked day=\(Self.formatDay(dayStart)) (ts=\(ts)) metrics=\(metrics.sorted().joined(separator: ","))"
        )
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func formatDay(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// 判断某"完整日"切片是否已被记录为上传成功（用于断点续传跳过）
    func hasUploadedDay(dayStart: Date) -> Bool {
        let ts = Int(dayStart.timeIntervalSince1970)
        return records.contains { $0.dayStartTs == ts }
    }

    func getAll() -> [Record] { records }

    /// 作废 `day` 当天及之后的记录，让这些天下次同步重新拉取并上传。
    /// 用于「构造健康数据」切换档位：只有切换日往后的数据变了，更早的历史保持原样，
    /// 不必也不该整段重传。
    func invalidateDays(from day: Date) {
        let ts = Int(Calendar.current.startOfDay(for: day).timeIntervalSince1970)
        let before = records.count
        records.removeAll { $0.dayStartTs >= ts }
        guard records.count != before else { return }
        save()
        Log.info("SyncSliceRecord", "invalidated \(before - records.count) day(s) from \(Self.formatDay(day))")
    }

    /// 清空所有记录（退出登录等场景）
    func reset() {
        records.removeAll()
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            Log.error("SyncSliceRecord", "save failed: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            records = try JSONDecoder().decode([Record].self, from: data)
        } catch {
            Log.error("SyncSliceRecord", "load failed: \(error)")
        }
    }
}
