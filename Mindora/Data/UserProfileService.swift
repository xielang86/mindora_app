import Foundation

struct UserProfileDraft: Codable {
    var nickname: String
    var gender: String
    var age: String
    var birthday: String
    var email: String
    var phone: String
    var address: String

    static let empty = UserProfileDraft(
        nickname: "",
        gender: "",
        age: "",
        birthday: "",
        email: "",
        phone: "",
        address: ""
    )
}

struct UserProfileAddressRecord {
    let id: String
    let isDefault: Bool
    let region: String
    let detail: String
    let name: String
    let phone: String
}

struct UserProfileSnapshot {
    let draft: UserProfileDraft
    let addresses: [UserProfileAddressRecord]
    let avatarJPEGData: Data?
}

private struct StoredAddress: Codable {
    let id: String
    let isDefault: Bool
    let region: String
    let detail: String
    let name: String
    let phone: String
}

extension Notification.Name {
    static let userProfileDidUpdate = Notification.Name("UserProfileDidUpdate")
}

final class UserProfileStore {
    static let shared = UserProfileStore()

    private let storageKey = "mindora.user_profile.draft"

    private init() {}

    func load(accountEmail: String?) -> UserProfileDraft {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let draft = try? JSONDecoder().decode(UserProfileDraft.self, from: data) else {
            return UserProfileDraft(
                nickname: "",
                gender: "",
                age: "",
                birthday: "",
                email: accountEmail ?? "",
                phone: "",
                address: ""
            )
        }

        var merged = draft
        if merged.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let accountEmail,
           !accountEmail.isEmpty {
            merged.email = accountEmail
        }
        return merged
    }

    func save(_ draft: UserProfileDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

enum UserProfileServiceError: Error {
    case invalidURL
    case missingCredentials
    case invalidResponse
    case apiError(code: Int, message: String?)
}

extension UserProfileServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return L("user_profile.update_failed")
        case .missingCredentials:
            return L("user_profile.token_missing")
        case .invalidResponse:
            return L("user_profile.update_failed")
        case .apiError(_, let message):
            return message ?? L("user_profile.update_failed")
        }
    }
}

final class UserProfileService {
    static let shared = UserProfileService()

    private let addressStorageKey = "MindoraSavedAddresses"
    private let logTag = "UserProfileService"

    private init() {}

