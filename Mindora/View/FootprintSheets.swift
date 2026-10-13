//
//  FootprintSheets.swift
//  mindora
//
//  陪伴足迹的两个底部弹层：指标说明（说明）+ 月份选择器（时间调整）。
//

import UIKit

// MARK: - 通用底部弹层基类

class FootprintBottomSheet: UIView {

    let dimView = UIView()
    let sheet = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleDimTap(_:))))

        sheet.backgroundColor = UIColor(red: 32/255, green: 32/255, blue: 34/255, alpha: 1.0)
        sheet.layer.cornerRadius = 20
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheet.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sheet)

        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),
            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func presentInWindow() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
        translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: window.topAnchor),
            leadingAnchor.constraint(equalTo: window.leadingAnchor),
            trailingAnchor.constraint(equalTo: window.trailingAnchor),
            bottomAnchor.constraint(equalTo: window.bottomAnchor)
        ])
        layoutIfNeeded()
        dimView.alpha = 0
        sheet.transform = CGAffineTransform(translationX: 0, y: sheet.bounds.height)
        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseOut]) {
            self.dimView.alpha = 1
            self.sheet.transform = .identity
        }
    }

    func dismissSheet(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.22, animations: {
            self.dimView.alpha = 0
            self.sheet.transform = CGAffineTransform(translationX: 0, y: self.sheet.bounds.height)
        }, completion: { _ in
            self.removeFromSuperview()
            completion?()
        })
    }

    @objc private func handleDimTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: sheet)
        if sheet.bounds.contains(location) { return }
        dismissSheet()
    }
}

// MARK: - 指标说明

final class FootprintInfoSheetView: FootprintBottomSheet {

    static func present(in view: UIView) {
        let sheet = FootprintInfoSheetView(frame: .zero)
        sheet.build()
        sheet.presentInWindow()
    }

