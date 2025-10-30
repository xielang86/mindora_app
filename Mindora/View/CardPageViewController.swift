import UIKit

final class CardPageViewController: UIViewController {
    init(titleText: String, bodyText: String, index: Int, total: Int) {
        super.init(nibName: nil, bundle: nil)
    let titleLabel = Theme.label(.bold, size: 22)
    titleLabel.text = titleText
        titleLabel.numberOfLines = 0

    let idxLabel = Theme.label(.regular, size: 13)
        idxLabel.text = "卡片 \(index)/\(total)"
    idxLabel.textColor = Theme.secondary

    let bodyLabel = Theme.label(.regular, size: 16)
        bodyLabel.text = bodyText
    bodyLabel.textColor = Theme.secondary
        bodyLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [idxLabel, titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

    view.backgroundColor = Theme.background
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
