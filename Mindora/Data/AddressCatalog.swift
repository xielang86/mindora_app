//
//  AddressCatalog.swift
//  mindora
//
//  收货地址用到的国家 / 州省 / 电话区号 / 邮编规则。
//
//  地址要同步到商城当收货地址，就不能再是「region + detail」两段自由文本：
//  承运商（USPS/UPS/FedEx）按 state 两位码 + ZIP 分区计价，缺一个都下不了单。
//  这里把结构化所需的最小数据集内置进来，避免为了一个下拉去拉三方库。
//

import Foundation

enum AddressCatalog {

    // MARK: - 国家

    struct Country {
        let code: String   // ISO 3166-1 alpha-2
        let name: String   // 按 App 当前语言本地化后的国家名
    }

    /// 全部国家/地区，按当前语言的国家名排序。
    ///
    /// 国家名不进本地化文件：`Locale.localizedString(forRegionCode:)` 已经带了全部语言的译名，
    /// 自己维护 245 × 10 条译文既没必要也一定会过期。
    static func countries() -> [Country] {
        let locale = LocalizationManager.shared.currentLocale
        let list = phoneRules.keys.compactMap { code -> Country? in
            guard let name = locale.localizedString(forRegionCode: code) else { return nil }
            return Country(code: code, name: name)
        }
        return list.sorted { $0.name.compare($1.name, options: [.caseInsensitive], range: nil, locale: locale) == .orderedAscending }
    }

    static func countryName(_ code: String) -> String {
        guard !code.isEmpty else { return "" }
        return LocalizationManager.shared.currentLocale.localizedString(forRegionCode: code) ?? code
    }

    /// 默认国家：优先跟随系统区域，系统区域不在表里时退回 US（主要客群）。
    static func defaultCountryCode() -> String {
        let region = Locale.current.regionCode ?? "US"
        return phoneRules[region] != nil ? region : "US"
    }

    // MARK: - 州 / 省

    struct Subdivision {
        let code: String
        let name: String
    }

    /// 有固定行政区划表的国家返回列表，其余返回 nil（表示这一栏改成自由文本输入）。
    static func subdivisions(for countryCode: String) -> [Subdivision]? {
        switch countryCode {
        case "US": return usStates
        case "CA": return caProvinces
        case "CN": return chinaDivisions.map { Subdivision(code: $0.code, name: $0.name) }
        default: return nil
        }
    }

    // MARK: - 中国的省 / 市 / 区三级联动

    /// 只有中国这一级要联动。美国「城市」是自由文本，没有可枚举的下级。
    static func hasCascadingCity(_ countryCode: String) -> Bool { countryCode == "CN" }
    static func hasDistrict(_ countryCode: String) -> Bool { countryCode == "CN" }

    struct DivisionNode {
        let code: String
        let name: String
        let children: [DivisionNode]
    }

    /// 省下面的市。省码对不上（比如用户先填了别的国家）时返回空数组。
    static func cities(provinceCode: String) -> [Subdivision] {
        guard let province = chinaDivisions.first(where: { $0.code == provinceCode }) else { return [] }
        return province.children.map { Subdivision(code: $0.code, name: $0.name) }
    }

    /// 市下面的区/县。
    static func districts(provinceCode: String, cityCode: String) -> [Subdivision] {
        guard let province = chinaDivisions.first(where: { $0.code == provinceCode }),
              let city = province.children.first(where: { $0.code == cityCode }) else { return [] }
        return city.children.map { Subdivision(code: $0.code, name: $0.name) }
    }

    /// 反查：只知道名字（老数据 / 定位回填）时找回对应的码。
    static func cityCode(provinceCode: String, cityName: String) -> String {
        cities(provinceCode: provinceCode).first { $0.name == cityName }?.code ?? ""
    }

    /// 省市区数据（3056 个区县）来自民政部区划代码，随包内置，不联网。
    /// 用懒加载：只有用户真的把国家切到中国才会解析这 87KB。
    private static let chinaDivisions: [DivisionNode] = loadChinaDivisions()

    private static func loadChinaDivisions() -> [DivisionNode] {
        guard let url = Bundle.main.url(forResource: "cn_divisions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return root.map { province in
            let cities = (province["s"] as? [[String: Any]] ?? []).map { city -> DivisionNode in
                let districts = (city["d"] as? [[String: Any]] ?? []).map {
                    DivisionNode(code: $0["c"] as? String ?? "", name: $0["n"] as? String ?? "", children: [])
                }
                return DivisionNode(code: city["c"] as? String ?? "",
                                    name: city["n"] as? String ?? "",
                                    children: districts)
            }
            return DivisionNode(code: province["c"] as? String ?? "",
                                name: province["n"] as? String ?? "",
                                children: cities)
        }
    }

    /// 州/省是否必填。没有区划表的国家（如英国、新加坡）本来就不写州，别拦着用户。
    static func requiresSubdivision(_ countryCode: String) -> Bool {
        return subdivisions(for: countryCode) != nil
    }

    // MARK: - 表单版式（字段顺序与标签随国家变）

    /// 表单里可能出现的行。收件人 / 手机号 / 国家三行所有国家都排在最前，不参与重排。
    enum Field {
        case line1, line2, cityState, district, zip
    }

    /// 地址各行的排列顺序。
    ///
    /// 参考 Google libaddressinput 的国别地址格式：英美系是「街道 → 城市 → 州 → 邮编」，
    /// 东亚等地区是「邮编 → 省市 → 街道」由大到小写。填写顺序不对，用户会一直填错格子。
    enum Layout {
        /// 美国 / 加拿大 / 澳洲 / 英国等：地址第 1 行 → 第 2 行 → 城市 → 州 → 邮编。
        case streetFirst
        /// 中国 / 日本 / 韩国等：邮编 → 省/州 → 城市 → 地址第 1 行 → 第 2 行。
        case postalFirst
    }

