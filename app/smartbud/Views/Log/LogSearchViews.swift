import Foundation
import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) var dismiss

    @State var searchQuery = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 9) {
                HStack {
                    Image(systemName: "magnifyingglass")
//                        .font(.system(size: 17))
                        .font(.system(.body, design: .rounded).weight(.regular))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(Color.DarkIcon.opacity(0.8))
                        .accessibilityHidden(true)
                    TextField(String.appLocalized("Search entry by note"), text: $searchQuery)
                        .focused($searchFocused)
                        .font(.system(.body, design: .rounded).weight(.regular))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.PrimaryText)

                    if searchQuery != "" {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(.subheadline, design: .rounded).weight(.regular))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                .font(.system(size: 15))
                                .foregroundStyle(Color.SubtitleText)
                                .background(Color.SecondaryBackground)
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.chip))

                Button {
                    dismiss()
                } label: {
                    Text(String.appLocalized("Cancel"))
                        .foregroundStyle(Color.PrimaryText)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                        .font(.system(size: 18, weight: .medium, design: .rounded))
                }
            }
            
            ScrollView {
                if searchQuery == "" {
                    EmptyView()
                } else {
                    FilteredSearchView(searchQuery: searchQuery)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(15)
        .background(Color.PrimaryBackground)
        .onAppear {
            searchFocused = true
        }
    }
}

struct FilteredSearchView: View {
    @Query private var transactions: [TransactionModel]

    var searchQuery: String

    var body: some View {
        VStack {
            if searchQuery != "" && transactions.count == 0 {
                VStack(spacing: 2) {
                    Text(String.appLocalized("📭️"))
                        .font(.system(size: 50))
                        .padding(.bottom, 15)
                    Text(String.appLocalized("No entries found."))
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.PrimaryText)
                    Text(String.appLocalized("Try a different search query!"))
                        .font(.system(.subheadline, design: .rounded).weight(.regular))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.SubtitleText)
                }
                .frame(alignment: .center)
                .opacity(0.8)
                .padding(.top, 80)
            }

            ListView(transactions: transactions)
        }
        .frame(maxHeight: .infinity)
    }

    init(searchQuery: String) {
        self.searchQuery = searchQuery
        let q = searchQuery
        // allow searching by amount too
        if let amountValue = Double(searchQuery) {
            _transactions = Query(filter: #Predicate<TransactionModel> {
                ($0.note ?? "").localizedStandardContains(q) ||
                    $0.amount == amountValue
            }, sort: [
                SortDescriptor(\TransactionModel.day, order: .reverse),
                SortDescriptor(\TransactionModel.date, order: .reverse)
            ])
        } else {
            _transactions = Query(filter: #Predicate<TransactionModel> {
                ($0.note ?? "").localizedStandardContains(q)
            }, sort: [
                SortDescriptor(\TransactionModel.day, order: .reverse),
                SortDescriptor(\TransactionModel.date, order: .reverse)
            ])
        }
    }
}

struct TimePickerView: View {
    @Namespace var animation

    let timeframes = ["today", "this week", "this month", "this year", "all time"]

    @Binding var showMenu: Bool
    @Binding var timeframe: Int
    @State var holdingTimeframe = 0

    @AppStorage("colourScheme", store: .appGroup) var colourScheme: Int = 0

    @Environment(\.colorScheme) var systemColorScheme

    var darkMode: Bool {
        (colourScheme == 0 && systemColorScheme == .dark) || colourScheme == 2
    }

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(timeframes.indices, id: \.self) { index in
                Button {
                    if holdingTimeframe == index + 1 {
                        showMenu = false
                    } else {
                        withAnimation(.easeIn(duration: 0.15)) {
                            holdingTimeframe = index + 1
                        }

                        timeframe = index + 1

                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(400))
                            showMenu = false
                        }
                    }
                } label: {
                    HStack {
                        Text(LocalizedStringKey(timeframes[index]))
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)

                        Spacer()

                        if holdingTimeframe == index + 1 {
                            Image(systemName: "checkmark")
                                .font(.system(.footnote, design: .rounded).weight(.medium))
                                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
//                            .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
//                .font(.system(size: 18, weight: .medium, design: .rounded))
                    .padding(5)
                    .background {
                        if holdingTimeframe == index + 1 {
                            RoundedRectangle(cornerRadius: GlassRadius.pill)
                                .fill(darkMode ? Color("AlwaysDarkSecondaryBackground") : Color("AlwaysLightSecondaryBackground"))
                                .matchedGeometryEffect(id: "TAB", in: animation)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
            }
        }
        .foregroundStyle(darkMode ? Color("AlwaysLightBackground") : Color("AlwaysDarkBackground"))
        .padding(4)
        .frame(width: dynamicTypeSize > .xxLarge ? 185 : 160)
        .background(RoundedRectangle(cornerRadius: GlassRadius.chip).fill(darkMode ? Color("AlwaysDarkBackground") : Color("AlwaysLightBackground")).shadow(color: darkMode ? Color.clear : Color.gray.opacity(0.25), radius: 6))
        .overlay(RoundedRectangle(cornerRadius: GlassRadius.chip).stroke(darkMode ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
        .onAppear {
            holdingTimeframe = timeframe
        }
    }
}

struct FilterPickerView: View {
    @Namespace var animation
    @Namespace var animation1
    @Binding var filterType: FilterType
    @Binding var showMenu: Bool

    @AppStorage("colourScheme", store: .appGroup) var colourScheme: Int = 0

    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var darkMode: Bool {
        (colourScheme == 0 && systemColorScheme == .dark) || colourScheme == 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(FilterType.allCases, id: \.self) { filter in
                Button {
                    if filterType == filter {
                        showMenu = false
                    } else {
                        withAnimation(.easeIn(duration: 0.15)) {
                            filterType = filter
                        }

                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            showMenu = false
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: FilterType.imageDictionary[filter] ?? "")
//                        .font(.system(size: 16))
                            .font(.system(.callout, design: .rounded).weight(.regular))
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                            .frame(width: 20)
                        Text(LocalizedStringKey(filter.rawValue))
//                        .font(.system(size: 18, weight: .medium, design: .rounded))
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                            .lineLimit(1)
                        Spacer()

                        if filterType == filter {
                            Image(systemName: "checkmark")
                                .font(.system(.footnote, design: .rounded).weight(.medium))
                                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
//                            .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(5)
                    .background {
                        if filterType == filter {
                            RoundedRectangle(cornerRadius: GlassRadius.pill)
                                .fill(darkMode ? Color("AlwaysDarkSecondaryBackground") : Color("AlwaysLightSecondaryBackground"))
                                .matchedGeometryEffect(id: "TAB", in: animation)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
            }
        }
        .foregroundStyle(darkMode ? Color("AlwaysLightBackground") : Color("AlwaysDarkBackground"))
        .padding(4)
        .frame(width: dynamicTypeSize > .xLarge ? 220 : 190)
        .background(RoundedRectangle(cornerRadius: GlassRadius.chip).fill(darkMode ? Color("AlwaysDarkBackground") : Color("AlwaysLightBackground")).shadow(color: darkMode ? Color.clear : Color.gray.opacity(0.25), radius: 6))
        .overlay(RoundedRectangle(cornerRadius: GlassRadius.chip).stroke(darkMode ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
    }
}

