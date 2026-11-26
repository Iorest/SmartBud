//
//  TagFilter.swift
//  smartbud
//
//  Tags and the pure matching rule used by the log. Kept Foundation-only so
//  the rule can be compiled and tested without SwiftData / SwiftUI.
//
//  `TagModel` is a Codable value type rather than a SwiftData entity: adding
//  an entity to the app/widget shared schema reproducibly breaks XCUITest's
//  launch handshake (see `InstallmentPlanStore` in Data/Helper.swift). Tags
//  live as JSON on their book, and transactions carry an array of tag ids —
//  that is a many-to-many relation without a join table or a new record type.
//

import Foundation

struct TagModel: Codable, Equatable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    /// Hex colour string, matching `CategoryModel.colour`.
    var color: String = "#5E9EFF"
    var order: Int = 0
    /// Ledger this tag belongs to. Nil only on rows read from an old backup.
    var bookID: UUID? = nil

    init(id: UUID = UUID(), name: String = "", color: String = "#5E9EFF",
         order: Int = 0, bookID: UUID? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.order = order
        self.bookID = bookID
    }

    /// Localised display is handled by the caller; the stored name is never
    /// translated so a backup keeps the user's own labels.
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TagFilter {
    /// Multi-select uses intersection semantics: a row must carry **all**
    /// selected tags. An empty selection is "no tag filter" and keeps every
    /// row, including legacy rows with no tag ids at all.
    static func matches(tagIDs: [UUID]?, selected: Set<UUID>) -> Bool {
        guard !selected.isEmpty else { return true }
        return selected.isSubset(of: Set(tagIDs ?? []))
    }

    /// Trims names, drops blanks and duplicates (case-insensitive, first
    /// spelling wins), then assigns a stable display order. Called on every
    /// edit so ids from existing transactions never need rewriting.
    static func normalize(_ tags: [TagModel]) -> [TagModel] {
        var seen: Set<String> = []
        var result: [TagModel] = []
        for tag in tags {
            let key = tag.trimmedName.lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            var copy = tag
            copy.name = tag.trimmedName
            copy.order = result.count
            result.append(copy)
        }
        return result
    }
}
