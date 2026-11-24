//
//  Helper.swift
//  smartbud
//
//  SwiftData @Model definitions for the app, widgets, and App Intents.
//  These replace the legacy CoreData `Transaction`/`Category`/`Budget`/`MainBudget`/`TemplateTransaction`
//  NSManagedObject classes that lived in `MainModel.xcdatamodeld`.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Book

/// One ledger. `bookID` on scoped rows is a plain UUID rather than a
/// relationship: it keeps CloudKit lightweight migration to a scalar field
/// and lets later query filtering work without loading the book object.
@Model
final class BookModel {
    /// Fixed id of the ledger every pre-multi-book row belongs to. Stable so
    /// a backup restored on another device, and CloudKit rows arriving from
    /// another device, resolve to the same book.
    static let defaultID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let defaultName = "Default Book"

    var id: UUID = UUID()
    var name: String = ""
    /// Asset name of the chosen icon; empty means the default icon.
    var icon: String = ""
    /// 0 = standard ledger. Other values are reserved for the reference
    /// product's book types so adding one later is a data-only change.
    var type: Int = 0
    var order: Int = 0
    var archived: Bool = false
    var dateCreated: Date = Date.now

    init(name: String = defaultName, icon: String = "", type: Int = 0,
         order: Int = 0, archived: Bool = false) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.type = type
        self.order = order
        self.archived = archived
        self.dateCreated = .now
    }
}

/// The device-local "which book am I looking at" setting. Stored as a string
/// so a missing or corrupt value falls back to the default book without a
/// migration of user defaults.
enum BookSelection {
    static let key = "currentBookID"

    static func current(in defaults: UserDefaults = .appGroup) -> UUID {
        guard let raw = defaults.string(forKey: key), let id = UUID(uuidString: raw) else {
            return BookModel.defaultID
        }
        return id
    }

    static func select(_ id: UUID, in defaults: UserDefaults = .appGroup) {
        defaults.set(id.uuidString, forKey: key)
    }
}

/// Shared read rule until every screen filters on a book (TELE-21). A legacy
/// row with no `bookID` belongs to the default book, not to "no book".
enum BookScope {
    static func matches(_ rowBookID: UUID?, selected: UUID) -> Bool {
        (rowBookID ?? BookModel.defaultID) == selected
    }
}

// MARK: - Transaction

