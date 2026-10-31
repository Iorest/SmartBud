//
//  UITestSupport.swift
//  SmartBudUITests
//
//  Shared base class for the interaction matrix. Everything here exists
//  because a flow case needs the same four things: a deterministic launch, a
//  way to find a control by identifier, a way to wait for the ledger to catch
//  up with a write, and an artifact trail when it fails.
//
//  Conventions (see docs/engineering.md, "UI 测试"):
//  - Queries are identifier-first (`AccessibilityID`), never copy-based, so a
//    localisation change cannot silently retarget a case. The two exceptions
//    are documented where they occur: the UITabBar buttons (position) and the
//    system-rendered segmented pickers (`Picker(.segmented)`), because UIKit
//    drops the identifier a `Label` carries.
//  - No `sleep`. Waits are `waitForExistence` / `XCTNSPredicateExpectation`
//    with an explicit timeout, so a passing case is as fast as the app.
//  - A failed case attaches a screenshot and the full element tree. Both live
//    in `.xcresult`, which CI uploads on every run.
//  - Only infrastructure faults are retried (a simulator that never got the
//    app to the foreground). An assertion failure is never retried: a red case
//    must stay red.
//

import XCTest

@MainActor
class SmartBudUITestCase: XCTestCase {

    /// The app under test. Set by `launch(...)`; `tearDown` uses it to attach
    /// the failure artifacts.
    private(set) var app: XCUIApplication!

    /// How long a launch may take before it counts as an infrastructure
    /// failure. First launch on a CI simulator boots SpringBoard, so this is
    /// generous; every later wait is much tighter.
    private let launchTimeout: TimeInterval = 60

    // No `setUp` / `tearDown` overrides: XCTest declares them `nonisolated`,
    // and this class is `@MainActor` because the SDK marks the XCUIElement
    // members isolated. `continueAfterFailure` is set in `launch()`, and the
    // failure artifacts are attached at the point of failure by
    // `attachDiagnostics(_:)` — XCTest also records its own screenshot for
    // every failed UI test, so `.xcresult` carries both.

    // MARK: - Launch

    /// Arguments every case shares. `-uiTestStore` / `-uiTestSeed` are
    /// DEBUG-only hooks (see `UITestFixture`): the store is in memory and the
    /// App Group defaults are cleared, so cases cannot contaminate each other.
    /// `-skipIntro` still matters because the welcome flow is shown from a
    /// persisted flag rather than from the store.
    private var baseArguments: [String] {
        [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-skipIntro",
            "-uiTestStore",
        ]
    }

    /// Launches the app and waits for the ledger to be interactive.
    ///
    /// - Parameters:
    ///   - extraArguments: case-specific DEBUG arguments (`-proEnforced`, ...).
    ///   - seed: insert the shared categories/accounts fixture. Cases that
    ///     assert on an empty picker pass `false`.
    ///   - environment: simulator-side variables (e.g. `START_TAB`).
    @discardableResult
    func launch(
        _ extraArguments: [String] = [],
        seed: Bool = true,
        environment: [String: String] = [:]
    ) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = baseArguments + (seed ? ["-uiTestSeed"] : []) + extraArguments
        app.launchEnvironment = environment
        app.launch()

        if !waitForLedger(app) {
            // Infrastructure retry: the app never reached the ledger. This is
            // the simulator failing to start it, not the behaviour under
            // test, so one relaunch is allowed (and only one).
            app.terminate()
            app.launch()
            if !waitForLedger(app) {
                XCTFail("The app never reached the ledger after a relaunch.\n\(app.debugDescription)")
            }
        }

