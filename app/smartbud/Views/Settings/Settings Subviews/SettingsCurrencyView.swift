//
//  SettingsCurrencyView.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsCurrencyView: View {
    @AppStorage("currency", store: .appGroup)
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"

    @Environment(\.dismiss) var dismiss
    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(CurrencyRateStore.self) private var rateStore
    @State private var search = ""
    @State private var pendingRebase: CurrencyRateStore.RebasePreview?
    @State private var rebaseError: String?
    @State private var showRebaseConfirmation = false
    @State private var showRebaseError = false

    private let currencies = Currency.allCurrencies

    private var filtered: [Currency] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return currencies }
        return currencies.filter {
            $0.code.localizedStandardContains(query) || $0.name.localizedStandardContains(query)
        }
    }

    var body: some View {
        List {
            Section {
                NavigationLink(value: SettingsRoute.rates) {
                    Label(String.appLocalized("Exchange Rates"), systemImage: "arrow.left.arrow.right")
                }
            }

            Section {
                ForEach(filtered, id: \.self) { currency in
                    currencyRow(currency)
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        #if os(iOS)
        .searchable(
            text: $search,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(String.appLocalized("Search currencies"))
        )
        #else
        .searchable(text: $search, prompt: Text(String.appLocalized("Search currencies")))
        #endif
        .navigationTitle(String.appLocalized("Currencies"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert(String.appLocalized("Switch base currency?"),
               isPresented: $showRebaseConfirmation,
               presenting: pendingRebase) { preview in
            Button(String.appLocalized("Switch")) { applySwitch(preview) }
            Button(String.appLocalized("Cancel"), role: .cancel) { pendingRebase = nil }
        } message: { preview in
            Text(rebaseMessage(preview))
        }
        .alert(String.appLocalized("Could not switch base currency"),
               isPresented: $showRebaseError) {
            Button(String.appLocalized("Done"), role: .cancel) {}
        } message: {
            Text(rebaseError ?? "")
        }
    }

    private func currencyRow(_ currency: Currency) -> some View {
        Group {
            Button {
                select(currency)
            } label: {
                HStack(spacing: SBSpace.small) {
                    Text(currency.code)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(Color.SubtitleText)
                        .frame(width: 48, alignment: .leading)

                    Text(currency.name)
                        .font(.body)
                        .foregroundStyle(Color.PrimaryText)
                        .lineLimit(1)

                    Spacer(minLength: SBSpace.extraSmall)

                    if currency.code == currencyCode {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(currency.name) (\(currency.code))")
            .accessibilityAddTraits(currency.code == currencyCode ? [.isButton, .isSelected] : .isButton)
        }
    }

    /// Switching the base currency rewrites every frozen base amount, so it is
    /// never a silent setting change: without stored amounts there is nothing
    /// to convert, otherwise we need an anchor rate and an explicit confirmation.
    private func select(_ currency: Currency) {
        guard currency.code != currencyCode else {
            leaveScreen()
            return
        }

        guard ConversionScope.needsConversion else {
            commitSwitch(to: currency.code)
            return
        }

        switch rateStore.rebasePreview(to: currency.code) {
        case .success(let preview):
            pendingRebase = preview
            showRebaseConfirmation = true
        case .failure(let error):
            rebaseError = error.errorDescription
            showRebaseError = true
        }
    }

    private func applySwitch(_ preview: CurrencyRateStore.RebasePreview) {
        pendingRebase = nil
        do {
            try rateStore.rebase(to: preview.newBase)
            leaveScreen()
        } catch {
            rebaseError = error.localizedDescription
            showRebaseError = true
        }
    }

    private func commitSwitch(to code: String) {
        currencyCode = code
        NSUbiquitousKeyValueStore.default.set(code, forKey: "currency")
        rateStore.load()
        leaveScreen()
    }

    /// Leaving while the search field is still active leaves its bar floating
    /// over the next screen, so close the search first.
    private func leaveScreen() {
        dismissSearch()
        dismiss()
    }

    private func rebaseMessage(_ preview: CurrencyRateStore.RebasePreview) -> String {
        let factor = preview.factor.formatted(
            .number.precision(.fractionLength(4)).locale(.appLocale))
        return String.appFormatted(
            "Every stored amount will be converted at 1 %@ = %@ %@ (%lld records) and then stay fixed.",
            preview.oldBase, factor, preview.newBase, preview.recordCount)
    }
}

/// Whether switching the base currency has anything to convert.
private enum ConversionScope {
    @MainActor
    static var needsConversion: Bool {
        let repo = DataRepository.shared
        // Accounts whose opening balance is a base-currency number, and the
        // transfers between them, move too. Missing them here skipped the
        // conversion entirely and left those amounts on the old scale.
        let baseAccounts = repo.fetch(AccountModel.self)
            .contains { $0.currencyCode.isEmpty && $0.openingBalance != 0 }
        return baseAccounts
            || !repo.fetch(TransactionModel.self).isEmpty
            || !repo.fetch(TransferModel.self).isEmpty
            || !repo.fetch(BudgetModel.self).isEmpty
            || !repo.fetch(MainBudgetModel.self).isEmpty
            || !repo.fetch(TemplateTransactionModel.self).isEmpty
            || !repo.fetch(CurrencyRate.self).isEmpty
    }
}
