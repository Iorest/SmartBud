//
//  SBTypography.swift
//  smartbud
//
//  Type tokens for the design-system components. Screen code uses system
//  text styles directly; these are for the places where two surfaces must
//  render identically (section headers, subtitles, money).
//

import SwiftUI

extension Font {
    static let sbSectionHeader = Font.headline
    static let sbRowSubtitle = Font.subheadline
    /// Money is the only place that keeps tabular figures, so columns of
    /// amounts stay aligned as they change.
    static let sbAmount = Font.title3.weight(.semibold).monospacedDigit()
    static let sbHeroAmount = Font.largeTitle.weight(.semibold).monospacedDigit()
}
