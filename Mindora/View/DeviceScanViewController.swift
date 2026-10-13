import UIKit

/// 扫描 + 多选绑定页。视觉跟 onboarding / DM 同一套深色基调（boot-p4 底图 + 自定义返回按钮），
/// 中部一个 iOS 蓝牙设置同款风格的列表，行高 + 左右插入 + "MY DEVICES" section header。
///
/// 两种入口模式只影响 backButton 的退出行为：
/// - `.onboarding`：首次进入引导流末位页。绑过 ≥1 台后 back = 完成 onboarding → 主 tab；
///                  否则 back = 回 OnboardingPage3
/// - `.management`：DM "Connect Another Device" 入口。back = pop 回 DM
final class DeviceScanViewController: UIViewController {

    enum Mode {
        case onboarding
        case management
    }

    /// 单个设备行的连接状态。
    enum BindStatus {
        case notBound           // 已发现但未绑定，可点击触发绑定
        case binding            // 正在绑定中，显示 spinner
        case boundReachable     // 已绑定 + 当前在 discovery 集合里 → "已连接"
        case boundUnreachable   // 已绑定但当前不可达 → "未连接"
    }

    /// 列表行的来源：持久化 Entry（永远显示）或新扫描到的 UnifiedDevice（discovered 期间显示）。
    private enum RowKind {
        case bound(DeviceSession.Entry, matchedDevice: UnifiedDevice?)
        case discovered(UnifiedDevice)
    }

    private struct Row {
        let id: String
        let displayName: String
        let state: BindStatus
        let kind: RowKind
    }

    private let mode: Mode

    // MARK: - UI

