import UIKit

class BirthdayEditViewController: UIViewController {

    // MARK: - Properties
    var currentBirthday: String?
    var onSave: ((String) -> Void)?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
    
    // MARK: - Scaled Metrics Helper
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
        label.text = L("user_profile.birthday")
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
    
    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 228/255.0, green: 228/255.0, blue: 228/255.0, alpha: 0.2)
        return view
    }()
    
    // Display Container
    private let displayContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 44/255.0, green: 44/255.0, blue: 44/255.0, alpha: 1.0)
        return view
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("user_profile.label_date")
        label.textColor = .white
        label.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        return label
    }()
    
    private let dateValueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor(white: 1.0, alpha: 0.6) // Slightly dimmed or main white? Design shows lighter.
        // Actually, looking at image, it seems white or very light gray.
        label.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        label.textAlignment = .right
        return label
    }()
    
    private let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        // Force dark mode appearance for the picking wheels
        picker.overrideUserInterfaceStyle = .dark
        // Limit max date to today? Usually birthdays are in the past.
        picker.maximumDate = Date()
        return picker
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        setupInitialDate()
    }
    
    // MARK: - Logic
    private func setupInitialDate() {
        if let dateString = currentBirthday, let date = dateFormatter.date(from: dateString) {
            datePicker.date = date
            dateValueLabel.text = dateString
        } else {
             // Default to standard picker date if empty (today)
             // Or maybe a reasonable default like 1990?
             // Image shows 1998.
             dateValueLabel.text = dateFormatter.string(from: datePicker.date)
        }
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        
        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        headerView.addSubview(saveButton)
        
        view.addSubview(separatorLine)
        
        view.addSubview(displayContainer)
        displayContainer.addSubview(dateLabel)
        displayContainer.addSubview(dateValueLabel)
        
        view.addSubview(datePicker)
        
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
            
            // Display Container
            displayContainer.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: s(27.5)),
            displayContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            displayContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            displayContainer.heightAnchor.constraint(equalToConstant: s(50)),
            
            // Date Picker
            // Image shows it at the bottom.
            datePicker.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: s(-20)),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Labels in Display Container
            dateLabel.leadingAnchor.constraint(equalTo: displayContainer.leadingAnchor, constant: s(24)),
            dateLabel.centerYAnchor.constraint(equalTo: displayContainer.centerYAnchor),
            
            dateValueLabel.trailingAnchor.constraint(equalTo: displayContainer.trailingAnchor, constant: s(-24)),
            dateValueLabel.centerYAnchor.constraint(equalTo: displayContainer.centerYAnchor)
        ])
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(handleSave), for: .touchUpInside)
        datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
    }
    
    // MARK: - Actions
    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func handleSave() {
        // Return formatting string
        let result = dateFormatter.string(from: datePicker.date)
        onSave?(result)
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func dateChanged(_ sender: UIDatePicker) {
        dateValueLabel.text = dateFormatter.string(from: sender.date)
    }
}
