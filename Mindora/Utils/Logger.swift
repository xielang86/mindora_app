import Foundation

enum Log {
    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private static func ts() -> String { df.string(from: Date()) }

    static func info(_ tag: String, _ message: @autoclosure () -> String) {
        #if DEBUG
        print("[INFO] [\(ts())] [\(tag)] \(message())")
        #endif
    }

    static func error(_ tag: String, _ message: @autoclosure () -> String) {
        #if DEBUG
        print("[ERROR] [\(ts())] [\(tag)] \(message())")
        #endif
    }

    static func prettyJSON(_ data: Data, maxChars: Int = 4000) -> String {
        let raw: String
        if let obj = try? JSONSerialization.jsonObject(with: data, options: []),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
           let str = String(data: pretty, encoding: .utf8) {
            raw = str
        } else if let str = String(data: data, encoding: .utf8) {
            raw = str
        } else {
            raw = "<non-utf8 body: \(data.count) bytes>"
        }

        if raw.count <= maxChars {
            return raw
        }

        let endIndex = raw.index(raw.startIndex, offsetBy: maxChars)
        return String(raw[..<endIndex]) + "…(truncated)"
    }
}
