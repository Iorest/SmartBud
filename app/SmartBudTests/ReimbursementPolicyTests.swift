//
//  ReimbursementPolicyTests.swift
//  SmartBudTests
//
//  The money rules of a partial reimbursement that do not need SwiftData:
//  cents-exact remainder, frozen-rate conversion and the refusals. Runs in
//  the Linux harness as well as the macOS suite.
//

import Testing
import Foundation

@Suite("Reimbursement policy")
struct ReimbursementPolicyTests {

    @Test("Outstanding balance shrinks with each repayment and never goes negative")
    func remaining() {
        #expect(ReimbursementPolicy.remaining(baseAmount: 100, reimbursed: 0) == 100)
        #expect(ReimbursementPolicy.remaining(baseAmount: 100, reimbursed: 40) == 60)
        #expect(ReimbursementPolicy.remaining(baseAmount: 100, reimbursed: 100) == 0)
        #expect(ReimbursementPolicy.remaining(baseAmount: 100, reimbursed: 130) == 0)
    }

    @Test("Three instalments keep one-cent precision")
    func centsSum() {
        var paid = 0.0
        for _ in 0..<3 {
            let left = ReimbursementPolicy.remaining(baseAmount: 100, reimbursed: paid)
            #expect(ReimbursementPolicy.validate(isClaim: true, isWrittenOff: false,
                                                 amount: 33.33, reimbursed: paid,
                                                 baseAmount: 100) == nil)
            paid += 33.33
            #expect(left > 0)
        }
        #expect(ReimbursementPolicy.remaining(baseAmount: 100, reimbursed: 99.99) == 0.01)
        #expect(ReimbursementPolicy.validate(isClaim: true, isWrittenOff: false,
                                             amount: 0.01, reimbursed: 99.99,
                                             baseAmount: 100) == nil)
    }

    @Test("Values outside 0...base are clamped before they reach a statistic")
    func clamped() {
        #expect(ReimbursementPolicy.clamped(reimbursed: -5, baseAmount: 100) == 0)
        #expect(ReimbursementPolicy.clamped(reimbursed: 140, baseAmount: 100) == 100)
        #expect(ReimbursementPolicy.clamped(reimbursed: .nan, baseAmount: 100) == 0)
        #expect(ReimbursementPolicy.clamped(reimbursed: 30, baseAmount: 0) == 0)
    }

    @Test("Full reimbursement is only true for a claim with an amount")
    func fullyReimbursed() {
        #expect(!ReimbursementPolicy.isFullyReimbursed(baseAmount: 0, reimbursed: 0))
        #expect(!ReimbursementPolicy.isFullyReimbursed(baseAmount: 100, reimbursed: 99.99))
        #expect(ReimbursementPolicy.isFullyReimbursed(baseAmount: 100, reimbursed: 100))
    }

    @Test("Repayments convert through the rate frozen on the claim")
    func frozenRate() {
        // 100 USD recorded as 720 CNY: a 25 USD instalment is 180 CNY.
        #expect(ReimbursementPolicy.baseAmount(for: 25, originalAmount: 100,
                                               originalBaseAmount: 720) == 180)
        #expect(ReimbursementPolicy.accountAmount(for: 180, originalAmount: 100,
                                                  originalBaseAmount: 720) == 25)
        #expect(ReimbursementPolicy.accountRemaining(amount: 100, baseAmount: 720,
                                                     reimbursed: 180) == 75)
        #expect(ReimbursementPolicy.baseAmount(for: 0, originalAmount: 100,
                                               originalBaseAmount: 720) == nil)
        #expect(ReimbursementPolicy.baseAmount(for: 25, originalAmount: 0,
                                               originalBaseAmount: 720) == nil)
    }

    @Test("An instalment past the balance is refused with the remaining figure")
    func exceedsRemaining() {
        #expect(ReimbursementPolicy.validate(isClaim: true, isWrittenOff: false,
                                             amount: 70, reimbursed: 40,
                                             baseAmount: 100)
                == .exceedsRemaining(remaining: 60))
        #expect(ReimbursementPolicy.validate(isClaim: true, isWrittenOff: false,
                                             amount: 60, reimbursed: 40,
                                             baseAmount: 100) == nil)
    }

    @Test("Non-claims, written-off claims and non-positive amounts are refused")
    func refusals() {
        #expect(ReimbursementPolicy.validate(isClaim: false, isWrittenOff: false,
                                             amount: 10, reimbursed: 0,
                                             baseAmount: 100) == .notAClaim)
        #expect(ReimbursementPolicy.validate(isClaim: true, isWrittenOff: true,
                                             amount: 10, reimbursed: 0,
                                             baseAmount: 100) == .alreadyWrittenOff)
        #expect(ReimbursementPolicy.validate(isClaim: true, isWrittenOff: false,
                                             amount: 0, reimbursed: 0,
                                             baseAmount: 100) == .nonPositiveAmount)
        #expect(ReimbursementPolicy.validate(isClaim: true, isWrittenOff: false,
                                             amount: .nan, reimbursed: 0,
                                             baseAmount: 100) == .nonPositiveAmount)
    }
}
