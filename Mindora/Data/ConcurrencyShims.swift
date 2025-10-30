import Foundation

// 全局并发兼容补丁：Foundation 部分类在当前工程中被异步 @Sendable 闭包捕获
// Swift 并未自动推断为 Sendable，因此显式标记为 @unchecked Sendable。
// 已知使用场景：HealthDataManager 中的 HKSampleQuery 回调。
// 注意：这些类本身不是线程安全的；这里只用于只读捕获（查询条件/排序描述符），风险可控。
#if swift(>=5.7)
extension NSPredicate: @unchecked @retroactive Sendable {}
extension NSSortDescriptor: @unchecked @retroactive Sendable {}
#endif
