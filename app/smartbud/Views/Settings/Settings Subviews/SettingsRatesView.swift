//
//  SettingsRatesView.swift
//  smartbud
//
//  Exchange rates for the currencies the user actually holds. Rates are stored
//  as "1 unit of CODE = X units of the base currency" and only affect totals
//  and account balances — past transactions keep the rate they were saved with.
//

import SwiftUI

struct SettingsRatesView: View {
    @Environment(AccountViewModel.self) private var accountVM
    @Environment(CurrencyRateStore.self) private var rateStore

    @AppStorage("currency", store: .appGroup) private var baseCurrency: String =
        Locale.current.currency?.identifier ?? "USD"

    @State private var drafts: [String: String] = [:]

    /// Every currency an account is denominated in, minus the base currency.
    private var foreignCodes: [String] {
        let codes = Set(accountVM.accounts.map(\.resolvedCurrencyCode))
        return codes.filter { $0 != baseCurrency }.sorted()
    }

    var body: some View {
        Form {
            Section {
                if foreignCodes.isEmpty {
                    Text(String.appLocalized(
                        "All your accounts use the base currency, so no rates are needed."))
                        .font(.footnote)
                        .foregroundStyle(Color.SubtitleText)
                } else {
                    ForEach(foreignCodes, id: \.self) { code in
                        rateRow(code)
                    }
                }
            } header: {
                Text(String.appFormatted("1 unit of each currency in %@", baseCurrency))
            } footer: {
                Text(String.appLocalized(
                    "Totals and the accounts screen convert with these rates. "
                        + "A transaction keeps the rate it was saved with, so history never changes."))
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String.appLocalized("Exchange Rates"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            accountVM.load()
            rateStore.load()
            for code in foreignCodes where drafts[code] == nil {
                drafts[code] = rateStore.rates[code].map { String(format: "%.4f", $0) } ?? ""
            }
        }
    }

    private func rateRow(_ code: String) -> some View {
        HStack(spacing: SBSpace.small) {
            Text(code)
                .font(.subheadline.monospaced())
                .foregroundStyle(Color.SubtitleText)
                .frame(width: 48, alignment: .leading)

            TextField("0", text: Binding(
                get: { drafts[code] ?? "" },
                set: { newValue in
                    drafts[code] = newValue
                    let parsed = Double(newValue.replacingOccurrences(of: ",", with: "."))
                    if let parsed, parsed > 0 {
                        rateStore.setRate(parsed, for: code)
                    }
                }
            ))
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
            .multilineTextAlignment(.trailing)
            .monospacedDigit()

            Text(baseCurrency)
                .font(.footnote)
                .foregroundStyle(Color.SubtitleText)
        }
        .accessibilityElement(children: .combine)
    }
}
