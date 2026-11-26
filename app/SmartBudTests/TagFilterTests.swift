//
//  TagFilterTests.swift
//  SmartBudTests
//
//  Pure label rules: multi-select intersection and backup-safe normalisation.
//  Foundation-only so the Linux harness runs these too.
//

import Testing
import Foundation

@Suite("Tag filtering")
struct TagFilterTests {
    @Test("Multi-select requires every selected label")
    func intersection() {
        let travel = UUID(), food = UUID(), work = UUID()
        #expect(TagFilter.matches(tagIDs: [travel, food], selected: [travel, food]))
        #expect(!TagFilter.matches(tagIDs: [food, work], selected: [travel, food]))
        #expect(!TagFilter.matches(tagIDs: nil, selected: [travel]))
    }

    @Test("An empty selection keeps every row, including untagged legacy rows")
    func noSelection() {
        #expect(TagFilter.matches(tagIDs: [UUID()], selected: []))
        #expect(TagFilter.matches(tagIDs: nil, selected: []))
    }

    @Test("Tag selection composes with expense and day criteria")
    func stacksWithOtherFilters() {
        struct Row {
            let tags: [UUID]
            let expense: Bool
            let day: Int
        }
        let food = UUID(), travel = UUID()
        let rows = [
            Row(tags: [food, travel], expense: true, day: 1),
            Row(tags: [food], expense: false, day: 1),
            Row(tags: [food, travel], expense: true, day: 2),
            Row(tags: [travel], expense: true, day: 1)
        ]
        // The same successive-filter chain LogView.visibleTransactions uses.
        let matched = rows.filter {
            $0.expense && $0.day == 1
                && TagFilter.matches(tagIDs: $0.tags, selected: [food, travel])
        }
        #expect(matched.count == 1)
    }

    @Test("Normalisation trims, deduplicates case-insensitively and keeps order")
    func normalise() {
        let tags = TagFilter.normalize([
            TagModel(name: "  Travel  "),
            TagModel(name: "travel"),
            TagModel(name: "Food")
        ])
        #expect(tags.count == 2)
        #expect(tags[0].name == "Travel")
        #expect(tags[0].order == 0)
        #expect(tags[1].name == "Food")
        #expect(tags[1].order == 1)
        #expect(TagFilter.normalize([TagModel(name: "  ")]).isEmpty)
    }
}
