//
//  AccountTransferUITests.swift
//  SmartBudUITests
//
//  Flows C (transfers) and E (accounts). Both are balance questions, so the
//  assertions read the account rows and the total row — not "the screen
//  opened". `Money.format` renders a magnitude, so a negative balance is
//  asserted as its absolute value plus the colour-free total.
//

import XCTest

@MainActor
final class AccountTransferUITests: SmartBudUITestCase {

    // MARK: - E10. A new account with an opening balance lands in the list and the total

    func testE10_newAccountWithOpeningBalance_listsAndTotals() throws {
        let app = launch()
        openAccountList(in: app)
        assertAmount(require(app, AccessibilityID.accountsTotal), equals: 0, "Opening total")

        createAccount(named: "储蓄卡", opening: "1000", in: app)

        let row = accountRow(named: "储蓄卡", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10),
                      "The new account never appeared.\n\(app.debugDescription)")
        assertAmount(row, equals: 1000, "New account balance")
        assertAmount(require(app, AccessibilityID.accountsTotal), equals: 1000, "Total after adding")
    }

    // MARK: - C7. A same-currency transfer moves money and never counts as spend

    func testC7_sameCurrencyTransfer_movesBalancesOnly() throws {
        let app = launch()
        openAccountList(in: app)
        createAccount(named: "来源", opening: "1000", in: app)
        createAccount(named: "去向", opening: "0", in: app)

        transfer(from: "来源", to: "去向", amount: "200", in: app)

        assertAmount(accountRow(named: "来源", in: app), equals: 800, "Source balance")
        assertAmount(accountRow(named: "去向", in: app), equals: 200, "Destination balance")
        // The total is unchanged: nothing left the user's own pockets.
        scrollToTop(in: app)
        assertAmount(require(app, AccessibilityID.accountsTotal), equals: 1000, "Total after transfer")

        // A transfer is not spend.
        select(.insights, in: app)
        assertAmount(require(app, AccessibilityID.insightsExpenseCard),
                     equals: 0, "Insights expenses after a transfer")
        assertAmount(require(app, AccessibilityID.insightsIncomeCard),
                     equals: 0, "Insights income after a transfer")
    }

    // MARK: - C8. Cross-currency transfer: the landed amount and the fee are both right

    func testC8_crossCurrencyTransferWithFee_booksFeeAsSpend() throws {
        let app = launch()
        openAccountList(in: app)

        // 现金 (USD, seeded) → 人民币 (CNY, seeded, rate 0.14 in the fixture).
        transfer(from: "现金", to: "人民币", amount: "100",
                 destinationAmount: "700", fee: "5", in: app)

        // The destination is denominated in CNY, so the landed amount is CNY
        // and the source pays the fee on top of the transfer.
        assertAmount(accountRow(named: "人民币", in: app), equals: 700, "Landed amount")
        assertAmount(accountRow(named: "现金", in: app), equals: 105, "Source out + fee")

        let transferRow = require(app, AccessibilityID.accountsTransferRow)
        XCTAssertTrue(transferRow.label.contains("100"),
                      "Transfer row lost the sent amount: \"\(transferRow.label)\"")
        XCTAssertTrue(transferRow.label.contains("700"),
                      "Transfer row lost the landed amount: \"\(transferRow.label)\"")

        // Only the fee is spend; the transferred principal is not.
        select(.insights, in: app)
        assertAmount(require(app, AccessibilityID.insightsExpenseCard),
                     equals: 5, "Insights expenses = fee only")
    }

    // MARK: - E11. Hiding an account takes it out of the total, and it can come back

    func testE11_hiddenAccount_leavesTotalAndReturns() throws {
        let app = launch()
        openAccountList(in: app)
        createAccount(named: "备用金", opening: "300", in: app)
        assertAmount(accountRow(named: "备用金", in: app), equals: 300, "Balance before hiding")

        swipeAction(on: accountRow(named: "备用金", in: app), titled: "Hide",
                    identifier: AccessibilityID.accountsRowHide, in: app)

        // Hidden: out of the total, out of the visible list.
        scrollToTop(in: app)
        assertAmount(require(app, AccessibilityID.accountsTotal), equals: 0, "Total after hiding")
        XCTAssertFalse(accountRow(named: "备用金", in: app).exists,
                       "The hidden account is still in the visible list.")

        // The hidden section is an expandable group, so nothing is lost.
        require(app, AccessibilityID.accountsHiddenToggle).tap()
        let restored = accountRow(named: "备用金", in: app)
        XCTAssertTrue(restored.waitForExistence(timeout: 10),
                      "The hidden account is not listed under Hidden.\n\(app.debugDescription)")
        assertAmount(restored, equals: 300, "Hidden account keeps its balance")
    }

    // MARK: - E11b. Archiving a non-zero balance asks first and says how much moves out

    func testE11_archiveNonZeroBalance_promptsThenMovesOutOfTotal() throws {
        let app = launch()
        openAccountList(in: app)
        createAccount(named: "旧卡", opening: "250", in: app)

        swipeAction(on: accountRow(named: "旧卡", in: app), titled: "Archive",
                    identifier: AccessibilityID.accountsRowArchive, in: app)

        // The balance is not zero, so the user is told what leaves the total
        // and has to confirm.
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10),
                      "Archiving a non-zero account did not ask.\n\(app.debugDescription)")
        XCTAssertTrue(alert.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "250")).firstMatch.exists,
            "The prompt does not state the leftover balance: \(alert.debugDescription)")
        alert.buttons["Archive"].firstMatch.tap()

        scrollToTop(in: app)
        assertAmount(require(app, AccessibilityID.accountsTotal), equals: 0, "Total after archiving")
        XCTAssertFalse(accountRow(named: "旧卡", in: app).exists,
                       "The archived account is still in the default list.")
    }

    // MARK: - Navigation

    private func openAccountList(in app: XCUIApplication) {
        select(.settings, in: app)
        tapSettingRow(AccessibilityID.settingsRow("accounts"), in: app)
        require(app, AccessibilityID.accountsAdd)
    }

    private func createAccount(named name: String, opening: String,
                               in app: XCUIApplication,
                               file: StaticString = #filePath, line: UInt = #line) {
        require(app, AccessibilityID.accountsAdd, file: file, line: line).tap()
        let nameField = require(app, AccessibilityID.accountName, file: file, line: line)
        nameField.tap()
        nameField.typeText(name)
        let balanceField = require(app, AccessibilityID.accountOpeningBalance, file: file, line: line)
        replaceText(in: balanceField, with: opening)
        require(app, AccessibilityID.accountSave, file: file, line: line).tap()
        // The sheet closes; the new row is the sync point.
        XCTAssertTrue(accountRow(named: name, in: app).waitForExistence(timeout: 15),
                      "Account \"\(name)\" was not created.\n\(app.debugDescription)",
                      file: file, line: line)
    }

    private func transfer(from: String, to: String, amount: String,
                          destinationAmount: String? = nil, fee: String? = nil,
                          in app: XCUIApplication,
                          file: StaticString = #filePath, line: UInt = #line) {
        require(app, AccessibilityID.accountsTransfer, file: file, line: line).tap()

        chooseMenuOption(from, from: require(app, AccessibilityID.transferSource, file: file, line: line),
                         in: app, file: file, line: line)
        chooseMenuOption(to, from: require(app, AccessibilityID.transferDestination, file: file, line: line),
                         in: app, file: file, line: line)

        replaceText(in: require(app, AccessibilityID.transferAmount, file: file, line: line), with: amount)

        if let destinationAmount {
            let field = require(app, AccessibilityID.transferDestinationAmount, file: file, line: line)
            replaceText(in: field, with: destinationAmount)
        }
        if let fee {
            replaceText(in: require(app, AccessibilityID.transferFee, file: file, line: line), with: fee)
        }

        require(app, AccessibilityID.transferSave, file: file, line: line).tap()
        XCTAssertTrue(require(app, AccessibilityID.accountsTransferRow, file: file, line: line)
            .waitForExistence(timeout: 15),
                      "The transfer never appeared in the account list.\n\(app.debugDescription)",
                      file: file, line: line)
    }

    // MARK: - Row helpers

    /// Account rows share one identifier; the row's combined label carries the
    /// account name, so cases pick by name. Scrolls the list because it is lazy.
    private func accountRow(named name: String, in app: XCUIApplication) -> XCUIElement {
        for _ in 0..<6 {
            let row = app.buttons.matching(identifier: AccessibilityID.accountsRow)
                .matching(NSPredicate(format: "label CONTAINS %@", name))
                .firstMatch
            if row.exists && row.isHittable { return row }
            app.swipeUp()
        }
        return app.buttons.matching(identifier: AccessibilityID.accountsRow)
            .matching(NSPredicate(format: "label CONTAINS %@", name))
            .firstMatch
    }

    private func scrollToTop(in app: XCUIApplication) {
        for _ in 0..<4 { app.swipeDown() }
    }

    /// Reveals a row's trailing swipe action. UIKit usually drops the
    /// identifier the Button carries, so the title is the fallback (the launch
    /// pins English); the same caveat as the ledger's delete action.
    private func swipeAction(on row: XCUIElement, titled title: String,
                             identifier: String, in app: XCUIApplication,
                             file: StaticString = #filePath, line: UInt = #line) {
        row.swipeLeft()
        let identified = element(app, identifier)
        if identified.waitForExistence(timeout: 5) {
            identified.tap()
            return
        }
        let titled = app.buttons.matching(
            NSPredicate(format: "label == %@", title)).firstMatch
        if titled.waitForExistence(timeout: 5) {
            titled.tap()
            return
        }
        XCTFail("The row's \"\(title)\" swipe action never appeared.\n\(app.debugDescription)",
                file: file, line: line)
    }

    /// Replaces a text field's contents (the number fields start pre-filled in
    /// the transfer editor).
    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        let current = (field.value as? String) ?? ""
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
        field.typeText(deletes + text)
    }
}
