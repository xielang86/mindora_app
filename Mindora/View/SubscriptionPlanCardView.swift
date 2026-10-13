//
//  SubscriptionPlanCardView.swift
//  mindora
//
//  会员订阅卡（dev/20260818_订阅及背景色）：等级分段器（普通会员 / AI 高级会员）+ 月度/年度
//  两张付费周期卡 + 该等级的四条权益 + 一个订阅按钮。等级和周期都是卡内切换，切换只换配色与
//  文案，不重建整页。
//
//  ⚠️ 尺寸/配色全部来自设计稿 CSS（html/lanhu_dingyue{putong,aigaoji}huiyuan/index.css），
//  设计稿是 750px 宽的 2 倍图，所以下面的 pt 值 = CSS px ÷ 2。文字透明度是量设计图像素定的：
//  CSS 里所有文案都写成 rgba(255,255,255,1)，但实际渲染出来次级文案峰值只有 171（≈0.6），
//  以像素为准。
//

import UIKit

// MARK: - 等级配色

/// 一个会员等级的整套视觉参数。两个等级只有配色和文案不同，结构完全一样。
private struct TierStyle {

    let gradientStart: UIColor      // 渐变左端（CSS 302deg/146deg 的起始色在左上）
    let gradientEnd: UIColor        // 渐变右端
    let accent: UIColor             // 选中周期卡的填充基色（叠 6% 透明度）
    let ctaTextColor: UIColor       // 订阅按钮文字色
    let tabTextColor: UIColor       // 选中态分段器文字色
    let iconPrefix: String
    let benefitKeyPrefix: String

    static let basic = TierStyle(
        gradientStart: UIColor(red: 166/255, green: 118/255, blue: 255/255, alpha: 1),  // #A676FF
        gradientEnd:   UIColor(red: 173/255, green: 110/255, blue: 223/255, alpha: 1),  // #AD6EDF
        accent:        UIColor(red: 173/255, green: 110/255, blue: 224/255, alpha: 1),
        ctaTextColor: .white,
        tabTextColor: .white,
        iconPrefix: "sub_benefit_basic_",
        benefitKeyPrefix: "subscription.benefit.basic."
    )

    static let premium = TierStyle(
        gradientStart: UIColor(red: 253/255, green: 200/255, blue: 171/255, alpha: 1),  // #FDC8AB
        gradientEnd:   UIColor(red: 254/255, green: 231/255, blue: 172/255, alpha: 1),  // #FEE7AC
        accent:        UIColor(red: 254/255, green: 226/255, blue: 172/255, alpha: 1),
        // 金色底上必须用深色字，设计稿写的是 rgba(44,44,44,1)
        ctaTextColor: UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1),
        tabTextColor: UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1),
        iconPrefix: "sub_benefit_premium_",
        benefitKeyPrefix: "subscription.benefit.premium."
    )

    static func of(_ tier: MembershipTier) -> TierStyle { tier == .premium ? .premium : .basic }
}

private enum SubColor {
    static let card = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1)      // #2C2C2C
    static let periodIdle = UIColor(red: 55/255, green: 55/255, blue: 55/255, alpha: 1) // #373737
    /// 未选中周期卡的描边。CSS 写的是 0.6，但设计图上那根线实测只有 0.3 —— 以像素为准，
    /// 用 0.6 会明显比设计稿抢眼。
    static let periodIdleBorder = UIColor(white: 1, alpha: 0.3)
    static let secondaryText = UIColor(white: 1, alpha: 0.6)
}

// MARK: - 渐变描边容器

/// 圆角渐变描边 + 纯色填充。选中态的周期卡用它——设计稿那圈边是渐变的（顶部 #A676FF、
/// 左侧已经过渡到 #A97AEE），用单色描边会看出来。
private final class GradientBorderView: UIView {

    private let gradient = CAGradientLayer()
    private let borderMask = CAShapeLayer()
    private let lineWidth: CGFloat
    private let radius: CGFloat

