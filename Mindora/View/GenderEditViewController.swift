import UIKit

class GenderEditViewController: UIViewController {

    var onSelectGender: ((String) -> Void)?
    
    // MARK: - Scaled Metrics Helper
    private var scale: CGFloat {
        return UIScreen.main.bounds.width / 375.0
    }
    
    private func s(_ value: CGFloat) -> CGFloat {
        return value * scale
    }
    
    // MARK: - UI Elements
    private let overlayView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        return view
    }()
    
    private let optionsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 34/255.0, green: 34/255.0, blue: 34/255.0, alpha: 1.0)
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        return view
    }()
    
    private let maleButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("user_profile.gender.male"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 18) ?? .systemFont(ofSize: 18)
        return button
    }()
    
    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.white.withAlphaComponent(0.1) // Subtle separator
        return view
    }()
    
    private let femaleButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("user_profile.gender.female"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 18) ?? .systemFont(ofSize: 18)
        return button
    }()
    
    private let cancelContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 44/255.0, green: 43/255.0, blue: 45/255.0, alpha: 1.0)
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        return view
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("common.cancel"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 18) ?? .systemFont(ofSize: 18, weight: .medium)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        view.addSubview(overlayView)
        view.addSubview(cancelContainer)
        view.addSubview(optionsContainer)
        
        // Add buttons to options container
        optionsContainer.addSubview(maleButton)
        optionsContainer.addSubview(separatorLine)
        optionsContainer.addSubview(femaleButton)
        
        // Add button to cancel container
        cancelContainer.addSubview(cancelButton)
        
        // Layout
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Cancel Container (Bottom)
            cancelContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: s(16)),
            cancelContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: s(-16)),
            cancelContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: s(-10)),
            cancelContainer.heightAnchor.constraint(equalToConstant: s(57)),
            
            cancelButton.centerXAnchor.constraint(equalTo: cancelContainer.centerXAnchor),
            cancelButton.centerYAnchor.constraint(equalTo: cancelContainer.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalTo: cancelContainer.widthAnchor),
            cancelButton.heightAnchor.constraint(equalTo: cancelContainer.heightAnchor),
            
            // Options Container (Above Cancel)
            optionsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: s(16)),
            optionsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: s(-16)),
            optionsContainer.bottomAnchor.constraint(equalTo: cancelContainer.topAnchor, constant: s(-10)),
            optionsContainer.heightAnchor.constraint(equalToConstant: s(114)), // 2 * 57
            
            // Male Button (Top half)
            maleButton.topAnchor.constraint(equalTo: optionsContainer.topAnchor),
            maleButton.leadingAnchor.constraint(equalTo: optionsContainer.leadingAnchor),
            maleButton.trailingAnchor.constraint(equalTo: optionsContainer.trailingAnchor),
            maleButton.heightAnchor.constraint(equalToConstant: s(57)),
            
            // Separator
            separatorLine.leadingAnchor.constraint(equalTo: optionsContainer.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: optionsContainer.trailingAnchor),
            separatorLine.centerYAnchor.constraint(equalTo: optionsContainer.centerYAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5),
            
            // Female Button (Bottom half)
            femaleButton.topAnchor.constraint(equalTo: separatorLine.bottomAnchor),
            femaleButton.leadingAnchor.constraint(equalTo: optionsContainer.leadingAnchor),
            femaleButton.trailingAnchor.constraint(equalTo: optionsContainer.trailingAnchor),
            femaleButton.bottomAnchor.constraint(equalTo: optionsContainer.bottomAnchor)
        ])
    }
    
    private func setupActions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        overlayView.isUserInteractionEnabled = true
        overlayView.addGestureRecognizer(tapGesture)
        
        cancelButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        maleButton.addTarget(self, action: #selector(maleSelected), for: .touchUpInside)
        femaleButton.addTarget(self, action: #selector(femaleSelected), for: .touchUpInside)
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func maleSelected() {
        onSelectGender?(L("user_profile.gender.male"))
        dismissSelf()
    }
    
    @objc private func femaleSelected() {
        onSelectGender?(L("user_profile.gender.female"))
        dismissSelf()
    }
}
