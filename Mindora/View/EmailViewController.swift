import UIKit
import MessageUI

// 邮箱是账号 ID，不可编辑。设计稿（lanhu_youxiangsuoding /
// lanhu_youxiangwufaxiugaidanchuang / lanhu_youxiangshanchutixing）：
// 顶部返回+标题「邮箱」，下方锁定态邮箱行（灰底 #2C2C2C + 锁图标，点击提示无法编辑），
// 底部一个红色删除账号大按钮，复用与个人资料页相同的删除账号两段式流程。
class EmailViewController: UIViewController, MFMailComposeViewControllerDelegate {

    var currentEmail: String?

    private lazy var deletionFlow = AccountDeletionFlow(presenter: self, actionButton: deleteAccountButton)

    // MARK: - Scaled Metrics Helper (base design width 375pt / 750px)
    private var scale: CGFloat {
        return iPadAdaptiveScale.capped(UIScreen.main.bounds.width, widthReference: UIScreen.main.bounds.width) / 375.0
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
        label.text = L("user_profile.email_title")
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()

    // #E4E4E4 20% opacity
    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 228/255.0, green: 228/255.0, blue: 228/255.0, alpha: 0.2)
        return view
    }()

    // 锁定态邮箱行，bg #2C2C2C
    private let lockedFieldContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 44/255.0, green: 44/255.0, blue: 44/255.0, alpha: 1.0)
        view.isUserInteractionEnabled = true
        return view
    }()

    private let emailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        return label
    }()

    private let lockIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: "lock_icon")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    // 删除账号：设计稿是一个醒目的红色大按钮（#FF5A59），而非个人资料页那种弱化文字。
    private let deleteAccountButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor(red: 1.0, green: 90/255.0, blue: 89/255.0, alpha: 1.0)
        button.setTitle(L("user_profile.delete"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        emailLabel.text = currentEmail
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)

        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)

        view.addSubview(separatorLine)

        view.addSubview(lockedFieldContainer)
        lockedFieldContainer.addSubview(emailLabel)
        lockedFieldContainer.addSubview(lockIconView)

        view.addSubview(deleteAccountButton)

        deleteAccountButton.layer.cornerRadius = s(25)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: s(10)),
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

            lockedFieldContainer.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: s(27.5)),
            lockedFieldContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lockedFieldContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            lockedFieldContainer.heightAnchor.constraint(equalToConstant: s(50)),

            emailLabel.leadingAnchor.constraint(equalTo: lockedFieldContainer.leadingAnchor, constant: s(24)),
            emailLabel.centerYAnchor.constraint(equalTo: lockedFieldContainer.centerYAnchor),
            emailLabel.trailingAnchor.constraint(lessThanOrEqualTo: lockIconView.leadingAnchor, constant: -s(12)),

            lockIconView.trailingAnchor.constraint(equalTo: lockedFieldContainer.trailingAnchor, constant: -s(24)),
            lockIconView.centerYAnchor.constraint(equalTo: lockedFieldContainer.centerYAnchor),
            lockIconView.widthAnchor.constraint(equalToConstant: s(17)),
            lockIconView.heightAnchor.constraint(equalToConstant: s(20)),

            deleteAccountButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: s(30)),
            deleteAccountButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -s(30)),
            deleteAccountButton.heightAnchor.constraint(equalToConstant: s(50)),
            deleteAccountButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -s(40))
        ])
    }

    private func setupActions() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        deleteAccountButton.addTarget(self, action: #selector(handleDeleteAccount), for: .touchUpInside)

        let lockedTap = UITapGestureRecognizer(target: self, action: #selector(showEmailLockedAlert))
        lockedFieldContainer.addGestureRecognizer(lockedTap)
    }

    // MARK: - Actions
    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func handleDeleteAccount() {
        deletionFlow.start()
    }

    // 邮箱是账号 ID，不可编辑；点击提示原因并提供联系入口。
    @objc private func showEmailLockedAlert() {
        let alert = CustomAlertViewController(
            title: L("user_profile.email_locked_title"),
            description: String(format: L("user_profile.email_locked_message"), Constants.Contact.supportEmail),
            confirmButtonTitle: L("user_profile.email_locked_contact"),
            cancelButtonTitle: L("user_profile.cancel"),
            onConfirm: { [weak self] in self?.sendSupportEmail() }
        )
        present(alert, animated: true)
    }

    private func sendSupportEmail() {
        let subject = L("user_profile.email_locked_title")
        let body = supportEmailBody()

        guard MFMailComposeViewController.canSendMail() else {
            // 没配置 Mail 账户时退化到 mailto:，主题/正文一并带上。
            var components = URLComponents(string: "mailto:\(Constants.Contact.supportEmail)")
            components?.queryItems = [
                URLQueryItem(name: "subject", value: subject),
                URLQueryItem(name: "body", value: body)
            ]
            if let url = components?.url {
                UIApplication.shared.open(url)
            }
            return
        }
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = self
        mail.setToRecipients([Constants.Contact.supportEmail])
        mail.setSubject(subject)
        mail.setMessageBody(body, isHTML: false)
        present(mail, animated: true)
    }

    // 预填账号邮箱 + 设备诊断信息，方便客服定位账号、少来回一轮问询。
    private func supportEmailBody() -> String {
        let accountEmail = currentEmail ?? AuthStorage.shared.email ?? ""
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let osVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model

        return """


        -------------------
        \(L("user_profile.email")): \(accountEmail)
        \(L("subscription.email.app_version")): \(appVersion)
        \(L("subscription.email.ios_version")): \(osVersion)
        \(L("subscription.email.device")): \(deviceModel)
        """
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
