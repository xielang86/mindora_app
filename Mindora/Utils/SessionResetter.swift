//
//  SessionResetter.swift
//  mindora
//
//  统一的「清理本地账号数据」入口。
//
//  === 为什么写成一张表 ===
//
//  这里原先是三个函数 + 两个布尔参数，「哪条路径清哪些东西」散落在各自的函数体里。
//  新增一种本地数据时，得记着去几个地方各判断一次；顺序上还有隐式依赖（账号清单以
//  邮箱做命名空间，必须赶在清邮箱之前删），没有任何东西保护，重排两行就静默失效。
//
//  改成：**每种数据在 `items` 里声明自己属于哪几个 scope**，执行器按表顺序跑。
//  新增数据 = 在表里加一行并勾选 scope，不用读任何一条清理路径的实现。
//

import Foundation

/// 清理场景。四条路径的差别只在「清到什么程度」。
enum ResetScope {
    /// 401 / token 过期。用户没有主动登出，本地数据全部保留，重新登录后无缝继续。
    case tokenOnly
    /// 主动退出登录。保留邮箱（登录页预填）与「同账号回来仍然有效」的那部分数据。
    case logout
    /// 没经过登出就换了账号（`AuthStorage.saveLoginInfo` 检测到邮箱变了）。
    ///
    /// 不是边角情况：401 走 `tokenOnly`，本地数据全留，用户被切回欢迎页，
    /// 而那个邮箱输入框就是普通登录框、可以随便改成别的账号。不清的话新账号会直接
    /// 看到上一个人的资料/头像/地址/首页与分析数据/站内消息。
    case accountSwitch
    /// 注销删除账号。连邮箱、账号清单、引导页标记一起清，等同全新安装。
    case deleteAccount
}

enum SessionResetter {

    private static let logTag = "SessionResetter"

    // MARK: - 声明表

    private struct Item {
        let name: String
        let scopes: Set<ResetScope>
        let clear: () -> Void
    }

