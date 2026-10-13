//
//  ConfirmDialogView.swift
//  mindora
//
//  通用确认弹窗（居中卡片 + 全屏遮罩）。精确对齐设计稿 03h/03l/01.C2 等确认弹窗 CSS：
//  遮罩 rgba(0,0,0,0.6)；卡片 #2C2C2C 圆角18pt + 阴影；标题18pt Medium 左对齐；
//  正文11pt #CDCDCD；按钮为并排胶囊——左侧描边（次要）+ 右侧纯白实心（主要，黑字）；
//  单按钮变体（如"计划已满"）只保留一个纯白通栏胶囊按钮。
//  覆盖睡眠计划里的全部确认场景：切换执行计划 / 未保存离开 / 计划已满 / 高级会员功能升级提示。
//
import UIKit

final class ConfirmDialogView: UIView {

    private let dimView = UIView()
    private let cardView = UIView()
    private var onOutline: (() -> Void)?
    private var onSolid: (() -> Void)?

    /// 卡片纵向留白。默认对齐睡眠计划弹窗（80px/66px/80px）；
    /// 仅标题无正文的删除设备确认弹窗（设备页/首页 box_4、box_29）是 120px/100px/92px。
    struct Spacing {
        let top: CGFloat
        let titleToButtons: CGFloat
        let bottom: CGFloat
        static let standard = Spacing(top: 40, titleToButtons: 33, bottom: 40)
        static let titleOnly = Spacing(top: 60, titleToButtons: 50, bottom: 46)
    }

    private init() {
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 双按钮确认弹窗。`outlineTitle` 为描边按钮（左），`solidTitle` 为纯白实心按钮（右，视觉主按钮）。
    @discardableResult
    static func present(title: String, message: String,
                         outlineTitle: String, solidTitle: String,
                         spacing: Spacing = .standard,
                         singleLineTitle: Bool = false,
                         onOutline: (() -> Void)? = nil, onSolid: (() -> Void)? = nil) -> ConfirmDialogView? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return nil }

        let view = ConfirmDialogView()
        view.onOutline = onOutline
        view.onSolid = onSolid
        view.build(title: title, message: message, outlineTitle: outlineTitle, solidTitle: solidTitle, spacing: spacing,
                   singleLineTitleWidth: singleLineTitle ? min(335, window.bounds.width - 80) - 60 : nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: window.topAnchor),
            view.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: window.bottomAnchor)
        ])
        view.animateIn()
        return view
    }

    /// 单按钮变体（如「睡眠计划已满」，只保留一个纯白通栏按钮）。
    static func presentSingleAction(title: String, message: String, actionTitle: String, onAction: (() -> Void)? = nil) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
        let view = ConfirmDialogView()
        view.onSolid = onAction
        view.build(title: title, message: message, outlineTitle: nil, solidTitle: actionTitle)
        view.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: window.topAnchor),
            view.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: window.bottomAnchor)
        ])
        view.animateIn()
    }

    private func build(title: String, message: String, outlineTitle: String?, solidTitle: String,
                       spacing: Spacing = .standard, singleLineTitleWidth: CGFloat? = nil) {
        dimView.backgroundColor = SleepPlanTheme.dialogOverlay
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // .section_6 / .box_26: #2C2C2C, radius 36px(18pt), shadow 0 0 16px rgba(0,0,0,.25),
        // padding 80px 60px 80px 60px (40pt/30pt/40pt/30pt).
        cardView.backgroundColor = SleepPlanTheme.cardBackground
        cardView.layer.cornerRadius = SleepPlanTheme.dialogCornerRadius
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.25
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOffset = .zero
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
            cardView.widthAnchor.constraint(equalToConstant: 335) // .box_41 width 670px → 335pt
        ])

        // .text_26: 白色 18pt Medium 左对齐
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = SleepPlanTheme.fontMedium(SleepPlanTheme.fontSizeCardTitle)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        if let width = singleLineTitleWidth {
            fitTitleOnOneLine(titleLabel, width: width)
        }

        // .text_27: #CDCDCD 11pt
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeDialogMessage)
        messageLabel.textColor = SleepPlanTheme.dialogMessage
        messageLabel.numberOfLines = 0
        messageLabel.isHidden = message.isEmpty

        let textStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        textStack.axis = .vertical
        textStack.spacing = 13 // 26px → 13pt
        textStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(textStack)

        let buttonRow: UIView
        if let outlineTitle {
            let outlineButton = pillButton(title: outlineTitle, solid: false)
            outlineButton.addTarget(self, action: #selector(handleOutline), for: .touchUpInside)
            let solidButton = pillButton(title: solidTitle, solid: true)
            solidButton.addTarget(self, action: #selector(handleSolid), for: .touchUpInside)
            let row = UIStackView(arrangedSubviews: [outlineButton, solidButton])
            row.axis = .horizontal
            row.spacing = 12
            row.distribution = .fillEqually
            buttonRow = row
        } else {
            let solidButton = pillButton(title: solidTitle, solid: true)
            solidButton.addTarget(self, action: #selector(handleSolid), for: .touchUpInside)
            buttonRow = solidButton
        }
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: spacing.top),
            textStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 30),
            textStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -30),

            buttonRow.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: spacing.titleToButtons), // ~66px
            buttonRow.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 30),
            buttonRow.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -30),
            buttonRow.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -spacing.bottom),
            buttonRow.heightAnchor.constraint(equalToConstant: 40),
            // .text-wrapper_7/_8: 文字 24px + padding 27~28px×2 → 78/80px ≈ 40pt
        ])
    }

    /// 标题尽量排成一行（删除设备弹窗设计稿 white-space: nowrap）：从 18pt 每次减 0.5 缩到 14pt；
    /// 仍放不下（超长昵称）才换行，并关掉系统的整词下推断行——否则英文会把引号里的设备名整段
    /// 推到第二行，出现「Delete device」独占一行的怪异排版。
    private func fitTitleOnOneLine(_ label: UILabel, width: CGFloat) {
        let text = (label.text ?? "") as NSString
        var size = SleepPlanTheme.fontSizeCardTitle
        let minSize: CGFloat = 14
        while size > minSize,
              text.size(withAttributes: [.font: SleepPlanTheme.fontMedium(size)]).width > width {
            size -= 0.5
        }
        label.font = SleepPlanTheme.fontMedium(size)
        label.lineBreakStrategy = []
    }

    /// .text-wrapper_7（描边，次要）/ .text-wrapper_8（纯白实心，主按钮）：radius 60px(30pt)。
    private func pillButton(title: String, solid: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = SleepPlanTheme.fontRegular(SleepPlanTheme.fontSizeOptionValue)
        button.layer.cornerRadius = SleepPlanTheme.dialogButtonCornerRadius
        if solid {
            button.backgroundColor = .white
            button.setTitleColor(.black, for: .normal)
        } else {
            button.backgroundColor = SleepPlanTheme.cardBackground
            button.setTitleColor(.white, for: .normal)
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.white.cgColor
        }
        return button
    }

    @objc private func handleOutline() { dismiss { self.onOutline?() } }
    @objc private func handleSolid() { dismiss { self.onSolid?() } }

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
}
