//
//  ImportDataView+Importing.swift
//  smartbud
//
//  Parsing, validation and the write step, kept out of the view file so the
//  wizard's layout code stays readable.
//

import SwiftUI
import SwiftData

/// Row validation failure, carrying the localized message shown in the wizard.
private struct ImportFailure: Error {
    let message: String
}

/// One validated row, ready to be written.
private struct ImportDraft {
    let note: String
    let category: CategoryModel
    let amount: Double
    let date: Date
    /// Sign wins over the linked category: a negative row is money out even
    /// when the value was mapped to an income category.
    let income: Bool
}

extension ImportDataView {

    /// Every row in the column has to parse — checking only the eight preview
    /// rows let a bad row at line 9 fail the whole import after seven steps.
    func validateAmounts(strings: [String]) -> Bool {
        strings.allSatisfy { ImportAmount.parse($0) != nil }
    }

    func processCSV() {
        do {
            let table = try CSVTable(text: data)
            var parsedRows = table.rows

            guard !parsedRows.isEmpty else {
                showToast = true
                toastMessage = String.appLocalized("Invalid File")
                return
            }

            let maxColumnCount = parsedRows.map(\.count).max() ?? 0
            guard maxColumnCount > 3 else {
                showToast = true
                toastMessage = String.appLocalized("Invalid File")
                return
            }

            // Payment-app exports start with a title/nickname/filter block and
            // end with summary rows; those have fewer cells than the table.
            // They used to become "data" rows and failed the import at step 8.
            while let first = parsedRows.first,
                  first.count < maxColumnCount || first.allSatisfy({ !$0.containsDigits }) {
                parsedRows.removeFirst()
            }
            while let last = parsedRows.last, last.count < maxColumnCount {
                parsedRows.removeLast()
            }

            guard !parsedRows.isEmpty else {
                showToast = true
                toastMessage = String.appLocalized("Invalid File")
                return
            }

            rows = parsedRows

            // Pad ragged rows so every column keeps the same row alignment.
            let padded = parsedRows.map { row in
                row + Array(repeating: "", count: maxColumnCount - row.count)
            }

            var holdingColumns: [[String]] = Array(repeating: [], count: maxColumnCount)
            for row in padded {
                for (index, value) in row.enumerated() {
                    holdingColumns[index].append(value)
                }
            }

            columns = holdingColumns
            displayedColumns = holdingColumns.map { Array($0.prefix(8)) }
            numberOfRows = displayedColumns.first?.count ?? 0
            remainingColumns = Array(0..<maxColumnCount)

            withAnimation {
                progress += 1
            }
        } catch {
            showToast = true
            toastMessage = String.appLocalized("Invalid File")
        }
    }

