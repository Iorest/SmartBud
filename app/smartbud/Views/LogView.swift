//
//  LogView.swift
//  smartbud
//
//  Created by Iorest on 19/5/22.
//

import Foundation
import SwiftData
import SwiftUI

struct LogView: View {
    @Query private var transactions: [TransactionModel]

    @Environment(TransactionViewModel.self) var transactionVM
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    var topEdge: CGFloat

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    @State var addTransaction = false

    // searching
    @State var searchMode = false

    // top bar
    @State var navBarText = ""
    @State var showMenu = false
    @AppStorage("logTimeFrame", store: .appGroup) var logTimeFrame = 2

    // show filter menu
    @State var showFilter = false
    @State var filter = FilterType.all

    // filters
    @State var categoryFilter: CategoryModel?
    @State var dateFilter = Date.now
    @State var weekFilter = Date.now
    @State var monthFilter = Date.now
    @State var income = false

    // to show/hide tab bar
    var bottomEdge: CGFloat
    var launchSearch: Bool
    /// Invoked by the empty state's primary button ("Add entry").
    var onAdd: () -> Void = {}

    // drag to open
//    enum PullToReach {
//        case none, search, filter
//    }

    @State var progress = 0.0

    var body: some View {
        if transactions.isEmpty {
            VStack(spacing: 5) {
                Image("dropbox")
                    .resizable()
                    .frame(width: 75, height: 75)
                    .padding(.bottom, 20)
                    .accessibilityHidden(true)

                Text(String.appLocalized("Your Log is Empty"))
                    .font(.system(.title2, design: .rounded).weight(.medium))
//                    .font(.system(size: 23.5, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.PrimaryText.opacity(0.8))

                Text(String.appLocalized("Record your first expense or income to get started"))
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .multilineTextAlignment(.center)
                    // Full-strength secondary text: the old 0.7 opacity sat
                    // below the 4.5:1 contrast floor on the gradient.
                    .foregroundStyle(Color.SubtitleText)

                Button(action: onAdd) {
                    Text(String.appLocalized("Add Entry"))
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }
            .padding(.horizontal, 30)
            .frame(height: 250, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.clear)

        } else {
            VStack(spacing: 0) {
                VStack(spacing: 18) {
                    HStack {
                        Button {
                            searchMode = true
                        } label: {
                            Image(systemName: "magnifyingglass")
//                                .font(.system(size: 23, weight: .regular))
                                .font(.system(.title2, design: .rounded).weight(.regular))
                                
                                .foregroundStyle(Color.DarkIcon)
                                .padding(5)
                                .contentShape(Rectangle())
                                .background {
                                    RoundedRectangle(cornerRadius: GlassRadius.chip)
                                        .fill(Color.SecondaryBackground)
                                        .scaleEffect(progress == 1 ? 1.5 : 1.0)
                                        .opacity(progress)
                                }
                        }
                        .accessibilityLabel(Text(String.appLocalized("Search")))

                        Spacer()

                        switch filter {
                        case .all:
//                            Text(navBarText)
//                            .font(.system(size: 16, weight: .semibold, design: .rounded))
//                            .opacity(0)
                            EmptyView()
                        case .category:
                            filterTagView(text: "filter-tag-category")
                        case .day:
                            filterTagView(text: "filter-tag-day")
                        case .week:
                            filterTagView(text: "filter-tag-week")
                        case .month:
                            filterTagView(text: "filter-tag-month")
                        case .recurring:
                            filterTagView(text: "filter-tag-recurring")
                        case .type:
                            filterTagView(text: "filter-tag-type")
                        case .upcoming:
                            filterTagView(text: "filter-tag-upcoming")
                        }

                        Spacer()

                        Button {
                            showFilter = true
                        } label: {
                            Image(systemName: filter == .all ? "triangle" : "triangle.tophalf.filled")
                                .font(.system(.title2, design: .rounded).weight(.regular))
                                
                                .foregroundStyle(Color.DarkIcon)
                                .rotationEffect(Angle(degrees: 180))
                                .padding(5)
                                .contentShape(Rectangle())
                                .background {
                                    if showFilter {
                                        RoundedRectangle(cornerRadius: GlassRadius.chip)
                                            .fill(Color.SecondaryBackground)
                                    }
//                                    if pullStatus == .filter || showFilter {
//                                        RoundedRectangle(cornerRadius: GlassRadius.chip)
//                                            .fill(Color.SecondaryBackground)
//                                            .scaleEffect(released == .filter ? 1.2 : 1.0)
//                                            .opacity(released  == .filter ? 0.5 : 1.0)
//                                    }
                                }
                        }
                        .accessibilityLabel(Text(String.appLocalized("Filter")))
                        .popover(isPresented: $showFilter) {
                            FilterPickerView(filterType: $filter, showMenu: $showFilter)
                        }
                    }

                    switch filter {
                    case .all:
                        EmptyView()
                    case .category:
                        CategoryStepperView(categoryFilter: $categoryFilter)
                    case .day:
                        DateStepperView(date: $dateFilter)
                    case .week:
                        WeekStepperView(showingDate: $weekFilter)
                    case .month:
                        MonthStepperView(showingDate: $monthFilter)
                    case .recurring:
                        EmptyView()
                    case .type:
                        IncomeFilterToggleView(income: $income)
                    case .upcoming:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 25)
                .frame(height: (filter == .all || filter == .recurring || filter == .upcoming) ? 50 : 110, alignment: .top)
                .padding(.top, topEdge + 10)

                ScrollView(showsIndicators: false) {
                    if filter == .all {
                        LogInsightsView(navBarText: $navBarText, showCents: showCents, currencySymbol: currencySymbol)
                    }

                    TransactionsList(filter: filter, category: categoryFilter, date: dateFilter, week: weekFilter, month: monthFilter, income: income)
                        .zIndex(0)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 70 + bottomEdge)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            }
            .background(.clear)
            .fullScreenCover(isPresented: $searchMode) {
                SearchView()
            }
            .onChange(of: scenePhase) { _, new in
                if new == .active,
                   !NSUbiquitousKeyValueStore.default.bool(forKey: "icloud_sync") {
                    transactionVM.updateAllRecurring()
                }
            }
            .onChange(of: launchSearch) { _, _ in
                searchMode = true
            }
            .onAppear {
                if !NSUbiquitousKeyValueStore.default.bool(forKey: "icloud_sync") {
                    transactionVM.updateAllRecurring()
                }
            }
            .onOpenURL { url in
                guard url.host == "search" else {
                    return
                }
                searchMode = true
            }
        }
    }

    @ViewBuilder
    func filterTagView(text: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            Text(text)
                .font(.system(.body, design: .rounded).weight(.medium))
                

            Button {
                withAnimation(.easeIn(duration: 0.15)) {
                    filter = .all
                }
            } label: {
                Image(systemName: "xmark")
//                    .resizable()
//                    .frame(width: 11, height: 11)
                    .font(.system(.caption, design: .rounded).weight(.regular))
                    
                    .foregroundStyle(Color.PrimaryText.opacity(0.7))
            }
            .accessibilityLabel(Text(String.appLocalized("remove filter")))
        }
        .padding(4)
        .padding(.horizontal, 6)
        .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
//        .font(.system(size: 17, weight: .medium, design: .rounded))
        .foregroundStyle(Color.PrimaryText)
    }
}

struct NumberView: View {
    let number: Double
    let dynamicTypeSize: DynamicTypeSize
    let netTotal: Bool
    let positive: Bool
    let showCents: Bool
    let currencySymbol: String

    @State private var displayNumber: Double = 0

    var fontSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall:
            return 46
        case .small:
            return 47
        case .medium:
            return 48
        case .large:
            return 50
        case .xLarge:
            return 56
        case .xxLarge:
            return 58
        case .xxxLarge:
            return 62
        default:
            return 50
        }
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text(netTotal ? (positive ? "+\(currencySymbol)" : "-\(currencySymbol)") : currencySymbol)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(Color.SubtitleText)
            Text(displayNumber, format: .number.precision(.fractionLength(showCents ? 2 : 0)))
                .font(.system(size: fontSize, weight: .regular, design: .rounded))
                .foregroundStyle(Color.PrimaryText)
                .contentTransition(.numericText(value: displayNumber))
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .onAppear { displayNumber = number }
        .onChange(of: number) { _, newValue in
            withAnimation(.smooth(duration: 0.6)) {
                displayNumber = newValue
            }
        }
    }
}

