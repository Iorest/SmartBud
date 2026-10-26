//
//  RecentTransactionsWidgetViews.swift
//  smartbud
//
import SwiftUI
import WidgetKit
import SwiftData

struct ExpenditureWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: Provider.Entry

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    var inlineSubtitleText: String {
        switch entry.duration {
        case .unknown:
            return String.appLocalized("NIL")
        case .day:
            return String.appLocalized("today")
        case .week:
            return String.appLocalized("this week")
        case .month:
            let formatter = DateFormatter()
            formatter.locale = Locale.appLocale
            formatter.dateFormat = "MMM"
            return String.appFormatted("in %@", formatter.string(from: Date.now))
        case .year:
            let formatter = DateFormatter()
            formatter.locale = Locale.appLocale
            formatter.dateFormat = "yyyy"
            return String.appFormatted("in %@", formatter.string(from: Date.now))
        }
    }

    var typeText: String {
        switch entry.type {
        case .unknown:
            return ""
        case .net:
            return String.appLocalized("net")
        case .income:
            return String.appLocalized("earned")
        case .expense:
            return String.appLocalized("spent")
        }
    }

    var positivityText: String {
        switch entry.type {
        case .unknown:
            return ""
        case .net:
            if entry.amount > 0 {
                return "+"
            } else {
                return "-"
            }
        case .income:
            return "+"
        case .expense:
            return "-"
        }
    }

    func getRectangularWidgetFont(width: CGFloat) -> CGFloat {
        var fontSize = 15.0

        while fontSize > 12 {
            var max = 0.0
            entry.transactions.forEach { transaction in
                let amountText: String
                if showCents && transaction.amount < 100 {
                    amountText = currencySymbol + transaction.amount.formatted(
                        .number.locale(Locale(identifier: "en_US_POSIX"))
                            .precision(.fractionLength(2))
                    )
                } else {
                    amountText = currencySymbol + transaction.amount.formatted(
                        .number.locale(Locale(identifier: "en_US_POSIX"))
                            .precision(.fractionLength(0))
                    )
                }

                let holding = transaction
                    .note
                    .widthOfRoundedString(size: fontSize, weight: .semibold) + amountText
                    .widthOfRoundedString(size: fontSize, weight: .regular) + 8

                if holding > max {
                    max = holding
                }
            }

            if width > max {
                return fontSize
            }

            fontSize -= 1
        }

        return 12
    }
}

