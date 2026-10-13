import Foundation

final class DeviceSession {
    static let shared = DeviceSession()
    private init() {
        migrateLegacySingleEntryIfNeeded()
    }

    /// Posted on any change to `entries` (add / update / remove / clear).
    static let didChangeNotification = Notification.Name("DeviceSession.didChange")

    enum Transport: String, Codable {
        case wifi   // Bonjour / mDNS only
        case ble    // BLE only
        case both   // Bonjour + BLE matched on the same device_id
    }

    /// One paired device. Persisted as part of `entries` via JSON to UserDefaults.
    ///
    /// ⚠️ 三个名字 / id 字段语义不要混（详见 Tools/doc/设备端接口契约.md §1.4）：
    /// - `model` ：设备型号常量，所有同款共用，如 `"Mindora 2026"`。来自 Bonjour service.name
    ///            或 BLE local name。用户不可改。
    /// - `displayName` ：用户可见名 = 用户自定义昵称，默认 = `model`。详情页可编辑。
    /// - `deviceID` ：每台机器唯一的底层 id（来自 Bonjour TXT / BLE characteristic）。dedup key。
    struct Entry: Codable, Equatable {
        /// Primary host — mDNS hostname when available, else IPv4, else service.name. Identity marker only.
        let host: String?
        /// IPv4 captured at pair time. Fallback when mDNS can't resolve `host`.
        let hostFallback: String?
        /// `CBPeripheral.identifier` for BLE-paired devices. Lets `retrievePeripherals(withIdentifiers:)`
        /// fetch the same peripheral after relaunch.
        let bleIdentifier: UUID?
        /// Canonical `device_id` (unique per physical device). Dedup key when re-pairing.
        let deviceID: String?
        /// Device model constant, e.g. `"Mindora 2026"`. Shared across all units of the same SKU.
        let model: String?
        /// User-editable nickname. Defaults to `model` on first pair; users can rename via detail page.
        var displayName: String?
        /// Which channel(s) saw this device at pair time.
        let transport: Transport
        /// When this entry was created or last updated. Used for newest-first ordering.
        let pairedAt: Date
        /// 用户主动断开标志。nil 或 false = 用户希望连接（默认）；true = 用户在 DM / DeviceDetail
        /// 里主动 tap 了断开。这跟"是否当前在网络范围"是独立的两个维度——出现 Connected 显示的
        /// 条件是 isReachable && !isUserDisconnected。可选类型保证老存档反序列化时回落到 nil(=false)。
        var isUserDisconnected: Bool?
        /// 上一次成功推送到设备 /login 的 JWT 指纹（SHA256 前 16 hex 字符）。用来去重：
        ///   - 指纹跟当前 AuthStorage 的 token 指纹一致 → 设备已经知道这个用户，不重复推
        ///   - 不一致 / nil → 需要（重新）推一次；外层 DeviceLoginPusher 在心跳里持续重试
        /// 存指纹而不是 token 本身，避免敏感数据双重落地。
        var lastLoginPushedTokenFingerprint: String?
        /// 上一次成功推送的时刻。指纹记忆是**客户端单方面的记忆**，只能证明「我推成功过」，
        /// 证明不了「设备现在还持有这个 token」（设备重启 / 恢复出厂 / 清存储都察觉不到）。
        /// 因此给记忆加保质期：超过 DeviceLoginPusher.memoryTTL 就当作没推过，重推一次。
        /// 有默认值，老存档反序列化成 nil（= 已过期 → 重推一次），不影响解码。
        var lastLoginPushedAt: Date? = nil
    }

    private enum Keys {
        static let entries = "mindora.device.entries"
        /// 持久化的"deviceID → 用户自定义昵称"映射，跟 entries 数组解耦——这样
        /// remove(entry) 删活 entry 时不会丢昵称记忆，用户下次重新绑定同一台 device_id
        /// 仍然能看到自己当初改过的名字。clear()（账户级清空）才会一起 wipe。
        static let nicknames = "mindora.device.nicknames"
        // Legacy single-entry keys — migrated on first run, then scrubbed.
        static let legacyHost = "mindora.device.host"
        static let legacyHostFallback = "mindora.device.host_fallback"
        static let legacyBleIdentifier = "mindora.device.ble_identifier"
        static let legacyDeviceID = "mindora.device.id"
        static let legacyDisplayName = "mindora.device.display_name"
        static let legacyTransport = "mindora.device.transport"
        static let legacyPort = "mindora.device.port"  // even older, from the 9102 era
    }

