//
//  ProAccessTests.swift
//  SmartBudTests
//
//  The Pro gates are shipped before the launch promo ends, so the rule that
//  decides "unlocked" has to be right on its own: promo on means everyone,
//  promo off means a verified entitlement only.
//

import Testing
import Foundation

@Suite("Pro access")
struct ProAccessTests {

    @Test("The launch promo unlocks every gate")
    func promoUnlocksEverything() {
        for feature in ProFeature.allCases {
            #expect(ProAccess.isUnlocked(feature, promo: true, entitled: false))
        }
    }

    @Test("A verified entitlement unlocks every gate after the promo")
    func entitlementUnlocksAfterPromo() {
        for feature in ProFeature.allCases {
            #expect(ProAccess.isUnlocked(feature, promo: false, entitled: true))
        }
    }

    @Test("Without promo or entitlement every gate is locked")
    func lockedWithoutEither() {
        for feature in ProFeature.allCases {
            #expect(!ProAccess.isUnlocked(feature, promo: false, entitled: false))
        }
    }

    @Test("Every gated feature has its own paywall title")
    func distinctTitles() {
        let titles = Set(ProFeature.allCases.map(\.titleKey))
        #expect(titles.count == ProFeature.allCases.count)
    }
}
