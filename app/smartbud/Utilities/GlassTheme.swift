//
//  GlassTheme.swift
//  smartbud
//
//  Created for the iOS 26 Liquid Glass redesign.
//  Centralised helpers for the glass design system: root gradient, card / chip
//  modifiers, and small reusable primitives. Reuses the existing `Color(hex:)`
//  initializer declared in `Utilities/Color.swift`.
//

import SwiftUI

// MARK: - Root background

/// The full-screen gradient placed behind every screen so the liquid glass
/// surfaces have something colourful to refract. Adapts to the system colour
/// scheme.
struct AppGlassBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark ? darkStops : lightStops,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: scheme == .dark
                    ? [Color(hex: "9D4EDD").opacity(0.7), .clear]
                    // 0.85 → 0.4: previous 0.85 produced solid pink/blue
                    // blocks that pushed `SubtitleText` (#A6A6A6) below
                    // WCAG 4.5:1 contrast. 0.4 keeps the colour as a soft
                    // glow and lets text read clearly.
                    : [Color(hex: "FF8FC1").opacity(0.4), .clear],
                center: UnitPoint(x: 0.9, y: 0.05),
                startRadius: 0,
                endRadius: 380
            )

            RadialGradient(
                colors: scheme == .dark
                    ? [Color(hex: "3A86FF").opacity(0.65), .clear]
                    : [Color(hex: "7AA0FF").opacity(0.4), .clear],
                center: UnitPoint(x: 0.05, y: 0.95),
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
        // Smooth crossfade when the user toggles Light/Dark/System.
        // `animation(_:value:)` (iOS 17+) is the modern replacement for
        // the deprecated `animation(_:)` modifier. Skipped under
        // Reduce Motion so we don't trigger vestibular issues.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: scheme)
    }

    private var lightStops: [Color] {
        // Pale pastels — these read as "tint" rather than "fill", so text
        // and icons keep ~4.5:1 contrast on top of the gradient.
        [Color(hex: "DCE7FF"), Color(hex: "EBDCFF"), Color(hex: "FFD9E5")]
    }

    private var darkStops: [Color] {
        [Color(hex: "1B1145"), Color(hex: "2D1B69"), Color(hex: "43237A")]
    }
}

extension View {
    /// Apply the standard glass background behind this view. Intended for
    /// fullScreenCover / sheet roots that don't inherit the HomeView gradient.
    func appBackground() -> some View {
        background(AppGlassBackground())
    }
}

// MARK: - Card modifier

/// A glass surface meant for the large grouping cards in lists (e.g. the
/// Settings grouped sections, the Insights summary block). Wraps the view in
/// a `GlassEffectContainer` so it can morph with siblings and uses the
/// regular glass variant with a small interactive boost.
struct GlassCard<Shape: SwiftUI.Shape>: ViewModifier {
    var shape: Shape
    var cornerStyle: RoundedCornerStyle = .continuous

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(.clear)
            }
            .glassEffect(.regular.interactive(true), in: shape)
    }
}

extension View {
    /// Wrap the view in a standard glass card. The view must have well-defined
    /// bounds (e.g. via padding or a fixed frame) before the glass will render
    /// correctly.
    func glassCard<S: SwiftUI.Shape>(
        in shape: S,
        cornerStyle: RoundedCornerStyle = .continuous
    ) -> some View {
        modifier(GlassCard(shape: shape, cornerStyle: cornerStyle))
    }
}

// MARK: - Chip modifier

/// A small glass surface for buttons, chips, tab items and similar compact UI.
/// Uses a thinner tint so the underlying gradient still bleeds through.
struct GlassChip<Shape: SwiftUI.Shape>: ViewModifier {
    var shape: Shape
    var interactive: Bool

    func body(content: Content) -> some View {
        content
            .background { shape.fill(.clear) }
            .glassEffect(interactive ? .regular.interactive(true) : .regular, in: shape)
    }
}

extension View {
    func glassChip<S: SwiftUI.Shape>(in shape: S, interactive: Bool = true) -> some View {
        modifier(GlassChip(shape: shape, interactive: interactive))
    }
}

// MARK: - Tinted chip (for category / icon chips that should keep their colour)

/// A glass chip that retains a category colour via the official `Glass.tint`
/// API instead of using a coloured fill. Lets the underlying gradient show
/// through while still signalling colour identity.
struct TintedGlassChip<Shape: SwiftUI.Shape>: ViewModifier {
    var shape: Shape
    var tint: Color
    var interactive: Bool

    func body(content: Content) -> some View {
        content
            .background { shape.fill(.clear) }
            .glassEffect(
                Glass.regular.tint(tint).interactive(interactive),
                in: shape
            )
    }
}

extension View {
    func tintedGlassChip<S: SwiftUI.Shape>(
        _ tint: Color,
        in shape: S,
        interactive: Bool = true
    ) -> some View {
        modifier(TintedGlassChip(shape: shape, tint: tint, interactive: interactive))
    }
}

// MARK: - Standard corner radii

enum GlassRadius {
    /// Cards inside lists (SettingsView groups, summary blocks, etc.).
    static let card: CGFloat = 16
    /// Big surfaces (tab bar pill, primary transaction entry).
    static let surface: CGFloat = 28
    /// Small buttons / chips.
    static let chip: CGFloat = 10
    /// Circle button.
    static let circle: CGFloat = 16
}