@Model
final class TransactionModel {
    var amount: Double = 0
    var date: Date?
    var day: Date?
    var id: UUID = UUID()
    /// Ledger this row belongs to. `nil` only on rows written before books
    /// existed; `BookMigration` turns those into the default book.
    var bookID: UUID? = BookModel.defaultID
    var income: Bool = false
    var month: Date?
    var note: String?
    var onceRecurring: Bool = false
    var recurringCoefficient: Int = 0
    var recurringType: Int = 0
    var category: CategoryModel?
    /// Optional so existing rows keep working; new entries set it.
    var account: AccountModel?
    /// Amount converted to the app's base currency at entry time. `nil` on
    /// rows written before multi-currency support (amount already in base).
    var baseAmount: Double?
    /// Discount applied at entry time. `amount` already holds the net total,
    /// so this is display-only ("原价 = amount + discount").
    var discount: Double = 0
    /// Expense the user will claim back. The part that has not come back is
    /// money the user is out of pocket for, so it counts as spend; each
    /// repayment moves that part back out of the spend figure.
    var reimbursable: Bool = false
    /// Set when the claim has been reimbursed **in full**. A partial repayment
    /// only changes `reimbursedAmount`; the date stays nil until nothing is
    /// owed, which keeps the pending list and the write-off rule unchanged.
    var reimbursedAt: Date?
    /// Total paid back so far, in the base currency (never in the account's
    /// currency). Invariants: `0 <= reimbursedAmount <= wrappedBaseAmount`;
    /// it is non-zero only on a claim (`reimbursable && !income &&
    /// reimbursementOf == nil`); `reimbursedAt != nil` exactly when it has
    /// reached the full base amount. Old rows default to 0 and are backfilled
    /// from `reimbursedAt` on first launch (`ReimbursementLedger.migrate`).
    var reimbursedAmount: Double = 0
    /// On the income row that pays a claim back: the id of the expense it
    /// settles. The pair moves money back into the account without either
    /// side counting as spend or income.
    var reimbursementOf: UUID?
    /// On the expense row that pays a transfer's fee: the id of the transfer.
    /// The transfer itself carries no money for the fee — this row does — so
    /// the fee can be categorised, budgeted and reported like any expense.
    var transferFeeOf: UUID?
    /// A balance correction written by "调整余额". It moves the account
    /// balance but is neither income nor spend.
    var adjustment: Bool = false
    /// Merchant as the user sees it, derived from the note by
    /// `MerchantNormalizer` ("美团-张亮麻辣烫" → "美团").
    ///
    /// No merchant entity exists: these two strings are the whole of the
    /// merchant data. They die with the row (delete a transaction, or wipe the
    /// store, and they are gone), and renaming a merchant means editing the
    /// rows themselves — nothing else points at them. `nil` means "not
    /// identified": rows written before this field existed, rows whose note
    /// carries no name, and every row `merchantKey == nil` implies.
    var merchant: String?
    /// Grouping key for statistics: the normalised form of `merchant`
    /// (half-width, lower-cased, platform prefix kept, store detail dropped).
    /// Invariant: `merchantKey == nil` exactly when `merchant == nil`, so a
    /// key is never guessed from an unknown name.
    var merchantKey: String?
    /// On a refund row: the id of the expense it refunds. A refund is money
    /// coming back for a purchase, not new earnings — it reduces the original
    /// category's spend in the period the money arrived and never enters
    /// income. The refunded total is *derived* from these rows (see
    /// `RefundPolicy`), not mirrored on the original: a second stored field
    /// would have to be kept in step with every edit and delete.
    var refundOf: UUID?
    /// On a written-off claim: the day the money was given up on. Mirrors
    /// `reimbursedAt` because the pending list is computed from the row itself
    /// — a `#Predicate`/`@Transient` property cannot look for the write-off row
    /// that points back at it. The loss itself is the write-off row (`badDebtOf`),
    /// which is where the amount and the reason live.
    var badDebtAt: Date?
    /// On the expense row that writes off a claim: the id of that claim. The
    /// row is the loss — it counts as spend, so the money the user never got
    /// back stops being invisible — but it moves no money, so it has no
    /// account of its own.
    var badDebtOf: UUID?
    /// Why the claim was written off (`BadDebtPolicy.Reason` raw value).
    var badDebtReason: String?
    /// On rows generated by an installment plan: the plan that owns them.
    /// Together with `installmentPeriod` and `installmentKind` this is the
    /// idempotency key — editing a plan must never duplicate a booked bill.
    var installmentOf: UUID?
    /// 1-based period of a generated row.
    var installmentPeriod: Int = 0
    /// 1 = fee/interest (spend), 2 = principal (liability reduction).
    var installmentKind: Int = 0

    init(
        note: String = "",
        category: CategoryModel? = nil,
        account: AccountModel? = nil,
        baseAmount: Double? = nil,
        income: Bool = false,
        amount: Double = 0,
        date: Date = Date.now,
        repeatType: Int = 0,
        repeatCoefficient: Int = 0,
        discount: Double = 0,
        reimbursable: Bool = false,
        reimbursedAmount: Double = 0,
        reimbursementOf: UUID? = nil,
        refundOf: UUID? = nil,
        badDebtOf: UUID? = nil,
        badDebtReason: String? = nil,
        installmentOf: UUID? = nil,
        installmentPeriod: Int = 0,
        installmentKind: Int = 0,
        transferFeeOf: UUID? = nil,
        adjustment: Bool = false,
        merchant: String? = nil,
        merchantKey: String? = nil,
        bookID: UUID? = BookModel.defaultID
    ) {
        self.id = UUID()
        self.note = note
        self.category = category
        self.account = account
        self.baseAmount = baseAmount
        self.discount = discount
        self.reimbursable = reimbursable
        self.reimbursedAmount = reimbursedAmount
        self.reimbursementOf = reimbursementOf
        self.refundOf = refundOf
        self.badDebtOf = badDebtOf
        self.badDebtReason = badDebtReason
        self.installmentOf = installmentOf
        self.installmentPeriod = installmentPeriod
        self.installmentKind = installmentKind
        self.transferFeeOf = transferFeeOf
        self.adjustment = adjustment
        self.merchant = merchant
        self.merchantKey = merchantKey
        self.bookID = bookID
        self.income = income
        self.amount = amount
        self.date = date
        self.day = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: date) ?? date
        let comps = Calendar.current.dateComponents([.month, .year], from: date)
        self.month = Calendar.current.date(from: comps) ?? date
        self.recurringType = repeatType
        self.recurringCoefficient = repeatCoefficient
        self.onceRecurring = repeatType > 0
    }
}

