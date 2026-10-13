//
//  SleepPlanEditorViewController.swift
//  mindora
//
//  新建/编辑睡眠计划页——官方三套预设与自定义计划共用同一框架，可编辑范围由
//  kind（官方/自定义）与会员等级共同决定，规则见两份"产品·设计·研发说明"：
//   - 所有等级都能改：入睡时间/起床时间/睡眠目标时长。
//   - 仅高级会员能改：入睡提醒分钟数、闹钟声音（官方计划里，普通会员点击这两项直接弹升级提示）。
//   - 官方计划的名称/执行周期/助眠方案任何等级都不可改，点击只弹只读说明。
//   - 自定义计划整页仅高级会员可进入（入口拦截在 SleepPlanViewController），执行周期/入睡提醒/
//     助眠方案/闹钟方案均需用户显式设置一遍才能保存。
//
import UIKit

final class SleepPlanEditorViewController: UIViewController {

    private var draft: SleepPlan
    private let originalSnapshot: SleepPlan
    private let isNew: Bool
    /// 自定义计划四个必填项是否都已被用户显式设置过（新建时用于门控保存按钮；编辑已有计划时视为已全部设置过）。
    private var configuredFields: Set<String>

    // 计算属性而非常量：升级会员弹窗在本页内完成购买后，需要立刻反映新等级（解锁提醒/闹钟）。
    private var tier: MembershipTier { SubscriptionManager.shared.membershipTier }

    init(kind: SleepPlanKind) {
        let now = Date()
        let plan = SleepPlan(
            kind: kind,
            targetMinutes: kind.isOfficial ? 9 * 60 : 8 * 60,
            sleepTime: 22 * 60,
            wakeTime: kind.isOfficial ? 7 * 60 : 6 * 60,
            cycle: kind.fixedCycleDays.map { .fixedDaily(days: $0) } ?? .weekdays(days: [], repeatsWeekly: true),
            reminderEnabled: kind.isOfficial,
            reminderMinutesBefore: 30,
            alarmSoundId: "sunlit_coast",
            sleepAidCategory: "smart",
            sleepAidItemId: "smart_recommend",
            createdAt: now, updatedAt: now)
        self.draft = plan
        self.originalSnapshot = plan
        self.isNew = true
        self.configuredFields = kind.isOfficial ? ["cycle", "reminder", "sleepAid", "alarm"] : []
        super.init(nibName: nil, bundle: nil)
    }

    init(existingPlan: SleepPlan) {
        self.draft = existingPlan
        self.originalSnapshot = existingPlan
        self.isNew = false
        self.configuredFields = ["cycle", "reminder", "sleepAid", "alarm"]
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()
    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 24
        return s
    }()

    private let nameLabel = UILabel()
    private let nameHintLabel = UILabel()
    private weak var trainingBadgeGradientLayer: CAGradientLayer?
    private let rangeView = SleepTimeRangeView()
    private let sleepTimeValueLabel = UILabel()
    private let wakeTimeValueLabel = UILabel()
    private let goalHeaderValueLabel = UILabel()

    private let cycleRow = SleepPlanOptionRow()
    private let reminderRow = SleepPlanOptionRow()
    private let sleepAidRow = SleepPlanOptionRow()
    private let alarmRow = SleepPlanOptionRow()