    /// Newest-first list of paired devices. Read-only externally; mutate via
    /// `connect(...)` / `remove(_:)` / `clear()`.
    private(set) var entries: [Entry] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Keys.entries) else { return [] }
            return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Keys.entries)
            }
        }
    }

    var isConnected: Bool { !entries.isEmpty }

    /// Convenience for code that hasn't been multi-device-aware'd: returns the newest entry's
    /// display name. Code that supports multiple devices should iterate `entries` directly.
    var displayName: String? { entries.first?.displayName }

    /// 按 device_id 持久化的用户昵称表。私有读写；外部用 `rememberedNickname(forDeviceID:)`
    /// 查询，写入只发生在 rename() / connect() 里。clear() 时一起清空（账户级 wipe 语义）。
    private var nicknames: [String: String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Keys.nicknames) else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Keys.nicknames)
            }
        }
    }

    /// 查这台 device_id 之前用户改过的昵称（如果有且没被重置回默认）。供 UI 在设备
    /// 未处于已绑状态（如刚被 remove 还在扫描列表里）时显示用户记忆里的名字。
    func rememberedNickname(forDeviceID deviceID: String) -> String? {
        nicknames[deviceID]
    }

    // MARK: - Mutation

    /// Add a paired device, or update the existing entry for the same physical device.
    /// Dedup priority: deviceID > bleIdentifier > host > displayName. When a match is found,
    /// the entry is replaced in place (preserving its slot in the list); otherwise the new entry
    /// is prepended (newest-first).
    ///
    /// - Parameters:
    ///   - bonjour: NetService from mDNS discovery. Doesn't need to be resolved.
    ///   - bleIdentifier: `CBPeripheral.identifier` for BLE-discovered devices.
    ///   - deviceID: Canonical id from Bonjour TXT or BLE characteristic (每台唯一).
    ///   - model: 设备型号，如 "Mindora 2026"，从 Bonjour service.name / BLE local name 来。
    ///   - displayName: 用户可见名 / 昵称。首次绑定通常 == model；后续可由用户在详情页改。
    ///                 不传时默认用 model。
    func connect(
        bonjour: NetService? = nil,
        bleIdentifier: UUID? = nil,
        deviceID: String? = nil,
        model: String? = nil,
        displayName: String? = nil
    ) {
        if bonjour == nil && bleIdentifier == nil {
            Log.error("DeviceSession", "connect() called with no transport — ignoring")
            return
        }

        let resolvedHost = bonjour?.hostName
        let ipv4 = bonjour?.firstIPv4Address
        let primary: String? = bonjour.flatMap { resolvedHost ?? ipv4 ?? $0.name }

        let newTransport: Transport
        if bonjour != nil && bleIdentifier != nil { newTransport = .both }
        else if bonjour != nil { newTransport = .wifi }
        else { newTransport = .ble }

        let resolvedID = deviceID ?? bonjour?.deviceID
        let resolvedModel = model ?? bonjour?.name
        // displayName 解析优先级：
        //   1) 调用方显式传入（一般 == model，scan 路径不显式覆盖）
        //   2) 持久化昵称表里 device_id 对应的用户改过的名字（即使之前断开过）
        //   3) 当前型号 model
        // (2) 是关键——用户改过昵称、断开后再次绑定同一台 device_id 时，自动恢复昵称。
        var resolvedDisplayName = displayName
        if resolvedDisplayName == nil || resolvedDisplayName == resolvedModel,
           let did = resolvedID, let remembered = nicknames[did] {
            resolvedDisplayName = remembered
        }
        if resolvedDisplayName == nil {
            resolvedDisplayName = resolvedModel
        }

        let entry = Entry(
            host: primary,
            hostFallback: ipv4,
            bleIdentifier: bleIdentifier,
            deviceID: resolvedID,
            model: resolvedModel,
            displayName: resolvedDisplayName,
            transport: newTransport,
            pairedAt: Date(),
            isUserDisconnected: false,   // 新绑定默认 "希望连接"
            lastLoginPushedTokenFingerprint: nil  // 新绑定还没推过 JWT
        )

        var current = entries
        // 同物理设备查重：任一非空标识符跟已有条目对得上就视为同一台，避免出现
        // "BLE 路径绑了一条 + Bonjour 路径再绑一条"这种重复卡片的 bug。
        // 优先级 deviceID > bleIdentifier > host > displayName。displayName 作为 soft
        // fallback：两台不同 Mindora 撞 4 位数字概率约 1/6561，比"经常出现重复"代价低。
        let matchIdx = current.firstIndex { existing in
            if let did = entry.deviceID, existing.deviceID == did { return true }
            if let ble = entry.bleIdentifier, existing.bleIdentifier == ble { return true }
            if let host = entry.host, existing.host == host { return true }
            // 注意：这里用 model 兜底而不是 displayName，因为 displayName 用户可能已经改过
            // 不再代表"同款设备"。同款 model 的多台机器靠上面三个唯一 id 区分，model 仅作
            // 三个 id 全 nil 的最后退路（极少发生）。
            if let m = entry.model, existing.model == m, entry.deviceID == nil,
               entry.bleIdentifier == nil, entry.host == nil { return true }
            return false
        }

        let finalEntry: Entry
        if let idx = matchIdx {
            // 重新绑定同一台时：保留用户已经改过的昵称，不被自动 fallback 覆盖回 model
            var merged = entry
            let prev = current[idx]
            if let prevName = prev.displayName, prevName != prev.model {
                merged.displayName = prevName
            }
            Log.info("DeviceSession", "update entry[\(idx)] name=\(merged.displayName ?? "nil") device_id=\(resolvedID ?? "nil")")
            current[idx] = merged
            finalEntry = merged
        } else {
            Log.info("DeviceSession", "add entry name=\(resolvedDisplayName ?? "nil") transport=\(newTransport.rawValue) device_id=\(resolvedID ?? "nil")")
            current.insert(entry, at: 0)
            finalEntry = entry
        }

        entries = current
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)

        // 绑定落库后立刻把 JWT 推到设备 user_server /login，让设备知道当前用户身份。
        // Fire-and-forget：DeviceLoginPusher 自己负责异步发送 + 重试，不阻塞 connect 主流程。
        // 失败也不影响绑定本身——下次 connect 会重新推一遍（接受同 device_id 的重新绑定）。
        DeviceLoginPusher.shared.pushLogin(for: finalEntry)
    }

    /// 标记某个 entry 上一次成功推送到设备 /login 的 JWT 指纹。下次推送前查这个值，
    /// 跟当前 AuthStorage.token 指纹一致就跳过重复推。
    ///
    /// 不发 didChangeNotification——这是 pusher 的内部簿记，UI 不关心，避免无谓 reload。
    /// 内部直接读写 UserDefaults 跟 entries 同源。
    func markLoginPushed(deviceID did: String, tokenFingerprint fp: String) {
        var current = entries
        guard let idx = current.firstIndex(where: { $0.deviceID == did }) else { return }
        var updated = current[idx]
        // 指纹没变也要刷新时间戳 —— 记忆的保质期从「最近一次推成功」算起。
        updated.lastLoginPushedTokenFingerprint = fp
        updated.lastLoginPushedAt = Date()
        current[idx] = updated
        entries = current
        Log.info("DeviceSession", "markLoginPushed device_id=\(did) fp=\(fp)")
    }

    /// 标记某个 entry 的"用户主动断开"状态。toggle 模式：从 DM 卡片或 DeviceDetail 点 Disconnect
    /// 时调 true；点 Connect / 重新激活时调 false。这跟 remove(entry) 不一样——entry 还在
    /// entries 数组里，DM 列表里仍可见，状态显示 "Not Connected"，用户可以随时 toggle 回来。
    /// 不发 didChangeNotification 之外的额外副作用；UI 自行根据 entry.isUserDisconnected 渲染。
    func setUserDisconnected(_ entry: Entry, to value: Bool) {
        var current = entries
        guard let idx = current.firstIndex(of: entry) else { return }
        var updated = current[idx]
        let normalizedNew: Bool? = value ? true : false
        if updated.isUserDisconnected == normalizedNew { return }
        updated.isUserDisconnected = normalizedNew
        current[idx] = updated
        entries = current
        Log.info("DeviceSession", "setUserDisconnected entry[\(idx)] -> \(value)")
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)

        // 用户点「重新连接」→ 无条件重推 JWT（忽略指纹）。这是人为干预的兜底入口：
        // 设备侧丢了 token 而客户端记忆还在时，用户重连一次就能自愈。
        if normalizedNew == false {
            DeviceLoginPusher.shared.forceRepush(for: updated, reason: "user reconnect")
        }
    }

    /// Rename one entry's displayName (user nickname). No-op if the entry isn't in the list.
    /// Trim 空白；空字符串等价于"恢复默认"——回落到 model 且从持久化昵称表里清掉这条
    /// device_id 的记忆。非空时同时写入 nicknames[deviceID]——保证下次 remove + reconnect
    /// 同一台 device_id 时仍能恢复这个昵称。
    func rename(_ entry: Entry, to newName: String) {
        var current = entries
        guard let idx = current.firstIndex(of: entry) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = current[idx]
        let resolved = trimmed.isEmpty ? updated.model : trimmed
        updated.displayName = resolved
        guard updated != current[idx] else { return }
        current[idx] = updated
        entries = current

        // 同步持久化 nickname 表
        if let did = updated.deviceID {
            var nicks = nicknames
            if let r = resolved, r != updated.model {
                nicks[did] = r
            } else {
                // 用户把名字清空 / 改回了型号 → 移除记忆，下次重连回落到 model 默认
                nicks.removeValue(forKey: did)
            }
            nicknames = nicks
        }

        Log.info("DeviceSession", "rename entry[\(idx)] name=\(updated.displayName ?? "nil")")
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// Remove a specific paired device. No-op if the entry isn't in the list.
    /// 按物理设备身份匹配（device_id > bleIdentifier > host），不用整条 Equatable：
    /// 调用方手里的 entry 往往是之前拿到的快照，期间 markLoginPushed 等会改写指纹/时间戳，
    /// 整条比较就对不上，删除静默失效（真机上点确认无反应的根因）。
    func remove(_ entry: Entry) {
        var current = entries
        let before = current.count
        current.removeAll { Self.isSameDevice($0, entry) }
        guard current.count != before else { return }
        entries = current
        Log.info("DeviceSession", "removed entry name=\(entry.displayName ?? "nil") remaining=\(current.count)")
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    private static func isSameDevice(_ a: Entry, _ b: Entry) -> Bool {
        if let did = b.deviceID { return a.deviceID == did }
        if let ble = b.bleIdentifier { return a.bleIdentifier == ble }
        if let host = b.host { return a.host == host }
        return a == b
    }

    /// Wipe all paired devices AND all remembered nicknames. 账户级清空（登出 / 切账号）调用。
    /// 普通的 remove(entry) 只删活 entry，保留昵称记忆——这里是"全清"语义。
    func clear() {
        let hadEntries = !entries.isEmpty
        Log.info("DeviceSession", "clear all entries (count=\(entries.count)) + nicknames")
        UserDefaults.standard.removeObject(forKey: Keys.entries)
        UserDefaults.standard.removeObject(forKey: Keys.nicknames)
        scrubLegacyKeys()
        if hadEntries {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    // MARK: - Legacy migration

    /// First-run migration: if the new `entries` key is absent but the old single-device
    /// fields exist, build one Entry from them and write it as the new persisted form.
    /// Idempotent — safe to call on every launch.
    private func migrateLegacySingleEntryIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.entries) != nil { return }

        let oldHost = defaults.string(forKey: Keys.legacyHost)
        let oldBleStr = defaults.string(forKey: Keys.legacyBleIdentifier)
        guard oldHost != nil || oldBleStr != nil else { return }

        Log.info("DeviceSession", "migrating legacy single-device fields to entries array")
        let transportRaw = defaults.string(forKey: Keys.legacyTransport) ?? Transport.wifi.rawValue
        // 老存储没有 model 字段；用 legacy displayName 同时填 model 和 displayName——
        // 旧用户当时还没法改昵称，所以"用户可见名"约等于"型号"，这里两边一致是安全的
        let legacyName = defaults.string(forKey: Keys.legacyDisplayName)
        let entry = Entry(
            host: oldHost,
            hostFallback: defaults.string(forKey: Keys.legacyHostFallback),
            bleIdentifier: oldBleStr.flatMap(UUID.init),
            deviceID: defaults.string(forKey: Keys.legacyDeviceID),
            model: legacyName,
            displayName: legacyName,
            transport: Transport(rawValue: transportRaw) ?? .wifi,
            pairedAt: Date(),
            isUserDisconnected: false,
            lastLoginPushedTokenFingerprint: nil
        )

        if let data = try? JSONEncoder().encode([entry]) {
            defaults.set(data, forKey: Keys.entries)
        }
        scrubLegacyKeys()
    }

    private func scrubLegacyKeys() {
        let defaults = UserDefaults.standard
        for k in [
            Keys.legacyHost, Keys.legacyHostFallback, Keys.legacyBleIdentifier,
            Keys.legacyDeviceID, Keys.legacyDisplayName, Keys.legacyTransport,
            Keys.legacyPort
        ] {
            defaults.removeObject(forKey: k)
        }
    }
}
