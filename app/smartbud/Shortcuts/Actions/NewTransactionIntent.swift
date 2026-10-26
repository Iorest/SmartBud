//
//  NewTransactionIntent.swift
//  smartbud
//
//  Created by Iorest on 23/7/23.
//

import AppIntents
import Foundation
import SwiftUI

struct NewTransactionIntent: AppIntent {
    static let title: LocalizedStringResource = "New Transaction"

    static let description =
        IntentDescription(LocalizedStringResource("Log new transactions in a blink"))

    @Parameter(
        title: LocalizedStringResource("Type"),
        description: LocalizedStringResource("Type of the transaction"),
        requestValueDialog: IntentDialog(LocalizedStringResource("Would you like to log an income or expense?"))
    )
    var income: TransactionType

    @Parameter(
        title: LocalizedStringResource("Amount"),
        description: LocalizedStringResource("Value of the transaction"),
        controlStyle: .field,
        inclusiveRange: (lowerBound: 0.01, upperBound: 100_000_000),
        requestValueDialog: IntentDialog(LocalizedStringResource("How much was transacted?"))
    )
    var amount: Double

    @Parameter(
        title: LocalizedStringResource("Category"),
        description: LocalizedStringResource("Category associated with the transaction"),
        requestValueDialog: IntentDialog(LocalizedStringResource("What category does it come under?"))
    )
    var incomeCategory: IncomeCategoryEntity?

    @Parameter(
        title: LocalizedStringResource("Category"),
        description: LocalizedStringResource("Category associated with the transaction"),
        requestValueDialog: IntentDialog(LocalizedStringResource("What category does it come under?"))
    )
    var expenseCategory: ExpenseCategoryEntity?

    @Parameter(title: LocalizedStringResource("Note"))
    var note: String?

    @Parameter(title: LocalizedStringResource("Recurring Transaction"), default: false)
    var recurringTransaction: Bool

    @Parameter(title: LocalizedStringResource("Recurring Frequency"), default: .weekly)
    var recurringType: RepeatType

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard !AppLockGate.isLocked else { throw AppLockError.locked }

        guard expenseCategory != nil || incomeCategory != nil else {
            throw income == .expense
                ? $expenseCategory.needsValueError()
                : $incomeCategory.needsValueError()
        }
        guard amount != 0 else { throw $amount.needsValueError() }

        let repeatType = self.repeatType
        if income == .expense {
            return try log(id: expenseCategory?.id, isExpense: true, repeatType: repeatType)
        }
        return try log(id: incomeCategory?.id, isExpense: false, repeatType: repeatType)
    }

    /// Maps the picker value onto the stored recurrence type.
    @MainActor
    private var repeatType: Int {
        guard recurringTransaction else { return 0 }
        switch recurringType {
        case .daily: return 1
        case .weekly: return 2
        case .monthly: return 3
        }
    }

    /// Resolves the category and logs the transaction, returning the snippet.
    @MainActor
    private func log(id: UUID?, isExpense: Bool,
                     repeatType: Int) throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let id, let category = CategoryViewModel.shared.findCategory(id: id) else {
            throw isExpense ? $expenseCategory.needsValueError() : $incomeCategory.needsValueError()
        }

        // The intent can run with no UI (Siri, widget, cold start), so the
        // cached account list is empty unless it is loaded here — the default
        // account then came back nil and the entry moved no balance. The rate
        // cache matters too: baseAmount is computed from it.
        AccountViewModel.shared.load()
        let account = AccountViewModel.shared.defaultAccount(
            lastUsedID: UserDefaults.appGroup.string(forKey: "lastAccountID"))
        guard let transaction = TransactionViewModel.shared.create(TransactionEdit(
            note: note ?? "",
            category: category,
            account: account,
            income: !isExpense,
            amount: amount,
            date: Date.now,
            repeatType: repeatType,
            repeatCoefficient: 1
        )) else {
            throw TransactionIntentError.saveFailed
        }
        let message: LocalizedStringResource = isExpense
            ? "Expense successfully logged."
            : "Income successfully logged."
        return .result(dialog: IntentDialog(message)) {
            ShortcutTransactionView(transaction: transaction)
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
        numberFormatter.locale = Locale.appLocale
        numberFormatter.numberStyle = .currency
        // `amount` is in the account's currency; the base symbol made €120
        // show as "¥120". Fall back to the base only for rows without one.
        numberFormatter.currencyCode = transaction.account?.resolvedCurrencyCode ?? currency

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
                            .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: SBRadius.pill))
                            .offset(x: 5, y: 5)
                    }
                }

            VStack(alignment: .leading) {
                Text(transaction.wrappedNote)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.PrimaryText)
                    .lineLimit(1)

                Text(transaction.wrappedDate, format: .dateTime.hour().minute())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.SubtitleText)
                    .lineLimit(1)
            }
            Spacer()
            if transaction.income {
                Text("+\(transactionAmountString)")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color.IncomeGreen)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .layoutPriority(1)
            } else {
                Text("-\(transactionAmountString)")
                    .font(.system(size: 19, weight: .medium))
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

/// Failures the Shortcuts action can report. The store rolls a failed write
/// back, so claiming success would leave the shortcut's caller believing a
/// row exists that does not.
enum TransactionIntentError: LocalizedError {
    case saveFailed

    var errorDescription: String? {
        String.appLocalized("无法保存更改，请稍后重试。")
    }
}
