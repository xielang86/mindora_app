//
//  HelpManualPagesViewController.swift
//  mindora
//
//  Created by gao chao on 2025/10/22.
//  Refactored by Copilot on 2025/10/23.
//
//  用户手册容器 - 使用统一的页面控制器，提供丝滑的切换体验
//  支持左右滑动切换页面，内容采用淡入淡出动画
//

import UIKit

final class HelpManualPagesViewController: UIViewController {
    
    // MARK: - Properties
    
    private lazy var unifiedViewController: HelpManualUnifiedViewController = {
        let vc = HelpManualUnifiedViewController()
        vc.delegate = self
        return vc
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUnifiedViewController()
        
        print("HelpManualPagesViewController loaded with unified view")
    }
    
    // MARK: - Setup
    
    private func setupUnifiedViewController() {
        // 添加统一的视图控制器
        addChild(unifiedViewController)
        view.addSubview(unifiedViewController.view)
        unifiedViewController.view.frame = view.bounds
        unifiedViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            unifiedViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            unifiedViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            unifiedViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            unifiedViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        unifiedViewController.didMove(toParent: self)
    }
    
    // MARK: - Public Methods
    
    /// 跳转到指定页面
    func moveToPage(at index: Int, animated: Bool = true) {
        unifiedViewController.moveToPage(index, animated: animated)
    }
    
    /// 获取当前页面索引
    func getCurrentPageIndex() -> Int {
        return unifiedViewController.getCurrentPageIndex()
    }
}

// MARK: - HelpManualUnifiedViewControllerDelegate

extension HelpManualPagesViewController: HelpManualUnifiedViewControllerDelegate {
    func helpManualDidTapConnect(_ controller: HelpManualUnifiedViewController) {
        print("🟢 HelpManualPagesViewController: helpManualDidTapConnect 被调用")
        // 关闭手册，跳转到连接页面
        dismiss(animated: true) {
            print("🟢 手册已关闭，发送导航通知")
            // 通知外部需要跳转到连接页面
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToConnect"), object: nil)
        }
    }
}
