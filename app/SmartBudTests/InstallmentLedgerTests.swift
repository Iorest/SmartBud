//
//  InstallmentLedgerTests.swift
//  SmartBudTests
//
//  A plan must generate each booked bill exactly once, must leave booked bills
//  alone when its terms change, and must keep principal out of both spend and
//  income while it restores the card balance.
//

import Testing
import Foundation
import SwiftData

@MainActor
@Suite("Installment ledger")
struct InstallmentLedgerTests {

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Schema([
                BookModel.self,
                TransactionModel.self,
                CategoryModel.self,
                AccountModel.self,
                TransferModel.self,
                CurrencyRate.self,
                BudgetModel.self,
                MainBudgetModel.self,
                TemplateTransactionModel.self,
                InstallmentPlanModel.self
            ]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @discardableResult
    private func plan(principal: Double = 100, fee: Double = 0.30, periods: Int = 3,
                      executed: Int = 0) -> InstallmentPlanModel {
        let card = AccountModel(name: "Card", kind: 2, bookID: BookModel.defaultID)
        context.insert(card)
        let result = InstallmentPlanModel(
            principal: principal, fee: fee, periods: periods,
            firstDate: Date(timeIntervalSince1970: 1_700_000_000),
            account: card, bookID: BookModel.defaultID
        )
        result.executedPeriods = executed
        context.insert(result)
        return result
    }

    @Test("Syncing twice never creates a second bill")
    func idempotent() throws {
        let result = plan(executed: 3)
        let first = InstallmentLedger.sync(result, in: context)
        #expect(first.created == 6)
        #expect(InstallmentLedger.rows(for: result, in: context).count == 6)

        let second = InstallmentLedger.sync(result, in: context)
        #expect(second.created == 0)
        #expect(second.kept == 6)
        #expect(InstallmentLedger.rows(for: result, in: context).count == 6)
    }

    @Test("Editing a plan re-prices only unbooked periods")
    func bookedRowsImmutable() throws {
        let result = plan(principal: 100, fee: 0.30, periods: 3, executed: 1)
        InstallmentLedger.sync(result, in: context)
        let firstFee = try #require(InstallmentLedger.rows(for: result, in: context)
            .first { $0.installmentKind == 1 })
        #expect(Money.cents(firstFee.amount) == Money.cents(0.10))

        result.fee = 3.00
        InstallmentLedger.sync(result, in: context)
        #expect(Money.cents(firstFee.amount) == Money.cents(0.10))
        #expect(InstallmentLedger.rows(for: result, in: context).count == 2)

        InstallmentLedger.bookNext(result, in: context)
        let secondFee = try #require(InstallmentLedger.rows(for: result, in: context)
            .first { $0.installmentPeriod == 2 && $0.installmentKind == 1 })
        #expect(Money.cents(secondFee.amount) == Money.cents(1.00))
    }

    @Test("Principal restores the card but is neither spend nor income")
    func accountingIdentity() throws {
        let result = plan(principal: 100, fee: 0.30, periods: 3, executed: 1)
        InstallmentLedger.sync(result, in: context)
        let rows = InstallmentLedger.rows(for: result, in: context)
        let fee = try #require(rows.first { $0.installmentKind == 1 })
        let principal = try #require(rows.first { $0.installmentKind == 2 })

        #expect(fee.countsAsSpend)
        #expect(Money.cents(fee.spendBaseAmount) == Money.cents(0.10))
        #expect(!principal.countsAsSpend)
        #expect(!principal.countsAsIncome)
        #expect(principal.spendBaseAmount == 0)
        #expect(principal.signedBaseAmount == 0)

        let balance = AccountBalance.current(
            opening: -100,
            transactions: rows.map { (amount: $0.amount, income: $0.income,
                                      isRefund: $0.isRefund) }
        )
        // The fee is real spend; the principal moves the card back towards zero.
        #expect(Money.cents(balance) == Money.cents(-66.77))
    }

    @Test("Deleting a plan removes every generated row")
    func cascade() throws {
        let result = plan(executed: 2)
        InstallmentLedger.sync(result, in: context)
        #expect(InstallmentLedger.rows(for: result, in: context).count == 4)
        InstallmentLedger.prepareForDeletion(result, in: context)
        #expect(InstallmentLedger.rows(for: result, in: context).isEmpty)
    }

    @Test("Credit restoration is capped at the plan principal")
    func restoreCap() throws {
        let result = plan(principal: 100, fee: 0.30, periods: 3, executed: 99)
        #expect(InstallmentLedger.restoredPrincipal(result) == 100)
    }
}
