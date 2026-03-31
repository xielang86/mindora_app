
import UIKit

class DeviceManagementViewController: UIViewController {

    // MARK: - Design Constants
    private let designWidth: CGFloat = 750
    private let designHeight: CGFloat = 1624
    
    // MARK: - Models
    struct DeviceItem {
        let name: String
        let imageName: String
        let isConnected: Bool
    }
    
    // Mock Data
    private var devices: [DeviceItem] = [
        DeviceItem(name: L("device_manage.default_name"), imageName: "device", isConnected: true)
        // Add more here to test scrolling if needed
    ]
    
    // MARK: - UI Components
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        // Using a standard back arrow or close button
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(DeviceManagementCell.self, forCellWithReuseIdentifier: DeviceManagementCell.identifier)
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    // group_4 > text-wrapper_4 (Button Background)
    private let connectOtherButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(red: 70/255.0, green: 70/255.0, blue: 70/255.0, alpha: 1.0)
        // CSS: border-radius: 48px;
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // group_4 > text-wrapper_4 > text_6 (Button Title)
    private let connectOtherLabel: UILabel = {
        let label = UILabel()
        label.text = L("device_manage.button.connect_other")
        label.textColor = .white
        label.textAlignment = .center
        // CSS: font-size: 28px; font-family: SourceHanSansCN-Regular;
        label.font = UIFont(name: "PingFangSC-Regular", size: 14) // Scaled approx
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update layout if needed
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = collectionView.bounds.size
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // CSS: .page { background-color: rgba(24, 24, 24, 1); }
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        
        // Add Subviews
        view.addSubview(backButton)
        view.addSubview(collectionView)
        view.addSubview(connectOtherButton)
        connectOtherButton.addSubview(connectOtherLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        // Back Button (Top Left)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Connect Other Button (Bottom)
        // CSS: group_4 margin: 36px 73px 0 60px; (This margin is relative to element above, let's pin to bottom)
        // text-wrapper_4: padding: 26px ...
        // Let's rely on scale for height/radius.
        _ = scale(100, basedOn: view.bounds.height, designDimension: designHeight) // Approx based on padding + text
        let btnBottomMargin = scale(100, basedOn: view.bounds.height, designDimension: designHeight)
        
        NSLayoutConstraint.activate([
            connectOtherButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -btnBottomMargin),
            connectOtherButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            connectOtherButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            connectOtherButton.heightAnchor.constraint(equalToConstant: 60) // Fixed height often better for touch targets
        ])
        
        connectOtherButton.layer.cornerRadius = 30 // Half of 60
        
        // Label inside button
        NSLayoutConstraint.activate([
            connectOtherLabel.centerXAnchor.constraint(equalTo: connectOtherButton.centerXAnchor),
            connectOtherLabel.centerYAnchor.constraint(equalTo: connectOtherButton.centerYAnchor)
        ])
        
        // Collection View (Takes remaining space)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: connectOtherButton.topAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        connectOtherButton.addTarget(self, action: #selector(didTapConnectOther), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func didTapBack() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc private func didTapConnectOther() {
        connectOtherButton.animateButtonTap {
            let vc = RegisterP4Controller()
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    // MARK: - Helpers
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return (dimension * designValue) / designDimension
    }
}

// MARK: - UICollectionViewDataSource & Delegate

extension DeviceManagementViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return devices.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DeviceManagementCell.identifier, for: indexPath) as? DeviceManagementCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: devices[indexPath.item])
        return cell
    }
}

// MARK: - Cell

class DeviceManagementCell: UICollectionViewCell {
    static let identifier = "DeviceManagementCell"
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont(name: "Kano-regular", size: 24) ?? .systemFont(ofSize: 24)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let statusContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let statusIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = UIImage(named: "device_connect")
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "PingFangSC-Medium", size: 24) ?? .systemFont(ofSize: 24, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(nameLabel)
        contentView.addSubview(imageView)
        contentView.addSubview(statusContainer)
        statusContainer.addSubview(statusIcon)
        statusContainer.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            // Name
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            nameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            // Image
            imageView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 40),
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.8),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            
            // Status
            statusContainer.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 40),
            statusContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            statusContainer.heightAnchor.constraint(equalToConstant: 30),
            
            statusIcon.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor),
            statusIcon.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 24),
            statusIcon.heightAnchor.constraint(equalToConstant: 24),
            
            statusLabel.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor)
        ])
    }
    
    func configure(with item: DeviceManagementViewController.DeviceItem) {
        nameLabel.text = item.name
        imageView.image = UIImage(named: item.imageName)
        
        if item.isConnected {
            statusLabel.text = L("device_manage.status.connected")
            statusIcon.isHidden = false
        } else {
            statusLabel.text = ""
            statusIcon.isHidden = true
        }
    }
}
