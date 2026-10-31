//
//  MerchantNormalizer.swift
//  smartbud
//
//  Turns the free text a receipt or the user leaves in the note into one
//  merchant identity: "美团-张亮麻辣烫", "美团外卖 35" and "美团" all have to
//  land on the same key, or statistics show three shops where the user sees
//  one. Pure functions only — no SwiftData, no repository — so the rules can
//  be unit tested without a store.
//

import Foundation

/// One merchant after normalisation.
struct MerchantIdentity: Hashable {
    /// What statistics show. The alias table's canonical spelling when it
    /// knows the name, otherwise the cleaned-up input.
    let name: String
    /// Grouping key. Lower-cased, half-width, spaces and punctuation removed.
    let key: String
}

/// Editable alias table.
///
/// Both dictionaries are keyed in *key form* (see `MerchantNormalizer.key`):
/// lower-case, no spaces, no punctuation. Adding a brand is a data edit here,
/// not a code change; callers may also pass their own table
/// (`normalize(_:aliases:)`) so a future settings screen can override it.
struct MerchantAliasTable: Equatable {
    /// Canonical key → spelling shown in statistics.
    var displayNames: [String: String]
    /// Alternative spelling's key → canonical key.
    var aliases: [String: String]

    static let `default` = MerchantAliasTable(
        displayNames: [
            "星巴克": "星巴克", "瑞幸": "瑞幸", "美团": "美团", "饿了么": "饿了么",
            "滴滴": "滴滴", "淘宝": "淘宝", "天猫": "天猫", "京东": "京东",
            "拼多多": "拼多多", "盒马": "盒马", "山姆": "山姆", "沃尔玛": "沃尔玛",
            "麦当劳": "麦当劳", "肯德基": "肯德基",
            "amazon": "Amazon", "uber": "Uber", "apple": "Apple"
        ],
        aliases: [
            "星巴克咖啡": "星巴克", "starbucks": "星巴克", "starbuckscoffee": "星巴克",
            "瑞幸咖啡": "瑞幸", "luckin": "瑞幸", "luckincoffee": "瑞幸",
            "美团外卖": "美团", "美团点评": "美团", "meituan": "美团", "meituanwaimai": "美团",
            "饿了么外卖": "饿了么", "eleme": "饿了么",
            "滴滴出行": "滴滴", "滴滴打车": "滴滴", "didi": "滴滴",
            "淘宝网": "淘宝", "taobao": "淘宝",
            "tmall": "天猫", "京东商城": "京东", "jd": "京东",
            "拼夕夕": "拼多多", "pinduoduo": "拼多多",
            "盒马鲜生": "盒马", "山姆会员店": "山姆", "samsclub": "山姆",
            "沃尔玛超市": "沃尔玛", "walmart": "沃尔玛",
            "kfc": "肯德基", "mcdonalds": "麦当劳"
        ]
    )
}

enum MerchantNormalizer {

    /// Longer names would be a receipt line rather than a merchant.
    static let maxLength = 40

    /// Brands the parser recognises. Matched as a substring of a note, so the
    /// order only decides which name wins when a note mentions two.
    static let knownBrands = [
        "星巴克", "瑞幸", "美团", "饿了么", "滴滴", "京东", "淘宝",
        "天猫", "麦当劳", "肯德基", "盒马", "永辉", "沃尔玛",
        "山姆", "拼多多", "小米", "华为", "苹果", "比亚迪",
        "Starbucks", "McDonald's", "Uber", "Amazon"
    ]

    /// Words that describe a kind of spending, not a shop. A note made only of
    /// one of these ("午饭", "地铁") names no merchant.
    private static let genericWords = [
        "午饭", "早饭", "晚饭", "早餐", "午餐", "晚餐", "夜宵", "零食", "买菜", "水果",
        "打车", "地铁", "公交", "加油", "停车", "房租", "水费", "电费", "燃气",
        "话费", "流量", "购物", "超市", "便利店", "快递", "电影", "健身", "理发",
        "工资", "奖金", "报销", "转账", "还款", "信用卡", "保险", "学费", "书", "药"
    ]

    /// Payment platforms that also act as the merchant of record. A store name
    /// behind the platform ("美团-张亮麻辣烫") is a branch detail: the money
    /// went to the platform, and the user reads it as "美团".
    /// Longest token first so "美团外卖" wins over "美团".
    private static let platforms: [(token: String, name: String)] = [
        ("美团外卖", "美团"), ("美团", "美团"),
        ("饿了么", "饿了么"),
        ("支付宝", "支付宝"), ("微信支付", "微信支付"), ("微信", "微信"),
        ("淘宝", "淘宝"), ("天猫", "天猫"), ("京东", "京东"), ("拼多多", "拼多多"),
        ("抖音", "抖音"), ("云闪付", "云闪付"),
        ("Starbucks", "星巴克"), ("Amazon", "Amazon"), ("Uber", "Uber")
    ]

    /// Company and store suffixes that never distinguish two merchants.
    /// Ordered longest first; single-character "店" is deliberately absent so
    /// "便利店" does not become "便利".
    private static let storeSuffixes = [
        "股份有限公司", "有限责任公司", "有限公司", "分公司",
        "连锁店", "旗舰店", "专卖店", "专营店", "加盟店",
        "餐饮管理", "餐饮"
    ]

    // MARK: - Public rules