    private static let streetFirstCountries: Set<String> = [
        "US", "CA", "AU", "NZ", "GB", "IE", "IN", "MY", "PH", "SG", "TH", "ZA",
        "MX", "BR", "AR", "CL", "CO", "PE", "NG", "KE", "PK", "BD", "LK", "AE",
    ]

    static func layout(for countryCode: String) -> Layout {
        return streetFirstCountries.contains(countryCode) ? .streetFirst : .postalFirst
    }

    static func fieldOrder(for countryCode: String) -> [Field] {
        switch layout(for: countryCode) {
        case .streetFirst: return [.line1, .line2, .cityState, .zip]
        case .postalFirst:
            return hasDistrict(countryCode)
                ? [.zip, .cityState, .district, .line1, .line2]
                : [.zip, .cityState, .line1, .line2]
        }
    }

    /// 不写州/省的国家：英国、德国、新加坡这些地方地址里根本没有这一层，
    /// 摆一个空格子在那儿只会让人以为漏填了。
    private static let noSubdivisionCountries: Set<String> = [
        "GB", "IE", "DE", "FR", "NL", "BE", "CH", "AT", "SE", "NO", "DK", "FI",
        "PL", "PT", "CZ", "HU", "RO", "GR", "SG", "HK", "MO", "IL", "LU", "IS",
    ]

    static func showsSubdivision(_ countryCode: String) -> Bool {
        if subdivisions(for: countryCode) != nil { return true }
        return !noSubdivisionCountries.contains(countryCode)
    }

    /// 州/省这一栏在各国的叫法：美国叫 State，加拿大 / 中国叫 Province，日本叫都道府県。
    static func subdivisionLabelKey(for countryCode: String) -> String {
        switch countryCode {
        case "US", "AU", "BR", "MX", "MY", "NG", "IN": return "address.state_only"
        case "CA", "CN", "ID", "PH", "ZA", "AR", "CL", "TH", "KR": return "address.province"
        case "JP": return "address.prefecture"
        default: return "address.state"
        }
    }

    /// 美国写 ZIP，其余国家写 Postal code。
    static func zipLabelKey(for countryCode: String) -> String {
        return countryCode == "US" ? "address.zip_only" : "address.postal_code"
    }

    // MARK: - 邮编

    /// 邮编是否必填。美国是硬需求：没有 ZIP 承运商无法分区，商城侧直接下不了单。
    static func requiresZip(_ countryCode: String) -> Bool {
        return !noZipCountries.contains(countryCode)
    }

