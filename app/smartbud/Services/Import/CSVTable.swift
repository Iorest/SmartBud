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
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var line = 1
        // Swift treats "\r\n" as one grapheme cluster, so normalise line
        // endings before iterating; quoted newlines become plain "\n".
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var iterator = normalized.makeIterator()
        var pending: Character?

        func finishField() {
            row.append(field)
            field = ""
        }

        func finishRow() {
            finishField()
            // Ignore the empty row produced by a trailing newline.
            if !(row.count == 1 && row[0].isEmpty) {
                rows.append(row)
            }
            row = []
        }

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

            if inQuotes {
                if character == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            pending = next
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    if character == "\n" { line += 1 }
                    field.append(character)
                }
                continue
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
        }

        if inQuotes {
            throw CSVError.unclosedQuote(line: line)
        }
        if !field.isEmpty || !row.isEmpty {
            finishRow()
        }
        guard !rows.isEmpty else { throw CSVError.empty }
        self.rows = rows
    }

    var columnCounts: Set<Int> { Set(rows.map(\.count)) }
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
