//
//  BatchRecognitionView.swift
//  smartbud
//
//  Preview and commit for multi-receipt recognition. Recognition turns each
//  selected image into text only (see `BatchRecognitionSupport`); this sheet
//  then edits those drafts and commits each accepted one through the same
//  `TransactionViewModel.create` path the add-entry form uses.
//

import SwiftUI

enum BatchRecognitionSupport {
    /// Mirrors the single-image smart-entry mapping so both paths agree on
    /// amount priority, direction, merchant and category hint.
    static func draft(from result: OCRService.OCRResult, sourceName: String) -> BatchReceiptDraft {
        let hint = ExpenseTextParser.parse(result.allText)
        guard let amount = result.amounts.first ?? hint?.amount else {
            return BatchReceiptDraft(sourceName: sourceName, issue: .missingAmount)
        }
        return BatchReceiptDraft(
            sourceName: sourceName,
            amount: amount,
            isIncome: hint?.isIncome ?? false,
            merchant: result.merchant ?? hint?.merchant,
            categoryHint: hint?.categoryHint
        )
    }
}

extension BatchDraftIssue {
    /// Kept here (not in the Foundation-only logic file) so the localization
    /// coverage test sees every literal key.
    var localizedMessage: String {
        let base: String
        switch self {
        case .missingAmount: base = String.appLocalized("图片里没有识别到金额。")
        case .amountTooLarge: base = String.appLocalized("金额超出上限。")
        case .unreadableImage: base = String.appLocalized("无法读取这张图片。")
        case .ocrFailed: base = String.appLocalized("这张票据识别失败，请重试。")
        case .saveFailed: base = String.appLocalized("保存失败，请重试。")
        }
        if let detail, !detail.isEmpty { return "\(base) \(detail)" }
        return base
    }
}

