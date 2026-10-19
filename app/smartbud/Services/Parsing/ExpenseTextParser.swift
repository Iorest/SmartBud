//
//  ExpenseTextParser.swift
//  smartbud
//
//  Rule-based natural-language expense parsing, ported from SmartExpense's
//  TextParser and adapted to SmartBud's CategoryModel. Produces the same
//  `ParsedExpense` shape that OCR and (optionally) the LLM fall back to.
//

import Foundation
import NaturalLanguage

/// Structured parse output shared by text, speech, OCR and LLM parsing.
struct ParsedExpense {
    var amount: Decimal
    var isIncome: Bool
    var merchant: String?
    /// Category "bucket" name (e.g. "餐饮"). Resolve to a real `CategoryModel`
    /// with `ExpenseTextParser.resolveCategory(_:from:)`.
    var categoryHint: String?
}

enum ExpenseTextParser {

    /// Bucket → words that appear in a phrase. Kept in Chinese because the
    /// source phrases are Chinese; English phrases fall through to NLTagger.
    private static let bucketKeywords: [String: [String]] = [
        "餐饮": ["餐", "饭", "外卖", "食堂", "小吃", "麻辣烫", "火锅", "烧烤", "面", "粉", "菜", "餐厅", "饭店", "料理"],
        "交通": ["车", "打车", "滴滴", "地铁", "公交", "加油", "停车", "高速", "高铁", "火车", "机票", "飞机", "自行车"],
        "购物": ["买", "淘宝", "京东", "拼多多", "超市", "便利店", "衣服", "鞋", "包", "化妆品"],
        "咖啡": ["咖啡", "星巴克", "瑞幸", "拿铁", "美式", "奶茶", "茶", "饮料", "冰淇淋"],
        "娱乐": ["电影", "ktv", "游戏", "旅游", "门票", "唱歌", "运动", "健身", "游泳"],
        "通讯": ["话费", "流量", "宽带", "充值"],
        "教育": ["书", "课程", "培训", "学费", "考试", "教材"],
        "医疗": ["药", "医院", "挂号", "检查", "体检", "看病", "诊所"],
        "工资": ["工资", "薪水"],
        "奖金": ["奖金", "奖励", "季度奖", "年终奖"],
    ]

    /// Bucket → tokens matched against `CategoryModel.name` (any language).
    private static let bucketSynonyms: [String: [String]] = [
        "餐饮": ["餐饮", "餐", "饭", "食", "food", "dining", "restaurant", "meal"],
        "交通": ["交通", "出行", "transport", "travel", "taxi"],
        "购物": ["购物", "买", "shopping", "shop"],
        "咖啡": ["咖啡", "饮料", "奶茶", "drink", "coffee", "tea"],
        "娱乐": ["娱乐", "entertainment", "movie", "game"],
        "通讯": ["通讯", "话费", "phone", "communication", "mobile"],
        "教育": ["教育", "education", "book", "course"],
        "医疗": ["医疗", "健康", "health", "medical", "pharmacy"],
        "工资": ["工资", "薪水", "salary", "paycheck", "income"],
        "奖金": ["奖金", "bonus"],
    ]

    // MARK: - Parse

    static func parse(_ text: String) -> ParsedExpense? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let amount = extractAmount(from: trimmed), amount > 0 else {
            return nil
        }
        let isIncome = detectIncome(in: trimmed)
        return ParsedExpense(
            amount: amount,
            isIncome: isIncome,
            merchant: extractMerchant(from: trimmed),
            categoryHint: matchBucket(in: trimmed)
        )
    }

    /// First amount found: ¥/￥ prefix, "N 元", or labelled amounts.
    static func extractAmount(from text: String) -> Decimal? {
        let patterns = [
            "¥\\s*(\\d+\\.?\\d*)",
            "￥\\s*(\\d+\\.?\\d*)",
            "(\\d+\\.?\\d*)\\s*元",
            "金额[:：]?\\s*(\\d+\\.?\\d*)",
            "消费[:：]?\\s*(\\d+\\.?\\d*)",
            "支付[:：]?\\s*(\\d+\\.?\\d*)",
            "花费[:：]?\\s*(\\d+\\.?\\d*)",
            "扣款[:：]?\\s*(\\d+\\.?\\d*)",
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text),
               let value = Decimal(string: String(text[range])) {
                return value
            }
        }
        if let range = text.range(of: "\\d+\\.?\\d*", options: .regularExpression),
           let value = Decimal(string: String(text[range])) {
            return value
        }
        return nil
    }

    /// Resolves a bucket hint against the user's actual categories.
    static func resolveCategory(_ hint: String?, from categories: [CategoryModel]) -> CategoryModel? {
        guard let hint, let tokens = bucketSynonyms[hint] else { return nil }
        let lowered = categories.map { ($0, $0.name.lowercased()) }
        for (category, name) in lowered where tokens.contains(where: { name.contains($0) }) {
            return category
        }
        return nil
    }

    // MARK: - Internals

    private static func detectIncome(in text: String) -> Bool {
        let keywords = ["收入", "工资", "奖金", "到账", "转入", "红包", "报销", "退款"]
        return keywords.contains { text.contains($0) }
    }

    private static func matchBucket(in text: String) -> String? {
        let lowered = text.lowercased()
        for (bucket, words) in bucketKeywords
        where words.contains(where: { lowered.contains($0.lowercased()) }) {
            return bucket
        }
        // NLTagger organization names as a second chance (e.g. brand phrases).
        for name in organizationNames(in: text) {
            let loweredName = name.lowercased()
            for (bucket, words) in bucketKeywords
            where words.contains(where: { loweredName.contains($0.lowercased()) }) {
                return bucket
            }
        }
        return nil
    }

    private static func extractMerchant(from text: String) -> String? {
        let known = [
            "星巴克", "瑞幸", "美团", "饿了么", "滴滴", "京东", "淘宝",
            "天猫", "麦当劳", "肯德基", "盒马", "永辉", "沃尔玛",
            "山姆", "拼多多", "小米", "华为", "苹果", "比亚迪",
            "Starbucks", "McDonald's", "Uber", "Amazon",
        ]
        if let merchant = known.first(where: { text.localizedCaseInsensitiveContains($0) }) {
            return merchant
        }
        return organizationNames(in: text).first
    }

    private static func organizationNames(in text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var names: [String] = []
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .joinNames]
        ) { tag, range in
            if tag == .organizationName {
                let name = String(text[range])
                let excluded = ["支付宝", "微信", "银联", "平台", "公司"]
                if name.count >= 2, name.count <= 12, !excluded.contains(name) {
                    names.append(name)
                }
            }
            return true
        }
        return names
    }
}
