import UIKit

struct AddrModel: Codable {
    var id: String
    var isDefault: Bool
    var region: String
    var detail: String
    var name: String
    var phone: String
}

class AddressListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Properties
    private var addresses: [AddrModel] = []
    
    // Keys for persistence
    private let kAddressStorageKey = "MindoraSavedAddresses"
    private let kMockDataInitializedKey = "MindoraMockAddressInitialized"

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
        // Matches NicknameEditViewController background implicitly or usually transparent on top of main bg
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
        label.text = L("address.title")
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()
    
    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 228/255.0, green: 228/255.0, blue: 228/255.0, alpha: 0.2)
        return view
    }()
    
    // Empty State View
    private let emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let emptyImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(named: "address")
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("address.empty")
        label.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        label.textColor = UIColor(white: 1, alpha: 0.6)
        label.textAlignment = .center
        return label
    }()
    
    // List View
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.isHidden = true
        return tv
    }()
    
    private let addButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("address.add_new"), for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .white
        button.layer.cornerRadius = 25 // Height 50 -> Radius 25
        button.clipsToBounds = true
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        loadData()
    }
    
    private func loadData() {
        let isInitialized = UserDefaults.standard.bool(forKey: kMockDataInitializedKey)
        
        if !isInitialized {
            // First time: Create Mock Data
            #if DEBUG
            addresses = [
                AddrModel(id: "1", isDefault: true, region: "上海市 普陀区", detail: "中海中心A座1501室", name: "Mindora", phone: "13866666678"),
                AddrModel(id: "2", isDefault: false, region: "上海市 普陀区", detail: "中海中心A座1501室", name: "Mindora", phone: "13866666678")
            ]
            saveToDisk()
            #endif
            UserDefaults.standard.set(true, forKey: kMockDataInitializedKey)
        } else {
            // Subsequent times: Load from disk
            if let data = UserDefaults.standard.data(forKey: kAddressStorageKey),
               let saved = try? JSONDecoder().decode([AddrModel].self, from: data) {
                addresses = saved
            } else {
                addresses = []
            }
        }
        
        updateState()
    }
    
    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(addresses) {
            UserDefaults.standard.set(data, forKey: kAddressStorageKey)
        }
    }
    
    private func updateState() {
        if addresses.isEmpty {
            emptyStateView.isHidden = false
            tableView.isHidden = true
            emptyLabel.text = L("address.empty")
        } else {
            emptyStateView.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        
        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        view.addSubview(separatorLine)
        
        view.addSubview(emptyStateView)
        emptyStateView.addSubview(emptyImageView)
        emptyStateView.addSubview(emptyLabel)
        
        view.addSubview(tableView)
        view.addSubview(addButton)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AddressListCell.self, forCellReuseIdentifier: "AddressListCell")
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            // Header matches NicknameEditVC
            headerView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: s(10)),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: s(18)),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: s(28)),
            backButton.heightAnchor.constraint(equalToConstant: s(28)),
            
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            separatorLine.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5),
            
            // Empty State
            emptyStateView.topAnchor.constraint(equalTo: separatorLine.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: addButton.topAnchor),
            
            emptyImageView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyImageView.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor, constant: -s(40)), // Slight offset up
            emptyImageView.widthAnchor.constraint(equalToConstant: s(64)), // Estimated size
            emptyImageView.heightAnchor.constraint(equalToConstant: s(80)),
            
            emptyLabel.topAnchor.constraint(equalTo: emptyImageView.bottomAnchor, constant: s(20)),
            emptyLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            
            // TableView
            tableView.topAnchor.constraint(equalTo: separatorLine.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -s(20)),
            
            // Add Button
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: s(32)),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -s(32)),
            addButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -s(34)),
            addButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        addButton.addTarget(self, action: #selector(handleAdd), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func handleAdd() {
        let vc = AddressAddEditViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.onSave = { [weak self] newAddress in
            self?.saveAddress(newAddress)
        }
        present(vc, animated: true, completion: nil)
    }
    
    @objc func handleEdit(_ sender: UIButton) {
        let point = sender.convert(CGPoint.zero, to: tableView)
        if let indexPath = tableView.indexPathForRow(at: point) {
            let model = addresses[indexPath.row]
            let vc = AddressAddEditViewController()
            vc.existingAddress = model
            vc.modalPresentationStyle = .fullScreen
            vc.onSave = { [weak self] updatedAddress in
                self?.saveAddress(updatedAddress)
            }
            present(vc, animated: true)
        }
    }
    
    private func saveAddress(_ address: AddrModel) {
        // Handle Default logic: if new is default, others become false
        if address.isDefault {
            for i in 0..<addresses.count {
                addresses[i].isDefault = false
            }
        }
        
        if let index = addresses.firstIndex(where: { $0.id == address.id }) {
            // Update existing
            addresses[index] = address
        } else {
            // Add new
            addresses.append(address)
        }
        
        saveToDisk()
        
        // If no default exists, make the first one default (optional business rule)
        // For now, adhere to user input.
        
        updateState()
    }
    
    // MARK: - TableView Data Source
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return addresses.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "AddressListCell", for: indexPath) as? AddressListCell else {
            return UITableViewCell()
        }
        let model = addresses[indexPath.row]
        cell.configure(with: model)
        cell.editButton.addTarget(self, action: #selector(handleEdit(_:)), for: .touchUpInside)
        return cell
    }
    
    // MARK: - TableView Delegate
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: L("address.delete")) { [weak self] (action, view, completionHandler) in
            guard let self = self else { return }
            self.addresses.remove(at: indexPath.row)
            self.saveToDisk()
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            
            // Check if we need to update state (e.g. show empty view)
            if self.addresses.isEmpty {
                 self.updateState()
            }
            
            completionHandler(true)
        }
        
        // Optional: Customize background color
        deleteAction.backgroundColor = .red
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100 // Estimate height
    }
}

