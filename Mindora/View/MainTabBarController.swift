import UIKit

final class MainTabBarController: UITabBarController {
    // MARK: - Design Constants (设计稿尺寸)
    private let designWidth: CGFloat = 750
    private let designHeight: CGFloat = 1932
    
    // 设计稿中的像素值 - Tab Bar
    private let designTabBarHeight: CGFloat = 138          // Tab Bar 高度 (23+48+8+36+23)
    private let designTabBarCornerRadius: CGFloat = 0      // Tab Bar 圆角
    private let designTabBarBottom: CGFloat = 0            // Tab Bar 距离底部
    private let designTabBarWidth: CGFloat = 750           // Tab Bar 宽度
    private let designPaddingLeft: CGFloat = 77            // 左边距
    private let designPaddingRight: CGFloat = 73           // 右边距
    private let designIconSize: CGFloat = 48               // 图标大小
    private let designFontSize: CGFloat = 20               // 字体大小
    private let designIconTextSpacing: CGFloat = 8         // 图标文字间距
    
    // 设计稿中的颜色
    private let tabBarBackgroundColor = UIColor.black
    private let normalTextColor = UIColor.white
    private let selectedTextColor = UIColor.white          // 选中文字颜色也为白色
    
    // 计算实际尺寸的辅助方法
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    // 自定义 Tab Bar 容器
    private let customTabBarContainer = UIView()
    private var tabBarItems: [TabBarItemView] = []
    private var stackViewBottomConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViewControllers()
        
        // 隐藏系统默认的 TabBar
        tabBar.isHidden = true
        
        // 设置背景色为透明
        view.backgroundColor = .clear
        
        // 创建自定义 Tab Bar
        setupCustomTabBar()
        
        // 确保子 VC 的安全区域包含自定义 Tab Bar 的高度
        updateAdditionalSafeArea()
        
