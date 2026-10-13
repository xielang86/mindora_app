//
//  DebugNotificationSimulator.swift
//  mindora
//
//  仅 DEBUG：一键模拟各类站内消息 / 首页弹窗，方便测试 UI。
//  入口：首页 Logo 长按 → 选择要模拟的类型（见 HomeViewController.presentDebugSimulator）。
//
//  说明：模拟出的站内消息 dedupKey 均以 "debug." 开头，AppNotificationStore 在下次启动
//  load() 时会自动清掉这些样例，不会污染真实数据。
//

#if DEBUG
import Foundation

enum DebugNotificationSimulator {

    /// 可模拟的站内消息条目（含展示名）。
    static let messageItems: [(name: String, seed: () -> Void)] = [
        ("站内消息 · 即将到期", { seed(.subscriptionExpiring, params: ["days": "5", "expiryEpoch": future(7)]) }),
        ("站内消息 · 已到期", { seed(.subscriptionExpired) }),
        ("站内消息 · 开通成功", { seed(.subscriptionActivated, params: ["expiryEpoch": future(30)]) }),
        ("站内消息 · 续订成功", { seed(.subscriptionActivated, params: ["expiryEpoch": future(60), "renewed": "1"]) }),
        ("站内消息 · 兑换成功", { seed(.redeemSuccess, params: ["days": "30", "expiryEpoch": future(30)]) }),
        ("站内消息 · 权限关闭", { seed(.permissionDisabled) }),
        ("站内消息 · 睡眠评分偏低", { seed(.sleepScoreLow, params: ["score": "52"]) }),
        ("站内消息 · 佩戴断签", { seed(.wearGap, params: ["days": "4"]) }),
        ("站内消息 · 参与调研", {
            seed(.survey, params: ["surveyId": "debug_survey",
                                   "title": L("popup.mock.survey.title"),
                                   "subtitle": L("popup.mock.survey.subtitle"),
                                   "expiryEpoch": future(7)])
        }),
        ("站内消息 · 商城活动", {
            seed(.promo, params: ["title": "夏夜安睡礼遇",
                                  "subtitle": "精选助眠好物限时优惠，前往商城查看。",
                                  "actionText": "前往商城",
                                  "actionType": "route",
                                  "route": "store"])
        })
    ]

    private static func seed(_ category: AppNotificationCategory, params: [String: String] = [:]) {
        // 唯一 dedupKey → 重复点击可持续新增；以 "debug." 前缀让下次启动自动清理。
        let tag = String(Int(Date().timeIntervalSince1970 * 1000))
        AppNotificationStore.shared.add(category, dedupKey: "debug.\(category.rawValue).\(tag)", params: params)
    }

    private static func future(_ days: Int) -> String {
        String(Int(Date().addingTimeInterval(Double(days) * 86400).timeIntervalSince1970))
    }

    // MARK: 示例弹窗

    static func samplePopup(_ type: HomePopup.PopupType) -> HomePopup {
        switch type {
        case .survey:
            return HomePopup(popupId: "debug_survey_popup", type: .survey,
                             badge: L("popup.badge.survey"), badgeStyle: "purple",
                             title: L("popup.mock.survey.title"), subtitle: L("popup.mock.survey.subtitle"),
                             imageURL: nil, actionText: L("popup.action.detail"), actionType: .survey,
                             surveyId: "debug_survey", linkURL: nil, route: nil,
                             startAt: nil, endAt: Date().addingTimeInterval(7 * 86400),
                             deliveredAt: nil, priority: 100, maxShowCount: nil, cooldownSeconds: nil, dismissStops: false,
                             localImageName: "popup_survey")
        case .mall:
            return HomePopup(popupId: "debug_mall_popup", type: .mall,
                             badge: "限时活动", badgeStyle: "orange",
                             title: "夏夜安睡礼遇", subtitle: "精选助眠好物限时优惠，前往商城查看。",
                             imageURL: nil, actionText: "前往商城", actionType: .route,
                             surveyId: nil, linkURL: nil, route: "store",
                             startAt: nil, endAt: nil,
                             deliveredAt: nil, priority: 90, maxShowCount: nil, cooldownSeconds: nil, dismissStops: false,
                             pushMessage: true)   // 商城活动默认落站内消息
        default: // .ad / .unknown
            return HomePopup(popupId: "debug_ad_popup", type: .ad,
                             badge: "品牌推荐", badgeStyle: "blue",
                             title: "今晚，给自己一点安静", subtitle: "聆听一段舒缓声音，慢慢放下今天。",
                             imageURL: nil, actionText: "了解更多", actionType: .dismiss,
                             surveyId: nil, linkURL: nil, route: nil,
                             startAt: nil, endAt: nil,
                             deliveredAt: nil, priority: 80, maxShowCount: nil, cooldownSeconds: nil, dismissStops: false,
                             pushMessage: true)   // 演示用：广告也落一条以便预览（正式由服务端控制，默认不落）
        }
    }
}
#endif
