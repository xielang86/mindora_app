//
//  CompanionFootprintViewController.swift
//  mindora
//
//  陪伴足迹：三项统计 + 月历标记 + 里程碑记录；顶部「说明」指标说明弹层；
//  月份选择器（本月及之前半年 + 全年入口）；全年视图。数据经 CompanionFootprintService。
//

import UIKit

// MARK: - 配色

private enum FP {
    static let bg = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0)          // #181818
    static let card = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0)         // #2C2C2C
    // 统计卡渐变（20260818 设计更新：linear-gradient(90deg, #38226D → #634195)，
    // 由原来的左上→右下改成正横向，配色整体提亮）
    static let statsGradStart = UIColor(red: 56/255, green: 34/255, blue: 109/255, alpha: 1.0)  // #38226D 左
    static let statsGradEnd = UIColor(red: 99/255, green: 65/255, blue: 149/255, alpha: 1.0)    // #634195 右
    // 日历/图例配色（对齐设计：App活跃=深紫，助眠陪伴=亮紫，完成计划=金色圆点）
    static let appActive = UIColor(red: 68/255, green: 48/255, blue: 126/255, alpha: 1.0)   // #44307E 深紫
    static let companion = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0)  // #8054FE 亮紫
    static let plan = UIColor(red: 255/255, green: 202/255, blue: 125/255, alpha: 1.0)      // #FFCA7D 金色
    static let lightPurple = UIColor(red: 172/255, green: 143/255, blue: 255/255, alpha: 1.0) // #AC8FFF 统计数字
    static let cellEmpty = UIColor(red: 59/255, green: 59/255, blue: 65/255, alpha: 1.0)      // #3B3B41 年视图无数据灰圈
    static let dimText = UIColor(white: 1, alpha: 0.4)
}

// MARK: - 主视图

final class CompanionFootprintViewController: UIViewController {

    private var year: Int
    private var month: Int

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let monthSelectorLabel = UILabel()
    private var calendarView: FootprintCalendarView?
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    // 卡片内需要动态更新的引用
    private var statsCard: FootprintStatsCard?
    private var milestonesContainer: UIStackView?

    init(year: Int? = nil, month: Int? = nil) {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        self.year = year ?? cal.component(.year, from: now)
        self.month = month ?? cal.component(.month, from: now)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FP.bg
        setupNav()
        setupBody()
        loadMonth()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // MARK: Nav

    private func setupNav() {
        let back = EnlargedHitAreaButton()
        back.setImage(UIImage(named: "sub_back"), for: .normal)
        back.translatesAutoresizingMaskIntoConstraints = false
        back.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        view.addSubview(back)

        let title = UILabel()
        title.text = L("footprint.title")
        title.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        // 英文标题与右上角「About These Metrics」都较长：居中只是偏好，放不下时向左让位并适度缩字，绝不与按钮重叠。
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.75
        title.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        view.addSubview(title)
        let titleCenterX = title.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        titleCenterX.priority = UILayoutPriority(500)   // 低于标题抗压缩（750）：宁可偏离居中也不截断
        titleCenterX.isActive = true

        let infoButton = UIButton(type: .system)
        infoButton.setTitle(L("footprint.explain"), for: .normal)
        infoButton.setTitleColor(.white, for: .normal)
        infoButton.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        infoButton.addTarget(self, action: #selector(showExplanation), for: .touchUpInside)
        view.addSubview(infoButton)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            back.topAnchor.constraint(equalTo: safe.topAnchor, constant: 10),
            back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            back.widthAnchor.constraint(equalToConstant: 24),
            back.heightAnchor.constraint(equalToConstant: 24),
            title.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            title.leadingAnchor.constraint(greaterThanOrEqualTo: back.trailingAnchor, constant: 12),
            title.trailingAnchor.constraint(lessThanOrEqualTo: infoButton.leadingAnchor, constant: -12),
            infoButton.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            infoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: back.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: Body

    private func setupBody() {
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -30),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16)
        ])

        // 统计卡
        let stats = FootprintStatsCard()
        contentStack.addArrangedSubview(stats)
        statsCard = stats

        // 月份选择行
        let monthRow = makeMonthSelectorRow()
        contentStack.addArrangedSubview(monthRow)