        // 监听语言变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: LocalizationManager.languageDidChangeNotification,
            object: nil
        )
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 确保自定义 Tab Bar 始终在最顶层，不被子视图遮挡
        view.bringSubviewToFront(customTabBarContainer)
        
        // 使用 window 的安全区域（纯设备安全区域，不受 additionalSafeAreaInsets 影响）
        // 来定位 stackView，打破循环依赖
        if let window = view.window {
            let deviceBottom = window.safeAreaInsets.bottom
            let newConstant = -(deviceBottom - 8)
            if stackViewBottomConstraint?.constant != newConstant {
                stackViewBottomConstraint?.constant = newConstant
            }
        }
        
        updateAdditionalSafeArea()
    }
    
    private func updateAdditionalSafeArea() {
        let tabBarHeight = customTabBarContainer.frame.height
        if tabBarHeight > 0 {
            // 使用 window 的安全区域获取纯设备安全区域，避免循环依赖
            let deviceBottomSafeArea = view.window?.safeAreaInsets.bottom ?? 0
            let additionalBottom = max(0, tabBarHeight - deviceBottomSafeArea)
            if additionalSafeAreaInsets.bottom != additionalBottom {
                additionalSafeAreaInsets.bottom = additionalBottom
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupViewControllers() {
        // 1. Home
        let home = UINavigationController(rootViewController: HomeViewController())
        home.view.backgroundColor = .clear
        
        // 2. Sleep (using HealthViewController as consistent with previous implementation)
        let sleepVC = HealthViewController()
        sleepVC.title = L("tab.sleep")
        let sleep = UINavigationController(rootViewController: sleepVC)
        sleep.view.backgroundColor = .clear
        
        // 3. Explore
        let exploreVC = ExploreViewController()
        let explore = UINavigationController(rootViewController: exploreVC)
        explore.view.backgroundColor = .clear
        
        // 4. Stores
        let storeVC = StoreViewController()
        let store = UINavigationController(rootViewController: storeVC)
        store.view.backgroundColor = .clear
        
        viewControllers = [home, sleep, explore, store]
    }
    
    // MARK: - Setup Custom Tab Bar
    
    private func setupCustomTabBar() {
        // 配置容器样式
        customTabBarContainer.backgroundColor = tabBarBackgroundColor
        customTabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customTabBarContainer)
        
        // 计算实际尺寸
        let tabBarWidth = scale(designTabBarWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let paddingLeft = scale(designPaddingLeft, basedOn: view.bounds.width, designDimension: designWidth)
        let paddingRight = scale(designPaddingRight, basedOn: view.bounds.width, designDimension: designWidth)
        // 恢复设计稿顶部间距
        let paddingTop = scale(23, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 布局约束：容器只需确定宽度、居中、和吸底
        NSLayoutConstraint.activate([
            customTabBarContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            customTabBarContainer.widthAnchor.constraint(equalToConstant: tabBarWidth),
            customTabBarContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Tab 配置
        let tabs: [(titleKey: String, image: String, selectedImage: String)] = [
            ("tab.home", "tab_home", "tab_home_select"),
            ("tab.sleep", "tab_sleep", "tab_sleep_select"),
            ("tab.explore", "tab_explore", "tab_explore_select"),
            ("tab.store", "tab_store", "tab_store_select")
        ]
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        customTabBarContainer.addSubview(stackView)
        
        // stackView 底部约束：使用 view.bottomAnchor 而非 safeAreaLayoutGuide.bottomAnchor
        // 避免与 additionalSafeAreaInsets 产生循环依赖
        // 实际常量在 viewDidLayoutSubviews 中根据设备安全区域动态设置
        let bottomConstraint = stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -26)
        stackViewBottomConstraint = bottomConstraint
        
        NSLayoutConstraint.activate([
            // StackView 顶部距离容器顶部 (严格按照设计稿)
            stackView.topAnchor.constraint(equalTo: customTabBarContainer.topAnchor, constant: paddingTop),
            
            // StackView 左右
            stackView.leadingAnchor.constraint(equalTo: customTabBarContainer.leadingAnchor, constant: paddingLeft),
            stackView.trailingAnchor.constraint(equalTo: customTabBarContainer.trailingAnchor, constant: -paddingRight),
            
            // 向下偏移 8pt 进入设备安全区域内，视觉上更平衡
            bottomConstraint
        ])
        
        // Scaled Values
        let iconSize = scale(designIconSize, basedOn: view.bounds.width, designDimension: designWidth)
        let fontSize = scale(designFontSize, basedOn: view.bounds.width, designDimension: designWidth) 
        let spacing = scale(designIconTextSpacing, basedOn: view.bounds.height, designDimension: designHeight)

        // 创建 Tab Items
        for (index, tab) in tabs.enumerated() {
            let item = TabBarItemView()
            item.configure(
                title: L(tab.titleKey),
                imageName: tab.image,
                selectedImageName: tab.selectedImage,
                normalColor: normalTextColor,
                selectedColor: selectedTextColor,
                iconSize: iconSize,
                fontSize: fontSize,
                spacing: spacing
            )
            item.tag = index
            item.addTarget(self, action: #selector(tabItemTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(item)
            tabBarItems.append(item)
        }
        
        // 默认选中第一个
        updateTabSelection(index: 0)
    }
    
    // MARK: - Actions
    
    /// Switch to Sleep tab (index 1) and optionally scroll to a specific section
    func switchToSleepTab(scrollTarget: HealthDayScrollTarget = .top) {
        let sleepIndex = 1
        
        // Pop to root on the target nav controller
        if let navController = viewControllers?[sleepIndex] as? UINavigationController {
            navController.popToRootViewController(animated: false)
        }
        
        selectedIndex = sleepIndex
        updateTabSelection(index: sleepIndex)
        
        // Find the HealthViewController and tell it to scroll
        if let navController = viewControllers?[sleepIndex] as? UINavigationController,
           let healthVC = navController.viewControllers.first as? HealthViewController {
            healthVC.navigateToDaySection(scrollTarget: scrollTarget)
        }
    }
    
    @objc private func tabItemTapped(_ sender: TabBarItemView) {
        let index = sender.tag
        
        // 如果点击的是当前已选中的 tab，或者切换到新 tab，都 pop 到根视图控制器
        if let navController = viewControllers?[index] as? UINavigationController {
            navController.popToRootViewController(animated: false)
        }
        
        selectedIndex = index
        updateTabSelection(index: index)
    }
    
    private func updateTabSelection(index: Int) {
        for (i, item) in tabBarItems.enumerated() {
            item.isSelectedState = (i == index)
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc override func languageDidChange() {
        let titleKeys = ["tab.home", "tab.sleep", "tab.explore", "tab.store"]
        for (index, item) in tabBarItems.enumerated() {
            if index < titleKeys.count {
                item.updateTitle(L(titleKeys[index]))
            }
        }
        
        // Update ViewControllers titles
        viewControllers?.enumerated().forEach { index, vc in
            if index < titleKeys.count {
                vc.title = L(titleKeys[index])
            }
        }
    }
}

// MARK: - Helper Classes

// Placeholder View Controllers

// Custom Tab Item View
private class TabBarItemView: UIControl {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    
    private var normalImage: UIImage?
    private var selectedImage: UIImage?
    private var normalColor: UIColor = .white
    private var selectedColor: UIColor = .white
    
    var isSelectedState: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Constraints will be set in configure to allow dynamic updates
        addSubview(iconImageView)
        addSubview(titleLabel)
    }
    
    func configure(title: String, imageName: String, selectedImageName: String, normalColor: UIColor, selectedColor: UIColor, iconSize: CGFloat, fontSize: CGFloat, spacing: CGFloat) {
        self.normalImage = UIImage(named: imageName)
        self.selectedImage = UIImage(named: selectedImageName)
        self.normalColor = normalColor
        self.selectedColor = selectedColor
        
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        
        // Remove old constraints
        removeConstraints(constraints)
        
        // Setup Layout with specific spacing
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: topAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: iconSize),
            iconImageView.heightAnchor.constraint(equalToConstant: iconSize),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: spacing),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        updateAppearance()
    }
    
    func updateTitle(_ title: String) {
        titleLabel.text = title
    }
    
    private func updateAppearance() {
        if isSelectedState {
            iconImageView.image = selectedImage
            titleLabel.textColor = selectedColor
        } else {
            iconImageView.image = normalImage
            titleLabel.textColor = normalColor
        }
    }
}
