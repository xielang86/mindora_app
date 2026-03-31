import UIKit

final class StoreSearchViewController: UIViewController {
    
    // MARK: - UI Components

    private let searchBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 243/255, green: 243/255, blue: 247/255, alpha: 1.0)
        view.layer.cornerRadius = 3
        return view
    }()
    
    private let searchIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "store_search_bar_icon"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private let searchTextField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        tf.textColor = .black
        tf.returnKeyType = .search
        tf.clearButtonMode = .whileEditing
        return tf
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        button.setTitleColor(.black, for: .normal)
        return button
    }()
    
    private let historyHeaderView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let historyTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .black
        return label
    }()
    
    private let deleteHistoryButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "store_history_delete"), for: .normal)
        return button
    }()
    
    private let historyTagsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Data
    private var searchHistory: [String] = ["MINDORA"]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupUI()
        updateHistoryView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchTextField.becomeFirstResponder()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        searchTextField.placeholder = L("store.search.placeholder")
        cancelButton.setTitle(L("store.search.cancel"), for: .normal)
        historyTitleLabel.text = L("store.search.history")
        
        // Search bar row
        searchBar.addSubview(searchIcon)
        searchBar.addSubview(searchTextField)
        view.addSubview(searchBar)
        view.addSubview(cancelButton)
        
        // History
        historyHeaderView.addSubview(historyTitleLabel)
        historyHeaderView.addSubview(deleteHistoryButton)
        view.addSubview(historyHeaderView)
        view.addSubview(historyTagsContainer)
        
        cancelButton.addTarget(self, action: #selector(handleCancelTapped), for: .touchUpInside)
        deleteHistoryButton.addTarget(self, action: #selector(handleDeleteHistoryTapped), for: .touchUpInside)
        searchTextField.delegate = self
        
        NSLayoutConstraint.activate([
            // Search bar
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 7),
            searchBar.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -6),
            searchBar.heightAnchor.constraint(equalToConstant: 30),
            
            searchIcon.leadingAnchor.constraint(equalTo: searchBar.leadingAnchor, constant: 10),
            searchIcon.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 22),
            searchIcon.heightAnchor.constraint(equalToConstant: 16),
            
            searchTextField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            searchTextField.trailingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: -10),
            searchTextField.topAnchor.constraint(equalTo: searchBar.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchBar.bottomAnchor),
            
            // Cancel button
            cancelButton.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            
            // History header
            historyHeaderView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 30),
            historyHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 7),
            historyHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -7),
            historyHeaderView.heightAnchor.constraint(equalToConstant: 13),
            
            historyTitleLabel.leadingAnchor.constraint(equalTo: historyHeaderView.leadingAnchor),
            historyTitleLabel.centerYAnchor.constraint(equalTo: historyHeaderView.centerYAnchor),
            
            deleteHistoryButton.trailingAnchor.constraint(equalTo: historyHeaderView.trailingAnchor),
            deleteHistoryButton.centerYAnchor.constraint(equalTo: historyHeaderView.centerYAnchor),
            deleteHistoryButton.widthAnchor.constraint(equalToConstant: 13),
            deleteHistoryButton.heightAnchor.constraint(equalToConstant: 13),
            
            // Tags container
            historyTagsContainer.topAnchor.constraint(equalTo: historyHeaderView.bottomAnchor, constant: 13),
            historyTagsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 7),
            historyTagsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -7)
        ])
    }
    
    private func updateHistoryView() {
        // Clear existing tags
        historyTagsContainer.subviews.forEach { $0.removeFromSuperview() }
        
        let isHidden = searchHistory.isEmpty
        historyHeaderView.isHidden = isHidden
        historyTagsContainer.isHidden = isHidden
        
        guard !searchHistory.isEmpty else { return }
        
        var xOffset: CGFloat = 0
        let yOffset: CGFloat = 0
        let tagHeight: CGFloat = 24
        let hSpacing: CGFloat = 8
        
        for keyword in searchHistory {
            let tag = createHistoryTag(keyword)
            historyTagsContainer.addSubview(tag)
            tag.frame = CGRect(x: xOffset, y: yOffset, width: tag.intrinsicContentSize.width + 14, height: tagHeight)
            xOffset += tag.frame.width + hSpacing
        }
        
        historyTagsContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: tagHeight).isActive = true
    }
    
    private func createHistoryTag(_ text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 243/255, green: 243/255, blue: 247/255, alpha: 1.0)
        container.layer.cornerRadius = 2
        
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 95/255, green: 95/255, blue: 95/255, alpha: 1.0)
        label.sizeToFit()
        label.frame = CGRect(x: 7, y: 3, width: label.frame.width, height: label.frame.height)
        
        container.addSubview(label)
        container.frame = CGRect(x: 0, y: 0, width: label.frame.width + 14, height: 24)
        
        // Tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleHistoryTagTapped(_:)))
        container.addGestureRecognizer(tap)
        container.isUserInteractionEnabled = true
        container.accessibilityLabel = text
        
        return container
    }
    
    // MARK: - Actions
    
    @objc private func handleCancelTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func handleDeleteHistoryTapped() {
        searchHistory.removeAll()
        updateHistoryView()
    }
    
    @objc private func handleHistoryTagTapped(_ gesture: UITapGestureRecognizer) {
        guard let text = gesture.view?.accessibilityLabel else { return }
        searchTextField.text = text
        performSearch(text)
    }
    
    private func performSearch(_ query: String) {
        // Add to history if not already present
        if !query.isEmpty && !searchHistory.contains(query) {
            searchHistory.insert(query, at: 0)
            updateHistoryView()
        }
        // TODO: Implement actual search logic
    }
}

// MARK: - UITextFieldDelegate

extension StoreSearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text, !text.isEmpty else { return true }
        textField.resignFirstResponder()
        performSearch(text)
        return true
    }
}
