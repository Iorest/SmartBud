//
//  BatchRecognition.swift
//  smartbud
//
//  Foundation-only state for multi-receipt recognition.
//
//  The batch sheet keeps text drafts, never decoded images: OCR consumes one
//  `UIImage` at a time and the image is released before the next one is read.
//  Saving is deliberately per row — `DataRepository.save()` rolls back every
//  uncommitted change when one insert fails, so a batch must commit each row
//  through the existing form-create path instead of staging them together.
//

import Foundation

/// Why one receipt could not be recognised or saved. The UI localises `key`
/// and appends `detail` (an OS error string) when present.
enum BatchDraftIssue: Equatable, Sendable {
    case missingAmount
    case amountTooLarge
    case unreadableImage
    case ocrFailed(String)
    case saveFailed(String)

    var key: String {
        switch self {
        case .missingAmount: return "图片里没有识别到金额。"
        case .amountTooLarge: return "金额超出上限。"
        case .unreadableImage: return "无法读取这张图片。"
        case .ocrFailed: return "这张票据识别失败，请重试。"
        case .saveFailed: return "保存失败，请重试。"
        }
    }

    var detail: String? {
        switch self {
        case let .ocrFailed(detail), let .saveFailed(detail): return detail
        case .missingAmount, .amountTooLarge, .unreadableImage: return nil
        }
    }
}

/// One editable row of the batch preview. `categoryID` is resolved against the
/// category arrays supplied by the form so CloudKit object identity never
/// crosses the pure layer.
struct BatchReceiptDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceName: String
    var amount: Decimal
    var isIncome: Bool
    var merchant: String?
    var categoryID: UUID?
    var categoryHint: String?
    var issue: BatchDraftIssue?
    var isSaved: Bool

    init(
        id: UUID = UUID(),
        sourceName: String,
        amount: Decimal = .zero,
        isIncome: Bool = false,
        merchant: String? = nil,
        categoryID: UUID? = nil,
        categoryHint: String? = nil,
        issue: BatchDraftIssue? = nil,
        isSaved: Bool = false
    ) {
        self.id = id
        self.sourceName = sourceName
        self.amount = amount
        self.isIncome = isIncome
        self.merchant = merchant
        self.categoryID = categoryID
        self.categoryHint = categoryHint
        self.issue = issue
        self.isSaved = isSaved
    }
}

struct BatchSaveSummary: Equatable, Sendable {
    var succeeded: Int = 0
    var failed: Int = 0
}

/// Value-type batch state. All mutations are explicit so the sheet can bind a
/// row to a text field without losing the "saved" flag after an edit.
struct BatchRecognitionSession: Equatable {
    var items: [BatchReceiptDraft]

    init(_ items: [BatchReceiptDraft] = []) {
        self.items = items
    }

    mutating func append(_ draft: BatchReceiptDraft) {
        items.append(draft)
    }

    mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// Applies a direct edit from the preview row. A closure is used so a
    /// cleared merchant (nil) is distinguishable from "not edited".
    mutating func update(id: UUID, _ change: (inout BatchReceiptDraft) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    /// Commits each selected row independently. A rejected row is flagged and
    /// the loop continues; already-saved rows are skipped so a retry cannot
    /// create duplicates. `commit` is the existing form-create path injected
    /// by the view, which keeps this state machine testable without SwiftData.
    @discardableResult
    mutating func save(
        ids: Set<UUID>,
        using commit: (BatchReceiptDraft) throws -> Void
    ) -> BatchSaveSummary {
        var summary = BatchSaveSummary()
        for index in items.indices {
            let draft = items[index]
            guard ids.contains(draft.id), !draft.isSaved else { continue }

            guard draft.amount > 0 else {
                items[index].issue = .missingAmount
                summary.failed += 1
                continue
            }
            guard Money.double(draft.amount) <= Money.maxAmount else {
                items[index].issue = .amountTooLarge
                summary.failed += 1
                continue
            }

            do {
                try commit(draft)
                items[index].isSaved = true
                items[index].issue = nil
                summary.succeeded += 1
            } catch let caught {
                items[index].issue = .saveFailed(caught.localizedDescription)
                summary.failed += 1
            }
        }
        return summary
    }

    @discardableResult
    mutating func saveAll(using commit: (BatchReceiptDraft) throws -> Void) -> BatchSaveSummary {
        save(ids: Set(items.filter { !$0.isSaved }.map(\.id)), using: commit)
    }
}

enum BatchRecognitionLimits {
    /// Kept small on purpose: PhotosPicker hands over one `Data` at a time and
    /// OCR runs serially, so ten photos never occupy memory simultaneously.
    static let maxSelection = 10
}
