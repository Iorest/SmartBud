//
//  SettingsNumberEntryView.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsNumberEntryView: View {
    @AppStorage("numberEntryType", store: .appGroup)
    var numberEntryType: Int = 1

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("currency", store: .appGroup) var currency:
        String = Locale.current.currency?.identifier ?? "USD"

    private var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    /// Single source of truth for the demo amount. `@State` so the view owns
    /// the VM's lifetime; `@Observable` gives automatic dependency tracking.
    @State private var vm = NumberPadViewModel(numberEntryType: 1, hapticType: 1)

    let options = [String.appLocalized(SettingsKey.numberEntryType1),
                   String.appLocalized(SettingsKey.numberEntryType2)]

    @Namespace var animation

    var body: some View {
        VStack(spacing: 10) {
            Text(String.appLocalized("Number Entry Method"))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(Color.PrimaryText)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button {
                        dismiss()
                    } label: {
                        SettingsBackButton()
                    }
                }

            HStack(spacing: 0) {
                ForEach(options.indices, id: \.self) { option in
                    let isSelected = numberEntryType == (option + 1)
                    Button {
                        withAnimation(.easeIn(duration: 0.15)) {
                            numberEntryType = (option + 1)
                            vm.numberEntryType = option + 1
                        }

                    } label: {
                        Text(options[option])
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .foregroundStyle(isSelected ? Color.PrimaryText : Color.SubtitleText)
                            .padding(6)
                            .padding(.horizontal, 8)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(Color.SecondaryBackground)
                                        .matchedGeometryEffect(id: "TAB1", in: animation)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(3)
            .background(
                Capsule().fill(Color.PrimaryBackground).shadow(
                    color: colorScheme == .light ? Color.Outline : Color.clear, radius: 6)
            )
            .overlay(
                Capsule().stroke(
                    colorScheme == .light ? Color.clear : Color.Outline.opacity(0.4), lineWidth: 1.3)
            )

            VStack(spacing: 10) {
                if numberEntryType == 1 {
                    Text(options[0])
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(Color.PrimaryText)

                    Text(String.appLocalized("Type the digits and the last two become cents automatically."))
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.SubtitleText)
                } else {
                    Text(options[1])
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(Color.PrimaryText)

                    Text(String.appLocalized("Enter whole numbers; tap the decimal point only when you need cents."))
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.SubtitleText)
                }
            }
            .padding(.horizontal, 25)

            Spacer(minLength: 0)

            NumberPadTextView(vm: vm, currencySymbol: currencySymbol)

            Spacer(minLength: 0)

            NumberPad(vm: vm) {
                submit()
            }
        }
        .modifier(SettingsSubviewModifier())
        .onAppear {
            // The demo pad used to start in mode 1 even when the stored
            // preference was mode 2, so the preview lied until the user tapped.
            vm.numberEntryType = numberEntryType
        }
        .onChange(of: numberEntryType) { _, new in
            vm.numberEntryType = new
        }
    }

    func submit() {
        // Haptic is fired by the VM's submit() via sensoryFeedback(.success).
        // We only need to clear the VM's local state here.
        vm.submit()
    }
}
