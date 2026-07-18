//
//  BarGraph.swift
//  dime
//
//  Bar-chart visualisation used by the redesigned Insights tab. Mirrors the
//  legacy `SingleWeekBarGraphView` design from the GitHub reference: y-axis
//  labels on the left (max / 0), 7/30/12 rounded dark bars on a tinted track,
//  dashed average line, and M/T/W/T/F/S/S or day-of-month or month-name
//  x-axis labels. Reads from the SwiftData `BarChartPoint` struct owned by
//  `InsightsViewModel`.
//

import SwiftUI

private let barHeight: CGFloat = 150

struct BarGraph: View {
    let data: [InsightsViewModel.BarChartPoint]
    let average: Double
    let income: Bool
    let period: Int  // 1=week, 2=month, 3=year

    @AppStorage("animated", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
    var animated: Bool = true

    private var getMax: Int {
        // Use the largest bar value (or average if larger) as the y-axis max.
        let maxBar = data.map(\.amount).max() ?? 0
        let candidate = max(maxBar, average)
        // Round up to a clean value so the top label looks tidy.
        return Int(candidate.rounded(.up))
    }

    private var barSpacing: CGFloat {
        switch period {
        case 1: return 7
        case 2: return 2
        default: return 4
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top, spacing: 2) {
                yAxisLabels
                bars
            }
            averageLine
        }
        .frame(maxWidth: .infinity)
    }

    private var yAxisLabels: some View {
        VStack(alignment: .leading) {
            Text(getMaxText(maxi: getMax))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(Color.SubtitleText)
            Spacer()
            Text("0")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(Color.SubtitleText)
        }
        .frame(height: barHeight)
        .padding(.trailing, 3)
    }

    private var bars: some View {
        HStack(alignment: .top, spacing: barSpacing) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                barColumn(point: point, index: index)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func barColumn(point: InsightsViewModel.BarChartPoint, index: Int) -> some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.SecondaryBackground)
                    .frame(height: barHeight)
                AnimatedBarGraph(index: index)
                    .frame(height: getBarHeight(point: point.amount, maxi: getMax))
            }
            .frame(height: barHeight)
            Text(point.label)
                .font(.system(size: period == 1 ? 12 : 10, weight: .bold, design: .rounded))
                .foregroundColor(Color.SubtitleText)
                .opacity(point.amount == 0 ? 0.3 : 1.0)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var averageLine: some View {
        if getMax > 0 && average > 0 && data.count > 1 {
            let offset = getOffset(maxi: getMax, average: average)
            let ratio = average / Double(getMax)
            if ratio > 0.05 && ratio < 0.95 {
                HStack(spacing: 2) {
                    DashedLine()
                        .stroke(
                            Color.SubtitleText,
                            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [5])
                        )
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                }
                .offset(y: offset)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Helpers

    private func getBarHeight(point: Double, maxi: Int) -> CGFloat {
        guard maxi > 0 else { return 0 }
        let ratio = CGFloat(point / Double(maxi))
        return max(0, min(barHeight, barHeight * ratio))
    }

    private func getOffset(maxi: Int, average: Double) -> CGFloat {
        guard maxi > 0 else { return 0 }
        let ratio = CGFloat(average / Double(maxi))
        return max(0, min(barHeight, barHeight * ratio))
    }

    private func getMaxText(maxi: Int) -> String {
        let value = Double(maxi)
        if value >= 1000 {
            return String(format: "%.0f", value / 1000) + "k"
        }
        return value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }
}

// MARK: - Animated bar fill

private struct AnimatedBarGraph: View {
    var index: Int

    @AppStorage("animated", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
    var animated: Bool = true

    @State private var showBar: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.DarkBackground)
                .frame(maxWidth: .infinity)
                .frame(height: showBar ? nil : 0, alignment: .bottom)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                if !animated {
                    showBar = true
                } else {
                    withAnimation(
                        .interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)
                            .delay(Double(index) * 0.1)
                    ) {
                        showBar = true
                    }
                }
            }
        }
    }
}

// MARK: - Dashed line shape

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height / 2))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        return path
    }
}
