//
//  CSVTable.swift
//  smartbud
//
//  RFC 4180 CSV parsing. The previous importer split on commas and newlines,
//  which broke on quoted fields and crashed later when a row was short.
//

import Foundation

struct CSVTable: Equatable {
    private(set) var rows: [[String]]

    /// Parses quoted fields (`"a,b"`), escaped quotes (`""`), CRLF, bare CR
    /// and a trailing newline.
    init(text: String) throws {
        // Swift treats "\r\n" as one grapheme cluster, so normalise line
        // endings before iterating; quoted newlines become plain "\n".
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var parser = CSVParser()
        rows = try parser.parse(normalized)
    }

    var columnCounts: Set<Int> { Set(rows.map(\.count)) }
}

/// Character-level RFC 4180 state machine. Split out of `CSVTable.init` so the
/// quote handling and the row bookkeeping can be read on their own.
private struct CSVParser {
    private var rows: [[String]] = []
    private var row: [String] = []
    private var field = ""
    private var inQuotes = false
    private var line = 1

    mutating func parse(_ text: String) throws -> [[String]] {
        var iterator = text.makeIterator()
        var pending: Character?

        while true {
            let character: Character
            if let ready = pending {
                character = ready
                pending = nil
            } else if let next = iterator.next() {
                character = next
            } else {
                break
            }
            pending = try consume(character, lookingAt: &iterator)
        }

        if inQuotes {
            throw CSVError.unclosedQuote(line: line)
        }
        if !field.isEmpty || !row.isEmpty {
            finishRow()
        }
        guard !rows.isEmpty else { throw CSVError.empty }
        return rows
    }

    /// Consumes one character. Returns a character that was read ahead and must
    /// be handled next (closing quote or escaped quote).
    private mutating func consume(_ character: Character,
                                  lookingAt iterator: inout String.Iterator) throws -> Character? {
        if inQuotes {
            if character == "\"" {
                guard let next = iterator.next() else {
                    inQuotes = false
                    return nil
                }
                if next == "\"" {
                    field.append("\"")
                    return nil
                }
                inQuotes = false
                return next
            }
            if character == "\n" { line += 1 }
            field.append(character)
            return nil
        }

        switch character {
        case "\"":
            if field.isEmpty {
                inQuotes = true
            } else {
                field.append(character)
            }
        case ",":
            finishField()
        case "\n":
            finishRow()
            line += 1
        default:
            field.append(character)
        }
        return nil
    }

    private mutating func finishField() {
        row.append(field)
        field = ""
    }

    private mutating func finishRow() {
        finishField()
        // Ignore the empty row produced by a trailing newline.
        if !(row.count == 1 && row[0].isEmpty) {
            rows.append(row)
        }
        row = []
    }
}

enum CSVError: LocalizedError, Equatable {
    case empty
    case unclosedQuote(line: Int)

    /// Developer-facing; the import UI maps these cases to localized copy.
    var errorDescription: String? {
        switch self {
        case .empty:
            return "The file is empty."
        case .unclosedQuote(let line):
            return "Unclosed quote on line \(line)."
        }
    }
}
