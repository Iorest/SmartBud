//
//  WidgetFormatting.swift
//  ExpenditureWidget
//
//  Shared formatting for the widget targets. Every widget used to inline the
//  same `specifier:` ternary and the same percent-encoded deep link, which
//  made the call sites long enough to be unreadable.
//

import Foundation
import SwiftUI

/// Formats an amount the way the widgets have always shown it: two decimals
/// below 100 when the user enabled cents, whole numbers otherwise.
func amountText(_ value: Double, showCents: Bool, under limit: Double = 100) -> String {
    String(format: showCents && value < limit ? "%.2f" : "%.0f", value)
}

/// Signed amount for a single transaction row, e.g. `+$5.00`.
func signedAmount(_ value: Double, income: Bool, showCents: Bool) -> String {
    let sign = income ? "+" : "-"
    return sign + amountText(value, showCents: showCents)
}

/// Appends the active book to a widget's `smartbud://` link. Widgets run in
/// another process, so they read the App Group selection directly. Old links
/// without `book` still mean "whatever book is currently open".
func widgetDeepLink(_ path: String) -> URL? {
    guard var components = URLComponents(string: "smartbud://\(path)") else { return nil }
    components.queryItems = (components.queryItems ?? []) + [
        URLQueryItem(name: "book", value: BookSelection.current().uuidString)
    ]
    return components.url
}

/// Deep link to a budget detail screen, percent-encoding the name.
func budgetDeepLink(_ name: String) -> URL? {
    let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    return widgetDeepLink("budget?budget=\(encoded)")
}

/// Period label shared by the budget widgets ("today" … "this year").
/// Mirrors the keys the app uses on its budget cards.
func budgetPeriodLabel(_ type: Int) -> String {
    String.appLocalized(BudgetPeriod.labelKey(for: type))
}

/// Category swatch for the breakdown bars. Income categories have no stored
/// colour, so they follow the palette order instead.
func widgetCategoryColor(_ category: HoldingCategory,
                         among categories: [HoldingCategory],
                         income: Bool) -> Color {
    if income {
        let palette = Color.colorArray
        guard !palette.isEmpty else { return Color.accentColor }
        let index = categories.firstIndex(of: category) ?? 0
        return Color(hex: palette[index % palette.count])
    }
    return Color(hex: category.colour)
}
