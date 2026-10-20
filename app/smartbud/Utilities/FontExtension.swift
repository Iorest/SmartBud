//
//  FontExtension.swift
//  smartbud
//
//  Created by Iorest on 29/7/22.
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import SwiftUI

extension UIFont {

    static func getBodyFontSize(dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall:
            return 14
        case .small:
            return 15
        case .medium:
            return 16
        case .large:
            return 17
        case .xLarge:
            return 19
        case .xxLarge:
            return 21
        case .xxxLarge:
            return 23
        default:
            return 23
        }
    }

    class func rounded(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        let font: UIFont

        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            let rounded: UIFont? = UIFont(descriptor: descriptor, size: size)
            font = rounded ?? systemFont
        } else {
            font = systemFont
        }
        return font
    }

    class func roundedSpecial(ofStyle style: UIFont.TextStyle, weight: UIFont.Weight, size: Double) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        let font: UIFont

        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            let rounded: UIFont? = UIFont(descriptor: descriptor, size: size)
            font = rounded ?? systemFont
        } else {
            font = systemFont
        }
        #if os(macOS)
        // macOS has no UIFontMetrics; the view's dynamicTypeSize already
        // drives the size passed in.
        return font
        #else
        return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
        #endif
    }

}
