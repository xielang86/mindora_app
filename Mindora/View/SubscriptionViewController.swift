import UIKit
import MessageUI
import SafariServices

class SubscriptionViewController: UIViewController, MFMailComposeViewControllerDelegate {

    // MARK: - Properties
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Background Image
    private let backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        // Use sub_bg normally, maybe switch if Pro? User provided sub_pro_bg.
        iv.image = UIImage(named: "sub_bg")
        return iv
    }()
    
    // Navigation Bar
    private let navBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    private let backButton: EnlargedHitAreaButton = {
        let btn = EnlargedHitAreaButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(named: "sub_back"), for: .normal)
        return btn
    }()
    
    private let navTitleLabel: UILabel = {
        let lb = UILabel()
        lb.translatesAutoresizingMaskIntoConstraints = false
        lb.text = L("subscription.nav.title")
        lb.font = UIFont(name: "PingFangSC-Semibold", size: 18)
        lb.textColor = .white
        return lb
    }()
    
    private let emailIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "sub_email"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        // iv.isHidden = true // Always visible
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    // Stack for dynamic content
    private let mainStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20
        return stack
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBaseUI()
        updateUI()
        
        NotificationCenter.default.addObserver(self, selector: #selector(subscriptionChanged), name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
        
        Task {
            await SubscriptionManager.shared.loadProducts()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    @objc private func subscriptionChanged() {
        updateUI()
    }
    
    // MARK: - UI Setup
    
    private func setupBaseUI() {
        view.backgroundColor = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0) // #181818
        
        // view.addSubview(backgroundImageView) // Removing background image to show solid color
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(navBar)
        navBar.addSubview(backButton)
        navBar.addSubview(navTitleLabel)
        navBar.addSubview(emailIcon)
        
        contentView.addSubview(mainStack)
        
        // Email Action
        emailIcon.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleEmailTap))
        emailIcon.addGestureRecognizer(tap)
        
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            // backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            // backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            // backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor), // Full screen bg
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Nav Bar
            navBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 44), // Safe area approx
            navBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 44),
            
            backButton.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 20),
            backButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            
            navTitleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            navTitleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            
            emailIcon.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -20),
            emailIcon.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            emailIcon.widthAnchor.constraint(equalToConstant: 20), // 40px
            emailIcon.heightAnchor.constraint(equalToConstant: 15), // 30px
            
            // Main Stack
            mainStack.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    private func updateUI() {
        // Clear stack
        mainStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let manager = SubscriptionManager.shared
        
        // 1. Profile / Header Info
        mainStack.addArrangedSubview(createProfileSection(isSubscribed: manager.isSubscribed))
        
        // 2. Subscription Options / My Subscription
        if manager.isSubscribed {
            setupSubscribedContent()
        } else {
            setupUnsubscribedContent()
        }
        
        // 3. Features
        mainStack.addArrangedSubview(createFeaturesSection())
        
        // 4. Footer Links
        mainStack.addArrangedSubview(createFooterSection())
        
        // Update BG and Icon
        if manager.isSubscribed {
            // backgroundImageView.image = UIImage(named: "sub_pro_bg") // Handled in profile section
            // emailIcon.isHidden = false // Fixed: Always visible
        } else {
            // backgroundImageView.image = UIImage(named: "sub_bg")
            // emailIcon.isHidden = true
        }
    }
    
    // MARK: - Sections
    
    private func createProfileSection(isSubscribed: Bool) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let bgImageView = UIImageView()
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        bgImageView.contentMode = .scaleToFill // Stretch to fill container
        container.addSubview(bgImageView)
        
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentStack)
        
        // Title: My MIDORA
        let titleLabel = UILabel()
        titleLabel.text = L("subscription.my_midora") // Font: Kano-regular (36px -> 18pt)
        titleLabel.font = UIFont(name: "PingFangSC-Regular", size: 18) 
        titleLabel.textColor = .white
        
        if isSubscribed {
            bgImageView.image = UIImage(named: "sub_pro_bg")
            
            // Subscribed Layout
            // 1. Title
            contentStack.addArrangedSubview(titleLabel)
            contentStack.setCustomSpacing(20, after: titleLabel) // spacing 52px approx 26pt
            
            // 2. TIDE Days Container (sub_pro_bg2)
            let daysContainer = UIView()
            daysContainer.translatesAutoresizingMaskIntoConstraints = false
            
            let daysBg = UIImageView(image: UIImage(named: "sub_pro_bg2"))
            daysBg.translatesAutoresizingMaskIntoConstraints = false
            daysBg.contentMode = .scaleToFill
            daysContainer.addSubview(daysBg)
            
            let daysStack = UIStackView()
            daysStack.axis = .vertical
            daysStack.alignment = .center
            daysStack.spacing = 5
            daysStack.translatesAutoresizingMaskIntoConstraints = false
            
            let numLabel = UILabel()
            numLabel.text = "\(SubscriptionManager.shared.tideDays)" // 94
            numLabel.font = UIFont(name: "PingFangSC-Semibold", size: 45) // 90px -> 45pt
            numLabel.textColor = .white
            
            let descLabel = UILabel()
            descLabel.text = L("subscription.tide_days")
            descLabel.font = UIFont(name: "PingFangSC-Regular", size: 11) // 22px -> 11pt
            descLabel.textColor = .white
            
            daysStack.addArrangedSubview(numLabel)
            daysStack.addArrangedSubview(descLabel)
            daysContainer.addSubview(daysStack)
            
            NSLayoutConstraint.activate([
                daysBg.topAnchor.constraint(equalTo: daysContainer.topAnchor),
                daysBg.leadingAnchor.constraint(equalTo: daysContainer.leadingAnchor),
                daysBg.trailingAnchor.constraint(equalTo: daysContainer.trailingAnchor),
                daysBg.bottomAnchor.constraint(equalTo: daysContainer.bottomAnchor),
                
                daysStack.centerXAnchor.constraint(equalTo: daysContainer.centerXAnchor),
                daysStack.centerYAnchor.constraint(equalTo: daysContainer.centerYAnchor),
                
                // Constraints for size if needed, or let content determine. 
                // Design padding: top 17, bottom 22, left 132, right 106. 
                // We'll set a min height/width or padding constraints
                daysStack.topAnchor.constraint(equalTo: daysContainer.topAnchor, constant: 10),
                daysStack.bottomAnchor.constraint(equalTo: daysContainer.bottomAnchor, constant: -10),
                daysStack.leadingAnchor.constraint(equalTo: daysContainer.leadingAnchor, constant: 40),
                daysStack.trailingAnchor.constraint(equalTo: daysContainer.trailingAnchor, constant: -40),
            ])
            
            contentStack.addArrangedSubview(daysContainer)
            contentStack.setCustomSpacing(25, after: daysContainer) // margin-top 48px -> 24pt
            
            // 3. Info Row (Active... Expires...)
            let infoRow = UIStackView()
            infoRow.axis = .horizontal
            infoRow.distribution = .equalSpacing // justify-between
            infoRow.spacing = 20
            infoRow.translatesAutoresizingMaskIntoConstraints = false
            
            let planName = SubscriptionManager.shared.currentPlan == .monthly ? 
                L("subscription.plan_name.monthly") : 
                L("subscription.plan_name.yearly")
            
            let statusLabel = UILabel()
            statusLabel.text = L("subscription.active.plan_prefix") + planName + L("subscription.active.plan_suffix")
            statusLabel.font = UIFont(name: "PingFangSC-Regular", size: 11) // 22px -> 11pt
            statusLabel.textColor = .white
            
            let date = SubscriptionManager.shared.expiryDate
            let formatter = DateFormatter()
            // Use current locale instead of fixed en_US to support Chinese format etc.
            formatter.locale = Locale.current 
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let dateStr = formatter.string(from: date)
            
            let expiryLabel = UILabel()
            expiryLabel.text = L("subscription.expires_prefix") + dateStr
            expiryLabel.font = UIFont(name: "PingFangSC-Regular", size: 11)
            expiryLabel.textColor = .white
            
            infoRow.addArrangedSubview(statusLabel)
            infoRow.addArrangedSubview(expiryLabel)
            
            // Info Row needs to be wide
            contentStack.addArrangedSubview(infoRow)
            infoRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -40).isActive = true
            
        } else {
            bgImageView.image = UIImage(named: "sub_bg")
            
            // Not Subscribed Layout
            // Centered Title and Paragraph
            
            contentStack.addArrangedSubview(titleLabel)
            contentStack.setCustomSpacing(20, after: titleLabel) // margin-top 44px -> 22pt
            
            let subtitleLabel = UILabel()
            subtitleLabel.numberOfLines = 0
            subtitleLabel.textAlignment = .center
            // Use attributed string for "You are not a member\nSubscribe..."
            let text = L("subscription.not_member") + "\n" + L("subscription.not_member_desc")
            subtitleLabel.text = text
            subtitleLabel.font = UIFont(name: "PingFangSC-Light", size: 12) // 24px -> 12pt
            subtitleLabel.textColor = .white
            
            contentStack.addArrangedSubview(subtitleLabel)
        }
        
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: container.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -25),
            contentStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            contentStack.widthAnchor.constraint(equalTo: container.widthAnchor)
        ])
        
        return container
    }
    
    private func setupUnsubscribedContent() {
        // Title
        let sectionTitle = UILabel()
        sectionTitle.text = L("subscription.section.title")
        sectionTitle.font = UIFont(name: "PingFangSC-Semibold", size: 16)
        sectionTitle.textColor = .white
        mainStack.addArrangedSubview(sectionTitle)
        
        // Helper to get price string
        func getPrice(for id: String, defaultPrice: String) -> String {
            if let product = SubscriptionManager.shared.products.first(where: { $0.id == id }) {
                return product.displayPrice
            }
            return defaultPrice
        }
        
        let monthlyPrice = getPrice(for: Constants.Subscription.monthlyProductID, defaultPrice: Constants.Subscription.monthlyPrice)
        let yearlyPrice = getPrice(for: Constants.Subscription.yearlyProductID, defaultPrice: Constants.Subscription.yearlyPrice)
        
        // Monthly Item
        let monthly = createProductView(
            title: L("subscription.monthly"),
            price: monthlyPrice + L("subscription.price.monthly"),
            desc: L("subscription.desc.monthly.prefix") + monthlyPrice + L("subscription.desc.monthly.suffix"),
            actionTitle: L("subscription.action.subscribe"),
            isActionDestructive: false) {
                SubscriptionManager.shared.purchase(type: .monthly)
            }
        mainStack.addArrangedSubview(monthly)
        
        // Yearly Item
        let yearly = createProductView(
            title: L("subscription.yearly"),
            price: yearlyPrice + L("subscription.price.yearly"),
            desc: L("subscription.desc.yearly"),
            actionTitle: L("subscription.action.subscribe"),
            isActionDestructive: false) {
                SubscriptionManager.shared.purchase(type: .yearly)
            }
        mainStack.addArrangedSubview(yearly)
    }
    
    private func setupSubscribedContent() {
        let sectionTitle = UILabel()
        sectionTitle.text = L("subscription.my.title")
        sectionTitle.font = UIFont(name: "PingFangSC-Semibold", size: 16)
        sectionTitle.textColor = .white
        mainStack.addArrangedSubview(sectionTitle)
        
        let currentPlan = SubscriptionManager.shared.currentPlan
        
        // Helper to get price string
        func getPrice(for id: String, defaultPrice: String) -> String {
            if let product = SubscriptionManager.shared.products.first(where: { $0.id == id }) {
                return product.displayPrice
            }
            return defaultPrice
        }
        
        let monthlyPrice = getPrice(for: Constants.Subscription.monthlyProductID, defaultPrice: Constants.Subscription.monthlyPrice)
        let yearlyPrice = getPrice(for: Constants.Subscription.yearlyProductID, defaultPrice: Constants.Subscription.yearlyPrice)
        
        // Active Plan
        if currentPlan == .monthly {
             // Expiry info for active
             let date = Calendar.current.date(byAdding: .day, value: -1, to: SubscriptionManager.shared.expiryDate) ?? Date()
             let formatter = DateFormatter()
             formatter.locale = Locale.current 
             formatter.dateStyle = .medium
             formatter.timeStyle = .none
             let dateStr = formatter.string(from: date)
             
             let isAutoRenew = SubscriptionManager.shared.willAutoRenew
             let infoText: String
             let actionTitle: String
             
             if isAutoRenew {
                 infoText = L("subscription.auto_renew") + dateStr
                 actionTitle = L("subscription.action.cancel")
             } else {
                 infoText = L("subscription.expires_prefix") + dateStr
                 actionTitle = L("subscription.action.subscribe")
             }

             let monthly = createProductView(
                title: L("subscription.monthly"),
                price: monthlyPrice + L("subscription.price.monthly"),
                desc: isAutoRenew ? (L("subscription.desc.monthly.prefix") + monthlyPrice + L("subscription.desc.monthly.suffix")) : L("subscription.desc.cancelled"),
                actionTitle: actionTitle,
                isActionDestructive: isAutoRenew,
                extraInfo: infoText) {
                    if isAutoRenew {
                        SubscriptionManager.shared.cancelSubscription()
                    } else {
                        SubscriptionManager.shared.purchase(type: .monthly)
                    }
                }
            mainStack.addArrangedSubview(monthly)
        }
        
        // Show Yearly upgrade option if monthly? Or show both?
        // Design 2 shows Monthly (Active) then Yearly (Option).
        let yearly = createProductView(
            title: L("subscription.yearly"),
            price: yearlyPrice + L("subscription.price.yearly"),
            desc: L("subscription.desc.yearly"),
            actionTitle: L("subscription.action.subscribe"),
            isActionDestructive: false) {
                SubscriptionManager.shared.purchase(type: .yearly)
            }
        mainStack.addArrangedSubview(yearly)
        
    }
    
    private func createProductView(title: String, price: String, desc: String, actionTitle: String, isActionDestructive: Bool, extraInfo: String? = nil, action: @escaping () -> Void) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0) // #2C2C2C
        container.layer.cornerRadius = 12
        
        // Top Row: Title + Price | Button
        let topRow = UIView()
        topRow.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLab = UILabel()
        titleLab.text = title
        titleLab.textColor = .white
        titleLab.font = UIFont(name: "PingFangSC-Medium", size: 18)
        
        let priceLab = UILabel()
        priceLab.text = price
        priceLab.textColor = UIColor(red: 172/255, green: 143/255, blue: 255/255, alpha: 1.0) // #AC8FFF
        priceLab.font = UIFont(name: "PingFangSC-Semibold", size: 11)
        
        let textStack = UIStackView(arrangedSubviews: [titleLab, priceLab])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        let button = UIButton(type: .system)
        button.setTitle(actionTitle, for: .normal)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 11)
        
        if isActionDestructive {
            // Cancel Subscription: Purple BG, White Text
            button.backgroundColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0) // #8054FE
            button.setTitleColor(.white, for: .normal)
            button.layer.borderWidth = 0
        } else {
            // Subscribe: White BG, Purple Text
            button.backgroundColor = .white
            button.setTitleColor(UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0), for: .normal) // #8054FE
            button.layer.borderWidth = 0
        }
        
        button.layer.cornerRadius = 15
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 15, bottom: 5, trailing: 15)
            button.configuration = config
        } else {
            button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 15, bottom: 5, right: 15)
        }
        button.addAction(UIAction(handler: { [weak button] _ in
            button?.animateButtonTap {
                action()
            }
        }), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        topRow.addSubview(textStack)
        topRow.addSubview(button)
        
        container.addSubview(topRow)
        
        // Extra Info (Auto Renew Date)
        var lastView: UIView = topRow
        
        if let info = extraInfo {
            let infoLabel = UILabel()
            infoLabel.text = info
            infoLabel.font = UIFont(name: "PingFangSC-Regular", size: 11)
            infoLabel.textColor = .white
            infoLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(infoLabel)
            
            NSLayoutConstraint.activate([
                infoLabel.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 5),
                infoLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
                infoLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15)
            ])
            lastView = infoLabel
        }
        
        // Separator - Dashed? User requested SketchPng8683...
        // Use custom dashed line view
        let separatorFn = {
            let v = SubscriptionLineSeparatorView(style: .dashed)
            v.translatesAutoresizingMaskIntoConstraints = false
            return v
        }()

        
        let descLab = UILabel()
        descLab.text = desc
        descLab.numberOfLines = 0
        descLab.font = UIFont.systemFont(ofSize: 12)
        descLab.textColor = .lightGray
        descLab.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(separatorFn)
        container.addSubview(descLab)
        
        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: container.topAnchor, constant: 15),
            topRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            topRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            
            textStack.leadingAnchor.constraint(equalTo: topRow.leadingAnchor),
            textStack.centerYAnchor.constraint(equalTo: topRow.centerYAnchor),
            
            button.trailingAnchor.constraint(equalTo: topRow.trailingAnchor),
            button.centerYAnchor.constraint(equalTo: topRow.centerYAnchor),
            button.heightAnchor.constraint(equalToConstant: 30),
            
            topRow.heightAnchor.constraint(equalToConstant: 40),
            
            separatorFn.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 10),
            separatorFn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            separatorFn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            separatorFn.heightAnchor.constraint(equalToConstant: 1),
            
            descLab.topAnchor.constraint(equalTo: separatorFn.bottomAnchor, constant: 10),
            descLab.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            descLab.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            descLab.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -15)
        ])
        
        return container
    }
    
    private func createFeaturesSection() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0) // #2C2C2C
        container.layer.cornerRadius = 12
        
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = L("subscription.exclusive")
        titleLabel.font = UIFont(name: "PingFangSC-Semibold", size: 16)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(titleLabel)
        container.addSubview(headerView)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let features = [
            ("sub_bf_line1", L("subscription.feature.1")),
            ("sub_bf_line2", L("subscription.feature.2")),
            ("sub_bf_line3", L("subscription.feature.3"))
        ]
        
        for (imgName, text) in features {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            row.alignment = .top // Align top in case of multiline
            
            let icon = UIImageView(image: UIImage(named: imgName))
            icon.contentMode = .scaleAspectFit
            // Need constraint for icon size? Assuming images are proper size.
            icon.widthAnchor.constraint(equalToConstant: 20).isActive = true // Approx
            icon.heightAnchor.constraint(equalToConstant: 20).isActive = true
            
            let label = UILabel()
            label.text = text
            label.numberOfLines = 0
            label.font = UIFont.systemFont(ofSize: 14)
            label.textColor = .white
            
            row.addArrangedSubview(icon)
            row.addArrangedSubview(label)
            stack.addArrangedSubview(row)
        }
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: container.topAnchor, constant: 15),
            headerView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            headerView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            
            stack.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 15),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -15)
        ])
        
        return container
    }

    private func createFooterSection() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0) // #2C2C2C
        container.layer.cornerRadius = 12
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0 // Using separators manually
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let itemKeys = [
            "subscription.help.faq",
            "subscription.help.message",
            "subscription.help.renewal",
            "subscription.help.restore",
            "subscription.help.community",
            "subscription.help.contact"
        ]
        
        for (index, key) in itemKeys.enumerated() {
            let btn = UIButton()
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
            btn.tag = index
            btn.addTarget(self, action: #selector(handleHelpItemTap(_:)), for: .touchUpInside)
            
            let label = UILabel()
            label.text = L(key)
            label.font = UIFont.systemFont(ofSize: 14)
            label.textColor = .white
            label.translatesAutoresizingMaskIntoConstraints = false
            
            let arrow = UIImageView(image: UIImage(named: "enter_icon")) // or system chevron
            arrow.contentMode = .scaleAspectFit
            arrow.translatesAutoresizingMaskIntoConstraints = false
            
            btn.addSubview(label)
            btn.addSubview(arrow)
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: btn.leadingAnchor),
                label.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
                
                arrow.trailingAnchor.constraint(equalTo: btn.trailingAnchor),
                arrow.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
                arrow.widthAnchor.constraint(equalToConstant: 12),
                arrow.heightAnchor.constraint(equalToConstant: 12)
            ])
            
            stack.addArrangedSubview(btn)
            
            // Add Separator below item (except last?) Use solid separator.
            if index != itemKeys.count - 1 {
                let sep = SubscriptionLineSeparatorView(style: .solid)
                sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stack.addArrangedSubview(sep)
            }
        }
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])
        
        return container
    }

    @objc private func handleHelpItemTap(_ sender: UIButton) {
        // 0: faq, 1: message, 2: renewal, 3: restore, 4: community, 5: contact
        switch sender.tag {
        case 0:
            let vc = FAQViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        case 1:
            // Message - Same as Notifications in SideMenu
            let vc = NotificationsViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        case 2:
            let vc = RenewalManagementViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        case 3:
            handleRestore()
        case 4:
            // Community - Same as noDeviceButtonTapped in StartViewController
            guard let url = URL(string: Constants.Network.mindoraWebURL) else { return }
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .pageSheet
            self.present(safariVC, animated: true)
        case 5:
            let vc = HelpViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        default:
            break
        }
    }

    private func handleRestore() {
        let alert = UIAlertController(title: nil, message: L("subscription.restore.loading"), preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        indicator.hidesWhenStopped = true
        indicator.style = .medium
        indicator.startAnimating()
        alert.view.addSubview(indicator)
        
        present(alert, animated: true) { [weak self] in
            Task {
                await SubscriptionManager.shared.restore()
                await MainActor.run {
                    alert.dismiss(animated: true) {
                        self?.showRestoreResult()
                    }
                }
            }
        }
    }
    
    private func showRestoreResult() {
        let isSubscribed = SubscriptionManager.shared.isSubscribed
        let message = isSubscribed ? L("subscription.restore.success") : L("subscription.restore.no_purchases")
        
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.ok"), style: .default))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func handleEmailTap() {
        emailIcon.animateButtonTap {
            self.sendEmail()
        }
    }
    
    private func sendEmail() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients([Constants.Contact.supportEmail])
            mail.setSubject(L("subscription.email.subject"))
            
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let osVersion = UIDevice.current.systemVersion
            let deviceModel = UIDevice.current.model
            
            let appVerTitle = L("subscription.email.app_version")
            let iosVerTitle = L("subscription.email.ios_version")
            let deviceTitle = L("subscription.email.device")
            
            let body = """
            
            
            -------------------
            \(appVerTitle): \(appVersion)
            \(iosVerTitle): \(osVersion)
            \(deviceTitle): \(deviceModel)
            """
            
            mail.setMessageBody(body, isHTML: false)
            present(mail, animated: true)
        } else {
            let alert = UIAlertController(title: L("subscription.email.error.title"), message: L("subscription.email.error.message"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("common.ok"), style: .default))
            present(alert, animated: true)
        }
    }
    
    // MARK: - MFMailComposeViewControllerDelegate
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

    @objc private func handleBack() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - LineSeparatorView

class SubscriptionLineSeparatorView: UIView {
    enum Style {
        case solid
        case dashed
    }
    
    private var style: Style
    private let calendarLayer = CALayer()
    
    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        self.style = .solid
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        if style == .dashed {
            let shapeLayer = CAShapeLayer()
            shapeLayer.strokeColor = UIColor(white: 1, alpha: 0.2).cgColor // Slightly transparent for subtle effect
            shapeLayer.lineWidth = 1
            shapeLayer.lineDashPattern = [4, 4] 
            layer.addSublayer(shapeLayer)
        } else {
            calendarLayer.backgroundColor = UIColor(white: 1, alpha: 0.1).cgColor // Faint separator
            layer.addSublayer(calendarLayer)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if style == .dashed {
            if let shapeLayer = layer.sublayers?.first as? CAShapeLayer {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: bounds.height / 2))
                path.addLine(to: CGPoint(x: bounds.width, y: bounds.height / 2))
                shapeLayer.path = path.cgPath
            }
        } else {
            calendarLayer.frame = bounds
        }
    }
}
