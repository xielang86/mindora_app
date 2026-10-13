//
//  SleepPlanSheets.swift
//  mindora
//
//  睡眠计划编辑页用到的全部底部浮层，均继承 FootprintBottomSheet（dim + 圆角顶部 sheet），
//  统一「取消 | 标题 | 确认」头部，对应设计稿 02/03 系列的各滚轮/列表/多选浮层。
//
import UIKit

// MARK: - 公共头部（取消 | 标题 | 确认）

private var sheetConfirmButtonKey: UInt8 = 0

extension FootprintBottomSheet {
    /// 头部「确认」按钮（校验不通过时按 .text_25 的 rgba(172,172,172,1) 置灰）。
    var sheetConfirmButton: UIButton? {
        get { objc_getAssociatedObject(self, &sheetConfirmButtonKey) as? UIButton }
        set { objc_setAssociatedObject(self, &sheetConfirmButtonKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 「确认」可用/置灰。
    func setSheetConfirmEnabled(_ enabled: Bool) {
        sheetConfirmButton?.setTitleColor(
            enabled ? SleepPlanTheme.valueBlue
                    : UIColor(red: 172/255, green: 172/255, blue: 172/255, alpha: 1), for: .normal)
    }

    /// 统一头部：左「取消」、中标题、右「确认」。返回内容区可用的顶部锚点。
    @discardableResult
    func addHeader(title: String, onCancel: @escaping () -> Void, onConfirm: @escaping () -> Void) -> NSLayoutYAxisAnchor {
        // .group_19/.box_30 等浮层容器: #2C2C2C（FootprintBottomSheet 默认的 #202022 是陪伴足迹自己的色，
        // 这里按睡眠计划设计稿精确色覆盖）。
        sheet.backgroundColor = SleepPlanTheme.cardBackground
        // .box_22/.group_19/.box_30: border-radius 36px 36px 0 0 → 顶部 18pt 圆角
        sheet.layer.cornerRadius = SleepPlanTheme.cardCornerRadius
        // .text_25 取消: 白 28px→14pt Regular
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(L("common.cancel"), for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionTitle)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addAction(UIAction { _ in onCancel() }, for: .touchUpInside)

        // .text_26 标题: 白 32px→16pt Regular（非加粗）
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = SleepPlanTheme.fontRegular(16)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // .text_27 确认: 浅蓝 rgba(151,178,246,1) 28px→14pt Medium
        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle(L("common.confirm"), for: .normal)
        confirmButton.setTitleColor(SleepPlanTheme.valueBlue, for: .normal)
        confirmButton.titleLabel?.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeOptionTitle)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.addAction(UIAction { _ in onConfirm() }, for: .touchUpInside)

        sheet.addSubview(cancelButton)
        sheet.addSubview(titleLabel)
        sheet.addSubview(confirmButton)

        // 浮层 padding: 80px 40px → 上 40pt / 左右 20pt
        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 40),
            cancelButton.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),

            titleLabel.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: sheet.centerXAnchor),

            confirmButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            confirmButton.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -20)
        ])
        sheetConfirmButton = confirmButton
        return cancelButton.bottomAnchor
    }
}

// MARK: - 入睡提醒：15/30/60/90 分钟滚轮

final class ReminderMinutesPickerSheet: FootprintBottomSheet, UIPickerViewDataSource, UIPickerViewDelegate {
    static let options = [15, 30, 60, 90]
    private let picker = UIPickerView()
    private var selected: Int
    private var onConfirm: ((Int) -> Void)?

    private init(current: Int) {
        self.selected = Self.options.contains(current) ? current : 30
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func present(in view: UIView, current: Int, onConfirm: @escaping (Int) -> Void) {
        let s = ReminderMinutesPickerSheet(current: current)
        s.onConfirm = onConfirm
        s.build()
        s.presentInWindow()
    }

    private func build() {
        let contentTop = addHeader(title: L("sleepplan.sheet.reminder.title"),
                                    onCancel: { [weak self] in self?.dismissSheet() },
                                    onConfirm: { [weak self] in
                                        guard let self else { return }
                                        self.dismissSheet { self.onConfirm?(self.selected) }
                                    })
        picker.dataSource = self
        picker.delegate = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: contentTop, constant: 8),
            picker.leadingAnchor.constraint(equalTo: sheet.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
            // 滚轮区 180pt + 底部留白 50pt。82 + 8 + 180 + 50 = 320pt，对上 .group_28 的
            // 浮层总高 637px→318.5pt。
            //
            // 这里返工过一次，把账算清楚免得再错：设计稿里选中项（.text-wrapper_7）中心
            // 距浮层顶 392.5px→196.25pt，而浮层中心才 159.25pt —— 选中项是**比中心低
            // 37pt** 的（它是 4 选 1 里的第 3 个，天然靠下），不是居中。上一版按「选中项
            // 应当居中」把滚轮压到 140pt，两头都输：选中项跑到比设计稿高 48pt 的位置，
            // 滚轮还矮到把第 4 个选项「90 分钟」切掉半行（下面却空着 60pt）。
            // 180pt 后选中项落在距顶 180pt，离设计稿只差 16pt，4 个选项也都完整。
            picker.heightAnchor.constraint(equalToConstant: 180),
            picker.bottomAnchor.constraint(equalTo: sheet.bottomAnchor, constant: -50)
        ])
        if let idx = Self.options.firstIndex(of: selected) { picker.selectRow(idx, inComponent: 0, animated: false) }
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { Self.options.count }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        String(format: L("sleepplan.sheet.reminder.minutes_before"), Self.options[row])
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selected = Self.options[row]
    }
}

