//
//  HelpManualPageData.swift
//  mindora
//
//  Created by gao chao on 2025/10/23.
//
//  用户手册页面数据模型
//

import UIKit

struct HelpManualPageData {
    let title: String
    let description: String
    let hasBackgroundImage: Bool  // 是否有背景图
    let hasQRCode: Bool           // 是否显示二维码
    let icons: [IconData]         // 图标数据
    
    struct IconData {
        let imageName: String
        let width: CGFloat
        let height: CGFloat
        let type: IconType
        
        enum IconType {
            case left      // 左侧图标
            case middle    // 中间虚线
            case right     // 右侧图标
        }
    }
    
    // 创建5页手册数据
    static func createAllPages() -> [HelpManualPageData] {
        return [
            // 第1页
            HelpManualPageData(
                title: L("help_manual.page1.title"),
                description: L("help_manual.page1.description"),
                hasBackgroundImage: true,
                hasQRCode: false,
                icons: [
                    IconData(imageName: "bluetooth_icon", width: 113.47, height: 105, type: .left),
                    IconData(imageName: "dashed_line", width: 636, height: 1, type: .middle),
                    IconData(imageName: "phone_icon", width: 70, height: 105, type: .right)
                ]
            ),
            // 第2页
            HelpManualPageData(
                title: L("help_manual.page2.title"),
                description: L("help_manual.page2.description"),
                hasBackgroundImage: true,
                hasQRCode: false,
                icons: [
                    IconData(imageName: "tap_icon", width: 113.47, height: 105, type: .left),
                    IconData(imageName: "dashed_line", width: 636, height: 1, type: .middle),
                    IconData(imageName: "bluetooth_icon", width: 113.47, height: 105, type: .right)
                ]
            ),
            // 第3页
            HelpManualPageData(
                title: L("help_manual.page3.title"),
                description: L("help_manual.page3.description"),
                hasBackgroundImage: true,
                hasQRCode: false,
                icons: [
                    IconData(imageName: "device_icon", width: 113.47, height: 105, type: .left),
                    IconData(imageName: "dashed_line", width: 636, height: 1, type: .middle),
                    IconData(imageName: "phone_icon", width: 70, height: 105, type: .right)
                ]
            ),
            // 第4页
            HelpManualPageData(
                title: L("help_manual.page4.title"),
                description: L("help_manual.page4.description"),
                hasBackgroundImage: true,
                hasQRCode: false,
                icons: [
                    IconData(imageName: "bluetooth_disconnect_icon", width: 113.47, height: 105, type: .left),
                    IconData(imageName: "dashed_line", width: 636, height: 1, type: .middle),
                    IconData(imageName: "device_icon", width: 113.47, height: 105, type: .right)
                ]
            ),
            // 第5页
            HelpManualPageData(
                title: L("help_manual.page5.title"),
                description: L("help_manual.page5.description"),
                hasBackgroundImage: false,  // 纯黑背景
                hasQRCode: true,             // 显示二维码
                icons: []                    // 无图标
            )
        ]
    }
}
