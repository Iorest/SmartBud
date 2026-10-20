//
//  ReviewRequester.swift
//  smartbud
//
//  Triggers the system in-app review sheet at meaningful moments in
//  the user's journey (3rd transaction created, etc.). Apple's
//  `StoreKit` itself caps the prompt at 3 times per app install per
//  year, so we can ask freely — the SDK silently no-ops after the
//  limit. This wrapper adds a per-version dedup so a single app
//  version only asks once, even across multiple eligible moments.
//
//  Reference: https://developer.apple.com/documentation/storekit/appstore/4213031-requestreview
//

import StoreKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
enum ReviewRequester {
    /// Lifetime counter of `create()` calls. Incremented from
    /// `TransactionViewModel.create`. Not user-visible; persisted in
    /// standard `UserDefaults` (not the App Group — review prompt is
    /// per-device, not synced).
    private static let transactionCountKey = "reviewPrompt.transactionCount"

    /// The app version that we last asked the user to review in.
    /// Compared against `Bundle.main.appVersion` so the prompt can
    /// re-trigger on a version upgrade even if the user dismissed
    /// the previous one. Apple's per-year cap is the upper bound.
    private static let lastAskedVersionKey = "reviewPrompt.lastAskedVersion"

    /// When the user first launched the app. Used to delay the
    /// review prompt past the very first session (an immediate
    /// "Rate us" feels pushy).
    private static let installDateKey = "reviewPrompt.installDate"

    /// Thresholds in the lifetime-transaction counter at which we
    /// attempt to show the review sheet. Apple will silently cap
    /// this to 3 prompts/year, so listing several moments here
    /// just gives us more chances to hit a moment the user is in
    /// a good mood to review.
    private static let transactionThresholds: [Int] = [3, 10, 25]

    /// Call from app launch. Stamps the install date the first time
    /// and is a no-op on subsequent launches.
    static func recordAppLaunch() {
        let store = UserDefaults.standard
        if store.object(forKey: installDateKey) == nil {
            store.set(Date.now.timeIntervalSince1970, forKey: installDateKey)
        }
    }

    /// Call from `TransactionViewModel.create(...)` after a
    /// transaction is successfully persisted. Increments the
    /// counter; if the count crosses one of `transactionThresholds`
    /// AND the user hasn't been prompted for the current app version
    /// yet, opens the system review sheet.
    static func recordTransactionCreated() {
        let store = UserDefaults.standard
        let count = store.integer(forKey: transactionCountKey) + 1
        store.set(count, forKey: transactionCountKey)

        guard transactionThresholds.contains(count) else { return }
        requestReviewIfAppropriate()
    }

    private static func requestReviewIfAppropriate() {
        let store = UserDefaults.standard
        let currentVersion = Bundle.main.appVersion
        if store.string(forKey: lastAskedVersionKey) == currentVersion {
            return // already asked for this version
        }

        #if os(macOS)
        // The macOS review prompt has no scene anchor and the App Store
        // handles its own throttling; skip the in-app nudge there.
        return
        #else
        // The system sheet needs a foreground scene to anchor to.
        // Prefer the active one; fall back to the first connected
        // scene (covers the "cold launch" case where the scene
        // exists but isn't yet `.foregroundActive`).
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
        else { return }

        // `AppStore.requestReview(in:)` is the iOS 18+ replacement
        // the deployment target is iOS 26, this is the right entry
        // point and matches the AppStore.* calls already used in
        // `SubscriptionManager`.
        AppStore.requestReview(in: scene)
        store.set(currentVersion, forKey: lastAskedVersionKey)
        #endif
    }
}
