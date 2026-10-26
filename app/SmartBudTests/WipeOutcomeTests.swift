//
//  WipeOutcomeTests.swift
//  SmartBudTests
//
//  "Erase all data" has to tell the user the truth: iCloud gone, retry
//  needed, wrong Apple ID, or nothing deleted at all. The mapping from
//  CloudKit errors is pure, so every branch is pinned here.
//

import CloudKit
import Testing

@Suite("Wipe outcome")
struct WipeOutcomeTests {

    private func error(_ code: CKError.Code) -> CKError {
        CKError(_nsError: NSError(domain: CKErrorDomain, code: code.rawValue))
    }

    @Test("A missing zone means the data is already gone")
    func missingZoneIsComplete() {
        #expect(WipeClassifier.outcome(for: error(.zoneNotFound)) == .complete)
        #expect(WipeClassifier.outcome(for: error(.unknownItem)) == .complete)
    }

    @Test("Another Apple ID or a permission problem is called out")
    func accountProblems() {
        #expect(WipeClassifier.outcome(for: error(.notAuthenticated)) == .iCloudAccountMismatch)
        #expect(WipeClassifier.outcome(for: error(.permissionFailure)) == .iCloudAccountMismatch)
    }

    @Test("Transient iCloud failures ask the user to retry")
    func transientFailures() {
        for code in [CKError.Code.networkUnavailable, .networkFailure,
                     .serviceUnavailable, .requestRateLimited, .zoneBusy] {
            #expect(WipeClassifier.outcome(for: error(code)) == .iCloudRetryable)
        }
    }
}
