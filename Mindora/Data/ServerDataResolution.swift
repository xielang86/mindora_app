//
//  ServerDataResolution.swift
//  mindora
//
//  服务端数据的**统一三态**解析层。全 App 只此一套口径，不允许各页面各写各的。
//
//  ## 为什么必须三态
//
//  服务端数据只有三种状态，而 `try?` 会把后两种揉成同一个 `nil`：
//
//  | 状态 | 含义 | 正确行为 |
//  | --- | --- | --- |
//  | 应答 + 有内容 | 服务端给了这份内容 | 展示，并写入缓存 |
//  | 应答 + 内容为空 | 服务端**明确说**「没有内容」 | 展示 `"--"`，并**清掉**缓存旧值 |
//  | 请求失败（没应答） | 服务端**没说话**（断网/超时/5xx） | **沿用上次缓存**；无缓存才 `"--"` |
//
//  揉在一起的后果是真实发生过的：睡眠日/周/月视图曾用
//  `try? await fetchDayAnalysis(...)`，断网时把已经渲染好的正确文案抹成 `"--"`，
//  而正确行为是继续显示上次那份。反过来，如果失败也保留缓存但「应答为空」时
//  同样保留，则接口早就不返回内容了 UI 还在显示陈旧数据。两个方向都会出错，
//  所以两者必须分开。
//
//  ## 怎么用
//
//  ```swift
//  private let store = ServerBackedStore<DayAnalysis>(namespace: "health.analysis.day")
//
//  let resolution = await store.resolve(key: dayKey(date)) {
//      try await self.fetchDayAnalysis(date: date)   // 失败要 throw，别在里面 try?
//  }
//  render(resolution.displayValue)   // 三态已在层内处理好
//  ```
//
//  **约定**：传进 `resolve` 的闭包必须让失败**抛出**。在闭包里 `try?` 会把
//  「失败」伪装成「应答为空」，本层就失去意义了。
//

import Foundation

/// 一次服务端取数的结果。
enum ServerResolution<Value> {
    /// 服务端应答且有内容。
    case fresh(Value)
    /// 服务端应答，但明确表示没有内容（`code == 0` 且 `data` 为空）。
    case empty
    /// 请求失败，服务端没有应答。附带的是上次缓存（可能没有）。
    case offline(cached: Value?)

    /// 最终用于展示的值。`nil` 表示该展示缺失标记（通常是 `"--"`）。
    ///
    /// - `.fresh` → 新内容
    /// - `.empty` → `nil`（服务端说没有，不能拿缓存顶）
    /// - `.offline` → 缓存（没缓存则 `nil`）
    var displayValue: Value? {
        switch self {
        case .fresh(let value): return value
        case .empty: return nil
        case .offline(let cached): return cached
        }
    }

    /// 服务端这次是否真的应答了。字段级合并时用它决定「清旧值」还是「回退缓存」。
    var serverAnswered: Bool {
        switch self {
        case .fresh, .empty: return true
        case .offline: return false
        }
    }
}

/// 按 key 持久化服务端数据，并提供三态解析。
///
/// 线程安全：内存表用 `NSLock` 保护；`UserDefaults` 自身线程安全。
final class ServerBackedStore<Value: Codable>: @unchecked Sendable {

    private let namespace: String
    private let lock = NSLock()
    private var memory: [String: Value] = [:]

    /// - Parameter namespace: 持久化键前缀，形如 `"health.analysis.day"`。各调用方必须唯一。
    init(namespace: String) {
        self.namespace = namespace
    }

    private func defaultsKey(_ key: String) -> String { "\(namespace).\(key)" }

    /// 同步取上次缓存（无则 nil）。用于首屏立即回显，避免等网络时白屏。
    func cached(_ key: String) -> Value? {
        lock.lock(); defer { lock.unlock() }
        if let value = memory[key] { return value }
        guard let data = UserDefaults.standard.data(forKey: defaultsKey(key)),
              let value = try? JSONDecoder().decode(Value.self, from: data) else { return nil }
        memory[key] = value
        return value
    }

    /// 取数并按三态归类。
    ///
    /// - Parameter fetch: 取数闭包。**失败必须 throw**；返回 `nil` 表示服务端应答了但没有内容。
    func resolve(key: String, fetch: () async throws -> Value?) async -> ServerResolution<Value> {
        do {
            guard let value = try await fetch() else {
                // 服务端明确说没有内容 → 清掉旧值，否则 UI 会一直显示早已下架的内容
                clear(key)
                return .empty
            }
            store(value, key: key)
            return .fresh(value)
        } catch {
            // 没应答 → 沿用上次缓存，不要把已渲染的正确内容抹掉
            return .offline(cached: cached(key))
        }
    }

    func store(_ value: Value, key: String) {
        lock.lock(); defer { lock.unlock() }
        memory[key] = value
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey(key))
    }

    func clear(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        memory.removeValue(forKey: key)
        UserDefaults.standard.removeObject(forKey: defaultsKey(key))
    }

    /// 清空本 store 的全部缓存。登出/注销时调用 —— 缓存是账号级数据，不能带到下一个账号。
    func clearAll() {
        lock.lock(); defer { lock.unlock() }
        memory.removeAll()
        let prefix = "\(namespace)."
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
