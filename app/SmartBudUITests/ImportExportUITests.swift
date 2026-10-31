//
//  ImportExportUITests.swift
//  SmartBudUITests
//
//  Flow F — export a JSON backup, then restore it into a *fresh* store and
//  check the numbers survive the trip. The system share sheet and the file
//  picker are the only parts a UI test cannot steer, so `-exportToDocuments` /
//  `-importBackupFromDocuments` park and read the very file those two surfaces
//  would have handled (see `UITestFixture`); everything between them —
//  encoding, the preview count, the merge, dedupe — is the production path.
//
//  Editing the JSON between export and import needs a filesystem editor, which
//  no UI test has; `docs/engineering.md` lists that as the one uncovered step.
//

import XCTest

@MainActor
final class ImportExportUITests: SmartBudUITestCase {

    // MARK: - F12. Export → restore into a clean store → same numbers

    func testF12_exportThenRestore_roundTrip() throws {
        let app = launch(["-exportToDocuments"])

        // One expense, so the backup carries both the fixture and a transaction.
        openEntryForm(in: app)
        enterAmount("12.50", in: app)
        selectCategory("餐饮", in: app)
        saveEntry(in: app)
        waitForRowCount(1, in: app)

        let exported = exportBackup(in: app)

        // A new launch: the store is in memory, so this app sees an empty
        // ledger again. Only the exported file survives, which is exactly the
        // situation a restore is for.
        app.terminate()
        _ = launch(["-exportToDocuments", "-importBackupFromDocuments"])

        let imported = restoreBackup(in: app)
        XCTAssertEqual(imported, exported,
                       "The preview/result count does not match what was exported.")
        XCTAssertTrue(element(app, AccessibilityID.importBackupResult).label.contains("Imported"),
                      "The restore did not report an import: \"\(element(app, AccessibilityID.importBackupResult).label)\"")

        // Numbers on the other side of the trip.
        require(app, AccessibilityID.settingsBack).tap()
        select(.log, in: app)
        waitForRowCount(1, in: app)
        assertNewestRowAmount("12.50", in: app)
        select(.insights, in: app)
        assertAmount(require(app, AccessibilityID.insightsExpenseCard),
                     equals: 12.50, "Insights expenses after the restore")
    }

    // MARK: - F13. Importing the same file twice adds nothing the second time

    func testF13_restoreSameFileTwice_importsNothingNew() throws {
        let app = launch(["-exportToDocuments"])
        openEntryForm(in: app)
        enterAmount("12.50", in: app)
        selectCategory("餐饮", in: app)
        saveEntry(in: app)
        waitForRowCount(1, in: app)

        let exported = exportBackup(in: app)
        XCTAssertEqual(exported, 7, "Fixture (6) + one transaction should be 7 records.")

        app.terminate()
        _ = launch(["-exportToDocuments", "-importBackupFromDocuments"])

        let first = restoreBackup(in: app)
        XCTAssertEqual(first, exported, "The first restore did not read the exported file.")
        require(app, AccessibilityID.settingsBack).tap()
        select(.log, in: app)
        waitForRowCount(1, in: app)

        // Same file, same store: every record is already here.
        select(.settings, in: app)
        tapSettingRow(AccessibilityID.settingsRow("importBackup"), in: app)
        require(app, AccessibilityID.importBackupChooseFile).tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 15),
                      "The second preview never appeared.\n\(app.debugDescription)")
        alert.buttons["Import"].firstMatch.tap()

        let result = require(app, AccessibilityID.importBackupResult, timeout: 20)
        XCTAssertTrue(result.label.contains("Nothing new"),
                      "A duplicate import claimed to import something: \"\(result.label)\"")
        require(app, AccessibilityID.settingsBack).tap()
        select(.log, in: app)
        waitForRowCount(1, in: app)
    }

    // MARK: - F13b. Cancelling the preview writes nothing

    func testF13_cancelRestorePreview_writesNothing() throws {
        let app = launch(["-exportToDocuments"])
        _ = exportBackup(in: app)

        app.terminate()
        _ = launch(["-exportToDocuments", "-importBackupFromDocuments"])

        require(app, AccessibilityID.importBackupChooseFile).tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 15),
                      "The preview never appeared.\n\(app.debugDescription)")
        alert.buttons["Cancel"].firstMatch.tap()

        requireAbsence(app, AccessibilityID.importBackupResult, timeout: 5)
        require(app, AccessibilityID.settingsBack).tap()
        select(.log, in: app)
        XCTAssertEqual(rowCount(in: app), 0,
                       "Cancelling the preview wrote data anyway.")
    }

    // MARK: - Helpers

    /// Settings → Export My Data → Generate Export. Returns the record count
    /// the app reports for the file it just wrote.
    @discardableResult
    private func exportBackup(in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) -> Int {
        select(.settings, in: app)
        tapSettingRow(AccessibilityID.settingsRow("export"), in: app)
        require(app, AccessibilityID.exportJSONButton, file: file, line: line).tap()

        let summary = require(app, AccessibilityID.exportSummary, timeout: 20,
                              file: file, line: line)
        guard let count = number(in: summary) else {
            XCTFail("The export summary carries no count: \"\(summary.label)\"",
                    file: file, line: line)
            return -1
        }
        require(app, AccessibilityID.settingsBack, file: file, line: line).tap()
        return Int(count)
    }

    /// Settings → Restore from Backup → choose file → confirm. Returns the
    /// record count the preview announced.
    private func restoreBackup(in app: XCUIApplication,
                               file: StaticString = #filePath, line: UInt = #line) -> Int {
        select(.settings, in: app)
        tapSettingRow(AccessibilityID.settingsRow("importBackup"), in: app)
        require(app, AccessibilityID.importBackupChooseFile, file: file, line: line).tap()

        let alert = app.alerts.firstMatch
        if !alert.waitForExistence(timeout: 15) {
            XCTFail("The import preview never appeared.\n\(app.debugDescription)",
                    file: file, line: line)
            return -1
        }
        // "Backup from <date> with 7 records." — the count is the number in the
        // message.
        let message = alert.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .first { $0.contains("records") } ?? ""
        let announced = Self.recordCount(from: message)

        alert.buttons["Import"].firstMatch.tap()
        _ = require(app, AccessibilityID.importBackupResult, timeout: 20,
                    file: file, line: line)
        return announced
    }

    /// Pulls the record count out of "Backup from Oct 31, 2026 with 7 records."
    /// The date also contains digits, so a plain digit scrape would read the
    /// year as part of the count.
    private static func recordCount(from message: String) -> Int {
        guard let range = message.range(of: #"(\d+)\s+records"#, options: .regularExpression) else {
            return -1
        }
        return Int(message[range].filter { $0.isNumber }) ?? -1
    }
}
