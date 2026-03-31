import UIKit

class UserProfileViewController: UIViewController {

    private let addressStorageKey = "MindoraSavedAddresses"
    private var isSyncingRemoteProfile = false

    // MARK: - Scaled Metrics Helper
    // Base design width is 375pt (750px)
    private var scale: CGFloat {
        return UIScreen.main.bounds.width / 375.0
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
    
    // Update Button
    private let updateButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("user_profile.update"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        button.backgroundColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0)
        return button
    }()
    
    // Rows
    private var userIdRow: UserProfileRowView!
    private var nicknameRow: UserProfileRowView!
    private var genderRow: UserProfileRowView!
    private var ageRow: UserProfileRowView!
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshProfileState()
        syncRemoteProfileIfNeeded()
    }
    
    private func setupData() {
        userIdRow = UserProfileRowView(title: L("user_profile.user_id"), icon: "profile_detail")
        nicknameRow = UserProfileRowView(title: L("user_profile.nickname"), icon: "enter_icon")
        genderRow = UserProfileRowView(title: L("user_profile.gender"), icon: "enter_icon")
        ageRow = UserProfileRowView(title: L("user_profile.age"), icon: "enter_icon")
        birthdayRow = UserProfileRowView(title: L("user_profile.birthday"), icon: "enter_icon")
        emailRow = UserProfileRowView(title: L("user_profile.email"), icon: "enter_icon")
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
        
        let rows = [userIdRow, nicknameRow, genderRow, ageRow, birthdayRow, emailRow, phoneRow, addressRow]
        
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
        
        scrollContentView.addSubview(updateButton)
        
        setupConstraints()
        
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleDetailsVisibility))
        userIdRow.isUserInteractionEnabled = true
        userIdRow.addGestureRecognizer(tapGesture)
        
        let nicknameTap = UITapGestureRecognizer(target: self, action: #selector(editNickname))
        nicknameRow.isUserInteractionEnabled = true
        nicknameRow.addGestureRecognizer(nicknameTap)
        
        let ageTap = UITapGestureRecognizer(target: self, action: #selector(editAge))
        ageRow.isUserInteractionEnabled = true
        ageRow.addGestureRecognizer(ageTap)
        
        let birthdayTap = UITapGestureRecognizer(target: self, action: #selector(editBirthday))
        birthdayRow.isUserInteractionEnabled = true
        birthdayRow.addGestureRecognizer(birthdayTap)
        
        let genderTap = UITapGestureRecognizer(target: self, action: #selector(editGender))
        genderRow.isUserInteractionEnabled = true
        genderRow.addGestureRecognizer(genderTap)
        
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

        updateButton.addTarget(self, action: #selector(handleUpdateProfile), for: .touchUpInside)
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
    
    @objc private func editAge() {
        let vc = AgeEditViewController()
        vc.currentAge = userDetails["age"]
        vc.onSave = { [weak self] newAge in
            self?.userDetails["age"] = newAge
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
    
    @objc private func editEmail() {
        let vc = EmailEditViewController()
        vc.currentEmail = userDetails["email"]
        vc.onSave = { [weak self] newEmail in
            self?.userDetails["email"] = newEmail
            self?.persistCurrentDraft()
            self?.updateVisibilityState()
        }
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
        updateButton.layer.cornerRadius = s(10)
        
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
            
            // Update Button
            // Margin 50pt from last element.
            // Last element is separator (9pt bottom spacing).
            // 50 - 9 = 41.
            updateButton.topAnchor.constraint(equalTo: rowsStack.bottomAnchor, constant: s(41)),
            updateButton.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: s(106.5)),
            updateButton.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: s(-110)),
            updateButton.bottomAnchor.constraint(equalTo: scrollContentView.bottomAnchor, constant: s(-50))
        ])
    }
    
    @objc private func handleBack() {
        if let navigationController, navigationController.viewControllers.first != self {
            navigationController.popViewController(animated: true)
            return
        }
        dismiss(animated: true, completion: nil)
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
            ageRow.valueLabel.text = ""
            birthdayRow.valueLabel.text = ""
            emailRow.valueLabel.text = ""
            phoneRow.valueLabel.text = ""
            addressRow.valueLabel.text = ""
        } else {
            userIdRow.valueLabel.text = userDetails["id"]
            nicknameRow.valueLabel.text = userDetails["nickname"]
            genderRow.valueLabel.text = userDetails["gender"]
            ageRow.valueLabel.text = userDetails["age"]
            birthdayRow.valueLabel.text = userDetails["birthday"]
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

        var fallbackID = ""
        var fallbackNick = ""
        var fallbackGender = ""
        var fallbackAge = ""
        var fallbackBirth = ""
        var fallbackPhone = ""
        var fallbackEmail = AuthStorage.shared.email ?? ""

        #if DEBUG
        fallbackID = "mIn111111"
        fallbackNick = "DK"
        fallbackGender = L("user_profile.gender.male")
        fallbackAge = "18"
        fallbackBirth = "1998.08.12"
        fallbackPhone = "13866997600"
        if fallbackEmail.isEmpty {
            fallbackEmail = "emailexample@example.com"
        }
        #endif

        userDetails = [
            "id": resolvedValue(AuthStorage.shared.preferredUserIdentifier, fallback: fallbackID),
            "nickname": resolvedValue(storedDraft.nickname, fallback: fallbackNick),
            "gender": resolvedValue(storedDraft.gender, fallback: fallbackGender),
            "age": resolvedValue(storedDraft.age, fallback: fallbackAge),
            "birthday": resolvedValue(storedDraft.birthday, fallback: fallbackBirth),
            "phone": resolvedValue(storedDraft.phone, fallback: fallbackPhone),
            "email": resolvedValue(storedDraft.email, fallback: fallbackEmail),
            "address": resolvedAddress
        ]

        updateVisibilityState()
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
            address: userDetails["address"] ?? ""
        )
    }

    private func persistCurrentDraft() {
        UserProfileStore.shared.save(currentDraft())
    }

    private func loadSavedAddresses() -> [AddrModel] {
        guard let data = UserDefaults.standard.data(forKey: addressStorageKey),
              let addresses = try? JSONDecoder().decode([AddrModel].self, from: data) else {
            return []
        }
        return addresses
    }

    private func saveAddresses(_ addresses: [AddrModel]) {
        guard let data = try? JSONEncoder().encode(addresses) else { return }
        UserDefaults.standard.set(data, forKey: addressStorageKey)
    }

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

    private func loadAvatarJPEGData() -> Data? {
        guard let url = avatarURL else { return nil }
        return try? Data(contentsOf: url)
    }

    private func setUpdateButtonLoading(_ isLoading: Bool) {
        updateButton.isEnabled = !isLoading
        updateButton.alpha = isLoading ? 0.6 : 1.0
    }

    private func profileErrorMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }
        return L("user_profile.update_failed")
    }

    private func syncRemoteProfileIfNeeded() {
          guard !isSyncingRemoteProfile,
              let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let token = AuthStorage.shared.token, !token.isEmpty else {
            return
        }

        _ = uid
        _ = token
        isSyncingRemoteProfile = true

        Task { [weak self] in
            guard let self else { return }

            do {
                let snapshot = try await UserProfileService.shared.queryProfile()
                await MainActor.run {
                    self.isSyncingRemoteProfile = false
                    guard let snapshot else { return }
                    self.applyRemoteSnapshot(snapshot)
                }
            } catch {
                await MainActor.run {
                    self.isSyncingRemoteProfile = false
                }
            }
        }
    }

    private func applyRemoteSnapshot(_ snapshot: UserProfileSnapshot) {
        let localDraft = UserProfileStore.shared.load(accountEmail: AuthStorage.shared.email)
        let mergedDraft = mergeDraft(local: localDraft, remote: snapshot.draft)

        let localAddresses = loadSavedAddresses()
        if localAddresses.isEmpty, !snapshot.addresses.isEmpty {
            saveAddresses(snapshot.addresses.map {
                AddrModel(
                    id: $0.id,
                    isDefault: $0.isDefault,
                    region: $0.region,
                    detail: $0.detail,
                    name: $0.name,
                    phone: $0.phone
                )
            })
        }

        if loadAvatarImage() == nil,
           let avatarData = snapshot.avatarJPEGData,
           let image = UIImage(data: avatarData) {
            saveAvatarImage(image)
        }

        UserProfileStore.shared.save(mergedDraft)
        refreshProfileState()
        NotificationCenter.default.post(name: .userProfileDidUpdate, object: nil)
    }

    private func mergeDraft(local: UserProfileDraft, remote: UserProfileDraft) -> UserProfileDraft {
        UserProfileDraft(
            nickname: preferredDraftValue(local.nickname, fallback: remote.nickname),
            gender: preferredDraftValue(local.gender, fallback: remote.gender),
            age: preferredDraftValue(local.age, fallback: remote.age),
            birthday: preferredDraftValue(local.birthday, fallback: remote.birthday),
            email: preferredDraftValue(local.email, fallback: remote.email),
            phone: preferredDraftValue(local.phone, fallback: remote.phone),
            address: preferredDraftValue(local.address, fallback: remote.address)
        )
    }

    private func preferredDraftValue(_ current: String, fallback: String) -> String {
        let currentTrimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !currentTrimmed.isEmpty {
            return currentTrimmed
        }
        return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @objc private func handleUpdateProfile() {
                guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let token = AuthStorage.shared.token, !token.isEmpty else {
            Toast.show(L("user_profile.token_missing"), in: view)
            return
        }

        _ = uid
        _ = token

        persistCurrentDraft()
        let draft = currentDraft()
        let avatarData = loadAvatarJPEGData()

        setUpdateButtonLoading(true)

        Task { [weak self] in
            guard let self else { return }

            do {
                let updatedDraft = try await UserProfileService.shared.updateProfile(draft: draft, avatarJPEGData: avatarData)

                await MainActor.run {
                    UserProfileStore.shared.save(updatedDraft)
                    self.refreshProfileState()
                    self.setUpdateButtonLoading(false)
                    NotificationCenter.default.post(name: .userProfileDidUpdate, object: nil)
                    Toast.show(L("user_profile.update_success"), in: self.view)
                }
            } catch {
                await MainActor.run {
                    self.setUpdateButtonLoading(false)
                    Toast.show(self.profileErrorMessage(for: error), in: self.view)
                }
            }
        }
    }
    
    // MARK: - Avatar Persistence
    private var avatarURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documentsDirectory.appendingPathComponent("user_avatar.jpg")
    }
    
    private func saveAvatarImage(_ image: UIImage) {
        guard let url = avatarURL, let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: url)
        NotificationCenter.default.post(name: NSNotification.Name("UserProfileAvatarUpdated"), object: nil)
    }
    
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
        
        let scale = UIScreen.main.bounds.width / 375.0
        
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
            saveAvatarImage(image)
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
