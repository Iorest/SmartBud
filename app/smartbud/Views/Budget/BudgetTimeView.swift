import Foundation
import SwiftUI
import SwiftData

/// Budget detail (category or overall). Both used to be separate 290-line
/// views that differed only in the model type, the header title and the tint.
struct BudgetTimeView: View {
    let amount: Double
    let type: Int
    /// Period start stored on the budget (not the day being browsed).
    let budgetStart: Date
    let endDate: Date
    /// nil for the overall budget.
    let category: CategoryModel?
    let title: String
    let emoji: String?

    private var tintColor: Color {
        guard let category else { return Color.accentColor }
        return Color(hex: category.wrappedColour)
    }

    var budgetAmount: Double {
        return amount
    }

    var budgetType: Int {
        return type
    }

    @State var startDate = Date.now

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        if budgetType == 1 {
            dateFormatter.dateFormat = "d MMM yyyy"
            return dateFormatter.string(from: startDate)
        } else if budgetType == 2 {
            let endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? Date.now
            dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")
            return dateFormatter.string(from: startDate) + " - " + dateFormatter.string(from: endDate)
        } else if budgetType == 3 {
            var endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
            endDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
            dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")
            return dateFormatter.string(from: startDate) + " - " + dateFormatter.string(from: endDate)
        } else if budgetType == 4 {
            var endDate = Calendar.current.date(byAdding: .year, value: 1, to: startDate)!
            endDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
            dateFormatter.dateFormat = "d MMM yy"
            return dateFormatter.string(from: startDate) + " - " + dateFormatter.string(from: endDate)
        } else {
            return ""
        }
    }

    @State var totalSpent = 0.0

    var timeLeft: String {
        let calendar = Calendar.current

        if budgetType == 1 {
            let components = calendar.dateComponents([.hour], from: budgetStart, to: Date.now)
            return String.appFormatted("%lld hours left", 24 - (components.hour ?? 0))
        } else {
            return String.appFormatted("%lld days left", daysLeftNumber)
        }
    }

    var subtitleText: String {
        if budgetStart == startDate {
            return timeLeft
        } else {
            return dateString
        }
    }

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var difference: Double {
        abs(budgetAmount - totalSpent)
    }

    var differenceSubtitle: String {
        if budgetAmount >= totalSpent {
            if startDate == budgetStart {
                if budgetType == 1 {
                    return String.appLocalized("left today")
                } else if budgetType == 2 {
                    return String.appLocalized("left this week")
                } else if budgetType == 3 {
                    return String.appLocalized("left this month")
                } else if budgetType == 4 {
                    return String.appLocalized("left this year")
                } else {
                    return ""
                }
            } else {
                if budgetType == 1 {
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale.appLocale
                    dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")
                    return String.appFormatted("left on %@", dateFormatter.string(from: startDate))
                } else if budgetType == 2 {
                    let components = Calendar.current.dateComponents([.day], from: startDate, to: budgetStart)
                    let weekString = String.appFormatted("%lld weeks ago", (components.day ?? 0) / 7)
                    return String.appFormatted("left %@", weekString)
                } else if budgetType == 3 {
                    let components = Calendar.current.dateComponents([.month], from: startDate, to: budgetStart)
                    let monthString = String.appFormatted("%lld months ago", components.month ?? 0)
                    return String.appFormatted("left %@", monthString)
                } else if budgetType == 4 {
                    let components = Calendar.current.dateComponents([.year], from: startDate, to: budgetStart)
                    let yearString = String.appFormatted("%lld years ago", components.year ?? 0)
                    return String.appFormatted("left %@", yearString)
                } else {
                    return ""
                }
            }
        } else {
            if startDate == budgetStart {
                if budgetType == 1 {
                    return String.appLocalized("over today")
                } else if budgetType == 2 {
                    return String.appLocalized("over this week")
                } else if budgetType == 3 {
                    return String.appLocalized("over this month")
                } else if budgetType == 4 {
                    return String.appLocalized("over this year")
                } else {
                    return ""
                }
            } else {
                if budgetType == 1 {
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale.appLocale
                    dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")
                    return String.appFormatted("over on %@", dateFormatter.string(from: startDate))
                } else if budgetType == 2 {
                    let components = Calendar.current.dateComponents([.day], from: startDate, to: budgetStart)
                    let weekString = String.appFormatted("%lld weeks ago", (components.day ?? 0) / 7)
                    return String.appFormatted("over %@", weekString)
                } else if budgetType == 3 {
                    let components = Calendar.current.dateComponents([.month], from: startDate, to: budgetStart)
                    let monthString = String.appFormatted("%lld months ago", components.month ?? 0)
                    return String.appFormatted("over %@", monthString)
                } else if budgetType == 4 {
                    let components = Calendar.current.dateComponents([.year], from: startDate, to: budgetStart)
                    let yearString = String.appFormatted("%lld years ago", components.year ?? 0)
                    return String.appFormatted("over %@", yearString)
                } else {
                    return ""
                }
            }
        }
    }

    // for week, month, year only

    var daysLeftNumber: Int {
        let calendar = Calendar.current

        if budgetType == 1 {
            return 0
        } else if budgetType == 2 {
            let components = calendar.dateComponents([.day], from: budgetStart, to: Date.now)
            return 7 - (components.day ?? 0)
        } else if budgetType == 3 {
            let components1 = calendar.dateComponents([.day], from: budgetStart, to: endDate)
            let numberOfDays = components1.day ?? 0
            let components2 = calendar.dateComponents([.day], from: budgetStart, to: Date.now)
            let numberOfDaysPast = components2.day ?? 0

            return Int(numberOfDays - numberOfDaysPast)
        } else if budgetType == 4 {
            let components1 = calendar.dateComponents([.day], from: budgetStart, to: endDate)
            let numberOfDays = components1.day ?? 0
            let components2 = calendar.dateComponents([.day], from: budgetStart, to: Date.now)
            let numberOfDaysPast = components2.day ?? 0
            return Int(numberOfDays - numberOfDaysPast)
        } else {
            return 0
        }
    }

    var leftPerDay: Double {
        // The last day of a period has 0 days left; dividing by it would
        // render "∞ per day".
        guard budgetType >= 2, daysLeftNumber > 0 else { return 0 }
        return (budgetAmount - totalSpent) / Double(daysLeftNumber)
    }

    var showExtraDetails: Bool {
        if budgetType >= 2 {
            return budgetStart == startDate && totalSpent < budgetAmount && daysLeftNumber != 1
        } else {
            return false
        }
    }

}

