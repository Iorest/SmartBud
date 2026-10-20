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
    @State private var search = ""

    private let currencies = Currency.allCurrencies

    private var filtered: [Currency] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return currencies }
        return currencies.filter {
            $0.code.localizedStandardContains(query) || $0.name.localizedStandardContains(query)
        }
    }

    var body: some View {
        List(filtered, id: \.self) { currency in
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

                    Spacer(minLength: SBSpace.xs)

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
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.plain)
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
    }

    private func select(_ currency: Currency) {
        currencyCode = currency.code
        NSUbiquitousKeyValueStore.default.set(currency.code, forKey: "currency")
        dismiss()
    }
}
