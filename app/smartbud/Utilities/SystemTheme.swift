//
//  SystemTheme.swift
//  smartbud
//
//  Root background and the two surface modifiers used across screens.
//  These used to be a bespoke Liquid Glass layer; they now render plain
//  system surfaces so the app matches native List/Form chrome.
//

import SwiftUI

// MARK: - Root background

/// Calm neutral canvas with two restrained brand glows. Kept as a single
/// view so screens don't stack gradients of their own.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// System grouped background: white cards need a visible grey canvas,
    /// otherwise every settings/template card disappears into the page.
    private var canvas: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    private var glowStrength: Double { scheme == .dark ? 0.16 : 0.06 }

    var body: some View {
        ZStack {
            canvas

            RadialGradient(
                colors: [Color(hex: "7C5CFF").opacity(glowStrength), .clear],
                center: UnitPoint(x: 1.02, y: -0.05),
                startRadius: 0,
                endRadius: 560
            )

            RadialGradient(
                colors: [Color(hex: "2F80ED").opacity(glowStrength * 0.75), .clear],
                center: UnitPoint(x: -0.05, y: 1.02),
                startRadius: 0,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: scheme)
    }
}

extension View {
    /// Apply the app canvas behind a sheet/full-screen root that doesn't
    /// inherit the window background.
    func appBackground() -> some View {
        background(AppBackground())
    }
}

// MARK: - Surfaces

/// Grouped card surface: system secondary background + hairline border.
struct SystemCard<Shape: SwiftUI.Shape>: ViewModifier {
    let shape: Shape

    func body(content: Content) -> some View {
        content
            .background(shape.fill(Color.SecondaryBackground))
            .overlay {
                shape.stroke(Color.Outline.opacity(0.6), lineWidth: 0.5)
            }
    }
}

/// Compact surface for chips and icon buttons.
struct SystemChip<Shape: SwiftUI.Shape>: ViewModifier {
    let shape: Shape
    let interactive: Bool

    func body(content: Content) -> some View {
        content
            .background(shape.fill(Color.SecondaryBackground))
            .overlay {
                shape.stroke(Color.Outline.opacity(0.5), lineWidth: 0.5)
            }
    }
}

/// Chip that keeps a category colour as a light tint.
struct SystemTintedChip<Shape: SwiftUI.Shape>: ViewModifier {
    let shape: Shape
    let tint: Color
    let interactive: Bool

    func body(content: Content) -> some View {
        content
            .background(shape.fill(tint.opacity(0.18)))
            .overlay {
                shape.stroke(tint.opacity(0.35), lineWidth: 0.5)
            }
    }
}

extension View {
    func systemCard<S: SwiftUI.Shape>(in shape: S) -> some View {
        modifier(SystemCard(shape: shape))
    }

    func systemChip<S: SwiftUI.Shape>(in shape: S, interactive: Bool = true) -> some View {
        modifier(SystemChip(shape: shape, interactive: interactive))
    }

    func systemTintedChip<S: SwiftUI.Shape>(_ tint: Color, in shape: S, interactive: Bool = true) -> some View {
        modifier(SystemTintedChip(shape: shape, tint: tint, interactive: interactive))
    }
}
