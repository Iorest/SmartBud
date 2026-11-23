//
//  NumberPad.swift
//  smartbud
//
//  iOS 26 rewrite of the numeric entry keypad. State now lives in
//  `NumberPadViewModel` (@Observable) so layout can stay purely declarative.
//
//  iOS 26 / new-API notes:
//  - `@Bindable` viewModel replaces the chain of `@Binding`s.
//  - `frame(maxHeight: .infinity)` on each row replaces the old
//    `proxy.size.height * 0.22` button-height math and the lost
//    `.frame(width:height:)` on the VStack. The pad now always fills its
//    parent.
//  - `sensoryFeedback(_:trigger:)` replaces the old CHHapticEngine plumbing.
//  - The keypad is a plain grid of system surfaces
//    effects for cheaper rendering (iOS 26 performance API).
//  - `foregroundStyle` instead of `foregroundColor`.
//

import SwiftUI

struct NumberPad: View {
    @Bindable var viewModel: NumberPadViewModel
    var showingNotePicker: Bool = false
    /// Selected category. Owned by the parent (it's a separate piece of
    /// transaction-entry state); the pad only reads it to drive the
    /// submit-button's bounce effect.
    var category: CategoryModel?
    /// Submit action. Called when the user taps the checkmark. The pad also
    /// calls `viewModel.submit()` first, which clears the state. Declared last so
    /// the trailing-closure syntax reads naturally at the call site.
    var submit: () -> Void = {}
    /// Long-press alternative: save without closing the form.
    var submitAndContinue: () -> Void = {}

    private let numPadNumbers = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    private let rowShape = RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)

    /// Fixed row height (was `frame(maxHeight: .infinity)` in the previous
    /// rewrite — that made each row greedy and the bottom row clipped off-screen
    /// when the parent gave it 800pt to fill). At
    /// 4 × 72pt + 3 × 8pt = 312pt the whole pad fits a standard iPhone without
    /// spilling into the rest of the add-transaction layout.
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 72

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// From xxLarge the scaled rows push the entry screen past the viewport
    /// on 4.7" phones, so the cells stop at their base height.
    private var cellHeight: CGFloat {
        // Accessibility sizes need headroom for the note/date/category rows
        // above the pad; at 72pt the last key row sat under the home indicator.
        if dynamicTypeSize.isAccessibilitySize { return 64 }
        return dynamicTypeSize >= .xxLarge ? min(rowHeight, 72) : rowHeight
    }

    /// Fires on every digit tap, with intensity driven by the user's
    /// `haptics` preference (computed in the VM). Skipped entirely when
    /// haptics are disabled, matching the old `if hapticType == 2` guard.
    var body: some View {
        VStack(spacing: 8) {
            ForEach(numPadNumbers, id: \.self) { row in
                numberRow(row)
            }
            bottomRow
        }
        .padding(.bottom, 15)
        .modifier(DigitHapticModifier(
            haptic: .impact(weight: .light, intensity: viewModel.digitHapticIntensity),
            trigger: viewModel.price,
            enabled: viewModel.hapticsEnabled
        ))
        .modifier(SuccessHapticModifier(
            trigger: viewModel.submitTrigger,
            enabled: viewModel.hapticsEnabled
        ))
    }

    @ViewBuilder
    private func numberRow(_ row: [Int]) -> some View {
        HStack(spacing: 8) {
            ForEach(row, id: \.self) { digit in
                digitButton(digit)
            }
        }
        .frame(height: cellHeight)
    }

    @ViewBuilder
    private var bottomRow: some View {
        HStack(spacing: 8) {
            if viewModel.numberEntryType == 1 {
                backspaceButton
            } else {
                decimalButton
            }
            digitButton(0)
            checkmarkButton
        }
        .frame(height: cellHeight)
    }

    // MARK: - Buttons

    @ViewBuilder
    private func digitButton(_ digit: Int) -> some View {
        let disabled = viewModel.isInputDisabled
        Button {
            viewModel.tap(digit)
        } label: {
            // `VStack` with equal Spacers above and below is the only way
            // to put the glyph truly in the middle of the cell. Text has a
            // fixed line height and the glyph sits at the baseline, so
            // `frame(alignment: .center)` and `ZStack` both leave the
            // digit hovering at the top or bottom of the cell instead of
            // centred. The Spacers push the Text away from both edges.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Text("\(digit)")
                    .font(.title2)
                    .foregroundStyle(Color.PrimaryText)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.SecondaryBackground, in: rowShape)
            .overlay {
                rowShape.strokeBorder(Color.Outline.opacity(0.5), lineWidth: 0.5)
            }
            // Without this, only the glyph is tappable, not the whole key.
            .contentShape(Rectangle())
            .opacity(disabled ? 0.6 : 1)
        }
        .disabled(disabled)
        .buttonStyle(NumPadButton())
        .accessibilityLabel(Text("\(digit)"))
        .accessibilityIdentifier(AccessibilityID.padDigit(digit))
    }

    @ViewBuilder
    private var backspaceButton: some View {
        Button {
            viewModel.deleteLast()
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Image(systemName: "delete.left.fill")
                    .font(.title3)
                    .foregroundStyle(Color.PrimaryText)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.TertiaryBackground, in: rowShape)
            .overlay {
                rowShape.strokeBorder(Color.Outline.opacity(0.5), lineWidth: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(NumPadButton())
        .accessibilityLabel(Text(String.appLocalized("Delete")))
        .accessibilityIdentifier(AccessibilityID.padBackspace)
    }

    @ViewBuilder
    private var decimalButton: some View {
        Button {
            viewModel.enterDecimal()
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(Locale.appLocale.decimalSeparator ?? ".")
                    .font(.title2)
                    .foregroundStyle(Color.PrimaryText)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.SecondaryBackground, in: rowShape)
            .overlay {
                rowShape.strokeBorder(Color.Outline.opacity(0.5), lineWidth: 0.5)
            }
            // Without this, only the glyph is tappable, not the whole key.
            .contentShape(Rectangle())
        }
        .buttonStyle(NumPadButton())
        .accessibilityLabel(Text("Decimal point"))
        .accessibilityIdentifier(AccessibilityID.padDecimal)
    }

    @ViewBuilder
    private var checkmarkButton: some View {
        let canSubmit = viewModel.price != 0
        Button {
            // IMPORTANT: do NOT call `viewModel.submit()` here before the parent
            // closure. The parent reads `padVM.price` to decide whether to
            // create the transaction; if the VM clears it first, the
            // parent sees `amount == 0` and shows a "Missing Amount" toast
            // instead of committing. The parent calls `padVM.submit()` itself
            // once it has captured the value and the transaction is saved.
            submit()
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.title2.weight(.semibold))
                    .symbolEffect(.bounce.up.byLayer, value: canSubmit)
                    .foregroundStyle(Color.LightIcon)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.accentColor.opacity(canSubmit ? 1 : 0.4), in: rowShape)
            .contentShape(Rectangle())
        }
        .buttonStyle(NumPadButton())
        .disabled(!canSubmit)
        .accessibilityLabel(Text("Submit"))
        .accessibilityHint(Text(String.appLocalized("Save the transaction and close")))
        .accessibilityIdentifier(AccessibilityID.entrySave)
        .contextMenu {
            Button {
                submitAndContinue()
            } label: {
                Label(String.appLocalized("Save and Continue"), systemImage: "plus.circle")
            }
            .accessibilityIdentifier(AccessibilityID.entrySaveAndContinue)
        }
    }
}

