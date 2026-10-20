//
//  TransactionDateRow.swift
//  smartbud
//
//  Date pill on the transaction form. Falls back to the date alone when the
//  row is too narrow for the time as well (`ViewThatFits` measures the real
//  container instead of guessing from the screen width).
//

import SwiftUI

struct TransactionDateRow: View {
    let date: Date
    /// Flips when the user picks a future date; drives the "rays" animation.
    let animateIcon: Bool
    let onTap: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(withTime: true)
            row(withTime: false)
        }
        .foregroundStyle(Color.PrimaryText)
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .animation(.default, value: TransactionDates.isToday(date))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
                .strokeBorder(Color.Outline, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func row(withTime: Bool) -> some View {
        HStack(spacing: 7) {
            Group {
                if date < Date.now {
                    Image(systemName: "calendar")
                } else {
                    Image(systemName: "rays")
                        .symbolEffect(
                            .variableColor.iterative.dimInactiveLayers.nonReversing,
                            options: .repeating, value: animateIcon)
                }
            }
            .foregroundStyle(Color.SubtitleText)
            .font(.subheadline.weight(.semibold))

            dateText
                .font(.body.weight(.semibold))

            if withTime {
                Spacer(minLength: 8)

                Text(TransactionDates.time(date))
                    .font(.body.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    private var dateText: some View {
        if TransactionDates.isToday(date) {
            Text(String.appLocalized("Today") + " · " + TransactionDates.day(date))
                .lineLimit(1)
        } else {
            Text(TransactionDates.day(date))
                .lineLimit(1)
        }
    }
}

enum TransactionDates {
    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.appLocale
        formatter.setLocalizedDateFormatFromTemplate(isToday(date) ? "MMMd" : "MMMdEEE")
        return formatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.appLocale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