// MARK: - 闹钟方案：声音滚轮

final class AlarmSoundPickerSheet: FootprintBottomSheet, UIPickerViewDataSource, UIPickerViewDelegate {
    static let options: [(id: String, nameKey: String)] = [
        ("temple_bell", "sleepplan.sound.temple_bell"),
        ("sunlit_coast", "sleepplan.sound.sunlit_coast"),
        ("rainforest_mist", "sleepplan.sound.rainforest_mist")
    ]
    private let picker = UIPickerView()
    private var selectedIndex: Int
    private var onConfirm: ((String) -> Void)?

    private init(current: String) {
        self.selectedIndex = Self.options.firstIndex { $0.id == current } ?? 1
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func present(in view: UIView, current: String, onConfirm: @escaping (String) -> Void) {
        let s = AlarmSoundPickerSheet(current: current)
        s.onConfirm = onConfirm
        s.build()
        s.presentInWindow()
    }

    private func build() {
        let contentTop = addHeader(title: L("sleepplan.sheet.alarm_sound.title"),
                                    onCancel: { [weak self] in self?.dismissSheet() },
                                    onConfirm: { [weak self] in
                                        guard let self else { return }
                                        let id = Self.options[self.selectedIndex].id
                                        self.dismissSheet { self.onConfirm?(id) }
                                    })
        picker.dataSource = self
        picker.delegate = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: contentTop, constant: 8),
            picker.leadingAnchor.constraint(equalTo: sheet.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
            // 滚轮区 180pt + 底部留白 50pt。82 + 8 + 180 + 50 = 320pt，对上 .group_28 的
            // 浮层总高 637px→318.5pt。
            //
            // 这里返工过一次，把账算清楚免得再错：设计稿里选中项（.text-wrapper_7）中心
            // 距浮层顶 392.5px→196.25pt，而浮层中心才 159.25pt —— 选中项是**比中心低
            // 37pt** 的（它是 4 选 1 里的第 3 个，天然靠下），不是居中。上一版按「选中项
            // 应当居中」把滚轮压到 140pt，两头都输：选中项跑到比设计稿高 48pt 的位置，
            // 滚轮还矮到把第 4 个选项「90 分钟」切掉半行（下面却空着 60pt）。
            // 180pt 后选中项落在距顶 180pt，离设计稿只差 16pt，4 个选项也都完整。
            picker.heightAnchor.constraint(equalToConstant: 180),
            picker.bottomAnchor.constraint(equalTo: sheet.bottomAnchor, constant: -50)
        ])
        picker.selectRow(selectedIndex, inComponent: 0, animated: false)
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { Self.options.count }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        L(Self.options[row].nameKey)
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedIndex = row
    }
}

// MARK: - 助眠方案：三项列表单选（非滚轮）

final class SleepAidPickerSheet: FootprintBottomSheet {
    static let categories: [(id: String, nameKey: String, descKey: String)] = [
        ("smart", "sleepplan.sleep_aid.smart.name", "sleepplan.sleep_aid.smart.desc"),
        ("preference", "sleepplan.sleep_aid.preference.name", "sleepplan.sleep_aid.preference.desc"),
        ("trending", "sleepplan.sleep_aid.trending.name", "sleepplan.sleep_aid.trending.desc")
    ]
    private var selectedId: String
    private var onConfirm: ((String) -> Void)?
    private var rows: [UIView] = []

