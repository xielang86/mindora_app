//
//  OnboardingExitButton.swift
//  mindora
//
//  Created by GitHub Copilot on 2025/12/16.
//

import UIKit

class OnboardingExitButton: ExpandedTouchButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        // 确保交互已启用
        isUserInteractionEnabled = true
        
        // SF Symbol "xmark" - White
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "xmark", withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        setImage(image, for: .normal)
        
        imageView?.contentMode = .scaleAspectFit
        translatesAutoresizingMaskIntoConstraints = false
        
        // Touch area expansion - 增大点击热区
        touchAreaInsets = UIEdgeInsets(top: -30, left: -30, bottom: -30, right: -30)
        
        // Add target
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }
    
    @objc private func handleTap() {
        print("OnboardingExitButton tapped")
        self.animateButtonTap {
            OnboardingExitButton.completeOnboarding()
        }
    }
    
    /// 完成引导页流程，进入主应用
    static func completeOnboarding() {
        print("DEBUG: completeOnboarding called")
        
        // 标记引导页已完成 (修正 key 为 hasSeenOnboarding，与 SceneDelegate 保持一致)
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding") // 保留旧 key 以防万一
        UserDefaults.standard.synchronize()
        
        // 尝试获取 window
        var targetWindow: UIWindow?
        
        // 1. 尝试从 SceneDelegate 获取
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            print("DEBUG: Found window from SceneDelegate")
            targetWindow = window
        }
        
        // 2. 如果失败，尝试获取 keyWindow
        if targetWindow == nil {
             print("DEBUG: Trying to find keyWindow")
             targetWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })
        }
        
        // 3. 最后的尝试：获取任意一个 window
        if targetWindow == nil {
            print("DEBUG: Trying to find any window")
            targetWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first
        }
        
        guard let window = targetWindow else {
            print("ERROR: Could not find target window")
            return
        }
        
        print("DEBUG: Target window found: \(window)")
        
        // 确保在主线程执行 UI 操作
        DispatchQueue.main.async {
            // 情况1：根控制器已经是 MainTabBarController (说明引导页是模态弹出的)
            if let tabBarController = window.rootViewController as? MainTabBarController {
                print("DEBUG: Already MainTabBarController - Dismissing modals")
                
                // 确保选中第一个 tab
                tabBarController.selectedIndex = 0
                
                // 关闭所有模态弹窗 (dismiss from root will dismiss the entire stack)
                window.rootViewController?.dismiss(animated: true, completion: nil)
                return
            }
            
            // 情况2：根控制器是 StartViewController (说明是首次启动，引导页是 Root)
            print("DEBUG: Switching rootViewController to MainTabBarController")
            let mainTabBarController = MainTabBarController()
            mainTabBarController.selectedIndex = 0
            
            UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: {
                window.rootViewController = mainTabBarController
            }, completion: { completed in
                print("DEBUG: Transition completed: \(completed)")
            })
            window.makeKeyAndVisible()
        }
    }
}
