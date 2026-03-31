//
//  RegisterP2Controller.swift
//  mindora
//
//  Created by GitHub Copilot on 2026/01/21.
//

import UIKit

final class RegisterP2Controller: UIViewController {

    // MARK: - Public Properties
    var email: String = "example@example.com"

    // MARK: - Private Properties
    private var code: String = "" {
        didSet {
            updateCodeViews()
            validateCode()
            if code.count == 4 {
                continueTapped()
            }
        }
    }
    
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
        label.text = L("register.p2.title")
        label.textColor = .white
        label.font = UIFont(name: "HKGrotesk-Bold", size: 48) ?? UIFont.systemFont(ofSize: 48, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont(name: "HKGrotesk-Light", size: 32) ?? UIFont.systemFont(ofSize: 32, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Hidden text field for input handling
    private lazy var codeTextField: UITextField = {
        let tf = UITextField()
        tf.keyboardType = .numberPad
        tf.isHidden = true
        tf.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        return tf
    }()
    
    private let codeStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private var digitViews: [DigitView] = []
    
    private let resendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L("register.p2.resend"), for: .normal)
        button.setTitleColor(UIColor(red: 37/255, green: 197/255, blue: 218/255, alpha: 1.0), for: .normal)
        button.titleLabel?.font = UIFont(name: "Kano-regular", size: 28) ?? UIFont.systemFont(ofSize: 28)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let continueButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(L("register.button.continue"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 37/255, green: 197/255, blue: 218/255, alpha: 1.0)
        button.isEnabled = false
        button.alpha = 0.5 
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        updateSubtitle()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        codeTextField.becomeFirstResponder()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        
        view.addSubview(backgroundImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(codeTextField)
        view.addSubview(codeStackView)
        view.addSubview(resendButton)
        view.addSubview(continueButton)
        continueButton.addSubview(activityIndicator)
        
        setupDigitViews()
        setupFontsAndCornerRadii()
        setupConstraints()
    }
    
    private func setupDigitViews() {
        for _ in 0..<4 {
            let digitView = DigitView()
            digitView.translatesAutoresizingMaskIntoConstraints = false
            codeStackView.addArrangedSubview(digitView)
            digitViews.append(digitView)
        }
    }
    
    private func setupFontsAndCornerRadii() {
        // Fonts scaling
        let titleSize = scale(48, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = titleLabel.font.withSize(titleSize)
        
        let subtitleSize = scale(32, basedOn: view.bounds.height, designDimension: designHeight)
        subtitleLabel.font = subtitleLabel.font.withSize(subtitleSize)
        
        let resendSize = scale(28, basedOn: view.bounds.height, designDimension: designHeight)
        resendButton.titleLabel?.font = resendButton.titleLabel?.font.withSize(resendSize)
        
        let continueSize = scale(36, basedOn: view.bounds.height, designDimension: designHeight)
        continueButton.titleLabel?.font = continueButton.titleLabel?.font.withSize(continueSize)
        
        // Button Radius
        let btnRadius = scale(48, basedOn: view.bounds.height, designDimension: designHeight)
        continueButton.layer.cornerRadius = btnRadius
        
        // Digit View Scaling (Propagate to views)
        let digitSize = scale(92, basedOn: view.bounds.width, designDimension: designWidth)
        let digitFontSize = scale(32, basedOn: view.bounds.height, designDimension: designHeight)
        let digitRadius = scale(20, basedOn: view.bounds.height, designDimension: designHeight)
        // Design text font-size is 32px (height), so cursor approx 32px
        let cursorHeight = scale(32, basedOn: view.bounds.height, designDimension: designHeight)
        
        digitViews.forEach { view in
            view.updateLayout(size: digitSize, fontSize: digitFontSize, radius: digitRadius, cursorHeight: cursorHeight)
        }
        
        // Stack Spacing
        let spacing = scale(30, basedOn: view.bounds.width, designDimension: designWidth)
        codeStackView.spacing = spacing
    }
    
    private func setupConstraints() {
        // Recalculated Vertical Positions based on 750x1624 design
        
        // 1. Background
        let bgHeight = scale(640, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 2. Title Top
        // CSS: section_1 padding-top (31) + group_1 height (34) + text_3 margin-top (195) = 260px
        let titleTop = scale(260, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 3. Subtitle Margin Top
        // CSS: paragraph_1 margin-top (36)
        let subtitleTop = scale(36, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 4. Code Input Margin Top
        // CSS: group_2 margin-top (80) + box_1 top/padding (20) = 100px
        let codeInputTop = scale(100, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 5. Resend Top
        // CSS: group_2 padding-bottom (8) + block_2 padding-top (162) = 170px
        let resendTop = scale(170, basedOn: view.bounds.height, designDimension: designHeight)
        
        // 6. Continue Button Top
        // CSS: text-wrapper_2 margin-top (28)
        let continueTop = scale(28, basedOn: view.bounds.height, designDimension: designHeight)
        
        let btnWidth = scale(546, basedOn: view.bounds.width, designDimension: designWidth)
        let btnHeight = scale(96, basedOn: view.bounds.height, designDimension: designHeight)
        let digitWidth = scale(92, basedOn: view.bounds.width, designDimension: designWidth)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.heightAnchor.constraint(equalToConstant: bgHeight),
            
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: titleTop),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: subtitleTop),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            codeStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: codeInputTop),
            codeStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            codeStackView.heightAnchor.constraint(equalToConstant: digitWidth),
            
            resendButton.topAnchor.constraint(equalTo: codeStackView.bottomAnchor, constant: resendTop),
            resendButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            continueButton.topAnchor.constraint(equalTo: resendButton.bottomAnchor, constant: continueTop),
            continueButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueButton.widthAnchor.constraint(equalToConstant: btnWidth),
            continueButton.heightAnchor.constraint(equalToConstant: btnHeight),
            
            activityIndicator.centerXAnchor.constraint(equalTo: continueButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: continueButton.centerYAnchor)
        ])
        
        digitViews.forEach {
            $0.widthAnchor.constraint(equalToConstant: digitWidth).isActive = true
            $0.heightAnchor.constraint(equalToConstant: digitWidth).isActive = true
        }
    }
    
    private func setupActions() {
        resendButton.addTarget(self, action: #selector(resendTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        view.addGestureRecognizer(tap)
    }
    
    private func updateSubtitle() {
        // Message on first line, email on second line
        let message = L("register.p2.subtitle")
        let fullText = message + "\n" + email
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8 // Adjust spacing as needed
        paragraphStyle.alignment = .center
        
        let attributedString = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: subtitleLabel.font!,
                .foregroundColor: subtitleLabel.textColor!,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        subtitleLabel.attributedText = attributedString
    }
    
    // MARK: - Actions
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        guard let text = textField.text else { return }
        if text.count > 4 {
            textField.text = String(text.prefix(4))
        }
        code = textField.text ?? ""
    }
    
    @objc private func resendTapped() {
        self.resendButton.animateButtonTap { [weak self] in
            guard let self = self else { return }
            // Debug mode: skip resend
            if Constants.Config.skipEmailVerification {
                let alert = CustomAlertViewController(
                    title: L("common.notice"),
                    description: "[Debug] Skipped sending verification code",
                    confirmButtonTitle: L("common.ok")
                )
                self.present(alert, animated: true)
                return
            }
            
            AuthService.shared.sendVerifyCode(email: self.email) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        let alert = CustomAlertViewController(
                            title: L("common.notice"),
                            description: L("register.verification_code_sent"),
                            confirmButtonTitle: L("common.ok")
                        )
                        self?.present(alert, animated: true)
                        
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
    
    @objc private func continueTapped() {
        self.continueButton.animateButtonTap { [weak self] in
            guard let self = self else { return }
            guard !self.code.isEmpty else { return }
            
            self.continueButton.isEnabled = false
            // 保持透明度和背景状态，只控制内容
            let originalTitle = self.continueButton.title(for: .normal)
            self.continueButton.setTitle("", for: .disabled)
            self.activityIndicator.startAnimating()
            
            // Debug mode: skip server verification, accept any code
            if Constants.Config.skipEmailVerification {
                self.continueButton.setTitle(originalTitle, for: .normal)
                self.activityIndicator.stopAnimating()
                self.validateCode()
                // Save mock login info so the app remembers the session
                AuthStorage.shared.saveLoginInfo(
                    email: self.email,
                    uid: "debug_uid_\(Int(Date().timeIntervalSince1970))",
                    token: "debug_token",
                    expireDays: 365
                )
                let vc = RegisterP3Controller()
                self.navigationController?.pushViewController(vc, animated: true)
                return
            }
            
            AuthService.shared.loginWithCode(email: self.email, code: self.code) { [weak self] result in
                DispatchQueue.main.async {
                    self?.continueButton.setTitle(originalTitle, for: .normal)
                    self?.activityIndicator.stopAnimating()
                    self?.validateCode()
                    
                    switch result {
                    case .success:
                        let vc = RegisterP3Controller()
                        self?.navigationController?.pushViewController(vc, animated: true)
                        
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
    
    @objc private func viewTapped() {
        codeTextField.becomeFirstResponder()
    }
    
    private func updateCodeViews() {
        for (index, digitView) in digitViews.enumerated() {
            if index < code.count {
                // Filled
                let indexParams = code.index(code.startIndex, offsetBy: index)
                let char = String(code[indexParams])
                digitView.state = .filled(text: char)
            } else if index == code.count {
                // Current / Active
                digitView.state = .active
            } else {
                // Empty
                digitView.state = .empty
            }
        }
    }
    
    private func validateCode() {
        let isValid = code.count == 4
        continueButton.isEnabled = isValid
        continueButton.alpha = isValid ? 1.0 : 0.5
    }
    
    // MARK: - Helper Scale
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }
}

// MARK: - DigitView Class
private class DigitView: UIView {
    
    enum State {
        case empty
        case active
        case filled(text: String)
    }
    
    var state: State = .empty {
        didSet {
            updateApperance()
        }
    }
    
    private let label: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let borderLayer: CALayer = {
        let l = CALayer()
        l.borderWidth = 2
        l.borderColor = UIColor(red: 229/255, green: 229/255, blue: 229/255, alpha: 1.0).cgColor
        return l
    }()
    
    private let cursorView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 1/255, green: 111/255, blue: 253/255, alpha: 1.0) // #016FFD
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()
    
    private var cursorHeightConstraint: NSLayoutConstraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        layer.addSublayer(borderLayer)
        
        addSubview(label)
        addSubview(cursorView)
        
        cursorHeightConstraint = cursorView.heightAnchor.constraint(equalToConstant: 32)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Cursor positioned slightly to the left of center and height adjusted
            cursorView.trailingAnchor.constraint(equalTo: centerXAnchor, constant: -6), 
            cursorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cursorView.widthAnchor.constraint(equalToConstant: 2),
            cursorHeightConstraint!
        ])
        
        updateApperance()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        borderLayer.frame = bounds
    }
    
    func updateLayout(size: CGFloat, fontSize: CGFloat, radius: CGFloat, cursorHeight: CGFloat) {
        label.font = UIFont(name: "Helvetica-Light", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize, weight: .light)
        borderLayer.cornerRadius = radius
        cursorHeightConstraint?.constant = cursorHeight
    }
    
    private func updateApperance() {
        // Stop animation by default
        cursorView.layer.removeAllAnimations()
        cursorView.alpha = 1.0
        
        switch state {
        case .empty:
            label.text = ""
            label.isHidden = true
            cursorView.isHidden = true
            // Show default border for empty state
            borderLayer.borderColor = UIColor(red: 229/255, green: 229/255, blue: 229/255, alpha: 1.0).cgColor
            
        case .active:
            label.text = ""
            label.isHidden = true
            cursorView.isHidden = false
            // Active border color #016FFD
            borderLayer.borderColor = UIColor(red: 1/255, green: 111/255, blue: 253/255, alpha: 1.0).cgColor
            startCursorAnimation()
            
        case .filled(let text):
            label.text = text
            label.isHidden = false
            cursorView.isHidden = true
            // Filled uses default border
             borderLayer.borderColor = UIColor(red: 229/255, green: 229/255, blue: 229/255, alpha: 1.0).cgColor
        }
    }
    
    private func startCursorAnimation() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.0
        animation.duration = 0.5
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.autoreverses = true
        animation.repeatCount = .infinity
        cursorView.layer.add(animation, forKey: "cursorBlink")
    }
}
