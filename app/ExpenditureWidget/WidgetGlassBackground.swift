//
//  WidgetGlassBackground.swift
//  dime
//
//  A compact version of `AppGlassBackground` sized for home-screen widgets.
//  Same linear gradient as the in-app background but a single radial glow
//  with a smaller end-radius so the highlight fits within a 158pt square.
//  No `ignoresSafeArea()` — the widget's `containerBackground(for: .widget)`
//  already covers the full widget bounds, so the gradient fits those bounds.
//

import SwiftUI

struct WidgetGlassBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark ? darkStops : lightStops,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: scheme == .dark
                    ? [Color(hex: "9D4EDD").opacity(0.55), .clear]
                    : [Color(hex: "FF5BA8").opacity(0.7), .clear],
                center: UnitPoint(x: 0.9, y: 0.1),
                startRadius: 0,
                endRadius: 220
            )
        }
    }

    private var lightStops: [Color] {
        [Color(hex: "8AB4FF"), Color(hex: "C9A1FF"), Color(hex: "FF9EC0")]
    }

    private var darkStops: [Color] {
        [Color(hex: "1B1145"), Color(hex: "2D1B69"), Color(hex: "43237A")]
    }
}
