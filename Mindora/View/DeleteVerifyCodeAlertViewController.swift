//
//  DeleteVerifyCodeAlertViewController.swift
//  mindora
//
//  注销验证码输入弹窗。视觉沿用 CustomAlertViewController（RGB(21,21,21) 容器、白色描边按钮、
//  按设计稿等比缩放），在描述与按钮之间加一个输入框；键盘弹出时整体上移避免遮挡。
//

import UIKit

final class DeleteVerifyCodeAlertViewController: UIViewController {

    // MARK: - 设计稿常量（与 CustomAlertViewController 对齐）
    private let designWidth: CGFloat = 1242
    private let designHeight: CGFloat = 2688
    private let designAlertWidth: CGFloat = 1100
    private let designAlertCornerRadius: CGFloat = 20
    private let designTitleTopMargin: CGFloat = 80
    private let designTextHorizontalMargin: CGFloat = 80
    private let designButtonWidth: CGFloat = 345
    private let designButtonHeight: CGFloat = 128
    private let designButtonCornerRadius: CGFloat = 64
    private let designButtonBottomMargin: CGFloat = 102
    private let designButtonFontSize: CGFloat = 47
    private let designButtonSpacing: CGFloat = 100
    private let designFieldHeight: CGFloat = 150
    private let designFieldCornerRadius: CGFloat = 24

    private let alertBackgroundColor = UIColor(red: 21/255, green: 21/255, blue: 21/255, alpha: 1.0)

    private func scale(_ v: CGFloat, basedOn dimension: CGFloat, designDimension: CGFloat) -> CGFloat {
        let capped = iPadAdaptiveScale.capped(dimension, widthReference: view.bounds.width)
        return v * (capped / designDimension)
    }

    // MARK: - Properties
    private let titleText: String
    private let descriptionText: String
    private let placeholderText: String
    private let confirmButtonTitle: String
    private let cancelButtonTitle: String
    private let onConfirm: ((String) -> Void)?
    private let onCancel: (() -> Void)?

    private var containerCenterY: NSLayoutConstraint?

    // MARK: - UI
    private let dimmedBackgroundView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let alertContainerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let descriptionLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let textFieldContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        v.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let codeTextField: UITextField = {
        let tf = UITextField()
        tf.textColor = .white
        tf.textAlignment = .center
        tf.keyboardType = .numberPad
        tf.textContentType = .oneTimeCode
        tf.tintColor = .white
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    private let confirmButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = .clear
        b.layer.borderColor = UIColor.white.cgColor
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = .clear
        b.layer.borderColor = UIColor.white.cgColor
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Init
    init(title: String,
         description: String,
         placeholder: String,
         confirmButtonTitle: String,
         cancelButtonTitle: String,
         onConfirm: ((String) -> Void)? = nil,
         onCancel: (() -> Void)? = nil) {
        self.titleText = title
        self.descriptionText = description
        self.placeholderText = placeholder
        self.confirmButtonTitle = confirmButtonTitle
        self.cancelButtonTitle = cancelButtonTitle
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        registerKeyboardObservers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        codeTextField.becomeFirstResponder()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .clear
        view.addSubview(dimmedBackgroundView)
        view.addSubview(alertContainerView)
        alertContainerView.addSubview(titleLabel)
        alertContainerView.addSubview(descriptionLabel)
        alertContainerView.addSubview(textFieldContainer)
        textFieldContainer.addSubview(codeTextField)
        alertContainerView.addSubview(confirmButton)
        alertContainerView.addSubview(cancelButton)

        alertContainerView.backgroundColor = alertBackgroundColor
        alertContainerView.layer.cornerRadius = scale(designAlertCornerRadius, basedOn: view.bounds.width, designDimension: designWidth)
        alertContainerView.clipsToBounds = true

        let titleFontSize = scale(DesignConstants.subtitleFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        titleLabel.font = UIFont.systemFont(ofSize: titleFontSize, weight: .semibold)
        titleLabel.text = titleText

        let descFontSize = scale(DesignConstants.bodyFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        let lineSpacing = scale(21, basedOn: view.bounds.height, designDimension: designHeight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.alignment = .center
        let attr = NSMutableAttributedString(string: descriptionText)
        let range = NSRange(location: 0, length: descriptionText.count)
        attr.addAttribute(.font, value: UIFont.systemFont(ofSize: descFontSize, weight: .regular), range: range)
        attr.addAttribute(.paragraphStyle, value: paragraph, range: range)
        attr.addAttribute(.foregroundColor, value: UIColor.white, range: range)
        descriptionLabel.attributedText = attr

        // 输入框
        let fieldFontSize = scale(52, basedOn: view.bounds.height, designDimension: designHeight)
        codeTextField.font = UIFont.systemFont(ofSize: fieldFontSize, weight: .medium)
        codeTextField.attributedPlaceholder = NSAttributedString(
            string: placeholderText,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.35)]
        )
        textFieldContainer.layer.cornerRadius = scale(designFieldCornerRadius, basedOn: view.bounds.width, designDimension: designWidth)
        textFieldContainer.layer.borderWidth = scale(2, basedOn: view.bounds.height, designDimension: designHeight)

        // 按钮
        let btnFontSize = scale(designButtonFontSize, basedOn: view.bounds.height, designDimension: designHeight)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: btnFontSize, weight: .medium)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: btnFontSize, weight: .medium)
        confirmButton.setTitle(confirmButtonTitle, for: .normal)
        cancelButton.setTitle(cancelButtonTitle, for: .normal)
        let btnCorner = scale(designButtonCornerRadius, basedOn: view.bounds.height, designDimension: designHeight)
        confirmButton.layer.cornerRadius = btnCorner
        cancelButton.layer.cornerRadius = btnCorner
        let borderWidth = scale(1, basedOn: view.bounds.height, designDimension: designHeight)
        confirmButton.layer.borderWidth = borderWidth
        cancelButton.layer.borderWidth = borderWidth

        setupConstraints()
    }

