
import UIKit

class DeviceManagementViewController: UIViewController {

    // MARK: - Design Constants
    private let designWidth: CGFloat = 750
    private let designHeight: CGFloat = 1624
    
    // MARK: - Models
    struct DeviceItem: Equatable {
        let name: String
        let imageName: String
        /// 当前是否在网络范围内（Bonjour 或 BLE 任一信道见到）。
        let isReachable: Bool
        /// 用户主动断开标志。结合 isReachable 决定显示状态：
        ///   isReachable && !isUserDisconnected → "Connected"（白 + device_connect 图标）
        ///   else                               → "Not Connected"（灰 + wifi.slash 图标）
        let isUserDisconnected: Bool
    }

    private var devices: [DeviceItem] = []

    /// 进入设备页时要定位到的设备序号（首页点哪台带哪台；与 DeviceSession.entries 顺序一致）。
    var initialDeviceIndex: Int = 0
    private var didApplyInitialScroll = false
    
    // MARK: - UI Components
    
    private let backButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton()
        button.setImage(UIImage(named: "sub_back"), for: .normal)
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
        // 整张卡片不响应点击——避免点设备图片误触解绑。解绑入口限定在 cell 底部
        // 的 statusContainer（图标 + "Connected" 文案），由 cell 自己处理。
        cv.allowsSelection = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(DeviceManagementCell.self, forCellWithReuseIdentifier: DeviceManagementCell.identifier)
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    /// 空态背景大图：DM 空态时显示在 "No device connected" 标题上方。
    /// 跟 Android DeviceEmptyState 视觉一致：60% 屏宽、正方形、alpha 0.25 淡化。
    private let emptyDeviceImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "device")
        iv.contentMode = .scaleAspectFit
        iv.alpha = 0.25
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var emptyStateView: UIStackView = {
        let titleLabel = UILabel()
        titleLabel.text = L("device_manage.empty.title")
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        // 跟 Android 一致：20pt semibold
        titleLabel.font = UIFont(name: "PingFangSC-Medium", size: 20) ?? .systemFont(ofSize: 20, weight: .semibold)

        let messageLabel = UILabel()
        messageLabel.text = L("device_manage.empty.message")
        messageLabel.textColor = UIColor(white: 1.0, alpha: 0.6)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)

        let stack = UIStackView(arrangedSubviews: [emptyDeviceImageView, titleLabel, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        // 图 → 标题 36pt 间距（跟 Android Spacer(36.dp) 一致），标题 → 副文案 12pt 用默认
        stack.setCustomSpacing(36, after: emptyDeviceImageView)
        stack.isHidden = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// 自定义分页指示器：当前页白色长条 + 其余灰色圆点（匹配设计稿）。
    private let pageControl: PageIndicatorView = {
        let pc = PageIndicatorView()
        pc.numberOfPages = 0
        pc.currentPage = 0
        pc.isUserInteractionEnabled = false
        pc.translatesAutoresizingMaskIntoConstraints = false
        return pc
    }()

    // 顶部设备名（随分页切换而更新）
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        // text_3: PingFangSC-Regular 48px=24pt
        label.font = UIFont(name: "PingFangSC-Regular", size: 24) ?? .systemFont(ofSize: 24)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // 副标题 text_4：SourceHanSansCN-Light 24px=12pt，两行
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("device_manage.subtitle")
        label.textColor = UIColor(white: 1.0, alpha: 0.5)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont(name: "PingFangSC-Light", size: 12) ?? .systemFont(ofSize: 12, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // 主操作按钮（白底）：已连接→断开连接 / 未连接→连接设备
    private let primaryButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.setTitleColor(UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0), for: .normal)
        // text_5: 28px=14pt（放大屏取 15pt）
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15)
        button.layer.cornerRadius = 24
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // 次操作按钮（灰底）：已连接→连接其他设备 / 未连接→搜索设备
    private let secondaryButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(red: 70/255.0, green: 70/255.0, blue: 70/255.0, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15)
        button.layer.cornerRadius = 24
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // 删除当前设备（text_6：SourceHanSansCN-Medium 28px=14pt，#FF5A59，居中纯文字）
    private let deleteButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton()
        button.setTitle(L("device_manage.button.delete_device"), for: .normal)
        button.setTitleColor(UIColor(red: 255/255, green: 90/255, blue: 89/255, alpha: 1.0), for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceSessionDidChange),
            name: DeviceSession.didChangeNotification,
            object: nil
        )
        reloadDevices()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 启动 discovery 给 DM 提供心跳：用当前可达的 device_id 集合来判定每条 entry 的
        // reachable 状态。手机走出网络范围（Wi-Fi 断开 / BLE 出距离），对应设备会从
        // "已连接"自动变成"未连接"。
        // 权限兜底见 viewDidAppear（这里首次 present 时 view 还没进 window，弹窗会被跳过）。
        UnifiedDeviceDiscovery.shared.startContinuous()
        NotificationCenter.default.addObserver(
            self, selector: #selector(discoveryDidUpdate),
            name: UnifiedDeviceDiscovery.didUpdateNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(dmBonjourDidFail(_:)),
            name: BonjourDiscovery.didFailNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(dmBleDidFail(_:)),
            name: BLEDiscovery.didFailNotification, object: nil
        )
        // Catch session changes that may have happened while another VC was on top
        // (e.g. user just finished the Connect flow).
        reloadDevices()
        // 用户进设备管理页就再扫一遍所有已绑 entry——之前没成功推 JWT 到设备的（首次启动
        // 这版代码、token 刚刷新、设备之前不可达等）这里强制再试一次。指纹匹配的会被
        // pusher 内部 skip，所以不会浪费请求。
        DeviceLoginPusher.shared.pushPendingForAllEntries()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 权限兜底：这两个权限已从开屏挪到设备流程里申请，被拒过的用户系统不会再弹
        // 原生授权框，没有这层引导他只会看到一个永远「未连接」的列表且得不到解释。
        // 每次打开设备页只自动提示一次：从扫描页返回时不再重复弹。
        guard !didAutoPromptBluetooth else { return }
        if DevicePermissionGuide.checkBluetoothOnEnter(from: self) { didAutoPromptBluetooth = true }
    }

    private var didAutoPromptBluetooth = false

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 只摘 observer，不 stop discovery——push 到 DeviceScan / Detail 等子页时
        // discovery 持续跑，子页能立刻拿到 DM 累积的 discovery 状态（避免 Scan
        // 进页面时看到两台设备瞬间从"已连接/未连接"变成"全未连"的过渡态）。
        // 真正的 stop 留到 deinit——DM 被 dismiss 出 nav 栈时才停。
        NotificationCenter.default.removeObserver(
            self, name: UnifiedDeviceDiscovery.didUpdateNotification, object: nil
        )
    }

    @objc private func discoveryDidUpdate() {
        reloadDevices()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update layout if needed
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = collectionView.bounds.size
        }
        applyInitialScrollIfNeeded()
    }

    /// 首次布局完成且设备已加载时，滚动到 initialDeviceIndex 指定的那台（仅执行一次，之后用户可自由左右滑）。
    private func applyInitialScrollIfNeeded() {
        guard !didApplyInitialScroll, !devices.isEmpty, collectionView.bounds.width > 0 else { return }
        let target = min(max(0, initialDeviceIndex), devices.count - 1)
        if target > 0 {
            collectionView.scrollToItem(at: IndexPath(item: target, section: 0), at: .centeredHorizontally, animated: false)
            pageControl.currentPage = target
            updateForCurrentPage()
        }
        didApplyInitialScroll = true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // 不再在此 stop discovery：discovery 生命周期已由 SceneDelegate 统一管理（前台常开），
        // 保证 DeviceLoginPusher 心跳补推不会因离开设备页而中断（token 同步可靠性关键）。
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // CSS: .page { background-color: rgba(24, 24, 24, 1); }
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        
        // Add Subviews
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(collectionView)
        view.addSubview(emptyStateView)
        view.addSubview(pageControl)
        view.addSubview(primaryButton)
        view.addSubview(secondaryButton)
        view.addSubview(deleteButton)

        setupConstraints()
    }

    // MARK: - Data

    private var didLoadDevicesOnce = false

    private func reloadDevices() {
        let entries = DeviceSession.shared.entries
        // 当前可达的 device_id 集合：Bonjour TXT / BLE characteristic 已读到 device_id 的设备
        let reachableIDs = Set(UnifiedDeviceDiscovery.shared.devices.compactMap { $0.deviceID })

        let newDevices: [DeviceItem]
        if !entries.isEmpty {
            // 绑过几台显示几张卡片，左右滑动切换（CollectionView 已经 isPagingEnabled = true）。
            // 没存 displayName 的老条目回退到 default_name 占位。
            // reachable 状态：entry.deviceID 命中当前 discovery 集合就算可达；nil device_id
            // 的老条目无法核验，默认 not reachable。
            newDevices = entries.map { entry in
                let reachable = entry.deviceID.map { reachableIDs.contains($0) } ?? false
                return DeviceItem(
                    name: entry.displayName ?? L("device_manage.default_name"),
                    imageName: "device",
                    isReachable: reachable,
                    isUserDisconnected: entry.isUserDisconnected ?? false
                )
            }
        } else if Constants.Config.showMockData {
            // 预览用假设备：默认「未连接」，与真实默认一致（未绑定/未发现的设备都算断开），
            // 避免预览里误显示成已连接。想预览已连接布局时手动改 isReachable 即可。
            newDevices = [
                DeviceItem(name: L("device_manage.default_name"), imageName: "device",
                           isReachable: false, isUserDisconnected: false)
            ]
        } else {
            newDevices = []
        }

        // 列表无变化就不 reloadData——discovery 现在前台常开、更新很频繁，无脑 reload 会在用户
        // 触摸/滑动时把 cell 反复销毁重建，触发 hitTest 访问已释放 cell 而崩溃。
        if didLoadDevicesOnce && newDevices == devices { return }
        didLoadDevicesOnce = true
        devices = newDevices
        applyDevicesState()
    }

    private func applyDevicesState() {
        let isEmpty = devices.isEmpty
        emptyStateView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
        titleLabel.isHidden = isEmpty
        subtitleLabel.isHidden = isEmpty

        pageControl.numberOfPages = devices.count
        // 仅多台设备（≥2）时显示翻页指示器；单台或空态隐藏
        pageControl.isHidden = devices.count <= 1
        if pageControl.currentPage >= devices.count {
            pageControl.currentPage = max(0, devices.count - 1)
        }
        collectionView.reloadData()
        updateForCurrentPage()
    }

    /// 根据当前分页的设备，刷新标题与两个按钮文案/样式。
    private func updateForCurrentPage() {
        if devices.isEmpty {
            // 空态：仅主按钮「连接设备」，隐藏次按钮
            primaryButton.setTitle(L("device_manage.button.connect_device"), for: .normal)
            secondaryButton.isHidden = true
            deleteButton.isHidden = true
            return
        }
        secondaryButton.isHidden = false
        let page = min(max(0, pageControl.currentPage), devices.count - 1)
        // 只有真实绑定的设备可删（mock 预览卡没有对应 entry）
        deleteButton.isHidden = page >= DeviceSession.shared.entries.count
        let device = devices[page]
        titleLabel.text = device.name

        let connected = device.isReachable && !device.isUserDisconnected
        if connected {
            primaryButton.setTitle(L("device_manage.button.disconnect"), for: .normal)
            secondaryButton.setTitle(L("device_manage.button.connect_other_device"), for: .normal)
        } else {
            primaryButton.setTitle(L("device_manage.button.connect_device"), for: .normal)
            secondaryButton.setTitle(L("device_manage.button.search_device"), for: .normal)
        }
    }

    @objc private func deviceSessionDidChange() {
        reloadDevices()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Back Button (Top Left)
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 24),
            backButton.heightAnchor.constraint(equalToConstant: 24),

            // 标题 + 副标题
            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 36),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -30),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 30),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -30)
        ])

        // 底部两个按钮（次按钮在下）。设计稿按钮左右边距 33pt（66/73px≈18pt页边距 + 容器），
        // 高 48pt 圆角 24pt，按钮间距 18pt（box_11 margin 36px），底部留白约屏高 12%（padding-bottom 200px）。
        NSLayoutConstraint.activate([
            secondaryButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -112),
            secondaryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 33),
            secondaryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -33),
            secondaryButton.heightAnchor.constraint(equalToConstant: 48),

            primaryButton.bottomAnchor.constraint(equalTo: secondaryButton.topAnchor, constant: -18),
            primaryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 33),
            primaryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -33),
            primaryButton.heightAnchor.constraint(equalToConstant: 48),

            // 删除该设备：位于次按钮下方 30pt（text-wrapper_6 margin-top 60px），水平居中
            deleteButton.topAnchor.constraint(equalTo: secondaryButton.bottomAnchor, constant: 30),
            deleteButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deleteButton.heightAnchor.constraint(equalToConstant: 21) // line-height 42px
        ])

        // Collection View（设备图片分页，居上半部，设计稿设备图约占屏高 30%、中心在 38% 处）
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.34)
        ])

        // Page indicator（紧贴设备图下方）
        NSLayoutConstraint.activate([
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 12),
            pageControl.heightAnchor.constraint(equalToConstant: 18)
        ])

        // Empty state
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),

            emptyDeviceImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),
            emptyDeviceImageView.heightAnchor.constraint(equalTo: emptyDeviceImageView.widthAnchor),
        ])
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        primaryButton.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(didTapSecondary), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        // 点击顶部设备名 → 进入名称编辑页
        titleLabel.isUserInteractionEnabled = true
        titleLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapDeviceName)))
    }

    /// 点击设备名进入昵称编辑页（仅真实 entry，mock 卡不响应）。
    @objc private func didTapDeviceName() {
        let entries = DeviceSession.shared.entries
        let page = min(max(0, pageControl.currentPage), max(0, devices.count - 1))
        guard page < entries.count else { return }
        let edit = DeviceNicknameEditViewController(entry: entries[page])
        navigationController?.pushViewController(edit, animated: true)
    }

    // MARK: - Actions

    @objc private func dmBonjourDidFail(_ notification: Notification) {
        let code = (notification.object as? Int) ?? -1
        Log.error("DeviceManagement", "bonjour failed errorCode=\(code)")
        DevicePermissionGuide.handleLocalNetworkFailure(from: self)
    }

    @objc private func dmBleDidFail(_ notification: Notification) {
        let stateRaw = (notification.object as? Int) ?? -1
        Log.error("DeviceManagement", "ble failed centralState=\(stateRaw)")
        DevicePermissionGuide.handleBluetoothFailure(state: stateRaw, from: self)
    }

    @objc private func didTapBack() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

    /// 主按钮：已连接→断开；未连接→连接（重连）。空态→进扫描页。
    @objc private func didTapPrimary() {
        primaryButton.animateButtonTap {
            let entries = DeviceSession.shared.entries
            guard !self.devices.isEmpty else {
                self.openScan()
                return
            }
            let page = min(max(0, self.pageControl.currentPage), self.devices.count - 1)
            guard page < entries.count else {
                // mock 卡或越界：退化为进扫描页
                self.openScan()
                return
            }
            let entry = entries[page]
            let current = entry.isUserDisconnected ?? false
            DeviceSession.shared.setUserDisconnected(entry, to: !current)
            // setUserDisconnected 会触发 didChangeNotification → reloadDevices → 刷新按钮
        }
    }

    /// 次按钮：连接其他设备 / 搜索设备 —— 均进扫描页。
    @objc private func didTapSecondary() {
        secondaryButton.animateButtonTap {
            self.openScan()
        }
    }

    /// 删除当前分页的设备：先弹确认，确认后从 DeviceSession 移除（didChange → reloadDevices 自动刷新/回落空态）。
    @objc private func didTapDelete() {
        let entries = DeviceSession.shared.entries
        let page = min(max(0, pageControl.currentPage), max(0, devices.count - 1))
        guard page < entries.count else { return }
        DeviceDeletePrompt.present(entry: entries[page])
    }

    private func openScan() {
        // DM 入口跳过原 RegisterP4 介绍页，直接进扫描+选择页。
        let vc = DeviceScanViewController(mode: .management)
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    // MARK: - Helpers
    private func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        let capped = iPadAdaptiveScale.capped(dimension, widthReference: view.bounds.width)
        return (capped * designValue) / designDimension
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
        // 三个 cell-level 回调仅给真实 entries 那几张卡，mock 卡不挂回调。
        let entries = DeviceSession.shared.entries
        if indexPath.item < entries.count {
            let entry = entries[indexPath.item]
            cell.onStatusTap = {
                // toggle 模式：Connected ↔ Disconnected 直接翻转，无确认弹窗。
                // entry 一直留在 entries 里——DM 列表不会消失，下次想重连直接再点回来。
                let current = entry.isUserDisconnected ?? false
                DeviceSession.shared.setUserDisconnected(entry, to: !current)
            }
            cell.onNameTap = { [weak self] in
                let edit = DeviceNicknameEditViewController(entry: entry)
                self?.navigationController?.pushViewController(edit, animated: true)
            }
            cell.onImageTap = { [weak self] in
                let detail = DeviceDetailViewController(entry: entry)
                self?.navigationController?.pushViewController(detail, animated: true)
            }
        }
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 让 pageControl 跟着滑动同步当前页
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }
        let page = Int(round(scrollView.contentOffset.x / pageWidth))
        if pageControl.currentPage != page {
            pageControl.currentPage = page
            updateForCurrentPage()
        }
    }

}