    private let backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "boot-p4")
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        // 适当 "灰度" 处理：降低底图自身亮度，再叠一层半透明黑 overlay。最终视觉是图像
        // 隐约可见但很暗，注意力自然集中到上层文字 + 设备列表上。
        iv.alpha = 0.45
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    /// 盖在 backgroundImageView 上的半透明黑遮罩，进一步压暗。
    private let darkOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0, alpha: 0.35)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    /// 右上关闭按钮：xmark SF Symbol 20pt 白色，跟 OnboardingExitButton 同款外观。
    /// 这页可能是初次进 App 的第一步用户实际能交互的地方（onboarding 模式），右上 X 比
    /// 左上 ← 更符合"我可以跳过"的预期；管理模式下也用同一个按钮 = 单一退出入口。
    private let closeButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "xmark", withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        button.setImage(image, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 26, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 权限说明 + 行内"前往系统设置"链接（蓝色）合在一起的 UILabel。整段 tap → 跳系统设置
    /// 给这个 App 的权限页。链接文字跟说明文字 inline 排版（不另起一行），跟正文融为一体。
    private let hintLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(white: 1.0, alpha: 0.7)
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let tableView: UITableView = {
        // 跟 DeviceDetail 一致 .insetGrouped 圆角卡片风格——系统自动处理 cell 横向 inset、
        // 圆角、section header 对齐。深底色用 backgroundColor = .clear 让 boot-p4 透过来。
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = .clear
        tv.separatorColor = UIColor(white: 1.0, alpha: 0.12)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    /// 当前列表行（持久化 entries 永远在前 + 新扫描到的未绑定在后）。
    private var rows: [Row] = []
    /// 正在绑定中的设备 id（过渡态由本 VC 维护）；其他状态都从 entries + discovery 动态推导。
    private var bindingIDs: Set<String> = []

    /// 搜索超时：进页面 / 重试后 15s 内没扫到任何设备就切到"未发现设备 / 点击重试"状态，
    /// 停止 spinner，让用户能感知到"出了问题"而不是看一辈子的转圈。
    private let searchTimeout: TimeInterval = 15.0
    private var searchTimeoutTimer: Timer?
    private var searchTimedOut = false
    /// 本次进页面是否已自动弹过蓝牙权限引导。进页面、搜索超时这类自动时机只弹一次，
    /// 免得用户点了取消 15 秒后又被弹一次；用户主动点「重试」则每次都检查。
    private var didAutoPromptBluetooth = false

    // MARK: - Lifecycle

    init(mode: Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        titleLabel.text = L("onboarding.page4.scanning_title")   // "扫描附近设备"
        applyHintWithSettingsLink()

        setupUI()
        setupActions()
        registerObservers()

        // 进 DeviceScan 用 startContinuous 而不是 reset——如果 DM 已经在跑（管理模式下
        // 的典型链路），这里是 no-op，DM 累积的 discovery 缓存直接延续；持久化 entries
        // 的可达状态立刻就是对的（避免用户在 DM 看到 1 已连/1 未连，切到 Scan 突然
        // 变成两台全未连的"自相矛盾"过渡态）。如需强制全清重扫由 retry 按钮触发。
        // 引导模式（首次进 App，DM 还没存在过）这里就是冷启动，也是 startContinuous 正确。
        // 蓝牙权限引导放在 viewDidAppear：这里 view 还没进 window，弹窗会被直接跳过。
        // notDetermined 留给 startContinuous 触发系统原生弹窗。
        UnifiedDeviceDiscovery.shared.startContinuous()
        refreshDevices()
        startSearchTimer()
        // 跟 DM 一样：进搜索页时把所有已绑 entry 的 JWT 推送补一遍。新绑的设备走
        // connect() 路径已经会触发推送；这里覆盖"老 entry 一直没推过 JWT"的场景。
        DeviceLoginPusher.shared.pushPendingForAllEntries()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 跟 onboarding / DM 各页一致：本页隐藏系统 nav bar，用自定义 backButton
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        autoPromptBluetoothIfDenied()
    }

    /// 蓝牙已被拒时系统不会再弹授权框，只能自己引导去设置；否则用户只会看到「未找到设备」。
    private func autoPromptBluetoothIfDenied() {
        guard !didAutoPromptBluetooth else { return }
        if DevicePermissionGuide.checkBluetoothOnEnter(from: self) { didAutoPromptBluetooth = true }
    }

    deinit {
        // 不再在此 stop discovery：discovery 生命周期已由 SceneDelegate 统一管理（前台常开），
        // 避免离开扫描页后切断 DeviceLoginPusher 的心跳补推（token 同步可靠性关键）。
        searchTimeoutTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(backgroundImageView)
        view.addSubview(darkOverlay)
        view.addSubview(closeButton)
        view.addSubview(titleLabel)
        view.addSubview(hintLabel)
        view.addSubview(tableView)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DeviceScanCell.self, forCellReuseIdentifier: DeviceScanCell.identifier)

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

            // 关闭按钮：右上角 xmark 24x24，跟 OnboardingExitButton / RegisterP1 等页同款位置 + 图标
            closeButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            hintLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            hintLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            // 列表：table 横向铺满（leading/trailing = 0），insetGrouped 系统自动给 cell
            // 加 ~20pt 横向 inset 形成圆角卡片视感。centerY 居中 + 高度固定 360。
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            tableView.heightAnchor.constraint(equalToConstant: 360),
        ])
    }

    private func setupActions() {
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        // 整段 hint 文本 tap 跳系统设置——简化交互。链接位置由 attributed string 配色提示，
        // 用户即使精准点不到蓝色字也能跳过去，比手指必须命中具体字符更友好。
        hintLabel.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(didTapOpenSettings))
        )
    }

    /// 拼"说明文字 + 蓝色行内链接"的 attributedText。链接段用 device_scan.open_settings
    /// 这条文案（如 "前往系统设置"），整段在 hintLabel 同一 paragraph 里随文流动换行。
    private func applyHintWithSettingsLink() {
        let plainHint = L("device_scan.hint")
        let linkText = L("device_scan.open_settings")
        // 中文逗号紧接、英文用空格隔开——视语言而定，保持自然书写习惯
        let separator = plainHint.last == "。" || plainHint.last == "." ? " " : "  "
        let attr = NSMutableAttributedString(
            string: plainHint + separator,
            attributes: [
                .foregroundColor: UIColor(white: 1.0, alpha: 0.7),
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            ]
        )
        attr.append(NSAttributedString(
            string: linkText,
            attributes: [
                .foregroundColor: UIColor(red: 0.40, green: 0.78, blue: 1.0, alpha: 1.0),
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            ]
        ))
        hintLabel.attributedText = attr
    }

    @objc private func didTapOpenSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(discoveryDidUpdate),
            name: UnifiedDeviceDiscovery.didUpdateNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(sessionDidChange),
            name: DeviceSession.didChangeNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(bonjourDidFail(_:)),
            name: BonjourDiscovery.didFailNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(bleDidFail(_:)),
            name: BLEDiscovery.didFailNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(bleDidDetectStalePairing(_:)),
            name: BLEDiscovery.didDetectStalePairingNotification, object: nil
        )
    }

    // MARK: - Data

    @objc private func discoveryDidUpdate() { refreshDevices() }
    @objc private func sessionDidChange() { refreshDevices() }

    /// 用 deviceID / bleIdentifier / host 匹配同一物理设备的 Entry 和 UnifiedDevice。
    private func entryMatches(_ entry: DeviceSession.Entry, _ dev: UnifiedDevice) -> Bool {
        if let did = dev.deviceID, entry.deviceID == did { return true }
        if let ble = dev.ble?.identifier, entry.bleIdentifier == ble { return true }
        if let host = dev.bonjour?.hostName, entry.host == host { return true }
        return false
    }

    @objc private func bonjourDidFail(_ notification: Notification) {
        let code = (notification.object as? Int) ?? -1
        Log.error("DeviceScan", "bonjour failed errorCode=\(code)")
        DevicePermissionGuide.handleLocalNetworkFailure(from: self)
    }

    @objc private func bleDidFail(_ notification: Notification) {
        let stateRaw = (notification.object as? Int) ?? -1
        Log.error("DeviceScan", "ble failed centralState=\(stateRaw)")
        DevicePermissionGuide.handleBluetoothFailure(state: stateRaw, from: self)
    }

    /// 本机残留的配对信息在设备侧已不存在 —— 链路层加密协商必然失败，App 无论怎么重试都连不上，
    /// 只有用户去系统设置里「忽略此设备」才能恢复。去重与冷却由 BLEDiscovery 负责。
    @objc private func bleDidDetectStalePairing(_ notification: Notification) {
        guard viewIfLoaded?.window != nil, presentedViewController == nil else { return }
        let name = (notification.object as? String) ?? L("device_manage.default_name")
        Log.error("DeviceScan", "配对信息失效 → 提示用户忽略设备 name=\(name)")
        let alert = CustomAlertViewController(
            title: L("device_scan.stale_pairing.title"),
            description: String(format: L("device_scan.stale_pairing.message"), name),
            confirmButtonTitle: L("permission.open_settings"),
            cancelButtonTitle: L("common.ok"),
            onConfirm: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            },
            onCancel: nil
        )
        present(alert, animated: true)
    }

    private func refreshDevices() {
        let entries = DeviceSession.shared.entries
        let discovered = UnifiedDeviceDiscovery.shared.devices.filter { $0.hasWifi || $0.hasBle }
        let reachableIDs = Set(UnifiedDeviceDiscovery.shared.devices.compactMap { $0.deviceID })

        var result: [Row] = []

        // 1) 持久化 entries 永远先列出来。状态由 (isReachable, isUserDisconnected) 联合
        //    决定——只有"网络可达"+"用户没主动断开"两个条件同时满足才算"已连接"。
        for entry in entries {
            let isReachable = entry.deviceID.map { reachableIDs.contains($0) } ?? false
            let isUserDisc = entry.isUserDisconnected ?? false
            let effectivelyConnected = isReachable && !isUserDisc
            let matched = discovered.first { entryMatches(entry, $0) }
            // id 兜底优先 deviceID（最稳定），然后是 bleIdentifier / host
            let id = entry.deviceID
                ?? entry.bleIdentifier?.uuidString
                ?? entry.host
                ?? "entry:\(ObjectIdentifier(entries as AnyObject).hashValue)"
            let displayName = entry.displayName ?? entry.model ?? L("device_manage.default_name")
            result.append(Row(
                id: id,
                displayName: displayName,
                state: effectivelyConnected ? .boundReachable : .boundUnreachable,
                kind: .bound(entry, matchedDevice: matched)
            ))
        }

        // 2) 已发现但未绑定的设备：
        //    - device_id 还没读到的设备先跳过（BLE 还在跑 connect+read characteristic 的
        //      1-3 秒过渡期；Bonjour TXT 还在 resolve 的窗口）。这些没有稳定 id 的条目
        //      绑了也没法 dedup，强行展示就会"闪一下消失"或在 id 一到时被合并改名。
        //    - 跟任一持久化 entry 命中标识符就跳过（避免同一物理设备既出现在 bound 段又
        //      出现在 discovered 段）
        for dev in discovered {
            guard let did = dev.deviceID, !did.isEmpty else { continue }
            _ = did
            if entries.contains(where: { entryMatches($0, dev) }) { continue }
            let state: BindStatus = bindingIDs.contains(dev.id) ? .binding : .notBound
            result.append(Row(
                id: dev.id,
                displayName: displayedName(for: dev),
                state: state,
                kind: .discovered(dev)
            ))
        }

        rows = result
        // 行数 > 0 → 清掉搜索超时（持久化设备永远占非空行，timeout 只对纯首次用户生效）
        if !rows.isEmpty {
            searchTimeoutTimer?.invalidate()
            searchTimeoutTimer = nil
            searchTimedOut = false
        }
        tableView.reloadData()
    }

    private func startSearchTimer() {
        searchTimeoutTimer?.invalidate()
        searchTimedOut = false
        searchTimeoutTimer = Timer.scheduledTimer(withTimeInterval: searchTimeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            // Re-check 一次：超时回调跑到时可能刚好有 didUpdate 把设备塞进来了，避免显示
            // 一个"未发现设备"然后立刻又被覆盖成实际设备列表的尴尬闪烁。
            guard self.rows.isEmpty else { return }
            Log.info("DeviceScan", "search timeout reached, no devices found after \(Int(self.searchTimeout))s")
            self.searchTimedOut = true
            self.tableView.reloadData()
            self.autoPromptBluetoothIfDenied()
        }
    }

    private func retrySearch() {
        Log.info("DeviceScan", "user tapped retry")
        DevicePermissionGuide.checkBluetoothOnEnter(from: self)
        UnifiedDeviceDiscovery.shared.reset()
        refreshDevices()
        startSearchTimer()
    }

    /// 已发现但未绑定的设备显示名：优先持久化的 nickname 记忆（之前绑过、改过名又断开
    /// 的设备能恢复昵称），回落到扫描层的型号名。已绑定 entries 的 displayName 直接走
    /// entry.displayName，不走这里。
    private func displayedName(for dev: UnifiedDevice) -> String {
        if let did = dev.deviceID,
           let remembered = DeviceSession.shared.rememberedNickname(forDeviceID: did) {
            return remembered
        }
        return dev.displayName
    }

    // MARK: - Bind / Exit

    private func bindDevice(_ dev: UnifiedDevice) {
        Log.info("DeviceScan", "tap to bind \(dev.displayName) transport=\(dev.transportLabel)")
        bindingIDs.insert(dev.id)
        refreshDevices()    // 立刻切到 spinner

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            DeviceSession.shared.connect(
                bonjour: dev.bonjour,
                bleIdentifier: dev.ble?.identifier,
                deviceID: dev.deviceID,
                model: dev.model,
                displayName: dev.displayName
            )
            self.bindingIDs.remove(dev.id)
            // DeviceSession.connect 已经发了 didChangeNotification → sessionDidChange →
            // refreshDevices；这里不必再 reload。Row 从 .discovered 段挪到 .bound 段是
            // refreshDevices 内部自动算出来的。
            self.showConnected(for: dev)
        }
    }

    /// 绑定成功进「已连接」页（设计稿 侧边栏 4）。connect() 没有任何传输通道时会直接忽略，那种情况留在列表页。
    /// 名字优先取绑定后的条目（重新绑定会恢复用户改过的昵称），对不上再用列表里显示的名字。
    private func showConnected(for dev: UnifiedDevice) {
        guard dev.bonjour != nil || dev.ble != nil, let nav = navigationController else { return }
        let entry = DeviceSession.shared.entries.first { entry in
            if let did = dev.deviceID, entry.deviceID == did { return true }
            if let ble = dev.ble?.identifier, entry.bleIdentifier == ble { return true }
            return false
        }
        let name = entry?.displayName ?? displayedName(for: dev)
        nav.pushViewController(DeviceConnectedViewController(deviceName: name, mode: mode), animated: true)
    }

    private func showDetail(for row: Row) {
        let detail: DeviceDetailViewController
        switch row.kind {
        case .bound(let entry, _):
            detail = DeviceDetailViewController(entry: entry)
        case .discovered(let dev):
            detail = DeviceDetailViewController(unified: dev)
        }
        if let nav = navigationController {
            nav.pushViewController(detail, animated: true)
        } else {
            // 兜底：本页是 SideMenu 直接 present 出来的（presented modal），用一个临时 nav 包装
            // 一下让 detail 也走 push pop。极少触发。
            let wrappedNav = UINavigationController(rootViewController: detail)
            wrappedNav.modalPresentationStyle = .fullScreen
            present(wrappedNav, animated: true)
        }
    }

    @objc private func didTapClose() {
        closeButton.animateButtonTap { [weak self] in
            guard let self else { return }
            switch self.mode {
            case .management:
                // 管理模式：回 DM。pushed 进来就 pop，presented 就 dismiss。
                if let nav = self.navigationController, nav.viewControllers.first != self {
                    nav.popViewController(animated: true)
                } else {
                    self.dismiss(animated: true)
                }
            case .onboarding:
                // 引导模式：X = "完成 onboarding，进主 App"——不论用户绑没绑设备都进
                // 主 tab，跟 OnboardingExitButton 默认行为一致。用户主动选择退出，
                // 即使空账户也允许进入（后续在主界面 DM 入口可继续绑）。
                OnboardingExitButton.completeOnboarding()
            }
        }
    }


}