    private func build() {
        let title = UILabel()
        title.text = L("footprint.info.title")
        title.font = UIFont(name: "PingFangSC-Semibold", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)
        title.textColor = .white
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(title)

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = UIColor(white: 1, alpha: 0.7)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        sheet.addSubview(close)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(stack)

        // 三项指标说明
        let metrics: [(String, String)] = [
            (L("footprint.stat.companion"), L("footprint.info.companion.desc")),
            (L("footprint.stat.app_active"), L("footprint.info.app_active.desc")),
            (L("footprint.stat.continuous"), L("footprint.info.continuous.desc"))
        ]
        for (name, desc) in metrics {
            stack.addArrangedSubview(makeMetricBlock(name: name, desc: desc))
        }

        // 日历标记
        let markTitle = UILabel()
        markTitle.text = L("footprint.info.marks.title")
        markTitle.font = UIFont(name: "PingFangSC-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        markTitle.textColor = .white
        stack.addArrangedSubview(markTitle)

        // 与日历一致：App活跃=深紫，助眠陪伴=亮紫，完成计划=金色。三项排在一行。
        let legendItems: [(UIColor, String)] = [
            (UIColor(red: 68/255, green: 48/255, blue: 126/255, alpha: 1), L("footprint.legend.app_active")),
            (UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1), L("footprint.legend.companion")),
            (UIColor(red: 255/255, green: 202/255, blue: 125/255, alpha: 1), L("footprint.legend.plan"))
        ]
        let legendRow = UIStackView()
        legendRow.axis = .horizontal
        legendRow.alignment = .center
        legendRow.distribution = .equalSpacing
        legendRow.spacing = 10   // equalSpacing 下为最小间距，窄屏不挤在一起
        for (index, (color, text)) in legendItems.enumerated() {
            let dot = UIView()
            dot.backgroundColor = color
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            let label = UILabel()
            label.text = text
            label.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
            label.textColor = UIColor(white: 1, alpha: 0.75)
            // 最后一项最长（英文 "Routine Completed / Usage Streak"），放不下就折成两行。
            let isLongest = index == legendItems.count - 1
            label.numberOfLines = isLongest ? 2 : 1
            label.setContentCompressionResistancePriority(isLongest ? .defaultLow : .required, for: .horizontal)
            let item = UIStackView(arrangedSubviews: [dot, label])
            item.axis = .horizontal
            item.spacing = 6
            item.alignment = .center
            legendRow.addArrangedSubview(item)
        }
        stack.addArrangedSubview(legendRow)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 20),
            title.centerXAnchor.constraint(equalTo: sheet.centerXAnchor),
            close.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            close.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -22),
            stack.bottomAnchor.constraint(equalTo: sheet.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    private func makeMetricBlock(name: String, desc: String) -> UIView {
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = UIFont(name: "PingFangSC-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        nameLabel.textColor = .white

        let descLabel = UILabel()
        descLabel.text = desc
        descLabel.font = UIFont(name: "PingFangSC-Regular", size: 13) ?? .systemFont(ofSize: 13)
        descLabel.textColor = UIColor(white: 1, alpha: 0.55)
        descLabel.numberOfLines = 0

        let block = UIStackView(arrangedSubviews: [nameLabel, descLabel])
        block.axis = .vertical
        block.spacing = 6
        return block
    }

    @objc private func handleClose() { dismissSheet() }
}

// MARK: - 月份选择器

final class FootprintMonthPickerView: FootprintBottomSheet {

    private var onSelectMonth: ((Int, Int) -> Void)?
    private var onSelectYear: ((Int) -> Void)?
    private var months: [(year: Int, month: Int)] = []
    private var selectedIndex: Int = 0
    private var chips: [UIButton] = []
    private var selectedYearForAnnual: Int = 0

    static func present(in view: UIView,
                        selectedYear: Int,
                        selectedMonth: Int,
                        onSelectMonth: @escaping (Int, Int) -> Void,
                        onSelectYear: @escaping (Int) -> Void) {
        let picker = FootprintMonthPickerView(frame: .zero)
        picker.onSelectMonth = onSelectMonth
        picker.onSelectYear = onSelectYear
        picker.selectedYearForAnnual = selectedYear
        picker.build(selectedYear: selectedYear, selectedMonth: selectedMonth)
        picker.presentInWindow()
    }

    /// 本月及之前半年（共 6 个月）。
    private func computeMonths() -> [(Int, Int)] {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        var result: [(Int, Int)] = []
        for offset in stride(from: 5, through: 0, by: -1) {
            if let date = cal.date(byAdding: .month, value: -offset, to: now) {
                result.append((cal.component(.year, from: date), cal.component(.month, from: date)))
            }
        }
        return result
    }

    private func build(selectedYear: Int, selectedMonth: Int) {
        months = computeMonths()
        selectedIndex = months.firstIndex(where: { $0.year == selectedYear && $0.month == selectedMonth }) ?? (months.count - 1)

        let title = UILabel()
        title.text = L("footprint.picker.title")
        title.font = UIFont(name: "PingFangSC-Semibold", size: 16) ?? .systemFont(ofSize: 16, weight: .semibold)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(title)

        // 全年入口
        let annualButton = UIButton(type: .system)
        annualButton.setTitle(L("footprint.picker.annual") + "  ›", for: .normal)
        annualButton.setTitleColor(UIColor(red: 172/255, green: 143/255, blue: 255/255, alpha: 1), for: .normal)
        annualButton.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        annualButton.translatesAutoresizingMaskIntoConstraints = false
        annualButton.addTarget(self, action: #selector(handleAnnual), for: .touchUpInside)
        sheet.addSubview(annualButton)

        // 月份 chips（每行 4 个）
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 12
        grid.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(grid)

        var currentRow: UIStackView?
        for (i, ym) in months.enumerated() {
            if i % 4 == 0 {
                let row = UIStackView()
                row.axis = .horizontal
                row.distribution = .fillEqually
                row.spacing = 12
                grid.addArrangedSubview(row)
                currentRow = row
            }
            let chip = UIButton(type: .system)
            chip.setTitle(FootprintFormat.monthShort(year: ym.year, month: ym.month), for: .normal)
            chip.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
            chip.layer.cornerRadius = 10
            chip.tag = i
            chip.heightAnchor.constraint(equalToConstant: 40).isActive = true
            chip.addTarget(self, action: #selector(handleChip(_:)), for: .touchUpInside)
            chips.append(chip)
            currentRow?.addArrangedSubview(chip)
        }
        // 补齐末行空位，避免 chip 被拉伸变形
        if let last = currentRow, months.count % 4 != 0 {
            for _ in 0..<(4 - months.count % 4) { last.addArrangedSubview(UIView()) }
        }

        // 确认按钮
        let confirm = UIButton(type: .system)
        confirm.setTitle(L("footprint.picker.confirm"), for: .normal)
        confirm.setTitleColor(UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1), for: .normal)
        confirm.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        confirm.backgroundColor = .white
        confirm.layer.cornerRadius = 24
        confirm.translatesAutoresizingMaskIntoConstraints = false
        confirm.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
        sheet.addSubview(confirm)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 22),
            title.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 22),
            annualButton.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            annualButton.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -20),
            grid.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 22),
            grid.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 22),
            grid.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -22),
            confirm.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 28),
            confirm.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 22),
            confirm.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -22),
            confirm.heightAnchor.constraint(equalToConstant: 48),
            confirm.bottomAnchor.constraint(equalTo: sheet.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        updateChipStyles()
    }

    private func updateChipStyles() {
        for (i, chip) in chips.enumerated() {
            if i == selectedIndex {
                chip.backgroundColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1)
                chip.setTitleColor(.white, for: .normal)
            } else {
                chip.backgroundColor = UIColor(white: 1, alpha: 0.08)
                chip.setTitleColor(UIColor(white: 1, alpha: 0.85), for: .normal)
            }
        }
    }

    @objc private func handleChip(_ sender: UIButton) {
        selectedIndex = sender.tag
        updateChipStyles()
    }

    @objc private func handleConfirm() {
        guard selectedIndex < months.count else { dismissSheet(); return }
        let ym = months[selectedIndex]
        let cb = onSelectMonth
        dismissSheet { cb?(ym.year, ym.month) }
    }

    @objc private func handleAnnual() {
        let year = selectedYearForAnnual
        let cb = onSelectYear
        dismissSheet { cb?(year) }
    }
}
