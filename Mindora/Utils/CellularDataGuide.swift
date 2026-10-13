import UIKit
import Network
import CoreTelephony

/// 蜂窝数据被禁用时的兜底引导（国行 iOS「无线数据」被设为关闭/仅 WLAN）。
///
/// 为什么需要它：这种机器上蜂窝网络本身是好的，但系统裁决 Denied over cellular
/// interface，App 所有请求秒失败 -1009。用户看到的只是首页评分等在线内容全空，
/// 完全想不到要去设置里给 App 开无线数据——系统不会替 App 解释，只能自己弹。
///
/// ⚠️ 判定必须两个条件同时成立，缺一不可：
/// 1. `NWPath.unsatisfiedReason == .cellularDenied`——当前确实因蜂窝被禁而没网；
/// 2. `CTCellularData.restrictedState == .restricted`——用户**明确拒绝**过。
///
/// 只看第 1 条会误伤首次启动：国行机首次联网时系统会弹「无线数据」授权框，在用户
/// 回答之前 unsatisfiedReason 同样是 .cellularDenied。此刻弹自己的「去设置」引导，
/// 等于抢在系统弹窗前面催用户改设置，而他其实只要点一下「允许」。
/// restrictedState 为 .restrictedStateUnknown（尚未回答）时一律不弹——它会在系统
/// 回调后落定，本次启动的后续 viewDidAppear 会重新判定，不会漏。
///
/// 打扰控制：连着 Wi-Fi 或蜂窝可用时路径是 satisfied，永远不弹；确实被拒时
/// 每次启动最多提醒一次，且跨启动有 24 小时冷却。
enum CellularDataGuide {

    private static let lastPromptKey = "cellularGuide.lastPromptAt"
    private static let promptCooldown: TimeInterval = 24 * 60 * 60
    private static var didPromptThisLaunch = false
    private static var isPresenting = false

    static func checkAndRemindIfNeeded(from presenter: UIViewController) {
        guard !didPromptThisLaunch, !isPresenting else { return }
        let last = UserDefaults.standard.double(forKey: lastPromptKey)
        guard Date().timeIntervalSince1970 - last >= promptCooldown else { return }

        // 先查是否明确拒绝过：未决定（首次启动、系统弹窗还没回答）直接放弃这一轮。
        guard PermissionManager.shared.cellularRestrictedState == .restricted else { return }

        detectCellularDenied { denied in
            guard denied else { return }
            guard !didPromptThisLaunch, !isPresenting else { return }
            // 别叠在弹窗/引导上面；这次没轮上就等下次 viewDidAppear 再查。
            guard presenter.presentedViewController == nil, presenter.view.window != nil else { return }
            didPromptThisLaunch = true
            isPresenting = true
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastPromptKey)
            Log.info("CellularGuide", "蜂窝数据被明确拒绝且无其他可用网络，弹设置引导")

            let alert = CustomAlertViewController(
                title: L("permission.cellular.denied_title"),
                description: L("permission.cellular.denied_message"),
                confirmButtonTitle: L("permission.open_settings"),
                cancelButtonTitle: L("common.cancel"),
                onConfirm: {
                    isPresenting = false
                    PermissionManager.shared.openAppSettings()
                },
                onCancel: { isPresenting = false }
            )
            presenter.present(alert, animated: true)
        }
    }

    /// 一次性查询当前网络路径：仅当「整体不可用，且原因是蜂窝被本 App 禁用」时回调 true。
    private static func detectCellularDenied(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            monitor.cancel()
            let denied = path.status != .satisfied && path.unsatisfiedReason == .cellularDenied
            DispatchQueue.main.async { completion(denied) }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }
}
