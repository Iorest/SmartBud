//
//  RefundLedgerTests.swift
//  SmartBudTests
//
//  A refund must behave like the mirror image of a purchase: it returns money
//  to the account, reduces the original category's spend where it arrived, and
//  never becomes income. These tests pin the sum rule (three partial refunds,
//  a fourth refused), the frozen exchange rate, the balance effect and the
//  cleanup when the purchase is deleted.
//

import Testing
import Foundation
import SwiftData

@MainActor
@Suite("Refund ledger")
struct RefundLedgerTests {

    /// Held for the whole test: a released container invalidates its context.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Schema([
                TransactionModel.self,
                CategoryModel.self,
                AccountModel.self,
                TransferModel.self,
                CurrencyRate.self,
                BudgetModel.self,
                MainBudgetModel.self,
                TemplateTransactionModel.self
            ]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private let originalDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func account(_ code: String = "CNY") -> AccountModel {
        let account = AccountModel(name: code, currencyCode: code, openingBalance: 1000)
        context.insert(account)
        return account
    }

    /// 100 CNY purchase recorded at 7.2 CNY per USD (base is USD).
    private func purchase(amount: Double = 100,
                          baseAmount: Double = 100,
                          account: AccountModel,
                          date: Date? = nil) -> TransactionModel {
        let category = CategoryModel(name: "Shopping")
        context.insert(category)
        let txn = TransactionModel(note: "Headphones", category: category, account: account,
                                   baseAmount: baseAmount, income: false,
                                   amount: amount, date: date ?? originalDate)
        context.insert(txn)
        return txn
    }

    @discardableResult
    private func refund(_ original: TransactionModel,
                        amount: Double,
                        date: Date? = nil,
                        account: AccountModel? = nil) -> Result<TransactionModel, RefundPolicy.Failure> {
        RefundLedger.refund(original, amount: amount,
                            date: date ?? originalDate.addingTimeInterval(86_400),
                            account: account ?? original.account, note: "", in: context)
    }

    /// The refusal inside a `Result`, or `nil` when it succeeded. `Result`
    /// itself is not comparable because the row it carries is a class.
    private func failure<T>(_ result: Result<T, RefundPolicy.Failure>) -> RefundPolicy.Failure? {
        if case .failure(let failure) = result { return failure }
        return nil
    }

    @Test("A refund carries the original category and the purchase link")
    func refundLinksBack() throws {
        let original = purchase(account: account())
        let row = try refund(original, amount: 30).get()

        #expect(row.refundOf == original.id)
        #expect(row.income == false)
        #expect(row.category?.id == original.category?.id)
        #expect(row.amount == 30)
        #expect(row.baseAmount == 30)
    }

    @Test("Three partial refunds reduce spend to zero, the fourth is refused")
    func partialRefundsSum() throws {
        let original = purchase(account: account())
        for amount in [40.0, 30.0, 30.0] {
            _ = try refund(original, amount: amount).get()
        }

        let rows = try context.fetch(FetchDescriptor<TransactionModel>())
        let spent = Money.double(Money.sum(rows.map(\.spendBaseAmount)))
        #expect(spent == 0)
        #expect(RefundLedger.remaining(for: original, in: context) == 0)

        let fourth = refund(original, amount: 0.01)
        #expect(failure(fourth) == .exceedsRemaining(remaining: 0))
    }

    @Test("A refund never counts as income")
    func refundIsNotIncome() throws {
        let original = purchase(account: account())
        _ = try refund(original, amount: 100).get()

        let rows = try context.fetch(FetchDescriptor<TransactionModel>())
        let income = Money.sum(rows.filter(\.countsAsIncome).map(\.wrappedBaseAmount))
        #expect(Money.double(income) == 0)
        #expect(rows.first { $0.isRefund }?.countsAsIncome == false)
        #expect(rows.first { $0.isRefund }?.countsInTotals == true)
    }

    @Test("A cross-currency refund uses the rate frozen on the purchase")
    func frozenRate() throws {
        let account = account("USD")
        // 100 USD bought at 7.2: base 720. Refund 30 USD → 216 base.
        let original = purchase(amount: 100, baseAmount: 720, account: account)
        let row = try refund(original, amount: 30).get()

        #expect(row.baseAmount == 216)
        let rows = try context.fetch(FetchDescriptor<TransactionModel>())
        #expect(Money.double(Money.sum(rows.map(\.spendBaseAmount))) == 504)
    }

    @Test("The refund returns money to the account without touching spend twice")
    func balanceMovesBack() throws {
        let account = account()
        let original = purchase(account: account)
        _ = try refund(original, amount: 30).get()

        let rows = try context.fetch(FetchDescriptor<TransactionModel>())
            .map { (amount: $0.amount, income: $0.income, isRefund: $0.isRefund) }
        let balance = AccountBalance.current(opening: account.openingBalance, transactions: rows)
        #expect(balance == 930)
    }

    @Test("Money cannot arrive before the purchase, or in another currency")
    func refusals() throws {
        let original = purchase(account: account("CNY"))
        let early = refund(original, amount: 10, date: originalDate.addingTimeInterval(-60))
        #expect(failure(early) == .arrivedBeforeExpense)

        let usd = account("USD")
        let wrongCurrency = refund(original, amount: 10, account: usd)
        #expect(failure(wrongCurrency) == .currencyMismatch)

        let zero = refund(original, amount: 0)
        #expect(failure(zero) == .nonPositiveAmount)
    }

    @Test("Income, claims, adjustments and refunds cannot be refunded")
    func onlyExpenses() throws {
        let account = account()
        let income = TransactionModel(note: "Salary", account: account, baseAmount: 50,
                                      income: true, amount: 50, date: originalDate)
        context.insert(income)
        let claim = TransactionModel(note: "Lunch", account: account, baseAmount: 20,
                                     income: false, amount: 20, date: originalDate,
                                     reimbursable: true)
        context.insert(claim)
        let adjustment = TransactionModel(note: "Fix", account: account, baseAmount: 5,
                                          income: false, amount: 5, date: originalDate,
                                          adjustment: true)
        context.insert(adjustment)

        #expect(failure(refund(income, amount: 1)) == .notAnExpense)
        #expect(failure(refund(claim, amount: 1)) == .notAnExpense)
        #expect(failure(refund(adjustment, amount: 1)) == .notAnExpense)

        let original = purchase(account: account)
        let row = try refund(original, amount: 10).get()
        #expect(failure(refund(row, amount: 1)) == .notAnExpense)
    }

    @Test("Deleting the purchase deletes its refunds")
    func deletingPurchaseCascades() throws {
        let original = purchase(account: account())
        _ = try refund(original, amount: 30).get()
        _ = try refund(original, amount: 20).get()

        RefundLedger.prepareForDeletion(of: original, in: context)
        context.delete(original)

        let rows = try context.fetch(FetchDescriptor<TransactionModel>())
        #expect(rows.isEmpty)
    }

    @Test("Deleting one refund puts the amount back without touching the others")
    func deletingRefundRestoresRemaining() throws {
        let original = purchase(account: account())
        let first = try refund(original, amount: 30).get()
        _ = try refund(original, amount: 20).get()

        context.delete(first)
        #expect(RefundLedger.remaining(for: original, in: context) == 80)
    }

    @Test("Editing a refund re-checks the remaining amount")
    func editValidation() throws {
        let original = purchase(account: account())
        let row = try refund(original, amount: 30).get()
        _ = try refund(original, amount: 20).get()

        #expect(RefundLedger.update(row, amount: 80, date: originalDate.addingTimeInterval(60),
                                   account: original.account, note: "", in: context) == nil)
        #expect(row.amount == 80)
        #expect(row.baseAmount == 80)

        #expect(RefundLedger.update(row, amount: 81, date: originalDate.addingTimeInterval(60),
                                   account: original.account, note: "", in: context)
                == .exceedsRemaining(remaining: 80))
        #expect(row.amount == 80)
    }

    @Test("An undo snapshot keeps the refund link")
    func snapshotKeepsLink() throws {
        let original = purchase(account: account())
        let row = try refund(original, amount: 25).get()
        let travelBook = UUID()
        row.bookID = travelBook

        let snapshot = TransactionSnapshot(row)
        let restored = snapshot.makeTransaction()

        #expect(restored.bookID == travelBook)
        #expect(restored.refundOf == original.id)
        #expect(restored.spendBaseAmount == -25)
        #expect(restored.id == row.id)
    }
}
