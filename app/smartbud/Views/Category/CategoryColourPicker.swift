import CoreHaptics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct ColourPickerView: View {
    var selectedColours: [String]

    @Binding var showMenu: Bool
    @Binding var selectedColour: String

    @Binding var showNativePicker: Bool

    @State var customMode: Bool = false
    @State var customSelectedColor = Color.white

    let columns = [
        GridItem(.fixed(40), spacing: 6),
        GridItem(.fixed(40), spacing: 6),
        GridItem(.fixed(40), spacing: 6),
        GridItem(.fixed(40), spacing: 6),
        GridItem(.fixed(40), spacing: 6),
        GridItem(.fixed(40))
    ]

    @AppStorage("colourScheme", store: .appGroup) var colourScheme: Int = 0

    @Environment(\.colorScheme) var systemColorScheme

    var darkMode: Bool {
        (colourScheme == 0 && systemColorScheme == .dark) || colourScheme == 2
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Color.colorArray, id: \.self) { suggestedColor in
                if suggestedColor == "#" {
                    Button {
                        showMenu = false
                        showNativePicker = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: SBRadius.chip)
                                .fill(
            AngularGradient(
                gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple, .pink]),
                center: .center
            )
        )

                            RoundedRectangle(cornerRadius: SBRadius.pill)
                                .fill(darkMode ? Color("AlwaysDarkBackground") : Color("AlwaysLightBackground"))
                                .padding(4)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(customSelectedColor)
                                .padding(8)

                            if customMode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(customSelectedColor.luminance() > 0.5 ? Color.black : Color.white)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.black)
                            }
                        }
                        .frame(width: 40, height: 40, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String.appLocalized("Custom color"))
                } else {
                    Button {
                        if !selectedColours.contains(suggestedColor) {
                            withAnimation {
                                selectedColour = suggestedColor
                                customMode = false
                                showMenu = false
                            }
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                            .fill(Color(hex: suggestedColor))
                            .frame(height: 40)
                            .opacity(selectedColours.contains(suggestedColor) ? 0.2 : 1)
                            .overlay {
                                if selectedColour == suggestedColor && !customMode {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color.black)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(6)
        .frame(width: 282)
        .background(
            RoundedRectangle(cornerRadius: SBRadius.chip)
                .fill(darkMode ? Color("AlwaysDarkBackground") : Color("AlwaysLightBackground"))
                .shadow(color: darkMode ? Color.clear : Color.gray.opacity(0.25), radius: 6)
        )
        .overlay(RoundedRectangle(cornerRadius: SBRadius.chip)
            .stroke(darkMode ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
    }

    init(selectedColor: Binding<String>, showMenu: Binding<Bool>, showNativePicker: Binding<Bool>,
         expenseCategories: [CategoryModel], toEdit: CategoryModel? = nil) {
        _selectedColour = selectedColor
        _showMenu = showMenu
        _showNativePicker = showNativePicker

        if !Color.colorArray.contains(selectedColor.wrappedValue) {
            _customMode = State(initialValue: true)
            _customSelectedColor = State(initialValue: Color(hex: selectedColor.wrappedValue))
        }

        var selectedColours = [String]()

        expenseCategories.forEach { category in
            selectedColours.append(category.wrappedColour)
        }

        if let editted = toEdit {
            selectedColours.removeAll { $0 == editted.wrappedColour }
        }

        self.selectedColours = selectedColours
    }
}

// Combines two .sensoryFeedback modifiers into a single .modifier() call so the
// trailing modifier chain on category alerts stays short enough for type inference.
struct ErrorSuccessHaptics: ViewModifier {
    let error: Int
    let success: Int

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.error, trigger: error)
            .sensoryFeedback(.success, trigger: success)
    }
}
