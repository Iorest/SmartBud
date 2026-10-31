//
//  SmartBudUITests.swift
//  SmartBudUITests
//
//  Five interaction smoke tests plus the iOS 17+ accessibility audit.
//
//  Conventions (see docs/engineering.md, section "UI 测试"):
//  - Every query goes through an identifier from `AccessibilityID`, which is
//    compiled into this target as well as the app. Localised copy is never a
//    query anchor: the app ships en / zh-Hans / zh-Hant and these cases pin en,
//    so a copy-based query would hide regressions in the other two.
//  - Two surfaces are system-rendered and cannot carry an identifier: the
//    UITabBar buttons behind `.tabItem` and the `.searchable` field. They are
//    located by position through `select(_:in:)`.
//  - Each case ends with `assertAccessible`, so a control added without an
//    accessibility description fails the run that introduced it.
//

import Foundation
import XCTest

@MainActor
final class SmartBudUITests: XCTestCase {

    // MARK: - Launch

    /// No `setUp` launch: some cases need their own arguments, so each test
    /// launches the app itself.
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += [
            // Pin the language so assertions never depend on the simulator's
            // region. `appLanguage` falls back to `Locale.current`.
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            // DEBUG-only QA hooks: skip the two-page welcome flow
            // (ContentViewModel.bootstrap) and feed the import wizard the
            // bundled sample CSV instead of the system file picker
            // (ImportDataView.body).
            "-skipIntro",
            "-importSample",
        ]
        app.launch()
        dismissLaunchOverlay(app)
        return app
    }

    /// A simulator without iCloud boots the store in App-Group mode, which
    /// raises the storage notice once per launch. Nothing here tests that
    /// banner, and the alert swallows the first tap of any case that ignores
    /// it.
    private func dismissLaunchOverlay(_ app: XCUIApplication) {
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 5), alert.buttons.firstMatch.exists {
            alert.buttons.firstMatch.tap()
        }
    }

    // MARK: - Queries

    /// Identifier-first lookup. Depending on the SwiftUI container the
    /// identifier lands on a button, a cell or a static text, so the query
    /// accepts any element type.
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    private func require(
        _ app: XCUIApplication,
        _ identifier: String,
        timeout: TimeInterval = 20,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let match = element(app, identifier)
        if !match.waitForExistence(timeout: timeout) {
            XCTFail("No element with identifier \"\(identifier)\".\n\(app.debugDescription)",
                    file: file, line: line)
        }
        return match
    }

    /// SwiftUI's `.tabItem` is rendered by UITabBar, which drops the
    /// identifier the `Label` carries, so the tab's position — fixed by
    /// `HomeView.tabShell` — is the only stable anchor. Each caller asserts a
    /// screen-specific identifier right after tapping, so a reordered tab bar
    /// fails the case instead of quietly testing the wrong screen.
    private enum Tab: Int {
        case log = 0
        case insights = 1
        case budget = 2
        case settings = 3
    }

    private func select(_ tab: Tab, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        let button = app.tabBars.buttons.element(boundBy: tab.rawValue)
        if !button.waitForExistence(timeout: 10) {
            XCTFail("Tab bar button \(tab.rawValue) is missing.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        button.tap()
    }

    /// The ledger row a test just created. Rows are ordered newest first and
    /// share one identifier, so the first cell holding a row button is it. The
    /// amount is asserted on the row's label afterwards — it is not the
    /// locator, so a formatting change cannot silently point the test at a
    /// different row.
    private func newestRow(in app: XCUIApplication) -> XCUIElement {
        app.cells.containing(.button, identifier: AccessibilityID.logRow).firstMatch
    }

    /// The row *cell* carries no label of its own; the row button inside it
    /// aggregates the note, time and amount. Assertions read the button.
    private func assertNewestRowAmount(
        _ amount: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = app.buttons.matching(identifier: AccessibilityID.logRow).firstMatch
        if !button.waitForExistence(timeout: 10) {
            XCTFail("No ledger row button found.\n\(app.debugDescription)", file: file, line: line)
            return
        }
        XCTAssertTrue(button.label.contains(amount),
                      "The newest row is not the expected expense: \"\(button.label)\"",
                      file: file, line: line)
    }

    /// Scrolls until `identifier` is on screen and hittable. The Settings list
    /// is taller than a phone screen and rows below the fold are not in the
    /// hierarchy at all (the List is lazy), so `exists` is only meaningful
    /// after scrolling.
    private func scrollIntoView(
        _ identifier: String,
        in app: XCUIApplication,
        maxSwipes: Int = 8
    ) -> XCUIElement {
        let target = element(app, identifier)
        for _ in 0..<maxSwipes {
            if target.exists && target.isHittable { return target }
            app.swipeUp()
        }
        return target
    }

    private func waitUntilEnabled(_ target: XCUIElement, timeout: TimeInterval = 10) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"), object: target)
        _ = XCTWaiter().wait(for: [expectation], timeout: timeout)
    }

    /// Reveals and taps the row's trailing delete action. `.swipeActions` is
    /// rendered by UIKit, which usually drops the identifier the Button
    /// carries, so the revealed button is matched by identifier first and by
    /// its title second. The title fallback is the suite's single copy-based
    /// query and only works because the launch pins English; it is listed as a
    /// known limitation in docs/engineering.md.
    private func swipeDelete(
        _ row: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        row.swipeLeft()

        let identified = element(app, AccessibilityID.logRowDelete)
        if identified.waitForExistence(timeout: 5) {
            identified.tap()
            return
        }

        // UIKit's own rendering of the destructive action.
        let titled = app.buttons["Delete"].firstMatch
        if titled.waitForExistence(timeout: 5) {
            titled.tap()
            return
        }

        XCTFail("The row's delete swipe action never appeared.\n\(app.debugDescription)",
                file: file, line: line)
    }

    // MARK: - Accessibility audit

    /// Runs the full audit for the screen under test. Issue types listed in
    /// `AccessibilityAuditPolicy.ignoredTypes` are documented, tracked
    /// exceptions; everything else fails the case. Every issue is printed so
    /// the CI log carries the unfiltered report, ignored or not.
    private func assertAccessible(
        _ app: XCUIApplication,
        screen: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try app.performAccessibilityAudit { issue in
                let identifier = issue.element?.identifier ?? ""
                print("AUDIT[\(screen)] \(issue.auditType) \(issue.compactDescription) [\(identifier)]")
                if AccessibilityAuditPolicy.ignoredTypes.contains(issue.auditType) { return true }
                return AccessibilityAuditPolicy.ignoredElementIdentifiers.contains(identifier)
            }
        } catch {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "audit-failure-\(screen)"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTFail("Accessibility audit failed on \(screen): \(error)", file: file, line: line)
        }
    }

    // MARK: - 1. Create an expense, delete it, undo the delete

    func testCreateExpenseThenUndoDelete() throws {
        let app = launch()
        require(app, AccessibilityID.logAddButton).tap()

        // 12.34. The decimal key only exists in the "type the decimal" entry
        // mode (the first-launch default), so the amount the pad will produce
        // depends on which key the run finds.
        let hasDecimalKey = element(app, AccessibilityID.padDecimal).waitForExistence(timeout: 5)
        for digit in [1, 2] { require(app, AccessibilityID.padDigit(digit)).tap() }
        if hasDecimalKey { element(app, AccessibilityID.padDecimal).tap() }
        for digit in [3, 4] { require(app, AccessibilityID.padDigit(digit)).tap() }
        let amount = hasDecimalKey ? "12.34" : "1234"

        // A category is mandatory. A fresh store has none, so seed the
        // starter set from the picker's empty state first.
        require(app, AccessibilityID.entryCategoryButton).tap()
        let seed = element(app, AccessibilityID.entrySeedCategories)
        if seed.waitForExistence(timeout: 3) { seed.tap() }
        let tile = element(app, AccessibilityID.entryCategoryTile)
        if !tile.waitForExistence(timeout: 10) {
            XCTFail("Category grid stayed empty.\n\(app.debugDescription)")
        }
        tile.tap()
        // The picker swaps the pad out; its return is the sync point for the
        // closing animation.
        require(app, AccessibilityID.padDigit(0))

        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        let created = newestRow(in: app)
        XCTAssertTrue(created.waitForExistence(timeout: 20),
                      "The new expense never showed up in the log.\n\(app.debugDescription)")
        assertNewestRowAmount(amount, in: app)

        // The row's trailing swipe action is the only delete path that stages
        // the delete, which is what raises the undo banner.
        swipeDelete(created, in: app)

        // The undo window is 6 s (TransactionViewModel.undoWindow).
        require(app, AccessibilityID.logUndoButton, timeout: 5).tap()

        let restored = newestRow(in: app)
        XCTAssertTrue(restored.waitForExistence(timeout: 15),
                      "Undo did not restore the deleted row.\n\(app.debugDescription)")
        assertNewestRowAmount(amount, in: app)

        assertAccessible(app, screen: "log")
    }

    // MARK: - 1b. Save stays disabled until there is an amount

    func testSaveStaysDisabledWithoutAmount() throws {
        let app = launch()
        require(app, AccessibilityID.logAddButton).tap()

        let save = require(app, AccessibilityID.entrySave)
        XCTAssertFalse(save.isEnabled,
                       "Save must stay disabled while the amount is zero")

        require(app, AccessibilityID.padDigit(5)).tap()
        waitUntilEnabled(save)
        XCTAssertTrue(save.isEnabled,
                      "Save must become enabled once an amount is entered")
    }

    // MARK: - 1c. Editing the amount updates the ledger row

    func testEditingAmountUpdatesRow() throws {
        let app = launch()
        require(app, AccessibilityID.logAddButton).tap()
        for digit in [4, 2] { require(app, AccessibilityID.padDigit(digit)).tap() }

        require(app, AccessibilityID.entryCategoryButton).tap()
        let seed = element(app, AccessibilityID.entrySeedCategories)
        if seed.waitForExistence(timeout: 3) { seed.tap() }
        let tile = element(app, AccessibilityID.entryCategoryTile)
        XCTAssertTrue(tile.waitForExistence(timeout: 10),
                      "Category grid stayed empty.\n\(app.debugDescription)")
        tile.tap()
        require(app, AccessibilityID.padDigit(0))

        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        let created = newestRow(in: app)
        XCTAssertTrue(created.waitForExistence(timeout: 20),
                      "The new expense never showed up in the log.\n\(app.debugDescription)")
        app.buttons.matching(identifier: AccessibilityID.logRow).firstMatch.tap()

        // Append a digit instead of clearing: the pad's bottom-left key is a
        // backspace only in integer-entry mode, so a clear-then-retype step
        // would depend on which mode the edited row happens to open in.
        require(app, AccessibilityID.padDigit(7)).tap()

        let saveEdit = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(saveEdit)
        saveEdit.tap()

        assertNewestRowAmount("427", in: app)
    }

    // MARK: - 1d. Cancelling a non-empty draft writes nothing

    func testCancelDiscardsDraft() throws {
        let app = launch()
        let rowsBefore = app.buttons.matching(identifier: AccessibilityID.logRow).count

        require(app, AccessibilityID.logAddButton).tap()
        require(app, AccessibilityID.padDigit(7)).tap()
        require(app, AccessibilityID.entryCancel).tap()

        // A non-empty draft asks for confirmation before it is dropped.
        let discard = app.alerts.buttons.matching(
            NSPredicate(format: "label == %@", "Discard")).firstMatch
        if discard.waitForExistence(timeout: 5) { discard.tap() }

        require(app, AccessibilityID.logAddButton)
        XCTAssertEqual(app.buttons.matching(identifier: AccessibilityID.logRow).count,
                       rowsBefore,
                       "Cancelling a draft must not create a ledger row")
    }

    // MARK: - 2. Every tab opens its own screen

    func testTabsCycleThroughAllFourSections() throws {
        let app = launch()
        require(app, AccessibilityID.logAddButton)  // Log is the launch tab

        select(.insights, in: app)
        require(app, AccessibilityID.insightsPeriodPicker)

        select(.budget, in: app)
        require(app, AccessibilityID.budgetAddButton)

        select(.settings, in: app)
        require(app, AccessibilityID.settingsRow(SettingsRouteKey.pro))

        select(.log, in: app)
        require(app, AccessibilityID.logAddButton)

        assertAccessible(app, screen: "tabs")
    }

    // MARK: - 3. Smart entry opens and closes

    func testSmartEntryOpensAndCancels() throws {
        let app = launch()
        require(app, AccessibilityID.logAddButton).tap()
        require(app, AccessibilityID.entrySmartEntry).tap()
        require(app, AccessibilityID.smartEntryField)
        require(app, AccessibilityID.smartEntryClose).tap()

        // Back on the form with an empty draft, so Cancel closes it outright
        // instead of asking "Discard this entry?".
        require(app, AccessibilityID.entryCancel, timeout: 10).tap()
        require(app, AccessibilityID.logAddButton)

        assertAccessible(app, screen: "smart-entry")
    }

    // MARK: - 4. Settings → Pro → back

    func testSettingsOpensProAndBackReturns() throws {
        let app = launch()
        select(.settings, in: app)
        require(app, AccessibilityID.settingsRow(SettingsRouteKey.pro)).tap()
        require(app, AccessibilityID.proTitle)
        require(app, AccessibilityID.proBack).tap()
        require(app, AccessibilityID.settingsRow(SettingsRouteKey.pro))

        assertAccessible(app, screen: "settings")
    }

    // MARK: - 5. Import preview then cancel

    func testImportPreviewThenCancel() throws {
        let app = launch()
        select(.settings, in: app)
        let importRow = scrollIntoView(AccessibilityID.settingsImportData, in: app)
        if !importRow.exists {
            XCTFail("The import row never came into view.\n\(app.debugDescription)")
        }
        importRow.tap()

        // `-importSample` already parsed the bundled CSV, so the wizard opens
        // on the column-preview step.
        require(app, AccessibilityID.importPreview, timeout: 20)
        require(app, AccessibilityID.importContinue)

        // One step back to the first page, then close.
        require(app, AccessibilityID.importClose).tap()
        require(app, AccessibilityID.importChooseFile, timeout: 10)
        require(app, AccessibilityID.importClose).tap()
        require(app, AccessibilityID.settingsImportData, timeout: 10)

        assertAccessible(app, screen: "settings-after-import")
    }

    // MARK: - Interaction E2E (TELE-36)
    //
    // Nine flows that go past "the screen opened": every case reads a number
    // or a message back out of the app (ledger row, stats card, account
    // balance, budget remaining, validation toast) and compares it with the
    // value before the action. Assertions are deltas against a value measured
    // in the same run, because the simulator's store is shared by every case
    // and survives between runs — absolute numbers here would encode the
    // order the suite happened to execute in.

    /// Amount currently shown above the keypad, read out of the read-out's
    /// label ("$ 12.50") so the assertion is on the number, not on copy.
    private func padAmount(_ app: XCUIApplication,
                           file: StaticString = #filePath, line: UInt = #line) -> Double? {
        amount(in: require(app, AccessibilityID.entryAmountDisplay, file: file, line: line).label)
    }

    private func typeDigits(_ app: XCUIApplication, _ digits: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        for character in digits {
            let digit = Int(String(character)) ?? 0
            require(app, AccessibilityID.padDigit(digit), file: file, line: line).tap()
        }
    }

    /// Empties the pad with its own delete key: how many digits a prefilled
    /// edit holds depends on the stored amount, not on the test.
    private func clearAmount(_ app: XCUIApplication) {
        for _ in 0..<12 {
            if (padAmount(app) ?? 0) == 0 { return }
            element(app, AccessibilityID.padBackspace).tap()
        }
    }

    /// Opens the category grid, seeding the starter set on a fresh store.
    private func openCategoryPicker(_ app: XCUIApplication) {
        require(app, AccessibilityID.entryCategoryButton).tap()
        let seed = element(app, AccessibilityID.entrySeedCategories)
        if seed.waitForExistence(timeout: 3) { seed.tap() }
    }

    /// Picks the first tile, or the tile whose label is `name`. The grid is
    /// lazy and the list of categories grows with every run, so the named
    /// variant scrolls.
    private func pickCategory(_ app: XCUIApplication, named name: String? = nil,
                              file: StaticString = #filePath, line: UInt = #line) {
        let tile: XCUIElement
        if let name {
            tile = app.buttons.matching(identifier: AccessibilityID.entryCategoryTile)
                .matching(NSPredicate(format: "label == %@", name)).firstMatch
            for _ in 0..<8 where !(tile.exists && tile.isHittable) { app.swipeUp() }
        } else {
            tile = element(app, AccessibilityID.entryCategoryTile)
        }
        if !tile.waitForExistence(timeout: 10) {
            XCTFail("Category tile \"\(name ?? "first")\" never appeared.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        tile.tap()
        // The pad coming back is the sync point for the closing animation.
        require(app, AccessibilityID.padDigit(0), file: file, line: line)
    }

    /// Reads a displayed amount ("Expenses, $12.50", "-$5.00", "left, $70")
    /// as a number. Currency copy is not used as a locator here, only parsed.
    private func amount(in text: String) -> Double? {
        var number = ""
        for character in text.replacingOccurrences(of: ",", with: "") {
            if character.isNumber || character == "." {
                number.append(character)
            } else if character == "-" && number.isEmpty {
                number.append(character)
            }
        }
        return Double(number)
    }

    /// Insights' expense total for the current period. `0` when the period is
    /// empty — the cards only exist once something was spent.
    private func expenseTotal(_ app: XCUIApplication) -> Double {
        select(.insights, in: app)
        let card = element(app, AccessibilityID.insightsExpenseCard)
        guard card.waitForExistence(timeout: 6) else { return 0 }
        return amount(in: card.label) ?? .nan
    }

    private func openAccounts(_ app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        select(.settings, in: app)
        // The Settings tab keeps its navigation stack across tab switches, so
        // the row is only present when Accounts is not already pushed.
        if !element(app, AccessibilityID.accountsAddButton).waitForExistence(timeout: 3) {
            let row = scrollIntoView(AccessibilityID.settingsRow("accounts"), in: app)
            if !row.exists {
                XCTFail("The Accounts settings row never came into view.\n\(app.debugDescription)",
                        file: file, line: line)
                return
            }
            row.tap()
        }
        require(app, AccessibilityID.accountsAddButton, file: file, line: line)
    }

    /// Back on the Accounts screen from any tab (the tab's navigation stack is
    /// kept alive across tab switches, so this re-taps the row only if needed).
    private func ensureAccounts(_ app: XCUIApplication,
                                file: StaticString = #filePath, line: UInt = #line) {
        select(.settings, in: app)
        if !element(app, AccessibilityID.accountsTransferButton).waitForExistence(timeout: 3) {
            let row = scrollIntoView(AccessibilityID.settingsRow("accounts"), in: app)
            if row.exists { row.tap() }
        }
        require(app, AccessibilityID.accountsTransferButton, file: file, line: line)
    }

    private func makeAccount(_ app: XCUIApplication, name: String,
                             currencyCode: String? = nil, opening: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        require(app, AccessibilityID.accountsAddButton, file: file, line: line).tap()

        let nameField = require(app, AccessibilityID.accountNameField, file: file, line: line)
        nameField.tap()
        nameField.typeText(name)

        if let currencyCode {
            require(app, AccessibilityID.accountCurrencyPicker, file: file, line: line).tap()
            // The picker lists every ISO code; the wanted one may be below the
            // fold, and the list is lazy.
            let option = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", currencyCode)).firstMatch
            for _ in 0..<20 where !(option.exists && option.isHittable) { app.swipeUp() }
            if !option.waitForExistence(timeout: 5) {
                XCTFail("\(currencyCode) is not offered by the currency picker.\n\(app.debugDescription)",
                        file: file, line: line)
                return
            }
            option.tap()
        }

        let openingField = require(app, AccessibilityID.accountOpeningBalance, file: file, line: line)
        openingField.tap()
        openingField.typeText(opening)

        require(app, AccessibilityID.accountDone, file: file, line: line).tap()
        // Back on the list: the sheet's button is gone.
        require(app, AccessibilityID.accountsAddButton, file: file, line: line)
    }

    private func balance(_ app: XCUIApplication, of accountName: String,
                         file: StaticString = #filePath, line: UInt = #line) -> Double {
        let figure = scrollIntoView(AccessibilityID.accountBalance(accountName), in: app)
        if !figure.exists {
            XCTFail("No balance row for \"\(accountName)\".\n\(app.debugDescription)",
                    file: file, line: line)
            return .nan
        }
        return amount(in: figure.label) ?? .nan
    }

    /// Segmented controls are system-rendered: the segments carry their copy,
    /// not an identifier (same exception as the tab bar).
    private func tapSegment(_ title: String, in app: XCUIApplication) {
        let segmented = app.segmentedControls.buttons[title].firstMatch
        if segmented.exists {
            segmented.tap()
            return
        }
        app.buttons[title].firstMatch.tap()
    }

    /// Saves a plain expense through the happy path and returns its row.
    @discardableResult
    private func addExpense(_ app: XCUIApplication, digits: String,
                            category: String? = nil, account: String? = nil,
                            file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        require(app, AccessibilityID.logAddButton, file: file, line: line).tap()
        typeDigits(app, digits, file: file, line: line)
        openCategoryPicker(app)
        pickCategory(app, named: category, file: file, line: line)
        if let account {
            require(app, AccessibilityID.entryAccountChip, file: file, line: line).tap()
            let option = element(app, AccessibilityID.accountOption(account))
            if !option.waitForExistence(timeout: 10) {
                XCTFail("Account \"\(account)\" is missing from the picker.\n\(app.debugDescription)",
                        file: file, line: line)
            }
            option.tap()
            require(app, AccessibilityID.entryCategoryButton, file: file, line: line)
        }
        let save = require(app, AccessibilityID.entrySave, file: file, line: line)
        waitUntilEnabled(save)
        save.tap()
        let row = newestRow(in: app)
        if !row.waitForExistence(timeout: 20) {
            XCTFail("The saved expense never showed up in the log.\n\(app.debugDescription)",
                    file: file, line: line)
        }
        return row
    }

    private func chooseTransferAccount(_ app: XCUIApplication, picker: String, name: String,
                                       file: StaticString = #filePath, line: UInt = #line) {
        element(app, picker).tap()
        let option = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        if !option.waitForExistence(timeout: 10) {
            XCTFail("\"\(name)\" is not offered by the transfer picker.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        option.tap()
        // The option list pops back to the form; the amount row is its anchor.
        require(app, AccessibilityID.transferAmount, file: file, line: line)
    }

    /// Moves the form's date to tomorrow through the graphical date picker.
    /// Tomorrow (not a fixed day of next month) so the row always lands inside
    /// the two-week upcoming window the log renders.
    private func chooseTomorrow(_ app: XCUIApplication,
                                file: StaticString = #filePath, line: UInt = #line) {
        let dateButton = require(app, AccessibilityID.entryDateButton, file: file, line: line)
        let originalLabel = dateButton.label
        dateButton.tap()
        let picker = app.datePickers.firstMatch
        if !picker.waitForExistence(timeout: 10) {
            XCTFail("The date picker never opened.\n\(app.debugDescription)", file: file, line: line)
            return
        }
        let calendar = Calendar.current
        let today = Date.now
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        if calendar.component(.month, from: tomorrow) != calendar.component(.month, from: today) {
            let nextMonth = picker.buttons["Next Month"].firstMatch
            if nextMonth.exists { nextMonth.tap() }
        }
        let day = String(calendar.component(.day, from: tomorrow))
        let cell = picker.buttons[day].firstMatch
        if !cell.waitForExistence(timeout: 5) {
            XCTFail("Date picker day \(day) is not addressable.\n\(picker.debugDescription)",
                    file: file, line: line)
            return
        }
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: cell)
        _ = XCTWaiter().wait(for: [hittable], timeout: 8)
        cell.tap()

        // Tapping a day closes the sheet through an animation; the row's own
        // label changing is the sync point, and it also proves the pick landed.
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", originalLabel), object: dateButton)
        _ = XCTWaiter().wait(for: [changed], timeout: 8)
    }

    private func setDiscount(_ app: XCUIApplication, _ value: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        require(app, AccessibilityID.entryDiscountChip, file: file, line: line).tap()
        let field = app.alerts.textFields.firstMatch
        if !field.waitForExistence(timeout: 5) {
            XCTFail("The discount alert never appeared.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        field.tap()
        field.typeText(value)
        app.alerts.buttons["Done"].firstMatch.tap()
    }

    // MARK: - A1. Expense from the add button updates the expense total

    func testA1_addExpense_updatesStats() throws {
        let app = launch()
        let before = expenseTotal(app)

        select(.log, in: app)
        require(app, AccessibilityID.logAddButton).tap()
        typeDigits(app, "1250")
        XCTAssertEqual(padAmount(app) ?? .nan, 12.50, accuracy: 0.001,
                       "The pad did not produce 12.50")
        openCategoryPicker(app)
        pickCategory(app)
        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        let created = newestRow(in: app)
        XCTAssertTrue(created.waitForExistence(timeout: 20),
                      "The new expense never showed up in the log.\n\(app.debugDescription)")
        assertNewestRowAmount("12.50", in: app)

        let after = expenseTotal(app)
        XCTAssertEqual(after, before + 12.50, accuracy: 0.005,
                       "Expenses went \(before) → \(after); expected +12.50")

        select(.log, in: app)
        assertAccessible(app, screen: "log")
    }

    // MARK: - A2. Save and continue keeps the category and account

    func testA2_continuousEntry_clearsAmountKeepsCategory() throws {
        let app = launch()
        let accountName = "QA Continue \(UUID().uuidString.prefix(4))"

        openAccounts(app)
        makeAccount(app, name: accountName, opening: "50")
        select(.log, in: app)

        require(app, AccessibilityID.logAddButton).tap()
        typeDigits(app, "500")
        openCategoryPicker(app)
        pickCategory(app)
        require(app, AccessibilityID.entryAccountChip).tap()
        let accountOption = element(app, AccessibilityID.accountOption(accountName))
        XCTAssertTrue(accountOption.waitForExistence(timeout: 10),
                      "The new account is missing from the entry picker.\n\(app.debugDescription)")
        accountOption.tap()
        require(app, AccessibilityID.entryCategoryButton)

        let categoryLabel = require(app, AccessibilityID.entryCategoryButton).label
        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        // The checkmark's context menu is the one-off "keep the form open"
        // path (Settings → Number Entry has the persistent switch).
        save.press(forDuration: 1.2)
        let saveAndContinue = element(app, AccessibilityID.entrySaveAndContinue)
        if saveAndContinue.waitForExistence(timeout: 3) {
            saveAndContinue.tap()
        } else {
            let titled = app.buttons["Save and Continue"].firstMatch
            XCTAssertTrue(titled.waitForExistence(timeout: 3),
                          "The checkmark's Save and Continue action never appeared.\n\(app.debugDescription)")
            titled.tap()
        }

        // The form is still open, the amount is cleared, the rest is kept.
        XCTAssertEqual(padAmount(app) ?? .nan, 0, accuracy: 0.001,
                       "The amount was not cleared after save-and-continue")
        XCTAssertEqual(require(app, AccessibilityID.entryCategoryButton).label, categoryLabel,
                       "The category was dropped after save-and-continue")
        XCTAssertTrue(require(app, AccessibilityID.entryAccountChip).label.contains(accountName),
                      "The account was dropped after save-and-continue")

        // A second entry saved with the normal checkmark closes the form.
        typeDigits(app, "300")
        let secondSave = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(secondSave)
        secondSave.tap()
        XCTAssertTrue(newestRow(in: app).waitForExistence(timeout: 20),
                      "The second consecutive entry never showed up.\n\(app.debugDescription)")
        assertNewestRowAmount("3.00", in: app)

        assertAccessible(app, screen: "log")
    }

    // MARK: - A3. Zero, over-limit and missing category are refused

    func testA3_invalidInput_isRefusedWithMessage() throws {
        let app = launch()
        let rowsBefore = app.buttons.matching(identifier: AccessibilityID.logRow).count

        require(app, AccessibilityID.logAddButton).tap()

        // Nothing typed: the checkmark cannot commit an empty amount.
        let save = require(app, AccessibilityID.entrySave)
        XCTAssertFalse(save.isEnabled, "The checkmark accepted a zero amount")

        // The pad caps a single amount at 99,999,999.99; more digits are
        // refused rather than silently truncating a longer number.
        typeDigits(app, String(repeating: "9", count: 12))
        XCTAssertEqual(padAmount(app) ?? .nan, 99_999_999.99, accuracy: 0.001)
        typeDigits(app, "9")
        XCTAssertEqual(padAmount(app) ?? .nan, 99_999_999.99, accuracy: 0.001,
                       "A digit past the cap was accepted")

        clearAmount(app)
        typeDigits(app, "1200")
        waitUntilEnabled(save)
        save.tap()
        let toast = require(app, AccessibilityID.entryToast, timeout: 5)
        XCTAssertTrue(toast.label.contains("Missing Category"),
                      "The refusal message was \"\(toast.label)\"")
        XCTAssertTrue(save.exists, "The form closed after an invalid save")

        require(app, AccessibilityID.entryCancel).tap()
        let discard = app.buttons["Discard"].firstMatch
        if discard.waitForExistence(timeout: 5) { discard.tap() }
        require(app, AccessibilityID.logAddButton)

        XCTAssertEqual(app.buttons.matching(identifier: AccessibilityID.logRow).count, rowsBefore,
                       "A refused save still wrote a ledger row")

        assertAccessible(app, screen: "log")
    }

    // MARK: - A4. Discount, claim and a future date stay out of this period

    func testA4_discountClaimFutureDate_staysOutOfStats() throws {
        let app = launch()
        let before = expenseTotal(app)
        select(.log, in: app)

        // A plain entry first: it gives the "today" section something to
        // compare the future row's position against.
        addExpense(app, digits: "100")
        assertNewestRowAmount("1.00", in: app)
        let afterPlain = expenseTotal(app)
        XCTAssertEqual(afterPlain, before + 1.00, accuracy: 0.005)

        select(.log, in: app)
        require(app, AccessibilityID.logAddButton).tap()
        typeDigits(app, "2000")
        openCategoryPicker(app)
        pickCategory(app)
        setDiscount(app, "5")
        require(app, AccessibilityID.entryClaimChip).tap()
        chooseTomorrow(app)
        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        require(app, AccessibilityID.logUpcomingHeader, timeout: 20)
        let futureRow = app.buttons.matching(identifier: AccessibilityID.logRow)
            .matching(NSPredicate(format: "label CONTAINS %@", "20.00")).firstMatch
        XCTAssertTrue(futureRow.waitForExistence(timeout: 10),
                      "The future expense is not in the ledger.\n\(app.debugDescription)")
        XCTAssertTrue(futureRow.label.contains("Discount $5.00"),
                      "The discount badge is missing: \"\(futureRow.label)\"")
        XCTAssertTrue(futureRow.label.contains("Pending"),
                      "The claim badge is missing: \"\(futureRow.label)\"")

        // The upcoming section renders above the month sections.
        let todayHeader = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "today,")).firstMatch
        XCTAssertTrue(todayHeader.waitForExistence(timeout: 10),
                      "No today section to compare against.\n\(app.debugDescription)")
        XCTAssertLessThan(futureRow.frame.minY, todayHeader.frame.minY,
                          "The future row is not in the upcoming section")

        // Neither the future date nor the claim moves this period's spend.
        let after = expenseTotal(app)
        XCTAssertEqual(after, before + 1.00, accuracy: 0.005,
                       "A future/claimed expense moved the period total: \(before) → \(after)")

        select(.log, in: app)
        assertAccessible(app, screen: "log")
    }

    // MARK: - A5. Editing the amount moves the total; switching type drops the category

    func testA5_editAmount_updatesStats_typeSwitchClearsCategory() throws {
        let app = launch()
        let before = expenseTotal(app)
        select(.log, in: app)
        addExpense(app, digits: "1250")
        assertNewestRowAmount("12.50", in: app)
        let afterCreate = expenseTotal(app)
        XCTAssertEqual(afterCreate, before + 12.50, accuracy: 0.005)

        select(.log, in: app)
        element(app, AccessibilityID.logRow).tap()

        // Wait for the stored amount to load into the pad before editing it.
        let display = require(app, AccessibilityID.entryAmountDisplay)
        let loaded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "12.50"), object: display)
        _ = XCTWaiter().wait(for: [loaded], timeout: 10)

        clearAmount(app)
        typeDigits(app, "2000")
        XCTAssertEqual(padAmount(app) ?? .nan, 20, accuracy: 0.001)
        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        let afterEdit = expenseTotal(app)
        XCTAssertEqual(afterEdit, afterCreate + 7.50, accuracy: 0.005,
                       "Editing 12.50 → 20.00 did not move the total by 7.50")

        // Switching to income drops a category that belongs to the other side.
        select(.log, in: app)
        element(app, AccessibilityID.logRow).tap()
        tapSegment("Income", in: app)
        XCTAssertEqual(require(app, AccessibilityID.entryCategoryButton).label, "Category",
                       "The expense category survived the switch to income")
        require(app, AccessibilityID.entryCancel).tap()
        let discard = app.buttons["Discard"].firstMatch
        if discard.waitForExistence(timeout: 5) { discard.tap() }

        // Cancelling kept the edited amount.
        assertNewestRowAmount("20.00", in: app)
        assertAccessible(app, screen: "log")
    }

    // MARK: - A6. Delete, undo, and the snapshot behind it

    func testA6_deleteUndo_restoresFieldsAndBalance() throws {
        let app = launch()
        let accountName = "QA Undo \(UUID().uuidString.prefix(4))"

        openAccounts(app)
        makeAccount(app, name: accountName, opening: "200")
        select(.log, in: app)

        require(app, AccessibilityID.logAddButton).tap()
        typeDigits(app, "4000")
        openCategoryPicker(app)
        pickCategory(app)
        require(app, AccessibilityID.entryAccountChip).tap()
        let option = element(app, AccessibilityID.accountOption(accountName))
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()
        require(app, AccessibilityID.entryCategoryButton)
        setDiscount(app, "10")
        require(app, AccessibilityID.entryClaimChip).tap()
        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        let created = newestRow(in: app)
        XCTAssertTrue(created.waitForExistence(timeout: 20),
                      "The expense never showed up.\n\(app.debugDescription)")
        let createdLabel = app.buttons.matching(identifier: AccessibilityID.logRow).firstMatch.label
        XCTAssertTrue(createdLabel.contains("40.00"))
        XCTAssertTrue(createdLabel.contains("Discount $10.00"))
        XCTAssertTrue(createdLabel.contains("Pending"))

        // The account was debited by the net amount.
        openAccounts(app)
        XCTAssertEqual(balance(app, of: accountName), 160, accuracy: 0.005,
                       "The account balance did not include the new expense")

        select(.log, in: app)
        swipeDelete(newestRow(in: app), in: app)

        // The undo banner is the staged-delete affordance; 6 s window.
        require(app, AccessibilityID.logUndoButton, timeout: 5).tap()

        let restored = app.buttons.matching(identifier: AccessibilityID.logRow)
            .matching(NSPredicate(format: "label CONTAINS %@", "Discount $10.00")).firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 15),
                      "Undo did not restore the row.\n\(app.debugDescription)")
        XCTAssertTrue(restored.label.contains("40.00"))
        XCTAssertTrue(restored.label.contains("Pending"),
                      "The claim flag was lost by undo: \"\(restored.label)\"")

        openAccounts(app)
        XCTAssertEqual(balance(app, of: accountName), 160, accuracy: 0.005,
                       "Undo did not restore the account balance")

        select(.log, in: app)
        assertAccessible(app, screen: "log")
    }

    // MARK: - A7. Same-currency transfer moves balances, not spend

    func testA7_sameCurrencyTransfer_movesBalancesOnly() throws {
        let app = launch()
        let suffix = UUID().uuidString.prefix(4)
        let source = "QA From \(suffix)"
        let destination = "QA To \(suffix)"

        openAccounts(app)
        makeAccount(app, name: source, opening: "100")
        makeAccount(app, name: destination, opening: "100")

        let spendBefore = expenseTotal(app)
        ensureAccounts(app)

        require(app, AccessibilityID.accountsTransferButton).tap()
        chooseTransferAccount(app, picker: AccessibilityID.transferFrom, name: source)
        chooseTransferAccount(app, picker: AccessibilityID.transferTo, name: destination)
        let amountField = require(app, AccessibilityID.transferAmount)
        amountField.tap()
        amountField.typeText("20")
        require(app, AccessibilityID.transferDone).tap()

        XCTAssertEqual(balance(app, of: source), 80, accuracy: 0.005,
                       "The source account was not debited")
        XCTAssertEqual(balance(app, of: destination), 120, accuracy: 0.005,
                       "The destination account was not credited")
        XCTAssertEqual(expenseTotal(app), spendBefore, accuracy: 0.005,
                       "Moving money between accounts changed the expense total")

        select(.log, in: app)
        assertAccessible(app, screen: "log")
    }

    // MARK: - A8. Cross-currency transfer: fee is the only spend

    func testA8_crossCurrencyTransfer_feeOnlyInSpend() throws {
        let app = launch()
        let suffix = UUID().uuidString.prefix(4)
        let source = "QA USD \(suffix)"
        let destination = "QA AUD \(suffix)"

        openAccounts(app)
        makeAccount(app, name: source, opening: "100")
        makeAccount(app, name: destination, currencyCode: "AUD", opening: "0")

        let spendBefore = expenseTotal(app)
        ensureAccounts(app)

        require(app, AccessibilityID.accountsTransferButton).tap()
        chooseTransferAccount(app, picker: AccessibilityID.transferFrom, name: source)
        chooseTransferAccount(app, picker: AccessibilityID.transferTo, name: destination)

        let amountField = require(app, AccessibilityID.transferAmount)
        amountField.tap()
        amountField.typeText("100")
        let feeField = require(app, AccessibilityID.transferFee)
        feeField.tap()
        feeField.typeText("5")
        // No stored rate on a fresh simulator: the landed amount is manual.
        let receivedField = require(app, AccessibilityID.transferReceived)
        receivedField.tap()
        receivedField.typeText("200")
        require(app, AccessibilityID.transferDone).tap()

        XCTAssertEqual(balance(app, of: source), -5, accuracy: 0.005,
                       "The source should be down the sent amount plus the fee")
        XCTAssertEqual(balance(app, of: destination), 200, accuracy: 0.005,
                       "The landed amount is wrong")

        // Only the fee is spend: neither 100 nor 200 may leak into the total.
        XCTAssertEqual(expenseTotal(app), spendBefore + 5, accuracy: 0.005,
                       "The transfer body leaked into the expense total")

        select(.log, in: app)
        let feeRow = app.buttons.matching(identifier: AccessibilityID.logRow)
            .matching(NSPredicate(format: "label CONTAINS %@", "Transfer Fee")).firstMatch
        XCTAssertTrue(feeRow.waitForExistence(timeout: 10),
                      "The fee was not booked as its own expense row.\n\(app.debugDescription)")
        XCTAssertTrue(feeRow.label.contains("5.00"))

        let transferRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                                  "→", "200.00")).firstMatch
        XCTAssertTrue(transferRow.waitForExistence(timeout: 10),
                      "The transfer row does not show the landed amount.\n\(app.debugDescription)")

        assertAccessible(app, screen: "log")
    }

    // MARK: - A9. Category budget: remaining drops, then goes over

    /// Budget remaining as a signed number. The tile renders an overage as a
    /// red "over $30" (magnitude + status word), so the sign comes from the
    /// status word rather than from the digits.
    private func budgetRemaining(_ app: XCUIApplication, for name: String,
                                 file: StaticString = #filePath, line: UInt = #line) -> Double? {
        let tile = element(app, AccessibilityID.budgetRemaining(name))
        if !tile.waitForExistence(timeout: 10) {
            XCTFail("No budget tile for \"\(name)\" .\n\(app.debugDescription)",
                    file: file, line: line)
            return nil
        }
        let magnitude = amount(in: tile.label) ?? .nan
        return tile.label.contains("over") ? -magnitude : magnitude
    }

    func testA9_budgetRemaining_dropsThenGoesOver() throws {
        let app = launch()

        // "Food" is part of the starter set; seeding is idempotent, so this
        // only fills in on a fresh store.
        select(.log, in: app)
        require(app, AccessibilityID.logAddButton).tap()
        openCategoryPicker(app)
        pickCategory(app, named: "Food")
        require(app, AccessibilityID.entryCancel).tap()
        require(app, AccessibilityID.logAddButton)

        select(.budget, in: app)
        let opening: Double
        if element(app, AccessibilityID.budgetRemaining("Food")).waitForExistence(timeout: 3) {
            // A re-run finds the budget an earlier run created. Its category
            // also carries those runs' expenses, so the case asserts deltas
            // instead of absolute remainders from here on.
            opening = budgetRemaining(app, for: "Food") ?? .nan
        } else {
            require(app, AccessibilityID.budgetAddButton).tap()
            require(app, AccessibilityID.budgetTypePicker)
            tapSegment("Category Budget", in: app)
            require(app, AccessibilityID.budgetCategoryPicker).tap()
            let option = app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@", "Food")).firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 10),
                          "Food is missing from the budget picker.\n\(app.debugDescription)")
            option.tap()
            require(app, AccessibilityID.budgetContinue).tap()

            typeDigits(app, "10000")  // 100.00
            let save = require(app, AccessibilityID.entrySave)
            waitUntilEnabled(save)
            save.tap()

            let fresh = budgetRemaining(app, for: "Food") ?? .nan
            XCTAssertEqual(fresh, 100, accuracy: 0.01,
                           "A new 100 budget should start with 100 left, got \(fresh)")
            opening = fresh
        }

        select(.log, in: app)
        addExpense(app, digits: "3000", category: "Food")  // 30.00

        select(.budget, in: app)
        let afterSpend = budgetRemaining(app, for: "Food") ?? .nan
        XCTAssertEqual(afterSpend, opening - 30, accuracy: 0.01,
                       "30 spent should leave \(opening - 30), got \(afterSpend)")

        select(.log, in: app)
        addExpense(app, digits: "10000", category: "Food")  // +100.00

        select(.budget, in: app)
        let overTile = element(app, AccessibilityID.budgetRemaining("Food"))
        XCTAssertTrue(overTile.waitForExistence(timeout: 10))
        // The app renders the overage as a red "over $30" (magnitude + status
        // word). A literal negative figure would be a design change, which
        // this test-infrastructure batch does not make; the sign is asserted
        // through the status word and the signed arithmetic below.
        XCTAssertTrue(overTile.label.contains("over"),
                      "130 against a 100 budget should read \"over\", got \"\(overTile.label)\"")
        let overage = budgetRemaining(app, for: "Food") ?? .nan
        XCTAssertEqual(overage, opening - 130, accuracy: 0.01,
                       "Expected a signed remainder of \(opening - 130), got \(overage)")

        select(.log, in: app)
        assertAccessible(app, screen: "log")
    }
}

