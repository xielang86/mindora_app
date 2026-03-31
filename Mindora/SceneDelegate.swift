//
//  SceneDelegate.swift
//  mindora
//
//  Created by gao chao on 2025/9/18.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var themeObserver: NSObjectProtocol?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // 以纯 UIKit 方式创建窗口和根控制器
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)

        // 初始化主题系统 - 这会加载保存的主题设置并应用
        _ = Theme.shared

        // 应用全局外观（导航栏 / TabBar）
        applyGlobalAppearance()

        // 监听主题切换，实时更新外观
        themeObserver = NotificationCenter.default.addObserver(
            forName: Theme.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyGlobalAppearance()
        }
        
        // 监听语言切换，重置根视图
        NotificationCenter.default.addObserver(
            forName: LocalizationManager.languageDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadRootViewController()
        }

        // 检查是否已登录 (优先使用 AuthStorage 的判断逻辑，它会检查 Keychain)
        // 如果 Keychain 中有有效会话，自动恢复登录状态
        let isLoggedIn = AuthStorage.shared.isLoggedIn
        if isLoggedIn {
             UserDefaults.standard.set(true, forKey: "isLoggedIn")
        }
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        
        // 统一使用 LaunchScreenViewController 作为启动页
        let launchScreen = LaunchScreenViewController()
        window.rootViewController = launchScreen
        window.backgroundColor = Theme.background
        window.makeKeyAndVisible()
        self.window = window

        // 延迟 1.5秒后根据状态跳转
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let targetVC: UIViewController
            
            if isLoggedIn && hasSeenOnboarding {
                // 已经登录且完成引导页 -> 主界面
                let tab = MainTabBarController()
                targetVC = tab
                
                // 延迟检查权限
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.checkPermissionsOnLaunch(from: tab)
                }
            } else {
                // 其他情况（未登录 或 已登录未引导）统一进入开始页
                // StartViewController 内部的点击事件会处理具体跳转逻辑
                let startVC = StartViewController()
                let nav = UINavigationController(rootViewController: startVC)
                nav.setNavigationBarHidden(true, animated: false)
                targetVC = nav
            }
            
            // 执行转场动画
            launchScreen.transition(to: targetVC, in: window)
        }
    }

    deinit {
        if let obs = themeObserver { NotificationCenter.default.removeObserver(obs) }
    }

    // 将导航栏与 TabBar 的外观配置集中到一个方法，便于主题切换时复用
    private func applyGlobalAppearance() {
        guard #available(iOS 13.0, *) else { return }

        // UINavigationBar 外观
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = Theme.surface
        navAppearance.titleTextAttributes = [.foregroundColor: Theme.primary]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: Theme.primary]
        #if compiler(>=5.3)
        navAppearance.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -3)
        #endif

        let navProxy = UINavigationBar.appearance()
        navProxy.standardAppearance = navAppearance
        navProxy.scrollEdgeAppearance = navAppearance
        navProxy.tintColor = Theme.primary
        navProxy.setTitleVerticalPositionAdjustment(-3, for: .default)
        if #available(iOS 11.0, *) {
            navProxy.setTitleVerticalPositionAdjustment(-3, for: .defaultPrompt)
        }

        // UITabBar 外观
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundEffect = nil
        tabAppearance.backgroundColor = Theme.surface
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titlePositionAdjustment = .zero
        itemAppearance.selected.titlePositionAdjustment = .zero
        tabAppearance.stackedLayoutAppearance = itemAppearance
        tabAppearance.inlineLayoutAppearance = itemAppearance
        tabAppearance.compactInlineLayoutAppearance = itemAppearance

        let tabProxy = UITabBar.appearance()
        tabProxy.standardAppearance = tabAppearance
        if #available(iOS 15.0, *) { tabProxy.scrollEdgeAppearance = tabAppearance }
        tabProxy.tintColor = Theme.accent
        tabProxy.unselectedItemTintColor = Theme.secondary

        // 同步应用到当前已存在的实例（否则外观代理只对后续创建的控件生效）
        if let window = window {
            window.backgroundColor = Theme.background

            func applyRecursively(_ vc: UIViewController) {
                if let nav = vc as? UINavigationController {
                    nav.navigationBar.standardAppearance = navAppearance
                    nav.navigationBar.scrollEdgeAppearance = navAppearance
                    nav.navigationBar.tintColor = Theme.primary
                }
                if let tab = vc as? UITabBarController {
                    tab.tabBar.standardAppearance = tabAppearance
                    if #available(iOS 15.0, *) { tab.tabBar.scrollEdgeAppearance = tabAppearance }
                    tab.tabBar.tintColor = Theme.accent
                    tab.tabBar.unselectedItemTintColor = Theme.secondary
                }
                for child in vc.children { applyRecursively(child) }
                if let presented = vc.presentedViewController { applyRecursively(presented) }
            }

            if let root = window.rootViewController {
                applyRecursively(root)
                root.view.setNeedsLayout()
                root.view.layoutIfNeeded()
            }
        }
    }
    
    // 重载根视图，用于语言切换
    private func reloadRootViewController() {
        guard let window = self.window else { return }
        
        let isLoggedIn = AuthStorage.shared.isLoggedIn
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        
        let targetVC: UIViewController
        if isLoggedIn && hasSeenOnboarding {
            // 重新创建 TabBar 及其子控制器，会重新加载本地化字符串
            targetVC = MainTabBarController()
        } else {
            let startVC = StartViewController()
            let nav = UINavigationController(rootViewController: startVC)
            nav.setNavigationBarHidden(true, animated: false)
            targetVC = nav
        }
        
        print("Reloading root view controller due to language change...")
        
        // 使用过渡动画切换 rootViewController
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            window.rootViewController = targetVC
        }, completion: nil)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    // MARK: - Permission Check
    
    /// 在应用启动时检查权限并提醒用户
    private func checkPermissionsOnLaunch(from rootViewController: UIViewController) {
        // 检查是否需要显示权限提醒
        if PermissionManager.shared.shouldShowHealthReminder() {
            PermissionManager.shared.showHealthPermissionReminder(from: rootViewController)
        }
    }


}

