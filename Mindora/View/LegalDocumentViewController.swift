import UIKit

class LegalDocumentViewController: UIViewController {

    private let pageTitle: String
    private let content: String

    // MARK: - UI Components
    
    private let navBarView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear // Changed to clear or remove completely if not used
        return view
    }()
    
    private let backButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        if let image = UIImage(named: "sub_back") {
            button.setImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
        }
        button.tintColor = .black
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .black
        label.textAlignment = .center
        return label
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        return scrollView
    }()
    
    private let contentLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        label.textColor = UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1.0) // Dark gray
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Init
    
    init(title: String, content: String) {
        self.pageTitle = title
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        configureData()
    }
    
    private func setupUI() {
        // Remove standard Nav Bar styling, follow design
        // Page padding analysis from CSS:
        // padding-left: 36px -> 18pt
        // padding-right: 29px -> 14.5pt
        // Back Button margin-top: 43px -> 21.5pt (from status bar/top)
        
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(contentLabel)
        
        // CSS label_4: width 28px (14pt), height 28px (14pt)
        
        NSLayoutConstraint.activate([
            // Back Button
            // Using safeAreaLayoutGuide.topAnchor for status bar bottom reference
            // Design seems to have spacing below status bar.
            // Let's use a reasonable top margin relative to Safe Area.
            // If design says 43px (21.5pt) from "box_1" (status bar), we align it there.
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10), 
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18), // 36px / 2
            backButton.widthAnchor.constraint(equalToConstant: 14), // 28px / 2
            backButton.heightAnchor.constraint(equalToConstant: 14), // 28px / 2
            
            // Title
            // CSS text-wrapper_2 margin-top: 114px -> 57pt from previous element (back button roughly)
            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 57),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            // Title is usually wide enough, but let's constrain width safely
            titleLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            
            // Scroll View
            // CSS paragraph_1 margin-top: 86px -> 43pt from title
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 43),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content Label
            // CSS paragraph_1 margins: left 12px -> 6pt, right 19px -> 9.5pt.
            // Plus page padding: left 18pt, right 14.5pt.
            // Total Left: 24pt, Total Right: 24pt (approx)
            contentLabel.topAnchor.constraint(equalTo: scrollView.topAnchor), // ScrollView handles scrolling
            contentLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentLabel.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48)
        ])
        
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        
        // Expand touch area for the small back button
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
            backButton.configuration = config
        } else {
            backButton.imageEdgeInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10) // Visual remains same, but hit test needs a larger view usually, or we wrap it.
        }
        // Better: increase constraints size or use a wrapper. But strictly following design visual size:
        // We can increase the frame but keep the image centered?
        // Let's just keep strict visual size for now as requested.
    }
    
    private func configureData() {
        titleLabel.text = pageTitle
        contentLabel.text = content
        
        // Adjust line spacing if needed
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        let attrString = NSMutableAttributedString(string: content)
        attrString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attrString.length))
        contentLabel.attributedText = attrString
    }
    
    @objc private func handleBack() {
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
}