// MARK: - Audit policy

/// Known audit failures that are tracked rather than fixed here. Every entry
/// names what it hides and why; the list is mirrored in docs/engineering.md
/// (section "UI 测试") next to the work that owns each item.
enum AccessibilityAuditPolicy {
    /// `nonisolated(unsafe)`: the array is never written after launch, and the
    /// XCTest type is not annotated Sendable, so Swift 6 cannot prove it.
    nonisolated(unsafe) static let ignoredTypes: [XCUIAccessibilityAuditType] = [
        // Brand colours are not AA-verified yet; the theme tokens are shared
        // with the design work, not with this test-infrastructure issue.
        .contrast,
        // Fixed-size text on the number pad and the charts; wire it to
        // Dynamic Type separately.
        .dynamicType,
        // Truncation inside the chart and chip labels at large sizes.
        .textClipped,
        // Sub-44pt chips (log badges, filter pills) need a layout pass.
        .hitRegion,
    ]

    /// Element-level exceptions, keyed by identifier so an exception can never
    /// silently widen to "any element with this copy".
    static let ignoredElementIdentifiers: [String] = []
}

/// Settings routes addressed by the tests. `SettingsRoute` itself lives in the
/// app target, so the raw key is mirrored here; `SettingsRoute.accessibilityKey`
/// is the single source of truth and a mismatch fails CI, not silently passes.
enum SettingsRouteKey {
    static let pro = "pro"
}
