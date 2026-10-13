//
//  RedeemCodeViewController.swift
//  mindora
//
//  兑换码兑换页面（含「使用规则」弹窗）
//  设计稿: 兑换码兑换 / 兑换码兑换备份 / 使用规则 (Lanhu20260618)
//

import UIKit

class RedeemCodeViewController: UIViewController {

    // 设计稿 750px 宽 => 375pt，缩放因子 2.0；页面内多数尺寸直接用 px/2 的 pt 值。

    // MARK: - Colors
    private let pageBg = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0)        // #181818
    private let fieldBg = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0)       // #2C2C2C
    private let disabledBtnBg = UIColor(red: 163/255, green: 163/255, blue: 163/255, alpha: 1.0) // #A3A3A3

    // MARK: - UI

    private let backButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton()
        button.setImage(UIImage(named: "sub_back"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let envelopeImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "redeem_envelope"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let fieldContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 18
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let textField: UITextField = {
        let tf = UITextField()
        tf.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        tf.textColor = .white
        tf.tintColor = .white
        tf.autocapitalizationType = .allCharacters
        tf.autocorrectionType = .no
        tf.clearButtonMode = .whileEditing
        tf.returnKeyType = .done
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let redeemButton: UIButton = {
        let b = UIButton(type: .custom)
        b.layer.cornerRadius = 25
        b.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let rulesButton: UIButton = {
        let b = UIButton(type: .custom)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = pageBg
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupUI()
        setupActions()
        updateButtonState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(backButton)
        view.addSubview(envelopeImageView)
        view.addSubview(fieldContainer)
        fieldContainer.addSubview(textField)
        view.addSubview(redeemButton)
        view.addSubview(rulesButton)

        fieldContainer.backgroundColor = fieldBg

        textField.attributedPlaceholder = NSAttributedString(
            string: L("redeem.placeholder"),
            attributes: [.foregroundColor: UIColor(white: 1.0, alpha: 0.4)]
        )
        redeemButton.setTitle(L("redeem.action"), for: .normal)
        rulesButton.setTitle(L("redeem.rules.entry"), for: .normal)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 24),
            backButton.heightAnchor.constraint(equalToConstant: 24),

            // 信封图：居中，位于上部
            envelopeImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            // 按蓝湖设计稿（750 宽画板按 2 倍标注）：信封 240×215.73 → 120×108pt，左右各 255 → 水平居中；
            // 距画板顶 349 → 174.5pt，减去 44pt 状态栏 = 安全区下 130.5pt。
            // 旧图是 190×160 的不透明图、信封四周带背景色留白；新图透明底、无留白，直接按信封尺寸放。
            envelopeImageView.topAnchor.constraint(equalTo: safe.topAnchor, constant: 130.5),
            envelopeImageView.widthAnchor.constraint(equalToConstant: 120),
            envelopeImageView.heightAnchor.constraint(equalToConstant: 108),

            // 输入框：左右 20pt 边距（设计稿 670/750≈89%）高 50pt 圆角 18pt
            fieldContainer.topAnchor.constraint(equalTo: envelopeImageView.bottomAnchor, constant: 50),   // 设计稿 100 → 50pt
            fieldContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            fieldContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            fieldContainer.heightAnchor.constraint(equalToConstant: 50),

            textField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor, constant: 24),
            textField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor, constant: -16),
            textField.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            textField.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor),

            // 立即兑换按钮：左右 20pt 边距 高 50pt 胶囊
            redeemButton.topAnchor.constraint(equalTo: fieldContainer.bottomAnchor, constant: 40),
            redeemButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            redeemButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            redeemButton.heightAnchor.constraint(equalToConstant: 50),

            // 使用规则
            rulesButton.topAnchor.constraint(equalTo: redeemButton.bottomAnchor, constant: 24),
            rulesButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func setupActions() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        rulesButton.addTarget(self, action: #selector(showRules), for: .touchUpInside)
        redeemButton.addTarget(self, action: #selector(handleRedeem), for: .touchUpInside)
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        textField.delegate = self

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - State

    private var hasInput: Bool {
        !(textField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private func updateButtonState() {
        if hasInput {
            redeemButton.backgroundColor = .white
            redeemButton.setTitleColor(pageBg, for: .normal)
            redeemButton.isEnabled = true
        } else {
            redeemButton.backgroundColor = disabledBtnBg
            redeemButton.setTitleColor(pageBg, for: .normal)
            redeemButton.isEnabled = false
        }
    }

    // MARK: - Actions

    @objc private func textChanged() { updateButtonState() }
    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func handleBack() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    /// 兑换成功确认框：提示「兑换 年度/月度 会员成功，会员有效期至 X」，点「好的」关闭并返回订阅页。
    private func showRedeemSuccessAlert(durationDays: Int?, previousEndAt: Date?) {
        // 读取累加后的会员到期时间（applyServerMembership 已更新）。
        let endAt = SubscriptionManager.shared.serverLevelEndAt
        let dateStr = endAt.map { Self.successDateFormatter.string(from: $0) }
        // 周期天数：优先用服务端 duration_days；没有则用「新到期 - 兑换前基准」反推。
        let effectiveDays = durationDays ?? Self.daysBetween(from: previousEndAt, to: endAt)
        let period = periodName(forDays: effectiveDays)   // 年度 / 月度 / ""

        let description: String
        if !period.isEmpty, let dateStr {
            description = String(format: L("redeem.success.detail"), period, dateStr)     // 年/月 + 到期
        } else if !period.isEmpty {
            description = String(format: L("redeem.success.detail.no_date"), period)      // 仅年/月
        } else if let dateStr {
            description = String(format: L("redeem.success.detail.generic"), dateStr)     // 仅到期
        } else {
            description = L("redeem.success")                                             // 最简兜底
        }

        let alert = CustomAlertViewController(
            title: L("redeem.success.title"),
            description: description,
            confirmButtonTitle: L("redeem.rules.ok"),   // 「好的」/「OK」
            onConfirm: { [weak self] in
                // 兑换页是从订阅页 present 出来的，dismiss 自身即返回订阅页。
                self?.dismiss(animated: true)
            }
        )
        present(alert, animated: true)
    }

    /// 兑换成功提示里展示到期日用的日期格式（本地化中等样式，如「2027年1月1日」/「Jan 1, 2027」）。
    /// 取 App 语言而不是 `.current`：`.current` 跟系统走，用户在 App 内选了别的语言时对不上。
    private static var successDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = LocalizationManager.shared.currentLocale
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    /// 由到期日增量反推本次兑换天数：base = max(兑换前到期, 现在)，返回 (newEnd - base) 的天数。
    private static func daysBetween(from previousEndAt: Date?, to newEndAt: Date?) -> Int? {
        guard let newEndAt else { return nil }
        let now = Date()
        let base = max(previousEndAt ?? now, now)
        let secs = newEndAt.timeIntervalSince(base)
        guard secs > 0 else { return nil }
        return Int((secs / 86400.0).rounded())
    }

    /// 由兑换天数推断会员周期文案：≥180 天按「年度」，其余有效天数按「月度」，未知（nil/≤0）返回空串。
    /// 阈值容错：服务端可能返回 364/366/365 等，避免精确匹配失败。
    private func periodName(forDays days: Int?) -> String {
        guard let d = days, d > 0 else { return "" }
        return d >= 180 ? L("redeem.period.yearly") : L("redeem.period.monthly")
    }

    @objc private func showRules() {
        view.endEditing(true)
        let sheet = RedeemRulesSheetView()
        sheet.present(over: view)
    }

    @objc private func handleRedeem() {
        guard hasInput else { return }
        view.endEditing(true)
        let code = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !code.isEmpty else { return }

        redeemButton.isEnabled = false
        Task { @MainActor in
            do {
                let result = try await RedeemService.shared.redeem(code: code)
                // 记录兑换前的到期时间，用于在服务端没返回 duration_days 时，由到期日增量反推年/月。
                let previousEndAt = SubscriptionManager.shared.serverLevelEndAt
                // 兑换成功：落地服务端会员并累加到期（多张可叠加），清空输入，弹确认框（含年/月+到期），点「好的」返回订阅页。
                SubscriptionManager.shared.applyServerMembership(level: result.level, durationDays: result.durationDays, serverEndAt: result.endAt, premiumTrialEndAt: result.premiumTrialEndAt)
                // 服务端为事实源：兑换后立刻拉一次完整状态（server 模式下判定直接用它）。
                MembershipStatusService.shared.refresh(reason: "redeem", force: true)
                textField.text = ""
                updateButtonState()
                showRedeemSuccessAlert(durationDays: result.durationDays, previousEndAt: previousEndAt)
            } catch RedeemService.RedeemError.message(let msg) {
                Toast.show(msg, in: view)
                updateButtonState()
            } catch {
                Toast.show(L("redeem.error.generic"), in: view)
                updateButtonState()
            }
        }
    }
}

// MARK: - UITextFieldDelegate

extension RedeemCodeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - 使用规则弹窗

final class RedeemRulesSheetView: UIView {

    private let dimView = UIView()
    private let sheet = UIView()
    private var sheetBottom: NSLayoutConstraint?

    private let sheetBg = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        // 用 frame + autoresizingMask 定位（见 present(over:)），故保持
        // translatesAutoresizingMaskIntoConstraints = true（默认），否则自身尺寸塌成 0。

        dimView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)

        sheet.backgroundColor = sheetBg
        sheet.layer.cornerRadius = 18
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheet.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sheet)

        // text_5 标题：SourceHanSans Regular 32px=16pt 白
        let title = UILabel()
        title.text = L("redeem.rules.title")
        title.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        title.textColor = .white
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(title)

        // paragraph_1 正文：SourceHanSans Light 28px=14pt，白，行高 40px=20pt
        let body = UILabel()
        body.numberOfLines = 0
        body.translatesAutoresizingMaskIntoConstraints = false
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 5
        para.paragraphSpacing = 10  // 条目之间留白（替代原来的空行）
        body.attributedText = NSAttributedString(
            // 用单换行分隔各条，靠 paragraphSpacing 控制间距，避免空行造成过大空白
            string: L("redeem.rules.body").replacingOccurrences(of: "\n\n", with: "\n"),
            attributes: [
                .font: UIFont(name: "PingFangSC-Light", size: 14) ?? .systemFont(ofSize: 14, weight: .light),
                .foregroundColor: UIColor(white: 1.0, alpha: 0.9),
                .paragraphStyle: para
            ]
        )
        sheet.addSubview(body)

        // text-wrapper_4 好的按钮：白底，圆角 24pt，高 48pt
        let okButton = UIButton(type: .custom)
        okButton.setTitle(L("redeem.rules.ok"), for: .normal)
        okButton.setTitleColor(.black, for: .normal)
        okButton.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15)
        okButton.backgroundColor = .white
        okButton.layer.cornerRadius = 24
        okButton.translatesAutoresizingMaskIntoConstraints = false
        okButton.addTarget(self, action: #selector(dismissSheet), for: .touchUpInside)
        sheet.addSubview(okButton)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSheet))
        dimView.addGestureRecognizer(tap)

        sheetBottom = sheet.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 600)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),

            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheetBottom!,

            // section_13 padding：上 30pt，左右 30pt，下 40pt
            title.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 30),
            title.centerXAnchor.constraint(equalTo: sheet.centerXAnchor),

            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 24),
            body.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 30),
            body.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -30),

            okButton.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 40),
            okButton.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 30),
            okButton.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -30),
            okButton.heightAnchor.constraint(equalToConstant: 48),
            okButton.bottomAnchor.constraint(equalTo: sheet.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    func present(over parent: UIView) {
        frame = parent.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.addSubview(self)
        dimView.alpha = 0
        layoutIfNeeded()
        sheetBottom?.constant = 0
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut) {
            self.dimView.alpha = 1
            self.layoutIfNeeded()
        }
    }

    @objc private func dismissSheet() {
        sheetBottom?.constant = sheet.bounds.height + 40
        UIView.animate(withDuration: 0.25, animations: {
            self.dimView.alpha = 0
            self.layoutIfNeeded()
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }
}
