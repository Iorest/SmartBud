//
//  BatchRecognitionTests.swift
//  SmartBudTests
//
//  The commit policy behind batch OCR: one bad receipt must not roll back the
//  other nine, and a retry must not duplicate a row that already succeeded.
//  Runs in the Foundation-only Linux slice as well as the macOS test target.
//

import Testing
import Foundation

@Suite("Batch recognition")
struct BatchRecognitionTests {
    private enum SaveError: LocalizedError {
        case rejected
        var errorDescription: String? { "save rejected" }
    }

    private func drafts(_ count: Int) -> [BatchReceiptDraft] {
        (1...count).map {
            BatchReceiptDraft(sourceName: "receipt-\($0).png", amount: Decimal($0) * 5)
        }
    }

    @Test("Ten-row batch commits independently and retry only re-saves the failed row")
    func partialFailureAndRetry() {
        var session = BatchRecognitionSession(drafts(10))
        let rejectedID = session.items[3].id
        var attempts: [UUID] = []

        let start = Date()
        let first = session.saveAll { draft in
            attempts.append(draft.id)
            if draft.id == rejectedID { throw SaveError.rejected }
        }
        let elapsed = Date().timeIntervalSince(start)
        // Measured on the Linux logic harness; the Vision/OCR half is timed on
        // the iOS CI shards, not here.
        print("[TELE-23] 10-row batch commit: \(String(format: "%.4f", elapsed))s")

        #expect(first.succeeded == 9)
        #expect(first.failed == 1)
        #expect(attempts.count == 10)
        #expect(session.items.filter(\.isSaved).count == 9)
        let failed = session.items.first { $0.id == rejectedID }
        #expect(failed?.issue == .saveFailed("save rejected"))

        let retry = session.save(ids: [rejectedID]) { draft in
            attempts.append(draft.id)
        }
        #expect(retry.succeeded == 1)
        #expect(retry.failed == 0)
        #expect(session.items.allSatisfy(\.isSaved))
        #expect(attempts.count == 11)

        // Calling confirm twice must not write the same receipt twice.
        let again = session.saveAll { _ in
            Issue.record("Saved rows must be skipped")
        }
        #expect(again == BatchSaveSummary())
    }

    @Test("Invalid amounts are flagged without calling the save closure")
    func invalidAmounts() {
        var session = BatchRecognitionSession([
            BatchReceiptDraft(sourceName: "zero.png", amount: .zero),
            BatchReceiptDraft(sourceName: "huge.png", amount: Decimal(Money.maxAmount + 1))
        ])
        var calls = 0
        let summary = session.saveAll { _ in calls += 1 }

        #expect(summary == BatchSaveSummary(succeeded: 0, failed: 2))
        #expect(calls == 0)
        #expect(session.items[0].issue == .missingAmount)
        #expect(session.items[1].issue == .amountTooLarge)
    }

    @Test("Rows can be edited and removed before confirming")
    func editAndRemove() {
        let categoryID = UUID()
        var session = BatchRecognitionSession(drafts(2))
        let removedID = session.items[0].id
        let keptID = session.items[1].id

        session.remove(id: removedID)
        session.update(id: keptID) { draft in
            draft.amount = 42.5
            draft.merchant = "lunch"
            draft.categoryID = categoryID
        }

        #expect(session.items.count == 1)
        let kept = session.items.first
        #expect(kept?.amount == 42.5)
        #expect(kept?.merchant == "lunch")
        #expect(kept?.categoryID == categoryID)
        #expect(kept?.sourceName == "receipt-2.png")
    }
}
