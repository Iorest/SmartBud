//
//  NumberPad.swift
//  dime
//
//  iOS 26 rewrite of the numeric entry keypad. State now lives in
//  `NumberPadViewModel` (@Observable) so layout can stay purely declarative.
//
//  iOS 26 / new-API notes:
//  - `@Bindable` viewModel replaces the chain of `@Binding`s.
//  - `frame(maxHeight: .infinity)` on each row replaces the old
//    `proxy.size.height * 0.22` button-height math and the lost
//    `.frame(width:height:)` on the VStack. The pad now always fills its
//    parent (set by `.keyboardAwareHeight`).
//  - `sensoryFeedback(_:trigger:)` replaces the old CHHapticEngine plumbing.
//  - `GlassEffectContainer(spacing:)` batches the per-button `glassChip`
//    effects for cheaper rendering (iOS 26 performance API).
//  - `foregroundStyle` instead of `foregroundColor`.
//

import SwiftUI

enum AssignedDecimal {
    case none, first, second
}

struct NumberPad: View {
    @Bindable var vm: NumberPadViewModel
    var showingNotePicker: Bool = false
    /// Selected category. Owned by the parent (it's a separate piece of
    /// transaction-entry state); the pad only reads it to drive the
    /// submit-button's bounce effect.
    var category: CategoryModel? = nil
    /// Submit action. Called when the user taps the checkmark. The pad also
    /// calls `vm.submit()` first, which clears the state. Declared last so
    /// the trailing-closure syntax reads naturally at the call site.
    var submit: () -> Void = {}

    private let numPadNumbers = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    private let rowShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    /// Fixed row height (was `frame(maxHeight: .infinity)` in the previous
    /// rewrite — that made each row greedy and the bottom row clipped off-screen
    /// when the parent (`.keyboardAwareHeight`) gave it 800pt to fill). At
    /// 4 × 72pt + 3 × 8pt = 312pt the whole pad fits a standard iPhone without
    /// spilling into the rest of the add-transaction layout.
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 72

    /// Fires on every digit tap, with intensity driven by the user's
    /// `haptics` preference (computed in the VM). Skipped entirely when
    /// haptics are disabled, matching the old `if hapticType == 2` guard.
    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                ForEach(numPadNumbers, id: \.self) { row in
                    numberRow(row)
                }
                bottomRow
            }
        }
        .padding(.bottom, 15)
        .keyboardAwareHeight(showToolbar: showingNotePicker)
        .modifier(DigitHapticModifier(
            haptic: .impact(weight: .light, intensity: vm.digitHapticIntensity),
            trigger: vm.price,
            enabled: vm.hapticsEnabled
        ))
        .modifier(SuccessHapticModifier(
            trigger: vm.submitTrigger,
            enabled: vm.hapticsEnabled
        ))
    }

    @ViewBuilder
    private func numberRow(_ row: [Int]) -> some View {
        HStack(spacing: 8) {
            ForEach(row, id: \.self) { digit in
                digitButton(digit)
            }
        }
        .frame(height: rowHeight)
    }

    @ViewBuilder
    private var bottomRow: some View {
        HStack(spacing: 8) {
            if vm.numberEntryType == 1 {
                backspaceButton
            } else {
                decimalButton
            }
            digitButton(0)
            checkmarkButton
        }
        .frame(height: rowHeight)
    }

    // MARK: - Buttons

    @ViewBuilder
    private func digitButton(_ digit: Int) -> some View {
        let disabled = vm.isInputDisabled
        Button {
            vm.tap(digit)
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
                    .font(.system(.title2, design: .rounded))
                    .foregroundStyle(Color.PrimaryText)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(rowShape.fill(.clear))
            .glassChip(in: rowShape)
            .opacity(disabled ? 0.6 : 1)
        }
        .disabled(disabled)
        .buttonStyle(NumPadButton())
        .accessibilityLabel(Text("\(digit)"))
    }

    @ViewBuilder
    private var backspaceButton: some View {
        Button {
            vm.deleteLast()
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Image("tag-cross")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Color.LightIcon)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.DarkBackground, in: rowShape)
        }
        .buttonStyle(NumPadButton())
        .accessibilityLabel(Text("Delete"))
    }

    @ViewBuilder
    private var decimalButton: some View {
        Button {
            vm.enterDecimal()
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(Locale.current.decimalSeparator ?? ".")
                    .font(.system(.title2, design: .rounded))
                    .foregroundStyle(Color.PrimaryText)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(rowShape.fill(.clear))
            .glassChip(in: rowShape)
        }
        .buttonStyle(NumPadButton())
        .accessibilityLabel(Text("Decimal point"))
    }

    @ViewBuilder
    private var checkmarkButton: some View {
        let canSubmit = vm.price != 0
        Button {
            // IMPORTANT: do NOT call `vm.submit()` here before the parent
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
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .symbolEffect(.bounce.up.byLayer, value: canSubmit)
                    .foregroundStyle(Color.LightIcon)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.accentColor.opacity(canSubmit ? 1 : 0.4), in: rowShape)
        }
        .buttonStyle(NumPadButton())
        .disabled(!canSubmit)
        .accessibilityLabel(Text("Submit"))
    }
}

// MARK: - Amount display

/// Big price text shown above the keypad. Reads its state from the shared
/// `NumberPadViewModel` so it stays in lockstep with `NumberPad` without
/// passing bindings around.
struct NumberPadTextView: View {
    @Bindable var vm: NumberPadViewModel
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
        HStack(alignment: .lastTextBaseline, spacing: 1) {
            Text(currencySymbol)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(Color.SubtitleText)

            Text(vm.amountString)
                .font(.system(size: fontSize, weight: .regular, design: .rounded))
                .foregroundStyle(Color.PrimaryText)
                .contentTransition(.numericText())
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .padding(.horizontal, vm.showsTrailingDelete ? 40 : 0)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            if vm.showsTrailingDelete {
                trailingDelete
            }
        }
    }

    @ViewBuilder
    private var trailingDelete: some View {
        Button {
            vm.deleteLast()
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.SubtitleText)
                .padding(7)
                .background(Circle().fill(.clear))
                .glassChip(in: Circle())
                .contentShape(Circle())
        }
        .disabled(vm.price == 0 && !vm.isEditingDecimal)
        .accessibilityLabel(Text("Delete"))
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
