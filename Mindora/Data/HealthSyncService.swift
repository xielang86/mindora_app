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
        // 回前台是「一批设备可能同时触发」的时刻，随机错峰几秒再同步（用户不在等这个上传）。
        NetworkPacing.afterSpread(upTo: 20) { [weak self] in
            Log.info("HealthSync", "App entering foreground, trigger sync (spread)")
            self?.tick()
        }
    }

    private func scheduleTimer(reset: Bool = false, fireImmediately: Bool = true) {
        let cfg = HealthSyncConfigStore.shared.current
        if !cfg.enabled { stop(); return }
        if reset { timer?.invalidate(); timer = nil }
        guard timer == nil else { return }
        // 单次定时器 + 每轮重新抖动间隔（±20%）：避免所有设备按同一节拍撞向服务端。
        let interval = NetworkPacing.jittered(TimeInterval(cfg.interval.rawValue))
        let next = Date().addingTimeInterval(interval)
        state = .running(nextFire: next)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.timer = nil
            self.tick()
            self.scheduleTimer(fireImmediately: false)   // 重新排下一轮，抖动重新抽
        }
        RunLoop.main.add(timer!, forMode: .common)
        // 首次排程立即触发一次（不等待第一个周期）；后续续排不再重复触发。
        if fireImmediately { tick() }
    }

    private func tick() {
        let cfg = HealthSyncConfigStore.shared.current
        if !cfg.enabled { stop(); return }
        performSync(config: cfg)
    }

    // 手动同步：后台调度 / App 回前台 / 连接设备后均走此入口（带去重，只上传增量）
    func performManualSync() { performSync(config: HealthSyncConfigStore.shared.current, forced: false, skipDedupe: false) }

    private func performSync(config: HealthSyncConfig, forced: Bool = false, skipDedupe: Bool = false) {
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.isSyncing else {
                Log.info("SyncService", "skip sync because previous task still running")
                return
            }

            self.isSyncing = true
            let endpointURL = Constants.Network.profileURL
            Log.info("SyncService", "schedule background sync endpoint=\(endpointURL) forced=\(forced) skipDedupe=\(skipDedupe)")

            let start = Date()
            var uploadedKeys: [String] = []
            self.runningTask = Task.detached(priority: .background) { [weak self] in
                do {
                    // 「构造健康数据」打开时不要求 HealthKit 授权：数据本来就不来自 HealthKit，
                    // 而测试机常常压根没授权，卡在这里同步就整个中断、服务端还是收不到数据。
                    if !HealthDataSimulator.shared.isEnabled {
                        try await HealthDataManager.shared.requestAuthorization()
                    }
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
                    // 动态窗口：
                    // - 已有 lastTs → 从最早的 lastTs 回拉 + 缓冲，覆盖断联期数据
                    // - 从未同步过（新用户）或距上次同步超过 30 天 → 按 30 天窗口拉
                    // 切片上传：按本地日历日切片，从旧到新依次上传。
                    // 断点续传：完整日切片若 SyncSliceRecord 已标记为上传成功，直接跳过（不拉数据、不发 HTTP）。
                    // 今天的部分切片 [今日 00:00, now] 边界随时间变化，始终走 UploadStateStore.lastTs 逐样本去重。
                    //
                    // 动态窗口：
                    // - 已有 lastTs → 从最早的 lastTs 回拉 + 缓冲，覆盖断联期数据
                    // - 从未同步过（新用户）或距上次同步超过 30 天 → 按 30 天窗口拉
                    func buildSlices() -> (window: Int, slices: [(start: Date, end: Date, isFullDay: Bool)]) {
                        let usedWindow = self?.determineWindowHours() ?? Constants.Network.healthSyncInitialWindowHours
                        let calendar = Calendar.current
                        let now = Date()
                        let todayStart = calendar.startOfDay(for: now)
                        let rawWindowStart = now.addingTimeInterval(-TimeInterval(usedWindow * 3600))
                        let windowStart = calendar.startOfDay(for: rawWindowStart)

                        var result: [(start: Date, end: Date, isFullDay: Bool)] = []
                        var cursor = windowStart
                        while cursor < todayStart {
                            let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400)
                            result.append((start: cursor, end: nextDay, isFullDay: true))
                            cursor = nextDay
                        }
                        if todayStart < now {
                            result.append((start: todayStart, end: now, isFullDay: false))
                        }
                        return (usedWindow, result)
                    }

                    var (usedWindow, slices) = buildSlices()

                    // 对账优先。拿到结果就按差集精确重传；接口不可用（nil）才退到
                    // 本地版本号兜底——那条路会清空全部上传记录、全量重传。
                    let reconciled = await Self.reconcileStaleDays(slices: slices)
                    let staleDays: Set<Date>
                    // 对账明确回答「区间内没有一天需要重传」，才算证实服务端已是当前口径
                    var serverConfirmedCurrent = false
                    if let reconciled {
                        staleDays = reconciled
                        serverConfirmedCurrent = reconciled.isEmpty
                    } else {
                        self?.migrateIfSchemaVersionChanged()
                        // 兜底迁移会清空水位线，而窗口正是按水位线算出来的——必须重算，
                        // 否则本轮仍用清空前的窄窗口（实测只重传了最近 5 天而非 30 天），
                        // 更早的历史要等下一轮才补上。
                        (usedWindow, slices) = buildSlices()
                        staleDays = []
                    }

                    Log.info("SyncService", "sync plan: window=\(usedWindow)h slices=\(slices.count) (oldest→newest, day-aligned) skipDedupe=\(skipDedupe) staleDays=\(staleDays.count)")

                    let intervalNs = UInt64(Constants.Network.healthSyncSliceIntervalMillis) * 1_000_000
                    for (idx, slice) in slices.enumerated() {
                        // 对账认定需要重传的天，绕过断点续传与水位线去重
                        let isStale = staleDays.contains(slice.start)

                        // 断点续传：完整日若已被记录为上传成功，跳过
                        if slice.isFullDay, !isStale, SyncSliceRecord.shared.hasUploadedDay(dayStart: slice.start) {
                            Log.info("SyncService", "slice \(idx + 1)/\(slices.count) day=\(Self.formatDay(slice.start)) already uploaded, skip")
                            continue
                        }

                        var sliceSeries = try await HealthDataManager.shared.fetchSeries(
                            from: slice.start,
                            to: slice.end,
                            maxSamples: Constants.Network.healthSyncMaxSamplesPerMetric
                        )
                        self?.logSeriesCounts(sliceSeries, stage: "slice \(idx + 1)/\(slices.count) fetch")
                        self?.filter(&sliceSeries, with: config)
                        if !skipDedupe, !isStale {
                            self?.dedupeUsingUploadState(&sliceSeries)
                        }

                        guard self?.hasAnyData(sliceSeries) == true else {
                            Log.info("SyncService", "slice \(idx + 1)/\(slices.count) empty after dedupe, skip")
                            // 完整日拿不到任何数据（数据源就没这天数据）→ 也标记已完成，免得下次再来拉一次空
                            if slice.isFullDay {
                                SyncSliceRecord.shared.markDayUploaded(dayStart: slice.start, metrics: [])
                            }
                            if idx < slices.count - 1 { try? await Task.sleep(nanoseconds: intervalNs) }
                            continue
                        }

                        let payload = HealthDataUploader.buildPayload(uid: uid, series: sliceSeries)
                        if payload.behaviors.isEmpty {
                            if idx < slices.count - 1 { try? await Task.sleep(nanoseconds: intervalNs) }
                            continue
                        }

                        _ = try await HealthDataUploader.postUpdateProfile(payload: payload, endpointURL: endpointURL)
                        let sliceMetrics = Array(payload.behaviors.keys).sorted()
                        Log.info("SyncService", "slice \(idx + 1)/\(slices.count) uploaded metrics=\(sliceMetrics.joined(separator: ","))")
                        self?.updateUploadStateAfterSuccess(series: sliceSeries)
                        // 只对完整日做持久化标记（今日的部分切片边界不稳定）
                        if slice.isFullDay {
                            SyncSliceRecord.shared.markDayUploaded(dayStart: slice.start, metrics: sliceMetrics)
                        }
                        uploadedKeys.append(contentsOf: sliceMetrics)

                        if idx < slices.count - 1 { try? await Task.sleep(nanoseconds: intervalNs) }
                    }

                    // 去重后聚合已上传的指标名
                    uploadedKeys = Array(Set(uploadedKeys)).sorted()

                    let dur = Date().timeIntervalSince(start)
                    // 整轮切片都跑完了才认为迁移成功
                    self?.finishSchemaMigrationIfNeeded(serverConfirmedCurrent: serverConfirmedCurrent)
                    let progress = SyncProgress(start: start, success: true, error: nil, duration: dur, uploadedMetrics: uploadedKeys)
                    self?.lastSyncDate = Date()
                    self?.postProgress(progress)
                } catch {
                    let dur = Date().timeIntervalSince(start)
                    // 必须打日志：这里原来只发进度通知，而接收方是进不去的同步设置页。
                    // 结果是切片循环里任何抛错（HealthKit 未授权 / 不可用等）都会静默
                    // 中断整轮同步，日志上表现为「打完某个 slice 就没下文」，无从排查。
                    Log.error("SyncService", "sync aborted after \(uploadedKeys.count) uploaded metric(s), \(String(format: "%.1f", dur))s: \(error.localizedDescription)")
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

    // MARK: - 口径版本迁移

    /// 与服务端对账，算出需要重传的天（自然日 00:00）。
    ///
    /// 判据 = 区间内**服务端没有的天** ∪ **版本低于当前口径的天**。
    /// 接口不可用（未上线 / 网络失败 / 未登录）时返回空集合，退到本地版本号兜底，
    /// **绝不能把「查不到」当成「服务端什么都没有」** —— 那样每次同步都会全量重传。
    private static func reconcileStaleDays(slices: [(start: Date, end: Date, isFullDay: Bool)]) async -> Set<Date>? {
        guard let first = slices.first?.start, let last = slices.last?.start else { return [] }

        // 节流：日常场景对账结果几乎恒为空，没必要每轮同步都发一次请求。
        // 但迁移尚未完成时必须每轮都查，否则重传进度推不动。
        // 迁移进行中、或本地记录的版本落后于当前口径时，都必须立刻对账，不受节流限制，
        // 否则升级后的重传会被拖延最多一小时。
        let migrating = UserDefaults.standard.object(forKey: schemaMigrationTargetKey) != nil
        let versionStale = (UserDefaults.standard.object(forKey: schemaVersionKey) as? Int) != Constants.Network.healthDataSchemaVersion
        let lastAt = UserDefaults.standard.object(forKey: reconcileAtKey) as? Double ?? 0
        if !migrating, !versionStale, Date().timeIntervalSince1970 - lastAt < reconcileMinInterval {
            return []
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"

        let serverState: [String: Int]
        do {
            serverState = try await HealthDataUploader.queryHealthSyncState(
                startDate: formatter.string(from: first),
                endDate: formatter.string(from: last)
            )
        } catch {
            Log.info("SyncService", "对账接口不可用，退到本地版本号兜底：\(error.localizedDescription)")
            return nil
        }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: reconcileAtKey)

        let current = Constants.Network.healthDataSchemaVersion
        var stale: Set<Date> = []
        for slice in slices {
            let key = formatter.string(from: slice.start)
            let serverVersion = serverState[key]
            if serverVersion == nil || serverVersion! < current {
                stale.insert(slice.start)
            }
        }
        if !stale.isEmpty {
            Log.info("SyncService", "对账结果：\(stale.count)/\(slices.count) 天需要按 v\(current) 重传")
        }
        return stale
    }

    /// 上次成功对账的时刻
    private static let reconcileAtKey = "health.data.lastReconcileAt"
    /// 对账最小间隔（秒）。迁移进行中不受此限制
    private static let reconcileMinInterval: TimeInterval = 3600

    /// 已【完成】迁移的口径版本
    private static let schemaVersionKey = "health.data.schemaVersion"
    /// 正在迁移到的目标版本。存在即表示重传尚未跑完
    private static let schemaMigrationTargetKey = "health.data.schemaMigrationTarget"

    /// 数据口径升级时，把已上传记录全部作废，让窗口内的历史按新口径重传一遍。
    ///
    /// 没有这一步的话，服务端会永远留着旧语义的历史数据：SyncSliceRecord 认为那些天
    /// 「已上传」直接跳过，UploadStateStore 的水位线也挡住了同一时间段的重传。结果就是
    /// 新老两套语义的数据混在同一个账号下，且旧的那批再也刷不掉。
    ///
    /// **两阶段提交**：这里只清记录并标记「迁移中」，版本号要等整轮重传成功跑完才落盘
    /// （见 finishSchemaMigrationIfNeeded）。否则 30 片重传跑到一半被杀掉 / 断网，版本号
    /// 却已经是新的，剩下的天再也不会重传——比不做迁移更糟，因为它把问题伪装成已完成。
    private func migrateIfSchemaVersionChanged() {
        let current = Constants.Network.healthDataSchemaVersion
        let done = UserDefaults.standard.object(forKey: Self.schemaVersionKey) as? Int
        guard done != current else { return }

        // 全新安装（既无上传记录也无水位线）：没有历史包袱，直接标记完成
        if done == nil, SyncSliceRecord.shared.getAll().isEmpty, UploadStateStore.shared.getAll().isEmpty {
            UserDefaults.standard.set(current, forKey: Self.schemaVersionKey)
            Log.info("SyncService", "schema version initialized to v\(current)（全新安装，无需重传）")
            return
        }

        // 已经在迁移中就不要重复清空——否则每轮同步都把刚传上去的记录again清掉，永远跑不完
        let target = UserDefaults.standard.object(forKey: Self.schemaMigrationTargetKey) as? Int
        guard target != current else {
            Log.info("SyncService", "schema migration to v\(current) 进行中，继续重传剩余切片")
            return
        }

        SyncSliceRecord.shared.reset()
        UploadStateStore.shared.reset()
        UserDefaults.standard.set(current, forKey: Self.schemaMigrationTargetKey)
        Log.info("SyncService", "schema version v\(done.map(String.init) ?? "未知") → v\(current)：已清空上传记录与水位线，窗口内历史将按新口径全量重传")
    }

    /// 整轮同步成功跑完后落盘版本号。两种情况都算「已迁移到当前口径」：
    ///
    /// 1. 兜底路径的整轮重传跑完（`schemaMigrationTarget` == 当前版本）
    /// 2. 对账明确回答「没有一天需要重传」（`serverConfirmedCurrent`）
    ///
    /// 第 2 种不可省：走对账路径时兜底迁移根本不执行，版本号就永远不落盘。等哪天对账
    /// 接口抖动一次退到兜底，会因为「本地无版本号 + 上传记录非空」被误判成老用户升级，
    /// 白白清空记录全量重传 30 天。
    private func finishSchemaMigrationIfNeeded(serverConfirmedCurrent: Bool) {
        let current = Constants.Network.healthDataSchemaVersion
        let migrationDone = UserDefaults.standard.object(forKey: Self.schemaMigrationTargetKey) as? Int == current

        guard migrationDone || serverConfirmedCurrent else { return }
        UserDefaults.standard.removeObject(forKey: Self.schemaMigrationTargetKey)

        guard (UserDefaults.standard.object(forKey: Self.schemaVersionKey) as? Int) != current else { return }
        UserDefaults.standard.set(current, forKey: Self.schemaVersionKey)
        Log.info("SyncService", "已确认服务端为 v\(current) 口径\(migrationDone ? "（重传完成）" : "（对账确认）")")
    }

    // MARK: - Window selection

    /// 决定本次同步的拉取窗口（小时数）。
    /// - 已有任一指标的 lastTs：从最早的 lastTs 回拉 + 缓冲（最小 1h，最大 30 天）
    /// - 从未同步过：按 30 天默认窗口，让新用户首次就能覆盖月视图
    private func determineWindowHours() -> Int {
        let capWindow = Constants.Network.healthSyncInitialWindowHours
        let lastTsValues = UploadStateStore.shared.getAll().values
        guard let minTs = lastTsValues.min() else {
            return capWindow
        }
        let secondsSince = Date().timeIntervalSince1970 - TimeInterval(minTs)
        let hoursSince = Int(ceil(secondsSince / 3600.0)) + Constants.Network.healthSyncIncrementalBufferHours
        return min(capWindow, max(1, hoursSince))
    }

    // MARK: - Dedupe helpers
    private func hasAnyData(_ series: HealthDataManager.HealthSeriesData) -> Bool {
        return !(
            series.sleepHeartRateRange == nil &&
            series.hrv.isEmpty &&
            series.respiratoryRate.isEmpty &&
            series.restingHeartRate.isEmpty &&
            series.sleepingWristTemperature.isEmpty &&
            series.bodyTemperature.isEmpty &&
            series.deepSleep.isEmpty &&
            series.remSleep.isEmpty &&
            series.lightSleep.isEmpty &&
            series.unspecifiedSleep.isEmpty &&
            series.awakeSleep.isEmpty &&
            series.inBed.isEmpty
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
        // 睡眠心率区间：按会话**终点**去重，不能用起点。
        // 半夜同步时这一晚还没睡完，传上去的是半截区间；醒来后区间变了但起点没变，
        // 用起点去重会把修正后的完整区间当成重复丢掉，服务端永远停在半截值。
        // 用终点：夜里每次同步终点都在推进 → 重发修正值（时间戳相同，服务端按后到的覆盖）；
        // 这一晚结束后终点不再变 → 自然停止重发。
        if let range = series.sleepHeartRateRange, let last = store.get("sleep_heart_rate"), range.endTs <= last {
            series.sleepHeartRateRange = nil
            Log.info("SyncService", "dedupe sleep_heart_rate: filtered 1 (last=\(last))")
        }
        filterPoints(&series.hrv, key: "sleep_heart_rate_variability_sdnn")
        filterPoints(&series.respiratoryRate, key: "sleep_respiratory_rate")
        filterPoints(&series.restingHeartRate, key: "resting_heart_rate")
        filterPoints(&series.sleepingWristTemperature, key: "sleeping_wrist_temperature")
        filterPoints(&series.bodyTemperature, key: "sleep_body_temperature")

        // 区间型序列按**终点**去重，不能用起点。
        // inBed 一晚只有一条合并后的区间，起点固定、时长随睡眠推进增长；睡眠阶段的
        // 最后一段同理。用起点去重会让半夜同步传上去的半截时长成为终值，醒来后修正
        // 的完整时长被当成重复丢弃，服务端的 Time in Bed 和睡眠效率会永远偏小。
        // 用终点：区间还在延长就重发修正值（起点相同，服务端按后到的覆盖）；
        // 区间定型后终点不再变，自然停止重发。
        func filterSleep(_ arr: inout [HealthDataManager.HealthSeriesData.SleepStagePoint], key: String) {
            if let last = store.get(key) {
                let before = arr.count
                arr = arr.filter { $0.endTs > last }
                Log.info("SyncService", "dedupe \(key): filtered \(before - arr.count) (last=\(last))")
            }
        }
        filterSleep(&series.deepSleep, key: "sleep_stage_deep")
        filterSleep(&series.remSleep, key: "sleep_stage_rem")
        filterSleep(&series.lightSleep, key: "sleep_stage_light")
        filterSleep(&series.unspecifiedSleep, key: "sleep_stage_unspecified")
        filterSleep(&series.awakeSleep, key: "sleep_stage_awake")
        filterSleep(&series.inBed, key: "sleep_in_bed")
    }

    /// 在服务端返回 success 后，记录各指标本次上传使用的最大时间戳
    private func updateUploadStateAfterSuccess(series: HealthDataManager.HealthSeriesData) {
        var maxTs: [String: Int] = [:]
        func recordMax(_ points: [HealthDataManager.HealthSeriesData.SamplePoint], key: String) {
            if let m = points.map({ $0.timestamp }).max() { maxTs[key] = m }
        }
        if let range = series.sleepHeartRateRange { maxTs["sleep_heart_rate"] = range.endTs }
        recordMax(series.hrv, key: "sleep_heart_rate_variability_sdnn")
        recordMax(series.respiratoryRate, key: "sleep_respiratory_rate")
        recordMax(series.restingHeartRate, key: "resting_heart_rate")
        recordMax(series.sleepingWristTemperature, key: "sleeping_wrist_temperature")
        recordMax(series.bodyTemperature, key: "sleep_body_temperature")

        // 与 filterSleep 保持一致：记终点
        func recordSleep(_ arr: [HealthDataManager.HealthSeriesData.SleepStagePoint], key: String) {
            if let m = arr.map({ $0.endTs }).max() { maxTs[key] = m }
        }
        recordSleep(series.deepSleep, key: "sleep_stage_deep")
        recordSleep(series.remSleep, key: "sleep_stage_rem")
        recordSleep(series.lightSleep, key: "sleep_stage_light")
        recordSleep(series.unspecifiedSleep, key: "sleep_stage_unspecified")
        recordSleep(series.awakeSleep, key: "sleep_stage_awake")
        recordSleep(series.inBed, key: "sleep_in_bed")

        if !maxTs.isEmpty {
            UploadStateStore.shared.update(maxTimestamps: maxTs)
            Log.info("SyncService", "updated upload state: \(maxTs)")
        }
    }

    private func filter(_ series: inout HealthDataManager.HealthSeriesData, with cfg: HealthSyncConfig) {
        // 如果某指标未被勾选，则清空对应数组
        if !cfg.metrics.contains(.heartRate) { series.sleepHeartRateRange = nil }
        if !cfg.metrics.contains(.hrv) { series.hrv.removeAll() }
        if !cfg.metrics.contains(.respiratoryRate) { series.respiratoryRate.removeAll() }
        if !cfg.metrics.contains(.restingHeartRate) { series.restingHeartRate.removeAll() }
        if !cfg.metrics.contains(.sleepingWristTemperature) { series.sleepingWristTemperature.removeAll() }
        if !cfg.metrics.contains(.bodyTemperature) { series.bodyTemperature.removeAll() }
        if !cfg.metrics.contains(.sleepStages) {
            series.deepSleep.removeAll(); series.remSleep.removeAll(); series.lightSleep.removeAll()
            series.unspecifiedSleep.removeAll(); series.awakeSleep.removeAll(); series.inBed.removeAll()
        }
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

extension HealthSyncService: @unchecked Sendable {}

// MARK: - Diagnostics
private extension HealthSyncService {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func formatDay(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    func logSeriesCounts(_ series: HealthDataManager.HealthSeriesData, stage: String) {
        let counts: [String: Int] = [
            "sleep_hr_range": series.sleepHeartRateRange == nil ? 0 : 1,
            "hrv": series.hrv.count,
            "respiratory_rate": series.respiratoryRate.count,
            "resting_heart_rate": series.restingHeartRate.count,
            "sleeping_wrist_temperature": series.sleepingWristTemperature.count,
            "body_temperature": series.bodyTemperature.count,
            "sleep_deep": series.deepSleep.count,
            "sleep_rem": series.remSleep.count,
            "sleep_light": series.lightSleep.count,
            "sleep_unspecified": series.unspecifiedSleep.count,
            "sleep_awake": series.awakeSleep.count,
            "sleep_in_bed": series.inBed.count
        ]
        Log.info("SyncService", "counts(\(stage))=\(counts)")
    }
}
