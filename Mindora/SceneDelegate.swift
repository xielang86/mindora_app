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
        Log.info("SceneDelegate", "willConnectTo start")
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

        // 监听 token 过期：切到 re-auth 邮箱页 + toast
        NotificationCenter.default.addObserver(
            forName: .sessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSessionExpired()
        }

        // token 变化（登录 / 换账号 / 登出）：前台常驻服务的启停以登录态为准。
        // 登录成功那一刻把设备发现等拉起来，登出时停掉 —— 见 startForegroundServices。
        NotificationCenter.default.addObserver(
            forName: AuthStorage.tokenDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startForegroundServices()
            // 登录成功那一刻把该账号的站内消息从服务端要回来。
            // 挂在 tokenDidChange 而不是 sceneDidBecomeActive：前者只在登录 / 换账号 / 登出
            // 时发一次，后者每次回前台都发 —— 恢复是一次性动作，不该做成轮询。
            if AuthStorage.shared.isLoggedIn {
                // 登出已经不再清站内消息了（见 SessionResetter 的 notifications 项），
                // 同账号重登本地就是完好的，不必再向服务端要一遍。
                // 真正需要恢复的只剩：换账号（消息被清）、重装、换设备。
                PopupService.shared.restoreHistory(reason: "login", onlyIfLocalEmpty: true)
                // 登出会清空本地资料（防串号），不在登录时拉回来的话，退出重进就是一片空白 ——
                // 侧栏没昵称没头像，改一个字段还会把服务端已有的其余字段覆盖成空串。
                // 换账号同理：先复位「已拉过」标记，免得沿用上一账号的结论。
                UserProfileSync.resetRemoteFlag()
                UserProfileSync.pull(reason: "login")
            }
        }

        // 检查是否已登录 (优先使用 AuthStorage 的判断逻辑，它会检查 Keychain)
        // 如果 Keychain 中有有效会话，自动恢复登录状态
        let isLoggedIn = AuthStorage.shared.isLoggedIn
        if isLoggedIn {
               UserDefaults.standard.set(true, forKey: Constants.Storage.UserDefaults.isLoggedIn)
               // 冷启动也恢复一次：Keychain 里的清单能活过「删除 App 重装」（iOS 上 Keychain
               // 不随 App 卸载而清），但站内消息在 UserDefaults 里，重装就没了。
               // 这条路径上 tokenDidChange 不会触发，只能在这里补。
               // onlyIfLocalEmpty：本地消息还在就什么都不做，不为每次启动多发一次请求。
               PopupService.shared.restoreHistory(reason: "cold_launch", onlyIfLocalEmpty: true)
               // 资料同理：冷启动拉一次，侧栏昵称/头像不必等用户点进资料页才正确。
               UserProfileSync.pull(reason: "cold_launch")
               // 把旧版遗留的问卷「已提交」标记迁进按账号隔离的清单。
               // 必须趁登录态还在时做 —— 惰性迁移会被登出清理抢先，见 SurveyService。
               SurveyService.shared.migrateLegacySubmitted()
        }
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

        Log.info("SceneDelegate", "state isLoggedIn=\(isLoggedIn) hasSeenOnboarding=\(hasSeenOnboarding)")
        #if DEBUG
        let storedEmail = AuthStorage.shared.email ?? ""
        let storedUID = AuthStorage.shared.uid ?? ""
        let tokenLen = AuthStorage.shared.token?.count ?? 0
        let expDate = AuthStorage.shared.expirationDate.map { "\($0)" } ?? "<nil>"
        Log.info("SceneDelegate", "[DEBUG] boot details email=\(storedEmail) uid=\(storedUID) tokenLen=\(tokenLen) expirationDate=\(expDate)")
        #endif

        // 注意：iOS 26 上如果直接把 MainTabBarController 设为 rootViewController 再
        // makeKeyAndVisible，view 不会被正常 attach 到 window（viewWillAppear 时
        // view.window == nil，viewDidAppear 不触发，表现为黑屏/进不了首页）。
        // 规避做法：先用一个轻量占位 VC 作为初始 root 把 window / scene 稳下来，
        // 下一个 runloop 再换成真正的 root。
        let placeholder = LaunchScreenViewController()
        window.rootViewController = placeholder
        window.backgroundColor = Theme.background
        window.makeKeyAndVisible()
        self.window = window

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }

            let rootVC: UIViewController
            if isLoggedIn && hasSeenOnboarding {
                Log.info("SceneDelegate", "route → MainTabBar (logged in & onboarded)")
                let tab = MainTabBarController()
                rootVC = tab
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.checkPermissionsOnLaunch(from: tab)
                }
            } else {
                Log.info("SceneDelegate", "route → StartViewController (isLoggedIn=\(isLoggedIn) hasSeenOnboarding=\(hasSeenOnboarding))")
                rootVC = self.makeStartRootViewController()
            }

            window.rootViewController = rootVC
            window.makeKeyAndVisible()

            Log.info("SceneDelegate", "root set root=\(type(of: rootVC)) windowFrame=\(window.frame) isKey=\(window.isKeyWindow)")
        }
    }

    /// 构造 StartViewController 包一层 nav 作为 root。
    /// 第一次安装、主动登出、token 过期都共用这一个起点；
    /// re-auth 与否由 RegisterP1Controller 自己根据本地 email + hasSeenOnboarding 自动识别。
    private func makeStartRootViewController() -> UIViewController {
        let startVC = StartViewController()
        let nav = UINavigationController(rootViewController: startVC)
        nav.setNavigationBarHidden(true, animated: false)
        return nav
    }

    /// 运行中收到 token 过期通知：toast + 切 root 到 StartViewController。
    private func handleSessionExpired() {
        // token 没了就回到「未登录」的开销水位：停掉设备发现等前台常驻服务。
        // 清 token 的那几个方法不发 tokenDidChange，只能在这里收口。
        startForegroundServices()

        guard let window = self.window else {
            SessionExpirationCenter.resetHandlingFlag()
            return
        }

        // 如果当前 root 已经是 Start nav，就什么都不做
        if let nav = window.rootViewController as? UINavigationController,
           nav.viewControllers.first is StartViewController {
            SessionExpirationCenter.resetHandlingFlag()
            return
        }

        Toast.show(L("auth.session_expired"), in: window)

        let target = makeStartRootViewController()
        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve, animations: {
            window.rootViewController = target
        }, completion: { _ in
            SessionExpirationCenter.resetHandlingFlag()
        })
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
            targetVC = makeStartRootViewController()
        }
        
        print("Reloading root view controller due to language change...")
        
        // 直接替换 rootViewController，避免窗口级动画导致新 VC 无法上屏。
        window.rootViewController = targetVC
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
        startForegroundServices()

        // 陪伴足迹与登录无关（本地计时 + 待传队列），放在门禁之外，
        // 保证它和 sceneDidEnterBackground 的 handleAppEnteredBackground 一定成对。
        FootprintTracker.shared.handleAppBecameActive()

        // 补发积压的订阅上报。未登录时 flush 内部自己会跳过并保留队列。
        SubscriptionReportService.shared.flush(reason: "foreground")
        // 服务端会员状态回前台刷新（10 分钟冷却；未登录内部跳过）。
        MembershipStatusService.shared.refresh(reason: "foreground")

        // 睡眠计划回前台同步：错峰 0–30s（与陪伴足迹上报一致）。用户不在等这个结果，
        // 不错峰的话所有设备会在「早晨集体解锁手机」这个尖峰上一起撞过来。
        NetworkPacing.afterSpread(upTo: 30) {
            SleepPlanSyncService.shared.sync(reason: "foreground")
        }
    }

    /// 前台常驻服务的统一入口。**未登录一律不启动**。
    ///
    /// 这些服务全都以「有 token + 有已绑设备」为前提：设备发现是为了给设备补推 JWT，
    /// 弹窗轮询没有凭证会直接早退。而停在欢迎页时两者都不存在，跑起来纯粹是空耗 ——
    /// BLE 用的是 AllowDuplicates 扫描（射频不做占空比压缩）、Bonjour 持续 mDNS 浏览，
    /// 两者都会让手机明显发热掉电，且扫到的结果没有任何消费方。
    ///
    /// 登录成功后由 `AuthStorage.tokenDidChangeNotification` 再次调进来，不会漏启动。
    private func startForegroundServices() {
        guard AuthStorage.shared.isLoggedIn else {
            // 登出 / token 过期回到欢迎页时也会走到这里：必须显式停掉，
            // 否则登录期间开起来的扫描会一直留在前台跑。
            UnifiedDeviceDiscovery.shared.stop()
            DeviceLoginPusher.shared.stopPeriodicSync()
            PopupService.shared.stopPeriodicSync()
            Log.info("SceneDelegate", "未登录，前台常驻服务保持停止（设备发现 / 补推 / 弹窗轮询）")
            return
        }

        // 设备发现在「整个前台期间」持续运行（幂等）。这是 token 同步可靠性的关键：
        // DeviceLoginPusher 的心跳重试依赖 UnifiedDeviceDiscovery.didUpdate；只有 discovery
        // 一直在跑，重新登录 / 设备刚上线后的 JWT 补推才能在设备可达的瞬间送达。
        // 不再依赖各设备页自己 start/stop（会留下 discovery 关闭的空窗、导致补推丢失）。
        //
        // 但**仅在已绑定设备时**启动：discovery 会同时拉起 Bonjour 与 BLE，各自触发
        // 「本地网络」和「蓝牙」系统权限弹窗。没绑过设备的用户一打开 App 就连收两个
        // 弹窗，而他既没有硬件、也不知道这两个权限做什么用。此时 JWT 补推本来也是
        // 空操作（没有设备可推），启动 discovery 没有任何收益。
        // 用户点进设备页时，DeviceManagement / DeviceScan 会自行启动 discovery，
        // 权限在那一刻才申请——用户此时明确知道为什么需要它。
        if !DeviceSession.shared.entries.isEmpty {
            UnifiedDeviceDiscovery.shared.startContinuous()
        } else {
            Log.info("SceneDelegate", "未绑定设备，跳过设备发现（避免开屏就弹蓝牙/本地网络权限）")
        }

        // 应用变 active 时机（冷启动 / 从后台回前台）：补推所有已绑设备的 JWT。覆盖：
        //   - 冷启动后用户从来不点 Device 菜单 → 之前没有任何 push 触发
        //   - App 后台一阵子后回前台 → 设备可能刚上线 / token 可能刚刷新
        // 指纹去重保证不会浪费请求；force=true 跳 cooldown（用户回 App 的动作不算被动）。
        DeviceLoginPusher.shared.pushPendingForAllEntries()

        // 启动后（本进程仅一次）对所有已绑设备无条件重推一次 JWT：指纹记忆是客户端单方面的，
        // 设备侧丢 token 时察觉不到，重启 App 是用户最自然的人为干预手段，必须能自愈。
        DeviceLoginPusher.shared.forceRepushAllOnLaunch()

        // 前台周期同步：每隔固定间隔对可达设备无条件重推一次当前 token，
        // 兜底指纹判据察觉不到的情况（设备重启丢 token、某次推送未真正生效等）。
        DeviceLoginPusher.shared.startPeriodicSync()

        // 首页弹窗配置：冷启动 / 回前台就同步一次（内部有 5 分钟最小间隔），
        // 不等用户切到首页 —— 站内消息与问卷预拉都在这一步完成。
        PopupService.shared.sync(reason: "scene_active")
        // 之后按服务端 next_query_after（无下发时 5 分钟）在前台周期性再拉：
        // 只靠冷启动 / 回前台两个触发点的话，App 长期挂前台时新配的弹窗永远到不了。
        PopupService.shared.startPeriodicSync()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        // 「读不到健康数据」引导每次前台最多一条（日/周/月共用），这里复位会话标记。
        // 真正的频控是 24 小时冷却 + 最多 6 次，在 PermissionManager 里。
        PermissionManager.resetHealthDataUnreadableSession()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // 进入后台停止设备发现 + 周期同步，省电（前台回来时 sceneDidBecomeActive 会重启）。
        UnifiedDeviceDiscovery.shared.stop()
        DeviceLoginPusher.shared.stopPeriodicSync()
        PopupService.shared.stopPeriodicSync()

        // 陪伴足迹：结算本次前台会话（助眠陪伴时长）并补传。
        FootprintTracker.shared.handleAppEnteredBackground()
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

