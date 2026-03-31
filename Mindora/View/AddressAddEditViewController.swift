import UIKit

class AddressAddEditViewController: UIViewController {

    // MARK: - Properties
    var existingAddress: AddrModel? // If set, we are editing
    var onSave: ((AddrModel) -> Void)?
    
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
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Smart Paste Area
    private let smartPasteContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(white: 1, alpha: 0.1)
        view.layer.cornerRadius = 8
        return view
    }()
    
    private let smartPasteLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("address.paste_tip")
        label.textColor = UIColor(white: 1, alpha: 0.5)
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
    private let pasteButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("address.paste"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.backgroundColor = UIColor(white: 1, alpha: 0.2)
        button.layer.cornerRadius = 14
        return button
    }()
    
    // Form Rows
    private lazy var nameRow = createInputRow(title: L("address.name"), placeholder: L("address.name_placeholder"))
    private lazy var phoneRow = createInputRow(title: L("address.phone"), placeholder: L("address.phone_placeholder"))
    
    // Region Row (Different structure)
    private let regionContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let regionTitle: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("address.region")
        label.textColor = .white
        label.font = UIFont(name: "PingFangSC-Regular", size: 16)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()
    
    private let regionValue: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("address.region_placeholder") // Default
        label.textColor = UIColor(white: 1, alpha: 0.5)
        label.font = UIFont(name: "PingFangSC-Regular", size: 16)
        return label
    }()
    
    private let locateButton: UIButton = {
        let btn = UIButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    // Helper to add locate icon and text
    private func setupLocateButton() {
        let iv = UIImageView(image: UIImage(named: "address_small"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text = L("address.locate")
        lbl.textColor = UIColor(white: 1, alpha: 0.5) // Adjust color
        lbl.font = UIFont.systemFont(ofSize: 12)
        
        locateButton.addSubview(iv)
        locateButton.addSubview(lbl)
        
        NSLayoutConstraint.activate([
            iv.centerYAnchor.constraint(equalTo: locateButton.centerYAnchor),
            iv.leadingAnchor.constraint(equalTo: locateButton.leadingAnchor),
            iv.widthAnchor.constraint(equalToConstant: 16),
            iv.heightAnchor.constraint(equalToConstant: 16),
            
            lbl.centerYAnchor.constraint(equalTo: locateButton.centerYAnchor),
            lbl.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 4),
            lbl.trailingAnchor.constraint(equalTo: locateButton.trailingAnchor)
        ])
    }
    
    private lazy var detailRow = createInputRow(title: L("address.detail"), placeholder: L("address.detail_placeholder"))
    
    // Default Switch
    private let defaultSwitchRow: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let defaultLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("address.set_default")
        label.textColor = .white
        label.font = UIFont(name: "PingFangSC-Regular", size: 16)
        return label
    }()
    
    private let defaultSwitch: UISwitch = {
        let sw = UISwitch()
        sw.translatesAutoresizingMaskIntoConstraints = false
        // Request: bg #D4D6DD, fg white
        sw.onTintColor = .white // Wait, standard switch doesn't let you set foreground easily if On. 
        // Typically onTintColor is the background when ON.
        // User said: "前景色白色，背景色#D4D6DD"
        // This likely means when ON, the circle is white, and the track is #D4D6DD? Or maybe OFF state?
        // Usually switches are Green when ON. 
        // If they want custom colors:
        sw.onTintColor = UIColor(red: 212/255, green: 214/255, blue: 221/255, alpha: 1.0) // #D4D6DD
        sw.thumbTintColor = .white
        return sw
    }()
    
    private let confirmButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("address.confirm"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 16)
        button.backgroundColor = UIColor(white: 1, alpha: 0.2) // Button style "grayish" in design 2
        button.layer.cornerRadius = 25
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocateButton()
        setupUI()
        setupActions()
        setupKeyboardDismiss()
        populateData()
    }
    
    private func populateData() {
        if let model = existingAddress {
            // Find textfields in rows and set text
            // Implementation detail: createInputRow returns a container. 
            // Better to have refs to text fields. 
            // For concise code in this tool, I'll iterate subviews or just rely on tag if I set it.
            // Let's improve createInputRow to return Tuple or custom View
            
            // Re-implementing handy refs below in property section would be cleaner but I'll access via tags or just set up direct refs.
            // Since createInputRow is lazy, I can access the textFields directly if I stored them.
            // I'll assume I can set them now.
            nameTextField?.text = model.name
            phoneTextField?.text = model.phone
            detailTextField?.text = model.detail
            regionValue.text = model.region
            regionValue.textColor = .white
            defaultSwitch.isOn = model.isDefault
        }
    }
    
    // MARK: - Helper for Rows
    var nameTextField: UITextField?
    var phoneTextField: UITextField?
    var detailTextField: UITextField?
    
    private func createInputRow(title: String, placeholder: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLbl = UILabel()
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.text = title
        titleLbl.textColor = .white
        titleLbl.font = UIFont(name: "PingFangSC-Regular", size: 16)
        titleLbl.widthAnchor.constraint(equalToConstant: s(80)).isActive = true // Fixed width for alignment
        
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.3)])
        tf.textColor = .white
        tf.font = UIFont(name: "PingFangSC-Regular", size: 16)
        tf.borderStyle = .none
        
        // Store ref based on title (Hack for this single file script)
        if title == L("address.name") { nameTextField = tf }
        if title == L("address.phone") { phoneTextField = tf }
        if title == L("address.detail") { detailTextField = tf }

        let sep = UIView()
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.backgroundColor = UIColor(white: 1, alpha: 0.1)
        
        container.addSubview(titleLbl)
        container.addSubview(tf)
        container.addSubview(sep)
        
        NSLayoutConstraint.activate([
            titleLbl.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLbl.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -1), // adjust for sep
            
            tf.leadingAnchor.constraint(equalTo: titleLbl.trailingAnchor, constant: 10),
            tf.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tf.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -1),
            tf.heightAnchor.constraint(equalToConstant: 44),
            
            sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
            
            container.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        return container
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        
        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        view.addSubview(separatorLine)
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add Elements to ContentView
        contentView.addSubview(smartPasteContainer)
        smartPasteContainer.addSubview(smartPasteLabel)
        smartPasteContainer.addSubview(pasteButton)
        
        contentView.addSubview(nameRow)
        contentView.addSubview(phoneRow)
        
        contentView.addSubview(regionContainer)
        regionContainer.addSubview(regionTitle)
        regionContainer.addSubview(regionValue)
        regionContainer.addSubview(locateButton)
        let regionSep = UIView()
        regionSep.backgroundColor = UIColor(white: 1, alpha: 0.1)
        regionSep.translatesAutoresizingMaskIntoConstraints = false
        regionContainer.addSubview(regionSep)

        contentView.addSubview(detailRow)
        
        contentView.addSubview(defaultSwitchRow)
        defaultSwitchRow.addSubview(defaultLabel)
        defaultSwitchRow.addSubview(defaultSwitch)
        
        view.addSubview(confirmButton) // Fixed at bottom
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        // Header
        NSLayoutConstraint.activate([
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
        ])
        
        // Confirm Button
        NSLayoutConstraint.activate([
            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: s(32)),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -s(32)),
            confirmButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -s(34)),
            confirmButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // ScrollView
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: separatorLine.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: confirmButton.topAnchor, constant: -20),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Content
        let margin = s(20)
        
        // Smart Paste
        NSLayoutConstraint.activate([
            smartPasteContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            smartPasteContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            smartPasteContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            smartPasteContainer.heightAnchor.constraint(equalToConstant: 80),
            
            smartPasteLabel.leadingAnchor.constraint(equalTo: smartPasteContainer.leadingAnchor, constant: 16),
            smartPasteLabel.centerYAnchor.constraint(equalTo: smartPasteContainer.centerYAnchor),
            
            pasteButton.trailingAnchor.constraint(equalTo: smartPasteContainer.trailingAnchor, constant: -16),
            pasteButton.centerYAnchor.constraint(equalTo: smartPasteContainer.centerYAnchor),
            pasteButton.widthAnchor.constraint(equalToConstant: 60),
            pasteButton.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        // Rows
        NSLayoutConstraint.activate([
            nameRow.topAnchor.constraint(equalTo: smartPasteContainer.bottomAnchor, constant: 20),
            nameRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            nameRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            
            phoneRow.topAnchor.constraint(equalTo: nameRow.bottomAnchor),
            phoneRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            phoneRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            
            regionContainer.topAnchor.constraint(equalTo: phoneRow.bottomAnchor),
            regionContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            regionContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            regionContainer.heightAnchor.constraint(equalToConstant: 60),
            
            // Region Internal
            regionTitle.leadingAnchor.constraint(equalTo: regionContainer.leadingAnchor),
            regionTitle.centerYAnchor.constraint(equalTo: regionContainer.centerYAnchor),
            regionTitle.widthAnchor.constraint(equalToConstant: s(80)),
            
            locateButton.trailingAnchor.constraint(equalTo: regionContainer.trailingAnchor),
            locateButton.centerYAnchor.constraint(equalTo: regionContainer.centerYAnchor),
            
            regionValue.leadingAnchor.constraint(equalTo: regionTitle.trailingAnchor, constant: 10),
            regionValue.centerYAnchor.constraint(equalTo: regionContainer.centerYAnchor),
            regionValue.trailingAnchor.constraint(lessThanOrEqualTo: locateButton.leadingAnchor, constant: -10),
            
            // Detail Row
            detailRow.topAnchor.constraint(equalTo: regionContainer.bottomAnchor),
            detailRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            detailRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            
            // Default Switch
            defaultSwitchRow.topAnchor.constraint(equalTo: detailRow.bottomAnchor, constant: 20),
            defaultSwitchRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            defaultSwitchRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            defaultSwitchRow.heightAnchor.constraint(equalToConstant: 50),
            
            defaultLabel.leadingAnchor.constraint(equalTo: defaultSwitchRow.leadingAnchor),
            defaultLabel.centerYAnchor.constraint(equalTo: defaultSwitchRow.centerYAnchor),
            
            defaultSwitch.trailingAnchor.constraint(equalTo: defaultSwitchRow.trailingAnchor),
            defaultSwitch.centerYAnchor.constraint(equalTo: defaultSwitchRow.centerYAnchor),
            
            // Bottom of content
            defaultSwitchRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        // Region Sep
        if let sep = regionContainer.subviews.last {
            NSLayoutConstraint.activate([
                sep.leadingAnchor.constraint(equalTo: regionContainer.leadingAnchor),
                sep.trailingAnchor.constraint(equalTo: regionContainer.trailingAnchor),
                sep.bottomAnchor.constraint(equalTo: regionContainer.bottomAnchor),
                sep.heightAnchor.constraint(equalToConstant: 0.5)
            ])
        }
    }
    
    // MARK: - Actions
    private func setupActions() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
        pasteButton.addTarget(self, action: #selector(handlePaste), for: .touchUpInside)
        locateButton.addTarget(self, action: #selector(handleLocate), for: .touchUpInside)
    }

    private func setupKeyboardDismiss() {
        scrollView.keyboardDismissMode = .onDrag
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func handlePaste() {
        guard let text = UIPasteboard.general.string else { return }
        
        var remaining = text
        
        // 1. Extract Phone (11 digits starting with 1)
        let phonePattern = "1\\d{10}"
        if let range = remaining.range(of: phonePattern, options: .regularExpression) {
            let phone = String(remaining[range])
            phoneTextField?.text = phone
            // Remove phone from parsing string
            remaining.removeSubrange(range)
        }
        
        // Clean up text
        remaining = remaining.replacingOccurrences(of: "，", with: " ")
        remaining = remaining.replacingOccurrences(of: ",", with: " ")
        remaining = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. Identify Name vs Address
        // Split by whitespace
        let parts = remaining.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        var extractedName: String?
        var extractedAddr: String?
        
        if parts.isEmpty {
            // No other info
        } else if parts.count == 1 {
            // If short, name. If long, address.
            let p = parts[0]
            if p.count <= 4 {
                extractedName = p
            } else {
                extractedAddr = p
            }
        } else {
            // Heuristic: Name is usually the shortest part (<= 4 chars)
            if let idx = parts.firstIndex(where: { $0.count <= 4 }) {
                extractedName = parts[idx]
                var addrParts = parts
                addrParts.remove(at: idx)
                extractedAddr = addrParts.joined(separator: "") // Join rest as address
            } else {
                // Fallback: Assume first part is name if we must choose, or strictly all address?
                // Common copy format: "Name Phone Address". If all parts long, maybe just address.
                // Let's assume the whole thing is address if no short part found.
                extractedAddr = parts.joined(separator: "")
            }
        }
        
        if let n = extractedName {
            nameTextField?.text = n
        }
        
        // 3. Parse Region vs Detail
        if let rawAddr = extractedAddr {
            // Simple logic: Find match for "District" (区/县) or "City" (市) or "Province" (省)
            // We want the most specific region level, usually "区" or "县".
            // If we find "区", split there.
            
            var splitIndex: String.Index?
            
            // Priority: 区 > 县 > 市 > 省
            if let range = rawAddr.range(of: "区", options: .backwards) {
                splitIndex = range.upperBound
            } else if let range = rawAddr.range(of: "县", options: .backwards) {
                splitIndex = range.upperBound
            } else if let range = rawAddr.range(of: "市", options: .backwards) {
                splitIndex = range.upperBound
            } else if let range = rawAddr.range(of: "省", options: .backwards) {
                splitIndex = range.upperBound
            }
            
            if let idx = splitIndex {
                let regionStr = String(rawAddr[..<idx])
                let detailStr = String(rawAddr[idx...])
                
                regionValue.text = regionStr
                regionValue.textColor = .white
                detailTextField?.text = detailStr
            } else {
                // No region keyword found, put all to detail
                detailTextField?.text = rawAddr
            }
        }
    }
    
    @objc private func handleLocate() {
        let vc = AddressMapPickerViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.onSelectLocation = { [weak self] location in
            self?.regionValue.text = location.region
            self?.regionValue.textColor = .white
            self?.detailTextField?.text = location.detail
        }
        present(vc, animated: true)
    }
    
    private func showPermissionAlert() {
        let alert = UIAlertController(title: L("common.tips"), message: L("permission.location_needed"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: L("common.settings"), style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func handleConfirm() {
        guard let name = nameTextField?.text, !name.isEmpty,
              let phone = phoneTextField?.text, !phone.isEmpty,
              let detail = detailTextField?.text, !detail.isEmpty else {
            // Simple validation feedback if needed
            return
        }
        
        // Mock region value if not set properly
         let region = regionValue.text == L("address.region_placeholder") ? "上海市 普陀区" : (regionValue.text ?? "上海市 普陀区")
         
        let id = existingAddress?.id ?? UUID().uuidString
        let newModel = AddrModel(
            id: id,
            isDefault: defaultSwitch.isOn,
            region: region,
            detail: detail,
            name: name,
            phone: phone
        )
        
        onSave?(newModel)
        dismiss(animated: true, completion: nil)
    }
}
