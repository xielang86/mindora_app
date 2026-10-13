//
//  SurveyService.swift
//  mindora
//
//  睡眠体验问卷：拉题 + 提交答案。对齐 Tools/doc/弹窗与调查问卷接口.md。
//  本地记录「该问卷已提交」，避免重复填写（服务端也应幂等）。
//

import Foundation

// MARK: - 数据模型

struct SurveyQuestion {
    enum QuestionType: String { case singleChoice = "single_choice", multiChoice = "multi_choice", text }
    struct Option { let optionId: String; let text: String }

    let questionId: String
    let index: Int
    let type: QuestionType
    let title: String
    let hint: String?
    let placeholder: String?
    let options: [Option]
    let required: Bool
}

/// 问卷奖励 / 礼品。提交前的「礼品领取」页据此展示（实体寄地址 / 虚拟发邮箱）。
struct SurveyReward {
    enum GiftType: String { case physical, virtual, none }
    let giftType: GiftType
    let giftName: String      // 礼品名称（展示用）
    let desc: String?         // 提交成功页的奖励说明文案（可空，服务端也可在提交响应里返回）
    let contactEmail: String? // 实体礼品「客服邮箱」；必须由服务端下发（无内置兜底），不下发则不展示该行
}

struct Survey {
    let surveyId: String
    let title: String
    let questions: [SurveyQuestion]
    let reward: SurveyReward?   // 有可领取礼品时，末题提交前插入「礼品领取」页
}

/// 一道题的作答。
struct SurveyAnswer {
    let questionId: String
    let type: SurveyQuestion.QuestionType
    var optionIds: [String]
    var text: String?
}

struct SurveySubmitResult {
    let rewardGranted: Bool
    let rewardTitle: String
    let rewardDesc: String
}

// MARK: - 服务

final class SurveyService {
    static let shared = SurveyService()
    private let logTag = "SurveyService"
    private let defaults = UserDefaults.standard
    private let submittedPrefix = "survey.submitted."
    private let knownIdsKey = "survey.knownIds"
    private init() {}

    enum SurveyError: Error {
        case message(String)
        /// 问卷不存在 / 已下线（HTTP 404 或业务码明示）。
        /// 与「服务端故障」必须区分开：前者重试多少次都是这个结果，不该计入退避 ——
        /// 否则一个已下线的 survey_id 会把**其他所有问卷**的预拉一起压住。
        case notFound
    }

    /// 问卷提交成功。object 为 surveyId。站内消息列表据此刷新按钮外观。
    static let didSubmitNotification = Notification.Name("SurveyService.didSubmit")

    /// 是否已提交过该问卷。
    ///
    /// 记录存 `AccountVault.submittedSurveys`（按账号邮箱隔离、登出不清、注销才清）。
    /// 原先存在会被登出清掉的 UserDefaults key 里 —— 重新登录后同一份问卷会再邀请一次，
    /// 用户明明答过、奖也发过，再答一遍还会撞上服务端的幂等拒绝。
    func hasSubmitted(surveyId: String) -> Bool {
        if AccountVault.submittedSurveys.contains(surveyId) { return true }
        // 旧版本把标记写在登出即清的 key 里，升级上来的用户读不到新清单会被重复邀请。
        // 命中即迁移一次，之后就走 AccountVault 了。
        if defaults.bool(forKey: submittedPrefix + surveyId) {
            AccountVault.submittedSurveys.insert(surveyId)
            return true
        }
        return false
    }

