import Foundation
import HealthKit

/// 自动同步服务：根据配置定时抓取并上传数据
final class HealthSyncService {
    static let shared = HealthSyncService()
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(configChanged(_:)), name: HealthSyncConfigStore.configDidChangeNotification, object: nil)
    }

    enum State { case stopped, running(nextFire: Date?) }
    private(set) var state: State = .stopped { didSet { notifyStateChanged() } }

    struct SyncProgress { let start: Date; let success: Bool; let error: Error?; let duration: TimeInterval; let uploadedMetrics: [String] }

    static let stateDidChangeNotification = Notification.Name("health.sync.service.state")
    static let progressNotification = Notification.Name("health.sync.service.progress")

    private var timer: Timer?
    private let queue = DispatchQueue(label: "health.sync.service", qos: .utility)
    private var isSyncing = false
    private var lastSyncDate: Date?

    func startIfNeeded() { scheduleTimer() }
    func stop() { timer?.invalidate(); timer = nil; state = .stopped }

    @objc private func configChanged(_ note: Notification) { scheduleTimer(reset: true) }

    private func scheduleTimer(reset: Bool = false) {
        let cfg = HealthSyncConfigStore.shared.current
        if !cfg.enabled { stop(); return }
        if reset { timer?.invalidate(); timer = nil }
        guard timer == nil else { return }
        let interval = TimeInterval(cfg.interval.rawValue)
        let next = Date().addingTimeInterval(interval)
        state = .running(nextFire: next)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
        // 立即触发一次（不等待第一个周期）
        tick()
    }

    private func tick() {
        let cfg = HealthSyncConfigStore.shared.current
        if !cfg.enabled { stop(); return }
        performSync(config: cfg)
    }

    // 手动同步（按需求：总是强制全量上传，不去重）
    func performManualFullUpload() { performSync(config: HealthSyncConfigStore.shared.current, forced: true, skipDedupe: true) }

    // 兼容旧调用：后台调度等仍调用去重版本；保持方法名防止编译错误
    func performManualSync() { performSync(config: HealthSyncConfigStore.shared.current, forced: false, skipDedupe: false) }

    private func performSync(config: HealthSyncConfig, forced: Bool = false, skipDedupe: Bool = false) {
        guard !isSyncing else { return }
        // 原逻辑：只向当前选中的一个设备上传。需求：多台设备时全部上传。
        // 策略：
        // 1. 如果 Bonjour 已发现至少 1 台服务，则以发现列表为准（全部广播）。
        // 2. 否则 fallback 到用户当前选中的单一 session host（与之前一致）。
        // 3. 同一次同步仅抓取一次 HealthKit 数据，然后对每个主机重复上传。
        // 4. 只要任意一台设备成功返回 success，即视为整体成功并更新去重状态；全部失败才算失败。

        var broadcastHosts: [String] = []
        let discovered = BonjourDiscovery.shared.services
            .map { $0.hostName ?? $0.name }
            .filter { !$0.isEmpty }
        if !discovered.isEmpty {
            // 去重保持原顺序（第一次出现保留）
            var seen: Set<String> = []
            for h in discovered where !seen.contains(h) { broadcastHosts.append(h); seen.insert(h) }
        } else if let single = DeviceSession.shared.host { broadcastHosts = [single] }
        guard !broadcastHosts.isEmpty else { return } // 无任何可用主机
        Log.info("SyncService", "targets count=\(broadcastHosts.count) hosts=\(broadcastHosts.joined(separator: ",")) forced=\(forced) skipDedupe=\(skipDedupe)")
        
        // 创建 broadcastHosts 的本地副本以避免并发访问问题
        let hostsToBroadcast = broadcastHosts
        isSyncing = true
        queue.async { [weak self] in
            let start = Date()
            var uploadedKeys: [String] = []
            Task {
                do {
                    try await HealthDataManager.shared.requestAuthorization()
                    // 初始窗口 24h；如果是强制全量且无数据，再尝试扩大窗口 (72h, 168h)
                    let fallbackWindows = [24, 72, 168]
                    var usedWindow = 24
                    var series = try await HealthDataManager.shared.fetchRecentSeries(hoursBack: usedWindow, maxSamples: 200)
                    Log.info("SyncService", "fetchRecentSeries window=\(usedWindow)h startedAt=\(Date())")
                    self?.logSeriesCounts(series, stage: "after fetch")
                    self?.filter(&series, with: config)
                    self?.logSeriesCounts(series, stage: "after filter (respect metrics selection)")

                    if forced && skipDedupe && !(self?.hasAnyData(series) ?? false) {
                        for win in fallbackWindows.dropFirst() { // 已尝试 24
                            usedWindow = win
                            Log.info("SyncService", "forced full upload: retry fetch with extended window=\(win)h because initial window empty")
                            var retry = try await HealthDataManager.shared.fetchRecentSeries(hoursBack: win, maxSamples: 200)
                            self?.logSeriesCounts(retry, stage: "after fetch (retry \(win)h)")
                            self?.filter(&retry, with: config)
                            self?.logSeriesCounts(retry, stage: "after filter (retry \(win)h)")
                            if self?.hasAnyData(retry) == true { series = retry; break }
                        }
                    }

                    // skipDedupe=true 时，不做去重（场景：用户选择“强制上传全部”）
                    if !skipDedupe {
                        // 根据最近一次成功上传时间戳，过滤掉已上传的数据
                        self?.dedupeUsingUploadState(&series)
                        self?.logSeriesCounts(series, stage: "after dedupe")
                    }

                    // forced=false & 去重后没有新增数据 => 跳过上传
                    if !forced {
                        if self?.hasAnyData(series) != true {
                            Log.info("SyncService", "no new data since last success, skip upload (forced=\(forced) skipDedupe=\(skipDedupe))")
                            let dur = Date().timeIntervalSince(start)
                            let progress = SyncProgress(start: start, success: true, error: nil, duration: dur, uploadedMetrics: [])
                            self?.postProgress(progress)
                            self?.isSyncing = false
                            return
                        }
                    }

                    let payload = HealthDataUploader.buildPayload(uid: "demo-user", series: series)
                    if payload.behaviors.isEmpty {
                        Log.info("SyncService", "payload.behaviors empty (forced=\(forced) skipDedupe=\(skipDedupe)) - possible causes: no HealthKit samples, metrics all disabled, or permission denied")
                    }
                    uploadedKeys = Array(payload.behaviors.keys)

                    // 广播上传
                    var successHosts: [String] = []
                    var failedHosts: [(String, Error)] = []
                    for h in hostsToBroadcast {
                        do {
                            _ = try await HealthDataUploader.postUpdateProfile(host: h, port: DeviceSession.shared.port, payload: payload)
                            successHosts.append(h)
                            Log.info("SyncService", "upload success host=\(h) metrics=\(uploadedKeys.joined(separator: ","))")
                        } catch {
                            failedHosts.append((h, error))
                            Log.error("SyncService", "upload failed host=\(h) error=\(error)")
                        }
                    }
                    Log.info("SyncService", "broadcast done success=\(successHosts.count) fail=\(failedHosts.count)")

                    // 任意成功则更新上传状态（避免全部失败时推进时间戳丢数据）
                    if !successHosts.isEmpty {
                        if !(forced && skipDedupe && payload.behaviors.isEmpty) {
                            self?.updateUploadStateAfterSuccess(series: series)
                        } else {
                            Log.info("SyncService", "skip updating upload state because payload empty under forced full upload")
                        }
                    }
                    if successHosts.isEmpty, let _ = failedHosts.first?.1 {
                        // 全部失败，抛出第一个错误（或聚合）
                        struct MultiHostUploadError: Error { let details: String }
                        let detail = failedHosts.map { "\($0.0): \($0.1)" }.joined(separator: "; ")
                        throw MultiHostUploadError(details: detail)
                    }

                    let dur = Date().timeIntervalSince(start)
                    let progress = SyncProgress(start: start, success: true, error: nil, duration: dur, uploadedMetrics: uploadedKeys)
                    self?.lastSyncDate = Date()
                    self?.postProgress(progress)
                } catch {
                    let dur = Date().timeIntervalSince(start)
                    let progress = SyncProgress(start: start, success: false, error: error, duration: dur, uploadedMetrics: uploadedKeys)
                    self?.postProgress(progress)
                }
                self?.isSyncing = false
            }
        }
    }

    // MARK: - Dedupe helpers
    private func hasAnyData(_ series: HealthDataManager.HealthSeriesData) -> Bool {
        return !(series.heartRate.isEmpty && series.hrv.isEmpty && series.deepSleep.isEmpty && series.remSleep.isEmpty && series.lightSleep.isEmpty)
    }

    /// 依据 UploadStateStore 的 lastTs 过滤序列中小于等于 lastTs 的数据点
    private func dedupeUsingUploadState(_ series: inout HealthDataManager.HealthSeriesData) {
        let store = UploadStateStore.shared
        func filterPoints(_ points: inout [HealthDataManager.HealthSeriesData.SamplePoint], key: String) {
            if let last = store.get(key) {
                let before = points.count
                points = points.filter { $0.timestamp > last }
                Log.info("SyncService", "dedupe \(key): filtered \(before - points.count) (last=\(last))")
            }
        }
        // 常规点
        filterPoints(&series.heartRate, key: "heart_rate")
        filterPoints(&series.hrv, key: "heart_rate_variability_sdnn")

        // 睡眠阶段使用区间的 startTs 作为去重时间戳
        func filterSleep(_ arr: inout [HealthDataManager.HealthSeriesData.SleepStagePoint], key: String) {
            if let last = store.get(key) {
                let before = arr.count
                arr = arr.filter { $0.startTs > last }
                Log.info("SyncService", "dedupe \(key): filtered \(before - arr.count) (last=\(last))")
            }
        }
        filterSleep(&series.deepSleep, key: "sleep_stage_deep")
        filterSleep(&series.remSleep, key: "sleep_stage_rem")
        filterSleep(&series.lightSleep, key: "sleep_stage_light")
    }

    /// 在服务端返回 success 后，记录各指标本次上传使用的最大时间戳
    private func updateUploadStateAfterSuccess(series: HealthDataManager.HealthSeriesData) {
        var maxTs: [String: Int] = [:]
        func recordMax(_ points: [HealthDataManager.HealthSeriesData.SamplePoint], key: String) {
            if let m = points.map({ $0.timestamp }).max() { maxTs[key] = m }
        }
        recordMax(series.heartRate, key: "heart_rate")
        recordMax(series.hrv, key: "heart_rate_variability_sdnn")

        func recordSleep(_ arr: [HealthDataManager.HealthSeriesData.SleepStagePoint], key: String) {
            if let m = arr.map({ $0.startTs }).max() { maxTs[key] = m }
        }
        recordSleep(series.deepSleep, key: "sleep_stage_deep")
        recordSleep(series.remSleep, key: "sleep_stage_rem")
        recordSleep(series.lightSleep, key: "sleep_stage_light")

        if !maxTs.isEmpty {
            UploadStateStore.shared.update(maxTimestamps: maxTs)
            Log.info("SyncService", "updated upload state: \(maxTs)")
        }
    }

    private func filter(_ series: inout HealthDataManager.HealthSeriesData, with cfg: HealthSyncConfig) {
        // 如果某指标未被勾选，则清空对应数组
        if !cfg.metrics.contains(.heartRate) { series.heartRate.removeAll() }
        if !cfg.metrics.contains(.hrv) { series.hrv.removeAll() }
        if !cfg.metrics.contains(.sleepStages) { series.deepSleep.removeAll(); series.remSleep.removeAll(); series.lightSleep.removeAll() }
    }

    private func postProgress(_ p: SyncProgress) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.progressNotification, object: p)
        }
    }

    private func notifyStateChanged() {
        NotificationCenter.default.post(name: Self.stateDidChangeNotification, object: state)
    }
}

// MARK: - Diagnostics
private extension HealthSyncService {
    func logSeriesCounts(_ series: HealthDataManager.HealthSeriesData, stage: String) {
        let counts: [String: Int] = [
            "hr": series.heartRate.count,
            "hrv": series.hrv.count,
            "sleep_deep": series.deepSleep.count,
            "sleep_rem": series.remSleep.count,
            "sleep_light": series.lightSleep.count
        ]
        Log.info("SyncService", "counts(\(stage))=\(counts)")
    }
}
