import Foundation

/// 语言变化时把「服务端按语言生成的文案缓存」作废。
///
/// 首页洞察、睡眠分析文案、弹窗/问卷正文都是服务端按请求里的 `language` 渲染的，
/// 而本地缓存只按日期分键（`home.lastData.v1`、`health.analysis.*`）。不清的话：
///   - 首页 stale-while-revalidate 会先回显上一语种的洞察文案；
///   - 分析页命中内存/磁盘缓存时压根不发请求，旧语种文案一直挂着。
///
/// 除了 App 内切换，还要覆盖「系统语言变了」——用户没在 App 内选过语言时，
/// `LocalizationManager.currentLanguage` 会跟随系统，但这条路径不发任何通知。
/// 所以这里额外记录「上一次生成缓存时用的语言」，冷启动比对一次即可兜住。
enum LanguageChangeCoordinator {

    private static let lastLanguageKey = "language.serverContent.lastLanguage"
    /// 上次**成功上报给服务端**的语言。与 `lastLanguageKey` 分开存：
    /// 前者管本地缓存作废（一定成功），后者管网络上报（可能失败要重试）。
    private static let reportedLanguageKey = "language.serverReported.lastLanguage"

    /// 在 `didFinishLaunching` 里调用：必须早于任何界面发起请求，
    /// 否则根视图重建时会先用旧语种缓存渲染一次。
    static func start() {
        // 先跟系统设置对齐（用户可能在 App 没运行时改的），再比对缓存。
        // 顺序不能反 —— adopt 会改 currentLanguage，反了就会拿旧值去比对缓存。
        // 这两步放在注册监听之前：否则 adopt 里的 currentLanguage 赋值会触发下面的
        // languageDidChange 观察者，缓存作废日志被记成 in_app，排查时看不出真实来源。
        LocalizationManager.shared.adoptSystemLanguageIfChanged()
        invalidateIfLanguageChanged(reason: "launch")
        // 冷启动也要报：老账号服务端那份 language 是建档时的默认值，用户可能从装上
        // App 起就是英文、从没切过语言，光靠「切换时上报」永远轮不到他们。
        reportLanguageIfNeeded(reason: "launch")

        NotificationCenter.default.addObserver(
            forName: LocalizationManager.languageDidChangeNotification,
            object: nil, queue: .main
        ) { _ in
            invalidateIfLanguageChanged(reason: "in_app")
            reportLanguageIfNeeded(reason: "in_app")
        }

        // 用户在「设置 → Mindora → 语言」里改语言，同样是显式选择，要采纳。
        // iOS 改 per-app 语言通常会重启 App，所以主要靠下面的冷启动那次；
        // 这条监听兜住不重启的情况（如只改了地区首选语言顺序）。
        NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil, queue: .main
        ) { _ in
            LocalizationManager.shared.adoptSystemLanguageIfChanged()
            invalidateIfLanguageChanged(reason: "system_locale")
            reportLanguageIfNeeded(reason: "system_locale")
        }
    }

    /// 把当前语言上报给服务端（`update_profile` → `user_profile.profile.language`）。
    ///
    /// 分析接口请求体里的 `data.language` 服务端不据此选语种，只落到
    /// `last_request_language`；生成 label / description 时读的是画像里的
    /// `profile.language`，以那份配置为准。所以切语言时必须单独报一次，
    /// 否则切成英文后拿到的还是中文文案。
    ///
    /// 幂等：与上次**成功**上报的值相同就跳过，不为每次冷启动白发一个请求。
    /// 失败不写标记、也不重试 —— 下次冷启动或下次切换会自然再报。
    static func reportLanguageIfNeeded(reason: String) {
        let current = LocalizationManager.shared.currentLanguage.rawValue
        guard UserDefaults.standard.string(forKey: reportedLanguageKey) != current else { return }
        // 接口要 uid + token。未登录时报不了，登录成功后 AuthStorage 会再叫一次。
        guard AuthStorage.shared.preferredUserIdentifier?.isEmpty == false,
              AuthStorage.shared.token?.isEmpty == false else { return }

        Task {
            do {
                try await UserProfileService.shared.reportLanguage(current)
                UserDefaults.standard.set(current, forKey: reportedLanguageKey)
                Log.info("Language", "已上报语言 \(current)（\(reason)）")
            } catch {
                Log.error("Language", "上报语言 \(current) 失败（\(reason)）：\(error)")
            }
        }
    }

    /// 清掉「已上报」标记。换账号 / 登出 / 注销时调用 —— 下一个账号在服务端那份
    /// language 可能是别的值，必须重新报一次，不能因为本机标记还在就跳过。
    static func resetReportedLanguage() {
        UserDefaults.standard.removeObject(forKey: reportedLanguageKey)
    }

    /// 与上次记录的语言比对，变了才清缓存。没变时什么都不做，避免每次启动白丢缓存。
    static func invalidateIfLanguageChanged(reason: String) {
        let current = LocalizationManager.shared.currentLanguage.rawValue
        let previous = UserDefaults.standard.string(forKey: lastLanguageKey)
        guard previous != current else { return }

        UserDefaults.standard.set(current, forKey: lastLanguageKey)

        // 首次运行（previous == nil）只记录，不清——缓存本来就是空的，清了只是白跑。
        guard let previous else {
            Log.info("Language", "首次记录语言 \(current)（\(reason)）")
            return
        }

        Log.info("Language", "语言 \(previous) → \(current)（\(reason)），作废服务端文案缓存")
        HomeService.clearCache()
        HealthAnalysisService.shared.clearCache()
        // 弹窗/问卷只丢内容，不动「已忽略 / 已提交」状态 —— 那些与语言无关，
        // 清掉会让用户已经处理过的弹窗和问卷又冒出来。
        PopupService.shared.invalidateContentCache()
        SurveyService.shared.invalidateContentCache()
    }
}