struct RecentTransactionsDollarView: View {
    var amount: Double
    var showCents: Bool
    var net: Bool
    var bigger: Bool = false

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var actualAmount: Double {
        if net {
            return abs(amount)
        } else {
            return amount
        }
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(net ? "\(amount < 0 ? "-" : (amount == 0 ? "" : "+"))\(currencySymbol)" : currencySymbol)
                .font(.system(bigger ? .title3 : .subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(Color.SubtitleText)

            Text("\(actualAmount, specifier: showCents && actualAmount < 100  ? "%.2f" : "%.0f")")
                .font(.system(bigger ? .title : .title3, design: .rounded).weight(.medium))
                .foregroundStyle(Color.PrimaryText)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}

extension ExpenditureWidgetEntryView {

    @ViewBuilder
    var body: some View {
        switch widgetFamily {
        case .accessoryInline:
            if entry.amount == 0 {
                Text("\(currencySymbol)0 \(typeText) \(inlineSubtitleText)")
            } else {
                let amount = amountText(abs(entry.amount), showCents: showCents, under: 1000)
                Text("\(positivityText)\(currencySymbol)\(amount) \(inlineSubtitleText)")
            }
        case .accessoryRectangular:
            if entry.transactions.count == 0 {
                Text(String.appLocalized("NO RECENT EXPENSES"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                GeometryReader { proxy in
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(entry.transactions.prefix(3), id: \.self) { transaction in
                            HStack(spacing: 3) {
                                Text(transaction.note)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(signedAmount(transaction.amount, income: transaction.income, showCents: showCents))
                                    .fontWeight(.regular)
                                    .layoutPriority(1)
                                    .lineLimit(1)
                            }
                            .font(.system(size: getRectangularWidgetFont(width: proxy.size.width), design: .rounded))
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .containerBackground(for: .widget) { Color.clear }
            }
        case .systemSmall:
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text("\(typeText) \(inlineSubtitleText)".uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.SubtitleText)

                        RecentTransactionsDollarView(
                            amount: entry.amount,
                            showCents: showCents,
                            net: entry.type == .net,
                            bigger: true
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: proxy.size.height * 0.27)
                    }
                    .frame(maxWidth: .infinity)

                    if entry.transactions.isEmpty {
                        VStack(spacing: 5) {
                            Text(String.appLocalized("NO RECENT EXPENSES"))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.SubtitleText)
                                .frame(maxHeight: .infinity)

                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))

                                Text(String.appLocalized("New Expense"))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.PrimaryText)
                            }
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: SBRadius.chip).fill(Color.SecondaryBackground))
                            .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                        .padding(.top, 12)

                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(String.appLocalized("RECENT EXPENSES"))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.SubtitleText)

                            ForEach(entry.transactions.prefix(3), id: \.self) { transaction in
                                HStack(spacing: 5) {
                                    Capsule()
                                        .fill(Color(hex: transaction.colour))
                                        .frame(width: 4, height: 12)

                                    Text(transaction.note)
                                        .lineLimit(1)
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(Color.PrimaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if transaction.income {
                                        Text(signedAmount(transaction.amount, income: true, showCents: showCents))
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundStyle(Color.IncomeGreen)
                                            .lineLimit(1)
                                            .layoutPriority(1)
                                    } else {
                                        Text(signedAmount(transaction.amount, income: false, showCents: showCents))
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundStyle(Color.SubtitleText)
                                            .lineLimit(1)
                                            .layoutPriority(1)
                                    }
                                }
                            }

                            if entry.transactions.count < 2 {
                                HStack(spacing: 5) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))

                                    Text(String.appLocalized("New Expense"))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.PrimaryText)
                                }
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: SBRadius.chip).fill(Color.SecondaryBackground)
                                )
                                .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                        .padding(.top, entry.transactions.count >= 3 ? 5 : 10)
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) {
                WidgetGlassBackground()
            }
            // Always open the ledger. With fewer than two rows this used to
            // open the entry form, so tapping a transaction started a new one.
            .widgetURL(URL(string: "smartbud://open?tab=log"))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

        case .systemLarge:
            GeometryReader { _ in
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text("\(typeText) \(inlineSubtitleText)".uppercased())
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.SubtitleText)

                        RecentTransactionsDollarView(
                            amount: entry.amount,
                            showCents: showCents,
                            net: entry.type == .net
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)

                    Spacer()
                        .frame(minHeight: 5, idealHeight: 15, maxHeight: 20)
                        .fixedSize()

                    if entry.transactions.isEmpty {
                        VStack(spacing: 20) {
                            Text(String.appLocalized("NO RECENT EXPENSES"))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.SubtitleText)

                            Link(destination: URL(string: "smartbud://newExpense")!) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))

                                    Text(String.appLocalized("New Expense"))
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.PrimaryText)
                                }
                                .padding(.vertical, 6)
                                .frame(width: 200)
                                .background(RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                                    .fill(Color.SecondaryBackground))
                            }
                        }
                        .frame(maxHeight: .infinity)

                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String.appLocalized("RECENT EXPENSES"))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.SubtitleText)

                            ForEach(entry.transactions, id: \.self) { transaction in
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: SBRadius.chip)
                                        .fill(Color(hex: transaction.colour))
                                        .frame(width: 15, height: 15)

                                    Text(transaction.note)
                                        .lineLimit(1)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.PrimaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if transaction.income {
                                        Text(signedAmount(transaction.amount, income: true, showCents: showCents))
                                            .font(.system(size: 16, weight: .regular, design: .rounded))
                                            .foregroundStyle(Color.IncomeGreen)
                                            .lineLimit(1)
                                            .layoutPriority(1)
                                    } else {
                                        Text(signedAmount(transaction.amount, income: false, showCents: showCents))
                                            .font(.system(size: 16, weight: .regular, design: .rounded))
                                            .foregroundStyle(Color.SubtitleText)
                                            .lineLimit(1)
                                            .layoutPriority(1)
                                    }
                                }
                            }

                            if entry.transactions.count < 5 {
                                Link(destination: URL(string: "smartbud://newExpense")!) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))

                                        Text(String.appLocalized("New Expense"))
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color.PrimaryText)
                                    }
                                    .padding(.vertical, 6)
                                    .frame(width: 200)
                                    .background(RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                                        .fill(Color.SecondaryBackground))
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) { WidgetGlassBackground() }
            .widgetURL(URL(string: "smartbud://open?tab=log"))

        default:
            EmptyView()
        }
    }
}
