//
//  Color.swift
//  smartbud
//
//  Created by Iorest on 10/5/22.
//

import Foundation
import SwiftUI

extension Color {
    /// Canonical category swatches live in `Theme.Palette`; kept here so the
    /// many existing `Color.colorArray` call sites stay unchanged.
    static var colorArray: [String] { Theme.Palette.swatches }

    init(hex: String) {
        // Income categories persist the asset name rather than a hex value;
        // without this every income swatch parsed as black.
        if hex == "IncomeGreen" {
            self = Color.IncomeGreen
            return
        }
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let red, green, blue: UInt64
        switch hex.count {
        case 6: // RGB (12-bit)
            (red, green, blue) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (16-bit)
            (_, red, green, blue) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (red, green, blue) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let red = Float(components[0])
        let green = Float(components[1])
        let blue = Float(components[2])
        var alpha = Float(1.0)

        if components.count >= 4 {
            alpha = Float(components[3])
        }

        if alpha != Float(1.0) {
            return "#" + hexByte(red) + hexByte(green) + hexByte(blue) + hexByte(alpha)
        } else {
            return "#" + hexByte(red) + hexByte(green) + hexByte(blue)
        }
    }

    /// One hex byte (`00`–`FF`) for the given `[0, 1]` float. Avoids the
    /// legacy C-style `String(format: "%02lX", ...)` by using `String(_:radix:uppercase:)`.
    private func hexByte(_ value: Float) -> String {
        let byte = Int(lroundf(value * 255)) & 0xFF
        let hex = String(byte, radix: 16, uppercase: true)
        return hex.count == 1 ? "0" + hex : hex
    }

    func luminance() -> Double {
        guard let components = UIColor(self).cgColor.components, !components.isEmpty else {
            return 0
        }
        // Grayscale colour spaces carry white (+ optional alpha) only, so the
        // RGB slots are absent rather than zero.
        guard components.count >= 3 else { return Double(components[0]) }
        let red = components[0]
        let green = components[1]
        let blue = components[2]
        return 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
    }

    // MARK: - Semantic colors (system-native)

    // These were asset-catalog colors with fixed hex values. Mapping them to
    // the platform's semantic colors fixes contrast (secondary text was
    // ~2.2:1 in light mode) and makes every screen adapt to light/dark,
    // increased contrast, and macOS window backgrounds automatically.

    static var PrimaryBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    static var SecondaryBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    static var TertiaryBackground: Color {
        #if os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color(uiColor: .tertiarySystemGroupedBackground)
        #endif
    }

    static var SettingsBackground: Color { SecondaryBackground }

    static var PrimaryText: Color {
        #if os(macOS)
        Color(nsColor: .labelColor)
        #else
        Color(uiColor: .label)
        #endif
    }

    static var SubtitleText: Color {
        #if os(macOS)
        Color(nsColor: .secondaryLabelColor)
        #else
        Color(uiColor: .secondaryLabel)
        #endif
    }

    static var EvenLighterText: Color {
        #if os(macOS)
        Color(nsColor: .tertiaryLabelColor)
        #else
        Color(uiColor: .tertiaryLabel)
        #endif
    }

    static var Outline: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }

    static var AlertRed: Color {
        #if os(macOS)
        Color(nsColor: .systemRed)
        #else
        Color(uiColor: .systemRed)
        #endif
    }

    static var IncomeGreen: Color {
        #if os(macOS)
        Color(nsColor: .systemGreen)
        #else
        Color(uiColor: .systemGreen)
        #endif
    }

    static var Alert: Color {
        #if os(macOS)
        Color(nsColor: .systemOrange)
        #else
        Color(uiColor: .systemOrange)
        #endif
    }

    static var DarkIcon: Color { SubtitleText }

    /// Icon color used on top of saturated category chips.
    static var DarkBackground: Color {
        return Color("DarkBackground")
    }

    static var LightIcon: Color {
        return Color("LightIcon")
    }
}

public extension View {
    /// Presents a native SwiftUI `ColorPicker` inside a sheet.
    ///
    /// Replaces the previous `UIViewRepresentable` wrapper around
    /// `UIColorPickerViewController` (iOS 14). The native
    /// `ColorPicker` is sufficient and avoids the UIKit dance.
    /// `title` is shown above the picker when non-empty.
    func colorPickerSheet(
        isPresented: Binding<Bool>,
        selection: Binding<Color>,
        supportsAlpha: Bool = true,
        title: String? = nil
    ) -> some View {
        sheet(isPresented: isPresented) {
            VStack(spacing: 12) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.headline)
                }
                ColorPicker("", selection: selection, supportsOpacity: supportsAlpha)
                    .labelsHidden()
                    .padding()
            }
            .presentationDetents([.medium])
        }
    }
}

func blend(over color: Color, withAlpha alpha: CGFloat) -> Color {
    let uiColor = UIColor(color)
    let alphaClamped = min(max(alpha, 0), 1)

    guard let inputRGBComponents = uiColor.cgColor.components,
          inputRGBComponents.count >= 3 else {
        // Grayscale and pattern colours have no RGB slots to blend.
        return color
    }

    let inputRed = inputRGBComponents[0]
    let inputGreen = inputRGBComponents[1]
    let inputBlue = inputRGBComponents[2]

    let whiteComponents: [CGFloat] = [1, 1, 1]
    let whiteRed = whiteComponents[0]
    let whiteGreen = whiteComponents[1]
    let whiteBlue = whiteComponents[2]

    // alpha blending
    let red = inputRed * alphaClamped + whiteRed * (1 - alphaClamped)
    let green = inputGreen * alphaClamped + whiteGreen * (1 - alphaClamped)
    let blue = inputBlue * alphaClamped + whiteBlue * (1 - alphaClamped)

    return Color(UIColor(red: red, green: green, blue: blue, alpha: 1))
}
