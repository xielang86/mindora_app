//
//  RequestTrace.swift
//  Mindora
//
//  所有发往服务端的请求统一走 RequestTrace.apply(&request)：
//  - X-Client-Request-ID：每个请求一个追踪号（16 位小写 hex）。服务端每条日志都带它，响应头原样带回；
//    拿着它能在服务端捞出这一个请求的完整处理链路。
//  - X-Mindora-Client：ios/<版本> (<构建号>; iOS <系统>; <机型>)，服务端据此区分来源。
//  详见 Tools/doc/客户端-请求追踪与客户端标识.md。
//

import Foundation
import UIKit

enum RequestTrace {
    static let requestIDHeader = "X-Client-Request-ID"
    static let clientHeader = "X-Mindora-Client"

    /// 启动后拼一次：ios/1.3.0 (18; iOS 18.1; iPhone15,2)
    static let clientLabel: String = {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let os = "iOS " + UIDevice.current.systemVersion
        return "ios/\(version) (\(build); \(os); \(deviceModel))"
    }()

    /// 新的追踪号：16 位小写 hex（8 位一天内容易重复，服务端按它串链路会串号）
    static func newID() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)).lowercased()
    }

    /// 给请求加上追踪头与客户端标识；返回本次的 requestID，调用方记日志用。
    /// 同一次业务重试可传入同一个 requestID，服务端能把几次尝试串起来。
    @discardableResult
    static func apply(_ request: inout URLRequest, requestID: String? = nil) -> String {
        let id = requestID ?? newID()
        request.setValue(id, forHTTPHeaderField: requestIDHeader)
        request.setValue(clientLabel, forHTTPHeaderField: clientHeader)
        return id
    }

    /// 服务端回的追踪号（正常情况等于我们发的；老服务端没有则为 nil）
    static func responseID(_ response: URLResponse?) -> String? {
        (response as? HTTPURLResponse)?.value(forHTTPHeaderField: requestIDHeader)
    }

    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let model = mirror.children.reduce(into: "") { acc, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            acc.append(String(UnicodeScalar(UInt8(value))))
        }
        return model.isEmpty ? UIDevice.current.model : model
    }
}
