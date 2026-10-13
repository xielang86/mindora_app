import UIKit

/// 设备详情页（DeviceScan 列表里点 ⓘ 进入）。
///
/// 视觉参考 iOS 蓝牙详情页：顶部大标题（= 当前设备名）+ 下方 insetGrouped 行：
///   "名称" 行 (chevron) → 跳子页编辑昵称
///   "型号" 行           只读
///   "设备 ID" 行         只读
///
/// 两种模式由 `boundEntry` 是否非空决定：
/// - 未绑定：顶部标题 = model；只有"型号 / 设备 ID"两行只读，没有"名称"行
/// - 已绑定：顶部标题 = displayName；多出一段"名称"行，点进去 [[DeviceNicknameEditViewController]] 改昵称
///
/// 监听 DeviceSession.didChangeNotification：编辑昵称返回后顶部标题 + 名称行同步刷新。
final class DeviceDetailViewController: UIViewController {

    /// 详情页只需要这些信息就够了，不依赖完整的 UnifiedDevice 对象。两个 init 入口都填这套。
    private let model: String
    private let fallbackDeviceID: String?
    private let lookupBleIdentifier: UUID?
    private let lookupHost: String?

    private var boundEntry: DeviceSession.Entry?

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

    /// 顶部大标题 = 当前用户看到的设备名（已绑 → displayName，未绑 → model）。
    /// 不可编辑——名称编辑入口是下方"名称"行 → 子页。
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 26, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 信息行表。.insetGrouped 给出 iOS Settings 同款圆角分组卡片视感；transparent background
    /// 让 boot-p4 + darkOverlay 透过来跟整 App 视觉风格统一。
    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = .clear
        tv.separatorColor = UIColor(white: 1, alpha: 0.12)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Lifecycle

    /// 从扫描结果进入（DeviceScan 列表点 ⓘ）。可能已绑定也可能未绑定，由 refreshBoundEntry 查
    /// DeviceSession 决定渲染模式。
    init(unified: UnifiedDevice) {
        self.model = unified.model
        self.fallbackDeviceID = unified.deviceID
        self.lookupBleIdentifier = unified.ble?.identifier
        self.lookupHost = unified.bonjour?.hostName
        super.init(nibName: nil, bundle: nil)
        refreshBoundEntry()
    }

    /// 从已绑定设备入口进入（DM 点设备图片）。一定已绑定；boundEntry 直接初始化为传入的 entry。
    /// 仍然走 refreshBoundEntry 兼容场景：用户在本页停留期间被别处删了 entry，能同步刷成"未绑定"视图。
    init(entry: DeviceSession.Entry) {
        self.model = entry.model ?? L("device_manage.default_name")
        self.fallbackDeviceID = entry.deviceID
        self.lookupBleIdentifier = entry.bleIdentifier
        self.lookupHost = entry.host
        super.init(nibName: nil, bundle: nil)
        self.boundEntry = entry
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupChrome()
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DetailValueCell.self, forCellReuseIdentifier: DetailValueCell.identifier)
        tableView.register(DisconnectActionCell.self, forCellReuseIdentifier: DisconnectActionCell.identifier)

        renderTitle()

