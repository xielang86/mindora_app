//
//  AppRoute.swift
//  Mindora
//
//  服务端下发 action_type = "route" 时，action_payload.route 的取值集合。
//  客户端只认识这里列出的常量；未知值一律按 nil 处理，由调用方决定兜底行为
//  （商城活动 / 广告默认回落到商城 Tab）。
//  与 Tools/doc/弹窗与调查问卷接口.md「route 候选常量」表保持一致。
//

import UIKit

enum AppRoute: String, CaseIterable {
    // 一级 Tab
    case home
    case sleep
    case explore
    case store

    // 二级页面（模态全屏）
    case subscription
    case redeem
    case footprint
    case device
    case profile
    case settings
    case faq
    case notifications

    /// 一级 Tab 对应的索引；二级页面为 nil。
    var tabIndex: Int? {
        switch self {
        case .home: return 0
        case .sleep: return 1
        case .explore: return 2
        case .store: return 3
        default: return nil
        }
    }

    /// 只认下表列出的常量本身（不设别名）；仅忽略大小写与首尾空格。
    static func parse(_ raw: String?) -> AppRoute? {
        guard let raw else { return nil }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        return AppRoute(rawValue: key)
    }

    /// 二级页面的目标控制器；一级 Tab 返回 nil（走切 Tab 逻辑）。
    fileprivate func makeViewController() -> UIViewController? {
        switch self {
        case .home, .sleep, .explore, .store:
            return nil
        case .subscription:
            let vc = SubscriptionViewController()
            vc.modalPresentationStyle = .fullScreen
            return vc
        case .redeem:
            let vc = RedeemCodeViewController()
            vc.modalPresentationStyle = .fullScreen
            return vc
        case .footprint:
            let vc = CompanionFootprintViewController()
            vc.modalPresentationStyle = .fullScreen
            return vc
        case .device:
            // 设备页与侧栏保持一致：包一层隐藏导航栏的 NavigationController。
            let nav = UINavigationController(rootViewController: DeviceManagementViewController())
            nav.setNavigationBarHidden(true, animated: false)
            nav.modalPresentationStyle = .fullScreen
            return nav
        case .profile:
            let vc = UserProfileViewController()
            vc.modalPresentationStyle = .overFullScreen
            vc.modalTransitionStyle = .crossDissolve
            return vc
        case .settings:
            let vc = SettingsViewController()
            vc.modalPresentationStyle = .fullScreen
            return vc
        case .faq:
            let vc = FAQViewController()
            vc.modalPresentationStyle = .fullScreen
            return vc
        case .notifications:
            let vc = NotificationsViewController()
            vc.modalPresentationStyle = .fullScreen
            return vc
        }
    }
}

enum AppRouter {

    /// 打开一个已知路由。切 Tab 或打开二级页前，会先关掉调用方所在的整条模态栈。
    static func open(_ route: AppRoute, from source: UIViewController) {
        let tab = resolveMainTab(from: source)

        if let index = route.tabIndex {
            tab?.selectedIndex = index
            dismissModalStack(from: source, completion: nil)
            return
        }

        dismissModalStack(from: source) {
            guard let vc = route.makeViewController() else { return }
            let host = topPresented(from: tab) ?? topPresented(from: source) ?? source
            host.present(vc, animated: true)
        }
    }

    /// 解析并打开服务端下发的 route；无法识别时用 `fallback`（可为 nil 表示不动）。
    /// 返回是否发生了跳转。
    @discardableResult
    static func open(rawRoute: String?, from source: UIViewController, fallback: AppRoute? = nil) -> Bool {
        if let route = AppRoute.parse(rawRoute) {
            open(route, from: source)
            return true
        }
        if let fallback {
            Log.info("AppRouter", "unknown route \"\(rawRoute ?? "")\" → fallback \(fallback.rawValue)")
            open(fallback, from: source)
            return true
        }
        Log.info("AppRouter", "unknown route \"\(rawRoute ?? "")\" → ignored")
        return false
    }

    // MARK: - Helpers

    /// 关掉 source 所在的整条模态栈（source 不是模态呈现时直接回调）。
    private static func dismissModalStack(from source: UIViewController, completion: (() -> Void)?) {
        guard source.presentingViewController != nil else {
            completion?()
            return
        }
        var bottomModal = source
        while let presenter = bottomModal.presentingViewController, presenter.presentingViewController != nil {
            bottomModal = presenter
        }
        if let presenter = bottomModal.presentingViewController {
            presenter.dismiss(animated: true, completion: completion)
        } else {
            source.dismiss(animated: true, completion: completion)
        }
    }

    private static func topPresented(from vc: UIViewController?) -> UIViewController? {
        guard var cur = vc else { return nil }
        while let next = cur.presentedViewController { cur = next }
        return cur
    }

    /// MainTabBarController 是自定义容器（非 UITabBarController），系统属性取不到，
    /// 依次沿 parent 链 → presenting 链 → 窗口根查找。
    static func resolveMainTab(from source: UIViewController) -> MainTabBarController? {
        var parent: UIViewController? = source.parent
        while let cur = parent {
            if let tab = cur as? MainTabBarController { return tab }
            parent = cur.parent
        }
        var presenter = source.presentingViewController
        while let cur = presenter {
            if let tab = find(in: cur) { return tab }
            presenter = cur.presentingViewController
        }
        let root = source.view.window?.rootViewController
            ?? UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
        return find(in: root)
    }

    private static func find(in vc: UIViewController?) -> MainTabBarController? {
        guard let vc else { return nil }
        if let tab = vc as? MainTabBarController { return tab }
        if let nav = vc as? UINavigationController { return find(in: nav.viewControllers.first) }
        for child in vc.children { if let tab = find(in: child) { return tab } }
        return find(in: vc.presentedViewController)
    }
}
