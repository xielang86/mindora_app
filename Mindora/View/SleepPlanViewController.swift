//
//  SleepPlanViewController.swift
//  mindora
//
//  「睡眠计划」Tab 首页。状态 A（无自建计划）/ 状态 B（已有保存计划）/ 状态 C（高级会员计划已满/降级锁定）
//  见 dev/20260812_睡眠计划/设计图/状态 A｜无计划｜Screen.png 与 状态 B｜已有开启计划＋未开启列表｜Screen.png。
//
import UIKit

final class SleepPlanViewController: UIViewController {

    // MARK: - Header（与 ExploreViewController 头部完全一致：侧栏 + Logo + 消息铃）

    private let headerView = UIView()
    private let sideBarButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "home_side_bar"), for: .normal)
        return button
    }()
    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "logo_dream"))
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    private let notificationButton = NotificationBellButton()

    // MARK: - Gate（未订阅：整页遮罩，与睡眠周/月、洞察页一致）

    private let subscriptionGate: SubscriptionPromptView = {
        let v = SubscriptionPromptView()
        v.isHidden = true
        return v
    }()
    private var overlayMaskView: UIView?

    // MARK: - Scroll content

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.backgroundColor = .clear
        return sv
    }()
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 28
        stack.alignment = .fill
        return stack
    }()

    private let titleRow = UIView()
    // .text_20: 白 48px→24pt Medium
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizePlanName)
        l.textColor = .white
        l.text = L("sleepplan.title")
        return l
    }()
    // .box_31: rgba(44,44,44,.32) 圆形，1px 描边 rgba(124,124,124,1)。
    // 尺寸 = 内容 24px + padding 17px×2 + 描边 1px×2 = 60px → 30pt；
    // .box_32/.box_33 加号笔画 24×2px → 12×1pt，圆角 4px→2pt。
    private let addButton: UIButton = {
        let b = UIButton(type: .custom)
        b.backgroundColor = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 0.32)
        b.layer.cornerRadius = 15
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor(red: 124/255, green: 124/255, blue: 124/255, alpha: 1).cgColor

        // 用两根约束居中的实心条画加号：走 setImage 的话 UIButton 会自己加内边距，
        // 加号会偏到左上角且横竖不等长（真机走查可见）。
        for isHorizontal in [true, false] {
            let bar = UIView()
            bar.backgroundColor = .white
            bar.layer.cornerRadius = 0.5
            bar.isUserInteractionEnabled = false
            bar.translatesAutoresizingMaskIntoConstraints = false
            b.addSubview(bar)
            NSLayoutConstraint.activate([
                bar.centerXAnchor.constraint(equalTo: b.centerXAnchor),
                bar.centerYAnchor.constraint(equalTo: b.centerYAnchor),
                bar.widthAnchor.constraint(equalToConstant: isHorizontal ? 12 : 1),
                bar.heightAnchor.constraint(equalToConstant: isHorizontal ? 1 : 12)
            ])
        }
        return b
    }()
    // .text_21: 白 24px→12pt Normal（非灰调）
    private let introLabel: UILabel = {
        let l = UILabel()
        l.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionValue)
        l.textColor = .white
        l.numberOfLines = 0
        l.text = L("sleepplan.intro")
        return l
    }()

    // .text_22: 白 36px→18pt Medium
    private let trainingSectionTitle: UILabel = {
        let l = UILabel()
        l.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeCardTitle)
        l.textColor = .white
        l.text = L("sleepplan.section.training")
        return l
    }()
    // .text_23: 白 24px→12pt Normal
    private let trainingSectionSubtitle: UILabel = {
        let l = UILabel()
        l.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionValue)
        l.textColor = .white
        l.numberOfLines = 0
        l.text = L("sleepplan.section.training.subtitle")
        return l
    }()
    private let trainingScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        return sv
    }()
    private let trainingStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        // 卡片间距 32px→16pt
        s.spacing = 16
        s.alignment = .fill
        return s
    }()

    // .text_7: 白 36px→18pt Medium
    private let myPlansSectionTitle: UILabel = {
        let l = UILabel()
        l.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeCardTitle)
        l.textColor = .white
        l.text = L("sleepplan.section.my_plans")
        return l
    }()
    private let myPlansQuotaLabel: UILabel = {
        let l = UILabel()
        l.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionValue)
        l.textColor = SleepPlanTheme.secondaryText
        return l
    }()
    private let myPlansSectionHeader = UIView()
    // .text_8: 白 24px→12pt Normal（非灰调）
    private let emptyStateLabel: UILabel = {
        let l = UILabel()
        l.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionValue)
        l.textColor = .white
        l.text = L("sleepplan.my_plans.empty")
        return l
    }()
    private let myPlansStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        // .list-items margin-bottom 26px→13pt
        s.spacing = 13
        return s
    }()
    // .text-wrapper_1: 纯白 radius 48px→24pt；.text_9: 黑 28px→14pt Normal
    private let createPlanButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle(L("sleepplan.action.create_plan"), for: .normal)
        b.setTitleColor(.black, for: .normal)
        b.titleLabel?.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionTitle)
        b.backgroundColor = .white
        b.layer.cornerRadius = SleepPlanTheme.primaryButtonCornerRadius
        return b
    }()

    private let officialKinds: [SleepPlanKind] = [.habitFormation, .jetLag, .anxietyRelief]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SleepPlanTheme.pageBackground
        setupHeader()
        setupScrollView()
        setupContent()
        reloadTrainingCards()
        subscriptionGate.onSubscribeTap = { [weak self] in
            let vc = SubscriptionViewController()
            if let nav = self?.navigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                vc.modalPresentationStyle = .fullScreen
                self?.present(vc, animated: true)
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(reloadData),
                                                name: SleepPlanStore.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData),
                                                name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSyncRejected(_:)),
                                                name: SleepPlanSyncService.didRejectNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 设计稿里 Tab 页只有 MINDORA 自绘头部，没有系统导航栏（与首页/睡眠/探索一致）。
        navigationController?.setNavigationBarHidden(true, animated: animated)
        reloadData()
        // 每次进 Tab 同步一次（接口文档 §9）。plans 可能为空 —— 那这次就只是去拉最新的，
        // 让别的设备上做的改动能显示出来。
        SleepPlanSyncService.shared.sync(reason: "tab")
    }

    /// 服务端拒绝了本次上报里的某些条目（接口文档 §7「rejected reason 取值」）。
    ///
    /// 只提示**第一条**：一批里往往是同一个原因（比如降级后一次性上报 5 条，后 4 条全是
    /// quota_exceeded），逐条弹窗会把用户按在屏幕上点五次。
    @objc private func handleSyncRejected(_ note: Notification) {
        // 只在本页真正显示着的时候弹。回前台那次同步（reason=foreground）可能在用户
        // 待在首页时返回拒绝，这个观察者却一直挂着 —— 不判可见性的话，用户会在首页
        // 莫名其妙收到一个「睡眠计划已满」的弹窗。
        guard isViewLoaded, view.window != nil else { return }
        guard let items = note.object as? [SleepPlanSyncService.RejectedItem],
              let first = items.first(where: { $0.reason != "duplicate_official_kind" }) else { return }
        // duplicate_official_kind 不提示：服务端已经把它合并到已有那条了，对用户是无感的。

        switch first.reason {
        case "quota_exceeded":
            ConfirmDialogView.presentSingleAction(
                title: L("sleepplan.alert.plan_full.title"),
                message: SleepPlanQuota.fullMessage(for: SubscriptionManager.shared.membershipTier),
                actionTitle: L("common.cancel"))
        case "tier_not_allowed":
            ConfirmDialogView.presentSingleAction(
                title: L("sleepplan.alert.premium_required.title"),
                message: L("sleepplan.alert.custom_plan_required.message"),
                actionTitle: L("common.ok"))
        case "invalid_duration":
            Toast.show(L("sleepplan.sheet.goal.too_short"), in: view)
        case "invalid_cycle":
            Toast.show(L("sleepplan.sheet.cycle.warning"), in: view)
        case "invalid_name":
            Toast.show(L("sleepplan.sheet.rename.hint"), in: view)
        default:
            break
        }
        reloadData()
    }

    @objc private func reloadData() {
        SleepPlanStore.shared.refreshCompletionStates()
        updateMembershipOverlay(gated: SubscriptionManager.shared.shouldGatePremiumContent)
        reloadMyPlansSection()
    }

    // MARK: - Header

    private func setupHeader() {
        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(sideBarButton)
        headerView.addSubview(logoImageView)
        headerView.addSubview(notificationButton)
        sideBarButton.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        notificationButton.translatesAutoresizingMaskIntoConstraints = false

        sideBarButton.addTarget(self, action: #selector(handleSideBarTapped), for: .touchUpInside)
        notificationButton.addTarget(self, action: #selector(handleNotificationTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),

            sideBarButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            sideBarButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            sideBarButton.widthAnchor.constraint(equalToConstant: 24),
            sideBarButton.heightAnchor.constraint(equalToConstant: 24),

            logoImageView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            logoImageView.heightAnchor.constraint(equalToConstant: 30),
            logoImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 153),

            notificationButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            notificationButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            notificationButton.widthAnchor.constraint(equalToConstant: 28),
            notificationButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func handleSideBarTapped() {
        let sideMenuVC = SideMenuViewController()
        sideMenuVC.modalPresentationStyle = .overFullScreen
        present(sideMenuVC, animated: false, completion: nil)
    }

    @objc private func handleNotificationTapped() {
        let vc = NotificationsViewController()
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    // MARK: - Scroll + content skeleton

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        scrollView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    private func setupContent() {
        // 标题行：睡眠计划 + 右上角「+」
        titleRow.addSubview(titleLabel)
        titleRow.addSubview(addButton)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addTarget(self, action: #selector(handleCreatePlanTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleRow.centerYAnchor),
            titleLabel.topAnchor.constraint(equalTo: titleRow.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: titleRow.bottomAnchor),

            addButton.trailingAnchor.constraint(equalTo: titleRow.trailingAnchor),
            addButton.centerYAnchor.constraint(equalTo: titleRow.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 30),
            addButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        contentStack.addArrangedSubview(titleRow)
        // .text_21 line-height 36px→18pt
        SleepPlanTheme.applyLineHeight(18, to: introLabel)
        contentStack.addArrangedSubview(introLabel)

        // 睡眠训练：官方预设横滑卡片
        let trainingHeader = UIStackView(arrangedSubviews: [trainingSectionTitle, trainingSectionSubtitle])
        trainingHeader.axis = .vertical
        // .text_23 margin-top 14px→7pt
        trainingHeader.spacing = 7
        contentStack.addArrangedSubview(trainingHeader)

        trainingScrollView.addSubview(trainingStack)
        trainingStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            trainingStack.topAnchor.constraint(equalTo: trainingScrollView.topAnchor),
            trainingStack.bottomAnchor.constraint(equalTo: trainingScrollView.bottomAnchor),
            trainingStack.leadingAnchor.constraint(equalTo: trainingScrollView.leadingAnchor),
            trainingStack.trailingAnchor.constraint(equalTo: trainingScrollView.trailingAnchor),
            trainingStack.heightAnchor.constraint(equalTo: trainingScrollView.heightAnchor)
        ])
        trainingScrollView.translatesAutoresizingMaskIntoConstraints = false
        // 高度不写死：上面那条 trainingStack.height == trainingScrollView.height 会把
        // 卡片撑出来的高度传回滚动视图自身。卡片有 >= 114pt 的下限，中文下仍是设计稿的
        // 228px→114pt；英文标题/说明各多一行时整排卡片一起长高，不再被裁掉半行。
        contentStack.addArrangedSubview(trainingScrollView)

        // 我的睡眠计划
        myPlansSectionHeader.addSubview(myPlansSectionTitle)
        myPlansSectionHeader.addSubview(myPlansQuotaLabel)
        myPlansSectionTitle.translatesAutoresizingMaskIntoConstraints = false
        myPlansQuotaLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            myPlansSectionTitle.leadingAnchor.constraint(equalTo: myPlansSectionHeader.leadingAnchor),
            myPlansSectionTitle.topAnchor.constraint(equalTo: myPlansSectionHeader.topAnchor),
            myPlansSectionTitle.bottomAnchor.constraint(equalTo: myPlansSectionHeader.bottomAnchor),
            myPlansQuotaLabel.trailingAnchor.constraint(equalTo: myPlansSectionHeader.trailingAnchor),
            myPlansQuotaLabel.centerYAnchor.constraint(equalTo: myPlansSectionTitle.centerYAnchor)
        ])
        contentStack.addArrangedSubview(myPlansSectionHeader)
        contentStack.addArrangedSubview(emptyStateLabel)
        contentStack.addArrangedSubview(myPlansStack)

        createPlanButton.translatesAutoresizingMaskIntoConstraints = false
        // .text-wrapper_1: padding 26px×2 + 文字 28px = 80px → 40pt
        createPlanButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        createPlanButton.addTarget(self, action: #selector(handleCreatePlanTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(createPlanButton)

        // 逐段间距按 CSS 取值（750px 稿 ÷2）：
        // .text_21 margin-top 26px→13pt；.section_19 margin-top 100px→50pt；
        // 卡片区上下各 20pt / .text-group_3 margin-top 100px→50pt；
        // .text_8 margin-top 14px→7pt；.text-wrapper_1 margin-top 76px→38pt
        contentStack.setCustomSpacing(13, after: titleRow)
        contentStack.setCustomSpacing(50, after: introLabel)
        contentStack.setCustomSpacing(20, after: trainingHeader)
        contentStack.setCustomSpacing(50, after: trainingScrollView)
        contentStack.setCustomSpacing(7, after: myPlansSectionHeader)
        contentStack.setCustomSpacing(38, after: emptyStateLabel)
        contentStack.setCustomSpacing(38, after: myPlansStack)
    }

    // MARK: - 睡眠训练卡片

    private func reloadTrainingCards() {
        trainingStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for kind in officialKinds {
            let card = SleepTrainingCardView(kind: kind)
            card.onTap = { [weak self] in self?.openOfficialPlan(kind: kind) }
            trainingStack.addArrangedSubview(card)
        }
    }

    private func openOfficialPlan(kind: SleepPlanKind) {
        // 官方预设是「一套方案」，不是「每次点都新建一条」——列表里已经有同一套就进去编辑它，
        // 否则点两次同一张卡片会存出两条一模一样的计划、白占额度。
        let editor: SleepPlanEditorViewController
        if let existing = SleepPlanStore.shared.all.first(where: { $0.kind == kind }) {
            editor = SleepPlanEditorViewController(existingPlan: existing)
        } else {
            editor = SleepPlanEditorViewController(kind: kind)
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    // MARK: - 我的睡眠计划

    private func reloadMyPlansSection() {
        let tier = SubscriptionManager.shared.membershipTier
        let plans = SleepPlanStore.shared.sortedPlans
        let quota = SleepPlanQuota.slots(for: tier)

        // 配额文案「普通会员 · 1/1」仅在普通会员出现（01.D/01.E CSS 逐值核对）；
        // 高级会员（01｜状态 B）与未订阅（整页已遮罩）都不显示。
        myPlansQuotaLabel.text = tier == .basic
            ? String(format: L("sleepplan.my_plans.quota"), L("sleepplan.tier.basic"), plans.count, quota)
            : ""

        emptyStateLabel.isHidden = !plans.isEmpty
        myPlansStack.isHidden = plans.isEmpty
        // 空态：.text_8 margin-top 14px→7pt；有列表时（状态 B）标题到首张卡片约 38px→19pt。
        contentStack.setCustomSpacing(plans.isEmpty ? 7 : 19, after: myPlansSectionHeader)
        myPlansStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, plan) in plans.enumerated() {
            // 状态 C：高级会员降级后，非当前开启/非首位的计划灰色锁定（可删不可开启/编辑）。
            let isLockedByDowngrade = tier == .basic && plan.status != .active && index >= quota
            let cell = SleepPlanListCell(plan: plan, isLockedByDowngrade: isLockedByDowngrade)
            cell.onToggle = { [weak self] in self?.handleToggle(plan: plan) }
            cell.onTapEdit = { [weak self] in self?.handleEdit(plan: plan, locked: isLockedByDowngrade) }
            cell.onDelete = { [weak self] in self?.handleDelete(plan: plan) }
            myPlansStack.addArrangedSubview(cell)
        }
    }

    private func handleToggle(plan: SleepPlan) {
        if plan.status == .active {
            if plan.isLockedForTonight() {
                showLockedTonightAlert()
                return
            }
            SleepPlanStore.shared.disable(id: plan.id)
            return
        }
        guard let active = SleepPlanStore.shared.activePlan else {
            SleepPlanStore.shared.enable(id: plan.id)
            return
        }
        // 「此时不可切换计划」：当前开启的计划今晚已经开始，连开别的计划也要拦住。
        if active.isLockedForTonight() {
            showLockedTonightAlert()
            return
        }
        ConfirmDialogView.present(
            title: L("sleepplan.alert.switch_plan.title"),
            message: String(format: L("sleepplan.alert.switch_plan.message"), active.displayName),
            outlineTitle: L("common.cancel"),
            solidTitle: L("common.confirm"),
            onSolid: { SleepPlanStore.shared.enable(id: plan.id) }
        )
    }

    /// 提示「今晚计划已开始，暂不可关闭」，并把被用户拨动的开关回滚回真实状态。
    private func showLockedTonightAlert() {
        ConfirmDialogView.presentSingleAction(
            title: L("sleepplan.alert.locked_tonight.title"),
            message: L("sleepplan.alert.locked_tonight.message"),
            actionTitle: L("common.ok"))
        reloadMyPlansSection()
    }

    private func handleEdit(plan: SleepPlan, locked: Bool) {
        guard !locked else { return }
        let editor = SleepPlanEditorViewController(existingPlan: plan)
        navigationController?.pushViewController(editor, animated: true)
    }

    private func handleDelete(plan: SleepPlan) {
        guard plan.status != .active else { return }
        SleepPlanStore.shared.delete(id: plan.id)
    }

    @objc private func handleCreatePlanTapped() {
        let tier = SubscriptionManager.shared.membershipTier
        // 会员权益表：「新建睡眠计划（个性化）」Basic 与 Premium 都是 ✅，差别只在列表额度
        // （Basic 1 条 / Premium 5 条）。所以普通会员**可以**进自定义创建流程，只有额度满了才拦。
        guard SleepPlanStore.shared.occupiedSlotCount >= SleepPlanQuota.slots(for: tier) else {
            let editor = SleepPlanEditorViewController(kind: .custom)
            navigationController?.pushViewController(editor, animated: true)
            return
        }
        presentQuotaFullBlock(tier: tier)
    }

    /// 额度已满时的拦截：普通会员引导升级（01.F/03.M，升级成功后回流进自定义编辑页），
    /// 高级会员是硬上限、只能先删（01.C1，弹窗只保留居中的「取消」）。
    private func presentQuotaFullBlock(tier: MembershipTier) {
        guard tier == .basic else {
            ConfirmDialogView.presentSingleAction(
                title: L("sleepplan.alert.plan_full.title"),
                message: L("sleepplan.alert.plan_full.message"),
                actionTitle: L("common.cancel"))
            return
        }
        SleepPlanUpsellPresenter.presentCustomPlanUpsell(from: self) { [weak self] in
            guard let self else { return }
            let editor = SleepPlanEditorViewController(kind: .custom)
            self.navigationController?.pushViewController(editor, animated: true)
        }
    }

    // MARK: - 会员遮罩（未订阅：整页遮罩，与 ExploreViewController.setupNonMemberOverlay 一致）

    private func updateMembershipOverlay(gated: Bool) {
        if gated {
            setupNonMemberOverlay()
            scrollView.isScrollEnabled = false
        } else {
            removeNonMemberOverlay()
            scrollView.isScrollEnabled = true
        }
    }

    private func setupNonMemberOverlay() {
        guard overlayMaskView == nil else { return }
        view.layoutIfNeeded()

        let mask = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        mask.alpha = 0.9
        mask.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mask)
        overlayMaskView = mask

        subscriptionGate.translatesAutoresizingMaskIntoConstraints = false
        subscriptionGate.isHidden = false
        view.addSubview(subscriptionGate)

        NSLayoutConstraint.activate([
            mask.topAnchor.constraint(equalTo: introLabel.bottomAnchor, constant: 10),
            mask.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mask.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mask.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            subscriptionGate.topAnchor.constraint(equalTo: introLabel.bottomAnchor, constant: 47),
            subscriptionGate.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subscriptionGate.widthAnchor.constraint(equalToConstant: 214)
        ])

        view.bringSubviewToFront(mask)
        view.bringSubviewToFront(subscriptionGate)
    }

    private func removeNonMemberOverlay() {
        overlayMaskView?.removeFromSuperview()
        overlayMaskView = nil
        if subscriptionGate.superview != nil {
            subscriptionGate.removeFromSuperview()
        }
    }
}

