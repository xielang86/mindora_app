//
//  OnboardingExitButton.swift
//  mindora
//
//  Created by GitHub Copilot on 2025/12/16.
//

import UIKit

class OnboardingExitButton: ExpandedTouchButton {

    private static func resolveActiveWindow() -> UIWindow? {
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            return window
        }

        if let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return keyWindow
        }

        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first
    }
    
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
        
        guard let window = resolveActiveWindow() else {
            print("ERROR: Could not find target window")
            return
        }
        
        print("DEBUG: Target window found: \(window)")
        
        // 确保在主线程执行 UI 操作
        DispatchQueue.main.async {
            if let tabBarController = window.rootViewController as? MainTabBarController {
                print("DEBUG: Already MainTabBarController - Dismissing modals")
                tabBarController.selectedIndex = 0
                window.rootViewController?.dismiss(animated: true, completion: nil)
                return
            }

            // 若旧 root 上还挂着模态（fullScreen 弹出的引导页或帮助页），
            // 先把它们 dismiss 掉。注意：不要在 dismiss 的 completion 里同步换 root，
            // 那个 completion 是在 UIKit 的过渡收尾里回调的，此时换根会导致
            // 新 view 没法 attach 到 window（viewWillAppear 时 view.window == nil，
            // viewDidAppear 也不触发，表现为进不了首页）。
            // 正确做法：让出当前 runloop，等 UIKit 把模态拆除彻底结束，再换 root。
            if window.rootViewController?.presentedViewController != nil {
                window.rootViewController?.dismiss(animated: false, completion: nil)
            }

            DispatchQueue.main.async {
                print("DEBUG: Switching rootViewController to MainTabBarController directly")
                let mainTabBarController = MainTabBarController()
                mainTabBarController.selectedIndex = 0

                UIView.performWithoutAnimation {
                    window.rootViewController = mainTabBarController
                    window.makeKeyAndVisible()
                    window.layoutIfNeeded()
                }

                print("DEBUG: Transition completed via direct root swap")
            }
        }
    }
}
