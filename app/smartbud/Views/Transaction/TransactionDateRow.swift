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
        Button(action: onTap) {
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String.appLocalized("Date") + ": "
            + TransactionDates.day(date) + " " + TransactionDates.time(date)))
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
        let style: Date.FormatStyle = isToday(date)
            ? .dateTime.month(.abbreviated).day()
            : .dateTime.month(.abbreviated).day().weekday(.abbreviated)
        return date.formatted(style.locale(Locale.appLocale))
    }

    static func time(_ date: Date) -> String {
        // Let the locale decide between 24h and 12h; a hardcoded "HH:mm"
        // disagreed with the log list on 12-hour devices.
        date.formatted(.dateTime.hour().minute().locale(Locale.appLocale))
    }
}
