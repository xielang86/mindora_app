import UIKit

final class Toast {
    static func show(_ text: String, in view: UIView, duration: TimeInterval = 2.0) {
        let padding: CGFloat = 12
        let label = UILabel()
        label.text = text
        label.textColor = Theme.primary
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityLabel = text
        let container = UIView()
        container.backgroundColor = Theme.surface
        container.layer.cornerRadius = 12
        container.alpha = 0
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = false
        container.addSubview(label)
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding)
        ])
        UIView.animate(withDuration: 0.2, animations: { container.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.25, delay: duration, options: .curveEaseInOut, animations: {
                container.alpha = 0
            }, completion: { _ in
                container.removeFromSuperview()
            })
        }
    }
}
