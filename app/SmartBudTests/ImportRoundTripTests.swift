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

    @Test("A write-off keeps its reason and its link through export and import")
    func badDebtRoundTrip() throws {
        let claimID = UUID()
        var claim = ExportSchema.TransactionDTO(
            id: claimID, amount: 100, date: .now, day: nil, month: nil,
            note: "差旅垫付", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: fixture.categoryID, categoryName: "餐饮",
            accountId: fixture.accountID, accountName: "招行", baseAmount: 720,
            accountCurrency: "CNY", discount: 0, reimbursable: true,
            reimbursedAt: nil, reimbursementOf: nil, refundOf: nil,
            transferFeeOf: nil, adjustment: false
        )
        claim.badDebtAt = .now
        let loss = ExportSchema.TransactionDTO(
            id: UUID(), amount: 100, date: .now, day: nil, month: nil,
            note: "坏账", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: fixture.categoryID, categoryName: "餐饮",
            accountId: nil, accountName: nil, baseAmount: 720,
            accountCurrency: nil, discount: 0, reimbursable: false,
            reimbursedAt: nil, reimbursementOf: nil, refundOf: nil,
            transferFeeOf: nil, adjustment: false, badDebtOf: claimID,
            badDebtReason: "unreachable", badDebtAt: nil
        )

        _ = try DataImporter.apply(
            fixture.payload(categories: [fixture.sampleCategory],
                            accounts: [fixture.sampleAccount],
                            transactions: [claim, loss]),
            context: fixture.context
        )

        let stored = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
        let restoredClaim = stored.first { $0.id == claimID }
        let restoredLoss = stored.first { $0.badDebtOf == claimID }

        #expect(restoredClaim?.badDebtAt != nil)
        #expect(restoredClaim?.isPendingReimbursement == false)
        #expect(restoredClaim?.countsAsSpend == false)
        #expect(restoredLoss?.isBadDebt == true)
        #expect(restoredLoss?.badDebtReason == "unreachable")
        #expect(restoredLoss?.account == nil)
        #expect(restoredLoss?.countsAsSpend == true)
        #expect(Money.double(Money.sum(stored.map(\.spendBaseAmount))) == 720)
    }

    @Test("Partial payments survive export and import; old full settlements are inferred")
    func reimbursedAmountRoundTrip() throws {
        let partialID = UUID()
        let legacyID = UUID()
        var partial = ExportSchema.TransactionDTO(
            id: partialID, amount: 100, date: .now, day: nil, month: nil,
            note: "团队午餐", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: nil, categoryName: nil,
            accountId: fixture.accountID, accountName: "招行", baseAmount: 100,
            accountCurrency: "CNY", discount: 0, reimbursable: true,
            reimbursedAt: nil, reimbursementOf: nil, refundOf: nil, transferFeeOf: nil,
            adjustment: false
        )
        partial.reimbursedAmount = 40
        let wire = try JSONSerialization.jsonObject(with: JSONEncoder().encode(partial)) as? [String: Any]
        #expect(wire?["reimbursedAmount"] as? Double == 40)
        let instalment = ExportSchema.TransactionDTO(
            id: UUID(), amount: 40, date: .now, day: nil, month: nil,
            note: "报销回款", income: true, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: nil, categoryName: nil,
            accountId: fixture.accountID, accountName: "招行", baseAmount: 40,
            accountCurrency: "CNY", discount: 0, reimbursable: false,
            reimbursedAt: nil, reimbursementOf: partialID, refundOf: nil,
            transferFeeOf: nil, adjustment: false
        )
        // A backup written before schema 9 carries only the settlement date.
        var legacy = partial
        legacy.id = legacyID
        legacy.reimbursedAmount = nil
        legacy.reimbursedAt = .now

        _ = try DataImporter.apply(
            fixture.payload(accounts: [fixture.sampleAccount],
                            transactions: [partial, instalment, legacy]),
            context: fixture.context
        )

        let stored = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
        let restoredPartial = try #require(stored.first { $0.id == partialID })
        let restoredLegacy = try #require(stored.first { $0.id == legacyID })

        #expect(restoredPartial.reimbursedAmount == 40)
        #expect(restoredPartial.unreimbursedBaseAmount == 60)
        #expect(restoredPartial.isPendingReimbursement)
        #expect(restoredLegacy.reimbursedAmount == 100)
        #expect(restoredLegacy.spendBaseAmount == 0)
    }

    @Test("A plan and its generated bills survive export and import together")
    func installmentPlanRoundTrip() throws {
        let planID = UUID()
        let plan = ExportSchema.InstallmentPlanDTO(
            id: planID, bookID: BookModel.defaultID, principal: 100, fee: 0.30,
            periods: 3, firstDate: .now, executedPeriods: 2,
            accountId: fixture.accountID, accountName: "招行",
            categoryId: nil, categoryName: nil, note: "phone", dateCreated: .now
        )
        func bill(_ period: Int, _ kind: Int) -> ExportSchema.TransactionDTO {
            ExportSchema.TransactionDTO(
                id: UUID(), amount: kind == 1 ? 0.10 : 33.33, date: .now, day: nil, month: nil,
                note: "", income: kind == 2, recurringType: 0, recurringCoefficient: 0,
                onceRecurring: false, categoryId: nil, categoryName: nil,
                accountId: fixture.accountID, accountName: "招行",
                baseAmount: kind == 1 ? 0.10 : 33.33, accountCurrency: "CNY",
                discount: 0, reimbursable: false, reimbursedAt: nil,
                reimbursementOf: nil, refundOf: nil, transferFeeOf: nil,
                adjustment: false, badDebtOf: nil, badDebtReason: nil, badDebtAt: nil,
                bookID: BookModel.defaultID,
                installmentOf: planID, installmentPeriod: period, installmentKind: kind
            )
        }

        _ = try DataImporter.apply(
            fixture.payload(accounts: [fixture.sampleAccount],
                            transactions: [bill(1, 1), bill(1, 2), bill(2, 1), bill(2, 2)],
                            installmentPlans: [plan]),
            context: fixture.context
        )

        let plans = InstallmentLedger.plans(in: fixture.context)
        let storedPlan = try #require(plans.first)
        #expect(storedPlan.id == planID)
        #expect(storedPlan.principal == 100)
        #expect(storedPlan.fee == 0.30)
        #expect(storedPlan.periods == 3)
        #expect(storedPlan.executedPeriods == 2)
        #expect(storedPlan.accountID == fixture.accountID)

        let rows = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
        #expect(rows.count == 4)
        #expect(rows.allSatisfy { $0.installmentOf == planID })
        #expect(Set(rows.map(\.installmentPeriod)) == [1, 2])
        #expect(rows.filter { $0.installmentKind == 2 }.allSatisfy {
            !$0.countsAsSpend && !$0.countsAsIncome
        })
        #expect(rows.filter { $0.installmentKind == 1 }.allSatisfy {
            $0.countsAsSpend && !$0.countsAsIncome
        })
    }

    @Test("Credit card terms survive export and import; debit accounts drop them")
    func creditCardTermsRoundTrip() throws {
        var card = fixture.sampleAccount
        card.id = UUID()
        card.kind = 2
        card.creditLimit = 5000
        card.statementDay = 25
        card.dueDay = 3
        var debit = fixture.sampleAccount
        debit.id = UUID()
        debit.creditLimit = 5000
        debit.statementDay = 25

        let wire = try JSONSerialization.jsonObject(with: JSONEncoder().encode(card)) as? [String: Any]
        #expect(wire?["creditLimit"] as? Double == 5000)
        #expect(wire?["statementDay"] as? Int == 25)
        #expect(wire?["dueDay"] as? Int == 3)

        _ = try DataImporter.apply(fixture.payload(accounts: [card, debit]),
                                   context: fixture.context)

        let stored = try fixture.context.fetch(FetchDescriptor<AccountModel>())
        let restoredCard = try #require(stored.first { $0.id == card.id })
        let restoredDebit = try #require(stored.first { $0.id == debit.id })
        #expect(restoredCard.creditLimit == 5000)
        #expect(restoredCard.statementDay == 25)
        #expect(restoredCard.dueDay == 3)
        #expect(restoredDebit.creditLimit == nil)
        #expect(restoredDebit.statementDay == nil)
    }

    @Test("Labels and receipt references survive a backup round trip")
    func tagAndAttachmentRoundTrip() throws {
        let tagID = UUID()
        let attachmentID = UUID()
        let tag = ExportSchema.TagDTO(
            id: tagID, name: "Food", color: "#5E9EFF", order: 0,
            bookID: BookModel.defaultID)
        let row = ExportSchema.TransactionDTO(
            id: UUID(), amount: 12.5, date: .now, day: nil, month: nil,
            note: "lunch", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: nil, categoryName: nil,
            accountId: fixture.accountID, accountName: "招行", baseAmount: 12.5,
            accountCurrency: "CNY", discount: 0, reimbursable: false,
            reimbursedAt: nil, reimbursementOf: nil, refundOf: nil,
            transferFeeOf: nil, adjustment: false,
            tagIds: [tagID],
            attachments: [ExportSchema.AttachmentRefDTO(
                id: attachmentID, fileName: "0-abc.jpg", byteCount: 4, checksum: "abc")])

        let summary = try DataImporter.apply(
            fixture.payload(tags: [tag], transactions: [row]),
            context: fixture.context)

        #expect(summary.tags == 1)
        let storedRows = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
        let restored = try #require(storedRows.first)
        #expect(restored.tagIDs == [tagID])
        #expect(restored.attachments.first?.id == attachmentID)
        // The referenced photo is not on this device: the row still imports
        // and the importer reports it for a readable warning.
        #expect(summary.missingAttachments == 1)
        #expect(TagStore.all(in: fixture.context, bookID: BookModel.defaultID).map(\.id) == [tagID])
    }

    @Test("A backup with no labels or attachment keys still imports")
    func legacyBackupWithoutTags() throws {
        let legacyJSON = """
        {"exportDate":"2026-01-01T00:00:00Z","appVersion":"test","schemaVersion":9,
         "transactions":[],"categories":[],"accounts":[],"settings":{"baseCurrency":"CNY"}}
        """.data(using: .utf8)!
        let payload = try DataImporter.decode(legacyJSON)
        #expect(payload.tags.isEmpty)
        #expect(payload.transactions.isEmpty)

        let summary = try DataImporter.apply(payload, context: fixture.context)
        #expect(summary.tags == 0)
        #expect(summary.missingAttachments == 0)
    }
}