        dismissLaunchOverlay(app)
        self.app = app
        return app
    }

    /// The ledger's floating add button is the first thing every case needs,
    /// so it doubles as the "app is ready" sentinel.
    private func waitForLedger(_ app: XCUIApplication) -> Bool {
        let add = app.descendants(matching: .any)
            .matching(identifier: AccessibilityID.logAddButton).firstMatch
        return add.waitForExistence(timeout: launchTimeout)
    }

    /// A simulator without iCloud raises the storage notice once per launch.
    /// No case is about that banner, and it swallows the first tap.
    private func dismissLaunchOverlay(_ app: XCUIApplication) {
        let alert = app.alerts.firstMatch
        if alert.exists, alert.buttons.firstMatch.exists {
            alert.buttons.firstMatch.tap()
        }
    }

    // MARK: - Queries

    /// Identifier-first lookup. Depending on the SwiftUI container the
    /// identifier lands on a button, a cell or a static text, so the query
    /// accepts any element type.
    func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    func require(
        _ app: XCUIApplication,
        _ identifier: String,
        timeout: TimeInterval = 20,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let match = element(app, identifier)
        if !match.waitForExistence(timeout: timeout) {
            attachDiagnostics(identifier)
            XCTFail("No element with identifier \"\(identifier)\".\n\(app.debugDescription)",
                    file: file, line: line)
        }
        return match
    }

    /// Waits for an element to disappear. Used for the surfaces a flow must
    /// *close* (a sheet, the undo banner) — asserting "still there" after a
    /// tap would pass even if the tap did nothing.
    func requireDisappearance(
        _ app: XCUIApplication,
        _ identifier: String,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element(app, identifier))
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            attachDiagnostics(identifier)
            XCTFail("\"\(identifier)\" never went away.\n\(app.debugDescription)",
                    file: file, line: line)
        }
    }

    /// Asserts an element is *not* on screen. Short timeout on purpose: this
    /// is the negative half of a "did not write" assertion, and waiting the
    /// full 20 s for an absence buys nothing.
    func requireAbsence(
        _ app: XCUIApplication,
        _ identifier: String,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if element(app, identifier).waitForExistence(timeout: timeout) {
            attachDiagnostics(identifier)
            XCTFail("\"\(identifier)\" should not be on screen.\n\(app.debugDescription)",
                    file: file, line: line)
        }
    }

    // MARK: - Tabs

    /// SwiftUI's `.tabItem` is rendered by UITabBar, which drops the
    /// identifier the `Label` carries, so the tab's position — fixed by
    /// `HomeView.tabShell` — is the only stable anchor. Each caller asserts a
    /// screen-specific identifier right after tapping, so a reordered tab bar
    /// fails the case instead of quietly testing the wrong screen.
    enum Tab: Int {
        case log = 0
        case insights = 1
        case budget = 2
        case settings = 3
    }

    func select(_ tab: Tab, in app: XCUIApplication,
                file: StaticString = #filePath, line: UInt = #line) {
        let button = app.tabBars.buttons.element(boundBy: tab.rawValue)
        if !button.waitForExistence(timeout: 10) {
            XCTFail("Tab bar button \(tab.rawValue) is missing.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        button.tap()
    }

    // MARK: - Amount entry

    /// Types an amount on the number pad. The pad's default mode ("cent-less",
    /// `numberEntryType == 2`) needs the decimal key before the cents; the
    /// "pre-dotted" mode has no decimal key at all and takes the digits
    /// directly. Both are supported so a settings change cannot quietly turn
    /// every case into "typed 1250 instead of 12.50".
    func enterAmount(
        _ text: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let hasDecimal = element(app, AccessibilityID.padDecimal).waitForExistence(timeout: 5)
        for character in text {
            switch character {
            case ".":
                if hasDecimal { element(app, AccessibilityID.padDecimal).tap() }
            case "0"..."9":
                let digit = Int(String(character)) ?? 0
                let key = element(app, AccessibilityID.padDigit(digit))
                if !key.waitForExistence(timeout: 5) {
                    XCTFail("Number key \(digit) is missing.\n\(app.debugDescription)",
                            file: file, line: line)
                }
                key.tap()
            default:
                break
            }
        }
    }

    /// Types a date as digits into whatever field is focused (the decimal pad
    /// style keyboards the editors use).
    func typeText(_ text: String, into field: XCUIElement) {
        field.tap()
        field.typeText(text)
    }

    // MARK: - Ledger rows

    /// The ledger row a test just created. Rows are ordered newest first and
    /// share one identifier, so the first cell holding a row button is it. The
    /// amount is asserted on the row's label afterwards — it is not the
    /// locator, so a formatting change cannot silently point the test at a
    /// different row.
    func newestRow(in app: XCUIApplication) -> XCUIElement {
        app.cells.containing(.button, identifier: AccessibilityID.logRow).firstMatch
    }

    /// Number of ledger rows currently in the hierarchy. Rows below the fold
    /// are lazy, so this is exact only for the short ledgers the cases build.
    func rowCount(in app: XCUIApplication) -> Int {
        app.buttons.matching(identifier: AccessibilityID.logRow).count
    }

    /// The row *cell* carries no label of its own; the row button inside it
    /// aggregates the note, time and amount. Assertions read the button.
    func assertNewestRowAmount(
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

    /// Waits until the ledger holds `count` rows. Every write path ends in a
    /// list refresh, so this is the sync point that replaces `sleep`.
    @discardableResult
    func waitForRowCount(
        _ count: Int,
        in app: XCUIApplication,
        timeout: TimeInterval = 15,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                app.buttons.matching(identifier: AccessibilityID.logRow).count == count
            },
            object: nil)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if result != .completed {
            attachDiagnostics("rowCount")
            XCTFail("The ledger never reached \(count) rows (currently \(rowCount(in: app))).\n\(app.debugDescription)",
                    file: file, line: line)
            return false
        }
        return true
    }

    /// Scrolls until `identifier` is on screen and hittable. Long lists (the
    /// Settings form, the account list) are lazy, so `exists` is only
    /// meaningful after scrolling.
    func scrollIntoView(
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

    func waitUntilEnabled(_ target: XCUIElement, timeout: TimeInterval = 10) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"), object: target)
        _ = XCTWaiter().wait(for: [expectation], timeout: timeout)
    }

    func waitUntilHittable(_ target: XCUIElement, timeout: TimeInterval = 10) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: target)
        _ = XCTWaiter().wait(for: [expectation], timeout: timeout)
    }

    /// Reveals and taps the row's trailing delete action. `.swipeActions` is
    /// rendered by UIKit, which usually drops the identifier the Button
    /// carries, so the revealed button is matched by identifier first and by
    /// its title second. The title fallback is the suite's single copy-based
    /// query and only works because the launch pins English; it is listed as a
    /// known limitation in docs/engineering.md.
    func swipeDelete(
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

        let titled = app.buttons["Delete"].firstMatch
        if titled.waitForExistence(timeout: 5) {
            titled.tap()
            return
        }

        XCTFail("The row's delete swipe action never appeared.\n\(app.debugDescription)",
                file: file, line: line)
    }

    /// Taps a menu-picker option. SwiftUI renders the collapsed picker as a
    /// button whose label is the current selection, and the options as menu
    /// items labelled with their copy — there is no identifier to carry.
    func chooseMenuOption(
        _ option: String,
        from picker: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        picker.tap()
        let item = app.buttons[option].firstMatch
        if !item.waitForExistence(timeout: 10) {
            XCTFail("Menu option \"\(option)\" never appeared.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        item.tap()
    }

    // MARK: - Money assertions

    /// Every rendering of `value` the app can produce for the pinned en_US
    /// locale (`Money.format`): with cents, and grouped for thousands. The
    /// row/total labels are read as text, so this is a substring test rather
    /// than a numeric compare — a label may hold a time as well.
    private func renderings(of value: Double) -> [String] {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let cents = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let whole = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return value == value.rounded() ? [cents, whole] : [cents]
    }

    func label(_ element: XCUIElement, shows value: Double) -> Bool {
        let text = element.label
        return renderings(of: value).contains { text.contains($0) }
    }

    /// Asserts a single-number element (a stat total, an account balance, a
    /// budget remainder) carries `value`.
    func assertAmount(
        _ element: XCUIElement,
        equals value: Double,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(label(element, shows: value),
                      "\(message.isEmpty ? "Amount" : message): expected \(renderings(of: value)), got \"\(element.label)\" (id: \(element.identifier))",
                      file: file, line: line)
    }

    /// Reads the first number out of a label. Only for elements whose whole
    /// label is one amount — never for a ledger row.
    func number(in element: XCUIElement) -> Double? {
        let text = element.label.replacingOccurrences(of: ",", with: "")
        let allowed = text.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(allowed)
    }

    // MARK: - Entry form

    /// Opens the entry form from the ledger and waits for the pad.
    @discardableResult
    func openEntryForm(in app: XCUIApplication,
                       file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        require(app, AccessibilityID.logAddButton, file: file, line: line).tap()
        return require(app, AccessibilityID.padDigit(0), file: file, line: line)
    }

    /// The category grid's tiles all share one identifier; the tile's label is
    /// the category name, so a case picks by name rather than by position.
    func categoryTile(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: AccessibilityID.entryCategoryTile)
            .matching(NSPredicate(format: "label CONTAINS %@", name))
            .firstMatch
    }

    /// Opens the category grid, picks `name`, and waits for the pad to come
    /// back (the grid swaps the pad out, so its return is the sync point).
    func selectCategory(_ name: String, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        require(app, AccessibilityID.entryCategoryButton, file: file, line: line).tap()
        let tile = categoryTile(named: name, in: app)
        if !tile.waitForExistence(timeout: 10) {
            XCTFail("No category tile \"\(name)\".\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        tile.tap()
        require(app, AccessibilityID.padDigit(0), file: file, line: line)
    }

    /// The Expense / Income segmented control. UIKit renders the segments, so
    /// the control carries the identifier and the segment is chosen by
    /// position: 0 = Expense, 1 = Income.
    func selectEntryType(income: Bool, in app: XCUIApplication,
                         file: StaticString = #filePath, line: UInt = #line) {
        let control = app.segmentedControls
            .matching(identifier: AccessibilityID.entryTypePicker).firstMatch
        let target = control.exists ? control : app.segmentedControls.firstMatch
        if !target.waitForExistence(timeout: 10) {
            XCTFail("The expense/income picker is missing.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        let segment = target.buttons.element(boundBy: income ? 1 : 0)
        if !segment.waitForExistence(timeout: 5) {
            XCTFail("Segment \(income ? "income" : "expense") is missing.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        segment.tap()
    }

    /// Empties the amount so an edit can type a fresh one. "Whole numbers"
    /// mode has the trailing delete next to the amount, "pre-dotted" mode has
    /// the backspace key; both are supported so the case does not depend on
    /// which entry mode the build defaults to.
    func clearEntryAmount(in app: XCUIApplication) {
        let trailing = element(app, AccessibilityID.padDelete)
        let backspace = element(app, AccessibilityID.padBackspace)
        if trailing.exists {
            for _ in 0..<12 where (entryAmount(in: app) ?? 0) != 0 || trailing.isEnabled {
                trailing.tap()
                if !trailing.isEnabled { break }
            }
        } else if backspace.exists {
            for _ in 0..<12 where (entryAmount(in: app) ?? 0) != 0 {
                backspace.tap()
            }
        }
        XCTAssertEqual(entryAmount(in: app) ?? -1, 0, accuracy: 0.001,
                       "The amount could not be cleared.\n\(app.debugDescription)")
    }

    /// Picks an account in the entry form's account sheet.
    func selectAccount(named name: String, in app: XCUIApplication,
                       file: StaticString = #filePath, line: UInt = #line) {
        require(app, AccessibilityID.entryAccount, file: file, line: line).tap()
        let row = app.buttons.matching(identifier: AccessibilityID.entryAccountRow)
            .matching(NSPredicate(format: "label CONTAINS %@", name))
            .firstMatch
        if !row.waitForExistence(timeout: 10) {
            XCTFail("No account row \"\(name)\".\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        row.tap()
        require(app, AccessibilityID.entryAccount, file: file, line: line)
    }

    /// The amount read-out above the pad, as a number.
    func entryAmount(in app: XCUIApplication) -> Double? {
        number(in: element(app, AccessibilityID.entryAmount))
    }

    /// Saves the entry form and waits for it to close.
    func saveEntry(in app: XCUIApplication,
                   file: StaticString = #filePath, line: UInt = #line) {
        let save = require(app, AccessibilityID.entrySave, file: file, line: line)
        waitUntilEnabled(save)
        save.tap()
        requireDisappearance(app, AccessibilityID.entrySave, timeout: 15, file: file, line: line)
    }

    /// Tap on the toolbar button identified by `identifier`, scrolling the
    /// Settings form first when the row is below the fold.
    func tapSettingRow(_ identifier: String, in app: XCUIApplication,
                       file: StaticString = #filePath, line: UInt = #line) {
        let row = scrollIntoView(identifier, in: app)
        if !row.exists {
            XCTFail("Settings row \"\(identifier)\" never came into view.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        row.tap()
    }

    /// Average brightness (0 = black, 1 = white) of a screenshot. The only way
    /// XCUITest can observe an appearance change: there is no colourScheme
    /// API, so the case compares the same screen before and after.
    func averageBrightness(of screenshot: XCUIScreenshot) -> Double {
        let image = screenshot.image
        guard let cgImage = image.cgImage else { return -1 }
        let width = 32, height = 32
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return -1 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var total = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            total += (Double(pixels[index]) + Double(pixels[index + 1])
                      + Double(pixels[index + 2])) / 3.0
        }
        return total / Double(width * height) / 255.0
    }

    // MARK: - System surfaces

    /// Accepts the iOS permission alert the app can raise (notifications). The
    /// alert belongs to SpringBoard, not to the app, so it is queried there.
    /// Returns false when no alert appeared, which the caller may treat as
    /// "already decided".
    @discardableResult
    func allowSystemAlertIfPresent(timeout: TimeInterval = 3) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: timeout) else { return false }
        for title in ["Allow", "OK"] {
            let button = alert.buttons[title]
            if button.exists {
                button.tap()
                return true
            }
        }
        return false
    }

    /// Sends the app to the background and brings it back, which is what
    /// re-locks an App-Locked session.
    func cycleToBackground(in app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        // Wait for the transition instead of sleeping on it.
        let backgrounded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "state == %d",
                                   XCUIApplication.State.runningBackground.rawValue),
            object: app)
        _ = XCTWaiter().wait(for: [backgrounded], timeout: 10)
        app.activate()
    }

    // MARK: - Failure artifacts

    /// A failed case must leave enough behind to diagnose it without watching
    /// the screens: the screenshot shows what was on screen, the element tree
    /// shows what XCUITest could see. Both are attached to the test, so they
    /// travel into `.xcresult` and the CI artifact.
    private func attachDiagnostics(_ reason: String) {
        guard let app else { return }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "failure-\(name)" 
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "hierarchy-\(name)"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    // MARK: - Accessibility audit

    /// Runs the full audit for the screen under test. Issue types listed in
    /// `AccessibilityAuditPolicy.ignoredTypes` are documented, tracked
    /// exceptions; everything else fails the case. Every issue is printed so
    /// the CI log carries the unfiltered report, ignored or not.
    func assertAccessible(
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
    static let elementExceptions: [String] = []

    static var ignoredElementIdentifiers: [String] { elementExceptions }
}

/// Settings routes addressed by the tests. `SettingsRoute` itself lives in the
/// app target, so the raw key is mirrored here; `SettingsRoute.accessibilityKey`
/// is the single source of truth and a mismatch fails CI, not silently passes.
enum SettingsRouteKey {
    static let pro = "pro"
}
