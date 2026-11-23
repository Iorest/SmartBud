//
//  SBSaveErrorBanner.swift
//  smartbud
//
//  Non-blocking report for a failed SwiftData write. Writes used to fail
//  silently, leaving the UI claiming success.
//

import SwiftUI

struct SBSaveErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: SBSpace.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.Alert)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.PrimaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: SBSpace.extraSmall)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String.appLocalized("关闭")))
            .accessibilityHint(Text(String.appLocalized("Close the save error message")))
        }
        .padding(SBSpace.small)
        .background(
            Color.SecondaryBackground,
            in: RoundedRectangle(cornerRadius: SBRadius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SBRadius.control, style: .continuous)
                .strokeBorder(Color.Alert.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}