// MARK: - UITableView
extension DeviceScanViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // 0 行时显示一行 "正在搜索..." / "未发现设备" 占位，让 section 始终至少有一行可见
        rows.isEmpty ? 1 : rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        L("device_scan.section.my_devices")
    }

    /// 让系统 insetGrouped section header 在深底色下变成白字（默认是浅灰几乎看不见）。
    /// 文字位置由系统自动对齐到 cell 内容左边沿，不再手写 layout。
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = UIColor(white: 1.0, alpha: 0.65)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DeviceScanCell.identifier, for: indexPath) as! DeviceScanCell
        if rows.isEmpty {
            if searchTimedOut {
                cell.configureAsNoResults()
            } else {
                cell.configureAsSearchingPlaceholder()
            }
        } else {
            let row = rows[indexPath.row]
            cell.configure(name: row.displayName, status: row.state)
            cell.onInfoTap = { [weak self] in
                self?.showDetail(for: row)
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !rows.isEmpty else {
            // 占位行：超时状态下 tap = 重试；搜索中 spinner 状态下不响应
            if searchTimedOut { retrySearch() }
            return
        }
        let row = rows[indexPath.row]
        switch row.state {
        case .notBound:
            // 已发现但未绑定 → tap = 绑定
            if case .discovered(let dev) = row.kind { bindDevice(dev) }
        case .boundReachable, .boundUnreachable:
            // 已绑定 → tap = toggle isUserDisconnected，跟 DM cell statusContainer 同款行为
            // 可达 + 已断 → 翻回 connected，立刻看到状态变 "已连接"
            // 可达 + 已连 → 标 disconnect，立刻看到 "未连接"
            // 不可达 → toggle 还是发生（设备恢复在线时会按新意图自动渲染），UI 暂时不变
            if case .bound(let entry, _) = row.kind {
                let current = entry.isUserDisconnected ?? false
                DeviceSession.shared.setUserDisconnected(entry, to: !current)
            }
        case .binding:
            // 绑定动画期间不响应
            break
        }
    }

    // ⓘ tap 现在走 cell.onInfoTap closure（自挂 accessoryView 路径），不再依赖系统的
    // accessoryButtonTappedForRowWith。整行 tap = 绑定；ⓘ tap = 详情，跟 iOS 蓝牙同款 UX。
}

