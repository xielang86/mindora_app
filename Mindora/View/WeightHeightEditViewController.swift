import UIKit

// 「体重 / 身高」编辑页。设计稿：lanhu_tizhongshengao。
// 顶部返回 + 标题 + 保存；下方两组「灰色小标题 + #2C2C2C 输入行（右侧清除按钮）」。
// 只存 kg / cm 的数字部分，单位不入库——换算与展示都由客户端负责。
// 英文界面按设计校对表用英制：体重填 lb，身高拆成 ft / in 两格，保存时换回 kg / cm。
class WeightHeightEditViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Properties
    var currentWeight: String?
    var currentHeight: String?
    /// (weight, height)，均为纯数字字符串；用户清空则回传空串。
    var onSave: ((String, String) -> Void)?

    /// 合理区间。超出就当输入错误挡在保存这一步，别把 300kg / 3cm 这种值同步到服务端。
    private static let weightRange: ClosedRange<Double> = 20...300
    private static let heightRange: ClosedRange<Double> = 50...250
    /// 英制区间与上面同一口径（45 lb≈20.4 kg，98 in≈249 cm），提示文案里写的也是这组数。
    private static let poundRange: ClosedRange<Double> = 45...661
    private static let inchRange: ClosedRange<Int> = 20...98

    private let imperial = UnitDisplay.usesImperial

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
        label.text = L("user_profile.weight_height")
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()

    private let saveButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("common.save"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        return button
    }()

    // #E4E4E4 20%
    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 228/255.0, green: 228/255.0, blue: 228/255.0, alpha: 0.2)
        return view
    }()

    private lazy var weightSectionLabel = makeSectionLabel(L("user_profile.weight_unit"))
    private lazy var heightSectionLabel = makeSectionLabel(L("user_profile.height_unit"))

    private lazy var weightField = makeTextField()
    private lazy var heightField = makeTextField()
    /// 英制时 heightField 填英尺，这一格填英寸。
    private lazy var inchField = makeTextField()
    private lazy var feetUnitLabel = makeUnitLabel("ft")
    private lazy var inchUnitLabel = makeUnitLabel("in")

    private lazy var weightContainer = makeInputContainer()
    private lazy var heightContainer = makeInputContainer()

    private lazy var weightClearButton = makeClearButton()
    private lazy var heightClearButton = makeClearButton()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        installTapToDismissKeyboard()

        if imperial {
            fillImperialFields()
        } else {
            weightField.text = currentWeight
            heightField.text = currentHeight
        }
        updateClearButtons()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        weightField.becomeFirstResponder()
    }

    // MARK: - Factories
    // 设计稿的小标题是 #A3A3A3 的灰字（CSS 里写的是白色，但导出图上量到的是 163,163,163），
    // 与下方 #2C2C2C 输入行里的白色数值明显分层。
    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        label.textColor = UIColor(red: 163/255.0, green: 163/255.0, blue: 163/255.0, alpha: 1.0)
        return label
    }

    private func makeInputContainer() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 44/255.0, green: 44/255.0, blue: 44/255.0, alpha: 1.0)
        return view
    }

    private func makeTextField() -> UITextField {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.textColor = .white
        field.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        field.borderStyle = .none
        field.keyboardType = .decimalPad
        field.keyboardAppearance = .dark
        return field
    }

    private func makeUnitLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        label.textColor = UIColor(red: 163/255.0, green: 163/255.0, blue: 163/255.0, alpha: 1.0)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }

    private func makeClearButton() -> UIButton {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "clean"), for: .normal)
        button.isHidden = true
        return button
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)

        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        headerView.addSubview(saveButton)
        view.addSubview(separatorLine)

        view.addSubview(weightSectionLabel)
        view.addSubview(weightContainer)
        weightContainer.addSubview(weightField)
        weightContainer.addSubview(weightClearButton)

        view.addSubview(heightSectionLabel)
        view.addSubview(heightContainer)
        heightContainer.addSubview(heightField)
        heightContainer.addSubview(heightClearButton)

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

            saveButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: s(-18)),
            saveButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            separatorLine.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5),

            // 体重：小标题距分割线 56px(28pt)，输入行再隔 32px(16pt)
            weightSectionLabel.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: s(28)),
            weightSectionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: s(24)),

            weightContainer.topAnchor.constraint(equalTo: weightSectionLabel.bottomAnchor, constant: s(16)),
            weightContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            weightContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            weightContainer.heightAnchor.constraint(equalToConstant: s(50)),

            weightField.leadingAnchor.constraint(equalTo: weightContainer.leadingAnchor, constant: s(24)),
            weightField.topAnchor.constraint(equalTo: weightContainer.topAnchor),
            weightField.bottomAnchor.constraint(equalTo: weightContainer.bottomAnchor),
            weightField.trailingAnchor.constraint(equalTo: weightClearButton.leadingAnchor, constant: -s(10)),

            weightClearButton.trailingAnchor.constraint(equalTo: weightContainer.trailingAnchor, constant: -s(18)),
            weightClearButton.centerYAnchor.constraint(equalTo: weightContainer.centerYAnchor),
            weightClearButton.widthAnchor.constraint(equalToConstant: s(20)),
            weightClearButton.heightAnchor.constraint(equalToConstant: s(20)),

            // 身高：与上一行输入框间距 60px(30pt)
            heightSectionLabel.topAnchor.constraint(equalTo: weightContainer.bottomAnchor, constant: s(30)),
            heightSectionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: s(24)),

            heightContainer.topAnchor.constraint(equalTo: heightSectionLabel.bottomAnchor, constant: s(16)),
            heightContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            heightContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heightContainer.heightAnchor.constraint(equalToConstant: s(50)),

            heightField.leadingAnchor.constraint(equalTo: heightContainer.leadingAnchor, constant: s(24)),
            heightField.topAnchor.constraint(equalTo: heightContainer.topAnchor),
            heightField.bottomAnchor.constraint(equalTo: heightContainer.bottomAnchor),

            heightClearButton.trailingAnchor.constraint(equalTo: heightContainer.trailingAnchor, constant: -s(18)),
            heightClearButton.centerYAnchor.constraint(equalTo: heightContainer.centerYAnchor),
            heightClearButton.widthAnchor.constraint(equalToConstant: s(20)),
            heightClearButton.heightAnchor.constraint(equalToConstant: s(20))
        ])

        guard imperial else {
            heightField.trailingAnchor.constraint(equalTo: heightClearButton.leadingAnchor, constant: -s(10)).isActive = true
            return
        }
        // 英制身高：同一输入行里「[英尺] ft  [英寸] in」，两格都只收整数。
        heightField.keyboardType = .numberPad
        inchField.keyboardType = .numberPad
        // 输入框随数字宽度收缩，单位紧跟在数字后面
        [heightField, inchField].forEach { $0.setContentHuggingPriority(.required, for: .horizontal) }
        [inchField, feetUnitLabel, inchUnitLabel].forEach { heightContainer.addSubview($0) }
        NSLayoutConstraint.activate([
            heightField.widthAnchor.constraint(greaterThanOrEqualToConstant: s(14)),
            feetUnitLabel.leadingAnchor.constraint(equalTo: heightField.trailingAnchor, constant: s(4)),
            feetUnitLabel.centerYAnchor.constraint(equalTo: heightContainer.centerYAnchor),

            inchField.leadingAnchor.constraint(equalTo: feetUnitLabel.trailingAnchor, constant: s(24)),
            inchField.topAnchor.constraint(equalTo: heightContainer.topAnchor),
            inchField.bottomAnchor.constraint(equalTo: heightContainer.bottomAnchor),
            inchField.widthAnchor.constraint(greaterThanOrEqualToConstant: s(14)),
            inchUnitLabel.leadingAnchor.constraint(equalTo: inchField.trailingAnchor, constant: s(4)),
            inchUnitLabel.centerYAnchor.constraint(equalTo: heightContainer.centerYAnchor),
            inchUnitLabel.trailingAnchor.constraint(lessThanOrEqualTo: heightClearButton.leadingAnchor, constant: -s(10))
        ])
    }

    /// 把存着的 kg / cm 换成 lb、ft/in 填进输入框。
    private func fillImperialFields() {
        if let kg = Double(currentWeight ?? "") {
            weightField.text = String(UnitDisplay.pounds(kilograms: kg))
        }
        if let cm = Double(currentHeight ?? "") {
            let (ft, inch) = UnitDisplay.feetInches(centimeters: cm)
            heightField.text = String(ft)
            inchField.text = String(inch)
        }
    }

    private func setupActions() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(handleSave), for: .touchUpInside)
        weightClearButton.addTarget(self, action: #selector(clearWeight), for: .touchUpInside)
        heightClearButton.addTarget(self, action: #selector(clearHeight), for: .touchUpInside)
        weightField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        heightField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        inchField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        weightField.delegate = self
        heightField.delegate = self
        inchField.delegate = self
    }

    // MARK: - Actions
    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func handleSave() {
        if imperial {
            saveImperial()
            return
        }
        let weight = normalized(weightField.text)
        let height = normalized(heightField.text)

        // 空 = 用户不想填，允许保存；填了就必须落在合理区间内。
        guard valueIsAcceptable(weight, range: Self.weightRange) else {
            showInvalidAlert()
            return
        }
        guard valueIsAcceptable(height, range: Self.heightRange) else {
            showInvalidAlert()
            return
        }

        onSave?(weight, height)
        dismiss(animated: true, completion: nil)
    }

    /// 英制输入换回 kg / cm。数值没改动（换算回来仍是原来显示的那个数）就原样回传，
    /// 免得用户只是点了保存，75 kg 就因为来回换算变成 74.8 kg。
    private func saveImperial() {
        let poundText = normalized(weightField.text)
        var weight = ""
        if !poundText.isEmpty {
            guard let lb = Double(poundText), Self.poundRange.contains(lb) else {
                showInvalidAlert()
                return
            }
            if let kg = Double(currentWeight ?? ""), Double(UnitDisplay.pounds(kilograms: kg)) == lb {
                weight = normalized(currentWeight)
            } else {
                weight = normalized(String(format: "%.1f", lb / UnitDisplay.poundsPerKilogram))
            }
        }

        let feetText = normalized(heightField.text)
        let inchText = normalized(inchField.text)
        var height = ""
        if !feetText.isEmpty || !inchText.isEmpty {
            guard let ft = Int(feetText.isEmpty ? "0" : feetText),
                  let inch = Int(inchText.isEmpty ? "0" : inchText),
                  (0...11).contains(inch),
                  Self.inchRange.contains(ft * 12 + inch) else {
                showInvalidAlert()
                return
            }
            if let cm = Double(currentHeight ?? ""), UnitDisplay.feetInches(centimeters: cm) == (ft, inch) {
                height = normalized(currentHeight)
            } else {
                height = String(Int((Double(ft * 12 + inch) * UnitDisplay.centimetersPerInch).rounded()))
            }
        }

        onSave?(weight, height)
        dismiss(animated: true, completion: nil)
    }

    private func valueIsAcceptable(_ text: String, range: ClosedRange<Double>) -> Bool {
        if text.isEmpty { return true }
        guard let value = Double(text) else { return false }
        return range.contains(value)
    }

    /// 去空格；把逗号小数点（部分语言键盘）统一成点，并去掉 "75.0" 这种多余的尾零。
    private func normalized(_ text: String?) -> String {
        var value = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: ",", with: ".")
        guard !value.isEmpty, let number = Double(value) else { return value }
        return number == number.rounded() ? String(Int(number)) : value
    }

    private func showInvalidAlert() {
        let alert = CustomAlertViewController(
            title: L("user_profile.weight_height"),
            description: L("user_profile.weight_height_invalid"),
            confirmButtonTitle: L("common.confirm"),
            cancelButtonTitle: nil,
            onConfirm: nil
        )
        present(alert, animated: true)
    }

    @objc private func clearWeight() {
        weightField.text = ""
        updateClearButtons()
    }

    @objc private func clearHeight() {
        heightField.text = ""
        inchField.text = ""
        updateClearButtons()
    }

    @objc private func textFieldDidChange() {
        updateClearButtons()
    }

    private func updateClearButtons() {
        weightClearButton.isHidden = (weightField.text ?? "").isEmpty
        heightClearButton.isHidden = (heightField.text ?? "").isEmpty && (inchField.text ?? "").isEmpty
    }

    // MARK: - UITextFieldDelegate
    // 数字键盘上没有「完成」，但仍要挡住多个小数点与超长输入。
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard !string.isEmpty else { return true }
        let current = textField.text ?? ""
        guard let stringRange = Range(range, in: current) else { return true }
        let updated = current.replacingCharacters(in: stringRange, with: string)
        // 英制身高两格只收整数：英尺 1 位、英寸 2 位
        if imperial, textField === heightField || textField === inchField {
            let limit = textField === heightField ? 1 : 2
            return updated.count <= limit && string.allSatisfy { "0123456789".contains($0) }
        }
        if updated.count > 6 { return false }
        let separators = updated.filter { $0 == "." || $0 == "," }.count
        if separators > 1 { return false }
        let allowed = CharacterSet(charactersIn: "0123456789.,")
        return string.rangeOfCharacter(from: allowed.inverted) == nil
    }
}