    private init(current: String) {
        self.selectedId = current
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func present(in view: UIView, current: String, onConfirm: @escaping (String) -> Void) {
        let s = SleepAidPickerSheet(current: current)
        s.onConfirm = onConfirm
        s.build()
        s.presentInWindow()
    }

    private func build() {
        let contentTop = addHeader(title: L("sleepplan.sheet.sleep_aid.title"),
                                    onCancel: { [weak self] in self?.dismissSheet() },
                                    onConfirm: { [weak self] in
                                        guard let self else { return }
                                        self.dismissSheet { self.onConfirm?(self.selectedId) }
                                    })
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 13
        stack.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentTop, constant: 16),
            stack.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: sheet.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        for category in Self.categories {
            let row = makeRow(category: category)
            stack.addArrangedSubview(row)
        }
    }

    /// .list-items_1-N: #3C3C3C 卡片 + 2px 白描边 radius 36px→18pt；.box_24-N 左侧圆形选择态
    /// 36px→18pt（选中=rgba(102,117,242,1) 实心+白色对勾，未选=1px 描边空心）。
    private func makeRow(category: (id: String, nameKey: String, descKey: String)) -> UIView {
        let container = UIControl()
        container.backgroundColor = UIColor(red: 60/255, green: 60/255, blue: 60/255, alpha: 1)
        container.layer.cornerRadius = SleepPlanTheme.cardCornerRadius
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.white.cgColor

        let circle = UIView()
        circle.layer.cornerRadius = 9
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.tag = 100
        let check = UIImageView(image: UIImage(systemName: "checkmark"))
        check.tintColor = .white
        check.contentMode = .scaleAspectFit
        check.translatesAutoresizingMaskIntoConstraints = false
        check.tag = 101
        circle.addSubview(check)
        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 18),
            circle.heightAnchor.constraint(equalToConstant: 18),
            check.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            check.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            check.widthAnchor.constraint(equalToConstant: 9),
            check.heightAnchor.constraint(equalToConstant: 9)
        ])

        // .text_26-N: 白 28px→14pt Medium
        let nameLabel = UILabel()
        nameLabel.text = L(category.nameKey)
        nameLabel.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeOptionTitle)
        nameLabel.textColor = .white
        // .text_27/28-N: 白 22px→11pt Regular
        let descLabel = UILabel()
        descLabel.text = L(category.descKey)
        descLabel.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeDialogMessage)
        descLabel.textColor = .white
        descLabel.numberOfLines = 0
        let textStack = UIStackView(arrangedSubviews: [nameLabel, descLabel])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.isUserInteractionEnabled = false

        container.addSubview(circle)
        container.addSubview(textStack)
        NSLayoutConstraint.activate([
            // .list-items_1-x padding: 32px 120px 58px 32px → 上 16 / 右 60 / 下 29 / 左 16 pt
            circle.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            circle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            textStack.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: 8),
            textStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            textStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -29)
        ])
        container.addAction(UIAction { [weak self] _ in self?.select(id: category.id) }, for: .touchUpInside)
        container.tag = Self.categories.firstIndex { $0.id == category.id } ?? 0
        rows.append(container)
        applyState(to: container, category: category)
        return container
    }

    private func select(id: String) {
        selectedId = id
        for row in rows {
            applyState(to: row, category: Self.categories[row.tag])
        }
    }

    private func applyState(to row: UIView, category: (id: String, nameKey: String, descKey: String)) {
        guard let circle = row.viewWithTag(100) else { return }
        let isOn = category.id == selectedId
        circle.viewWithTag(101)?.isHidden = !isOn
        circle.backgroundColor = isOn ? SleepPlanTheme.sleepBlue : .clear
        circle.layer.borderWidth = isOn ? 0 : 1
        circle.layer.borderColor = UIColor(red: 212/255, green: 212/255, blue: 212/255, alpha: 1).cgColor
    }
}

// MARK: - 执行周期：周一至周日多选 + 每周重复

final class WeekdayCyclePickerSheet: FootprintBottomSheet {
    private var selectedDays: Set<Int>
    private var repeatsWeekly: Bool
    private var onConfirm: ((Set<Int>, Bool) -> Void)?
    private var dayButtons: [UIButton] = []
    private var instructionLabel: UILabel!
    private var warningBanner: UIView!
    private var hintLabel: UILabel!

    /// .text-wrapper_7...13: 圆形按钮 = 文字 32px + padding 22px×2 = 76px → 38pt
    /// （设计稿实测直径约 75px，一致）。早期按 54px→27pt 取值是算错了，圆明显偏小。
    private let dayButtonDiameter: CGFloat = 38

    /// 星期按钮的排列顺序（编号 1=周一 … 7=周日，只影响显示，存储不变）。
    /// 英文按设计校对表用美式日历、周日开头；其他语言与设计稿一致、周一开头。
    static var displayOrder: [Int] {
        LocalizationManager.shared.currentLanguage == .english ? [7, 1, 2, 3, 4, 5, 6] : Array(1...7)
    }

