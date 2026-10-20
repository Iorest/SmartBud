//
//  AmountFormatting.swift
//  smartbud
//
//  App-facing money strings. `Money.format` takes an explicit locale so it
//  stays testable without the app group; this wrapper supplies the in-app
//  language's locale for view and view-model call sites.
//

import Foundation

extension Money {
    static func format(
        _ value: Double,
        currencyCode: String,
        showsCents: Bool = true,
        plus: Bool? = nil
    ) -> String {
        format(value, currencyCode: currencyCode,
               showsCents: showsCents, plus: plus, locale: .appLocale)
    }

    static func format(
        _ value: Decimal,
        currencyCode: String,
        showsCents: Bool = true,
        plus: Bool? = nil
    ) -> String {
        format(value, currencyCode: currencyCode,
               showsCents: showsCents, plus: plus, locale: .appLocale)
    }
}