class AddressListCell: UITableViewCell {
    
    // Scale helper duplicate for Cell
    private var scale: CGFloat { return UIScreen.main.bounds.width / 375.0 }
    private func s(_ val: CGFloat) -> CGFloat { return val * scale }

    let defaultTag: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("address.default_tag")
        label.font = UIFont(name: "PingFangSC-Regular", size: 10) ?? .systemFont(ofSize: 10)
        label.textColor = .white
        label.backgroundColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0) // Purple
        label.textAlignment = .center
        label.layer.cornerRadius = 2
        label.clipsToBounds = true
        return label
    }()
    
    let regionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        label.textColor = UIColor(white: 1, alpha: 0.5)
        return label
    }()
    
    let detailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "PingFangSC-Semibold", size: 16) ?? .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()
    
    let contactLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        label.textColor = UIColor(white: 1, alpha: 0.5)
        return label
    }()
    
    let editButton: UIButton = {
        let btn = UIButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(named: "address_edit"), for: .normal)
        return btn
    }()
    
    let separator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(white: 1, alpha: 0.1)
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(defaultTag)
        contentView.addSubview(regionLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(contactLabel)
        contentView.addSubview(editButton)
        contentView.addSubview(separator)
        
        NSLayoutConstraint.activate([
            // Row 1: Top infos
            // Tag logic needs handling in configure
            
            defaultTag.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: s(20)),
            defaultTag.topAnchor.constraint(equalTo: contentView.topAnchor, constant: s(15)),
            defaultTag.widthAnchor.constraint(equalToConstant: s(30)),
            defaultTag.heightAnchor.constraint(equalToConstant: s(16)),
            
            regionLabel.centerYAnchor.constraint(equalTo: defaultTag.centerYAnchor),
            // Leading anchor will be dynamic based on Tag visibility
            
            // Detail Address
            detailLabel.topAnchor.constraint(equalTo: defaultTag.bottomAnchor, constant: s(8)),
            detailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: s(20)),
            detailLabel.trailingAnchor.constraint(equalTo: editButton.leadingAnchor, constant: -s(10)),
            
            // Name Phone
            contactLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: s(6)),
            contactLabel.leadingAnchor.constraint(equalTo: detailLabel.leadingAnchor),
            
            // Edit Button
            editButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            editButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -s(20)),
            editButton.widthAnchor.constraint(equalToConstant: s(24)),
            editButton.heightAnchor.constraint(equalToConstant: s(24)),
            
            // Separator
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: s(20)),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -s(20)),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }
    
    private var regionLeadingConstraint: NSLayoutConstraint!
    
    func configure(with model: AddrModel) {
        defaultTag.isHidden = !model.isDefault
        regionLabel.text = model.region
        detailLabel.text = model.detail
        contactLabel.text = "\(model.name) \(model.phone)"
        
        // Adjust layout if default tag is hidden
        // Ideally we use a StackView or remaking constraint.
        // For simplicity:
        regionLabel.removeFromSuperview()
        contentView.addSubview(regionLabel)
        
        if model.isDefault {
            NSLayoutConstraint.activate([
                regionLabel.leadingAnchor.constraint(equalTo: defaultTag.trailingAnchor, constant: 6),
                regionLabel.centerYAnchor.constraint(equalTo: defaultTag.centerYAnchor)
            ])
        } else {
             NSLayoutConstraint.activate([
                regionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: s(20)),
                regionLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: s(15))
            ])
        }
    }
}