    private init(days: Set<Int>, repeatsWeekly: Bool) {
        self.selectedDays = days
        self.repeatsWeekly = repeatsWeekly
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func present(in view: UIView, days: Set<Int>, repeatsWeekly: Bool,
                         onConfirm: @escaping (Set<Int>, Bool) -> Void) {
        let s = WeekdayCyclePickerSheet(days: days, repeatsWeekly: repeatsWeekly)
        s.onConfirm = onConfirm
        s.build()
        s.presentInWindow()
    }

    private func build() {
        let contentTop = addHeader(title: L("sleepplan.sheet.cycle.title"),
                                    onCancel: { [weak self] in self?.dismissSheet() },
                                    onConfirm: { [weak self] in self?.handleConfirm() })

        // .text_26: 白 26px→13pt Regular
        instructionLabel = UILabel()
        instructionLabel.text = L("sleepplan.sheet.cycle.instruction")
        // .text_26: 20px→10pt Light
        instructionLabel.font = SleepPlanTheme.fontLight(SleepPlanTheme.fontSizeHint)
        instructionLabel.textColor = .white
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(instructionLabel)

        // .box_41: 7 个圆形按钮，selected=rgba(102,117,242,1) 实心，unselected=1px rgba(212,212,212,1) 描边。
        let dayRow = UIStackView()
        dayRow.axis = .horizontal
        dayRow.distribution = .equalSpacing
        dayRow.translatesAutoresizingMaskIntoConstraints = false
        let dayKeys = ["footprint.weekday.mon", "footprint.weekday.tue", "footprint.weekday.wed",
                       "footprint.weekday.thu", "footprint.weekday.fri", "footprint.weekday.sat", "footprint.weekday.sun"]
        for day in Self.displayOrder {
            let key = dayKeys[day - 1]
            let button = UIButton(type: .system)
            button.setTitle(L(key), for: .normal)
            button.titleLabel?.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeOptionTitle)
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = dayButtonDiameter / 2
            button.widthAnchor.constraint(equalToConstant: dayButtonDiameter).isActive = true
            button.heightAnchor.constraint(equalToConstant: dayButtonDiameter).isActive = true
            button.tag = day
            button.addAction(UIAction { [weak self] _ in self?.toggleDay(day) }, for: .touchUpInside)
            dayButtons.append(button)
            dayRow.addArrangedSubview(button)
        }
        sheet.addSubview(dayRow)

        // .section_14: #3C3C3C, radius 36px→18pt, border 0.5px rgba(170,170,170,1)。
        let repeatCard = UIView()
        repeatCard.backgroundColor = UIColor(red: 60/255, green: 60/255, blue: 60/255, alpha: 1)
        repeatCard.layer.cornerRadius = SleepPlanTheme.cardCornerRadius
        repeatCard.layer.borderWidth = 0.5
        repeatCard.layer.borderColor = UIColor(red: 170/255, green: 170/255, blue: 170/255, alpha: 1).cgColor
        repeatCard.translatesAutoresizingMaskIntoConstraints = false

        let repeatLabel = UILabel()
        repeatLabel.text = L("sleepplan.sheet.cycle.repeat_weekly")
        repeatLabel.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionTitle)
        repeatLabel.textColor = .white
        let repeatHint = UILabel()
        repeatHint.text = L("sleepplan.sheet.cycle.repeat_hint")
        // .text_35: 22px→11pt Normal
        repeatHint.font = SleepPlanTheme.fontRegular(11)
        repeatHint.textColor = .white
        repeatHint.numberOfLines = 0
        let repeatTextStack = UIStackView(arrangedSubviews: [repeatLabel, repeatHint])
        repeatTextStack.axis = .vertical
        repeatTextStack.spacing = 4
        repeatTextStack.translatesAutoresizingMaskIntoConstraints = false

        let repeatSwitch = UISwitch()
        repeatSwitch.isOn = repeatsWeekly
        repeatSwitch.onTintColor = SleepPlanTheme.valueBlue
        // .group_21: 75×42px→37.5×21pt，UISwitch 原生 51×31，等比缩到 0.7
        repeatSwitch.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        repeatSwitch.translatesAutoresizingMaskIntoConstraints = false
        repeatSwitch.addAction(UIAction { [weak self] _ in self?.repeatsWeekly = repeatSwitch.isOn }, for: .valueChanged)

        repeatCard.addSubview(repeatTextStack)
        repeatCard.addSubview(repeatSwitch)
        NSLayoutConstraint.activate([
            repeatTextStack.topAnchor.constraint(equalTo: repeatCard.topAnchor, constant: 18),
            repeatTextStack.bottomAnchor.constraint(equalTo: repeatCard.bottomAnchor, constant: -18),
            repeatTextStack.leadingAnchor.constraint(equalTo: repeatCard.leadingAnchor, constant: 18),
            repeatTextStack.trailingAnchor.constraint(lessThanOrEqualTo: repeatSwitch.leadingAnchor, constant: -12),
            repeatSwitch.centerYAnchor.constraint(equalTo: repeatCard.centerYAnchor),
            repeatSwitch.trailingAnchor.constraint(equalTo: repeatCard.trailingAnchor, constant: -24)
        ])
        sheet.addSubview(repeatCard)

