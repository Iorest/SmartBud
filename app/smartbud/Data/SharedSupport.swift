//
//  SharedSupport.swift
//  smartbud
//
//  Small shared pieces used by the app, the widgets and App Intents.
//  Split out of Helper.swift to keep that file within the project's length
//  limit; the API is unchanged.
//

import Foundation
import SwiftUI

// MARK: - Shared date utilities
//
// Free functions used by the app (`InsightsViewModel`), widgets (`InsightsWidget`), and App Intents.
// Originally lived in the single legacy data controller.

/// Returns the start-of-day for the current month, offset by `startDay` (1–28).
/// If `startDay` is 1, this is the 1st of the month at 00:00. If `startDay` is 15, it's the 15th at 00:00.
/// Months where the configured `startDay` doesn't exist (e.g. Feb 30) fall back to the last day of the month.
func getStartOfMonth(startDay: Int) -> Date {
    let calendar = Calendar.current
    let now = Date.now
    let comps = calendar.dateComponents([.year, .month], from: now)
    var startComps = comps
    startComps.day = max(1, min(startDay, 28))
    startComps.hour = 0
    startComps.minute = 0
    startComps.second = 0
    return calendar.date(from: startComps) ?? now
}

// MARK: - Line graph
//
// A single sampled data point on the `LineGraph` view, used by the Insights screen and the
// "Get Insights" App Intent snippet. `Equatable` so SwiftUI diffing can skip no-op redraws.

struct LineGraphDataPoint: Equatable, Identifiable {
    let date: Date
    let amount: Double

    var id: Date { date }

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale
        dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")
        return dateFormatter.string(from: date)
    }

    var monthString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale
        dateFormatter.setLocalizedDateFormatFromTemplate("yMMM")
        return dateFormatter.string(from: date)
    }

    var amountString: String {
        if abs(amount) < 1000 {
            return amount.formatted(.number.precision(.fractionLength(2)))
        } else {
            return amount.formatted(.number.precision(.fractionLength(0)))
        }
    }
}
