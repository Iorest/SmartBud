//
//  DataExporter+CSV.swift
//  smartbud
//
//  Spreadsheet export (one flat row per ledger entry). Split from the JSON
//  exporter so each file stays focused; both share `DataExporter.schemaVersion`.
//

import Foundation
import SwiftData

@MainActor
extension DataExporter {

    // MARK: - CSV

    /// Column order of the CSV export. Kept as data so the header row and
    /// every row are generated from the same list. `merchant` and
    /// `merchant_key` are appended rather than inserted so an existing
    /// spreadsheet keeps its column positions.
    static let csvHeader = [
        "date", "type", "amount", "currency", "base_amount",
        "category", "account", "note", "reimbursable", "reimbursed", "fee",
        "merchant", "merchant_key", "tags"
    ]

    /// Spreadsheet-friendly export: one flat row per ledger entry, transfers
    /// included as their own type. Unlike the JSON file this is not a backup
    /// (it cannot be imported back), it is for Numbers / Excel / a bank
    /// reconciliation.
    static func exportCSVToFile(repo: DataRepository = .shared) throws -> URL {
        let rows = csvRows(repo: repo)
        guard rows.count > 1 else { throw ExportError.noData }

        let data = Data(rows.joined(separator: "\r\n").utf8)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "smartbud-export-\(formatter.string(from: .now)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailed(error)
        }
        return url
    }

    /// Every CSV line, header first. Split out from the file write so the
    /// contents can be tested without touching the filesystem.
    static func csvRows(repo: DataRepository = .shared) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var rows = [csvRow(csvHeader)]
        let allTags = TagStore.allAcrossBooks(in: repo.container.mainContext)

        let transactions = repo.fetch(TransactionModel.self)
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        for txn in transactions {
            let type: String
            if txn.adjustment {
                type = "adjustment"
            } else if txn.isRefund {
                // Its own type so a spreadsheet that sums `expense` does not
                // count a purchase and its refund as two purchases.
                type = "refund"
            } else {
                type = txn.income ? "income" : "expense"
            }
            rows.append(csvRow([
                formatter.string(from: txn.wrappedDate),
                type,
                amountField(txn.amount),
                // A row without an account is recorded in the base currency.
                // Writing an empty cell here made the sheet look like the
                // amount had no currency at all.
                txn.account?.resolvedCurrencyCode ?? AppBaseCurrency.code,
                amountField(txn.wrappedBaseAmount),
                txn.category?.name ?? "",
                txn.account?.name ?? "",
                txn.wrappedNote,
                txn.reimbursable ? "true" : "false",
                txn.reimbursedAt.map { formatter.string(from: $0) } ?? "",
                "",
                txn.merchant ?? "",
                txn.merchantKey ?? "",
                allTags.filter { txn.tagIDs.contains($0.id) }
                    .map(\.name).joined(separator: ";")
            ]))
        }

        let transfers = repo.fetch(TransferModel.self).sorted { $0.date > $1.date }
        for transfer in transfers {
            let source = transfer.source?.wrappedName ?? ""
            let destination = transfer.destination?.wrappedName ?? ""
            rows.append(csvRow([
                formatter.string(from: transfer.wrappedDate),
                "transfer",
                amountField(transfer.amount),
                transfer.source?.resolvedCurrencyCode ?? AppBaseCurrency.code,
                "",
                "",
                "\(source) → \(destination)",
                transfer.wrappedNote,
                "false",
                "",
                amountField(transfer.fee),
                "",
                "",
                ""
            ]))
        }

        return rows
    }

    /// Fixed two-decimal representation so spreadsheets never guess a locale.
    private static func amountField(_ value: Double) -> String {
        let decimal = Money.rounded(Money.cents(value))
        return "\(decimal)"
    }

    private static func csvRow(_ fields: [String]) -> String {
        CSVSupport.row(fields)
    }
}
