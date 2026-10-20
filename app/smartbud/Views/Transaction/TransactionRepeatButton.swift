//
//  TransactionRepeatButton.swift
//  smartbud
//
//  Toolbar button that opens the recurrence picker. Shows the "D/W/M" badge
//  once a recurrence is set.
//

import SwiftUI

struct TransactionRepeatButton: View {
    @Binding var repeatType: Int
    @Binding var repeatCoefficient: Int
    /// Drives the full recurrence editor sheet opened from the picker.
    @Binding var showPicker: Bool

    @State private var showRecurring = false

    private let overlays = ["D", "W", "M"]

    var body: some View {
        Button {
            showRecurring = true
        } label: {
            if repeatType > 0 {
                iconWithBadge
            } else {
                Image(systemName: "repeat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.SubtitleText)
                    .padding(7)
                    .background(Color.SecondaryBackground, in: Circle())
                    .contentShape(Circle())
            }
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityLabel)
        .popover(isPresented: $showRecurring) {
            RecurringPickerView(
                repeatType: $repeatType,
                repeatCoefficient: $repeatCoefficient,
                showMenu: $showRecurring,
                showPicker: $showPicker
            )
        }
    }

    private var badge: String {
        overlays[max(0, min(repeatType - 1, overlays.count - 1))]
    }

    private var iconWithBadge: some View {
        Image(systemName: "repeat")
            .font(.subheadline.weight(.semibold))
            .overlay(alignment: .topTrailing) {
                Text(badge)
                    .font(.system(size: 6, weight: .black))
                    .foregroundStyle(Color.IncomeGreen)
                    .frame(width: 10, alignment: .leading)
                    .offset(x: 5.7, y: 1.5)
            }
            .foregroundStyle(Color.IncomeGreen)
            .padding(7)
            .background(Color.IncomeGreen.opacity(0.23), in: Circle())
            .contentShape(Circle())
    }

    private var accessibilityLabel: String {
        switch repeatType {
        case 1: return String.appLocalized("transaction recurs daily, button to edit recurring duration")
        case 2: return String.appLocalized("transaction recurs weekly, button to edit recurring duration")
        case 3: return String.appLocalized("transaction recurs monthly, button to edit recurring duration")
        default: return String.appLocalized("button to make transaction recurring")
        }
    }
}
