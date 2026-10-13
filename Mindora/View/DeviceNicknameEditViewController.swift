import UIKit

/// 设备昵称编辑子页（DeviceDetail 点"名称"行进入）。
///
/// 设计参考 iOS 蓝牙 → 设备 → 名称编辑页：单一文本输入框 + 系统 X 清除按钮；
/// 进入即聚焦键盘，pop 回上一页时落库（DeviceSession.rename）。空字符串等价
/// "恢复默认"——回落到 entry.model。
final class DeviceNicknameEditViewController: UIViewController {

    private let entry: DeviceSession.Entry

    // MARK: - UI

    private let backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "boot-p4")
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.alpha = 0.45
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let darkOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0, alpha: 0.35)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let backButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton()
        button.setImage(UIImage(named: "sub_back"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none   // 单行 cell，不需要分隔
        tv.isScrollEnabled = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let textField: UITextField = {
        let f = UITextField()
        f.font = .systemFont(ofSize: 17, weight: .regular)
        f.textColor = .white
        f.tintColor = .white
        f.returnKeyType = .done
        f.clearButtonMode = .whileEditing
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()

    // MARK: - Lifecycle

    init(entry: DeviceSession.Entry) {
        self.entry = entry
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        installTapToDismissKeyboard()

        titleLabel.text = L("device_detail.section.name")
        textField.text = entry.displayName ?? entry.model
        textField.placeholder = entry.model

        setupChrome()
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        textField.addTarget(self, action: #selector(textFieldDidEndOnExit), for: .editingDidEndOnExit)

        // 点页面空白处（背景、深底图任意位置）收起键盘——iOS Bluetooth 编辑页同款手感。
        // cancelsTouchesInView = false 让 cell 上的 textField 自身 tap 不被吞，仍能正常激活。
        let tapToDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapToDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(tapToDismiss)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(EditFieldCell.self, forCellReuseIdentifier: EditFieldCell.identifier)
    }

    @objc private func dismissKeyboard() {
        textField.resignFirstResponder()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 进入即聚焦键盘，让用户立即可编辑——iOS 蓝牙编辑昵称同款体验
        textField.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 返回前落库；空字符串由 DeviceSession.rename 自动回落到 model
        DeviceSession.shared.rename(entry, to: textField.text ?? "")
    }

    // MARK: - Setup

    private func setupChrome() {
        view.addSubview(backgroundImageView)
        view.addSubview(darkOverlay)
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(tableView)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            darkOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            darkOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            darkOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            darkOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 24),
            backButton.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            tableView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 24),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func didTapBack() {
        backButton.animateButtonTap { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    @objc private func textFieldDidEndOnExit() {
        // 用户按 "Done" 键直接返回上一页（跟 iOS 蓝牙同款行为）
        navigationController?.popViewController(animated: true)
    }
}

extension DeviceNicknameEditViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: EditFieldCell.identifier, for: indexPath) as! EditFieldCell
        cell.attach(textField: textField)
        return cell
    }
}

/// 包一个 UITextField 进 insetGrouped cell。textField 是外部持有的实例（VC 直接拿来读写值）
/// cell 只负责放置 + 设置 16pt 横向 padding。
private final class EditFieldCell: UITableViewCell {
    static let identifier = "EditFieldCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(white: 1, alpha: 0.08)
        selectionStyle = .none
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func attach(textField: UITextField) {
        // 重用时 textField 可能已经在 contentView 里——idempotent 处理
        if textField.superview !== contentView {
            textField.removeFromSuperview()
            contentView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
                textField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
                textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            ])
        }
    }
}
