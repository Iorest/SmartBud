//
//  SettingsProView.swift
//  smartbud
//
//  SmartBud Pro subscription view. Shows the premium feature list and a
//  StoreKit 2 `ProductView` for purchasing, plus the disclosures required
//  by App Store Guideline 3.1.2 (auto-renewal terms, links to Terms of
//  Use / Privacy Policy, an in-app Manage Subscription entry per
//  Guideline 3.1.5).
//
//  All StoreKit work is delegated to `SubscriptionManager`. The view is
//  intentionally free of `Product.products(for:)` and `AppStore.sync()`
//  calls so the entitlement lifecycle has exactly one implementation.
//

import StoreKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct SettingsProView: View {
    @Environment(\.dismiss) var dismiss

    @State var subscription = SubscriptionManager.shared
    @State private var settingsVM = SettingsViewModel.shared

    @State var isPresentingError: Bool = false
    @State var pendingErrorMessage: String = ""

    // Note: `iCloud Sync` was removed from `features` because all users
    // already get it for free via the CloudKit-backed SwiftData store
    // (`SwiftDataCore.swift`). Charging for it as a Pro feature is
    // misleading advertising and a likely 3.1.1 reviewer flag.
    //
    // Note: `Batch Recognition` (OCR import from receipt photos) is
    // also not in this list — the underlying Vision pipeline is not
    // shipped yet, so advertising it would be a 3.1.1 violation
    // (misleading). Add it back here when the implementation lands.
    struct ProFeature {
        let icon: String
        let color: String
        let titleKey: String
        let subtitleKey: String
    }

    // Keep this list to features that are actually gated by `ProAccess`;
    // advertising more than the app enforces is a 3.1.1 problem.
    private var features: [ProFeature] = [
        ProFeature(icon: "chart.bar.xaxis", color: "103", titleKey: "Advanced Insights",
                   subtitleKey: "AI analysis of this period with concrete suggestions."),
        ProFeature(icon: "paintpalette.fill", color: "100", titleKey: "Exclusive Themes",
                   subtitleKey: "Six additional app icons."),
        ProFeature(icon: "bell.badge.fill", color: "102", titleKey: "Smart Reminders",
                   subtitleKey: "Choose a custom time for the daily reminder.")
    ]

    // MARK: - Header

    var headerBar: some View {
        HStack {
            Button { dismiss() } label: { SettingsBackButton() }
            Spacer()
        }
        .overlay(alignment: .center) {
            Text(String.appLocalized(SettingsKey.proTitle))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.PrimaryText)
        }
        .padding(.bottom, 20)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Brand.premium)
                    .frame(width: 80, height: 80)
                    .shadow(
                        color: Theme.Brand.premium.opacity(0.4),
                        radius: 12, y: 4
                    )
                Image(systemName: "crown.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)

            Text(settingsVM.proCardSubtitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.PrimaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    // MARK: - States

    var activeState: some View {
        // We only reach this branch when the user has a verified
        // StoreKit entitlement — so the limited-time-free flag is
        // irrelevant here. (Free-but-never-paid users land on
        // `subscribeState`, where the banner handles the promo
        // messaging.)
        VStack(spacing: 24) {
            hero
            if subscription.userOwnsLifetime {
                // Lifetime owner has no subscription to manage — show
                // the Pro badge plus a Restore button in case they
                // switch devices. Keep the auto-renew legal block out
                // (replaced by the lifetime one below).
                proActiveBadge
                restorePurchasesButton
            } else {
                proActiveBadge
                manageSubscriptionButton
                restorePurchasesButton
            }
            legalBlock
        }
    }

    var subscribeState: some View {
        VStack(spacing: 24) {
            hero
            // Show the limited-time-free banner only when the user
            // hasn't paid AND the promo flag is on. After the flag is
            // flipped to `false` (see `SubscriptionManager.isLimitedTimeFree`),
            // the banner disappears automatically — no UI change needed.
            if subscription.isLimitedTimeFree {
                limitedTimeFreeBanner
            }
            featuresList
            subscribeSection
            legalBlock
        }
    }

    private var proActiveBadge: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.IncomeGreen)
            Text(String.appLocalized("Pro Active"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.PrimaryText)
            Text(String.appLocalized("Thank you for supporting SmartBud development."))
                .font(.subheadline)
                .foregroundStyle(Color.SubtitleText)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 30)
    }

    /// Compact "Limited-Time Free" notice shown at the top of the
    /// pricing screen during the launch / promo period
    /// (`SubscriptionManager.isLimitedTimeFree == true`). Tells the
    /// user that Pro features are free for now and they can buy
    /// early-access anyway if they want to lock in lifetime.
    ///
    /// Kept as a small inline banner so it doesn't visually compete
    /// with the price list and feature list below it.
    private var limitedTimeFreeBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.body)
                .foregroundStyle(Color.IncomeGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(String.appLocalized(SettingsKey.proLimitedFreeTitle))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.PrimaryText)
                Text(String.appLocalized(SettingsKey.proLimitedFreeSubtitle))
                    .font(.caption)
                    .foregroundStyle(Color.SubtitleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(
            Color.SettingsBackground,
            in: RoundedRectangle(cornerRadius: SBRadius.card)
        )
    }

    private var featuresList: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Color(feature.color),
                            in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(feature.titleKey))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.PrimaryText)
                        Text(LocalizedStringKey(feature.subtitleKey))
                            .font(.footnote)
                            .foregroundStyle(Color.SubtitleText)
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                if index < features.count - 1 {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(
            Color.SettingsBackground,
            in: RoundedRectangle(cornerRadius: SBRadius.card)
        )
    }

    @ViewBuilder
    private var subscribeSection: some View {
        if subscription.loadedProducts.isEmpty {
            VStack(spacing: 8) {
                Text(String.appLocalized("Coming Soon"))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.PrimaryText)
                Text(String.appLocalized("Subscription products will be available in a future update."))
                    .font(.footnote)
                    .foregroundStyle(Color.SubtitleText)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                Color.SettingsBackground,
                in: RoundedRectangle(cornerRadius: SBRadius.card)
            )
        } else {
            VStack(spacing: 20) {
                if !subscription.subscriptionProducts.isEmpty {
                    subscriptionsGroup
                }
                if subscription.lifetimeProduct != nil {
                    lifetimeGroup
                }
                restorePurchasesButton
            }
        }
    }

    /// Renders the three auto-renewable subscription SKUs (monthly /
    /// half-yearly / yearly) under a "SUBSCRIPTIONS" header. Empty
    /// list is fine — the `subscribeSection` outer guard handles
    /// "no products at all", but a Store can return only the lifetime
    /// product, in which case this group is omitted.
    private var subscriptionsGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(SettingsKey.proSectionSubscriptions)
            VStack(spacing: 12) {
                ForEach(subscription.subscriptionProducts) { product in
                    ProductView(product)
                        .productViewStyle(.compact)
                        .onInAppPurchaseCompletion { _, result in
                            // `result` is `Result<Product.PurchaseResult, Error>`.
                            // The ProductView handles the actual StoreKit
                            // call and verification; we just need to
                            // re-read `Transaction.currentEntitlements`
                            // so `isProSubscriber` flips on this device.
                            Task { await subscription.refreshEntitlements() }
                            if case .failure(let error) = result {
                                pendingErrorMessage = error.localizedDescription
                                isPresentingError = true
                            }
                        }
                }
            }
        }
    }

    /// Renders the non-consumable lifetime SKU under a "LIFETIME"
    /// header, with a one-line "One-time purchase" caption so the
    /// user can tell it apart from the auto-renewing plans above.
    /// The @ViewBuilder lets us return `EmptyView` cleanly when the
    /// Store didn't return the lifetime product (e.g. a sandbox that
    /// only has subscriptions configured).
    @ViewBuilder
    private var lifetimeGroup: some View {
        if let lifetime = subscription.lifetimeProduct {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(SettingsKey.proSectionLifetime)
                VStack(spacing: 4) {
                    ProductView(lifetime)
                        .productViewStyle(.compact)
                        .onInAppPurchaseCompletion { _, result in
                            Task { await subscription.refreshEntitlements() }
                            if case .failure(let error) = result {
                                pendingErrorMessage = error.localizedDescription
                                isPresentingError = true
                            }
                        }
                    Text(String.appLocalized(SettingsKey.proLifetimeOneTime))
                        .font(.caption2)
                        .foregroundStyle(Color.SubtitleText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Small uppercase label used to head each product group on the
    /// Pro screen. Kept as a separate helper so the visual style stays
    /// consistent if the grouping expands in the future.
    private func sectionHeader(_ key: String) -> some View {
        Text(String.appLocalized(key).uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.SubtitleText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
