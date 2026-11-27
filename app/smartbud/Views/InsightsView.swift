//
//  InsightsView.swift
//  smartbud
//
//  Insights / analytics screen. Backed by `InsightsViewModel` and rendered
//  with the redesigned layout that matches the GitHub reference "Good Ol'
//  Charts" design: period picker chip, a single row combining the date range
//  with the period average, income/expenses cards, `BarGraph`,
//  `CategoryBreakdownView`, `MerchantBreakdownView`, and today / yesterday
//  transaction sections.
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
    /// Opens the log on the tapped calendar day. The log owns all other
    /// filters, so this only sets the date filter.
    var onSelectDay: ((Date) -> Void)?

    @Environment(InsightsViewModel.self) var insightsVM
    @Environment(AppLockViewModel.self) private var appLockVM

    @AppStorage("currency", store: .appGroup)
    var currency: String = Locale.current.currency?.identifier ?? "USD"

    @AppStorage("showCents", store: .appGroup)
    var showCents: Bool = true

    @State private var period: Int = 2  // 1=week, 2=month, 3=year (matches design)
    @State var showAIAnalysis = false
    @State var subscription = SubscriptionManager.shared
    @State var showProUpsell = false
    @State var showPendingReimbursements = false
    @Environment(\.dynamicTypeSize) var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    dateRangeRow

                    calendarSection
                        .padding(.bottom, 18)

                    // Net worth is a balance-sheet figure, not a period
                    // total, so it stays visible even in an empty period.
                    if insightsVM.totalAssets != 0 || insightsVM.totalDebt != 0 {
                        netWorthCard
                            .padding(.horizontal, 30)
                            .padding(.bottom, 13)
                    }
                    // Claims are excluded from income and spend, so a period
                    // with nothing but claims would otherwise fall into the
                    // "no entries" state and hide the money the user is owed.
                    if insightsVM.pendingReimbursementTotal > 0 {
                        pendingReimbursementCard
                            .padding(.bottom, 13)
                    }
                    if insightsVM.budgetForecast != nil {
                        forecastCard
                            .padding(.bottom, 13)
                    }
                    // Suggestions come from the whole ledger, not this
                    // period, so they stay visible even on an empty month.
                    if !insightsVM.subscriptionSuggestions.isEmpty {
                        subscriptionSuggestionsSection
                            .padding(.horizontal, 30)
                            .padding(.bottom, 18)
                    }

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
                        // Rendered only when there is merchant data, so the
                        // section's bottom padding cannot leave a gap.
                        if !insightsVM.merchantBreakdown.isEmpty {
                            merchantBreakdownSection
                                .padding(.horizontal, 30)
                                .padding(.bottom, 18)
                        }
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
        .onChange(of: appLockVM.isAppUnLocked) { _, unlocked in
            // Sheets sit above the lock overlay; close them when the app locks.
            guard !unlocked else { return }
            showAIAnalysis = false
            showPendingReimbursements = false
            showProUpsell = false
        }
        .sheet(isPresented: $showAIAnalysis) {
            InsightsAIAnalysisView()
                .environment(insightsVM)
        }
        .sheet(isPresented: $showPendingReimbursements) {
            PendingReimbursementSheet()
                .environment(insightsVM)
        }
        .proUpsell(isPresented: $showProUpsell)
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

    private var periodSegmented: some View {
        Picker(String.appLocalized("Period"), selection: $period) {
            Text(String.appLocalized("week")).tag(1)
            Text(String.appLocalized("month")).tag(2)
            Text(String.appLocalized("year")).tag(3)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier(AccessibilityID.insightsPeriodPicker)
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

    // MARK: - Period calendar

    private var calendarSection: some View {
        Group {
            if let snapshot = insightsVM.calendarSnapshot {
                let maxSpend = snapshot.days.map { Money.double($0.spend) }.max() ?? 0
                SBCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Text(snapshot.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.SubtitleText)
                            Spacer(minLength: 4)
                            calendarMonthButton(systemImage: "chevron.left",
                                                label: String.appLocalized("Previous")) {
                                insightsVM.shiftCalendarMonth(by: -1)
                            }
                            calendarMonthButton(systemImage: "chevron.right",
                                                label: String.appLocalized("Next")) {
                                insightsVM.shiftCalendarMonth(by: 1)
                            }
                        }
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                            spacing: 2
                        ) {
                            ForEach(snapshot.weekdaySymbols, id: \.self) { symbol in
                                Text(symbol)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.SubtitleText)
                                    .frame(maxWidth: .infinity)
                                    .accessibilityHidden(true)
                            }
                            ForEach(0..<snapshot.leadingBlanks, id: \.self) { _ in
                                Color.clear.frame(height: 48)
                            }
                            ForEach(snapshot.days) { day in
                                calendarCell(day, maxSpend: maxSpend)
                            }
                        }
                        HStack(spacing: 14) {
                            calendarTotal(String.appLocalized("Expense"),
                                          value: snapshot.totalSpend,
                                          color: Color.AlertRed, plus: false)
                            calendarTotal(String.appLocalized("Income"),
                                          value: snapshot.totalIncome,
                                          color: Color.IncomeGreen, plus: true)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 30)
    }

    private func calendarMonthButton(systemImage: String, label: String,
                                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private func calendarCell(_ day: AppPeriod.DayTotals, maxSpend: Double) -> some View {
        let spend = Money.double(day.spend)
        let income = Money.double(day.income)
        let intensity = maxSpend > 0 ? min(1, max(0, spend / maxSpend)) : 0
        return Button {
            onSelectDay?(day.date)
        } label: {
            VStack(spacing: 1) {
                Text("\(gregorian.component(.day, from: day.date))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.PrimaryText)
                if income != 0 {
                    Text(Money.format(income, currencyCode: currency,
                                      showsCents: false, plus: true))
                        .font(.system(size: 8))
                        .foregroundStyle(Color.IncomeGreen)
                }
                if spend != 0 {
                    Text(Money.format(spend, currencyCode: currency,
                                      showsCents: false, plus: false))
                        .font(.system(size: 8))
                        .foregroundStyle(Color.AlertRed)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(day.hasEntries
                        ? Color.AlertRed.opacity(0.08 + 0.28 * intensity)
                        : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(calendarAccessibilityLabel(day)))
    }

    private func calendarTotal(_ title: String, value: Double,
                               color: Color, plus: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.SubtitleText)
            Text(Money.format(value, currencyCode: currency, showsCents: showCents,
                              plus: value == 0 ? nil : plus))
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var gregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale.appLocale
        return calendar
    }

    private func calendarAccessibilityLabel(_ day: AppPeriod.DayTotals) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.appLocale
        formatter.calendar = gregorian
        formatter.dateStyle = .medium
        let spend = Money.format(Money.double(day.spend), currencyCode: currency,
                                 showsCents: showCents, plus: day.spend == 0 ? nil : false)
        let income = Money.format(Money.double(day.income), currencyCode: currency,
                                  showsCents: showCents, plus: day.income == 0 ? nil : true)
        return "\(formatter.string(from: day.date)), "
            + "\(String.appLocalized("Expense")) \(spend), "
            + "\(String.appLocalized("Income")) \(income)"
    }

    private var netWorthCard: some View {
        SBCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(String.appLocalized("Net Worth"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)
                Text(format(insightsVM.netWorth))
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(insightsVM.netWorth < 0 ? Color.AlertRed : Color.PrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: SBSpace.medium) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String.appLocalized("Total Assets"))
                        Text(format(insightsVM.totalAssets)).monospacedDigit()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String.appLocalized("Total Debt"))
                        Text(format(insightsVM.totalDebt)).monospacedDigit()
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.SubtitleText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.insightsNetWorthCard)
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
            // Bars are spend, so the reference line has to be spend per day
            // too. `periodAverage` is the net average shown above.
            average: insightsVM.periodAverageSpend,
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

    // MARK: - Merchant breakdown

    private var merchantBreakdownSection: some View {
        MerchantBreakdownView(
            merchants: insightsVM.merchantBreakdown,
            currencyCode: currency,
            showCents: insightsVM.showCents
        )
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


    // MARK: - Forecast and subscription suggestions

    private var forecastCard: some View {
        Group {
            if let forecast = insightsVM.budgetForecast {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: SBSpace.extraSmall) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(forecast.overspend > 0 ? Color.AlertRed : Color.IncomeGreen)
                            .accessibilityHidden(true)
                        Text(String.appLocalized("Period-end forecast"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)
                        Spacer()
                        Text("\(forecast.elapsedDays)/\(forecast.totalDays)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.SubtitleText)
                    }
                    Text(forecast.overspend > 0
                         ? String.appFormatted("At this pace you will overspend by %@",
                                               format(forecast.overspend))
                         : String.appLocalized("On track for this period"))
                        .font(.headline)
                        .foregroundStyle(Color.PrimaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    if forecast.excludedOutlierCount > 0 {
                        Text(String.appFormatted("%lld one-off entries excluded",
                                                 forecast.excludedOutlierCount))
                            .font(.caption)
                            .foregroundStyle(Color.SubtitleText)
                    }
                }
                .padding(SBSpace.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 30)
    }

    private var subscriptionSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: SBSpace.extraSmall) {
            Text(String.appLocalized("Recurring payment detected"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.SubtitleText)

            ForEach(insightsVM.subscriptionSuggestions) { suggestion in
                HStack(spacing: SBSpace.extraSmall) {
                    Image(systemName: "repeat.circle.fill")
                        .foregroundStyle(Color.orange)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.merchantName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.PrimaryText)
                            .lineLimit(1)
                        Text("\(format(suggestion.amount)) · \(cadenceLabel(suggestion.cadence))")
                            .font(.caption)
                            .foregroundStyle(Color.SubtitleText)
                    }
                    Spacer(minLength: SBSpace.extraSmall)
                    Button {
                        insightsVM.adoptSubscription(suggestion)
                    } label: {
                        Text(String.appLocalized("Make recurring"))
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(Text(String.appLocalized("Create a repeating entry for this merchant")))
                }
                .padding(SBSpace.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
            }
        }
    }

    private func cadenceLabel(_ cadence: SubscriptionCadence) -> String {
        switch cadence {
        case .monthly: return String.appLocalized("Monthly")
        case .quarterly: return String.appLocalized("Quarterly")
        case .yearly: return String.appLocalized("Yearly")
        }
    }
}

// MARK: - InsightsDollarView
//
// A composite "+$" + value pair used by the date-range header. `net` forces
// a leading sign; `color` tints the value portion.