    private let saveButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitleColor(.black, for: .normal)
        b.titleLabel?.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionTitle)
        b.backgroundColor = .white
        b.layer.cornerRadius = SleepPlanTheme.primaryButtonCornerRadius
        return b
    }()
    private let saveHintLabel = UILabel()
    private let backButton = UIButton(type: .system)
    /// 官方预设头部右侧的会员等级角标（.text_5：随当前用户等级在「普通会员/高级会员」间切换）。
    private let tierTagLabel = UILabel()
    private let footerContainer = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SleepPlanTheme.pageBackground
        setupLayout()
        refreshAllUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 设计稿里本页顶部只有一个「‹」，底部是保存按钮——既没有系统导航栏也没有 Tab Bar。
        navigationController?.setNavigationBarHidden(true, animated: animated)
        hostMainTabBarController?.setCustomTabBarHidden(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            hostMainTabBarController?.setCustomTabBarHidden(false)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let gradient = trainingBadgeGradientLayer {
            gradient.frame = gradient.superlayer?.bounds ?? .zero
        }
    }

    // MARK: - Layout

    private func setupLayout() {
        // 顶部返回「‹」：设计稿在状态栏下方、左边距 20pt。
        view.addSubview(backButton)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setImage(UIImage(systemName: "chevron.left",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .light)),
                            for: .normal)
        backButton.tintColor = .white
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)

        // 底部固定区（.box_38）：说明文案 + 保存按钮，不随内容滚动。
        view.addSubview(footerContainer)
        footerContainer.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.widthAnchor.constraint(equalToConstant: 32),
            backButton.heightAnchor.constraint(equalToConstant: 32),

            footerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            footerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            footerContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerContainer.topAnchor, constant: -9)
        ])
        scrollView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            // 滚到底时卡片下边缘就是内容末尾，不留额外余量：与底部固定区之间的
            // 9pt（scrollView.bottom 那条约束）正好等于 .block_23 的 padding-top 18px→9pt。
            // 这里原来多留了 40pt，叠上去变成 49pt，说明文案被推得离卡片老远。
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        // 计划名称 .text_3: 白 48px→24pt Medium；.text_4 提示语: 白 24px→12pt Normal（非灰调，CSS 原值即纯白）
        nameLabel.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizePlanName)
        nameLabel.textColor = .white
        nameHintLabel.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionValue)
        nameHintLabel.textColor = .white
        nameHintLabel.text = L("sleepplan.editor.name_hint")
        nameHintLabel.numberOfLines = 0

        if draft.kind.isOfficial {
            // 官方预设专属头部（02.A 等设计稿）：「睡眠训练」渐变胶囊 + 标题/「高级会员」角标一行 + 两行说明，
            // 不显示自定义计划才有的「点击计划名称即可修改」提示。
            let badgeGradient = CAGradientLayer()
            badgeGradient.colors = SleepPlanTheme.trainingBadgeGradientColors
            badgeGradient.startPoint = CGPoint(x: 0.85, y: 0.15)
            badgeGradient.endPoint = CGPoint(x: 0.15, y: 0.85)
            // .text-wrapper_2: 文字 20px + padding 8px×2 = 36px→18pt 高，radius 36px 即胶囊（=高/2=9pt）。
            // 之前直接套了卡片的 18pt 圆角，配上偏高的实际高度，胶囊被撑成一个变形的椭圆。
            let badgeContainer = UIView()
            badgeContainer.layer.cornerRadius = 9
            badgeContainer.clipsToBounds = true
            badgeContainer.translatesAutoresizingMaskIntoConstraints = false
            badgeContainer.heightAnchor.constraint(equalToConstant: 18).isActive = true
            badgeContainer.layer.addSublayer(badgeGradient)
            trainingBadgeGradientLayer = badgeGradient
            let badgeLabel = UILabel()
            badgeLabel.text = L("sleepplan.section.training")
            badgeLabel.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeHint)
            badgeLabel.textColor = .white
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            badgeContainer.addSubview(badgeLabel)
            NSLayoutConstraint.activate([
                badgeLabel.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
                // padding 左右 28px→14pt
                badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 14),
                badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -14)
            ])
            let badgeRow = UIStackView(arrangedSubviews: [badgeContainer, UIView()])
            badgeRow.alignment = .center

            // .text_5: 24px→12pt Medium rgba(172,143,255)，文案是**当前用户等级**
            // （02 高级会员稿写「高级会员」，02.M/N/O/P 普通会员稿写「普通会员」）。
            tierTagLabel.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeOptionValue)
            tierTagLabel.textColor = SleepPlanTheme.premiumTagText
            // .text-wrapper_14 是 `flex-row justify-between`（整宽 670px→335pt）：标题贴左、
            // 等级角标贴右。两个 label 的 hugging 默认都是 251，distribution=.fill 时拉伸哪个
            // 由布局引擎随机挑；英文下拉伸的是角标，左对齐的「Premium」就直接糊在标题屁股后面。
            // 把「谁被拉开」定死：标题吃掉多余空间（hugging 低），角标保持自身宽度贴到右边缘。
            //
            // 中文这一行两者加起来远不满 335pt，拉伸的一直是同一块空白，最终位置与原先一致。
            nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            tierTagLabel.setContentHuggingPriority(.required, for: .horizontal)
            tierTagLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            tierTagLabel.textAlignment = .right
            // 标题超长的语种（德语等）折行而不是把角标挤出去；中文/英文都只有一行，不受影响。
            nameLabel.numberOfLines = 0
            let titleRow = UIStackView(arrangedSubviews: [nameLabel, tierTagLabel])
            // 折行时角标跟首行走（设计稿里它在行的右上角），用 lastBaseline 会掉到第二行去。
            titleRow.alignment = .firstBaseline
            // .text_4 与 .text_5 之间至少留一口气，别贴死。
            titleRow.spacing = 8

            let descriptionLabel = UILabel()
            descriptionLabel.text = L(draft.kind.descriptionKey)
            descriptionLabel.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionValue)
            descriptionLabel.textColor = .white
            descriptionLabel.numberOfLines = 0

            let headerStack = UIStackView(arrangedSubviews: [badgeRow, titleRow, descriptionLabel])
            headerStack.axis = .vertical
            headerStack.spacing = 10
            headerStack.setCustomSpacing(16, after: badgeRow)
            contentStack.addArrangedSubview(headerStack)
        } else {
            let nameStack = UIStackView(arrangedSubviews: [nameLabel, nameHintLabel])
            nameStack.axis = .vertical
            nameStack.spacing = 16
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleRenameTapped))
            nameLabel.isUserInteractionEnabled = true
            nameLabel.addGestureRecognizer(tap)
            contentStack.addArrangedSubview(nameStack)
        }

        // 睡眠目标卡片（.block_21: #2C2C2C, radius 36px→18pt）
        let goalCard = UIView()
        goalCard.backgroundColor = SleepPlanTheme.cardBackground
        goalCard.layer.cornerRadius = SleepPlanTheme.cardCornerRadius

        // .text_56: 白 36px→18pt Medium
        let goalTitle = UILabel()
        goalTitle.text = L("sleepplan.editor.sleep_goal")
        goalTitle.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeCardTitle)
        goalTitle.textColor = .white

        // .text_58: 白 28px→14pt Normal（"9小时"）
        goalHeaderValueLabel.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionTitle)
        goalHeaderValueLabel.textColor = .white
        goalHeaderValueLabel.isUserInteractionEnabled = true
        goalHeaderValueLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleGoalTapped)))

        let goalTitleRow = UIStackView(arrangedSubviews: [goalTitle, UIView(), goalHeaderValueLabel])
        goalTitleRow.axis = .horizontal
        goalTitleRow.alignment = .center

        // .text_57: 白 20px→10pt Normal
        let goalHint = UILabel()
        goalHint.text = L("sleepplan.editor.sleep_goal_hint")
        goalHint.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeHint)
        goalHint.textColor = .white
        goalHint.numberOfLines = 0
        // .text_7: width 366px→183pt、line-height 28px→14pt（设计稿里这句刻意折成两行）
        goalHint.translatesAutoresizingMaskIntoConstraints = false
        goalHint.widthAnchor.constraint(equalToConstant: 183).isActive = true
        SleepPlanTheme.applyLineHeight(14, to: goalHint)

        rangeView.translatesAutoresizingMaskIntoConstraints = false
        // 轨道 18pt + 端点上下溢出 4.5pt + 刻度数字 10.5pt 间距 ≈ 48pt
        rangeView.heightAnchor.constraint(equalToConstant: 48).isActive = true
        rangeView.onChange = { [weak self] sleepMinutes, wakeMinutes in
            guard let self else { return }
            self.draft.sleepTime = sleepMinutes
            self.draft.wakeTime = wakeMinutes
            self.draft.targetMinutes = Self.duration(sleep: sleepMinutes, wake: wakeMinutes)
            self.refreshGoalLabels()
            self.refreshSaveButtonState()
        }

        // 入睡时间数字 .text_72: 浅蓝 rgba(151,178,246,1) 48px→24pt Medium
        sleepTimeValueLabel.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizePlanName)
        sleepTimeValueLabel.textColor = SleepPlanTheme.valueBlue
        sleepTimeValueLabel.textAlignment = .left
        sleepTimeValueLabel.isUserInteractionEnabled = true
        sleepTimeValueLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleGoalTapped)))
        let sleepTimeCaption = UILabel()
        sleepTimeCaption.text = L("sleepplan.editor.sleep_time")
        sleepTimeCaption.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeHint)
        sleepTimeCaption.textColor = .white
        let sleepTimeStack = UIStackView(arrangedSubviews: [sleepTimeValueLabel, sleepTimeCaption])
        sleepTimeStack.axis = .vertical
        sleepTimeStack.spacing = 2

        // 起床时间数字 .text_74: 橙 rgba(242,182,106,1) 48px→24pt Medium
        wakeTimeValueLabel.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizePlanName)
        wakeTimeValueLabel.textColor = SleepPlanTheme.wakeOrange
        wakeTimeValueLabel.textAlignment = .right
        wakeTimeValueLabel.isUserInteractionEnabled = true
        wakeTimeValueLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleGoalTapped)))
        let wakeTimeCaption = UILabel()
        wakeTimeCaption.text = L("sleepplan.editor.wake_time")
        wakeTimeCaption.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeHint)
        wakeTimeCaption.textColor = .white
        wakeTimeCaption.textAlignment = .right
        let wakeTimeStack = UIStackView(arrangedSubviews: [wakeTimeValueLabel, wakeTimeCaption])
        wakeTimeStack.axis = .vertical
        wakeTimeStack.spacing = 2

        let timeRow = UIStackView(arrangedSubviews: [sleepTimeStack, wakeTimeStack])
        timeRow.axis = .horizontal
        timeRow.distribution = .fillEqually

        // 固定 183pt 宽的说明要放进一个左对齐容器，否则会和外层 stack 的 .fill 冲突。
        let goalHintRow = UIStackView(arrangedSubviews: [goalHint, UIView()])
        goalHintRow.axis = .horizontal

        let goalInnerStack = UIStackView(arrangedSubviews: [goalTitleRow, goalHintRow, rangeView, timeRow])
        goalInnerStack.axis = .vertical
        // .text_57 margin-top 18px→9pt；.box_29 margin-top 57px→28.5pt；.box_30 margin-top 60px→30pt
        goalInnerStack.spacing = 9
        goalInnerStack.translatesAutoresizingMaskIntoConstraints = false
        goalInnerStack.setCustomSpacing(28.5, after: goalHintRow)
        goalInnerStack.setCustomSpacing(30, after: rangeView)
        goalCard.addSubview(goalInnerStack)
        NSLayoutConstraint.activate([
            // .block_21 padding: 47.5px 31.5px 62.5px 31.5px → 23.75 / 15.75 / 31.25 pt
            goalInnerStack.topAnchor.constraint(equalTo: goalCard.topAnchor, constant: 23.75),
            goalInnerStack.leadingAnchor.constraint(equalTo: goalCard.leadingAnchor, constant: 15.75),
            goalInnerStack.trailingAnchor.constraint(equalTo: goalCard.trailingAnchor, constant: -15.75),
            goalInnerStack.bottomAnchor.constraint(equalTo: goalCard.bottomAnchor, constant: -31.25)
        ])
        contentStack.addArrangedSubview(goalCard)

        // 计划选项
        let optionsTitle = UILabel()
        optionsTitle.text = L(draft.kind.isOfficial ? "sleepplan.editor.options" : "sleepplan.editor.options.custom")
        optionsTitle.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeCardTitle)
        optionsTitle.textColor = .white
        contentStack.addArrangedSubview(optionsTitle)

        let optionsCard = UIView()
        optionsCard.backgroundColor = SleepPlanTheme.cardBackground
        optionsCard.layer.cornerRadius = SleepPlanTheme.cardCornerRadius
        let optionsStack = UIStackView(arrangedSubviews: [cycleRow, reminderRow, sleepAidRow, alarmRow])
        // 首行顶、末行底不再额外留白：卡片 padding（24pt）就是边距。
        cycleRow.topPadding = 0
        alarmRow.showsDivider = false
        alarmRow.bottomPadding = 0
        optionsStack.axis = .vertical
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsCard.addSubview(optionsStack)
        NSLayoutConstraint.activate([
            // .section_12 padding: 48px 24px 48px 24px → 24 / 12 pt
            optionsStack.topAnchor.constraint(equalTo: optionsCard.topAnchor, constant: 24),
            optionsStack.leadingAnchor.constraint(equalTo: optionsCard.leadingAnchor, constant: 12),
            optionsStack.trailingAnchor.constraint(equalTo: optionsCard.trailingAnchor, constant: -12),
            optionsStack.bottomAnchor.constraint(equalTo: optionsCard.bottomAnchor, constant: -24)
        ])
        contentStack.addArrangedSubview(optionsCard)
        // .text-wrapper_16 padding 72px 上 / 37px 下 → 36pt / 18.5pt
        contentStack.setCustomSpacing(36, after: goalCard)
        contentStack.setCustomSpacing(18.5, after: optionsTitle)

        // 官方训练是固定「执行周期」，自定义计划是按星期选的「执行日程」，标题与说明各用一套。
        cycleRow.configure(title: L(draft.kind.isOfficial ? "sleepplan.editor.cycle" : "sleepplan.editor.cycle.custom"),
                           subtitle: L(draft.kind.isOfficial ? "sleepplan.editor.cycle.hint" : "sleepplan.editor.cycle.hint.custom"))
        cycleRow.onTap = { [weak self] in self?.handleCycleTapped() }
        reminderRow.configure(title: L("sleepplan.editor.reminder"), subtitle: L("sleepplan.editor.reminder.hint"))
        reminderRow.onTap = { [weak self] in self?.handleReminderTapped() }
        sleepAidRow.configure(title: L("sleepplan.editor.sleep_aid"), subtitle: L("sleepplan.editor.sleep_aid.hint"))
        sleepAidRow.onTap = { [weak self] in self?.handleSleepAidTapped() }
        alarmRow.configure(title: L("sleepplan.editor.alarm"), subtitle: L("sleepplan.editor.alarm.hint"))
        alarmRow.onTap = { [weak self] in self?.handleAlarmTapped() }

        // .paragraph_3: 白 20px→10pt Light，line-height 28px→14pt，**左对齐**（不是居中）
        saveHintLabel.font = SleepPlanTheme.fontLight(SleepPlanTheme.fontSizeHint)
        saveHintLabel.textColor = .white
        saveHintLabel.numberOfLines = 0
        saveHintLabel.textAlignment = .left
        // 官方预设页（.paragraph_3）与自定义新建页（.text_30）文案不同，CSS 里是两段。
        // 编辑列表里已有、未开启的自定义计划另有一句（设计稿 自定义睡眠计划 36）；
        // 正在开启的计划保存后仍保持开启，那句「显示为未开启」对它不成立，沿用新建文案。
        let editingInactivePlan = SleepPlanStore.shared.plan(id: draft.id).map { $0.status != .active } ?? false
        saveHintLabel.text = L(draft.kind.isOfficial ? "sleepplan.editor.save_hint.official"
                               : editingInactivePlan ? "sleepplan.editor.save_hint.edit"
                               : "sleepplan.editor.save_hint")
        SleepPlanTheme.applyLineHeight(14, to: saveHintLabel)

        // .text-wrapper_7: radius 48px→24pt，padding 26px 上下 + 28px 文字 = 80px→40pt 高，
        // 与说明文案间距 60px→30pt
        saveButton.setTitle(L("sleepplan.action.save"), for: .normal)
        saveButton.addTarget(self, action: #selector(handleSaveTapped), for: .touchUpInside)

        let footerStack = UIStackView(arrangedSubviews: [saveHintLabel, saveButton])
        footerStack.axis = .vertical
        footerStack.spacing = 30
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        footerContainer.addSubview(footerStack)
        NSLayoutConstraint.activate([
            saveButton.heightAnchor.constraint(equalToConstant: 40),
            footerStack.topAnchor.constraint(equalTo: footerContainer.topAnchor),
            footerStack.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor),
            footerStack.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor),
            footerStack.bottomAnchor.constraint(equalTo: footerContainer.bottomAnchor)
        ])
    }

    // MARK: - Refresh

    private func refreshAllUI() {
        nameLabel.text = draft.displayName
        tierTagLabel.text = L(tier == .premium ? "sleepplan.tier.premium" : "sleepplan.tier.basic")
        refreshGoalLabels()
        refreshOptionRows()
        refreshSaveButtonState()
    }

    private func refreshGoalLabels() {
        sleepTimeValueLabel.text = DateDisplay.clock(minutesOfDay: draft.sleepTime)
        wakeTimeValueLabel.text = DateDisplay.clock(minutesOfDay: draft.wakeTime)
        goalHeaderValueLabel.text = String(format: L("sleepplan.duration.hours_short"), draft.targetMinutes / 60) + " ›"
        rangeView.configure(sleepMinutes: draft.sleepTime, wakeMinutes: draft.wakeTime)
    }

    private func refreshOptionRows() {
        let canEditReminderAlarm = tier == .premium

        switch draft.cycle {
        case .fixedDaily(let days):
            cycleRow.setValue(String(format: L("sleepplan.cycle.fixed_daily"), days), locked: false, isReadOnly: true)
        case .weekdays(let days, let repeats):
            if days.isEmpty {
                cycleRow.setValue(L("sleepplan.action.tap_to_set"), locked: false, isReadOnly: false, isPlaceholder: true)
            } else {
                // 顿号是中日文的列表分隔符，英文/欧语里要用逗号+空格——写死「、」的话
                // 英文下会渲染成「Tue、Wed」。分隔符本身走本地化。
                let names = Self.weekdaysText(days)
                let suffix = repeats ? L("sleepplan.cycle.repeats_weekly") : L("sleepplan.cycle.once")
                cycleRow.setValue("\(names) · \(suffix)", locked: false, isReadOnly: false)
            }
        }

        if draft.kind.isOfficial {
            // 普通会员：这两行不显示具体值，直接显示「高级会员」（仍是蓝色可点，点了弹升级提示）——
            // 见 02.D / 02.N / 02.O / 02.P 的 .text_49/.text_54/.text_58/.text_63。
            if canEditReminderAlarm {
                let reminderText = draft.reminderEnabled
                    ? String(format: L("sleepplan.reminder.minutes_before_short"), draft.reminderMinutesBefore) : L("sleepplan.reminder.off")
                reminderRow.setValue(reminderText, locked: false, isReadOnly: false)
                alarmRow.setValue(L(AlarmSoundPickerSheet.options.first { $0.id == draft.alarmSoundId }?.nameKey ?? "sleepplan.sound.sunlit_coast"),
                                   locked: false, isReadOnly: false)
            } else {
                reminderRow.setValue(L("sleepplan.tier.premium"), locked: false, isReadOnly: false)
                alarmRow.setValue(L("sleepplan.tier.premium"), locked: false, isReadOnly: false)
            }
            sleepAidRow.setValue(L("sleepplan.sleep_aid.smart.name"), locked: false, isReadOnly: true)
        } else {
            if configuredFields.contains("reminder") {
                let reminderText = draft.reminderEnabled
                    ? String(format: L("sleepplan.reminder.minutes_before_short"), draft.reminderMinutesBefore) : L("sleepplan.reminder.off")
                reminderRow.setValue(reminderText, locked: false, isReadOnly: false)
            } else {
                reminderRow.setValue(L("sleepplan.action.tap_to_set"), locked: false, isReadOnly: false, isPlaceholder: true)
            }
            if configuredFields.contains("sleepAid") {
                sleepAidRow.setValue(L(SleepAidPickerSheet.categories.first { $0.id == draft.sleepAidCategory }?.nameKey ?? "sleepplan.sleep_aid.smart.name"),
                                      locked: false, isReadOnly: false)
            } else {
                sleepAidRow.setValue(L("sleepplan.action.tap_to_set"), locked: false, isReadOnly: false, isPlaceholder: true)
            }
            if configuredFields.contains("alarm") {
                alarmRow.setValue(L(AlarmSoundPickerSheet.options.first { $0.id == draft.alarmSoundId }?.nameKey ?? "sleepplan.sound.sunlit_coast"),
                                   locked: false, isReadOnly: false)
            } else {
                alarmRow.setValue(L("sleepplan.action.tap_to_set"), locked: false, isReadOnly: false, isPlaceholder: true)
            }
        }
    }

    private func refreshSaveButtonState() {
        // 「最小睡眠目标为 1 小时；低于 1 小时提示无法设置并禁用保存」——浮层里拦了，但色带
        // 直接拖也能拖出不足 1 小时，这里必须再兜一次，否则能存进去一条 30 分钟的计划。
        let durationOK = draft.targetMinutes >= 60
        let ready: Bool
        if draft.kind == .custom {
            ready = durationOK
                && configuredFields.isSuperset(of: ["cycle", "reminder", "sleepAid", "alarm"])
                && !draft.cycle.hasEmptyWeekdaySelection
        } else {
            ready = durationOK
        }
        saveButton.isEnabled = ready
        // .text-wrapper_6：禁用态 #464646 底 + 白字；.text-wrapper_7/text_25：启用态白底 + 黑字。
        saveButton.backgroundColor = ready ? .white : SleepPlanTheme.disabledButtonBackground
        saveButton.setTitleColor(ready ? .black : .white, for: .normal)
    }

    // MARK: - Actions

    @objc private func handleRenameTapped() {
        PlanNameEditSheet.present(in: view, currentName: draft.customName.isEmpty ? draft.displayName : draft.customName) { [weak self] newName in
            self?.draft.customName = newName
            self?.nameLabel.text = newName
        }
    }

    @objc private func handleGoalTapped() {
        SleepGoalPickerSheet.present(in: view, sleepMinutes: draft.sleepTime, wakeMinutes: draft.wakeTime) { [weak self] sleep, wake in
            guard let self else { return }
            self.draft.sleepTime = sleep
            self.draft.wakeTime = wake
            self.draft.targetMinutes = Self.duration(sleep: sleep, wake: wake)
            self.refreshGoalLabels()
        }
    }

    private func handleCycleTapped() {
        if draft.kind.isOfficial {
            let days = draft.kind.fixedCycleDays ?? 0
            ConfirmDialogView.presentSingleAction(
                title: L("sleepplan.sheet.cycle.readonly_title"),
                message: String(format: L("sleepplan.sheet.cycle.readonly_message"), days),
                actionTitle: L("common.got_it"))
            return
        }
        guard case .weekdays(let days, let repeats) = draft.cycle else { return }
        WeekdayCyclePickerSheet.present(in: view, days: days, repeatsWeekly: repeats) { [weak self] newDays, newRepeats in
            guard let self else { return }
            self.draft.cycle = .weekdays(days: newDays, repeatsWeekly: newRepeats)
            self.configuredFields.insert("cycle")
            self.refreshOptionRows()
            self.refreshSaveButtonState()
        }
    }

    private func handleReminderTapped() {
        if draft.kind.isOfficial && tier != .premium {
            SleepPlanUpsellPresenter.presentPremiumUpsell(from: self) { [weak self] in
                self?.refreshOptionRows()
            }
            return
        }
        ReminderMinutesPickerSheet.present(in: view, current: draft.reminderMinutesBefore) { [weak self] minutes in
            guard let self else { return }
            self.draft.reminderEnabled = true
            self.draft.reminderMinutesBefore = minutes
            self.configuredFields.insert("reminder")
            self.refreshOptionRows()
            self.refreshSaveButtonState()
        }
    }

    private func handleSleepAidTapped() {
        if draft.kind.isOfficial {
            ConfirmDialogView.presentSingleAction(
                title: L("sleepplan.sheet.sleep_aid.readonly_title"),
                message: L("sleepplan.sheet.sleep_aid.readonly_message"),
                actionTitle: L("common.got_it"))
            return
        }
        SleepAidPickerSheet.present(in: view, current: draft.sleepAidCategory) { [weak self] categoryId in
            guard let self else { return }
            self.draft.sleepAidCategory = categoryId
            self.draft.sleepAidItemId = categoryId + "_default"
            self.configuredFields.insert("sleepAid")
            self.refreshOptionRows()
            self.refreshSaveButtonState()
        }
    }

    private func handleAlarmTapped() {
        if draft.kind.isOfficial && tier != .premium {
            SleepPlanUpsellPresenter.presentPremiumUpsell(from: self) { [weak self] in
                self?.refreshOptionRows()
            }
            return
        }
        AlarmSoundPickerSheet.present(in: view, current: draft.alarmSoundId) { [weak self] soundId in
            guard let self else { return }
            self.draft.alarmSoundId = soundId
            self.configuredFields.insert("alarm")
            self.refreshOptionRows()
            self.refreshSaveButtonState()
        }
    }

    @objc private func handleSaveTapped() {
        let tierNow = SubscriptionManager.shared.membershipTier
        let quota = SleepPlanQuota.slots(for: tierNow)
        let alreadySaved = SleepPlanStore.shared.plan(id: draft.id) != nil
        if !alreadySaved, SleepPlanStore.shared.occupiedSlotCount >= quota {
            // 与首页入口一致：普通会员新建自定义计划满额引导升级（01.F），高级会员是硬上限（01.C1/02.L/03.L）。
            // 普通会员保存官方训练满额时升级也解决不了「先删再加」，弹「普通会员最多 1 条」（设计稿 睡眠计划 8）。
            // 「满额弹窗关闭后保留当前全部设置，不自动返回首页，不丢失已填写数据」，所以这里只弹窗、不 pop。
            if tierNow == .basic, !draft.kind.isOfficial {
                SleepPlanUpsellPresenter.presentCustomPlanUpsell(from: self) { [weak self] in
                    self?.handleSaveTapped()
                }
            } else {
                ConfirmDialogView.presentSingleAction(title: L("sleepplan.alert.plan_full.title"),
                                                       message: SleepPlanQuota.fullMessage(for: tierNow),
                                                       actionTitle: L("common.cancel"))
            }
            return
        }
        SleepPlanStore.shared.save(draft)
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleBack() {
        guard hasUnsavedChanges() else {
            navigationController?.popViewController(animated: true)
            return
        }
        let titleKey = isNew ? "sleepplan.alert.exit_new.title" : "sleepplan.alert.unsaved_edit.title"
        let messageKey = isNew ? "sleepplan.alert.exit_new.message" : "sleepplan.alert.unsaved_edit.message"
        let outlineTitle = isNew ? L("sleepplan.action.confirm_exit") : L("sleepplan.action.discard")
        ConfirmDialogView.present(
            title: L(titleKey), message: L(messageKey),
            outlineTitle: outlineTitle, solidTitle: L("sleepplan.action.keep_editing"),
            onOutline: { [weak self] in self?.navigationController?.popViewController(animated: true) })
    }

    private func hasUnsavedChanges() -> Bool {
        draft != originalSnapshot
    }

    private static func duration(sleep: Int, wake: Int) -> Int {
        let d = wake - sleep
        return d <= 0 ? d + 1440 : d
    }
}

