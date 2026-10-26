//
//  ImportAmount.swift
//  smartbud
//
//  CSV imports come from banks and payment apps, so the amount cell is rarely
//  a bare number: "$1,200.00", "12.50元", "（1,200.00）". Kept pure so the
//  wizard's validation and the write step share one parser.
//

import Foundation

enum ImportAmount {
    /// Parses one amount cell. Returns nil when nothing numeric is left, and
    /// refuses values the entry form would not accept either.
    static func parse(_ raw: String) -> Double? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Accounting style: (1,200.00) means -1200.
        var negative = false
        if text.hasPrefix("("), text.hasSuffix(")") {
            negative = true
            text = String(text.dropFirst().dropLast())
        }

        text = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        // Scientific notation ("1e400") is not an amount, and stripping the
        // "e" would silently turn it into 1400.
        if text.range(of: #"\d[eE][+-]?\d"#, options: .regularExpression) != nil {
            return nil
        }
        text = text.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: " ", with: "")

        // Keep digits, separators and a sign; drop currency symbols and units.
        text = String(text.filter { $0.isASCII && ($0.isNumber || $0 == "." || $0 == "-" || $0 == "+") })
        guard !text.isEmpty, text != "-", text != "+", text != "." else { return nil }
        guard let value = Double(text), value.isFinite else { return nil }

        let magnitude = abs(value)
        guard magnitude <= Money.maxAmount else { return nil }
        // "(0)" is still zero; the caller decides whether zero is acceptable.
        return negative ? -magnitude : value
    }
}
