import Foundation
import SwiftData
import SwiftUI

struct LogInsightsView: View {
    @Environment(InsightsViewModel.self) var insightsVM
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @Binding var navBarText: String

    let showCents: Bool
    let currencySymbol: String

    @AppStorage("logInsightsTimeFrame", store: .appGroup) var timeframe = 2
    @AppStorage("logInsightsType", store: .appGroup) var insightsType = 1

    @AppStorage("logViewLineGraph", store: .appGroup) var lineGraph: Bool = false

    private var data: InsightsViewModel.LogInsightsData {
        insightsVM.logInsightsData(timeframe: timeframe, insightsType: insightsType)
    }

    /// Spoken summary for the card: heading, amount and currency.
    private var accessibilitySummary: String {
        let amount = data.amount.formatted(
            .number.precision(.fractionLength(showCents ? 2 : 0))
        )
        return "\(data.headingText) \(amount) \(currencySymbol)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SBSpace.xxs) {
            if dynamicTypeSize.isAccessibilitySize {
                // At accessibility sizes "Net total" and the range chip each
                // need their own line; side by side they wrap mid-word.
                VStack(alignment: .leading, spacing: SBSpace.xxs) {
                    headingLabel
                    rangeButton
                }
            } else {
                HStack(spacing: SBSpace.xxs) {
                    headingLabel
                    rangeButton
                    Spacer(minLength: 0)
                }
            }

            NumberView(
                number: data.amount,
                dynamicTypeSize: _dynamicTypeSize.wrappedValue,
                netTotal: insightsType == 1,
                positive: data.netPositive,
                showCents: showCents,
                currencySymbol: currencySymbol
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)

            if data.totalSpent != 0 && data.totalIncome != 0 && insightsType == 1 {
                HStack(spacing: SBSpace.extraSmall) {
                    Text(data.formattedIncome)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.IncomeGreen)
                        .lineLimit(1)

                    Text(data.formattedSpent)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.AlertRed)
                        .lineLimit(1)
                }
            }

            if lineGraph {
                LineGraph(data: data.lineGraphData, green: data.lineGraphGreen, type: timeframe, range: data.range)
                    .frame(height: 25)
                    .padding(.top, SBSpace.xxs)
            }
        }
        .padding(.horizontal, SBSpace.medium)
        .padding(.vertical, SBSpace.small)
        .contentShape(Rectangle())
        .contextMenu {
            if insightsType != 3 {
                Button {
                    insightsType = 3
                } label: {
                    Label(String.appLocalized("Total Spent"), systemImage: "minus")
                }
            }

            if insightsType != 2 {
                Button {
                    insightsType = 2
                } label: {
                    Label(String.appLocalized("Total Income"), systemImage: "plus")
                }
            }

            if insightsType != 1 {
                Button {
                    insightsType = 1
                } label: {
                    Label(String.appLocalized("Net Total"), systemImage: "alternatingcurrent")
                }
            }
        }
    }

    private static let periodOptions = ["today", "this week", "this month", "this year", "all time"]

    private var headingLabel: some View {
        Text(data.headingText)
            .font(.subheadline)
            .foregroundStyle(Color.SubtitleText)
            .lineLimit(1)
    }

    private var rangeButton: some View {
        Menu {
            ForEach(Array(Self.periodOptions.enumerated()), id: \.offset) { index, option in
                Button {
                    timeframe = index + 1
                } label: {
                    if timeframe == index + 1 {
                        Label(String.appLocalized(option), systemImage: "checkmark")
                    } else {
                        Text(String.appLocalized(option))
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(data.rangeLabel)
                    .lineLimit(1)
                #if os(iOS)
                // macOS draws its own menu indicator; iOS does not.
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                #endif
            }
            .font(.subheadline)
            .foregroundStyle(Color.PrimaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.SecondaryBackground, in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

/// Large animated total used by the log header. Kept beside its only caller.
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
        case .xSmall: return 46
        case .small: return 47
        case .medium: return 48
        case .large: return 50
        case .xLarge: return 56
        case .xxLarge: return 58
        case .xxxLarge: return 62
        default: return 50
        }
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text(netTotal ? (positive ? "+\(currencySymbol)" : "-\(currencySymbol)") : currencySymbol)
                .font(.largeTitle)
                .foregroundStyle(Color.SubtitleText)
            Text(displayNumber, format: .number.precision(.fractionLength(showCents ? 2 : 0)))
                .font(.system(size: fontSize, weight: .regular))
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