    private func setupConstraints() {
        let alertWidth = scale(designAlertWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let titleTop = scale(designTitleTopMargin, basedOn: view.bounds.height, designDimension: designHeight)
        let textH = scale(designTextHorizontalMargin, basedOn: view.bounds.width, designDimension: designWidth)
        let btnW = scale(designButtonWidth, basedOn: view.bounds.width, designDimension: designWidth)
        let btnH = scale(designButtonHeight, basedOn: view.bounds.height, designDimension: designHeight)
        let btnBottom = scale(designButtonBottomMargin, basedOn: view.bounds.height, designDimension: designHeight)
        let btnSpacing = scale(designButtonSpacing, basedOn: view.bounds.width, designDimension: designWidth)
        let fieldH = scale(designFieldHeight, basedOn: view.bounds.height, designDimension: designHeight)

        let titleToDesc = scale(50, basedOn: view.bounds.height, designDimension: designHeight)
        let descToField = scale(70, basedOn: view.bounds.height, designDimension: designHeight)
        let fieldToButton = scale(80, basedOn: view.bounds.height, designDimension: designHeight)

        let centerY = alertContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        containerCenterY = centerY

        NSLayoutConstraint.activate([
            dimmedBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmedBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            alertContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alertContainerView.widthAnchor.constraint(equalToConstant: alertWidth),
            centerY,

            titleLabel.topAnchor.constraint(equalTo: alertContainerView.topAnchor, constant: titleTop),
            titleLabel.leadingAnchor.constraint(equalTo: alertContainerView.leadingAnchor, constant: textH),
            titleLabel.trailingAnchor.constraint(equalTo: alertContainerView.trailingAnchor, constant: -textH),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: titleToDesc),
            descriptionLabel.leadingAnchor.constraint(equalTo: alertContainerView.leadingAnchor, constant: textH),
            descriptionLabel.trailingAnchor.constraint(equalTo: alertContainerView.trailingAnchor, constant: -textH),

            textFieldContainer.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: descToField),
            textFieldContainer.leadingAnchor.constraint(equalTo: alertContainerView.leadingAnchor, constant: textH),
            textFieldContainer.trailingAnchor.constraint(equalTo: alertContainerView.trailingAnchor, constant: -textH),
            textFieldContainer.heightAnchor.constraint(equalToConstant: fieldH),

            codeTextField.leadingAnchor.constraint(equalTo: textFieldContainer.leadingAnchor, constant: textH / 2),
            codeTextField.trailingAnchor.constraint(equalTo: textFieldContainer.trailingAnchor, constant: -textH / 2),
            codeTextField.topAnchor.constraint(equalTo: textFieldContainer.topAnchor),
            codeTextField.bottomAnchor.constraint(equalTo: textFieldContainer.bottomAnchor),

            cancelButton.widthAnchor.constraint(equalToConstant: btnW),
            cancelButton.heightAnchor.constraint(equalToConstant: btnH),
            cancelButton.topAnchor.constraint(equalTo: textFieldContainer.bottomAnchor, constant: fieldToButton),
            cancelButton.trailingAnchor.constraint(equalTo: alertContainerView.centerXAnchor, constant: -btnSpacing / 2),

            confirmButton.widthAnchor.constraint(equalToConstant: btnW),
            confirmButton.heightAnchor.constraint(equalToConstant: btnH),
            confirmButton.topAnchor.constraint(equalTo: textFieldContainer.bottomAnchor, constant: fieldToButton),
            confirmButton.leadingAnchor.constraint(equalTo: alertContainerView.centerXAnchor, constant: btnSpacing / 2),

            alertContainerView.bottomAnchor.constraint(equalTo: confirmButton.bottomAnchor, constant: btnBottom)
        ])
    }

    private func setupActions() {
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        dimmedBackgroundView.addGestureRecognizer(tap)
    }

    // MARK: - Keyboard avoidance
    private func registerKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ note: Notification) {
        guard let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        // 让弹窗底部离键盘留一点空隙。
        let overlap = (alertContainerView.frame.maxY) - (view.bounds.height - frame.height)
        let shift = max(0, overlap + scale(60, basedOn: view.bounds.height, designDimension: designHeight))
        containerCenterY?.constant = -shift
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        containerCenterY?.constant = 0
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    // MARK: - Actions
    @objc private func confirmTapped() {
        let code = (codeTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.confirmButton.animateButtonTap { [weak self] in
            self?.view.endEditing(true)
            self?.dismiss(animated: true) { self?.onConfirm?(code) }
        }
    }

    @objc private func cancelTapped() {
        self.cancelButton.animateButtonTap { [weak self] in
            self?.view.endEditing(true)
            self?.dismiss(animated: true) { self?.onCancel?() }
        }
    }

    @objc private func backgroundTapped() {
        // 点击空白：若键盘弹着先收键盘，否则视为取消。
        if codeTextField.isFirstResponder {
            view.endEditing(true)
        } else {
            cancelTapped()
        }
    }
}
