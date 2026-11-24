//
//  DataImporter.swift
//  smartbud
//
//  Reads a JSON file written by `DataExporter` back into the local store.
//  This is the restore half of the portability promise: a new device, or a
//  store recovered from an erase, can be rebuilt from the export file.
//
//  ## Merge, never replace
//
//  Every entity that has an id is matched on it. Rows already present are
//  skipped, so importing the same file twice is a no-op and importing onto a
//  populated store cannot duplicate or clobber anything. Deleting data is
//  the job of Settings → Erase, not of an import.
//
//  ## Tolerant decoding
//
//  Older exports are missing whole sections (transfers and rates were added
//  in schema 4) and newer fields (discount, reimbursement, archive). Missing
//  sections decode as empty and missing fields as their defaults, so a 3.x
//  file still restores everything it knows about.
//

import Foundation
import SwiftData

@MainActor
enum DataImporter {

    /// What one import actually did, shown to the user when it finishes.
    struct Summary: Equatable {
        var categories = 0
        var accounts = 0
        var transactions = 0
        var transfers = 0
        var budgets = 0
        var mainBudgets = 0
        var templates = 0
        var rates = 0
        /// Rows already on this device (same id) that were left alone.
        var skipped = 0
        /// Settings from the backup that still have to be written to the app
        /// (only when this device had no data to protect).
        var settingsToApply: ExportSchema.SettingsDTO?

        /// Records the user thinks of as "data". Rates are configuration and
        /// stay out of the count.
        var imported: Int {
            categories + accounts + transactions + transfers + budgets + mainBudgets + templates
        }

        var isEmpty: Bool { imported == 0 }
    }

    enum ImportError: LocalizedError {
        case unreadable
        case notABackup
        case newerVersion
        case baseCurrencyMismatch(backup: String, local: String)
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .unreadable: String.appLocalized("This file could not be read.")
            case .notABackup: String.appLocalized("This file is not a SmartBud backup.")
            case .newerVersion:
                String.appLocalized("This backup comes from a newer version of SmartBud. "
                                    + "Update the app before restoring it.")
            case .baseCurrencyMismatch(let backup, let local):
                String.appFormatted(
                    "This backup was recorded in %@ but this device uses %@. "
                        + "Switch the base currency first, or erase the data and import again.",
                    backup, local)
            case .writeFailed: String.appLocalized("The backup could not be saved. Try again.")
            }
        }
    }

    // MARK: - Entry points

    /// Reads and applies the backup at `url`. The URL comes from a file
    /// importer, so it is security-scoped and must be unlocked explicitly.
    static func importFile(at url: URL, context: ModelContext) throws -> Summary {
        try apply(decodeFile(at: url), context: context)
    }

    /// Reads and validates the file without writing anything, so the UI can
    /// show "N records" before the user commits.
    static func decodeFile(at url: URL) throws -> ExportSchema.Payload {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }
        return try decode(data)
    }

    /// What the file contains, counted without touching the store. Skips are
    /// not predicted — that depends on what is already here.
    static func preview(_ payload: ExportSchema.Payload) -> Summary {
        var summary = Summary()
        summary.categories = payload.categories.count
        summary.accounts = payload.accounts.count
        summary.transactions = payload.transactions.count
        summary.transfers = payload.transfers.count
        summary.budgets = payload.budgets.count
        summary.mainBudgets = payload.mainBudgets.count
        summary.templates = payload.templates.count
        summary.rates = payload.rates.count
        return summary
    }

    static func decode(_ data: Data) throws -> ExportSchema.Payload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let payload = try decoder.decode(ExportSchema.Payload.self, from: data)
            // `Payload` is lenient enough that any JSON object decodes to an
            // empty file. A real backup always carries a schema version, so
            // that is the one key we insist on.
            guard payload.exportedBySmartBud else { throw ImportError.notABackup }
            // A future format may store amounts or relationships differently;
            // importing it silently would write wrong numbers into the ledger.
            guard payload.schemaVersion <= ExportSchema.version else {
                throw ImportError.newerVersion
            }
            return payload
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.notABackup
        }
    }

    /// Merges `payload` into `context` in a single save. On failure the
    /// context is rolled back so a half-imported file leaves no trace.
    static func apply(
        _ payload: ExportSchema.Payload,
        context: ModelContext
    ) throws -> Summary {
        let settingsToApply = try resolveSettings(payload, context: context)
        var merger = BackupMerger(context: context)

        merger.importCategories(payload.categories)
        merger.importAccounts(payload.accounts)
        merger.importRates(payload.rates)
        merger.importTransactions(payload.transactions)
        merger.importTransfers(payload.transfers)
        merger.importBudgets(payload.budgets)
        merger.importMainBudgets(payload.mainBudgets)
        merger.importTemplates(payload.templates)

        do {
            try context.save()
        } catch {
            context.rollback()
            throw ImportError.writeFailed
        }

        var summary = merger.summary
        summary.settingsToApply = settingsToApply
        return summary
    }

    /// A backup carries the base currency its amounts were frozen in. Restoring
    /// it onto a device that already has data in another currency would
    /// reinterpret every total, so that combination is refused; an empty device
    /// simply adopts the backup's settings.
    private static func resolveSettings(
        _ payload: ExportSchema.Payload,
        context: ModelContext
    ) throws -> ExportSchema.SettingsDTO? {
        guard let settings = payload.settings,
              let backupBase = settings.baseCurrency?.uppercased(),
              !backupBase.isEmpty else { return nil }

        let storeIsEmpty = isEmpty(context)
        let localBase = AppBaseCurrency.code.uppercased()

        if storeIsEmpty { return settings }
        if !localBase.isEmpty, localBase != backupBase {
            throw ImportError.baseCurrencyMismatch(backup: backupBase, local: localBase)
        }
        // Same currency: keep the user's own period settings.
        return nil
    }

    private static func isEmpty(_ context: ModelContext) -> Bool {
        func count<T: PersistentModel>(_ type: T.Type) -> Int {
            (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
        }
        return count(TransactionModel.self) == 0
            && count(CategoryModel.self) == 0
            && count(AccountModel.self) == 0
            && count(BudgetModel.self) == 0
            && count(MainBudgetModel.self) == 0
            && count(TemplateTransactionModel.self) == 0
    }
}