// MARK: - 睡眠训练官方预设卡片

private final class SleepTrainingCardView: UIControl {
    var onTap: (() -> Void)?

    private let kind: SleepPlanKind
    private let gradientLayer = CAGradientLayer()

    init(kind: SleepPlanKind) {
        self.kind = kind
        super.init(frame: .zero)
        // .block_1/.block_2/.block_3: radius 36px→18pt, linear-gradient(317deg, ...)
        layer.cornerRadius = SleepPlanTheme.cardCornerRadius
        // 渐变层铺满 bounds，不裁切的话四角仍是直角（走查时卡片圆角完全没生效）。
        layer.masksToBounds = true
        gradientLayer.colors = Self.gradientColors(for: kind)
        // 317deg ≈ 右下→左上对角线（CAGradientLayer 用单位坐标近似 CSS 角度）。
        gradientLayer.startPoint = CGPoint(x: 0.85, y: 0.85)
        gradientLayer.endPoint = CGPoint(x: 0.15, y: 0.15)
        layer.insertSublayer(gradientLayer, at: 0)
        translatesAutoresizingMaskIntoConstraints = false
        // .text-wrapper_2: width 268px→134pt。
        // 高度：中文稿是 228px→114pt，但卡片里三段文字的行数是语种相关的（英文标题要两行、
        // 说明要两行），写死 114pt 时英文直接溢出被 masksToBounds 裁掉半行。这里改成
        // 「不小于设计稿高度、由内容撑开」，中文仍严格落在 114pt。
        widthAnchor.constraint(equalToConstant: 134).isActive = true
        heightAnchor.constraint(greaterThanOrEqualToConstant: 114).isActive = true

        // .text_1/.text_4/.text_10: 白 28px→14pt Medium
        let nameLabel = UILabel()
        nameLabel.text = L(kind.nameKey)
        nameLabel.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeOptionTitle)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 2