        NotificationCenter.default.addObserver(
            self, selector: #selector(sessionDidChange),
            name: DeviceSession.didChangeNotification, object: nil
        )
        // 也订阅 discovery 更新——按钮文案依赖 isReachable，设备上线 / 下线时按钮要跟着翻
        NotificationCenter.default.addObserver(
            self, selector: #selector(discoveryDidUpdate),
            name: UnifiedDeviceDiscovery.didUpdateNotification, object: nil
        )
    }

    @objc private func discoveryDidUpdate() {
        tableView.reloadData()
    }

    /// 当前 device_id 是否在 UnifiedDeviceDiscovery 的 reachable 集合里。决定底部按钮
    /// 文案要显示 "断开连接" 还是 "连接"——跟 DM / MY DEVICES 行显示的"是否 Connected"
    /// 保持一致语义。
    private func isCurrentlyReachable() -> Bool {
        guard let did = boundEntry?.deviceID ?? fallbackDeviceID else { return false }
        return UnifiedDeviceDiscovery.shared.devices.contains { $0.deviceID == did }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        // 从子页（编辑昵称）返回时，sessionDidChange 已经把 boundEntry 刷过；
        // 主动 reload 一次确保 cells 跟最新 entry 同步。
        refreshBoundEntry()
        renderTitle()
        tableView.reloadData()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

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

            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
        ])
    }

    // MARK: - Render

    private func refreshBoundEntry() {
        let entries = DeviceSession.shared.entries
        boundEntry = entries.first { e in
            if let did = fallbackDeviceID, e.deviceID == did { return true }
            if let ble = lookupBleIdentifier, e.bleIdentifier == ble { return true }
            if let host = lookupHost, e.host == host { return true }
            return false
        }
    }

    private func renderTitle() {
        let resolvedModel = boundEntry?.model ?? model
        titleLabel.text = boundEntry?.displayName ?? resolvedModel
    }

    // MARK: - Actions

    @objc private func sessionDidChange() {
        refreshBoundEntry()
        renderTitle()
        tableView.reloadData()
    }

    @objc private func didTapBack() {
        backButton.animateButtonTap { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
}

// MARK: - UITableView

extension DeviceDetailViewController: UITableViewDataSource, UITableViewDelegate {

    /// 已绑定时三段：昵称编辑 + 信息（型号 + 设备 ID）+ 断开连接；未绑定只有信息一段。
    private enum LogicalSection { case nickname, info, disconnect }

    private var sections: [LogicalSection] {
        boundEntry != nil ? [.nickname, .info, .disconnect] : [.info]
    }

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .nickname:   return 1
        case .info:       return 2     // 型号 + 设备 ID
        case .disconnect: return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let resolvedModel = boundEntry?.model ?? model
        let deviceID = boundEntry?.deviceID ?? fallbackDeviceID ?? L("device_detail.value.unknown")

        switch sections[indexPath.section] {
        case .nickname:
            let cell = tableView.dequeueReusableCell(withIdentifier: DetailValueCell.identifier, for: indexPath) as! DetailValueCell
            cell.configure(
                title: L("device_detail.section.name"),
                value: boundEntry?.displayName ?? resolvedModel,
                tappable: true,
                monospace: false
            )
            return cell
        case .info:
            let cell = tableView.dequeueReusableCell(withIdentifier: DetailValueCell.identifier, for: indexPath) as! DetailValueCell
            if indexPath.row == 0 {
                cell.configure(
                    title: L("device_detail.section.model"),
                    value: resolvedModel,
                    tappable: false,
                    monospace: false
                )
            } else {
                cell.configure(
                    title: L("device_detail.section.device_id"),
                    value: deviceID,
                    tappable: false,
                    monospace: true
                )
            }
            return cell
        case .disconnect:
            let cell = tableView.dequeueReusableCell(withIdentifier: DisconnectActionCell.identifier, for: indexPath) as! DisconnectActionCell
            // 文案跟"行显示的状态"对齐：当前 effectivelyConnected → 按钮 "断开连接"；
            // 否则 → 按钮 "连接"。effectivelyConnected = isReachable && !isUserDisconnected。
            // 之前只看 isUserDisconnected 会出现"行显示 Not Connected 但按钮是断开连接"
            // 的怪异 case（设备下线 + 用户未主动断开 = 行 Not Connected + 按钮 Disconnect）。
            let isUserDisc = boundEntry?.isUserDisconnected ?? false
            let effectivelyConnected = isCurrentlyReachable() && !isUserDisc
            cell.configure(asDisconnect: effectivelyConnected)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .nickname:
            guard let entry = boundEntry else { return }
            let edit = DeviceNicknameEditViewController(entry: entry)
            navigationController?.pushViewController(edit, animated: true)
        case .info:
            break
        case .disconnect:
            guard let entry = boundEntry else { return }
            // 跟按钮文案对齐：当前 effectivelyConnected → "断开连接" → 设 userDisc=true；
            // 否则 → "连接" → 设 userDisc=false（设备在线立刻显示 Connected，离线就等
            // 它恢复在线时自动按新意图渲染）。entry 不删。
            let isUserDisc = entry.isUserDisconnected ?? false
            let effectivelyConnected = isCurrentlyReachable() && !isUserDisc
            DeviceSession.shared.setUserDisconnected(entry, to: effectivelyConnected)
            navigationController?.popViewController(animated: true)
        }
    }
}

/// 详情页通用 value1 行：标题左 + 灰色值右；可选 chevron。深底色适配 iOS Settings dark mode 视感。
private final class DetailValueCell: UITableViewCell {
    static let identifier = "DetailValueCell"

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .regular)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .regular)
        l.textColor = UIColor(white: 1, alpha: 0.55)
        l.textAlignment = .right
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingMiddle    // device_id 长时中间省略，两端可读
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        // .insetGrouped 默认 cell 背景跟 system grouped 颜色一致，深底图上看起来发亮——
        // 改成半透明白让 boot-p4 透过来，跟 DeviceScan 等其他页保持一致深度。
        backgroundColor = UIColor(white: 1, alpha: 0.08)
        let bg = UIView()
        bg.backgroundColor = UIColor(white: 1, alpha: 0.14)
        selectedBackgroundView = bg
        tintColor = UIColor(white: 1, alpha: 0.4)   // chevron 灰

        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, value: String, tappable: Bool, monospace: Bool) {
        titleLabel.text = title
        valueLabel.text = value
        valueLabel.font = monospace
            ? .monospacedSystemFont(ofSize: 14, weight: .regular)
            : .systemFont(ofSize: 17, weight: .regular)
        accessoryType = tappable ? .disclosureIndicator : .none
        selectionStyle = tappable ? .default : .none
    }
}

/// 详情页底部 toggle 行：蓝色居左文字 "断开连接" / "连接"，无 chevron / 无右侧值。
/// 蓝色 (0.40, 0.78, 1.0) 跟 DeviceScan "前往系统设置" 链接 + DeviceScanCell ⓘ tint 三处
/// 保持一致——全 App 唯一一种"可点击操作"蓝。
private final class DisconnectActionCell: UITableViewCell {
    static let identifier = "DisconnectActionCell"

    private let actionLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .regular)
        l.textColor = UIColor(red: 0.40, green: 0.78, blue: 1.0, alpha: 1.0)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// `asDisconnect == true` → 显示 "断开连接"（当前是已连接状态，按下断开）
    /// `asDisconnect == false` → 显示 "连接"（当前是已断开状态，按下重新连接）
    func configure(asDisconnect: Bool) {
        actionLabel.text = asDisconnect
            ? L("device_detail.disconnect")
            : L("device_detail.connect")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(white: 1, alpha: 0.08)
        let bg = UIView()
        bg.backgroundColor = UIColor(white: 1, alpha: 0.14)
        selectedBackgroundView = bg

        contentView.addSubview(actionLabel)
        NSLayoutConstraint.activate([
            actionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            actionLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            actionLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
