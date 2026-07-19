//
//  SettingsNumberEntryView.swift
//  dime
//
//  Created by Rafael Soh on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsNumberEntryView: View {
    @AppStorage("numberEntryType", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
    var numberEntryType: Int = 1

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("currency", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var currency:
        String = Locale.current.currency?.identifier ?? "USD"

    private var currencySymbol: String {
        return Locale.current.localizedCurrencySymbol(forCurrencyCode: currency)!
    }

    /// Single source of truth for the demo amount. `@State` so the view owns
    /// the VM's lifetime; `@Observable` gives automatic dependency tracking.
    @State private var vm = NumberPadViewModel(numberEntryType: 1, hapticType: 1)

    let options = ["Type 1", "Type 2"]

    @Namespace var animation

    var body: some View {
        VStack(spacing: 10) {
            Text("Number Entry Method")
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
                    Text(LocalizedStringKey(options[option]))
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
                        .onTapGesture {
                            DispatchQueue.main.async {
                                withAnimation(.easeIn(duration: 0.15)) {
                                    numberEntryType = (option + 1)
                                    vm.numberEntryType = option + 1
                                }
                            }
                        }
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
                    Text("\"Pre-dotted\"")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(Color.PrimaryText)

                    Text("If you're too lazy to add a decimal point, I gotchu covered.")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.SubtitleText)
                } else {
                    Text("\"Cent-less\"")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(Color.PrimaryText)

                    Text("If your transactions usually amount to whole numbers - this one is for you.")
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
