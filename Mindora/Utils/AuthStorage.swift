//
//  AuthStorage.swift
//  mindora
//
//  Created by GitHub Copilot.
//

import Foundation
import Security

final class AuthStorage {
    static let shared = AuthStorage()

    /// JWT 发生变化（登录 / 重新登录 / 换账号）时发出。DeviceLoginPusher 监听它统一触发
    /// 把新 token 同步给已绑定设备——这样任何写 token 的代码路径都不会漏推。
    static let tokenDidChangeNotification = Notification.Name("AuthStorage.tokenDidChange")

    private let tokenKey = Constants.Storage.Keychain.authToken
    private let expirationDateKey = Constants.Storage.Keychain.authExpirationDate
    private let uidKey = Constants.Storage.Keychain.authUID
    private let emailKey = Constants.Storage.Keychain.authEmail
    
    private init() {}

    // MARK: - 可访问性迁移

    private static let accessibilityMigratedKey = "keychain.accessibility_migrated_v1"

    /// 把老版本写入的鉴权条目升级为「首次解锁后可访问」。启动时调一次。
    ///
    /// 老条目带的是系统默认的 `WhenUnlocked`，锁屏时读不到 —— 后台健康同步在锁屏时
    /// 被唤醒就拿不到 token，静默跳过。改常量只影响**新写入**的条目，存量必须显式迁移。
    func migrateAccessibilityIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.accessibilityMigratedKey) else { return }
        let keys = [tokenKey, expirationDateKey, uidKey, emailKey]
        let allOK = keys.allSatisfy { KeychainHelper.standard.upgradeAccessibility(forKey: $0) }
        // 只有全部成功才打标记。设备恰好锁屏时启动（如后台唤醒）会失败，
        // 那就留到下次前台启动再试，不要把没迁成的当成迁完了。
        if allOK {
            defaults.set(true, forKey: Self.accessibilityMigratedKey)
            Log.info("AuthStorage", "Keychain 可访问性已迁移为 AfterFirstUnlock")
        }
    }

    // MARK: - Save
    
    func saveLoginInfo(email: String, uid: String, token: String, expireDays: Int) {
        // 换账号检测必须在覆盖 **之前**取旧值。
        // 这里是所有登录路径的唯一收口（AuthService 与 RegisterP2Controller 都走它），
        // 放在这里才不会漏。
        //
        // 判据是**邮箱**而不是服务端返回的 uid：账号本身就是邮箱（所有接口的 uid 字段发的
        // 也是它），uid 只是个附带的哈希，而且 `clearLoginInfoKeepingEmail`（登出）会把
        // uid 删掉、邮箱留着 —— 用 uid 判断的话，「登出后换个账号登录」这条路上旧值恒为空，
        // 检测永远不会触发。
        func normalized(_ s: String?) -> String {
            (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        let previousEmail = normalized(self.email)
        let newEmail = normalized(email)
        // 旧值为空 = 首次登录，一律不清 —— 误清是不可逆的数据损失，宁可漏清也不能错清。
        let didSwitchAccount = !previousEmail.isEmpty && !newEmail.isEmpty && previousEmail != newEmail

        // uid 缺省时退回邮箱。
        //
        // 账号身份本来就是邮箱，uid 只是服务端附带的一串哈希、可能压根不下发。但
        // SubscriptionManager 从头到尾拿 uid 当键（会员归属 serverByUid、兑换记录、
        // appAccountToken），且每处都是 `guard !uid.isEmpty` —— uid 一旦为空，
        // 整套会员逻辑会**静默失效**：兑换的会员存不进也读不出，换账号也不作废上一账号的
        // StoreKit 快照。这里补一个兜底，保证 uid 永远有值。
        //
        // 不直接把 SubscriptionManager 改成按邮箱存：已有用户的会员是按真实 uid 存的，
        // 换键需要迁移，而会员是付费权益，迁移出错的代价太大。老用户继续用服务端 uid，
        // 只有服务端不下发 uid 的账号才落到邮箱这一支。
        let storedUID = uid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? newEmail : uid

        // Save sensitive data to Keychain
        KeychainHelper.standard.save(email, forKey: emailKey)
        KeychainHelper.standard.save(storedUID, forKey: uidKey)
        KeychainHelper.standard.save(token, forKey: tokenKey)
        
        // Calculate and save expiration date
        // Default to a reasonably long time if expireDays is 0 or negative for some reason
        let days = expireDays > 0 ? expireDays : 30
        let expirationDate = Date().addingTimeInterval(TimeInterval(days * 24 * 60 * 60))
        let timestamp = expirationDate.timeIntervalSince1970
        KeychainHelper.standard.save(String(timestamp), forKey: expirationDateKey)
        
        // Also save a logged in flag if needed, though existence of token might be enough
        UserDefaults.standard.set(true, forKey: Constants.Storage.UserDefaults.isLoggedIn)

        // App 审核演示账号的构造数据开关。判据是派生的（见 HealthDataSimulator），
        // 这里只是在状态翻转时把缓存和上传进度作废，让构造数据真的生成并传上去。
        // 放在这个收口是因为上面注释已经说明：所有登录路径都经过 saveLoginInfo。
        HealthDataSimulator.shared.refreshAppReviewDemoMode()

        // 没经过登出就换了账号：把上一账号的本地数据清干净。
        //
        // 这条路径很常见 —— token 过期/401 走的是 reset(.tokenOnly)（只清 token，本地数据全留），
        // 用户被切回欢迎页，而那个邮箱输入框就是普通登录框，改成别的账号即可登录。
        // 不清的话新账号会直接看到上一个人的资料/头像/地址/首页与分析数据/站内消息，
        // 而且 mergeDraft 本地优先，新账号点「更新」会把上一账号的昵称/性别/生日以自己的 uid 传上去。
        //
        // 放在写完 Keychain **之后**：清理函数不碰鉴权信息，此时执行既不会覆盖刚写入的凭证，
        // 又能让被它触发的刷新逻辑读到新账号。
        if didSwitchAccount {
            Log.info("AuthStorage", "检测到换账号 previous=\(previousEmail) new=\(newEmail)，清理上一账号本地数据")
            SessionResetter.reset(.accountSwitch)
        }

        // token 已变化：统一广播，由 DeviceLoginPusher 负责把新 token 推给已绑定设备。
        // 放在这里而不是各调用点，保证任何写 token 的路径都不会漏掉同步。
        NotificationCenter.default.post(name: Self.tokenDidChangeNotification, object: nil)

        // 登录后校正会员归属：换了新账户则清掉上一账号的服务端会员（不继承）；同账号保留。
        // 放这里保证所有登录路径都走到。SubscriptionManager 是 @MainActor，跳主线程执行。
        Task { @MainActor in SubscriptionManager.shared.reconcileMembershipOwner() }

        // 把当前语言报给服务端。冷启动那次上报大概率发生在登录之前（接口要 uid+token，
        // 那时还没有），所以登录成功后必须补一次，否则新账号的分析文案会一直是
        // 服务端建档时的默认语种。必须排在上面 accountSwitch 清理**之后** ——
        // 那次清理会抹掉「已上报」标记，反了就会被当成已报过而跳过。
        LanguageChangeCoordinator.reportLanguageIfNeeded(reason: "login")
    }
    
    // MARK: - Read
    
    var email: String? {
        return KeychainHelper.standard.read(forKey: emailKey)
    }
    
    var uid: String? {
        return KeychainHelper.standard.read(forKey: uidKey)
    }

    var preferredUserIdentifier: String? {
        let normalizedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedEmail.isEmpty {
            return normalizedEmail
        }

        let normalizedUID = uid?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalizedUID.isEmpty ? nil : normalizedUID
    }
    
    var token: String? {
        return KeychainHelper.standard.read(forKey: tokenKey)
    }
    
    var expirationDate: Date? {
        if let timestampString = KeychainHelper.standard.read(forKey: expirationDateKey),
           let timestamp = TimeInterval(timestampString) {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }
    
    var isLoggedIn: Bool {
        // Keychain 是唯一事实来源：token 有效且未过期、且知道是哪个账号（邮箱）才算登录。
        //
        // **不检查 uid**：账号身份就是邮箱，服务端返回的 uid 只是附带的哈希，可能压根不下发。
        // 以前把它列为必要条件，等于让一个可有可无的字段决定登录态成不成立 ——
        // 服务端哪天不返回 uid，用户就会「登录成功但立刻被判为未登录」。
        guard let token = token, !token.isEmpty,
              let email = email, !email.isEmpty,
              let expirationDate = expirationDate else {
            return false
        }
        return Date() < expirationDate
    }

    // MARK: - Clear

    /// 完整清理：清掉 email/uid/token/expirationDate。用于**注销删除账号**（连账号都不留）。
    func clearLoginInfo() {
        KeychainHelper.standard.delete(forKey: emailKey)
        KeychainHelper.standard.delete(forKey: uidKey)
        KeychainHelper.standard.delete(forKey: tokenKey)
        KeychainHelper.standard.delete(forKey: expirationDateKey)

        UserDefaults.standard.set(false, forKey: Constants.Storage.UserDefaults.isLoggedIn)
        HealthDataSimulator.shared.refreshAppReviewDemoMode()
    }

    /// 退出登录用：**保留 email**（登录页预填上次账号），清 uid/token/过期 + isLoggedIn。
    /// 与 clearLoginInfo() 的区别：退出登录留账号方便重新登录；注销删除账号才连 email 一起清。
    func clearLoginInfoKeepingEmail() {
        KeychainHelper.standard.delete(forKey: uidKey)
        KeychainHelper.standard.delete(forKey: tokenKey)
        KeychainHelper.standard.delete(forKey: expirationDateKey)

        UserDefaults.standard.set(false, forKey: Constants.Storage.UserDefaults.isLoggedIn)
        HealthDataSimulator.shared.refreshAppReviewDemoMode()
    }

    /// 仅清理 token / 过期时间，保留 email / uid。
    /// 用于 token 过期场景：本地用户数据保留，下次启动直接进 re-auth 流程并把邮箱预填。
    func clearTokenOnly() {
        KeychainHelper.standard.delete(forKey: tokenKey)
        KeychainHelper.standard.delete(forKey: expirationDateKey)

        UserDefaults.standard.set(false, forKey: Constants.Storage.UserDefaults.isLoggedIn)
        HealthDataSimulator.shared.refreshAppReviewDemoMode()
    }

    #if DEBUG
    /// 调试用：把 expirationDate 改成过去 1 分钟，token / email / uid 都保留。
    /// 触发后杀掉 app 重启即可复现"启动时 token 过期"路径。
    func debugMarkExpired() {
        let past = Date(timeIntervalSinceNow: -60)
        let timestamp = past.timeIntervalSince1970
        KeychainHelper.standard.save(String(timestamp), forKey: expirationDateKey)
        UserDefaults.standard.set(false, forKey: Constants.Storage.UserDefaults.isLoggedIn)
        Log.info("AuthStorage", "[DEBUG] marked session expired: expiration=\(past) email=\(email ?? "-") uid=\(uid ?? "-") tokenLen=\(token?.count ?? 0)")
    }

    /// 调试用：保留 JWT 三段结构，把签名段最后 8 个字符替换掉。
    /// 服务端 JWT parser 能正常解出 header/payload，但签名验证一定失败 → 返回 401。
    /// 触发后随便点 Home / Health / Explore 拉一下数据 →
    /// SessionExpirationCenter 接管 → 切到 Start。
    func debugCorruptToken() {
        guard let original = token, !original.isEmpty else {
            Log.info("AuthStorage", "[DEBUG] cannot corrupt: no existing token in keychain")
            return
        }

        let tampered: String
        // 标准 JWT 是 header.payload.signature 三段。
        if original.contains(".") {
            let segments = original.split(separator: ".", omittingEmptySubsequences: false)
            if segments.count == 3, segments[2].count >= 8 {
                let sig = String(segments[2])
                let tamperedSig = String(sig.dropLast(8)) + "AAAAAAAA"
                tampered = "\(segments[0]).\(segments[1]).\(tamperedSig)"
            } else {
                tampered = original + "X"
            }
        } else {
            tampered = original + "X"
        }

        KeychainHelper.standard.save(tampered, forKey: tokenKey)
        Log.info("AuthStorage", "[DEBUG] tampered token signature; original len=\(original.count) new len=\(tampered.count); fire any API to trigger 401")
    }
    #endif
}

// MARK: - Keychain Helper

class KeychainHelper {
    static let standard = KeychainHelper()
    private init() {}

    private let logTag = "Keychain"

    /// 可访问性：**首次解锁后即可读写，包括之后锁屏期间**。
    ///
    /// 不写这个属性时系统默认是 `kSecAttrAccessibleWhenUnlocked` —— 锁屏就读不到。
    /// 而后台健康同步（BGAppRefreshTask，15 分钟一次）恰恰经常在锁屏时被唤醒，
    /// 它第一件事就是读 token；读不到就走「凭证缺失」分支静默跳过，同步等于白排。
    ///
    /// 不用更宽松的 `Always`：那个连开机未解锁都能读，且已被 Apple 废弃。
    /// `AfterFirstUnlock` 是后台任务场景的标准选择。
    private static let accessibility = kSecAttrAccessibleAfterFirstUnlock

    func save(_ data: Data, forKey key: String) {
        let deleteQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as [String: Any]

        SecItemDelete(deleteQuery as CFDictionary)

        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrAccessible: Self.accessibility,
            kSecValueData: data
        ] as [String: Any]

        // 写失败必须留痕。锁屏时会返回 errSecInteractionNotAllowed(-25308)，
        // 静默吞掉的话表现是「登录成功但下次启动又要重登」，极难定位。
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Log.error(logTag, "写入失败 key=\(key) status=\(status)")
        }
    }

    /// 把已存在的条目升级到 `AfterFirstUnlock`。
    ///
    /// 老版本写入的 token 带的是默认的 `WhenUnlocked`，光改上面的常量不会影响它们 ——
    /// 已经躺在 Keychain 里的条目属性不会自己变。这里用 SecItemUpdate 原地改属性，
    /// 不需要读出明文（读本身在锁屏时也会失败）。
    /// 在 App 启动时调一次即可，那时设备通常是解锁的。
    @discardableResult
    func upgradeAccessibility(forKey key: String) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as [String: Any]
        let attrs = [kSecAttrAccessible: Self.accessibility] as [String: Any]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        // errSecItemNotFound 是正常的（该项本来就不存在），不算失败。
        if status != errSecSuccess && status != errSecItemNotFound {
            Log.error(logTag, "升级可访问性失败 key=\(key) status=\(status)")
            return false
        }
        return true
    }
    
    func save(_ string: String, forKey key: String) {
        if let data = string.data(using: .utf8) {
            save(data, forKey: key)
        }
    }
    
    func readData(forKey key: String) -> Data? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    func read(forKey key: String) -> String? {
        if let data = readData(forKey: key) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func delete(forKey key: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as [String: Any]

        let status = SecItemDelete(query as CFDictionary)
        // 删除失败尤其危险：登出没删掉 token 就等于没登出。
        if status != errSecSuccess && status != errSecItemNotFound {
            Log.error(logTag, "删除失败 key=\(key) status=\(status)")
        }
    }
}
