//
//  MerchantBreakdownView.swift
//  smartbud
//
//  Spend by merchant for the selected period, largest first. Sits below
//  `CategoryBreakdownView` on the Insights tab and drives off the
//  `MerchantSlice` list produced by `MerchantSummary.breakdown`.
//

import SwiftUI

struct MerchantBreakdownView: View {
    let merchants: [MerchantSlice]
    let currencyCode: String
    let showCents: Bool

    @Environment(\.dynamicTypeSize) private var typeSize

    private let rankWidth: CGFloat = 14

    var body: some View {
        // Same contract as `CategoryBreakdownView`: no data, no section, so the
        // caller's spacing does not leave a gap.
        if !merchants.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(String.appLocalized("Merchants", comment: "Insights merchant breakdown heading"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)

                VStack(spacing: 10) {
                    ForEach(Array(merchants.enumerated()), id: \.element.id) { index, merchant in
                        row(merchant, rank: index + 1)
                    }
                }
            }
        }
    }

    private func row(_ merchant: MerchantSlice, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if typeSize.isAccessibilitySize {
                // Four columns cannot hold scaled-up text; the amount and share
                // move under the name instead of being squeezed.
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        rankLabel(rank)
                        nameLabel(merchant)
                    }
                    HStack(spacing: 8) {
                        amountLabel(merchant)
                        percentChip(merchant)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    rankLabel(rank)
                    nameLabel(merchant)
                    amountLabel(merchant)
                    percentChip(merchant)
                }
            }

            shareBar(merchant)
        }
    }

    private func rankLabel(_ rank: Int) -> some View {
        Text("\(rank)")
            .font(.footnote.monospacedDigit())
            .foregroundStyle(Color.SubtitleText)
            .frame(width: rankWidth, alignment: .leading)
    }

    private func nameLabel(_ merchant: MerchantSlice) -> some View {
        // Shop names run to 40 characters; one line that may shrink keeps the
        // amount and share on the same row on every device width.
        Text(merchant.name)
            .font(.body.weight(.medium))
            .foregroundStyle(Color.PrimaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func amountLabel(_ merchant: MerchantSlice) -> some View {
        Text(Money.format(merchant.amount, currencyCode: currencyCode, showsCents: showCents))
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(Color.SubtitleText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func percentChip(_ merchant: MerchantSlice) -> some View {
        // Monochrome: merchants carry no stored colour, and inventing one per
        // rank would read as a second category palette.
        Text("\(Int((merchant.percent * 100).rounded()))%")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.PrimaryText)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                Color.PrimaryText.opacity(0.07),
                in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
            )
    }

    private func shareBar(_ merchant: MerchantSlice) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.PrimaryText.opacity(0.07))
                Capsule()
                    .fill(Color.PrimaryText.opacity(0.45))
                    .frame(width: max(6, proxy.size.width * merchant.percent))
            }
        }
        .frame(height: 4)
        .padding(.leading, rankWidth + 10)
    }
}
