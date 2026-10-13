//
//  AuthService.swift
//  mindora
//
//  Created by GitHub Copilot on 2026/01/21.
//

import Foundation

enum AuthServiceError: Error {
    case invalidURL
    case serializationError
    case networkError(Error)
    case noData
    case apiError(code: Int, message: String?)
    case invalidResponse
    case missingData
    case httpError(status: Int, intent: Intent)
    /// 新版服务端的统一错误（带 error_code / 已本地化的 msg，见 ServerError）。
    case server(ServerError, intent: Intent)

    enum Intent {
        case send
        case verify
    }
    
    /// 服务端要求等多少秒后才能重发（send_too_frequent 时有值）。
    var retryAfter: Int? {
        if case .server(let e, _) = self, e.errorCode == "send_too_frequent" { return e.retryAfter }
        return nil
    }

    var localizedDescription: String {
        switch self {
        case .server(let e, let intent):
            // 服务端已按 App 语言翻好；没给（老格式）时按状态码走下面的本地文案
            if let msg = e.displayMessage { return msg }
            return AuthServiceError.httpError(status: e.code ?? 500, intent: intent).localizedDescription
        case .invalidURL:
            return L("auth.error.invalid_url")
        case .serializationError:
            return L("auth.error.serialization_error")
        case .networkError(let error):
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorTimedOut:
                    return L("auth.error.timeout")
                case NSURLErrorNotConnectedToInternet,
                     NSURLErrorNetworkConnectionLost,
                     NSURLErrorCannotConnectToHost,
                     NSURLErrorCannotFindHost,
                     NSURLErrorDNSLookupFailed:
                    return L("auth.error.network")
                default:
                    return L("auth.error.network")
                }
            }
            return L("auth.error.network")
        case .noData:
            return L("auth.error.no_data")
        case .apiError(_, let message):
            // Prefer server-provided message only if it looks user-friendly; otherwise fall back.
            if let msg = message, !msg.isEmpty, !msg.lowercased().contains("not found") {
                return msg
            }
            return L("auth.error.verify_failed")
        case .invalidResponse:
            return L("auth.error.server")
        case .missingData:
            return L("auth.error.verify_failed")
        case .httpError(let status, let intent):
            switch intent {
            case .send:
                return (500...599).contains(status)
                    ? L("auth.error.server")
                    : L("auth.error.send_failed")
            case .verify:
                switch status {
                case 400, 401, 403, 422:
                    return L("auth.error.code_invalid")
                case 410:
                    return L("auth.error.code_expired")
                case 500...599:
                    return L("auth.error.server")
                default:
                    return L("auth.error.verify_failed")
                }
            }
        }
    }
}

class AuthService {

    static let logTag = "AuthService"

    /// 把响应体里的 token 值抹掉再写日志。
    ///
    /// `enableNetworkLogging` 在 Release 也是开的，日志会落到设备上的滚动文件里 ——
    /// 登录响应体带着完整 JWT，原样写进去等于把长期有效的凭证留在磁盘上。
    /// 其余字段（code / msg / uid / expire_days）照常保留，排查时够用。
    static func redactToken(_ body: String) -> String {
        // ⚠️ 必须连 `jwt_token` 一起匹配。原先只认 `"token"`，而睡眠计划/分析这些接口
        // 的请求体里字段名是 `jwt_token`，一个都没被打码 —— JWT 全文进了日志，且
        // Log 还会落到 LogFileWriter 的滚动文件里，等于长期留在用户设备上。
        // 捕获组保留原字段名，日志里仍看得出是哪一个被打的码。
        guard let regex = try? NSRegularExpression(pattern: "\"((?:jwt_)?token)\"\\s*:\\s*\"[^\"]*\"") else { return body }
        return regex.stringByReplacingMatches(
            in: body, range: NSRange(body.startIndex..., in: body),
            withTemplate: "\"$1\": \"<redacted>\"")
    }

    
    static let shared = AuthService()
    
