import Foundation

struct UserProfileDraft: Codable, Equatable {
    var nickname: String
    var gender: String
    var age: String
    var birthday: String
    var email: String
    var phone: String
    var address: String
    /// 体重（kg）与身高（cm），只存数字部分，单位固定不入库。
    var weight: String
    var height: String

    static let empty = UserProfileDraft(
        nickname: "",
        gender: "",
        age: "",
        birthday: "",
        email: "",
        phone: "",
        address: "",
        weight: "",
        height: ""
    )

    init(nickname: String,
         gender: String,
         age: String,
         birthday: String,
         email: String,
         phone: String,
         address: String,
         weight: String = "",
         height: String = "") {
        self.nickname = nickname
        self.gender = gender
        self.age = age
        self.birthday = birthday
        self.email = email
        self.phone = phone
        self.address = address
        self.weight = weight
        self.height = height
    }

    /// 手写解码只为一件事：`weight` / `height` 是后加的字段，**老用户本地存的 JSON 里没有这两个键**。
    /// 合成的 Codable 遇到缺键的非可选 String 会直接抛错，而 draft 与「已上传快照」都是整体解码的 ——
    /// 一处报错就等于升级后本地资料被判为空：轻则整页空白，重则拿空资料覆盖服务端。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        gender = try c.decodeIfPresent(String.self, forKey: .gender) ?? ""
        age = try c.decodeIfPresent(String.self, forKey: .age) ?? ""
        birthday = try c.decodeIfPresent(String.self, forKey: .birthday) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        weight = try c.decodeIfPresent(String.self, forKey: .weight) ?? ""
        height = try c.decodeIfPresent(String.self, forKey: .height) ?? ""
    }
}

struct UserProfileAddressRecord {
    let id: String
    let isDefault: Bool
    let name: String
    let phone: String
    let countryCode: String
    let stateCode: String
    let state: String
    let city: String
    /// 区/县。只有中国这类三级行政区划的国家会用到。
    let district: String
    let street1: String
    let street2: String
    let zip: String
    // 旧协议字段，服务端历史数据与老客户端仍在读。
    let region: String
    let detail: String
}

