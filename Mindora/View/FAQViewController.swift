import UIKit
import SafariServices

/// 常见问题解答页（设计稿 dev/20260625/常见问题备份3）：
/// 返回箭头 + 顶部分隔线 → 大标题 → 简介 → 一张圆角卡片(手风琴式问答) → 底部说明文字。
class FAQViewController: UIViewController {

    // 设计稿取色（750px 宽 = 2x，÷2 得 pt）
    private let pageBg = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0)   // #181818
    private let cardBg = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0)   // #2C2C2C

    // 底部「帮助中心」入口：footerLabel 上点击落在 helpLinkRange 内即打开帮助中心。
    private let footerLabel = UILabel()
    private var helpLinkRange = NSRange(location: 0, length: 0)

    // (问题 key, 答案 key)，顺序即展示顺序。
    private let items: [(q: String, a: String)] = [
        ("faq.q1", "faq.a1"), ("faq.q2", "faq.a2"), ("faq.q3", "faq.a3"),
        ("faq.q4", "faq.a4"), ("faq.q5", "faq.a5"), ("faq.q6", "faq.a6"),
        ("faq.q7", "faq.a7"), ("faq.q8", "faq.a8"), ("faq.q9", "faq.a9"),
        ("faq.q10", "faq.a10"), ("faq.q11", "faq.a11")
    ]

    private let backButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton()
        button.setImage(UIImage(named: "sub_back"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let navSeparatorView: UIView = {
        let view = UIView()
        // 顶部分隔线：#E4E4E4 20%，0.5pt
        view.backgroundColor = UIColor(red: 228/255, green: 228/255, blue: 228/255, alpha: 0.2)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = .clear
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = pageBg
        setupUI()
        setupContent()
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(backButton)
        view.addSubview(navSeparatorView)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 24),
            backButton.heightAnchor.constraint(equalToConstant: 24),

            navSeparatorView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 13.5),
            navSeparatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navSeparatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navSeparatorView.heightAnchor.constraint(equalToConstant: 0.5),

            scrollView.topAnchor.constraint(equalTo: navSeparatorView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupContent() {
        // 大标题
        let titleLabel = UILabel()
        titleLabel.text = L("faq.title")
        titleLabel.font = UIFont(name: "PingFangSC-Medium", size: 18) ?? .systemFont(ofSize: 18, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // 简介
        let introLabel = UILabel()
        introLabel.text = L("faq.subtitle")
        introLabel.font = UIFont(name: "PingFangSC-Light", size: 12) ?? .systemFont(ofSize: 12, weight: .light)
        introLabel.textColor = UIColor(white: 1.0, alpha: 0.7)
        introLabel.numberOfLines = 0
        introLabel.setLineSpacing(6)
        introLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(introLabel)

        // 问答卡片
        let card = UIView()
        card.backgroundColor = cardBg
        card.layer.cornerRadius = 18
        card.layer.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        let rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = 0
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rowsStack)

        for (index, item) in items.enumerated() {
            let row = FAQItemView(question: L(item.q), answer: L(item.a))
            row.onToggle = { [weak self, weak row] expanded in
                guard let self = self, let row = row else { return }
                UIView.animate(withDuration: 0.25) {
                    row.applyChevron(expanded: expanded)
                    self.view.layoutIfNeeded()
                }
            }
            rowsStack.addArrangedSubview(row)
            if index < items.count - 1 {
                rowsStack.addArrangedSubview(makeDivider())
            }
        }

        // 底部说明：「如有其他问题，可前往Mindora官网 帮助中心 查看。」帮助中心加粗+下划线。
        footerLabel.numberOfLines = 0
        footerLabel.attributedText = makeFooterText()
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.isUserInteractionEnabled = true
        footerLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleFooterTap(_:))))
        contentView.addSubview(footerLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            introLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            introLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            introLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            card.topAnchor.constraint(equalTo: introLabel.bottomAnchor, constant: 28),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            rowsStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            rowsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            rowsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            rowsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            footerLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 24),
            footerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            footerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            footerLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    private func makeDivider() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let line = UIView()
        line.backgroundColor = UIColor(white: 1.0, alpha: 0.4)
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 0.5),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }

    private func makeFooterText() -> NSAttributedString {
        let light = UIFont(name: "PingFangSC-Light", size: 12) ?? .systemFont(ofSize: 12, weight: .light)
        let medium = UIFont(name: "PingFangSC-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: L("faq.footer.prefix"),
                                         attributes: [.font: light, .foregroundColor: UIColor.white]))
        let linkText = L("faq.footer.link")
        helpLinkRange = NSRange(location: result.length, length: (linkText as NSString).length)
        result.append(NSAttributedString(string: linkText,
                                         attributes: [.font: medium,
                                                      .foregroundColor: UIColor.white,
                                                      .underlineStyle: NSUnderlineStyle.single.rawValue]))
        result.append(NSAttributedString(string: L("faq.footer.suffix"),
                                         attributes: [.font: light, .foregroundColor: UIColor.white]))
        return result
    }

    /// 点击落在「帮助中心」字样范围内 → APP 内打开帮助中心（SFSafariViewController）。
    @objc private func handleFooterTap(_ gesture: UITapGestureRecognizer) {
        guard let attributed = footerLabel.attributedText else { return }
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: footerLabel.bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = footerLabel.lineBreakMode
        textContainer.maximumNumberOfLines = footerLabel.numberOfLines
        layoutManager.addTextContainer(textContainer)

        let location = gesture.location(in: footerLabel)
        let index = layoutManager.characterIndex(for: location, in: textContainer,
                                                 fractionOfDistanceBetweenInsertionPoints: nil)
        guard NSLocationInRange(index, helpLinkRange) else { return }
        guard let url = URL(string: Constants.Network.helpCenterURL) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    @objc private func handleBack() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
}

