//
//  NumberPadViewModelTests.swift
//  SmartBudTests
//
//  Regression tests for the digit-string entry rewrite. The old
//  implementation did Double arithmetic (`price *= 10`, `Int(price * 10)`),
//  which drifted on backspace and lost digits; every case below is a sequence
//  that called that out.
//

import Testing
import Foundation

@MainActor
@Suite("NumberPadViewModel")
struct NumberPadViewModelTests {

    private func pad(_ mode: NumberEntryMode) -> NumberPadViewModel {
        NumberPadViewModel(numberEntryType: mode.rawValue, hapticType: 0)
    }

    // MARK: - Pre-dotted (Type 1)

    @Test("Digits enter as cents: 1,2,3 → 1.23")
    func preDottedEntry() {
        let viewModel = pad(.preDotted)
        viewModel.tap(1); viewModel.tap(2); viewModel.tap(3)
        #expect(viewModel.amount == Decimal(string: "1.23"))
        #expect(viewModel.amountString == "1.23")
    }

    @Test("Backspace removes exactly one digit (old Int(price*10) truncated)")
    func preDottedBackspace() {
        let viewModel = pad(.preDotted)
        viewModel.tap(1); viewModel.tap(2); viewModel.tap(3); viewModel.tap(4)   // 12.34
        viewModel.deleteLast()                                // 1.23
        #expect(viewModel.amount == Decimal(string: "1.23"))
        viewModel.deleteLast()                                // 0.12
        #expect(viewModel.amount == Decimal(string: "0.12"))
        viewModel.deleteLast()                                // 0.01
        #expect(viewModel.amount == Decimal(string: "0.01"))
        viewModel.deleteLast()                                // 0
        #expect(viewModel.amount == Decimal.zero)
    }

    @Test("Leading zero is ignored, then digits still work")
    func preDottedLeadingZero() {
        let viewModel = pad(.preDotted)
        viewModel.tap(0)                                      // still empty
        #expect(viewModel.amount == Decimal.zero)
        viewModel.tap(5)                                      // 0.05
        #expect(viewModel.amount == Decimal(string: "0.05"))
    }

    @Test("Amount cap stops input at 100,000,000")
    func preDottedCap() {
        let viewModel = pad(.preDotted)
        for _ in 0..<12 { viewModel.tap(9) }
        #expect(viewModel.amount < 100_000_000)
        #expect(viewModel.isInputDisabled)
    }

    // MARK: - Cent-less (Type 2)

    @Test("Whole-number entry, then cents after the decimal key")
    func centlessEntry() {
        let viewModel = pad(.centless)
        viewModel.tap(1); viewModel.tap(2)
        #expect(viewModel.amount == Decimal(string: "12"))
        #expect(viewModel.amountString == "12")

        viewModel.enterDecimal()
        viewModel.tap(3); viewModel.tap(4)
        #expect(viewModel.amount == Decimal(string: "12.34"))
        #expect(viewModel.amountString == "12.34")
    }

    @Test("Only two cent digits are accepted")
    func centlessMaxTwoCents() {
        let viewModel = pad(.centless)
        viewModel.tap(5)
        viewModel.enterDecimal()
        viewModel.tap(1); viewModel.tap(2); viewModel.tap(3)
        #expect(viewModel.amount == Decimal(string: "5.12"))
    }

    @Test("Backspace walks cents then whole part then leaves decimal mode")
    func centlessBackspace() {
        let viewModel = pad(.centless)
        viewModel.tap(1); viewModel.tap(2)
        viewModel.enterDecimal()
        viewModel.tap(3); viewModel.tap(4)
        viewModel.deleteLast()                                // 12.3
        #expect(viewModel.amount == Decimal(string: "12.3"))
        viewModel.deleteLast()                                // 12.  (still editing)
        #expect(viewModel.amount == Decimal(string: "12"))
        #expect(viewModel.isEditingDecimal)
        #expect(viewModel.amountString == "12.")
        viewModel.deleteLast()                                // exit decimal mode
        #expect(!viewModel.isEditingDecimal)
        viewModel.deleteLast()                                // 1
        #expect(viewModel.amount == Decimal(string: "1"))
    }

    // MARK: - Loading an existing amount

    @Test("Loading a Double 12.3 keeps exactly 12.30")
    func loadExistingAmount() {
        let viewModel = pad(.centless)
        viewModel.price = 12.3
        #expect(viewModel.amount == Decimal(string: "12.3"))
        viewModel.enterDecimal()
        #expect(viewModel.amountString == "12.3")
        #expect(viewModel.amount == Decimal(string: "12.3"))
    }

    @Test("Loading 0.1 + 0.2 style drift rounds to cents")
    func loadRoundsToCents() {
        let viewModel = pad(.preDotted)
        viewModel.price = 0.1 + 0.2                           // 0.30000000000000004
        #expect(viewModel.amount == Decimal(string: "0.30"))
    }

    @Test("Submit clears the entry")
    func submitClears() {
        let viewModel = pad(.preDotted)
        viewModel.tap(9); viewModel.tap(9)
        viewModel.submit()
        #expect(viewModel.amount == Decimal.zero)
        #expect(viewModel.submitTrigger == 1)
    }
}

@Suite("Money")
struct MoneyTests {

    @Test("0.1 + 0.2 sums exactly")
    func exactSum() {
        #expect(Money.sum([0.1, 0.2]) == Decimal(string: "0.3"))
    }

    @Test("Sum of many amounts stays exact")
    func manyAmounts() {
        let values = Array(repeating: 0.1, count: 10)
        #expect(Money.sum(values) == Decimal(string: "1.0"))
    }

    @Test("Stored Double noise is rounded to cents before summing")
    func roundsNoise() {
        #expect(Money.cents(12.299999999999999) == Decimal(string: "12.3"))
    }

    @Test("Non-finite amounts sum to zero instead of trapping")
    func nonFiniteAmount() {
        #expect(Money.cents(.infinity) == .zero)
        #expect(Money.cents(.nan) == .zero)
        #expect(Money.sum([.infinity, 1]) == Decimal(1))
    }

    @Test("Spend fraction divides normally")
    func spendFractionNormal() {
        #expect(Money.spendFraction(25, of: 100) == 0.25)
    }

    @Test("Zero budget reads as fully spent once anything is spent")
    func spendFractionZeroBudget() {
        #expect(Money.spendFraction(20, of: 0) == 1)
        #expect(Money.spendFraction(0, of: 0) == 0)
    }

    @Test("Non-finite inputs never produce NaN")
    func spendFractionNonFinite() {
        #expect(Money.spendFraction(.infinity, of: 100) == 0)
        #expect(Money.spendFraction(10, of: .infinity) == 1)
    }
}
