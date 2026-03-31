import Foundation
import HealthKit
import UIKit

/// 自动同步服务：根据配置定时抓取并上传数据
final class HealthSyncService {
    static let shared = HealthSyncService()
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(configChanged(_:)), name: HealthSyncConfigStore.configDidChangeNotification, object: nil)
        // 监听应用进入前台的通知，马上触发一次同步
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
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
    private var runningTask: Task<Void, Never>?

    func startIfNeeded() { scheduleTimer() }
    func stop() {
        timer?.invalidate()
        timer = nil
        runningTask?.cancel()
        runningTask = nil
        state = .stopped
    }

    @objc private func configChanged(_ note: Notification) { scheduleTimer(reset: true) }

    @objc private func appWillEnterForeground() {
        Log.info("HealthSync", "App entering foreground, trigger immediate sync")
        tick()
    }

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
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.isSyncing else {
                Log.info("SyncService", "skip sync because previous task still running")
                return
            }

            self.isSyncing = true
            let endpointURL = Constants.Network.healthSyncURL
            Log.info("SyncService", "schedule background sync endpoint=\(endpointURL) forced=\(forced) skipDedupe=\(skipDedupe)")

            let start = Date()
            var uploadedKeys: [String] = []
            self.runningTask = Task.detached(priority: .background) { [weak self] in
                do {
                    try await HealthDataManager.shared.requestAuthorization()
                                        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
                          let token = AuthStorage.shared.token, !token.isEmpty else {
                        Log.info("SyncService", "skip health sync because credentials are missing")
                        let dur = Date().timeIntervalSince(start)
                        let progress = SyncProgress(start: start, success: false, error: HealthDataUploaderError.missingCredentials, duration: dur, uploadedMetrics: [])
                        self?.postProgress(progress)
                        self?.queue.async {
                            self?.isSyncing = false
                            self?.runningTask = nil
                        }
                        return
                    }
                    _ = token
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

                    let payload = HealthDataUploader.buildPayload(uid: uid, series: series)
                    if payload.behaviors.isEmpty {
                        Log.info("SyncService", "payload.behaviors empty (forced=\(forced) skipDedupe=\(skipDedupe)) - possible causes: no HealthKit samples, metrics all disabled, or permission denied")
                    }
                    uploadedKeys = Array(payload.behaviors.keys)

                    do {
                        _ = try await HealthDataUploader.postUpdateProfile(payload: payload, endpointURL: endpointURL)
                        Log.info("SyncService", "upload success endpoint=\(endpointURL) metrics=\(uploadedKeys.joined(separator: ","))")
                        if !(forced && skipDedupe && payload.behaviors.isEmpty) {
                            self?.updateUploadStateAfterSuccess(series: series)
                        } else {
                            Log.info("SyncService", "skip updating upload state because payload empty under forced full upload")
                        }
                    } catch {
                        Log.error("SyncService", "upload failed endpoint=\(endpointURL) error=\(error)")
                        throw error
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
                self?.queue.async {
                    self?.isSyncing = false
                    self?.runningTask = nil
                }
            }
        }
    }

    // MARK: - Dedupe helpers
    private func hasAnyData(_ series: HealthDataManager.HealthSeriesData) -> Bool {
        return !(
            series.heartRate.isEmpty &&
            series.hrv.isEmpty &&
            series.respiratoryRate.isEmpty &&
            series.restingHeartRate.isEmpty &&
            series.sleepingWristTemperature.isEmpty &&
            series.bodyTemperature.isEmpty &&
            series.deepSleep.isEmpty &&
            series.remSleep.isEmpty &&
            series.lightSleep.isEmpty
        )
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
        filterPoints(&series.respiratoryRate, key: "respiratory_rate")
        filterPoints(&series.restingHeartRate, key: "resting_heart_rate")
        filterPoints(&series.sleepingWristTemperature, key: "sleeping_wrist_temperature")
        filterPoints(&series.bodyTemperature, key: "body_temperature")

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
        recordMax(series.respiratoryRate, key: "respiratory_rate")
        recordMax(series.restingHeartRate, key: "resting_heart_rate")
        recordMax(series.sleepingWristTemperature, key: "sleeping_wrist_temperature")
        recordMax(series.bodyTemperature, key: "body_temperature")

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
        if !cfg.metrics.contains(.respiratoryRate) { series.respiratoryRate.removeAll() }
        if !cfg.metrics.contains(.restingHeartRate) { series.restingHeartRate.removeAll() }
        if !cfg.metrics.contains(.sleepingWristTemperature) { series.sleepingWristTemperature.removeAll() }
        if !cfg.metrics.contains(.bodyTemperature) { series.bodyTemperature.removeAll() }
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
            "respiratory_rate": series.respiratoryRate.count,
            "resting_heart_rate": series.restingHeartRate.count,
            "sleeping_wrist_temperature": series.sleepingWristTemperature.count,
            "body_temperature": series.bodyTemperature.count,
            "sleep_deep": series.deepSleep.count,
            "sleep_rem": series.remSleep.count,
            "sleep_light": series.lightSleep.count
        ]
        Log.info("SyncService", "counts(\(stage))=\(counts)")
    }
}