// MARK: - Third-party bill CSV (Alipay / WeChat Pay)

/// A bill exported by Alipay or WeChat Pay. The generic `ImportDataView`
/// wizard asks the user to map columns by hand; these files have stable,
/// platform-specific headers, so the mapping happens here instead.
enum BillPlatform: String, Sendable {
    case alipay
    case wechat
}

/// One bill row after column mapping and validation. `amount` is the positive
/// magnitude; `income` carries the direction separately.
struct BillRow: Equatable, Sendable {
    let date: Date
    let amount: Double
    let income: Bool
    let counterparty: String
    let item: String
    let paymentMethod: String
    let note: String
}

/// `line` is the 1-based index among the file's detail rows: CSVTable drops
/// empty rows, so a physical file line number would drift after a blank line.
struct BillFailure: Equatable, Sendable {
    let line: Int
    let reason: String
    let raw: String
}

/// Everything the user needs in order to confirm an import. Nothing here has
/// touched the store; `skipped` counts duplicates already found.
struct BillPreview: Equatable, Sendable {
    let platform: BillPlatform
    let rows: [BillRow]
    let skipped: Int
    let failures: [BillFailure]
    let paymentMethods: [String]

    var added: Int { rows.count }
    var addedTotal: Double { rows.reduce(0) { $0 + $1.amount } }
}

struct BillImportResult: Equatable, Sendable {
    var imported = 0
    var skipped = 0
    var failures: [BillFailure] = []