private extension SleepPlanCycle {
    var hasEmptyWeekdaySelection: Bool {
        if case .weekdays(let days, _) = self { return days.isEmpty }
        return false
    }
}

// MARK: - 计划选项行（执行周期/入睡提醒/助眠方案/闹钟方案通用行）

extension SleepPlanEditorViewController {
    /// 执行日的展示文本。规则要求至少连续 3 天（周六、周日、周一算连续），所以按起止范围写：
    /// `Mon–Wed` / `Sat–Mon` / 中文「周一至周三」；一整周就是 `Sun–Sat`（英文）/「周一至周日」。
    /// 不连续（理论上不会出现）时退回逐个列出。weekday 编号 1=周一 … 7=周日。
    static func weekdaysText(_ days: Set<Int>) -> String {
        let name: (Int) -> String = { L("weekday.short.\($0)") }
        let listed = days.sorted().map(name).joined(separator: L("common.list_separator"))
        guard days.count >= 2 else { return listed }
        let next: (Int) -> Int = { $0 % 7 + 1 }
        let prev: (Int) -> Int = { ($0 + 5) % 7 + 1 }
        // 起点：前一天不在集合里的那天；整周没有起点，从选择器的第一格算（英文周日、其他周一）。
        let start = days.count == 7 ? WeekdayCyclePickerSheet.displayOrder[0] : days.sorted().first { !days.contains(prev($0)) }
        guard let start else { return listed }
        var end = start
        var run = 1
        while run < days.count, days.contains(next(end)) { end = next(end); run += 1 }
        guard run == days.count else { return listed }
        return String(format: L("sleepplan.cycle.range"), name(start), name(end))
    }
}

