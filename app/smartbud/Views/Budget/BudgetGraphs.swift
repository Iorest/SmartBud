import Foundation
import SwiftUI
import SwiftData

struct AnimatedBudgetBarGraph: View {
    var color: Color
    var percent: Double

    @AppStorage("animated", store: .appGroup) var animated: Bool = true
    @State var showBar: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(0.3))
                    .frame(height: proxy.size.height)

                if percent > 0 {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color.opacity(0.73))
                            .frame(height: showBar ? nil : 0, alignment: .bottom)
                    }
                    .frame(height: proxy.size.height * percent)
                }
            }
        }
        .onAppear {
            Task { @MainActor in
                if !animated {
                    showBar = true
                } else {
                    withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)) {
                        showBar = true
                    }
                }
            }
        }
    }
}

struct BudgetDollarView: View {
    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    var amount: Double
    var red: Bool
    var scale: Int
    var size: CGFloat

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
                .font(.system(dynamicTypeSizes.symbol, design: .rounded).weight(.medium))
                .foregroundStyle(red ? Color.AlertRed : Color.SubtitleText)

            Text(amount, format: .number.precision(.fractionLength(showCents && amount < 100 ? 2 : 0)))
                .font(.system(dynamicTypeSizes.amount, design: .rounded).weight(.medium))
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
                .font(.system(.title2, design: .rounded).weight(.medium))
                .foregroundStyle(Color.SubtitleText)

            Text(amount, format: .number.precision(.fractionLength(showCents && amount < 100 ? 2 : 0)))
                .font(.system(.largeTitle, design: .rounded).weight(.medium))
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
                .font(.system(.title2, design: .rounded).weight(.medium))
                .foregroundStyle(red ? Color.AlertRed : Color.SubtitleText)

            Text(amount, format: .number.precision(.fractionLength(showCents && amount < 100 ? 2 : 0)))
                .font(.system(.largeTitle, design: .rounded).weight(.medium))
                .foregroundStyle(red ? Color.AlertRed : Color.PrimaryText)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}

struct AnimatedHorizontalBarGraphBudget: View {
    let category: CategoryModel

    @State var showBar: Bool = false
    @AppStorage("animated", store: .appGroup) var animated: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
                .foregroundStyle(Color(hex: category.wrappedColour))
                .frame(width: showBar ? nil : 0, alignment: .leading)

            Spacer(minLength: 0)
        }
        .onAppear {
            Task { @MainActor in
                if !animated {
                    showBar = true
                } else {
                    withAnimation(.easeInOut(duration: 0.7)) {
                        showBar = true
                    }
                }
            }
        }
    }
}

struct AnimatedHorizontalBarGraphMainBudget: View {
    @State var showBar: Bool = false
    @AppStorage("animated", store: .appGroup) var animated: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
                .fill(Color.DarkBackground)
                .frame(width: showBar ? nil : 0, alignment: .leading)

            Spacer(minLength: 0)
        }
        .onAppear {
            Task { @MainActor in
                if !animated {
                    showBar = true
                } else {
                    withAnimation(.easeInOut(duration: 0.7)) {
                        showBar = true
                    }
                }
            }
        }
    }
}

struct AnimatedCurvedBarGraphBudget: View {
    var totalSpent: Double
    var budgetTotal: Double
    let cornerRadius: Double
    let width: Double
    let color: String
    @State var percent: Double = 0

    @AppStorage("animated", store: .appGroup) var animated: Bool = true

    var body: some View {
        DonutSemicircle(percent: percent, cornerRadius: cornerRadius, width: width)
            .fill(Color(color))
            .onAppear {
                Task { @MainActor in
                    if !animated {
                        percent = 1 - (totalSpent / budgetTotal)
                    } else {
                        withAnimation(.easeInOut(duration: 0.7)) {
                            percent = 1 - (totalSpent / budgetTotal)
                        }
                    }
                }
            }
    }
}

struct AnimatedCurvedBarGraphMainBudget: View {
    var totalSpent: Double
    var budgetTotal: Double
    let cornerRadius: Double
    let width: Double

    @State var percent: Double = 0

    @AppStorage("animated", store: .appGroup) var animated: Bool = true

    var body: some View {
        DonutSemicircle(percent: percent, cornerRadius: cornerRadius, width: width)
            .fill(Color.DarkBackground)
            .onAppear {
                Task { @MainActor in
                    if !animated {
                        percent = 1 - (totalSpent / budgetTotal)
                    } else {
                        withAnimation(.easeInOut(duration: 0.7)) {
                            percent = 1 - (totalSpent / budgetTotal)
                        }
                    }
                }
            }
    }
}

