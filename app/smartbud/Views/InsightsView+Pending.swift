//
//  InsightsView+Pending.swift
//  smartbud
//
//  Card that surfaces money the user is owed. The claim rows are excluded
//  from the expense card, so this is the only place that total appears.
//

import SwiftUI

extension InsightsView {

    // MARK: - Pending reimbursement

    /// Claims the user is still owed. The unpaid part also appears in the
    /// expense card; this card is the only place the *outstanding* total
    /// appears on its own.
    var pendingReimbursementCard: some View {
        Button {
            showPendingReimbursements = true
        } label: {
            HStack(spacing: SBSpace.small) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.orange)
                    .frame(width: 30, height: 30)
                    .background(Color.orange.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String.appLocalized("Pending Reimbursement"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.SubtitleText)
                    Text(Money.format(insightsVM.pendingReimbursementTotal,
                                      currencyCode: currency,
                                      showsCents: insightsVM.showCents,
                                      locale: .appLocale))
                        .font(.title3.weight(.medium).monospacedDigit())
                        .foregroundStyle(Color.PrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Spacer(minLength: SBSpace.extraSmall)

                Text(String.appFormatted("%lld entries",
                                         insightsVM.pendingReimbursements.count))
                    .font(.caption)
                    .foregroundStyle(Color.SubtitleText)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)
            }
            .padding(SBSpace.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 30)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
