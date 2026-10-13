import Foundation

extension NetService {
    /// `device_id` value extracted from the service's TXT record. This is the canonical
    /// per-physical-device identifier shared by Bonjour and BLE — used as the join key
    /// to merge the two channels into one row in the device selection UI.
    /// Returns nil when the TXT record is absent or doesn't contain a non-empty `device_id` field.
    var deviceID: String? {
        guard let txtData = txtRecordData() else { return nil }
        let dict = NetService.dictionary(fromTXTRecord: txtData)
        guard let v = dict["device_id"], let s = String(data: v, encoding: .utf8) else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// First IPv4 address in the resolved address list, formatted as a string.
    /// Returns nil if the service hasn't been resolved or has no IPv4 address.
    var firstIPv4Address: String? {
        guard let addresses = addresses else { return nil }
        for data in addresses {
            let ip = data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> String? in
                guard let addr = pointer.bindMemory(to: sockaddr.self).baseAddress else { return nil }
                guard addr.pointee.sa_family == sa_family_t(AF_INET) else { return nil }
                let addrIn = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var addrCopy = addrIn.sin_addr
                inet_ntop(AF_INET, &addrCopy, &buffer, socklen_t(INET_ADDRSTRLEN))
                return String(cString: buffer)
            }
            if let ip { return ip }
        }
        return nil
    }
}
