//
//  SleepPlanUpsellPresenter.swift
//  mindora
//
//  「高级会员功能」升级提示的统一入口（对应 01.F / 02.P 等升级弹窗），以及 03.M/03.N
//  「普通会员点击新建→停留首页提示升级→升级成功后自动返回并进入自定义计划编辑页」的回流。
//
import UIKit

enum SleepPlanUpsellPresenter {

    /// 通用「高级会员功能」升级提示：取消（描边）/ 升级高级会员（纯白主按钮）→ 跳订阅页。
    /// - Parameter onUpgradeSuccess: 订阅页里购买成功、等级变为高级会员后调用（订阅页会自动收起）。
    ///   用于 03.M/03.N 回流：从「新建计划」触发升级时传入，成功后直接进入自定义计划编辑页。
    static func presentPremiumUpsell(from viewController: UIViewController, onUpgradeSuccess: (() -> Void)? = nil) {
        // 02.P：官方预设点击入睡提醒/闹钟方案时的文案。
        presentUpsell(from: viewController, message: L("sleepplan.alert.premium_required.message"),
                      onUpgradeSuccess: onUpgradeSuccess)
    }

    /// 「新建计划」入口：普通会员/未订阅点击后走这个（不进入自定义编辑页），见 01.F。
    /// 文案与 `presentPremiumUpsell` 不同（CSS 逐值核对两处不是同一句话），单独取一份 key。
    static func presentCustomPlanUpsell(from viewController: UIViewController, onUpgradeSuccess: (() -> Void)? = nil) {
        presentUpsell(from: viewController, message: L("sleepplan.alert.custom_plan_required.message"),
                      onUpgradeSuccess: onUpgradeSuccess)
    }

    private static func presentUpsell(from viewController: UIViewController, message: String,
                                       onUpgradeSuccess: (() -> Void)?) {
        ConfirmDialogView.present(
            title: L("sleepplan.alert.premium_required.title"),
            message: message,
            outlineTitle: L("common.cancel"),
            solidTitle: L("sleepplan.action.upgrade_premium"),
            onSolid: {
                let vc = SubscriptionViewController()
                let nav = UINavigationController(rootViewController: vc)
                nav.modalPresentationStyle = .fullScreen
                if let onUpgradeSuccess {
                    observeUpgradeSuccess(presentedOn: viewController, presented: nav, onSuccess: onUpgradeSuccess)
                }
                viewController.present(nav, animated: true)
            })
    }

    /// 监听购买成功：等级变为高级会员时自动收起订阅页并回调，一次性观察，收起后立即移除。
    private static func observeUpgradeSuccess(presentedOn viewController: UIViewController,
                                                presented nav: UINavigationController,
                                                onSuccess: @escaping () -> Void) {
        let box = ObserverTokenBox()
        box.token = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SubscriptionStatusChanged"), object: nil, queue: .main
        ) { _ in
            // queue:.main 保证运行在主线程；显式 Task{@MainActor} 满足编译期严格并发检查。
            Task { @MainActor in
                guard SubscriptionManager.shared.membershipTier == .premium else { return }
                if let token = box.token { NotificationCenter.default.removeObserver(token) }
                nav.dismiss(animated: true) { onSuccess() }
            }
        }
    }
}

/// 持有一次性通知观察者的 token，避免在 @Sendable 闭包里直接捕获/改写局部 var。
private final class ObserverTokenBox: @unchecked Sendable {
    var token: NSObjectProtocol?
}
