import Foundation
import SwiftData
import SwiftUI

struct LogInsightsView: View {
    @Environment(InsightsViewModel.self) var insightsVM
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @Binding var navBarText: String

    let showCents: Bool
    let currencySymbol: String

    @State var showMenu1 = false

    @AppStorage("logInsightsTimeFrame", store: .appGroup) var timeframe = 2
    @AppStorage("logInsightsType", store: .appGroup) var insightsType = 1

    @AppStorage("logViewLineGraph", store: .appGroup) var lineGraph: Bool = false

    private var data: InsightsViewModel.LogInsightsData {
        insightsVM.logInsightsData(timeframe: timeframe, insightsType: insightsType)
    }

    var body: some View {
        VStack(spacing: -3) {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(data.headingText)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.PrimaryText.opacity(0.9))
                    Button {
                        showMenu1 = true
                    } label: {
                        Text(data.rangeLabel)
                            .padding(2)
                            .padding(.horizontal, 6)
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(Color.PrimaryText.opacity(9))
                            .overlay(Capsule().stroke(Color.Outline, lineWidth: 1.3))
                    }
                    .popover(isPresented: $showMenu1) {
                        TimePickerView(showMenu: $showMenu1, timeframe: $timeframe)
                    }
                }

                NumberView(number: data.amount, dynamicTypeSize: _dynamicTypeSize.wrappedValue, netTotal: insightsType == 1, positive: data.netPositive, showCents: showCents, currencySymbol: currencySymbol)
            }
            .padding(7)
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

            if data.totalSpent != 0 && data.totalIncome != 0 && insightsType == 1 {
                HStack {
                    Text(data.formattedIncome)
                        .font(.system(.title2, design: .rounded).weight(.medium))
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Color.IncomeGreen)
                        .lineLimit(1)

                    DottedLine()
                        .stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                        .frame(width: 1.7, height: 15)
                        .foregroundStyle(Color.Outline)

                    Text(data.formattedSpent)
                        .font(.system(.title2, design: .rounded).weight(.medium))
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Color.AlertRed)
                        .lineLimit(1)
                }
                .padding(.bottom, 13)
            }

            if lineGraph {
                LineGraph(data: data.lineGraphData, green: data.lineGraphGreen, type: timeframe, range: data.range)
                    .frame(height: 25)
                    .padding(.horizontal, 60)
                    .padding(.top, 16)
            }
        }
        .padding([.bottom, .horizontal], 20)
        
        .frame(height: lineGraph ? 240 : 170)
    }
}