extension BudgetTimeView {

    var body: some View {
        VStack(spacing: 20) {
            // budget name and emoji and time left
            VStack(spacing: 10) {
                HStack(spacing: 7.5) {
                    if let emoji {
                        Text(emoji)
                            .font(.subheadline)
                    }
                    Text(title)
                        .font(.title3.weight(.medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.PrimaryText)

                Text(subtitleText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)
                    .padding(4)
                    .padding(.horizontal, 7)
                    .background(Color.SecondaryBackground, in: Capsule())
            }
            .padding(.bottom, 15)

            // amount left and averages

            if budgetType >= 2 {
                HStack(alignment: .top, spacing: 15) {
                    VStack(alignment: showExtraDetails ? .leading : .center, spacing: -4) {
                        BudgetDollarView(amount: difference, red: totalSpent >= budgetAmount, scale: 3)

                        Text(differenceSubtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.SubtitleText)
                    }
                    .frame(maxWidth: .infinity, alignment: showExtraDetails ? .leading : .center)

                    if showExtraDetails {
                        VStack(alignment: .trailing, spacing: -4) {
                            BudgetDollarView(amount: leftPerDay, scale: 3)

                            Text("left each day")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.SubtitleText)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 25)
            } else {
                VStack(spacing: -4) {
                    BudgetDollarView(amount: difference, red: totalSpent >= budgetAmount, scale: 3)

                    Text(differenceSubtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.SubtitleText)
                }
                .padding(.horizontal, 25)
            }

            // bar graph

            VStack(spacing: SBSpace.extraSmall) {
                ProgressView(value: min(max(totalSpent / max(budgetAmount, 1), 0), 1))
                    .tint(totalSpent >= budgetAmount ? Color.AlertRed : tintColor)
                    .accessibilityLabel(String.appLocalized("Spent"))
                    .accessibilityValue("\(Int(round((totalSpent / max(budgetAmount, 1)) * 100)))%")

                HStack {
                    Text("\(currencySymbol)\(totalSpent.formatted(.number.precision(.fractionLength(2))))")
                    Spacer()
                    Text("\(currencySymbol)\(budgetAmount.formatted(.number.precision(.fractionLength(2))))")
                }
                .frame(maxWidth: .infinity)
                .font(.caption)
                .foregroundStyle(Color.SubtitleText)
            }
            .padding(.bottom, budgetType >= 2 ? 20 : 0)
            .padding(.horizontal, 25)

            if budgetType == 1 {
                Divider()
                    .overlay(Color.Outline)
                    .padding(.horizontal, 25)
            }

            ScrollView(showsIndicators: false) {
                if budgetType == 1 {
                    FilteredCategoryDayBudgetView(category: category, day: startDate, totalSpent: $totalSpent)
                        .padding(.horizontal, 15)
                } else {
                    FilteredBudgetView(
                        category: category,
                        startDate: startDate,
                        totalSpent: $totalSpent,
                        type: budgetType - 1
                    )
                        .padding(.horizontal, 15)
                }
            }
            .frame(maxHeight: .infinity)

            BudgetStepperView(category: category, date: $startDate, startDate: budgetStart, budgetType: budgetType)
                .padding(.horizontal, 25)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            startDate = budgetStart
        }
    }
}
