//
//  ReimbursementLedgerTests.swift
//  SmartBudTests
//
//  A claim must be neutral: the expense is kept out of spend, and settling it
//  puts the money back without turning the repayment into income. These tests
//  pin both halves and the cleanup rules.
//

import Testing
import Foundation
import SwiftData

@MainActor
@Suite("Reimbursement ledger")
struct ReimbursementLedgerTests {

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

    private func claim(amount: Double = 88, account: AccountModel? = nil) -> TransactionModel {
        let txn = TransactionModel(note: "Team lunch", account: account,
                                   baseAmount: amount, income: false,
                                   amount: amount, date: .now, reimbursable: true)
        context.insert(txn)
        return txn
    }

    @discardableResult
    private func repay(_ claim: TransactionModel, _ amount: Double,
                       date: Date = .now) -> TransactionModel? {
        switch ReimbursementLedger.repay(claim, amount: amount, date: date, in: context) {
        case .success(let row): return row
        case .failure: return nil
        }
    }

    @Test("Settling writes one income row linked to the claim")
    func settleWritesRepayment() throws {
        let txn = claim()
        let row = try #require(ReimbursementLedger.settle(txn, in: context))

        #expect(txn.reimbursedAt != nil)
        #expect(row.income)
        #expect(row.amount == 88)
        #expect(row.reimbursementOf == txn.id)
        #expect(row.account?.id == txn.account?.id)
        #expect(!row.wrappedNote.isEmpty)
    }

    @Test("Neither half of the pair counts as spend or income")
    func pairIsNeutral() throws {
        let txn = claim()
        let row = try #require(ReimbursementLedger.settle(txn, in: context))

        #expect(!txn.countsAsSpend)
        #expect(!txn.countsAsIncome)
        #expect(!row.countsAsIncome)
        #expect(!row.countsAsSpend)
        #expect(txn.signedBaseAmount == 0)
        #expect(row.signedBaseAmount == 0)
        #expect(!txn.isPendingReimbursement)
    }

    @Test("Settling twice does not create a second row")
    func settleIsIdempotent() {
        let txn = claim()
        ReimbursementLedger.settle(txn, in: context)
        ReimbursementLedger.settle(txn, in: context)

        #expect(ReimbursementLedger.repayments(in: context).count == 1)
    }

    @Test("Undoing a settlement removes the row and the date")
    func unsettleRemovesRow() {
        let txn = claim()
        ReimbursementLedger.settle(txn, in: context)
        ReimbursementLedger.unsettle(txn, in: context)

        #expect(txn.reimbursedAt == nil)
        #expect(ReimbursementLedger.repayments(in: context).isEmpty)
        #expect(txn.isPendingReimbursement)
    }

    @Test("The pair leaves the account balance where it started")
    func balanceIsRestored() throws {
        let account = AccountModel(name: "Bank", currencyCode: "CNY", openingBalance: 1000)
        context.insert(account)
        let txn = claim(amount: 88, account: account)

        let afterSpend = AccountBalance.current(
            opening: account.openingBalance,
            transactions: (try context.fetch(FetchDescriptor<TransactionModel>()))
                .map { (amount: $0.amount, income: $0.income, isRefund: $0.isRefund) },
            transfersIn: 0, transfersOut: 0)
        #expect(afterSpend == 912)

        ReimbursementLedger.settle(txn, in: context)

        let afterSettle = AccountBalance.current(
            opening: account.openingBalance,
            transactions: (try context.fetch(FetchDescriptor<TransactionModel>()))
                .map { (amount: $0.amount, income: $0.income, isRefund: $0.isRefund) },
            transfersIn: 0, transfersOut: 0)
        #expect(afterSettle == 1000)
    }

    @Test("Deleting the claim deletes its repayment")
    func deletingClaimCascades() throws {
        let txn = claim()
        ReimbursementLedger.settle(txn, in: context)
        ReimbursementLedger.prepareForDeletion(of: txn, in: context)
        context.delete(txn)

        #expect(ReimbursementLedger.repayments(in: context).isEmpty)
    }