    init(colors: [UIColor], lineWidth: CGFloat, radius: CGFloat, fill: UIColor) {
        self.lineWidth = lineWidth
        self.radius = radius
        super.init(frame: .zero)
        backgroundColor = fill
        layer.cornerRadius = radius
        gradient.colors = colors.map { $0.cgColor }
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        borderMask.fillColor = UIColor.clear.cgColor
        borderMask.strokeColor = UIColor.black.cgColor
        borderMask.lineWidth = lineWidth
        gradient.mask = borderMask
        layer.addSublayer(gradient)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        borderMask.frame = bounds
        // 描边是画在路径上的，一半在外一半在内 —— 内缩半个线宽才不会被 cornerRadius 切掉。
        borderMask.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2),
            cornerRadius: radius - lineWidth / 2
        ).cgPath
        CATransaction.commit()
    }
}

/// 纯渐变填充的圆角块（分段器选中丸子、订阅按钮）。
private final class GradientView: UIView {

    private let gradient = CAGradientLayer()

    init(radius: CGFloat) {
        super.init(frame: .zero)
        layer.cornerRadius = radius
        layer.masksToBounds = true
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(_ colors: [UIColor]) {
        gradient.colors = colors.map { $0.cgColor }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
    }
}

/// 周期卡里那根虚线。设计稿：宽 261px(130.5pt)、4/4 虚线、白 60%。
private final class DashedLineView: UIView {

    private let shape = CAShapeLayer()

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        shape.strokeColor = SubColor.secondaryText.cgColor
        shape.lineWidth = 0.5
        shape.lineDashPattern = [2, 2]   // CSS 4,4 是 2 倍图
        layer.addSublayer(shape)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.midY))
        shape.path = path.cgPath
        shape.frame = bounds
    }
}

// MARK: - 会员订阅卡

final class SubscriptionPlanCardView: UIView {

    /// 用户点了订阅按钮。参数是当前选中的等级与周期。
    private let onPurchase: (MembershipTier, SubscriptionType) -> Void
    /// 已付费拥有的等级。选中它时按钮变成不可点的「当前套餐」。
    /// StoreKit 权益/服务端授予都是异步到的，到了要能更新 —— 但只更新这一项，
    /// **绝不重摆选中的档位**，见 update(paidTier:)。
    private var paidTier: MembershipTier

    private var selectedTier: MembershipTier
    private var selectedPeriod: SubscriptionType = .monthly

    // 分段器
    private let tabPill = GradientView(radius: 13)
    private let basicTabLabel = UILabel()
    private let premiumTabLabel = UILabel()
    private var pillLeadingToBasic: NSLayoutConstraint!
    private var pillLeadingToPremium: NSLayoutConstraint!

    // 周期卡
    private var monthlyCard: PeriodCardView!
    private var yearlyCard: PeriodCardView!

    // 权益区 / 按钮
    private let benefitsStack = UIStackView()
    private let ctaButton = UIButton(type: .custom)
    private let ctaGradient = GradientView(radius: 20)

    // 已订阅时显示：当前套餐 + 续费日 +（若有）已排期的变更 + 管理订阅入口
    private let statusLabel = UILabel()
    private let manageButton = UIButton(type: .system)
    private var statusRow: UIView!

    /// - Parameters:
    ///   - paidTier: 真金白银买到的等级，**必须是已确认的值**，只用来决定「当前套餐」那套不可点态。
    ///   - initialTier: 摆初始默认停在哪一档。StoreKit 权益解析完成前 `paidTier` 只能是 `.free`
    ///     （见 SubscriptionManager.lastKnownPaidTier 的注释），此时由调用方传上次已知的等级进来，
    ///     卡片才不会先按非会员摆好、解析完成重建时再当着用户的面跳一下。
    ///   - initialYearly: 同理，初始高亮哪张周期卡。
    /// 上一次渲染时「当前生效的产品」，用来分辨「状态真的变了」和「只是又广播了一次刷新」。
    private var renderedActiveProductID: String? = nil