    private func markSubmitted(surveyId: String) {
        AccountVault.submittedSurveys.insert(surveyId)
        // 通知列表把该问卷的「填写问卷」按钮切成已完成态。问卷页是 fullScreen present 上来的，
        // 光靠 viewWillAppear 不够：提交成功页可能停留很久，期间列表要能立刻反映状态。
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didSubmitNotification, object: surveyId)
        }
    }

    /// 只丢掉预拉到的题目，保留「已提交」标记。用于语言切换：
    /// 题目文案跟着语言走，已提交与否跟语言无关，一起清会让用户重复答同一份问卷。
    func invalidateContentCache() {
        prefetched = [:]
    }

    /// 只清内存里的题目缓存，**不动任何「已提交」记录**（含旧版遗留的）。用于登出。
    ///
    /// 曾经在这里顺手删旧版遗留标记，是个 bug：迁移是**读取时惰性触发**的
    /// （见 hasSubmitted），用户如果在从没读过某个 id 的情况下登出，源数据就被删了、
    /// 迁移再也不会发生 —— 结果是他重新登录后被重复邀请一份早就答过的问卷。
    /// 现在改为启动时一次性迁移，见 migrateLegacySubmitted()。
    func clearCache() {
        prefetched = [:]
        inFlight = []
    }

    /// 把旧版遗留在 UserDefaults 里的「已提交」标记一次性迁进 AccountVault。
    /// 启动时（已登录）调一次即可；未登录时 vault 没有账号命名空间，直接跳过等下次。
    func migrateLegacySubmitted() {
        let ids = defaults.stringArray(forKey: knownIdsKey) ?? []
        guard !ids.isEmpty else { return }
        guard AuthStorage.shared.email?.isEmpty == false else { return }
        var migrated = 0
        for id in ids where defaults.bool(forKey: submittedPrefix + id) {
            AccountVault.submittedSurveys.insert(id)
            defaults.removeObject(forKey: submittedPrefix + id)
            migrated += 1
        }
        defaults.removeObject(forKey: knownIdsKey)
        Log.info(logTag, "旧版「已提交」标记迁移完成，共 \(migrated) 条")
    }

    /// 注销时把旧版遗留标记也清掉 —— 真值在 AccountVault 由 purgeCurrentAccount 负责，
    /// 但万一还没迁移过，残留的标记会让同邮箱重新注册的用户被判成「答过了」。
    func purgeLegacySubmitted() {
        for id in defaults.stringArray(forKey: knownIdsKey) ?? [] {
            defaults.removeObject(forKey: submittedPrefix + id)
        }
        defaults.removeObject(forKey: knownIdsKey)
    }


    // MARK: 预拉题（内存缓存）

    /// 预拉到的题目：surveyId → (题目, 拉取时刻)。只在内存，杀进程即失效。
    /// **缓存不设过期**：只要拉到过就一直可用，用户任何时候点开都是零等待。
    private var prefetched: [String: (survey: Survey, at: Date)] = [:]
    private var inFlight: Set<String> = []
    /// 预拉失败退避（只影响后台预拉；用户主动点开时的 fetchSurvey 不受它限制）。
    private var prefetchBackoff = NetworkBackoff()
    /// 静默刷新阈值：缓存比这个还旧时，后台重新拉一份覆盖（旧的照常先用），
    /// 保证运营中途改过题面也能跟上，但用户永远不会因此等待。
    private let refreshInterval: TimeInterval = 30 * 60

    /// 首页弹窗同步到调研时立即调用：把题目提前拉回来缓存，用户点开时零等待。
    /// 已提交 / 缓存还新 / 正在拉取时都不重复发请求。
    func prefetch(surveyId: String) {
        guard !surveyId.isEmpty, !hasSubmitted(surveyId: surveyId), !shouldUseDemo(surveyId) else { return }
        if let hit = prefetched[surveyId], Date().timeIntervalSince(hit.at) < refreshInterval { return }
        guard !inFlight.contains(surveyId) else { return }
        guard !prefetchBackoff.isBlocked else {
            Log.info(logTag, "prefetch 跳过：处于失败退避期（还剩 \(prefetchBackoff.remainingSeconds)s）")
            return
        }
        inFlight.insert(surveyId)
        Log.info(logTag, "prefetch survey=\(surveyId)")
        // 预拉是纯后台行为，用户不在等：随机错峰 0–15s 再发，
        // 一次同步下发多份问卷时也不会同时打服务端。
        NetworkPacing.afterSpread(upTo: 15) { [weak self] in
            guard let self else { return }
            self.requestSurvey(surveyId: surveyId) { [weak self] result in
                guard let self else { return }
                self.inFlight.remove(surveyId)
                switch result {
                case .success(let survey):
                    self.prefetchBackoff.recordSuccess()
                    self.prefetched[surveyId] = (survey, Date())
                case .failure(let error):
                    // 问卷不存在 / 已下线：重试多少次都是这个结果，不是服务端故障。
                    // 计入退避的话，一个已下线的 survey_id 会把其他所有问卷的预拉一起压住。
                    if case SurveyError.notFound = error { return }
                    // 未登录不算失败：requestSurvey 未登录时也走 failure 分支，若照记退避，
                    // 会让「还没登录」被当成「服务端故障」压住后续预拉。与 PopupService 口径保持一致。
                    guard AuthStorage.shared.token?.isEmpty == false else {
                        Log.info(self.logTag, "prefetch 跳过：未登录（不计失败、不退避）")
                        return
                    }
                    self.prefetchBackoff.recordFailure()
                }
            }
        }
    }

    // MARK: 拉题

    func fetchSurvey(surveyId: String, completion: @escaping (Result<Survey, Error>) -> Void) {
        // 预拉命中：不论多旧都先用缓存渲染（零等待）；旧了就顺手在后台刷新，下次用新的。
        if let hit = prefetched[surveyId] {
            let age = Int(Date().timeIntervalSince(hit.at))
            Log.info(logTag, "fetchSurvey 命中预拉缓存 survey=\(surveyId) age=\(age)s")
            completion(.success(hit.survey))
            if TimeInterval(age) >= refreshInterval { prefetch(surveyId: surveyId) }
            return
        }
        requestSurvey(surveyId: surveyId) { [weak self] result in
            if case .success(let survey) = result {
                self?.prefetched[surveyId] = (survey, Date())
            }
            completion(result)
        }
    }

    private func requestSurvey(surveyId: String, completion: @escaping (Result<Survey, Error>) -> Void) {
        // 客户端不内置任何正式问卷：题目一律由服务端 query_survey 下发。
        // 仅 DEBUG（showMockData / demo·debug·mock 问卷 / 拉题失败）回退到 demo 问卷，方便预览。
        if shouldUseDemo(surveyId) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion(.success(Self.demoSurvey(surveyId: surveyId)))
            }
            return
        }
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let token = AuthStorage.shared.token, !token.isEmpty,
              let url = URL(string: Constants.Network.surveyURL) else {
            completion(Self.failureOrDemo(surveyId))
            return
        }

        let body: [String: Any] = [
            "request_type": "query_survey",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": [
                "uid": uid,
                "jwt_token": token,
                "language": LocalizationManager.shared.currentLanguage.rawValue,
                "survey_id": surveyId
            ]
        ]
        var req = URLRequest(url: url)
        RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = Constants.Network.timeoutInterval
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            if let http = response as? HTTPURLResponse, let data {
                SessionExpirationCenter.handle(httpResponse: http, data: data)
            }
            if let error {
                Log.error(self.logTag, "query_survey error=\(error.localizedDescription)")
                DispatchQueue.main.async { completion(Self.failureOrDemo(surveyId)) }
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let json = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any]
            let code = json?["code"] as? Int
            // 问卷不存在 / 已下线：明确区分出来，调用方据此不计退避。
            if status == 404 || code == 404 {
                Log.info(self.logTag, "query_survey 问卷不存在 survey=\(surveyId)（不计退避）")
                DispatchQueue.main.async { completion(.failure(SurveyError.notFound)) }
                return
            }
            // 业务码要看：code != 0 时 data 常为 null，只判 data 会把服务端的明确拒绝
            // 记成「解析失败」，日志里看不出真实原因。
            if let code, code != 0 {
                Log.error(self.logTag, "query_survey 业务失败 survey=\(surveyId) code=\(code) msg=\(json?["msg"] as? String ?? "-")")
                DispatchQueue.main.async { completion(Self.failureOrDemo(surveyId)) }
                return
            }
            guard let payload = json?["data"] as? [String: Any],
                  let survey = Self.parseSurvey(payload, fallbackId: surveyId) else {
                DispatchQueue.main.async { completion(Self.failureOrDemo(surveyId)) }
                return
            }
            DispatchQueue.main.async { completion(.success(survey)) }
        }.resume()
    }

    /// 是否直接用 demo 问卷（不走网络）：showMockData，或 DEBUG 下的 demo / debug / mock 预览问卷。
    private func shouldUseDemo(_ surveyId: String) -> Bool {
        if Constants.Config.showMockData { return true }
        #if DEBUG
        return surveyId.hasPrefix("demo") || surveyId.hasPrefix("debug") || surveyId.hasPrefix("mock")
        #else
        return false
        #endif
    }

    /// 拉题失败：一律返回错误（不内置问卷）。demo / debug / mock 前缀的预览问卷在
    /// shouldUseDemo 已提前短路，不会走到这里；DEBUG 下也不再回退 demo 题面 ——
    /// 否则会拿 demo 的 question_id 提交真实 survey_id，污染服务端数据。
    private static func failureOrDemo(_ surveyId: String) -> Result<Survey, Error> {
        .failure(SurveyError.message(L("survey.error.generic")))
    }

    // MARK: 提交

    func submit(surveyId: String,
                answers: [SurveyAnswer],
                durationSeconds: Int?,
                giftDelivery: [String: Any]? = nil,
                completion: @escaping (Result<SurveySubmitResult, Error>) -> Void) {
        if shouldUseDemo(surveyId) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.markSubmitted(surveyId: surveyId)
                completion(.success(SurveySubmitResult(
                    rewardGranted: true,
                    rewardTitle: L("survey.reward.title"),
                    rewardDesc: L("survey.reward.desc"))))
            }
            return
        }
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let token = AuthStorage.shared.token, !token.isEmpty,
              let url = URL(string: Constants.Network.surveyURL) else {
            completion(.failure(SurveyError.message(L("survey.error.generic"))))
            return
        }

        let answerPayload: [[String: Any]] = answers.map { a in
            var dict: [String: Any] = ["question_id": a.questionId, "type": a.type.rawValue]
            if a.type == .text {
                dict["text"] = a.text ?? ""
            } else {
                dict["option_ids"] = a.optionIds
            }
            return dict
        }
        var data: [String: Any] = [
            "uid": uid,
            "jwt_token": token,
            "language": LocalizationManager.shared.currentLanguage.rawValue,
            "survey_id": surveyId,
            "answers": answerPayload,
            "submitted_at": Int(Date().timeIntervalSince1970)
        ]
        if let durationSeconds { data["duration_seconds"] = durationSeconds }
        // 礼品领取信息：实体 {type:physical, address_id, ...}；虚拟 {type:virtual, email}。
        if let giftDelivery { data["gift_delivery"] = giftDelivery }

        let body: [String: Any] = [
            "request_type": "submit_survey",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": data
        ]
        var req = URLRequest(url: url)
        RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = Constants.Network.timeoutInterval
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] respData, response, error in
            guard let self else { return }
            if let http = response as? HTTPURLResponse, let respData {
                SessionExpirationCenter.handle(httpResponse: http, data: respData)
            }
            if let error {
                Log.error(self.logTag, "submit_survey error=\(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(SurveyError.message(L("survey.error.generic")))) }
                return
            }
            let json = (respData.flatMap { try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any]
            let http = response as? HTTPURLResponse
            let statusOK = (200..<300).contains(http?.statusCode ?? 0)
            let bizCode = json?["code"] as? Int
            // 409（已提交）也视为成功：本地标记已提交、走到成功页。
            // 兼容两种下发：HTTP 409（此时 statusOK 为 false），或 HTTP 200 + body code=409。
            let alreadySubmitted = http?.statusCode == 409 || bizCode == 409
            guard alreadySubmitted || (statusOK && (bizCode == 0 || bizCode == 200)) else {
                let msg = (json?["msg"] as? String) ?? L("survey.error.generic")
                DispatchQueue.main.async { completion(.failure(SurveyError.message(msg))) }
                return
            }
            self.markSubmitted(surveyId: surveyId)
            let payload = json?["data"] as? [String: Any]
            let result = SurveySubmitResult(
                rewardGranted: payload?["reward_granted"] as? Bool ?? false,
                rewardTitle: payload?["reward_title"] as? String ?? L("survey.reward.title"),
                rewardDesc: payload?["reward_desc"] as? String ?? L("survey.reward.desc"))
            DispatchQueue.main.async { completion(.success(result)) }
        }.resume()
    }

    // MARK: 解析

    private static func parseSurvey(_ dict: [String: Any], fallbackId: String) -> Survey? {
        guard let rawQuestions = dict["questions"] as? [[String: Any]], !rawQuestions.isEmpty else { return nil }
        let questions: [SurveyQuestion] = rawQuestions.enumerated().compactMap { idx, q in
            guard let questionId = q["question_id"] as? String,
                  let title = q["title"] as? String,
                  let type = SurveyQuestion.QuestionType(rawValue: q["type"] as? String ?? "") else { return nil }
            let options = (q["options"] as? [[String: Any]] ?? []).compactMap { o -> SurveyQuestion.Option? in
                guard let oid = o["option_id"] as? String, let text = o["text"] as? String else { return nil }
                return SurveyQuestion.Option(optionId: oid, text: text)
            }
            // 选择题必须有选项：服务端漏配则丢弃该题，避免用户被卡死在无选项的必答题上。
            if type != .text, options.isEmpty { return nil }
            return SurveyQuestion(
                questionId: questionId,
                index: q["index"] as? Int ?? (idx + 1),
                type: type,
                title: title,
                hint: q["hint"] as? String,
                placeholder: q["placeholder"] as? String,
                options: options,
                required: q["required"] as? Bool ?? (type != .text))
        }
        guard !questions.isEmpty else { return nil }
        var reward: SurveyReward?
        if let r = dict["reward"] as? [String: Any] {
            reward = SurveyReward(
                giftType: SurveyReward.GiftType(rawValue: r["gift_type"] as? String ?? "none") ?? .none,
                giftName: r["gift_name"] as? String ?? "",
                desc: r["desc"] as? String,
                contactEmail: (r["contact_email"] as? String).flatMap { $0.isEmpty ? nil : $0 })
        }
        return Survey(
            surveyId: dict["survey_id"] as? String ?? fallbackId,
            title: dict["title"] as? String ?? L("survey.title"),
            questions: questions,
            reward: reward)
    }

    // MARK: Demo 问卷（仅 DEBUG / showMockData 预览用；正式版问卷全部由服务端下发）

    static func demoSurvey(surveyId: String) -> Survey {
        let scale: [SurveyQuestion.Option] = [
            .init(optionId: "o1", text: L("survey.scale.very_satisfied")),
            .init(optionId: "o2", text: L("survey.scale.satisfied")),
            .init(optionId: "o3", text: L("survey.scale.neutral")),
            .init(optionId: "o4", text: L("survey.scale.dissatisfied")),
            .init(optionId: "o5", text: L("survey.scale.very_dissatisfied"))
        ]
        return Survey(
            surveyId: surveyId,
            title: L("survey.title"),
            questions: [
                SurveyQuestion(questionId: "q1", index: 1, type: .singleChoice,
                               title: L("survey.q1.title"), hint: L("survey.choice.hint"),
                               placeholder: nil, options: scale, required: true),
                SurveyQuestion(questionId: "q2", index: 2, type: .singleChoice,
                               title: L("survey.q2.title"), hint: L("survey.choice.hint"),
                               placeholder: nil, options: scale, required: true),
                SurveyQuestion(questionId: "q3", index: 3, type: .text,
                               title: L("survey.q3.title"), hint: L("survey.q3.hint"),
                               placeholder: L("survey.q3.placeholder"), options: [], required: false)
            ],
            // demo 礼品类型由 surveyId 决定：含 "physical" → 实体礼品，否则虚拟礼品（方便调试分别预览两种领取页）。
            // demo 客服邮箱仅为预览占位（正式环境由服务端 reward.contact_email 下发）。
            reward: SurveyReward(giftType: surveyId.contains("physical") ? .physical : .virtual,
                                 giftName: L("survey.reward.demo_gift"),
                                 desc: L("survey.reward.desc"),
                                 contactEmail: Constants.Contact.supportEmail))
    }
}
