//
//  StringExtension.swift
//  smartbud
//
//  Created by Iorest on 16/5/22.
//

import Foundation
import UIKit

extension StringProtocol {
    var firstUppercased: String { prefix(1).uppercased() + dropFirst() }
    var firstCapitalized: String { prefix(1).capitalized + dropFirst() }
}

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
            roundedFont = UIFont(descriptor: descriptor, size: size)
        } else {
            roundedFont = systemFont
        }

        let fontAttributes = [NSAttributedString.Key.font: roundedFont]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }

    func heightOfRoundedString(size: CGFloat, weight: UIFont.Weight) -> CGFloat {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        let roundedFont: UIFont
        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            roundedFont = UIFont(descriptor: descriptor, size: size)
        } else {
            roundedFont = systemFont
        }

        let fontAttributes = [NSAttributedString.Key.font: roundedFont]
        let size = self.size(withAttributes: fontAttributes)
        return size.height
    }
}

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}
