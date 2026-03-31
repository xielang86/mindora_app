//
//  RegisterP4Controller.swift
//  mindora
//
//  Created by GitHub Copilot.
//

import UIKit
import SafariServices

final class RegisterP4Controller: UIViewController {
    
    // MARK: - Design Constants
    private let designWidth: CGFloat = 750
    private let designHeight: CGFloat = 1624
    
    // MARK: - UI Components
    
    // text-wrapper_2 > text_3
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L("register.p4.title")
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        // CSS: font-size: 48px; font-family: HKGrotesk-Bold; line-height: 60px;
        label.font = UIFont(name: "HKGrotesk-Bold", size: 48) ?? UIFont.systemFont(ofSize: 48, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // text-wrapper_3 > text_4
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = L("register.p4.subtitle")
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        // CSS: font-size: 32px; font-family: HKGrotesk-Light; line-height: 42px;
        label.font = UIFont(name: "HKGrotesk-Light", size: 32) ?? UIFont.systemFont(ofSize: 32, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // image_1
    private let deviceImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "device")
        imageView.contentMode = .scaleAspectFit
        // CSS: width: 692px; height: 692px;
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // box_2 > text-wrapper_4 (Button Background)
    private let setRingButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        // CSS: border-radius: 48px;
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // box_2 > text-wrapper_4 > text_5 (Button Title)
    private let setRingLabel: UILabel = {
        let label = UILabel()
        label.text = L("register.p4.button.set_mindor")
        label.textColor = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0)
        label.textAlignment = .center
        // CSS: font-size: 36px; font-family: Kano-regular;
        label.font = UIFont(name: "Kano-regular", size: 36) ?? UIFont.systemFont(ofSize: 36, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // box_2 > text_6
    private let noMindoraLabel: UILabel = {
        let label = UILabel()
        label.text = L("register.p4.no_mindora")
        label.textColor = .white
        label.textAlignment = .center
        // CSS: font-size: 28px; font-family: Kano-regular; line-height: 60px;
        label.font = UIFont(name: "Kano-regular", size: 28) ?? UIFont.systemFont(ofSize: 28, weight: .regular)
        label.isUserInteractionEnabled = true 
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // CSS: .page { background-color: rgba(24, 24, 24, 1); }
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(deviceImageView)
        
        view.addSubview(setRingButton)
        setRingButton.addSubview(setRingLabel)
        
        view.addSubview(noMindoraLabel)
        
        setupFontsAndStyles()
        setupConstraints()
    }
    
    private func setupFontsAndStyles() {
        // 1. Title Scaling
        let titleSize = scale(48, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = titleLabel.font.withSize(titleSize)
        
        // 2. Description Scaling
        let descSize = scale(32, basedOn: view.bounds.height, designDimension: designHeight)
        descriptionLabel.font = descriptionLabel.font.withSize(descSize)
        
        // 3. Button Label Scaling
        let btnFontSize = scale(36, basedOn: view.bounds.height, designDimension: designHeight)
        setRingLabel.font = setRingLabel.font.withSize(btnFontSize)
        
        // Button Corner Radius
        let btnRadius = scale(48, basedOn: view.bounds.height, designDimension: designHeight)
        setRingButton.layer.cornerRadius = btnRadius
        
        // 4. No Mindora Label Scaling
        let noMindoraSize = scale(28, basedOn: view.bounds.height, designDimension: designHeight)
        noMindoraLabel.font = noMindoraLabel.font.withSize(noMindoraSize)
    }
    
    private func setupConstraints() {
        // Layout Approach: Relative Vertical Stacking
        
        // 1. Title
        // box_1 padding-top: 31px
        // group_1 estimated height: 40px (ignored but space exists in design logic)
        // text-wrapper_2 margin-top: 195px
        // Total Top ~= 31 + 40 + 195 = 266px. Round to 266 -> scaled.
        let titleTop = scale(266, basedOn: view.bounds.height, designDimension: designHeight)
        // Margins: left 92, right 105. Width should be constrained or centered with padding.
        // Let's use basic centering and width factor to be safe, or explicit margins.
        let titleLeading = scale(92, basedOn: view.bounds.width, designDimension: designWidth)
        let titleTrailing = scale(105, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 2. Description
        // text-wrapper_3 margin-top: 60px (from Title wrapper)
        // CSS Width: 532px.
        // CSS Height: 168px (Fixed height to prevent layout shift between languages)
        let descTop = scale(60, basedOn: view.bounds.height, designDimension: designHeight)
        let descWidth = scale(532, basedOn: view.bounds.width, designDimension: designWidth)
        let descHeight = scale(168, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 3. Image
        // Wrapper margin-top: 200px
        let imageTopGap = scale(200, basedOn: view.bounds.height, designDimension: designHeight)
        // CSS Width: 380px
        let imageWidth = scale(380, basedOn: view.bounds.width, designDimension: designWidth)
        // CSS Height: 340px
        let imageHeight = scale(340, basedOn: view.bounds.width, designDimension: designWidth)
        
        // 4. Button
        // Section margin-top: 252px
        let buttonTopGap = scale(252, basedOn: view.bounds.height, designDimension: designHeight)
        // Button Padding: Left/Right 190px each. Total Width 750. Content 750 - 380 = 370.
        // Wait, button itself IS text-wrapper_4?
        // text-wrapper_4 padding: 2px 190px 18px 190px.
        // This implies the button (text-wrapper_4) might span full width minus some outer box_2 padding?
        // box_2 padding: 102px left/right.
        // Let's look at it: Box 2 (102px pad) -> TextWrapper 4 (Button).
        // So Button Width = 750 - 102 - 102 = 546px.
        // Let's constrain Button Width to 546px.
        let buttonWidth = scale(546, basedOn: view.bounds.width, designDimension: designWidth)
        // Height estimation: Text LineHeight 60 + Top 2 + Bottom 18 = 80px? But Radius is 48, so usually >= 96.
        // Let's set height to ~96px which is common for 48px radius.
        let buttonHeight = scale(96, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 5. No Mindora
        // Margin-top: 36px (Increased from 18px for better spacing)
        let linkTopGap = scale(36, basedOn: view.bounds.height, designDimension: designHeight)
        
        
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: titleTop),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: titleLeading),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -titleTrailing),
            
            // Description
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: descTop),
            descriptionLabel.heightAnchor.constraint(equalToConstant: descHeight),
            descriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            descriptionLabel.widthAnchor.constraint(equalToConstant: descWidth),
            
            // Image
            deviceImageView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: imageTopGap),
            deviceImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deviceImageView.widthAnchor.constraint(equalToConstant: imageWidth),
            deviceImageView.heightAnchor.constraint(equalToConstant: imageHeight),
            
            setRingButton.topAnchor.constraint(equalTo: deviceImageView.bottomAnchor, constant: buttonTopGap),
            setRingButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            setRingButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            setRingButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            
            // Button Label Center
            setRingLabel.centerXAnchor.constraint(equalTo: setRingButton.centerXAnchor),
            setRingLabel.centerYAnchor.constraint(equalTo: setRingButton.centerYAnchor),
            
            // No Mindora
            noMindoraLabel.topAnchor.constraint(equalTo: setRingButton.bottomAnchor, constant: linkTopGap),
            noMindoraLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func setupActions() {
        setRingButton.addTarget(self, action: #selector(setRingTapped), for: .touchUpInside)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(noMindoraTapped))
        noMindoraLabel.addGestureRecognizer(tapGesture)
    }
    
    @objc private func setRingTapped() {
        self.setRingButton.animateButtonTap { [weak self] in
            print("Set up ring tapped")
            let nextVC = OnboardingPage2ViewController()
            self?.navigationController?.pushViewController(nextVC, animated: true)
        }
    }
    
    @objc private func noMindoraTapped() {
        self.noMindoraLabel.animateButtonTap { [weak self] in
            print("No Mindora yet tapped")
            guard let url = URL(string: Constants.Network.mindoraWebURL) else { return }
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .pageSheet
            self?.present(safariVC, animated: true)
        }
    }
    
    // MARK: - Helpers
    
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        // Simple linear scaling based on height mostly for vertical flows
        // For fonts, we usually scale based on width or height, here sticking to height for consistency with previous file (RegisterP3)
        return (designValue / designDimension) * dimension
    }
}
