//
//  HomePopupView.swift
//  mindora
//
//  首页弹窗卡片（参与调研 / 商城活动 / 纯广告）。服务端下发内容，本地按 HomePopup 渲染。
//  以全屏遮罩 + 居中卡片的形式呈现在当前窗口之上。
//

import UIKit

final class HomePopupView: UIView {

    private let popup: HomePopup
    private let onAction: (HomePopup) -> Void
    private let onClose: (HomePopup) -> Void

    private let dimView = UIView()
    private let cardView = UIView()

    // MARK: - Init

    init(popup: HomePopup,
         onAction: @escaping (HomePopup) -> Void,
         onClose: @escaping (HomePopup) -> Void) {
        self.popup = popup
        self.onAction = onAction
        self.onClose = onClose
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Present / Dismiss

    /// 呈现到当前 key window 顶层。
    @discardableResult
    static func present(popup: HomePopup,
                        onAction: @escaping (HomePopup) -> Void,
                        onClose: @escaping (HomePopup) -> Void) -> HomePopupView? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return nil }

        let view = HomePopupView(popup: popup, onAction: onAction, onClose: onClose)
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

    private func animateIn() {
        dimView.alpha = 0
        cardView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        cardView.alpha = 0
        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: [.curveEaseOut]) {
            self.dimView.alpha = 1
            self.cardView.transform = .identity
            self.cardView.alpha = 1
        }
    }

    private func dismiss(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.22, animations: {
            self.dimView.alpha = 0
            self.cardView.alpha = 0
            self.cardView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            self.removeFromSuperview()
            completion?()
        })
    }

    // MARK: - Setup

    private func setup() {
        // 遮罩
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)

        // 卡片
        cardView.backgroundColor = UIColor(red: 32/255, green: 32/255, blue: 34/255, alpha: 1.0)
        cardView.layer.cornerRadius = 18
        cardView.clipsToBounds = true
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        // 关闭按钮（对齐设计稿：实心中灰圆 + 白色叉）
        let closeButton = UIButton(type: .system)
        // 叉号约占圆直径 30%（实测设计稿），22pt 圆 → 约 7pt。
        closeButton.setImage(UIImage(systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .regular)), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor(red: 0.47, green: 0.47, blue: 0.49, alpha: 1.0) // 中灰
        closeButton.layer.cornerRadius = 11
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        cardView.addSubview(closeButton)

        // 图片
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = UIColor(white: 1, alpha: 0.06)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(imageView)
        // 取图优先级：服务端远程图 → 显式内置图 → 按类型的默认底图（防止无图弹窗留白）。
        if let urlString = popup.imageURL, let url = URL(string: urlString) {
            imageView.mdr_loadImage(from: url)
            imageView.image = UIImage(named: Self.defaultImageName(for: popup.type)) // 远程未回来前先占位
        } else if let name = popup.localImageName, let img = UIImage(named: name) {
            imageView.image = img
        } else {
            imageView.image = UIImage(named: Self.defaultImageName(for: popup.type))
        }

        // 标签
        let badgeLabel = PaddingLabel()
        badgeLabel.text = popup.badge
        badgeLabel.font = UIFont(name: "PingFangSC-Medium", size: 11) ?? .systemFont(ofSize: 11, weight: .medium)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = Self.badgeColor(popup.badgeStyle)
        badgeLabel.layer.cornerRadius = 11
        badgeLabel.clipsToBounds = true
        badgeLabel.isHidden = (popup.badge?.isEmpty ?? true)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(badgeLabel)

        // 标题
        let titleLabel = UILabel()
        titleLabel.text = popup.title
        titleLabel.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        // 副标题
        let subtitleLabel = UILabel()
        subtitleLabel.text = popup.subtitle
        subtitleLabel.font = UIFont(name: "PingFangSC-Regular", size: 13) ?? .systemFont(ofSize: 13)
        subtitleLabel.textColor = UIColor(white: 1, alpha: 0.6)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(subtitleLabel)

        // 主按钮
        let actionButton = UIButton(type: .system)
        actionButton.setTitle(popup.actionText, for: .normal)
        actionButton.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        actionButton.setTitleColor(UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0), for: .normal)
        actionButton.backgroundColor = .white
        actionButton.layer.cornerRadius = 22
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
        cardView.addSubview(actionButton)

        // 点击遮罩空白处关闭
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleDimTap(_:)))
        dimView.addGestureRecognizer(tap)

        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),

            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 360),

            // 关闭按钮与徽标同高、同一水平中线（对齐设计：圆直径 = 徽标高度）。
            closeButton.centerYAnchor.constraint(equalTo: badgeLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.heightAnchor.constraint(equalToConstant: 22),

            badgeLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            badgeLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            badgeLabel.heightAnchor.constraint(equalToConstant: 22),

            imageView.topAnchor.constraint(equalTo: badgeLabel.bottomAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.485),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            actionButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            actionButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            actionButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            actionButton.heightAnchor.constraint(equalToConstant: 44),
            actionButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20)
        ])
    }

    /// 按弹窗类型的默认底图（无远程图 / 无显式内置图时兜底）。
    private static func defaultImageName(for type: HomePopup.PopupType) -> String {
        switch type {
        case .mall: return "popup_mall"
        case .ad, .unknown: return "popup_ad"
        case .survey: return "popup_survey"
        }
    }

    private static func badgeColor(_ style: String?) -> UIColor {
        switch style {
        case "orange": return UIColor(red: 240/255, green: 158/255, blue: 60/255, alpha: 1.0)
        case "blue": return UIColor(red: 76/255, green: 130/255, blue: 240/255, alpha: 1.0)
        default: return UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0) // #8054FE
        }
    }

    // MARK: - Actions

    @objc private func handleClose() {
        onClose(popup)
        dismiss()
    }

    @objc private func handleDimTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: cardView)
        if cardView.bounds.contains(location) { return }   // 点在卡片内不关闭
        onClose(popup)
        dismiss()
    }

    @objc private func handleAction() {
        let popup = self.popup
        let action = self.onAction
        dismiss { action(popup) }
    }
}

// MARK: - 带内边距的胶囊标签

final class PaddingLabel: UILabel {
    var insets = UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right,
                      height: s.height + insets.top + insets.bottom)
    }
}

// MARK: - 轻量远程图片加载（无三方依赖，带内存缓存）

private final class MdrImageCache {
    static let shared = NSCache<NSURL, UIImage>()
}

extension UIImageView {
    /// 加载远程图片（内存缓存），主线程回填。用于弹窗主图。
    func mdr_loadImage(from url: URL) {
        if let cached = MdrImageCache.shared.object(forKey: url as NSURL) {
            self.image = cached
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            MdrImageCache.shared.setObject(image, forKey: url as NSURL)
            DispatchQueue.main.async { self?.image = image }
        }.resume()
    }
}
