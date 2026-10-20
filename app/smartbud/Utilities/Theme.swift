//
//  Theme.swift
//  smartbud
//
//  Single source of truth for colours that are not asset-catalog backed.
//  Asset-catalog semantic colours stay on `Color` (Color.PrimaryText, …);
//  hex values live here so views never hardcode a literal.
//

import SwiftUI

enum Theme {
    /// User-selectable category colours. Hex strings are persisted in
    /// `CategoryModel.colour`, so the format and order must not change.
    enum Palette {
        static let swatches: [String] = [
            "#279AF4", "#EC7A58", "#A6678A", "#C56AF7", "#6E7BF1", "#F3BF56",
            "#ED80A2", "#F6D24A", "#E34D63", "#61C7FA", "#7014F5", "#EB7068",
            "#84B4EB", "#4088AD", "#B8D6FA", "#C38D5D", "#A0ACF9", "#7CB0AA",
            "#F6D489", "#88997A", "#F1AF8A", "#2D4B7B", "#5FAF9F", "#D46D7F"
        ]

        /// Stable 6-bucket palette for the category breakdown chart.
        static let chartSwatches: [String] = [
            "#EB4263", "#D933A6", "#408CF2", "#F28C33", "#4DBF73", "#8C59D9"
        ]

        static func chartColors() -> [Color] { chartSwatches.map(Color.init(hex:)) }
    }

    /// Fixed brand colours used by chrome (not themeable by the user).
    enum Brand {
        /// Warning banner.
        static let warning = Color(hex: "FF9500")
        /// Pro / premium crown.
        static let premium = Color(hex: "F2C74F")
        /// Edit affordance on the budget detail toolbars.
        static let edit = Color(hex: "FDBC3B")
    }
}