        // .text_2/.text_5: 白 22px→11pt Regular
        // 中文「21天习惯养成」一行就够，英文「21-day habit training」在 106.5pt 的内容宽里
        // 放不下，写死一行会被截成「21-day habit traini…」。允许折行，卡片跟着长高。
        let summaryLabel = UILabel()
        summaryLabel.text = L(kind.summaryKey)
        summaryLabel.font = SleepPlanTheme.fontRegular(11)
        summaryLabel.textColor = .white
        summaryLabel.numberOfLines = 0

        // .text_3/.text_6: 白 20px→10pt Normal
        let detailLabel = UILabel()
        detailLabel.text = L("sleepplan.action.plan_detail")
        detailLabel.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeHint)
        detailLabel.textColor = .white

        let stack = UIStackView(arrangedSubviews: [nameLabel, UIView(), summaryLabel, detailLabel])
        stack.axis = .vertical
        // .text_3 margin-top 14px→7pt
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        // UIStackView 默认可交互，覆盖在 self（UIControl）上会截走触摸，导致卡片点击完全无响应。
        stack.isUserInteractionEnabled = false
        addSubview(stack)
        // .block_1 padding: 35.5px 27.5px 39.5px → 17.75 / 13.75 / 19.75 pt
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 17.75),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13.75),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13.75),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -19.75)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    @objc private func tapped() { onTap?() }

    /// .block_1/.block_2/.block_3 精确渐变色：317deg linear-gradient。
    private static func gradientColors(for kind: SleepPlanKind) -> [CGColor] {
        switch kind {
        case .habitFormation:
            return [UIColor(red: 31/255, green: 57/255, blue: 54/255, alpha: 1).cgColor,
                    UIColor(red: 28/255, green: 38/255, blue: 38/255, alpha: 1).cgColor]
        case .jetLag:
            return [UIColor(red: 66/255, green: 85/255, blue: 96/255, alpha: 1).cgColor,
                    UIColor(red: 43/255, green: 62/255, blue: 73/255, alpha: 1).cgColor]
        case .anxietyRelief:
            return [UIColor(red: 71/255, green: 81/255, blue: 132/255, alpha: 1).cgColor,
                    UIColor(red: 54/255, green: 64/255, blue: 109/255, alpha: 1).cgColor]
        case .custom:
            return [UIColor(white: 0.3, alpha: 1).cgColor, UIColor(white: 0.15, alpha: 1).cgColor]
        }
    }
}

