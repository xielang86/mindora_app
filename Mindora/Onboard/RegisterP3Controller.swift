//
//  RegisterP3Controller.swift
//  mindora
//
//  Created by GitHub Copilot on 2026/01/21.
//

import UIKit
import SafariServices

final class RegisterP3Controller: UIViewController, UITextViewDelegate {

    // MARK: - Design Constants
    private let designWidth: CGFloat = 750
    private let designHeight: CGFloat = 1624
    
    // MARK: - UI Components
    
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "register_bg")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L("register.p3.title")
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont(name: "HKGrotesk-Bold", size: 48) ?? UIFont.systemFont(ofSize: 48, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("register.p3.subtitle")
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .left
        label.font = UIFont(name: "HKGrotesk-Light", size: 40) ?? UIFont.systemFont(ofSize: 40, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Row 1: Terms
    private let termsSwitch: UISwitch = {
        let s = UISwitch()
        s.onTintColor = UIColor(red: 37/255, green: 197/255, blue: 218/255, alpha: 1.0)
        s.translatesAutoresizingMaskIntoConstraints = false
        // Scale transform will be applied in layout
        return s
    }()
    
    private lazy var termsTextView: UITextView = {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = self
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    // Row 2: Marketing
    private let marketingSwitch: UISwitch = {
        let s = UISwitch()
        s.onTintColor = UIColor(red: 37/255, green: 197/255, blue: 218/255, alpha: 1.0)
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    
    private let marketingLabel: UILabel = {
        let label = UILabel()
        label.text = L("register.p3.marketing")
        label.textColor = .white
        label.numberOfLines = 0
        label.font = UIFont(name: "HKGrotesk-Light", size: 32) ?? UIFont.systemFont(ofSize: 32, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let continueButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(L("register.p3.button.save"), for: .normal)
        button.setTitleColor(UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0), for: .normal)
        button.backgroundColor = .white
        button.isEnabled = false
        button.alpha = 0.5
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        
        view.addSubview(backgroundImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        
        view.addSubview(termsSwitch)
        view.addSubview(termsTextView)
        
        view.addSubview(marketingSwitch)
        view.addSubview(marketingLabel)
        
        view.addSubview(continueButton)
        
        setupFontsAndStyles()
        setupConstraints()
    }
    
    private func setupFontsAndStyles() {
        // Title Scaling
        let titleSize = scale(48, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = titleLabel.font.withSize(titleSize)
        
        // Subtitle Scaling
        let subtitleSize = scale(40, basedOn: view.bounds.height, designDimension: designHeight)
        subtitleLabel.font = subtitleLabel.font.withSize(subtitleSize)
        
        // Terms Text Styling
        let termsFontSize = scale(32, basedOn: view.bounds.height, designDimension: designHeight)
        let termsFont = UIFont(name: "HKGrotesk-Light", size: termsFontSize) ?? UIFont.systemFont(ofSize: termsFontSize, weight: .light)
        
        let prefix = L("register.p3.agree_prefix")
        let terms = L("register.p3.terms")
        let middle = L("register.p3.and")
        let privacy = L("register.p3.privacy")
        
        let fullString = prefix + terms + middle + privacy
        let attributedString = NSMutableAttributedString(string: fullString)
        
        // Base Attributes
        attributedString.addAttribute(.font, value: termsFont, range: NSRange(location: 0, length: fullString.count))
        attributedString.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(location: 0, length: fullString.count))
        
        // Links
        let linkColor = UIColor(red: 37/255, green: 197/255, blue: 218/255, alpha: 1.0)
        
        // Terms Range
        if let termsRange = fullString.range(of: terms) {
            let nsRange = NSRange(termsRange, in: fullString)
            attributedString.addAttribute(.foregroundColor, value: linkColor, range: nsRange)
            // Add custom link attribute or use NSLinkAttributeName with custom scheme
            attributedString.addAttribute(.link, value: Constants.Network.termsOfUseURL, range: nsRange)
        }
        
        // Privacy Range
        if let privacyRange = fullString.range(of: privacy) {
            let nsRange = NSRange(privacyRange, in: fullString)
            attributedString.addAttribute(.foregroundColor, value: linkColor, range: nsRange)
            attributedString.addAttribute(.link, value: Constants.Network.privacyPolicyURL, range: nsRange)
        }
        
        // Line Height / Paragraph Style
        let paragraphStyle = NSMutableParagraphStyle()
        let lineHeight = scale(42, basedOn: view.bounds.height, designDimension: designHeight)
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: fullString.count))
        
        termsTextView.attributedText = attributedString
        termsTextView.linkTextAttributes = [
            .foregroundColor: linkColor
        ]
        
        // Marketing Label
        let marketingFontSize = scale(32, basedOn: view.bounds.height, designDimension: designHeight)
        marketingLabel.font = marketingLabel.font.withSize(marketingFontSize)
        
        // Button
        let btnFontSize = scale(36, basedOn: view.bounds.height, designDimension: designHeight)
        continueButton.titleLabel?.font = UIFont(name: "Kano-regular", size: btnFontSize) ?? UIFont.systemFont(ofSize: btnFontSize)
        
        let btnRadius = scale(48, basedOn: view.bounds.height, designDimension: designHeight)
        continueButton.layer.cornerRadius = btnRadius
        
        // Scale Switches slightly to match "66px" (33pt) vs standard 51pt
        // 33/51 ~= 0.65.
        // But switches are fixed size interactions area. I will leave standard or scale down a bit.
        // Actually, let's keep it standard for usability unless it looks huge.
        // I'll apply a transform to scale it to ~0.7
        let switchScale: CGFloat = 0.8
        termsSwitch.transform = CGAffineTransform(scaleX: switchScale, y: switchScale)
        marketingSwitch.transform = CGAffineTransform(scaleX: switchScale, y: switchScale)
    }
    
    private func setupConstraints() {
        // Design Values from CSS (Absolute Positioning Strategy)
        // Design Resolution: 750 x 1624
        
        // 1. Background Image (Top Section Only)
        // Height from P2 logic or similar design element: 640px
        let bgHeight = scale(640, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 2. Title
        // Top: 260px
        let titleTop = scale(260, basedOn: view.bounds.height, designDimension: designHeight)
        let titleWidth = scale(540, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 3. Subtitle
        // Top: 560px
        let subtitleTop = scale(560, basedOn: view.bounds.height, designDimension: designHeight)
        let subtitleLeading = scale(56, basedOn: view.bounds.width, designDimension: designWidth)
        let subtitleWidth = scale(532, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 4. Terms Row
        // Top: 748px
        let termsTop = scale(748, basedOn: view.bounds.height, designDimension: designHeight)
        let contentLeading = scale(56, basedOn: view.bounds.width, designDimension: designWidth)
        
        // Switch / Text Components
        let switchTextGap = scale(36, basedOn: view.bounds.width, designDimension: designWidth)
        let termsTextWidth = scale(495, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 5. Marketing Row
        // Top: 954px
        let marketingTop = scale(954, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 6. Button
        // Top: 1344px
        let buttonTop = scale(1344, basedOn: view.bounds.height, designDimension: designHeight)
        let buttonWidth = scale(540, basedOn: view.bounds.width, designDimension: designWidth)
        let buttonHeight = scale(96, basedOn: view.bounds.height, designDimension: designHeight)

        NSLayoutConstraint.activate([
            // Background - Top Aligned, Fixed Height
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.heightAnchor.constraint(equalToConstant: bgHeight),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: titleTop),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: titleWidth),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: subtitleTop),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: subtitleLeading),
            subtitleLabel.widthAnchor.constraint(equalToConstant: subtitleWidth),
            
            // Terms Row
            termsSwitch.topAnchor.constraint(equalTo: view.topAnchor, constant: termsTop),
            termsSwitch.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: contentLeading),
            
            termsTextView.topAnchor.constraint(equalTo: termsSwitch.topAnchor, constant: -5),
            termsTextView.leadingAnchor.constraint(equalTo: termsSwitch.trailingAnchor, constant: switchTextGap),
            termsTextView.widthAnchor.constraint(equalToConstant: termsTextWidth),
            termsTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: scale(120, basedOn: view.bounds.height, designDimension: designHeight)),
            
            // Marketing Row
            marketingSwitch.topAnchor.constraint(equalTo: view.topAnchor, constant: marketingTop),
            marketingSwitch.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: contentLeading),
            
            marketingLabel.topAnchor.constraint(equalTo: marketingSwitch.topAnchor),
            marketingLabel.leadingAnchor.constraint(equalTo: marketingSwitch.trailingAnchor, constant: switchTextGap),
            marketingLabel.widthAnchor.constraint(equalToConstant: termsTextWidth),
            
            // Continue Button
            continueButton.topAnchor.constraint(equalTo: view.topAnchor, constant: buttonTop),
            continueButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            continueButton.heightAnchor.constraint(equalToConstant: buttonHeight)
        ])
    }
    
    private func setupActions() {
        termsSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
    }
    
    @objc private func switchValueChanged() {
        continueButton.isEnabled = termsSwitch.isOn
        continueButton.alpha = termsSwitch.isOn ? 1.0 : 0.5
    }
    
    @objc private func continueTapped() {
        self.continueButton.animateButtonTap { [weak self] in
            // Proceed to next screen (Home/Tab Bar Controller)
            // For now, maybe dismiss or navigate to main app.
            // Usually sets root view controller to Main TabBar.
            if let _ = self?.view.window?.windowScene?.delegate as? SceneDelegate {
               // sceneDelegate.switchToMain() // Assuming such method exists
            }
            print("Continue tapped - Terms Accepted: \(self?.termsSwitch.isOn ?? false), Marketing: \(self?.marketingSwitch.isOn ?? false)")
            
            let vc = RegisterP4Controller()
            self?.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    // MARK: - UITextViewDelegate
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        let safariVC = SFSafariViewController(url: URL)
        present(safariVC, animated: true)
        return false // Don't let system handle it, we handled it
    }
    
    // MARK: - Helpers
    
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
}
