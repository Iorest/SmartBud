//
//  BadDebtLedgerTests.swift
//  SmartBudTests
//
//  A written-off claim turns pass-through money into real spend without moving
//  a single yuan. These tests pin the pairing (loss row points at the claim),
//  the amount (in base currency, no account), the balance-neutrality, the
//  spend effect, and both cleanup directions.
//

import Testing
import Foundation
import SwiftData

@MainActor
@Suite("Bad debt ledger")
struct BadDebtLedgerTests {

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

    private let claimDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func account(_ code: String = "CNY") -> AccountModel {
        let account = AccountModel(name: code, currencyCode: code, openingBalance: 1000)
        context.insert(account)
        return account
    }

    /// A 120 CNY claim recorded at 7.2 CNY per USD (base is USD), so the base
    /// amount (100) and the entered amount (120) differ on purpose.
    private func claim(amount: Double = 120,
                       baseAmount: Double = 100,
                       account: AccountModel) -> TransactionModel {
        let category = CategoryModel(name: "Travel")
        context.insert(category)
        let txn = TransactionModel(note: "Train ticket", category: category, account: account,
                                   baseAmount: baseAmount, income: false,
                                   amount: amount, date: claimDate, reimbursable: true)
        context.insert(txn)
        return txn
    }

    private func writeOffDate(daysAfter days: Int) -> Date {
        Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: days, to: claimDate) ?? claimDate
    }

    private func failure<T>(_ result: Result<T, BadDebtPolicy.Failure>) -> BadDebtPolicy.Failure? {
        if case .failure(let failure) = result { return failure }
        return nil
    }

    @discardableResult
    private func writeOff(_ claim: TransactionModel,
                          days: Int = 100,
                          reason: BadDebtPolicy.Reason = .unreachable)
        -> Result<TransactionModel, BadDebtPolicy.Failure> {
        BadDebtLedger.writeOff(claim, reason: reason,
                               date: writeOffDate(daysAfter: days), in: context)
    }

    @Test("The loss row points at the claim, carries its category and no account")
    func writeOffLinksBack() throws {
        let claim = claim(account: account())
        let row = try writeOff(claim).get()

        #expect(row.badDebtOf == claim.id)
        #expect(row.income == false)
        #expect(row.category?.id == claim.category?.id)
        #expect(row.badDebtReason == "unreachable")
        #expect(BadDebtLedger.reason(of: row) == .unreachable)
        // Nothing moved, so there is no account to move it in: this is what
        // keeps every account balance untouched.
        #expect(row.account == nil)
        // The loss is booked in base currency, not in the claim's currency.
        #expect(row.amount == 100)
        #expect(row.wrappedBaseAmount == 100)
        #expect(claim.badDebtAt == writeOffDate(daysAfter: 100))
    }

    @Test("A written-off claim leaves the pending list and the claim row stays untouched")
    func claimStopsPending() throws {
        let claim = self.claim(account: account())
        #expect(claim.isPendingReimbursement)

        _ = try writeOff(claim).get()

        #expect(claim.isPendingReimbursement == false)
        #expect(claim.isWrittenOffClaim)
        // The original keeps its own amount, account and claim flag: it is the
        // history of the money, the loss row is the accounting of it.
        #expect(claim.amount == 120)
        #expect(claim.reimbursable)
        #expect(claim.account != nil)
    }

    @Test("The loss becomes spend: claim + loss rows add up to the claim's base amount")
    func lossCountsAsSpend() throws {
        let claim = self.claim(account: account())
        let rows = { try self.context.fetch(FetchDescriptor<TransactionModel>()) }

        #expect(Money.double(Money.sum(try rows().map(\.spendBaseAmount))) == 0)

        _ = try writeOff(claim).get()

        let all = try rows()
        #expect(Money.double(Money.sum(all.map(\.spendBaseAmount))) == 100)
        // Net-total maths sees the same loss, and income stays at zero.
        #expect(Money.double(Money.sum(all.map(\.signedBaseAmount))) == -100)
        #expect(all.filter(\.countsAsIncome).isEmpty)
    }

    @Test("A claim that is still young cannot be written off")
    func refusedWhileRecent() throws {
        let claim = self.claim(account: account())
        #expect(failure(writeOff(claim, days: 89)) == .tooRecent(daysLeft: 1))
        #expect(claim.badDebtAt == nil)
        #expect(BadDebtLedger.allWriteOffs(in: context).isEmpty)

        #expect(failure(writeOff(claim, days: 90)) == nil)
    }

    @Test("A paid-back claim, a plain expense and a second write-off are refused")
    func refusedOtherRows() throws {
        let settled = claim(account: account())
        settled.reimbursedAt = writeOffDate(daysAfter: 30)
        #expect(failure(writeOff(settled)) == .alreadySettled)

        let plain = TransactionModel(note: "Lunch", account: account(), baseAmount: 10,
                                     income: false, amount: 10, date: claimDate)
        context.insert(plain)
        #expect(failure(writeOff(plain)) == .notAClaim)

        let claim = self.claim(account: account())
        _ = try writeOff(claim).get()
        #expect(failure(writeOff(claim)) == .alreadyWrittenOff)
        #expect(BadDebtLedger.allWriteOffs(in: context).count == 1)
    }

    @Test("Undoing a write-off puts the claim back into the pending list")
    func undoRestoresPending() throws {
        let claim = self.claim(account: account())
        let row = try writeOff(claim).get()

        BadDebtLedger.undo(row, in: context)

        #expect(claim.isPendingReimbursement)
        #expect(claim.badDebtAt == nil)
        #expect(BadDebtLedger.allWriteOffs(in: context).isEmpty)
        let all = try context.fetch(FetchDescriptor<TransactionModel>())
        #expect(Money.double(Money.sum(all.map(\.spendBaseAmount))) == 0)
    }

    @Test("Deleting the claim deletes its loss row")
    func deletingClaimCascades() throws {
        let claim = self.claim(account: account())
        _ = try writeOff(claim).get()

        BadDebtLedger.prepareForDeletion(of: claim, in: context)
        context.delete(claim)

        #expect(BadDebtLedger.allWriteOffs(in: context).isEmpty)
    }

    @Test("Deleting the loss row alone restores the claim")
    func deletingLossRestoresClaim() throws {
        let claim = self.claim(account: account())
        let row = try writeOff(claim).get()

        BadDebtLedger.prepareForDeletion(of: row, in: context)
        context.delete(row)

        #expect(claim.isPendingReimbursement)
        #expect(claim.badDebtAt == nil)
    }

    @Test("Clearing the claim flag removes the loss with it")
    func clearingClaimRemovesLoss() throws {
        let claim = self.claim(account: account())
        _ = try writeOff(claim).get()

        BadDebtLedger.clearWriteOff(of: claim, in: context)

        #expect(claim.badDebtAt == nil)
        #expect(BadDebtLedger.allWriteOffs(in: context).isEmpty)
    }

    @Test("Editing the claim's amount moves the loss with it")
    func syncFollowsAmount() throws {
        let claim = self.claim(account: account())
        let row = try writeOff(claim).get()

        claim.amount = 240
        claim.baseAmount = 200
        BadDebtLedger.sync(claim, in: context)

        #expect(row.amount == 200)
        #expect(row.wrappedBaseAmount == 200)
        // The day the loss was booked does not move with the amount.
        #expect(row.wrappedDate == writeOffDate(daysAfter: 100))
    }

    @Test("A loss row can neither be refunded nor written off itself")
    func lossRowIsTerminal() throws {
        let claim = self.claim(account: account())
        let row = try writeOff(claim).get()

        #expect(row.canBeRefunded == false)
        #expect(failure(writeOff(row)) == .notAClaim)
    }
}