extension TransactionModel {
    @Transient var wrappedAmount: Double { amount }
    /// Amount in the app's base currency. Legacy rows (written before
    /// multi-currency) stored the base amount directly.
    @Transient var wrappedBaseAmount: Double { baseAmount ?? amount }
    @Transient var currencyCode: String { account?.currencyCode ?? "" }
    @Transient var wrappedDate: Date { date ?? .now }
    @Transient var wrappedNote: String { note ?? "" }
    @Transient var wrappedCategoryName: String { category?.name ?? "" }
    @Transient var wrappedColour: String { category?.colour ?? "#FFFFFF" }

    /// Price before the discount, when one was recorded.
    @Transient var grossAmount: Double { amount + discount }

    /// Still waiting for money. Written off claims are no longer expected
    /// back; a fully reimbursed claim has no remainder to wait for.
    @Transient var isPendingReimbursement: Bool {
        reimbursable && !income && badDebtAt == nil && unreimbursedBaseAmount > 0
    }

    /// Base-currency amount still owed on this claim; zero for every other
    /// row and for a claim that has been paid back in full.
    @Transient var unreimbursedBaseAmount: Double {
        guard reimbursable, !income else { return 0 }
        return ReimbursementPolicy.remaining(baseAmount: wrappedBaseAmount,
                                             reimbursed: reimbursedAmount)
    }

    /// The same remainder in the account's currency, for the ledger and the
    /// pending sheet: the user reads and enters amounts in that currency.
    @Transient var unreimbursedAmount: Double {
        guard reimbursable, !income else { return 0 }
        return ReimbursementPolicy.accountRemaining(amount: amount,
                                                   baseAmount: wrappedBaseAmount,
                                                   reimbursed: reimbursedAmount)
    }

    /// The expense row that writes off a claim: the money is gone, so it is
    /// spend — but no account moved, so it stays out of every balance.
    @Transient var isBadDebt: Bool { badDebtOf != nil }

    /// A claim nobody paid back. The original row stays an ordinary claim (its
    /// spend and balance rules are unchanged); this only drives the badges and
    /// the "undo" action.
    @Transient var isWrittenOffClaim: Bool { badDebtAt != nil }

    /// Income row that settles a claim. It puts the money back into the
    /// account but is not new earnings — counting it would turn a neutral
    /// claim into profit.
    @Transient var isReimbursementIncome: Bool { reimbursementOf != nil }

    /// A row that gives part (or all) of an expense back. Its money returns
    /// to the account, but it is the counterpart of a purchase, not income.
    @Transient var isRefund: Bool { refundOf != nil }
    /// Fee/interest row generated by an installment plan. It is an ordinary
    /// expense: it counts towards spend, budgets and category totals.
    @Transient var isInstallmentFee: Bool { installmentKind == 1 }
    /// Principal repayment. It moves the linked account towards zero, but it
    /// is neither income nor spend — the purchase was already booked.
    @Transient var isInstallmentPrincipal: Bool { installmentKind == 2 }

    /// An ordinary expense that can still be refunded. Claims (money already
    /// expected back), adjustments and refund rows themselves are excluded:
    /// every one of them would double-count the return.
    @Transient var canBeRefunded: Bool {
        !income && !adjustment && !reimbursable && !isRefund && !isBadDebt
            && !isInstallmentFee && !isInstallmentPrincipal
    }

    /// Counts towards "spent" in insights and budgets. A claim contributes
    /// its unreimbursed remainder (the self-paid part) until the money comes
    /// back; adjustments and refunds are not spend at all (a refund *reduces*
    /// spend through `spendBaseAmount`).
    @Transient var countsAsSpend: Bool {
        if income || adjustment || isRefund || isInstallmentPrincipal { return false }
        if reimbursable { return badDebtAt == nil && unreimbursedBaseAmount > 0 }
        return true
    }

    /// Counts towards "earned" in insights.
    @Transient var countsAsIncome: Bool {
        income && !adjustment && !isReimbursementIncome && !isInstallmentPrincipal
    }

    /// A row that belongs in income/spend totals. A claim with an outstanding
    /// balance counts as spend; a fully reimbursed one is pass-through. An
    /// adjustment counts as neither; a refund belongs on the spend side.
    @Transient var countsInTotals: Bool { countsAsSpend || countsAsIncome || isRefund }

