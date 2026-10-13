//
//  NetworkPacing.swift
//  Mindora
//
//  客户端请求错峰（分散 / 抖动）工具。
//
//  背景：任何「不是用户点出来的」请求 —— 周期定时器、回前台自动同步、后台任务、
//  失败重试 —— 都可能让成千上万台设备在同一秒撞向服务端。设备时钟对齐（整点、
//  固定间隔从同一事件起算）会把这种撞击放大成周期性尖峰。
//
//  规则：
//  1. 周期性请求的间隔一律走 `jittered(_:)`，不要用裸的固定间隔；
//  2. 事件触发的后台上报（回前台补传等）先 `spreadDelay` 随机延迟再发；
//  3. 服务端可用响应里的 `next_query_after` 把客户端间隔顶上去（全局降频阀门）；
//  4. 用户主动点出来的请求不加延迟 —— 那本来就是分散的，且用户在等。
//

import Foundation

enum NetworkPacing {

    /// 给周期性间隔加 ±ratio 的随机抖动（默认 ±20%）。
    /// 每次重新排程都要重新调用，才能让原本对齐的设备逐轮散开。
    static func jittered(_ base: TimeInterval, ratio: Double = 0.2) -> TimeInterval {
        guard base > 0, ratio > 0 else { return base }
        let delta = base * min(max(ratio, 0), 1)
        return max(1, base + Double.random(in: -delta...delta))
    }

    /// 0...max 之间的随机延迟，用于把「同一事件触发」的后台上报摊开。
    static func spreadDelay(upTo max: TimeInterval) -> TimeInterval {
        guard max > 0 else { return 0 }
        return Double.random(in: 0...max)
    }

    /// 随机延迟后执行（默认主队列）。用于后台上报类请求，用户不在等它。
    static func afterSpread(upTo max: TimeInterval,
                            on queue: DispatchQueue = .main,
                            _ work: @escaping () -> Void) {
        queue.asyncAfter(deadline: .now() + spreadDelay(upTo: max), execute: work)
    }
}

/// 失败退避。**这是最关键的一环**：服务端出问题（5xx / 超时）时，如果客户端照旧
/// 每次回前台就重试，等于在服务端最虚弱的时候加倍施压，把局部故障放大成雪崩。
/// 每次失败把等待时间翻倍（并带 ±50% 抖动，避免所有设备同时重试），成功即清零。
struct NetworkBackoff {
    private let base: TimeInterval
    private let cap: TimeInterval
    private var failureCount = 0
    private var blockedUntil: Date?

    init(base: TimeInterval = 30, cap: TimeInterval = 30 * 60) {
        self.base = base
        self.cap = cap
    }

    /// 当前是否处于退避期（应跳过本次请求）。
    var isBlocked: Bool {
        guard let until = blockedUntil else { return false }
        return Date() < until
    }

    /// 距退避结束还有多少秒（仅用于打日志）。
    var remainingSeconds: Int {
        guard let until = blockedUntil else { return 0 }
        return Swift.max(0, Int(until.timeIntervalSinceNow))
    }

    mutating func recordFailure() {
        failureCount += 1
        // 30s → 60s → 120s … 封顶 cap，再叠 ±50% 抖动。
        let raw = Swift.min(base * pow(2, Double(failureCount - 1)), cap)
        blockedUntil = Date().addingTimeInterval(NetworkPacing.jittered(raw, ratio: 0.5))
    }

    mutating func recordSuccess() {
        failureCount = 0
        blockedUntil = nil
    }
}