        // 日历
        let calendar = FootprintCalendarView(compact: false, showsLegend: true)
        contentStack.addArrangedSubview(calendar)
        calendarView = calendar

        // 里程碑
        let milestoneTitle = UILabel()
        milestoneTitle.text = L("footprint.milestones.title")
        milestoneTitle.font = UIFont(name: "PingFangSC-Semibold", size: 16) ?? .systemFont(ofSize: 16, weight: .semibold)
        milestoneTitle.textColor = .white
        contentStack.addArrangedSubview(milestoneTitle)

        let milestones = UIStackView()
        milestones.axis = .vertical
        milestones.spacing = 12
        contentStack.addArrangedSubview(milestones)
        milestonesContainer = milestones
    }

    private func makeMonthSelectorRow() -> UIView {
        let row = UIView()
        monthSelectorLabel.font = UIFont(name: "PingFangSC-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        monthSelectorLabel.textColor = .white
        monthSelectorLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(monthSelectorLabel)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
        chevron.tintColor = UIColor(white: 1, alpha: 0.7)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        row.addSubview(chevron)

        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(showMonthPicker), for: .touchUpInside)
        row.addSubview(button)

        NSLayoutConstraint.activate([
            monthSelectorLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            monthSelectorLabel.topAnchor.constraint(equalTo: row.topAnchor),
            monthSelectorLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            chevron.leadingAnchor.constraint(equalTo: monthSelectorLabel.trailingAnchor, constant: 6),
            chevron.centerYAnchor.constraint(equalTo: monthSelectorLabel.centerYAnchor),
            button.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            button.topAnchor.constraint(equalTo: row.topAnchor),
            button.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            button.trailingAnchor.constraint(equalTo: chevron.trailingAnchor, constant: 8)
        ])
        return row
    }

    // MARK: Load

    /// 请求代号：快速切换月份时只认最后一次请求，旧响应后到直接丢弃（防并发覆盖）。
    private var loadGeneration = 0

    private func loadMonth() {
        monthSelectorLabel.text = FootprintFormat.monthTitle(year: year, month: month)
        loadingIndicator.startAnimating()
        loadGeneration += 1
        let generation = loadGeneration
        CompanionFootprintService.shared.fetchMonth(year: year, month: month) { [weak self] result in
            guard let self, generation == self.loadGeneration else { return }
            self.loadingIndicator.stopAnimating()
            if case .success(let data) = result {
                self.render(data)
            }
        }
    }

    private func render(_ data: FootprintMonth) {
        statsCard?.configure(anchorDate: data.anchorDate, weekday: data.weekday, stats: data.stats)
        let today = todayIfCurrentMonth()
        calendarView?.configure(year: data.year, month: data.month, days: data.days, today: today)

        milestonesContainer?.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if data.milestones.isEmpty {
            let empty = UILabel()
            empty.text = L("footprint.milestones.empty")
            empty.font = UIFont(name: "PingFangSC-Regular", size: 13) ?? .systemFont(ofSize: 13)
            empty.textColor = FP.dimText
            milestonesContainer?.addArrangedSubview(empty)
        } else {
            for m in data.milestones {
                milestonesContainer?.addArrangedSubview(FootprintMilestoneCard(milestone: m))
            }
        }
    }

    /// 若展示的是当前自然月，返回今天的「日」用于高亮；否则 nil。
    private func todayIfCurrentMonth() -> Int? {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        guard cal.component(.year, from: now) == year, cal.component(.month, from: now) == month else { return nil }
        return cal.component(.day, from: now)
    }

    // MARK: Actions

    @objc private func handleBack() {
        // 栈底时 pop 无处可退、静默失败，返回按钮会彻底失效（订阅页踩过这个坑）
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            (navigationController ?? self).dismiss(animated: true)
        }
    }

    @objc private func showExplanation() {
        FootprintInfoSheetView.present(in: view)
    }

    @objc private func showMonthPicker() {
        FootprintMonthPickerView.present(in: view, selectedYear: year, selectedMonth: month,
            onSelectMonth: { [weak self] y, m in
                guard let self else { return }
                self.year = y; self.month = m
                self.loadMonth()
            },
            onSelectYear: { [weak self] y in
                guard let self else { return }
                let vc = FootprintAnnualViewController(year: y)
                if let nav = self.navigationController {
                    nav.pushViewController(vc, animated: true)
                } else {
                    vc.modalPresentationStyle = .fullScreen
                    self.present(vc, animated: true)
                }
            })
    }
}

