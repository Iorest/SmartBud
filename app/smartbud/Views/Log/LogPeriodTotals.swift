//
//  LogPeriodTotals.swift
//  smartbud
//
//  One-line totals for the filtered ledger (day / week / month / category).
//  The header card with the big net number only exists for "all", so without
//  this line a filtered list had no idea what the period added up to.
//

import Foundation
import SwiftUI

struct LogPeriodTotals: View {
    let entries: [TransactionModel]
    let currency: String
    let showCents: Bool

    private var spent: Decimal {
        Money.sum(entries.filter(\.countsAsSpend).map(\.wrappedBaseAmount))
    }

    private var income: Decimal {
        Money.sum(entries.filter(\.countsAsIncome).map(\.wrappedBaseAmount))
    }

    private var net: Decimal { income - spent }

    var body: some View {
        HStack(spacing: SBSpace.small) {
            // The row is already labelled, so only income/net carry a sign.
            label(String.appLocalized("Expense"), value: plain(spent), colour: Color.AlertRed)
            label(String.appLocalized("Income"), value: signed(income), colour: Color.IncomeGreen)
            Spacer(minLength: 0)
            label(String.appLocalized("Net"), value: signed(net),
                  colour: net >= 0 ? Color.PrimaryText : Color.AlertRed)
        }
        .accessibilityElement(children: .combine)
    }

    /// Keeps the "+" for money coming in and the "−" for money going out, but
    /// never writes "−¥0.00".
    private func plain(_ value: Decimal) -> String {
        Money.format(value, currencyCode: currency, showsCents: showCents, locale: .appLocale)
    }

    private func signed(_ value: Decimal) -> String {
        guard value != 0 else {
            return Money.format(Decimal.zero, currencyCode: currency,
                                showsCents: showCents, locale: .appLocale)
        }
        return Money.format(value, currencyCode: currency, showsCents: showCents,
                            plus: value > 0, locale: .appLocale)
    }

    private func label(_ title: String, value: String, colour: Color) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .foregroundStyle(Color.SubtitleText)
            Text(value)
                .foregroundStyle(colour)
                .monospacedDigit()
        }
        .font(.caption)
        .lineLimit(1)
    }
}
