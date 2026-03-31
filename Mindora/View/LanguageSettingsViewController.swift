import UIKit

class LanguageSettingsViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let backButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "sub_back"), for: .normal)
        // Increase touch area
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
            button.configuration = config
        } else {
            button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }
        button.contentHorizontalAlignment = .leading
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("settings.language_title")
        label.textColor = .white
        label.font = UIFont(name: "PingFangSC-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        return label
    }()
    
    private let headerSeparator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // #E4E4E4 -> 228/255
        view.backgroundColor = UIColor(red: 228/255, green: 228/255, blue: 228/255, alpha: 0.2)
        return view
    }()

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.rowHeight = 56 // Standard row height
        tv.showsVerticalScrollIndicator = false
        return tv
    }()
    
    // MARK: - Data
    
    private let languages: [SupportedLanguage] = [
        .chinese,           // 简体中文
        .traditionalChinese, // 繁體中文
        .english,           // English
        .indonesian,        // Bahasa Indonesia
        .korean,            // 한국어
        .japanese,          // 日本語
        .italian            // Italiano
    ]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0)
        
        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        headerView.addSubview(headerSeparator)
        view.addSubview(tableView)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(LanguageCell.self, forCellReuseIdentifier: "LanguageCell")
        
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            // Back button positioned 18pt from left (margin) - adjusting for inset
            // CSS margin-left 36px -> 18pt.
            // Button has 10pt inset. So leading anchor should be 18 - 10 = 8.
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 8),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44), 
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            // Header Separator: Full width, height 0.5
            headerSeparator.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerSeparator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerSeparator.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            headerSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 0),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }
    
    private func updateLanguage(to language: SupportedLanguage) {
        let previousLanguage = LocalizationManager.shared.currentLanguage
        if previousLanguage != language {
            LocalizationManager.shared.currentLanguage = language
            tableView.reloadData()
            
            // Post notification (Manager handles it, but we might want to refresh specific things if needed)
            // Ideally the app root needs reload.
            // For now, we update the UI checkmark.
            
            // If the app requires a restart or root change, it should be handled by an observer in SceneDelegate.
        }
    }
}

// MARK: - UITableViewDelegate & DataSource

extension LanguageSettingsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return languages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LanguageCell", for: indexPath) as! LanguageCell
        let lang = languages[indexPath.row]
        let isSelected = lang == LocalizationManager.shared.currentLanguage
        cell.configure(text: lang.nativeDisplayName, isSelected: isSelected)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let lang = languages[indexPath.row]
        updateLanguage(to: lang)
    }
}

// MARK: - LanguageCell

class LanguageCell: UITableViewCell {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        return label
    }()
    
    private let checkIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(named: "lang_check")
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()
    
    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // #E4E4E4 -> 228/255, 20% opacity
        view.backgroundColor = UIColor(red: 228/255, green: 228/255, blue: 228/255, alpha: 0.2) 
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(checkIcon)
        contentView.addSubview(separatorLine)
        
        NSLayoutConstraint.activate([
            // Left margin 18pt (36px)
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18), 
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            // Check icon also align to right with margin? Default margin + size.
            // CSS label_5: width 30px (15pt).
            // Usually right margin matches left margin roughly or follows spec. 
            // Design usually aligns right content with some margin. Let's assume 18pt right margin as well.
            checkIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            checkIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkIcon.widthAnchor.constraint(equalToConstant: 15),
            checkIcon.heightAnchor.constraint(equalToConstant: 15),
            
            // Separator: Left 18pt, Right 0 (Full width to right)
            separatorLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            separatorLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            separatorLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(text: String, isSelected: Bool) {
        titleLabel.text = text
        checkIcon.isHidden = !isSelected
    }
}
