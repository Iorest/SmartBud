//
//  InsightsView.swift
//  dime
//
//  Insights / analytics screen. Backed by `InsightsViewModel` and the
//  existing `LineGraph` Canvas-based view. Renders:
//    - a time-frame picker (1 week, 1 month, 1 year, all time)
//    - a summary block (income / expenses / net / average)
//    - the net-balance line graph with drag-to-inspect
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
    @EnvironmentObject var insightsVM: InsightsViewModel

    @AppStorage("currency", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
    private var currency: String = Locale.current.currency?.identifier ?? "USD"

    @AppStorage("showCents", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
    private var showCents: Bool = true

    @State private var period: InsightsPeriod = .month

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                periodPicker
                summaryCards
                lineGraphCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.PrimaryBackground.ignoresSafeArea())
        .navigationTitle(Text("Insights", comment: "Insights screen title"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            insightsVM.setPeriod(period.rawValue)
        }
        .onChange(of: period) { _, newValue in
            insightsVM.setPeriod(newValue.rawValue)
        }
    }

    // MARK: Subviews

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(InsightsPeriod.allCases) { p in
                Text(p.localizedTitle).tag(p)
            }
        }
        .pickerStyle(.segmented)
    }

    private var summaryCards: some View {
        let s = insightsVM.summary
        return HStack(spacing: 10) {
            InsightsSummaryBlockView(
                income: false,
                amountString: format(spent: s.spent),
                showOverlay: false,
                action: {}
            )
            InsightsSummaryBlockView(
                income: true,
                amountString: format(spent: s.income),
                showOverlay: false,
                action: {}
            )
        }
    }

    private var lineGraphCard: some View {
        let s = insightsVM.summary
        let data = insightsVM.lineGraphData
        let green = s.positive

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(s.positive
                     ? String(localized: "Net total", comment: "Insights net total label")
                     : String(localized: "Net spent", comment: "Insights net spent label"))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundColor(Color.SubtitleText)

                Spacer()

                Text(format(spent: s.net))
                    .font(.system(.title2, design: .rounded).weight(.medium))
                    .foregroundColor(green ? Color.IncomeGreen : Color.AlertRed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            if data.isEmpty {
                Text("No data yet", comment: "Insights empty state")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(Color.SubtitleText)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                LineGraph(data: data, green: green, type: period.rawValue, range: 1)
                    .frame(height: 180)
            }
        }
        .padding(14)
        .background(Color.TertiaryBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Helpers

    private func format(spent amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = showCents ? 2 : 0
        return formatter.string(from: NSNumber(value: abs(amount))) ?? "$0"
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
                .foregroundColor(Color.SubtitleText)
        }
        .padding(12)
        .background(Color.TertiaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct FilteredDateInsightsView: View {
    let date: Date
    let income: Bool

    var body: some View {
        HStack {
            Text(date, format: .dateTime.day().month().year())
            Image(systemName: income ? "arrow.up.right" : "arrow.down.right")
                .foregroundColor(income ? Color.IncomeGreen : Color.AlertRed)
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
            .foregroundColor(Color.SubtitleText)
    }
}

// MARK: - Preview

#Preview("Insights") {
    InsightsView()
        .environmentObject(InsightsViewModel())
        .modelContainer(for: [
            TransactionModel.self,
            CategoryModel.self,
            BudgetModel.self,
            MainBudgetModel.self,
            TemplateTransactionModel.self
        ], inMemory: true)
}
