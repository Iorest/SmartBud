//
//  StringExtension.swift
//  smartbud
//
//  Created by Iorest on 16/5/22.
//

import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension String {
    var containsDigits: Bool {
        return rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
    }

    func onlyEmoji() -> String {
        return filter { $0.isEmoji }
    }

    func widthOfRoundedString(size: CGFloat, weight: UIFont.Weight) -> CGFloat {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        let roundedFont: UIFont
        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            let rounded: UIFont? = UIFont(descriptor: descriptor, size: size)
            roundedFont = rounded ?? systemFont
        } else {
            roundedFont = systemFont
        }

        let fontAttributes = [NSAttributedString.Key.font: roundedFont]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }

}

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}