// MARK: - 统计卡

final class FootprintStatsCard: UIView {
    private let dateLabel = UILabel()
    private let col1 = FootprintStatColumn()
    private let col2 = FootprintStatColumn()
    private let col3 = FootprintStatColumn()

    private let gradientLayer = CAGradientLayer()

    init() {
        super.init(frame: .zero)
        layer.cornerRadius = 18
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        // 渐变背景（左→右，对应设计稿 CSS 的 90deg）
        gradientLayer.colors = [FP.statsGradStart.cgColor, FP.statsGradEnd.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradientLayer, at: 0)

        dateLabel.font = UIFont(name: "PingFangSC-Regular", size: 13) ?? .systemFont(ofSize: 13)
        dateLabel.textColor = UIColor(white: 1, alpha: 0.6)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dateLabel)

        let statsRow = UIStackView(arrangedSubviews: [col1, col2, col3])
        statsRow.axis = .horizontal
        statsRow.distribution = .fillEqually
        statsRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statsRow)

        // 间距参考设计截图：日期距顶 ~20，日期到数字块 ~34，数字块到卡底 ~24。
        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            dateLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            statsRow.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 34),
            statsRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statsRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            statsRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    func configure(anchorDate: Date?, weekday: Int?, stats: FootprintStats?) {
        dateLabel.text = FootprintFormat.anchorTitle(date: anchorDate, weekday: weekday)
        // 助眠陪伴数字=浅紫，App活跃=白，连续使用=金（对齐设计）。
        col1.configure(value: "\(stats?.sleepCompanionMonth ?? 0)", unit: L("footprint.unit.day"),
                       title: L("footprint.stat.companion"), sub: L("footprint.stat.month_total"), color: FP.lightPurple)
        col2.configure(value: "\(stats?.appActiveMonth ?? 0)", unit: L("footprint.unit.day"),
                       title: L("footprint.stat.app_active"), sub: L("footprint.stat.month_total"), color: .white)
        col3.configure(value: "\(stats?.continuousUseYear ?? 0)", unit: L("footprint.unit.day"),
                       title: L("footprint.stat.continuous"), sub: L("footprint.stat.year_total"), color: FP.plan)
    }
}

final class FootprintStatColumn: UIView {
    private let valueLabel = UILabel()
    private let unitLabel = UILabel()
    private let titleLabel = UILabel()
    private let subLabel = UILabel()

