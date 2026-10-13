//
//  SurveyViewController.swift
//  mindora
//
//  睡眠体验问卷填写流程：逐题作答（单选 / 文本）→ 提交 → 提交成功页。
//  题目与提交对齐 Tools/doc/弹窗与调查问卷接口.md，数据经 SurveyService。
//

import UIKit

final class SurveyViewController: UIViewController {

    // MARK: - Properties

    private let surveyId: String
    private var survey: Survey?
    private var answers: [String: SurveyAnswer] = [:]   // questionId -> answer
    private var currentIndex = 0
    private let startedAt = Date()

    // 阶段：答题 → 礼品领取（有可领取礼品时）→ 提交成功
    private enum Phase { case questions, gift }
    private var phase: Phase = .questions
    private var giftEmailField: UITextField?
    private var giftNeedsAddress = false   // 实体礼品但未获取到收货地址：底部按钮改为「填写地址」

    private let bgColor = UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0)
    private let cardColor = UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1.0)
    private let accentPurple = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0)

    // MARK: - UI

    private let backButton = EnlargedHitAreaButton()
    private let titleLabel = UILabel()
    private let progressLabel = UILabel()
    private let progressTrack = UIView()          // 顶部进度条轨道（米色）
    private let progressFill = UIView()           // 进度填充（紫色）
    private var progressFillWidth: NSLayoutConstraint?
    private let contentContainer = UIView()      // 每题内容重建于此
    private let bottomButton = UIButton(type: .system)
    private let footNote = UILabel()
    private var buttonBottomNormal: NSLayoutConstraint!   // 无脚注时：按钮贴底
    private var footNoteBottom: NSLayoutConstraint!       // 有脚注时：脚注贴底、按钮上移
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    // MARK: - Init

    init(surveyId: String) {
        self.surveyId = surveyId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor
        setupNav()
        setupBody()
        setupKeyboardDismiss()
        loadSurvey()
    }

    /// 点击空白处收起键盘（文本题输入时）。cancelsTouchesInView=false 保证不影响选项 / 按钮点击。
    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // MARK: - Setup

    private func setupNav() {
        backButton.setImage(UIImage(named: "sub_back"), for: .normal)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        view.addSubview(backButton)

        // 标题与进度数在返回按钮下方一行；再下方是进度条。
        titleLabel.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        progressLabel.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        progressLabel.textColor = UIColor(white: 1, alpha: 0.5)
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressLabel)

        progressTrack.backgroundColor = UIColor(red: 0.83, green: 0.80, blue: 0.72, alpha: 1.0) // 米色轨道
        progressTrack.layer.cornerRadius = 1.5
        progressTrack.clipsToBounds = true
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressTrack)

        progressFill.backgroundColor = accentPurple
        progressFill.layer.cornerRadius = 1.5
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)

        let safe = view.safeAreaLayoutGuide
        progressFillWidth = progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: 0.02)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 24),
            backButton.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            progressLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            progressTrack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            progressTrack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressTrack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressTrack.heightAnchor.constraint(equalToConstant: 3),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFillWidth!
        ])
    }

    private func setupBody() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)

        footNote.font = UIFont(name: "PingFangSC-Regular", size: 11) ?? .systemFont(ofSize: 11)
        footNote.textColor = UIColor(white: 1, alpha: 0.4)
        footNote.textAlignment = .center
        footNote.numberOfLines = 0
        footNote.isHidden = true
        footNote.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footNote)

        bottomButton.setTitleColor(UIColor(red: 24/255, green: 24/255, blue: 24/255, alpha: 1.0), for: .normal)
        bottomButton.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        bottomButton.backgroundColor = .white
        bottomButton.layer.cornerRadius = 24
        bottomButton.translatesAutoresizingMaskIntoConstraints = false
        bottomButton.addTarget(self, action: #selector(handleBottomButton), for: .touchUpInside)
        view.addSubview(bottomButton)

        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)

        let safe = view.safeAreaLayoutGuide
        // 脚注在按钮「下方」；两种贴底方式互斥切换。
        buttonBottomNormal = bottomButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -20)
        footNoteBottom = footNote.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16)
        buttonBottomNormal.isActive = true
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: 24),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: bottomButton.topAnchor, constant: -12),

            footNote.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            footNote.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            footNote.topAnchor.constraint(equalTo: bottomButton.bottomAnchor, constant: 12),

            bottomButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            bottomButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            bottomButton.heightAnchor.constraint(equalToConstant: 48),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    /// 切换底部脚注（提交页）与按钮贴底方式，并更新进度条。
    private func updateProgress(current: Int, total: Int, showFootnote: Bool) {
        progressLabel.text = String(format: L("survey.progress"), current, total)
        let fraction = max(0.02, min(1.0, CGFloat(current) / CGFloat(max(total, 1))))
        progressFillWidth?.isActive = false
        progressFillWidth = progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: fraction)
        progressFillWidth?.isActive = true

        if showFootnote {
            buttonBottomNormal.isActive = false
            footNoteBottom.isActive = true
        } else {
            footNoteBottom.isActive = false
            buttonBottomNormal.isActive = true
        }
        footNote.isHidden = !showFootnote
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
    }

    // MARK: - Load

    private func loadSurvey() {
        loadingIndicator.startAnimating()
        bottomButton.isHidden = true
        SurveyService.shared.fetchSurvey(surveyId: surveyId) { [weak self] result in
            guard let self else { return }
            self.loadingIndicator.stopAnimating()
            self.bottomButton.isHidden = false
            switch result {
            case .success(let survey):
                self.survey = survey
                self.titleLabel.text = survey.title
                self.currentIndex = 0
                self.renderCurrentQuestion()
            case .failure:
                Toast.show(L("survey.error.generic"), in: self.view)
                self.dismissSelf()
            }
        }
    }

    // MARK: - Render question

    private func renderCurrentQuestion() {
        guard let survey, currentIndex < survey.questions.count else { return }
        let question = survey.questions[currentIndex]

        contentContainer.subviews.forEach { $0.removeFromSuperview() }

        let isLast = currentIndex == survey.questions.count - 1
        bottomButton.setTitle(isLast ? L("survey.submit") : L("survey.next"), for: .normal)
        if isLast { footNote.text = L("survey.submit.note") }
        // 进度条按本地题序推进（不信任服务端 index，防 0 起始 / 不连续错位）；末题展示同意脚注。
        updateProgress(current: currentIndex + 1, total: survey.questions.count, showFootnote: isLast)

        // 题干
        let qTitle = UILabel()
        qTitle.text = question.title
        qTitle.font = UIFont(name: "PingFangSC-Semibold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        qTitle.textColor = .white
        qTitle.numberOfLines = 0
        qTitle.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(qTitle)

        let qHint = UILabel()
        qHint.text = question.hint
        qHint.font = UIFont(name: "PingFangSC-Regular", size: 13) ?? .systemFont(ofSize: 13)
        qHint.textColor = UIColor(white: 1, alpha: 0.5)
        qHint.numberOfLines = 0
        qHint.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(qHint)

        NSLayoutConstraint.activate([
            qTitle.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            qTitle.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 24),
            qTitle.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -24),

            qHint.topAnchor.constraint(equalTo: qTitle.bottomAnchor, constant: 8),
            qHint.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 24),
            qHint.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -24)
        ])

        switch question.type {
        case .singleChoice, .multiChoice:
            renderOptions(for: question, below: qHint)
        case .text:
            renderTextInput(for: question, below: qHint)
        }
    }

    private func renderOptions(for question: SurveyQuestion, below topView: UIView) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(stack)

        let selectedIds = Set(answers[question.questionId]?.optionIds ?? [])
        let isMultiple = question.type == .multiChoice

        for option in question.options {
            let row = SurveyOptionRow(text: option.text,
                                      selected: selectedIds.contains(option.optionId),
                                      multiple: isMultiple,
                                      cardColor: cardColor,
                                      accent: accentPurple)
            row.onTap = { [weak self] in
                self?.selectOption(question: question, optionId: option.optionId)
            }
            stack.addArrangedSubview(row)
            row.heightAnchor.constraint(equalToConstant: 52).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topView.bottomAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -24)
        ])
    }

    private func renderTextInput(for question: SurveyQuestion, below topView: UIView) {
        let textView = UITextView()
        textView.backgroundColor = cardColor
        textView.layer.cornerRadius = 12
        textView.font = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15)
        textView.textColor = .white
        textView.tintColor = accentPurple
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.tag = 999
        contentContainer.addSubview(textView)

        // 占位符
        let placeholder = UILabel()
        placeholder.text = question.placeholder
        placeholder.font = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15)
        placeholder.textColor = UIColor(white: 1, alpha: 0.35)
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.tag = 1000
        contentContainer.addSubview(placeholder)

        let existing = answers[question.questionId]?.text ?? ""
        textView.text = existing
        placeholder.isHidden = !existing.isEmpty

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topView.bottomAnchor, constant: 20),
            textView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 24),
            textView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -24),
            textView.heightAnchor.constraint(equalToConstant: 160),

            placeholder.topAnchor.constraint(equalTo: textView.topAnchor, constant: 14),
            placeholder.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 16)
        ])
    }

    // MARK: - Answer handling

    private func selectOption(question: SurveyQuestion, optionId: String) {
        if question.type == .multiChoice {
            // 多选：点击切换选中，累积到 optionIds。
            var current = answers[question.questionId]?.optionIds ?? []
            if let idx = current.firstIndex(of: optionId) {
                current.remove(at: idx)
            } else {
                current.append(optionId)
            }
            answers[question.questionId] = SurveyAnswer(questionId: question.questionId,
                                                        type: question.type,
                                                        optionIds: current,
                                                        text: nil)
        } else {
            // 单选：替换为唯一选中项。
            answers[question.questionId] = SurveyAnswer(questionId: question.questionId,
                                                        type: question.type,
                                                        optionIds: [optionId],
                                                        text: nil)
        }
        renderCurrentQuestion()
    }

    @objc private func handleBottomButton() {
        if phase == .gift {
            if giftNeedsAddress { presentAddressSheet(); return }
            handleGiftConfirm(); return
        }
        guard let survey else { return }
        let question = survey.questions[currentIndex]

        // 校验必答
        if question.required {
            switch question.type {
            case .singleChoice, .multiChoice:
                if (answers[question.questionId]?.optionIds.isEmpty ?? true) {
                    Toast.show(L("survey.validation.choose"), in: view)
                    return
                }
            case .text:
                if (answers[question.questionId]?.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                    Toast.show(L("survey.validation.input"), in: view)
                    return
                }
            }
        }

        view.endEditing(true)
        if currentIndex < survey.questions.count - 1 {
            currentIndex += 1
            renderCurrentQuestion()
        } else if let reward = survey.reward, reward.giftType == .physical || reward.giftType == .virtual {
            // 末题后：有可领取礼品 → 先进「礼品领取」页确认收货方式，再提交。
            showGiftClaim(reward: reward)
        } else {
            submit(giftDelivery: nil)
        }
    }

    private func submit(giftDelivery: [String: Any]?) {
        guard let survey else { return }
        loadingIndicator.startAnimating()
        bottomButton.isEnabled = false

        // 每题都要出现在 answers[] 中：未作答的非必答题以空值占位（服务端不容忍缺席）。
        let orderedAnswers = survey.questions.map { q in
            answers[q.questionId] ?? SurveyAnswer(questionId: q.questionId,
                                                  type: q.type,
                                                  optionIds: [],
                                                  text: q.type == .text ? "" : nil)
        }
        let duration = Int(Date().timeIntervalSince(startedAt))
        SurveyService.shared.submit(surveyId: surveyId, answers: orderedAnswers, durationSeconds: duration, giftDelivery: giftDelivery) { [weak self] result in
            guard let self else { return }
            self.loadingIndicator.stopAnimating()
            self.bottomButton.isEnabled = true
            switch result {
            case .success(let res):
                // 提交后刷新站内消息（调研消息可标记为已完成）。
                NotificationCenter.default.post(name: AppNotificationStore.didChangeNotification, object: nil)
                self.showSuccess(res)
            case .failure(let error):
                let msg = (error as? SurveyService.SurveyError).flatMap {
                    if case .message(let m) = $0 { return m } else { return nil }
                } ?? L("survey.error.generic")
                Toast.show(msg, in: self.view)
            }
        }
    }

    // MARK: - 礼品领取

    private func showGiftClaim(reward: SurveyReward) {
        phase = .gift
        giftNeedsAddress = false
        view.endEditing(true)
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        giftEmailField = nil

        // 头部：隐藏进度，标题改「礼品领取」；底部无同意脚注。
        progressLabel.isHidden = true
        progressTrack.isHidden = true
        titleLabel.text = L("gift.title")
        footNoteBottom.isActive = false
        buttonBottomNormal.isActive = true
        footNote.isHidden = true
        bottomButton.setTitle(L("gift.confirm"), for: .normal)

        // 实体礼品且未获取到收货地址：走「未获取地址」空态（居中提示 + 填写地址按钮）。
        if reward.giftType == .physical, Self.defaultAddress() == nil {
            buildPhysicalNoAddress()
            return
        }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -24)
        ])

        if reward.giftType == .physical {
            buildPhysicalGift(into: stack, reward: reward)
        } else {
            buildVirtualGift(into: stack, giftName: reward.giftName)
        }
    }

    /// 实体礼品-未获取地址：居中「抱歉…请先填写收货地址」，底部按钮改「填写地址」。
    private func buildPhysicalNoAddress() {
        giftNeedsAddress = true
        bottomButton.setTitle(L("gift.fill_address"), for: .normal)

        let titleLabel = UILabel()
        titleLabel.text = L("gift.no_address.title")
        titleLabel.font = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15)
        titleLabel.textColor = UIColor(white: 1, alpha: 0.85)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let hintLabel = UILabel()
        hintLabel.text = L("gift.no_address.hint")
        hintLabel.font = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15)
        hintLabel.textColor = UIColor(white: 1, alpha: 0.85)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, hintLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentContainer.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentContainer.trailingAnchor, constant: -40)
        ])
    }

    /// 弹出「填写地址」页，确认后写入本地地址簿并刷新礼品领取页。
    ///
    /// 这里直接复用地址簿的结构化编辑页，而不是另做一个轻量弹层：
    /// 实物礼品要真发货，收集到的必须是带国家 / 州 / 邮编的完整收货地址。
    private func presentAddressSheet() {
        guard let reward = survey?.reward else { return }
        let vc = AddressAddEditViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.onSave = { [weak self] address in
            guard let self else { return }
            var address = address
            address.isDefault = true
            self.saveAddressToBook(address)
            self.showGiftClaim(reward: reward)   // 已有地址 → 重渲染为地址卡片
        }
        present(vc, animated: true)
    }

    /// 写入本地地址簿（个人中心「地址管理」共用同一存储），并设为默认地址。
    private func saveAddressToBook(_ address: AddrModel) {
        var list = UserProfileSync.loadAddresses()
        if address.isDefault {
            for i in 0..<list.count { list[i].isDefault = false }
        }
        list.append(address)
        // 领奖填的收货地址同样要同步到服务端（发货用），所以走统一写入口而不是直接写 UserDefaults。
        UserProfileSync.saveAddresses(list)
    }

    private func buildPhysicalGift(into stack: UIStackView, reward: SurveyReward) {
        stack.addArrangedSubview(giftDescLabel(String(format: L("gift.physical.desc"), reward.giftName)))

        if let addr = Self.defaultAddress() {
            let card = UIView()
            card.backgroundColor = cardColor
            card.layer.cornerRadius = 12
            card.translatesAutoresizingMaskIntoConstraints = false

            let line1 = UILabel()
            line1.text = "\(addr.name)  \(addr.phone)"
            line1.font = UIFont(name: "PingFangSC-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
            line1.textColor = .white
            line1.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(line1)

            let line2 = UILabel()
            line2.text = addr.region.isEmpty ? addr.detail : "\(addr.region) \(addr.detail)"
            line2.font = UIFont(name: "PingFangSC-Regular", size: 13) ?? .systemFont(ofSize: 13)
            line2.textColor = UIColor(white: 1, alpha: 0.6)
            line2.numberOfLines = 0
            line2.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(line2)

            NSLayoutConstraint.activate([
                line1.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
                line1.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                line1.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                line2.topAnchor.constraint(equalTo: line1.bottomAnchor, constant: 8),
                line2.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                line2.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                line2.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
            ])
            stack.addArrangedSubview(card)
        } else {
            stack.addArrangedSubview(giftDescLabel(L("gift.no_address")))
        }

        // 更改提示 + 客服邮箱（可复制）
        let hint = UILabel()
        hint.text = L("gift.physical.change_hint")
        hint.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12)
        hint.textColor = UIColor(white: 1, alpha: 0.4)
        hint.numberOfLines = 0
        stack.addArrangedSubview(hint)
        stack.setCustomSpacing(8, after: hint)

        // 客服邮箱：由服务端下发（reward.contact_email）；未下发则不展示这一行。
        if let contactEmail = reward.contactEmail, !contactEmail.isEmpty {
            let emailRow = UIStackView()
            emailRow.axis = .horizontal
            emailRow.spacing = 8
            emailRow.alignment = .center
            let emailLabel = UILabel()
            emailLabel.text = contactEmail
            emailLabel.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
            emailLabel.textColor = .white
            let copyBtn = UIButton(type: .system)
            copyBtn.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
            copyBtn.tintColor = UIColor(white: 1, alpha: 0.6)
            copyBtn.addAction(UIAction(handler: { [weak self] _ in
                UIPasteboard.general.string = contactEmail
                if let self { Toast.show(L("common.copy_success"), in: self.view) }
            }), for: .touchUpInside)
            emailRow.addArrangedSubview(emailLabel)
            emailRow.addArrangedSubview(copyBtn)
            emailRow.addArrangedSubview(UIView())   // 撑左
            stack.addArrangedSubview(emailRow)
        }
    }

    private func buildVirtualGift(into stack: UIStackView, giftName: String) {
        stack.addArrangedSubview(giftDescLabel(String(format: L("gift.virtual.desc"), giftName)))

        let field = UITextField()
        // 默认填写用户账户邮箱。
        field.text = AuthStorage.shared.email ?? AuthStorage.shared.preferredUserIdentifier
        field.attributedPlaceholder = NSAttributedString(
            string: L("gift.email.placeholder"),
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.35)])
        field.backgroundColor = cardColor
        field.textColor = .white
        field.tintColor = accentPurple
        field.font = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15)
        field.layer.cornerRadius = 12
        field.keyboardType = .emailAddress
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.clearButtonMode = .whileEditing
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true
        stack.addArrangedSubview(field)
        giftEmailField = field
    }

    private func giftDescLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        l.textColor = UIColor(white: 1, alpha: 0.7)
        l.numberOfLines = 0
        return l
    }

    private func handleGiftConfirm() {
        guard let reward = survey?.reward else { submit(giftDelivery: nil); return }
        view.endEditing(true)
        var delivery: [String: Any] = ["type": reward.giftType.rawValue]
        if reward.giftType == .virtual {
            let email = (giftEmailField?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard Self.isValidEmail(email) else {
                Toast.show(L("gift.validation.email"), in: view); return
            }
            delivery["email"] = email
        } else if let addr = Self.defaultAddress() {
            // 实物礼品要真发货，结构化字段一并带上（承运商按 state + zip 分区）；
            // region / detail 是旧协议的展示串，服务端存量逻辑还在读，一起传。
            delivery["address_id"] = addr.id
            delivery["name"] = addr.name
            delivery["phone"] = addr.phone
            delivery["country_code"] = addr.countryCode
            delivery["state_code"] = addr.stateCode
            delivery["state"] = addr.state
            delivery["city"] = addr.city
            delivery["district"] = addr.district
            delivery["street1"] = addr.street1
            delivery["street2"] = addr.street2
            delivery["zip"] = addr.zip
            delivery["region"] = addr.region
            delivery["detail"] = addr.detail
        }
        submit(giftDelivery: delivery)
    }

    /// 默认收货地址（个人中心「地址管理」保存的）。
    private static func defaultAddress() -> AddrModel? {
        guard let data = UserDefaults.standard.data(forKey: "MindoraSavedAddresses"),
              let list = try? JSONDecoder().decode([AddrModel].self, from: data), !list.isEmpty else { return nil }
        return list.first(where: { $0.isDefault }) ?? list.first
    }

    private static func isValidEmail(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        // 锚定全串匹配，避免 "a@b.com 任意后缀" 之类的子串误通过。
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Success screen

    private func showSuccess(_ result: SurveySubmitResult) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        backButton.isHidden = true
        progressLabel.isHidden = true
        progressTrack.isHidden = true
        titleLabel.text = L("survey.success.title")
        titleLabel.isHidden = true
        footNote.isHidden = true
        // 成功页无脚注：按钮恢复贴底。
        footNoteBottom.isActive = false
        buttonBottomNormal.isActive = true

        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        // check 圆
        let checkCircle = UIView()
        checkCircle.backgroundColor = accentPurple
        checkCircle.layer.cornerRadius = 34
        checkCircle.translatesAutoresizingMaskIntoConstraints = false
        let checkIcon = UIImageView(image: UIImage(systemName: "checkmark"))
        checkIcon.tintColor = .white
        checkIcon.contentMode = .scaleAspectFit
        checkIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        checkCircle.addSubview(checkIcon)
        NSLayoutConstraint.activate([
            checkCircle.widthAnchor.constraint(equalToConstant: 68),
            checkCircle.heightAnchor.constraint(equalToConstant: 68),
            checkIcon.centerXAnchor.constraint(equalTo: checkCircle.centerXAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: checkCircle.centerYAnchor)
        ])
        stack.addArrangedSubview(checkCircle)
        stack.setCustomSpacing(20, after: checkCircle)

        let successTitle = UILabel()
        successTitle.text = L("survey.success.title")
        successTitle.font = UIFont(name: "PingFangSC-Semibold", size: 20) ?? .systemFont(ofSize: 20, weight: .semibold)
        successTitle.textColor = .white
        stack.addArrangedSubview(successTitle)
        stack.setCustomSpacing(12, after: successTitle)

        let successDesc = UILabel()
        successDesc.text = [L("survey.success.line1"), L("survey.success.line2"), L("survey.success.line3")].joined(separator: "\n")
        successDesc.font = UIFont(name: "PingFangSC-Regular", size: 13) ?? .systemFont(ofSize: 13)
        successDesc.textColor = UIColor(white: 1, alpha: 0.6)
        successDesc.numberOfLines = 0
        successDesc.textAlignment = .center
        stack.addArrangedSubview(successDesc)
        stack.setCustomSpacing(28, after: successDesc)

        // 奖励卡片
        let rewardCard = UIView()
        rewardCard.backgroundColor = cardColor
        rewardCard.layer.cornerRadius = 12
        rewardCard.translatesAutoresizingMaskIntoConstraints = false

        let rewardTitle = UILabel()
        rewardTitle.text = result.rewardTitle
        rewardTitle.font = UIFont(name: "PingFangSC-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        rewardTitle.textColor = .white
        rewardTitle.translatesAutoresizingMaskIntoConstraints = false
        rewardCard.addSubview(rewardTitle)

        let rewardDesc = UILabel()
        rewardDesc.text = result.rewardDesc
        rewardDesc.font = UIFont(name: "PingFangSC-Regular", size: 13) ?? .systemFont(ofSize: 13)
        rewardDesc.textColor = UIColor(white: 1, alpha: 0.6)
        rewardDesc.numberOfLines = 0
        rewardDesc.translatesAutoresizingMaskIntoConstraints = false
        rewardCard.addSubview(rewardDesc)

        NSLayoutConstraint.activate([
            rewardTitle.topAnchor.constraint(equalTo: rewardCard.topAnchor, constant: 16),
            rewardTitle.leadingAnchor.constraint(equalTo: rewardCard.leadingAnchor, constant: 16),
            rewardTitle.trailingAnchor.constraint(equalTo: rewardCard.trailingAnchor, constant: -16),
            rewardDesc.topAnchor.constraint(equalTo: rewardTitle.bottomAnchor, constant: 10),
            rewardDesc.leadingAnchor.constraint(equalTo: rewardCard.leadingAnchor, constant: 16),
            rewardDesc.trailingAnchor.constraint(equalTo: rewardCard.trailingAnchor, constant: -16),
            rewardDesc.bottomAnchor.constraint(equalTo: rewardCard.bottomAnchor, constant: -16)
        ])
        stack.addArrangedSubview(rewardCard)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 40),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48),
            rewardCard.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        bottomButton.setTitle(L("survey.success.back_home"), for: .normal)
        bottomButton.removeTarget(nil, action: nil, for: .allEvents)
        bottomButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
    }

    // MARK: - Nav actions

    @objc private func handleBack() {
        view.endEditing(true)
        // 礼品领取页返回 → 回到最后一题。
        if phase == .gift {
            phase = .questions
            progressLabel.isHidden = false
            progressTrack.isHidden = false
            titleLabel.text = survey?.title
            bottomButton.isEnabled = true
            renderCurrentQuestion()
            return
        }
        if currentIndex > 0 {
            currentIndex -= 1
            renderCurrentQuestion()
        } else {
            dismissSelf()
        }
    }

    @objc private func dismissSelf() {
        // 栈底时 pop 无处可退、静默失败，返回按钮会彻底失效（订阅页踩过这个坑）
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            (navigationController ?? self).dismiss(animated: true)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate（点击收起键盘）

extension SurveyViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 点在输入框 / 控件自身时不触发收起，交给它们正常聚焦 / 响应。
        var v = touch.view
        while let cur = v {
            if cur is UIControl || cur is UITextView || cur is UITextField { return false }
            v = cur.superview
        }
        return true
    }
}