    /// Validates every row first, then writes the whole batch with one save.
    /// A bad row aborts the import with zero rows written.
    func importData() {
        guard importSelectionIsValid() else { return }

        let indexes = ImportColumns(
            category: selectedColumns[0], note: selectedColumns[1],
            date: selectedColumns[2], amount: selectedColumns[3]
        )
        let dateFormatter = DateFormatter()
        // Fixed locale, not the device's: in a Thai or Japanese locale the
        // same pattern parses "2024-01-05" as a Buddhist/era year.
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = dateFormatString

        let categoryDictionary: [String: CategoryModel] = Dictionary(
            uniqueCategories.compactMap { entry in
                entry.category.map { (entry.excelValue, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        let drafts: [ImportDraft]
        switch makeDrafts(indexes: indexes, formatter: dateFormatter,
                          categories: categoryDictionary) {
        case .success(let built):
            drafts = built
        case .failure(let failure):
            processingState = .error
            errorMessage = failure.message
            return
        }

        let account = accounts.first { $0.id == importAccountID }
        importedIDs = write(drafts, to: account)

        guard DataRepository.shared.save() else {
            // Drop the staged rows so a later save can't commit half an import.
            DataRepository.shared.rollback()
            processingState = .error
            errorMessage = DataRepository.shared.lastSaveError
                ?? String.appLocalized("导入失败，未写入任何数据。")
            return
        }

        // Remember this exact file so a second pick can warn instead of
        // silently doubling the ledger.
        if let pendingDigest {
            var history = UserDefaults.appGroup
                .dictionary(forKey: ImportDataView.importedFilesKey) as? [String: Date] ?? [:]
            history[pendingDigest] = .now
            // Keep the list bounded; only the recent files matter for the
            // duplicate warning.
            if history.count > 20 {
                for key in history.sorted(by: { $0.value < $1.value }).prefix(history.count - 20).map(\.key) {
                    history.removeValue(forKey: key)
                }
            }
            UserDefaults.appGroup.set(history, forKey: ImportDataView.importedFilesKey)
        }

        withAnimation {
            processingState = .success
            confettiNumber += 1
        }
    }

    /// Writes the validated rows. Without an account they never move a
    /// balance, so the ledger total and every account total disagreed;
    /// `baseAmount` has to be frozen at the account's currency too.
    private func write(_ drafts: [ImportDraft], to account: AccountModel?) -> [UUID] {
        var ids: [UUID] = []
        for draft in drafts {
            let baseAmount = account.map {
                CurrencyRateStore.shared.convertToBase(
                    draft.amount, from: $0.resolvedCurrencyCode)
            }
            let merchant = MerchantNormalizer.derive(fromNote: draft.note)
            let txn = TransactionModel(
                note: draft.note,
                category: draft.category,
                account: account,
                baseAmount: baseAmount,
                income: draft.income,
                amount: draft.amount,
                date: draft.date,
                merchant: merchant?.name,
                merchantKey: merchant?.key
            )
            DataRepository.shared.insert(txn)
            ids.append(txn.id)
        }
        return ids
    }

    /// Rejects an incomplete wizard, or an account we cannot convert, before
    /// any parsing happens. The whole batch is refused: one row written at a
    /// guessed rate would make every total wrong.
    private func importSelectionIsValid() -> Bool {
        if selectedColumns.count <= 3 {
            processingState = .error
            errorMessage = String.appLocalized("请先完成列匹配。")
            return false
        }
        if dateFormatString.isEmpty {
            processingState = .error
            errorMessage = String.appLocalized("请先选择日期格式。")
            return false
        }
        if let account = accounts.first(where: { $0.id == importAccountID }),
           CurrencyRateStore.shared.needsRate(for: account.resolvedCurrencyCode) {
            processingState = .error
            errorMessage = String.appFormatted(
                "“%@” has no exchange rate yet, so this CSV cannot be imported. Add one in Settings → Currency → Exchange Rates first.",
                account.resolvedCurrencyCode)
            return false
        }
        return true
    }

    /// Column indexes picked in the wizard.
    private struct ImportColumns {
        let category: Int
        let note: Int
        let date: Int
        let amount: Int
    }

    /// Validates every row before anything is written, so a bad row leaves the
    /// store untouched.
    private func makeDrafts(indexes: ImportColumns,
                            formatter: DateFormatter,
                            categories: [String: CategoryModel])
    -> Result<[ImportDraft], ImportFailure> {
        var drafts: [ImportDraft] = []
        drafts.reserveCapacity(rows.count)

        for (offset, row) in rows.enumerated() {
            let line = offset + 1

            guard row.count > maxIndex(of: indexes) else {
                return .failure(ImportFailure(message: String(format: String.appLocalized("第 %d 行缺少列，请检查 CSV。"), line)))
            }
            guard let transactionDate = formatter.date(from: row[indexes.date]) else {
                return .failure(ImportFailure(message: String(format: String.appLocalized("第 %d 行的日期无法解析。"), line)))
            }
            guard let rowCategory = categories[row[indexes.category]] else {
                return .failure(ImportFailure(message: String(format: String.appLocalized("第 %d 行的分类未匹配。"), line)))
            }
            guard let transactionAmount = ImportAmount.parse(row[indexes.amount]),
                  transactionAmount != 0 else {
                return .failure(ImportFailure(message: String(format: String.appLocalized("第 %d 行的金额无法解析。"), line)))
            }

            let isNegative = transactionAmount < 0
            if isNegative && rowCategory.income {
                return .failure(ImportFailure(message: String(
                    format: String.appLocalized("第 %d 行是负数金额，不能链接到收入分类。"), line)))
            }

            drafts.append(ImportDraft(
                note: row[indexes.note],
                category: rowCategory,
                amount: abs(transactionAmount),
                date: transactionDate,
                income: rowCategory.income && !isNegative
            ))
        }
        return .success(drafts)
    }

    private func maxIndex(of indexes: ImportColumns) -> Int {
        max(indexes.category, indexes.note, indexes.date, indexes.amount)
    }

    func deduceDateFormat(from dateString: String) -> String? {
        let dateFormats = ["yyyy-MM-dd", "dd-MM-yyyy", "MM-dd-yyyy",
                           "yyyy/MM/dd", "dd/MM/yyyy", "MM/dd/yyyy",
                           "yyyyMMdd", "ddMMyyyy", "MMddyyyy", "yyyy-MM-dd HH:mm:ss Z",
                           "dd/MM/yyyy HH:mm:ss"]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current

        for dateFormat in dateFormats {
            dateFormatter.dateFormat = dateFormat
            if dateFormatter.date(from: dateString) != nil {
                return dateFormat
            }
        }

        return nil
    }

    func makeAttributedString() -> AttributedString {
        var string = AttributedString(String.appLocalized("this article"))
        string.foregroundColor = Color.PrimaryText
        let reference = "https://pro.arcgis.com/en/pro-app/latest/help/mapping/time/"
            + "convert-string-or-numeric-time-values-into-data-format.htm"
        string.link = URL(string: reference)
        string.underlineColor = UIColor(Color.PrimaryText)
        string.underlineStyle = .single

        return string
    }

    @ViewBuilder
    func pointerView(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.SecondaryBackground)

                Text("\(number)")
                    .font(.body.weight(.bold))

                    .foregroundStyle(Color.SubtitleText)
            }
            .frame(width: 25, height: 25)

            Text(text)
                .font(.body.weight(.medium))

                .foregroundStyle(Color.PrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