        // .text_36: 常驻说明文案，白 20px→10pt Light（校验失败时被警示条取代）。
        hintLabel = UILabel()
        hintLabel.text = L("sleepplan.sheet.cycle.hint")
        hintLabel.font = SleepPlanTheme.fontLight(SleepPlanTheme.fontSizeHint)
        hintLabel.textColor = .white
        hintLabel.numberOfLines = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(hintLabel)

        // .group_25: 校验失败时的警示条，取代上面的常驻说明；bg rgba(210,85,100,1)。
        warningBanner = UIView()
        warningBanner.backgroundColor = UIColor(red: 210/255, green: 85/255, blue: 100/255, alpha: 1)
        warningBanner.layer.cornerRadius = SleepPlanTheme.cardCornerRadius
        warningBanner.isHidden = true
        warningBanner.translatesAutoresizingMaskIntoConstraints = false
        let warningIcon = UIImageView(image: UIImage(systemName: "exclamationmark.circle.fill"))
        warningIcon.tintColor = .white
        warningIcon.translatesAutoresizingMaskIntoConstraints = false
        let warningLabel = UILabel()
        warningLabel.text = L("sleepplan.sheet.cycle.warning")
        // .text_59: 22px→11pt Normal
        warningLabel.font = SleepPlanTheme.fontRegular(11)
        warningLabel.textColor = .white
        warningLabel.numberOfLines = 0
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        warningBanner.addSubview(warningIcon)
        warningBanner.addSubview(warningLabel)
        NSLayoutConstraint.activate([
            warningIcon.leadingAnchor.constraint(equalTo: warningBanner.leadingAnchor, constant: 18),
            warningIcon.centerYAnchor.constraint(equalTo: warningBanner.centerYAnchor),
            warningIcon.widthAnchor.constraint(equalToConstant: 16),
            warningIcon.heightAnchor.constraint(equalToConstant: 16),
            warningLabel.leadingAnchor.constraint(equalTo: warningIcon.trailingAnchor, constant: 8),
            warningLabel.trailingAnchor.constraint(equalTo: warningBanner.trailingAnchor, constant: -18),
            warningLabel.topAnchor.constraint(equalTo: warningBanner.topAnchor, constant: 14),
            warningLabel.bottomAnchor.constraint(equalTo: warningBanner.bottomAnchor, constant: -14)
        ])
        sheet.addSubview(warningBanner)

        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: contentTop, constant: 16),
            instructionLabel.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -20),

            dayRow.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 16),
            dayRow.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            dayRow.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -20),

            // .section_14 margin-top 74px→37pt
            repeatCard.topAnchor.constraint(equalTo: dayRow.bottomAnchor, constant: 37),
            repeatCard.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            repeatCard.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -20),

            hintLabel.topAnchor.constraint(equalTo: repeatCard.bottomAnchor, constant: 18),
            hintLabel.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -20),

            warningBanner.topAnchor.constraint(equalTo: repeatCard.bottomAnchor, constant: 18),
            warningBanner.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            warningBanner.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -20),

            hintLabel.bottomAnchor.constraint(equalTo: sheet.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        let warningBottom = warningBanner.bottomAnchor.constraint(equalTo: sheet.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        warningBottom.priority = .defaultHigh
        warningBottom.isActive = true
        updateDayButtonAppearance()
    }

    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) { selectedDays.remove(day) } else { selectedDays.insert(day) }
        updateDayButtonAppearance()
    }

    private func updateDayButtonAppearance() {
        let isValid = SleepPlanCycle.hasConsecutiveRun(selectedDays)
        setSheetConfirmEnabled(isValid)
        if isValid { setWarningVisible(false) }
        for button in dayButtons {
            let isOn = selectedDays.contains(button.tag)
            button.backgroundColor = isOn ? SleepPlanTheme.sleepBlue : .clear
            button.layer.borderWidth = isOn ? 0 : 1
            button.layer.borderColor = UIColor(red: 212/255, green: 212/255, blue: 212/255, alpha: 1).cgColor
        }
    }

    private func handleConfirm() {
        // 至少 3 天连续（含跨周六/周日/周一），不满足时保留选择、浮层不关闭，只提示。
        let isValid = SleepPlanCycle.hasConsecutiveRun(selectedDays)
        setWarningVisible(!isValid)
        guard isValid else { return }
        dismissSheet { self.onConfirm?(self.selectedDays, self.repeatsWeekly) }
    }

    /// 03.B（常驻长说明）与 03.B1（红色警示条）在设计稿里是互斥的两版底部内容，
    /// 两者用的是同一个顶部锚点，同时显示会直接叠在一起。
    private func setWarningVisible(_ visible: Bool) {
        warningBanner.isHidden = !visible
        hintLabel.isHidden = visible
    }
}

