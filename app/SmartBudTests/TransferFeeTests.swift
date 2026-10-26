//
//  TransferFeeTests.swift
//  SmartBudTests
//
//  A transfer fee is money spent, so it lives in its own expense row. These
//  tests pin that the transfer itself no longer charges it, that the row is
//  counted as spend, and that creating it twice is harmless.
//

import Testing
import Foundation
import SwiftData

@MainActor
@Suite("Transfer fees")
struct TransferFeeTests {

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

    private struct Fixture {
        let transfer: TransferModel
        let source: AccountModel
        let destination: AccountModel
    }

    private func makeTransfer(fee: Double = 2.5) -> Fixture {
        let bank = AccountModel(name: "Bank", currencyCode: "CNY", openingBalance: 1000)
        let wallet = AccountModel(name: "Wallet", currencyCode: "CNY", openingBalance: 0)
        context.insert(bank)
        context.insert(wallet)
        let transfer = TransferModel(amount: 100, destinationAmount: 0, fee: fee,
                                     date: .now, note: nil,
                                     source: bank, destination: wallet)
        context.insert(transfer)
        return Fixture(transfer: transfer, source: bank, destination: wallet)
    }

    @Test("Recording the fee writes an expense row on the sending account")
    func writesFeeRow() throws {
        let setup = makeTransfer()
        let row = try #require(TransferFeeLedger.recordFee(for: setup.transfer, in: context))

        #expect(!row.income)
        #expect(row.amount == 2.5)
        #expect(row.account?.id == setup.source.id)
        #expect(row.transferFeeOf == setup.transfer.id)
        #expect(row.category?.income == false)
        #expect(row.category?.name == String.appLocalized(TransferFeeLedger.categoryNameKey))
    }

    @Test("The fee row counts as spend; the transfer does not")
    func feeCountsAsSpend() throws {
        let transfer = makeTransfer().transfer
        let row = try #require(TransferFeeLedger.recordFee(for: transfer, in: context))

        #expect(row.countsAsSpend)
        #expect(!row.countsAsIncome)
        #expect(row.signedBaseAmount == -2.5)
        #expect(transfer.outgoingTotal == 100)   // fee is not folded in any more
    }

    @Test("Balance is the moved amount plus the fee row, not the fee twice")
    func balanceCountsOnce() throws {
        let setup = makeTransfer()
        _ = TransferFeeLedger.recordFee(for: setup.transfer, in: context)

        let rows = (try context.fetch(FetchDescriptor<TransactionModel>()))
            .map { (amount: $0.amount, income: $0.income) }
        let sent = AccountBalance.current(opening: setup.source.openingBalance,
                                          transactions: rows,
                                          transfersIn: 0,
                                          transfersOut: setup.transfer.outgoingTotal)
        let received = AccountBalance.current(opening: setup.destination.openingBalance,
                                              transactions: [],
                                              transfersIn: setup.transfer.receivedAmount,
                                              transfersOut: 0)
        #expect(sent == 897.5)
        #expect(received == 100)
    }

    @Test("A zero fee writes nothing")
    func zeroFeeDoesNothing() {
        let transfer = makeTransfer(fee: 0).transfer
        #expect(TransferFeeLedger.recordFee(for: transfer, in: context) == nil)
        #expect(TransferFeeLedger.feeRows(in: context).isEmpty)
    }

    @Test("Recording the same fee twice keeps one row")
    func recordIsIdempotent() {
        let transfer = makeTransfer().transfer
        TransferFeeLedger.recordFee(for: transfer, in: context)
        TransferFeeLedger.recordFee(for: transfer, in: context)

        #expect(TransferFeeLedger.feeRows(in: context).count == 1)
    }

    @Test("Deleting the fee rows leaves the transfer alone")
    func deleteFeeRows() {
        let transfer = makeTransfer().transfer
        TransferFeeLedger.recordFee(for: transfer, in: context)

        TransferFeeLedger.deleteFeeRows(for: transfer, in: context)

        #expect(TransferFeeLedger.feeRows(in: context).isEmpty)
        #expect((try? context.fetch(FetchDescriptor<TransferModel>()))?.count == 1)
    }

    @Test("Deleting the fee row clears the transfer's stored fee")
    func detachClearsDisplayedFee() throws {
        let setup = makeTransfer()
        let row = try #require(TransferFeeLedger.recordFee(for: setup.transfer, in: context))

        TransferFeeLedger.detachFeeRow(row, in: context)

        // `migrate` rebuilds a row for every transfer whose `fee` is > 0, so
        // this is what keeps a deleted charge from coming back on next launch.
        #expect(setup.transfer.fee == 0)
    }

    @Test("An undo snapshot keeps the transfer link")
    func snapshotKeepsTransferLink() throws {
        let transfer = makeTransfer().transfer
        let row = try #require(TransferFeeLedger.recordFee(for: transfer, in: context))

        let restored = TransactionSnapshot(row).makeTransaction()

        #expect(restored.transferFeeOf == transfer.id)
    }

    @Test("Switching language does not create a second fee category")
    func categorySurvivesLanguageChange() throws {
        let first = makeTransfer().transfer
        let row = try #require(TransferFeeLedger.recordFee(for: first, in: context))
        let original = try #require(row.category)

        // Simulate the app running in another language: the localised name no
        // longer matches, but the icon/colour still identifies the category.
        original.name = "Transfer Fee"
        let again = TransferFeeLedger.feeCategory(in: context)

        #expect(again?.id == original.id)
        let count = (try context.fetch(FetchDescriptor<CategoryModel>()))
            .filter { !$0.income }.count
        #expect(count == 1)
    }

    @Test("The fee reuses one category instead of creating a new one each time")
    func reusesCategory() {
        let first = makeTransfer().transfer
        let second = makeTransfer().transfer

        let firstRow = TransferFeeLedger.recordFee(for: first, in: context)
        let secondRow = TransferFeeLedger.recordFee(for: second, in: context)

        #expect(firstRow?.category?.id == secondRow?.category?.id)
    }
}