    private let deviceId = UUID().uuidString.lowercased()

    /// 服务端没给 retry_after 时的重发间隔（与服务端 VERIFY_CODE_RESEND_SECONDS 默认值一致）。
    static let defaultResendSeconds = 60
    
    private init() {}
    
    /// 成功时返回服务端给的重发间隔秒数（验证码页按它倒计时）。
    func sendVerifyCode(email: String, completion: @escaping (Result<Int, AuthServiceError>) -> Void) {
        guard let url = URL(string: Constants.Network.authURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        
        RequestTrace.apply(&request)
        request.timeoutInterval = Constants.Network.timeoutInterval
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "request_type": "send_verify_code",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": [
                "email": email,
                "device_id": deviceId,
                // 验证码邮件的正文语种由服务端渲染，不带这个字段服务端只能猜。
                "language": LocalizationManager.shared.currentLanguage.rawValue
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            // 走 Log 而不是 print：登录是唯一一条以前没有文件日志的网络路径，
            // 出问题时（验证码没收到、登录后立刻被踢）设备上捞不到任何痕迹，
            // 只能靠连着 Xcode 复现 —— 而这类问题恰恰多发在测试机上。
            if Constants.Config.enableNetworkLogging,
               let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) {
                Log.info(Self.logTag, "sendVerifyCode request url=\(url) body=\(bodyString)")
            }
        } catch {
            completion(.failure(.serializationError))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if Constants.Config.enableNetworkLogging {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let bodyText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "-"
                Log.info(Self.logTag, "sendVerifyCode response status=\(status) body=\(Self.redactToken(bodyText))")
            }
            
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                let status = httpResponse.statusCode
                if let e = ServerError.parse(data: data, status: status), e.errorCode != nil {
                    completion(.failure(.server(e, intent: .send)))
                } else {
                    completion(.failure(.httpError(status: status, intent: .send)))
                }
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let code = json["code"] as? Int {
                    if code == 0 {
                        let retryAfter = ((json["data"] as? [String: Any])?["retry_after"] as? NSNumber)?.intValue
                        completion(.success(retryAfter ?? Self.defaultResendSeconds))
                    } else if let e = ServerError.parse(json), e.errorCode != nil {
                        completion(.failure(.server(e, intent: .send)))
                    } else {
                        // 老格式服务端：msg 可能是中文，不直接显示
                        completion(.failure(.httpError(status: code, intent: .send)))
                    }
                } else {
                    completion(.failure(.invalidResponse))
                }
            } catch {
                completion(.failure(.invalidResponse))
            }
        }.resume()
    }
    
    func loginWithCode(email: String, code: String, completion: @escaping (Result<Void, AuthServiceError>) -> Void) {
        guard let url = URL(string: Constants.Network.authURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        
        RequestTrace.apply(&request)
        request.timeoutInterval = Constants.Network.timeoutInterval
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "request_type": "login_with_email_verify_code",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": [
                "email": email,
                "device_id": deviceId,
                "verify_code": code,
                "platform": "ios",
                "language": LocalizationManager.shared.currentLanguage.rawValue
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            // 走 Log 而不是 print：登录是唯一一条以前没有文件日志的网络路径，
            // 出问题时（验证码没收到、登录后立刻被踢）设备上捞不到任何痕迹，
            // 只能靠连着 Xcode 复现 —— 而这类问题恰恰多发在测试机上。
            if Constants.Config.enableNetworkLogging,
               let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) {
                Log.info(Self.logTag, "loginWithCode request url=\(url) body=\(bodyString)")
            }
        } catch {
            completion(.failure(.serializationError))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if Constants.Config.enableNetworkLogging {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let bodyText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "-"
                Log.info(Self.logTag, "loginWithCode response status=\(status) body=\(Self.redactToken(bodyText))")
            }
            
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                let status = httpResponse.statusCode
                if let e = ServerError.parse(data: data, status: status), e.errorCode != nil {
                    completion(.failure(.server(e, intent: .verify)))
                } else {
                    completion(.failure(.httpError(status: status, intent: .verify)))
                }
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let retCode = json["code"] as? Int {
                    
                    // Accept 0 (Created/Updated) or 200 (Existing/No Update) as success
                    if retCode == 0 || retCode == 200 {
                        // Parse and save login data
                        // token 是登录的唯一必要产物：账号身份就是用户输入的 email，
                        // 服务端返回的 uid 只是个附带的哈希，缺了不影响任何事。
                        //
                        // 拿不到 token 必须报失败。这里以前是「打个警告然后 completion(.success)」，
                        // 后果很严重：saveLoginInfo 压根没执行，Keychain 里还是上一个账号的
                        // token 与 email，用户以为登进了 B，App 实际仍然是 A —— 换账号检测
                        // 不触发、本地数据不清，B 会看到 A 的资料和消息，还以 A 的身份发请求。
                        guard let dataDict = json["data"] as? [String: Any],
                              let token = dataDict["token"] as? String,
                              !token.isEmpty else {
                            Log.error("AuthService", "登录响应 code=\(retCode) 但缺少 token，判为失败")
                            completion(.failure(.invalidResponse))
                            return
                        }
                        let uid = (dataDict["uid"] as? String) ?? ""
                        let expireDays = dataDict["expire_days"] as? Int ?? 30
                        AuthStorage.shared.saveLoginInfo(email: email, uid: uid, token: token, expireDays: expireDays)
                        // 高级会员体验期（见 Tools/doc/高级会员体验期接口.md）。只取这一个字段：
                        // 登录响应里的 user_level / level_end_at 一概不落地——服务端若没带或返回 free，
                        // 落地会把用户兑换来的会员抹掉。字段缺失时 applyPremiumTrial 直接返回，行为与接入前一致。
                        // 必须在 saveLoginInfo 之后调用：记录按 uid 存，uid 还没写入时会落不进去。
                        let trialEnd = SubscriptionManager.parseServerDate(dataDict["premium_trial_end_at"])
                        if trialEnd == nil {
                            // 显式打一行：applyPremiumTrial 收到 nil 是直接 return 的（保留旧值），
                            // 不打的话「体验期没生效」时分不清是服务端没下发还是客户端没解析。
                            Log.info("AuthService", "登录响应未带 premium_trial_end_at，保留本地已有体验期不动")
                        }
                        Task { @MainActor in SubscriptionManager.shared.applyPremiumTrial(endAt: trialEnd) }
                        // 补发登录前积压的订阅上报（先买后登录 / 买完就掉登录态的情况）。
                        SubscriptionReportService.shared.flush(reason: "login")
                        // 服务端会员状态（订阅状态服务端化 §3.3）：登录后强制拉一次。
                        MembershipStatusService.shared.refresh(reason: "login", force: true)
                        // 睡眠计划：登出会清空本地，换机/重装同理，登录后必须从服务端拉回来
                        //（本地没有 last_sync_at 时走全量 query_plans）。
                        SleepPlanSyncService.shared.syncAfterLogin()
                        // 新 token 落库后立刻给所有已绑设备同步过去——之前的 token 指纹
                        // 全部失效，需要重新推。force=true 跳 cooldown。
                        DeviceLoginPusher.shared.pushPendingForAllEntries()
                        completion(.success(()))
                    } else if let e = ServerError.parse(json), e.errorCode != nil {
                        completion(.failure(.server(e, intent: .verify)))
                    } else {
                        completion(.failure(.apiError(code: retCode, message: nil)))
                    }
                } else {
                    completion(.failure(.invalidResponse))
                }
            } catch {
                completion(.failure(.invalidResponse))
            }
        }.resume()
    }
}
