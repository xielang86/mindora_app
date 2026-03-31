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
        
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        
        // Layout Config
        // Design: 750px width, 1624px height.
        // Logo center Y is approx 51% of screen height (809px + 18px / 1624px).
        // Best practice for launch screen is to center the main logo or visually center the content.
        
        NSLayoutConstraint.activate([
            // Logo (Primary Anchor) - Center in Screen
            // logo width 300px -> 150pt
            // logo height 36px -> 18pt
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor), // 垂直居中
            logoImageView.widthAnchor.constraint(equalToConstant: 150),
            logoImageView.heightAnchor.constraint(equalToConstant: 18),
            
            // Device Logo - Positioned relative to Logo
            // device_logo width 167px -> 83.5pt
            // device_logo height 151px -> 75.5pt
            // Gap is 38px -> 19pt
            deviceLogoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deviceLogoImageView.bottomAnchor.constraint(equalTo: logoImageView.topAnchor, constant: -19),
            deviceLogoImageView.widthAnchor.constraint(equalToConstant: 83.5),
            deviceLogoImageView.heightAnchor.constraint(equalToConstant: 75.5)
        ])
    }
    
    // MARK: - Transition
    
    func transition(to root: UIViewController, in window: UIWindow, duration: TimeInterval = 0.35) {
        // 平滑淡出 & 缩放动画
        UIView.transition(with: window, duration: duration, options: [.transitionCrossDissolve]) {
            window.rootViewController = root
        } completion: { _ in }
    }
}
