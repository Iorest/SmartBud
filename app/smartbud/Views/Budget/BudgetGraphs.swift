import Foundation
import SwiftUI
import SwiftData

struct BudgetDollarView: View {
    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    var amount: Double
    var red: Bool
    var scale: Int

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var dynamicTypeSizes: (symbol: Font.TextStyle, amount: Font.TextStyle) {
        if scale == 1 {
            return (.callout, .title3)
        } else if scale == 2 {
            return (.body, .title2)
        } else {
            return (.title2, .largeTitle)
        }
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(currencySymbol)
                .font(.system(dynamicTypeSizes.symbol).weight(.medium))
                .foregroundStyle(red ? Color.AlertRed : Color.SubtitleText)

            Text(amount, format: .number.precision(.fractionLength(showCents && amount < 100 ? 2 : 0)))
                .font(.system(dynamicTypeSizes.amount).weight(.medium))
                .foregroundStyle(red ? Color.AlertRed : Color.PrimaryText)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}

struct DetailedBudgetDollarView: View {
    var amount: Double
    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(currencySymbol)
                .font(.title2.weight(.medium))
                .foregroundStyle(Color.SubtitleText)

            Text(amount, format: .number.precision(.fractionLength(showCents && amount < 100 ? 2 : 0)))
                .font(.largeTitle.weight(.medium))
                .foregroundStyle(Color.PrimaryText)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}

struct DetailedBudgetDifferenceDollarView: View {
    var amount: Double
    var red: Bool

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(currencySymbol)
                .font(.title2.weight(.medium))
                .foregroundStyle(red ? Color.AlertRed : Color.SubtitleText)

            Text(amount, format: .number.precision(.fractionLength(showCents && amount < 100 ? 2 : 0)))
                .font(.largeTitle.weight(.medium))
                .foregroundStyle(red ? Color.AlertRed : Color.PrimaryText)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}
