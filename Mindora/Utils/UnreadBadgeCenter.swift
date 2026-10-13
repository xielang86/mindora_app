//
//  UnreadBadgeCenter.swift
//  mindora
//
//  消息「未读」红点的统一状态源。三处入口（Sleep 铃铛 / 洞察铃铛 / 侧边栏消息通知行）
//  都绑定它：有未读 → 都显示红点；用户浏览过消息后 markAllRead → 三处红点一起消失。
//

import Foundation

final class UnreadBadgeCenter {
    static let shared = UnreadBadgeCenter()

    /// 未读状态变化时广播，UI 据此刷新红点。
    static let didChangeNotification = Notification.Name("UnreadBadgeCenter.didChange")

    private let key = "hasUnreadNotifications"
    private init() {}

    /// 是否有未读消息。默认 false——消息改为动态生成后，新装用户收件箱本就是空的，
    /// 不该凭空亮红点；真正有新消息（store.add → markUnread）时才点亮。
    var hasUnread: Bool {
        get {
            return UserDefaults.standard.bool(forKey: key)
        }
        set {
            guard newValue != hasUnread else { return }
            UserDefaults.standard.set(newValue, forKey: key)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    /// 用户浏览过消息后调用：清空未读，三处红点随之消失。
    func markAllRead() { hasUnread = false }

    /// 有新消息到达时调用：置为未读（预留给后续真实推送接入）。
    func markUnread() { hasUnread = true }
}
