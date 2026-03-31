
import UIKit

class FAQViewController: UIViewController {

    // MARK: - UI Components
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L("subscription.renewal_management") // "续费管理"
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let backButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton()
        button.setImage(UIImage(named: "sub_back"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let navSeparatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let scrollView: UIScrollView = {
        let kv = UIScrollView()
        kv.backgroundColor = .clear
        kv.showsVerticalScrollIndicator = false
        kv.translatesAutoresizingMaskIntoConstraints = false
        return kv
    }()
    
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0 
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let mainContainerView: UIView = {
        let view = UIView()
        // Correct Background Color: 181818
        view.backgroundColor = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Outer view background (black/dark)
        view.backgroundColor = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0)
        
        setupUI()
        setupContent()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure nav separator layer frame is correct
        if let layers = navSeparatorView.layer.sublayers {
            for layer in layers {
                layer.frame = navSeparatorView.bounds
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.addSubview(mainContainerView)
        mainContainerView.addSubview(titleLabel)
        mainContainerView.addSubview(backButton)
        mainContainerView.addSubview(navSeparatorView)
        mainContainerView.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        
        // Nav Separator Style (Top)
        // 375pt width (full), 0.5pt height, #E4E4E4, 20% opacity.
        let borderLayer = CALayer()
        borderLayer.backgroundColor = UIColor(red: 228/255, green: 228/255, blue: 228/255, alpha: 0.2).cgColor
        navSeparatorView.layer.addSublayer(borderLayer)
        
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            // Main container (the card)
            mainContainerView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 10), // Give some space from top if it is a card
            // Actually usually full screen implies top is 0. 
            // If it mimics Notifications, it was:
            // listContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            // Let's assume user wants the CONTENT area to be this card.
            // But the header is inside mainContainerView.
            // Let's make mainContainerView fill screen but have the color and radius.
            // If radius is 18, it might be for the whole screen (like a presented card).
            mainContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            mainContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            backButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: mainContainerView.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 24),
            backButton.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: mainContainerView.centerXAnchor),
            
            // Nav Separator
            navSeparatorView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 13.5),
            navSeparatorView.leadingAnchor.constraint(equalTo: mainContainerView.leadingAnchor),
            navSeparatorView.trailingAnchor.constraint(equalTo: mainContainerView.trailingAnchor),
            navSeparatorView.heightAnchor.constraint(equalToConstant: 0.5),
            
            scrollView.topAnchor.constraint(equalTo: navSeparatorView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: mainContainerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: mainContainerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: mainContainerView.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupContent() {
        // --- Header Intro ---
        let introContainer = UIView()
        introContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let introTitleLabel = UILabel()
        introTitleLabel.text = L("faq.title") // Mindora 常见问题解答
        introTitleLabel.font = UIFont(name: "PingFangSC-Semibold", size: 24) ?? .systemFont(ofSize: 24, weight: .bold)
        introTitleLabel.textColor = .white
        introTitleLabel.numberOfLines = 0
        introTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let introDescLabel = UILabel()
        introDescLabel.text = L("faq.subtitle")
        introDescLabel.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        introDescLabel.textColor = UIColor(white: 1, alpha: 0.6)
        introDescLabel.numberOfLines = 0
        introDescLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Header Text Wrapper (No special bg)
        introContainer.addSubview(introTitleLabel)
        introContainer.addSubview(introDescLabel)
        
        NSLayoutConstraint.activate([
            introTitleLabel.topAnchor.constraint(equalTo: introContainer.topAnchor, constant: 20),
            introTitleLabel.leadingAnchor.constraint(equalTo: introContainer.leadingAnchor, constant: 20),
            introTitleLabel.trailingAnchor.constraint(equalTo: introContainer.trailingAnchor, constant: -20),
            
            introDescLabel.topAnchor.constraint(equalTo: introTitleLabel.bottomAnchor, constant: 12),
            introDescLabel.leadingAnchor.constraint(equalTo: introContainer.leadingAnchor, constant: 20),
            introDescLabel.trailingAnchor.constraint(equalTo: introContainer.trailingAnchor, constant: -20),
            introDescLabel.bottomAnchor.constraint(equalTo: introContainer.bottomAnchor, constant: -30)
        ])
        
        contentStack.addArrangedSubview(introContainer)
        
        // Items Data
        // Order: Packaging (A), Accuracy (A), AI (NA), Accuracy (NA - Duplicate), Packaging (NA - Duplicate) based on provided HTML structure or context.
        // User request: "Getting Started has 5 questions... Only 'Packaging' and 'Accuracy' have answers, others temporarily no answer".
        // I will assume the duplicates also have no answer to be safe as "others".
        // Or if the content is EXACTLY the same question string, logically it would have an answer.
        // But let's follow stricter instruction "others temporarily no answer".
        
        let packagingQ = L("faq.q.packaging")
        let packagingA = L("faq.a.packaging")
        
        let accuracyQ = L("faq.q.accuracy")
        let accuracyA = L("faq.a.accuracy")
        
        let aiQ = L("faq.q.ai")
        // No answer for AI question
        
        // Section 1 List
        let s1_items: [(q: String, a: String?)] = [
            (packagingQ, packagingA),
            (accuracyQ, accuracyA),
            (aiQ, nil),
            (accuracyQ, nil) // Duplicate, no answer per instruction "others"
        ]
        
        // Section 2 List (Same pattern per design draft implication)
        let s2_items: [(q: String, a: String?)] = [
            (packagingQ, packagingA),
            (accuracyQ, accuracyA),
            (aiQ, nil),
            (accuracyQ, nil)
        ]
        
        // --- Section 1: Getting Started ---
        addSectionHeader(title: L("faq.section.getting_started"))
        addCardSection(items: s1_items)

        // --- Section 2: Core Features & AI ---
        addSpacer(height: 30)
        addSectionHeader(title: L("faq.section.core_ai"))
        addCardSection(items: s2_items)
        
        // Bottom padding
        addSpacer(height: 50)
    }
    
    private func addCardSection(items: [(q: String, a: String?)]) {
        let card = createCardContainer()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        for (index, item) in items.enumerated() {
            let itemView = createFAQItem(question: item.q, answer: item.a ?? "")
            stack.addArrangedSubview(itemView)
            
            // Add separator if not last item
            if index < items.count - 1 {
                let sep = createSeparator()
                stack.addArrangedSubview(sep)
            }
        }
        
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        
        contentStack.addArrangedSubview(card)
    }
    
    private func createCardContainer() -> UIView {
        let view = UIView()
        // Specific Question Background Color: 2C2C2C
        view.backgroundColor = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0)
        // Corner Radius 18pt
        view.layer.cornerRadius = 18
        // "Rounded Rectangle not seen" might imply masksToBounds required
        view.layer.masksToBounds = true 
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    private func createFAQItem(question: String, answer: String) -> UIView {
        return FAQItemView(question: question, answer: answer)
    }
    
    private func createSeparator() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        let sep = FAQSeparatorView()
        sep.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sep)
        
