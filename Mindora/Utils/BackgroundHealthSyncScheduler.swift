import Foundation
import BackgroundTasks
import UIKit

/// 负责注册与调度低频后台健康数据同步任务（使用 BGAppRefreshTask）
/// - 设计策略：
///   - 使用任务标识符 `com.mindora.healthsync.refresh`
///   - 根据用户配置的同步间隔（15分钟/30分钟/1小时）设置最早执行时间。
///   - 每次任务执行后重新调度下一次。
///   - 若当前前台定时器已在运行（App 处于前台），后台任务仅作为兜底不重复主动执行同步。
///   - 若需要更可靠的长时任务（如上传耗时），未来可改用 `BGProcessingTask`。
final class BackgroundHealthSyncScheduler {
    static let shared = BackgroundHealthSyncScheduler()
    private init() {}

    static let taskIdentifier = "com.mindora.healthsync.refresh"

    /// 注册后台任务；应在 AppDelegate didFinishLaunching 中调用一次
    func register() {
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            // 确保类型
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleRefresh(task: refreshTask)
        }
        Log.info(
            "BGTask",
            "Register result identifier=\(Self.taskIdentifier) success=\(registered) backgroundRefreshStatus=\(backgroundRefreshStatusDescription()) simulator=\(isRunningOnSimulator())"
        )
    }

    /// 依据当前配置安排下一次后台刷新
    func scheduleIfNeeded() {
        // 先取消已存在的同类请求，避免重复
        cancelPending()
        let cfg = HealthSyncConfigStore.shared.current
        Log.info(
            "BGTask",
            "Schedule requested identifier=\(Self.taskIdentifier) enabled=\(cfg.enabled) interval=\(cfg.interval.rawValue)s backgroundRefreshStatus=\(backgroundRefreshStatusDescription()) simulator=\(isRunningOnSimulator())"
        )
        guard cfg.enabled else {
            Log.info("BGTask", "Skip scheduling because sync is disabled")
            return
        }

        guard !isRunningOnSimulator() else {
            Log.info("BGTask", "Skip scheduling on simulator because BGTaskScheduler submit is unsupported")
            return
        }

        guard UIApplication.shared.backgroundRefreshStatus == .available else {
            Log.info(
                "BGTask",
                "Skip scheduling because background refresh is unavailable status=\(backgroundRefreshStatusDescription())"
            )
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        let earliestBeginDate = Date().addingTimeInterval(derivedBackgroundInterval(from: cfg.interval))
        request.earliestBeginDate = earliestBeginDate
        Log.info(
            "BGTask",
            "Submitting refresh request identifier=\(request.identifier) earliestBeginDate=\(iso8601String(from: earliestBeginDate))"
        )

        do {
            try BGTaskScheduler.shared.submit(request)
            Log.info(
                "BGTask",
                "Submit succeeded identifier=\(request.identifier) earliestBeginDate=\(iso8601String(from: earliestBeginDate))"
            )
        } catch {
            Log.error(
                "BGTask",
                "Submit failed identifier=\(request.identifier) earliestBeginDate=\(iso8601String(from: earliestBeginDate)) diagnosis=\(diagnoseSubmitError(error)) rawError=\(error)"
            )
        }
    }

    /// 取消所有未执行的后台请求
    func cancelPending() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
    }

    private func handleRefresh(task: BGAppRefreshTask) {
        // 规划下一次
        scheduleIfNeeded()
        // 如果应用在前台且定时器正常运行，可直接完成（兜底策略）
        if UIApplication.shared.applicationState == .active {
            task.setTaskCompleted(success: true)
            return
        }

        let lock = NSLock()
        var observer: NSObjectProtocol?
        var didCompleteTask = false

        func finish(success: Bool, reason: String) {
            lock.lock()
            defer { lock.unlock() }
            guard !didCompleteTask else { return }
            didCompleteTask = true
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            Log.info("BGTask", "Refresh task completed success=\(success) reason=\(reason)")
            task.setTaskCompleted(success: success)
        }

        observer = NotificationCenter.default.addObserver(
            forName: HealthSyncService.progressNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let progress = notification.object as? HealthSyncService.SyncProgress else { return }
            finish(success: progress.success, reason: progress.success ? "sync finished" : "sync failed")
        }

        // 后台执行：触发一次同步（若满足条件）
        HealthSyncService.shared.performManualSync()

        // 超时兜底：若同步长时间没有回调，避免任务悬挂
        DispatchQueue.global().asyncAfter(deadline: .now() + 25) {
            finish(success: false, reason: "sync timeout")
        }

        // 如果任务超时，系统会终止；在 expiration 中结束任务并清理观察者
        task.expirationHandler = {
            Log.error("BGTask", "Refresh task expired")
            finish(success: false, reason: "system expiration")
        }
    }

    private func derivedBackgroundInterval(from interval: HealthSyncInterval) -> TimeInterval {
        return TimeInterval(interval.rawValue)
    }

    private func diagnoseSubmitError(_ error: Error) -> String {
        let nsError = error as NSError
        var reasons: [String] = []

        if nsError.domain == BGTaskScheduler.errorDomain,
           let code = BGTaskScheduler.Error.Code(rawValue: nsError.code) {
            switch code {
            case .unavailable:
                reasons.append("BGTaskScheduler unavailable")
                reasons.append("common_causes=simulator|Background App Refresh disabled|running in unsupported environment")
            case .tooManyPendingTaskRequests:
                reasons.append("too many pending task requests")
            case .notPermitted:
                reasons.append("identifier not permitted")
                reasons.append("check Info.plist BGTaskSchedulerPermittedIdentifiers and target capabilities")
            @unknown default:
                reasons.append("unknown BGTaskScheduler error code=\(nsError.code)")
            }
        } else {
            reasons.append("non-BGTaskScheduler error domain=\(nsError.domain) code=\(nsError.code)")
        }

        reasons.append("backgroundRefreshStatus=\(backgroundRefreshStatusDescription())")
        reasons.append("simulator=\(isRunningOnSimulator())")
        reasons.append("taskIdentifier=\(Self.taskIdentifier)")
        return reasons.joined(separator: " ; ")
    }

    private func backgroundRefreshStatusDescription() -> String {
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available:
            return "available"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        @unknown default:
            return "unknown"
        }
    }

    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func isRunningOnSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
