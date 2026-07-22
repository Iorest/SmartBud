//
//  NumberPadViewModel.swift
//  smartbud
//
//  Owns the numeric-entry state shared between `NumberPad` (the digit keypad)
//  and `NumberPadTextView` (the amount display). Extracted from the old
//  NumberPad.swift so the SwiftUI views only describe layout; the iOS 26
//  digit-handling, decimal-point logic, and haptics live here.
//
//  Marked `@Observable` (iOS 17+) so the views can react to mutations of
//  `price` / `isEditingDecimal` / `decimalValuesAssigned` without manual
//  `@Published` plumbing.
//

import Foundation
import Observation
import SwiftUI

/// State for the "pre-dotted" (Type 1) and "cent-less" (Type 2) entry modes
/// in `NumberPad`. Kept here so both NumberPad and NumberPadTextView can
/// share it without a chain of `@Binding` parameters.
enum NumberEntryMode: Int {
    /// "Pre-dotted" — every two digits become a decimal value, like a calculator.
    case preDotted = 1
    /// "Cent-less" — whole numbers only; tap the decimal key to enter cents.
    case centless = 2
}

@MainActor
@Observable
final class NumberPadViewModel {
    /// The numeric value being entered. `0` means "empty".
    var price: Double = 0
    /// True while the user is editing the cents part of the number (Type 2).
    var isEditingDecimal: Bool = false
    /// Tracks which decimal digit position we're in (Type 2 only).
    var decimalValuesAssigned: AssignedDecimal = .none

    /// Entry mode. Mirrors the `numberEntryType` UserDefaults flag, injected
    /// so this VM stays UserDefaults-free and is easy to test.
    var numberEntryType: Int

    /// Bump to drive a SwiftUI `sensoryFeedback(.success, trigger:)` after
    /// a successful submit. Pure UI concern; doesn't affect any state.
    var submitTrigger: Int = 0

    private let hapticType: Int
    private var disabled: Bool { price >= 100_000_000 }

    init(numberEntryType: Int, hapticType: Int) {
        self.numberEntryType = numberEntryType
        self.hapticType = hapticType
    }

    // MARK: - Display

    /// Human-readable amount string for `NumberPadTextView`. Matches the old
    /// computed `amount` verbatim so the visual is unchanged.
    var amountString: String {
        let mode = NumberEntryMode(rawValue: numberEntryType) ?? .preDotted
        if mode == .preDotted {
            return price.formatted(.number.precision(.fractionLength(2)))
        }
        if isEditingDecimal {
            switch decimalValuesAssigned {
            case .none:
                return price.formatted(.number.precision(.fractionLength(0))) + "."
            case .first:
                return price.formatted(.number.precision(.fractionLength(1)))
            case .second:
                return price.formatted(.number.precision(.fractionLength(2)))
            }
        }
        return price.formatted(.number.precision(.fractionLength(0)))
    }

    /// True while the user is editing cents; `NumberPadTextView` uses this to
    /// show its trailing delete button.
    var showsTrailingDelete: Bool {
        NumberEntryMode(rawValue: numberEntryType) == .centless
    }

    // MARK: - Haptics

    /// The SwiftUI view should call this from `sensoryFeedback(_:trigger:)`
    /// whenever a digit is tapped, so the haptic intensity follows the user's
    /// `haptics` preference (0 = none, 1 = subtle, 2 = excessive).
    var digitHapticIntensity: Double {
        hapticType == 2 ? 1.0 : 0.5
    }

    /// Honours the user's `haptics` "none" preference. The view applies
    /// `sensoryFeedback` only when this is true; otherwise no digit haptics
    /// fire (matches the old `if hapticType == 2 { hapticTap() }` semantics).
    var hapticsEnabled: Bool { hapticType > 0 }

    // MARK: - Actions

    /// Apply a digit tap. Originally inline in `NumberPad.swift` `NumberButton`.
    func tap(_ digit: Int) {
        if disabled { return }
        let mode = NumberEntryMode(rawValue: numberEntryType) ?? .preDotted
        if mode == .preDotted {
            price *= 10
            price += Double(digit) / 100
        } else {
            if isEditingDecimal {
                switch decimalValuesAssigned {
                case .none:
                    price += Double(digit) / 10
                    decimalValuesAssigned = .first
                case .first:
                    price += Double(digit) / 100
                    decimalValuesAssigned = .second
                case .second:
                    return
                }
            } else {
                price *= 10
                price += Double(digit)
            }
        }
    }

    /// Backspace behaviour. Identical logic to the old `deleteLastDigit()` in
    /// both `NumberPad` and `NumberPadTextView`.
    func deleteLast() {
        let mode = NumberEntryMode(rawValue: numberEntryType) ?? .preDotted
        if mode == .preDotted {
            price = Double(Int(price * 10)) / 100
        } else if !isEditingDecimal {
            price = Double(Int(price / 10))
        } else {
            switch decimalValuesAssigned {
            case .none:
                isEditingDecimal = false
                return
            case .first:
                price = Double(Int(price))
                decimalValuesAssigned = .none
            case .second:
                price = Double(Int(price * 10)) / 10
                decimalValuesAssigned = .first
            }
        }
    }

    /// Enter cents-editing mode (the Type 2 decimal key). No-op in Type 1.
    func enterDecimal() {
        guard NumberEntryMode(rawValue: numberEntryType) == .centless else { return }
        isEditingDecimal = true
    }

    /// Commit the current entry. The SwiftUI view can react to the cleared
    /// price (and to `submitTrigger` if it wants to fire haptics). This
    /// intentionally does *not* trigger a `dataRepository.save()` — the
    /// caller (TransactionView) owns the actual commit semantics.
    func submit() {
        price = 0
        isEditingDecimal = false
        decimalValuesAssigned = .none
        submitTrigger &+= 1
    }

    // MARK: - Button enable / disable

    /// Mirrors the old `disabled` flag on the number keys (price capped at
    /// 100M to keep the display legible). Exposed so the view can dim keys.
    var isInputDisabled: Bool { disabled }
}
