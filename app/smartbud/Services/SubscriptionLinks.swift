//
//  SubscriptionLinks.swift
//  smartbud
//
//  Legal and App Store URLs, kept out of SubscriptionManager so the class
//  stays focused on StoreKit state.
//

import Foundation

extension SubscriptionManager {
    static let termsOfServiceURL: URL = {
        SubscriptionManager.resolveLegalURL(path: termsOfServicePath, kind: "Terms of Service")
    }()

    /// Public URL for the SmartBud Privacy Policy. The user must
    /// replace the host with a stable App-Store-friendly URL before
    /// submission — see `Open item (hosting)` below.
    static let privacyPolicyURL: URL = {
        SubscriptionManager.resolveLegalURL(path: privacyPolicyPath, kind: "Privacy Policy")
    }()

    /// Apple's web "Manage Subscriptions" page. Stable, no maintenance
    /// required from our side.
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
}
