import Foundation
import SwiftUI
import SwiftData

struct BudgetStepperView: View {
    @Query private var transactions: [TransactionModel]

    @Binding var date: Date
    var firstDate: Date {
        if transactions.isEmpty {
            return Date.now
        } else {
            return transactions[0].day ?? Date.now
        }
    }

    var endDate: Date {
        if type == 1 {
            return Calendar.current.date(byAdding: .day, value: 1, to: date)!
        } else if type == 2 {
            return Calendar.current.date(byAdding: .day, value: 6, to: date)!
        } else if type == 3 {
            let holdingDate = Calendar.current.date(byAdding: .month, value: 1, to: date)!
            return Calendar.current.date(byAdding: .day, value: -1, to: holdingDate)!
        } else if type == 4 {
            let holdingDate = Calendar.current.date(byAdding: .year, value: 1, to: date)!
            return Calendar.current.date(byAdding: .day, value: -1, to: holdingDate)!
        }

        return startDate
    }

    let startDate: Date
    let type: Int

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        if type == 1 {
            dateFormatter.dateFormat = "d MMM yyyy"
            return dateFormatter.string(from: date)
        } else if type == 4 {
            dateFormatter.dateFormat = "d MMM yy"
            return dateFormatter.string(from: date) + " - " + dateFormatter.string(from: endDate)
        } else {
            dateFormatter.dateFormat = "d MMM"
            return dateFormatter.string(from: date) + " - " + dateFormatter.string(from: endDate)
        }
    }

    var body: some View {
        HStack {
            StepperButtonView(left: true, disabled: date <= firstDate) {
                if date > firstDate {
                    if type == 1 {
                        date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
                    } else if type == 2 {
                        date = Calendar.current.date(byAdding: .day, value: -7, to: date)!
                    } else if type == 3 {
                        date = Calendar.current.date(byAdding: .month, value: -1, to: date)!
                    } else if type == 4 {
                        date = Calendar.current.date(byAdding: .year, value: -1, to: date)!
                    }
                }
            }

            Spacer()

            Text(dateString)
                .font(.system(.title3, design: .rounded).weight(.bold))

            Spacer()

            StepperButtonView(left: false, disabled: date == startDate) {
                if date < startDate {
                    if type == 1 {
                        date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
                    } else if type == 2 {
                        date = Calendar.current.date(byAdding: .day, value: 7, to: date)!
                    } else if type == 3 {
                        date = Calendar.current.date(byAdding: .month, value: 1, to: date)!
                    } else if type == 4 {
                        date = Calendar.current.date(byAdding: .year, value: -1, to: date)!
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    init(category: CategoryModel?, date: Binding<Date>, startDate: Date, budgetType: Int) {
        if let unwrappedCategory = category {
            let categoryId = unwrappedCategory.id
            _transactions = Query(filter: #Predicate<TransactionModel> {
                $0.category?.id == categoryId
            }, sort: [SortDescriptor(\.day)])
        } else {
            _transactions = Query(sort: [SortDescriptor(\.day)])
        }

        _date = date

        self.startDate = startDate
        type = budgetType
    }
}

// MARK: - Arced Text (replaces CrookedText)
struct ArcedText: View {
    let text: String
    let radius: CGFloat

    @Environment(\.font) private var font

    var body: some View {
        Canvas { context, size in
            let resolvedFont = font ?? .footnote
            let resolvedColor: Color = .primary
            let midX = size.width / 2
            let midY = size.height
            let center = CGPoint(x: midX, y: midY)
            let charCount = text.count
            let totalAngle: CGFloat = .pi / 2.5
            let startAngle: CGFloat = .pi + totalAngle / 2
            let spacing: CGFloat = charCount > 1 ? totalAngle / CGFloat(charCount - 1) : 0

            for (index, character) in text.enumerated() {
                let angle = startAngle + CGFloat(index) * spacing
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                let charText = Text(String(character)).font(resolvedFont).foregroundStyle(resolvedColor)
                let resolved = context.resolve(charText)
                let charSize = resolved.measure(in: .zero)
                context.draw(resolved, at: CGPoint(x: x - charSize.width / 2, y: y - charSize.height / 2))
            }
        }
    }
}
