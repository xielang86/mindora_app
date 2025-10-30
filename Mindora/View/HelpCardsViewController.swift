import UIKit

final class HelpCardsViewController: UIViewController {
    private var pages: [(String, String)] {
        return [
            (L("help.connect_01_title"), L("help.connect_01_content")),
            (L("help.connect_02_title"), L("help.connect_02_content")),
            (L("help.connect_03_title"), L("help.connect_03_content")),
            (L("help.connect_04_title"), L("help.connect_04_content")),
            (L("help.connect_05_title"), L("help.connect_05_content"))
        ]
    }

    private let pageVC = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
    private var controllers: [UIViewController] = []
    private let pageControl = UIPageControl()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        title = L("help.title")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L("help.done"), style: .done, target: self, action: #selector(dismissSelf))

        setupControllers()
        setupPageViewController()
        setupPageControl()
        
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
    
    private func setupControllers() {
        controllers = pages.enumerated().map { idx, item in
            let vc = CardPageViewController(titleText: item.0, bodyText: item.1, index: idx + 1, total: pages.count)
            return vc
        }
    }
    
    private func setupPageViewController() {
        addChild(pageVC)
        view.addSubview(pageVC.view)
        pageVC.didMove(toParent: self)
        pageVC.dataSource = self
        pageVC.delegate = self
        pageVC.setViewControllers([controllers.first!], direction: .forward, animated: false)
        pageVC.view.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupPageControl() {
        pageControl.numberOfPages = controllers.count
        pageControl.currentPage = 0
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControl)

        NSLayoutConstraint.activate([
            pageVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pageVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageVC.view.bottomAnchor.constraint(equalTo: pageControl.topAnchor),

            pageControl.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageControl.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }
    
    @objc override func languageDidChange() {
        title = L("help.title")
        navigationItem.rightBarButtonItem?.title = L("help.done")
        
        // 重新创建控制器以使用新的本地化文本
        setupControllers()
        pageVC.setViewControllers([controllers.first!], direction: .forward, animated: false)
        pageControl.currentPage = 0
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}

extension HelpCardsViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let idx = controllers.firstIndex(of: viewController), idx > 0 else { return nil }
        return controllers[idx - 1]
    }
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let idx = controllers.firstIndex(of: viewController), idx < controllers.count - 1 else { return nil }
        return controllers[idx + 1]
    }
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let current = pageViewController.viewControllers?.first, let idx = controllers.firstIndex(of: current) else { return }
        pageControl.currentPage = idx
    }
}
