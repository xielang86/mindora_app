import Foundation
import os

/// 三路输出的日志门面：
///   1. `print`（仅 DEBUG）—— Xcode / devicectl console 实时看
///   2. `os_log` —— 进 iOS 统一日志，Console.app 可实时看，事后 `log collect` 能捞
///   3. 滚动文件 —— 唯一能**事后追溯**的通道；用户报「昨天某点连不上」时靠它
///
/// 背景：之前只有 print，console 会话一断日志就没了，排查「昨天 18:16 连接失败」
/// 这类问题完全无从下手。设备端 user_server 早就在写文件日志，客户端反而没有。
enum Log {
    private static let df: DateFormatter = {
        let f = DateFormatter()
        // 日志时间戳要可比对、可 grep，钉死 POSIX，别跟系统历法/语言走
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private static let osLogger = os.Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.mindora316.mindora",
        category: "app"
    )

    private static func ts() -> String { df.string(from: Date()) }

    static func info(_ tag: String, _ message: @autoclosure () -> String) {
        emit(level: "INFO", tag: tag, message: message())
    }

    static func error(_ tag: String, _ message: @autoclosure () -> String) {
        emit(level: "ERROR", tag: tag, message: message())
    }

    private static func emit(level: String, tag: String, message: String) {
        let line = "[\(level)] [\(ts())] [\(tag)] \(message)"
        #if DEBUG
        print(line)
        #endif
        // privacy: .public —— 日志里不放 JWT / 密码原文（只打指纹与长度），
        // 打上 public 才能在 Console / log collect 里看到实际内容而不是 <private>。
        if level == "ERROR" {
            osLogger.error("\(line, privacy: .public)")
        } else {
            osLogger.info("\(line, privacy: .public)")
        }
        LogFileWriter.shared.append(line)
    }

    static func requestID() -> String {
        RequestTrace.newID()
    }

    static func prettyJSON(_ data: Data, maxChars: Int = 4000) -> String {
        let raw: String
        if let obj = try? JSONSerialization.jsonObject(with: data, options: []),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
           let str = String(data: pretty, encoding: .utf8) {
            raw = Self.redactSecrets(str)
        } else if let str = String(data: data, encoding: .utf8) {
            raw = Self.redactSecrets(str)
        } else {
            raw = "<non-utf8 body: \(data.count) bytes>"
        }

        if raw.count <= maxChars {
            return raw
        }

        let endIndex = raw.index(raw.startIndex, offsetBy: maxChars)
        return String(raw[..<endIndex]) + "…(truncated)"
    }

    /// 把请求/响应体里的长期凭证打码后再写日志。
    ///
    /// 放在 prettyJSON 里而不是靠每个调用点自觉：`enableNetworkLogging` 在 Release 也是
    /// 开的，日志还会落到 LogFileWriter 的滚动文件里；只要有一个调用点忘了打码，
    /// 用户的 JWT 就长期躺在设备磁盘上。真机实测漏的就是这一类——分析、首页、睡眠计划
    /// 这些接口的 body 直接进了 prettyJSON，一个字都没打码。
    ///
    /// 字段名两边都认：请求体用 `jwt_token`，登录响应用 `token`。
    private static let secretRegex = try? NSRegularExpression(
        pattern: "\"((?:jwt_)?token)\"\\s*:\\s*\"[^\"]*\"")

    static func redactSecrets(_ text: String) -> String {
        guard let regex = secretRegex else { return text }
        return regex.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text),
            withTemplate: "\"$1\": \"<redacted>\"")
    }
}

/// 滚动文件日志。串行队列写入，单文件超过 maxFileBytes 就换新文件，最多保留 maxFiles 个。
final class LogFileWriter {

    static let shared = LogFileWriter()

    /// 单文件上限 2MB、保留 3 个 —— 最多占 6MB，够覆盖几天的正常使用。
    private let maxFileBytes = 2 * 1024 * 1024
    private let maxFiles = 3

    private let queue = DispatchQueue(label: "com.mindora.logfile", qos: .utility)
    private var handle: FileHandle?
    private var currentSize = 0

    /// 日志目录：Library/Application Support/Logs。不放 Documents —— 那里开了文件共享
    /// 会暴露给用户；也不放 Caches —— 系统可能在磁盘紧张时清掉，正好丢掉要排查的那段。
    private(set) lazy var directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private lazy var nameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f
    }()

    private init() {}

    func append(_ line: String) {
        queue.async { [weak self] in
            guard let self else { return }
            guard let data = (line + "\n").data(using: .utf8) else { return }
            if self.handle == nil { self.openNewFile() }
            if self.currentSize + data.count > self.maxFileBytes {
                self.rotate()
            }
            self.handle?.write(data)
            self.currentSize += data.count
        }
    }

    /// 当前保留的日志文件，新的在前。导出 / 分享用。
    func files() -> [URL] {
        queue.sync {
            handle?.synchronizeFile()
            return existingFiles()
        }
    }

    /// 把所有日志合并成一个临时文件，方便一次性分享。
    func exportCombined() -> URL? {
        queue.sync {
            handle?.synchronizeFile()
            let all = existingFiles().reversed()   // 旧 → 新，时间顺序读起来才对
            var merged = Data()
            for url in all {
                if let d = try? Data(contentsOf: url) {
                    merged.append("===== \(url.lastPathComponent) =====\n".data(using: .utf8) ?? Data())
                    merged.append(d)
                    merged.append("\n".data(using: .utf8) ?? Data())
                }
            }
            guard !merged.isEmpty else { return nil }
            let out = FileManager.default.temporaryDirectory
                .appendingPathComponent("mindora-logs-\(nameFormatter.string(from: Date())).log")
            try? merged.write(to: out)
            return out
        }
    }

    // MARK: - Internals（全部在 queue 上跑）

    private func existingFiles() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return urls.filter { $0.pathExtension == "log" }.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return da > db
        }
    }

    private func openNewFile() {
        let url = directory.appendingPathComponent("mindora-\(nameFormatter.string(from: Date())).log")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try? FileHandle(forWritingTo: url)
        handle?.seekToEndOfFile()
        currentSize = 0
        pruneOldFiles()
    }

    private func rotate() {
        try? handle?.close()
        handle = nil
        openNewFile()
    }

    private func pruneOldFiles() {
        let files = existingFiles()
        guard files.count > maxFiles else { return }
        for url in files.dropFirst(maxFiles) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
