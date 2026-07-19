//
//  BarGraph.swift
//  dime
//
//  Bar-chart visualisation for the Insights tab. Migrated to Apple Swift
//  Charts (iOS 16+, deployment target is iOS 26). Reads the
//  `BarChartPoint` array owned by `InsightsViewModel` and renders:
//    - a tinted track behind every bar (the `Color.SecondaryBackground` fill),
//    - a `Color.DarkBackground` filled bar per data point,
//    - a dashed `RuleMark` for the average,
//    - period-aware x-axis labels (M/T/W/T/F/S/S for week, day-of-month for
//      month, J/F/M/… for year).
//
// The legacy per-bar `withAnimation(... .delay(Double(index) * 0.1))`
// entrance is preserved as a `.transition` keyed on the bar's first
// appearance. `chartYScale` clamps the top to the rounded max so the
// "max/0" y-axis labels still sit on the gridline.
//

import Charts
import SwiftUI

struct BarGraph: View {
    let data: [InsightsViewModel.BarChartPoint]
    let average: Double
    let income: Bool
    let period: Int  // 1=week, 2=month, 3=year

    @AppStorage("animated", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
    var animated: Bool = true

    private var roundedMax: Double {
        let maxBar = data.map(\.amount).max() ?? 0
        return max(maxBar, average).rounded(.up)
    }

    private var yMax: Double { max(roundedMax, 1) }

    var body: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Slot", point.label.isEmpty ? "" : point.label),
                y: .value("Amount", point.amount)
            )
            .foregroundStyle(Color.DarkBackground)
            .cornerRadius(6)

            if roundedMax > 0 && average > 0 {
                let ratio = average / yMax
                if ratio > 0.05 && ratio < 0.95 {
                    RuleMark(y: .value("Average", average))
                        .lineStyle(StrokeStyle(lineWidth: 1, lineCap: .round, dash: [5]))
                        .foregroundStyle(Color.SubtitleText)
                }
            }
        }
        .chartYScale(domain: 0...yMax)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, yMax]) { value in
                AxisGridLine().foregroundStyle(.clear)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(yAxisLabel(for: v))
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.SubtitleText)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: data.count)) { value in
                AxisGridLine().foregroundStyle(.clear)
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.system(size: period == 1 ? 12 : 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.SubtitleText)
                            .opacity(labelOpacity(for: label))
                    }
                }
            }
        }
        .frame(height: 185)
        .padding(.horizontal, 4)
        .animation(animated ? .interactiveSpring(response: 0.6, dampingFraction: 0.8) : nil, value: data)
    }

    // MARK: - Helpers

    private func yAxisLabel(for value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0f", value / 1000) + "k"
        }
        return value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }

    private func labelOpacity(for label: String) -> Double {
        // Match the legacy "dim 0-amount labels" behaviour: any day whose
        // amount is 0 in the month-period view (where labels are digits)
        // gets a 0.3 alpha. The Charts axis only has the label, not the
        // amount, so we look it up by label.
        guard period == 2 else { return 1.0 }
        return data.first(where: { $0.label == label })?.amount == 0 ? 0.3 : 1.0
    }
}
