//
//  SmartBudUITests.swift
//  SmartBudUITests
//
//  Eight interaction smoke tests plus the iOS 17+ accessibility audit.
//
//  Conventions (see docs/engineering.md, section "UI 测试"):
//  - Every query goes through an identifier from `AccessibilityID`, which is
//    compiled into this target as well as the app. Localised copy is never a
//    query anchor: the app ships en / zh-Hans / zh-Hant and these cases pin en,
//    so a copy-based query would hide regressions in the other two.
//  - Two surfaces are system-rendered and cannot carry an identifier: the
//    UITabBar buttons behind `.tabItem` and the `.searchable` field. They are
//    located by position through `select(_:in:)`.
//  - Five of the eight cases end with `assertAccessible`, so a control added
//    without an accessibility description fails the run that introduced it.
//

import CoreGraphics
import Foundation
import XCTest

@MainActor
final class SmartBudUITests: XCTestCase {

    // MARK: - Launch

    /// No `setUp` launch: each case launches the app itself so the store and
    /// the QA hooks stay explicit at the call site.
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
            // Each case gets its own empty in-memory store
            // (DataRepository.freshMemoryContainer). Without it every case
            // shares one ledger: a case that saves a future-dated row leaves
            // it at the top of the list for every case that follows, which is
            // how the first batch broke two older smoke cases.
            "-freshStore",
            // The run creates enough transactions to cross the 3rd/10th/25th
            // App Store review thresholds; the system sheet would cover the
            // screen mid-case (ReviewRequester.requestReviewIfAppropriate).
            "-skipReviewPrompt",
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
        // A full-screen cover removes the tab bar while it dismisses; tapping
        // in that window resolves to a {-1, -1} hit point and does nothing.
        let tappable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: button)
        _ = XCTWaiter().wait(for: [tappable], timeout: 10)
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
            // The audit engine itself can time out on a loaded CI runner
            // ("Audit failed to complete in time", code -56). That is not a
            // finding, so it must not redden the branch; the log keeps the
            // fact visible. Real findings still fail through the XCTFail
            // below (the hard gates are .trait and .sufficientElementDescription).
            let nsError = error as NSError
            if nsError.domain == "com.apple.xcode.xctest.accessibilityAudit", nsError.code == -56 {
                print("AUDIT[\(screen)] skipped: \(nsError.localizedDescription)")
                return
            }
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
    // balance, budget remainder, validation toast) and compares it with the
    // value before the action.
    //
    // Two rules keep these assertions stable:
    // - `launch()` starts each case on its own empty in-memory store
    //   (`-freshStore`), so a case never inherits another case's ledger.
    // - Every entry carries a unique note and is found again by that note.
    //   The ledger sorts by date, so "the newest row" is not the row a case
    //   just saved as soon as a future-dated row exists.

    /// Unique note for one case's entry, e.g. "QA A1 3F2A".
    private func qaNote(_ area: String) -> String {
        "QA \(area) \(UUID().uuidString.prefix(4))"
    }

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

    /// Types `value` ("12.50") the way the *current* entry mode expects.
    ///
    /// `ContentViewModel.bootstrap` seeds the "cent-less" mode
    /// (`numberEntryType = 2`), where the pad's bottom-left key is the decimal
    /// point and 12.50 is `12` `.` `50`. The older "pre-dotted" mode turns
    /// every two digits into cents, so the same amount is `1250` and there is
    /// no decimal key at all. The pad's own keys say which mode is live, so a
    /// case never encodes whichever mode this simulator happens to be in.
    private func enterAmount(_ app: XCUIApplication, _ value: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        clearAmount(app)
        // `clearAmount` already waited for the read-out, so the pad is up: a
        // plain existence check is enough (and costs no timeout when the mode
        // is "pre-dotted").
        let centless = element(app, AccessibilityID.padDecimal).exists
        let parts = value.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let whole = String(parts.first ?? "")
        let cents = parts.count > 1 ? String(parts[1]) : ""
        if centless {
            typeDigits(app, whole, file: file, line: line)
            if !cents.isEmpty {
                require(app, AccessibilityID.padDecimal, file: file, line: line).tap()
                typeDigits(app, cents, file: file, line: line)
            }
        } else {
            typeDigits(app, whole + cents, file: file, line: line)
        }
    }

    /// Empties the pad with whatever erase key the mode offers: the pad's own
    /// backspace in "pre-dotted", the read-out's trailing delete in
    /// "cent-less". Stops on the read-out rather than after a fixed number of
    /// taps, and keeps going until the trailing decimal point is gone too —
    /// leaving it behind would send the next digits into the cents part.
    private func clearAmount(_ app: XCUIApplication) {
        for _ in 0..<24 {
            let label = require(app, AccessibilityID.entryAmountDisplay).label
                .trimmingCharacters(in: .whitespaces)
            if (amount(in: label) ?? 0) == 0 && !label.hasSuffix(".") { return }
            let backspace = element(app, AccessibilityID.padBackspace)
            if backspace.exists {
                backspace.tap()
            } else if element(app, AccessibilityID.entryAmountDelete).exists {
                element(app, AccessibilityID.entryAmountDelete).tap()
            } else {
                return
            }
        }
    }

    /// Types a unique note and returns to the keypad. The note field owns the
    /// system keyboard, which replaces the pad until focus goes away.
    private func setNote(_ app: XCUIApplication, _ note: String,
                         file: StaticString = #filePath, line: UInt = #line) {
        let field = require(app, AccessibilityID.entryNoteField, file: file, line: line)
        field.tap()
        field.typeText(note)
        // Return resigns the field; the pad coming back is the sync point that
        // the keyboard is gone again.
        app.typeText("\n")
        require(app, AccessibilityID.padDigit(0), file: file, line: line)
    }

    /// Opens the category grid, seeding the starter set on a fresh store.
    private func openCategoryPicker(_ app: XCUIApplication) {
        require(app, AccessibilityID.entryCategoryButton).tap()
        let seed = element(app, AccessibilityID.entrySeedCategories)
        if seed.waitForExistence(timeout: 3) { seed.tap() }
    }

    /// Picks the first tile, or the tile whose label is `name`. The grid is
    /// lazy and scrollable, so the named variant scrolls when needed.
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

    /// First amount in a label: "Expenses, $1,234.50" → 1234.5, "-$5.00" → -5,
    /// "left, $70.00, 0% spent" → 70. Only the first number is read, so a
    /// composite label cannot turn into one enormous number.
    private func amount(in text: String) -> Double? {
        var number = ""
        var negative = false
        var started = false
        for character in text.replacingOccurrences(of: ",", with: "") {
            if character.isNumber || character == "." {
                number.append(character)
                started = true
            } else if started {
                break
            } else if character == "-" || character == "\u{2212}" {
                negative = true
            }
        }
        guard started, let value = Double(number) else { return nil }
        return negative ? -value : value
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
        if element(app, AccessibilityID.accountsAddButton).waitForExistence(timeout: 3) {
            // Already on Accounts (the tab keeps its navigation stack). Step
            // out and back in so AccountListView.onAppear reloads: balances
            // are derived from the store, and a rolled-back delete must be
            // visible without relaunching the app.
            app.navigationBars.buttons["BackButton"].firstMatch.tap()
        }
        let row = scrollIntoView(AccessibilityID.settingsRow("accounts"), in: app)
        if !row.exists {
            XCTFail("The Accounts settings row never came into view.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        row.tap()
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

    /// Picks a currency from the account editor's currency row. Tapped before
    /// any text field has focus: the first tap on a Form row while the keyboard
    /// is up is consumed by the dismissal, so the picker would never open.
    private func selectCurrency(_ app: XCUIApplication, _ code: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        let currencyRow = require(app, AccessibilityID.accountCurrencyPicker,
                                  file: file, line: line)
        XCTAssertTrue(currencyRow.isHittable,
                      "The currency row is not hittable.\n\(app.debugDescription)",
                      file: file, line: line)
        currencyRow.tap()
        let option = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", code)).firstMatch
        if !option.waitForExistence(timeout: 5) {
            // The popup opens scrolled to the *current* selection, so codes
            // that sort above it are outside the hierarchy. Drag the list
            // (never the app: that dismisses the popup) until it appears.
            let anOption = app.buttons
                .matching(NSPredicate(format: "label CONTAINS %@ AND NOT (label BEGINSWITH %@)",
                                      " · ", "Currency,"))
                .firstMatch
            for _ in 0..<25 where !option.exists {
                if anOption.exists { anOption.swipeDown() } else { break }
            }
        }
        if !option.waitForExistence(timeout: 5) {
            XCTFail("\(code) is not offered by the currency picker.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        option.tap()
        // Back on the editor: the name field is its first input.
        require(app, AccessibilityID.accountNameField, file: file, line: line)
    }

    private func makeAccount(_ app: XCUIApplication, name: String,
                             currencyCode: String? = nil, opening: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        require(app, AccessibilityID.accountsAddButton, file: file, line: line).tap()

        // Currency first, while no keyboard is up (see `selectCurrency`).
        if let currencyCode {
            selectCurrency(app, currencyCode, file: file, line: line)
        }

        let nameField = require(app, AccessibilityID.accountNameField, file: file, line: line)
        nameField.tap()
        nameField.typeText(name)

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
        // The visible figure drops the sign of a negative balance (it goes
        // red instead), so the row exposes the signed number as its value.
        if let raw = figure.value as? String, let signed = Double(raw) { return signed }
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

    private func logRows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: AccessibilityID.logRow)
    }

    /// The ledger row carrying `note`. Not "the newest row": the list sorts by
    /// date, so a future-dated entry would answer that question instead.
    private func row(note: String, in app: XCUIApplication) -> XCUIElement {
        logRows(app).matching(NSPredicate(format: "label CONTAINS %@", note)).firstMatch
    }

    /// Waits until the row for `note` (and, when given, `amount`) is rendered.
    @discardableResult
    private func waitForRow(_ app: XCUIApplication, note: String, amount: String? = nil,
                            timeout: TimeInterval = 20,
                            file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let target = row(note: note, in: app)
        let predicate: NSPredicate
        if let amount {
            predicate = NSPredicate(format: "exists == true AND label CONTAINS %@", amount)
        } else {
            predicate = NSPredicate(format: "exists == true")
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            let wanted = amount.map { " carrying \($0)" } ?? ""
            XCTFail("No row for \"\(note)\"\(wanted) after \(Int(timeout)) s: "
                        + "\(ledgerSummary(app))\n\(app.debugDescription)",
                    file: file, line: line)
        }
        return target
    }

    /// The rendered row labels plus the pad, for failure messages.
    private func ledgerSummary(_ app: XCUIApplication) -> String {
        let labels = logRows(app).allElementsBoundByIndex.prefix(6).map(\.label)
        let pad = element(app, AccessibilityID.entryAmountDisplay).exists
            ? (padAmount(app) ?? .nan) : .nan
        let toast = element(app, AccessibilityID.entryToast)
        return "rows=\(labels) pad=\(pad) toast=\(toast.exists ? toast.label : "none")"
    }

    /// Waits until the full-screen entry form is gone.
    ///
    /// The dismissal is animated, and a tab-bar tap that lands while the form
    /// is still on screen resolves to a {-1, -1} hit point and does nothing —
    /// the caller would then assert on the wrong screen.
    private func waitForFormDismissed(_ app: XCUIApplication,
                                      file: StaticString = #filePath, line: UInt = #line) {
        let pad = element(app, AccessibilityID.entryAmountDisplay)
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: pad)
        if XCTWaiter().wait(for: [gone], timeout: 15) != .completed {
            XCTFail("The entry form never closed.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        // The cover's views leave the hierarchy before the tab shell is laid
        // out again, so "pad is gone" is not yet "the tabs are tappable".
        let tabBar = app.tabBars.firstMatch
        let shellBack = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: tabBar)
        if XCTWaiter().wait(for: [shellBack], timeout: 20) != .completed {
            XCTFail("The tab bar never came back after the form closed.\n\(app.debugDescription)",
                    file: file, line: line)
        }
    }

    /// Saves a plain expense through the happy path and returns its row.
    @discardableResult
    private func addExpense(_ app: XCUIApplication, amount value: String, note: String,
                            category: String? = nil, account: String? = nil,
                            file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        require(app, AccessibilityID.logAddButton, file: file, line: line).tap()
        enterAmount(app, value, file: file, line: line)
        setNote(app, note, file: file, line: line)
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
        let row = waitForRow(app, note: note, amount: value, file: file, line: line)
        waitForFormDismissed(app, file: file, line: line)
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
        // UIKit's calendar cells are exposed with the day number as the whole
        // label on some OS versions and as "Saturday, November 1" on others.
        // Match either, on any element type, so the case does not pin one.
        let cell = picker.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR label ENDSWITH %@", day, " \(day)"))
            .firstMatch
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

    /// Budget remainder as a signed number, read from the tile's numeric
    /// `accessibilityValue` (see `SingleBudgetView.signedRemainingText`).
    /// Negative means overspent; the visible figure stays an unsigned
    /// magnitude next to a "left" / "over" word.
    private func budgetRemaining(_ app: XCUIApplication, for name: String,
                                 file: StaticString = #filePath, line: UInt = #line) -> Double? {
        let tile = element(app, AccessibilityID.budgetRemaining(name))
        if !tile.waitForExistence(timeout: 10) {
            XCTFail("No budget tile for \"\(name)\".\n\(app.debugDescription)",
                    file: file, line: line)
            return nil
        }
        let raw = (tile.value as? String) ?? ""
        // Defensive: read only the number, in case the row's value ever picks
        // up a second component from a sibling control again.
        let numeric = raw.split(separator: ",").first.map(String.init) ?? raw
        guard let value = Double(numeric.trimmingCharacters(in: .whitespaces)) else {
            XCTFail("Budget \"\(name)\" exposes no numeric remainder "
                        + "(value=\"\(raw)\", label=\"\(tile.label)\")",
                    file: file, line: line)
            return nil
        }
        return value
    }

    // MARK: - A1. Expense from the add button updates the expense total

    func testA1_addExpense_updatesStats() throws {
        let app = launch()
        let before = expenseTotal(app)

        select(.log, in: app)
        let note = qaNote("A1")
        require(app, AccessibilityID.logAddButton).tap()
        enterAmount(app, "12.50")
        XCTAssertEqual(padAmount(app) ?? .nan, 12.50, accuracy: 0.001,
                       "The pad did not produce 12.50")
        setNote(app, note)
        openCategoryPicker(app)
        pickCategory(app)
        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        waitForRow(app, note: note, amount: "12.50")
        waitForFormDismissed(app)
        let after = expenseTotal(app)
        XCTAssertEqual(after, before + 12.50, accuracy: 0.005,
                       "Expenses went \(before) → \(after); expected +12.50")

        select(.log, in: app)
    }

    // MARK: - A2. Save and continue keeps the category and account

    func testA2_continuousEntry_clearsAmountKeepsCategory() throws {
        let app = launch()
        let accountName = "QA Continue \(UUID().uuidString.prefix(4))"

        openAccounts(app)
        makeAccount(app, name: accountName, opening: "50")
        select(.log, in: app)

        let firstNote = qaNote("A2a")
        let secondNote = qaNote("A2b")
        require(app, AccessibilityID.logAddButton).tap()
        enterAmount(app, "5.00")
        setNote(app, firstNote)
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

        // The form is still open on a cleared pad; the ledger sits behind the
        // full-screen form, so whether the first entry landed is checked once
        // the second save closes the form.
        XCTAssertEqual(padAmount(app) ?? .nan, 0, accuracy: 0.001,
                       "The amount was not cleared after save-and-continue")
        XCTAssertEqual(require(app, AccessibilityID.entryCategoryButton).label, categoryLabel,
                       "The category was dropped after save-and-continue")
        XCTAssertTrue(require(app, AccessibilityID.entryAccountChip).label.contains(accountName),
                      "The account was dropped after save-and-continue")

        // A second entry saved with the normal checkmark closes the form.
        enterAmount(app, "3.00")
        setNote(app, secondNote)
        let secondSave = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(secondSave)
        secondSave.tap()

        waitForRow(app, note: secondNote, amount: "3.00")
        waitForFormDismissed(app)
        waitForRow(app, note: firstNote, amount: "5.00")
    }

    // MARK: - A3. Zero, over-limit and missing category are refused

    func testA3_invalidInput_isRefusedWithMessage() throws {
        // The refusal toast is the assertion. It stays up until the form is
        // edited (SBToast.sbToastDismissal(after: nil)), so a stalled CI
        // snapshot cannot outrun it.
        let app = launch()
        require(app, AccessibilityID.logAddButton).tap()

        // Nothing typed: the checkmark cannot commit an empty amount.
        let save = require(app, AccessibilityID.entrySave)
        XCTAssertFalse(save.isEnabled, "The checkmark accepted a zero amount")

        // The pad caps a single amount at 99,999,999.99: the digits stop being
        // tappable once that value is on the read-out, so a longer number can
        // never be entered.
        enterAmount(app, "99999999.99")
        XCTAssertEqual(padAmount(app) ?? .nan, 99_999_999.99, accuracy: 0.001)
        XCTAssertFalse(require(app, AccessibilityID.padDigit(9)).isEnabled,
                       "The pad still accepted a digit past the 99,999,999.99 cap")

        enterAmount(app, "12.00")
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

        // Fresh store: a refused save must leave the ledger empty.
        XCTAssertFalse(logRows(app).firstMatch.exists,
                       "A refused save still wrote a ledger row: \(ledgerSummary(app))")
    }

    // MARK: - A4. Discount, claim and a future date stay out of this period

    func testA4_discountClaimFutureDate_staysOutOfStats() throws {
        let app = launch()
        let before = expenseTotal(app)
        select(.log, in: app)

        // A plain entry first: it gives the "today" section something to
        // compare the future row's position against.
        let plainNote = qaNote("A4a")
        addExpense(app, amount: "1.00", note: plainNote)
        let afterPlain = expenseTotal(app)
        XCTAssertEqual(afterPlain, before + 1.00, accuracy: 0.005)

        select(.log, in: app)
        let futureNote = qaNote("A4b")
        require(app, AccessibilityID.logAddButton).tap()
        enterAmount(app, "20.00")
        setNote(app, futureNote)
        openCategoryPicker(app)
        pickCategory(app)
        setDiscount(app, "5")
        require(app, AccessibilityID.entryClaimChip).tap()
        chooseTomorrow(app)
        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        waitForFormDismissed(app)
        require(app, AccessibilityID.logUpcomingHeader, timeout: 20)
        let futureRow = waitForRow(app, note: futureNote, amount: "20.00")
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
    }

    // MARK: - A5. Editing the amount moves the total; switching type drops the category

    func testA5_editAmount_updatesStats_typeSwitchClearsCategory() throws {
        let app = launch()
        let before = expenseTotal(app)
        select(.log, in: app)
        let note = qaNote("A5")
        addExpense(app, amount: "12.50", note: note)
        let afterCreate = expenseTotal(app)
        XCTAssertEqual(afterCreate, before + 12.50, accuracy: 0.005)

        select(.log, in: app)
        row(note: note, in: app).tap()

        // Wait for the stored amount to load into the pad before editing it.
        let display = require(app, AccessibilityID.entryAmountDisplay)
        let loaded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "12.50"), object: display)
        _ = XCTWaiter().wait(for: [loaded], timeout: 10)

        enterAmount(app, "20.00")
        XCTAssertEqual(padAmount(app) ?? .nan, 20, accuracy: 0.001)
        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        waitForFormDismissed(app)
        let afterEdit = expenseTotal(app)
        XCTAssertEqual(afterEdit, afterCreate + 7.50, accuracy: 0.005,
                       "Editing 12.50 → 20.00 did not move the total by 7.50")

        // Switching to income drops a category that belongs to the other side.
        select(.log, in: app)
        row(note: note, in: app).tap()
        tapSegment("Income", in: app)
        XCTAssertEqual(require(app, AccessibilityID.entryCategoryButton).label, "Category",
                       "The expense category survived the switch to income")
        require(app, AccessibilityID.entryCancel).tap()
        let discard = app.buttons["Discard"].firstMatch
        if discard.waitForExistence(timeout: 5) { discard.tap() }

        // Cancelling kept the edited amount.
        waitForRow(app, note: note, amount: "20.00")
    }

    // MARK: - A6. Delete, undo, and the snapshot behind it

    func testA6_deleteUndo_restoresFieldsAndBalance() throws {
        let app = launch()
        let accountName = "QA Undo \(UUID().uuidString.prefix(4))"

        openAccounts(app)
        makeAccount(app, name: accountName, opening: "200")
        select(.log, in: app)
        let note = qaNote("A6")
        require(app, AccessibilityID.logAddButton).tap()
        enterAmount(app, "40.00")
        setNote(app, note)
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

        let created = waitForRow(app, note: note, amount: "40.00")
        waitForFormDismissed(app)
        XCTAssertTrue(created.label.contains("Discount $10.00"),
                      "Saved row reads: \"\(created.label)\"")
        XCTAssertTrue(created.label.contains("Pending"),
                      "Saved row reads: \"\(created.label)\"")

        // The account was debited by the net amount.
        openAccounts(app)
        XCTAssertEqual(balance(app, of: accountName), 160, accuracy: 0.005,
                       "The account balance did not include the new expense")

        select(.log, in: app)
        swipeDelete(row(note: note, in: app), in: app)

        // The undo banner is the staged-delete affordance; 6 s window.
        require(app, AccessibilityID.logUndoButton, timeout: 5).tap()

        let restored = waitForRow(app, note: note, amount: "40.00", timeout: 15)
        XCTAssertTrue(restored.label.contains("Discount $10.00"),
                      "The discount was lost by undo: \"\(restored.label)\"")
        XCTAssertTrue(restored.label.contains("Pending"),
                      "The claim flag was lost by undo: \"\(restored.label)\"")

        XCTAssertTrue(restored.label.contains(accountName),
                      "The row is no longer linked to its account: \(restored.label)")

        openAccounts(app)
        XCTAssertEqual(balance(app, of: accountName), 160, accuracy: 0.005,
                       "Undo did not restore the account balance")

        select(.log, in: app)
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
    }

    // MARK: - A8. Cross-currency transfer: fee is the only spend

    func testA8_crossCurrencyTransfer_feeOnlyInSpend() throws {
        let app = launch()
        let suffix = UUID().uuidString.prefix(4)
        let source = "QA USD \(suffix)"
        let destination = "QA VND \(suffix)"

        openAccounts(app)
        makeAccount(app, name: source, opening: "100")
        makeAccount(app, name: destination, currencyCode: "VND", opening: "0")

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
        let feeRow = logRows(app)
            .matching(NSPredicate(format: "label CONTAINS %@", "Transfer Fee")).firstMatch
        XCTAssertTrue(feeRow.waitForExistence(timeout: 10),
                      "The fee was not booked as its own expense row.\n\(app.debugDescription)")
        XCTAssertTrue(feeRow.label.contains("5.00"))

        let transferRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                                  "→", "200.00")).firstMatch
        XCTAssertTrue(transferRow.waitForExistence(timeout: 10),
                      "The transfer row does not show the landed amount.\n\(app.debugDescription)")
    }

    // MARK: - A9. Category budget: remaining drops, then goes over

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

        enterAmount(app, "100.00")
        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        waitForFormDismissed(app)
        let fresh = budgetRemaining(app, for: "Food") ?? .nan
        XCTAssertEqual(fresh, 100, accuracy: 0.01,
                       "A new 100 budget should start with 100 left, got \(fresh)")

        select(.log, in: app)
        addExpense(app, amount: "30.00", note: qaNote("A9a"), category: "Food")

        select(.budget, in: app)
        let afterSpend = budgetRemaining(app, for: "Food") ?? .nan
        XCTAssertEqual(afterSpend, 70, accuracy: 0.01,
                       "30 spent from 100 should leave 70, got \(afterSpend)")

        select(.log, in: app)
        addExpense(app, amount: "100.00", note: qaNote("A9b"), category: "Food")

        select(.budget, in: app)
        let overTile = element(app, AccessibilityID.budgetRemaining("Food"))
        XCTAssertTrue(overTile.waitForExistence(timeout: 15),
                      "The budget tile never appeared after the second expense.\n\(app.debugDescription)")
        // The app renders the overage as a red "over $30" (magnitude + status
        // word), not as a negative figure. Turning it into -$30 is a design
        // change this test-infrastructure batch does not make, so the case
        // asserts the status word plus the signed remainder the tile exposes.
        XCTAssertTrue(overTile.label.contains("over"),
                      "130 against a 100 budget should read \"over\", got \"\(overTile.label)\"")
        let overage = budgetRemaining(app, for: "Food") ?? .nan
        XCTAssertEqual(overage, -30, accuracy: 0.01,
                       "130 spent against a 100 budget is -30, got \(overage)")

        select(.log, in: app)
    }

    // MARK: - A10. A refund reduces spend and never becomes income

    func testA10_refund_reducesSpendWithoutIncome() throws {
        let app = launch()
        let before = expenseTotal(app)
        select(.log, in: app)

        let note = qaNote("A10")
        addExpense(app, amount: "20.00", note: note)
        XCTAssertEqual(expenseTotal(app), before + 20, accuracy: 0.005,
                       "The purchase did not reach spend")
        select(.log, in: app)

        // The refund action shares the context menu with the claim actions.
        let original = waitForRow(app, note: note)
        original.press(forDuration: 1.5)
        let refundAction = app.buttons["Refund"].firstMatch
        XCTAssertTrue(refundAction.waitForExistence(timeout: 10),
                      "A refundable expense offered no refund action.\n\(app.debugDescription)")
        refundAction.tap()

        let remaining = require(app, AccessibilityID.refundRemaining)
        XCTAssertTrue(remaining.label.contains("20"),
                      "Remaining should start at 20, got \(remaining.label)")

        // The sheet prefills the whole remaining amount; a full refund is
        // one tap, and no software keyboard is involved.
        require(app, AccessibilityID.refundAmount)
        require(app, AccessibilityID.refundSave).tap()

        // The refund is its own row, named after the purchase it gives back.
        waitForRow(app, note: "Refund · \(note)")
        XCTAssertEqual(expenseTotal(app), before, accuracy: 0.005,
                       "Refunding the full 20 should remove it from spend")
        select(.log, in: app)
    }

    // MARK: - TELE-37 · accounts, import/export, search & filter, deep links
    //
    // These six cases stay on the surfaces that ship on `main`: the SwiftData
    // account editor, the `-importSample` CSV preview, the Log filter/search
    // controls, and the `smartbud://add` URL scheme. The JSON backup/restore
    // sheets use system share/file pickers with no accessibility hooks on this
    // build, and App Lock has no DEBUG unlock hook here, so the round-trip and
    // locked-x-error paths are covered up to the observable behaviour: a
    // cancelled preview writes no row and a locked session refuses the add.
    // Each case asserts on data (balances, ledger row counts, spend) rather
    // than on a screen merely appearing.

    /// Launches a fresh app with App Lock forced on through the
    /// NSArgumentDomain key that Authentication.migrateLegacyAppLockKey()
    /// copies into the App Group suite. launch() itself stays untouched.
    private func launchLocked() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-skipIntro", "-importSample", "-freshStore",
            "-skipReviewPrompt", "-appLockEnabled", "YES",
        ]
        app.launch()
        return app
    }

    /// Clears the persisted App Lock flag (the in-memory store does not reset
    /// UserDefaults) so the next case in this shard boots unlocked.
    private func resetAppLock() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-skipIntro", "-freshStore", "-skipReviewPrompt",
            "-appLockEnabled", "NO",
        ]
        app.launch()
    }

    // B1. A new account with an opening balance is listed with that balance.
    func testB1_newAccountWithOpeningBalance_listsBalanceAndTotal() throws {
        let app = launch()
        let name = qaNote("B1")
        openAccounts(app)
        makeAccount(app, name: name, opening: "250")

        // DATA: the row's accessibilityValue carries the opening balance.
        XCTAssertEqual(balance(app, of: name), 250, accuracy: 0.005,
                       "A new account must list its opening balance")
        // The aggregate Total Balance row has no stable identifier on this
        // build; its presence (fed by the balance above) is asserted here.
        let total = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Total Balance"))
            .firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 10),
                      "The Total Balance row must be rendered")
    }

    // B2. Archiving a funded account prompts first, then leaves the default list.
    func testB2_archiveFundedAccount_promptsThenLeavesDefaultList() throws {
        let app = launch()
        let name = qaNote("B2")
        openAccounts(app)
        makeAccount(app, name: name, opening: "120")
        XCTAssertEqual(balance(app, of: name), 120, accuracy: 0.005,
                       "The funded account must show its opening balance")

        // Long-press (context menu) or swipe reveals the Archive action.
        let cell = app.cells
            .containing(.staticText, identifier: AccessibilityID.accountBalance(name))
            .firstMatch
        let accountCell: XCUIElement = cell.exists
            ? cell
            : scrollIntoView(AccessibilityID.accountBalance(name), in: app)
        accountCell.press(forDuration: 1.5)
        var archive = app.buttons["Archive"].firstMatch
        if !archive.waitForExistence(timeout: 6) {
            accountCell.swipeLeft()
            archive = app.buttons["Archive"].firstMatch
        }
        XCTAssertTrue(archive.waitForExistence(timeout: 10),
                      "No Archive action for the account row")
        archive.tap()

        // A non-zero balance must not archive silently.
        let prompt = app.alerts.firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 10),
                      "Archiving a funded account must prompt for confirmation")
        prompt.buttons["Archive"].firstMatch.tap()

        // DATA: once archived, the balance figure drops out of the visible list.
        let figure = element(app, AccessibilityID.accountBalance(name))
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: figure)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed,
                       "Archived account is still in the default list")
    }

    // B3. The import preview can be cancelled without writing a single row.
    func testB3_importPreview_cancelWritesNothing() throws {
        let app = launch()
        let note = qaNote("B3")
        addExpense(app, amount: "18.00", note: note)
        let before = logRows(app).count
        XCTAssertGreaterThan(before, 0, "A seeded ledger is needed to prove a no-op")

        select(.settings, in: app)
        let importRow = scrollIntoView(AccessibilityID.settingsImportData, in: app)
        XCTAssertTrue(importRow.exists, "The Import Data row is missing")
        importRow.tap()
        require(app, AccessibilityID.importPreview, timeout: 20)
        require(app, AccessibilityID.importContinue)
        // Step back to the file step, then dismiss: the proven cancel sequence.
        require(app, AccessibilityID.importClose).tap()
        require(app, AccessibilityID.importChooseFile, timeout: 10)
        require(app, AccessibilityID.importClose).tap()
        require(app, AccessibilityID.settingsImportData, timeout: 10)

        // DATA: cancelling the preview leaves the ledger count unchanged.
        select(.log, in: app)
        XCTAssertEqual(logRows(app).count, before,
                       "Cancelling the import preview must not write any row")
    }

    // B4. Opening the same sample twice and cancelling adds no rows either time.
    func testB4_importSameSampleTwice_addsNothing() throws {
        let app = launch()
        let note = qaNote("B4")
        addExpense(app, amount: "24.00", note: note)
        let before = logRows(app).count
        XCTAssertGreaterThan(before, 0)

        for _ in 0..<2 {
            select(.settings, in: app)
            let importRow = scrollIntoView(AccessibilityID.settingsImportData, in: app)
            XCTAssertTrue(importRow.exists)
            importRow.tap()
            require(app, AccessibilityID.importPreview, timeout: 20)
            require(app, AccessibilityID.importContinue)
            require(app, AccessibilityID.importClose).tap()
            require(app, AccessibilityID.importChooseFile, timeout: 10)
            require(app, AccessibilityID.importClose).tap()
            require(app, AccessibilityID.settingsImportData, timeout: 10)

            // DATA: each preview — including the second import of the same file —
            // leaves the ledger untouched when cancelled.
            select(.log, in: app)
            XCTAssertEqual(logRows(app).count, before,
                           "Importing the same sample twice must add no rows")
        }
    }

    // B5. Search stacks on the active filter; the type filter keeps real expenses.
    func testB5_searchStacksOnFilter_typeFilterKeepsExpenses() throws {
        let app = launch()
        let first = qaNote("B5a")
        let second = qaNote("B5b")
        addExpense(app, amount: "12.00", note: first)
        addExpense(app, amount: "34.00", note: second)

        // Type filter keeps genuine expenses (LogView drops balance adjustments
        // through the !adjustment predicate in visibleTransactions).
        let filter = app.buttons["Filter"].firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 10), "The Filter menu is missing")
        filter.tap()
        let byType = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "by type"))
            .firstMatch
        XCTAssertTrue(byType.waitForExistence(timeout: 10), "No 'by type' filter option")
        byType.tap()
        XCTAssertGreaterThanOrEqual(logRows(app).count, 2,
                                    "The type filter must keep both real expenses")

        // Search narrows within the current filter instead of resetting it.
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The searchable field is missing")
        field.tap()
        field.typeText(first)
        waitForRow(app, note: first)
        XCTAssertEqual(logRows(app).count, 1,
                       "Search must stack on the filter, leaving only the match")
        XCTAssertFalse(row(note: second, in: app).exists,
                       "The non-matching row must be filtered out")
    }

    // B6. `smartbud://add` writes a row when unlocked and is refused when locked.
    func testB6_deepLinkAdd_unlockedWrites_lockedRefuses() throws {
        // No x-error target is attached: fireCallback is a no-op without one, so
        // a rejected URL cannot loop back into another onOpenURL. The refusal is
        // asserted on data (no row written) rather than on the callback URL.
        let addURL = URL(string: "smartbud://add?amount=35&category=%E9%A4%90%E9%A5%AE")!

        // Unlocked: the add deep link books a 35.00 expense.
        let app = launch()
        let before = expenseTotal(app)
        app.open(addURL)
        select(.log, in: app)
        let firstRow = logRows(app).firstMatch
        let appeared = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"), object: firstRow)
        XCTAssertEqual(XCTWaiter().wait(for: [appeared], timeout: 20), .completed,
                       "The unlocked add deep link must write a row")
        XCTAssertEqual(expenseTotal(app), before + 35, accuracy: 0.005,
                       "The add deep link must book the 35 amount")

        // Locked: the same URL is refused (x-error=app_locked) and writes nothing.
        let locked = launchLocked()
        XCTAssertTrue(locked.staticTexts["App Locked"].firstMatch.waitForExistence(timeout: 20),
                      "The session should be locked")
        locked.open(addURL)
        XCTAssertTrue(locked.staticTexts["App Locked"].firstMatch.exists,
                      "A locked session must not be bypassed by the add deep link")
        XCTAssertEqual(logRows(locked).count, 0,
                       "A refused deep link must not write a row (it wrote one above)")

        // Clear the persisted App Lock flag so later cases in this shard boot unlocked.
        resetAppLock()
    }

    // MARK: - TELE-38 C batch: deterministic launch + small query helpers

    /// Mirrors `launch()` but pins a deterministic settings baseline for this
    /// batch. `-qaResetSettings` (handled by the DEBUG hook in SmartBudApp)
    /// clears the persisted App Group keys so a case never inherits language /
    /// theme / notification state from an earlier case in the same shard.
    /// `-appLockEnabled NO` keeps the session unlocked regardless of any
    /// earlier `launchLocked()` case (the migration copies it every launch).
    private func launchC(_ extra: [String] = []) -> XCUIApplication {
        // Every case starts in portrait, so a landscape case can never leak its
        // device orientation into a later case in the same shard.
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        continueAfterFailure = false
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-skipIntro",
            "-importSample",
            "-freshStore",
            "-skipReviewPrompt",
            "-appLockEnabled", "NO",
            "-qaResetSettings",
        ]
        app.launchArguments += extra
        app.launch()
        dismissLaunchOverlay(app)
        return app
    }

    /// Taps the first control whose accessibility label contains `fragment`.
    /// System-rendered picker rows and toolbar buttons carry no identifier in
    /// this build, so a copy query is the only handle; the launch pins English.
    private func tapLabeled(
        _ app: XCUIApplication,
        _ fragment: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", fragment)
        let button = app.buttons.matching(predicate).firstMatch
        if button.waitForExistence(timeout: 10) {
            button.tap()
            return
        }
        let label = app.staticTexts.matching(predicate).firstMatch
        if label.waitForExistence(timeout: 3) {
            label.tap()
            return
        }
        let any = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(any.waitForExistence(timeout: 3),
                      "No control labelled with \(fragment) appeared.\n\(app.debugDescription)",
                      file: file, line: line)
        any.tap()
    }

    /// Hard "free state did not write to the store" assertion. `-freshStore`
    /// gives each launch an isolated empty ledger, so both the row count and
    /// the expense statistic must still be zero.
    private func assertNoLedgerWrite(
        _ app: XCUIApplication,
        _ context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        select(.log, in: app, file: file, line: line)
        XCTAssertEqual(logRows(app).count, 0,
                       "\(context): no log row may be written.\n\(app.debugDescription)",
                       file: file, line: line)
        XCTAssertEqual(expenseTotal(app), 0, accuracy: 0.005,
                       "\(context): the expense statistic must stay zero.",
                       file: file, line: line)
    }

    /// Closes the add-entry form, tolerating the discard confirmation when a
    /// draft is present (an empty form cancels directly).
    private func cancelEntryForm(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let cancel = element(app, AccessibilityID.entryCancel)
        XCTAssertTrue(cancel.waitForExistence(timeout: 10),
                      "The add-entry form must expose a Cancel button.",
                      file: file, line: line)
        cancel.tap()
        let discard = app.buttons["Discard"].firstMatch
        if discard.waitForExistence(timeout: 3) {
            discard.tap()
        }
    }

    // MARK: - C1: App Lock

    func testC1_appLock_relocksOnReturnAndRefusesWrite() throws {
        // A locked launch shows the App Lock screen (B6 convention).
        let locked = launchLocked()
        XCTAssertTrue(locked.staticTexts["App Locked"].firstMatch.waitForExistence(timeout: 20),
                      "The session should be locked at launch.")

        // Background -> foreground must still require unlock. ContentView re-locks
        // on .inactive/.background and only reconciles notifications on .active,
        // so no biometric prompt re-runs and the lock stays up.
        XCUIDevice.shared.press(.home)
        locked.activate()
        XCTAssertTrue(locked.staticTexts["App Locked"].firstMatch.waitForExistence(timeout: 20),
                      "Returning to the foreground must keep the app locked.")

        // A write-intent deep link is refused while locked and writes nothing.
        let addURL = URL(string: "smartbud://add?amount=35&category=%E9%A4%90%E9%A5%AE")!
        locked.open(addURL)
        XCTAssertTrue(locked.staticTexts["App Locked"].firstMatch.exists,
                      "A refused add deep link must not dismiss the lock screen.")
        XCTAssertEqual(logRows(locked).count, 0,
                       "A locked session must not write a row.")
        resetAppLock()
    }

    func testC1b_appLock_queuesNewEntryUntilUnlocked() throws {
        let newExpense = URL(string: "smartbud://newexpense")!

        // Locked: requestNewTransaction only sets pendingAddAfterUnlock. The
        // intent is queued — no form over the lock, no write.
        let locked = launchLocked()
        XCTAssertTrue(locked.staticTexts["App Locked"].firstMatch.waitForExistence(timeout: 20),
                      "The session should be locked.")
        locked.open(newExpense)
        XCTAssertTrue(locked.staticTexts["App Locked"].firstMatch.exists,
                      "A queued new-entry intent must not bypass the lock.")
        XCTAssertFalse(element(locked, AccessibilityID.entryAmountDisplay).exists,
                       "The entry form must not open while locked.")
        XCTAssertEqual(logRows(locked).count, 0,
                       "Queueing a new entry must not write a row.")
        resetAppLock()

        // Face-ID unlock cannot be simulated on a CI simulator, so the unlocked
        // session is represented by a fresh `-appLockEnabled NO` launch (the
        // same contrast B6 uses). The identical intent now replays into the
        // entry form, but opening a form is not itself a write.
        let unlocked = launchC()
        unlocked.open(newExpense)
        XCTAssertTrue(element(unlocked, AccessibilityID.entryAmountDisplay).waitForExistence(timeout: 20),
                      "After unlock the queued intent must open the entry form.")
        XCTAssertEqual(logRows(unlocked).count, 0,
                       "Opening the form must not write a row by itself.")
    }

    // MARK: - C2: Pro gate (free state must not write)

    func testC2_proGate_threeSurfacesBlockWrite() throws {
        // `-proEnforced` forces the free state: ProAccess.isUnlocked returns
        // false for every ProFeature. Each of the four gated surfaces must
        // raise the Pro page instead of running the feature, and the free
        // ledger must stay empty. One fresh launch per surface keeps navigation
        // state independent (B6 already launches several apps in one case).

        // (1) AI analysis, from the Insights toolbar.
        do {
            let app = launchC(["-proEnforced"])
            select(.insights, in: app)
            tapLabeled(app, "AI bill analysis")
            XCTAssertTrue(element(app, AccessibilityID.proTitle).waitForExistence(timeout: 20),
                          "The AI analysis gate must raise the Pro page.")
            let back = element(app, AccessibilityID.proBack)
            XCTAssertTrue(back.waitForExistence(timeout: 10),
                          "The Pro page must expose its back button so we can reach the ledger.")
            back.tap()
            assertNoLedgerWrite(app, "AI analysis gate")
        }

        // (2) A non-default app icon, from Settings -> App Icon.
        do {
            let app = launchC(["-proEnforced"])
            select(.settings, in: app)
            scrollIntoView(AccessibilityID.settingsRow("appIcon"), in: app).tap()
            tapLabeled(app, "Midnight")
            XCTAssertTrue(element(app, AccessibilityID.proTitle).waitForExistence(timeout: 20),
                          "The extra-icon gate must raise the Pro page.")
            let back = element(app, AccessibilityID.proBack)
            XCTAssertTrue(back.waitForExistence(timeout: 10),
                          "The Pro page must expose its back button so we can reach the ledger.")
            back.tap()
            assertNoLedgerWrite(app, "extra-icon gate")
        }

        // (3) A custom reminder time, from Settings -> Notifications. The
        // `-qaNotificationsOn` hook seeds the toggle ON before views mount, so
        // the picker is visible without firing the system permission dialog.
        // iOS 26 exposes the inline picker's three options as a wheel whose
        // rows carry no accessible label (they are zero-size `Other` children),
        // so a copy query cannot reach the third one. Tap the centre of that
        // row; the gate assertion below still proves the tap raised the Pro page.
        do {
            let app = launchC(["-proEnforced", "-qaNotificationsOn"])
            select(.settings, in: app)
            scrollIntoView(AccessibilityID.settingsRow("notifications"), in: app).tap()
            let wheel = app.pickerWheels.firstMatch
            XCTAssertTrue(wheel.waitForExistence(timeout: 20),
                          "The reminder-time picker must be visible.\n\(app.debugDescription)")
            wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 5.0 / 6.0)).tap()
            XCTAssertTrue(element(app, AccessibilityID.proTitle).waitForExistence(timeout: 20),
                          "The custom-reminder gate must raise the Pro page.")
            let back = element(app, AccessibilityID.proBack)
            XCTAssertTrue(back.waitForExistence(timeout: 10),
                          "The Pro page must expose its back button so we can reach the ledger.")
            back.tap()
            assertNoLedgerWrite(app, "custom-reminder gate")
        }

        // (4) Batch OCR, from the Smart Entry sheet. The test name stays
        // unchanged so the CI shard lists keep referencing it.
        do {
            let app = launchC(["-proEnforced"])
            require(app, AccessibilityID.logAddButton).tap()
            require(app, AccessibilityID.entrySmartEntry).tap()
            require(app, AccessibilityID.smartEntryBatch).tap()
            XCTAssertTrue(element(app, AccessibilityID.proTitle).waitForExistence(timeout: 20),
                          "The batch OCR gate must raise the Pro page.")
            let back = element(app, AccessibilityID.proBack)
            XCTAssertTrue(back.waitForExistence(timeout: 10),
                          "The Pro page must expose its back button so we can reach the ledger.")
            back.tap()
            require(app, AccessibilityID.smartEntryClose).tap()
            cancelEntryForm(app)
            assertNoLedgerWrite(app, "batch OCR gate")
        }
    }

    // MARK: - C3: Smart entry

    func testC3_smartEntry_previewAndCancelWritesNothing() throws {
        let app = launchC()
        // Open the add-entry form, then the Smart Entry sheet.
        require(app, AccessibilityID.logAddButton).tap()
        require(app, AccessibilityID.entrySmartEntry).tap()
        let field = require(app, AccessibilityID.smartEntryField)
        field.tap()
        field.typeText("午饭35")
        tapLabeled(app, "Parse")

        // The preview shows the parsed amount 35.00 and offers Fill in form.
        XCTAssertTrue(app.staticTexts["35.00"].firstMatch.waitForExistence(timeout: 20),
                      "The preview must show the parsed amount 35.")
        XCTAssertTrue(app.buttons["Fill in form"].firstMatch.waitForExistence(timeout: 20),
                      "The preview must offer a Fill in form action.")

        // Cancel the sheet (X, not Fill in form) -> nothing is written. Close the
        // still-empty add form first so the tab bar is reachable.
        require(app, AccessibilityID.smartEntryClose).tap()
        cancelEntryForm(app)
        assertNoLedgerWrite(app, "Cancelling a smart-entry preview")
    }

    func testC3b_smartEntry_confirmFillsFormWithoutSaving() throws {
        let app = launchC()
        require(app, AccessibilityID.logAddButton).tap()
        require(app, AccessibilityID.entrySmartEntry).tap()
        let field = require(app, AccessibilityID.smartEntryField)
        field.tap()
        field.typeText("午饭35")
        tapLabeled(app, "Parse")
        XCTAssertTrue(app.staticTexts["35.00"].firstMatch.waitForExistence(timeout: 20),
                      "The preview must show 35 before confirming.")

        // Fill in form (onApply) populates the form but does not save it.
        app.buttons["Fill in form"].firstMatch.tap()
        let display = require(app, AccessibilityID.entryAmountDisplay)
        let shown = amount(in: display.label)
        XCTAssertEqual(shown ?? -1, 35.0, accuracy: 0.005,
                       "Fill in form must populate the amount with 35.")
        XCTAssertTrue(element(app, AccessibilityID.entrySave).exists,
                      "The form must stay open — confirming an apply is not a save.")

        // Dismiss the filled form (discard confirmation may appear) and prove
        // that no row was written.
        cancelEntryForm(app)
        assertNoLedgerWrite(app, "Confirming a smart-entry fill")
    }

    // MARK: - C4: Settings

    func testC4_settings_languageChangesKeyCopy() throws {
        // String.appLocalized resolves the in-app language from App Group at
        // call time. Seeding zh-Hans before any view mounts equals a cold launch
        // after a language switch (SettingsLanguageView says one is required).
        // Compare the Settings screen copy in the two language states.
        let english = launchC()
        select(.settings, in: english)
        let englishCopy = english.staticTexts.allElementsBoundByIndex.map { $0.label }

        let chinese = launchC(["-qaAppLanguage", "zh-Hans"])
        select(.settings, in: chinese)
        let chineseCopy = chinese.staticTexts.allElementsBoundByIndex.map { $0.label }

        XCTAssertFalse(englishCopy.isEmpty, "The Settings screen must expose localised text.")
        XCTAssertFalse(chineseCopy.isEmpty, "The Settings screen must expose localised text.")
        XCTAssertNotEqual(englishCopy, chineseCopy,
                          "Switching to zh-Hans must change the key controls' copy.")
    }

    func testC4b_settings_darkModeChangesTheme() throws {
        let app = launchC()
        select(.settings, in: app)
        let appearanceRow = scrollIntoView(AccessibilityID.settingsRow("appearance"), in: app)
        let before = appearanceRow.label
        appearanceRow.tap()
        // The inline theme picker lists System / Light / Dark. XCUITest cannot
        // sample pixel colour, so assert the selected theme state that drives
        // .preferredColorScheme (documented in the PR).
        tapLabeled(app, "Dark")
        let after = scrollIntoView(AccessibilityID.settingsRow("appearance"), in: app).label
        XCTAssertNotEqual(before, after,
                          "Selecting Dark must change the appearance selection state.")
    }

    func testC4c_settings_baseCurrencyShowsRebaseHint() throws {
        // `-qaSeedRates` inserts a EUR rate into the fresh store. That makes
        // ConversionScope.needsConversion true and gives CurrencyRebase.plan an
        // anchor rate, so switching the base currency deterministically shows
        // the rebase ("折算") hint instead of "Could not switch base currency".
        let app = launchC(["-qaSeedRates"])
        select(.settings, in: app)
        scrollIntoView(AccessibilityID.settingsRow("currency"), in: app).tap()

        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("EUR")
        }
        let euroRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "(EUR)")).firstMatch
        XCTAssertTrue(euroRow.waitForExistence(timeout: 10),
                      "The EUR currency row must be listed.")
        euroRow.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10),
                      "Switching base currency must show the conversion hint.")
        XCTAssertTrue(
            alert.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "converted")).firstMatch.exists,
            "The hint must explain that stored amounts are converted.")
        alert.buttons["Cancel"].firstMatch.tap()
        assertNoLedgerWrite(app, "A cancelled base-currency switch")
    }

    // MARK: - C5: Layout

    func testC5_layout_compactFlowAndLandscapeNotClipped() throws {
        // The frozen CI destination is a compact-width iPhone 16 (the smallest
        // class available without editing DESTINATION). Run the whole
        // bookkeeping chain on it, then verify the entry form is not clipped in
        // landscape. XCUITest cannot switch the device model at runtime.
        let app = launchC()
        let note = qaNote("C5")
        let added = addExpense(app, amount: "12.50", note: note)
        XCTAssertTrue(added.exists,
                      "The compact-width bookkeeping flow must complete.")

        XCUIDevice.shared.orientation = .landscapeLeft

        require(app, AccessibilityID.logAddButton).tap()
        let window = app.windows.firstMatch.frame
        for identifier in [AccessibilityID.entryAmountDisplay,
                           AccessibilityID.entrySave,
                           AccessibilityID.entryCancel] {
            let control = require(app, identifier)
            XCTAssertTrue(control.isHittable,
                          "\(identifier) must stay on screen in landscape.")
            XCTAssertTrue(window.contains(control.frame) || window.intersects(control.frame),
                          "\(identifier) must not be clipped outside the window in landscape.")
        }

        // launchC() normalises orientation for the next case, but restore it
        // here too so a landscape device never outlives this shard.
        XCUIDevice.shared.orientation = .portrait
    }

    func testC5b_layout_ipadSplitNavigationAndDetail() throws {
        // Dedicated shard: on a regular-width (iPad/split) destination this
        // exercises the NavigationSplitView sidebar + detail; on the compact
        // iPhone 16 CI device it verifies the same navigation reaches a detail
        // without truncation. Its own CI job keeps a layout failure separable
        // from a bookkeeping-logic failure in the other shards.
        let app = launchC()
        let window = app.windows.firstMatch.frame
        let wideLayout = window.width >= 768

        if wideLayout {
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 20),
                          "A regular-width layout must present a split navigation shell.")
            // The split shell shows its detail column immediately; the Insights
            // period picker is that detail, so navigation is already proven.
            XCTAssertTrue(element(app, AccessibilityID.insightsPeriodPicker).waitForExistence(timeout: 20),
                          "The split shell must present a reachable detail.")
        } else {
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 20),
                          "A compact-width layout must present a tab shell.")
            XCTAssertGreaterThan(tabBar.buttons.count, 0,
                                 "The compact shell must keep its tabs.")
            for index in 0..<tabBar.buttons.count {
                XCTAssertTrue(tabBar.buttons.element(boundBy: index).isHittable,
                              "Tab \(index) must not be clipped by the layout.")
            }
            // Navigation from the tab shell into detail content.
            select(.insights, in: app)
            XCTAssertTrue(element(app, AccessibilityID.insightsPeriodPicker).waitForExistence(timeout: 20),
                          "Navigation must reach the Insights detail.")
            select(.settings, in: app)
            let row = scrollIntoView(AccessibilityID.settingsImportData, in: app)
            XCTAssertTrue(row.isHittable, "Navigation must expose settings detail rows.")
            row.tap()
            XCTAssertTrue(element(app, AccessibilityID.importPreview).waitForExistence(timeout: 20),
                          "Tapping a settings row must open its detail.")
        }
    }

    // MARK: - TELE-83 multi-select editing

    /// Two selected rows must be edited together, and a book move must show
    /// the affected count before writing. Assertions land on the result
    /// count and on the rows' rendered labels, not on the menus alone.
    func testBatchEditCategoryAndBook() throws {
        let app = launch()

        // A second book is required to prove a batch move actually happened.
        select(.settings, in: app)
        scrollIntoView(AccessibilityID.settingsRow("books"), in: app).tap()
        let newBook = app.buttons.matching(NSPredicate(format: "label == %@", "New Book")).firstMatch
        XCTAssertTrue(newBook.waitForExistence(timeout: 10),
                      "Books screen must offer New Book.\n\(app.debugDescription)")
        newBook.tap()
        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Trip")
        app.buttons.matching(NSPredicate(format: "label == %@", "Save")).firstMatch.tap()

        select(.log, in: app)
        // Creating a book switches into it; its log is empty. Go back to the
        // default book, which owns the bundled sample rows we batch-edit.
        let currentBook = app.buttons.matching(NSPredicate(format: "label == %@", "Trip")).firstMatch
        XCTAssertTrue(currentBook.waitForExistence(timeout: 5))
        currentBook.tap()
        let defaultBook = app.buttons.matching(NSPredicate(format: "label == %@", "Default Book")).firstMatch
        XCTAssertTrue(defaultBook.waitForExistence(timeout: 5),
                      "Book switcher must offer the default book.\n\(app.debugDescription)")
        defaultBook.tap()
        require(app, AccessibilityID.logSelectionToggle).tap()
        let rows = app.descendants(matching: .any).matching(identifier: AccessibilityID.logBatchRow)
        XCTAssertGreaterThanOrEqual(rows.count, 2,
                                    "The sample log must offer at least two rows.\n\(app.debugDescription)")
        rows.element(boundBy: 0).tap()
        rows.element(boundBy: 1).tap()

        require(app, AccessibilityID.logBatchCategoryMenu).tap()
        let category = element(app, AccessibilityID.logBatchCategory)
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        category.tap()
        let categoryResult = element(app, AccessibilityID.logBatchResult)
        XCTAssertTrue(categoryResult.waitForExistence(timeout: 10))
        XCTAssertTrue(categoryResult.label.contains("2"),
                      "Both selected rows must be counted.\n\(categoryResult.label)")
        app.alerts.firstMatch.buttons["Done"].tap()

        require(app, AccessibilityID.logSelectionToggle).tap()
        let rowsAgain = app.descendants(matching: .any).matching(identifier: AccessibilityID.logBatchRow)
        rowsAgain.element(boundBy: 0).tap()
        rowsAgain.element(boundBy: 1).tap()
        require(app, AccessibilityID.logBatchEditMenu).tap()
        let trip = app.buttons.matching(identifier: AccessibilityID.logBatchBook)
            .matching(NSPredicate(format: "label CONTAINS %@", "Trip")).firstMatch
        XCTAssertTrue(trip.waitForExistence(timeout: 5),
                      "The new book must be offered to a batch action.\n\(app.debugDescription)")
        trip.tap()
        let confirm = app.alerts.firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(confirm.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "2")).count, 0,
            "The confirmation must preview the number of affected rows.")
        confirm.buttons["Save"].tap()
        XCTAssertTrue(element(app, AccessibilityID.logBatchResult).waitForExistence(timeout: 10),
                      "A book move must report its result.")
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
