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
        let vm = pad(.preDotted)
        vm.tap(1); vm.tap(2); vm.tap(3)
        #expect(vm.amount == Decimal(string: "1.23"))
        #expect(vm.amountString == "1.23")
    }

    @Test("Backspace removes exactly one digit (old Int(price*10) truncated)")
    func preDottedBackspace() {
        let vm = pad(.preDotted)
        vm.tap(1); vm.tap(2); vm.tap(3); vm.tap(4)   // 12.34
        vm.deleteLast()                                // 1.23
        #expect(vm.amount == Decimal(string: "1.23"))
        vm.deleteLast()                                // 0.12
        #expect(vm.amount == Decimal(string: "0.12"))
        vm.deleteLast()                                // 0.01
        #expect(vm.amount == Decimal(string: "0.01"))
        vm.deleteLast()                                // 0
        #expect(vm.amount == Decimal.zero)
    }

    @Test("Leading zero is ignored, then digits still work")
    func preDottedLeadingZero() {
        let vm = pad(.preDotted)
        vm.tap(0)                                      // still empty
        #expect(vm.amount == Decimal.zero)
        vm.tap(5)                                      // 0.05
        #expect(vm.amount == Decimal(string: "0.05"))
    }

    @Test("Amount cap stops input at 100,000,000")
    func preDottedCap() {
        let vm = pad(.preDotted)
        for _ in 0..<12 { vm.tap(9) }
        #expect(vm.amount < 100_000_000)
        #expect(vm.isInputDisabled)
    }

    // MARK: - Cent-less (Type 2)

    @Test("Whole-number entry, then cents after the decimal key")
    func centlessEntry() {
        let vm = pad(.centless)
        vm.tap(1); vm.tap(2)
        #expect(vm.amount == Decimal(string: "12"))
        #expect(vm.amountString == "12")

        vm.enterDecimal()
        vm.tap(3); vm.tap(4)
        #expect(vm.amount == Decimal(string: "12.34"))
        #expect(vm.amountString == "12.34")
    }

    @Test("Only two cent digits are accepted")
    func centlessMaxTwoCents() {
        let vm = pad(.centless)
        vm.tap(5)
        vm.enterDecimal()
        vm.tap(1); vm.tap(2); vm.tap(3)
        #expect(vm.amount == Decimal(string: "5.12"))
    }

    @Test("Backspace walks cents then whole part then leaves decimal mode")
    func centlessBackspace() {
        let vm = pad(.centless)
        vm.tap(1); vm.tap(2)
        vm.enterDecimal()
        vm.tap(3); vm.tap(4)
        vm.deleteLast()                                // 12.3
        #expect(vm.amount == Decimal(string: "12.3"))
        vm.deleteLast()                                // 12.  (still editing)
        #expect(vm.amount == Decimal(string: "12"))
        #expect(vm.isEditingDecimal)
        #expect(vm.amountString == "12.")
        vm.deleteLast()                                // exit decimal mode
        #expect(!vm.isEditingDecimal)
        vm.deleteLast()                                // 1
        #expect(vm.amount == Decimal(string: "1"))
    }

    // MARK: - Loading an existing amount

    @Test("Loading a Double 12.3 keeps exactly 12.30")
    func loadExistingAmount() {
        let vm = pad(.centless)
        vm.price = 12.3
        #expect(vm.amount == Decimal(string: "12.3"))
        vm.enterDecimal()
        #expect(vm.amountString == "12.3")
        #expect(vm.amount == Decimal(string: "12.3"))
    }

    @Test("Loading 0.1 + 0.2 style drift rounds to cents")
    func loadRoundsToCents() {
        let vm = pad(.preDotted)
        vm.price = 0.1 + 0.2                           // 0.30000000000000004
        #expect(vm.amount == Decimal(string: "0.30"))
    }

    @Test("Submit clears the entry")
    func submitClears() {
        let vm = pad(.preDotted)
        vm.tap(9); vm.tap(9)
        vm.submit()
        #expect(vm.amount == Decimal.zero)
        #expect(vm.submitTrigger == 1)
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
}
