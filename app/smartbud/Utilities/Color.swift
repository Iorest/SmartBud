//
//  Color.swift
//  smartbud
//
//  Created by Iorest on 10/5/22.
//

import Foundation
import SwiftUI

extension Color {
    static let colourMigrationDictionary: [String: String] = [
        "1": "#279AF4",
        "2": "#EC7A58",
        "3": "#A6678A",
        "4": "#C56AF7",
        "5": "#6E7BF1",
        "6": "#F3BF56",
        "7": "#ED80A2",
        "8": "#F6D24A",
        "9": "#E34D63",
        "10": "#61C7FA",
        "11": "#7014F5",
        "12": "#EB7068",
        "13": "#84B4EB",
        "14": "#4088AD",
        "15": "#B8D6FA",
        "16": "#C38D5D",
        "17": "#A0ACF9",
        "18": "#7CB0AA",
        "19": "#F6D489",
        "20": "#88997A",
        "21": "#F1AF8A",
        "22": "#2D4B7B",
        "23": "#5FAF9F",
        "24": "#D46D7F"
    ]

    static let colorArray: [String] = [
        "#279AF4",
        "#EC7A58",
        "#A6678A",
        "#C56AF7",
        "#6E7BF1",
        "#F3BF56",
        "#ED80A2",
        "#F6D24A",
        "#E34D63",
        "#61C7FA",
        "#7014F5",
        "#EB7068",
        "#84B4EB",
        "#4088AD",
        "#B8D6FA",
        "#C38D5D",
        "#A0ACF9",
        "#7CB0AA",
        "#F6D489",
        "#88997A",
        "#F1AF8A",
        "#2D4B7B",
        "#5FAF9F",
        "#D46D7F"
    ]

    static let neuBackground = Color(hex: "f0f0f3")
    static let dropShadow = Color(hex: "aeaec0").opacity(0.4)
    static let dropLight = Color(hex: "ffffff")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (12-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (16-bit)
            (_, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if a != Float(1.0) {
            return "#" + hexByte(r) + hexByte(g) + hexByte(b) + hexByte(a)
        } else {
            return "#" + hexByte(r) + hexByte(g) + hexByte(b)
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
        let components = UIColor(self).cgColor.components
        let r = components?[0] ?? 0
        let g = components?[1] ?? 0
        let b = components?[2] ?? 0
        return 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
    }

    static var PrimaryBackground: Color {
        return Color("PrimaryBackground")
    }

    static var SecondaryBackground: Color {
        return Color("SecondaryBackground")
    }

    static var DarkBackground: Color {
        return Color("DarkBackground")
    }

    static var PrimaryText: Color {
        return Color("PrimaryText")
    }

    static var AlertRed: Color {
        return Color("AlertRed")
    }

    static var IncomeGreen: Color {
        return Color("IncomeGreen")
    }

    static var BudgetBackground: Color {
        return Color("BudgetBackground")
    }

    static var SubtitleText: Color {
        return Color("SubtitleText")
    }

    static var Outline: Color {
        return Color("Outline")
    }

    static var LightIcon: Color {
        return Color("LightIcon")
    }

    static var DarkIcon: Color {
        return Color("DarkIcon")
    }

    static var GreyIcon: Color {
        return Color("GreyIcon")
    }

    static var Alert: Color {
        return Color("Alert")
    }

    static var TertiaryBackground: Color {
        return Color("TertiaryBackground")
    }

    static var SettingsBackground: Color {
        return Color("Settings")
    }

    static var EvenLighterText: Color {
        return Color("EvenLighterText")
    }
}

public extension View {
    /// Presents a native SwiftUI `ColorPicker` inside a sheet.
    ///
    /// Replaces the previous `UIViewRepresentable` wrapper around
    /// `UIColorPickerViewController` (iOS 14). The native
    /// `ColorPicker` is sufficient and avoids the UIKit dance.
    /// `title` is shown above the picker when non-empty.
    func colorPickerSheet(isPresented: Binding<Bool>, selection: Binding<Color>, supportsAlpha: Bool = true, title: String? = nil) -> some View {
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

    guard let inputRGBComponents = uiColor.cgColor.components else {
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