    @Test("Deleting the repayment puts the claim back in the pending list")
    func deletingRepaymentReopensClaim() throws {
        let txn = claim()
        let row = try #require(ReimbursementLedger.settle(txn, in: context))

        ReimbursementLedger.prepareForDeletion(of: row, in: context)
        context.delete(row)

        #expect(txn.reimbursedAt == nil)
        #expect(txn.isPendingReimbursement)
    }

    @Test("Editing a settled claim keeps the repayment in step")
    func syncFollowsTheClaim() throws {
        let first = AccountModel(name: "A", currencyCode: "CNY", openingBalance: 0)
        let second = AccountModel(name: "B", currencyCode: "CNY", openingBalance: 0)
        context.insert(first)
        context.insert(second)

        let txn = claim(amount: 88, account: first)
        let row = try #require(ReimbursementLedger.settle(txn, in: context))

        txn.amount = 120
        txn.baseAmount = 120
        txn.account = second
        ReimbursementLedger.sync(txn, in: context)

        #expect(row.amount == 120)
        #expect(row.baseAmount == 120)
        #expect(row.account?.id == second.id)
    }

    @Test("Editing the repayment row moves the claim with it")
    func editingRepaymentSyncsClaim() throws {
        let txn = claim(amount: 88)
        let row = try #require(ReimbursementLedger.settle(txn, in: context))

        row.amount = 120
        row.baseAmount = 120
        ReimbursementLedger.syncClaim(from: row, in: context)

        #expect(txn.amount == 120)
        #expect(txn.baseAmount == 120)
    }

    @Test("An undo snapshot keeps the repayment link")
    func snapshotKeepsRepaymentLink() throws {
        let txn = claim()
        let row = try #require(ReimbursementLedger.settle(txn, in: context))

        let restored = TransactionSnapshot(row).makeTransaction()

        // Without the link the restored row would count as ordinary income
        // while the claim stays excluded from spend: the pair stops balancing.
        #expect(restored.reimbursementOf == txn.id)
        #expect(!restored.countsAsIncome)
    }

    @Test("Editing the repayment amount does not move the claim to another account")
    func editingRepaymentKeepsClaimAccount() throws {
        let first = AccountModel(name: "A", currencyCode: "CNY", openingBalance: 0)
        let second = AccountModel(name: "B", currencyCode: "CNY", openingBalance: 0)
        context.insert(first)
        context.insert(second)

        let txn = claim(amount: 88, account: first)
        let row = try #require(ReimbursementLedger.settle(txn, in: context))

        row.account = second
        row.amount = 120
        row.baseAmount = 120
        ReimbursementLedger.syncClaim(from: row, in: context)

        #expect(txn.amount == 120)
        #expect(txn.account?.id == first.id)
    }

    @Test("A repayment row is never offered as a claim")
    func repaymentCannotBeClaimed() throws {
        let txn = claim()
        let row = try #require(ReimbursementLedger.settle(txn, in: context))

        #expect(ReimbursementLedger.settle(row, in: context) == nil)
        #expect(!row.isPendingReimbursement)
    }

    @Test("A partial repayment leaves the self-paid part in spend")
    func partialRepaymentCountsAsSelfPay() throws {
        let txn = claim(amount: 100)
        let row = try #require(repay(txn, 40))

        #expect(txn.reimbursedAmount == 40)
        #expect(txn.reimbursedAt == nil)
        #expect(txn.isPendingReimbursement)
        #expect(txn.countsAsSpend)
        #expect(txn.spendBaseAmount == 60)
        #expect(txn.signedBaseAmount == -60)
        #expect(row.amount == 40)
        #expect(row.baseAmount == 40)
        #expect(row.reimbursementOf == txn.id)
    }

    @Test("Several repayments accumulate and full settlement clears spend")
    func repeatedRepayments() throws {
        let txn = claim(amount: 100)
        _ = try #require(repay(txn, 30))
        _ = try #require(repay(txn, 70))

        #expect(ReimbursementLedger.repayments(for: txn, in: context).count == 2)
        #expect(txn.reimbursedAmount == 100)
        #expect(txn.reimbursedAt != nil)
        #expect(!txn.isPendingReimbursement)
        #expect(txn.spendBaseAmount == 0)
        #expect(txn.signedBaseAmount == 0)
    }

