import UIKit

enum ThemeMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return L("theme.system")
        case .light: return L("theme.light")
        case .dark: return L("theme.dark")
        }
    }
}

class Theme {
    static let shared = Theme()
    
    private let themeKey = "app_theme_mode"
    private(set) var currentMode: ThemeMode = .system
    
    // 主题变更通知
    static let didChangeNotification = Notification.Name("ThemeDidChange")
    
    private init() {
        loadSavedTheme()
    }
    
    // 加载保存的主题设置
    private func loadSavedTheme() {
        if let savedTheme = UserDefaults.standard.string(forKey: themeKey),
           let mode = ThemeMode(rawValue: savedTheme) {
            currentMode = mode
        } else {
            // 默认使用深色模式
            currentMode = .dark
        }
        applyTheme()
    }
    
    // 设置主题模式
    func setThemeMode(_ mode: ThemeMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: themeKey)
        applyTheme()
        NotificationCenter.default.post(name: Theme.didChangeNotification, object: nil)
    }
    
    // 应用主题到系统
    private func applyTheme() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        let interfaceStyle: UIUserInterfaceStyle
        switch currentMode {
        case .system:
            interfaceStyle = .unspecified
        case .light:
            interfaceStyle = .light
        case .dark:
            interfaceStyle = .dark
        }
        
        windowScene.windows.forEach { window in
            window.overrideUserInterfaceStyle = interfaceStyle
        }
    }
    
    // 判断当前是否为深色模式
    private var isDarkMode: Bool {
        switch currentMode {
        case .system:
            return UITraitCollection.current.userInterfaceStyle == .dark
        case .light:
            return false
        case .dark:
            return true
        }
    }
    
    // 动态颜色属性
    static var background: UIColor {
        return shared.isDarkMode ? UIColor.black : UIColor.systemBackground
    }
    
    static var surface: UIColor {
        return shared.isDarkMode ? UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1) : UIColor.secondarySystemBackground
    }
    
    static var primary: UIColor {
        return shared.isDarkMode ? UIColor.white : UIColor.label
    }
    
    static var secondary: UIColor {
        return shared.isDarkMode ? UIColor(white: 1.0, alpha: 0.7) : UIColor.secondaryLabel
    }
    
    static let accent = UIColor.systemBlue

    // MARK: - 新增：科技感主题参数
    static var cornerRadius: CGFloat { 16 }
    static var smallCornerRadius: CGFloat { 12 }
    static var largeCornerRadius: CGFloat { 22 }
    
    // 霓虹渐变主色（蓝-青-紫）
    static var neonGradientColors: [UIColor] {
        if shared.isDarkMode {
            return [
                UIColor(red: 0.33, green: 0.80, blue: 1.00, alpha: 1.0), // 天蓝
                UIColor(red: 0.22, green: 0.92, blue: 0.92, alpha: 1.0), // 青色
                UIColor(red: 0.60, green: 0.45, blue: 1.00, alpha: 1.0)  // 紫罗兰
            ]
        } else {
            return [
                UIColor(red: 0.28, green: 0.60, blue: 1.00, alpha: 1.0),
                UIColor(red: 0.10, green: 0.80, blue: 0.80, alpha: 1.0),
                UIColor(red: 0.55, green: 0.35, blue: 1.00, alpha: 1.0)
            ]
        }
    }
    
    // 卡片背景（半透明叠加）
    static var cardBackground: UIColor {
        if shared.isDarkMode {
            return UIColor(white: 1.0, alpha: 0.06)
        } else {
            return UIColor(white: 0.0, alpha: 0.04)
        }
    }
    
    // 毛玻璃效果
    static var blurEffect: UIBlurEffect {
        if #available(iOS 13.0, *) {
            return UIBlurEffect(style: shared.isDarkMode ? .systemUltraThinMaterialDark : .systemUltraThinMaterial)
        } else {
            return UIBlurEffect(style: .light)
        }
    }
    
    // 阴影样式（柔和发光）
    static func applyCardShadow(to layer: CALayer) {
        layer.shadowColor = UIColor.black.withAlphaComponent(0.45).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 10)
        layer.shadowRadius = 20
    }
    
    // 图标容器阴影（霓虹微光）
    static func applyNeonGlow(to layer: CALayer, color: UIColor = Theme.neonGradientColors.first ?? Theme.accent) {
        layer.shadowColor = color.withAlphaComponent(0.9).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = .zero
        layer.shadowRadius = 12
    }
    
    // 生成渐变图层
    static func makeGradientLayer(direction: CGPoint = CGPoint(x: 1, y: 0)) -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.colors = neonGradientColors.map { $0.cgColor }
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = direction
        return gradient
    }

    static func label(_ weight: UIFont.Weight = .regular, size: CGFloat) -> UILabel {
        let l = UILabel()
        l.textColor = primary
        l.font = .systemFont(ofSize: size, weight: weight)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    static func filledButton(title: String) -> UIButton {
        let b = UIButton(type: .system)
        
        if #available(iOS 15.0, *) {
            var cfg = UIButton.Configuration.filled()
            cfg.title = title
            cfg.baseBackgroundColor = accent
            cfg.baseForegroundColor = .white
            cfg.cornerStyle = .large
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
            b.configuration = cfg
        } else {
            // iOS 14.0 兼容方案
            b.setTitle(title, for: .normal)
            b.backgroundColor = accent
            b.setTitleColor(.white, for: .normal)
            b.layer.cornerRadius = 12
            b.contentEdgeInsets = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
            b.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        }
        
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }
}
