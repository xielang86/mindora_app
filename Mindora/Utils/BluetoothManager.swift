//
//  BluetoothManager.swift
//  mindora
//
//  Created by gao chao on 2025/10/20.
//

import Foundation
import CoreBluetooth

final class BluetoothManager: NSObject {
    static let shared = BluetoothManager()
    
    private var centralManager: CBCentralManager?
    private var authorizationCallback: ((CBManagerAuthorization) -> Void)?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 检查蓝牙权限状态
    func checkBluetoothAuthorization() -> CBManagerAuthorization {
        return CBCentralManager.authorization
    }
    
    /// 请求蓝牙权限（通过初始化 CBCentralManager 来触发系统权限弹窗）
    func requestBluetoothAuthorization(completion: @escaping (CBManagerAuthorization) -> Void) {
        authorizationCallback = completion
        
        // 创建 CBCentralManager 会触发蓝牙权限请求
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        } else {
            // 如果已经存在，直接返回当前状态
            let status = checkBluetoothAuthorization()
            DispatchQueue.main.async {
                completion(status)
            }
        }
    }
    
    /// 获取蓝牙权限状态的可读描述
    func getBluetoothStatusDescription() -> String {
        let authorization = checkBluetoothAuthorization()
        switch authorization {
        case .allowedAlways:
            return L("permission.status.authorized")
        case .denied:
            return L("permission.status.not_determined")
        case .restricted:
            return L("permission.status.unavailable")
        case .notDetermined:
            return L("permission.status.not_determined")
        @unknown default:
            return L("permission.status.unavailable")
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let authorization = checkBluetoothAuthorization()
        
        // 调用回调
        if let callback = authorizationCallback {
            DispatchQueue.main.async {
                callback(authorization)
            }
            authorizationCallback = nil
        }
        
        // 打印状态日志
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on and ready")
        case .poweredOff:
            print("Bluetooth is powered off")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is not supported on this device")
        case .resetting:
            print("Bluetooth is resetting")
        case .unknown:
            print("Bluetooth state is unknown")
        @unknown default:
            print("Unknown bluetooth state")
        }
    }
}