    /// 按**执行顺序**声明。顺序上唯一的硬约束：`accountVaults` 必须排在 `auth` 之前
    /// —— 清单以账号邮箱做命名空间，邮箱一没就找不到该删哪份了。
    private static var items: [Item] {
        [
            // 账号清单（收到过哪些消息 / 读没读 / 答过哪份问卷）。
            // 只有注销才清：登出还清就回到了「重新登录后消息全没了」的老 bug。
            Item(name: "accountVaults", scopes: [.deleteAccount]) {
                AccountVault.purgeCurrentAccount()
                SurveyService.shared.purgeLegacySubmitted()
            },

            // 鉴权信息。tokenOnly 只清 token/过期时间，保留邮箱与 uid；
            // logout 额外清 uid（保留邮箱以便登录页预填）；deleteAccount 连邮箱一起清。
            Item(name: "auth", scopes: [.tokenOnly, .logout, .deleteAccount]) {
                // 具体清到哪一层由 reset() 按 scope 决定，见下方 clearAuth(for:)。
            },

            // 「本次进程已拉过服务端资料」的标记。这只是进程内状态，任何一次登录态变化
            // 都该复位：新的登录必须先拉到属于自己的资料，才允许自动上传，
            // 否则可能拿一份残缺的本地数据覆盖服务端。
            Item(name: "userProfileRemoteFlag", scopes: [.logout, .accountSwitch, .deleteAccount]) {
                UserProfileSync.resetRemoteFlag()
            },

            // 用户资料本体：本地草稿 / 已上传基准 / 头像文件 / 地址本 / mock 标记。
            //
            // **登出不清**，理由比站内消息更硬：消息至少还能从服务端拉回来，而**头像文件
            // 和地址本是纯本地的**（服务端当前对本账号返回的就是 profile: null）——
            // 登出清掉就是永久丢失，用户没做错任何事却丢了自己传的头像。
            //
            // 换账号照清：那时这些确实属于上一个人。检测按邮箱判断且在 saveLoginInfo 里
            // 同步执行，早于任何界面渲染，不存在串号。
            Item(name: "userProfile", scopes: [.accountSwitch, .deleteAccount]) {
                UserProfileStore.shared.clear()
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: "user_profile_avatar")
                defaults.removeObject(forKey: UserProfileSync.addressStorageKey)
                defaults.removeObject(forKey: "MindoraMockAddressInitialized")
                // 头像真正存的是 Documents/user_avatar.jpg，UserDefaults 那个 key 是历史遗留；
                // 文件必须删，否则换账号后头像残留。
                if let url = UserProfileSync.avatarURL {
                    try? FileManager.default.removeItem(at: url)
                }
            },

            // 设备会话：已绑定设备 + 用户自己起的设备昵称，纯本地数据。
            // **登出不清** —— 清掉意味着用户每次退出重进都要重新扫描、重新绑定自己的
            // Mindora，昵称也没了。设备是物理上属于这个人的，跟登录态没关系。
            Item(name: "deviceSession", scopes: [.accountSwitch, .deleteAccount]) {
                DeviceSession.shared.clear()
            },

            // 健康同步进度：传到哪一天了 / 切片记录 / 同步配置 / 时间锚点。
            //
            // **登出不清**。登出后最可能发生的是同一个账号重新登录，这些进度完全有效，
            // 清掉只会白白重传 30 天。以前无差别清是 bug。
            // 换账号才必须清 —— 这个区分之所以安全，是因为换账号检测按邮箱判断
            // （见 AuthStorage.saveLoginInfo），而登出保留邮箱，所以「登出 → 换个账号
            // 登录」仍然会走到 accountSwitch。
            Item(name: "healthSyncProgress", scopes: [.accountSwitch, .deleteAccount]) {
                UploadStateStore.shared.reset()
                SyncSliceRecord.shared.reset()
                HealthSyncConfigStore.shared.save(.default())
            },

            // 健康数据查询缓存：纯缓存，重建代价小，哪条路径都清。
            // 不清 HealthKit 原始数据——那是设备级的，App 只有读权限，本来也删不了。
            Item(name: "healthQueryCache", scopes: [.logout, .accountSwitch, .deleteAccount]) {
                Task { await HealthDataManager.shared.queryCache.removeAll() }
            },

            // 纯内存缓存：问卷题目预拉。杀进程本来就没了，清不清都无所谓，
            // 但登出后语言/账号可能变，顺手丢掉更干净。
            Item(name: "volatileCaches", scopes: [.logout, .accountSwitch, .deleteAccount]) {
                SurveyService.shared.clearCache()
            },

            // 「已把语言上报给服务端」的标记。它记的是**服务端那份画像**的状态，
            // 换个账号就完全不作数了 —— 不清的话新账号会被当成已报过而跳过，
            // 分析文案一直用服务端建档时的语种。
            // tokenOnly 不清：同一个账号，服务端那份没变。
            Item(name: "reportedLanguage", scopes: [.logout, .accountSwitch, .deleteAccount]) {
                LanguageChangeCoordinator.resetReportedLanguage()
            },

            // 服务端会员状态缓存（query_user_rights 下发的快照）。它只是缓存：登录后
            // AuthService 会强制重拉，所以登出 / 换账号 / 注销都可以清。旧的兑换码 per-uid
            // 记录（serverByUid）仍按原规矩不清。
            Item(name: "serverMembershipState", scopes: [.logout, .accountSwitch, .deleteAccount]) {
                MembershipStateStore.shared.clearAll()
            },

            // 账号级业务数据：首页数据、日/周/月分析（含睡眠评分）、弹窗频控、陪伴足迹。
            // **登出一律不清**，逐条理由：
            //
            //  - 陪伴足迹（footprint.tracker.days.v1）是**待上传队列**，没传成功的记录
            //    一清就是永久丢失，属于真数据丢失而不是「缓存失效」。
            //  - 弹窗频控（shownCount / lastShown / dismissed）清掉后，用户明确关过的
            //    弹窗重新登录会再弹一次 —— 跟「绝不重复打扰」的原则直接冲突。
            //  - 日/周/月分析是服务端 LLM 生成的（接口超时给到 600s），清掉等于让用户
            //    重新等一次长时间生成。
            //  - 首页数据虽然重拉很便宜，但同属账号级派生数据，跟着一起走更好理解。
            //
            // 注意：服务端授予的会员（兑换码）**任何 scope 都不在这里清**。它是账号级数据、
            // 且登录时不会从服务端重新拉取，清掉会让同一用户重新登录后永久丢失已兑换的会员。
            // 改为「按 owner uid 归属」，见 SubscriptionManager.reconcileMembershipOwner()。
            Item(name: "accountData", scopes: [.accountSwitch, .deleteAccount]) {
                HomeService.clearCache()
                HealthAnalysisService.shared.clearCache()
                ExploreManager.shared.clearCache()
                PopupService.shared.clearCache()
                CompanionFootprintService.shared.clearCache()
            },

            // 站内消息本体 + 消息引擎快照。**登出不清**。
            //
            // 这是本轮改动的核心简化：消息本来就是「这个账号的长期资产」，登出后最可能
            // 发生的是同一个账号重新登录，把它清掉再从服务端拉回来纯属绕远路 —— 也正是
            // 那个「登出重登消息全没了」bug 的成因（服务端不会重复下发）。
            //
            // 之所以敢不清，是因为换账号检测现在按邮箱判断且发生在 saveLoginInfo 里、
            // 早于任何界面渲染：登出保留邮箱，用别的账号登录一定会命中 accountSwitch，
            // 消息在新账号看到界面之前就被清掉了，不存在串号。
            Item(name: "notifications", scopes: [.accountSwitch, .deleteAccount]) {
                AppNotificationStore.shared.clear()
                Task { @MainActor in AppNotificationEngine.shared.reset() }
            },

            // 睡眠计划：账号级业务数据（跟首页/分析同类），登出不清，换账号/注销才清，
            // 同时取消掉所有已排的入睡提醒本地通知，避免残留上一账号的计划继续响铃。
            Item(name: "sleepPlans", scopes: [.accountSwitch, .deleteAccount]) {
                SleepPlanStore.shared.clear()
            },

            // 权限提醒计数（已经催过用户几次开健康/蓝牙权限）。
            // **登出不清** —— 清掉就是从头再催一遍，同一个人、同一台设备、同一个系统开关，
            // 没有任何理由因为他登出过一次就重新打扰。
            Item(name: "permissionCounters", scopes: [.accountSwitch, .deleteAccount]) {
                PermissionManager.shared.resetHealthReminderCount()
                PermissionManager.shared.resetBluetoothReminderCount()
            },

            // 引导页标记。**只有注销才清** —— 以前登出也清，老用户每次退出重进都要
            // 重看一遍引导页，那是 bug。
            //
            // 换账号也不清：换账号是在登录**过程中**触发的，而 RegisterP1Controller
            // 早在发验证码之前就已经读过 hasSeenOnboarding 决定了要不要跳 P3/P4，
            // 中途改它会让导航走到一半自相矛盾。
            Item(name: "onboarding", scopes: [.deleteAccount]) {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: "hasSeenOnboarding")
                defaults.removeObject(forKey: "hasCompletedOnboarding")
            },
        ]
    }

    // MARK: - 执行

    /// 唯一入口。
    ///
    /// 注意 `HealthDataManager` 的内存缓存清理是异步的，会以 fire-and-forget 方式启动。
    /// 语言、主题等设备级 UX 偏好任何 scope 都不碰。
    static func reset(_ scope: ResetScope) {
        var applied: [String] = []
        for item in items where item.scopes.contains(scope) {
            if item.name == "auth" {
                clearAuth(for: scope)
            } else {
                item.clear()
            }
            applied.append(item.name)
        }

        // token 变化必须广播：SceneDelegate 据此把前台常驻服务（BLE + Bonjour 设备发现、
        // JWT 周期补推、弹窗轮询）停掉，否则登出后回到欢迎页这些还在跑，白白耗电发热。
        // 放在最后 —— 此时 DeviceSession 已清空，DeviceLoginPusher 收到后遍历到的是空
        // entries，不会误推。
        //
        // accountSwitch 不发：那条路径是 saveLoginInfo 调进来的，它自己会在写完新凭证
        // 之后发一次；这里提前发会让监听方读到「旧 token 已清、新 token 未写」的中间态。
        if scope != .accountSwitch {
            NotificationCenter.default.post(name: AuthStorage.tokenDidChangeNotification, object: nil)
        }

        Log.info(logTag, "reset(\(scope)) 完成：\(applied.joined(separator: ", "))")
    }

    private static func clearAuth(for scope: ResetScope) {
        switch scope {
        case .tokenOnly:
            // 只清 token / 过期时间，保留邮箱与 uid：用户没主动登出，本地数据要保留，
            // 重新登录后无缝继续，登录页也能预填邮箱。
            AuthStorage.shared.clearTokenOnly()
        case .logout:
            // 保留邮箱，登录页预填上次账号。
            AuthStorage.shared.clearLoginInfoKeepingEmail()
        case .deleteAccount:
            AuthStorage.shared.clearLoginInfo()
        case .accountSwitch:
            // 换账号时新凭证正在写入，绝不能清。
            break
        }
    }
}
