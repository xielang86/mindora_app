//
//  AppVersionChecker.swift
//  mindora
//
//  Created by gao chao on 2025/10/21.
//
//  App 版本检查工具 - 检查 App Store 更新
//

import UIKit

/// App 版本检查结果
enum VersionCheckResult {
    case upToDate(currentVersion: String)
    case updateAvailable(currentVersion: String, appStoreVersion: String)
    case error(message: String)
}

/// App 版本检查工具类
final class AppVersionChecker {
    
    // MARK: - Properties
    
    /// App Store ID - 需要替换为实际的 App Store ID
    /// 可以在 App Store Connect 中找到，或从 App Store URL 中获取
    private let appStoreID: String
    
    /// 当前应用版本号
    private var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    // MARK: - Initialization
    
    /// 初始化版本检查器
    /// - Parameter appStoreID: App Store ID（例如: "123456789"）
    init(appStoreID: String) {
        self.appStoreID = appStoreID
    }
    
    // MARK: - Public Methods
    
    /// 获取当前应用版本号
    /// - Returns: 当前版本号字符串
    func getCurrentVersion() -> String {
        return currentVersion
    }
    
    /// 检查 App Store 版本更新
    /// - Parameter completion: 检查完成后的回调，返回 VersionCheckResult
    func checkForUpdates(completion: @escaping (VersionCheckResult) -> Void) {
        // 使用 iTunes Search API 查询 App Store 版本
        let urlString = "https://itunes.apple.com/lookup?id=\(appStoreID)"
        guard let url = URL(string: urlString) else {
            completion(.error(message: "Invalid App Store ID"))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // 处理网络错误
                if let error = error {
                    print("版本检查网络错误: \(error.localizedDescription)")
                    completion(.error(message: error.localizedDescription))
                    return
                }
                
                // 检查数据
                guard let data = data else {
                    completion(.error(message: "No data received"))
                    return
                }
                
                // 解析 JSON 数据
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let results = json["results"] as? [[String: Any]],
                       let firstResult = results.first,
                       let appStoreVersion = firstResult["version"] as? String {
                        
                        // 比较版本号
                        let result = self.compareVersions(
                            currentVersion: self.currentVersion,
                            appStoreVersion: appStoreVersion
                        )
                        completion(result)
                    } else {
                        completion(.error(message: "Failed to parse version info"))
                    }
                } catch {
                    print("解析版本信息错误: \(error.localizedDescription)")
                    completion(.error(message: error.localizedDescription))
                }
            }
        }
        
        task.resume()
    }
    
    /// 打开 App Store 页面
    func openAppStore() {
        let appStoreURL = "https://apps.apple.com/app/id\(appStoreID)"
        if let url = URL(string: appStoreURL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    // MARK: - Private Methods
    
    /// 比较版本号
    /// - Parameters:
    ///   - currentVersion: 当前版本号
    ///   - appStoreVersion: App Store 版本号
    /// - Returns: 版本检查结果
    private func compareVersions(currentVersion: String, appStoreVersion: String) -> VersionCheckResult {
        // 将版本号分割为数字数组
        let currentComponents = currentVersion.components(separatedBy: ".").compactMap { Int($0) }
        let appStoreComponents = appStoreVersion.components(separatedBy: ".").compactMap { Int($0) }
        
        // 补齐版本号长度（例如: 1.0 vs 1.0.1）
        let maxLength = max(currentComponents.count, appStoreComponents.count)
        var current = currentComponents
        var appStore = appStoreComponents
        
        while current.count < maxLength { current.append(0) }
        while appStore.count < maxLength { appStore.append(0) }
        
        // 逐位比较版本号
        for i in 0..<maxLength {
            if appStore[i] > current[i] {
                // App Store 版本更高，需要更新
                return .updateAvailable(currentVersion: currentVersion, appStoreVersion: appStoreVersion)
            } else if appStore[i] < current[i] {
                // 当前版本更高（可能是测试版本）
                break
            }
            // 相等则继续比较下一位
        }
        
        // 版本号相同或当前版本更高
        return .upToDate(currentVersion: currentVersion)
    }
}