    @Test("A repayment past the balance is refused without writing a row")
    func excessRepaymentIsRefused() throws {
        let txn = claim(amount: 100)
        _ = try #require(repay(txn, 60))

        switch ReimbursementLedger.repay(txn, amount: 50, in: context) {
        case .failure(let failure):
            #expect(failure == .exceedsRemaining(remaining: 40))
        case .success:
            #expect(Bool(false), "An overpayment must not be written")
        }
        #expect(ReimbursementLedger.repayments(for: txn, in: context).count == 1)
        #expect(txn.reimbursedAmount == 60)
    }

    @Test("Undoing a partial settlement removes all instalments")
    func unsettleRemovesEveryRow() throws {
        let txn = claim(amount: 100)
        _ = try #require(repay(txn, 40))
        _ = try #require(repay(txn, 30))

        ReimbursementLedger.unsettle(txn, in: context)

        #expect(txn.reimbursedAmount == 0)
        #expect(txn.reimbursedAt == nil)
        #expect(ReimbursementLedger.repayments(for: txn, in: context).isEmpty)
        #expect(txn.spendBaseAmount == 100)
    }

    @Test("Deleting one instalment puts only that part back into the balance")
    func deletingOneRepaymentReopensPartOfClaim() throws {
        let txn = claim(amount: 100)
        _ = try #require(repay(txn, 40))
        let second = try #require(repay(txn, 30))

        ReimbursementLedger.prepareForDeletion(of: second, in: context)
        context.delete(second)

        #expect(txn.reimbursedAmount == 40)
        #expect(txn.reimbursedAt == nil)
        #expect(txn.unreimbursedBaseAmount == 60)
    }

    @Test("Editing a partially reimbursed claim keeps the rows within the new amount")
    func editingPartialClaimKeepsRowsInStep() throws {
        let txn = claim(amount: 100)
        let row = try #require(repay(txn, 50))

        txn.amount = 200
        txn.baseAmount = 200
        ReimbursementLedger.sync(txn, in: context)

        #expect(txn.reimbursedAmount == 50)
        #expect(row.baseAmount == 50)
        #expect(txn.unreimbursedBaseAmount == 150)
    }

    @Test("An undo snapshot keeps the paid-back amount of a partial claim")
    func snapshotKeepsPartialAmount() throws {
        let txn = claim(amount: 100)
        _ = try #require(repay(txn, 40))

        let restored = TransactionSnapshot(txn).makeTransaction()

        #expect(restored.reimbursedAmount == 40)
        #expect(restored.unreimbursedBaseAmount == 60)
        #expect(restored.reimbursedAt == nil)
    }

    @Test("Old settled claims get their paid-back amount backfilled")
    func legacySettlementIsBackfilled() {
        let txn = claim(amount: 88)
        txn.reimbursedAt = .now

        #expect(ReimbursementLedger.migrate(in: context) == 1)
        #expect(txn.reimbursedAmount == 88)
        #expect(txn.spendBaseAmount == 0)
        #expect(ReimbursementLedger.migrate(in: context) == 0)
    }

    @Test("Editing a fully settled claim with instalments does not multiply the money")
    func editingFullClaimKeepsRowSum() throws {
        let txn = claim(amount: 100)
        _ = try #require(repay(txn, 40))
        _ = try #require(repay(txn, 60))

        txn.amount = 200
        txn.baseAmount = 200
        ReimbursementLedger.sync(txn, in: context)

        let rows = ReimbursementLedger.repayments(for: txn, in: context)
        #expect(Money.double(Money.sum(rows.map(\.wrappedBaseAmount))) == 200)
        #expect(rows.reduce(0) { $0 + $1.amount } == 200)
        #expect(txn.reimbursedAmount == 200)
    }
}
