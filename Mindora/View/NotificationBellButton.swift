//
//  NotificationBellButton.swift
//  mindora
//
//  顶部导航栏右上角「消息通知」铃铛入口。红点跟随 UnreadBadgeCenter 的未读状态，
//  浏览消息后自动消失（与侧边栏红点联动）。
//

import UIKit

final class NotificationBellButton: UIControl {

    private let bellImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "nav_bell")?.withRenderingMode(.alwaysTemplate))
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let redDot: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 1.0, green: 59/255, blue: 48/255, alpha: 1.0) // #FF3B30
        v.layer.cornerRadius = 3
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(bellImageView)
        addSubview(redDot)
        NSLayoutConstraint.activate([
            // 铃铛 ~16×20pt（贴合设计稿 ≈15.5×19.5pt），整体触控区由外部约束（28pt）保证
            bellImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            bellImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            bellImageView.widthAnchor.constraint(equalToConstant: 16),
            bellImageView.heightAnchor.constraint(equalToConstant: 20),

            // 红点 6pt，位于铃铛右上
            redDot.widthAnchor.constraint(equalToConstant: 6),
            redDot.heightAnchor.constraint(equalToConstant: 6),
            redDot.centerXAnchor.constraint(equalTo: bellImageView.trailingAnchor),
            redDot.centerYAnchor.constraint(equalTo: bellImageView.topAnchor, constant: 1)
        ])

        // 红点跟随全局未读状态，并监听变化（浏览消息后实时消失）
        refreshBadge()
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshBadge),
            name: UnreadBadgeCenter.didChangeNotification, object: nil
        )
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func refreshBadge() {
        redDot.isHidden = !UnreadBadgeCenter.shared.hasUnread
    }
}