// MARK: - 我的睡眠计划列表 Cell

private final class SleepPlanListCell: UIView, UIGestureRecognizerDelegate {
    var onToggle: (() -> Void)?
    var onTapEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    private let plan: SleepPlan
    private let isLockedByDowngrade: Bool
    private let toggle = UISwitch()
    private var editButtonRef: UIButton?

    init(plan: SleepPlan, isLockedByDowngrade: Bool) {
        self.plan = plan
        self.isLockedByDowngrade = isLockedByDowngrade
        super.init(frame: .zero)

        // .list-items_1-0: #2C2C2C, radius 36px→18pt；已开启行额外描边白 2px→1pt（其余无描边，
        // 与"状态 B"截图一致：仅当前开启的那条卡片有描边高亮）。
        backgroundColor = SleepPlanTheme.cardBackground
        layer.cornerRadius = SleepPlanTheme.cardCornerRadius
        layer.borderWidth = plan.status == .active ? 1 : 0
        layer.borderColor = UIColor.white.cgColor

        // .text_8-0: 白 28px→14pt Medium
        let nameLabel = UILabel()
        nameLabel.text = plan.displayName
        nameLabel.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeOptionTitle)
        nameLabel.textColor = isLockedByDowngrade ? UIColor.white.withAlphaComponent(0.4) : .white

