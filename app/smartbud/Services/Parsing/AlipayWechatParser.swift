//
//  AlipayWechatParser.swift
//  smartbud
//
//  Targeted parser for Alipay / WeChat Pay receipt screenshots. Detects the
//  platform, extracts amount + merchant, and reports a confidence score;
//  callers fall back to generic OCR when confidence < 0.7.
//

import Foundation

struct AlipayWechatParser {

    enum Platform: String {
        case alipay = "Alipay"
        case wechat = "WeChat Pay"
    }

    struct ParseResult {
        let amount: Decimal
        let merchant: String?
        let platform: Platform
        let confidence: Double
    }

    private static let alipayKeywords: Set<String> = [
        "支付宝", "余额宝", "花呗", "借呗", "收款方", "付款方", "账单详情"
    ]
    private static let wechatKeywords: Set<String> = [
        "微信支付", "零钱", "微信转账", "收款方备注", "当前状态", "支付凭证", "转账说明"
    ]

    /// Labeled amounts first: a receipt also prints "余额 ¥1,234.56" above the
    /// real total, and matching the bare symbol first reported the balance as
    /// the payment. Thousands separators are part of the number.
    private static let amountPatterns = [
        #"(?:实付|支付金额|付款金额|收款金额|金额|支付|总计|合计)\s*[:：]?\s*(?:¥|￥|RMB)?\s*(\d[\d,]*(?:\.\d{1,2})?)"#,
        #"(?:¥|￥)\s*(\d[\d,]*(?:\.\d{1,2})?)"#
    ]

    /// A line about the wallet balance, a coupon or a discount is not the
    /// amount the user paid.
    private static let ignoredAmountWords = ["余额", "优惠", "立减", "红包", "折扣"]

    private static let merchantPatterns = [
        #"收款方\s*[:：]?\s*(.+?)(?:\s|$)"#,
        #"商户\s*[:：]?\s*(.+?)(?:\s|$)"#,
        #"付款给\s*[:：]?\s*(.+?)(?:\s|$)"#,
        #"商品说明\s*[:：]?\s*(.+?)(?:\s|$)"#
    ]

    func parse(lines: [String]) -> ParseResult? {
        let joined = lines.joined(separator: "\n")
        guard let platform = detectPlatform(in: joined) else { return nil }

        let amount = extractAmount(from: joined)
        let merchant = extractMerchant(from: joined)
        let confidence = calculateConfidence(
            hasAmount: amount != nil,
            hasMerchant: merchant != nil,
            lineCount: lines.count
        )

        guard let amount, confidence >= 0.7 else { return nil }
        return ParseResult(amount: amount, merchant: merchant, platform: platform, confidence: confidence)
    }

    private func detectPlatform(in text: String) -> Platform? {
        let alipayScore = Self.alipayKeywords.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
        let wechatScore = Self.wechatKeywords.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
        if alipayScore > wechatScore && alipayScore >= 1 { return .alipay }
        if wechatScore > alipayScore && wechatScore >= 1 { return .wechat }
        return nil
    }

    private func extractAmount(from text: String) -> Decimal? {
        let lines = text.components(separatedBy: .newlines)
        for pattern in Self.amountPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for line in lines {
                if Self.ignoredAmountWords.contains(where: { line.contains($0) }) { continue }
                let range = NSRange(line.startIndex..., in: line)
                guard let match = regex.firstMatch(in: line, range: range),
                      match.range(at: 1).location != NSNotFound,
                      let swiftRange = Range(match.range(at: 1), in: line) else { continue }
                let raw = String(line[swiftRange]).replacingOccurrences(of: ",", with: "")
                if let value = Decimal(string: raw), value > 0, value <= Decimal(Money.maxAmount) {
                    return value
                }
            }
        }
        return nil
    }

    private func extractMerchant(from text: String) -> String? {
        for pattern in Self.merchantPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               match.range(at: 1).location != NSNotFound,
               let swiftRange = Range(match.range(at: 1), in: text) {
                let merchant = String(text[swiftRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !merchant.isEmpty && merchant.count < 50 {
                    return merchant
                }
            }
        }
        return nil
    }

    private func calculateConfidence(hasAmount: Bool, hasMerchant: Bool, lineCount: Int) -> Double {
        var score = 0.4
        if hasAmount { score += 0.4 }
        if hasMerchant { score += 0.2 }
        if (3...30).contains(lineCount) { score += 0.1 }
        return min(score, 1.0)
    }
}
