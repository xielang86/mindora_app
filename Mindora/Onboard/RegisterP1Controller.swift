//
//  RegisterP1Controller.swift
//  mindora
//
//  Created by GitHub Copilot on 2026/01/21.
//

import UIKit

final class RegisterP1Controller: UIViewController {

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
    
    private let welcomeLabel: UILabel = {
        let label = UILabel()
        label.text = L("register.welcome")
        label.textColor = .white
        label.font = UIFont(name: "Kano-regular", size: 56) ?? UIFont.systemFont(ofSize: 56, weight: .bold) // Fallback
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Email Input Group
    private let emailContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.cornerRadius = 12 // scaled later
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emailIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "email")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let emailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = L("register.email_placeholder")
        // Placeholder color customization if needed
        textField.attributedPlaceholder = NSAttributedString(
            string: L("register.email_placeholder"),
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        )
        textField.textColor = .white
        textField.font = UIFont(name: "HKGrotesk-Medium", size: 28) ?? UIFont.systemFont(ofSize: 28, weight: .medium)
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let emailCheckImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "register_email_check")
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // Info Group
    private let infoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let infoIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "info") // Ensure this asset exists
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let infoTextStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10 // scaled later
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let infoLabel1: UILabel = {
        let label = UILabel()
        label.text = L("register.info.create")
        label.textColor = .white
        label.numberOfLines = 0
        label.font = UIFont(name: "HKGrotesk-Light", size: 28) ?? UIFont.systemFont(ofSize: 28, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let infoLabel2: UILabel = {
        let label = UILabel()
        label.text = L("register.info.signin")
        label.textColor = .white
        label.numberOfLines = 0
        label.font = UIFont(name: "HKGrotesk-Light", size: 28) ?? UIFont.systemFont(ofSize: 28, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let continueButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(L("register.button.continue"), for: .normal)
        button.setTitleColor(UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0), for: .normal) // Text color from CSS
        // Initial state: Disabled -> Grayish background
        button.backgroundColor = UIColor(red: 104/255, green: 102/255, blue: 102/255, alpha: 1.0)
        button.isEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        
        if let savedEmail = AuthStorage.shared.email, !savedEmail.isEmpty {
            emailTextField.text = savedEmail
            emailTextFieldChanged(emailTextField)
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Background Color #181818
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        
        view.addSubview(backgroundImageView)
        view.addSubview(welcomeLabel)
        
        view.addSubview(emailContainerView)
        emailContainerView.addSubview(emailIconImageView)
        emailContainerView.addSubview(emailTextField)
        emailContainerView.addSubview(emailCheckImageView)
        
        view.addSubview(infoContainerView)
        infoContainerView.addSubview(infoIconImageView)
        infoContainerView.addSubview(infoTextStackView)
        
        infoTextStackView.addArrangedSubview(infoLabel1)
        infoTextStackView.addArrangedSubview(infoLabel2)
        
        view.addSubview(continueButton)
        continueButton.addSubview(activityIndicator)
        
        setupFontsAndCornerRadii()
        setupConstraints()
    }
    
    private func setupFontsAndCornerRadii() {
        // Font sizes
        let welcomeSize = scale(56, basedOn: view.bounds.height, designDimension: designHeight)
        welcomeLabel.font = welcomeLabel.font.withSize(welcomeSize)
        
        let inputSize = scale(28, basedOn: view.bounds.height, designDimension: designHeight)
        emailTextField.font = emailTextField.font?.withSize(inputSize)
        
        let infoSize = scale(28, basedOn: view.bounds.height, designDimension: designHeight)
        infoLabel1.font = infoLabel1.font.withSize(infoSize)
        infoLabel2.font = infoLabel2.font.withSize(infoSize)
        
        let btnSize = scale(36, basedOn: view.bounds.height, designDimension: designHeight)
        continueButton.titleLabel?.font = UIFont(name: "Kano-regular", size: btnSize) ?? UIFont.systemFont(ofSize: btnSize)
        
        // Corner Radii
        let containerRadius = scale(24, basedOn: view.bounds.height, designDimension: designHeight)
        emailContainerView.layer.cornerRadius = containerRadius
        
        let btnRadius = scale(48, basedOn: view.bounds.height, designDimension: designHeight)
        continueButton.layer.cornerRadius = btnRadius
        
        // Spacing for stack view
        let stackSpacing = scale(36, basedOn: view.bounds.height, designDimension: designHeight)
        infoTextStackView.spacing = stackSpacing
    }
    
    private func setupConstraints() {
        // Recalculated Vertical Positions based on 750x1624 design
        
        // 1. Welcome Label
        // CSS: section_1 padding-top (31) + text_3 margin-top (218) + block_1 height (34 approx) = ~283px
        let welcomeTopMargin = scale(283, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 2. Background Image
        // Covers section_1. Height inference:
        // Top(0) -> Welcome Top(283) + Welcome Height(66) + Margin(171) + Block2 Height(120) = 640px
        let bgHeight = scale(640, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 3. Email Container
        // Gap from Welcome Bottom to Email Top
        // CSS: Welcome Bottom -> Margin(171) -> Block2(120) -> Padding(84) -> Email
        // Total Gap = 171 + 120 + 84 = 375px
        let formTopGap = scale(375, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 4. Info Group
        // CSS: Margin-top 66px
        let infoGroupTop = scale(66, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 5. Continue Button
        // CSS: Margin-top 258px
        _ = scale(258, basedOn: view.bounds.height, designDimension: designHeight)
        
        // Lateral Dimensions
        let emailContainerWidth = scale(670, basedOn: view.bounds.width, designDimension: designWidth)
        let infoWidth = scale(557, basedOn: view.bounds.width, designDimension: designWidth)
        let btnWidth = scale(546, basedOn: view.bounds.width, designDimension: designWidth)
        let btnHeight = scale(80, basedOn: view.bounds.height, designDimension: designHeight)
        
        // Inner Dimensions
        let iconSize = scale(36, basedOn: view.bounds.width, designDimension: designWidth)
        let innerPaddingV = scale(17, basedOn: view.bounds.height, designDimension: designHeight)
        let innerPaddingLeft = scale(40, basedOn: view.bounds.width, designDimension: designWidth)
        let innerPaddingRight = scale(37, basedOn: view.bounds.width, designDimension: designWidth)
        let textGap = scale(36, basedOn: view.bounds.width, designDimension: designWidth)
        let innerGap = scale(20, basedOn: view.bounds.width, designDimension: designWidth)
        let checkIconWidth = scale(29, basedOn: view.bounds.width, designDimension: designWidth)
        let checkIconHeight = scale(22, basedOn: view.bounds.height, designDimension: designHeight)
        
        // Info Group Leading Margin
        // CSS Section 2 Padding Left: 40px
        // CSS Group 2 Margin Left: 40px
        // Total Leading: 40 + 40 = 80px relative to view
        let infoLeadingMargin = scale(80, basedOn: view.bounds.width, designDimension: designWidth)
        
        NSLayoutConstraint.activate([
            // 1. Background (Top Section Only)
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.heightAnchor.constraint(equalToConstant: bgHeight),
            
            // 2. Welcome Label (Centered)
            welcomeLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: welcomeTopMargin),
            welcomeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // 3. Email Container
            emailContainerView.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: formTopGap),
            emailContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emailContainerView.widthAnchor.constraint(equalToConstant: emailContainerWidth),
            emailContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: scale(80, basedOn: view.bounds.height, designDimension: designHeight)),
            
            // Email Inner
            emailIconImageView.leadingAnchor.constraint(equalTo: emailContainerView.leadingAnchor, constant: innerPaddingLeft),
            emailIconImageView.centerYAnchor.constraint(equalTo: emailContainerView.centerYAnchor),
            emailIconImageView.widthAnchor.constraint(equalToConstant: iconSize),
            emailIconImageView.heightAnchor.constraint(equalToConstant: iconSize),
            
            // Check Icon
            emailCheckImageView.centerYAnchor.constraint(equalTo: emailContainerView.centerYAnchor),
            emailCheckImageView.trailingAnchor.constraint(equalTo: emailContainerView.trailingAnchor, constant: -innerPaddingRight),
            emailCheckImageView.widthAnchor.constraint(equalToConstant: checkIconWidth),
            emailCheckImageView.heightAnchor.constraint(equalToConstant: checkIconHeight),
            
            // TextField
            emailTextField.leadingAnchor.constraint(equalTo: emailIconImageView.trailingAnchor, constant: textGap),
            emailTextField.trailingAnchor.constraint(equalTo: emailCheckImageView.leadingAnchor, constant: -10), // Gap before check icon
            emailTextField.topAnchor.constraint(equalTo: emailContainerView.topAnchor, constant: innerPaddingV),
            emailTextField.bottomAnchor.constraint(equalTo: emailContainerView.bottomAnchor, constant: -innerPaddingV),
            emailTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: scale(44, basedOn: view.bounds.height, designDimension: designHeight)),

            // 4. Info Group
            infoContainerView.topAnchor.constraint(equalTo: emailContainerView.bottomAnchor, constant: infoGroupTop),
            infoContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: infoLeadingMargin),
            infoContainerView.widthAnchor.constraint(equalToConstant: infoWidth), // Fixed width from design
            
            infoIconImageView.topAnchor.constraint(equalTo: infoContainerView.topAnchor),
            infoIconImageView.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor),
            infoIconImageView.widthAnchor.constraint(equalToConstant: iconSize),
            infoIconImageView.heightAnchor.constraint(equalToConstant: iconSize),
            
            infoTextStackView.topAnchor.constraint(equalTo: infoContainerView.topAnchor),
            infoTextStackView.leadingAnchor.constraint(equalTo: infoIconImageView.trailingAnchor, constant: innerGap),
            infoTextStackView.trailingAnchor.constraint(equalTo: infoContainerView.trailingAnchor),
            infoTextStackView.bottomAnchor.constraint(equalTo: infoContainerView.bottomAnchor),
            
            // 5. Continue Button
            // Pinned to bottom to match design absolute layout logic (padding-bottom 205px)
            continueButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -scale(205, basedOn: view.bounds.height, designDimension: designHeight)),
            continueButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueButton.widthAnchor.constraint(equalToConstant: btnWidth),
            continueButton.heightAnchor.constraint(equalToConstant: btnHeight),
            
            activityIndicator.centerXAnchor.constraint(equalTo: continueButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: continueButton.centerYAnchor)
        ])
    }
    
    private func setupActions() {
        emailTextField.addTarget(self, action: #selector(emailTextFieldChanged), for: .editingChanged)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Actions
    
    @objc private func emailTextFieldChanged(_ textField: UITextField) {
        let email = textField.text ?? ""
        let isValid = isValidEmail(email)
        
        if continueButton.isEnabled != isValid {
            continueButton.isEnabled = isValid
            emailCheckImageView.isHidden = !isValid
            
            UIView.animate(withDuration: 0.3) {
                if isValid {
                    self.continueButton.backgroundColor = .white
                } else {
                    self.continueButton.backgroundColor = UIColor(red: 104/255, green: 102/255, blue: 102/255, alpha: 1.0)
                }
            }
        }
    }
    
    @objc private func continueButtonTapped() {
        self.continueButton.animateButtonTap { [weak self] in
            guard let self = self else { return }
            guard let email = self.emailTextField.text, self.isValidEmail(email) else { return }
            
            self.continueButton.isEnabled = false
            // 临时隐藏文字并显示 loading
            let originalTitle = self.continueButton.title(for: .normal)
            self.continueButton.setTitle("", for: .disabled)
            self.activityIndicator.startAnimating()
            
            // Debug mode: skip server verification, go directly to P2
            if Constants.Config.skipEmailVerification {
                self.continueButton.isEnabled = true
                self.continueButton.setTitle(originalTitle, for: .normal)
                self.activityIndicator.stopAnimating()
                let p2Controller = RegisterP2Controller()
                p2Controller.email = email
                self.navigationController?.pushViewController(p2Controller, animated: true)
                return
            }
            
            AuthService.shared.sendVerifyCode(email: email) { [weak self] result in
                DispatchQueue.main.async {
                    self?.continueButton.isEnabled = true
                    self?.continueButton.setTitle(originalTitle, for: .normal) // 恢复文字
                    self?.activityIndicator.stopAnimating()
                    
                    switch result {
                    case .success:
                        let p2Controller = RegisterP2Controller()
                        p2Controller.email = email
                        self?.navigationController?.pushViewController(p2Controller, animated: true)
                        
                    case .failure(let error):
                        let alert = CustomAlertViewController(
                            title: L("common.error"),
                            description: error.localizedDescription,
                            confirmButtonTitle: L("common.ok")
                        )
                        self?.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Helpers
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
}
