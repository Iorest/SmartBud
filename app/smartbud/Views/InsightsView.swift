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
enum InsightsPeriod: Int, CaseIterable, Identifiable {
    case week = 1
    case month = 2
    case year = 3
    case allTime = 5

    var id: Int { rawValue }

    var localizedTitle: LocalizedStringResource {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .allTime: return "All Time"
        }
    }
}

// MARK: - InsightsView

struct InsightsView: View {
    @Environment(InsightsViewModel.self) var insightsVM

    @AppStorage("currency", store: .appGroup)
    private var currency: String = Locale.current.currency?.identifier ?? "USD"

    @AppStorage("showCents", store: .appGroup)
    private var showCents: Bool = true

    @State private var period: Int = 2  // 1=week, 2=month, 3=year (matches design)

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
            .padding(.bottom, 40)
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
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Insights", comment: "Insights screen title")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Color.PrimaryText)
            Spacer()
            periodPickerChip
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }

    private var periodPickerChip: some View {
        Menu {
            Button {
                period = 1
            } label: {
                if period == 1 {
                    Label("week", systemImage: "checkmark")
                } else {
                    Text("week")
                }
            }
            Button {
                period = 2
            } label: {
                if period == 2 {
                    Label("month", systemImage: "checkmark")
                } else {
                    Text("month")
                }
            }
            Button {
                period = 3
            } label: {
                if period == 3 {
                    Label("year", systemImage: "checkmark")
                } else {
                    Text("year")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(periodTitle)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.PrimaryText)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.SubtitleText)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(Color.Outline, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .fixedSize()
    }

    // MARK: - Date range row

    /// One row: left = date range + net total; right = "AVG/DAY" or "AVG/MONTH" + amount.
    private var dateRangeRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(insightsVM.periodDateRangeText.isEmpty ? "—" : insightsVM.periodDateRangeText)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
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
                     ? String(localized: "AVG/MONTH", comment: "Insights avg per month")
                     : String(localized: "AVG/DAY", comment: "Insights avg per day"))
                    .font(.system(.callout, design: .rounded).weight(.semibold))
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
        HStack(spacing: 11) {
            InsightsSummaryBlockView(
                income: true,
                amountString: format(insightsVM.periodTotalIncome),
                showOverlay: false,
                action: {}
            )
            InsightsSummaryBlockView(
                income: false,
                amountString: format(insightsVM.periodTotalSpent),
                showOverlay: false,
                action: {}
            )
        }
        .padding(.horizontal, 30)
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
            currencySymbol: insightsVM.currencySymbol,
            showCents: insightsVM.showCents
        )
        .padding(.horizontal, 30)
    }

    // MARK: - Today / Yesterday

    private var todaySection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: String(localized: "TODAY", comment: "Insights today section header"),
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
                title: String(localized: "YESTERDAY", comment: "Insights yesterday section header"),
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
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.SubtitleText)
            Spacer()
            Text(sectionAmountString(amount))
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.PrimaryText)
                .lineLimit(1)
        }
    }

    // MARK: - Helpers

    private var periodTitle: String {
        switch period {
        case 1: return String(localized: "week", comment: "Period picker: week")
        case 3: return String(localized: "year", comment: "Period picker: year")
        default: return String(localized: "month", comment: "Period picker: month")
        }
    }

    private func format(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = showCents ? 2 : 0
        return formatter.string(from: NSNumber(value: abs(amount))) ?? "0"
    }

    private func sectionAmountString(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = showCents ? 2 : 0
        let sign = amount >= 0 ? "+" : "-"
        return "\(sign)\(formatter.string(from: NSNumber(value: abs(amount))) ?? "0")"
    }

    private func sectionAmountColor(_ amount: Double) -> Color {
        if amount > 0 { return Color.IncomeGreen }
        if amount < 0 { return Color.AlertRed }
        return Color.PrimaryText
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
        let cents = showCents && amount < 100
        if cents {
            return String(format: "%.2f", amount)
        } else {
            return String(format: "%.0f", amount)
        }
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(symbol)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Color.SubtitleText)
            Text(formattedAmount)
                .font(.system(.title, design: .rounded).weight(.medium))
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
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.PrimaryText)
                    .lineLimit(1)
                Text(timeLabel(transaction.wrappedDate))
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.SubtitleText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(amountString)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(transaction.income ? Color.IncomeGreen : Color.PrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 8)
    }

    private var amountString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencySymbol == "$" ? "USD" : currencySymbol
        formatter.maximumFractionDigits = showCents ? 2 : 0
        let base = formatter.string(from: NSNumber(value: abs(transaction.amount))) ?? "0"
        return transaction.income ? "+\(base)" : "-\(base)"
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "j:mm", options: 0, locale: .current) ?? "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Filtered views
//
// These are stub views referenced from `LogView` (e.g. `FilteredInsightsView(startDate:type:)`).
// They are intentionally minimal — LogView uses them to render small contextual graphs and the
// full Insights screen is `InsightsView` above.

struct FilteredCategoryInsightsView: View {
    let category: CategoryModel?
    let date: Date
    let type: ChartTimeFrame

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category?.wrappedName ?? "")
                .font(.system(.headline, design: .rounded))
            Text(date, format: .dateTime.day().month())
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.SubtitleText)
        }
        .padding(12)
        .glassCard(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct FilteredDateInsightsView: View {
    let date: Date
    let income: Bool

    var body: some View {
        HStack {
            Text(date, format: .dateTime.day().month().year())
            Image(systemName: income ? "arrow.up.right" : "arrow.down.right")
                .foregroundStyle(income ? Color.IncomeGreen : Color.AlertRed)
        }
        .font(.system(.subheadline, design: .rounded))
    }
}

struct FilteredInsightsView: View {
    let startDate: Date
    let type: Int

    var body: some View {
        Text(startDate, format: .dateTime.day().month().year())
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(Color.SubtitleText)
    }
}

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
