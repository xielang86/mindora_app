import UIKit

class HealthLinkAlertView: UIView {
    
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
    
    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // block_5
    private let alertContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 18 // 36px / 2 = 18pt
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // text_31
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L("health_link.alert.title")
        label.textColor = .black
        // Font: SourceHanSansCN-Normal, 28px -> 14pt. Using PingFangSC-Regular as iOS substitute
        label.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // group_17 container logic is handled by layout constraints relative to alertContainer
    
    // text-wrapper_5 + text_32
    private let cancelButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(red: 229/255, green: 229/255, blue: 229/255, alpha: 1.0)
        button.layer.cornerRadius = 10 // 20px / 2 = 10pt
        button.setTitle(L("health_link.alert.cancel"), for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        // CSS Padding: 18px 81px 18px 83px -> 9pt 40.5pt 9pt 41.5pt
        // Height calculation: 18(top) + 36(line-height) + 18(bottom) = 72px = 36pt
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // text-wrapper_6 + text_33
    private let confirmButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .black
        button.layer.cornerRadius = 10 // 20px / 2 = 10pt
        button.setTitle(L("health_link.alert.confirm"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        // CSS Padding: 18px 81px 18px 83px -> 9pt 40.5pt 9pt 41.5pt
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(backgroundView)
        addSubview(alertContainer)
        alertContainer.addSubview(titleLabel)
        alertContainer.addSubview(cancelButton)
        alertContainer.addSubview(confirmButton)
        
        NSLayoutConstraint.activate([
            // Background
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            // Alert Container
            // Width: Dynamic based on screen width padding
            // Design: box_7 padding 107px -> 53.5pt
            alertContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 53.5),
            alertContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -53.5),
            alertContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            alertContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            // Max width constraint to prevent it from looking weird on iPads or landscape
            alertContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 340),
            
            // Title
            // Padding Top: 114px -> 57pt
            titleLabel.topAnchor.constraint(equalTo: alertContainer.topAnchor, constant: 57),
            titleLabel.centerXAnchor.constraint(equalTo: alertContainer.centerXAnchor),
            // Flex width with padding, ensuring it doesn't touch edges
            titleLabel.leadingAnchor.constraint(equalTo: alertContainer.leadingAnchor, constant: 25),
            titleLabel.trailingAnchor.constraint(equalTo: alertContainer.trailingAnchor, constant: -25),
            
            // Buttons
            // Margin Top: 70px -> 35pt
            cancelButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 35),
            confirmButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 35),
            
            // Height: 36pt (Derived from line-height 36px + padding 18px*2 = 72px)
            cancelButton.heightAnchor.constraint(equalToConstant: 36),
            confirmButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Width/Constraints
            // Group Width: 436px -> 218pt. Container Width 268pt. 
            // 268 - 218 = 50pt total horizontal padding (25pt each).
            cancelButton.leadingAnchor.constraint(equalTo: alertContainer.leadingAnchor, constant: 25),
            confirmButton.trailingAnchor.constraint(equalTo: alertContainer.trailingAnchor, constant: -25),
            
            // Padding Bottom: 46px -> 23pt
            cancelButton.bottomAnchor.constraint(equalTo: alertContainer.bottomAnchor, constant: -23),
            confirmButton.bottomAnchor.constraint(equalTo: alertContainer.bottomAnchor, constant: -23),
            
            // Minimum gap
            cancelButton.trailingAnchor.constraint(lessThanOrEqualTo: confirmButton.leadingAnchor, constant: -10),
            
            // Apply Content Insets implicitly via width constraint or min width?
            // The design has huge padding (approx 40pt each side).
            // Let's explicitly set width to respect design "visual" size if possible, 
            // or use content insets.
            // 164px (padding L+R) + text width. 
            // "取消" ~24px. Total ~188px -> 94pt.
            // 218pt available. 94pt * 2 = 188pt. 
            // Gap = 30pt.
            // So fixed width constraint ~94pt is safe for Chinese.
            // For English "Cancel" -> ~100pt. 
            // I will add a constraint for Minimum Width to match the visual look.
            cancelButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 94),
            confirmButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 94)
        ])
        
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
    }
    
    @objc private func handleCancel() {
        onCancel?()
        removeFromSuperview()
    }
    
    @objc private func handleConfirm() {
        onConfirm?()
        removeFromSuperview()
    }
    
    // MARK: - Display Helper
    static func show(in view: UIView, onConfirm: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        let alert = HealthLinkAlertView(frame: view.bounds)
        alert.onConfirm = onConfirm
        alert.onCancel = onCancel
        view.addSubview(alert)
        
        // Animation
        alert.backgroundView.alpha = 0
        alert.alertContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        alert.alertContainer.alpha = 0
        
        UIView.animate(withDuration: 0.3) {
            alert.backgroundView.alpha = 1
            alert.alertContainer.transform = .identity
            alert.alertContainer.alpha = 1
        }
    }
}
