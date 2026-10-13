//
//  SessionExpirationCenter.swift
//  mindora
//
//  统一处理 token 过期 / 服务器返回 401 的场景。
//  - 任何 service 在拿到 HTTP response 后调用 handle(httpResponse:data:requestID:)
//  - 若识别为 token 失效，会执行"软退出"（保留用户数据）并 post 通知，
//    由 SceneDelegate 切换到 re-auth 邮箱页。
//  - 幂等：短时间内多次触发只处理第一次，避免并发请求引起多次切换。
//

import Foundation

extension Notification.Name {
    /// Token 过期 / 服务器返回 401。SceneDelegate 监听该通知并切到 re-auth 流程。
    static let sessionExpired = Notification.Name("MindoraSessionExpired")
}

enum SessionExpirationCenter {

    private static let logTag = "SessionExpirationCenter"
    private static let lock = NSLock()
    private static var isHandling = false

    /// 检测 HTTP 响应是否为 token 失效。命中则执行软清理并 post 通知。
    /// 返回 true 表示已识别为 token 过期（调用方仍然应该 throw 自己的错误，UI 会被通知接管）。
    @discardableResult
    static func handle(httpResponse: URLResponse?,
                       data: Data?,
                       requestID: String? = nil) -> Bool {
        guard isTokenExpired(httpResponse: httpResponse, data: data) else {
            return false
        }
        triggerExpired(requestID: requestID)
        return true
    }

    /// 调试开关：短路掉 401 处理。见 Constants.Config.ignoreSessionExpiration。
    /// 注意它只挡「踢回欢迎页」这个动作，请求该失败还是失败。
    private static var shouldIgnore: Bool {
        Constants.Config.ignoreSessionExpiration
    }

    /// 判断响应是否表示 token 失效：HTTP 401，或 body 里 code=401 / msg 含 "token invalid or expired"。
    static func isTokenExpired(httpResponse: URLResponse?, data: Data?) -> Bool {
        if let http = httpResponse as? HTTPURLResponse, http.statusCode == 401 {
            return true
        }
        guard let data = data, !data.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return false
        }
        if let code = json["code"] as? Int, code == 401 {
            return true
        }
        if let msg = json["msg"] as? String,
           msg.lowercased().contains("token invalid or expired") {
            return true
        }
        return false
    }

    /// 主动触发（一般由 handle 内部调用；外部一般不直接用）。
    static func triggerExpired(requestID: String? = nil) {
        if shouldIgnore {
            Log.info(logTag, "[DEBUG] ignoreSessionExpiration=on，忽略 401，不做软登出（req:\(requestID ?? "-")）")
            return
        }

        // 幂等：避免并发请求都进入这条分支后多次切 root。
        lock.lock()
        if isHandling {
            lock.unlock()
            Log.info(logTag, "session expired already being handled, skip (req:\(requestID ?? "-"))")
            return
        }
        isHandling = true
        lock.unlock()

        Log.info(logTag, "session expired detected (req:\(requestID ?? "-")) — soft logout + notify")

        SessionResetter.reset(.tokenOnly)

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
        }
    }

    /// 一次切换完成后调用，重置幂等开关，让下一次过期能再次触发。
    static func resetHandlingFlag() {
        lock.lock()
        isHandling = false
        lock.unlock()
    }
}