struct BatchRecognitionView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lastAccountID", store: .appGroup) private var lastAccountID = ""

    let expenseCategories: [CategoryModel]
    let incomeCategories: [CategoryModel]

    @State private var session: BatchRecognitionSession
    @State private var isSaving = false
    @State private var summary: BatchSaveSummary?

    init(drafts: [BatchReceiptDraft],
         expenseCategories: [CategoryModel],
         incomeCategories: [CategoryModel]) {
        self.expenseCategories = expenseCategories
        self.incomeCategories = incomeCategories
        _session = State(initialValue: BatchRecognitionSession(drafts))
    }

    private var pendingCount: Int {
        session.items.filter { !$0.isSaved }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String.appLocalized("逐条核对金额、分类与备注，只有点“保存”才写入账本。"))
                        .font(.footnote)
                        .foregroundStyle(Color.SubtitleText)
                }
                ForEach($session.items) { $draft in
                    row(for: $draft)
                }
                if let summary {
                    Section {
                        Text(String.appFormatted("Saved %lld receipts, %lld failed.",
                                                 summary.succeeded, summary.failed))
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .navigationTitle(String.appLocalized("Batch Recognition"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String.appLocalized("关闭")) { dismiss() }
                        .accessibilityIdentifier(AccessibilityID.batchClose)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveAll()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(String.appFormatted("Save %lld", pendingCount))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || pendingCount == 0)
                    .accessibilityIdentifier(AccessibilityID.batchSave)
                }
            }
            .alert(String.appLocalized("Batch result"), isPresented: Binding(
                get: { summary != nil },
                set: { presented in
                    if !presented {
                        summary = nil
                        dismiss()
                    }
                }
            )) {
                Button(String.appLocalized("关闭"), role: .cancel) {
                    summary = nil
                    dismiss()
                }
            } message: {
                if let summary {
                    Text(String.appFormatted("Saved %lld receipts, %lld failed.",
                                             summary.succeeded, summary.failed))
                }
            }
        }
    }

    private func row(for draft: Binding<BatchReceiptDraft>) -> some View {
        let categories = draft.wrappedValue.isIncome ? incomeCategories : expenseCategories
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField(String.appLocalized("金额"), value: Binding(
                    get: { Money.double(draft.wrappedValue.amount) },
                    set: { draft.wrappedValue.amount = Money.cents($0) }
                ), format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
                .keyboardType(.decimalPad)

                Picker(String.appLocalized("收支"), selection: Binding(
                    get: { draft.wrappedValue.isIncome },
                    set: { newValue in
                        draft.wrappedValue.isIncome = newValue
                        draft.wrappedValue.categoryID = nil
                    }
                )) {
                    Text(String.appLocalized("支出")).tag(false)
                    Text(String.appLocalized("收入")).tag(true)
                }
                .pickerStyle(.segmented)
            }

            TextField(String.appLocalized("商户 / 备注"), text: Binding(
                get: { draft.wrappedValue.merchant ?? "" },
                set: { draft.wrappedValue.merchant = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Picker(String.appLocalized("分类"), selection: Binding(
                get: { draft.wrappedValue.categoryID },
                set: { draft.wrappedValue.categoryID = $0 }
            )) {
                Text(String.appLocalized("未分类")).tag(nil as UUID?)
                ForEach(categories) { category in
                    Text(category.wrappedName).tag(Optional(category.id))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(draft.wrappedValue.sourceName)
                    .font(.caption)
                    .foregroundStyle(Color.SubtitleText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if draft.wrappedValue.isSaved {
                    Label(String.appLocalized("已保存"), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.IncomeGreen)
                } else if let issue = draft.wrappedValue.issue {
                    Text(issue.localizedMessage)
                        .font(.caption)
                        .foregroundStyle(Color.AlertRed)
                    Button(String.appLocalized("重试")) { retry(draft.wrappedValue.id) }
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier(AccessibilityID.batchRow(draft.wrappedValue.id.uuidString))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                session.remove(id: draft.wrappedValue.id)
            } label: {
                Label(String.appLocalized("删除"), systemImage: "trash")
            }
            .disabled(draft.wrappedValue.isSaved)
        }
    }

    // MARK: - Save

    private enum BatchSaveFailure: LocalizedError {
        case validation(String)
        case store

        var errorDescription: String? {
            switch self {
            case let .validation(key): return String.appLocalized(key)
            case .store: return String.appLocalized("无法保存更改，请稍后重试。")
            }
        }
    }

    private func saveAll() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        AccountViewModel.shared.load()
        summary = session.saveAll(using: saveOne)
    }

    private func retry(_ id: UUID) {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        AccountViewModel.shared.load()
        summary = session.save(ids: [id], using: saveOne)
    }

    /// The batch never writes directly to SwiftData: this is the same create
    /// path (validation, rate conversion, merchant derivation, save and review
    /// prompt) used by the add-entry form's confirm button.
    private func saveOne(_ draft: BatchReceiptDraft) throws {
        let account = AccountViewModel.shared.defaultAccount(lastUsedID: lastAccountID)
        let categories = draft.isIncome ? incomeCategories : expenseCategories
        let category = categories.first { $0.id == draft.categoryID }
        let needsRate = account.map {
            CurrencyRateStore.shared.needsRate(for: $0.resolvedCurrencyCode)
        } ?? false

        if let error = TransactionValidation.error(
            amount: Money.double(draft.amount),
            hasCategory: category != nil,
            needsExchangeRate: needsRate
        ) {
            throw BatchSaveFailure.validation(error.toastTitleKey)
        }

        let trimmedNote = draft.merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let note = trimmedNote.isEmpty ? (category?.wrappedName ?? draft.sourceName) : trimmedNote
        guard TransactionViewModel.shared.create(TransactionEdit(
            note: note,
            category: category,
            account: account,
            income: draft.isIncome,
            amount: Money.double(draft.amount),
            date: Date(),
            repeatType: 0,
            repeatCoefficient: 0
        )) != nil else {
            throw BatchSaveFailure.store
        }
    }
}
