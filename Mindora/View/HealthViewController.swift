import UIKit

final class HealthViewController: UIViewController {

    // MARK: - Legacy Support (Kept for compilation of unused views)
    let designWidth: CGFloat = 1242
    let designHeight: CGFloat = 2688
    let designItemCornerRadius: CGFloat = 38
    
    func scale(_ designValue: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        return designValue * (dimension / designDimension)
    }

    // MARK: - UI Components
    private let headerView = UIView()
    
    private let sideBarButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "home_side_bar"), for: .normal)
        return button
    }()
    
    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "logo"))
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    // Custom Segment Control
    private let segmentContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 44/255.0, green: 44/255.0, blue: 44/255.0, alpha: 1.0)
        // Design: header 24px radius @ 2x => 12pt
        view.layer.cornerRadius = 12
        return view
    }()
    
    private var segmentButtons: [UIButton] = []
    private var separators: [UIView] = []
    private let segments = ["health.segment.day", "health.segment.week", "health.segment.month"]
    private var selectedSegmentIndex = 0

    // Pending scroll target from Home navigation — now handled by HealthDayView
    
    // Content Container
    private let contentContainer = UIView()
    private let dayView = HealthDayView()
    private let weekView: HealthWeekView = {
        let view = HealthWeekView()
        view.isHidden = true
        return view
    }()
    private let monthView: HealthMonthView = {
        let view = HealthMonthView()
        view.isHidden = true
        return view
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        setupUI()
        updateSegmentSelection()
        
        setupMembershipLogic()
        setupDebugInteractions()
        
        // Listen for subscription status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSubscriptionStatusChanged),
            name: NSNotification.Name("SubscriptionStatusChanged"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleSubscriptionStatusChanged() {
        updateMembershipStatus()
    }
    
    private func setupMembershipLogic() {
        // Use actual subscription status from SubscriptionManager
        updateMembershipStatus()
        
        let showSubscription = { [weak self] in
            let vc = SubscriptionViewController()
            // Assuming we are in a navigation stack or fallback to present
            if let nav = self?.navigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                self?.present(vc, animated: true)
            }
        }
        
        weekView.onSubscribeTap = showSubscription
        monthView.onSubscribeTap = showSubscription
    }
    
    private func updateMembershipStatus() {
        let isMember = SubscriptionManager.shared.isSubscribed
        weekView.isMember = isMember
        monthView.isMember = isMember
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        // Refresh membership status when view appears (in case user subscribed)
        updateMembershipStatus()
        refreshHealthDataIfNeeded()
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        view.addSubview(headerView)
        view.addSubview(segmentContainer)
        view.addSubview(contentContainer)
        
        headerView.translatesAutoresizingMaskIntoConstraints = false
        segmentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Header Layout
        headerView.addSubview(sideBarButton)
        headerView.addSubview(logoImageView)
        sideBarButton.translatesAutoresizingMaskIntoConstraints = false
        sideBarButton.addTarget(self, action: #selector(handleSideBarBtnTapped), for: .touchUpInside)
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            sideBarButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            sideBarButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            sideBarButton.widthAnchor.constraint(equalToConstant: 24),
            sideBarButton.heightAnchor.constraint(equalToConstant: 24),
            
            logoImageView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            logoImageView.heightAnchor.constraint(equalToConstant: 30),
            logoImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 200)
        ])
        
        // Segment Control Layout
        NSLayoutConstraint.activate([
            segmentContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            segmentContainer.heightAnchor.constraint(equalToConstant: 44),
            segmentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        setupSegments()
        
        // Content Container Layout
        contentContainer.addSubview(dayView)
        contentContainer.addSubview(weekView)
        contentContainer.addSubview(monthView)
        
        dayView.translatesAutoresizingMaskIntoConstraints = false
        weekView.translatesAutoresizingMaskIntoConstraints = false
        monthView.translatesAutoresizingMaskIntoConstraints = false
        
        // Disable clipping so overlay can extend beyond container bounds
        contentContainer.clipsToBounds = false
        
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: segmentContainer.bottomAnchor, constant: 20),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            dayView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            dayView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            dayView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            dayView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            
            weekView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            weekView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            weekView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            weekView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            
            monthView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            monthView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            monthView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            monthView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }
    
    private func setupSegments() {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 0 
        stackView.distribution = .fillProportionally
        
        segmentContainer.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        // Design: Padding 8px -> 4pt
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: segmentContainer.topAnchor, constant: 4),
            stackView.leadingAnchor.constraint(equalTo: segmentContainer.leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: segmentContainer.trailingAnchor, constant: -4),
            stackView.bottomAnchor.constraint(equalTo: segmentContainer.bottomAnchor, constant: -4)
        ])
        
        for (index, key) in segments.enumerated() {
            // Add separator if not first item
            if index > 0 {
                let separatorContainer = UIView()
                separatorContainer.translatesAutoresizingMaskIntoConstraints = false
                separatorContainer.widthAnchor.constraint(equalToConstant: 1).isActive = true
                
                let separator = UIView()
                separator.backgroundColor = UIColor(white: 1.0, alpha: 0.3)
                separator.translatesAutoresizingMaskIntoConstraints = false
                separatorContainer.addSubview(separator)
                
                // Design: Separator height 36px -> 18pt
                NSLayoutConstraint.activate([
                    separator.widthAnchor.constraint(equalToConstant: 1),
                    separator.heightAnchor.constraint(equalToConstant: 18),
                    separator.centerYAnchor.constraint(equalTo: separatorContainer.centerYAnchor),
                    separator.centerXAnchor.constraint(equalTo: separatorContainer.centerXAnchor)
                ])
                
                stackView.addArrangedSubview(separatorContainer)
                separators.append(separatorContainer)
            }
            
            let button = UIButton(type: .custom)
            button.setTitle(L(key).uppercased(), for: .normal)
            // Design: Font 24px -> 12pt, adjustable
            button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            button.setTitleColor(.white, for: .selected)
            button.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
            button.tag = index
            // Design: Radius 24px -> 12pt
            button.layer.cornerRadius = 12
            button.addTarget(self, action: #selector(segmentTapped(_:)), for: .touchUpInside)
            
            stackView.addArrangedSubview(button)
            segmentButtons.append(button)
            
            // Equal width buttons
            if index > 0 {
                button.widthAnchor.constraint(equalTo: segmentButtons[0].widthAnchor).isActive = true
            }
        }
    }
    
    @objc private func segmentTapped(_ sender: UIButton) {
        selectedSegmentIndex = sender.tag
        updateSegmentSelection()
        reloadSelectedSegmentIfNeeded()
    }
    
    private func updateSegmentSelection() {
        for (index, button) in segmentButtons.enumerated() {
            if index == selectedSegmentIndex {
                button.isSelected = true
                button.backgroundColor = UIColor(red: 128/255.0, green: 84/255.0, blue: 254/255.0, alpha: 1.0)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            } else {
                button.isSelected = false
                button.backgroundColor = .clear
                button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            }
        }
        
        // Update separators visibility
        // Separator i is between button i and button i+1
        // It corresponds to separators[i] in the array? No, separators array has size count-1.
        // separators[0] is between 0 and 1.
        // separators[1] is between 1 and 2.
        
        for (index, separator) in separators.enumerated() {
            // Separator at 'index' connects button 'index' and button 'index + 1'
            let isLeftSelected = (index == selectedSegmentIndex)
            let isRightSelected = (index + 1 == selectedSegmentIndex)
            
            separator.isHidden = isLeftSelected || isRightSelected
            separator.alpha = separator.isHidden ? 0 : 1
        }
        
        dayView.isHidden = selectedSegmentIndex != 0
        weekView.isHidden = selectedSegmentIndex != 1
        monthView.isHidden = selectedSegmentIndex != 2
        
        if selectedSegmentIndex == 2 && monthView.subviews.isEmpty {
            let label = UILabel()
            label.text = "Month View Coming Soon"
            label.textColor = .white
            monthView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.centerXAnchor.constraint(equalTo: monthView.centerXAnchor).isActive = true
            label.centerYAnchor.constraint(equalTo: monthView.centerYAnchor).isActive = true
        }
    }
    
    // MARK: - Action Methods
    @objc private func handleSideBarBtnTapped() {
        let sideMenuVC = SideMenuViewController()
        sideMenuVC.modalPresentationStyle = .overFullScreen
        self.present(sideMenuVC, animated: false, completion: nil)
    }
    
    // MARK: - Debug Interactions
    private func setupDebugInteractions() {
        #if DEBUG
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDebugToggle))
        tapGesture.numberOfTapsRequired = 3
        logoImageView.addGestureRecognizer(tapGesture)
        logoImageView.isUserInteractionEnabled = true
        #endif
    }
    
    @objc private func handleDebugToggle() {
        #if DEBUG
        Constants.Config.showMockData.toggle()
        refreshAllHealthViews()
        #endif
    }

    private func refreshHealthDataIfNeeded() {
        guard !Constants.Config.showMockData else { return }
        refreshAllHealthViews()
    }

    private func reloadSelectedSegmentIfNeeded() {
        guard !Constants.Config.showMockData else { return }

        switch selectedSegmentIndex {
        case 0:
            dayView.reloadData()
        case 1:
            weekView.reloadData()
        case 2:
            monthView.reloadData()
        default:
            break
        }
    }

    private func refreshAllHealthViews() {
        dayView.reloadData()
        weekView.reloadData()
        monthView.reloadData()
    }
    
    // MARK: - Navigation from Home
    /// Switch to Day segment and scroll to the specified section
    func navigateToDaySection(scrollTarget: HealthDayScrollTarget) {
        #if DEBUG
        print("[HealthViewController] navigateToDaySection target=\(scrollTarget.rawValue)")
        #endif

        loadViewIfNeeded()

        // Ensure Day segment is selected
        selectedSegmentIndex = 0
        updateSegmentSelection()

        view.setNeedsLayout()
        view.layoutIfNeeded()
        contentContainer.setNeedsLayout()
        contentContainer.layoutIfNeeded()
        dayView.setNeedsLayout()
        dayView.layoutIfNeeded()
        
        // Delegate to dayView — it will defer scrolling until its own
        // layoutSubviews confirms the inner scrollView content is ready.
        dayView.scrollToSection(scrollTarget)
    }
}


