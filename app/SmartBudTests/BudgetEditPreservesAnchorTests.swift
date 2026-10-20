//
//  BudgetEditPreservesAnchorTests.swift
//  SmartBudTests
//
//  Editing a budget's amount used to recompute `startDate` from today, which
//  silently moved the period. Only a period-type change may re-anchor.
//

import Testing
import Foundation

@Suite("BudgetAnchor")
struct BudgetEditPreservesAnchorTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("Editing the amount keeps the stored start date")
    func keepsAnchor() {
        let original = date(2026, 2, 15)
        let computed = date(2026, 3, 15)
        let result = BudgetAnchor.startDate(original: original, oldType: 3,
                                            newType: 3, computed: computed)
        #expect(result == original)
    }

    @Test("Changing the period type re-anchors to the new pick")
    func reanchorsOnTypeChange() {
        let original = date(2026, 2, 15)
        let computed = date(2026, 3, 1)
        let result = BudgetAnchor.startDate(original: original, oldType: 3,
                                            newType: 2, computed: computed)
        #expect(result == computed)
    }

    @Test("A new budget uses the computed date")
    func newBudget() {
        let computed = date(2026, 3, 1)
        #expect(BudgetAnchor.startDate(original: nil, oldType: 3,
                                       newType: 3, computed: computed) == computed)
    }
}