    func queryProfile() async throws -> UserProfileSnapshot? {
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let jwtToken = AuthStorage.shared.token, !jwtToken.isEmpty else {
            throw UserProfileServiceError.missingCredentials
        }

        guard let url = URL(string: Constants.Network.profileURL) else {
            throw UserProfileServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.Network.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")

        let payload = QueryUserProfileRequest(
            timestamp: Int(Date().timeIntervalSince1970),
            data: .init(uid: uid, jwtToken: jwtToken)
        )
        let body = try JSONEncoder().encode(payload)
        request.httpBody = body

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "query_profile request url=\(url.absoluteString)")
            Log.info(logTag, "query_profile request body=\(Log.prettyJSON(body))")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                Log.error(logTag, "query_profile invalid HTTP status=\(httpResponse.statusCode)")
            } else {
                Log.error(logTag, "query_profile invalid HTTP response")
            }
            throw UserProfileServiceError.invalidResponse
        }

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "query_profile response status=\(httpResponse.statusCode)")
            Log.info(logTag, "query_profile response body=\(Log.prettyJSON(data))")
        }

        let decoded = try JSONDecoder().decode(QueryProfileAck.self, from: data)
        if let code = decoded.code {
            guard code == 0 else {
                Log.error(logTag, "query_profile business error code=\(code), msg=\(decoded.msg ?? "")")
                throw UserProfileServiceError.apiError(code: code, message: decoded.msg)
            }
        } else {
            let normalizedStatus = decoded.status.lowercased()
            if normalizedStatus == "not_found" {
                Log.info(logTag, "query_profile returned not_found")
                return nil
            }
            guard normalizedStatus.isEmpty || normalizedStatus == "success" else {
                Log.error(logTag, "query_profile legacy error status=\(normalizedStatus), message=\(decoded.message ?? "")")
                throw UserProfileServiceError.apiError(code: -1, message: decoded.message)
            }
        }

        guard let remoteProfile = decoded.data?.userProfile?.profile ?? decoded.profile?.profile else {
            return nil
        }

        let draft = UserProfileDraft(
            nickname: remoteProfile.nickname ?? "",
            gender: remoteProfile.gender ?? "",
            age: remoteProfile.age ?? "",
            birthday: remoteProfile.birthday ?? "",
            email: remoteProfile.email ?? "",
            phone: remoteProfile.phone ?? "",
            address: ""
        )
        let addresses = (remoteProfile.addressList ?? []).map {
            UserProfileAddressRecord(
                id: $0.id,
                isDefault: $0.isDefault,
                region: $0.region,
                detail: $0.detail,
                name: $0.name,
                phone: $0.phone
            )
        }
        let avatarJPEGData = remoteProfile.avatarBase64.flatMap { Data(base64Encoded: $0) }
        return UserProfileSnapshot(draft: draft, addresses: addresses, avatarJPEGData: avatarJPEGData)
    }

    func updateProfile(draft: UserProfileDraft, avatarJPEGData: Data?) async throws -> UserProfileDraft {
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let jwtToken = AuthStorage.shared.token, !jwtToken.isEmpty else {
            throw UserProfileServiceError.missingCredentials
        }

        guard let url = URL(string: Constants.Network.profileURL) else {
            throw UserProfileServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.Network.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")

        let payload = UpdateUserProfileRequest(
            timestamp: Int(Date().timeIntervalSince1970),
            data: .init(
                uid: uid,
                jwtToken: jwtToken,
                userProfile: .init(
                    uidEmb: [],
                    behaviors: [:],
                    profile: .init(
                        draft: draft,
                        addressList: loadAddressList(),
                        avatarJPEGData: avatarJPEGData
                    )
                )
            )
        )

        let body = try JSONEncoder().encode(payload)
        request.httpBody = body

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "update_profile request url=\(url.absoluteString)")
            Log.info(logTag, "update_profile request body=\(Log.prettyJSON(body))")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                Log.error(logTag, "update_profile invalid HTTP status=\(httpResponse.statusCode)")
            } else {
                Log.error(logTag, "update_profile invalid HTTP response")
            }
            throw UserProfileServiceError.invalidResponse
        }

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "update_profile response status=\(httpResponse.statusCode)")
            Log.info(logTag, "update_profile response body=\(Log.prettyJSON(data))")
        }

        let decoded = try JSONDecoder().decode(UpdateProfileAck.self, from: data)
        if let code = decoded.code {
            guard code == 0 else {
                Log.error(logTag, "update_profile business error code=\(code), msg=\(decoded.msg ?? "")")
                throw UserProfileServiceError.apiError(code: code, message: decoded.msg)
            }
        } else {
            guard decoded.status.lowercased() == "success" else {
                Log.error(logTag, "update_profile legacy error status=\(decoded.status), message=\(decoded.message ?? "")")
                throw UserProfileServiceError.apiError(code: -1, message: decoded.message)
            }
        }

        Log.info(logTag, "update_profile completed successfully")

        return draft
    }

    private func loadAddressList() -> [AddressItemPayload] {
        guard let data = UserDefaults.standard.data(forKey: addressStorageKey),
              let storedAddresses = try? JSONDecoder().decode([StoredAddress].self, from: data) else {
            return []
        }

        return storedAddresses.map {
            AddressItemPayload(
                id: $0.id,
                isDefault: $0.isDefault,
                region: $0.region,
                detail: $0.detail,
                name: $0.name,
                phone: $0.phone
            )
        }
    }
}

private struct QueryUserProfileRequest: Encodable {
    let requestType = "query_profile"
    let timestamp: Int
    let version = "1.0"
    let data: QueryRequestData

    enum CodingKeys: String, CodingKey {
        case requestType = "request_type"
        case timestamp
        case version
        case data
    }
}

private struct QueryRequestData: Encodable {
    let uid: String
    let jwtToken: String

    enum CodingKeys: String, CodingKey {
        case uid
        case jwtToken = "jwt_token"
    }
}

private struct UpdateUserProfileRequest: Encodable {
    let requestType = "update_profile"
    let timestamp: Int
    let version = "1.0"
    let data: ProfileRequestData

    enum CodingKeys: String, CodingKey {
        case requestType = "request_type"
        case timestamp
        case version
        case data
    }
}