// MARK: - 计划名称编辑（≤10 字符）

// 计划名称编辑：CSS（03a）显示这是居中卡片（rgba(0,0,0,.6) 遮罩 + #2C2C2C 圆角卡片），
// 不是滑出式底部浮层，所以不继承 FootprintBottomSheet，结构与 ConfirmDialogView 同源。
final class PlanNameEditSheet: UIView, UITextFieldDelegate {
    private let dimView = UIView()
    private let cardView = UIView()
    private var currentName: String
    private var onConfirm: ((String) -> Void)?
    private let textField = UITextField()

    private init(currentName: String) {
        self.currentName = currentName
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func present(in view: UIView, currentName: String, onConfirm: @escaping (String) -> Void) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
        let s = PlanNameEditSheet(currentName: currentName)
        s.onConfirm = onConfirm
        s.build()
        s.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(s)
        NSLayoutConstraint.activate([
            s.topAnchor.constraint(equalTo: window.topAnchor),
            s.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            s.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            s.bottomAnchor.constraint(equalTo: window.bottomAnchor)
        ])
        s.animateIn()
    }

    private func build() {
        dimView.backgroundColor = SleepPlanTheme.dialogOverlay
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)
        // 点空白处收起键盘：手势代理会放过输入框和按钮自身，只在空白处生效。
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(handleDismissKeyboardTap))
        dismissTap.cancelsTouchesInView = false
        dismissTap.delegate = KeyboardDismissGestureDelegate.shared
        addGestureRecognizer(dismissTap)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // .box_23: #2C2C2C radius 36px→18pt, padding 80/48/108/48 → 40/24/54/24
        cardView.backgroundColor = SleepPlanTheme.cardBackground
        cardView.layer.cornerRadius = SleepPlanTheme.dialogCornerRadius
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
            cardView.widthAnchor.constraint(equalToConstant: 335)
        ])

        // 取消 | 修改计划名称 | 确认（同 addHeader 的配色规则：取消/标题白，确认浅蓝）
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(L("common.cancel"), for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionTitle)
        cancelButton.addAction(UIAction { [weak self] _ in self?.dismiss() }, for: .touchUpInside)

        let titleLabel = UILabel()
        titleLabel.text = L("sleepplan.sheet.rename.title")
        titleLabel.font = SleepPlanTheme.fontRegular(16)
        titleLabel.textColor = .white

        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle(L("common.confirm"), for: .normal)
        confirmButton.setTitleColor(SleepPlanTheme.valueBlue, for: .normal)
        confirmButton.titleLabel?.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeOptionTitle)
        confirmButton.addAction(UIAction { [weak self] _ in self?.handleConfirm() }, for: .touchUpInside)

        let headerRow = UIStackView(arrangedSubviews: [cancelButton, titleLabel, confirmButton])
        headerRow.axis = .horizontal
        headerRow.distribution = .equalSpacing
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(headerRow)

        // .text-wrapper_7: #3C3C3C radius 36px→18pt border 0.5pt #AAAAAA；.text_29: 白 28px→14pt
        textField.text = currentName
        textField.textColor = .white
        textField.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionTitle)
        textField.backgroundColor = UIColor(red: 60/255, green: 60/255, blue: 60/255, alpha: 1)
        textField.layer.cornerRadius = SleepPlanTheme.cardCornerRadius
        textField.layer.borderWidth = 0.5
        textField.layer.borderColor = UIColor(red: 170/255, green: 170/255, blue: 170/255, alpha: 1).cgColor
        // .text-wrapper_7 padding-left 35.5px→17.75pt
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 17.75, height: 1))
        textField.leftViewMode = .always
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(textField)

        // .text_30: 白 22px→11pt Regular
        let hint = UILabel()
        hint.text = L("sleepplan.sheet.rename.hint")
        hint.font = SleepPlanTheme.fontRegular(11)
        hint.textColor = .white
        hint.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(hint)

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 40),
            headerRow.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            headerRow.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),

            textField.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 30),
            textField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            textField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            // .text-wrapper_7: 文字 28px + padding 35.5px×2 → 49.5pt
            textField.heightAnchor.constraint(equalToConstant: 49.5),

            hint.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 8),
            hint.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            // .box_23 padding-bottom 108px→54pt
            hint.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -54)
        ])
    }

    private func handleConfirm() {
        let trimmed = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        dismiss { self.onConfirm?(trimmed) }
    }

    private func animateIn() {
        dimView.alpha = 0
        cardView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5) {
            self.dimView.alpha = 1
            self.cardView.transform = .identity
        }
    }

    private func dismiss(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, animations: {
            self.dimView.alpha = 0
            self.cardView.alpha = 0
        }, completion: { _ in
            self.removeFromSuperview()
            completion?()
        })
    }

    @objc private func handleDismissKeyboardTap() {
        endEditing(true)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let current = (textField.text ?? "") as NSString
        let updated = current.replacingCharacters(in: range, with: string)
        return updated.count <= 10
    }
}