    /// 邮编格式校验。没有列出规则的国家只做「非空且不超长」的宽松判断，
    /// 宁可放行也不要因为规则不全把真实用户挡在门外。
    static func isValidZip(_ raw: String, countryCode: String) -> Bool {
        let zip = raw.trimmingCharacters(in: .whitespaces)
        if zip.isEmpty { return !requiresZip(countryCode) }
        if let pattern = zipPatterns[countryCode] {
            return zip.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        return zip.count <= 16
    }

    static func zipPlaceholder(_ countryCode: String) -> String {
        return zipExamples[countryCode] ?? ""
    }

    // MARK: - 电话

    struct PhoneRule {
        let calling: Int      // 国际区号，不含 "+"
        let minDigits: Int    // 国内号码位数下限（不含区号）
        let maxDigits: Int
        let example: String   // 该国的示例号码，用作输入框 placeholder
    }

    static func callingCode(for countryCode: String) -> String {
        guard let rule = phoneRules[countryCode] else { return "" }
        return "+\(rule.calling)"
    }

    static func phoneExample(for countryCode: String) -> String {
        return phoneRules[countryCode]?.example ?? ""
    }

    /// 只校验位数，不做运营商号段判断。
    ///
    /// 位数区间取自 libphonenumber 的 general_desc（固话+手机+服务号全算），
    /// 所以美国是精确 10 位，德国这类号长跨度大的国家区间就宽 —— 目的是拦住
    /// 「1111」「123」这种明显乱填，而不是替承运商做地址核验。
    static func isValidPhone(national raw: String, countryCode: String) -> Bool {
        let digits = raw.filter { $0.isNumber }
        guard !digits.isEmpty else { return false }
        guard let rule = phoneRules[countryCode] else { return digits.count >= 6 && digits.count <= 15 }
        return digits.count >= rule.minDigits && digits.count <= rule.maxDigits
    }

    /// 拼成 E.164（`+16505551234`）：商城和短信通道都按这个格式收号码。
    static func e164(national raw: String, countryCode: String) -> String {
        let digits = raw.filter { $0.isNumber }
        guard !digits.isEmpty else { return "" }
        guard let rule = phoneRules[countryCode] else { return "+" + digits }
        return "+\(rule.calling)\(digits)"
    }

    /// E.164 拆回「国家 + 国内号码」，用于回填编辑页。
    ///
    /// 同一个区号可能对应多个国家（+1 就有美国、加拿大和一堆加勒比国家），
    /// 所以这里带上地址本身的国家做提示，匹配得上就优先用它。
    static func splitE164(_ raw: String, hintCountry: String) -> (country: String, national: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("+") else {
            return (hintCountry, trimmed.filter { $0.isNumber })
        }
        let digits = trimmed.dropFirst().filter { $0.isNumber }
        // 区号最长 3 位，从长到短试，命中即止。
        for length in stride(from: 3, through: 1, by: -1) where digits.count > length {
            guard let calling = Int(digits.prefix(length)) else { continue }
            let national = String(digits.dropFirst(length))
            if let rule = phoneRules[hintCountry], rule.calling == calling {
                return (hintCountry, national)
            }
            if let match = phoneRules.first(where: { $0.value.calling == calling })?.key {
                return (match, national)
            }
        }
        return (hintCountry, String(digits))
    }

    // MARK: - 数据表

    /// 不使用邮编的国家/地区，这些地方要求填邮编等于逼用户瞎编。
    private static let noZipCountries: Set<String> = [
        "AE", "AO", "AG", "AW", "BS", "BZ", "BJ", "BW", "BF", "BI", "CM", "CF", "KM", "CG", "CD",
        "CK", "CI", "DJ", "DM", "GQ", "ER", "FJ", "TF", "GM", "GH", "GD", "GY", "HK", "IE", "JM",
        "KE", "KI", "KP", "LY", "MO", "MW", "ML", "MR", "MU", "MS", "NR", "AN", "NU", "KN", "LC",
        "ST", "SC", "SL", "SB", "SO", "SR", "SY", "TL", "TK", "TO", "TT", "TV", "UG", "VU", "YE",
        "ZW", "QA", "PA",
    ]

    private static let zipPatterns: [String: String] = [
        "US": "^\\d{5}(-\\d{4})?$",
        "CA": "^[A-Z]\\d[A-Z] ?\\d[A-Z]\\d$",
        "GB": "^[A-Z]{1,2}\\d[A-Z\\d]? ?\\d[A-Z]{2}$",
        "CN": "^\\d{6}$",
        "JP": "^\\d{3}-?\\d{4}$",
        "DE": "^\\d{5}$",
        "FR": "^\\d{5}$",
        "IT": "^\\d{5}$",
        "ES": "^\\d{5}$",
        "AU": "^\\d{4}$",
        "NZ": "^\\d{4}$",
        "IN": "^\\d{6}$",
        "BR": "^\\d{5}-?\\d{3}$",
        "MX": "^\\d{5}$",
        "KR": "^\\d{5}$",
        "NL": "^\\d{4} ?[A-Z]{2}$",
        "SG": "^\\d{6}$",
        "ID": "^\\d{5}$",
        "TW": "^\\d{3}(\\d{2})?$",
    ]

    private static let zipExamples: [String: String] = [
        "US": "94043", "CA": "K1A 0B1", "GB": "SW1A 1AA", "CN": "200062", "JP": "150-0001",
        "DE": "10115", "FR": "75001", "IT": "00100", "ES": "28001", "AU": "2000", "NZ": "6011",
        "IN": "110001", "BR": "01310-100", "MX": "01000", "KR": "04524", "NL": "1012 AB",
        "SG": "018956", "ID": "10110", "TW": "100",
    ]

    private static let usStates: [Subdivision] = [
            Subdivision(code: "AL", name: "Alabama"),
            Subdivision(code: "AK", name: "Alaska"),
            Subdivision(code: "AZ", name: "Arizona"),
            Subdivision(code: "AR", name: "Arkansas"),
            Subdivision(code: "CA", name: "California"),
            Subdivision(code: "CO", name: "Colorado"),
            Subdivision(code: "CT", name: "Connecticut"),
            Subdivision(code: "DE", name: "Delaware"),
            Subdivision(code: "DC", name: "District of Columbia"),
            Subdivision(code: "FL", name: "Florida"),
            Subdivision(code: "GA", name: "Georgia"),
            Subdivision(code: "HI", name: "Hawaii"),
            Subdivision(code: "ID", name: "Idaho"),
            Subdivision(code: "IL", name: "Illinois"),
            Subdivision(code: "IN", name: "Indiana"),
            Subdivision(code: "IA", name: "Iowa"),
            Subdivision(code: "KS", name: "Kansas"),
            Subdivision(code: "KY", name: "Kentucky"),
            Subdivision(code: "LA", name: "Louisiana"),
            Subdivision(code: "ME", name: "Maine"),
            Subdivision(code: "MD", name: "Maryland"),
            Subdivision(code: "MA", name: "Massachusetts"),
            Subdivision(code: "MI", name: "Michigan"),
            Subdivision(code: "MN", name: "Minnesota"),
            Subdivision(code: "MS", name: "Mississippi"),
            Subdivision(code: "MO", name: "Missouri"),
            Subdivision(code: "MT", name: "Montana"),
            Subdivision(code: "NE", name: "Nebraska"),
            Subdivision(code: "NV", name: "Nevada"),
            Subdivision(code: "NH", name: "New Hampshire"),
            Subdivision(code: "NJ", name: "New Jersey"),
            Subdivision(code: "NM", name: "New Mexico"),
            Subdivision(code: "NY", name: "New York"),
            Subdivision(code: "NC", name: "North Carolina"),
            Subdivision(code: "ND", name: "North Dakota"),
            Subdivision(code: "OH", name: "Ohio"),
            Subdivision(code: "OK", name: "Oklahoma"),
            Subdivision(code: "OR", name: "Oregon"),
            Subdivision(code: "PA", name: "Pennsylvania"),
            Subdivision(code: "RI", name: "Rhode Island"),
            Subdivision(code: "SC", name: "South Carolina"),
            Subdivision(code: "SD", name: "South Dakota"),
            Subdivision(code: "TN", name: "Tennessee"),
            Subdivision(code: "TX", name: "Texas"),
            Subdivision(code: "UT", name: "Utah"),
            Subdivision(code: "VT", name: "Vermont"),
            Subdivision(code: "VA", name: "Virginia"),
            Subdivision(code: "WA", name: "Washington"),
            Subdivision(code: "WV", name: "West Virginia"),
            Subdivision(code: "WI", name: "Wisconsin"),
            Subdivision(code: "WY", name: "Wyoming"),
            Subdivision(code: "AS", name: "American Samoa"),
            Subdivision(code: "GU", name: "Guam"),
            Subdivision(code: "MP", name: "Northern Mariana Islands"),
            Subdivision(code: "PR", name: "Puerto Rico"),
            Subdivision(code: "VI", name: "U.S. Virgin Islands"),
            Subdivision(code: "AA", name: "Armed Forces Americas"),
            Subdivision(code: "AE", name: "Armed Forces Europe"),
            Subdivision(code: "AP", name: "Armed Forces Pacific"),
    ]

    private static let caProvinces: [Subdivision] = [
            Subdivision(code: "AB", name: "Alberta"),
            Subdivision(code: "BC", name: "British Columbia"),
            Subdivision(code: "MB", name: "Manitoba"),
            Subdivision(code: "NB", name: "New Brunswick"),
            Subdivision(code: "NL", name: "Newfoundland and Labrador"),
            Subdivision(code: "NT", name: "Northwest Territories"),
            Subdivision(code: "NS", name: "Nova Scotia"),
            Subdivision(code: "NU", name: "Nunavut"),
            Subdivision(code: "ON", name: "Ontario"),
            Subdivision(code: "PE", name: "Prince Edward Island"),
            Subdivision(code: "QC", name: "Quebec"),
            Subdivision(code: "SK", name: "Saskatchewan"),
            Subdivision(code: "YT", name: "Yukon"),
    ]

    /// 区号与号码位数，由 libphonenumber 元数据生成，勿手改。
    static let phoneRules: [String: PhoneRule] = [
        "AC": PhoneRule(calling: 247, minDigits: 5, maxDigits: 6, example: "62889"),
        "AD": PhoneRule(calling: 376, minDigits: 6, maxDigits: 9, example: "712 345"),
        "AE": PhoneRule(calling: 971, minDigits: 5, maxDigits: 12, example: "02 234 5678"),
        "AF": PhoneRule(calling: 93, minDigits: 9, maxDigits: 9, example: "023 456 7890"),
        "AG": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(268) 460-1234"),
        "AI": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(264) 461-2345"),
        "AL": PhoneRule(calling: 355, minDigits: 6, maxDigits: 9, example: "022 345 678"),
        "AM": PhoneRule(calling: 374, minDigits: 8, maxDigits: 8, example: "(010) 123456"),
        "AO": PhoneRule(calling: 244, minDigits: 9, maxDigits: 9, example: "222 123 456"),
        "AR": PhoneRule(calling: 54, minDigits: 10, maxDigits: 11, example: "011 2345-6789"),
        "AS": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(684) 622-1234"),
        "AT": PhoneRule(calling: 43, minDigits: 4, maxDigits: 13, example: "01 234567890"),
        "AU": PhoneRule(calling: 61, minDigits: 5, maxDigits: 12, example: "(02) 1234 5678"),
        "AW": PhoneRule(calling: 297, minDigits: 7, maxDigits: 7, example: "521 2345"),
        "AX": PhoneRule(calling: 358, minDigits: 5, maxDigits: 12, example: "018 1234567"),
        "AZ": PhoneRule(calling: 994, minDigits: 9, maxDigits: 9, example: "(012) 312 34 56"),
        "BA": PhoneRule(calling: 387, minDigits: 8, maxDigits: 9, example: "030 212-345"),
        "BB": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(246) 412-3456"),
        "BD": PhoneRule(calling: 880, minDigits: 6, maxDigits: 10, example: "02-7111234"),
        "BE": PhoneRule(calling: 32, minDigits: 8, maxDigits: 9, example: "012 34 56 78"),
        "BF": PhoneRule(calling: 226, minDigits: 8, maxDigits: 8, example: "20 49 12 34"),
        "BG": PhoneRule(calling: 359, minDigits: 6, maxDigits: 12, example: "02 123 456"),
        "BH": PhoneRule(calling: 973, minDigits: 8, maxDigits: 8, example: "1700 1234"),
        "BI": PhoneRule(calling: 257, minDigits: 8, maxDigits: 8, example: "22 20 12 34"),
        "BJ": PhoneRule(calling: 229, minDigits: 8, maxDigits: 10, example: "01 20 21 12 34"),
        "BL": PhoneRule(calling: 590, minDigits: 9, maxDigits: 9, example: "0590 27 12 34"),
        "BM": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(441) 412-3456"),
        "BN": PhoneRule(calling: 673, minDigits: 7, maxDigits: 7, example: "234 5678"),
        "BO": PhoneRule(calling: 591, minDigits: 8, maxDigits: 9, example: "2 2123456"),
        "BQ": PhoneRule(calling: 599, minDigits: 7, maxDigits: 7, example: "715 1234"),
        "BR": PhoneRule(calling: 55, minDigits: 8, maxDigits: 11, example: "(11) 2345-6789"),
        "BS": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(242) 345-6789"),
        "BT": PhoneRule(calling: 975, minDigits: 7, maxDigits: 8, example: "2 345 678"),
        "BW": PhoneRule(calling: 267, minDigits: 7, maxDigits: 10, example: "240 1234"),
        "BY": PhoneRule(calling: 375, minDigits: 6, maxDigits: 11, example: "8 0152 45-09-11"),
        "BZ": PhoneRule(calling: 501, minDigits: 7, maxDigits: 11, example: "222-1234"),
        "CA": PhoneRule(calling: 1, minDigits: 7, maxDigits: 10, example: "(506) 234-5678"),
        "CC": PhoneRule(calling: 61, minDigits: 6, maxDigits: 12, example: "(08) 9162 1234"),
        "CD": PhoneRule(calling: 243, minDigits: 7, maxDigits: 10, example: "012 34567"),
        "CF": PhoneRule(calling: 236, minDigits: 8, maxDigits: 8, example: "21 61 23 45"),
        "CG": PhoneRule(calling: 242, minDigits: 9, maxDigits: 9, example: "22 212 3456"),
        "CH": PhoneRule(calling: 41, minDigits: 9, maxDigits: 12, example: "021 234 56 78"),
        "CI": PhoneRule(calling: 225, minDigits: 10, maxDigits: 10, example: "21 23 4 56789"),
        "CK": PhoneRule(calling: 682, minDigits: 5, maxDigits: 5, example: "21 234"),
        "CL": PhoneRule(calling: 56, minDigits: 9, maxDigits: 11, example: "600 123 456"),
        "CM": PhoneRule(calling: 237, minDigits: 8, maxDigits: 9, example: "2 22 12 34 56"),
        "CN": PhoneRule(calling: 86, minDigits: 7, maxDigits: 12, example: "010 1234 5678"),
        "CO": PhoneRule(calling: 57, minDigits: 8, maxDigits: 11, example: "(601) 2345678"),
        "CR": PhoneRule(calling: 506, minDigits: 8, maxDigits: 10, example: "2212 3456"),
        "CU": PhoneRule(calling: 53, minDigits: 6, maxDigits: 10, example: "(07) 1234567"),
        "CV": PhoneRule(calling: 238, minDigits: 7, maxDigits: 7, example: "221 12 34"),
        "CW": PhoneRule(calling: 599, minDigits: 7, maxDigits: 8, example: "9 435 1234"),
        "CX": PhoneRule(calling: 61, minDigits: 6, maxDigits: 12, example: "(08) 9164 1234"),
        "CY": PhoneRule(calling: 357, minDigits: 8, maxDigits: 8, example: "22 345678"),
        "CZ": PhoneRule(calling: 420, minDigits: 9, maxDigits: 12, example: "212 345 678"),
        "DE": PhoneRule(calling: 49, minDigits: 4, maxDigits: 15, example: "030 123456"),
        "DJ": PhoneRule(calling: 253, minDigits: 8, maxDigits: 8, example: "21 36 00 03"),
        "DK": PhoneRule(calling: 45, minDigits: 8, maxDigits: 8, example: "32 12 34 56"),
        "DM": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(767) 420-1234"),
        "DO": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(809) 234-5678"),
        "DZ": PhoneRule(calling: 213, minDigits: 8, maxDigits: 9, example: "012 34 56 78"),
        "EC": PhoneRule(calling: 593, minDigits: 8, maxDigits: 11, example: "(02) 212-3456"),
        "EE": PhoneRule(calling: 372, minDigits: 7, maxDigits: 10, example: "321 2345"),
        "EG": PhoneRule(calling: 20, minDigits: 8, maxDigits: 10, example: "02 34567890"),
        "EH": PhoneRule(calling: 212, minDigits: 9, maxDigits: 9, example: "05288-12345"),
        "ER": PhoneRule(calling: 291, minDigits: 7, maxDigits: 7, example: "08 370 362"),
        "ES": PhoneRule(calling: 34, minDigits: 9, maxDigits: 9, example: "810 12 34 56"),
        "ET": PhoneRule(calling: 251, minDigits: 9, maxDigits: 9, example: "011 111 2345"),
        "FI": PhoneRule(calling: 358, minDigits: 5, maxDigits: 12, example: "013 1234567"),
        "FJ": PhoneRule(calling: 679, minDigits: 7, maxDigits: 11, example: "321 2345"),
        "FK": PhoneRule(calling: 500, minDigits: 5, maxDigits: 5, example: "31234"),
        "FM": PhoneRule(calling: 691, minDigits: 7, maxDigits: 7, example: "320 1234"),
        "FO": PhoneRule(calling: 298, minDigits: 6, maxDigits: 6, example: "201234"),
        "FR": PhoneRule(calling: 33, minDigits: 9, maxDigits: 9, example: "01 23 45 67 89"),
        "GA": PhoneRule(calling: 241, minDigits: 7, maxDigits: 8, example: "01 44 12 34"),
        "GB": PhoneRule(calling: 44, minDigits: 7, maxDigits: 10, example: "0121 234 5678"),
        "GD": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(473) 269-1234"),
        "GE": PhoneRule(calling: 995, minDigits: 9, maxDigits: 9, example: "032 212 34 56"),
        "GF": PhoneRule(calling: 594, minDigits: 9, maxDigits: 9, example: "0594 10 12 34"),
        "GG": PhoneRule(calling: 44, minDigits: 7, maxDigits: 10, example: "01481 256789"),
        "GH": PhoneRule(calling: 233, minDigits: 8, maxDigits: 9, example: "030 234 5678"),
        "GI": PhoneRule(calling: 350, minDigits: 8, maxDigits: 8, example: "200 12345"),
        "GL": PhoneRule(calling: 299, minDigits: 6, maxDigits: 6, example: "32 10 00"),
        "GM": PhoneRule(calling: 220, minDigits: 7, maxDigits: 7, example: "566 1234"),
        "GN": PhoneRule(calling: 224, minDigits: 8, maxDigits: 9, example: "30 24 12 34"),
        "GP": PhoneRule(calling: 590, minDigits: 9, maxDigits: 9, example: "0590 20 12 34"),
        "GQ": PhoneRule(calling: 240, minDigits: 9, maxDigits: 9, example: "333 091 234"),
        "GR": PhoneRule(calling: 30, minDigits: 10, maxDigits: 12, example: "21 2345 6789"),
        "GT": PhoneRule(calling: 502, minDigits: 8, maxDigits: 11, example: "2245 6789"),
        "GU": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(671) 300-1234"),
        "GW": PhoneRule(calling: 245, minDigits: 7, maxDigits: 9, example: "443 201 234"),
        "GY": PhoneRule(calling: 592, minDigits: 7, maxDigits: 7, example: "220 1234"),
        "HK": PhoneRule(calling: 852, minDigits: 5, maxDigits: 11, example: "2123 4567"),
        "HN": PhoneRule(calling: 504, minDigits: 8, maxDigits: 11, example: "2212-3456"),
        "HR": PhoneRule(calling: 385, minDigits: 7, maxDigits: 9, example: "01 2345 678"),
        "HT": PhoneRule(calling: 509, minDigits: 8, maxDigits: 8, example: "22 45 3300"),
        "HU": PhoneRule(calling: 36, minDigits: 8, maxDigits: 9, example: "(06 1) 234 5678"),
        "ID": PhoneRule(calling: 62, minDigits: 7, maxDigits: 17, example: "(021) 8350123"),
        "IE": PhoneRule(calling: 353, minDigits: 7, maxDigits: 10, example: "(022) 12345"),
        "IL": PhoneRule(calling: 972, minDigits: 7, maxDigits: 12, example: "02-123-4567"),
        "IM": PhoneRule(calling: 44, minDigits: 10, maxDigits: 10, example: "01624 756789"),
        "IN": PhoneRule(calling: 91, minDigits: 8, maxDigits: 13, example: "074104 10123"),
        "IO": PhoneRule(calling: 246, minDigits: 7, maxDigits: 7, example: "370 9100"),
        "IQ": PhoneRule(calling: 964, minDigits: 8, maxDigits: 10, example: "01 234 5678"),
        "IR": PhoneRule(calling: 98, minDigits: 4, maxDigits: 10, example: "021 2345 6789"),
        "IS": PhoneRule(calling: 354, minDigits: 7, maxDigits: 9, example: "410 1234"),
        "IT": PhoneRule(calling: 39, minDigits: 6, maxDigits: 12, example: "02 1234 5678"),
        "JE": PhoneRule(calling: 44, minDigits: 10, maxDigits: 10, example: "01534 456789"),
        "JM": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(876) 523-0123"),
        "JO": PhoneRule(calling: 962, minDigits: 8, maxDigits: 9, example: "(06) 200 1234"),
        "JP": PhoneRule(calling: 81, minDigits: 8, maxDigits: 17, example: "03-1234-5678"),
        "KE": PhoneRule(calling: 254, minDigits: 7, maxDigits: 10, example: "020 2012345"),
        "KG": PhoneRule(calling: 996, minDigits: 9, maxDigits: 10, example: "0312 123 456"),
        "KH": PhoneRule(calling: 855, minDigits: 8, maxDigits: 10, example: "023 756 789"),
        "KI": PhoneRule(calling: 686, minDigits: 5, maxDigits: 8, example: "31234"),
        "KM": PhoneRule(calling: 269, minDigits: 7, maxDigits: 7, example: "771 23 45"),
        "KN": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(869) 236-1234"),
        "KP": PhoneRule(calling: 850, minDigits: 8, maxDigits: 10, example: "02 123 4567"),
        "KR": PhoneRule(calling: 82, minDigits: 5, maxDigits: 14, example: "02-212-3456"),
        "KW": PhoneRule(calling: 965, minDigits: 7, maxDigits: 8, example: "2234 5678"),
        "KY": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(345) 222-1234"),
        "KZ": PhoneRule(calling: 7, minDigits: 10, maxDigits: 14, example: "8 (71234) 5 67 89"),
        "LA": PhoneRule(calling: 856, minDigits: 8, maxDigits: 10, example: "021 212 862"),
        "LB": PhoneRule(calling: 961, minDigits: 7, maxDigits: 8, example: "01 123 456"),
        "LC": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(758) 430-5678"),
        "LI": PhoneRule(calling: 423, minDigits: 7, maxDigits: 9, example: "234 56 78"),
        "LK": PhoneRule(calling: 94, minDigits: 9, maxDigits: 9, example: "0112 345 678"),
        "LR": PhoneRule(calling: 231, minDigits: 7, maxDigits: 9, example: "021 234 567"),
        "LS": PhoneRule(calling: 266, minDigits: 8, maxDigits: 8, example: "2212 3456"),
        "LT": PhoneRule(calling: 370, minDigits: 8, maxDigits: 8, example: "(0-312) 34567"),
        "LU": PhoneRule(calling: 352, minDigits: 4, maxDigits: 11, example: "27 12 34 56"),
        "LV": PhoneRule(calling: 371, minDigits: 8, maxDigits: 8, example: "63 123 456"),
        "LY": PhoneRule(calling: 218, minDigits: 9, maxDigits: 9, example: "021-2345678"),
        "MA": PhoneRule(calling: 212, minDigits: 9, maxDigits: 9, example: "0520-123456"),
        "MC": PhoneRule(calling: 377, minDigits: 8, maxDigits: 9, example: "99 12 34 56"),
        "MD": PhoneRule(calling: 373, minDigits: 8, maxDigits: 8, example: "022 212 345"),
        "ME": PhoneRule(calling: 382, minDigits: 8, maxDigits: 9, example: "030 234 567"),
        "MF": PhoneRule(calling: 590, minDigits: 9, maxDigits: 9, example: "0590 27 12 34"),
        "MG": PhoneRule(calling: 261, minDigits: 9, maxDigits: 9, example: "020 21 234 56"),
        "MH": PhoneRule(calling: 692, minDigits: 7, maxDigits: 7, example: "247-1234"),
        "MK": PhoneRule(calling: 389, minDigits: 8, maxDigits: 8, example: "02 201 2345"),
        "ML": PhoneRule(calling: 223, minDigits: 8, maxDigits: 8, example: "20 21 23 45"),
        "MM": PhoneRule(calling: 95, minDigits: 6, maxDigits: 10, example: "01 234 567"),
        "MN": PhoneRule(calling: 976, minDigits: 8, maxDigits: 10, example: "5312 3456"),
        "MO": PhoneRule(calling: 853, minDigits: 7, maxDigits: 8, example: "2821 2345"),
        "MP": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(670) 234-5678"),
        "MQ": PhoneRule(calling: 596, minDigits: 9, maxDigits: 9, example: "0596 30 12 34"),
        "MR": PhoneRule(calling: 222, minDigits: 8, maxDigits: 8, example: "35 12 34 56"),
        "MS": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(664) 491-2345"),
        "MT": PhoneRule(calling: 356, minDigits: 8, maxDigits: 8, example: "2100 1234"),
        "MU": PhoneRule(calling: 230, minDigits: 7, maxDigits: 10, example: "5448 0123"),
        "MV": PhoneRule(calling: 960, minDigits: 7, maxDigits: 10, example: "670-1234"),
        "MW": PhoneRule(calling: 265, minDigits: 7, maxDigits: 9, example: "01 234 567"),
        "MX": PhoneRule(calling: 52, minDigits: 10, maxDigits: 10, example: "200 123 4567"),
        "MY": PhoneRule(calling: 60, minDigits: 8, maxDigits: 10, example: "03-2385 6789"),
        "MZ": PhoneRule(calling: 258, minDigits: 8, maxDigits: 9, example: "21 123 456"),
        "NA": PhoneRule(calling: 264, minDigits: 8, maxDigits: 9, example: "061 221 234"),
        "NC": PhoneRule(calling: 687, minDigits: 6, maxDigits: 6, example: "20.12.34"),
        "NE": PhoneRule(calling: 227, minDigits: 8, maxDigits: 8, example: "20 20 12 34"),
        "NF": PhoneRule(calling: 672, minDigits: 6, maxDigits: 6, example: "10 6609"),
        "NG": PhoneRule(calling: 234, minDigits: 10, maxDigits: 14, example: "02033 12 3456"),
        "NI": PhoneRule(calling: 505, minDigits: 8, maxDigits: 8, example: "2123 4567"),
        "NL": PhoneRule(calling: 31, minDigits: 5, maxDigits: 11, example: "010 123 4567"),
        "NO": PhoneRule(calling: 47, minDigits: 5, maxDigits: 8, example: "21 23 45 67"),
        "NP": PhoneRule(calling: 977, minDigits: 8, maxDigits: 11, example: "01-4567890"),
        "NR": PhoneRule(calling: 674, minDigits: 7, maxDigits: 7, example: "444 1234"),
        "NU": PhoneRule(calling: 683, minDigits: 4, maxDigits: 7, example: "7012"),
        "NZ": PhoneRule(calling: 64, minDigits: 5, maxDigits: 10, example: "03 234 5678"),
        "OM": PhoneRule(calling: 968, minDigits: 7, maxDigits: 9, example: "23 123456"),
        "PA": PhoneRule(calling: 507, minDigits: 7, maxDigits: 11, example: "200-1234"),
        "PE": PhoneRule(calling: 51, minDigits: 8, maxDigits: 9, example: "(01) 1234567"),
        "PF": PhoneRule(calling: 689, minDigits: 6, maxDigits: 9, example: "40 41 23 45"),
        "PG": PhoneRule(calling: 675, minDigits: 7, maxDigits: 8, example: "312 3456"),
        "PH": PhoneRule(calling: 63, minDigits: 6, maxDigits: 13, example: "(02) 3234 5678"),
        "PK": PhoneRule(calling: 92, minDigits: 8, maxDigits: 12, example: "(021) 23456789"),
        "PL": PhoneRule(calling: 48, minDigits: 6, maxDigits: 10, example: "12 345 67 89"),
        "PM": PhoneRule(calling: 508, minDigits: 6, maxDigits: 9, example: "043 01 23"),
        "PR": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(787) 234-5678"),
        "PS": PhoneRule(calling: 970, minDigits: 8, maxDigits: 10, example: "02 223 4567"),
        "PT": PhoneRule(calling: 351, minDigits: 9, maxDigits: 9, example: "21 234 5678"),
        "PW": PhoneRule(calling: 680, minDigits: 7, maxDigits: 7, example: "277 1234"),
        "PY": PhoneRule(calling: 595, minDigits: 6, maxDigits: 11, example: "(021) 234 5678"),
        "QA": PhoneRule(calling: 974, minDigits: 7, maxDigits: 11, example: "4412 3456"),
        "RE": PhoneRule(calling: 262, minDigits: 9, maxDigits: 9, example: "0262 16 12 34"),
        "RO": PhoneRule(calling: 40, minDigits: 6, maxDigits: 9, example: "021 123 4567"),
        "RS": PhoneRule(calling: 381, minDigits: 6, maxDigits: 12, example: "010 234567"),
        "RU": PhoneRule(calling: 7, minDigits: 10, maxDigits: 14, example: "8 (301) 123-45-67"),
        "RW": PhoneRule(calling: 250, minDigits: 8, maxDigits: 9, example: "250 123 456"),
        "SA": PhoneRule(calling: 966, minDigits: 9, maxDigits: 10, example: "011 234 5678"),
        "SB": PhoneRule(calling: 677, minDigits: 5, maxDigits: 7, example: "40123"),
        "SC": PhoneRule(calling: 248, minDigits: 7, maxDigits: 7, example: "4 217 123"),
        "SD": PhoneRule(calling: 249, minDigits: 9, maxDigits: 9, example: "015 312 3456"),
        "SE": PhoneRule(calling: 46, minDigits: 6, maxDigits: 12, example: "08-12 34 56"),
        "SG": PhoneRule(calling: 65, minDigits: 8, maxDigits: 11, example: "6123 4567"),
        "SH": PhoneRule(calling: 290, minDigits: 4, maxDigits: 5, example: "22158"),
        "SI": PhoneRule(calling: 386, minDigits: 5, maxDigits: 8, example: "(01) 234 56 78"),
        "SJ": PhoneRule(calling: 47, minDigits: 5, maxDigits: 8, example: "79 12 34 56"),
        "SK": PhoneRule(calling: 421, minDigits: 6, maxDigits: 9, example: "02/212 345 67"),
        "SL": PhoneRule(calling: 232, minDigits: 8, maxDigits: 8, example: "(022) 221234"),
        "SM": PhoneRule(calling: 378, minDigits: 8, maxDigits: 10, example: "0549 886377"),
        "SN": PhoneRule(calling: 221, minDigits: 9, maxDigits: 9, example: "30 101 23 45"),
        "SO": PhoneRule(calling: 252, minDigits: 6, maxDigits: 9, example: "4 012345"),
        "SR": PhoneRule(calling: 597, minDigits: 6, maxDigits: 7, example: "211-234"),
        "SS": PhoneRule(calling: 211, minDigits: 9, maxDigits: 9, example: "0181 234 567"),
        "ST": PhoneRule(calling: 239, minDigits: 7, maxDigits: 7, example: "222 1234"),
        "SV": PhoneRule(calling: 503, minDigits: 7, maxDigits: 11, example: "2123 4567"),
        "SX": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(721) 542-5678"),
        "SY": PhoneRule(calling: 963, minDigits: 8, maxDigits: 9, example: "011 234 5678"),
        "SZ": PhoneRule(calling: 268, minDigits: 8, maxDigits: 9, example: "2217 1234"),
        "TA": PhoneRule(calling: 290, minDigits: 4, maxDigits: 4, example: "8999"),
        "TC": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(649) 712-1234"),
        "TD": PhoneRule(calling: 235, minDigits: 8, maxDigits: 8, example: "22 50 12 34"),
        "TG": PhoneRule(calling: 228, minDigits: 8, maxDigits: 8, example: "22 21 23 45"),
        "TH": PhoneRule(calling: 66, minDigits: 8, maxDigits: 13, example: "02 123 4567"),
        "TJ": PhoneRule(calling: 992, minDigits: 9, maxDigits: 9, example: "372 12 3456"),
        "TK": PhoneRule(calling: 690, minDigits: 4, maxDigits: 7, example: "3101"),
        "TL": PhoneRule(calling: 670, minDigits: 7, maxDigits: 8, example: "211 2345"),
        "TM": PhoneRule(calling: 993, minDigits: 8, maxDigits: 8, example: "(8 12) 34-56-78"),
        "TN": PhoneRule(calling: 216, minDigits: 8, maxDigits: 8, example: "30 010 123"),
        "TO": PhoneRule(calling: 676, minDigits: 5, maxDigits: 7, example: "20-123"),
        "TR": PhoneRule(calling: 90, minDigits: 7, maxDigits: 13, example: "(0212) 345 67 89"),
        "TT": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(868) 221-1234"),
        "TV": PhoneRule(calling: 688, minDigits: 5, maxDigits: 7, example: "20 123"),
        "TW": PhoneRule(calling: 886, minDigits: 7, maxDigits: 11, example: "02 2123 4567"),
        "TZ": PhoneRule(calling: 255, minDigits: 9, maxDigits: 9, example: "022 234 5678"),
        "UA": PhoneRule(calling: 380, minDigits: 9, maxDigits: 10, example: "03112 34567"),
        "UG": PhoneRule(calling: 256, minDigits: 9, maxDigits: 9, example: "031 2345678"),
        "US": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(201) 555-0123"),
        "UY": PhoneRule(calling: 598, minDigits: 4, maxDigits: 13, example: "2123 1234"),
        "UZ": PhoneRule(calling: 998, minDigits: 9, maxDigits: 9, example: "66 905 01 23"),
        "VA": PhoneRule(calling: 39, minDigits: 6, maxDigits: 12, example: "06 6981 2345"),
        "VC": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(784) 266-1234"),
        "VE": PhoneRule(calling: 58, minDigits: 10, maxDigits: 10, example: "0212-1234567"),
        "VG": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(284) 229-1234"),
        "VI": PhoneRule(calling: 1, minDigits: 10, maxDigits: 10, example: "(340) 642-1234"),
        "VN": PhoneRule(calling: 84, minDigits: 7, maxDigits: 10, example: "0210 1234 567"),
        "VU": PhoneRule(calling: 678, minDigits: 5, maxDigits: 7, example: "22123"),
        "WF": PhoneRule(calling: 681, minDigits: 6, maxDigits: 9, example: "72 12 34"),
        "WS": PhoneRule(calling: 685, minDigits: 5, maxDigits: 10, example: "22123"),
        "XK": PhoneRule(calling: 383, minDigits: 8, maxDigits: 12, example: "028 012 345"),
        "YE": PhoneRule(calling: 967, minDigits: 7, maxDigits: 9, example: "01 234 567"),
        "YT": PhoneRule(calling: 262, minDigits: 9, maxDigits: 9, example: "0269 60 12 34"),
        "ZA": PhoneRule(calling: 27, minDigits: 5, maxDigits: 10, example: "010 123 4567"),
        "ZM": PhoneRule(calling: 260, minDigits: 9, maxDigits: 9, example: "0211 234 567"),
        "ZW": PhoneRule(calling: 263, minDigits: 5, maxDigits: 10, example: "013 12345"),
    ]
}
