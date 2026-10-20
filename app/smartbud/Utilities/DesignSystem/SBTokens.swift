//
//  SBTokens.swift
//  smartbud
//
//  Layout constants for the system-native redesign. Screens should compose
//  from these instead of raw numbers so spacing stays consistent across
//  iPhone, iPad and Mac.
//

import CoreGraphics

enum SBSpace {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xl: CGFloat = 32
}

enum SBRadius {
    /// Smallest UI: segmented-control selection, swatches, day pills.
    static let pill: CGFloat = 6
    /// Chips, tags, compact buttons.
    static let chip: CGFloat = 10
    static let control: CGFloat = 10
    /// Text fields and narrow form rows.
    static let input: CGFloat = 12
    /// Cards inside lists.
    static let card: CGFloat = 16
}
