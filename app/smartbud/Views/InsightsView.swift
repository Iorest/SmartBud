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

// MARK: - InsightsView

struct InsightsView: View {
    /// Opens the new-transaction sheet; the empty state offers it as a CTA.
    var onAdd: (() -> Void)?

    @Environment(InsightsViewModel.self) var insightsVM

    @AppStorage("currency", store: .appGroup)
    private var currency: String = Locale.current.currency?.identifier ?? "USD"

    @AppStorage("showCents", store: .appGroup)
    private var showCents: Bool = true

    @State private var period: Int = 2  // 1=week, 2=month, 3=year (matches design)
    @State private var showAIAnalysis = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    dateRangeRow

                    if insightsVM.periodTotalIncome == 0 && insightsVM.periodTotalSpent == 0 {
                        // Nothing to chart this period: one explicit empty
                        // state beats four cards reading 0.00 plus a blank graph.
                        SBEmptyState(
                            systemImage: "chart.bar.xaxis",
                            title: String.appLocalized("No entries in this period"),
                            message: String.appLocalized(
                                "Transactions you add will show up here as trends and category shares."),
                            actionTitle: String.appLocalized("Add New Transaction"),
                            action: onAdd
                        )
                        .padding(.top, 24)
                    } else {
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
                }
                // Clear the floating add button and the tab bar.
                .padding(.bottom, 130)
            }
            .background(Color.clear.ignoresSafeArea())
            .navigationTitle(String.appLocalized("Insights"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    aiButton
                }
            }
        }
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

    /// The period control is the page's only header content now: the title
    /// lives in the navigation bar and the AI action in the toolbar.
    private var header: some View {
        periodSegmented
            .padding(.horizontal, 30)
            .padding(.top, SBSpace.extraSmall)
            .padding(.bottom, SBSpace.medium)
    }

    private var aiButton: some View {
        Button {
            showAIAnalysis = true
        } label: {
            Label(String.appLocalized("AI"), systemImage: "sparkles")
        }
        .accessibilityLabel(Text(String.appLocalized("AI 账单分析")))
    }

    private var periodSegmented: some View {
        Picker(String.appLocalized("Period"), selection: $period) {
            Text(String.appLocalized("week")).tag(1)
            Text(String.appLocalized("month")).tag(2)
            Text(String.appLocalized("year")).tag(3)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
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
                        currencyCode: currency,
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
                        currencyCode: currency,
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
