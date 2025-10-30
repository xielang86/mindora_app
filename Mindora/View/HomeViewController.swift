import UIKit

final class HomeViewController: UIViewController {
    // 背景图片视图
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(named: "boot-p2")
        imageView.clipsToBounds = true
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // 隐藏导航栏
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 确保导航栏隐藏
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 检查蓝牙权限并显示提醒（如果需要）
        checkBluetoothPermissionAndShowReminder()
    }
    
    private func setupUI() {
        // 设置视图背景为透明，让背景图可以穿透到 TabBar 层
        view.backgroundColor = .clear
        
        // 添加背景图片
        view.addSubview(backgroundImageView)
        
        // 设置约束，让背景图片填满整个视图
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Permission Check
    
    /// 检查蓝牙权限并显示提醒（如果需要）
    private func checkBluetoothPermissionAndShowReminder() {
        // 检查是否应该显示提醒
        guard PermissionManager.shared.shouldShowBluetoothReminder() else {
            return
        }
        
        // 延迟显示，避免与页面加载动画冲突
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            PermissionManager.shared.showBluetoothPermissionReminder(from: self)
        }
    }
}
