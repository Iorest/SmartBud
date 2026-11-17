//
//  RefundPolicyTests.swift
//  SmartBudTests
//
//  The refund rules that do not need SwiftData: remaining amount, cents
//  rounding, the frozen-rate conversion and the refusals. Runs in the Linux
//  harness (`scripts/linux-tests.sh`) as well as the macOS suite.
//

import Testing
import Foundation

@Suite("Refund policy")
struct RefundPolicyTests {

    private let originalDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Remaining shrinks with every partial refund and never goes negative")
    func remaining() {
        #expect(RefundPolicy.remaining(originalAmount: 100, refunded: 0) == 100)
        #expect(RefundPolicy.remaining(originalAmount: 100, refunded: 30) == 70)
        #expect(RefundPolicy.remaining(originalAmount: 100, refunded: 100) == 0)
        #expect(RefundPolicy.remaining(originalAmount: 100, refunded: 130) == 0)
    }

    @Test("Three partial refunds add up to the original without float drift")
    func centsSum() {
        var refunded = 0.0
        for _ in 0..<3 {
            let left = RefundPolicy.remaining(originalAmount: 100, refunded: refunded)
            #expect(RefundPolicy.validate(amount: 33.33, date: originalDate,
                                          originalAmount: 100, originalDate: originalDate,
                                          refunded: refunded) == nil)
            refunded += 33.33
            #expect(left > 0)
        }
        // 99.99 given back leaves exactly one cent, not a float tail that
        // refuses the last cent forever.
        #expect(RefundPolicy.remaining(originalAmount: 100, refunded: 99.99) == 0.01)
        #expect(RefundPolicy.validate(amount: 0.01, date: originalDate,
                                      originalAmount: 100, originalDate: originalDate,
                                      refunded: 99.99) == nil)
    }

    @Test("A refund past the original amount is refused with the remaining figure")
    func exceedsRemaining() {
        let failure = RefundPolicy.validate(amount: 30, date: originalDate,
                                            originalAmount: 100, originalDate: originalDate,
                                            refunded: 80)
        #expect(failure == .exceedsRemaining(remaining: 20))
    }

    @Test("A fully refunded purchase cannot be refunded again")
    func fullyRefunded() {
        #expect(RefundPolicy.validate(amount: 0.01, date: originalDate,
                                      originalAmount: 50, originalDate: originalDate,
                                      refunded: 50) == .exceedsRemaining(remaining: 0))
    }

    @Test("Zero and negative amounts are refused")
    func nonPositive() {
        #expect(RefundPolicy.validate(amount: 0, date: originalDate,
                                      originalAmount: 100, originalDate: originalDate,
                                      refunded: 0) == .nonPositiveAmount)
        #expect(RefundPolicy.validate(amount: -5, date: originalDate,
                                      originalAmount: 100, originalDate: originalDate,
                                      refunded: 0) == .nonPositiveAmount)
    }

    @Test("Money cannot come back before it left")
    func beforeOriginal() {
        let earlier = originalDate.addingTimeInterval(-60)
        #expect(RefundPolicy.validate(amount: 10, date: earlier,
                                      originalAmount: 100, originalDate: originalDate,
                                      refunded: 0) == .arrivedBeforeExpense)
        // The same instant is allowed: a card refund can post immediately.
        #expect(RefundPolicy.validate(amount: 10, date: originalDate,
                                      originalAmount: 100, originalDate: originalDate,
                                      refunded: 0) == nil)
    }

    @Test("Base amount uses the rate frozen on the original row")
    func frozenRate() {
        // 100 USD was recorded as 720 CNY; a 30 USD refund is 216 CNY even if
        // today's rate is different.
        let base = RefundPolicy.baseAmount(originalBaseAmount: 720,
                                           originalAmount: 100,
                                           refundAmount: 30)
        #expect(base == 216)
    }

    @Test("Full refund reproduces the original base amount to the cent")
    func fullRefundMatchesOriginal() {
        let base = RefundPolicy.baseAmount(originalBaseAmount: 719.99,
                                           originalAmount: 100,
                                           refundAmount: 100)
        #expect(base == 719.99)
    }

    @Test("A base amount that cannot be derived is refused")
    func unusableOriginal() {
        #expect(RefundPolicy.baseAmount(originalBaseAmount: 10,
                                        originalAmount: 0,
                                        refundAmount: 5) == nil)
        #expect(RefundPolicy.baseAmount(originalBaseAmount: .nan,
                                        originalAmount: 100,
                                        refundAmount: 5) == nil)
        #expect(RefundPolicy.baseAmount(originalBaseAmount: 100,
                                        originalAmount: 100,
                                        refundAmount: 0) == nil)
    }

    @Test("Editing checks the amount against the other refunds only")
    func editExcludesSelf() {
        // 60 already refunded by the row being edited, 90 by another one.
        #expect(RefundPolicy.validateEdit(amount: 60, date: originalDate,
                                          originalAmount: 100, originalDate: originalDate,
                                          refundedExcludingSelf: 40) == nil)
        #expect(RefundPolicy.validateEdit(amount: 61, date: originalDate,
                                          originalAmount: 100, originalDate: originalDate,
                                          refundedExcludingSelf: 40) != nil)
    }
}
