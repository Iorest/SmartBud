//
//  MerchantAggregationTests.swift
//  SmartBudTests
//
//  The merchant ranking is the only place the normalised key is read. These
//  tests pin that it merges spellings, keeps different shops apart, and never
//  counts rows that are not spend.
//

import Testing
import Foundation
import SwiftData

@Suite("Merchant aggregation")
@MainActor
struct MerchantAggregationTests {

    /// Builds a row the way entry does: the merchant is derived from the
    /// typed name, never passed in by hand.
    private func expense(
        _ name: String?,
        _ amount: Double,
        income: Bool = false,
        adjustment: Bool = false
    ) -> TransactionModel {
        let identity = name.flatMap { MerchantNormalizer.normalize($0) }
        return TransactionModel(
            note: name ?? "",
            baseAmount: amount,
            income: income,
            amount: amount,
            adjustment: adjustment,
            merchant: identity?.name,
            merchantKey: identity?.key
        )
    }

    @Test("Three spellings of one shop are one row")
    func mergesSpellings() throws {
        let slices = MerchantSummary.breakdown(of: [
            expense("美团-张亮麻辣烫", 30),
            expense("美团外卖", 20),
            expense("美团", 50)
        ])
        let slice = try #require(slices.first)
        #expect(slices.count == 1)
        #expect(slice.id == "美团")
        #expect(slice.amount == 100)
        #expect(slice.transactionCount == 3)
        #expect(slice.percent == 1)
    }

    @Test("Different merchants are not merged")
    func keepsMerchantsApart() {
        let slices = MerchantSummary.breakdown(of: [
            expense("星巴克", 20),
            expense("美团", 30)
        ])
        #expect(slices.map(\.id) == ["美团", "星巴克"])
    }

    @Test("Unnamed rows, income and adjustments are not merchants")
    func skipsNonSpend() {
        let slices = MerchantSummary.breakdown(of: [
            expense(nil, 10),
            expense("星巴克", 5, income: true),
            expense("星巴克", 7, adjustment: true),
            expense("星巴克", 20)
        ])
        #expect(slices.count == 1)
        #expect(slices.first?.amount == 20)
    }

    @Test("The ranking is capped and ordered by spend")
    func limit() {
        let rows = (1...8).map { expense("Shop \($0)", Double($0)) }
        let slices = MerchantSummary.breakdown(of: rows)
        #expect(slices.count == MerchantSummary.defaultLimit)
        #expect(slices.first?.amount == 8)
    }
}
