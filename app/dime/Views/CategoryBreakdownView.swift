//
//  CategoryBreakdownView.swift
//  dime
//
//  Horizontal stacked-bar breakdown of expenses by category plus a legend
//  list. Used on the redesigned Insights tab. Drives off the SwiftData
//  `PowerCategory` struct produced by `InsightsViewModel.getCategoryBreakdown`.
//

import SwiftUI

struct CategoryBreakdownView: View {
    let categories: [PowerCategory]
    let currencySymbol: String
    let showCents: Bool

    /// Stable 6-color palette: red, magenta, blue, orange, green, purple. Mirrors the
    /// GitHub legacy design's color order for the most common breakdown buckets.
    private let palette: [Color] = [
        Color(red: 0.92, green: 0.26, blue: 0.39),
        Color(red: 0.85, green: 0.20, blue: 0.65),
        Color(red: 0.25, green: 0.55, blue: 0.95),
        Color(red: 0.95, green: 0.55, blue: 0.20),
        Color(red: 0.30, green: 0.75, blue: 0.45),
        Color(red: 0.55, green: 0.35, blue: 0.85)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !categories.isEmpty {
                Text("Categories", comment: "Insights category breakdown heading")
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundColor(Color.SubtitleText)

                stackedBar

                VStack(spacing: 10) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        legendRow(category: category, index: index)
                    }
                }
            }
        }
    }

    private var stackedBar: some View {
        GeometryReader { proxy in
            let totalSpacing = proxy.size.width * 0.015 * Double(max(0, categories.count - 1))
            let usableWidth = max(0, proxy.size.width - totalSpacing)
            HStack(spacing: proxy.size.width * 0.015) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    if category.percent >= 0.005 {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(colorForCategory(category, index: index))
                            .frame(width: max(8, usableWidth * category.percent))
                    }
                }
            }
        }
        .frame(height: 17)
    }

    private func legendRow(category: PowerCategory, index: Int) -> some View {
        let color = colorForCategory(category, index: index)
        return HStack(spacing: 10) {
            Text(category.category.fullName)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(Color.PrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            Text(formattedAmount(category.amount))
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundColor(Color.SubtitleText)
                .lineLimit(1)

            Text("\(Int((category.percent * 100).rounded()))%")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundColor(color)
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(color.opacity(0.23), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    private func colorForCategory(_ category: PowerCategory, index: Int) -> Color {
        // GitHub reference: income categories use the shared `colorArray` palette
        // by index, expense categories use the category's custom colour.
        if category.category.income {
            let hex = Color.colorArray[index % Color.colorArray.count]
            return Color(hex: hex)
        }
        let hex = category.category.colour
        if !hex.isEmpty {
            return Color(hex: hex)
        }
        return palette[index % palette.count]
    }

    private func formattedAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = showCents ? 2 : 0
        formatter.currencySymbol = currencySymbol
        return formatter.string(from: NSNumber(value: abs(amount))) ?? "0"
    }
}
