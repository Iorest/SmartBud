//
//  ImportRoundTripTests.swift
//  SmartBudTests
//
//  Export → import round trips for the rows that carry a link to another row.
//  These are the ones most likely to be dropped silently: a fee without its
//  transfer, or a repayment without its claim, still looks like a normal row.
//

import Testing
import Foundation
import SwiftData

@MainActor
@Suite("Import round trip")
struct ImportRoundTripTests {

    private let fixture: ImportFixture

    init() throws {
        fixture = try ImportFixture()
    }

    @Test("A transfer fee row keeps its link through export and import")
    func transferFeeRoundTrip() throws {
        let transferID = UUID()
        let feeRow = ExportSchema.TransactionDTO(
            id: UUID(), amount: 2.5, date: .now, day: nil, month: nil,
            note: "", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: nil, categoryName: nil,
            accountId: fixture.accountID, accountName: "招行", baseAmount: 2.5,
            accountCurrency: "CNY", discount: 0, reimbursable: false,
            reimbursedAt: nil, reimbursementOf: nil, refundOf: nil, transferFeeOf: transferID,
            adjustment: false
        )
        let transfer = ExportSchema.TransferDTO(
            id: transferID, amount: 100, date: .now, note: nil,
            sourceId: fixture.accountID, sourceName: "招行",
            destinationId: nil, destinationName: nil,
            destinationAmount: 0, fee: 2.5
        )

        _ = try DataImporter.apply(
            fixture.payload(accounts: [fixture.sampleAccount],
                            transactions: [feeRow],
                            transfers: [transfer]),
            context: fixture.context
        )

        let stored = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
            .first { $0.amount == 2.5 }
        #expect(stored?.transferFeeOf == transferID)
        #expect(stored?.countsAsSpend == true)
        #expect(stored?.signedBaseAmount == -2.5)
    }

    @Test("A reimbursement pair keeps its link through export and import")
    func reimbursementRoundTrip() throws {
        let claimID = UUID()
        let claim = ExportSchema.TransactionDTO(
            id: claimID, amount: 88, date: .now, day: nil, month: nil,
            note: "团队午餐", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: nil, categoryName: "餐饮",
            accountId: fixture.accountID, accountName: "招行", baseAmount: 88,
            accountCurrency: "CNY", discount: 0, reimbursable: true,
            reimbursedAt: .now, reimbursementOf: nil, refundOf: nil, transferFeeOf: nil,
            adjustment: false
        )
        let repayment = ExportSchema.TransactionDTO(
            id: UUID(), amount: 88, date: .now, day: nil, month: nil,
            note: "报销回款 · 团队午餐", income: true, recurringType: 0,
            recurringCoefficient: 0, onceRecurring: false, categoryId: nil,
            categoryName: nil, accountId: fixture.accountID, accountName: "招行",
            baseAmount: 88, accountCurrency: "CNY", discount: 0, reimbursable: false,
            reimbursedAt: nil, reimbursementOf: claimID, refundOf: nil, transferFeeOf: nil,
            adjustment: false
        )

        _ = try DataImporter.apply(
            fixture.payload(accounts: [fixture.sampleAccount],
                            transactions: [claim, repayment]),
            context: fixture.context
        )

        let stored = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
        let restoredClaim = stored.first { $0.id == claimID }
        let restoredRepayment = stored.first { $0.reimbursementOf == claimID }

        #expect(restoredClaim?.reimbursedAt != nil)
        #expect(restoredClaim?.countsAsSpend == false)
        #expect(restoredRepayment?.countsAsIncome == false)
        #expect(restoredRepayment?.amount == 88)
    }

    @Test("A refund keeps its link and stays out of income through export and import")
    func refundRoundTrip() throws {
        let purchaseID = UUID()
        let purchase = ExportSchema.TransactionDTO(
            id: purchaseID, amount: 100, date: .now, day: nil, month: nil,
            note: "耳机", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: fixture.categoryID, categoryName: "餐饮",
            accountId: fixture.accountID, accountName: "招行", baseAmount: 720,
            accountCurrency: "CNY", discount: 0, reimbursable: false,
            reimbursedAt: nil, reimbursementOf: nil, refundOf: nil,
            transferFeeOf: nil, adjustment: false
        )
        let refund = ExportSchema.TransactionDTO(
            id: UUID(), amount: 30, date: .now, day: nil, month: nil,
            note: "退款", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: fixture.categoryID, categoryName: "餐饮",
            accountId: fixture.accountID, accountName: "招行", baseAmount: 216,
            accountCurrency: "CNY", discount: 0, reimbursable: false,
            reimbursedAt: nil, reimbursementOf: nil, refundOf: purchaseID,
            transferFeeOf: nil, adjustment: false
        )

        _ = try DataImporter.apply(
            fixture.payload(categories: [fixture.sampleCategory],
                            accounts: [fixture.sampleAccount],
                            transactions: [purchase, refund]),
            context: fixture.context
        )

        let stored = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
        let restoredRefund = stored.first { $0.refundOf == purchaseID }

        #expect(restoredRefund?.isRefund == true)
        #expect(restoredRefund?.countsAsIncome == false)
        #expect(restoredRefund?.countsAsSpend == false)
        #expect(restoredRefund?.spendBaseAmount == -216)
        #expect(Money.double(Money.sum(stored.map(\.spendBaseAmount))) == 504)
    }
}
