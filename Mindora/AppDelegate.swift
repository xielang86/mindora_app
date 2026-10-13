//
//  AppDelegate.swift
//  mindora
//
//  Created by gao chao on 2025/9/18.
//

import UIKit
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // 语言变化监听要早于任何界面发起请求：服务端文案缓存必须先作废，
        // 否则根视图重建时会先拿旧语种的缓存渲染一遍。
        LanguageChangeCoordinator.start()
        // Keychain 可访问性迁移要排在任何读 token 的代码之前：老条目锁屏时读不到，
        // 后台同步会因此静默失败。见 AuthStorage.migrateAccessibilityIfNeeded。
        AuthStorage.shared.migrateAccessibilityIfNeeded()
        // App 审核演示账号：对齐构造数据的生效态。必须排在健康同步启动**之前** ——
        // 同步一跑就会去读 HealthDataSimulator，晚了这一次读到的就是真机的空数据。
        HealthDataSimulator.shared.primeAppReviewDemoState()
        // 启动健康自动同步（若已启用）
        HealthSyncService.shared.startIfNeeded()
        // 注册后台刷新任务
        BackgroundHealthSyncScheduler.shared.register()
        // 预调度一次后台任务（若启用）
        BackgroundHealthSyncScheduler.shared.scheduleIfNeeded()
        // 提前实例化 DeviceLoginPusher，确保它的 token 变化 / discovery 监听在启动时就生效，
        // 避免登录发生在 .shared 首次访问之前而漏掉同步。
        _ = DeviceLoginPusher.shared
        // 启动站内消息生成引擎：监听订阅/权限/健康事件，动态生成通知（内建去重 + 冷却）。
        AppNotificationEngine.shared.start()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // 进入后台时，重新调度后台任务（确保最新配置生效）
        BackgroundHealthSyncScheduler.shared.scheduleIfNeeded()
    }


}

