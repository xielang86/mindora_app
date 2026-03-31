import UIKit

class HelpViewController: UIViewController {

    // MARK: - UI Configuration (1px = 0.5pt)
    
    // Group 1 Metrics
    private let box2MarginLeft: CGFloat = 18.0 // 36px
    private let box2Width: CGFloat = 184.5 // 369px
    
    // Box 3 Metrics (Inside Group 1)
    private let box3Height: CGFloat = 157.0 // 314px
    
    // MARK: - UI Components
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Group 1 Container
    private let group1View: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let helpTopImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: "help_top")
        imageView.contentMode = .scaleToFill // Fills Group 1
        return imageView
    }()
    
    private let backButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "sub_back"), for: .normal)
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("help.page.title")
        label.textColor = .white
        // CSS text_3: 30px -> 15pt, SourceHanSansCN-Medium -> PingFangSC-Medium
        label.font = UIFont(name: "PingFangSC-Medium", size: 15) ?? .boldSystemFont(ofSize: 15)
        label.textAlignment = .center
        return label
    }()
    
    private let helpBottomImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: "help_bottom")
        imageView.contentMode = .scaleToFill
        return imageView
    }()
    
    // Group 2 Container
    private let group2View: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let qrCodeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: "qr_code")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("help.page.description")
        label.textColor = .white
        // 24px -> 12pt, SourceHanSansCN-Normal
        label.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.textAlignment = .center
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.2
        paragraphStyle.alignment = .center
        
        let attrString = NSMutableAttributedString(string: L("help.page.description"))
        attrString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attrString.length))
        label.attributedText = attrString
        
        return label
    }()
    
    private let emailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("help.page.email")
        label.textColor = .white
        // 28px -> 14pt, HKGrotesk-SemiBold
        label.font = UIFont(name: "HKGrotesk-SemiBold", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(group1View)
        contentView.addSubview(group2View)
        
        // Group 1 Subviews
        group1View.addSubview(helpTopImageView)
        group1View.sendSubviewToBack(helpTopImageView)
        group1View.addSubview(backButton)
        group1View.addSubview(titleLabel)
        group1View.addSubview(helpBottomImageView)
        
        // Group 2 Subviews
        group2View.addSubview(qrCodeImageView)
        group2View.addSubview(descriptionLabel)
        group2View.addSubview(emailLabel)
        
        setupConstraints()
        
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
    }
    
    private func setupConstraints() {
        // ScrollView
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        
        // Group 1
        NSLayoutConstraint.activate([
            group1View.topAnchor.constraint(equalTo: contentView.topAnchor),
            group1View.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            group1View.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
        
        // Help Top Image (Background of Group 1)
        NSLayoutConstraint.activate([
            helpTopImageView.topAnchor.constraint(equalTo: group1View.topAnchor),
            helpTopImageView.leadingAnchor.constraint(equalTo: group1View.leadingAnchor),
            helpTopImageView.trailingAnchor.constraint(equalTo: group1View.trailingAnchor),
            helpTopImageView.bottomAnchor.constraint(equalTo: group1View.bottomAnchor)
        ])
        
        // Header (Box 2)
        // Top = 15.5 (Pad) + 17 (Box1) + 21 (Margin) = 53.5pt from Top
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: group1View.topAnchor, constant: 53.5),
            backButton.leadingAnchor.constraint(equalTo: group1View.leadingAnchor, constant: box2MarginLeft),
            backButton.widthAnchor.constraint(equalToConstant: 14), // 28px -> 14pt
            backButton.heightAnchor.constraint(equalToConstant: 14)
        ])
        
        // Title Label
        // Right-aligned in Box 2.
        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: group1View.leadingAnchor, constant: box2MarginLeft + box2Width)
        ])
        
        // Match CSS margin-top 539px (269.5pt) + Header Offset
        // Original was 338. Increasing to push content lower as requested.
        // Let's try 420pt.
        NSLayoutConstraint.activate([
            helpBottomImageView.topAnchor.constraint(equalTo: group1View.topAnchor, constant: 420),
            helpBottomImageView.leadingAnchor.constraint(equalTo: group1View.leadingAnchor),
            helpBottomImageView.trailingAnchor.constraint(equalTo: group1View.trailingAnchor),
            helpBottomImageView.heightAnchor.constraint(equalToConstant: box3Height),
            helpBottomImageView.bottomAnchor.constraint(equalTo: group1View.bottomAnchor) // Pins Group1 Bottom
        ])
        
        // Group 2
        NSLayoutConstraint.activate([
            group2View.topAnchor.constraint(equalTo: group1View.bottomAnchor),
            group2View.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            group2View.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            group2View.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -50) // Padding bottom
        ])
        
        // QR Code
        // Top of Group 2.
        NSLayoutConstraint.activate([
            qrCodeImageView.topAnchor.constraint(equalTo: group2View.topAnchor),
            qrCodeImageView.centerXAnchor.constraint(equalTo: group2View.centerXAnchor),
            qrCodeImageView.widthAnchor.constraint(equalToConstant: 114),
            qrCodeImageView.heightAnchor.constraint(equalToConstant: 114)
        ])
        
        // Description
        // Margin top 22.5 (45px) from QR
        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(equalTo: qrCodeImageView.bottomAnchor, constant: 22.5),
            descriptionLabel.centerXAnchor.constraint(equalTo: group2View.centerXAnchor),
            descriptionLabel.widthAnchor.constraint(equalToConstant: 276) // 552px
        ])
        
        // Email
        // Margin top 14 (28px) from Desc
        NSLayoutConstraint.activate([
            emailLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 14),
            emailLabel.centerXAnchor.constraint(equalTo: group2View.centerXAnchor),
            emailLabel.bottomAnchor.constraint(equalTo: group2View.bottomAnchor)
        ])
    }
    
    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }
}
