//
//  AddrModel.swift
//  mindora
//
//  收货地址模型。
//
//  这份地址要同步到商城当收货地址，所以是结构化字段（国家/州/城市/街道/邮编），
//  不再是早期的「region + detail」两段自由文本。region / detail 仍然保留并在保存时
//  由结构化字段拼出来：服务端历史数据和还没升级的老客户端都在读这两个键。
//

import Foundation

struct AddrModel: Codable {
    var id: String
    var isDefault: Bool
    var name: String
    /// 收件人电话，统一存 E.164（`+16505551234`）。
    var phone: String
    /// ISO 3166-1 alpha-2，如 `US`。
    var countryCode: String
    /// 有区划表的国家存两位码（`CA` = California），自由文本的国家为空。
    var stateCode: String
    /// 州/省显示名。承运商面单上打的是它。
    var state: String
    var city: String
    /// 区/县。只有中国这类三级行政区划的国家会用到，其余国家为空。
    var district: String
    var street1: String
    /// 门牌 / 套间 / 单元，选填。
    var street2: String
    var zip: String

    // MARK: - 旧协议兼容字段（派生值，不要单独编辑）
    var region: String
    var detail: String

    init(id: String,
         isDefault: Bool,
         name: String,
         phone: String,
         countryCode: String,
         stateCode: String,
         state: String,
         city: String,
         district: String,
         street1: String,
         street2: String,
         zip: String) {
        self.id = id
        self.isDefault = isDefault
        self.name = name
        self.phone = phone
        self.countryCode = countryCode
        self.stateCode = stateCode
        self.state = state
        self.city = city
        self.district = district
        self.street1 = street1
        self.street2 = street2
        self.zip = zip
        self.region = AddrModel.composeRegion(countryCode: countryCode, state: state, city: city, district: district)
        self.detail = AddrModel.composeDetail(street1: street1, street2: street2, zip: zip)
    }

    /// 直接按字段构造（用于解析服务端下发的记录，不重新拼 region / detail）。
    init(id: String, isDefault: Bool, name: String, phone: String,
         countryCode: String, stateCode: String, state: String, city: String,
         district: String, street1: String, street2: String, zip: String,
         region: String, detail: String) {
        self.id = id
        self.isDefault = isDefault
        self.name = name
        self.phone = phone
        self.countryCode = countryCode
        self.stateCode = stateCode
        self.state = state
        self.city = city
        self.district = district
        self.street1 = street1
        self.street2 = street2
        self.zip = zip
        self.region = region
        self.detail = detail
    }

    enum CodingKeys: String, CodingKey {
        case id, isDefault, name, phone, countryCode, stateCode, state, city, district
        case street1, street2, zip, region, detail
    }

    /// 手写解码：结构化字段是后加的，**升级前存下来的地址里一个都没有**。
    /// 合成的 Codable 遇到缺键的非可选 String 会整条抛错，那等于用户升级后地址簿全空。
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

    /// 老记录：只有 region / detail，没有结构化字段。
    /// 它还能正常展示和寄给旧接口，但不能直接当商城收货地址用，编辑页会要求补全。
    var isStructured: Bool {
        return !countryCode.isEmpty && !street1.isEmpty && !city.isEmpty
    }

    /// 列表 / 资料页展示用的一行地址。
    var displayLine: String {
        if isStructured {
            let parts = [street1, street2, district, city,
                         [state, zip].filter { !$0.isEmpty }.joined(separator: " "),
                         AddressCatalog.countryName(countryCode)]
            return parts.filter { !$0.isEmpty }.joined(separator: ", ")
        }
        return [region, detail].filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: - 派生字段

    static func composeRegion(countryCode: String, state: String, city: String, district: String) -> String {
        let country = AddressCatalog.countryName(countryCode)
        return [country, state, city, district].filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func composeDetail(street1: String, street2: String, zip: String) -> String {
        return [street1, street2, zip].filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: - 老记录迁移

    /// 把只有 region / detail 的老记录尽量拆成结构化字段，供编辑页预填。
    /// 拆不准没关系 —— 用户在编辑页会看到并改，保存时才做完整校验。
    func migratedForEditing() -> AddrModel {
        guard !isStructured else { return self }
        let looksChinese = region.range(of: "\\p{Han}", options: .regularExpression) != nil
        let country = looksChinese ? "CN" : AddressCatalog.defaultCountryCode()

        var stateName = ""
        var stateCodeValue = ""
        var cityName = region
        if let list = AddressCatalog.subdivisions(for: country),
           let hit = list.first(where: { region.hasPrefix($0.name) || region.contains($0.name) }) {
            stateName = hit.name
            stateCodeValue = hit.code
            cityName = region.replacingOccurrences(of: hit.name, with: "").trimmingCharacters(in: .whitespaces)
        }

        let (phoneCountry, national) = AddressCatalog.splitE164(phone, hintCountry: country)
        let normalizedPhone = national.isEmpty ? "" : AddressCatalog.e164(national: national, countryCode: phoneCountry)

        return AddrModel(id: id,
                         isDefault: isDefault,
                         name: name,
                         phone: normalizedPhone,
                         countryCode: country,
                         stateCode: stateCodeValue,
                         state: stateName,
                         city: cityName,
                         district: "",
                         street1: detail,
                         street2: "",
                         zip: "")
    }
}
