import UIKit

class EmailEditViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Properties
    var currentEmail: String?
    var onSave: ((String) -> Void)?

    // MARK: - Scaled Metrics Helper
    // Base design width is 375pt
    private var scale: CGFloat {
        return UIScreen.main.bounds.width / 375.0
    }
    
    private func s(_ value: CGFloat) -> CGFloat {
        return value * scale
    }
    
    // MARK: - UI Elements
    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let backButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "sub_back"), for: .normal)
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("user_profile.email")
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()
    
    private let saveButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("common.save"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        return button
    }()
    
    // Separator Line
    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // #E4E4E4 = R228 G228 B228. Opacity 20%
        view.backgroundColor = UIColor(red: 228/255.0, green: 228/255.0, blue: 228/255.0, alpha: 0.2)
        return view
    }()
    
    // Input Container
    private let inputContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // Background #2C2C2C
        view.backgroundColor = UIColor(red: 44/255.0, green: 44/255.0, blue: 44/255.0, alpha: 1.0)
        return view
    }()
    
    private let emailTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textColor = .white
        textField.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        textField.borderStyle = .none
        textField.keyboardType = .emailAddress
        textField.returnKeyType = .done
        textField.autocapitalizationType = .none
        return textField
    }()
    
    private let clearButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "clean"), for: .normal)
        button.isHidden = true
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        
        if let email = currentEmail {
            emailTextField.text = email
        }
        updateClearButtonVisibility()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        emailTextField.becomeFirstResponder()
    }

    // MARK: - UI Setup
    private func setupUI() {
        // Page background #181818
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        
        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        headerView.addSubview(saveButton)
        
        view.addSubview(separatorLine)
        
        view.addSubview(inputContainer)
        inputContainer.addSubview(emailTextField)
        inputContainer.addSubview(clearButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: s(10)),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            // Back Button
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: s(18)),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: s(28)),
            backButton.heightAnchor.constraint(equalToConstant: s(28)),
            
            // Title
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            // Save Button
            saveButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: s(-18)),
            saveButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            // Separator Line
            separatorLine.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 0),
            separatorLine.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5),
            
            // Input Container
            inputContainer.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: s(27.5)),
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainer.heightAnchor.constraint(equalToConstant: s(50)),
            
            // Text Field
            emailTextField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: s(24)),
            emailTextField.topAnchor.constraint(equalTo: inputContainer.topAnchor),
            emailTextField.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor),
            emailTextField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -10),
            
            // Clear Button
            clearButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: s(-18)),
            clearButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: s(20)), 
            clearButton.heightAnchor.constraint(equalToConstant: s(20))
        ])
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(handleSave), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(handleClear), for: .touchUpInside)
        emailTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        emailTextField.delegate = self
    }
    
    // MARK: - Actions
    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func handleSave() {
        if let text = emailTextField.text {
             onSave?(text)
        }
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func handleClear() {
        emailTextField.text = ""
        updateClearButtonVisibility()
    }
    
    @objc private func textFieldDidChange() {
        updateClearButtonVisibility()
    }
    
    private func updateClearButtonVisibility() {
        let hasText = !(emailTextField.text?.isEmpty ?? true)
        clearButton.isHidden = !hasText
    }
    
    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
