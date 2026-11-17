//
//  BadDebtPolicyTests.swift
//  SmartBudTests
//
//  The write-off rules that do not need SwiftData: the waiting period, the
//  refusals, and the stored shape of the reason. Runs in the Linux harness
//  (`scripts/linux-tests.sh`) as well as the macOS suite.
//

import Testing
import Foundation

@Suite("Bad debt policy")
struct BadDebtPolicyTests {

    private let claimDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func date(daysAfter days: Int) -> Date {
        Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: days, to: claimDate) ?? claimDate
    }

    private func refusal(isClaim: Bool = true,
                         isSettled: Bool = false,
                         isWrittenOff: Bool = false,
                         days: Int,
                         amount: Double = 120) -> BadDebtPolicy.Failure? {
        BadDebtPolicy.validate(isClaim: isClaim, isSettled: isSettled,
                               isWrittenOff: isWrittenOff,
                               claimDate: claimDate, now: date(daysAfter: days),
                               amount: amount)
    }

    @Test("A claim becomes writable off on its 90th day, not the 89th")
    func threshold() {
        #expect(refusal(days: 0) == .tooRecent(daysLeft: 90))
        #expect(refusal(days: 89) == .tooRecent(daysLeft: 1))
        #expect(refusal(days: 90) == nil)
        #expect(refusal(days: 91) == nil)
    }

    @Test("The countdown is in calendar days and stops at zero")
    func daysLeft() {
        #expect(BadDebtPolicy.daysLeft(claimDate: claimDate, now: date(daysAfter: 0)) == 90)
        #expect(BadDebtPolicy.daysLeft(claimDate: claimDate, now: date(daysAfter: 60)) == 30)
        #expect(BadDebtPolicy.daysLeft(claimDate: claimDate, now: date(daysAfter: 90)) == 0)
        #expect(BadDebtPolicy.daysLeft(claimDate: claimDate, now: date(daysAfter: 365)) == 0)
    }

    @Test("A claim entered late in the evening does not gain a day overnight")
    func calendarDaysNotHours() {
        let lateEvening = Calendar(identifier: .gregorian)
            .date(bySettingHour: 23, minute: 30, second: 0, of: claimDate) ?? claimDate
        let nextMorning = Calendar(identifier: .gregorian)
            .date(bySettingHour: 8, minute: 0, second: 0, of: date(daysAfter: 1)) ?? claimDate
        #expect(BadDebtPolicy.daysWaiting(claimDate: lateEvening, now: nextMorning) == 1)
        // The hour between 23:30 and 08:00 is not a day, so the claim is still
        // waiting for its ninetieth.
        #expect(BadDebtPolicy.isEligible(claimDate: lateEvening, now: nextMorning) == false)
    }

    @Test("Rows that are not un-settled claims are refused")
    func refusals() {
        #expect(refusal(isClaim: false, days: 200) == .notAClaim)
        #expect(refusal(isSettled: true, days: 200) == .alreadySettled)
        #expect(refusal(isWrittenOff: true, days: 200) == .alreadyWrittenOff)
        #expect(refusal(days: 200, amount: 0) == .nonPositiveAmount)
        #expect(refusal(days: 200, amount: -5) == .nonPositiveAmount)
        // The refusals that describe the row itself win over the waiting
        // period: a paid-back claim never becomes writable by waiting longer.
        #expect(refusal(isSettled: true, days: 0) == .alreadySettled)
    }

    @Test("Reasons keep their stored names: they are part of the export file")
    func reasonRawValues() {
        #expect(BadDebtPolicy.Reason.allCases.map(\.rawValue)
                == ["unreachable", "rejected", "companyClosed", "other"])
    }
}
