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

    private let overlays = ["D", "W", "M"]

    var body: some View {
        Menu {
            Picker(String.appLocalized("Repeat"), selection: preset) {
                Text(String.appLocalized("None")).tag(0)
                Text(String.appLocalized("Daily")).tag(1)
                Text(String.appLocalized("Weekly")).tag(2)
                Text(String.appLocalized("Monthly")).tag(3)
            }
            .pickerStyle(.inline)

            Divider()

            Button {
                // Hop to the next runloop so the menu finishes dismissing
                // before the sheet presentation starts; otherwise the menu
                // dismissal animation swallows it.
                Task { @MainActor in showPicker = true }
            } label: {
                Label(customTitle, systemImage: "slider.horizontal.3")
            }
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
    }

    /// The custom row carries the active interval so the menu still shows the
    /// current setting once a preset is no longer selected.
    private var customTitle: String {
        guard repeatCoefficient > 1 else {
            return String.appLocalized("Custom Interval")
        }
        let unit: String
        switch repeatType {
        case 3: unit = String.appLocalized("months")
        case 2: unit = String.appLocalized("weeks")
        default: unit = String.appLocalized("days")
        }
        return "\(String.appLocalized("Custom Interval")) · \(repeatCoefficient) \(unit)"
    }

    /// `-1` means "custom interval", which no preset row should tick.
    private var preset: Binding<Int> {
        Binding(
            get: { repeatCoefficient == 1 ? repeatType : -1 },
            set: { newValue in
                guard newValue >= 0 else { return }
                repeatType = newValue
                repeatCoefficient = 1
            }
        )
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
