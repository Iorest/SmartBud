//
//  NumberPadViewModel.swift
//  smartbud
//
//  Owns the numeric-entry state shared between `NumberPad` (the digit keypad)
//  and `NumberPadTextView` (the amount display).
//
//  The entry is stored as typed digits, never as a floating-point value: the
//  old implementation did `price *= 10` and `Int(price * 10)` on a Double,
//  which drifted (0.1 + 0.2 cases) and truncated on backspace. The decimal
//  point is derived from the digit position, so every edit is exact.
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
    /// Type 1 ("pre-dotted") digit stream: the last two digits are the cents.
    private var digits: String = ""
    /// Type 2 integer part ("cent-less" mode).
    private var integerDigits: String = ""
    /// Type 2 cents part (max 2 digits).
    private var fractionDigits: String = ""

    /// True while the user is editing the cents part of the number (Type 2).
    var isEditingDecimal: Bool = false

    /// Entry mode. Mirrors the `numberEntryType` UserDefaults flag, injected
    /// so this VM stays UserDefaults-free and is easy to test.
    var numberEntryType: Int

    /// Bump to drive a SwiftUI `sensoryFeedback(.success, trigger:)` after
    /// a successful submit. Pure UI concern; doesn't affect any state.
    var submitTrigger: Int = 0

    /// Mirrors the `haptics` UserDefaults flag. A `var` so the views can keep
    /// it in step with Settings; it used to be fixed at 1, which made the
    /// setting a no-op for the pad (still buzzing on "None", never stronger
    /// on "Excessive").
    var hapticType: Int

    /// Upper bound for a single amount, kept so the display stays legible.
    private static let maxAmount = Decimal(100_000_000)
    /// Largest value that still fits under `maxAmount` with cents
    /// (99,999,999.99). Computed from integers so no floating literal enters.
    private static let maxCentsValue = Decimal(9_999_999_999) / 100

    init(numberEntryType: Int, hapticType: Int) {
        self.numberEntryType = numberEntryType
        self.hapticType = hapticType
    }

    private var mode: NumberEntryMode {
        NumberEntryMode(rawValue: numberEntryType) ?? .preDotted
    }

    // MARK: - Value

    /// Exact value represented by the current entry.
    var amount: Decimal {
        switch mode {
        case .preDotted:
            guard !digits.isEmpty else { return 0 }
            return (Decimal(string: digits) ?? 0) / 100
        case .centless:
            let whole = integerDigits.isEmpty ? "0" : integerDigits
            guard !fractionDigits.isEmpty else { return Decimal(string: whole) ?? 0 }
            return Decimal(string: whole + "." + fractionDigits) ?? 0
        }
    }

    /// Double view of `amount` for callers that still take a Double.
    /// The conversion happens once, at the boundary — no arithmetic on it.
    var price: Double {
        get { NSDecimalNumber(decimal: amount).doubleValue }
        set { load(newValue) }
    }

    /// Seeds the entry from an existing amount (edit mode). Rounds to cents
    /// before splitting the digits so 12.299… loads as 12.30.
    private func load(_ value: Double) {
        var source = Decimal(value) * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        let cents = NSDecimalNumber(decimal: rounded).intValue

        switch mode {
        case .preDotted:
            digits = cents == 0 ? "" : String(cents)
        case .centless:
            integerDigits = cents / 100 == 0 ? "" : String(cents / 100)
            let fraction = abs(cents % 100)
            if fraction == 0 {
                fractionDigits = ""
            } else if fraction % 10 == 0 {
                fractionDigits = String(fraction / 10)
            } else {
                fractionDigits = String(format: "%02d", fraction)
            }
        }
    }

    // MARK: - Display

    /// Human-readable amount string for `NumberPadTextView`.
    var amountString: String {
        switch mode {
        case .preDotted:
            return amount.formatted(.number.precision(.fractionLength(2)))
        case .centless:
            guard isEditingDecimal else {
                return amount.formatted(.number.precision(.fractionLength(0)))
            }
            switch fractionDigits.count {
            case 0:
                return amount.formatted(.number.precision(.fractionLength(0))) + "."
            case 1:
                return amount.formatted(.number.precision(.fractionLength(1)))
            default:
                return amount.formatted(.number.precision(.fractionLength(2)))
            }
        }
    }

    /// True while the user is editing cents; `NumberPadTextView` uses this to
    /// show its trailing delete button.
    var showsTrailingDelete: Bool { mode == .centless }

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

    /// Apply a digit tap. A leading zero is ignored (matches the old
    /// Double arithmetic, where it left the value unchanged).
    func tap(_ digit: Int) {
        switch mode {
        case .preDotted:
            guard !(digits.isEmpty && digit == 0) else { return }
            let candidate = digits + String(digit)
            guard candidateCents(candidate) < Self.maxAmount else { return }
            digits = candidate
        case .centless:
            if isEditingDecimal {
                guard fractionDigits.count < 2 else { return }
                fractionDigits.append(String(digit))
            } else {
                guard !(integerDigits.isEmpty && digit == 0) else { return }
                let candidate = integerDigits + String(digit)
                guard (Decimal(string: candidate) ?? 0) < Self.maxAmount else { return }
                integerDigits = candidate
            }
        }
    }

    private func candidateCents(_ digits: String) -> Decimal {
        (Decimal(string: digits) ?? 0) / 100
    }

    /// Backspace behaviour: removes the last typed digit in the current part.
    func deleteLast() {
        switch mode {
        case .preDotted:
            if !digits.isEmpty { digits.removeLast() }
        case .centless:
            if isEditingDecimal {
                if !fractionDigits.isEmpty {
                    fractionDigits.removeLast()
                } else {
                    isEditingDecimal = false
                }
            } else if !integerDigits.isEmpty {
                integerDigits.removeLast()
            }
        }
    }

    /// Enter cents-editing mode (the Type 2 decimal key). No-op in Type 1.
    func enterDecimal() {
        guard mode == .centless else { return }
        isEditingDecimal = true
    }

    /// Commit the current entry. The SwiftUI view can react to the cleared
    /// entry (and to `submitTrigger` if it wants to fire haptics). This
    /// intentionally does *not* trigger a `dataRepository.save()` — the
    /// caller (TransactionView) owns the actual commit semantics.
    func submit() {
        digits = ""
        integerDigits = ""
        fractionDigits = ""
        isEditingDecimal = false
        submitTrigger &+= 1
    }

    // MARK: - Button enable / disable

    /// Dims the number keys once no further digit can be appended.
    var isInputDisabled: Bool { amount >= Self.maxCentsValue }
}