        // .text_9-0: 白 22px→11pt Normal
        // 「已完成/已停止」是产品说明里明确列出的状态，不能都笼统显示成「未开启」。
        let statusKey: String
        switch plan.status {
        case .active: statusKey = "sleepplan.status.active"
        case .notEnabled: statusKey = "sleepplan.status.not_enabled"
        case .completed: statusKey = "sleepplan.status.completed"
        case .stopped: statusKey = "sleepplan.status.stopped"
        }
        let statusText = L(statusKey)
        let sleepTimeText = DateDisplay.clock(minutesOfDay: plan.sleepTime)
        let subLabel = UILabel()
        subLabel.text = "\(statusText)  ·  \(String(format: L("sleepplan.list.target_sleep_time"), sleepTimeText))"
        subLabel.font = SleepPlanTheme.fontRegular(11)
        // 设计稿实测 rgb(171,171,171)，即 #2C2C2C 底上的白 60%（CSS 导出丢了透明度）
        subLabel.textColor = UIColor.white.withAlphaComponent(isLockedByDowngrade ? 0.25 : 0.6)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, subLabel])
        textStack.axis = .vertical
        // .text_9-0 margin-top 28px→14pt
        textStack.spacing = 14
        textStack.translatesAutoresizingMaskIntoConstraints = false

        // .text_10-0: 白 22px→11pt Normal
        let editButton = UIButton(type: .system)
        editButton.setTitle(L("sleepplan.action.edit"), for: .normal)
        editButton.setTitleColor(UIColor.white.withAlphaComponent(isLockedByDowngrade ? 0.3 : 1.0), for: .normal)
        editButton.titleLabel?.font = SleepPlanTheme.fontRegular(11)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        editButton.isEnabled = !isLockedByDowngrade
        editButtonRef = editButton

        // .box_1-0 开: rgba(87,216,150,1)；.box_1-1 关: rgba(84,84,84,1)（UISwitch 只能定制 onTintColor）。
        toggle.isOn = plan.status == .active
        toggle.onTintColor = UIColor(red: 87/255, green: 216/255, blue: 150/255, alpha: 1.0)
        // .box_1-0: 75×42px→37.5×21pt，UISwitch 原生 51×31，等比缩到 0.7
        toggle.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        // 「当晚计划已经开始后，开关进入禁用状态，并提示"今晚计划已开始，暂不可关闭"」——
        // 真把 isEnabled 关掉就收不到点击、也就弹不出那句提示，这里保持可点，由
        // handleToggle 拦截并回滚开关。
        toggle.isEnabled = !isLockedByDowngrade

        addSubview(textStack)
        addSubview(editButton)
        addSubview(toggle)

        // .list-items_1-x: 高 154px→77pt，padding 36px 48px 36px 36px → 上下 18pt / 左 18pt / 右 24pt
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 77),

            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),

            editButton.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -12),
            editButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        if plan.status != .active {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(deleteSwiped))
            swipe.direction = .left
            addGestureRecognizer(swipe)
        }

        // 「开关、行点击与左滑删除为独立区域」：整行的点击手势不能吃掉开关和「编辑」按钮上的触摸，
        // 否则拨开关会变成进编辑页。
        let tap = UITapGestureRecognizer(target: self, action: #selector(editTapped))
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let hit = touch.view else { return true }
        if hit === toggle || hit.isDescendant(of: toggle) { return false }
        if let editButton = editButtonRef, hit === editButton || hit.isDescendant(of: editButton) { return false }
        return true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func toggleChanged() { onToggle?() }
    @objc private func editTapped() { onTapEdit?() }
    @objc private func deleteSwiped() { onDelete?() }
}