    init(paidTier: MembershipTier,
         initialTier: MembershipTier,
         initialYearly: Bool,
         onPurchase: @escaping (MembershipTier, SubscriptionType) -> Void) {
        self.paidTier = paidTier
        switch initialTier {
        // 普通会员进来默认停在「AI 高级会员」页 —— 他要看的是能升到什么，不是自己已经买过的那档。
        case .basic:   self.selectedTier = .premium
        // 已是最高档，默认停在自己这档，看到的是当前套餐与续费信息。
        case .premium: self.selectedTier = .premium
        case .free:    self.selectedTier = .basic
        }
        // 已订阅的人默认落在自己当前的周期上，否则「当前套餐」标记会落到他没买的那张卡上。
        if initialTier != .free {
            self.selectedPeriod = initialYearly ? .yearly : .monthly
        }
        self.onPurchase = onPurchase
        super.init(frame: .zero)
        setup()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: 构建

    private func setup() {
        backgroundColor = SubColor.card
        layer.cornerRadius = 18
        translatesAutoresizingMaskIntoConstraints = false

        let tabs = buildTabs()
        let periods = buildPeriodRow()
        let exclusiveLabel = UILabel()
        exclusiveLabel.text = L("subscription.exclusive")
        exclusiveLabel.font = UIFont(name: "PingFangSC-Regular", size: 14)
        exclusiveLabel.textColor = .white
        exclusiveLabel.translatesAutoresizingMaskIntoConstraints = false

        benefitsStack.axis = .vertical
        benefitsStack.spacing = 16
        benefitsStack.translatesAutoresizingMaskIntoConstraints = false

        let cta = buildCTA()
        statusRow = buildStatusRow()

        let footnote = UILabel()
        footnote.text = L("subscription.plan.footnote")
        footnote.font = UIFont(name: "PingFangSC-Regular", size: 9)
        footnote.textColor = SubColor.secondaryText
        footnote.numberOfLines = 0
        footnote.textAlignment = .center
        footnote.translatesAutoresizingMaskIntoConstraints = false

        [tabs, periods, exclusiveLabel, benefitsStack, cta, statusRow, footnote].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            // 分段器只内缩 6pt（CSS padding 12px），比下面的内容区窄一档，是设计稿的样子
            tabs.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            tabs.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            tabs.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            tabs.heightAnchor.constraint(equalToConstant: 41),

            periods.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 24),
            periods.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            periods.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            exclusiveLabel.topAnchor.constraint(equalTo: periods.bottomAnchor, constant: 30),
            exclusiveLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            benefitsStack.topAnchor.constraint(equalTo: exclusiveLabel.bottomAnchor, constant: 14),
            benefitsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            benefitsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            cta.topAnchor.constraint(equalTo: benefitsStack.bottomAnchor, constant: 36),
            cta.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            cta.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            cta.heightAnchor.constraint(equalToConstant: 40),

            statusRow.topAnchor.constraint(equalTo: cta.bottomAnchor, constant: 14),
            statusRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statusRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            footnote.topAnchor.constraint(equalTo: statusRow.bottomAnchor, constant: 14),
            footnote.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            footnote.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            footnote.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -30)
        ])
    }

    private func buildTabs() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        tabPill.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tabPill)

        for (label, key) in [(basicTabLabel, "subscription.plan.tier.basic"),
                             (premiumTabLabel, "subscription.plan.tier.premium")] {
            label.text = L(key)
            label.font = UIFont(name: "PingFangSC-Regular", size: 12)
            label.textColor = .white
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
        }

        let basicTap = UIView(); let premiumTap = UIView()
        [basicTap, premiumTap].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.backgroundColor = .clear
            container.addSubview($0)
        }
        basicTap.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectBasicTier)))
        premiumTap.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectPremiumTier)))

        // 丸子宽度 = 容器一半，靠约束在左右两半之间切，切换时能直接做动画
        pillLeadingToBasic = tabPill.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        pillLeadingToPremium = tabPill.leadingAnchor.constraint(equalTo: container.centerXAnchor)

        NSLayoutConstraint.activate([
            tabPill.topAnchor.constraint(equalTo: container.topAnchor),
            tabPill.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            tabPill.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.5),

            basicTabLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            basicTabLabel.trailingAnchor.constraint(equalTo: container.centerXAnchor),
            basicTabLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            premiumTabLabel.leadingAnchor.constraint(equalTo: container.centerXAnchor),
            premiumTabLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            premiumTabLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            basicTap.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            basicTap.trailingAnchor.constraint(equalTo: container.centerXAnchor),
            basicTap.topAnchor.constraint(equalTo: container.topAnchor),
            basicTap.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            premiumTap.leadingAnchor.constraint(equalTo: container.centerXAnchor),
            premiumTap.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            premiumTap.topAnchor.constraint(equalTo: container.topAnchor),
            premiumTap.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func buildPeriodRow() -> UIView {
        monthlyCard = PeriodCardView(period: .monthly)
        yearlyCard = PeriodCardView(period: .yearly)
        monthlyCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectMonthly)))
        yearlyCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectYearly)))

        let row = UIStackView(arrangedSubviews: [monthlyCard, yearlyCard])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 17
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func buildCTA() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        ctaGradient.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 14)
        ctaButton.addTarget(self, action: #selector(handleCTA), for: .touchUpInside)
        container.addSubview(ctaGradient)
        container.addSubview(ctaButton)
        NSLayoutConstraint.activate([
            ctaGradient.topAnchor.constraint(equalTo: container.topAnchor),
            ctaGradient.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            ctaGradient.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ctaGradient.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ctaButton.topAnchor.constraint(equalTo: container.topAnchor),
            ctaButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            ctaButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ctaButton.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    /// 当前套餐信息行。未订阅时整行高度归零（`isHidden` 对非 stack 的子视图不影响约束，
    /// 所以这里靠 heightAnchor 显式压平，否则会留出一段空白）。
    private func buildStatusRow() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = UIFont(name: "PingFangSC-Regular", size: 9)
        statusLabel.textColor = SubColor.secondaryText
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        manageButton.setTitle(L("subscription.plan.manage"), for: .normal)
        manageButton.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 9)
        manageButton.translatesAutoresizingMaskIntoConstraints = false
        manageButton.addTarget(self, action: #selector(handleManage), for: .touchUpInside)
        // 文字按钮容易点不中，横向撑一点热区
        manageButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        container.addSubview(statusLabel)
        container.addSubview(manageButton)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: container.topAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: manageButton.leadingAnchor, constant: -10),
            manageButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            manageButton.topAnchor.constraint(equalTo: container.topAnchor)
        ])
        return container
    }

    @objc private func handleManage() {
        SubscriptionManager.shared.openSubscriptionManagement()
    }

    // MARK: 交互

    @objc private func selectBasicTier() { select(tier: .basic) }
    @objc private func selectPremiumTier() { select(tier: .premium) }
    @objc private func selectMonthly() { select(period: .monthly) }
    @objc private func selectYearly() { select(period: .yearly) }

    /// 订阅状态异步到了之后刷新卡片：价格、「当前套餐」不可点态、续费信息都跟着变，
    /// **但选中的等级/周期一律不动**。
    ///
    /// 卡上那个丸子只能由用户的手指挪 —— 页面在屏幕上之后自己挪一下，就是用户报的
    /// 「第一次进订阅页，普通会员和 AI 高级会员之间自己跳一下」。订阅状态是分好几路
    /// 异步到的（StoreKit 权益解析、服务端资料里的兑换/赠送会员、体验期），每到一路都会
    /// 广播一次刷新，只要刷新时重新按当时的状态摆一遍默认档位，就可能当着用户的面挪。
    /// 页面刷新时把最新的订阅状态喂进来。
    /// 档位没变也要重画：升档 / 换周期时 paidTier 仍是 premium，变的是「当前生效的产品」，
    /// 早先在这里提前 return，结果买完年付后按钮和到期日纹丝不动（用户看到的就是「点了没反应」）。
    func update(paidTier: MembershipTier) {
        let active = SubscriptionManager.shared.activeProductID
        let activeChanged = active != renderedActiveProductID
        let tierChanged = paidTier != self.paidTier
        self.paidTier = paidTier
        // 生效产品变了 = 刚买成 / 换档落地这类新事实，把丸子挪到它上面；用户自己拨的选择不受影响
        //（renderedActiveProductID 没变就不动，所以不会跟用户的手指抢）。
        if activeChanged, let active, let plan = Self.plan(of: active) {
            selectedTier = plan.tier
            selectedPeriod = plan.period
        }
        renderedActiveProductID = active
        guard activeChanged || tierChanged else { return }
        refresh()
        UIView.animate(withDuration: 0.22) { self.layoutIfNeeded() }
    }

    private func select(tier: MembershipTier) {
        guard tier != selectedTier else { return }
        selectedTier = tier
        refresh()
        UIView.animate(withDuration: 0.22) { self.layoutIfNeeded() }
    }

    private func select(period: SubscriptionType) {
        guard period != selectedPeriod else { return }
        selectedPeriod = period
        refresh()
    }

    @objc private func handleCTA() {
        guard ctaButton.isEnabled else { return }   // 「当前套餐」/「已排期」不可点
        ctaButton.animateButtonTap { [weak self] in
            guard let self else { return }
            self.onPurchase(self.selectedTier, self.selectedPeriod)
        }
    }

    // MARK: 刷新

    private func refresh() {
        let style = TierStyle.of(selectedTier)
        let colors = [style.gradientStart, style.gradientEnd]

        // 分段器
        tabPill.apply(colors)
        pillLeadingToBasic.isActive = (selectedTier == .basic)
        pillLeadingToPremium.isActive = (selectedTier == .premium)
        basicTabLabel.font = UIFont(name: selectedTier == .basic ? "PingFangSC-Medium" : "PingFangSC-Regular", size: 12)
        premiumTabLabel.font = UIFont(name: selectedTier == .premium ? "PingFangSC-Medium" : "PingFangSC-Regular", size: 12)
        basicTabLabel.textColor = selectedTier == .basic ? style.tabTextColor : .white
        premiumTabLabel.textColor = selectedTier == .premium ? style.tabTextColor : .white

        // 周期卡
        let monthlyPrice = Self.price(tier: selectedTier, period: .monthly)
        let yearlyPrice = Self.price(tier: selectedTier, period: .yearly)
        monthlyCard.update(priceText: monthlyPrice + L("subscription.price.monthly"),
                           selected: selectedPeriod == .monthly, style: style)
        yearlyCard.update(priceText: yearlyPrice + L("subscription.price.yearly"),
                          selected: selectedPeriod == .yearly, style: style)

        // 权益
        benefitsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for i in 1...4 {
            benefitsStack.addArrangedSubview(BenefitRowView(
                icon: UIImage(named: "\(style.iconPrefix)\(i)"),
                title: L("\(style.benefitKeyPrefix)\(i).title"),
                desc: L("\(style.benefitKeyPrefix)\(i).desc")
            ))
        }

        // 订阅按钮
        ctaGradient.apply(colors)
        ctaButton.setTitleColor(style.ctaTextColor, for: .normal)
        manageButton.setTitleColor(style.gradientEnd, for: .normal)

        let priceText = selectedPeriod == .monthly
            ? monthlyPrice + L("subscription.price.monthly")
            : yearlyPrice + L("subscription.price.yearly")
        let periodName = L(selectedPeriod == .yearly ? "subscription.yearly" : "subscription.monthly")

        let manager = SubscriptionManager.shared
        let selectedID = Self.productID(tier: selectedTier, period: selectedPeriod)
        let activeID = manager.activeProductID
        let pendingID = manager.pendingRenewalProductID

        let title: String
        var enabled = true
        if selectedID == activeID {
            // 正在生效的就是这一档
            title = L("subscription.plan.current")
            enabled = false
        } else if selectedID == pendingID {
            // 已经切过来了，只是要等当前订阅走完
            title = L("subscription.plan.cta.scheduled")
            enabled = false
        } else if activeID == nil && paidTier != .free {
            // 兑换码 / 后台赠送的会员：没有店内订阅可「切换」。同档或更低档就是当前套餐，不能再买一份
            // （真机实测：兑换码 Premium 到 2027 年，按钮却显示「切换为年付」还能点）；只有更高档才是升级。
            if Self.rank(selectedTier) <= Self.rank(paidTier) {
                title = L("subscription.plan.current")
                enabled = false
            } else {
                title = String(format: L("subscription.plan.cta.upgrade"), priceText)
            }
        } else if paidTier == .free {
            let key = selectedTier == .premium ? "subscription.plan.cta.premium" : "subscription.plan.cta.basic"
            title = String(format: L(key), priceText)
        } else if selectedTier == paidTier {
            // 同档换时长：同级 crossgrade，下个续费日生效
            title = String(format: L("subscription.plan.cta.switch"), periodName)
        } else if selectedTier == .premium {
            // 升级：跨级，立即生效并按比例折抵未用完的时间
            title = String(format: L("subscription.plan.cta.upgrade"), priceText)
        } else {
            // 降级：下个续费日生效
            title = String(format: L("subscription.plan.cta.downgrade"), priceText)
        }
        ctaButton.setTitle(title, for: .normal)
        ctaButton.isEnabled = enabled
        ctaGradient.alpha = enabled ? 1 : 0.4

        refreshStatusRow()
    }

    /// 当前套餐 / 续费日 / 已排期变更。未订阅时整行压平。
    private func refreshStatusRow() {
        let manager = SubscriptionManager.shared
        guard manager.paidMembershipTier != .free else {
            statusRow.isHidden = true
            statusLabel.text = nil
            return
        }
        statusRow.isHidden = false
        guard let activeID = manager.activeProductID else {
            // 兑换码 / 赠送会员：档位 + 来源 + 到期日（到期日来自服务端授予记录）
            statusLabel.text = [
                String(format: L("subscription.plan.status.current"),
                       L(manager.paidMembershipTier == .premium ? "subscription.plan.tier.premium"
                                                                : "subscription.plan.tier.basic"),
                       L("subscription.plan.period.redeemed")),
                String(format: L("subscription.plan.status.expire"), manager.expiryDisplayText()),
            ].joined(separator: "\n")
            return
        }

        var lines: [String] = []
        lines.append(String(format: L("subscription.plan.status.current"),
                            L(manager.paidMembershipTier == .premium ? "subscription.plan.tier.premium"
                                                                     : "subscription.plan.tier.basic"),
                            Self.periodName(of: activeID)))

        let dateStr = manager.expiryDisplayText()
        // 会自动续费 → 那天扣款；已取消 → 那天到期。两种说法不能混，用户看的就是这一行。
        lines.append(String(format: L(manager.willAutoRenew ? "subscription.plan.status.renew"
                                                            : "subscription.plan.status.expire"), dateStr))

        if let pendingID = manager.pendingRenewalProductID {
            lines.append(String(format: L("subscription.plan.status.pending"),
                                Self.displayName(of: pendingID), dateStr))
        }
        statusLabel.text = lines.joined(separator: "\n")
    }

    private static func rank(_ tier: MembershipTier) -> Int {
        switch tier { case .free: return 0; case .basic: return 1; case .premium: return 2 }
    }

    /// 产品 ID → (档位, 周期)。非订阅产品返回 nil。
    private static func plan(of productID: String) -> (tier: MembershipTier, period: SubscriptionType)? {
        switch productID {
        case Constants.Subscription.premiumYearlyProductID:  return (.premium, .yearly)
        case Constants.Subscription.premiumMonthlyProductID: return (.premium, .monthly)
        case Constants.Subscription.yearlyProductID:         return (.basic, .yearly)
        case Constants.Subscription.monthlyProductID:        return (.basic, .monthly)
        default: return nil
        }
    }

    private static func productID(tier: MembershipTier, period: SubscriptionType) -> String {
        let isYearly = (period == .yearly)
        if tier == .premium {
            return isYearly ? Constants.Subscription.premiumYearlyProductID
                            : Constants.Subscription.premiumMonthlyProductID
        }
        return isYearly ? Constants.Subscription.yearlyProductID : Constants.Subscription.monthlyProductID
    }

    private static func periodName(of productID: String) -> String {
        let isYearly = productID == Constants.Subscription.yearlyProductID
            || productID == Constants.Subscription.premiumYearlyProductID
        return L(isYearly ? "subscription.yearly" : "subscription.monthly")
    }

    private static func displayName(of productID: String) -> String {
        let isPremium = productID == Constants.Subscription.premiumYearlyProductID
            || productID == Constants.Subscription.premiumMonthlyProductID
        return L(isPremium ? "subscription.plan.tier.premium" : "subscription.plan.tier.basic")
            + " · " + periodName(of: productID)
    }

    /// 取 StoreKit 拉回来的本地化价格；拉不到（无网/审核中）就退回 Constants 里的兜底字符串。
    private static func price(tier: MembershipTier, period: SubscriptionType) -> String {
        // SubscriptionType 还有个 .free，但卡里只会取到 .monthly / .yearly，
        // 非 .yearly 一律按月度处理。
        let isYearly = (period == .yearly)
        let (id, fallback): (String, String)
        if tier == .premium {
            id = isYearly ? Constants.Subscription.premiumYearlyProductID : Constants.Subscription.premiumMonthlyProductID
            fallback = isYearly ? Constants.Subscription.premiumYearlyPrice : Constants.Subscription.premiumMonthlyPrice
        } else {
            id = isYearly ? Constants.Subscription.yearlyProductID : Constants.Subscription.monthlyProductID
            fallback = isYearly ? Constants.Subscription.yearlyPrice : Constants.Subscription.monthlyPrice
        }
        return SubscriptionManager.shared.products.first(where: { $0.id == id })?.displayPrice ?? fallback
    }
}

