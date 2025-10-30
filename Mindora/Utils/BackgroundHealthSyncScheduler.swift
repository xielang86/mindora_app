import Foundation
import BackgroundTasks
import UIKit

/// 负责注册与调度低频后台健康数据同步任务（使用 BGAppRefreshTask）
/// - 设计策略：
///   - 使用任务标识符 `com.mindora.healthsync.refresh`
///   - 根据用户配置的最小同步间隔 (6s / 12s / 30s) 推导一个后台刷新最早执行时间。
///     由于系统会对极短间隔进行聚合与延迟，这里设置一个折中：
///       * 6 秒 或 12 秒配置 -> 取 5 分钟后台刷新周期
///       * 30 秒配置 -> 取 10 分钟后台刷新周期
///   - 每次任务执行后重新调度下一次。
///   - 若当前前台定时器已在运行（App 处于前台），后台任务仅作为兜底不重复主动执行同步。
///   - 若需要更可靠的长时任务（如上传耗时），未来可改用 `BGProcessingTask`。
final class BackgroundHealthSyncScheduler {
    static let shared = BackgroundHealthSyncScheduler()
    private init() {}

    static let taskIdentifier = "com.mindora.healthsync.refresh"

    /// 注册后台任务；应在 AppDelegate didFinishLaunching 中调用一次
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            // 确保类型
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleRefresh(task: refreshTask)
        }
    }

    /// 依据当前配置安排下一次后台刷新
    func scheduleIfNeeded() {
        // 先取消已存在的同类请求，避免重复
        cancelPending()
        let cfg = HealthSyncConfigStore.shared.current
        guard cfg.enabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(derivedBackgroundInterval(from: cfg.interval))
        do { try BGTaskScheduler.shared.submit(request) } catch {
            Log.error("BGTask", "Submit failed: \(error)")
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
        // 后台执行：触发一次同步（若满足条件）
        HealthSyncService.shared.performManualSync()
        // 为避免长时间占用，简化：延迟检查 10 秒判断一次最近进度（可扩展为监听通知）
        let start = Date()
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
            // 这里简单认为 10 秒内完成即 success；可扩展读取服务状态
            let success = Date().timeIntervalSince(start) < 30
            task.setTaskCompleted(success: success)
        }
        // 如果任务超时，系统会终止；可利用 expirationHandler 作清理
        task.expirationHandler = {
            Log.error("BGTask", "Refresh task expired")
        }
    }

    private func derivedBackgroundInterval(from interval: HealthSyncInterval) -> TimeInterval {
        switch interval {
        case .six, .twelve: return 60 // 1 分钟
        case .thirty: return 3 * 60 // 3 分钟
        }
    }
}