private final class SleepPlanOptionRow: UIControl {
    var onTap: (() -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueLabel = UILabel()
    private let divider = UIView()

    /// 分割线只画在行**之间**：CSS 里 4 行只有 3 条线（group_13/16/20），
    /// 最后一行后面紧接着就是卡片下边缘，再画一条就成了贴着卡片底的多余白线。
    var showsDivider: Bool = true {
        didSet { divider.isHidden = !showsDivider }
    }
    private let lockIcon = UIImageView(image: UIImage(systemName: "lock.fill"))
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let infoIcon = UIImageView(image: UIImage(systemName: "exclamationmark.circle"))

    /// 行内容到分割线的距离。CSS 里内容与线之间是 42/30/42px→21/15/21pt，
    /// 线到下一行内容是 32/48/48px→16/24/24pt，蓝湖导出的值本身不统一，统一取 20pt。
    private static let contentGap: CGFloat = 20

    private var topPaddingConstraint: NSLayoutConstraint!
    private var bottomPaddingConstraint: NSLayoutConstraint!

    /// 首行顶部/末行底部不留这段间隙——卡片自己的 padding（.section_12 的 48px→24pt）就是边距，
    /// 再叠一层就成了用户看到的「上下空白太多」。
    var topPadding: CGFloat = contentGap { didSet { topPaddingConstraint.constant = topPadding } }
    var bottomPadding: CGFloat = contentGap { didSet { bottomPaddingConstraint.constant = -bottomPadding } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 行高**由内容撑开**，不写死。写死 76pt 的话，一行副标题的行只有约 32pt 内容，
        // 剩下 44pt 全变成上下空白，跟 CSS 对不上（CSS 里行内容就是 66px→33pt）。

        // .text_19/22/25/28: 白 28px→14pt Regular
        titleLabel.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionTitle)
        titleLabel.textColor = .white
        // .text_20/21 说明行: 白 18px→9pt Regular（CSS 原值即纯白，非灰调）
        subtitleLabel.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeTick)
        subtitleLabel.textColor = .white
        // 中文说明两行就写完，英文同一句要三行——写死 2 行会被截成
        //「The cycle length is fixed by the system a…」。行高本来就是内容撑的，放宽即可。
        //
        // ⚠️ 只能放宽到一个**有限**值，不能写 0。这一行的可用宽度取决于右边数值有多长
        //（中文「周一、周二、周三 · 每周重复」比「21天·每天」宽一倍），多行 label 靠
        // UIKit 自动回写 preferredMaxLayoutWidth 才知道该折几行；numberOfLines = 0 时这套
        // 自动机制不生效，label 按「一行」算高度、再在窄框里画一行打省略号——中文自定义
        // 计划页实测复现（「训练周期由系统固定配置，完成…」）。5 行是给德语之类留的余量。
        subtitleLabel.numberOfLines = 5
        // 左边两个 label 的 compression resistance 保持默认 750 不动：多行 label 的宽度本来就
        // 靠「抗压缩 750 > 抗拉伸 251」顶开，调低会让它缩成一条窄柱，中文版面立刻就变了。
        // 这里只把右边数值抬到 required，让原先 750:750 的随机平局有确定结果。
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        // .text_21 margin-top: 10px → 5pt
        textStack.spacing = 5
        textStack.translatesAutoresizingMaskIntoConstraints = false
        // UIStackView 默认可交互，会在 hitTest 时截走整行的触摸，导致 self（UIControl）永远收不到
        // touchesBegan、addTarget(.touchUpInside) 形同虚设——这里必须关掉，让触摸穿透到 self。
        textStack.isUserInteractionEnabled = false

