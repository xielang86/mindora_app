import UIKit

/// 新增 / 编辑收货地址。
///
/// 版式沿用原设计稿：顶部「智能粘贴」框 + 60pt 高的表单行（标题 s(80) 宽、输入左对齐、
/// 底部 0.5pt 分隔线）+ 底部「设为默认」开关 + 固定在底部的确认按钮。
/// 这次只是把原来的「所在地区 + 详细地址」两段自由文本拆成结构化字段
/// （国家 / 州省 / 城市 / 街道 / 邮编）—— 地址要同步到商城发货，承运商按
/// state 两位码 + ZIP 分区，拼在一起的自由文本对面拆不出来。
class AddressAddEditViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Properties
    var existingAddress: AddrModel? // If set, we are editing
    var onSave: ((AddrModel) -> Void)?

    /// 表单当前选中的国家。切换国家会重排「州/省」这一行（下拉还是自由文本）与邮编规则。
    private var countryCode: String = AddressCatalog.defaultCountryCode()
    /// 电话区号所属国家，默认跟随收货国家，但允许不同（人在美国、号码是中国号很常见）。
    private var phoneCountryCode: String = AddressCatalog.defaultCountryCode()
    private var stateCode: String = ""
    private var stateName: String = ""
    /// 中国的市 / 区是三级联动，需要记住市的区划码才能取到下一级。
    private var cityCode: String = ""
    private var districtName: String = ""

    // MARK: - Scaled Metrics Helper
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

    /// 表单行竖排容器。行本身仍是原设计稿的 60pt 样式，这里只负责按顺序摞起来。
    private let formStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // 表单字段
    private let nameField = AddressAddEditViewController.makeField()
    private let phoneField = AddressAddEditViewController.makeField()
    private let stateField = AddressAddEditViewController.makeField()
    private let cityField = AddressAddEditViewController.makeField()
    private let street1Field = AddressAddEditViewController.makeField()
    private let street2Field = AddressAddEditViewController.makeField()
    private let zipField = AddressAddEditViewController.makeField()

    /// 手机号前面的区号，沿用原来那一行的样式，只是把输入框往右挪了一个区号的位置。
    private let phoneCodeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        btn.contentHorizontalAlignment = .left
        return btn
    }()

    private let countryValueLabel = AddressAddEditViewController.makeValueLabel()
    private let stateValueLabel = AddressAddEditViewController.makeValueLabel()
    private let cityValueLabel = AddressAddEditViewController.makeValueLabel()
    private let districtValueLabel = AddressAddEditViewController.makeValueLabel()
    /// 市这一格：有下级区划的国家（中国）放选择器，其余国家放自由输入框。
    private let citySlot = UIView()

    // 「定位」按钮：原设计稿挂在「所在地区」那一行的右侧，这里保持不动，挂在「国家/地区」行。
    private let locateButton = UIButton()

    private lazy var countryRow = makeTapRow(title: L("address.country"),
                                             valueLabel: countryValueLabel,
                                             action: #selector(handlePickCountry),
                                             accessory: locateButton)
    /// 「州/省 + 城市」同一行的左半格：有区划表时放选择器的值，没有时放自由输入框。
    private let stateSlot = UIView()
    /// 这一行里两个格子的左右次序随国家变，所以用横向 stack 装，重排时直接调顺序。
    private let pairStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    /// scrollView 底部约束。键盘弹出时把它顶到键盘上方 —— 只加 contentInset 不够，
    /// 表单本身比可视区短的时候根本滚不动，底部那几行照样被盖住。
    private var scrollBottomConstraint: NSLayoutConstraint!
    private var cityStateTitleLabel: UILabel!
    private var zipTitleLabel: UILabel!
    private lazy var cityStateRow = makeCityStateRow()
    private lazy var districtRow = makeTapRow(title: L("address.district"),
                                              valueLabel: districtValueLabel,
                                              action: #selector(handlePickDistrict),
                                              accessory: nil)
    private lazy var line1Row = makeFieldRow(title: L("address.street1"), field: street1Field)
    private lazy var line2Row = makeFieldRow(title: L("address.street2"), field: street2Field)
    private lazy var zipRow = makeZipRow()

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
        button.backgroundColor = UIColor(white: 1, alpha: 0.2)
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
        applyCountry()
    }

    // Helper to add locate icon and text（与原实现一致）
    private func setupLocateButton() {
        locateButton.translatesAutoresizingMaskIntoConstraints = false
        let iv = UIImageView(image: UIImage(named: "address_small"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text = L("address.locate")
        lbl.textColor = UIColor(white: 1, alpha: 0.5)
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

    private func populateData() {
        // 老记录只有 region / detail，先尽量拆成结构化字段预填，用户核对后再保存。
        guard let model = existingAddress?.migratedForEditing() else { return }
        nameField.text = model.name
        countryCode = model.countryCode.isEmpty ? AddressCatalog.defaultCountryCode() : model.countryCode
        let (phoneCountry, national) = AddressCatalog.splitE164(model.phone, hintCountry: countryCode)
        phoneCountryCode = phoneCountry
        phoneField.text = national
        stateCode = model.stateCode
        stateName = model.state
        stateField.text = model.state
        cityField.text = model.city
        cityCode = AddressCatalog.cityCode(provinceCode: model.stateCode, cityName: model.city)
        districtName = model.district
        street1Field.text = model.street1
        street2Field.text = model.street2
        zipField.text = model.zip
        defaultSwitch.isOn = model.isDefault
    }

    // MARK: - Row builders（沿用原设计稿：60pt 行高、标题 s(80) 宽、输入左对齐）

    private static func makeField() -> UITextField {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.textColor = .white
        tf.font = UIFont(name: "PingFangSC-Regular", size: 16)
        tf.borderStyle = .none
        tf.autocorrectionType = .no
        return tf
    }

    private static func makeValueLabel() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor(white: 1, alpha: 0.5)
        label.font = UIFont(name: "PingFangSC-Regular", size: 16)
        return label
    }

    private func placeholder(_ field: UITextField, _ text: String) {
        field.attributedPlaceholder = NSAttributedString(
            string: text,
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.3)])
    }

    private func makeRowShell(title: String) -> (row: UIView, titleLabel: UILabel) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.text = title
        titleLbl.textColor = .white
        titleLbl.font = UIFont(name: "PingFangSC-Regular", size: 16)
        // 标题宽度固定，保证各行的输入起点对齐（原实现的做法）。
        titleLbl.widthAnchor.constraint(equalToConstant: s(80)).isActive = true
        titleLbl.adjustsFontSizeToFitWidth = true
        titleLbl.minimumScaleFactor = 0.8
        // 英文标签（Phone Number / Street Address / Country/Region）在固定宽度里一行放不下，
        // 允许折成两行（行高 60pt 足够），不截断。
        titleLbl.numberOfLines = 2
        titleLbl.lineBreakMode = .byWordWrapping
        container.addSubview(titleLbl)

        let sep = UIView()
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.backgroundColor = UIColor(white: 1, alpha: 0.1)
        container.addSubview(sep)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 60),
            titleLbl.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLbl.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -1),
            sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        return (container, titleLbl)
    }

    private func makeFieldRow(title: String, field: UITextField) -> UIView {
        let shell = makeRowShell(title: title)
        field.delegate = self
        shell.row.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: shell.titleLabel.trailingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: shell.row.trailingAnchor),
            field.centerYAnchor.constraint(equalTo: shell.row.centerYAnchor, constant: -1),
            field.heightAnchor.constraint(equalToConstant: 44)
        ])
        return shell.row
    }

    /// 点击弹选择器的行。样式与原「所在地区」行一致：标题 + 左对齐的值 +（可选）右侧配件。
    private func makeTapRow(title: String, valueLabel: UILabel, action: Selector, accessory: UIView?) -> UIView {
        let shell = makeRowShell(title: title)
        shell.row.addSubview(valueLabel)

        if let accessory {
            shell.row.addSubview(accessory)
            NSLayoutConstraint.activate([
                accessory.trailingAnchor.constraint(equalTo: shell.row.trailingAnchor),
                accessory.centerYAnchor.constraint(equalTo: shell.row.centerYAnchor, constant: -1),
                valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: accessory.leadingAnchor, constant: -10)
            ])
        } else {
            valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: shell.row.trailingAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            valueLabel.leadingAnchor.constraint(equalTo: shell.titleLabel.trailingAnchor, constant: 10),
            valueLabel.centerYAnchor.constraint(equalTo: shell.row.centerYAnchor, constant: -1)
        ])
        shell.row.isUserInteractionEnabled = true
        shell.row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
        return shell.row
    }

    /// 州/省与城市并排一行：这两项是同一层级的行政区划，分成两行既占地方，
    /// 视觉上也读不出「先选州再填市」的关系。左右次序随国家变（见 applyCountry）。
    private func makeCityStateRow() -> UIView {
        let shell = makeRowShell(title: L("address.city"))
        cityStateTitleLabel = shell.titleLabel
        stateSlot.translatesAutoresizingMaskIntoConstraints = false
        stateField.delegate = self
        cityField.delegate = self

        stateSlot.addSubview(stateValueLabel)
        stateSlot.addSubview(stateField)
        citySlot.translatesAutoresizingMaskIntoConstraints = false
        citySlot.addSubview(cityValueLabel)
        citySlot.addSubview(cityField)
        shell.row.addSubview(pairStack)

        NSLayoutConstraint.activate([
            pairStack.leadingAnchor.constraint(equalTo: shell.titleLabel.trailingAnchor, constant: 10),
            pairStack.trailingAnchor.constraint(equalTo: shell.row.trailingAnchor),
            pairStack.centerYAnchor.constraint(equalTo: shell.row.centerYAnchor, constant: -1),
            pairStack.heightAnchor.constraint(equalToConstant: 44),

            stateValueLabel.leadingAnchor.constraint(equalTo: stateSlot.leadingAnchor),
            stateValueLabel.trailingAnchor.constraint(lessThanOrEqualTo: stateSlot.trailingAnchor),
            stateValueLabel.centerYAnchor.constraint(equalTo: stateSlot.centerYAnchor),

            stateField.leadingAnchor.constraint(equalTo: stateSlot.leadingAnchor),
            stateField.trailingAnchor.constraint(equalTo: stateSlot.trailingAnchor),
            stateField.centerYAnchor.constraint(equalTo: stateSlot.centerYAnchor),

            cityValueLabel.leadingAnchor.constraint(equalTo: citySlot.leadingAnchor),
            cityValueLabel.trailingAnchor.constraint(lessThanOrEqualTo: citySlot.trailingAnchor),
            cityValueLabel.centerYAnchor.constraint(equalTo: citySlot.centerYAnchor),

            cityField.leadingAnchor.constraint(equalTo: citySlot.leadingAnchor),
            cityField.trailingAnchor.constraint(equalTo: citySlot.trailingAnchor),
            cityField.centerYAnchor.constraint(equalTo: citySlot.centerYAnchor)
        ])

        stateSlot.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handlePickState)))
        citySlot.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handlePickCity)))
        return shell.row
    }

    private func makeZipRow() -> UIView {
        let shell = makeRowShell(title: L("address.zip"))
        zipTitleLabel = shell.titleLabel
        zipField.delegate = self
        shell.row.addSubview(zipField)
        NSLayoutConstraint.activate([
            zipField.leadingAnchor.constraint(equalTo: shell.titleLabel.trailingAnchor, constant: 10),
            zipField.trailingAnchor.constraint(equalTo: shell.row.trailingAnchor),
            zipField.centerYAnchor.constraint(equalTo: shell.row.centerYAnchor, constant: -1),
            zipField.heightAnchor.constraint(equalToConstant: 44)
        ])
        return shell.row
    }

    private func makePhoneRow() -> UIView {
        let shell = makeRowShell(title: L("address.phone"))
        phoneField.delegate = self
        phoneField.keyboardType = .phonePad
        shell.row.addSubview(phoneCodeButton)
        shell.row.addSubview(phoneField)
        NSLayoutConstraint.activate([
            phoneCodeButton.leadingAnchor.constraint(equalTo: shell.titleLabel.trailingAnchor, constant: 10),
            phoneCodeButton.centerYAnchor.constraint(equalTo: shell.row.centerYAnchor, constant: -1),
            phoneCodeButton.widthAnchor.constraint(equalToConstant: 56),
            phoneField.leadingAnchor.constraint(equalTo: phoneCodeButton.trailingAnchor, constant: 4),
            phoneField.trailingAnchor.constraint(equalTo: shell.row.trailingAnchor),
            phoneField.centerYAnchor.constraint(equalTo: shell.row.centerYAnchor, constant: -1),
            phoneField.heightAnchor.constraint(equalToConstant: 44)
        ])
        phoneCodeButton.addTarget(self, action: #selector(handlePickPhoneCountry), for: .touchUpInside)
        return shell.row
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)

        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        view.addSubview(separatorLine)

        view.addSubview(scrollView)
        scrollView.addSubview(smartPasteContainer)
        smartPasteContainer.addSubview(smartPasteLabel)
        smartPasteContainer.addSubview(pasteButton)
        scrollView.addSubview(formStack)
        scrollView.addSubview(defaultSwitchRow)
        defaultSwitchRow.addSubview(defaultLabel)
        defaultSwitchRow.addSubview(defaultSwitch)

        view.addSubview(confirmButton) // Fixed at bottom

        placeholder(nameField, L("address.name_placeholder"))
        placeholder(stateField, L("address.state_placeholder"))
        placeholder(cityField, L("address.city_placeholder"))
        placeholder(street1Field, L("address.street1_placeholder"))
        placeholder(street2Field, L("address.street2_placeholder"))

        // 顺序按国际通行的收件人 → 联系方式 → 由大到小的行政区划来排。
        // 收件人 / 手机号 / 国家三行所有国家都在最前，后面几行的顺序由 applyCountry 按国家决定。
        formStack.addArrangedSubview(makeFieldRow(title: L("address.name"), field: nameField))
        formStack.addArrangedSubview(makePhoneRow())
        formStack.addArrangedSubview(countryRow)

        setupConstraints()
    }

    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        let margin = s(20)

        scrollBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: confirmButton.topAnchor, constant: -20)
        scrollBottomConstraint.isActive = true

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

            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: s(32)),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -s(32)),
            confirmButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -s(34)),
            confirmButton.heightAnchor.constraint(equalToConstant: 50),

            scrollView.topAnchor.constraint(equalTo: separatorLine.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Smart Paste
            smartPasteContainer.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            smartPasteContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: margin),
            smartPasteContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -margin * 2),
            smartPasteContainer.heightAnchor.constraint(equalToConstant: 80),

            smartPasteLabel.leadingAnchor.constraint(equalTo: smartPasteContainer.leadingAnchor, constant: 16),
            smartPasteLabel.centerYAnchor.constraint(equalTo: smartPasteContainer.centerYAnchor),

            pasteButton.trailingAnchor.constraint(equalTo: smartPasteContainer.trailingAnchor, constant: -16),
            pasteButton.centerYAnchor.constraint(equalTo: smartPasteContainer.centerYAnchor),
            pasteButton.widthAnchor.constraint(equalToConstant: 60),
            pasteButton.heightAnchor.constraint(equalToConstant: 28),

            // Rows
            formStack.topAnchor.constraint(equalTo: smartPasteContainer.bottomAnchor, constant: 20),
            formStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: margin),
            formStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -margin * 2),

            // Default Switch
            defaultSwitchRow.topAnchor.constraint(equalTo: formStack.bottomAnchor, constant: 20),
            defaultSwitchRow.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: margin),
            defaultSwitchRow.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -margin * 2),
            defaultSwitchRow.heightAnchor.constraint(equalToConstant: 50),

            defaultLabel.leadingAnchor.constraint(equalTo: defaultSwitchRow.leadingAnchor),
            defaultLabel.centerYAnchor.constraint(equalTo: defaultSwitchRow.centerYAnchor),

            defaultSwitch.trailingAnchor.constraint(equalTo: defaultSwitchRow.trailingAnchor),
            defaultSwitch.centerYAnchor.constraint(equalTo: defaultSwitchRow.centerYAnchor),

            defaultSwitchRow.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20)
        ])
    }

    /// 国家一变，整张表要跟着重排：字段顺序、州省这一栏的叫法、邮编叫 ZIP 还是 Postal code。
    ///
    /// 参考 Google libaddressinput 的国别地址格式 —— 美国是「地址 → 城市 → 州 → 邮编」，
    /// 中日韩是「邮编 → 省 → 市 → 地址」由大到小。顺序不对用户会一直填错格子。
    private func applyCountry() {
        // 先把几行都实例化出来再动它们的内容：这些行是 lazy 的，而标题 label 是在行构造里
        // 才赋值的隐式解包属性 —— 少了这一句，下面第一次读 cityStateTitleLabel 就是 nil 崩溃。
        let reorderableRows = [cityStateRow, districtRow, line1Row, line2Row, zipRow]

        countryValueLabel.text = AddressCatalog.countryName(countryCode)
        countryValueLabel.textColor = .white

        // 1. 州/省这一格：有区划表的国家（美/加/中）用选择器，其余国家退化成自由文本；
        //    英国、德国、新加坡这类地址里根本没有州省，整格隐藏。
        let hasList = AddressCatalog.subdivisions(for: countryCode) != nil
        let showsState = AddressCatalog.showsSubdivision(countryCode)
        stateValueLabel.isHidden = !hasList
        stateField.isHidden = hasList
        stateSlot.isUserInteractionEnabled = hasList
        stateValueLabel.text = stateName.isEmpty ? L("address.select") : stateName
        stateValueLabel.textColor = stateName.isEmpty ? UIColor(white: 1, alpha: 0.5) : .white
        placeholder(stateField, L(AddressCatalog.subdivisionLabelKey(for: countryCode)))

        // 2. 市这一格：中国的市是省的下级，用选择器联动；其余国家是自由文本。
        let cascading = AddressCatalog.hasCascadingCity(countryCode)
        cityValueLabel.isHidden = !cascading
        cityField.isHidden = cascading
        citySlot.isUserInteractionEnabled = cascading
        let cityText = cityField.text ?? ""
        cityValueLabel.text = cityText.isEmpty ? L("address.select") : cityText
        cityValueLabel.textColor = cityText.isEmpty ? UIColor(white: 1, alpha: 0.5) : .white

        // 3. 城市 / 州省这一行的左右次序：英美系先城市后州，东亚系先省后市。
        let stateFirst = AddressCatalog.layout(for: countryCode) == .postalFirst
        pairStack.arrangedSubviews.forEach { pairStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        if showsState {
            let ordered = stateFirst ? [stateSlot, citySlot] : [citySlot, stateSlot]
            ordered.forEach { pairStack.addArrangedSubview($0) }
            cityStateTitleLabel.text = stateFirst
                ? L(AddressCatalog.subdivisionLabelKey(for: countryCode))
                : L("address.city")
        } else {
            pairStack.addArrangedSubview(citySlot)
            cityStateTitleLabel.text = L("address.city")
        }

        // 4. 区/县：只有中国这类三级区划的国家才有这一行。
        districtValueLabel.text = districtName.isEmpty ? L("address.select") : districtName
        districtValueLabel.textColor = districtName.isEmpty ? UIColor(white: 1, alpha: 0.5) : .white

        // 3. 邮编：叫法与键盘类型。
        zipTitleLabel.text = L(AddressCatalog.zipLabelKey(for: countryCode))
        let zipHint = AddressCatalog.zipPlaceholder(countryCode)
        placeholder(zipField, zipHint.isEmpty ? L("address.zip_placeholder") : zipHint)
        zipField.keyboardType = countryCode == "US" ? .numbersAndPunctuation : .default
        zipRow.isHidden = !AddressCatalog.requiresZip(countryCode) && zipField.text?.isEmpty != false

        // 4. 行顺序。
        for row in reorderableRows {
            if row.superview != nil { formStack.removeArrangedSubview(row) }
            row.removeFromSuperview()
        }
        for field in AddressCatalog.fieldOrder(for: countryCode) {
            switch field {
            case .line1: formStack.addArrangedSubview(line1Row)
            case .line2: formStack.addArrangedSubview(line2Row)
            case .cityState: formStack.addArrangedSubview(cityStateRow)
            case .district: formStack.addArrangedSubview(districtRow)
            case .zip: if !zipRow.isHidden { formStack.addArrangedSubview(zipRow) }
            }
        }

        phoneCodeButton.setTitle(AddressCatalog.callingCode(for: phoneCountryCode), for: .normal)
        let phoneHint = AddressCatalog.phoneExample(for: phoneCountryCode)
        placeholder(phoneField, phoneHint.isEmpty ? L("address.phone_placeholder") : phoneHint)
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
        // 用全 App 统一那套：它的手势代理会放过输入框和控件自身，只在空白处收起。
        installTapToDismissKeyboard()

        // 键盘避让：表单比一屏长，「地址 / 详细地址 / 邮编」这几行在下半屏，
        // 键盘一弹就把正在输入的框盖住了，用户看不见自己打的字。
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleKeyboardFrameChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleKeyboardHide),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func handleKeyboardFrameChange(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardTop = view.convert(frame, from: nil).minY
        let overlap = max(0, view.bounds.height - keyboardTop)
        guard overlap > 0 else { return handleKeyboardHide() }

        // 可视区直接压到键盘上方（不是加 inset）：表单不一定比屏幕长，
        // 只加 inset 的话内容根本滚不动，底部几行还是被盖着。
        scrollBottomConstraint.isActive = false
        scrollBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor,
                                                                   constant: -overlap - 12)
        scrollBottomConstraint.isActive = true
        view.layoutIfNeeded()
        scrollToActiveField()
    }

    @objc private func handleKeyboardHide() {
        scrollBottomConstraint.isActive = false
        scrollBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: confirmButton.topAnchor,
                                                                   constant: -20)
        scrollBottomConstraint.isActive = true
        view.layoutIfNeeded()
    }

    /// 把当前正在编辑的那一行滚进可见区域。
    ///
    /// 手动算偏移而不用 `scrollRectToVisible`：后者对 contentInset 的处理在不同系统版本上
    /// 表现不一致，这里的可视区又是靠约束压出来的，自己算最稳。
    private func scrollToActiveField() {
        let fields: [UITextField] = [nameField, phoneField, stateField, cityField,
                                     street1Field, street2Field, zipField]
        guard let active = fields.first(where: { $0.isFirstResponder }) else { return }
        // 从输入框往上找到它所在的那一行（formStack 的直接子视图）：
        // 城市 / 州省是嵌在格子 + 横向 stack 里的，不能只取 superview。
        var node: UIView = active
        while let parent = node.superview, parent !== formStack { node = parent }
        let row = node

        let rowFrame = row.convert(row.bounds, to: scrollView)
        let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let visibleBottom = scrollView.contentOffset.y + scrollView.bounds.height
        guard rowFrame.maxY > visibleBottom - 8 else { return }
        let target = min(rowFrame.maxY + 8 - scrollView.bounds.height, maxOffset)
        scrollView.setContentOffset(CGPoint(x: 0, y: max(0, target)), animated: true)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        scrollToActiveField()
    }

    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }

    /// 智能粘贴：从剪贴板里抠出电话和姓名，剩下的按行政区划关键字拆。
    ///
    /// 只对中文地址有效（切「省/市/区/县」这些字），英文地址拆不出来，
    /// 所以拆不动时就整段丢进「街道地址」，让用户自己挪 —— 总比什么都不填强。
    @objc private func handlePaste() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        var remaining = text

        // 1. 电话：先试国际格式，再试中国大陆手机号。
        if let range = remaining.range(of: "\\+\\d[\\d\\- ]{6,17}", options: .regularExpression)
            ?? remaining.range(of: "1\\d{10}", options: .regularExpression) {
            let raw = String(remaining[range])
            let (country, national) = AddressCatalog.splitE164(raw.filter { !$0.isWhitespace && $0 != "-" },
                                                              hintCountry: countryCode)
            phoneCountryCode = country
            phoneField.text = national
            remaining.removeSubrange(range)
        }

        remaining = remaining.replacingOccurrences(of: "，", with: " ")
        remaining = remaining.replacingOccurrences(of: ",", with: " ")
        remaining = remaining.trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. 姓名：不超过 4 个字的那一段。
        var parts = remaining.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if let idx = parts.firstIndex(where: { $0.count <= 4 && $0.rangeOfCharacter(from: .decimalDigits) == nil }) {
            nameField.text = parts[idx]
            parts.remove(at: idx)
        }
        let addressText = parts.joined(separator: " ")
        guard !addressText.isEmpty else { applyCountry(); return }

        // 3. 行政区划：能匹配上省份就填进「州/省」，剩下的进城市 / 街道。
        var rest = addressText
        if let list = AddressCatalog.subdivisions(for: countryCode),
           let hit = list.first(where: { addressText.contains($0.name) }) {
            stateCode = hit.code
            stateName = hit.name
            stateField.text = hit.name
            rest = rest.replacingOccurrences(of: hit.name, with: "")
        }
        if let range = rest.range(of: "[^\\s]*?[市县区]", options: .regularExpression) {
            cityField.text = String(rest[range]).trimmingCharacters(in: .whitespaces)
            rest = String(rest[range.upperBound...])
        }
        street1Field.text = rest.trimmingCharacters(in: .whitespaces)
        applyCountry()
    }

    @objc private func handlePickCountry() {
        view.endEditing(true)
        let items = AddressCatalog.countries().map { AddressPickerSheet.Item(code: $0.code, name: $0.name) }
        AddressPickerSheet.present(title: L("address.country"), items: items, selectedCode: countryCode) { [weak self] item in
            guard let self = self else { return }
            guard item.code != self.countryCode else { return }
            self.countryCode = item.code
            // 换国家后旧的州码必然对不上（US-CA 到了加拿大就是另一回事），清掉重选。
            self.stateCode = ""
            self.stateName = ""
            self.stateField.text = ""
            self.cityCode = ""
            self.cityField.text = ""
            self.districtName = ""
            // 号码区号默认跟着收货国家走，用户仍可单独改。
            self.phoneCountryCode = item.code
            self.applyCountry()
        }
    }

    @objc private func handlePickPhoneCountry() {
        view.endEditing(true)
        let items = AddressCatalog.countries().map {
            AddressPickerSheet.Item(code: $0.code, name: "\($0.name) \(AddressCatalog.callingCode(for: $0.code))")
        }
        AddressPickerSheet.present(title: L("address.phone_country"), items: items, selectedCode: phoneCountryCode) { [weak self] item in
            self?.phoneCountryCode = item.code
            self?.applyCountry()
        }
    }

    @objc private func handlePickState() {
        view.endEditing(true)
        guard let list = AddressCatalog.subdivisions(for: countryCode) else { return }
        let items = list.map { AddressPickerSheet.Item(code: $0.code, name: $0.name) }
        AddressPickerSheet.present(title: L(AddressCatalog.subdivisionLabelKey(for: countryCode)),
                                   items: items,
                                   selectedCode: stateCode) { [weak self] item in
            guard let self = self else { return }
            guard item.code != self.stateCode else { return }
            self.stateCode = item.code
            self.stateName = item.name
            // 省换了，原来的市和区必然不属于新省，清掉重选。
            if AddressCatalog.hasCascadingCity(self.countryCode) {
                self.cityCode = ""
                self.cityField.text = ""
                self.districtName = ""
            }
            self.applyCountry()
        }
    }

    @objc private func handlePickCity() {
        view.endEditing(true)
        guard AddressCatalog.hasCascadingCity(countryCode) else { return }
        guard !stateCode.isEmpty else { return Toast.show(L("address.state_required"), in: view) }
        let items = AddressCatalog.cities(provinceCode: stateCode)
            .map { AddressPickerSheet.Item(code: $0.code, name: $0.name) }
        AddressPickerSheet.present(title: L("address.city"), items: items, selectedCode: cityCode) { [weak self] item in
            guard let self = self else { return }
            guard item.code != self.cityCode else { return }
            self.cityCode = item.code
            self.cityField.text = item.name
            self.districtName = ""   // 市换了，区跟着清
            self.applyCountry()
        }
    }

    @objc private func handlePickDistrict() {
        view.endEditing(true)
        guard !cityCode.isEmpty else { return Toast.show(L("address.city_required"), in: view) }
        let items = AddressCatalog.districts(provinceCode: stateCode, cityCode: cityCode)
            .map { AddressPickerSheet.Item(code: $0.code, name: $0.name) }
        AddressPickerSheet.present(title: L("address.district"), items: items, selectedCode: "") { [weak self] item in
            self?.districtName = item.name
            self?.applyCountry()
        }
    }

    @objc private func handleLocate() {
        let vc = AddressMapPickerViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.onSelectLocation = { [weak self] place in
            guard let self = self else { return }
            if !place.countryCode.isEmpty { self.countryCode = place.countryCode }
            if let list = AddressCatalog.subdivisions(for: self.countryCode) {
                // 定位回来的是州全名（California）或缩写，两种都试一下。
                let hit = list.first { $0.name.caseInsensitiveCompare(place.state) == .orderedSame }
                    ?? list.first { $0.code.caseInsensitiveCompare(place.state) == .orderedSame }
                self.stateCode = hit?.code ?? ""
                self.stateName = hit?.name ?? ""
            } else {
                self.stateCode = ""
                self.stateName = place.state
                self.stateField.text = place.state
            }
            if !place.city.isEmpty { self.cityField.text = place.city }
            if !place.street.isEmpty { self.street1Field.text = place.street }
            if !place.zip.isEmpty { self.zipField.text = place.zip }
            self.phoneCountryCode = self.countryCode
            self.applyCountry()
        }
        present(vc, animated: true)
    }

    @objc private func handleConfirm() {
        view.endEditing(true)
        let name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let phoneNational = phoneField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let city = cityField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let street1 = street1Field.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let street2 = street2Field.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let zip = zipField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let stateInput = AddressCatalog.subdivisions(for: countryCode) != nil
            ? stateName
            : (stateField.text?.trimmingCharacters(in: .whitespaces) ?? "")

        // 逐条给出具体原因。原来这里是 guard 里一个空 return，用户点了没反应也不知道差什么。
        guard !name.isEmpty else { return Toast.show(L("address.name_required"), in: view) }
        // 商城对收货人有硬要求：不得包含数字。面单上打的就是这个名字。
        guard name.rangeOfCharacter(from: .decimalDigits) == nil else {
            return Toast.show(L("address.name_invalid"), in: view)
        }
        guard AddressCatalog.isValidPhone(national: phoneNational, countryCode: phoneCountryCode) else {
            return Toast.show(L("address.phone_invalid"), in: view)
        }
        if AddressCatalog.requiresSubdivision(countryCode) && stateInput.isEmpty {
            return Toast.show(L("address.state_required"), in: view)
        }
        guard !city.isEmpty else { return Toast.show(L("address.city_required"), in: view) }
        guard !street1.isEmpty else { return Toast.show(L("address.street_required"), in: view) }
        guard AddressCatalog.isValidZip(zip, countryCode: countryCode) else {
            return Toast.show(L("address.zip_invalid"), in: view)
        }

        let model = AddrModel(id: existingAddress?.id ?? UUID().uuidString,
                              isDefault: defaultSwitch.isOn,
                              name: name,
                              phone: AddressCatalog.e164(national: phoneNational, countryCode: phoneCountryCode),
                              countryCode: countryCode,
                              stateCode: stateCode,
                              state: stateInput,
                              city: city,
                              district: districtName,
                              street1: street1,
                              street2: street2,
                              zip: zip)
        onSave?(model)
        dismiss(animated: true, completion: nil)
    }
}