// MARK: - FAQ Item (accordion row)

private final class FAQItemView: UIView {

    private var isExpanded = false

    // 行内上下内边距：与改造前一致的紧凑高度（单行问题 ≈ 14+17+14 ≈ 45pt）。
    private let verticalPadding: CGFloat = 14

    private let questionLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        l.textColor = .white
        l.numberOfLines = 0
        // 让问题占满宽度、垂直方向贴合内容（不被拉高）。
        l.setContentHuggingPriority(.defaultHigh, for: .vertical)
        l.setContentCompressionResistancePriority(.required, for: .vertical)
        return l
    }()

    private let chevron: UIImageView = {
        let iv = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .light)
        iv.image = UIImage(systemName: "chevron.down", withConfiguration: cfg)
        iv.tintColor = .white
        iv.contentMode = .center
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        return iv
    }()

    private let answerLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.isHidden = true
        return l
    }()

    init(question: String, answer: String) {
        super.init(frame: .zero)
        setup(question: question, answer: answer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(question: String, answer: String) {
        questionLabel.text = question

        let ans = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 5
        answerLabel.attributedText = NSAttributedString(
            string: answer,
            attributes: [.font: ans,
                         .foregroundColor: UIColor(white: 1.0, alpha: 0.6),
                         .paragraphStyle: para]
        )

        // 标题行：问题(占满) + 箭头(14x14)，垂直居中。
        let header = UIStackView(arrangedSubviews: [questionLabel, chevron])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 12
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true
        chevron.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let inner = UIStackView(arrangedSubviews: [header, answerLabel])
        inner.axis = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(inner)

        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: topAnchor, constant: verticalPadding),
            inner.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -verticalPadding),
            inner.leadingAnchor.constraint(equalTo: leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        // 整行可点（点 header 区域触发展开/收起）。
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggle))
        header.isUserInteractionEnabled = true
        header.addGestureRecognizer(tap)
    }

    /// 展开/收起回调（参数为展开后状态）。由 VC 在回调里统一 animate 整个页面布局。
    var onToggle: ((Bool) -> Void)?

    func applyChevron(expanded: Bool) {
        chevron.transform = expanded ? CGAffineTransform(rotationAngle: .pi) : .identity
    }

    @objc private func toggle() {
        isExpanded.toggle()
        answerLabel.isHidden = !isExpanded
        onToggle?(isExpanded)
    }
}

private extension UILabel {
    func setLineSpacing(_ spacing: CGFloat) {
        guard let text = self.text else { return }
        let para = NSMutableParagraphStyle()
        para.lineSpacing = spacing
        attributedText = NSAttributedString(string: text, attributes: [
            .font: font as Any,
            .foregroundColor: textColor as Any,
            .paragraphStyle: para
        ])
    }
}
