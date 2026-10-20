import Foundation
import SwiftUI

struct RecurringPickerView: View {
    @Namespace var animation
    @Binding var repeatType: Int
    @Binding var repeatCoefficient: Int
    @Binding var showMenu: Bool

    @Binding var showPicker: Bool

    let stringArray = ["none", "daily", "weekly", "monthly"]

    @AppStorage("bottomEdge", store: .appGroup)
    var bottomEdge: Double = 15

    @AppStorage("colourScheme", store: .appGroup)
    var colourScheme: Int = 0

    @Environment(\.colorScheme) var systemColorScheme

    var darkMode: Bool {
        (colourScheme == 0 && systemColorScheme == .dark) || colourScheme == 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(stringArray.enumerated()), id: \.element) { index, string in
                HStack {
                    Text(LocalizedStringKey(string))
                        .font(.body.weight(.medium))

                        .lineLimit(1)
                    Spacer()

                    if repeatType == index && repeatCoefficient == 1 {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.medium))

                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(5)
                .background {
                    if repeatType == index && repeatCoefficient == 1 {
                        RoundedRectangle(cornerRadius: SBRadius.pill)
                            .fill(
                                darkMode
                                ? Color("AlwaysDarkSecondaryBackground") : Color("AlwaysLightSecondaryBackground")
                            )
                            .matchedGeometryEffect(id: "TAB", in: animation)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if repeatType == index && repeatCoefficient == 1 {
                        showMenu = false
                    } else {
                        withAnimation(.easeIn(duration: 0.15)) {
                            repeatType = index
                            repeatCoefficient = 1
                        }

                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(400))
                            showMenu = false
                        }
                    }
                }
            }

            HStack {
                if repeatCoefficient == 1 {
                    Text(String.appLocalized("custom"))
                } else {
                    if repeatType == 1 {
                        Text("\(repeatCoefficient) \(String.appLocalized("days"))")
                    } else if repeatType == 2 {
                        Text("\(repeatCoefficient) \(String.appLocalized("weeks"))")
                    } else if repeatType == 3 {
                        Text("\(repeatCoefficient) \(String.appLocalized("months"))")
                    }
                }

                Spacer()

                if repeatCoefficient > 1 {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.medium))

                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.body.weight(.medium))

            .padding(5)
            .background {
                if repeatCoefficient > 1 {
                    RoundedRectangle(cornerRadius: SBRadius.pill)
                        .fill(
                            darkMode
                            ? Color("AlwaysDarkSecondaryBackground") : Color("AlwaysLightSecondaryBackground")
                        )
                        .matchedGeometryEffect(id: "TAB", in: animation)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if repeatCoefficient == 1 {
                    repeatCoefficient = 2
                    repeatType = 2

                }

                withAnimation {
                    showPicker = true
                }
            }
            .onChange(of: showPicker) { _, newValue in
                // holdingType != repeatType || holdingCoefficient != repeatCoefficient
                if !newValue {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(400))
                        showMenu = false
                    }
                }
            }
        }
        .foregroundStyle(darkMode ? Color("AlwaysLightBackground") : Color("AlwaysDarkBackground"))
        .padding(4)
        .frame(width: 150)
        .background(
            RoundedRectangle(cornerRadius: SBRadius.chip).fill(
                darkMode ? Color("AlwaysDarkBackground") : Color("AlwaysLightBackground")
            ).shadow(color: darkMode ? Color.clear : Color.gray.opacity(0.25), radius: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.chip).stroke(
                darkMode ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
    }
}
