//
//  NewTransactionIntent.swift
//  dime
//
//  Created by Rafael Soh on 23/7/23.
//

import AppIntents
import Foundation
import SwiftUI

struct NewTransactionIntent: AppIntent {
    static let title: LocalizedStringResource = "New Transaction"

    static let description =
        IntentDescription(LocalizedStringResource("Log new transactions in a blink"))

    @Parameter(title: LocalizedStringResource("Type"), description: LocalizedStringResource("Type of the transaction"), requestValueDialog: IntentDialog(LocalizedStringResource("Would you like to log an income or expense?")))
    var income: TransactionType

    @Parameter(title: LocalizedStringResource("Amount"), description: LocalizedStringResource("Value of the transaction"), controlStyle: .field, inclusiveRange: (lowerBound: 0.01, upperBound: 100_000_000), requestValueDialog: IntentDialog(LocalizedStringResource("How much was transacted?")))
    var amount: Double

    @Parameter(title: LocalizedStringResource("Category"), description: LocalizedStringResource("Category associated with the transaction"), requestValueDialog: IntentDialog(LocalizedStringResource("What category does it come under?")))
    var incomeCategory: IncomeCategoryEntity?

    @Parameter(title: LocalizedStringResource("Category"), description: LocalizedStringResource("Category associated with the transaction"), requestValueDialog: IntentDialog(LocalizedStringResource("What category does it come under?")))
    var expenseCategory: ExpenseCategoryEntity?

    @Parameter(title: LocalizedStringResource("Note"))
    var note: String?

    @Parameter(title: LocalizedStringResource("Recurring Transaction"), default: false)
    var recurringTransaction: Bool

    @Parameter(title: LocalizedStringResource("Recurring Frequency"), default: .weekly)
    var recurringType: RepeatType

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        if expenseCategory == nil && incomeCategory == nil {
            if income == .expense {
                throw $expenseCategory.needsValueError()
            } else {
                throw $incomeCategory.needsValueError()
            }
        } else {
            if amount == 0 {
                throw $amount.needsValueError()
            }

            let repeatType: Int

            if !recurringTransaction {
                repeatType = 0
            } else {
                switch recurringType {
                case .daily:
                    repeatType = 1
                case .weekly:
                    repeatType = 2
                case .monthly:
                    repeatType = 3
                }
            }

            if income == .expense {
                if let unwrappedExpenseCategory = expenseCategory {
                    guard let category = CategoryViewModel.shared.findCategory(id: unwrappedExpenseCategory.id) else {
                        throw $expenseCategory.needsValueError()
                    }

                    let transaction = TransactionViewModel.shared.create(note: note ?? "", category: category, income: false, amount: amount, date: Date.now, repeatType: repeatType, repeatCoefficient: 1)

                    return .result(dialog: IntentDialog(LocalizedStringResource("Expense successfully logged."))) {
                        ShortcutTransactionView(transaction: transaction)
                    }
                } else {
                    throw $expenseCategory.needsValueError()
                }
            } else {
                if let unwrappedIncomeCategory = incomeCategory {
                    guard let category = CategoryViewModel.shared.findCategory(id: unwrappedIncomeCategory.id) else {
                        throw $incomeCategory.needsValueError()
                    }

                    let transaction = TransactionViewModel.shared.create(note: note ?? "", category: category, income: true, amount: amount, date: Date.now, repeatType: repeatType, repeatCoefficient: 1)

                    return .result(dialog: IntentDialog(LocalizedStringResource("Income successfully logged."))) {
                        ShortcutTransactionView(transaction: transaction)
                    }
                } else {
                    throw $incomeCategory.needsValueError()
                }
            }
        }
    }

    static var parameterSummary: some ParameterSummary {
        Switch(\NewTransactionIntent.$income) {
            Case(TransactionType.expense) {
                When(\NewTransactionIntent.$recurringTransaction, .equalTo, true, {
                    Summary("Log an \(\.$income) of \(\.$amount) under \(\.$expenseCategory)", table: "Localizable") {
                        \.$note
                        \.$recurringTransaction
                        \.$recurringType
                    }
                }, otherwise: {
                    Summary("Log an \(\.$income) of \(\.$amount) under \(\.$expenseCategory)", table: "Localizable") {
                        \.$note
                        \.$recurringTransaction
                    }
                })
            }
            Case(TransactionType.income) {
                When(\NewTransactionIntent.$recurringTransaction, .equalTo, true, {
                    Summary("Log an \(\.$income) of \(\.$amount) under \(\.$incomeCategory)", table: "Localizable") {
                        \.$note
                        \.$recurringTransaction
                        \.$recurringType
                    }
                }, otherwise: {
                    Summary("Log an \(\.$income) of \(\.$amount) under \(\.$incomeCategory)", table: "Localizable") {
                        \.$note
                        \.$recurringTransaction
                    }
                })
            }
            DefaultCase {
                Summary("Log an \(\.$income) of \(\.$amount)", table: "Localizable") {
                    \.$note
                }
            }
        }
    }
}

// income or expense

enum TransactionType: String {
    case income, expense
}

extension TransactionType: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: LocalizedStringResource("Type"))
    }

    static let caseDisplayRepresentations: [TransactionType: DisplayRepresentation] = [
        .income: DisplayRepresentation(title: LocalizedStringResource("income"),
                                       image: .init(systemName: "plus.square.fill")),
        .expense: DisplayRepresentation(title: LocalizedStringResource("expense"),
                                        image: .init(systemName: "minus.square.fill"))
    ]
}

enum RepeatType: String {
    case daily, weekly, monthly
}

extension RepeatType: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: LocalizedStringResource("Frequency"))
    }

    static let caseDisplayRepresentations: [RepeatType: DisplayRepresentation] = [
        .daily: DisplayRepresentation(title: LocalizedStringResource("Daily")),
        .weekly: DisplayRepresentation(title: LocalizedStringResource("Weekly")),
        .monthly: DisplayRepresentation(title: LocalizedStringResource("Monthly"))
    ]
}

struct ShortcutTransactionView: View {
    let transaction: TransactionModel

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"

    var transactionAmountString: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = currency

        if showCents {
            numberFormatter.maximumFractionDigits = 2
        } else {
            numberFormatter.maximumFractionDigits = 0
        }

        return numberFormatter.string(from: NSNumber(value: transaction.amount)) ?? "$0"
    }

    var body: some View {
        HStack(spacing: 12) {
            EmojiLogView(emoji: (transaction.category?.wrappedEmoji ?? ""),
                         colour: (transaction.category?.wrappedColour ?? ""), future: false)
                .frame(width: 35, height: 35, alignment: .center)
                .overlay(alignment: .bottomTrailing) {
                    if transaction.recurringType > 0 {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.DarkIcon)
                            .padding(3)
                            .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: 6))
                            .offset(x: 5, y: 5)
                    }
                }

            VStack(alignment: .leading) {
                Text(transaction.wrappedNote)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.PrimaryText)
                    .lineLimit(1)

                Text(transaction.wrappedDate, format: .dateTime.hour().minute())
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.SubtitleText)
                    .lineLimit(1)
            }
            Spacer()
            if transaction.income {
                Text("+\(transactionAmountString)")
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.IncomeGreen)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .layoutPriority(1)
            } else {
                Text("-\(transactionAmountString)")
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.PrimaryText)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
    }
}
