//
//  StartViewController.swift
//  mindora
//
//  Created by GitHub Copilot on 2026/01/09.
//

import UIKit
import SafariServices

final class StartViewController: UIViewController {

    // MARK: - Design Constants
    private let designWidth: CGFloat = 750
    private let designHeight: CGFloat = 1624
    
    // MARK: - UI Components
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "boot-p1")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let taglineLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let startButton: UIButton = {
        let button = UIButton(type: .system)
        // Title set in setupButtonStyles
        button.setTitleColor(UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0), for: .normal)
        button.backgroundColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let noDeviceButton: UIButton = {
        let button = UIButton(type: .system)
        // Title set in setupButtonStyles
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .clear
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Properties
    var isReplaying = false

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startBackgroundAnimation()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(backgroundImageView)
        view.addSubview(logoImageView)
        view.addSubview(taglineLabel)
        view.addSubview(startButton)
        view.addSubview(noDeviceButton)
        
        setupTextStyle()
        setupButtonStyles()
        setupConstraints()
    }
    
    private func setupTextStyle() {
        // Tagline Style
        let fontSize = scale(56, basedOn: view.bounds.height, designDimension: designHeight)
        let lineHeight = scale(66, basedOn: view.bounds.height, designDimension: designHeight)
        
        let text = L("login_start.tagline")
        let attributedString = NSMutableAttributedString(string: text)
        
        let font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.count))
        
        let paragraphStyle = NSMutableParagraphStyle()
        let lineSpacing = lineHeight - fontSize
        paragraphStyle.lineSpacing = max(0, lineSpacing)
        paragraphStyle.alignment = .left
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: text.count))
        
        attributedString.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(location: 0, length: text.count))
        
        taglineLabel.attributedText = attributedString
    }
    
    private func setupButtonStyles() {
        // Start Button Style
        let startFontSize = scale(36, basedOn: view.bounds.height, designDimension: designHeight)
        startButton.setTitle(L("login_start.button.start"), for: .normal)
        startButton.titleLabel?.font = UIFont.systemFont(ofSize: startFontSize, weight: .regular)
        
        let startCornerRadius = scale(48, basedOn: view.bounds.height, designDimension: designHeight)
        startButton.layer.cornerRadius = startCornerRadius
        
        // No Device Button Style
        let noDeviceFontSize = scale(28, basedOn: view.bounds.height, designDimension: designHeight)
        noDeviceButton.setTitle(L("login_start.button.no_device"), for: .normal)
        noDeviceButton.titleLabel?.font = UIFont.systemFont(ofSize: noDeviceFontSize, weight: .regular)
    }
    
    private func setupConstraints() {
        // CSS Margins converted to top-down flow approximations for AutoLayout
        
        // Logo Top: 260px from top
        let logoTopMargin = scale(260, basedOn: view.bounds.height, designDimension: designHeight)
        
        // Content Left: 60px
        let contentLeadingMargin = scale(60, basedOn: view.bounds.width, designDimension: designWidth)
        
        // Logo Size: 288x34
        let logoWidth = scale(288, basedOn: view.bounds.width, designDimension: designWidth)
        let logoHeight = scale(34, basedOn: view.bounds.height, designDimension: designHeight)
        
        // Tagline Top: 120px from Logo Bottom
        let taglineTopMargin = scale(120, basedOn: view.bounds.height, designDimension: designHeight)
        let taglineWidth = scale(438, basedOn: view.bounds.width, designDimension: designWidth)
        
        // Start Button Top: 728px from Tagline Bottom (based on CSS previous sibling margin)
        let startButtonTopMargin = scale(728, basedOn: view.bounds.height, designDimension: designHeight)
        let startButtonHeight = scale(80, basedOn: view.bounds.height, designDimension: designHeight)
        
        // Start Button Side Margins: 185px each side
        let startButtonSideMargin = scale(185, basedOn: view.bounds.width, designDimension: designWidth)
        
        // No Device Top: 18px from Start Button Bottom
        let noDeviceTopMargin = scale(18, basedOn: view.bounds.height, designDimension: designHeight)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            logoImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: logoTopMargin),
            logoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: contentLeadingMargin),
            logoImageView.widthAnchor.constraint(equalToConstant: logoWidth),
            logoImageView.heightAnchor.constraint(equalToConstant: logoHeight),
            
            taglineLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: taglineTopMargin),
            taglineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: contentLeadingMargin),
            taglineLabel.widthAnchor.constraint(equalToConstant: taglineWidth),
            
            startButton.topAnchor.constraint(equalTo: taglineLabel.bottomAnchor, constant: startButtonTopMargin),
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: startButtonSideMargin),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -startButtonSideMargin),
            startButton.heightAnchor.constraint(equalToConstant: startButtonHeight),
            
            noDeviceButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: noDeviceTopMargin),
            noDeviceButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func setupActions() {
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        noDeviceButton.addTarget(self, action: #selector(noDeviceButtonTapped), for: .touchUpInside)
    }

    private func startBackgroundAnimation() {
        backgroundImageView.layer.removeAllAnimations()
        backgroundImageView.transform = .identity
        
        // Sequence: Breathing first, then Moving
        UIView.animateKeyframes(withDuration: 20.0, delay: 0, options: [.repeat, .calculationModeCubic], animations: {
            // 1. Breathing In (Scale Up)
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.25) {
                self.backgroundImageView.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
            }
            // 2. Breathing Out (Scale Down)
            UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.25) {
                self.backgroundImageView.transform = .identity
            }
            // 3. Move Up
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.25) {
                self.backgroundImageView.transform = CGAffineTransform(translationX: 0, y: -50)
            }
            // 4. Move Down (Back to Origin)
            UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) {
                self.backgroundImageView.transform = .identity
            }
        }, completion: nil)
    }
    
    // MARK: - Helpers
    
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
    
    // MARK: - Actions
    
    @objc private func startTapped() {
        self.startButton.animateButtonTap { [weak self] in
            guard let self = self else { return }
            
            // Check auth storage which prioritizes keychain + expiration check
            let isLoggedIn = AuthStorage.shared.isLoggedIn
            if isLoggedIn {
                 UserDefaults.standard.set(true, forKey: "isLoggedIn")
            }
            let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            
            if !isLoggedIn {
                // 没有注册 -> RegisterP1Controller
                let registerP1VC = RegisterP1Controller()
                self.navigationController?.pushViewController(registerP1VC, animated: true)
            } else if !hasSeenOnboarding || self.isReplaying {
                // 如果没有引导 或者 正在重播 -> OnboardingPage2ViewController
                let onboardingVC = OnboardingPage2ViewController()
                if let navigationController = self.navigationController {
                    navigationController.pushViewController(onboardingVC, animated: true)
                } else {
                    onboardingVC.modalPresentationStyle = .fullScreen
                    self.present(onboardingVC, animated: true)
                }
            } else {
                // 否则（已登录且已引导） -> 首页
                guard let window = self.view.window else { return }
                let mainVC = MainTabBarController()
                UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: {
                    window.rootViewController = mainVC
                }, completion: nil)
            }
        }
    }
    
    @objc private func noDeviceButtonTapped() {
        self.noDeviceButton.animateButtonTap { [weak self] in
            guard let self = self else { return }
            guard let url = URL(string: Constants.Network.mindoraWebURL) else { return }
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .pageSheet
            self.present(safariVC, animated: true)
        }
    }
}