        // .text_22/27/29 数值: 浅蓝 rgba(151,178,246,1) 24px→12pt Regular
        valueLabel.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionValue)
        valueLabel.textColor = SleepPlanTheme.valueBlue
        valueLabel.textAlignment = .right
        // 执行周期这一项的值是「周二、周三 · 每周重复」这种拼出来的串，英文（Tue, Wed · Repeats
        // weekly）长出一截。左边说明和右边数值原先 compression resistance 都是 750，谁被压
        // 由布局引擎随机挑，结果是数值被截成「Tue、」。这里明确：数值优先保全（一行写完，
        // 不许压），左边说明让位（本来就是多行，折行即可）。
        //
        // ⚠️ 不要再给这一行加「右侧不超过行宽 xx%」或「左侧至少 xx pt」之类的宽度约束。
        // 左边是多行 label，UIKit 会把它上一轮的实际宽度回写成 preferredMaxLayoutWidth，
        // 于是任何 required 的宽度约束都会变成吸引子：哪怕数值远没到上限，说明也会被钉在
        // 那个值上折行。逐张截图比对过两次，中文说明当场从一行变两行。
        // 保持单行。试过放开成 2 行让长数值折行，中文自定义计划页当场坏掉：数值一变成
        // 多行 label，左边说明的自动 preferredMaxLayoutWidth 就失准，两行说明被压成一行
        // 加省略号（截图比对确认）。数值靠下面 required 的抗压缩保全，不靠折行。
        valueLabel.numberOfLines = 1
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        lockIcon.tintColor = UIColor.white.withAlphaComponent(0.5)
        lockIcon.translatesAutoresizingMaskIntoConstraints = false
        // infoIcon 只在 isReadOnly 行显示，颜色跟随只读数值统一用 wakeOrange。
        infoIcon.tintColor = SleepPlanTheme.wakeOrange
        infoIcon.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = UIColor.white.withAlphaComponent(0.3)
        chevron.translatesAutoresizingMaskIntoConstraints = false

        let trailingStack = UIStackView(arrangedSubviews: [valueLabel, infoIcon, lockIcon, chevron])
        trailingStack.axis = .horizontal
        trailingStack.spacing = 4
        trailingStack.alignment = .center
        trailingStack.translatesAutoresizingMaskIntoConstraints = false
        trailingStack.isUserInteractionEnabled = false

        // 分割线 .group_13/16/20: rgba(255,255,255,0.4)，宽 622px→311pt。
        // （.group_19 不是分割线，是 10x22px 的箭头图标，别跟着一起抄。）
        divider.backgroundColor = SleepPlanTheme.divider
        divider.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textStack)
        addSubview(trailingStack)
        addSubview(divider)
        topPaddingConstraint = textStack.topAnchor.constraint(equalTo: topAnchor, constant: topPadding)
        bottomPaddingConstraint = textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomPadding)
        NSLayoutConstraint.activate([
            // 行内容 .box_46/47/48/49 宽 606px→303pt，分割线 622px→311pt，两者不等宽：
            // 卡片内容区（670-48=622px）里，文字再各缩 8px→4pt。贴着分割线排会宽出 8pt。
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            topPaddingConstraint,
            bottomPaddingConstraint,
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingStack.leadingAnchor, constant: -8),

            trailingStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            // 跟文字块对齐，而不是跟整行对齐：末行没有下间隙，按整行居中会偏下。
            trailingStack.centerYAnchor.constraint(equalTo: textStack.centerYAnchor),

            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    func setValue(_ text: String, locked: Bool, isReadOnly: Bool, isPlaceholder: Bool = false) {
        valueLabel.text = text
        // CSS 原文逐值核对：只读项（执行周期/助眠方案）数值色是 rgba(242,182,106,1)（wakeOrange），
        // 与可编辑项（入睡提醒/闹钟方案）的 valueBlue 明确不同，用颜色区分「能不能点」。
        valueLabel.textColor = isPlaceholder ? UIColor.white.withAlphaComponent(0.3)
            : (locked ? UIColor.white.withAlphaComponent(0.4)
               : (isReadOnly ? SleepPlanTheme.wakeOrange : SleepPlanTheme.valueBlue))
        lockIcon.isHidden = !locked
        infoIcon.isHidden = !isReadOnly
        chevron.isHidden = isReadOnly
    }

    @objc private func tapped() { onTap?() }
}
