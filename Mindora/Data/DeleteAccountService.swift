//
//  DeleteAccountService.swift
//  mindora
//
//  账号删除（App Store 5.1.1(v) / Google Play 强制要求：有注册就必须能删账号）。
//  后端两阶段接口（复用登录/注册同款 POST /auth）：
//    阶段 1  send_delete_verify_code  —— 向用户绑定的邮箱/手机发送注销验证码
//    阶段 2  delete_user_with_code    —— 携带验证码真正注销账号
//  data 必填 jwt_token（服务端从 token 解析用户）。
//
//  响应统一为 { request_type, code, msg, data }，code==0 为成功，其余为业务失败。
//  失败时服务端带 error_code + 按 App 语言翻好的 msg（见 ServerError），直接展示 msg、按 error_code 判 token 失效；
//  老格式响应（无 error_code，msg 为中文）仍按 code + 关键字映射为本地文案。
//

import Foundation

final class DeleteAccountService {
    static let shared = DeleteAccountService()
    private let logTag = "DeleteAccount"
    private init() {}

    enum DeleteAccountError: Error { case message(String) }

    private let sendCodeRequestType = "send_delete_verify_code"
    private let deleteRequestType = "delete_user_with_code"

    /// 阶段 1：请求后端向用户绑定的邮箱/手机发送注销验证码。
    func sendDeleteVerifyCode() async throws {
        var data: [String: Any] = [:]
        data["jwt_token"] = try requireToken()
        _ = try await post(requestType: sendCodeRequestType, data: data)
        Log.info(logTag, "send delete verify code success")
    }

    /// 阶段 2：携带验证码真正注销账号。
    func deleteUserWithCode(_ code: String) async throws {
        var data: [String: Any] = [:]
        data["jwt_token"] = try requireToken()
        data["verify_code"] = code
        _ = try await post(requestType: deleteRequestType, data: data)
        Log.info(logTag, "delete account with code success")
    }

    // MARK: - 通用请求

    private func requireToken() throws -> String {
        guard let token = AuthStorage.shared.token, !token.isEmpty else {
            throw DeleteAccountError.message(L("user_profile.token_missing"))
        }
        return token
    }

    /// 发送一次 /auth POST，成功返回解析后的 JSON，失败抛出本地化 DeleteAccountError。
    @discardableResult
    private func post(requestType: String, data: [String: Any]) async throws -> [String: Any]? {
        guard let url = URL(string: Constants.Network.authURL) else {
            throw DeleteAccountError.message(L("user_profile.delete_failed"))
        }

        // 注销验证码同样是服务端渲染的邮件，语种要跟着 App 走。
        var payload = data
        payload["language"] = LocalizationManager.shared.currentLanguage.rawValue

        let body: [String: Any] = [
            "request_type": requestType,
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": payload
        ]

        var req = URLRequest(url: url)

        RequestTrace.apply(&req)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = Constants.Network.timeoutInterval
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        // 打印请求（脱敏 jwt_token）便于排查。
        Log.info(logTag, "→ POST \(Constants.Network.authURL) req=\(redactedBodyString(body))")

        let (respData, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw DeleteAccountError.message(L("user_profile.delete_failed"))
        }
        // 打印响应（响应体为 {code,msg,data:null}，不含敏感数据，原样打印）。
        Log.info(logTag, "← \(requestType) http=\(http.statusCode) resp=\(String(data: respData, encoding: .utf8) ?? "")")

        let json = (try? JSONSerialization.jsonObject(with: respData)) as? [String: Any]
        let code = (json?["code"] as? Int) ?? (json?["code"] as? NSNumber)?.intValue
        let msg = (json?["msg"] as? String) ?? extractDetail(json)
        let serverError = ServerError.parse(json, status: http.statusCode)

        // ⚠️ 后端对「验证码错误/已过期」也返回 HTTP 401，与「token 失效」共用 401。
        // 只有确认是 token 失效时才走全局会话过期（切登录页）；否则（验证码错误等）绝不能误登出——
        // 之前无条件调用 SessionExpirationCenter.handle 会把「验证码错误」当成 token 失效直接踢到登录页，
        // 看起来像账号被删了，实则没删。
        if isTokenError(code: code, msg: msg, serverError: serverError) {
            SessionExpirationCenter.handle(httpResponse: http, data: respData)
        }

        // 严格：只有 code == 0 才算成功（对齐后端文档）。缺 code / code != 0 / HTTP 非 2xx 一律按失败处理，
        // 抛本地化错误 → 界面 toast、停留原页，绝不继续删除/登出。
        guard code == 0 else {
            Log.error(logTag, "\(requestType) http=\(http.statusCode) code=\(code.map(String.init) ?? "nil") msg=\(msg ?? "") body=\(String(data: respData, encoding: .utf8) ?? "")")
            throw DeleteAccountError.message(localizedMessage(code: code, msg: msg, serverError: serverError))
        }
        return json
    }

    /// 是否为「token 真正失效」——只有它才该触发全局会话过期。验证码错误共用 401，但绝不是 token 失效。
    private func isTokenError(code: Int?, msg: String?, serverError: ServerError?) -> Bool {
        if let e = serverError, e.errorCode != nil { return e.isTokenError || code == 2 }
        let m = msg ?? ""
        if m.contains("验证码") { return false }              // 验证码错误/过期，不是 token 问题
        if code == 2 { return true }                          // 业务码：Token expired
        if m.contains("Token expired") || m.contains("Invalid token") { return true }
        return false
    }

    /// 将后端 code + 中文 msg 映射为本地化提示；未知情况回退到通用失败文案，避免中文泄漏给外语用户。
    private func localizedMessage(code: Int?, msg: String?, serverError: ServerError?) -> String {
        let m = msg ?? ""
        if code == 2 || serverError?.isTokenError == true || m.contains("Token expired") || m.contains("Invalid token") {
            return L("auth.session_expired")
        }
        if let text = serverError?.displayMessage { return text }
        if m.contains("验证码") {
            return L("user_profile.delete_err_bad_code")
        }
        if code == 400 || m.contains("未绑定") {
            return L("user_profile.delete_err_no_contact")
        }
        if code == 409 || m.contains("发送失败") {
            return L("user_profile.delete_err_send_failed")
        }
        if m.contains("不存在") || m.contains("已被注销") || m.contains("已注销") {
            return L("user_profile.delete_err_user_gone")
        }
        return L("user_profile.delete_failed")
    }

    /// 生成用于日志的请求体串，把 data.jwt_token 脱敏（只保留长度），其余字段原样。
    private func redactedBodyString(_ body: [String: Any]) -> String {
        var copy = body
        if var data = copy["data"] as? [String: Any] {
            if let token = data["jwt_token"] as? String {
                data["jwt_token"] = "***REDACTED(len=\(token.count))***"
            }
            copy["data"] = data
        }
        if let d = try? JSONSerialization.data(withJSONObject: copy),
           let s = String(data: d, encoding: .utf8) {
            return s
        }
        return "\(copy)"
    }

    private func extractDetail(_ json: [String: Any]?) -> String? {
        if let s = json?["detail"] as? String { return s }
        if let arr = json?["detail"] as? [[String: Any]], let msg = arr.first?["msg"] as? String { return msg }
        return nil
    }
}
