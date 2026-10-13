import Foundation
import UIKit

// MARK: - 支持的语言枚举
enum SupportedLanguage: String, CaseIterable {
    case chinese = "zh-Hans"
    case english = "en"
    case german = "de"
    case spanish = "es"
    case french = "fr"
    case italian = "it"
    case japanese = "ja"
    case korean = "ko"
    case traditionalChinese = "zh-Hant"
    case indonesian = "id"
    
    var displayName: String {
        switch self {
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        case .german:
            return "Deutsch"
        case .spanish:
            return "Español"
        case .french:
            return "Français"
        case .italian:
            return "Italiano"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        case .traditionalChinese:
            return "繁體中文"
        case .indonesian:
            return "Bahasa Indonesia"
        }
    }
    
    var nativeDisplayName: String {
        switch self {
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        case .german:
            return "Deutsch"
        case .spanish:
            return "Español"
        case .french:
            return "Français"
        case .italian:
            return "Italiano"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        case .traditionalChinese:
            return "繁體中文"
        case .indonesian:
            return "Bahasa Indonesia"
        }
    }
}

// MARK: - 本地化管理器
final class LocalizationManager {
    static let shared = LocalizationManager()
    
    // 语言变更通知
    static let languageDidChangeNotification = Notification.Name("LocalizationManager.languageDidChange")
    
    private let userDefaults = UserDefaults.standard
    private let languageKey = "AppSelectedLanguage"
    
    private var currentBundle: Bundle = Bundle.main
    
    private init() {
        // 初始化时设置语言包
        setLanguageBundle()
    }
    
    // MARK: - 公共方法
    
