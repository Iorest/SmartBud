//
//  CurrencyRebaseService.swift
//  smartbud
//
//  Applies a `CurrencyRebase.Plan` to a SwiftData store: converts every frozen
//  base-currency amount, rebuilds the rate rows, and saves once. Kept separate
//  from the rate store so it can be tested with an in-memory container.
//

import Foundation
import SwiftData

@MainActor
enum CurrencyRebaseService {

    enum Failure: LocalizedError, Equatable {
        case sameCurrency
        case missingRate(String)
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .sameCurrency:
                String.appLocalized("This is already your base currency.")
            case .missingRate(let code):
                String.appFormatted(
                    "Add an exchange rate for %@ first (Settings → Currency → Exchange Rates), "
                        + "then switch the base currency.",
                    code)
            case .writeFailed:
                String.appLocalized("The switch could not be saved. Nothing was changed.")
            }
        }
    }

    struct Result: Equatable {
        let transactions: Int
        let budgets: Int
        let mainBudgets: Int
        let templates: Int
        let rates: Int

        var records: Int { transactions + budgets + mainBudgets + templates }
    }

    static func apply(
        _ plan: CurrencyRebase.Plan,
        context: ModelContext
    ) throws -> Result {
        let factor = plan.factor

        let transactions = (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? []
        for transaction in transactions {
            // An account without a currency is denominated in the base
            // currency (the app falls back to it), and a transaction without
            // an account is shown in the base too. Their `amount` is therefore
            // an old-base number as well: converting only `baseAmount` would
            // leave the row and the account balance in the old scale while
            // every total moved to the new one.
            let amountsAreInBase = (transaction.account?.currencyCode ?? "").isEmpty
            if amountsAreInBase {
                let converted = Money.cents(transaction.amount * factor)
                transaction.amount = Money.double(converted)
                transaction.baseAmount = Money.double(converted)
                continue
            }
            // Rows written before multi-currency support have no `baseAmount`;
            // their `amount` was already in the old base, so materialise it.
            let source = transaction.baseAmount ?? transaction.amount
            transaction.baseAmount = Money.double(Money.cents(source * factor))
        }

        let budgets = (try? context.fetch(FetchDescriptor<BudgetModel>())) ?? []
        for budget in budgets {
            budget.amount = Money.double(Money.cents(budget.amount * factor))
        }

        let mainBudgets = (try? context.fetch(FetchDescriptor<MainBudgetModel>())) ?? []
        for budget in mainBudgets {
            budget.amount = Money.double(Money.cents(budget.amount * factor))
        }

        let templates = (try? context.fetch(FetchDescriptor<TemplateTransactionModel>())) ?? []
        for template in templates {
            template.amount = Money.double(Money.cents(template.amount * factor))
        }

        let rates = (try? context.fetch(FetchDescriptor<CurrencyRate>())) ?? []
        let existingCodes = Set(rates.map { $0.code.uppercased() })
        for rate in rates {
            if let value = plan.rates[rate.code.uppercased()] {
                rate.rate = value
                rate.updatedAt = .now
            } else {
                context.delete(rate)
            }
        }
        for (code, value) in plan.rates where !existingCodes.contains(code) {
            context.insert(CurrencyRate(code: code, rate: value))
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw Failure.writeFailed
        }

        return Result(transactions: transactions.count, budgets: budgets.count,
                      mainBudgets: mainBudgets.count, templates: templates.count,
                      rates: plan.rates.count)
    }
}
