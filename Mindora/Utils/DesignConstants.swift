//
//  DesignConstants.swift
//  mindora
//
//  Created by gao chao on 2025/10/22.
//
//  设计稿常量定义
//  用于统一管理整个应用中使用的设计稿尺寸常量
//

import UIKit

/// 设计稿常量
struct DesignConstants {
    // MARK: - 设计稿基准尺寸
    /// 设计稿宽度 (iPhone X/XS Max @3x)
    static let designWidth: CGFloat = 1242
    
    /// 设计稿高度 (iPhone X/XS Max @3x)
    static let designHeight: CGFloat = 2688
    
    // MARK: - 字体大小
    /// 标题字体大小 (设计稿中的主标题)
    static let titleFontSize: CGFloat = 81
    
    /// 副标题/按钮文字字体大小
    static let subtitleFontSize: CGFloat = 58
    
    /// 描述文字/正文字体大小
    static let bodyFontSize: CGFloat = 49
    
    // MARK: - 布局间距
    /// 标题距离顶部的距离
    static let titleTopMargin: CGFloat = 366
    
    /// 分割线左右边距 (设计稿中的像素值)
    static let separatorHorizontalMargin: CGFloat = 84
    
    // MARK: - 颜色
    /// 分割线颜色 (白色半透明)
    static let separatorColor: UIColor = UIColor(white: 1.0, alpha: 0.2)
    
    /// 折线图颜色 - 心率 (浅绿色)
    static let chartColorHeartRate: UIColor = UIColor(red: 86/255.0, green: 239/255.0, blue: 65/255.0, alpha: 1.0)
    
    /// 折线图颜色 - 心率变异性 (中绿色)
    static let chartColorHRV: UIColor = UIColor(red: 21/255.0, green: 178/255.0, blue: 4/255.0, alpha: 1.0)
    
    /// 折线图颜色 - 睡眠 (深绿色)
    static let chartColorSleep: UIColor = UIColor(red: 10/255.0, green: 137/255.0, blue: 0/255.0, alpha: 1.0)
    
    // MARK: - 图表样式
    /// 月度柱体宽度
    static let monthlyBarWidth: CGFloat = 17
    
    /// 月度柱体圆角
    static let monthlyBarCornerRadius: CGFloat = 5
    
    /// 年度柱体宽度
    static let yearlyBarWidth: CGFloat = 57
    
    /// 年度柱体圆角
    static let yearlyBarCornerRadius: CGFloat = 15
    
    // MARK: - 权限提醒
    /// 健康权限提醒最大次数
    static let maxHealthPermissionReminderCount: Int = 6
    
    /// 蓝牙权限提醒最大次数
    static let maxBluetoothPermissionReminderCount: Int = 6
    
    /// 权限提醒最小间隔时间（小时）
    /// 注意：实际间隔逻辑在 PermissionManager 中实现，固定为24小时
    static let permissionReminderIntervalHours: Double = 24
    
    // MARK: - Debug 模式
    /// Debug 模式开关 (用于返回虚假健康数据以便测试)
    static let isDebugMode: Bool = true
    
    /// Debug 模式下的虚假健康数据
    struct DebugHealthData {
        /// 心率 (次/分)
        static let heartRate: Double = 76
        
        /// 心率变异性 (毫秒)
        static let heartRateVariability: Double = 26
        
        /// 睡眠时间 (小时)
        static let sleepHours: Double = 7
        
        /// 睡眠分钟数
        static let sleepMinutes: Double = 57
        
        /// 总睡眠时间 (小时，包含分钟的小数部分) - 实际睡着的时间
        static let totalSleepHours: Double = sleepHours + sleepMinutes / 60.0

        /// 在床上的总时间 (小时) - 包括睡眠和清醒时间，设置为8小时30分钟
        static let timeInBed: Double = 8 + 30.0 / 60.0
        
        // MARK: - 月度数据 (最近30天)
        /// 月度心率数据 (bpm) - 30个数据点,模拟正常人的日常波动(60-85范围)
        static let monthlyHeartRate: [Double] = [
            68, 79, 71, 84, 65, 76, 82, 70, 81, 67,
            85, 63, 74, 78, 61, 77, 83, 69, 80, 73,
            66, 82, 72, 84, 68, 75, 62, 79, 71, 83
        ]
        
        /// 月度心率变异性数据 (ms) - 30个数据点,模拟正常人的波动(15-40范围)
        static let monthlyHRV: [Double] = [
            22, 35, 26, 38, 20, 31, 29, 18, 36, 24,
            40, 19, 30, 34, 17, 28, 37, 23, 39, 27,
            21, 33, 25, 38, 22, 32, 16, 35, 26, 37
        ]
        
        /// 月度睡眠时间数据 (小时) - 30个数据点,模拟正常人的波动(5.5-9.5范围)
        static let monthlySleep: [Double] = [
            6.5, 8.8, 7.2, 9.2, 6.1, 8.3, 7.8, 6.3, 9.0, 7.1,
            9.4, 5.8, 7.9, 8.6, 5.6, 8.1, 9.1, 6.7, 8.9, 7.5,
            6.2, 8.5, 7.3, 9.3, 6.9, 8.2, 5.9, 8.7, 7.4, 9.0
        ]
        
        // MARK: - 年度数据 (最近12个月)
        /// 年度心率数据 (bpm) - 12个数据点,模拟正常人的季节性变化(65-82范围)
        static let yearlyHeartRate: [Double] = [
            74, 79, 68, 82, 71, 80, 75, 66, 77, 81, 70, 76
        ]
        
        /// 年度心率变异性数据 (ms) - 12个数据点,模拟正常人的季节性变化(18-38范围)
        static let yearlyHRV: [Double] = [
            28, 35, 22, 38, 25, 36, 30, 19, 32, 37, 24, 26
        ]
        
        /// 年度睡眠时间数据 (小时) - 12个数据点,模拟正常人的季节性变化(6-9范围)
        static let yearlySleep: [Double] = [
            7.6, 8.8, 6.5, 9.0, 7.1, 8.6, 7.9, 6.2, 8.2, 8.9, 6.8, 7.95
        ]
    }
}
