//
//  SettingsProView+Sections.swift
//  smartbud
//

import StoreKit
import SwiftUI

extension SettingsProView {
    var legalBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Lifetime owners have no auto-renewal — the subscription
            // body (which describes how to turn off auto-renew, when
            // the account is charged, etc.) would be misleading. Show
            // the lifetime body instead. Limited-time-free users and
            // active subscribers both still see the standard auto-
            // renewal disclosure.
            Text(String.appLocalized(
                subscription.userOwnsLifetime
                    ? SettingsKey.proLifetimeLegalBody
                    : SettingsKey.proLegalBody
            ))
            .font(.caption)
            .foregroundStyle(Color.SubtitleText)
            .fixedSize(horizontal: false, vertical: true)

            legalAgreementLinks
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.SettingsBackground.opacity(0.6),
            in: RoundedRectangle(cornerRadius: SBRadius.card)
        )
    }

    /// Renders the "By subscribing, you agree to our [Terms] · [Privacy]."
    /// line as separate `Text` + `Link` views. Two separate `Link`s are
    /// preferred over a Markdown blob inside `Text` so the URLs are
    /// bound at runtime from `SubscriptionManager.termsOfServiceURL` /
    /// `.privacyPolicyURL` (both are open items before App Store submission
    /// — see the `Open item (hosting)` note on `SubscriptionManager`).
    var legalAgreementLinks: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(String.appLocalized(SettingsKey.proLegalAgree) + " ")
            Link(
                String.appLocalized(SettingsKey.proTermsOfUse),
                destination: SubscriptionManager.termsOfServiceURL
            )
            Text("·")
                .foregroundStyle(Color.SubtitleText.opacity(0.6))
            Link(
                String.appLocalized(SettingsKey.proPrivacyPolicy),
                destination: SubscriptionManager.privacyPolicyURL
            )
            Text(".")
        }
        .font(.caption)
        .foregroundStyle(Color.SubtitleText)
    }

    // MARK: - Action buttons

    var manageSubscriptionButton: some View {
        Button {
            Task { await subscription.showManageSubscriptions() }
        } label: {
            HStack {
                Image(systemName: "gearshape.fill")
                Text(String.appLocalized(SettingsKey.proManageSubscription))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
    }

    var restorePurchasesButton: some View {
        Button {
            Task { await subscription.restorePurchases() }
        } label: {
            Text(String.appLocalized("Restore Purchases"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.SubtitleText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .accessibilityIdentifier(AccessibilityID.proRestore)
    }
}

extension SettingsProView {

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollView {
                VStack(spacing: 24) {
                    // `hasActualProEntitlement` is the verified-storekit
                    // entitlement only — independent of the
                    // `isLimitedTimeFree` flag. This means:
                    //   * Unlimited-time-free + never paid → subscribe
                    //     state, with a banner up top, so the reviewer
                    //     (and the user) can still see and tap prices.
                    //   * Unlimited-time-free + already paid → active
                    //     state, the "you already have Pro" UI.
                    //   * Limited-time-free off + paid → active state.
                    //   * Limited-time-free off + never paid → subscribe
                    //     state, plain pricing, no banner.
                    // Previously this branched on `isProSubscriber`,
                    // which folds the promo flag in — so under the
                    // default `isLimitedTimeFree = true` we were
                    // permanently on the active branch and never showed
                    // any product. That was a Guideline 2.1 / 2.3
                    // rejection risk (no IAPs visible to the reviewer).
                    if subscription.hasActualProEntitlement {
                        activeState
                    } else {
                        subscribeState
                    }
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
        .modifier(SettingsSubviewModifier())
        .task {
            await subscription.bootstrap()
        }
        .onChange(of: subscription.lastError) { _, newError in
            guard let newError else { return }
            pendingErrorMessage = newError.errorDescription
                ?? String.appLocalized(SettingsKey.proErrorPurchase)
            isPresentingError = true
            subscription.clearError()
        }
        .alert(
            String.appLocalized(SettingsKey.proErrorTitle),
            isPresented: $isPresentingError,
            actions: {
                Button(String.appLocalized(SettingsKey.proErrorDismiss), role: .cancel) {}
            },
            message: { Text(pendingErrorMessage) }
        )
    }
}
