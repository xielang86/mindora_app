import UIKit

class SubscriptionPromptView: UIView {
    
    var onSubscribeTap: (() -> Void)?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 44/255.0, green: 44/255.0, blue: 44/255.0, alpha: 1.0)
        view.layer.cornerRadius = 18
        view.clipsToBounds = true
        return view
    }()
    
    private let hintLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular) // SourceHanSansCN-Regular approximation
        label.textColor = .white
        return label
    }()
    
    private let separatorView: UIView = {
        let view = UIView()
        // Width 146pt, Height 0.5pt, Opacity 40%
        // Center border 0.25pt #FFFFFF 100%
        // The user description of separator is complex.
        // "SketchPnga0c89e04a596d9bd62edfd453a28a8b6c0225e4b3c94d20478ec1b6e02839087是一个分割线...大小146pt 0.5pt 不透明度40% 中心边框粗细0.25pt #FFFFFF 100%"
        // It seems to be a line.
        view.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        return view
    }()
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium) // SourceHanSansCN-Medium approximation
        button.setTitleColor(.white, for: .normal)
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(hintLabel)
        containerView.addSubview(separatorView)
        containerView.addSubview(actionButton)
        
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Populate text
        let hintText = "\(L("subscription.not_member"))\n\(L("subscription.view_content_hint"))"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.25 // adjusting for line-height 18pt with 12pt font (1.5x)
        paragraphStyle.alignment = .center
        let attributedString = NSMutableAttributedString(string: hintText, attributes: [
            .paragraphStyle: paragraphStyle,
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.white
        ])
        hintLabel.attributedText = attributedString
        
        actionButton.setTitle(L("subscription.go_to_subscribe"), for: .normal)
        actionButton.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        
        // CSS Padding: 48px 68px 30px 68px -> 24pt, 34pt, 15pt, 34pt
        
        // Constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Hint Label
            // Top padding: 24pt
            hintLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            hintLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            // Side padding: 34pt
            hintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 34),
            hintLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -34),
            
            // Separator
            // Width: 146pt. Height: 0.5pt.
            // If the box width is 214pt, margin = (214-146)/2 = 34pt.
            separatorView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 23),
            separatorView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            separatorView.widthAnchor.constraint(equalToConstant: 146),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),
            
            // Action Button
            actionButton.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 14),
            actionButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -15)
        ])
        
        // The container needs to grow to fit content, which it does.
        // Also it needs a tap gesture on the whole view or just button? 
        // "点击前往订阅跳转" - Clicking 'Go to Subscription' jumps.
        // I used a button for the text "Go to Subscription".
        
        // Add separator border effect if needed. Using simple view for now.
    }
    
    @objc private func handleTap() {
        onSubscribeTap?()
    }
}
