//
//  LocalizationCoverageTests.swift
//  SmartBudTests
//
//  Missing translation keys fail silently: `String.appLocalized` falls back to
//  the key itself, so Chinese users see English. This test scans the source for
//  every literal key and checks it against the String Catalog, and checks that
//  each catalog entry really has all three languages.
//
//  It reads the source tree through `#filePath`, so it runs from the checkout
//  (local machine or CI) rather than from the app bundle.
//

import Testing
import Foundation

@Suite("Localization coverage")
struct LocalizationCoverageTests {

    /// …/app/SmartBudTests/LocalizationCoverageTests.swift → …/app
    private var appRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // SmartBudTests
            .deletingLastPathComponent()   // app
    }

    private var catalog: [String: [String: Any]] {
        get throws {
            let url = appRoot.appendingPathComponent("Localizations/Localizable.xcstrings")
            let data = try Data(contentsOf: url)
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return root?["strings"] as? [String: [String: Any]] ?? [:]
        }
    }

    private var sourceFiles: [URL] {
        let roots = ["smartbud", "ExpenditureWidget"]
        var files: [URL] = []
        for root in roots {
            let base = appRoot.appendingPathComponent(root)
            guard let walker = FileManager.default.enumerator(
                at: base, includingPropertiesForKeys: nil
            ) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                files.append(url)
            }
        }
        return files
    }

    /// Literal arguments of `String.appLocalized("…")` / `appFormatted("…")`.
    private func literalKeys(in source: String) -> [String] {
        let pattern = #"String\.app(?:Localized|Formatted)\(\s*"((?:[^"\\]|\\.)*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(source.startIndex..., in: source)
        return regex.matches(in: source, range: range).compactMap { match in
            guard let captured = Range(match.range(at: 1), in: source) else { return nil }
            return unescape(String(source[captured]))
        }
    }

    private func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    /// Values of `static let xxx = "key"` in SettingsKeys.swift.
    private func constantKeys() -> [String] {
        let url = appRoot.appendingPathComponent("smartbud/Utilities/SettingsKeys.swift")
        guard let source = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let pattern = #"static let \w+ = "([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(source.startIndex..., in: source)
        return regex.matches(in: source, range: range).compactMap { match in
            guard let captured = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[captured])
        }
    }

    @Test("Every literal key exists in the String Catalog")
    func everyKeyIsCatalogued() throws {
        let keys = try catalog

        // Fragments of multi-line concatenated strings and doc-comment
        // examples; a fragment counts as covered when a real key starts with it.
        let allowlist: Set<String> = ["key", "literal"]

        var missing: [String] = []
        for file in sourceFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            for literal in literalKeys(in: source) {
                if allowlist.contains(literal) { continue }
                if keys[literal] != nil { continue }
                if keys.keys.contains(where: { $0.hasPrefix(literal) }) { continue }
                missing.append("\(literal) — \(file.lastPathComponent)")
            }
        }

        for key in constantKeys() where keys[key] == nil {
            missing.append("\(key) — SettingsKeys.swift")
        }

        #expect(missing.isEmpty, "Missing translations:\n\(missing.joined(separator: "\n"))")
    }

    @Test("Every entry has English, Simplified and Traditional Chinese")
    func everyEntryHasThreeLanguages() throws {
        var incomplete: [String] = []
        for (key, entry) in try catalog {
            // Xcode writes an entry for the empty string with
            // `shouldTranslate: false`; there is nothing to translate.
            if key.isEmpty || (entry["shouldTranslate"] as? Bool) == false { continue }
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            for language in ["en", "zh-Hans", "zh-Hant"] {
                guard let unit = localizations[language] as? [String: Any],
                      let stringUnit = unit["stringUnit"] as? [String: Any],
                      let value = stringUnit["value"] as? String,
                      !value.isEmpty else {
                    incomplete.append("\(key) [\(language)]")
                    continue
                }
            }
        }
        #expect(incomplete.isEmpty, "Incomplete translations:\n\(incomplete.joined(separator: "\n"))")
    }
}
