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
        // 启动健康自动同步（若已启用）
        HealthSyncService.shared.startIfNeeded()
        // 注册后台刷新任务
        BackgroundHealthSyncScheduler.shared.register()
        // 预调度一次后台任务（若启用）
        BackgroundHealthSyncScheduler.shared.scheduleIfNeeded()
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

