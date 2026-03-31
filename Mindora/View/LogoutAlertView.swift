import UIKit

// MARK: - Logout Alert View

class LogoutAlertView: UIView {
    
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
    
    // MARK: - UI Components
    
    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerRadius = 18 // 36px
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("logout.alert.title")
        label.textColor = .black
        // CSS: 36px -> 18pt, HKGrotesk-SemiBold
        label.font = UIFont(name: "HKGrotesk-SemiBold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("logout.alert.message")
        label.textColor = UIColor.black.withAlphaComponent(0.6)
        // CSS: 24px -> 12pt, HKGrotesk-Regular
        label.font = UIFont(name: "HKGrotesk-Regular", size: 12) ?? .systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("logout.alert.cancel"), for: .normal)
        button.setTitleColor(UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0), for: .normal)
        // CSS: 24px -> 12pt, Kano-regular
        button.titleLabel?.font = UIFont(name: "Kano-Regular", size: 12) ?? .systemFont(ofSize: 12, weight: .regular)
        
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0).cgColor
        button.layer.cornerRadius = 10 // 20px
        
        return button
    }()
    
    private let confirmButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("logout.alert.confirm"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        // CSS: 24px -> 12pt, Kano-regular
        button.titleLabel?.font = UIFont(name: "Kano-Regular", size: 12) ?? .systemFont(ofSize: 12, weight: .regular)
        
        button.backgroundColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0)
        button.layer.cornerRadius = 10 // 20px
        
        return button
    }()
    
    private let buttonsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 15 // Gap to fit 208pt width with buttons approx 96pt each
        stack.alignment = .fill
        return stack
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor(white: 0, alpha: 0.6)
        
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(messageLabel)
        containerView.addSubview(buttonsStackView)
        
        buttonsStackView.addArrangedSubview(cancelButton)
        buttonsStackView.addArrangedSubview(confirmButton)
        
        setupConstraints()
        
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
        
        // Tap background to dismiss (optional, but good UX)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCancel))
        // We only want to dismiss if tapping the background, not the container
        tap.delegate = self
        addGestureRecognizer(tap)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 45.5),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -45.5),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 27.5),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -27.5),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 27.5),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -27.5),
            
            buttonsStackView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 30),
            buttonsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 38),
            buttonsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -38),
            buttonsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -28),
            
            // Enforce height for buttons
            cancelButton.heightAnchor.constraint(equalToConstant: 28), // 56px
            confirmButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    @objc private func handleCancel() {
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.alpha = 0
        }) { [weak self] _ in
            self?.removeFromSuperview()
            self?.onCancel?()
        }
    }
    
    @objc private func handleConfirm() {
        onConfirm?()
    }
}

extension LogoutAlertView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view == containerView || touch.view?.isDescendant(of: containerView) == true {
             return false
        }
        return true
    }
}
