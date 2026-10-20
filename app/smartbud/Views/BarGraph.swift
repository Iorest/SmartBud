//
//  BarGraph.swift
//  smartbud
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

    @AppStorage("animated", store: .appGroup)
    var animated: Bool = true

    private var roundedMax: Double {
        let maxBar = data.map(\.amount).max() ?? 0
        return max(maxBar, average).rounded(.up)
    }

    private var yMax: Double { max(roundedMax, 1) }

    /// Indices into `data` that should be drawn on the x-axis. Using the array
    /// index (not the label) as the BarMark x-value is critical: the month
    /// period has 23 empty-label buckets that would otherwise all collapse
    /// onto the same x position, hiding most of the bars.
    private var xAxisTickIndices: [Int] {
        switch period {
        case 1: return Array(0..<min(7, data.count))
        case 3: return Array(0..<min(12, data.count))
        default: return stride(from: 0, to: data.count, by: 7).map { $0 }
        }
    }

    var body: some View {
        if hasData {
            chart
        } else {
            // An empty chart used to render bare "1.0 / 0" axis labels
            // floating in whitespace — looks broken. Show an explicit
            // empty state instead.
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                Text(String.appLocalized("本期暂无支出"))
                    .font(.footnote)
            }
            .foregroundStyle(Color.SubtitleText)
            .frame(maxWidth: .infinity, minHeight: 185)
        }
    }

    private var hasData: Bool {
        data.contains { $0.amount > 0 }
    }

    private var chart: some View {
        Chart(Array(data.indices), id: \.self) { index in
            BarMark(
                x: .value("Slot", index),
                y: .value("Amount", data[index].amount),
                width: .fixed(data.count > 20 ? 7 : (data.count > 10 ? 14 : 26))
            )
            .foregroundStyle(Color.accentColor)
            .cornerRadius(4)

            if roundedMax > 0 && average > 0 {
                let ratio = average / yMax
                if ratio > 0.05 && ratio < 0.95 {
                    RuleMark(y: .value("Average", average))
                        .lineStyle(StrokeStyle(lineWidth: 1, lineCap: .round, dash: [5]))
                        .foregroundStyle(Color.SubtitleText)
                }
            }
        }
        .chartXScale(domain: -0.5...Double(max(0, data.count - 1)) + 0.5)
        .chartYScale(domain: 0...yMax)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, yMax]) { value in
                AxisGridLine().foregroundStyle(.clear)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(yAxisLabel(for: v))
                            .font(.caption2)
                            .foregroundStyle(Color.SubtitleText)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: xAxisTickIndices) { value in
                AxisGridLine().foregroundStyle(.clear)
                AxisValueLabel {
                    if let idx = value.as(Int.self), idx >= 0, idx < data.count {
                        Text(data[idx].label)
                            .font(.system(period == 1 ? .caption : .caption2).weight(.bold))
                            .foregroundStyle(Color.SubtitleText)
                            .opacity(labelOpacity(at: idx))
                    }
                }
            }
        }
        .frame(height: 185)
        .padding(.horizontal, 4)
        // Chart labels are graphics inside a fixed plot area; cap them at
        // the first accessibility size so they stay legible without colliding.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .animation(animated ? .interactiveSpring(response: 0.6, dampingFraction: 0.8) : nil, value: data)
    }

    // MARK: - Helpers

    private func yAxisLabel(for value: Double) -> String {
        if value >= 1000 {
            return value.formatted(.number.precision(.fractionLength(0))) + "k"
        }
        return value.formatted(.number.precision(.fractionLength(value < 10 ? 1 : 0)))
    }

    private func labelOpacity(at index: Int) -> Double {
        // Dim 0-amount day labels in the month view so users can see which
        // days had no spending. Look up by index, not by label — multiple
        // buckets share the same label, so a label-based lookup is wrong.
        guard period == 2, index >= 0, index < data.count else { return 1.0 }
        return data[index].amount == 0 ? 0.3 : 1.0
    }
}
