//
//  SubscriptionManager.swift
//  smartbud
//
//  StoreKit 2 wrapper for the SmartBud Pro subscription.
//
//  Single source of truth for `isProSubscriber`, derived from
//  `Transaction.currentEntitlements` and kept in sync with the
//  background `Transaction.updates` stream. The bool is also cached in
//  the App Group `UserDefaults` so the UI can paint instantly on cold
//  start before the first entitlements round-trip completes.
//
//  This is the only place that talks to StoreKit. Views observe
//  `SubscriptionManager.shared` and call into its `purchase` /
//  `restore` / `showManageSubscriptions` methods. Putting the policy
//  (product IDs, T&CS / Privacy URLs) here means there's exactly one
//  place to update when a new SKU is added or the legal URLs move.
//

import StoreKit
#if os(macOS)
import AppKit
#endif
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    // MARK: - Public state

    /// Effective Pro state — what every gate should observe.
    /// True when the launch/promo period is on (everyone is Pro) OR
    /// when the user has a verified auto-renewing subscription.
    /// See `isLimitedTimeFree` and `hasActualProEntitlement`.
    var isProSubscriber: Bool {
        isLimitedTimeFree ? true : hasActualProEntitlement
    }

    /// While `true`, every user is treated as Pro regardless of their
    /// actual subscription state. Used during the launch / promo period
    /// so all features are available to early adopters. Flip to `false`
    /// in a follow-up release to enforce the real entitlement check
    /// (the existing `refreshEntitlements()` machinery will then take
    /// over without any other code change required).
    ///
    /// TODO(promo): set to `false` when the limited-time-free period
    /// ends. Mark the cut-over in a CHANGELOG entry.
    ///
    /// Read from the app-group defaults (`limitedTimeFree`) so the promo can
    /// be switched off without shipping a build; defaults to `true` while
    /// the promo is running.
    var isLimitedTimeFree: Bool {
        UserDefaults.appGroup.object(forKey: "limitedTimeFree") as? Bool ?? true
    }

    /// `true` when the user has a verified (and non-revoked) StoreKit
    /// transaction for any product in `productIDs`. Independent of
    /// `isLimitedTimeFree` — that's the key difference from
    /// `isProSubscriber`. Used by the Pro view to decide whether to
    /// show the active ("you already have Pro") state or the pricing
    /// state, so users can see and buy SKUs even while the
    /// limited-time-free flag is on.
    ///
    /// Persisted to the App Group so a cold start (before the first
    /// `refreshEntitlements()` round-trip completes) doesn't flash
    /// "Not Pro" on a real subscriber when the promo flag has been
    /// flipped to `false`.
    private(set) var hasActualProEntitlement: Bool

    /// `true` when the user owns the lifetime (non-consumable) SKU
    /// specifically. Tracked separately from `hasActualProEntitlement`
    /// because the active-state UI uses it to decide whether to show
    /// the "Manage Subscription" button — a lifetime owner has no
    /// subscription to manage. Only the non-consumable IAP is reported
    /// here; auto-renewing subscriptions are not (those users have
    /// active subscriptions and should see the manage button).
    ///
    /// Persisted to the App Group for the same reason as
    /// `hasActualProEntitlement` — so a lifetime owner who reinstalls
    /// the app or moves to a new device sees the lifetime active state
    /// immediately, without waiting for StoreKit to re-issue the
    /// non-consumable transaction.
    private(set) var userOwnsLifetime: Bool = false

    /// Products loaded from the App Store. Empty means "not loaded yet"
    /// OR "no products configured in App Store Connect for this app" —
    /// check `lastError` to disambiguate.
    private(set) var loadedProducts: [Product] = []

    /// Most recent user-facing error. Cleared by `clearError()` after
    /// the view has shown it.
    var lastError: SubscriptionError?

    // MARK: - Configuration

    /// Product IDs must match the products created in App Store
    /// Connect for this app's bundle ID. The three auto-renewable
    /// subscriptions live in a single Subscription Group; the lifetime
    /// unlock is a separate non-consumable In-App Purchase (non-
    /// consumable products cannot live inside a subscription group).
    /// `refreshEntitlements()` treats every product in this set as
    /// evidence of a Pro entitlement — `Transaction.currentEntitlements`
    /// returns both subscription and non-consumable transactions, so
    /// the existing for-await loop already covers lifetime without
    /// further changes.
    static let productIDs: Set<String> = [
        "com.iorest.smartbud.pro.monthly",
        "com.iorest.smartbud.pro.halfyearly",
        "com.iorest.smartbud.pro.yearly",
        "com.iorest.smartbud.pro.lifetime"
    ]

    /// The three auto-renewable subscription SKUs. Subset of
    /// `productIDs`. Used by the UI to group products on the Pro
    /// screen — the lifetime unlock is rendered in a separate group.
    static let subscriptionProductIDs: Set<String> = [
        "com.iorest.smartbud.pro.monthly",
        "com.iorest.smartbud.pro.halfyearly",
        "com.iorest.smartbud.pro.yearly"
    ]

    /// The non-consumable lifetime unlock SKU. Single string (not a
    /// set) because there is exactly one lifetime product. The
    /// `activeState` view uses `userOwnsLifetime` to decide whether to
    /// show a "Manage Subscription" button — a lifetime owner has no
    /// subscription to manage.
    static let lifetimeProductID = "com.iorest.smartbud.pro.lifetime"

    // MARK: - Legal URLs (required for App Store Guideline 3.1.2 / 3.1.5)

    /// Path to the Terms of Service inside this repository, relative
    /// to the repo root. Used to build the public `termsOfServiceURL`
    /// below. Update both sides if the file moves.
    private static let termsOfServicePath = "docs/TERMS.md"

    /// Path to the Privacy Policy inside this repository, relative
    /// to the repo root. Used to build the public `privacyPolicyURL`
    /// below. Update both sides if the file moves.
    private static let privacyPolicyPath = "docs/privacypolicy.md"

    /// Public URL for the SmartBud Terms of Service. The user must
    /// replace the host with a stable App-Store-friendly URL before
    /// submission — see `TODO(hosting)` below.
    static let termsOfServiceURL: URL = {
        SubscriptionManager.resolveLegalURL(path: termsOfServicePath, kind: "Terms of Service")
    }()

    /// Public URL for the SmartBud Privacy Policy. The user must
    /// replace the host with a stable App-Store-friendly URL before
    /// submission — see `TODO(hosting)` below.
    static let privacyPolicyURL: URL = {
        SubscriptionManager.resolveLegalURL(path: privacyPolicyPath, kind: "Privacy Policy")
    }()

    /// Apple's web "Manage Subscriptions" page. Stable, no maintenance
    /// required from our side.
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    /// Resolves a path like `"docs/TERMS.md"` to a public URL.
    ///
    /// Override behaviour: if the `SMARTBUD_LEGAL_URL_BASE` Info.plist
    /// key is present (set via INFOPLIST_KEY_SMARTBUD_LEGAL_URL_BASE in
    /// the Xcode build settings), that base is used directly. This lets
    /// the maintainer publish the legal docs on a stable host (e.g.
    /// `https://smartbud.app/`) without touching source.
    ///
    /// Fallback when the override is absent: GitHub raw URL. Stable as
    /// long as the repo is public, returns the file content with the
    /// right MIME type, and does not require GitHub Pages setup.
    ///
    /// `TODO(hosting)`: before App Store submission, the maintainer
    /// should set `SMARTBUD_LEGAL_URL_BASE` to a stable, App-Store-
    /// friendly host. Suggested options, in order of preference:
    ///   1. GitHub Pages under the project org:
    ///      `https://<org>.github.io/smartbud/`
    ///   2. A custom domain (e.g. `https://smartbud.app/`)
    ///   3. Any other always-on static host.
    /// Plain `github.com/.../blob/...` URLs are NOT preferred — they
    /// render as code in a browser and may be flagged by Apple review.
    private static func resolveLegalURL(path: String, kind: String) -> URL {
        if let base = Bundle.main.object(forInfoDictionaryKey: "SMARTBUD_LEGAL_URL_BASE") as? String,
           !base.isEmpty,
           let resolved = URL(string: base + path) {
            return resolved
        }
        // Fallback: raw GitHub URL. Stable as long as the repo is
        // public; Apple reviewers can read the rendered markdown via
        // the GitHub UI by following the link.
        let repoOwner = "iorest"
        let repoName = "smartbud"
        let branch = "main"
        let urlString = "https://raw.githubusercontent.com/\(repoOwner)/\(repoName)/\(branch)/\(path)"
        guard let url = URL(string: urlString) else {
            // If the fallback URL itself fails to construct (shouldn't
            // happen — the input is a hard-coded constant), fall back
            // to the GitHub web UI URL so the link is at least tappable.
            assertionFailure("Could not construct legal URL for \(kind)")
            return URL(string: "https://github.com/\(repoOwner)/\(repoName)/blob/\(branch)/\(path)")!
        }
        return url
    }

    /// App Group key for the `hasActualProEntitlement` cache. Used so
    /// a cold start (before the first `refreshEntitlements()` round-
    /// trip completes) doesn't flash "Not Pro" on a real subscriber.
    private let storageKey = "isProSubscriber"

    /// App Group key for the `userOwnsLifetime` cache. Same reason as
    /// `storageKey` — a lifetime owner who reinstalls the app or moves
    /// to a new device sees the lifetime active state immediately
    /// instead of waiting for StoreKit to re-issue the non-consumable
    /// transaction.
    private let lifetimeStorageKey = "hasLifetimePurchase"

    init() {
        // Seed the entitlement caches from disk. The promo flag
        // (`isLimitedTimeFree`) overrides both while it's on, so the
        // seeds only matter once the flag is flipped to `false`.
        self.hasActualProEntitlement = UserDefaults.appGroup.bool(forKey: storageKey)
        self.userOwnsLifetime = UserDefaults.appGroup.bool(forKey: lifetimeStorageKey)
    }

    // MARK: - Lifecycle

    /// Call once on app launch (from `ContentView.task` or similar).
    /// Idempotent; safe to call multiple times.
    func bootstrap() async {
        async let entitlements: Void = refreshEntitlements()
        async let products: Void = loadProducts()
        _ = await (entitlements, products)
    }

    /// Re-derive `hasActualProEntitlement` and `userOwnsLifetime` from
    /// `Transaction.currentEntitlements`. Called on bootstrap, after
    /// every purchase, and on every transaction update from StoreKit.
    /// The promo flag (`isLimitedTimeFree`) is not consulted here —
    /// `isProSubscriber` reads it separately.
    func refreshEntitlements() async {
        var hasPro = false
        var hasLifetime = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result,
               Self.productIDs.contains(txn.productID),
               txn.revocationDate == nil {
                hasPro = true
                if txn.productID == Self.lifetimeProductID {
                    hasLifetime = true
                }
            }
        }
        if hasPro != hasActualProEntitlement {
            hasActualProEntitlement = hasPro
            UserDefaults.appGroup.set(hasPro, forKey: storageKey)
        }
        if hasLifetime != userOwnsLifetime {
            userOwnsLifetime = hasLifetime
            UserDefaults.appGroup.set(hasLifetime, forKey: lifetimeStorageKey)
        }
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: Array(Self.productIDs))
            loadedProducts = products.sorted { $0.price < $1.price }
        } catch {
            loadedProducts = []
            lastError = .loadProductsFailed(error)
        }
    }

    // MARK: - Product grouping for UI

    /// Auto-renewable subscription products returned by the App Store,
    /// sorted by price ascending. The Pro screen renders this list in
    /// a "Subscriptions" group. Excludes the lifetime product.
    /// Returns an empty array when the App Store hasn't returned any
    /// matching products (e.g. reviewer in a sandbox without those
    /// subscriptions configured).
    var subscriptionProducts: [Product] {
        loadedProducts
            .filter { Self.subscriptionProductIDs.contains($0.id) }
            .sorted { $0.price < $1.price }
    }

    /// The lifetime (non-consumable) product, if the App Store returned
    /// it. Rendered in its own "Lifetime" group on the Pro screen.
    /// `nil` when the IAP isn't configured in App Store Connect for
    /// the current storefront / sandbox.
    var lifetimeProduct: Product? {
        loadedProducts.first { $0.id == Self.lifetimeProductID }
    }

    // MARK: - Actions

    /// Returns `true` if the purchase completed successfully and the
    /// entitlement is now active. `false` covers user-cancel, pending,
    /// and failure paths — callers should inspect `lastError` to show
    /// a useful message when `false` is returned unexpectedly.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let txn):
                    await txn.finish()
                    await refreshEntitlements()
                    return true
                case .unverified(_, let error):
                    lastError = .purchaseFailed(error)
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                lastError = .purchasePending
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = .purchaseFailed(error)
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = .restoreFailed(error)
        }
    }

    /// Open the system subscription management sheet. Falls back to the
    /// App Store's web subscription page if the sheet can't be presented
    /// (e.g. no active foreground scene).
    func showManageSubscriptions() async {
        #if os(macOS)
        // StoreKit 2 has no `showManageSubscriptions` scene overload on macOS.
        NSWorkspace.shared.open(Self.manageSubscriptionsURL)
        #else
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        do {
            if let scene {
                try await AppStore.showManageSubscriptions(in: scene)
            } else {
                await UIApplication.shared.open(Self.manageSubscriptionsURL)
            }
        } catch {
            await UIApplication.shared.open(Self.manageSubscriptionsURL)
        }
        #endif
    }

    func clearError() { lastError = nil }
}

// MARK: - Errors

enum SubscriptionError: Error, Identifiable, Equatable {
    case loadProductsFailed(Error)
    case purchaseFailed(Error)
    case purchasePending
    case restoreFailed(Error)

    var id: String {
        switch self {
        case .loadProductsFailed: "loadProductsFailed"
        case .purchaseFailed:     "purchaseFailed"
        case .purchasePending:    "purchasePending"
        case .restoreFailed:      "restoreFailed"
        }
    }

    var errorDescription: String? {
        switch self {
        case .loadProductsFailed(let e),
             .purchaseFailed(let e),
             .restoreFailed(let e):
            e.localizedDescription
        case .purchasePending:
            String.appLocalized("settings.pro.error.pending")
        }
    }

    // Compare on the case label only — wrapped `Error`s aren't
    // `Equatable`, and two errors of the same kind are equivalent for
    // the `onChange(of: subscription.lastError)` deduplication in the
    // Pro view.
    static func == (lhs: SubscriptionError, rhs: SubscriptionError) -> Bool {
        lhs.id == rhs.id
    }
}
