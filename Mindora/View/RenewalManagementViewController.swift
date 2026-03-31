//
//  RenewalManagementViewController.swift
//  mindora
//
//  Created by Handover on 2026/02/02.
//

import UIKit
import StoreKit

class RenewalManagementViewController: UIViewController {

    // MARK: - Properties
    
    // MARK: - UI Components
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L("renewal.title")
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
    
    // Separator under the navigation bar
    private let navSeparatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let yourSubscriptionLabel: UILabel = {
        let label = UILabel()
        label.text = L("renewal.your_subscription")
        label.font = UIFont(name: "PingFangSC-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // The main card container
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0) // 2C2C2C
        view.layer.cornerRadius = 18
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Content inside the card
    private let cardStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1.0) // #181818
        
        setupUI()
        setupActions()
        updateContent()
        
        // Listen for subscription updates
        NotificationCenter.default.addObserver(self, selector: #selector(updateContent), name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Setup Nav Separator Layer
        if navSeparatorView.layer.sublayers == nil {
            let borderLayer = CALayer()
            // #E4E4E4 at 20% opacity
            borderLayer.backgroundColor = UIColor(red: 228/255, green: 228/255, blue: 228/255, alpha: 0.2).cgColor
            borderLayer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 0.5)
            navSeparatorView.layer.addSublayer(borderLayer)
        } else if let layer = navSeparatorView.layer.sublayers?.first {
             layer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 0.5)
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(backButton)
        view.addSubview(navSeparatorView)
        
        view.addSubview(yourSubscriptionLabel)
        view.addSubview(cardView)
        cardView.addSubview(cardStack)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        // Nav items
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            
            navSeparatorView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 10),
            navSeparatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navSeparatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navSeparatorView.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
        // Content
        NSLayoutConstraint.activate([
            yourSubscriptionLabel.topAnchor.constraint(equalTo: navSeparatorView.bottomAnchor, constant: 30),
            yourSubscriptionLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            
            cardView.topAnchor.constraint(equalTo: yourSubscriptionLabel.bottomAnchor, constant: 15),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            cardStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            cardStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            cardStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            cardStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func updateContent() {
        // Clear existing views
        cardStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        setupCardContent()
    }
    
    private func setupCardContent() {
        // 1. Header: Image + My MIDORA
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        // Image "renewal_manage_dev.png"
        let iconView = UIImageView(image: UIImage(named: "renewal_manage_dev"))
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let productNameLabel = UILabel()
        productNameLabel.text = L("renewal.product_name")
        productNameLabel.font = UIFont(name: "PingFangSC-Semibold", size: 16) ?? .boldSystemFont(ofSize: 16)
        productNameLabel.textColor = .white
        productNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerContainer.addSubview(iconView)
        headerContainer.addSubview(productNameLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24), // Assuming icon size
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            productNameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            productNameLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor)
        ])
        
        cardStack.addArrangedSubview(headerContainer)
        
        // Padding after header
        addSpacer(height: 20)
        addSeparator()
        addSpacer(height: 20)
        
        // Get data from SubscriptionManager
        let manager = SubscriptionManager.shared
        
        // 2. Plan (Subscription Scheme)
        let planText: String
        switch manager.currentPlan {
        case .monthly:
            planText = L("renewal.plan.monthly")
        case .yearly:
            planText = L("renewal.plan.yearly")
        default:
            // "renewal.plan.none" -> "No Subscription" / "无订阅"
            planText = L("renewal.plan.none")
        }
        addDetailRow(title: L("renewal.plan"), value: planText)
        
        addSpacer(height: 15)
        addSeparator()
        addSpacer(height: 15)
        
        // 3. Renewal Date
        let dateString: String
        if manager.isSubscribed {
            let dateFormatter = DateFormatter()
            // If system locale is Chinese, force Chinese format like "2026年2月15日"
            // else use medium date style
            if Locale.current.identifier.hasPrefix("zh") {
                dateFormatter.dateFormat = "yyyy年M月d日"
            } else {
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
            }
            dateString = dateFormatter.string(from: manager.expiryDate)
        } else {
            dateString = "-"
        }
        addDetailRow(title: L("renewal.renewal_date"), value: dateString)
        
        addSpacer(height: 15)
        addSeparator()
        addSpacer(height: 15)
        
        // 4. Amount (Deduction Amount)
        // Find product price
        let amountText: String
        if let product = manager.products.first(where: {
            if manager.currentPlan == .monthly {
                return $0.id == Constants.Subscription.monthlyProductID
            } else if manager.currentPlan == .yearly {
                return $0.id == Constants.Subscription.yearlyProductID
            }
            return false
        }) {
            amountText = product.displayPrice
        } else {
             // Fallback if products not loaded or free
            amountText = "-"
        }
        
        addDetailRow(title: L("renewal.amount"), value: amountText)
        
        addSpacer(height: 15)
        addSeparator()
        addSpacer(height: 15)
        
        // 5. Manage Button
        let manageButtonContainer = UIView()
        manageButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        manageButtonContainer.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        let manageLabel = UILabel()
        manageLabel.text = L("renewal.manage")
        // Manage Button: 32px -> 16pt, Medium, #4188F7
        manageLabel.font = UIFont(name: "PingFangSC-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        manageLabel.textColor = UIColor(red: 65/255, green: 136/255, blue: 247/255, alpha: 1.0)
        manageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        manageButtonContainer.addSubview(manageLabel)
        NSLayoutConstraint.activate([
            manageLabel.centerXAnchor.constraint(equalTo: manageButtonContainer.centerXAnchor),
            manageLabel.centerYAnchor.constraint(equalTo: manageButtonContainer.centerYAnchor)
        ])
        
        // Make it tappable
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleManage))
        manageButtonContainer.addGestureRecognizer(tap)
        manageButtonContainer.isUserInteractionEnabled = true
        
        cardStack.addArrangedSubview(manageButtonContainer)
    }
    
    // MARK: - Helpers
    
    private func addDetailRow(title: String, value: String) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        // Labels: 24px -> 12pt, Regular, White
        titleLabel.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        // Values: 24px -> 12pt, Light, White
        valueLabel.font = UIFont(name: "PingFangSC-Light", size: 12) ?? .systemFont(ofSize: 12, weight: .light)
        valueLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        cardStack.addArrangedSubview(container)
    }
    
    private func addSpacer(height: CGFloat) {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        cardStack.addArrangedSubview(view)
    }
    
    private func addSeparator() {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        // #FFFFFF at 40% opacity
        view.backgroundColor = UIColor(white: 1.0, alpha: 0.4)
        cardStack.addArrangedSubview(view)
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
    }
    
    @objc private func handleBack() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func handleManage() {
        // Handle manage subscription action (e.g. open App Store)
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}
