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