    init() {
        super.init(frame: .zero)
        let valueRow = UIStackView(arrangedSubviews: [valueLabel, unitLabel])
        valueRow.axis = .horizontal
        valueRow.alignment = .firstBaseline
        valueRow.spacing = 3

        valueLabel.font = UIFont(name: "PingFangSC-Semibold", size: 28) ?? .systemFont(ofSize: 28, weight: .semibold)
        unitLabel.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        unitLabel.textColor = UIColor(white: 1, alpha: 0.6)
        titleLabel.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        titleLabel.textColor = .white
        subLabel.font = UIFont(name: "PingFangSC-Regular", size: 10) ?? .systemFont(ofSize: 10)
        subLabel.textColor = UIColor(white: 1, alpha: 0.45)

        let stack = UIStackView(arrangedSubviews: [valueRow, titleLabel, subLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.setCustomSpacing(10, after: valueRow)   // 数字到标签留白（参考设计）
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(value: String, unit: String, title: String, sub: String, color: UIColor) {
        valueLabel.text = value
        valueLabel.textColor = color
        unitLabel.text = unit
        titleLabel.text = title
        subLabel.text = sub
    }
}

// MARK: - 里程碑卡

final class FootprintMilestoneCard: UIView {
    init(milestone: FootprintMilestone) {
        super.init(frame: .zero)
        backgroundColor = FP.card
        layer.cornerRadius = 12
        translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = milestone.title
        title.font = UIFont(name: "PingFangSC-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        let range = UILabel()
        range.text = milestone.dateRange
        range.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        range.textColor = FP.plan
        range.translatesAutoresizingMaskIntoConstraints = false
        addSubview(range)

        let desc = UILabel()
        desc.text = milestone.desc
        desc.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        desc.textColor = UIColor(white: 1, alpha: 0.55)
        desc.translatesAutoresizingMaskIntoConstraints = false
        addSubview(desc)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            range.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            range.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            desc.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            desc.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            desc.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            desc.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 单元格形状（月=圆角方块，年=圆形，圆角随尺寸自适应）

final class FootprintCellShape: UIView {
    private let circular: Bool
    init(circular: Bool) { self.circular = circular; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = circular ? bounds.height / 2 : 12
    }
}

// MARK: - 日历视图（月 / 全年通用）

final class FootprintCalendarView: UIView {

    private let compact: Bool
    private let showsLegend: Bool
    private let weekStack = UIStackView()   // 竖排的「周」
    private let headerStack = UIStackView() // 星期表头
    private var legendView: UIView?

    /// - Parameters:
    ///   - compact: 全年视图用紧凑尺寸、不显示图例。
    ///   - showsLegend: 是否显示底部图例。
    init(compact: Bool, showsLegend: Bool) {
        self.compact = compact
        self.showsLegend = showsLegend
        super.init(frame: .zero)
        backgroundColor = compact ? .clear : FP.card
        layer.cornerRadius = compact ? 0 : 12
        translatesAutoresizingMaskIntoConstraints = false
        setup()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        let outer = UIStackView()
        outer.axis = .vertical
        outer.spacing = compact ? 6 : 8
        outer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outer)
        let pad: CGFloat = compact ? 0 : 14
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: topAnchor, constant: pad),
            outer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            outer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            outer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -pad)
        ])

        // 星期表头（日一二三四五六）——仅月视图有；年视图不显示（对齐设计）。
        if !compact {
            headerStack.axis = .horizontal
            headerStack.distribution = .fillEqually
            let symbols = [L("footprint.weekday.sun"), L("footprint.weekday.mon"), L("footprint.weekday.tue"),
                           L("footprint.weekday.wed"), L("footprint.weekday.thu"), L("footprint.weekday.fri"),
                           L("footprint.weekday.sat")]
            for s in symbols {
                let l = UILabel()
                l.text = s
                l.textAlignment = .center
                l.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
                l.textColor = UIColor(white: 1, alpha: 0.45)
                headerStack.addArrangedSubview(l)
            }
            outer.addArrangedSubview(headerStack)
        }

        weekStack.axis = .vertical
        weekStack.distribution = .fillEqually
        weekStack.spacing = compact ? 2 : 6
        outer.addArrangedSubview(weekStack)

        if showsLegend {
            let legend = makeLegend()
            outer.addArrangedSubview(legend)
            legendView = legend
        }
    }

    func configure(year: Int, month: Int, days: [FootprintDay], today: Int?) {
        weekStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var lookup: [Int: FootprintDay] = [:]
        for d in days { lookup[d.day] = d }

        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents(); comps.year = year; comps.month = month; comps.day = 1
        guard let first = cal.date(from: comps) else { return }
        let daysInMonth = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        // weekday: 1=Sunday...7=Saturday；周日在第 0 列。
        let leading = cal.component(.weekday, from: first) - 1

        var cells: [UIView] = []
        for _ in 0..<leading { cells.append(makeEmptyCell()) }
        for day in 1...daysInMonth {
            cells.append(makeDayCell(day: day, mark: lookup[day], isToday: today == day))
        }
        while cells.count % 7 != 0 { cells.append(makeEmptyCell()) }

        for weekStartIndex in stride(from: 0, to: cells.count, by: 7) {
            let row = UIStackView(arrangedSubviews: Array(cells[weekStartIndex..<weekStartIndex + 7]))
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = compact ? 4 : 6
            weekStack.addArrangedSubview(row)
        }
    }

    // 单元格高宽比（对齐 HTML 实测）：月视图格子略高于宽(1.22)；
    // 年视图行距=列距×0.88（圆直径 26.4pt / 列距 43.8pt，行距 38.4pt）。
    private var cellAspect: CGFloat { compact ? 0.88 : 1.22 }

    private func makeEmptyCell() -> UIView {
        let v = UIView()
        v.heightAnchor.constraint(equalTo: v.widthAnchor, multiplier: cellAspect).isActive = true
        return v
    }

    private func makeDayCell(day: Int, mark: FootprintDay?, isToday: Bool) -> UIView {
        let container = UIView()
        container.heightAnchor.constraint(equalTo: container.widthAnchor, multiplier: cellAspect).isActive = true

        let shape = FootprintCellShape(circular: compact)
        shape.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(shape)

        // 填充：助眠陪伴(亮紫) > App活跃(深紫) > 无。
        // 无数据：年视图灰色圆圈(#3B3B41)+白字；月视图透明+近白数字(#DFDFDF，实测≈0.87)。完成计划=金点(月)/金描边(年)。
        var fill: UIColor = compact ? FP.cellEmpty : .clear
        var textColor: UIColor = compact ? .white : UIColor(white: 0.87, alpha: 1)
        if mark?.sleepCompanion == true {
            fill = FP.companion; textColor = .white
        } else if mark?.appActive == true {
            fill = FP.appActive; textColor = .white
        }
        shape.backgroundColor = fill

        let label = UILabel()
        label.text = "\(day)"
        label.textAlignment = .center
        label.font = UIFont(name: "PingFangSC-Regular", size: compact ? 10 : 13) ?? .systemFont(ofSize: compact ? 10 : 13)
        label.textColor = textColor
        label.translatesAutoresizingMaskIntoConstraints = false
        shape.addSubview(label)

        NSLayoutConstraint.activate([
            shape.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            shape.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.centerXAnchor.constraint(equalTo: shape.centerXAnchor)
        ])

        if compact {
            // 年视图：圆形（直径 = 列宽×0.60，实测 26.4pt/43.8pt）。完成计划→金色描边；不加「今天」白圈（严格按设计）。
            shape.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.60).isActive = true
            shape.heightAnchor.constraint(equalTo: shape.widthAnchor).isActive = true
            label.centerYAnchor.constraint(equalTo: shape.centerYAnchor).isActive = true
            if mark?.planCompleted == true {
                shape.layer.borderWidth = 2; shape.layer.borderColor = FP.plan.cgColor
            }
        } else {
            // 月视图：圆角方块（宽 = 列宽×0.82，略高于宽）。数字偏上，完成计划金点在下方。
            shape.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.82).isActive = true
            shape.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.86).isActive = true
            label.centerYAnchor.constraint(equalTo: shape.centerYAnchor, constant: -5).isActive = true
            if isToday {
                shape.layer.borderWidth = 1.5; shape.layer.borderColor = UIColor.white.cgColor
            }
            if mark?.planCompleted == true {
                let dot = UIView()
                dot.backgroundColor = FP.plan
                dot.layer.cornerRadius = 2.5
                dot.translatesAutoresizingMaskIntoConstraints = false
                shape.addSubview(dot)
                NSLayoutConstraint.activate([
                    dot.widthAnchor.constraint(equalToConstant: 5),
                    dot.heightAnchor.constraint(equalToConstant: 5),
                    dot.centerXAnchor.constraint(equalTo: shape.centerXAnchor),
                    dot.bottomAnchor.constraint(equalTo: shape.bottomAnchor, constant: -6)
                ])
            }
        }
        return container
    }

    private func makeLegend() -> UIView {
        // 单行图例：App活跃(深紫) / 助眠陪伴(亮紫) / 完成计划·连续陪伴(金)。
        let items: [(UIColor, String)] = [
            (FP.appActive, L("footprint.legend.app_active")),
            (FP.companion, L("footprint.legend.companion")),
            (FP.plan, L("footprint.legend.plan"))
        ]
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        // equalSpacing 下 spacing 是最小间距：窄屏放不下时不能把三项挤到一起。
        stack.spacing = 10
        for (index, (color, text)) in items.enumerated() {
            let dot = UIView()
            dot.backgroundColor = color
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            let label = UILabel()
            label.text = text
            label.font = UIFont(name: "PingFangSC-Regular", size: 11) ?? .systemFont(ofSize: 11)
            label.textColor = UIColor(white: 1, alpha: 0.6)
            // 最后一项最长（英文 "Routine Completed / Usage Streak"），一行放不下就折成两行，其余两项保持单行。
            let isLongest = index == items.count - 1
            label.numberOfLines = isLongest ? 2 : 1
            label.setContentCompressionResistancePriority(isLongest ? .defaultLow : .required, for: .horizontal)
            let item = UIStackView(arrangedSubviews: [dot, label])
            item.axis = .horizontal
            item.spacing = 5
            item.alignment = .center
            stack.addArrangedSubview(item)
        }
        return stack
    }
}

