//
//  PermissionManager.swift
//  mindora
//
//  Created by GitHub Copilot on 2025/10/14.
//

import Foundation
import HealthKit
import UIKit
import CoreTelephony
import Network
import CoreBluetooth

final class PermissionManager {
    static let shared = PermissionManager()
    
    private let healthStore = HKHealthStore()
    private let userDefaults = UserDefaults.standard
    private let cellularData = CTCellularData()
    private var cachedCellularStatus: PermissionStatus?
    private var cellularCallbacks: [((PermissionStatus) -> Void)] = []
    private var cachedLocalNetworkStatus: PermissionStatus?
    private var localNetworkCallbacks: [((PermissionStatus) -> Void)] = []
    private var localNetworkProbe: LocalNetworkAuthorizationProbe?
    
    // UserDefaults keys
    private let healthPermissionReminderCountKey = "health_permission_reminder_count"
    private let healthPermissionLastCheckKey = "health_permission_last_check_date"
    private let bluetoothPermissionReminderCountKey = "bluetooth_permission_reminder_count"
    private let bluetoothPermissionLastCheckKey = "bluetooth_permission_last_check_date"
    
    private init() {
        cellularData.cellularDataRestrictionDidUpdateNotifier = { [weak self] state in
            guard let self else { return }
            let status = self.mapCellularStatus(state)
            self.cachedCellularStatus = status
            let callbacks = self.cellularCallbacks
            self.cellularCallbacks.removeAll()
            DispatchQueue.main.async {
                callbacks.forEach { $0(status) }
            }
        }
    }
    
    // MARK: - Permission Status
    
