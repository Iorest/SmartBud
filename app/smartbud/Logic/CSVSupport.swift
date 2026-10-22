//
//  CSVSupport.swift
//  smartbud
//
//  RFC 4180 field escaping, kept separate from the exporter so it can be
//  unit tested without a SwiftData store.
//

import Foundation

enum CSVSupport {
    /// Quotes a field only when it needs it (comma, quote, CR or LF) and
    /// doubles any embedded quotes. Plain values stay unquoted so a
    /// hand-edited file stays readable.
    static func field(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"")
                || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func row(_ fields: [String]) -> String {
        fields.map(field).joined(separator: ",")
    }
}
