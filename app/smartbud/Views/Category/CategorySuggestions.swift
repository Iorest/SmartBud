import CoreHaptics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct SuggestedCategoriesView: View {
    let income: Bool
    @Environment(CategoryViewModel.self) var categoryVM

    var categories: [CategoryModel] {
        income ? categoryVM.incomeCategories : categoryVM.expenseCategories
    }

    var nameArray: [String] {
        var emptyArray = [String]()

        categories.forEach { category in
            emptyArray.append(category.wrappedName)
        }

        return emptyArray
    }

    var emojiArray: [String] {
        var emptyArray = [String]()

        categories.forEach { category in
            emptyArray.append(category.wrappedEmoji)
        }

        return emptyArray
    }

    var suggestions: [SuggestedCategory] {
        var holding = [SuggestedCategory]()

        if income {
            SuggestedCategory.incomes.forEach { category in
                if !nameArray.contains(category.name) && !emojiArray.contains(category.emoji) {
                    holding.append(category)
                }
            }
        } else {
            SuggestedCategory.expenses.forEach { category in
                if !nameArray.contains(category.name) && !emojiArray.contains(category.emoji) {
                    holding.append(category)
                }
            }
        }

        return holding
    }

    @State private var availableColours: [String] = Color.colorArray
    @State private var selectedColour = "1"
    @State private var lightHaptic: Int = 0

    var body: some View {
        Group {
            if !suggestions.isEmpty {
                Section(header: Text(String.appLocalized("SUGGESTED")).foregroundStyle(Color.SubtitleText)) {
                    ForEach(suggestions, id: \.self) { category in
                        HStack(spacing: 8) {
                            Text(category.emoji)
                                .font(.subheadline)

                            Text(LocalizedStringKey(category.name))
                                .font(.body)

                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "plus")
                                .font(.subheadline.weight(.semibold))

                                .foregroundStyle(Color.SubtitleText)
                                .padding(4)
                                .background(Color.SecondaryBackground, in: Circle())
                                .contentShape(Circle())
                        }
                        .padding(.vertical, 5)
                        .foregroundStyle(Color.PrimaryText)
                        .listRowBackground(Color.SettingsBackground)
                        .listRowSeparatorTint(Color.Outline)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // double check

                            let validation = categoryVM.validate(name: category.name,
                                                         emoji: category.emoji,
                                                         income: income)
                            let outcome = validation.error
                            let order = validation.order

                            if outcome != .none {
                                return
                            }

                            lightHaptic &+= 1

                            if !income {
                                _ = categoryVM.create(
                                    name: NSLocalizedString(category.name, comment: "category name"),
                                    emoji: category.emoji,
                                    colour: selectedColour,
                                    income: false,
                                    order: order
                                )

                                availableColours = Color.colorArray
                                categories.forEach { category in
                                    if availableColours.contains(category.wrappedColour) {
                                        availableColours.removeAll { $0 == category.wrappedColour }
                                    }
                                }

                                if availableColours.isEmpty {
                                    selectedColour = "#FFFFFF"
                                } else {
                                    selectedColour = availableColours[0]
                                }
                            } else {
                                _ = categoryVM.create(
                                    name: NSLocalizedString(category.name, comment: "category name"),
                                    emoji: category.emoji,
                                    colour: "#76FBB0",
                                    income: true,
                                    order: order
                                )
                            }
                        }
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .onAppear {
                    if !income {
                        categories.forEach { category in
                            if availableColours.contains(category.wrappedColour) {
                                availableColours.removeAll { $0 == category.wrappedColour }
                            }
                        }

                        if availableColours.isEmpty {
                            selectedColour = "#FFFFFF"
                        } else {
                            selectedColour = availableColours[0]
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lightHaptic)
    }

    init(income: Bool) {
        self.income = income
    }
}

#if !os(macOS)
class UIEmojiTextField: UITextField {
    override var textInputMode: UITextInputMode? {
        .activeInputModes.first(where: { $0.primaryLanguage == "emoji" })
    }

    override func caretRect(for _: UITextPosition) -> CGRect {
        return CGRect.zero
    }
}
#endif
