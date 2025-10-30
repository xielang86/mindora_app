import UIKit

final class DeviceCell: UITableViewCell {
    struct Model {
        let name: String
        let connected: Bool
    }

    private let card = UIView()
    private let iconView = UIImageView()
    private let nameLabel = Theme.label(.medium, size: 18)
    private let statusContainer = UIView()
    private let statusLabel = Theme.label(.regular, size: 12)
    private let stack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        card.translatesAutoresizingMaskIntoConstraints = false
    card.backgroundColor = Theme.surface
    card.layer.cornerRadius = Theme.cornerRadius
        card.layer.cornerCurve = .continuous
    card.layer.borderWidth = 0
        contentView.addSubview(card)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Theme.primary
        iconView.image = UIImage(systemName: "dot.radiowaves.left.and.right")

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.numberOfLines = 2

        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.backgroundColor = Theme.accent
        statusContainer.layer.cornerRadius = 12
        statusContainer.layer.masksToBounds = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusContainer.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: statusContainer.topAnchor, constant: 4),
            statusLabel.bottomAnchor.constraint(equalTo: statusContainer.bottomAnchor, constant: -4),
            statusLabel.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: -10)
        ])

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [nameLabel])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(textStack)
    stack.addArrangedSubview(statusContainer)

        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    statusContainer.isHidden = true
    }

    func configure(_ model: Model) {
        nameLabel.text = model.name
        if model.connected {
            statusContainer.isHidden = false
            statusLabel.text = L("home.connected_state")
        } else {
            statusContainer.isHidden = true
        }
        updateForCurrentTheme()
    }

    func updateForCurrentTheme() {
        card.backgroundColor = Theme.surface
        nameLabel.textColor = Theme.primary
        iconView.tintColor = Theme.primary
        if traitCollection.userInterfaceStyle == .dark {
            card.layer.shadowOpacity = 0
        } else {
            card.layer.shadowOpacity = 0.05
            card.layer.shadowRadius = 8
            card.layer.shadowOffset = CGSize(width: 0, height: 4)
            card.layer.shadowColor = UIColor.black.cgColor
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let alpha: CGFloat = highlighted ? 0.8 : 1
        if animated {
            UIView.animate(withDuration: 0.18) { self.card.alpha = alpha }
        } else {
            card.alpha = alpha
        }
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // 同高亮
        let alpha: CGFloat = selected ? 0.86 : 1
        if animated { UIView.animate(withDuration: 0.2) { self.card.alpha = alpha } } else { card.alpha = alpha }
    }
}