// MARK: - 全年视图

final class FootprintAnnualViewController: UIViewController {
    private let year: Int
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private weak var currentMonthCard: UIView?   // 当前月卡片，用于首次布局后滚动到此
    private var didScrollToCurrent = false

    init(year: Int) { self.year = year; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FP.bg
        setupNav()
        load()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func setupNav() {
        let back = EnlargedHitAreaButton()
        back.setImage(UIImage(named: "sub_back"), for: .normal)
        back.translatesAutoresizingMaskIntoConstraints = false
        back.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        view.addSubview(back)

        let title = UILabel()
        title.text = String(format: L("footprint.annual.title"), year)
        title.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        // 英文标题与右上角「About These Metrics」都较长：居中只是偏好，放不下时向左让位并适度缩字，绝不与按钮重叠。
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.75
        title.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        view.addSubview(title)
        let titleCenterX = title.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        titleCenterX.priority = UILayoutPriority(500)   // 低于标题抗压缩（750）：宁可偏离居中也不截断
        titleCenterX.isActive = true

        let info = UIButton(type: .system)
        info.setTitle(L("footprint.explain"), for: .normal)
        info.setTitleColor(.white, for: .normal)
        info.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        info.translatesAutoresizingMaskIntoConstraints = false
        info.setContentCompressionResistancePriority(.required, for: .horizontal)
        info.addTarget(self, action: #selector(showExplanation), for: .touchUpInside)
        view.addSubview(info)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        // 关闭自动 inset 调整：首次上屏时系统调整 adjustedContentInset 会把手动设置的 offset 顶回顶部。
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            back.topAnchor.constraint(equalTo: safe.topAnchor, constant: 10),
            back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            back.widthAnchor.constraint(equalToConstant: 24),
            back.heightAnchor.constraint(equalToConstant: 24),
            title.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            title.leadingAnchor.constraint(greaterThanOrEqualTo: back.trailingAnchor, constant: 12),
            title.trailingAnchor.constraint(lessThanOrEqualTo: info.leadingAnchor, constant: -12),
            info.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            info.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: back.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -30),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16)
        ])
    }

    private func load() {
        CompanionFootprintService.shared.fetchYear(year: year) { [weak self] result in
            guard let self, case .success(let months) = result else { return }
            let cal = Calendar(identifier: .gregorian)
            let now = Date()
            let todayY = cal.component(.year, from: now)
            let todayM = cal.component(.month, from: now)
            let todayD = cal.component(.day, from: now)
            // 当年只展示到当前月（不显示未来月份）；往年展示全 12 个月。
            let visibleMonths = months
                .sorted(by: { $0.month < $1.month })
                .filter { self.year < todayY || ($0.year == todayY && $0.month <= todayM) }
            for m in visibleMonths {
                let card = UIView()
                card.backgroundColor = FP.card
                card.layer.cornerRadius = 18   // 设计 36px/2
                card.translatesAutoresizingMaskIntoConstraints = false

                let monthLabel = UILabel()
                monthLabel.text = FootprintFormat.monthName(year: m.year, month: m.month)
                monthLabel.font = UIFont(name: "PingFangSC-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)  // 30px/2
                monthLabel.textColor = .white
                monthLabel.translatesAutoresizingMaskIntoConstraints = false
                card.addSubview(monthLabel)

                let calView = FootprintCalendarView(compact: true, showsLegend: false)
                let today = (m.year == todayY && m.month == todayM) ? todayD : nil
                calView.configure(year: m.year, month: m.month, days: m.days, today: today)
                card.addSubview(calView)

                // 卡片内边距对齐设计：左右 20，上 20，下 24。
                NSLayoutConstraint.activate([
                    monthLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
                    monthLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
                    calView.topAnchor.constraint(equalTo: monthLabel.bottomAnchor, constant: 12),
                    calView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                    calView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                    calView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
                ])
                self.stack.addArrangedSubview(card)
                if m.year == todayY && m.month == todayM { self.currentMonthCard = card }
            }
            // 数据到位后强制布局算出 contentSize，再滚到当前月（下一 runloop 兜底一次，
            // 避免个别机型首帧 contentSize 尚未稳定）。
            self.view.layoutIfNeeded()
            self.scrollToCurrentMonth()
            DispatchQueue.main.async { self.scrollToCurrentMonth() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollToCurrentMonth()   // 布局稳定后兜底滚动一次
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToCurrentMonth()   // 上屏后最终兜底（数据先于上屏返回的场景）
    }

    /// 滚动到当前月卡片顶部，避免默认停在最顶部（1 月）。
    /// 只在「视图已上屏 + 可视高度就绪 + 内容高度就绪」时才执行并消耗一次性标志，
    /// 否则静默返回等下一个时机 —— 防止 bounds 未就绪时空跑一次把标志耗掉。
    private func scrollToCurrentMonth() {
        if didScrollToCurrent { return }
        guard let card = currentMonthCard else {
            Log.info("FootprintAnnual", "scroll skip: no currentMonthCard"); return
        }
        guard view.window != nil else {
            Log.info("FootprintAnnual", "scroll skip: window nil"); return
        }
        guard scrollView.bounds.height > 0 else {
            Log.info("FootprintAnnual", "scroll skip: bounds zero"); return
        }
        scrollView.layoutIfNeeded()
        guard scrollView.contentSize.height > 0 else {
            Log.info("FootprintAnnual", "scroll skip: contentSize zero"); return
        }
        didScrollToCurrent = true
        let target = scrollView.convert(card.frame, from: card.superview)
        let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let y = min(max(0, target.minY - 8), maxY)
        Log.info("FootprintAnnual", "scroll to y=\(y) target=\(target.minY) contentH=\(scrollView.contentSize.height) boundsH=\(scrollView.bounds.height)")
        scrollView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
    }

    @objc private func handleBack() {
        // 栈底时 pop 无处可退、静默失败，返回按钮会彻底失效（订阅页踩过这个坑）
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            (navigationController ?? self).dismiss(animated: true)
        }
    }
    @objc private func showExplanation() { FootprintInfoSheetView.present(in: view) }
}

// MARK: - 格式化工具

enum FootprintFormat {
    /// 英文按设计校对表用系统日期模板（`July 2026` / `Thu, Jul 23, 2026` / `January`）；
    /// 其他语言的版式尚未经设计校对，保持原有的 key 拼接格式不变。
    private static var usesDateTemplates: Bool {
        LocalizationManager.shared.currentLanguage == .english
    }

    private static func date(year: Int, month: Int, day: Int = 1) -> Date? {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))
    }

    /// 「2026年 7月」/ `July 2026`
    static func monthTitle(year: Int, month: Int) -> String {
        if usesDateTemplates, let d = date(year: year, month: month) {
            return DateDisplay.yearMonthFull(d)
        }
        return String(format: L("footprint.month_selector"), year, month)
    }
    /// 年视图月卡片标题：「7月」/ `July`
    static func monthName(year: Int, month: Int) -> String {
        if usesDateTemplates, let d = date(year: year, month: month) {
            return DateDisplay.monthName(d)
        }
        return String(format: L("footprint.month_label"), month)
    }
    /// 选月弹窗的月份按钮：「7月」/ `Jul`
    static func monthShort(year: Int, month: Int) -> String {
        if usesDateTemplates, let d = date(year: year, month: month) {
            return DateDisplay.monthShort(d)
        }
        return String(format: L("footprint.month_label"), month)
    }
    /// 「2026年7月23日·周四」/ `Thu, Jul 23, 2026`
    static func anchorTitle(date: Date?, weekday: Int?) -> String {
        guard let date else { return "" }
        if usesDateTemplates { return DateDisplay.dateWithWeekday(date) }
        let cal = Calendar(identifier: .gregorian)
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let wdIndex = weekday ?? ((cal.component(.weekday, from: date) + 5) % 7 + 1)  // 1=周一
        let wdKeys = ["footprint.weekday.full.mon", "footprint.weekday.full.tue", "footprint.weekday.full.wed",
                      "footprint.weekday.full.thu", "footprint.weekday.full.fri", "footprint.weekday.full.sat",
                      "footprint.weekday.full.sun"]
        let wd = L(wdKeys[min(max(wdIndex - 1, 0), 6)])
        return String(format: L("footprint.anchor_date"), y, m, d, wd)
    }
}