        NSLayoutConstraint.activate([
            sep.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            // Updated alignment: Align with text leading (20) and button trailing (-20)
            sep.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            sep.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            sep.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        return container
    }
    
    private func addSectionHeader(title: String) {
        let container = UIView()
        let label = UILabel()
        label.text = title
        label.font = UIFont(name: "PingFangSC-Semibold", size: 16) ?? .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])
        
        contentStack.addArrangedSubview(container)
    }
    
    private func addSpacer(height: CGFloat) {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        contentStack.addArrangedSubview(view)
    }
    
    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - FAQ Item View

class FAQItemView: UIView {
    
    private let question: String
    private let answer: String
    private var isExpanded: Bool = false
    
    // Main Stack to hold Header and Answer vertically
    private let mainStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Header View containing Question and Arrow
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear // Transparent
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let questionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let arrowImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "arrow_down")
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    // Answer Container for padding
    private let answerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let answerLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Regular", size: 13) ?? .systemFont(ofSize: 13)
        // Correct text color: White 60%
        label.textColor = UIColor(white: 1, alpha: 0.6)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let toggleButton: UIButton = {
        let btn = UIButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    init(question: String, answer: String) {
        self.question = question
        self.answer = answer
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        addSubview(mainStack)
        
        // Setup Header
        headerView.addSubview(questionLabel)
        headerView.addSubview(arrowImageView)
        headerView.addSubview(toggleButton)
        
        questionLabel.text = question
        answerLabel.text = answer
        
        // Initial configuration: If no answer, hide arrow and disable user interaction
        let hasAnswer = !answer.isEmpty
        toggleButton.isUserInteractionEnabled = hasAnswer
        arrowImageView.isHidden = !hasAnswer
        
        NSLayoutConstraint.activate([
             headerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50), // Min height
             
             // Question
             questionLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
             questionLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
             questionLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
             questionLabel.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -10),
             
             // Arrow
             arrowImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
             arrowImageView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
             arrowImageView.widthAnchor.constraint(equalToConstant: 16),
             arrowImageView.heightAnchor.constraint(equalToConstant: 16),
             
             // Button
             toggleButton.topAnchor.constraint(equalTo: headerView.topAnchor),
             toggleButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
             toggleButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
             toggleButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])
        
        // Setup Answer
        answerContainer.addSubview(answerLabel)
        NSLayoutConstraint.activate([
            answerLabel.topAnchor.constraint(equalTo: answerContainer.topAnchor, constant: 0), // Closer to title
            answerLabel.leadingAnchor.constraint(equalTo: answerContainer.leadingAnchor, constant: 20),
            answerLabel.trailingAnchor.constraint(equalTo: answerContainer.trailingAnchor, constant: -20),
            answerLabel.bottomAnchor.constraint(equalTo: answerContainer.bottomAnchor, constant: -16)
        ])
        
        // Add to stack
        mainStack.addArrangedSubview(headerView)
        mainStack.addArrangedSubview(answerContainer)
        
        // Main Constraints
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        toggleButton.addTarget(self, action: #selector(toggle), for: .touchUpInside)
    }
    
    @objc private func toggle() {
        isExpanded.toggle()
        updateState(animated: true)
    }
    
    private func updateState(animated: Bool) {
        let duration = animated ? 0.3 : 0.0
        
        UIView.animate(withDuration: duration) {
            self.answerContainer.isHidden = !self.isExpanded
            self.answerContainer.alpha = self.isExpanded ? 1.0 : 0.0
            self.arrowImageView.transform = self.isExpanded ? CGAffineTransform(rotationAngle: .pi) : .identity
            // Layout needs to be explicitly refreshed for StackView animations sometimes
            self.layoutIfNeeded()
        }
    }
}

// MARK: - Custom Separator

class FAQSeparatorView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
    }
    
    override func draw(_ rect: CGRect) {
        // Just fill with White 40% as requested
        UIColor(white: 1.0, alpha: 0.4).setFill()
        UIRectFill(rect)
    }
}
