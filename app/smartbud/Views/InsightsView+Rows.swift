//
//  InsightsView+Rows.swift
//  smartbud
//
import SwiftUI
import SwiftData
import WidgetKit

struct InsightsDollarView: View {
    let amount: Double
    let currencySymbol: String
    let showCents: Bool
    let net: Bool?
    let color: Color

    private var symbol: String {
        if let netPositive = net {
            return netPositive ? "+\(currencySymbol)" : "-\(currencySymbol)"
        }
        return currencySymbol
    }

    private var formattedAmount: String {
        amount.formatted(.number.precision(.fractionLength(showCents && amount < 100 ? 2 : 0)))
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(symbol)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.SubtitleText)
            Text(formattedAmount)
                .font(.title.weight(.medium))
                .foregroundStyle(color)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

// MARK: - InsightsTransactionRow
//
// A read-only transaction row used inside the Insights today/yesterday
// sections. Reuses the existing `EmojiLogView` for the category chip.

struct InsightsTransactionRow: View {
    let transaction: TransactionModel
    let currencyCode: String
    let showCents: Bool

    var body: some View {
        HStack(spacing: 12) {
            EmojiLogView(
                emoji: (transaction.category?.wrappedEmoji ?? ""),
                colour: (transaction.category?.wrappedColour ?? "#FFFFFF"),
                future: false
            )
            .fixedSize(horizontal: true, vertical: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.wrappedNote.isEmpty ? (transaction.category?.wrappedName ?? "") : transaction
                    .wrappedNote)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.PrimaryText)
                    .lineLimit(1)
                Text(timeLabel(transaction.wrappedDate))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.SubtitleText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(amountString)
                .font(.title3.weight(.medium))
                .foregroundStyle(transaction.income ? Color.IncomeGreen : Color.PrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 8)
    }

    private var amountString: String {
        Money.format(transaction.amount,
                     currencyCode: transaction.account?.resolvedCurrencyCode ?? currencyCode,
                     showsCents: showCents, plus: transaction.income)
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Filtered views
//
// MARK: - Preview

#Preview("Insights") {
    InsightsView()
        .environment(InsightsViewModel())
        .modelContainer(for: [
            TransactionModel.self,
            CategoryModel.self,
            BudgetModel.self,
            MainBudgetModel.self,
            TemplateTransactionModel.self
        ], inMemory: true)
}

// MARK: - Toolbar

extension InsightsView {
    var aiButton: some View {
        Button {
            if subscription.isUnlocked(.aiAnalysis) {
                showAIAnalysis = true
            } else {
                showProUpsell = true
            }
        } label: {
            Label(String.appLocalized("AI"),
                  systemImage: subscription.isUnlocked(.aiAnalysis) ? "sparkles" : "lock.fill")
        }
        .accessibilityLabel(Text(String.appLocalized("AI 账单分析")))
    }
}