    /// Contribution to the **spend** figure: a normal expense adds its base
    /// amount, a claim adds what is still owed, a refund subtracts it,
    /// everything else adds nothing. Every place that answers "how much was
    /// spent" must sum this instead of filtering on `countsAsSpend` and
    /// adding `wrappedBaseAmount` — otherwise partial repayments silently
    /// keep counting as spend.
    @Transient var spendBaseAmount: Double {
        if isRefund { return -wrappedBaseAmount }
        if reimbursable && !income {
            return badDebtAt == nil ? unreimbursedBaseAmount : 0
        }
        return countsAsSpend ? wrappedBaseAmount : 0
    }

    /// Signed amount in the base currency for net-total maths. A claim's
    /// outstanding part is negative spend; a full repayment makes both sides
    /// zero. A refund returns money, so it is positive.
    @Transient var signedBaseAmount: Double {
        if isRefund { return wrappedBaseAmount }
        if countsAsIncome { return wrappedBaseAmount }
        if countsAsSpend { return -spendBaseAmount }
        return 0
    }

    @Transient var nextTransactionDate: Date {
        guard let day else { return date ?? .now }
        switch recurringType {
        case 1: return Calendar.current.date(byAdding: .day, value: recurringCoefficient, to: day) ?? day
        case 2: return Calendar.current.date(byAdding: .day, value: recurringCoefficient * 7, to: day) ?? day
        case 3: return Calendar.current.date(byAdding: .month, value: recurringCoefficient, to: day) ?? day
        default: return date ?? .now
        }
    }
}

// MARK: - Category

@Model
final class CategoryModel {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = ""
    var colour: String = ""
    var income: Bool = false
    var order: Int = 0
    var dateCreated: Date = Date.now
    /// Ledger this category belongs to; see `TransactionModel.bookID`.
    var bookID: UUID? = BookModel.defaultID
    /// CloudKit requires all to-many relationships to be optional.
    var transactions: [TransactionModel]?
    var budget: BudgetModel?
    /// CloudKit requires all to-many relationships to be optional.
    var templates: [TemplateTransactionModel]?

    init(
        name: String = "",
        emoji: String = "",
        colour: String = "",
        income: Bool = false,
        order: Int = 0,
        bookID: UUID? = BookModel.defaultID
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colour = colour
        self.income = income
        self.order = order
        self.bookID = bookID
        self.dateCreated = .now
    }
}

extension CategoryModel {
    @Transient var wrappedName: String { name }
    @Transient var wrappedEmoji: String { emoji }
    @Transient var wrappedColour: String { colour }
    @Transient var wrappedDate: Date { dateCreated }
    @Transient var fullName: String { "\(emoji)  \(name)" }
    @Transient var allTransactions: [TransactionModel] {
        (transactions ?? []).sorted { $0.wrappedDate < $1.wrappedDate }
    }
    @Transient var transactionCount: Int { transactions?.count ?? 0 }
}

// MARK: - Account

@Model
final class AccountModel {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = ""
    var colour: String = ""
    /// 0 = cash, 1 = debit card, 2 = credit card.
    var kind: Int = 0
    /// ISO code this account is denominated in. Empty means the app's base
    /// currency (rows created before multi-currency support).
    var currencyCode: String = ""
    /// Balance before any recorded transaction.
    var openingBalance: Double = 0
    /// Hidden accounts stay in the list but stop counting towards the total.
    var hidden: Bool = false
    /// Archived accounts leave the default list and the total, but every
    /// transaction, transfer and report still resolves their history.
    var archived: Bool = false
    var order: Int = 0
    var dateCreated: Date = Date.now
    /// Ledger this account belongs to; see `TransactionModel.bookID`.
    var bookID: UUID? = BookModel.defaultID
    /// CloudKit requires all to-many relationships to be optional.
    var transactions: [TransactionModel]?
    var outgoingTransfers: [TransferModel]?
    var incomingTransfers: [TransferModel]?

    init(
        name: String = "",
        emoji: String = "",
        colour: String = "",
        kind: Int = 0,
        currencyCode: String = "",
        openingBalance: Double = 0,
        order: Int = 0,
        bookID: UUID? = BookModel.defaultID
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colour = colour
        self.kind = kind
        self.currencyCode = currencyCode
        self.openingBalance = openingBalance
        self.order = order
        self.dateCreated = .now
        self.bookID = bookID
    }
}

