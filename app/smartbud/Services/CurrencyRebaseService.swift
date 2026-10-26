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
        let accounts: Int
        let transfers: Int
        let budgets: Int
        let mainBudgets: Int
        let templates: Int
        let rates: Int

        var records: Int {
            transactions + accounts + transfers + budgets + mainBudgets + templates
        }
    }

    static func apply(
        _ plan: CurrencyRebase.Plan,
        context: ModelContext
    ) throws -> Result {
        let factor = plan.factor

        let transactions = convertTransactions(context, factor: factor)
        let accounts = convertOpeningBalances(context, factor: factor)
        let transfers = convertTransfers(context, factor: factor)

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

        rebuildRates(plan, context: context)

        do {
            try context.save()
        } catch {
            context.rollback()
            throw Failure.writeFailed
        }

        return Result(transactions: transactions.count,
                      accounts: accounts.filter { $0.currencyCode.isEmpty }.count,
                      transfers: transfers.count,
                      budgets: budgets.count,
                      mainBudgets: mainBudgets.count,
                      templates: templates.count,
                      rates: plan.rates.count)
    }

    /// Frozen base amounts, plus the row amount when the row is denominated in
    /// the base (no account, or an account that follows it).
    private static func convertTransactions(_ context: ModelContext,
                                            factor: Double) -> [TransactionModel] {
        let transactions = (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? []
        for transaction in transactions {
            let amountsAreInBase = (transaction.account?.currencyCode ?? "").isEmpty
            if amountsAreInBase {
                let converted = Money.double(Money.cents(transaction.amount * factor))
                transaction.amount = converted
                transaction.baseAmount = converted
                continue
            }
            // Rows written before multi-currency support have no `baseAmount`;
            // their `amount` was already in the old base, so materialise it.
            let source = transaction.baseAmount ?? transaction.amount
            transaction.baseAmount = Money.double(Money.cents(source * factor))
        }
        return transactions
    }

    /// An account without a currency keeps its balance in the base currency;
    /// leaving it on the old scale made the balance off by the factor.
    private static func convertOpeningBalances(_ context: ModelContext,
                                               factor: Double) -> [AccountModel] {
        let accounts = (try? context.fetch(FetchDescriptor<AccountModel>())) ?? []
        for account in accounts where account.currencyCode.isEmpty {
            account.openingBalance = Money.double(Money.cents(account.openingBalance * factor))
        }
        return accounts
    }

    /// Transfers carry one amount per side; each side moves only when that
    /// account follows the base currency.
    private static func convertTransfers(_ context: ModelContext,
                                         factor: Double) -> [TransferModel] {
        let transfers = (try? context.fetch(FetchDescriptor<TransferModel>())) ?? []
        for transfer in transfers {
            let sourceInBase = (transfer.source?.currencyCode ?? "").isEmpty
            let destinationInBase = (transfer.destination?.currencyCode ?? "").isEmpty
            if sourceInBase {
                transfer.amount = Money.double(Money.cents(transfer.amount * factor))
                if transfer.fee > 0 {
                    transfer.fee = Money.double(Money.cents(transfer.fee * factor))
                }
            }
            if destinationInBase, transfer.destinationAmount > 0 {
                transfer.destinationAmount = Money.double(
                    Money.cents(transfer.destinationAmount * factor))
            }
        }
        return transfers
    }

    /// Re-expresses the rate table against the new base.
    private static func rebuildRates(_ plan: CurrencyRebase.Plan, context: ModelContext) {
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
    }
}