    /// Normalises a merchant name. Returns `nil` when nothing nameable is left
    /// (empty input, pure punctuation, or a pure number).
    static func normalize(
        _ raw: String?,
        aliases: MerchantAliasTable = .default
    ) -> MerchantIdentity? {
        guard let surface = surfaceForm(raw) else { return nil }
        if let platform = platformIdentity(in: surface) { return platform }

        let body = stripStoreDetail(surface)
        guard let normalizedKey = key(body) else { return nil }
        let canonical = aliases.aliases[normalizedKey] ?? normalizedKey
        return MerchantIdentity(name: aliases.displayNames[canonical] ?? body, key: canonical)
    }

    /// Merchant for a transaction note — what entry writes and what the
    /// backfill migration derives from old rows.
    ///
    /// A note that mentions a known brand yields that brand ("美团外卖 35" →
    /// 美团). A note that is *only* a name yields that name ("张亮麻辣烫"), but
    /// a note carrying numbers or a generic word ("午饭 35", "地铁") yields
    /// nothing: guessing there would invent merchants out of the whole note.
    static func derive(
        fromNote note: String?,
        aliases: MerchantAliasTable = .default
    ) -> MerchantIdentity? {
        guard let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        if let brand = knownBrand(in: trimmed) {
            return normalize(brand, aliases: aliases)
        }
        guard !trimmed.contains(where: \.isNumber),
              trimmed.count <= 20,
              !genericWords.contains(where: { trimmed.localizedCaseInsensitiveContains($0) })
        else { return nil }
        return normalize(trimmed, aliases: aliases)
    }

    /// Grouping key on its own. `nil` for empty and purely numeric input.
    static func key(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let folded = halfWidth(raw).lowercased()
        let kept = folded.unicodeScalars.filter { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
                && !CharacterSet.punctuationCharacters.contains(scalar)
                && !CharacterSet.symbols.contains(scalar)
        }
        var key = String()
        key.unicodeScalars.append(contentsOf: kept)
        guard !key.isEmpty, key.count <= maxLength else { return nil }
        // A shop number is not a merchant: "12345" would merge unrelated shops.
        guard key.contains(where: { !$0.isNumber }) else { return nil }
        return key
    }

    /// Spelling to show for a stored key.
    static func displayName(forKey key: String, aliases: MerchantAliasTable = .default) -> String {
        aliases.displayNames[aliases.aliases[key] ?? key] ?? key
    }

    // MARK: - Internals

    /// Trimmed, half-width form. `nil` when there is nothing left to name.
    private static func surfaceForm(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "-–—·・|、,，/\\:：;；~～"))
        let trimmed = halfWidth(raw)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: separators)
        guard !trimmed.isEmpty, trimmed.count <= maxLength else { return nil }
        return trimmed
    }

    /// Full-width letters, digits and punctuation folded to ASCII. Receipts
    /// mix both widths for the same shop.
    private static func halfWidth(_ text: String) -> String {
        var out = String()
        out.unicodeScalars.reserveCapacity(text.unicodeScalars.count)
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0xFF01...0xFF5E:
                // Offset of the full-width block from ASCII.
                out.unicodeScalars.append(Unicode.Scalar(scalar.value - 0xFEE0) ?? scalar)
            case 0x3000:
                out.append(" ")
            case 0x00B7, 0x30FB, 0x2022:
                // Middot bullets are separators, not part of a name.
                out.append("-")
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    /// Platform of record. The token has to be the whole string or be followed
    /// by a separator, so "京东健康" stays its own merchant while
    /// "美团-张亮麻辣烫" becomes 美团.
    private static func platformIdentity(in surface: String) -> MerchantIdentity? {
        let lowered = surface.lowercased()
        for platform in platforms.sorted(by: { $0.token.count > $1.token.count }) {
            let token = platform.token.lowercased()
            guard lowered.hasPrefix(token) else { continue }
            let rest = lowered.dropFirst(token.count)
            let boundary = rest.isEmpty
                || rest.first.map { !$0.isLetter && !$0.isNumber } == true
            guard boundary else { continue }
            let key = MerchantNormalizer.key(platform.name) ?? platform.name
            return MerchantIdentity(name: platform.name, key: key)
        }
        return nil
    }

    /// Drops branch markers and company suffixes: "张亮麻辣烫（望京店）有限公司"
    /// → "张亮麻辣烫".
    private static func stripStoreDetail(_ text: String) -> String {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "-–—·・|、,，/\\:：;；"))
        var body = text
        // Bracketed branch qualifiers: "（望京店）", "(No.12)". Removed
        // wherever they appear, since they qualify a shop rather than name it.
        body = body.replacingOccurrences(
            of: #"\s*[（(][^）)]*[)）]"#, with: "", options: .regularExpression)
        // Trailing store code: "-001", "#12", "|3". Skipped when what remains
        // would be a bare number, so a code never eats the whole name.
        if let range = body.range(of: #"\s*[-–—#·|]\s*[A-Za-z]?\d{1,6}$"#,
                                  options: .regularExpression) {
            let head = String(body[..<range.lowerBound])
            if head.contains(where: { !$0.isNumber && !$0.isWhitespace }) { body = head }
        }
        for suffix in storeSuffixes where body.count > suffix.count {
            if body.lowercased().hasSuffix(suffix.lowercased()) {
                body = String(body.dropLast(suffix.count))
            }
        }
        return body.trimmingCharacters(in: separators)
    }

    private static func knownBrand(in text: String) -> String? {
        knownBrands.first { text.localizedCaseInsensitiveContains($0) }
    }
}