    /// One row per rejected source line. The user keeps this even when the
    /// rest of the file was written, so a partial import is auditable.
    var reportCSV: String {
        var lines = ["line,reason,source_row"]
        for failure in failures {
            lines.append([String(failure.line), failure.reason, failure.raw]
                .map { Self.quoted(Self.sanitized($0)) }.joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    func writeReport(to url: URL) throws {
        try Data(reportCSV.utf8).write(to: url)
    }

    /// A leading formula character is executed by spreadsheet apps even when
    /// the field is quoted. Prefixing an apostrophe keeps the raw text readable
    /// without letting a rejected bill row become a live formula in the report.
    private static func sanitized(_ value: String) -> String {
        guard let first = value.first, "=+-@\t".contains(first) else { return value }
        return "'" + value
    }

    private static func quoted(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

enum BillImportError: LocalizedError {
    case unsupportedFormat
    case badEncoding
    case missingColumns([String])
    case unmappedPaymentMethods([String])
    case tooLarge
    case missingRate(String)
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            String.appLocalized("This is not an Alipay or WeChat Pay bill CSV.")
        case .badEncoding:
            String.appLocalized("This file's text encoding is not supported.")
        case .tooLarge:
            String.appLocalized("This bill file is too large to import.")
        case .missingColumns(let names):
            String.appFormatted("The bill is missing these columns: %@", names.joined(separator: "、"))
        case .unmappedPaymentMethods(let names):
            String.appFormatted("Choose an account for: %@", names.joined(separator: "、"))
        case .missingRate(let code):
            String.appFormatted("No exchange rate for %@. Add one in Settings → Currency first.", code)
        case .writeFailed:
            String.appLocalized("The import could not be saved. Try again.")
        }
    }
}

extension DataImporter {

    /// A crafted single field can otherwise hold the entire file in memory.
    private static let billSizeLimit = 20 * 1024 * 1024

    /// Reads a platform bill without writing anything. Used by the preview
    /// step so the user sees "added N / skipped M" before committing.
    static func previewBill(_ data: Data, context: ModelContext) throws -> BillPreview {
        guard data.count <= Self.billSizeLimit else { throw BillImportError.tooLarge }
        let table = try CSVTable(text: try decodeBillText(data))
        guard let header = table.rows.firstIndex(where: { BillColumns.looksLikeHeader($0) }) else {
            throw BillImportError.unsupportedFormat
        }
        guard let columns = BillColumns.match(table.rows[header]) else {
            throw BillImportError.missingColumns(BillColumns.missingFields(in: table.rows[header]))
        }

        let platform = detectPlatform(in: table.rows.prefix(header + 1))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        var keys = existingBillKeys(context)
        var rows: [BillRow] = []
        var failures: [BillFailure] = []
        var methods: Set<String> = []
        var skipped = 0

        for (offset, source) in table.rows.dropFirst(header + 1).enumerated() {
            let line = offset + 1
            let raw = source.joined(separator: ",")
            if source.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
            // Alipay/WeChat append a short summary after the detail table.
            // It has fewer cells than the header and is never a transaction.
            if source.count < columns.width { continue }

            func cell(_ index: Int?) -> String {
                guard let index, index < source.count else { return "" }
                return source[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let counterparty = cell(columns.counterparty)
            let item = cell(columns.item)
            let sourceNote = cell(columns.note)
            let method = cell(columns.paymentMethod)
            let directionRaw = cell(columns.direction)

            guard let date = parseBillDate(cell(columns.date), formatter: formatter) else {
                failures.append(BillFailure(line: line, reason: "日期无法解析", raw: raw))
                continue
            }
            guard let signed = ImportAmount.parse(cell(columns.amount)), signed != 0 else {
                failures.append(BillFailure(line: line, reason: "金额无法解析", raw: raw))
                continue
            }
            guard let income = parseDirection(directionRaw) else {
                failures.append(BillFailure(line: line, reason: "收/支无法识别", raw: raw))
                continue
            }
            guard !counterparty.isEmpty else {
                failures.append(BillFailure(line: line, reason: "交易对方为空", raw: raw))
                continue
            }

            let amount = abs(signed)
            let merchantKey = billMerchantKey(counterparty)
            let key = billFingerprint(date: date, amount: amount,
                                      merchantKey: merchantKey, income: income)
            guard keys.insert(key).inserted else {
                skipped += 1
                continue
            }

            let details = [item, counterparty, sourceNote].filter { !$0.isEmpty }
            let note = details.isEmpty ? counterparty : details.joined(separator: " · ")
            rows.append(BillRow(date: date, amount: amount, income: income,
                                counterparty: counterparty, item: item,
                                paymentMethod: method.isEmpty ? BillColumns.noMethod : method,
                                note: note))
            methods.insert(method.isEmpty ? BillColumns.noMethod : method)
        }

        return BillPreview(platform: platform, rows: rows, skipped: skipped,
                           failures: failures, paymentMethods: methods.sorted())
    }

    /// Suggested account for each payment method in the file. `nil` means the
    /// user must pick one; `applyBill` refuses such a file rather than writing
    /// a row with no account (which would count in totals but move no money).
    static func accountMappings(for preview: BillPreview,
                                accounts: [AccountModel]) -> [String: UUID?] {
        Dictionary(uniqueKeysWithValues: preview.paymentMethods.map {
            ($0, suggestedAccountID(for: $0, accounts: accounts))
        })
    }

    static func suggestedAccountID(for paymentMethod: String,
                                   accounts: [AccountModel]) -> UUID? {
        let needle = accountMatchKey(paymentMethod)
        guard !needle.isEmpty else { return nil }
        let candidates = accounts.filter { !$0.archived }

        if let exact = candidates.first(where: { accountMatchKey($0.name) == needle }) {
            return exact.id
        }
        for token in accountAliases(needle) {
            if let match = candidates.first(where: {
                let name = accountMatchKey($0.name)
                return !name.isEmpty && (name.contains(token) || token.contains(name))
            }) { return match.id }
        }
        // "招商银行(1234)" names the same card as an account ending in 1234.
        if let suffix = paymentMethod.range(of: #"\d{4}\D*$"#, options: .regularExpression) {
            let digits = String(paymentMethod[suffix]).filter(\.isNumber)
            if let match = candidates.first(where: { accountMatchKey($0.name).contains(digits) }) {
                return match.id
            }
        }
        return nil
    }

    /// Writes the confirmed rows. Every payment method must have an account;
    /// unmatched rows are an error, never silently dropped. Bad source lines
    /// were already collected in the preview and travel into the result.
    static func applyBill(_ preview: BillPreview,
                          accountIDs: [String: UUID],
                          context: ModelContext) throws -> BillImportResult {
        let needed = Set(preview.rows.map(\.paymentMethod))
        let unmapped = needed.filter { accountIDs[$0] == nil }.sorted()
        guard unmapped.isEmpty else { throw BillImportError.unmappedPaymentMethods(unmapped) }

        let accounts = (try? context.fetch(FetchDescriptor<AccountModel>())) ?? []
        var resolved: [String: AccountModel] = [:]
        for method in needed {
            guard let id = accountIDs[method],
                  let account = accounts.first(where: { $0.id == id }) else {
                throw BillImportError.unmappedPaymentMethods([method])
            }
            resolved[method] = account
        }

        let categories = (try? context.fetch(FetchDescriptor<CategoryModel>())) ?? []
        let base = AppBaseCurrency.code.uppercased()
        // Pure conversion from the store being written to. The app-wide
        // `CurrencyRateStore` is not linked into the test target, which
        // compiles this file too.
        let rates = Self.billRates(context)
        for account in resolved.values {
            let code = account.currencyCode.uppercased()
            if CurrencyConversion.needsRate(for: code, base: base, rates: rates) {
                throw BillImportError.missingRate(code)
            }
        }

        var keys = existingBillKeys(context)
        var imported = 0
        var skipped = 0

        for row in preview.rows {
            let merchantKey = billMerchantKey(row.counterparty)
            let key = billFingerprint(date: row.date, amount: row.amount,
                                      merchantKey: merchantKey, income: row.income)
            // The store may have changed between preview and confirmation.
            guard keys.insert(key).inserted else {
                skipped += 1
                continue
            }
            guard let account = resolved[row.paymentMethod] else {
                throw BillImportError.unmappedPaymentMethods([row.paymentMethod])
            }
            let code = account.currencyCode.uppercased()
            let conversion = code.isEmpty || code == base
                ? row.amount
                : CurrencyConversion.convertRounded(
                    row.amount, from: code, to: base, rates: rates)

            let identity = MerchantNormalizer.normalize(row.counterparty)
            let txn = TransactionModel(
                note: row.note,
                category: billCategory(for: row, categories: categories),
                account: account,
                baseAmount: conversion,
                income: row.income,
                amount: row.amount,
                date: row.date,
                merchant: identity?.name ?? row.counterparty,
                merchantKey: merchantKey
            )
            context.insert(txn)
            imported += 1
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw BillImportError.writeFailed
        }
        return BillImportResult(imported: imported, skipped: skipped,
                                failures: preview.failures)
    }

    // MARK: Internals

    private static func decodeBillText(_ data: Data) throws -> String {
        let decoded: String
        // Foundation accepts most GB18030 byte strings as UTF-16, so trying
        // UTF-16 without a BOM silently turns Chinese headers into mojibake.
        let hasUTF16BOM = data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF])
        if hasUTF16BOM, let utf16 = String(data: data, encoding: .utf16) {
            decoded = utf16
        } else if !hasUTF16BOM, let utf8 = String(data: data, encoding: .utf8) {
            decoded = utf8
        } else {
            let encoding = CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
            guard let gbk = String(data: data, encoding: String.Encoding(rawValue: encoding)) else {
                throw BillImportError.badEncoding
            }
            decoded = gbk
        }
        return decoded.hasPrefix("\u{FEFF}") ? String(decoded.dropFirst()) : decoded
    }

    private static func detectPlatform(in preamble: ArraySlice<[String]>) -> BillPlatform {
        let text = preamble.joined().joined(separator: " ")
        if text.localizedCaseInsensitiveContains("微信") { return .wechat }
        if text.localizedCaseInsensitiveContains("支付宝") { return .alipay }
        // Header-only fixtures still have a deterministic answer.
        return text.contains("交易创建时间") ? .alipay : .wechat
    }

    private static let billDateFormats = [
        "yyyy-MM-dd HH:mm:ss", "yyyy/MM/dd HH:mm:ss", "yyyy-MM-dd HH:mm",
        "yyyy/MM/dd HH:mm", "yyyy-MM-dd", "yyyy/MM/dd",
        "yyyy年M月d日 HH:mm:ss", "yyyyMMddHHmmss", "yyyyMMdd"
    ]

    private static func parseBillDate(_ raw: String, formatter: DateFormatter) -> Date? {
        guard !raw.isEmpty else { return nil }
        for format in billDateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }

    private static func parseDirection(_ raw: String) -> Bool? {
        switch raw {
        case "收入", "收款", "转入", "income", "Income": return true
        case "支出", "付款", "转出", "expense", "Expense": return false
        default: return nil
        }
    }

    private static func billMerchantKey(_ counterparty: String) -> String {
        MerchantNormalizer.normalize(counterparty)?.key
            ?? MerchantNormalizer.key(counterparty)
            ?? counterparty.lowercased()
    }

    /// Time (to the second) + amount + counterparty + direction. Stored rows
    /// carry the same key in `merchantKey`, so re-importing a file skips them.
    private static func billFingerprint(date: Date, amount: Double,
                                        merchantKey: String, income: Bool) -> String {
        let seconds = Int64(date.timeIntervalSince1970.rounded())
        let cents = Int64((amount * 100).rounded())
        return "\(seconds)|\(cents)|\(merchantKey.lowercased())|\(income ? 1 : 0)"
    }

    private static func existingBillKeys(_ context: ModelContext) -> Set<String> {
        let transactions = (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? []
        return Set(transactions.compactMap { txn in
            guard let date = txn.date else { return nil }
            let key = txn.merchantKey
                ?? MerchantNormalizer.key(txn.merchant)
                ?? txn.note?.lowercased()
                ?? ""
            return billFingerprint(date: date, amount: txn.amount,
                                   merchantKey: key, income: txn.income)
        })
    }

    /// Rates from the store being written to. `DataImporter.swift` is also
    /// compiled into the test target, which does not link the app-wide
    /// `CurrencyRateStore` singleton.
    private static func billRates(_ context: ModelContext) -> [String: Double] {
        let records = (try? context.fetch(FetchDescriptor<CurrencyRate>())) ?? []
        var rates: [String: Double] = [:]
        for record in records where !record.code.isEmpty {
            rates[record.code.uppercased()] = record.rate
        }
        return rates
    }

    private static func billCategory(for row: BillRow,
                                     categories: [CategoryModel]) -> CategoryModel? {
        let haystack = "\(row.item) \(row.counterparty)".lowercased()
        if let direct = categories.first(where: {
            $0.income == row.income
                && !$0.name.isEmpty
                && haystack.contains($0.name.lowercased())
        }) { return direct }
        return categories.first { $0.income == row.income }
    }

    private static func accountMatchKey(_ raw: String) -> String {
        String(raw.unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
                && !CharacterSet.punctuationCharacters.contains($0)
                && !CharacterSet.symbols.contains($0)
        }).lowercased()
    }

    private static func accountAliases(_ key: String) -> [String] {
        let table: [[String]] = [
            ["招行", "招商银行"], ["工行", "工商银行"], ["建行", "建设银行"],
            ["中行", "中国银行"], ["农行", "农业银行"], ["交行", "交通银行"],
            ["余额", "支付宝"], ["零钱", "微信"],
            ["微信支付", "微信"], ["支付宝", "余额"]
        ]
        for group in table where group.contains(where: { key.contains($0) }) { return group }
        return [key]
    }
}

/// Column positions for a recognised bill header. Header lookup is by name,
/// so a reordered export still maps to the right app fields.
private struct BillColumns {
    static let noMethod = "未指定账户"

    private static let dateHeaders = ["交易创建时间", "付款时间", "交易时间"]
    private static let amountHeaders = ["金额(元)", "金额", "交易金额"]
    private static let directionHeaders = ["收/支", "收支"]
    private static let counterpartyHeaders = ["交易对方", "对方", "商户名称"]
    private static let requiredGroups = [dateHeaders, amountHeaders,
                                         directionHeaders, counterpartyHeaders]
    private static let requiredNames = ["交易日期", "金额", "收/支", "交易对方"]

    let date: Int
    let amount: Int
    let direction: Int
    let counterparty: Int
    let item: Int?
    let paymentMethod: Int?
    let note: Int?

    var width: Int { max(date, amount, direction, counterparty) + 1 }

    /// Preamble rows mention a nickname or a date range; a real header carries
    /// at least three of the four required names.
    static func looksLikeHeader(_ row: [String]) -> Bool {
        let headers = Set(row.map(normalizeHeader))
        let matched = requiredGroups.filter { group in
            group.contains { headers.contains(normalizeHeader($0)) }
        }.count
        return matched >= 3
    }

    static func missingFields(in row: [String]) -> [String] {
        var missing: [String] = []
        for (name, group) in zip(requiredNames, requiredGroups) {
            if index(of: group, in: row) == nil { missing.append(name) }
        }
        return missing
    }

    static func match(_ row: [String]) -> BillColumns? {
        guard let date = index(of: Self.dateHeaders, in: row),
              let amount = index(of: Self.amountHeaders, in: row),
              let direction = index(of: Self.directionHeaders, in: row),
              let counterparty = index(of: Self.counterpartyHeaders, in: row) else { return nil }
        return BillColumns(date: date, amount: amount, direction: direction,
                           counterparty: counterparty,
                           item: index(of: ["商品名称", "商品", "商品说明"], in: row),
                           paymentMethod: index(of: ["付款方式", "支付方式", "资金渠道"], in: row),
                           note: index(of: ["备注", "备注说明"], in: row))
    }

    private static func index(of aliases: [String], in row: [String]) -> Int? {
        let headers = row.map(normalizeHeader)
        for alias in aliases {
            let key = normalizeHeader(alias)
            if let index = headers.firstIndex(of: key) { return index }
        }
        return nil
    }

    private static func normalizeHeader(_ raw: String) -> String {
        String(raw.trimmingCharacters(in: .whitespacesAndNewlines).compactMap { character -> Character? in
            switch character {
            case "（": return "("
            case "）": return ")"
            case "／": return "/"
            default: return character.isWhitespace ? nil : character
            }
        })
    }
}
