//
//  BudgetUITests.swift
//  SmartBudUITests
//
//  Flow D — a category budget is created through the real wizard, then spent
//  against. The remaining figure is a magnitude (`Money.format`), so
//  overspending is asserted as the amount plus the "over" status word beside
//  it — asserting only the number would pass for a budget that is simply
//  small.
//

import XCTest

@MainActor
final class BudgetUITests: SmartBudUITestCase {

    func testD9_categoryBudget_remainingFallsThenGoesOver() throws {
        let app = launch()
        createCategoryBudget(category: "餐饮", amount: "100", in: app)

        // A fresh budget has spent nothing.
        assertAmount(require(app, AccessibilityID.budgetRowRemaining),
                     equals: 100, "Budget remaining before any spend")

        addExpense(category: "餐饮", amount: "30", in: app)
        select(.budget, in: app)
        require(app, AccessibilityID.budgetRow)
        assertAmount(require(app, AccessibilityID.budgetRowRemaining),
                     equals: 70, "Budget remaining after 30 of 100")

        addExpense(category: "餐饮", amount: "80", in: app)
        select(.budget, in: app)
        require(app, AccessibilityID.budgetRow)
        assertAmount(require(app, AccessibilityID.budgetRowRemaining),
                     equals: 10, "Budget overspend amount")
        // The status word is what makes 10 mean "10 over" instead of "10 left".
        XCTAssertTrue(app.staticTexts["over"].waitForExistence(timeout: 10),
                      "The overspent budget does not say \"over\".\n\(app.debugDescription)")
    }

    func testD9_budgetIgnoresOtherCategories() throws {
        let app = launch()
        createCategoryBudget(category: "餐饮", amount: "100", in: app)

        addExpense(category: "交通", amount: "40", in: app)
        select(.budget, in: app)
        require(app, AccessibilityID.budgetRow)
        assertAmount(require(app, AccessibilityID.budgetRowRemaining),
                     equals: 100, "Remaining after an unrelated category")

        // The spend is still real money, so the ledger totals move.
        select(.insights, in: app)
        assertAmount(require(app, AccessibilityID.insightsExpenseCard),
                     equals: 40, "Insights expenses")
    }

    // MARK: - Helpers

    /// Budget tab → New Budget → Category Budget → category → Continue →
    /// amount pad → save.
    private func createCategoryBudget(category: String, amount: String,
                                      in app: XCUIApplication,
                                      file: StaticString = #filePath, line: UInt = #line) {
        select(.budget, in: app)
        require(app, AccessibilityID.budgetAddButton, file: file, line: line).tap()

        // "Category Budget" is segment 1 of the type picker.
        let typePicker = app.segmentedControls
            .matching(identifier: AccessibilityID.budgetCreateTypePicker).firstMatch
        let control = typePicker.exists ? typePicker : app.segmentedControls.firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 10),
                      "The budget type picker is missing.\n\(app.debugDescription)",
                      file: file, line: line)
        control.buttons.element(boundBy: 1).tap()

        let categoryPicker = require(app, AccessibilityID.budgetCreateCategoryPicker,
                                     file: file, line: line)
        categoryPicker.tap()
        let option = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", category)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10),
                      "No category option \"\(category)\".\n\(app.debugDescription)",
                      file: file, line: line)
        option.tap()

        require(app, AccessibilityID.budgetCreateContinue, file: file, line: line).tap()

        // Amount page: the same number pad as the entry form.
        require(app, AccessibilityID.padDigit(0), file: file, line: line)
        enterAmount(amount, in: app)
        saveEntry(in: app)

        // Back on the budget list with the new card.
        let remaining = require(app, AccessibilityID.budgetRowRemaining,
                                timeout: 20, file: file, line: line)
        XCTAssertTrue(remaining.exists, "The new budget card never appeared.",
                      file: file, line: line)
    }

    private func addExpense(category: String, amount: String, in app: XCUIApplication) {
        select(.log, in: app)
        openEntryForm(in: app)
        enterAmount(amount, in: app)
        selectCategory(category, in: app)
        saveEntry(in: app)
    }
}