// MARK: - Cell

class DeviceManagementCell: UICollectionViewCell {
    static let identifier = "DeviceManagementCell"

    /// 用户点击底部 statusContainer（图标 + "Connected" 文案）时调用。
    /// nil 表示当前 cell 不响应（例如 mock 卡片）。
    var onStatusTap: (() -> Void)?

    /// 顶部设备名 tap → push 昵称编辑子页。mock 卡不挂回调。
    var onNameTap: (() -> Void)?

    /// 中部设备图片 tap → push 设备详情页（跟 DeviceScan 列表点 ⓘ 同款）。mock 卡不挂回调。
    var onImageTap: (() -> Void)?

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // 连接状态徽标：白底圆 + 绿色链（已连接）/ 灰色断链（未连接），叠在设备图右下。
    private let linkBadge: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // 徽标定位锚点（贴 imageView 左上角，宽/高为图片 84%/95%，右下角=徽标中心）。
    private let badgeAnchorGuide = UILayoutGuide()

    // imageView 宽高比约束，随实际图片在 configure() 中重设，使 frame 紧贴画面无留白。
    private var imageAspectConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onStatusTap = nil
        onNameTap = nil
        onImageTap = nil
    }

    @objc private func imageTapped() {
        onImageTap?()
    }

    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(linkBadge)

        // 中部图片 tap → 设备详情（跟 DeviceScan ⓘ 同款）
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        )

        // 徽标位于设备图「右下角边缘」（设计稿约设备宽 84%、高 95% 处，半压底边）。
        // imageView 宽度是 contentView 宽度的固定比例（0.5），iPad 上 contentView 更宽、
        // 图片随之放大；徽标若用固定点偏移（如 73/88pt）只在设计稿尺寸下准确，放大后偏移量
        // 相对图片显得太小，徽标会缩到图片中间。改用「贴着图片左上角、宽/高为图片 84%/95%」
        // 的 guide，其右下角即徽标中心 = 图片 (84%, 95%) 处，随图片尺寸等比缩放。
        //
        // 注意：guide 从左上角起、右下角 = (84%,95%)，才能精确落在设计稿百分比；若用居中
        // guide，其右下角会落在 (50%+42%, 50%+47.5%)=(92%,97.5%)，偏出设备（之前的 bug）。
        // 同时 imageView frame 必须紧贴图片真实宽高比（见 configure 里的 aspect 约束），
        // 否则 .scaleAspectFit 会在方形 frame 内上下留白，按 frame 百分比定位的徽标会掉进留白里。
        imageView.addLayoutGuide(badgeAnchorGuide)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.5),
            // 高度由 configure() 按图片真实宽高比设定，使 frame 紧贴画面（无留白）。

            badgeAnchorGuide.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            badgeAnchorGuide.topAnchor.constraint(equalTo: imageView.topAnchor),
            badgeAnchorGuide.widthAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.84),
            badgeAnchorGuide.heightAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 0.95),

            linkBadge.widthAnchor.constraint(equalToConstant: 32),
            linkBadge.heightAnchor.constraint(equalToConstant: 32),
            linkBadge.centerXAnchor.constraint(equalTo: badgeAnchorGuide.trailingAnchor),
            linkBadge.centerYAnchor.constraint(equalTo: badgeAnchorGuide.bottomAnchor)
        ])
    }

    func configure(with item: DeviceManagementViewController.DeviceItem) {
        let image = UIImage(named: item.imageName)
        imageView.image = image

        // frame 紧贴图片真实宽高比，消除 .scaleAspectFit 在方形 frame 内的上下留白，
        // 让上面按百分比定位的徽标精确落在设备右下角边缘。
        imageAspectConstraint?.isActive = false
        if let size = image?.size, size.width > 0 {
            let c = imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor,
                                                      multiplier: size.height / size.width)
            c.isActive = true
            imageAspectConstraint = c
        }

        let effectivelyConnected = item.isReachable && !item.isUserDisconnected
        linkBadge.image = UIImage(named: effectivelyConnected ? "device_link_conn" : "device_link_disc")
    }
}

// MARK: - 删除设备确认

/// 删除设备的确认弹窗（首页左滑删除、设备页「删除该设备」共用）。
/// 删除只移除本机绑定记录，昵称记忆保留（同 DeviceSession.remove 语义），之后可重新配对。
enum DeviceDeletePrompt {
    static func present(entry: DeviceSession.Entry,
                        onCancel: (() -> Void)? = nil,
                        beforeDelete: (() -> Void)? = nil) {
        let name = entry.displayName ?? L("device_manage.default_name")
        ConfirmDialogView.present(
            title: String(format: L("device_manage.delete.confirm_title"), name),
            message: "",
            outlineTitle: L("common.cancel"),
            solidTitle: L("common.confirm"),
            spacing: .titleOnly,
            singleLineTitle: true,
            onOutline: onCancel,
            onSolid: {
                Log.info("DeviceManagement", "user deleted device name=\(name) device_id=\(entry.deviceID ?? "nil")")
                beforeDelete?()
                DeviceSession.shared.remove(entry)
            }
        )
    }
}
