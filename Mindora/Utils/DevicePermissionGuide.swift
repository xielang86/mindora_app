import UIKit
import CoreBluetooth

/// 设备连接相关的权限兜底引导（蓝牙 / 本地网络）。
///
/// 为什么需要它：这两个权限已经从开屏挪到「用户进入设备流程」时才申请（见 SceneDelegate
/// 与 HomeViewController 的守卫）。而 iOS 的规则是——用户拒绝过一次之后，系统授权框
/// **不会再弹**，App 只能自己解释并把用户引到设置页。没有这层兜底，被拒的用户进设备页
/// 只会看到一个永远空的列表，得不到任何解释。
///
/// 两个权限的可检测性不同：
/// - 蓝牙：`CBCentralManager.authorization` 可直接查状态，进页面就能主动判断
/// - 本地网络：iOS **不提供**查询 API，只能等 Bonjour 报错回调后才知道被拒
enum DevicePermissionGuide {

    /// 进入设备页时主动检查一次蓝牙授权。已被拒 / 受限则弹引导，返回 true 表示已弹窗。
    ///
    /// 只处理 denied 与 restricted：notDetermined 要留给系统原生授权框（此刻启动
    /// discovery 正好会触发它），allowedAlways 无需处理。
    @discardableResult
    static func checkBluetoothOnEnter(from presenter: UIViewController) -> Bool {
        switch CBCentralManager.authorization {
        case .denied, .restricted:
            Log.info("DevicePermission", "蓝牙权限被拒，弹引导：\(CBCentralManager.authorization.rawValue)")
            showBluetoothDenied(from: presenter)
            return true
        default:
            return false
        }
    }

    /// 蓝牙状态回调判定为未授权（CBManagerState.unauthorized == 3）时调用。
    static func handleBluetoothFailure(state: Int, from presenter: UIViewController) {
        guard state == CBManagerState.unauthorized.rawValue else { return }
        showBluetoothDenied(from: presenter)
    }

    /// Bonjour 报错时调用。本地网络无法主动查询状态，只能靠这条路径兜底。
    static func handleLocalNetworkFailure(from presenter: UIViewController) {
        showAlert(
            titleKey: "permission.local_network.denied_title",
            messageKey: "permission.local_network.denied_message",
            from: presenter
        )
    }

    // MARK: - Private

    private static func showBluetoothDenied(from presenter: UIViewController) {
        showAlert(
            titleKey: "permission.bluetooth.denied_title",
            messageKey: "permission.bluetooth.denied_message",
            from: presenter
        )
    }

    /// 同一时刻只允许一个引导弹窗，避免蓝牙与本地网络同时失败时叠两层。
    private static var isPresenting = false

    private static func showAlert(titleKey: String, messageKey: String, from presenter: UIViewController) {
        guard !isPresenting, presenter.presentedViewController == nil, presenter.view.window != nil else { return }
        isPresenting = true

        let alert = CustomAlertViewController(
            title: L(titleKey),
            description: L(messageKey),
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
