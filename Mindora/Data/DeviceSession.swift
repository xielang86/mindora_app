import Foundation

final class DeviceSession {
    static let shared = DeviceSession()
    private init() {}

    private enum Keys { static let host = "mindora.device.host"; static let port = "mindora.device.port" }

    private var lastLoggedHost: String? = nil
    var host: String? {
        get {
            let v = UserDefaults.standard.string(forKey: Keys.host)
            if v != lastLoggedHost {
                Log.info("DeviceSession", "host=\(v ?? "nil")")
                lastLoggedHost = v
            }
            return v
        }
        set {
            let old = UserDefaults.standard.string(forKey: Keys.host)
            if old != newValue {
                Log.info("DeviceSession", "host change \(old ?? "nil") -> \(newValue ?? "nil")")
            }
            UserDefaults.standard.setValue(newValue, forKey: Keys.host)
            lastLoggedHost = newValue
        }
    }

    private var lastLoggedPort: Int? = nil
    var port: Int {
        get {
            let raw = UserDefaults.standard.integer(forKey: Keys.port)
            let v = raw == 0 ? 9102 : raw
            if lastLoggedPort != v { Log.info("DeviceSession", "port=\(v)"); lastLoggedPort = v }
            return v
        }
        set {
            let old = UserDefaults.standard.integer(forKey: Keys.port)
            if old != newValue { Log.info("DeviceSession", "port change \(old) -> \(newValue)") }
            UserDefaults.standard.setValue(newValue, forKey: Keys.port)
            lastLoggedPort = newValue
        }
    }

    var isConnected: Bool { host != nil }

    func clear() {
        Log.info("DeviceSession", "clear session")
        UserDefaults.standard.removeObject(forKey: Keys.host)
        UserDefaults.standard.removeObject(forKey: Keys.port)
    }
}
