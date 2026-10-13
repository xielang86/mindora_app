//
//  LaunchScreenViewController.swift
//  mindora
//
//  Created by gao chao on 2025/1/20.
//

import UIKit

class LaunchScreenViewController: UIViewController {
    
    private let deviceLogoImageView = UIImageView()
    private let logoImageView = UIImageView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置背景颜色 (rgba(24, 24, 24, 1) -> #181818)
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1)
        
        setupUI()
    }
    
    private func setupUI() {
        // Build view hierarchy
        view.addSubview(deviceLogoImageView)
        view.addSubview(logoImageView)
        
        deviceLogoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure images
        deviceLogoImageView.image = UIImage(named: "device_logo")
        deviceLogoImageView.contentMode = .scaleAspectFit
        
        logoImageView.image = UIImage(named: "logo_dream")
        logoImageView.contentMode = .scaleAspectFit
        
        // Layout Config
        // Design: 750px width, 1624px height.
        // Logo center Y is approx 51% of screen height (809px + 18px / 1624px).
        // Best practice for launch screen is to center the main logo or visually center the content.
        
        NSLayoutConstraint.activate([
            // Logo (Primary Anchor) - Center in Screen
            // logo width 344px -> 172pt
            // logo height 24.7px -> 12.4pt
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor), // 垂直居中
            logoImageView.widthAnchor.constraint(equalToConstant: 172),
            logoImageView.heightAnchor.constraint(equalToConstant: 12.4),
            
            // Device Logo - Positioned relative to Logo
            // 按设计图与 MINDORA DREAM 字标的比例：73 x 66.5pt，间距 19.5pt
            deviceLogoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deviceLogoImageView.bottomAnchor.constraint(equalTo: logoImageView.topAnchor, constant: -19.5),
            deviceLogoImageView.widthAnchor.constraint(equalToConstant: 73),
            deviceLogoImageView.heightAnchor.constraint(equalToConstant: 66.5)
        ])
    }
    
    // MARK: - Transition
    
    func transition(to root: UIViewController, in window: UIWindow, duration: TimeInterval = 0.35) {
        // 直接替换 rootViewController，不做窗口级动画。
        window.rootViewController = root
        window.makeKeyAndVisible()

        // 强制一次布局，避免某些情况下 window 不刷新
        window.setNeedsLayout()
        window.layoutIfNeeded()

        let rootView = root.view
        Log.info("LaunchTransition", "done root=\(type(of: root)) rootViewFrame=\(rootView?.frame ?? .zero) windowFrame=\(window.frame) windowHidden=\(window.isHidden) windowAlpha=\(window.alpha) isKey=\(window.isKeyWindow)")
    }
}
