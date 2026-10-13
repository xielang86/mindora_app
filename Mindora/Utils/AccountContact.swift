//
//  AccountContact.swift
//  mindora
//
//  账号绑定联系方式（注销验证码的接收方）的识别与脱敏展示。
//  客户端登录标识目前是邮箱（AuthStorage.email），但为稳妥同时兼容手机号：
//  含 "@" → 邮箱；否则看起来像号码 → 手机；都不是 → 未知（用通用文案兜底）。
//

import Foundation

struct AccountContact {
    enum Kind { case email, phone }

    let kind: Kind
    /// 脱敏后的展示串，如 "ga****@gmail.com" / "138****5678"。
    let masked: String

    /// 从 AuthStorage 读取当前绑定联系方式；无法识别时返回 nil（调用方用通用文案）。
    static func current() -> AccountContact? {
        let raw = (AuthStorage.shared.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return from(raw)
    }

    static func from(_ raw: String) -> AccountContact? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.contains("@") {
            return AccountContact(kind: .email, masked: maskEmail(value))
        }
        // 手机号：去掉常见分隔符后主要是数字（允许前导 +）。
        let digits = value.filter { $0.isNumber }
        let looksLikePhone = digits.count >= 5 &&
            value.allSatisfy { $0.isNumber || $0 == "+" || $0 == "-" || $0 == " " || $0 == "(" || $0 == ")" }
        if looksLikePhone {
            return AccountContact(kind: .phone, masked: maskPhone(value))
        }
        return nil
    }

    /// 邮箱：保留本地部分前 1-2 位 + "****"，域名完整保留。abcdef@gmail.com → "ab****@gmail.com"。
    static func maskEmail(_ email: String) -> String {
        guard let at = email.firstIndex(of: "@") else { return email }
        let local = String(email[email.startIndex..<at])
        let domain = String(email[at...]) // 含 "@"
        let keep = local.count <= 2 ? 1 : 2
        let head = String(local.prefix(keep))
        return head + "****" + domain
    }

    /// 手机号：保留前 3 位和后 4 位（不足则相应缩减），中间用 "****" 遮掩。保留前导 "+"。
    static func maskPhone(_ phone: String) -> String {
        let hasPlus = phone.trimmingCharacters(in: .whitespaces).hasPrefix("+")
        let digits = Array(phone.filter { $0.isNumber })
        let prefix = hasPlus ? "+" : ""
        if digits.count <= 4 {
            return prefix + "****"
        }
        let headCount = min(3, max(0, digits.count - 4))
        let head = String(digits.prefix(headCount))
        let tail = String(digits.suffix(4))
        return prefix + head + "****" + tail
    }
}