    /// 获取当前语言
    var currentLanguage: SupportedLanguage {
        get {
            let savedLanguage = userDefaults.string(forKey: languageKey)
            if let saved = savedLanguage, let language = SupportedLanguage(rawValue: saved) {
                return language
            }
            // 没有 App 内覆盖 → 跟随系统
            return systemResolvedLanguage
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: languageKey)
            userDefaults.synchronize()
            setLanguageBundle()
            
            // 发送语言变更通知
            NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: nil)
        }
    }
    
    /// 设置语言
    func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
    }

    /// 展示型格式化（月份名、星期、上午/下午、数字）该用的 locale。
    ///
    /// 换语言包只改 `NSLocalizedString` 的查表，**改不了 `Locale.current`** ——
    /// 它始终跟着系统。所以 `DateFormatter` 不显式赋 locale 时，App 内选了日语，
    /// 月份名还是按系统语言出。凡是给用户看的格式化都从这里取 locale。
    ///
    /// 注意：传给服务端或用于解析的固定格式（`yyyy-MM-dd` 之类）**不能**用这个，
    /// 必须用 `en_US_POSIX`，否则遇到佛历/和历用户会格式化出 "2569-08-06"。
    var currentLocale: Locale {
        Locale(identifier: currentLanguage.rawValue)
    }

    // MARK: - 与系统语言设置对齐

    private let systemSnapshotKey = "AppSystemLanguageSnapshot"

    /// 是否处于「跟随系统」状态：没有 App 内覆盖时就是。
    var isFollowingSystem: Bool {
        userDefaults.string(forKey: languageKey) == nil
    }

    /// 回到跟随系统：清掉 App 内覆盖，语言交还给 iOS 的裁决。
    func followSystemLanguage() {
        userDefaults.removeObject(forKey: languageKey)
        userDefaults.synchronize()
        setLanguageBundle()
        NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: nil)
    }

    /// 系统侧当前生效的语言原始值。
    ///
    /// 用 `Bundle.main.preferredLocalizations.first` 而不是 `Locale.preferredLanguages.first`：
    /// 前者是 **iOS 针对本 App 给出的裁决**，已经把「设置 → Mindora → 语言」的 per-app 覆盖
    /// 算进去了，而且是从 App 实际带的语言包里选的，不会给出我们不支持的语种。
    ///
    /// （试过从 App 自己的 preferences domain 读 `AppleLanguages` 来单独识别 per-app 覆盖，
    /// 实测恒为 nil，这条路不通。）
    private var systemLanguageRaw: String? {
        Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first
    }

    /// 系统侧语言映射到支持列表，映射不到时回退英文。
    var systemResolvedLanguage: SupportedLanguage {
        supportedLanguage(forRaw: systemLanguageRaw) ?? .english
    }

    /// 把原始语言标识（`zh-Hans-CN` / `en-US` …）映射到支持的语言，不支持则 nil。
    private func supportedLanguage(forRaw raw: String?) -> SupportedLanguage? {
        guard let raw else { return nil }
        return SupportedLanguage.allCases.first { raw.hasPrefix($0.rawValue) }
    }

    /// 用户在系统设置里改了语言时采纳它。
    ///
    /// 在系统设置里改语言同样是**用户的显式选择**，而且发生得比 App 内那次更晚，忽略它是 bug。
    ///
    /// 判据是「系统侧的值相对上次记录**变了**」，而不是「系统值与 App 内选择不同」：
    /// 后者会让用户在 App 内选的语言每次启动都被系统值冲掉，等于 App 内的选择作废。
    /// 跟随系统状态下无需处理——`currentLanguage` 本来就实时读系统值。
    ///
    /// - Returns: 是否真的改了语言。
    @discardableResult
    func adoptSystemLanguageIfChanged() -> Bool {
        let raw = systemLanguageRaw
        let previous = userDefaults.string(forKey: systemSnapshotKey)
        userDefaults.set(raw ?? "", forKey: systemSnapshotKey)

        // 这块的判据依赖多个来源，出问题时不打出来根本没法定位，所以每次启动都记一行。
        Log.info("Language", "语言状态 系统裁决=\(raw ?? "nil") 快照=\(previous ?? "nil") "
                 + "App当前=\(currentLanguage.rawValue) 跟随系统=\(isFollowingSystem)")

        // 跟随系统时 currentLanguage 直接取系统值，不需要也不该写入 App 内覆盖。
        guard !isFollowingSystem else { return false }

        guard let previous else { return false }
        guard previous != (raw ?? "") else { return false }

        // 系统语言换成了我们不支持的语种（如俄语）：保持现状，不要莫名其妙掉成英文。
        guard let adopted = supportedLanguage(forRaw: raw) else {
            Log.info("Language", "系统语言变为 \(raw ?? "nil")，不在支持列表，维持 \(currentLanguage.rawValue)")
            return false
        }
        guard adopted != currentLanguage else { return false }

        Log.info("Language", "系统设置里改了语言：\(previous) → \(raw ?? "nil")，采纳 \(adopted.rawValue) 并回到跟随系统")
        // 清掉 App 内覆盖而不是写入新值：既然这次是从系统来的，之后就该一直跟着系统走，
        // 用户不必每次改系统都指望这套快照比对能识别出来。
        followSystemLanguage()
        return true
    }
    
    /// 本地化字符串
    func localizedString(for key: String, comment: String = "") -> String {
        let missingValue = "___LOCALIZATION_MISSING___"
        let localized = NSLocalizedString(key, bundle: currentBundle, value: missingValue, comment: comment)
        
        if localized != missingValue {
            return localized
        }
        
        // 如果当前语言没有找到key，且当前语言不是英文，尝试回退到英文
        if currentLanguage != .english {
            if let path = Bundle.main.path(forResource: SupportedLanguage.english.rawValue, ofType: "lproj"),
               let englishBundle = Bundle(path: path) {
                return NSLocalizedString(key, bundle: englishBundle, value: key, comment: comment)
            }
        }
        
        return key
    }
    
    // MARK: - 私有方法
    
    private func setLanguageBundle() {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            currentBundle = Bundle.main
            return
        }
        currentBundle = bundle
    }
}

// MARK: - 全局本地化函数
/// 本地化字符串的便捷函数
func L(_ key: String, comment: String = "") -> String {
    return LocalizationManager.shared.localizedString(for: key, comment: comment)
}

// MARK: - String 扩展
extension String {
    /// 本地化当前字符串
    var localized: String {
        return L(self)
    }
    
    /// 本地化当前字符串（带注释）
    func localized(comment: String) -> String {
        return L(self, comment: comment)
    }
}

// MARK: - UIViewController 扩展
extension UIViewController {
    /// 设置本地化标题
    func setLocalizedTitle(_ key: String) {
        title = L(key)
    }
    
    /// 监听语言变更
    func observeLanguageChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: LocalizationManager.languageDidChangeNotification,
            object: nil
        )
    }
    
    /// 语言变更回调（子类可重写）
    @objc func languageDidChange() {
        // 子类可以重写此方法来更新UI
    }
    
    func removeLanguageObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: LocalizationManager.languageDidChangeNotification,
            object: nil
        )
    }
}