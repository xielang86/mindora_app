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
}
