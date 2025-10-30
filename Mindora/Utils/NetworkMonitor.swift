import Foundation
import Network

/// 使用 NWPathMonitor 监听网络状态，仅在 Wi‑Fi 可用时允许扫描
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "net.monitor")

    enum Connectivity {
        case wifi
        case cellular
        case offline
        case other
    }

    private(set) var connectivity: Connectivity = .offline
    var onChange: ((Connectivity) -> Void)?

    private init() {}

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let status: Connectivity
            if path.status != .satisfied {
                status = .offline
            } else if path.usesInterfaceType(.wifi) {
                status = .wifi
            } else if path.usesInterfaceType(.cellular) {
                status = .cellular
            } else {
                status = .other
            }
            if status != self.connectivity {
                let old = self.connectivity
                self.connectivity = status
                Log.info("Network", "status changed old=\(old) new=\(status) expensive=\(path.isExpensive)")
                DispatchQueue.main.async { self.onChange?(status) }
            }
        }
        monitor.start(queue: queue)
    }

    func stop() { monitor.cancel() }
}