// MARK: - 付费周期卡

private final class PeriodCardView: UIView {

    private let period: SubscriptionType
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let noteLabel = UILabel()
    private let tagLabel = UILabel()
    private let dash = DashedLineView()
    private var borderView: GradientBorderView?

    init(period: SubscriptionType) {
        self.period = period
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 18

        titleLabel.text = L(period == .monthly ? "subscription.monthly" : "subscription.yearly")
        titleLabel.font = UIFont(name: "PingFangSC-Regular", size: 12)
        titleLabel.textColor = .white

        priceLabel.font = UIFont(name: "PingFangSC-Semibold", size: 16)
        priceLabel.textColor = .white
        priceLabel.adjustsFontSizeToFitWidth = true
        priceLabel.minimumScaleFactor = 0.7

        noteLabel.text = L(period == .monthly ? "subscription.plan.monthly.note" : "subscription.plan.yearly.note")
        noteLabel.font = UIFont(name: "PingFangSC-Regular", size: 9)
        noteLabel.textColor = SubColor.secondaryText
        // 英文 "Renews monthly. Cancel anytime." 在窄屏卡片里差几个点宽，略缩字号而不是截断。
        noteLabel.adjustsFontSizeToFitWidth = true
        noteLabel.minimumScaleFactor = 0.8

        tagLabel.text = L(period == .monthly ? "subscription.plan.monthly.tag" : "subscription.plan.yearly.tag")
        tagLabel.font = UIFont(name: "PingFangSC-Regular", size: 9)
        tagLabel.textColor = SubColor.secondaryText

        [titleLabel, priceLabel, noteLabel, tagLabel, dash].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        // 文案内缩 12pt、虚线只内缩 6pt —— 设计稿就是这么错开的（CSS 里文字多一层
        // margin-left:12px，虚线没有），不是笔误。
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),

            priceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            priceLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            priceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            noteLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 3),
            noteLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            noteLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),

            dash.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 9),
            dash.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            dash.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            dash.heightAnchor.constraint(equalToConstant: 1),

            tagLabel.topAnchor.constraint(equalTo: dash.bottomAnchor, constant: 8),
            tagLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            tagLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            tagLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(priceText: String, selected: Bool, style: TierStyle) {
        priceLabel.text = priceText

        borderView?.removeFromSuperview()
        borderView = nil

        if selected {
            backgroundColor = .clear
            layer.borderWidth = 0
            // 6% 的 accent 叠在 #2C2C2C 卡底上，等于设计稿量到的 (51,48,54)
            let border = GradientBorderView(colors: [style.gradientStart, style.gradientEnd],
                                            lineWidth: 1, radius: 18,
                                            fill: style.accent.withAlphaComponent(0.06))
            border.translatesAutoresizingMaskIntoConstraints = false
            border.isUserInteractionEnabled = false
            insertSubview(border, at: 0)
            NSLayoutConstraint.activate([
                border.topAnchor.constraint(equalTo: topAnchor),
                border.leadingAnchor.constraint(equalTo: leadingAnchor),
                border.trailingAnchor.constraint(equalTo: trailingAnchor),
                border.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            borderView = border
        } else {
            backgroundColor = SubColor.periodIdle
            layer.borderWidth = 0.5
            layer.borderColor = SubColor.periodIdleBorder.cgColor
        }
    }
}

// MARK: - 权益行

private final class BenefitRowView: UIView {

    init(icon: UIImage?, title: String, desc: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: icon)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont(name: "PingFangSC-Medium", size: 12)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = UILabel()
        descLabel.text = desc
        descLabel.font = UIFont(name: "PingFangSC-Regular", size: 9)
        descLabel.textColor = SubColor.secondaryText
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(descLabel)

        NSLayoutConstraint.activate([
            // 图标顶对齐（不是居中）：描述换行时图标要留在第一行边上
            iconView.topAnchor.constraint(equalTo: topAnchor),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 21),
            iconView.heightAnchor.constraint(equalToConstant: 21),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 13),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            descLabel.bottomAnchor.constraint(equalTo: bottomAnchor),

            heightAnchor.constraint(greaterThanOrEqualTo: iconView.heightAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
