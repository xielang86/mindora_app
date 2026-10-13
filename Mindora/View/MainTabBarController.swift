import UIKit

/// 主 Tab 容器。
///
/// 不再继承 `UITabBarController`：iOS 26 重写了 `UITabBarController`（Liquid Glass 浮动 tab
/// bar、新的 `mode` / `tabs` API），叠上我们原本"隐藏系统 tabBar + 自画一套 customTabBarContainer"
/// 的玩法，view 在被 set 成 rootViewController 时没法 attach 到 window（viewWillAppear 时
/// view.window == nil，viewDidAppear 不触发 → 黑屏 / 进不了首页）。
///
/// 反正系统 tab bar 已经被藏了，继承纯属包袱。改成普通 `UIViewController` 自己管 4 个 child VC，
/// 外观、`selectedIndex`、`switchToSleepTab(scrollTarget:)` 这些都保持一致。
final class MainTabBarController: UIViewController {
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
        let capped = iPadAdaptiveScale.capped(dimension, widthReference: view.bounds.width)
        return designValue * (capped / designDimension)
    }

    // 自定义 Tab Bar 容器
    private let customTabBarContainer = UIView()
    private var isCustomTabBarHidden = false
    private var tabBarItems: [TabBarItemView] = []
    private var stackViewBottomConstraint: NSLayoutConstraint?

    // Child VC 容器（child.view 会贴在 customTabBarContainer 之下）
    private let contentContainer = UIView()

    private func normalizedLayoutValue(_ value: CGFloat) -> CGFloat {
        let scale = view.window?.screen.scale ?? UIScreen.main.scale
        guard scale > 0 else { return value }
        return (value * scale).rounded() / scale
    }

    // MARK: - Public API（保持兼容）

    /// 4 个 Tab 对应的 VC。外部只读，内部在 setupViewControllers 时填充。
    private(set) var viewControllers: [UIViewController]? = nil

    /// 当前选中的 Tab 索引。
    var selectedIndex: Int = 0 {
        didSet {
            guard isViewLoaded else { return }
            if oldValue != selectedIndex {
                switchChild(from: oldValue, to: selectedIndex)
            }
            updateTabSelection(index: selectedIndex)
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        Log.info("MainTab", "viewDidLoad")

        // 设置背景色为黑色
        view.backgroundColor = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0)

        // 内容容器（child.view 贴这里）
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        setupViewControllers()

        // 创建自定义 Tab Bar（要在 installChild 之前，child.view insert 到 tabBar 之下）
        setupCustomTabBar()

        // 装入第一个 child
        if let vcs = viewControllers, !vcs.isEmpty {
            let idx = min(max(selectedIndex, 0), vcs.count - 1)
            installChild(at: idx)
            updateTabSelection(index: idx)
        }

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

        updateTabBarLayoutIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Log.info("MainTab", "viewWillAppear frame=\(view.frame) window=\(view.window != nil ? "exists" : "nil")")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Log.info("MainTab", "viewDidAppear frame=\(view.frame) window=\(view.window != nil ? "exists" : "nil") isKey=\(view.window?.isKeyWindow ?? false) selected=\(selectedIndex)")
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

    /// 二级页（如睡眠计划编辑页）设计稿里没有 Tab Bar，push 进去时整条隐藏并归还底部安全区。
    func setCustomTabBarHidden(_ hidden: Bool) {
        guard isCustomTabBarHidden != hidden else { return }
        isCustomTabBarHidden = hidden
        customTabBarContainer.isHidden = hidden
        if hidden {
            additionalSafeAreaInsets.bottom = 0
        } else {
            updateAdditionalSafeArea()
        }
    }

    private func updateTabBarLayoutIfNeeded() {
        guard !isCustomTabBarHidden else { return }
        let deviceBottom = normalizedLayoutValue(view.window?.safeAreaInsets.bottom ?? view.safeAreaInsets.bottom)
        let targetBottomConstant = normalizedLayoutValue(-(deviceBottom - 8))
        if stackViewBottomConstraint?.constant != targetBottomConstant {
            stackViewBottomConstraint?.constant = targetBottomConstant
        }

        let tabBarHeight = normalizedLayoutValue(customTabBarContainer.bounds.height)
        guard tabBarHeight > 0 else { return }

        let additionalBottom = normalizedLayoutValue(max(0, tabBarHeight - deviceBottom))
        if additionalSafeAreaInsets.bottom != additionalBottom {
            additionalSafeAreaInsets.bottom = additionalBottom
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

        // 3. Plan（睡眠计划）
        let planVC = SleepPlanViewController()
        planVC.title = L("tab.plan")
        let plan = UINavigationController(rootViewController: planVC)
        plan.view.backgroundColor = .clear

        // 4. Explore
        let exploreVC = ExploreViewController()
        let explore = UINavigationController(rootViewController: exploreVC)
        explore.view.backgroundColor = .clear

        // 5. Stores
        let storeVC = StoreViewController()
        let store = UINavigationController(rootViewController: storeVC)
        store.view.backgroundColor = .clear

        viewControllers = [home, sleep, plan, explore, store]
    }

    // MARK: - Child Containment

    private func installChild(at index: Int) {
        guard let vcs = viewControllers, index >= 0, index < vcs.count else { return }
        let child = vcs[index]
        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            child.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            child.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        child.didMove(toParent: self)
    }

    private func removeChild(at index: Int) {
        guard let vcs = viewControllers, index >= 0, index < vcs.count else { return }
        let child = vcs[index]
        guard child.parent === self else { return }
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
    }

    private func switchChild(from oldIndex: Int, to newIndex: Int) {
        removeChild(at: oldIndex)
        installChild(at: newIndex)
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
            ("tab.plan", "tab_plan", "tab_plan_select"),
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
        if let vcs = viewControllers, sleepIndex < vcs.count,
           let navController = vcs[sleepIndex] as? UINavigationController {
            navController.popToRootViewController(animated: false)
        }

        selectedIndex = sleepIndex

        // Find the HealthViewController and tell it to scroll
        if let vcs = viewControllers, sleepIndex < vcs.count,
           let navController = vcs[sleepIndex] as? UINavigationController,
           let healthVC = navController.viewControllers.first as? HealthViewController {
            healthVC.navigateToDaySection(scrollTarget: scrollTarget)
        }
    }

    @objc private func tabItemTapped(_ sender: TabBarItemView) {
        let index = sender.tag

        // 如果点击的是当前已选中的 tab，或者切换到新 tab，都 pop 到根视图控制器
        if let vcs = viewControllers, index < vcs.count,
           let navController = vcs[index] as? UINavigationController {
            navController.popToRootViewController(animated: false)
        }

        if index != selectedIndex {
            selectedIndex = index
        } else {
            updateTabSelection(index: index)
        }
    }

    private func updateTabSelection(index: Int) {
        for (i, item) in tabBarItems.enumerated() {
            item.isSelectedState = (i == index)
        }
    }

    // MARK: - Notification Handlers

    @objc override func languageDidChange() {
        let titleKeys = ["tab.home", "tab.sleep", "tab.plan", "tab.explore", "tab.store"]
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

// MARK: - Helper: 从任意子 VC 上溯找到 MainTabBarController

extension UIViewController {
    /// 走 parent 链找到外层的 MainTabBarController。
    /// 原来靠 UIViewController.tabBarController 走 UITabBarController 祖先链拿到，
    /// 现在 MainTabBarController 不再是 UITabBarController，要手动找。
    var mindoraMainTab: MainTabBarController? {
        var p: UIViewController? = self.parent
        while let parent = p {
            if let main = parent as? MainTabBarController { return main }
            p = parent.parent
        }
        return nil
    }
}

// MARK: - Helper Classes

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

// MARK: - 便捷查找

extension UIViewController {
    /// 沿 parent 链向上找承载当前页面的 MainTabBarController（用于二级页隐藏自定义 Tab Bar）。
    var hostMainTabBarController: MainTabBarController? {
        var current: UIViewController? = self
        while let vc = current {
            if let tab = vc as? MainTabBarController { return tab }
            current = vc.parent
        }
        return nil
    }
}