// MARK: - Amount display

/// Big price text shown above the keypad. Reads its state from the shared
/// `NumberPadViewModel` so it stays in lockstep with `NumberPad` without
/// passing bindings around.
struct NumberPadTextView: View {
    @Bindable var viewModel: NumberPadViewModel
    /// Currency symbol displayed to the left of the amount. Owned by the
    /// caller because it's purely a presentation concern.
    var currencySymbol: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// iOS 26: `.font(.body.scaled(by:))` is the modern replacement for
    /// `@ScaledMetric` when targeting iOS 26+. We still need raw points
    /// because the amount display uses a single large size; the formula
    /// below matches the old `largerFontSize` table.
    private var fontSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 46
        case .small: return 47
        case .medium: return 48
        case .large: return 50
        case .xLarge: return 56
        case .xxLarge: return 58
        case .xxxLarge: return 62
        default: return 50
        }
    }

    var body: some View {
        // Amount and the backspace sit in one centred row, so the delete key
        // stays next to the number it edits instead of floating at the screen
        // edge (HIG: destructive/edit affordances belong with their target).
        HStack(spacing: 10) {
            // Alphabetic symbols ("SGD", "CHF") need breathing room that a
            // single "$" does not.
            HStack(alignment: .lastTextBaseline, spacing: currencySymbol.count > 1 ? 6 : 1) {
                Text(currencySymbol)
                    .font(.largeTitle)
                    .foregroundStyle(Color.SubtitleText)

                Text(viewModel.amountString)
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundStyle(Color.PrimaryText)
                    .contentTransition(.numericText())
            }
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            // One anchor for the read-out: the E2E cases read the amount the
            // pad produced (12.50, the 0 after "save and continue", the cap)
            // back from this element's label instead of scanning the screen.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.entryAmountDisplay)

            if viewModel.showsTrailingDelete {
                trailingDelete
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var trailingDelete: some View {
        Button {
            viewModel.deleteLast()
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.SubtitleText)
                // 44pt minimum touch target (was 35×32).
                .frame(width: 44, height: 44)
                .systemChip(in: Circle())
                .contentShape(Circle())
        }
        .disabled(viewModel.price == 0 && !viewModel.isEditingDecimal)
        .accessibilityLabel(Text(String.appLocalized("Delete")))
        .accessibilityIdentifier(AccessibilityID.entryAmountDelete)
    }
}

// MARK: - Conditional haptic modifiers

/// Applies `sensoryFeedback` only when `enabled` is true. SwiftUI has no
/// built-in "off switch" for `sensoryFeedback`, so we wrap it.
private struct DigitHapticModifier: ViewModifier {
    let haptic: SensoryFeedback
    let trigger: Double
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.sensoryFeedback(haptic, trigger: trigger)
        } else {
            content
        }
    }
}

private struct SuccessHapticModifier: ViewModifier {
    let trigger: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.sensoryFeedback(.success, trigger: trigger)
        } else {
            content
        }
    }
}