// 只读说明弹窗（执行周期/助眠方案的官方计划固定项说明，02g/02c 等）：CSS 显示这其实和
// 「确认」类弹窗同一结构（居中卡片 + 单个纯白通栏按钮 + 阴影），直接复用 ConfirmDialogView.presentSingleAction，
// 不再单独维护一个 FootprintBottomSheet 派生类。

// MARK: - 睡眠目标设置（联动浮层）：目标时长 / 入睡时间 / 起床时间

final class SleepGoalPickerSheet: FootprintBottomSheet {
    private var sleepMinutes: Int
    private var wakeMinutes: Int
    private var onConfirm: ((Int, Int) -> Void)?

    /// 三张设置卡（.list-items_1-0/1/2）。
    private enum Field: Int { case duration, sleep, wake }
    private var rows: [Field: GoalRowCard] = [:]
    private var openField: Field?
    private var picker: UIPickerView!
    private var pickerHeight: NSLayoutConstraint!
    private var warningLabel: UILabel!

    private init(sleepMinutes: Int, wakeMinutes: Int) {
        self.sleepMinutes = sleepMinutes
        self.wakeMinutes = wakeMinutes
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func present(in view: UIView, sleepMinutes: Int, wakeMinutes: Int,
                         onConfirm: @escaping (_ sleepMinutes: Int, _ wakeMinutes: Int) -> Void) {
        let s = SleepGoalPickerSheet(sleepMinutes: sleepMinutes, wakeMinutes: wakeMinutes)
        s.onConfirm = onConfirm
        s.build()
        s.presentInWindow()
    }

    private static func duration(sleep: Int, wake: Int) -> Int {
        let d = wake - sleep
        return d <= 0 ? d + 1440 : d
    }
    private var durationMinutes: Int { Self.duration(sleep: sleepMinutes, wake: wakeMinutes) }

    private func build() {
        let contentTop = addHeader(title: L("sleepplan.sheet.goal.title"),
                                    onCancel: { [weak self] in self?.dismissSheet() },
                                    onConfirm: { [weak self] in self?.handleConfirm() })

        for field in [Field.duration, .sleep, .wake] {
            let card = GoalRowCard(title: L(titleKey(for: field)))
            card.onTap = { [weak self] in self?.toggle(field) }
            rows[field] = card
        }

        // .text_28: 22px→11pt Normal，白色（不是系统红）
        warningLabel = UILabel()
        warningLabel.text = L("sleepplan.sheet.goal.too_short")
        warningLabel.font = SleepPlanTheme.fontRegular(11)
        warningLabel.textColor = .white
        warningLabel.numberOfLines = 0
        warningLabel.isHidden = true

        picker = UIPickerView()
        picker.dataSource = self
        picker.delegate = self
        picker.isHidden = true
        picker.translatesAutoresizingMaskIntoConstraints = false
        pickerHeight = picker.heightAnchor.constraint(equalToConstant: 0)
        pickerHeight.isActive = true

        let stack = UIStackView(arrangedSubviews: [rows[.duration]!, warningLabel, rows[.sleep]!, rows[.wake]!, picker])
        stack.axis = .vertical
        // .list-items margin-bottom 28px→14pt
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(stack)
        NSLayoutConstraint.activate([
            // .list_3 margin-top 80px→40pt
            stack.topAnchor.constraint(equalTo: contentTop, constant: 40),
            stack.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: sheet.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
        refreshValues()
    }

    private func titleKey(for field: Field) -> String {
        switch field {
        case .duration: return "sleepplan.sheet.goal.duration"
        case .sleep: return "sleepplan.sheet.goal.sleep_time"
        case .wake: return "sleepplan.sheet.goal.wake_time"
        }
    }

    private func refreshValues() {
        rows[.duration]?.setValue(formattedDuration())
        rows[.sleep]?.setValue(DateDisplay.clock(minutesOfDay: sleepMinutes))
        rows[.wake]?.setValue(DateDisplay.clock(minutesOfDay: wakeMinutes))
        let ok = durationMinutes >= 60
        warningLabel.isHidden = ok
        setSheetConfirmEnabled(ok)
    }

    private func formattedDuration() -> String {
        durationMinutes % 60 == 0
            ? String(format: L("sleepplan.duration.hours"), durationMinutes / 60)
            : String(format: L("sleepplan.duration.hours_minutes"), durationMinutes / 60, durationMinutes % 60)
    }

    private func toggle(_ field: Field) {
        openField = (openField == field) ? nil : field
        for (key, card) in rows { card.setExpanded(key == openField) }
        picker.isHidden = openField == nil
        pickerHeight.constant = openField == nil ? 0 : 180
        if openField != nil {
            picker.reloadAllComponents()
            syncPickerSelection()
        }
        sheet.layoutIfNeeded()
    }

    private func syncPickerSelection() {
        guard let field = openField else { return }
        switch field {
        case .duration:
            picker.selectRow(durationMinutes / 60, inComponent: 0, animated: false)
            picker.selectRow(durationMinutes % 60, inComponent: 1, animated: false)
        case .sleep:
            picker.selectRow(sleepMinutes / 60, inComponent: 0, animated: false)
            picker.selectRow(sleepMinutes % 60, inComponent: 1, animated: false)
        case .wake:
            picker.selectRow(wakeMinutes / 60, inComponent: 0, animated: false)
            picker.selectRow(wakeMinutes % 60, inComponent: 1, animated: false)
        }
    }

    private func handleConfirm() {
        // 「最小睡眠目标为 1 小时；低于 1 小时提示无法设置并禁用保存」——浮层不关闭。
        guard durationMinutes >= 60 else {
            warningLabel.isHidden = false
            return
        }
        dismissSheet { self.onConfirm?(self.sleepMinutes, self.wakeMinutes) }
    }
}

extension SleepGoalPickerSheet: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        component == 0 ? 24 : 60
    }

    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let unitKey = component == 0 ? "sleepplan.unit.hour" : "sleepplan.unit.minute"
        return NSAttributedString(string: "\(row)\(L(unitKey))", attributes: [
            .foregroundColor: UIColor.white,
            .font: SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionTitle)
        ])
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let field = openField else { return }
        let minutes = pickerView.selectedRow(inComponent: 0) * 60 + pickerView.selectedRow(inComponent: 1)
        // 「改入睡→保留时长算起床；改起床→保留时长算入睡；改时长→保留入睡算起床」
        switch field {
        case .duration:
            wakeMinutes = (sleepMinutes + max(0, minutes)) % 1440
        case .sleep:
            let keep = durationMinutes
            sleepMinutes = minutes % 1440
            wakeMinutes = (sleepMinutes + keep) % 1440
        case .wake:
            let keep = durationMinutes
            wakeMinutes = minutes % 1440
            sleepMinutes = ((wakeMinutes - keep) % 1440 + 1440) % 1440
        }
        refreshValues()
    }
}

