import Foundation
import SwiftUI
import SwiftData

/// Currency symbol + amount, as used on the budget cards and the detail
/// header. `scale` picks the type ramp (1 = card, 2 = promoted card,
/// 3 = detail header); `red` switches to the over-budget colour.
struct BudgetDollarView: View {
    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    var amount: Double
    var red: Bool = false
    var scale: Int = 1

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var dynamicTypeSizes: (symbol: Font.TextStyle, amount: Font.TextStyle) {
        switch scale {
        case 1: return (.callout, .title3)
        case 2: return (.body, .title2)
        default: return (.title2, .largeTitle)
        }
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: currencySymbol.count > 1 ? 6 : 1.3) {
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