// MARK: - Currency rate

/// One row per foreign currency the user holds: how many base-currency units
/// one unit is worth. The base currency itself never needs a row (rate = 1).
@Model
final class CurrencyRate {
    var code: String = ""
    var rate: Double = 1
    var updatedAt: Date = Date.now

    init(code: String = "", rate: Double = 1) {
        self.code = code
        self.rate = rate
        self.updatedAt = .now
    }
}

// MARK: - Transfer

/// Money moved between two accounts. Kept out of `TransactionModel` so the
/// ledger, statistics and budgets never treat a transfer as income or spend.
@Model
final class TransferModel {
    var id: UUID = UUID()
    /// Amount leaving the source account, in that account's currency.
    var amount: Double = 0
    /// Amount arriving in the destination account, in its currency. `0` means
    /// same-currency transfer (legacy rows and same-currency transfers).
    var destinationAmount: Double = 0
    /// Fee charged on top of `amount`, in the source account's currency. Kept
    /// for display only: the money is booked as an expense row linked through
    /// `TransactionModel.transferFeeOf`, so the fee can be categorised and
    /// counted in spend without being charged twice.
    var fee: Double = 0
    var date: Date = Date.now
    var note: String?
    var dateCreated: Date = Date.now
    // Two relationships to the same type need explicit inverses, otherwise
    // CloudKit refuses to load the store ("all relationships have an inverse").
    @Relationship(inverse: \AccountModel.outgoingTransfers)
    var source: AccountModel?
    @Relationship(inverse: \AccountModel.incomingTransfers)
    var destination: AccountModel?

    init(
        amount: Double = 0,
        destinationAmount: Double = 0,
        fee: Double = 0,
        date: Date = .now,
        note: String? = nil,
        source: AccountModel? = nil,
        destination: AccountModel? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.destinationAmount = destinationAmount
        self.fee = fee
        self.date = date
        self.note = note
        self.source = source
        self.destination = destination
        self.dateCreated = .now
    }
}

extension TransferModel {
    @Transient var wrappedDate: Date { date }
    @Transient var wrappedNote: String { note ?? "" }
    /// What lands in the destination account (falls back to `amount`).
    @Transient var receivedAmount: Double {
        destinationAmount > 0 ? destinationAmount : amount
    }
    /// Effective rate applied by this transfer, when it crossed currencies.
    @Transient var impliedRate: Double? {
        guard destinationAmount > 0, amount > 0 else { return nil }
        return destinationAmount / amount
    }
    /// What leaves the source account, fee included.
    /// What leaves the sending account. The fee is a separate expense row, so
    /// charging it here as well would deduct it twice.
    @Transient var outgoingTotal: Double { amount }
}

// MARK: - Installment plan

/// A consumer or bill installment. `principal` is the debt and `fee` the
/// total interest/fees, both in the base currency (no cross-currency plans).
/// `InstallmentPolicy` splits them cent-exactly across `periods`.
///
/// Rows are materialised only for executed periods: a future bill must not
/// restore the card's available credit before the money is actually paid.
@Model
final class InstallmentPlanModel {
    var id: UUID = UUID()
    var bookID: UUID? = BookModel.defaultID
    /// Total debt, in the base currency.
    var principal: Double = 0
    /// Total interest/fees, in the base currency. The only part that is spend.
    var fee: Double = 0
    var periods: Int = 0
    var firstDate: Date = Date.now
    /// Periods already booked. Generated rows for these periods are immutable
    /// when the plan is edited; editing only re-prices future periods.
    var executedPeriods: Int = 0
    var note: String?
    var dateCreated: Date = Date.now
    /// Card the plan hangs off. Each principal row raises its balance towards
    /// zero, which is the only "used limit" model this app has.
    var account: AccountModel?
    /// Category applied to fee rows so they land in the right spend bucket.
    var category: CategoryModel?

    init(principal: Double = 0, fee: Double = 0, periods: Int = 0,
         firstDate: Date = .now, note: String? = nil,
         account: AccountModel? = nil, category: CategoryModel? = nil,
         bookID: UUID? = BookModel.defaultID) {
        self.id = UUID()
        self.principal = principal
        self.fee = fee
        self.periods = periods
        self.firstDate = firstDate
        self.note = note
        self.account = account
        self.category = category
        self.bookID = bookID
        self.dateCreated = .now
    }
}

// MARK: - Category Budget

