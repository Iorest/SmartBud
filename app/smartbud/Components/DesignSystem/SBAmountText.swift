//
//  SBAmountText.swift
//  smartbud
//
//  Single money renderer. All amounts enter as Decimal (never Double) and
//  use tabular figures so columns stay aligned.
//

import SwiftUI

struct SBAmountText: View {
    enum Style {
        case body
        case title
        case hero
    }

    let amount: Decimal
    let currencyCode: String
    var signed: Bool = false
    var showsCents: Bool = true
    var style: Style = .body

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(Color.PrimaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityLabel(text)
    }

    private var font: Font {
        switch style {
        case .body: return .sbAmount
        case .title: return .title2.weight(.semibold).monospacedDigit()
        case .hero: return .sbHeroAmount
        }
    }

    private var text: String {
        Money.format(amount, currencyCode: currencyCode, showsCents: showsCents,
                     plus: signed ? amount >= 0 : nil)
    }
}
