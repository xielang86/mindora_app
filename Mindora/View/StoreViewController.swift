import UIKit

final class StoreViewController: UIViewController {
    
    // MARK: - Constants
    private let purpleColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0)
    
    // MARK: - UI Components
    private let headerView = UIView()
    
    private let sideBarButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "home_side_bar_black"), for: .normal)
        return button
    }()
    
    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "logo_black"))
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private let searchButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "store_search"), for: .normal)
        return button
    }()
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        return sv
    }()
    
    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        setupHeader()
        setupScrollView()
        setupBanner()
        setupMemberExclusiveSection()
        setupPromoSection()
        setupNewArrivalsSection()
    }
    
    private func setupHeader() {
        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(sideBarButton)
        headerView.addSubview(logoImageView)
        headerView.addSubview(searchButton)
        sideBarButton.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        
        sideBarButton.addTarget(self, action: #selector(handleSideBarBtnTapped), for: .touchUpInside)
        searchButton.addTarget(self, action: #selector(handleSearchButtonTapped), for: .touchUpInside)
        
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
            logoImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            
            searchButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            searchButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 24),
            searchButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    // MARK: - Banner Section
    
    /// The last view added to contentView, used to chain vertical constraints
    private var lastAnchorView: UIView?
    private var lastAnchorBottom: NSLayoutYAxisAnchor {
        return lastAnchorView?.bottomAnchor ?? contentView.topAnchor
    }
    
    private func setupBanner() {
        // Banner background image
        let bannerView = UIImageView(image: UIImage(named: "store_banner_bg"))
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.contentMode = .scaleAspectFill
        bannerView.clipsToBounds = true
        bannerView.isUserInteractionEnabled = true
        contentView.addSubview(bannerView)
        
        // Banner title
        let bannerTitle = UILabel()
        bannerTitle.translatesAutoresizingMaskIntoConstraints = false
        bannerTitle.text = L("store.banner.title")
        bannerTitle.textColor = .white
        bannerTitle.font = UIFont.systemFont(ofSize: 30, weight: .light)
        bannerTitle.numberOfLines = 0
        bannerTitle.textAlignment = .center
        bannerView.addSubview(bannerTitle)
        
        // Divider line 1
        let divider1 = UIImageView(image: UIImage(named: "store_divider"))
        divider1.translatesAutoresizingMaskIntoConstraints = false
        divider1.contentMode = .scaleAspectFit
        bannerView.addSubview(divider1)
        
        // Discount text
        let discountLabel = UILabel()
        discountLabel.translatesAutoresizingMaskIntoConstraints = false
        let discountAttr = NSMutableAttributedString()
        discountAttr.append(NSAttributedString(string: L("store.banner.discount_prefix"), attributes: [
            .font: UIFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.white
        ]))
        discountAttr.append(NSAttributedString(string: L("store.banner.discount_value"), attributes: [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor.white
        ]))
        discountAttr.append(NSAttributedString(string: L("store.banner.discount_suffix"), attributes: [
            .font: UIFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.white
        ]))
        discountLabel.attributedText = discountAttr
        discountLabel.textAlignment = .center
        bannerView.addSubview(discountLabel)
        
        // Divider line 2
        let divider2 = UIImageView(image: UIImage(named: "store_divider"))
        divider2.translatesAutoresizingMaskIntoConstraints = false
        divider2.contentMode = .scaleAspectFit
        bannerView.addSubview(divider2)
        
        // Learn More button
        let learnMoreBtn = UIButton(type: .system)
        learnMoreBtn.translatesAutoresizingMaskIntoConstraints = false
        learnMoreBtn.setTitle(L("store.banner.learn_more"), for: .normal)
        learnMoreBtn.setTitleColor(.white, for: .normal)
        learnMoreBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        learnMoreBtn.layer.cornerRadius = 8
        learnMoreBtn.layer.borderWidth = 1
        learnMoreBtn.layer.borderColor = UIColor.white.cgColor
        learnMoreBtn.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
        bannerView.addSubview(learnMoreBtn)
        
        // Page dots
        let dotsView = UIImageView(image: UIImage(named: "store_page_dots"))
        dotsView.translatesAutoresizingMaskIntoConstraints = false
        dotsView.contentMode = .scaleAspectFit
        bannerView.addSubview(dotsView)
        
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bannerView.heightAnchor.constraint(equalTo: bannerView.widthAnchor, multiplier: 0.95),
            
            bannerTitle.topAnchor.constraint(equalTo: bannerView.topAnchor, constant: 54),
            bannerTitle.centerXAnchor.constraint(equalTo: bannerView.centerXAnchor),
            bannerTitle.widthAnchor.constraint(lessThanOrEqualTo: bannerView.widthAnchor, multiplier: 0.6),
            
            divider1.topAnchor.constraint(equalTo: bannerTitle.bottomAnchor, constant: 22),
            divider1.centerXAnchor.constraint(equalTo: bannerView.centerXAnchor),
            divider1.widthAnchor.constraint(equalTo: bannerView.widthAnchor, multiplier: 0.54),
            divider1.heightAnchor.constraint(equalToConstant: 1),
            
            discountLabel.topAnchor.constraint(equalTo: divider1.bottomAnchor, constant: 5),
            discountLabel.centerXAnchor.constraint(equalTo: bannerView.centerXAnchor),
            
            divider2.topAnchor.constraint(equalTo: discountLabel.bottomAnchor, constant: 4),
            divider2.centerXAnchor.constraint(equalTo: bannerView.centerXAnchor),
            divider2.widthAnchor.constraint(equalTo: divider1.widthAnchor),
            divider2.heightAnchor.constraint(equalToConstant: 1),
            
            learnMoreBtn.bottomAnchor.constraint(equalTo: dotsView.topAnchor, constant: -32),
            learnMoreBtn.centerXAnchor.constraint(equalTo: bannerView.centerXAnchor),
            learnMoreBtn.widthAnchor.constraint(equalToConstant: 118),
            learnMoreBtn.heightAnchor.constraint(equalToConstant: 29),
            
            dotsView.bottomAnchor.constraint(equalTo: bannerView.bottomAnchor, constant: -16),
            dotsView.centerXAnchor.constraint(equalTo: bannerView.centerXAnchor),
            dotsView.widthAnchor.constraint(equalToConstant: 28),
            dotsView.heightAnchor.constraint(equalToConstant: 4)
        ])
        
        lastAnchorView = bannerView
    }
    
    // MARK: - Member Exclusive Section
    
    private func setupMemberExclusiveSection() {
        // Section Title
        let sectionTitle = makeSectionTitle(L("store.section.member_exclusive"))
        contentView.addSubview(sectionTitle)
        
        NSLayoutConstraint.activate([
            sectionTitle.topAnchor.constraint(equalTo: lastAnchorBottom, constant: 30),
            sectionTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            sectionTitle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24)
        ])
        
        // Featured Card (combo oil)
        let featuredCard = makeFeaturedProductCard(
            backgroundImage: "store_featured_card_bg",
            productImage: "store_featured_card_image",
            badgeText: L("store.badge.hot"),
            name: L("store.product.combo_oil"),
            price: "$56.97USD",
            originalPrice: "$59.97USD"
        )
        contentView.addSubview(featuredCard)
        
        NSLayoutConstraint.activate([
            featuredCard.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 16),
            featuredCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            featuredCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
        
        // Two small product cards row
        let productRow = makeProductPairRow(
            card1Background: "store_product_oil1_card",
            card1Image: "store_product_oil1_image",
            card1Name: L("store.product.frankincense_oil"),
            card1Price: "$19.99USD",
            card2Background: "store_product_oil2_card",
            card2Image: "store_product_oil2_image",
            card2Name: L("store.product.calming_oil"),
            card2Price: "$19.99USD"
        )
        contentView.addSubview(productRow)
        
        NSLayoutConstraint.activate([
            productRow.topAnchor.constraint(equalTo: featuredCard.bottomAnchor, constant: 7),
            productRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            productRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
        
        lastAnchorView = productRow
    }
    
    // MARK: - Promo Section
    
    private func setupPromoSection() {
        let promoContainer = UIView()
        promoContainer.translatesAutoresizingMaskIntoConstraints = false
        promoContainer.clipsToBounds = true
        contentView.addSubview(promoContainer)
        
        // Background image (right side beige with "15% OFF")
        let promoBg = UIImageView(image: UIImage(named: "store_promo_bg"))
        promoBg.translatesAutoresizingMaskIntoConstraints = false
        promoBg.contentMode = .scaleAspectFill
        promoBg.clipsToBounds = true
        promoContainer.addSubview(promoBg)
        
        // Left image (woman on couch)
        let promoLeft = UIImageView(image: UIImage(named: "store_promo_left"))
        promoLeft.translatesAutoresizingMaskIntoConstraints = false
        promoLeft.contentMode = .scaleAspectFill
        promoLeft.clipsToBounds = true
        promoContainer.addSubview(promoLeft)
        
        // Close (X) button — SF Symbol xmark
        let closeBtn = UIButton(type: .system)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        let xConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        closeBtn.setImage(UIImage(systemName: "xmark", withConfiguration: xConfig), for: .normal)
        closeBtn.tintColor = UIColor(red: 120/255, green: 120/255, blue: 120/255, alpha: 1.0)
        promoContainer.addSubview(closeBtn)
        
        // "WOULD   YOU   LIKE" — three separate labels in a horizontal stack
        // Design: Kano-regular 18px(=9pt), dark color on beige background
        let wordFont = UIFont.systemFont(ofSize: 9, weight: .regular)
        let wordColor = UIColor(red: 50/255, green: 50/255, blue: 50/255, alpha: 1.0)
        
        let wouldWord = UILabel()
        wouldWord.text = "WOULD"
        wouldWord.font = wordFont
        wouldWord.textColor = wordColor
        
        let youWord = UILabel()
        youWord.text = "YOU"
        youWord.font = wordFont
        youWord.textColor = wordColor
        
        let likeWord = UILabel()
        likeWord.text = "LIKE"
        likeWord.font = wordFont
        likeWord.textColor = wordColor
        
        let wouldStack = UIStackView(arrangedSubviews: [wouldWord, youWord, likeWord])
        wouldStack.translatesAutoresizingMaskIntoConstraints = false
        wouldStack.axis = .horizontal
        wouldStack.distribution = .equalSpacing
        promoContainer.addSubview(wouldStack)
        
        // YES Button — Design: 18px(=9pt) Kano-regular, black bg, borderRadius 8
        let yesBtn = UIButton(type: .system)
        yesBtn.translatesAutoresizingMaskIntoConstraints = false
        yesBtn.setTitle("YES", for: .normal)
        yesBtn.setTitleColor(.white, for: .normal)
        yesBtn.titleLabel?.font = UIFont.systemFont(ofSize: 9, weight: .regular)
        yesBtn.backgroundColor = .black
        yesBtn.layer.cornerRadius = 8
        promoContainer.addSubview(yesBtn)
        
        // NO THANKS — with underline, 18px(=9pt) Kano-regular
        let noLabel = UILabel()
        noLabel.translatesAutoresizingMaskIntoConstraints = false
        noLabel.textAlignment = .center
        let noAttr = NSAttributedString(
            string: "NO THANKS",
            attributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.black,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        noLabel.attributedText = noAttr
        promoContainer.addSubview(noLabel)
        
        // Layout guide for right half area
        let centerGuide = UILayoutGuide()
        promoContainer.addLayoutGuide(centerGuide)
        
        // Proportional spacing guides (based on design: 750×540 @2x)
        // Top space: 165/540 = 0.306 of height (from top to WOULD YOU LIKE)
        let topSpacing = UILayoutGuide()
        promoContainer.addLayoutGuide(topSpacing)
        
        // Mid space: 161/540 = 0.298 of height (from WOULD YOU LIKE bottom to YES top)
        let midSpacing = UILayoutGuide()
        promoContainer.addLayoutGuide(midSpacing)
        
        NSLayoutConstraint.activate([
            promoContainer.topAnchor.constraint(equalTo: lastAnchorBottom, constant: 0),
            promoContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            promoContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            promoContainer.heightAnchor.constraint(equalTo: promoContainer.widthAnchor, multiplier: 0.72),
            
            // Background fills entire container
            promoBg.topAnchor.constraint(equalTo: promoContainer.topAnchor),
            promoBg.leadingAnchor.constraint(equalTo: promoContainer.leadingAnchor),
            promoBg.trailingAnchor.constraint(equalTo: promoContainer.trailingAnchor),
            promoBg.bottomAnchor.constraint(equalTo: promoContainer.bottomAnchor),
            
            // Left image fills left half
            promoLeft.topAnchor.constraint(equalTo: promoContainer.topAnchor),
            promoLeft.leadingAnchor.constraint(equalTo: promoContainer.leadingAnchor),
            promoLeft.bottomAnchor.constraint(equalTo: promoContainer.bottomAnchor),
            promoLeft.widthAnchor.constraint(equalTo: promoContainer.widthAnchor, multiplier: 0.5),
            
            // Center guide = right half area
            centerGuide.leadingAnchor.constraint(equalTo: promoLeft.trailingAnchor),
            centerGuide.trailingAnchor.constraint(equalTo: promoContainer.trailingAnchor),
            centerGuide.topAnchor.constraint(equalTo: promoContainer.topAnchor),
            centerGuide.bottomAnchor.constraint(equalTo: promoContainer.bottomAnchor),
            
            // Top spacing guide: 30.6% of container height
            topSpacing.topAnchor.constraint(equalTo: promoContainer.topAnchor),
            topSpacing.heightAnchor.constraint(equalTo: promoContainer.heightAnchor, multiplier: 0.306),
            
            // Mid spacing guide: 29.8% of container height (gap for "15% OFF" background text)
            midSpacing.topAnchor.constraint(equalTo: wouldStack.bottomAnchor),
            midSpacing.heightAnchor.constraint(equalTo: promoContainer.heightAnchor, multiplier: 0.298),
            
            // Close button top right
            closeBtn.topAnchor.constraint(equalTo: promoContainer.topAnchor, constant: 14),
            closeBtn.trailingAnchor.constraint(equalTo: promoContainer.trailingAnchor, constant: -14),
            closeBtn.widthAnchor.constraint(equalToConstant: 22),
            closeBtn.heightAnchor.constraint(equalToConstant: 22),
            
            // "WOULD YOU LIKE", "15% OFF" bg text, and YES button share same horizontal edges
            wouldStack.topAnchor.constraint(equalTo: topSpacing.bottomAnchor),
            wouldStack.leadingAnchor.constraint(equalTo: centerGuide.leadingAnchor, constant: 28),
            wouldStack.trailingAnchor.constraint(equalTo: centerGuide.trailingAnchor, constant: -28),
            
            // YES button — same leading/trailing as wouldStack for vertical edge alignment
            yesBtn.topAnchor.constraint(equalTo: midSpacing.bottomAnchor),
            yesBtn.leadingAnchor.constraint(equalTo: wouldStack.leadingAnchor),
            yesBtn.trailingAnchor.constraint(equalTo: wouldStack.trailingAnchor),
            yesBtn.heightAnchor.constraint(equalToConstant: 30),
            
            // NO THANKS — 10pt below YES button
            noLabel.topAnchor.constraint(equalTo: yesBtn.bottomAnchor, constant: 10),
            noLabel.centerXAnchor.constraint(equalTo: centerGuide.centerXAnchor),
        ])
        
        lastAnchorView = promoContainer
    }
    
    // MARK: - New Arrivals Section
    
    private func setupNewArrivalsSection() {
        // Section Title
        let sectionTitle = makeSectionTitle(L("store.section.new_arrivals"))
        contentView.addSubview(sectionTitle)
        
        NSLayoutConstraint.activate([
            sectionTitle.topAnchor.constraint(equalTo: lastAnchorBottom, constant: 30),
            sectionTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            sectionTitle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24)
        ])
        
        // Featured New Product Card
        let featuredCard = UIView()
        featuredCard.translatesAutoresizingMaskIntoConstraints = false
        featuredCard.layer.cornerRadius = 12
        featuredCard.clipsToBounds = true
        contentView.addSubview(featuredCard)
        
        let cardBg = UIImageView(image: UIImage(named: "store_new_featured_bg"))
        cardBg.translatesAutoresizingMaskIntoConstraints = false
        cardBg.contentMode = .scaleAspectFill
        cardBg.clipsToBounds = true
        featuredCard.addSubview(cardBg)
        
        // "新品" badge
        let badge = makeBadge(text: L("store.badge.new"))
        featuredCard.addSubview(badge)
        
        // Arrow right icon  
        let arrowIcon = UIImageView(image: UIImage(named: "store_arrow_right"))
        arrowIcon.translatesAutoresizingMaskIntoConstraints = false
        arrowIcon.contentMode = .scaleAspectFit
        featuredCard.addSubview(arrowIcon)
        
        NSLayoutConstraint.activate([
            featuredCard.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 16),
            featuredCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            featuredCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            featuredCard.heightAnchor.constraint(equalTo: featuredCard.widthAnchor, multiplier: 0.55),
            
            cardBg.topAnchor.constraint(equalTo: featuredCard.topAnchor),
            cardBg.leadingAnchor.constraint(equalTo: featuredCard.leadingAnchor),
            cardBg.trailingAnchor.constraint(equalTo: featuredCard.trailingAnchor),
            cardBg.bottomAnchor.constraint(equalTo: featuredCard.bottomAnchor),
            
            badge.topAnchor.constraint(equalTo: featuredCard.topAnchor, constant: 18),
            badge.leadingAnchor.constraint(equalTo: featuredCard.leadingAnchor, constant: 18),
            
            arrowIcon.trailingAnchor.constraint(equalTo: featuredCard.trailingAnchor, constant: -18),
            arrowIcon.bottomAnchor.constraint(equalTo: featuredCard.bottomAnchor, constant: -18),
            arrowIcon.widthAnchor.constraint(equalToConstant: 55),
            arrowIcon.heightAnchor.constraint(equalToConstant: 55)
        ])
        
        // Two new product cards
        let productRow = makeProductPairRow(
            card1Background: "store_product_pajama_card",
            card1Image: "store_product_pajama_image",
            card1Name: L("store.product.silk_pajama"),
            card1Price: "$258.00USD",
            card2Background: "store_product_gift_card",
            card2Image: "store_product_gift_image",
            card2Name: L("store.product.gift_set"),
            card2Price: "$159.00USD"
        )
        contentView.addSubview(productRow)
        
        NSLayoutConstraint.activate([
            productRow.topAnchor.constraint(equalTo: featuredCard.bottomAnchor, constant: 7),
            productRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            productRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            productRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }
    
    // MARK: - Factory Methods
    
    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        return label
    }
    
    private func makeBadge(text: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let bgImage = UIImageView(image: UIImage(named: "store_badge_bg"))
        bgImage.translatesAutoresizingMaskIntoConstraints = false
        bgImage.contentMode = .scaleToFill
        container.addSubview(bgImage)
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .center
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            bgImage.topAnchor.constraint(equalTo: container.topAnchor),
            bgImage.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bgImage.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bgImage.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -3),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
        ])
        
        return container
    }
    
    private func makeFeaturedProductCard(
        backgroundImage: String,
        productImage: String,
        badgeText: String,
        name: String,
        price: String,
        originalPrice: String
    ) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 18
        card.clipsToBounds = true
        
        // Card background
        let cardBg = UIImageView(image: UIImage(named: backgroundImage))
        cardBg.translatesAutoresizingMaskIntoConstraints = false
        cardBg.contentMode = .scaleAspectFill
        cardBg.clipsToBounds = true
        card.addSubview(cardBg)
        
        // Product image area
        let productImgView = UIImageView(image: UIImage(named: productImage))
        productImgView.translatesAutoresizingMaskIntoConstraints = false
        productImgView.contentMode = .scaleAspectFill
        productImgView.layer.cornerRadius = 12
        productImgView.clipsToBounds = true
        card.addSubview(productImgView)
        
        // Badge
        let badge = makeBadge(text: badgeText)
        card.addSubview(badge)
        
        // Name
        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = name
        nameLabel.textColor = .black
        nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        card.addSubview(nameLabel)
        
        // Price
        let priceLabel = UILabel()
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.text = price
        priceLabel.textColor = purpleColor
        priceLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        card.addSubview(priceLabel)
        
        // Original price (strikethrough)
        let origPriceLabel = UILabel()
        origPriceLabel.translatesAutoresizingMaskIntoConstraints = false
        let strikeAttrs: [NSAttributedString.Key: Any] = [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 9, weight: .light)
        ]
        origPriceLabel.attributedText = NSAttributedString(string: originalPrice, attributes: strikeAttrs)
        card.addSubview(origPriceLabel)
        
        NSLayoutConstraint.activate([
            cardBg.topAnchor.constraint(equalTo: card.topAnchor),
            cardBg.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            cardBg.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            cardBg.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            productImgView.topAnchor.constraint(equalTo: card.topAnchor),
            productImgView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            productImgView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            productImgView.heightAnchor.constraint(equalTo: card.widthAnchor, multiplier: 0.75),
            
            badge.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            badge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            
            nameLabel.topAnchor.constraint(equalTo: productImgView.bottomAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            
            priceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            priceLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            priceLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -19),
            
            origPriceLabel.centerYAnchor.constraint(equalTo: priceLabel.centerYAnchor),
            origPriceLabel.leadingAnchor.constraint(equalTo: priceLabel.trailingAnchor, constant: 8)
        ])
        
        return card
    }
    
    private func makeSmallProductCard(
        backgroundImage: String,
        productImage: String,
        name: String,
        price: String
    ) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 18
        card.clipsToBounds = true
        
        // Card background
        let cardBg = UIImageView(image: UIImage(named: backgroundImage))
        cardBg.translatesAutoresizingMaskIntoConstraints = false
        cardBg.contentMode = .scaleAspectFill
        cardBg.clipsToBounds = true
        card.addSubview(cardBg)
        
        // Product image
        let productImgView = UIImageView(image: UIImage(named: productImage))
        productImgView.translatesAutoresizingMaskIntoConstraints = false
        productImgView.contentMode = .scaleAspectFill
        productImgView.layer.cornerRadius = 12
        productImgView.clipsToBounds = true
        card.addSubview(productImgView)
        
        // Name
        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = name
        nameLabel.textColor = .black
        nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        card.addSubview(nameLabel)
        
        // Price
        let priceLabel = UILabel()
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.text = price
        priceLabel.textColor = purpleColor
        priceLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        card.addSubview(priceLabel)
        
        NSLayoutConstraint.activate([
            cardBg.topAnchor.constraint(equalTo: card.topAnchor),
            cardBg.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            cardBg.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            cardBg.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            productImgView.topAnchor.constraint(equalTo: card.topAnchor),
            productImgView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            productImgView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            productImgView.heightAnchor.constraint(equalTo: card.widthAnchor, multiplier: 1.29),
            
            nameLabel.topAnchor.constraint(equalTo: productImgView.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 11),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -11),
            
            priceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            priceLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            priceLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -15)
        ])
        
        return card
    }
    
    private func makeProductPairRow(
        card1Background: String, card1Image: String, card1Name: String, card1Price: String,
        card2Background: String, card2Image: String, card2Name: String, card2Price: String
    ) -> UIView {
        let row = UIStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.spacing = 14
        row.distribution = .fillEqually
        
        let card1 = makeSmallProductCard(backgroundImage: card1Background, productImage: card1Image, name: card1Name, price: card1Price)
        let card2 = makeSmallProductCard(backgroundImage: card2Background, productImage: card2Image, name: card2Name, price: card2Price)
        
        row.addArrangedSubview(card1)
        row.addArrangedSubview(card2)
        
        return row
    }
    
    // MARK: - Actions
    
    @objc private func handleSearchButtonTapped() {
        let searchVC = StoreSearchViewController()
        searchVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(searchVC, animated: true)
    }

    @objc private func handleSideBarBtnTapped() {
        let sideMenuVC = SideMenuViewController()
        sideMenuVC.modalPresentationStyle = .overFullScreen
        self.present(sideMenuVC, animated: false, completion: nil)
    }
}