private struct ProfileRequestData: Encodable {
    let uid: String
    let jwtToken: String
    let userProfile: UnifiedUserProfilePayload

    enum CodingKeys: String, CodingKey {
        case uid
        case jwtToken = "jwt_token"
        case userProfile = "user_profile"
    }
}

private struct UnifiedUserProfilePayload: Encodable {
    let uidEmb: [Double]
    let behaviors: [String: [[IntOrDoubleCodable]]]
    let profile: ProfileDetailsPayload

    init(
        uidEmb: [Double],
        behaviors: [String: [[IntOrDoubleCodable]]],
        profile: ProfileDetailsPayload
    ) {
        self.uidEmb = uidEmb
        self.behaviors = behaviors
        self.profile = profile
    }

    enum CodingKeys: String, CodingKey {
        case uidEmb = "uid_emb"
        case behaviors
        case profile
    }
}

private struct ProfileDetailsPayload: Encodable {
    let nickname: String
    let gender: String
    let age: String
    let birthday: String
    let email: String
    let phone: String
    let addressList: [AddressItemPayload]
    let avatarBase64: String?
    let avatarMimeType: String?

    init(draft: UserProfileDraft, addressList: [AddressItemPayload], avatarJPEGData: Data?) {
        nickname = draft.nickname
        gender = draft.gender
        age = draft.age
        birthday = draft.birthday
        email = draft.email
        phone = draft.phone
        self.addressList = addressList
        avatarBase64 = avatarJPEGData?.base64EncodedString()
        avatarMimeType = avatarJPEGData == nil ? nil : "image/jpeg"
    }

    enum CodingKeys: String, CodingKey {
        case nickname
        case gender
        case age
        case birthday
        case email
        case phone
        case addressList = "address_list"
        case avatarBase64 = "avatar_base64"
        case avatarMimeType = "avatar_mime_type"
    }
}

private struct AddressItemPayload: Encodable {
    let id: String
    let isDefault: Bool
    let region: String
    let detail: String
    let name: String
    let phone: String

    enum CodingKeys: String, CodingKey {
        case id
        case isDefault = "is_default"
        case region
        case detail
        case name
        case phone
    }
}

private struct UpdateProfileAck: Decodable {
    let code: Int?
    let msg: String?
    let status: String
    let message: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code)
        msg = try container.decodeIfPresent(String.self, forKey: .msg)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case msg
        case status
        case message
    }
}

private struct QueryProfileAck: Decodable {
    let code: Int?
    let msg: String?
    let data: QueryProfileResponseData?
    let status: String
    let message: String?
    let profile: QueriedUserProfile?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code)
        msg = try container.decodeIfPresent(String.self, forKey: .msg)
        data = try container.decodeIfPresent(QueryProfileResponseData.self, forKey: .data)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        message = try container.decodeIfPresent(String.self, forKey: .message)
        profile = try container.decodeIfPresent(QueriedUserProfile.self, forKey: .profile)
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case msg
        case data
        case status
        case message
        case profile
    }
}

private struct QueryProfileResponseData: Decodable {
    let userProfile: QueriedUserProfile?

    enum CodingKeys: String, CodingKey {
        case userProfile = "user_profile"
    }
}

private struct QueriedUserProfile: Decodable {
    let profile: QueriedProfileDetails?
}

private struct QueriedProfileDetails: Decodable {
    let nickname: String?
    let gender: String?
    let age: String?
    let birthday: String?
    let email: String?
    let phone: String?
    let addressList: [RemoteAddressItem]?
    let avatarBase64: String?

    enum CodingKeys: String, CodingKey {
        case nickname
        case gender
        case age
        case birthday
        case email
        case phone
        case addressList = "address_list"
        case avatarBase64 = "avatar_base64"
    }
}

private struct RemoteAddressItem: Decodable {
    let id: String
    let isDefault: Bool
    let region: String
    let detail: String
    let name: String
    let phone: String

    enum CodingKeys: String, CodingKey {
        case id
        case isDefault = "is_default"
        case region
        case detail
        case name
        case phone
    }
}

private struct IntOrDoubleCodable: Encodable {
    private let value: Encodable

    init(_ value: Int) {
        self.value = value
    }

    init(_ value: Double) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}