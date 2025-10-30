import UIKit

final class MainTabBarController: UITabBarController {
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    
    // 设计稿中的像素值 - Tab Bar
    private let designTabBarHeight: CGFloat = 176          // Tab Bar 高度
    private let designTabBarFontSize: CGFloat = DesignConstants.subtitleFontSize  // Tab 文字大小 (54pt Medium)
    private let designTabBarCornerRadius: CGFloat = 88     // Tab Bar 圆角
    private let designTabBarBottom: CGFloat = 60          // Tab Bar 距离底部（不包含安全区）
    private let designTabBarWidth: CGFloat = 1129          // Tab Bar 宽度
    private let designTabBarHorizontalPadding: CGFloat = 30  // Tab 文字距离容器边缘的距离
    
    // 设计稿中的颜色
    private let selectedColor = UIColor(red: 10/255, green: 137/255, blue: 0/255, alpha: 1.0)  // 选中颜色 RGB(10, 137, 0)
    private let normalColor = UIColor.white  // 未选中颜色 - 白色
    private let backgroundColor = UIColor(red: 21/255, green: 21/255, blue: 21/255, alpha: 1.0)  // 背景色 RGB(21, 21, 21)
    
    // 计算实际尺寸的辅助方法
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    // 自定义 Tab Bar 容器
    private let customTabBarContainer = UIView()
    private var tabButtons: [UIButton] = []
    private var currentSelectedIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let home = UINavigationController(rootViewController: HomeViewController())
        home.view.backgroundColor = .clear
        
        let health = UINavigationController(rootViewController: HealthViewController())
        health.view.backgroundColor = .clear
        
        let settings = UINavigationController(rootViewController: SettingsViewController())
        settings.view.backgroundColor = .clear

        viewControllers = [home, health, settings]

        // 隐藏系统默认的 TabBar
        tabBar.isHidden = true
        
        // 设置背景色为透明，让背景图可以显示
        view.backgroundColor = .clear
        
        // 创建自定义 Tab Bar
        setupCustomTabBar()
        
        // 监听语言变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: LocalizationManager.languageDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup Custom Tab Bar
    
    /// 创建自定义 Tab Bar（圆角矩形容器 + 纯文字按钮）
    private func setupCustomTabBar() {
        // 配置容器样式 - 背景色 RGB(21, 21, 21)
        customTabBarContainer.backgroundColor = UIColor(red: 21/255, green: 21/255, blue: 21/255, alpha: 1.0)
        customTabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customTabBarContainer)
        
        // 计算实际尺寸
        let tabBarHeight = scale(designTabBarHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let tabBarWidth = scale(designTabBarWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let cornerRadius = scale(designTabBarCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        let bottomMargin = scale(designTabBarBottom, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 设置圆角
        customTabBarContainer.layer.cornerRadius = cornerRadius
        customTabBarContainer.clipsToBounds = true
        
        // 布局约束 - 居中，底部距离安全区
        NSLayoutConstraint.activate([
            customTabBarContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            customTabBarContainer.widthAnchor.constraint(equalToConstant: tabBarWidth),
            customTabBarContainer.heightAnchor.constraint(equalToConstant: tabBarHeight),
            customTabBarContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -bottomMargin)
        ])
        
        // 创建三个 Tab 按钮
        let titles = [L("tab.home"), L("tab.health"), L("tab.settings")]
        // 根据设计稿像素值计算实际字体大小（设计稿是 54px，参考 OnboardingPage4 的处理方式）
        let fontSize = scale(designTabBarFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        
        for (index, title) in titles.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            button.tag = index
            button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            customTabBarContainer.addSubview(button)
            tabButtons.append(button)
        }
        
        // 计算水平边距
        let horizontalPadding = scale(designTabBarHorizontalPadding, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 水平均分三个按钮
        let stackView = UIStackView(arrangedSubviews: tabButtons)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        customTabBarContainer.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: customTabBarContainer.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: customTabBarContainer.leadingAnchor, constant: horizontalPadding),
            stackView.trailingAnchor.constraint(equalTo: customTabBarContainer.trailingAnchor, constant: -horizontalPadding),
            stackView.bottomAnchor.constraint(equalTo: customTabBarContainer.bottomAnchor)
        ])
        
        // 默认选中第一个
        updateTabSelection(index: 0)
    }
    
    /// Tab 按钮点击事件
    @objc private func tabButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        selectedIndex = index
        updateTabSelection(index: index)
    }
    
    /// 更新 Tab 选中状态
    private func updateTabSelection(index: Int) {
        currentSelectedIndex = index
        
        for (i, button) in tabButtons.enumerated() {
            if i == index {
                // 选中状态 - 绿色 RGB(10, 137, 0)
                button.setTitleColor(selectedColor, for: .normal)
            } else {
                // 未选中状态 - 白色
                button.setTitleColor(normalColor, for: .normal)
            }
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc override func languageDidChange() {
        // 更新 Tab 按钮文字
        let titles = [L("tab.home"), L("tab.health"), L("tab.settings")]
        for (index, button) in tabButtons.enumerated() {
            button.setTitle(titles[index], for: .normal)
        }
    }
}
