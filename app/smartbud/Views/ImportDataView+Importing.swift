//
//  ImportDataView+Importing.swift
//  smartbud
//
//  Parsing, validation and the write step, kept out of the view file so the
//  wizard's layout code stays readable.
//

import SwiftUI
import SwiftData

extension ImportDataView {

    func validateDoubles(strings: [String]) -> Bool {
        for string in strings {
            if let _ = Double(string) {
                // Valid double
            } else {
                return false // Invalid double found
            }
        }
        return true // All strings are valid doubles
    }

    func processCSV() {
        do {
            let table = try CSVTable(text: data)
            var parsedRows = table.rows

            // Drop a text-only header row (no digits in any cell).
            if let first = parsedRows.first,
               first.allSatisfy({ !$0.containsDigits }) {
                parsedRows.removeFirst()
            }

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
        guard selectedColumns.count > 3 else {
            processingState = .error
            errorMessage = String.appLocalized("请先完成列匹配。")
            return
        }

        let categoryColumnIndex = selectedColumns[0]
        let noteColumnIndex = selectedColumns[1]
        let dateColumnIndex = selectedColumns[2]
        let amountColumnIndex = selectedColumns[3]
        let maxIndex = max(categoryColumnIndex, noteColumnIndex, dateColumnIndex, amountColumnIndex)

        guard !dateFormatString.isEmpty else {
            processingState = .error
            errorMessage = String.appLocalized("请先选择日期格式。")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale
        dateFormatter.dateFormat = dateFormatString

        let categoryDictionary: [String: CategoryModel] = Dictionary(
            uniqueCategories.compactMap { entry in
                entry.category.map { (entry.excelValue, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        struct Draft {
            let note: String
            let category: CategoryModel
            let amount: Double
            let date: Date
        }

        var drafts: [Draft] = []
        drafts.reserveCapacity(rows.count)

        for (offset, row) in rows.enumerated() {
            let line = offset + 1

            guard row.count > maxIndex else {
                processingState = .error
                errorMessage = String(format: String.appLocalized("第 %d 行缺少列，请检查 CSV。"), line)
                return
            }
            guard let transactionDate = dateFormatter.date(from: row[dateColumnIndex]) else {
                processingState = .error
                errorMessage = String(format: String.appLocalized("第 %d 行的日期无法解析。"), line)
                return
            }
            guard let rowCategory = categoryDictionary[row[categoryColumnIndex]] else {
                processingState = .error
                errorMessage = String(format: String.appLocalized("第 %d 行的分类未匹配。"), line)
                return
            }
            guard let transactionAmount = Double(row[amountColumnIndex]) else {
                processingState = .error
                errorMessage = String(format: String.appLocalized("第 %d 行的金额无法解析。"), line)
                return
            }

            drafts.append(Draft(
                note: row[noteColumnIndex],
                category: rowCategory,
                amount: abs(transactionAmount),
                date: transactionDate
            ))
        }

        for draft in drafts {
            let txn = TransactionModel(
                note: draft.note,
                category: draft.category,
                income: draft.category.income,
                amount: draft.amount,
                date: draft.date
            )
            DataRepository.shared.insert(txn)
        }

        guard DataRepository.shared.save() else {
            processingState = .error
            errorMessage = DataRepository.shared.lastSaveError
                ?? String.appLocalized("导入失败，未写入任何数据。")
            return
        }

        withAnimation {
            processingState = .success
            confettiNumber += 1
        }
    }

    func deduceDateFormat(from dateString: String) -> String? {
        let dateFormats = ["yyyy-MM-dd", "dd-MM-yyyy", "MM-dd-yyyy",
                           "yyyy/MM/dd", "dd/MM/yyyy", "MM/dd/yyyy",
                           "yyyyMMdd", "ddMMyyyy", "MMddyyyy", "yyyy-MM-dd HH:mm:ss Z",
                           "dd/MM/yyyy HH:mm:ss"]

        let dateFormatter = DateFormatter()

        for dateFormat in dateFormats {
            dateFormatter.dateFormat = dateFormat
            if let _ = dateFormatter.date(from: dateString) {
                return dateFormat
            }
        }

        return nil
    }

    func makeAttributedString() -> AttributedString {
        var string = AttributedString("this article")
        string.foregroundColor = Color.PrimaryText
        string.link = URL(string: "https://pro.arcgis.com/en/pro-app/latest/help/mapping/time/convert-string-or-numeric-time-values-into-data-format.htm")
        string.underlineColor = UIColor(Color.PrimaryText)
        string.underlineStyle = .single

        return string
    }

    @ViewBuilder
    func PointerView(number: Int, text: String) -> some View {
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
