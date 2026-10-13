import UIKit

class UserProfileViewController: UIViewController {

    private lazy var deletionFlow = AccountDeletionFlow(presenter: self, actionButton: deleteAccountButton)

    // MARK: - Scaled Metrics Helper
    // Base design width is 375pt (750px)
    private var scale: CGFloat {
        return iPadAdaptiveScale.capped(UIScreen.main.bounds.width, widthReference: UIScreen.main.bounds.width) / 375.0
    }
    
    private func s(_ value: CGFloat) -> CGFloat {
        return value * scale
    }

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        return view
    }()
    
    // Header
    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Back Button
    private let backButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "sub_back"), for: .normal)
        return button
    }()
    
    // Title
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("user_profile.title")
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let scrollContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Avatar Container (White Circle)
    private let avatarContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.clipsToBounds = true
        return view
    }()
    
    // Avatar Image (Content)
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(named: "default_avatar")
        imageView.clipsToBounds = true
        return imageView
    }()
    
    // Username
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("user_profile.username_default")
        label.font = UIFont(name: "HKGrotesk-Bold", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    // Email
    private let emailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "HKGrotesk-Light", size: 11) ?? .systemFont(ofSize: 11, weight: .light)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    // Stack for rows
    private let rowsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0
        return stack
    }()
    
    // 删除账号（App Store 5.1.1(v) / Google Play 强制）。放个人资料页最底部，
    // 弱化为淡红文字，示意危险又不易误点。
    //
    // 设计稿（dev/侧边栏个人信息-新增身高体重）已经去掉了原来的「更新资料」按钮：
    // 每行改完都会走 scheduleAutoUpload 自动上传，那个按钮只是重复入口。
    private let deleteAccountButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("user_profile.delete"), for: .normal)
        // 稿子里是 28px/750 = 14pt、Medium、#FF5A59 不透明（和各行标题同字号）。
        button.setTitleColor(UIColor(red: 1.0, green: 90/255, blue: 89/255, alpha: 1.0), for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        return button
    }()
    
    // Rows
    private var userIdRow: UserProfileRowView!
    private var nicknameRow: UserProfileRowView!
    private var genderRow: UserProfileRowView!
    private var weightHeightRow: UserProfileRowView!
    private var birthdayRow: UserProfileRowView!
    private var emailRow: UserProfileRowView!
    private var phoneRow: UserProfileRowView!
    private var addressRow: UserProfileRowView!
    
    // State
    private var isDetailsHidden = false
    private var userDetails: [String: String] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupData()
        setupUI()
        updateVisibilityState()
        // 资料现在可能在本页之外被改写（服务端拉取回填、自动上传成功后的回写、
        // 地址页/问卷写地址簿），统一靠这个通知刷新，本页不再各处手动 refresh。
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleProfileDidUpdate),
                                               name: .userProfileDidUpdate,
                                               object: nil)
    }

    @objc private func handleProfileDidUpdate() {
        refreshProfileState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshProfileState()
        syncRemoteProfileIfNeeded()
        // 两件事：地址是在独立页面改的（改完只会走到这里，没有 onSave 回调），
        // 以及上次自动上传失败留下的脏改动在这里重试。
        UserProfileSync.scheduleAutoUpload(requireBaseline: true)
    }
    
    private func setupData() {
        userIdRow = UserProfileRowView(title: L("user_profile.user_id"), icon: "profile_detail")
        nicknameRow = UserProfileRowView(title: L("user_profile.nickname"), icon: "enter_icon")
        genderRow = UserProfileRowView(title: L("user_profile.gender"), icon: "enter_icon")
        weightHeightRow = UserProfileRowView(title: L("user_profile.weight_height"), icon: "enter_icon")
        // 年龄不再单独展示：改由生日推导，避免年龄/生日两处并存自相矛盾。
        birthdayRow = UserProfileRowView(title: L("user_profile.birthday"), icon: "enter_icon")
        // 邮箱是用户 ID，不可修改，右侧展示锁定图标而非可进入的箭头。
        emailRow = UserProfileRowView(title: L("user_profile.email"), icon: "lock_icon")
        phoneRow = UserProfileRowView(title: L("user_profile.phone"), icon: "enter_icon")
        addressRow = UserProfileRowView(title: L("user_profile.address"), icon: "enter_icon")

        refreshProfileState()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        
        view.addSubview(scrollView)
        scrollView.addSubview(scrollContentView)
        
        scrollContentView.addSubview(avatarContainer)
        avatarContainer.addSubview(avatarImageView)
        
        scrollContentView.addSubview(nameLabel)
        scrollContentView.addSubview(emailLabel)
        
        scrollContentView.addSubview(rowsStack)
        
        let rows = [userIdRow, nicknameRow, genderRow, weightHeightRow, birthdayRow, emailRow, phoneRow, addressRow]
        
        for (_, row) in rows.enumerated() {
            guard let row = row else { continue }
            rowsStack.addArrangedSubview(row)
            
            // Add Separator
            // Design Spec:
            // Row Height is reduced to ~25pt.
            // Spacing is ~9pt top and bottom.
            // Leading offset: -7.5pt from StackView leading
            let separator = UserProfileSeparatorView(width: s(330.5), leadingOffset: s(-7.5), verticalSpacing: s(9))
            rowsStack.addArrangedSubview(separator)
        }
        
        scrollContentView.addSubview(deleteAccountButton)

        setupConstraints()

        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        deleteAccountButton.addTarget(self, action: #selector(handleDeleteAccount), for: .touchUpInside)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleDetailsVisibility))
        userIdRow.isUserInteractionEnabled = true
        userIdRow.addGestureRecognizer(tapGesture)
        
        let nicknameTap = UITapGestureRecognizer(target: self, action: #selector(editNickname))
        nicknameRow.isUserInteractionEnabled = true
        nicknameRow.addGestureRecognizer(nicknameTap)
        
        let birthdayTap = UITapGestureRecognizer(target: self, action: #selector(editBirthday))
        birthdayRow.isUserInteractionEnabled = true
        birthdayRow.addGestureRecognizer(birthdayTap)
        
        let genderTap = UITapGestureRecognizer(target: self, action: #selector(editGender))
        genderRow.isUserInteractionEnabled = true
        genderRow.addGestureRecognizer(genderTap)
        
        let weightHeightTap = UITapGestureRecognizer(target: self, action: #selector(editWeightHeight))
        weightHeightRow.isUserInteractionEnabled = true
        weightHeightRow.addGestureRecognizer(weightHeightTap)
        
        let emailTap = UITapGestureRecognizer(target: self, action: #selector(editEmail))
        emailRow.isUserInteractionEnabled = true
        emailRow.addGestureRecognizer(emailTap)
        
        let phoneTap = UITapGestureRecognizer(target: self, action: #selector(editPhone))
        phoneRow.isUserInteractionEnabled = true
        phoneRow.addGestureRecognizer(phoneTap)
        
        let addressTap = UITapGestureRecognizer(target: self, action: #selector(editAddress))
        addressRow.isUserInteractionEnabled = true
        addressRow.addGestureRecognizer(addressTap)
        
        // Add gesture for avatar
        let avatarTap = UITapGestureRecognizer(target: self, action: #selector(handleAvatarTap))
        avatarContainer.isUserInteractionEnabled = true
        avatarContainer.addGestureRecognizer(avatarTap)
    }
    
    @objc private func handleAvatarTap() {
        let vc = AvatarSelectionViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.onAction = { [weak self] action in
            self?.handleAvatarAction(action)
        }
        present(vc, animated: false, completion: nil)
    }

    private func handleAvatarAction(_ action: AvatarSelectionViewController.Action) {
        switch action {
        case .camera:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .camera
            picker.allowsEditing = true
            present(picker, animated: true)
        case .album:
            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else { return }
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            picker.allowsEditing = true
            present(picker, animated: true)
        case .cancel:
            break
        }
    }
    
    @objc private func editAddress() {
        let vc = AddressListViewController()
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true, completion: nil)
    }
    
    @objc private func editNickname() {
        let vc = NicknameEditViewController()
        vc.currentNickname = userDetails["nickname"]
        vc.onSave = { [weak self] newName in
            self?.userDetails["nickname"] = newName
            self?.persistCurrentDraft()
            self?.updateVisibilityState()
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true, completion: nil)
    }
    
    @objc private func editBirthday() {
        let vc = BirthdayEditViewController()
        vc.currentBirthday = userDetails["birthday"]
        vc.onSave = { [weak self] newBirthday in
            self?.userDetails["birthday"] = newBirthday
            self?.persistCurrentDraft()
            self?.updateVisibilityState()
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true, completion: nil)
    }
    
    @objc private func editWeightHeight() {
        let vc = WeightHeightEditViewController()
        vc.currentWeight = userDetails["weight"]
        vc.currentHeight = userDetails["height"]
        vc.onSave = { [weak self] weight, height in
            self?.userDetails["weight"] = weight
            self?.userDetails["height"] = height
            self?.persistCurrentDraft()
            self?.updateVisibilityState()
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true, completion: nil)
    }
    
    @objc private func editGender() {
        let vc = GenderEditViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        vc.onSelectGender = { [weak self] gender in
            self?.userDetails["gender"] = gender
            self?.persistCurrentDraft()
            self?.updateVisibilityState()
        }
        present(vc, animated: true, completion: nil)
    }
    
    // 邮箱是账号 ID，不可编辑：跳转到独立的「邮箱」页（锁定态 + 删除账号入口）。
    @objc private func editEmail() {
        let vc = EmailViewController()
        vc.currentEmail = userDetails["email"]
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true, completion: nil)
    }
    
    @objc private func editPhone() {
        let vc = PhoneEditViewController()
        vc.currentPhone = userDetails["phone"]
        vc.onSave = { [weak self] newPhone in
            self?.userDetails["phone"] = newPhone
            self?.persistCurrentDraft()
            self?.updateVisibilityState()
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true, completion: nil)
    }

    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        // Avatar Container is 120px = 60pt
        avatarContainer.layer.cornerRadius = s(30)
        
        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: s(10)),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: s(18)),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: s(14)),
            backButton.heightAnchor.constraint(equalToConstant: s(14)),
            
            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: s(12)),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            scrollContentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            scrollContentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            scrollContentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrollContentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            scrollContentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Avatar Container: 120px (60pt) size, 74px (37pt) top margin
            avatarContainer.topAnchor.constraint(equalTo: scrollContentView.topAnchor, constant: s(37)),
            avatarContainer.centerXAnchor.constraint(equalTo: scrollContentView.centerXAnchor),
            avatarContainer.widthAnchor.constraint(equalToConstant: s(60)),
            avatarContainer.heightAnchor.constraint(equalToConstant: s(60)),
            
            // Avatar Image: fill container
            avatarImageView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor),
            
            // Name: 24px (12pt) top margin
            nameLabel.topAnchor.constraint(equalTo: avatarContainer.bottomAnchor, constant: s(12)),
            nameLabel.centerXAnchor.constraint(equalTo: scrollContentView.centerXAnchor),
            
            // Email: 4px (2pt) top margin
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: s(2)),
            emailLabel.centerXAnchor.constraint(equalTo: scrollContentView.centerXAnchor),
            
            // Rows Stack: 92px (46pt) top margin
            rowsStack.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: s(46)),
            rowsStack.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: s(30)),
            rowsStack.widthAnchor.constraint(equalToConstant: s(316.5)),
            
            // 删除账号：内容最底部。设计稿里它离最后一条分隔线 136px（68pt），
            // 分隔线自带 9pt 下间距，所以这里补 59。
            deleteAccountButton.topAnchor.constraint(equalTo: rowsStack.bottomAnchor, constant: s(59)),
            deleteAccountButton.centerXAnchor.constraint(equalTo: scrollContentView.centerXAnchor),
            deleteAccountButton.bottomAnchor.constraint(equalTo: scrollContentView.bottomAnchor, constant: s(-32))
        ])
    }
    
    @objc private func handleBack() {
        if let navigationController, navigationController.viewControllers.first != self {
            navigationController.popViewController(animated: true)
            return
        }
        dismiss(animated: true, completion: nil)
    }

    // MARK: - 删除账号

    @objc private func handleDeleteAccount() {
        deletionFlow.start()
    }

    @objc private func toggleDetailsVisibility() {
        isDetailsHidden.toggle()
        updateVisibilityState()
    }
    
    private func updateVisibilityState() {
        if isDetailsHidden {
            userIdRow.valueLabel.text = userDetails["id"]
            nicknameRow.valueLabel.text = ""
            genderRow.valueLabel.text = ""
            weightHeightRow.valueLabel.text = ""
            birthdayRow.valueLabel.text = ""
            emailRow.valueLabel.text = ""
            phoneRow.valueLabel.text = ""
            addressRow.valueLabel.text = ""
        } else {
            userIdRow.valueLabel.text = userDetails["id"]
            nicknameRow.valueLabel.text = userDetails["nickname"]
            genderRow.valueLabel.text = Self.genderDisplay(userDetails["gender"])
            weightHeightRow.valueLabel.text = Self.weightHeightSummary(weight: userDetails["weight"], height: userDetails["height"])
            birthdayRow.valueLabel.text = Self.birthdayDisplay(userDetails["birthday"])
            emailRow.valueLabel.text = userDetails["email"]
            phoneRow.valueLabel.text = userDetails["phone"]
            addressRow.valueLabel.text = userDetails["address"]
        }

        let nickname = userDetails["nickname"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        nameLabel.text = nickname.isEmpty ? L("user_profile.username_default") : nickname
    }

    private func refreshProfileState() {
        if let savedImage = loadAvatarImage() {
            avatarImageView.image = savedImage
        }

        if let email = AuthStorage.shared.email, !email.isEmpty {
            emailLabel.text = email
        } else {
            emailLabel.text = L("sidemenu.not_logged_in")
        }

        let storedDraft = UserProfileStore.shared.load(accountEmail: AuthStorage.shared.email)
        let savedAddresses = loadSavedAddresses()
        let addressSummary = formattedAddressSummary(from: savedAddresses)
        let resolvedAddress = addressSummary.isEmpty ? storedDraft.address : addressSummary

        // 注意：这里不再塞任何「示例数据」。曾经在 #if DEBUG 下用假数据（DK / 18 / 1998.08.12 …）
        // 预览 UI，但那会让「注销 / 登出后重新登录」时空资料被假数据填满，误以为数据没清干净、
        // 也无法验证删除逻辑。现统一：draft 为空就显示空，DEBUG 与 Release 表现一致。
        let fallbackID = ""
        let fallbackNick = ""
        let fallbackGender = ""
        let fallbackAge = ""
        let fallbackBirth = ""
        let fallbackPhone = ""
        let fallbackEmail = AuthStorage.shared.email ?? ""

        userDetails = [
            "id": resolvedValue(AuthStorage.shared.preferredUserIdentifier, fallback: fallbackID),
            "nickname": resolvedValue(storedDraft.nickname, fallback: fallbackNick),
            "gender": resolvedValue(storedDraft.gender, fallback: fallbackGender),
            "age": resolvedValue(storedDraft.age, fallback: fallbackAge),
            "birthday": resolvedValue(storedDraft.birthday, fallback: fallbackBirth),
            "weight": resolvedValue(storedDraft.weight, fallback: ""),
            "height": resolvedValue(storedDraft.height, fallback: ""),
            "phone": resolvedValue(storedDraft.phone, fallback: fallbackPhone),
            "email": resolvedValue(storedDraft.email, fallback: fallbackEmail),
            "address": resolvedAddress
        ]

        updateVisibilityState()
    }

    /// 「75kg / 175cm」。只填了一项就只显示那一项，别出现「75kg / cm」这种半截文案。
    /// 服务端资料里的性别是 `male` / `female` 这类原始值，展示时换成当前语言的文案；
    /// 其他值（本地选过的、已是文案的）原样显示。
    private static func genderDisplay(_ raw: String?) -> String? {
        switch raw?.lowercased() {
        case "male": return L("user_profile.gender.male")
        case "female": return L("user_profile.gender.female")
        default: return raw
        }
    }

    /// 生日按存档格式 `yyyy.MM.dd` 存取，展示时按 locale 显示（`Aug 12, 1998` / `1998年8月12日`）。
    /// 解析不了（历史数据格式不同）就原样显示，不丢内容。
    private static func birthdayDisplay(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return raw }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy.MM.dd", "yyyy-MM-dd"] {
            parser.dateFormat = format
            if let date = parser.date(from: raw) { return DateDisplay.date(date) }
        }
        return raw
    }

    private static func weightHeightSummary(weight: String?, height: String?) -> String {
        let weightText = (weight ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let heightText = (height ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if !weightText.isEmpty { parts.append(UnitDisplay.weight(kilogramsText: weightText)) }
        if !heightText.isEmpty { parts.append(UnitDisplay.height(centimetersText: heightText)) }
        return parts.joined(separator: " / ")
    }

    private func resolvedValue(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func currentDraft() -> UserProfileDraft {
        UserProfileDraft(
            nickname: userDetails["nickname"] ?? "",
            gender: userDetails["gender"] ?? "",
            age: userDetails["age"] ?? "",
            birthday: userDetails["birthday"] ?? "",
            email: userDetails["email"] ?? "",
            phone: userDetails["phone"] ?? "",
            address: userDetails["address"] ?? "",
            weight: userDetails["weight"] ?? "",
            height: userDetails["height"] ?? ""
        )
    }

    // MARK: - 自动上传

    // 具体实现在 UserProfileSync：地址在独立页面改、问卷领奖也会写地址簿，
    // 上传若只挂在本页就只能等用户下次打开资料页才补传。这里只负责「改完了，排一次」。

    private func persistCurrentDraft() {
        UserProfileStore.shared.save(currentDraft())
        UserProfileSync.scheduleAutoUpload()
    }

    // 地址 / 头像的读写统一收在 UserProfileSync —— 登录时的拉取也要用同一份，
    // 两处各写一份迟早写歪。
    private func loadSavedAddresses() -> [AddrModel] { UserProfileSync.loadAddresses() }

    private func formattedAddressSummary(from addresses: [AddrModel]) -> String {
        guard !addresses.isEmpty else { return "" }

        let orderedAddresses = addresses.sorted {
            if $0.isDefault != $1.isDefault {
                return $0.isDefault && !$1.isDefault
            }
            return $0.id < $1.id
        }

        return orderedAddresses
            .map { address in
                [address.region, address.detail]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    private func loadAvatarJPEGData() -> Data? { UserProfileSync.loadAvatarData() }

    /// 打开资料页拉一次服务端资料。合并落地、以及合并后的补传都在 UserProfileSync 里，
    /// 结果通过 `.userProfileDidUpdate` 回到本页刷新，不用本页自己再存一份状态。
    private func syncRemoteProfileIfNeeded() {
        UserProfileSync.pull(reason: "profile_page")
    }

    // MARK: - Avatar Persistence
    private var avatarURL: URL? { UserProfileSync.avatarURL }
    
    
    private func loadAvatarImage() -> UIImage? {
        guard let url = avatarURL, let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

class UserProfileRowView: UIView {
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        return label
    }()
    
    let valueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        label.textAlignment = .right
        return label
    }()
    
    let rightIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    init(title: String, icon: String) {
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        rightIconView.image = UIImage(named: icon)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayer() {
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(rightIconView)

        // 标题不许被值挤没。地址这类值现在可能很长（国家+省+市+区+街道），
        // 默认两个 label 的优先级相同，长值会把「地址」两个字压到零宽度整个消失。
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.lineBreakMode = .byTruncatingTail
        
        let scale = iPadAdaptiveScale.capped(UIScreen.main.bounds.width, widthReference: UIScreen.main.bounds.width) / 375.0
        
        NSLayoutConstraint.activate([
            // Reduced row height from 42 to 25 to reduce visual spacing
            heightAnchor.constraint(equalToConstant: 25 * scale),
            
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            rightIconView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightIconView.widthAnchor.constraint(equalToConstant: 14 * scale),
            rightIconView.heightAnchor.constraint(equalToConstant: 14 * scale),
            
            valueLabel.trailingAnchor.constraint(equalTo: rightIconView.leadingAnchor, constant: -8 * scale),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 10 * scale)
        ])
    }
}

class UserProfileSeparatorView: UIView {
    
    private let line: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let sepWidth: CGFloat
    private let leadingOffset: CGFloat
    private let verticalSpacing: CGFloat
    
    init(width: CGFloat, leadingOffset: CGFloat, verticalSpacing: CGFloat) {
        self.sepWidth = width
        self.leadingOffset = leadingOffset
        self.verticalSpacing = verticalSpacing
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        addSubview(line)
        
        // Spec: Opacity 50%, #FFFFFE (Increased visibility)
        line.backgroundColor = UIColor(red: 255/255, green: 255/255, blue: 254/255, alpha: 0.5)
        
        NSLayoutConstraint.activate([
            // Spec: Thickness 0.5pt to ensure visibility on device
            line.heightAnchor.constraint(equalToConstant: 0.5),
            line.widthAnchor.constraint(equalToConstant: sepWidth),
            
            // Center the line vertically
            line.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Offsets
            line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingOffset),
            
            // Container Height
            heightAnchor.constraint(equalToConstant: (verticalSpacing * 2) + 0.5)
        ])
    }
}

// MARK: - Image Picker Delegate
extension UserProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        // Try to get the edited image first, otherwise fallback to original
        var selectedImage: UIImage?
        if let editedImage = info[.editedImage] as? UIImage {
            selectedImage = editedImage
        } else if let originalImage = info[.originalImage] as? UIImage {
            selectedImage = originalImage
        }
        
        if let image = selectedImage {
            avatarImageView.image = image
            // 写盘 + 通知 + 自动上传都在 UserProfileSync.saveAvatar 里。
            UserProfileSync.saveAvatar(image)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

// MARK: - Avatar Selection View Controller
class AvatarSelectionViewController: UIViewController {
    
    enum Action {
        case camera
        case album
        case cancel
    }
    
    var onAction: ((Action) -> Void)?
    
    private let dimView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.alpha = 0
        return view
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    // Upper box: Camera + Album
    private let upperBox: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1.0)
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        return view
    }()
    
    private let cameraBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(L("user_profile.take_photo", comment: "拍照"), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 18) ?? .systemFont(ofSize: 18)
        return btn
    }()
    
    private let albumBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(L("user_profile.choose_from_album", comment: "从手机相册选择"), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 18) ?? .systemFont(ofSize: 18)
        return btn
    }()
    
    // Separator
    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        return view
    }()
    
    // Cancel box
    private let cancelBox: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 44/255, green: 43/255, blue: 45/255, alpha: 1.0)
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        return view
    }()
    
    private let cancelBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(L("user_profile.cancel", comment: "取消"), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 18) ?? .boldSystemFont(ofSize: 18)
        return btn
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        show()
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        view.addSubview(dimView)
        view.addSubview(contentView)
        
        contentView.addSubview(upperBox)
        contentView.addSubview(cancelBox)
        
        upperBox.addSubview(cameraBtn)
        upperBox.addSubview(separatorLine)
        upperBox.addSubview(albumBtn)
        
        cancelBox.addSubview(cancelBtn)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCancel))
        dimView.addGestureRecognizer(tap)
        
        // Layout
        // Padding side: 8pt (16px)
        let sidePadding: CGFloat = 8
        
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Cancel Box
            cancelBox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sidePadding),
            cancelBox.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sidePadding),
            cancelBox.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -24), 
            cancelBox.heightAnchor.constraint(equalToConstant: 58.5),
            
            cancelBtn.centerXAnchor.constraint(equalTo: cancelBox.centerXAnchor),
            cancelBtn.centerYAnchor.constraint(equalTo: cancelBox.centerYAnchor),
            cancelBtn.widthAnchor.constraint(equalTo: cancelBox.widthAnchor),
            cancelBtn.heightAnchor.constraint(equalTo: cancelBox.heightAnchor),
            
            // Upper Box
            upperBox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sidePadding),
            upperBox.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sidePadding),
            upperBox.bottomAnchor.constraint(equalTo: cancelBox.topAnchor, constant: -5), 
            upperBox.topAnchor.constraint(equalTo: contentView.topAnchor),
            upperBox.heightAnchor.constraint(equalToConstant: 114), 
            
            // Camera Button (Top half)
            cameraBtn.topAnchor.constraint(equalTo: upperBox.topAnchor),
            cameraBtn.leadingAnchor.constraint(equalTo: upperBox.leadingAnchor),
            cameraBtn.trailingAnchor.constraint(equalTo: upperBox.trailingAnchor),
            cameraBtn.bottomAnchor.constraint(equalTo: separatorLine.topAnchor),
            
            // Separator
            separatorLine.leadingAnchor.constraint(equalTo: upperBox.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: upperBox.trailingAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.25),
            separatorLine.topAnchor.constraint(equalTo: upperBox.topAnchor, constant: 53.5),
            
            // Album Button (Bottom half)
            albumBtn.topAnchor.constraint(equalTo: separatorLine.bottomAnchor),
            albumBtn.leadingAnchor.constraint(equalTo: upperBox.leadingAnchor),
            albumBtn.trailingAnchor.constraint(equalTo: upperBox.trailingAnchor),
            albumBtn.bottomAnchor.constraint(equalTo: upperBox.bottomAnchor)
        ])
        
        cameraBtn.addTarget(self, action: #selector(handleCamera), for: .touchUpInside)
        albumBtn.addTarget(self, action: #selector(handleAlbum), for: .touchUpInside)
        cancelBtn.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        
        // Initial state
        contentView.transform = CGAffineTransform(translationX: 0, y: 300)
    }
    
    private func show() {
        UIView.animate(withDuration: 0.25) {
            self.dimView.alpha = 1
            self.contentView.transform = .identity
        }
    }
    
    private func hide(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.25, animations: {
            self.dimView.alpha = 0
            self.contentView.transform = CGAffineTransform(translationX: 0, y: 300)
        }) { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }
    
    @objc private func handleCamera() {
        hide {
            self.onAction?(.camera)
        }
    }
    
    @objc private func handleAlbum() {
        hide {
            self.onAction?(.album)
        }
    }
    
    @objc private func handleCancel() {
        hide {
            self.onAction?(.cancel)
        }
    }
}
