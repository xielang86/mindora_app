//
//  ServerError.swift
//  mindora
//
//  mindora_auth 的统一错误形状（服务端 common/errors.py）：
//
//    {"code": 429, "error_code": "send_too_frequent", "params": {"retry_after": 42},
//     "msg": "You can request a new code in 42 seconds."}
//
//  - error_code：稳定错误码，要做特殊处理（倒计时、判 token 失效）时认它，不要比对文案。
//  - msg：服务端已按请求里的 language 翻好，可以直接显示。
//  - params：文案里的数值单独给出（如 retry_after 秒数）。
//
//  只有带 error_code 的响应，msg 才保证是按 App 语言翻译过的；老格式的 msg / detail 可能是中文，
//  不能直接给外语用户看 —— 这时 displayMessage 为 nil，调用方用本地文案兜底。
//

import Foundation

struct ServerError {
    /// 业务码（HTTP 200 + code）或 HTTP 状态码。
    let code: Int?
    let errorCode: String?
    let message: String?
    let params: [String: Any]

    var retryAfter: Int? { Self.int(params["retry_after"]) }

    /// 可直接展示给用户的文案；服务端没给翻译好的文案时为 nil。
    var displayMessage: String? {
        guard errorCode != nil, let msg = message?.trimmingCharacters(in: .whitespacesAndNewlines), !msg.isEmpty else {
            return nil
        }
        return msg
    }

    var isTokenError: Bool { errorCode == "token_expired" || errorCode == "token_invalid" }

    /// 从响应 JSON 里取错误；没有任何错误信息（既无 error_code 也无 msg/detail）时返回 nil。
    static func parse(_ json: [String: Any]?, status: Int? = nil) -> ServerError? {
        guard let json else { return nil }
        let errorCode = json["error_code"] as? String
        let message = (json["msg"] as? String) ?? (json["detail"] as? String)
        guard errorCode != nil || message != nil else { return nil }
        return ServerError(code: int(json["code"]) ?? status,
                           errorCode: errorCode,
                           message: message,
                           params: (json["params"] as? [String: Any]) ?? [:])
    }

    static func parse(data: Data?, status: Int? = nil) -> ServerError? {
        guard let data else { return nil }
        return parse((try? JSONSerialization.jsonObject(with: data)) as? [String: Any], status: status)
    }

    private static func int(_ value: Any?) -> Int? {
        (value as? Int) ?? (value as? NSNumber)?.intValue
    }
}