    /// 检查 HealthKit 权限状态
    /// 
    /// ⚠️ HealthKit 权限检查的真相（经过充分测试）：
    /// 
    /// Apple 的隐私保护机制导致无法准确获取读取权限状态：
    /// 
    /// 1. authorizationStatus(for:) - 完全不可用
    ///    - 无论是否授权，都返回 sharingDenied
    /// 
    /// 2. getRequestStatusForAuthorization - 部分可用
    ///    - .shouldRequest = 从未请求过权限 ✅ 可信
    ///    - .unnecessary = 已经请求过权限（但不知道用户选择了什么）❌ 不可信
    /// 
    /// 3. 实际查询数据 - 看起来可行，但也有问题
    ///    - 即使没有权限，查询也可能成功（返回空数据）
    ///    - 无法区分"有权限但无数据"和"无权限所以无数据"
    /// 
    /// 最终策略（务实的做法）：
    /// 
    /// - 如果 shouldRequest = true → 显示"未授权"，引导用户授权
    /// - 如果 unnecessary = true → 显示"已配置"，但提醒用户检查设置
    /// 
    /// 因为 Apple 故意隐藏了读取权限的真实状态，我们只能：
    /// 1. 首次安装时引导授权
    /// 2. 之后假设用户已授权，如果数据同步有问题再提示检查权限
    /// 
    /// 这是目前业界的通用做法，也是 Apple 推荐的方式
    func checkHealthPermissionStatus() -> PermissionStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[PermissionManager] HealthKit 不可用")
            return .unavailable
        }
        
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        print("[PermissionManager] ======== 开始检查健康权限 ========")
        
        // 检查 getRequestStatusForAuthorization（这是唯一有用的 API）
        let semaphore = DispatchSemaphore(value: 0)
        var requestStatus: HKAuthorizationRequestStatus?
        var requestError: Error?

        healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, error in
            requestStatus = status
            requestError = error
            semaphore.signal()
        }

        // 最多等待 2 秒钟
        let waitResult = semaphore.wait(timeout: .now() + 2.0)
        
        // 处理超时情况
        guard waitResult == .success else {
            print("[PermissionManager] ⚠️ getRequestStatusForAuthorization 超时")
            print("[PermissionManager] 默认显示为未授权，引导用户设置")
            print("[PermissionManager] ========================================")
            return .notDetermined
        }
        
        // 处理错误情况
        if let error = requestError {
            print("[PermissionManager] ❌ getRequestStatusForAuthorization 错误: \(error.localizedDescription)")
            print("[PermissionManager] 默认显示为未授权，引导用户设置")
            print("[PermissionManager] ========================================")
            return .notDetermined
        }
        
        guard let status = requestStatus else {
            print("[PermissionManager] ⚠️ requestStatus 为 nil")
            print("[PermissionManager] 默认显示为未授权，引导用户设置")
            print("[PermissionManager] ========================================")
            return .notDetermined
        }
        
        let result: PermissionStatus
        
        switch status {
        case .shouldRequest:
            // 从未请求过权限 = 未授权
            result = .notDetermined
            print("[PermissionManager] ❌ getRequestStatus = shouldRequest")
            print("[PermissionManager] 说明：从未请求过健康数据权限")
            print("[PermissionManager] 结论：未授权")

        case .unnecessary:
            // 已经请求过权限了
            // 注意：这并不等于“已授权”，只是代表“用户已经做过选择（可能允许，也可能拒绝）”。
            // 由于 HealthKit 不提供读取权限的精确状态，这里返回“部分授权”，
            // 用于驱动 UI 提醒用户去健康 App 核对设置，避免误判为“已完全授权”。
            result = .partiallyAuthorized
            print("[PermissionManager] getRequestStatus = unnecessary")
            print("[PermissionManager] 说明：已经请求过权限（用户已做出选择，可能允许也可能拒绝）")
            print("[PermissionManager] 结论：标记为部分授权（需要用户核对设置）")

        case .unknown:
            // 状态未知，保守地标记为未授权
            result = .notDetermined
            print("[PermissionManager] ⚪️ getRequestStatus = unknown")
            print("[PermissionManager] 结论：状态未知，标记为未授权")
            
        @unknown default:
            result = .notDetermined
            print("[PermissionManager] ⚠️ getRequestStatus = @unknown")
            print("[PermissionManager] 结论：未知状态，标记为未授权")
        }
        
        print("[PermissionManager] ========================================")
        print("[PermissionManager] 最终结果: \(result == .authorized ? "✅ 已授权" : "❌ 未授权")")
        print("[PermissionManager] ========================================")
        
        return result
    }

    /// 异步获取 HealthKit 权限状态（不阻塞主线程）
    /// - Note: 读取权限无法被系统精确披露，因此返回值语义与同步方法相同：
    ///   - .notDetermined: 从未请求过（应发起首次授权请求）
    ///   - .partiallyAuthorized: 用户已做过选择（可能允许也可能拒绝）
    ///   - .unavailable: 设备不支持 HealthKit
    ///   - .authorized: 仅当我们未来引入可验证的写入权限时才返回；当前仅读取场景不会返回该值
    @MainActor
    func getHealthPermissionStatus() async -> PermissionStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        return await withCheckedContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, error in
                if let error = error {
                    print("[PermissionManager] getHealthPermissionStatus error: \(error.localizedDescription)")
                    continuation.resume(returning: .notDetermined)
                    return
                }

                switch status {
                case .shouldRequest:
                    continuation.resume(returning: .notDetermined)
                case .unnecessary:
                    continuation.resume(returning: .partiallyAuthorized)
                case .unknown:
                    continuation.resume(returning: .notDetermined)
                @unknown default:
                    continuation.resume(returning: .notDetermined)
                }
            }
        }
    }

    /// 获取本地网络权限状态
    func getLocalNetworkStatus(forceRefresh: Bool = false, completion: @escaping (PermissionStatus) -> Void) {
        if !forceRefresh, let cached = cachedLocalNetworkStatus {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        if #available(iOS 14.0, *) {
            localNetworkCallbacks.append(completion)
            guard localNetworkProbe == nil else { return }
            let probe = LocalNetworkAuthorizationProbe()
            localNetworkProbe = probe
            probe.start { [weak self] status in
                guard let self else { return }
                self.cachedLocalNetworkStatus = status
                let callbacks = self.localNetworkCallbacks
                self.localNetworkCallbacks.removeAll()
                self.localNetworkProbe = nil
                DispatchQueue.main.async {
                    callbacks.forEach { $0(status) }
                }
            }
        } else {
            DispatchQueue.main.async { completion(.unavailable) }
        }
    }

    /// 获取蜂窝数据权限状态
    func getCellularDataStatus(forceRefresh: Bool = false, completion: @escaping (PermissionStatus) -> Void) {
        if !forceRefresh, let cached = cachedCellularStatus {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        let state = cellularData.restrictedState
        let status = mapCellularStatus(state)
        cachedCellularStatus = status

        if state == .restrictedStateUnknown {
            cellularCallbacks.append(completion)
            DispatchQueue.main.async { completion(status) }
        } else {
            DispatchQueue.main.async { completion(status) }
        }
    }
    
    /// 检查蓝牙权限状态
    func checkBluetoothPermissionStatus() -> PermissionStatus {
        let authorization = BluetoothManager.shared.checkBluetoothAuthorization()
        let statusDescription: String
        let result: PermissionStatus
        
        switch authorization {
        case .allowedAlways:
            statusDescription = "已授权"
            result = .authorized
        case .denied:
            statusDescription = "已拒绝"
            result = .notDetermined
        case .restricted:
            statusDescription = "受限制"
            result = .unavailable
        case .notDetermined:
            statusDescription = "未确定"
            result = .notDetermined
        @unknown default:
            statusDescription = "未知"
            result = .unavailable
        }
        
        print("[PermissionManager] 蓝牙授权状态: rawValue=\(authorization.rawValue), status=\(statusDescription)")
        return result
    }
    
    // MARK: - Reminder Logic
    
    /// 获取健康权限提醒次数
    func getHealthReminderCount() -> Int {
        return userDefaults.integer(forKey: healthPermissionReminderCountKey)
    }
    
    /// 增加健康权限提醒次数
    func incrementHealthReminderCount() {
        let current = getHealthReminderCount()
        userDefaults.set(current + 1, forKey: healthPermissionReminderCountKey)
        userDefaults.set(Date(), forKey: healthPermissionLastCheckKey)
    }
    
    /// 重置健康权限提醒次数
    func resetHealthReminderCount() {
        userDefaults.set(0, forKey: healthPermissionReminderCountKey)
        userDefaults.removeObject(forKey: healthPermissionLastCheckKey)
    }
    
    /// 判断是否应该显示健康权限提醒
    func shouldShowHealthReminder() -> Bool {
        // 暂时禁用健康权限提醒，因为 HealthKit 权限状态无法准确获取
        // 避免误导用户或造成困扰
        return false
        
        /* 原有逻辑保留，需要时可以重新启用
        let status = checkHealthPermissionStatus()
        
        // 如果已授权或不可用，不显示提醒
        guard status == .notDetermined || status == .partiallyAuthorized else {
            return false
        }
        
        let reminderCount = getHealthReminderCount()
        
        // 使用 DesignConstants 中的最大提醒次数
        guard reminderCount < DesignConstants.maxHealthPermissionReminderCount else {
            return false
        }
        
        // 检查距离上次提醒是否超过24小时
        if let lastCheckDate = userDefaults.object(forKey: healthPermissionLastCheckKey) as? Date {
            let hoursSinceLastCheck = Date().timeIntervalSince(lastCheckDate) / 3600
            if hoursSinceLastCheck < DesignConstants.permissionReminderIntervalHours {
                return false
            }
        }
        
        return true
        */
    }

    /// 异步版本：判断是否应该显示健康权限提醒（不阻塞主线程）
    @MainActor
    func shouldShowHealthReminder() async -> Bool {
        // 暂时禁用健康权限提醒，因为 HealthKit 权限状态无法准确获取
        // 避免误导用户或造成困扰
        return false
        
        /* 原有逻辑保留，需要时可以重新启用
        let status = await getHealthPermissionStatus()

        // 如果已授权或不可用，不显示提醒
        guard status == .notDetermined || status == .partiallyAuthorized else {
            return false
        }

        let reminderCount = getHealthReminderCount()

        // 使用 DesignConstants 中的最大提醒次数
        guard reminderCount < DesignConstants.maxHealthPermissionReminderCount else {
            return false
        }

        // 检查距离上次提醒是否超过24小时
        if let lastCheckDate = userDefaults.object(forKey: healthPermissionLastCheckKey) as? Date {
            let hoursSinceLastCheck = Date().timeIntervalSince(lastCheckDate) / 3600
            if hoursSinceLastCheck < DesignConstants.permissionReminderIntervalHours {
                return false
            }
        }

        return true
        */
    }
    
    /// 获取蓝牙权限提醒次数
    func getBluetoothReminderCount() -> Int {
        return userDefaults.integer(forKey: bluetoothPermissionReminderCountKey)
    }
    
    /// 增加蓝牙权限提醒次数
    func incrementBluetoothReminderCount() {
        let current = getBluetoothReminderCount()
        userDefaults.set(current + 1, forKey: bluetoothPermissionReminderCountKey)
        userDefaults.set(Date(), forKey: bluetoothPermissionLastCheckKey)
    }
    
    /// 重置蓝牙权限提醒次数
    func resetBluetoothReminderCount() {
        userDefaults.set(0, forKey: bluetoothPermissionReminderCountKey)
        userDefaults.removeObject(forKey: bluetoothPermissionLastCheckKey)
    }
    
    /// 判断是否应该显示蓝牙权限提醒
    func shouldShowBluetoothReminder() -> Bool {
        let status = checkBluetoothPermissionStatus()
        
        // 如果已授权或不可用，不显示提醒
        guard status == .notDetermined else {
            return false
        }
        
        let reminderCount = getBluetoothReminderCount()
        
        // 使用 DesignConstants 中的最大提醒次数
        guard reminderCount < DesignConstants.maxBluetoothPermissionReminderCount else {
            return false
        }
        
        // 检查距离上次提醒是否超过24小时
        if let lastCheckDate = userDefaults.object(forKey: bluetoothPermissionLastCheckKey) as? Date {
            let hoursSinceLastCheck = Date().timeIntervalSince(lastCheckDate) / 3600
            if hoursSinceLastCheck < DesignConstants.permissionReminderIntervalHours {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Show Permission Alert
    
    /// 显示健康权限提醒弹窗（使用 CustomAlertViewController）
    func showHealthPermissionReminder(from viewController: UIViewController, completion: (() -> Void)? = nil) {
        let customAlert = CustomAlertViewController(
            title: L("permission.health.reminder_title"),
            description: L("permission.health.reminder_message"),
            confirmButtonTitle: L("permission.open_health_app"),
            cancelButtonTitle: L("permission.later"),
            onConfirm: { [weak self] in
                guard let self = self else { return }
                self.incrementHealthReminderCount()
                // 先请求健康数据授权，这样才能在健康 App 中看到 Mindora 配置
                Task {
                    do {
                        try await HealthDataManager.shared.requestAuthorization()
                        // 授权请求完成后，引导用户到健康 App 查看和调整权限
                        await MainActor.run {
                            // 尝试打开健康 App
                            self.openHealthApp { success in
                                if !success {
                                    // 如果打开失败，显示设置指引
                                    self.showHealthAppGuide(from: viewController)
                                }
                            }
                            completion?()
                        }
                    } catch {
                        // 授权失败，显示指引
                        await MainActor.run {
                            self.showHealthAppGuide(from: viewController)
                            completion?()
                        }
                    }
                }
            },
            onCancel: { [weak self] in
                self?.incrementHealthReminderCount()
                completion?()
            }
        )
        
        viewController.present(customAlert, animated: true)
    }
    
    /// 显示蓝牙权限提醒弹窗（使用 CustomAlertViewController）
    func showBluetoothPermissionReminder(from viewController: UIViewController, completion: (() -> Void)? = nil) {
        let customAlert = CustomAlertViewController(
            title: L("permission.bluetooth.reminder_title"),
            description: L("permission.bluetooth.reminder_message"),
            confirmButtonTitle: L("permission.open_settings"),
            cancelButtonTitle: L("permission.later"),
            onConfirm: { [weak self] in
                guard let self = self else { return }
                self.incrementBluetoothReminderCount()
                
                // 检查当前蓝牙权限状态
                let authorization = BluetoothManager.shared.checkBluetoothAuthorization()
                
                switch authorization {
                case .notDetermined:
                    // 未确定：首次请求，触发系统授权弹窗
                    BluetoothManager.shared.requestBluetoothAuthorization { result in
                        DispatchQueue.main.async {
                            // 如果用户拒绝或授权后需要进一步设置，引导到设置页面
                            if result == .denied {
                                self.openAppSettings()
                            }
                            completion?()
                        }
                    }
                case .denied, .allowedAlways, .restricted:
                    // 已拒绝、已授权或受限制：直接打开系统设置
                    self.openAppSettings()
                    completion?()
                @unknown default:
                    // 未知状态：打开系统设置
                    self.openAppSettings()
                    completion?()
                }
            },
            onCancel: { [weak self] in
                self?.incrementBluetoothReminderCount()
                completion?()
            }
        )
        
        viewController.present(customAlert, animated: true)
    }
    
    // MARK: - Deprecated (保留向后兼容)
    
    /// 获取权限提醒次数（已废弃，使用 getHealthReminderCount）
    @available(*, deprecated, renamed: "getHealthReminderCount")
    func getReminderCount() -> Int {
        return getHealthReminderCount()
    }
    
    /// 增加提醒次数（已废弃，使用 incrementHealthReminderCount）
    @available(*, deprecated, renamed: "incrementHealthReminderCount")
    func incrementReminderCount() {
        incrementHealthReminderCount()
    }
    
    /// 重置提醒次数（已废弃，使用 resetHealthReminderCount）
    @available(*, deprecated, renamed: "resetHealthReminderCount")
    func resetReminderCount() {
        resetHealthReminderCount()
    }
    
    /// 判断是否应该显示权限提醒（已废弃，使用 shouldShowHealthReminder）
    @available(*, deprecated, renamed: "shouldShowHealthReminder")
    func shouldShowReminder() -> Bool {
        return shouldShowHealthReminder()
    }
    
    /// 显示权限提醒弹窗（已废弃，使用 showHealthPermissionReminder）
    @available(*, deprecated, renamed: "showHealthPermissionReminder")
    func showPermissionReminder(from viewController: UIViewController, completion: (() -> Void)? = nil) {
        showHealthPermissionReminder(from: viewController, completion: completion)
    }
    
    // MARK: - Private Helpers
    
    /// 显示如何在健康 App 中设置权限的指引
    private func showHealthAppGuide(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: L("permission.health.guide_title"),
            message: L("permission.health.guide_message"),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: L("permission.open_health_app"), style: .default) { _ in
            self.openHealthApp()
        })
        
        alert.addAction(UIAlertAction(title: L("common.ok"), style: .cancel))
        
        viewController.present(alert, animated: true)
    }
    
    /// 打开健康 App
    func openHealthApp(completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: "x-apple-health://") else {
            completion?(false)
            openAppSettings()
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { success in
                if !success {
                    self.openAppSettings()
                }
                completion?(success)
            }
        } else {
            openAppSettings()
            completion?(false)
        }
    }
    
    /// 打开应用设置页面
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - Permission Status Enum

enum PermissionStatus {
    case authorized      // 已授权
    case partiallyAuthorized // 部分授权
    case notDetermined   // 未授权
    case unavailable     // 不可用
    
    var localizedDescription: String {
        switch self {
        case .authorized:
            return L("permission.status.authorized")
        case .partiallyAuthorized:
            return L("permission.status.partial")
        case .notDetermined:
            return L("permission.status.not_determined")
        case .unavailable:
            return L("permission.status.unavailable")
        }
    }
}

// MARK: - Private Helpers

private extension PermissionManager {
    func mapCellularStatus(_ state: CTCellularDataRestrictedState) -> PermissionStatus {
        switch state {
        case .restrictedStateUnknown:
            return .notDetermined
        case .restricted:
            return .notDetermined
        case .notRestricted:
            return .authorized
        @unknown default:
            return .unavailable
        }
    }

    func unauthorizedAll(authorized: Int, denied: Int, pending: Int) -> Bool {
        return authorized == 0 && denied > 0 && pending == 0
    }
}

// MARK: - Local Network Probe

@available(iOS 14.0, *)
private final class LocalNetworkAuthorizationProbe {
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.mindora.permission.localnetwork.probe")
    private var completion: ((PermissionStatus) -> Void)?

    func start(completion: @escaping (PermissionStatus) -> Void) {
        self.completion = completion

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: "_mindora._tcp", domain: nil), using: parameters)
        browser?.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.finish(with: .authorized)
            case .failed(let error):
                if case .posix = error {
                    self.finish(with: .notDetermined)
                } else {
                    self.finish(with: .unavailable)
                }
            default:
                break
            }
        }

        browser?.start(queue: queue)

        queue.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self, self.browser != nil else { return }
            self.finish(with: .notDetermined)
        }
    }

    private func finish(with status: PermissionStatus) {
        browser?.cancel()
        browser = nil
        let completion = self.completion
        self.completion = nil
        completion?(status)
    }
}
