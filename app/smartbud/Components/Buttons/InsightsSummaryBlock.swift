//
//  InsightsSummaryBlock.swift
//  smartbud
//
//  Read-only income/expense tile on the Insights screen.
//

import SwiftUI

struct InsightsSummaryBlockView: View {
    let income: Bool
    let amountString: String

    private var color: Color {
        income ? Color.IncomeGreen : Color.AlertRed
    }

    private var title: String {
        String.appLocalized(income ? "Income" : "Expenses")
    }

    var body: some View {
        HStack(spacing: SBSpace.extraSmall) {
            Image(systemName: income ? "arrow.up.right" : "arrow.down.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)
                    .lineLimit(1)

                Text(amountString)
                    .font(.title3.weight(.medium).monospacedDigit())
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(SBSpace.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(amountString)")
    }
}