@Model
final class BudgetModel {
    var id: UUID = UUID()
    var amount: Double = 0
    var startDate: Date = Date.now
    var dateCreated: Date = Date.now
    var type: Int = 0
    var green: Bool = false
    var category: CategoryModel?
    /// Ledger this budget belongs to; see `TransactionModel.bookID`.
    var bookID: UUID? = BookModel.defaultID

    init(amount: Double = 0, startDate: Date = Date.now, type: Int = 3,
         bookID: UUID? = BookModel.defaultID) {
        self.id = UUID()
        self.amount = amount
        self.startDate = startDate
        self.dateCreated = Date.now
        self.type = type
        self.bookID = bookID
    }
}

extension BudgetModel {
    @Transient var wrappedDate: Date { startDate }
    @Transient var wrappedName: String { category?.name ?? "" }
    @Transient var wrappedEmoji: String { category?.emoji ?? "" }
    @Transient var wrappedColour: String { category?.colour ?? "#FFFFFF" }
    @Transient var fullName: String { "\(wrappedEmoji) \(wrappedName)" }

    @Transient var endDate: Date {
        BudgetPeriod.endDate(from: startDate, type: type)
    }
}

// MARK: - Main (overall) Budget

@Model
final class MainBudgetModel {
    var amount: Double = 0
    var startDate: Date = Date.now
    var dateCreated: Date = Date.now
    var type: Int = 0
    /// Ledger this budget belongs to; see `TransactionModel.bookID`.
    var bookID: UUID? = BookModel.defaultID
    var green: Bool = false

    init(amount: Double = 0, startDate: Date = Date.now, type: Int = 3,
         bookID: UUID? = BookModel.defaultID) {
        self.amount = amount
        self.startDate = startDate
        self.dateCreated = .now
        self.type = type
        self.bookID = bookID
    }
}

extension MainBudgetModel {
    @Transient var wrappedDate: Date { startDate }

    @Transient var endDate: Date {
        BudgetPeriod.endDate(from: startDate, type: type)
    }
}

// MARK: - Book migration

/// Runs on every launch. Creates the structural default book and converts
/// legacy rows (whose `bookID` is nil after lightweight migration) to it.
/// Reentrant: a second run writes nothing, so it is safe on every cold start
/// and after an import.
enum BookMigration {

    @MainActor
    @discardableResult
    static func migrate(in context: ModelContext) -> Int {
        var written = ensureDefaultBook(in: context) ? 1 : 0
        written += backfillBookIDs(in: context)

        let defaults = UserDefaults.appGroup
        if defaults.string(forKey: BookSelection.key) == nil {
            BookSelection.select(BookModel.defaultID, in: defaults)
        }
        if written > 0 { try? context.save() }
        return written
    }

    /// Inserts the default book if missing. Does not save, so an import can
    /// call it inside its own single save/rollback boundary.
    @discardableResult
    @MainActor
    static func ensureDefaultBook(in context: ModelContext) -> Bool {
        let books = (try? context.fetch(FetchDescriptor<BookModel>())) ?? []
        guard !books.contains(where: { $0.id == BookModel.defaultID }) else { return false }
        let book = BookModel(name: BookModel.defaultName)
        book.id = BookModel.defaultID
        context.insert(book)
        return true
    }

    /// Legacy rows have no book id. They all belong to the default book, and
    /// assigning it never changes an amount, date or relationship.
    @MainActor
    @discardableResult
    static func backfillBookIDs(in context: ModelContext) -> Int {
        var written = 0
        func fill<T: PersistentModel>(
            _ type: T.Type, value: (T) -> UUID?, assign: (T, UUID) -> Void
        ) {
            let rows = (try? context.fetch(FetchDescriptor<T>())) ?? []
            for row in rows where value(row) == nil {
                assign(row, BookModel.defaultID)
                written += 1
            }
        }
        fill(TransactionModel.self, value: { $0.bookID }) { $0.bookID = $1 }
        fill(CategoryModel.self, value: { $0.bookID }) { $0.bookID = $1 }
        fill(AccountModel.self, value: { $0.bookID }) { $0.bookID = $1 }
        fill(BudgetModel.self, value: { $0.bookID }) { $0.bookID = $1 }
        fill(MainBudgetModel.self, value: { $0.bookID }) { $0.bookID = $1 }
        fill(TemplateTransactionModel.self, value: { $0.bookID }) { $0.bookID = $1 }
        return written
    }
}