struct UserProfileSnapshot {
    let draft: UserProfileDraft
    let addresses: [UserProfileAddressRecord]
    let avatarJPEGData: Data?
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
        var draft = draft
        // UI 里已经没有「年龄」那一格了（改由生日推导），但协议里 age 仍是独立字段。
        // 不在写入时一并推导，服务端就会长期存着一个和 birthday 自相矛盾的旧年龄。
        // 推不出来（生日为空 / 格式不认 / 日期在未来）时保持原值，不去清空 —— 我们只是
        // 不知道，不代表用户清空了。
        if let age = Self.derivedAge(fromBirthday: draft.birthday) { draft.age = age }
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// 由生日算年龄。生日格式与编辑页一致：`yyyy.MM.dd`。
    static func derivedAge(fromBirthday birthday: String) -> String? {
        let text = birthday.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: text) else { return nil }
        let years = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? -1
        guard years >= 0 else { return nil }
        return "\(years)"
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        clearUploadedSnapshot()
    }

    // MARK: - 已上传快照

    // 「最近一次成功上传到服务端的内容」。资料改动现在是自动上传的，需要一个基准来回答
    // 「还有没有没送出去的改动」—— 否则每次进资料页都会无条件再传一遍。
    // 上传失败时不更新它，改动就一直是脏的，下次进页面或下次改动会自动重试。
    private let uploadedKey = "mindora.user_profile.uploaded"
    private let uploadedAvatarKey = "mindora.user_profile.uploaded_avatar_hash"
    private let uploadedAddressKey = "mindora.user_profile.uploaded_address_hash"

    func loadUploadedSnapshot() -> UserProfileDraft? {
        guard let data = UserDefaults.standard.data(forKey: uploadedKey) else { return nil }
        return try? JSONDecoder().decode(UserProfileDraft.self, from: data)
    }

    /// 头像不进 draft，单独记一个摘要：不然换了头像但文字没变就检测不到改动。
    ///
    /// 注意用的是自算的 FNV-1a 而不是 `Data.hashValue` —— 后者每个进程的哈希种子是随机的，
    /// 存下来跨启动对不上，会让每次冷启动都误判成「头像变了」而白传一次。
    var uploadedAvatarDigest: String {
        UserDefaults.standard.string(forKey: uploadedAvatarKey) ?? ""
    }

    /// 地址簿同样不在 draft 里，也单独记一个摘要。
    ///
    /// 之前只比 draft 里那串地址摘要文案，只要改动没落到那串文案上就检测不到 ——
    /// 比如只改收件人姓名或电话（摘要拼的是 region + detail，不含姓名/电话），
    /// 用户改完看着像保存了，服务端那份却永远是旧的。
    var uploadedAddressDigest: String {
        UserDefaults.standard.string(forKey: uploadedAddressKey) ?? ""
    }

    /// 内容摘要：头像与地址簿都用它（都不在 draft 里，只能靠摘要判断有没有变）。
    static func digest(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "" }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return "\(data.count):\(hash)"
    }

    func saveUploadedSnapshot(_ draft: UserProfileDraft, avatarDigest: String, addressDigest: String) {
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: uploadedKey)
        }
        UserDefaults.standard.set(avatarDigest, forKey: uploadedAvatarKey)
        UserDefaults.standard.set(addressDigest, forKey: uploadedAddressKey)
    }

    func clearUploadedSnapshot() {
        UserDefaults.standard.removeObject(forKey: uploadedKey)
        UserDefaults.standard.removeObject(forKey: uploadedAvatarKey)
        UserDefaults.standard.removeObject(forKey: uploadedAddressKey)
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

        RequestTrace.apply(&request)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.Network.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")

        let payload = QueryUserProfileRequest(
            timestamp: Int(Date().timeIntervalSince1970),
            data: .init(
                uid: uid,
                jwtToken: jwtToken,
                language: LocalizationManager.shared.currentLanguage.rawValue
            )
        )
        let body = try JSONEncoder().encode(payload)
        request.httpBody = body

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "query_profile request url=\(url.absoluteString)")
            Log.info(logTag, "query_profile request body=\(Log.prettyJSON(body))")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        SessionExpirationCenter.handle(httpResponse: response, data: data)
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
            address: "",
            weight: remoteProfile.weight ?? "",
            height: remoteProfile.height ?? ""
        )
        let addresses = (remoteProfile.addressList ?? []).map {
            UserProfileAddressRecord(
                id: $0.id,
                isDefault: $0.isDefault,
                name: $0.name,
                phone: $0.phone,
                countryCode: $0.countryCode,
                stateCode: $0.stateCode,
                state: $0.state,
                city: $0.city,
                district: $0.district,
                street1: $0.street1,
                street2: $0.street2,
                zip: $0.zip,
                region: $0.region,
                detail: $0.detail
            )
        }
        let avatarJPEGData = remoteProfile.avatarBase64.flatMap { Data(base64Encoded: $0) }
        return UserProfileSnapshot(draft: draft, addresses: addresses, avatarJPEGData: avatarJPEGData)
    }

    func updateProfile(draft: UserProfileDraft,
                       baseline: UserProfileDraft?,
                       avatarJPEGData: Data?) async throws -> UserProfileDraft {
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let jwtToken = AuthStorage.shared.token, !jwtToken.isEmpty else {
            throw UserProfileServiceError.missingCredentials
        }

        guard let url = URL(string: Constants.Network.profileURL) else {
            throw UserProfileServiceError.invalidURL
        }

        var request = URLRequest(url: url)

        RequestTrace.apply(&request)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.Network.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")

        let payload = UpdateUserProfileRequest(
            timestamp: Int(Date().timeIntervalSince1970),
            data: .init(
                uid: uid,
                jwtToken: jwtToken,
                language: LocalizationManager.shared.currentLanguage.rawValue,
                userProfile: .init(
                    uidEmb: [],
                    behaviors: [:],
                    profile: .init(
                        draft: draft,
                        baseline: baseline,
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
        SessionExpirationCenter.handle(httpResponse: response, data: data)
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

    /// 只把「当前 App 语言」上报给服务端（`update_profile`）。
    ///
    /// 为什么非报不可：`analysis_*` 请求体里的 `data.language` **服务端不据此选语种**
    /// —— 它只落到 `last_request_language`，而生成 label / description 时读的是
    /// 画像里的 `user_profile.profile.language`（以配置为准）。那个字段只有
    /// `update_profile` 这条路能写，冷启动捎带一次不够：用户在 App 里切到英文后
    /// 服务端那份还停在建档时的值，返回的文案仍旧是中文。
    ///
    /// 载荷里 `profile` **只放 `language` 一个键**，其余键一律不出现。服务端按
    /// 「键不出现 → 保持原值」合并，少一个键就少一份误改风险 —— 尤其是
    /// `address_list`，它的语义是「键出现即整体替换，空数组 = 清空」，
    /// 顺手带个空数组就会把用户的收货地址抹掉。
    func reportLanguage(_ language: String) async throws {
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let jwtToken = AuthStorage.shared.token, !jwtToken.isEmpty else {
            throw UserProfileServiceError.missingCredentials
        }

        guard let url = URL(string: Constants.Network.profileURL) else {
            throw UserProfileServiceError.invalidURL
        }

        var request = URLRequest(url: url)

        RequestTrace.apply(&request)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.Network.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")

        let payload = ReportLanguageRequest(
            timestamp: Int(Date().timeIntervalSince1970),
            data: .init(
                uid: uid,
                jwtToken: jwtToken,
                language: language,
                userProfile: .init(profile: .init(language: language))
            )
        )
        let body = try JSONEncoder().encode(payload)
        request.httpBody = body

        Log.info(logTag, "report_language request body=\(Log.prettyJSON(body))")

        let (data, response) = try await URLSession.shared.data(for: request)
        SessionExpirationCenter.handle(httpResponse: response, data: data)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            Log.error(logTag, "report_language invalid HTTP status="
                      + "\((response as? HTTPURLResponse)?.statusCode.description ?? "nil")")
            throw UserProfileServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(UpdateProfileAck.self, from: data)
        if let code = decoded.code {
            guard code == 0 else {
                Log.error(logTag, "report_language business error code=\(code), msg=\(decoded.msg ?? "")")
                throw UserProfileServiceError.apiError(code: code, message: decoded.msg)
            }
        } else {
            guard decoded.status.lowercased() == "success" else {
                Log.error(logTag, "report_language legacy error status=\(decoded.status)")
                throw UserProfileServiceError.apiError(code: -1, message: decoded.message)
            }
        }

        Log.info(logTag, "report_language completed successfully language=\(language)")
    }

    private func loadAddressList() -> [AddressItemPayload] {
        guard let data = UserDefaults.standard.data(forKey: addressStorageKey),
              let storedAddresses = try? JSONDecoder().decode([AddrModel].self, from: data) else {
            return []
        }

        return storedAddresses.map {
            AddressItemPayload(
                id: $0.id,
                isDefault: $0.isDefault,
                name: $0.name,
                phone: $0.phone,
                countryCode: $0.countryCode,
                stateCode: $0.stateCode,
                state: $0.state,
                city: $0.city,
                district: $0.district,
                street1: $0.street1,
                street2: $0.street2,
                zip: $0.zip,
                region: $0.region,
                detail: $0.detail
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
    let language: String

    enum CodingKeys: String, CodingKey {
        case uid
        case jwtToken = "jwt_token"
        case language
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

/// 「只报语言」的请求体。刻意不复用 `UpdateUserProfileRequest` —— 那条路的
/// `ProfileDetailsPayload` 会把 nickname/phone/address_list 等所有键都编码出来，
/// 用在这里等于每次切语言都对整份资料做一次全量覆盖。
private struct ReportLanguageRequest: Encodable {
    let requestType = "update_profile"
    let timestamp: Int
    let version = "1.0"
    let data: ReportLanguageData

    enum CodingKeys: String, CodingKey {
        case requestType = "request_type"
        case timestamp
        case version
        case data
    }
}

private struct ReportLanguageData: Encodable {
    let uid: String
    let jwtToken: String
    /// 顶层 language：服务端记到 `last_request_language`，是次要来源（兜底）。
    /// 真正决定文案语种的是下面 `user_profile.profile.language`。
    let language: String
    let userProfile: ReportLanguageProfileEnvelope

    enum CodingKeys: String, CodingKey {
        case uid
        case jwtToken = "jwt_token"
        case language
        case userProfile = "user_profile"
    }
}

private struct ReportLanguageProfileEnvelope: Encodable {
    /// 与常规 update_profile 保持同样的空值形状（那条路已验证过服务端接受）。
    let uidEmb: [Double] = []
    let behaviors: [String: [[Double]]] = [:]
    let profile: ReportLanguageProfile

    enum CodingKeys: String, CodingKey {
        case uidEmb = "uid_emb"
        case behaviors
        case profile
    }
}

private struct ReportLanguageProfile: Encodable {
    /// 服务端 `_profile_language()` 的第一优先来源。取值就是 `SupportedLanguage`
    /// 的 rawValue（zh-Hans / en / de / es / fr / it / ja / ko / zh-Hant / id），
    /// 与服务端 `_LANG_CANONICAL` 的键一一对得上，不需要额外转换。
    let language: String
}

private struct ProfileRequestData: Encodable {
    let uid: String
    let jwtToken: String
    /// 当前 App 语言。服务端据此更新 UserPreference.language —— 这是唯一能让服务端在
    /// 非请求驱动的场景（邮件、后台生成的文案）知道用户语种的落点。
    let language: String
    let userProfile: UnifiedUserProfilePayload

    enum CodingKeys: String, CodingKey {
        case uid
        case jwtToken = "jwt_token"
        case language
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

/// 资料字段的上行表示。**每个字段都会出现在请求里**（保持整体形状不变），
/// 但空值分成两种，服务端必须区别对待：
///
///   - `null` —— 客户端没有这个字段的值，**服务端保持原值不变**；
///   - `""`   —— 用户**主动清空**了这个字段，服务端置空。
///
/// 不做这个区分的话，用户只改昵称时其余字段会以 `""` 一起送上去，
/// 把他在别处填过的手机 / 性别 / 生日全部抹掉 —— 这是一次静默的数据丢失。
/// 详见 Tools/doc/个人资料同步约定.md。
private struct ProfileDetailsPayload: Encodable {
    let nickname: String?
    let gender: String?
    let age: String?
    let birthday: String?
    let email: String?
    let phone: String?
    let weight: String?
    let height: String?
    let addressList: [AddressItemPayload]
    let avatarBase64: String?
    let avatarMimeType: String?

    /// - Parameter baseline: 最近一次成功上传的快照。用来判断「空」到底是哪一种：
    ///   基准里有值而现在没了 → 用户清空了（送 `""`）；基准里本来就没有 → 客户端不知道（送 `null`）。
    ///   没有基准（从没成功传过）时一律按「不知道」处理，宁可不改也不误删。
    init(draft: UserProfileDraft,
         baseline: UserProfileDraft?,
         addressList: [AddressItemPayload],
         avatarJPEGData: Data?) {
        func field(_ current: String, _ previous: String?) -> String? {
            let value = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
            let had = (previous ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return had.isEmpty ? nil : ""
        }
        nickname = field(draft.nickname, baseline?.nickname)
        gender = field(draft.gender, baseline?.gender)
        age = field(draft.age, baseline?.age)
        birthday = field(draft.birthday, baseline?.birthday)
        // 邮箱是账号本身，永远非空，也不允许清空。
        email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        phone = field(draft.phone, baseline?.phone)
        weight = field(draft.weight, baseline?.weight)
        height = field(draft.height, baseline?.height)
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
        case weight
        case height
        case addressList = "address_list"
        case avatarBase64 = "avatar_base64"
        case avatarMimeType = "avatar_mime_type"
    }

    /// 手写 encode：合成实现对 `String?` 用的是 `encodeIfPresent`，nil 会让整个键
    /// **消失**，而我们要的是显式的 `null`（键在、值为 null）。
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(nickname, forKey: .nickname)
        try c.encode(gender, forKey: .gender)
        try c.encode(age, forKey: .age)
        try c.encode(birthday, forKey: .birthday)
        try c.encode(email, forKey: .email)
        try c.encode(phone, forKey: .phone)
        try c.encode(weight, forKey: .weight)
        try c.encode(height, forKey: .height)
        try c.encode(addressList, forKey: .addressList)
        // 头像两项保持原样：没有新头像就整个键不出现，服务端不必处理 null。
        try c.encodeIfPresent(avatarBase64, forKey: .avatarBase64)
        try c.encodeIfPresent(avatarMimeType, forKey: .avatarMimeType)
    }
}

/// 收货地址上行结构。
///
/// 结构化字段（country_code / state_code / city / street1 / zip）是给商城发货用的，
/// region / detail 是旧协议留下的展示串，客户端拼好一起传：服务端历史数据里只有这两个，
/// 突然不传会让还没升级的老客户端拉到空地址。
private struct AddressItemPayload: Encodable {
    let id: String
    let isDefault: Bool
    let name: String
    let phone: String
    let countryCode: String
    let stateCode: String
    let state: String
    let city: String
    /// 区/县。只有中国这类三级行政区划的国家会用到。
    let district: String
    let street1: String
    let street2: String
    let zip: String
    let region: String
    let detail: String

    enum CodingKeys: String, CodingKey {
        case id
        case isDefault = "is_default"
        case name
        case phone
        case countryCode = "country_code"
        case stateCode = "state_code"
        case state
        case city
        case district
        case street1
        case street2
        case zip
        case region
        case detail
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
    let weight: String?
    let height: String?
    let addressList: [RemoteAddressItem]?
    let avatarBase64: String?

    enum CodingKeys: String, CodingKey {
        case nickname
        case gender
        case age
        case birthday
        case email
        case phone
        case weight
        case height
        case addressList = "address_list"
        case avatarBase64 = "avatar_base64"
    }

    /// 手写解码只为了 weight / height 能容忍数字：这两个字段客户端是按字符串上行的，
    /// 但服务端很可能把 "75" 规范化成数字再回传。合成解码遇到数字会抛错，而这里一抛错
    /// **整个 query_profile 就失败了**——为了两个新字段把昵称头像地址一起拖下水不划算。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname)
        gender = try c.decodeIfPresent(String.self, forKey: .gender)
        age = try c.decodeIfPresent(String.self, forKey: .age)
        birthday = try c.decodeIfPresent(String.self, forKey: .birthday)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        weight = Self.looseString(c, .weight)
        height = Self.looseString(c, .height)
        addressList = try c.decodeIfPresent([RemoteAddressItem].self, forKey: .addressList)
        avatarBase64 = try c.decodeIfPresent(String.self, forKey: .avatarBase64)
    }

    private static func looseString(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let text = try? c.decodeIfPresent(String.self, forKey: key) { return text }
        if let number = try? c.decodeIfPresent(Double.self, forKey: key) {
            // 75.0 要显示成 "75"，不能变成 "75.0"。
            return number == number.rounded() ? String(Int(number)) : String(number)
        }
        return nil
    }
}

private struct RemoteAddressItem: Decodable {
    let id: String
    let isDefault: Bool
    let name: String
    let phone: String
    let countryCode: String
    let stateCode: String
    let state: String
    let city: String
    /// 区/县。只有中国这类三级行政区划的国家会用到。
    let district: String
    let street1: String
    let street2: String
    let zip: String
    let region: String
    let detail: String

    enum CodingKeys: String, CodingKey {
        case id
        case isDefault = "is_default"
        case name
        case phone
        case countryCode = "country_code"
        case stateCode = "state_code"
        case state
        case city
        case district
        case street1
        case street2
        case zip
        case region
        case detail
    }

    /// 结构化字段是后加的，服务端存量地址一条都没有 ——
    /// 缺键抛错会让整个 query_profile 失败，不只是地址列表拿不到。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        isDefault = (try? c.decode(Bool.self, forKey: .isDefault)) ?? false
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        phone = (try? c.decodeIfPresent(String.self, forKey: .phone)) ?? ""
        countryCode = (try? c.decodeIfPresent(String.self, forKey: .countryCode)) ?? ""
        stateCode = (try? c.decodeIfPresent(String.self, forKey: .stateCode)) ?? ""
        state = (try? c.decodeIfPresent(String.self, forKey: .state)) ?? ""
        city = (try? c.decodeIfPresent(String.self, forKey: .city)) ?? ""
        district = (try? c.decodeIfPresent(String.self, forKey: .district)) ?? ""
        street1 = (try? c.decodeIfPresent(String.self, forKey: .street1)) ?? ""
        street2 = (try? c.decodeIfPresent(String.self, forKey: .street2)) ?? ""
        zip = (try? c.decodeIfPresent(String.self, forKey: .zip)) ?? ""
        region = (try? c.decodeIfPresent(String.self, forKey: .region)) ?? ""
        detail = (try? c.decodeIfPresent(String.self, forKey: .detail)) ?? ""
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