/// 睡眠目标设置浮层里的一行卡片（.list-items_1-x：#3C3C3C、radius 36px→18pt、
/// 0.5px 描边 rgba(170,170,170)、padding 49.5/31.5/49.5/35.5px）。
private final class GoalRowCard: UIControl {
    var onTap: (() -> Void)?
    private let valueLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    init(title: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor(red: 60/255, green: 60/255, blue: 60/255, alpha: 1)
        layer.cornerRadius = SleepPlanTheme.cardCornerRadius
        layer.borderWidth = 0.5
        layer.borderColor = UIColor(red: 170/255, green: 170/255, blue: 170/255, alpha: 1).cgColor

        // .text_26-0: 28px→14pt Normal 白；.text_27-0: 28px→14pt Medium 白
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionTitle)
        titleLabel.textColor = .white
        valueLabel.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeOptionTitle)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .right
        chevron.tintColor = .white
        chevron.contentMode = .scaleAspectFit

        let row = UIStackView(arrangedSubviews: [titleLabel, UIView(), valueLabel, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 6
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            chevron.widthAnchor.constraint(equalToConstant: 6),
            chevron.heightAnchor.constraint(equalToConstant: 11),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 24.75),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24.75),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 17.75),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15.75)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValue(_ text: String) { valueLabel.text = text }

    func setExpanded(_ expanded: Bool) {
        chevron.transform = expanded ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
    }

    @objc private func tapped() { onTap?() }
}


/// UIGestureRecognizer 的 target 不能直接持有闭包，用这个小适配器包一层。
private final class BlockTarget: NSObject {
    private let block: () -> Void
    init(_ block: @escaping () -> Void) { self.block = block }
    @objc func invoke() { block() }
}
