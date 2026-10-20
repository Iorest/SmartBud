//
//  LineGraph.swift
//  smartbud
//
//  Animated line graph for the Log tab. Migrated to Apple Swift Charts
//  (iOS 17+ uses `chartXSelection` for tap-and-drag tooltip, replacing
//  the legacy `DragGesture` plumbing). The look — coloured line over
//  Outline grey for the unfilled portion, draggable tooltip pill with
//  date + amount + dotted indicator — is preserved.
//

import Charts
import SwiftUI

struct LineGraph: View {
    var data: [LineGraphDataPoint]
    var green: Bool
    var type: Int
    var range: Int

    @State private var selectedDate: Date?
    @State private var showPlot: Bool = false

    private var currentPlot: LineGraphDataPoint? {
        guard let selectedDate else { return nil }
        // Pick the data point whose date is closest to the selected x.
        return data.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) })
    }

    private var color: Color {
        green ? Color.IncomeGreen : Color.AlertRed
    }

    private var lineColor: Color {
        guard let plot = currentPlot,
              let index = data.firstIndex(of: plot) else {
            return color
        }
        return data.count - range <= index ? color : Color.Outline
    }

    private var tooltipDate: String {
        guard let plot = currentPlot else { return "" }
        return type < 4 ? plot.dateString : plot.monthString
    }

    var body: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Amount", point.amount)
            )
            .interpolationMethod(.linear)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .foregroundStyle(lineColor)
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 100)
        .padding(.horizontal, 10)
        .overlay(alignment: .topLeading) {
            tooltip
        }
        .animation(.easeInOut(duration: 1.2), value: data)
        .onChange(of: selectedDate) { _, new in
            withAnimation(.easeInOut(duration: 0.2)) {
                showPlot = new != nil
            }
        }
    }

    @ViewBuilder
    private var tooltip: some View {
        if showPlot, let plot = currentPlot,
           let index = data.firstIndex(of: plot) {
            // Estimate x-position: equal spacing across width.
            GeometryReader { proxy in
                let count = max(data.count - 1, 1)
                let xPosition = proxy.size.width * CGFloat(index) / CGFloat(count)
                tooltipContent
                    .offset(x: max(40, min(xPosition - 40, proxy.size.width - 80)), y: 0)
                    .frame(width: 80, alignment: .center)
            }
            .allowsHitTesting(false)
        }
    }

    private var tooltipContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 1) {
                Text(tooltipDate)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.SubtitleText)
                Text(currentPlot?.amountString ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.PrimaryText)
            }
            .frame(height: 33)
            .padding(.horizontal, 7)
            .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: SBRadius.pill))
            .padding(.bottom, 4)

            Rectangle()
                .fill(lineColor)
                .frame(width: 2.5, height: 25)

            Circle()
                .stroke(Color.PrimaryBackground, lineWidth: 2.5)
                .background(Circle().fill(lineColor))
                .frame(width: 14, height: 11)
        }
        .offset(y: 6)
    }
}
