//
//  AccountVault.swift
//  mindora
//
//  账号级「清单」存储：一组字符串 ID，按账号（邮箱）隔离。
//
//  === 为什么是 UserDefaults 而不是 Keychain ===
//
//  这几份清单必须活过「登出 → 重新登录」。第一版为此放进了 Keychain，理由是错的：
//  登出清掉什么完全由我们自己的 SessionResetter 决定，换个 UserDefaults key、
//  让登出那条清理路径不碰它，效果一样。
//
//  Keychain 的定位是**存机密**（token / 密码 / 密钥）。popup_id、读没读、答没答问卷
//  都不是机密，泄露也无后果，放进去属于误用，而且要付三笔代价：
//    - 每次读写都是跨进程 IPC 到 securityd，而清单是「读整个数组→改→写回」；
//    - 受 kSecAttrAccessible 约束，锁屏时可能直接读写失败（后台任务常在锁屏时跑）；
//    - 活过 App 卸载 —— 用户删掉重装，期望是干净的，消息却会回来。
//
//  === 生命周期 ===
//
//  按账号邮箱分命名空间，所以换账号天然隔离、切回来仍在，不需要在换账号时做任何清理。
//    - 登出：**不清**（这正是它存在的意义）
//    - 注销删除账号：清
//
//  线上实测过不清的必要性：同一账号 15:42 收到一条调研消息，15:43 登出后重新登录，
//  服务端不会重复下发，本地那条又被清了，消息就此永久消失。
//
//  职责边界（详见 Tools/doc/弹窗与调查问卷接口.md 2.1）：
//    - 服务端只存**消息内容**，提供「按 popup_id 拉」和「拉全量」两种取法；
//    - 客户端存**状态** —— 收到过哪些、读没读、问卷答没答，就是这里这三份清单。
//
//  范围：**只管服务端 query_popups 下发的消息**（参与调研 / 运营活动）。
//  本地引擎按运行状态生成的那些（订阅到期、睡眠评分偏低、佩戴断签、通知权限被关）
//  不在此列 —— 它们没有服务端副本，本地清掉后引擎会重新评估、按需重新生成。
//

import Foundation

final class AccountVault {

    /// 该账号收到过站内消息的全部 popup_id。登录后凭它向服务端要回消息内容。
    static let popupIds = AccountVault(name: "popup_ids")

    /// 该账号已提交过的 survey_id。用于不再重复邀请、消息里按钮置灰为「已完成」。
    static let submittedSurveys = AccountVault(name: "submitted_surveys")

    /// 该账号已读消息的 dedupKey。存 dedupKey 而不是消息 id ——
    /// 消息 id 是每次写入时新生成的 UUID，恢复一次就换一个，对不上；
    /// dedupKey 才是「同一条消息」的稳定标识（如 `survey.sv_sleep_2026q3`）。
    static let readMessages = AccountVault(name: "read_messages")

    /// 三份清单共用的 key 前缀。注销时据此把当前账号的全部清单一次清干净，
    /// 不用在每个调用点逐个点名。
    private static let keyPrefix = "vault."
    private static let versionSuffix = ".v1"

    private let name: String
    private let logTag = "AccountVault"
    private let defaults = UserDefaults.standard

    private init(name: String) {
        self.name = name
    }

    // MARK: - 账号命名空间

    /// 账号就是邮箱 —— 服务端所有接口的 `uid` 字段发的也是它。
    ///
    /// 不用 `AuthStorage.uid`：那是服务端返回的一串哈希，登出时会被
    /// `clearLoginInfoKeepingEmail` 删掉，而邮箱会保留 —— 用 uid 做键的话，
    /// 登出后清单会整个失联。
    ///
    /// 邮箱统一小写去空格，避免同一账号因大小写不同分裂成两份清单。
    private var currentKey: String? {
        guard let email = AuthStorage.shared.email?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !email.isEmpty else { return nil }
        return Self.keyPrefix + name + "." + email + Self.versionSuffix
    }

    // MARK: - 读

    /// 当前账号清单里的全部 ID（无序）。无账号时返回空。
    var all: [String] {
        guard let key = currentKey else { return [] }
        return defaults.stringArray(forKey: key) ?? []
    }

    var isEmpty: Bool { all.isEmpty }

    func contains(_ id: String) -> Bool {
        guard !id.isEmpty else { return false }
        return all.contains(id)
    }

    // MARK: - 写

    /// 加入清单。已存在则不重复写。
    func insert(_ id: String) {
        guard !id.isEmpty, let key = currentKey else { return }
        var ids = defaults.stringArray(forKey: key) ?? []
        guard !ids.contains(id) else { return }
        ids.append(id)
        defaults.set(ids, forKey: key)
        // 有过内容就算建立起来了：即便之后被删空，也不该再走「拉全量」。
        markInitialized()
        Log.info(logTag, "\(name) += \(id)（共 \(ids.count) 条）")
    }

    /// 从清单移除。用户删除站内消息时调用 —— 删除是纯本地行为，不通知服务端，
    /// 下次登录走「按 popup_id 拉」时清单里没有它，自然不会回来。
    func remove(_ id: String) {
        guard !id.isEmpty, let key = currentKey else { return }
        var ids = defaults.stringArray(forKey: key) ?? []
        let before = ids.count
        ids.removeAll { $0 == id }
        guard ids.count != before else { return }
        defaults.set(ids, forKey: key)
        Log.info(logTag, "\(name) -= \(id)（剩 \(ids.count) 条）")
    }

    // MARK: - 初始化标记

    /// 这个账号是否已经建立过本地清单。
    ///
    /// 光看清单空不空是不够的 —— 空有两种截然不同的含义：
    ///   1. **从没收到过**：新设备 / 重装 / 全新账号 → 该向服务端拉全量；
    ///   2. **用户把消息全删了**：清单被一条条摘空 → **绝不能拉全量**，
    ///      否则用户刚删干净的消息下次登录原地复活。
    var isInitialized: Bool {
        guard let key = currentKey else { return false }
        return defaults.bool(forKey: key + ".initialized")
    }

    func markInitialized() {
        guard let key = currentKey, !isInitialized else { return }
        defaults.set(true, forKey: key + ".initialized")
        Log.info(logTag, "\(name) 标记为已初始化")
    }

    // MARK: - 清理

    /// 清空**当前账号的全部清单**（三份一起）。
    /// **只在注销删除账号时调用，登出不要调** —— 登出还清就回到了本文件开头说的那个 bug。
    ///
    /// 做成 static 一次清干净，而不是每份各调一次：漏掉一份不会有任何报错，
    /// 只会在几个月后表现为「注销重注册还能看到上个账号的消息」。
    static func purgeCurrentAccount() {
        guard let email = AuthStorage.shared.email?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !email.isEmpty else { return }
        let defaults = UserDefaults.standard
        let suffix = "." + email + versionSuffix
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix(keyPrefix) && (key.hasSuffix(suffix) || key.hasSuffix(suffix + ".initialized")) {
            defaults.removeObject(forKey: key)
        }
        Log.info("AccountVault", "已清空账号全部清单（注销）")
    }
}
