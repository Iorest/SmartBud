//
//  InsightsView.swift
//  smartbud
//
//  Insights / analytics screen. Backed by `InsightsViewModel` and rendered
//  with the redesigned layout that matches the GitHub reference "Good Ol'
//  Charts" design: period picker chip, a single row combining the date range
//  with the period average, income/expenses cards, `BarGraph`,
//  `CategoryBreakdownView`, and today / yesterday transaction sections.
//  The legacy `Filtered*InsightsView` stubs are kept at the bottom because
//  `LogView` still references them.
//

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Periods

/// Time window for the Insights summary + graph. Matches the integer codes
/// already used by `InsightsViewModel.selectedPeriod` so App Intents can reuse them.
// MARK: - InsightsView

struct InsightsView: View {
    @Environment(InsightsViewModel.self) var insightsVM

    @AppStorage("currency", store: .appGroup)
    private var currency: String = Locale.current.currency?.identifier ?? "USD"

    @AppStorage("showCents", store: .appGroup)
    private var showCents: Bool = true

    @State private var period: Int = 2  // 1=week, 2=month, 3=year (matches design)
    @State private var showAIAnalysis = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                dateRangeRow
                summaryCards
                    .padding(.bottom, 13)
                barChartSection
                    .padding(.bottom, 18)
                categoryBreakdownSection
                    .padding(.bottom, 18)
                if !insightsVM.todayTransactions.isEmpty {
                    todaySection
                }
                if !insightsVM.yesterdayTransactions.isEmpty {
                    yesterdaySection
                }
            }
            // Clear the floating add button and the tab bar.
            .padding(.bottom, 130)
        }
        .background(Color.clear.ignoresSafeArea())
        .onAppear {
            insightsVM.setPeriod(period)
            insightsVM.refreshAll()
        }
        .onChange(of: period) { _, newValue in
            insightsVM.setPeriod(newValue)
            insightsVM.refreshAll()
        }
        .sheet(isPresented: $showAIAnalysis) {
            InsightsAIAnalysisView()
                .environment(insightsVM)
        }
    }

    // MARK: - Header

    private var header: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // Title + AI on one row, period control full width below.
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center) {
                        titleText
                        Spacer(minLength: 8)
                        aiButton
                    }
                    periodSegmented
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(alignment: .center) {
                    titleText
                    Spacer()
                    aiButton
                    periodSegmented
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }

    private var titleText: some View {
        Text("Insights", comment: "Insights screen title")
            .font(.title.bold())
            .foregroundStyle(Color.PrimaryText)
    }

    private var aiButton: some View {
        Button {
            showAIAnalysis = true
        } label: {
            Label(String.appLocalized("AI"), systemImage: "sparkles")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, SBSpace.xs)
                .frame(minHeight: 34)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(String.appLocalized("AI 账单分析")))
    }

    private var periodSegmented: some View {
        Picker("Period", selection: $period) {
            Text(String.appLocalized("week")).tag(1)
            Text(String.appLocalized("month")).tag(2)
            Text(String.appLocalized("year")).tag(3)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 240)
    }

    // MARK: - Date range row

    /// One row: left = date range + net total; right = "AVG/DAY" or "AVG/MONTH" + amount.
    private var dateRangeRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(insightsVM.periodDateRangeText.isEmpty ? "—" : insightsVM.periodDateRangeText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)

                InsightsDollarView(
                    amount: insightsVM.periodTotalNet,
                    currencySymbol: insightsVM.currencySymbol,
                    showCents: insightsVM.showCents,
                    net: insightsVM.periodNetPositive,
                    color: insightsVM.periodNetPositive ? Color.IncomeGreen : Color.AlertRed
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(period == 3
                     ? String.appLocalized("AVG/MONTH", comment: "Insights avg per month")
                     : String.appLocalized("AVG/DAY", comment: "Insights avg per day"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)

                InsightsDollarView(
                    amount: insightsVM.periodAverage,
                    currencySymbol: insightsVM.currencySymbol,
                    showCents: insightsVM.showCents,
                    net: nil,
                    color: Color.PrimaryText
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 18)
    }

    // MARK: - Summary cards

    private var summaryCards: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // Two cards side by side cannot fit large text; stack them.
                VStack(spacing: 11) {
                    incomeCard
                    expenseCard
                }
            } else {
                HStack(spacing: 11) {
                    incomeCard
                    expenseCard
                }
            }
        }
        .padding(.horizontal, 30)
    }

    private var incomeCard: some View {
        InsightsSummaryBlockView(
            income: true,
            amountString: format(insightsVM.periodTotalIncome)
        )
    }

    private var expenseCard: some View {
        InsightsSummaryBlockView(
            income: false,
            amountString: format(insightsVM.periodTotalSpent)
        )
    }

    // MARK: - Bar chart

    private var barChartSection: some View {
        BarGraph(
            data: insightsVM.barChartData,
            average: insightsVM.periodAverage,
            income: false,
            period: period
        )
        .frame(height: 200)
        .padding(.horizontal, 30)
    }

    // MARK: - Category breakdown

    private var categoryBreakdownSection: some View {
        CategoryBreakdownView(
            categories: insightsVM.categoryBreakdown,
            currencyCode: currency,
            showCents: insightsVM.showCents
        )
        .padding(.horizontal, 30)
    }

    // MARK: - Today / Yesterday

    private var todaySection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: String.appLocalized("TODAY", comment: "Insights today section header"),
                amount: insightsVM.todayTotal
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(insightsVM.todayTransactions, id: \.id) { transaction in
                    InsightsTransactionRow(
                        transaction: transaction,
                        currencySymbol: insightsVM.currencySymbol,
                        showCents: insightsVM.showCents
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var yesterdaySection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: String.appLocalized("YESTERDAY", comment: "Insights yesterday section header"),
                amount: insightsVM.yesterdayTotal
            )
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(insightsVM.yesterdayTransactions, id: \.id) { transaction in
                    InsightsTransactionRow(
                        transaction: transaction,
                        currencySymbol: insightsVM.currencySymbol,
                        showCents: insightsVM.showCents
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func sectionHeader(title: String, amount: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.SubtitleText)
            Spacer()
            Text(sectionAmountString(amount))
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.PrimaryText)
                .lineLimit(1)
        }
    }

    // MARK: - Helpers

    private func format(_ amount: Double) -> String {
        Money.format(amount, currencyCode: currency, showsCents: showCents)
    }

    private func sectionAmountString(_ amount: Double) -> String {
        let sign = amount >= 0 ? "+" : "-"
        return "\(sign)\(format(amount))"
    }

}

// MARK: - InsightsDollarView
//
// A composite "+$" + value pair used by the date-range header. `net` forces
// a leading sign; `color` tints the value portion.

private struct InsightsDollarView: View {
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

private struct InsightsTransactionRow: View {
    let transaction: TransactionModel
    let currencySymbol: String
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
                Text(transaction.wrappedNote.isEmpty ? (transaction.category?.wrappedName ?? "") : transaction.wrappedNote)
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
        let base = abs(transaction.amount).formatted(
            .currency(code: currencySymbol == "$" ? "USD" : currencySymbol)
                .precision(.fractionLength(showCents ? 2 : 0))
        )
        return transaction.income ? "+\(base)" : "-\(base)"
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