/// 深底色 cell：左侧 17pt 白色设备名，右侧 17pt 灰色状态（"未连接" / "已连接"）。
/// 正在绑定时右侧换 UIActivityIndicatorView。selectedBackgroundView 用浅白高亮。
private final class DeviceScanCell: UITableViewCell {
    static let identifier = "DeviceScanCell"

    /// 用户点击右侧 ⓘ 时触发 → VC 推详情页。系统 accessoryType = .detailButton 默认 ~22pt
    /// 在 17pt 文字旁边显得偏大；改成 accessoryView 自挂一个 18pt SF Symbol info.circle
    /// 让视觉比例协调。tap 通过 closure 上抛 VC，绕开 table delegate 的
    /// accessoryButtonTappedForRowWith 路径。
    var onInfoTap: (() -> Void)?

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = UIColor(white: 1.0, alpha: 0.55)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = UIColor(white: 1.0, alpha: 0.7)
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        // 深底色下半透明白卡片背景，跟 DeviceDetail 的 DetailValueCell 同款
        backgroundColor = UIColor(white: 1.0, alpha: 0.08)
        let bg = UIView()
        bg.backgroundColor = UIColor(white: 1.0, alpha: 0.14)
        selectedBackgroundView = bg

        attachInfoAccessory()

        contentView.addSubview(nameLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(spinner)
        NSLayoutConstraint.activate([
            // insetGrouped 系统自动处理 cell 外圈 inset，内部文字 16pt padding 即可。
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 12),

            spinner.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 自挂 18pt SF Symbol info.circle 当 accessoryView——比系统 .detailButton 小一圈、
    /// 跟 17pt 文字更协调。蓝色用全 App 统一的"操作蓝"。
    private func attachInfoAccessory() {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        let image = UIImage(systemName: "info.circle", withConfiguration: config)?
            .withTintColor(UIColor(red: 0.40, green: 0.78, blue: 1.0, alpha: 1.0),
                           renderingMode: .alwaysOriginal)
        let button = UIButton(type: .custom)
        button.setImage(image, for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 28, height: 28)   // 给一点 hit area
        button.addTarget(self, action: #selector(infoButtonTapped), for: .touchUpInside)
        accessoryView = button
    }

    @objc private func infoButtonTapped() {
        onInfoTap?()
    }

    func configure(name: String, status: DeviceScanViewController.BindStatus) {
        nameLabel.text = name
        nameLabel.textColor = .white
        // statusLabel 颜色每次都重置回灰色——cell 从 configureAsNoResults 复用过来时会
        // 残留蓝色（操作蓝那条"点击重试"），否则下一次"已连接"也会变蓝。
        statusLabel.textColor = UIColor(white: 1.0, alpha: 0.55)
        if accessoryView == nil { attachInfoAccessory() }  // 占位 → 正常态时重新挂上
        switch status {
        case .notBound:
            // 已发现未绑定 → 整行可点击触发绑定
            statusLabel.text = L("device_scan.status.not_connected")
            statusLabel.isHidden = false
            spinner.stopAnimating()
            selectionStyle = .default
        case .binding:
            statusLabel.text = nil
            statusLabel.isHidden = true
            spinner.startAnimating()
            selectionStyle = .none
        case .boundReachable:
            // 已绑定 + 在场 → 灰色"已连接"（不变蓝），tap 切到 disconnect
            statusLabel.text = L("device_scan.status.connected")
            statusLabel.isHidden = false
            spinner.stopAnimating()
            selectionStyle = .default
        case .boundUnreachable:
            // 已绑定但离开范围 / 用户主动断开 → 灰色"未连接"，tap toggle 回 connected
            statusLabel.text = L("device_scan.status.not_connected")
            statusLabel.isHidden = false
            spinner.stopAnimating()
            selectionStyle = .default
        }
    }

    /// 0 设备时的占位行：左侧 "正在搜索附近设备..." 灰字 + 右侧 spinner。整行不可选、无 ⓘ。
    func configureAsSearchingPlaceholder() {
        nameLabel.text = L("device_scan.searching")
        nameLabel.textColor = UIColor(white: 1.0, alpha: 0.55)
        statusLabel.text = nil
        statusLabel.isHidden = true
        spinner.startAnimating()
        selectionStyle = .none
        accessoryView = nil
        onInfoTap = nil
    }

    /// 超时后的"未发现设备"占位行：spinner 停转，右侧 "点击重试" 蓝色提示，整行可点。
    /// tap 由外层 VC 在 didSelectRowAt 里识别 searchTimedOut 状态触发 retrySearch。
    func configureAsNoResults() {
        nameLabel.text = L("device_scan.no_devices_found")
        nameLabel.textColor = UIColor(white: 1.0, alpha: 0.55)
        statusLabel.text = L("device_scan.tap_to_retry")
        statusLabel.textColor = UIColor(red: 0.40, green: 0.78, blue: 1.0, alpha: 1.0)
        statusLabel.isHidden = false
        spinner.stopAnimating()
        selectionStyle = .default
        accessoryView = nil
        onInfoTap = nil
    }
}
