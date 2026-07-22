//
//  SettingsProView.swift
//  smartbud
//
//  SmartBud Pro subscription view. Shows the premium feature list and a
//  StoreKit 2 ProductView for purchasing. When no products are configured
//  (e.g. development build without App Store Connect setup), falls back to
//  a "Coming Soon" placeholder so the screen still renders correctly.
//

import SwiftUI
import StoreKit

struct SettingsProView: View {
    @Environment(\.dismiss) var dismiss
    @State var settingsVM = SettingsViewModel.shared

    @AppStorage("isProSubscriber", store: .appGroup)
    var isProSubscriber: Bool = false

    @State private var loadedProducts: [Product] = []
    @State private var isLoadingProducts: Bool = false

    private let productIDs: [String] = [
        "com.iorest.smartbud.pro.monthly",
        "com.iorest.smartbud.pro.yearly"
    ]

    private let features: [(icon: String, color: String, title: String, subtitle: String)] = [
        ("icloud.fill", "111", String.appLocalized("iCloud Sync"), String.appLocalized("Sync your data across all your Apple devices")),
        ("doc.text.viewfinder", "112", String.appLocalized("Batch Recognition"), String.appLocalized("Import multiple transactions from a single receipt photo")),
        ("chart.bar.xaxis", "103", String.appLocalized("Advanced Insights"), String.appLocalized("Deeper breakdowns, custom date ranges, exportable charts")),
        ("paintpalette.fill", "100", String.appLocalized("Exclusive Themes"), String.appLocalized("Additional app icons and accent colors")),
        ("bell.badge.fill", "102", String.appLocalized("Smart Reminders"), String.appLocalized("Customizable notification schedules and quiet hours")),
        ("lock.shield.fill", "105", String.appLocalized("Priority Support"), String.appLocalized("Direct access to the development team for help"))
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    SettingsBackButton()
                }
                Spacer()
            }
            .overlay(alignment: .center) {
                Text(String.appLocalized("SmartBud Pro"))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.PrimaryText)
            }
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 24) {
                    header
                    if isProSubscriber {
                        proActiveBadge
                    } else {
                        featuresList
                        subscribeSection
                    }
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
        .modifier(SettingsSubviewModifier())
        .task {
            await loadProducts()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.78, blue: 0.31))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(red: 0.95, green: 0.78, blue: 0.31).opacity(0.4), radius: 12, y: 4)
                Image(systemName: "crown.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)

            Text(settingsVM.proCardSubtitle)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.PrimaryText)
                .multilineTextAlignment(.center)

            Text(String.appLocalized("iCloud Sync, Batch Recognition and more"))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.SubtitleText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    private var proActiveBadge: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.IncomeGreen)
            Text(String.appLocalized("Pro Active"))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.PrimaryText)
            Text(String.appLocalized("Thank you for supporting SmartBud development."))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.SubtitleText)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 30)
    }

    private var featuresList: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color(feature.color), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(feature.title))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.PrimaryText)
                        Text(LocalizedStringKey(feature.subtitle))
                            .font(.system(.footnote, design: .rounded))
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
        .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var subscribeSection: some View {
        if loadedProducts.isEmpty {
            VStack(spacing: 8) {
                Text(String.appLocalized("Coming Soon"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.PrimaryText)
                Text(String.appLocalized("Subscription products will be available in a future update."))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.SubtitleText)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(spacing: 12) {
                ForEach(loadedProducts) { product in
                    ProductView(product)
                        .productViewStyle(.compact)
                        .onInAppPurchaseCompletion { _, result in
                            if case .success = result {
                                isProSubscriber = true
                            }
                        }
                }

                Button {
                    Task { await restorePurchases() }
                } label: {
                    Text(String.appLocalized("Restore Purchases"))
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.SubtitleText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
    }

    @MainActor
    private func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: productIDs)
            loadedProducts = products.sorted { $0.price < $1.price }
        } catch {
            loadedProducts = []
        }
    }

    @MainActor
    private func restorePurchases() async {
        do {
            try await AppStore.sync()
            // After sync, the ProductView's onInAppPurchaseCompletion will
            // fire for any restored transactions. For a development build
            // without configured products, AppStore.sync() succeeds silently
            // and we just keep the current isProSubscriber state.
        } catch {
            // Silent failure — StoreKit shows its own error UI
        }
    }
}
