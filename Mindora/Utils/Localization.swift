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
            
            // 如果没有保存的语言，则根据系统语言选择
            let systemLanguage = Locale.preferredLanguages.first ?? "en"

            // 尝试匹配系统语言
            for language in SupportedLanguage.allCases {
                if systemLanguage.hasPrefix(language.rawValue) {
                    return language
                }
            }

            // 默认回退到英文
            return .english
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
    
    /// 本地化字符串
    func localizedString(for key: String, comment: String = "") -> String {
        return NSLocalizedString(key, bundle: currentBundle, comment: comment)
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