// MARK: - UITextViewDelegate

extension SurveyViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        guard let survey else { return }
        let question = survey.questions[currentIndex]
        answers[question.questionId] = SurveyAnswer(questionId: question.questionId,
                                                    type: .text, optionIds: [], text: textView.text)
        if let placeholder = contentContainer.viewWithTag(1000) {
            placeholder.isHidden = !(textView.text?.isEmpty ?? true)
        }
    }
}

// MARK: - 单选选项行

final class SurveyOptionRow: UIView {
    var onTap: (() -> Void)?

    private let radio = UIView()
    private let checkIcon = UIImageView(image: UIImage(systemName: "checkmark"))
    private let accent: UIColor
    private var selected: Bool

    init(text: String, selected: Bool, multiple: Bool = false, cardColor: UIColor, accent: UIColor) {
        self.selected = selected
        self.accent = accent
        super.init(frame: .zero)

        backgroundColor = cardColor
        layer.cornerRadius = 12
        translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.font = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        // 多选用圆角方框（复选框），单选用圆形（单选钮）。
        radio.layer.cornerRadius = multiple ? 6 : 11
        radio.layer.borderWidth = 1.5
        radio.translatesAutoresizingMaskIntoConstraints = false
        addSubview(radio)

        checkIcon.tintColor = .white
        checkIcon.contentMode = .scaleAspectFit
        checkIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        radio.addSubview(checkIcon)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            radio.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            radio.centerYAnchor.constraint(equalTo: centerYAnchor),
            radio.widthAnchor.constraint(equalToConstant: 22),
            radio.heightAnchor.constraint(equalToConstant: 22),

            checkIcon.centerXAnchor.constraint(equalTo: radio.centerXAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: radio.centerYAnchor)
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        applySelection()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func applySelection() {
        if selected {
            radio.backgroundColor = accent
            radio.layer.borderColor = accent.cgColor
            checkIcon.isHidden = false
            layer.borderWidth = 1
            layer.borderColor = accent.withAlphaComponent(0.6).cgColor
        } else {
            radio.backgroundColor = .clear
            radio.layer.borderColor = UIColor(white: 1, alpha: 0.4).cgColor
            checkIcon.isHidden = true
            layer.borderWidth = 0
        }
    }

    @objc private func handleTap() { onTap?() }
}
