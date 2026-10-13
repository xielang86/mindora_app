import Foundation

extension Optional where Wrapped == String {
    /// 去掉首尾空白后仍非空才返回值，否则返回 nil。
    ///
    /// 服务端的「字段缺失」和「字段在但值是空串」对 UI 是同一件事：都没有可展示的内容，
    /// 都该回退本地兜底文案。但 Swift 里 `""` 是非 nil 的，`?? 兜底` 和 `if let` 都会把空串
    /// 当成有效内容放行——健康页周/月/日就是这么把兜底文案跳过、标签直接渲染成空白的
    /// （真机日志：analysis_sleep_week 16 次响应全是 `"body": "", "description": ""`）。
    ///
    /// 取服务端文案时一律用 `xxx.nonBlank ?? 本地兜底`，别直接 `??`。
    var nonBlank: String? {
        guard let self else { return nil }
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
