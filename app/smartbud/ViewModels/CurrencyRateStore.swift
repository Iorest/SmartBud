//
//  CurrencyRateStore.swift
//  smartbud
//
//  Holds the user's exchange rates (one row per foreign currency) and answers
//  "what is this amount in my base currency". Loaded once at launch; rates are
//  written from Settings → Currency → Exchange rates.
//

import Foundation
import Observation
import SwiftData
import WidgetKit

@MainActor
@Observable
final class CurrencyRateStore {
    static let shared = CurrencyRateStore()
    private let repo = DataRepository.shared

    private(set) var records: [CurrencyRate] = []
    private(set) var rates: [String: Double] = [:]

    /// The app-wide base currency, stored by `@AppStorage("currency")`.
    var baseCurrency: String { AppBaseCurrency.code }

    func load() {
        records = repo.fetch(CurrencyRate.self, sort: [SortDescriptor(\.code)])
        var map: [String: Double] = [:]
        for record in records where !record.code.isEmpty {
            map[record.code.uppercased()] = record.rate
        }
        rates = map
    }

    func rate(for code: String) -> Double {
        CurrencyConversion.rate(for: code, base: baseCurrency, rates: rates)
    }

    /// True when the currency has no rate row yet and is not the base currency.
    func needsRate(for code: String) -> Bool {
        let target = code.uppercased()
        return !target.isEmpty && target != baseCurrency.uppercased() && rates[target] == nil
    }

    func setRate(_ value: Double, for code: String) {
        let target = code.uppercased()
        guard !target.isEmpty, target != baseCurrency.uppercased(),
              value > 0, value.isFinite else { return }

        if let existing = records.first(where: { $0.code.uppercased() == target }) {
            existing.rate = value
            existing.updatedAt = .now
        } else {
            repo.insert(CurrencyRate(code: target, rate: value))
        }
        repo.save()
        load()
    }

    /// How many units of `target` one unit of `source` buys, derived from both
    /// currencies' rates against the base currency.
    func rate(from source: String, to target: String) -> Double {
        let sourceRate = rate(for: source)
        let targetRate = rate(for: target)
        guard targetRate > 0 else { return 1 }
        return sourceRate / targetRate
    }

    /// Pulls reference rates for `codes` from the public service and stores
    /// them. Codes the service does not publish keep their existing rate.
    /// Returns how many currencies were refreshed.
    @discardableResult
    func refreshRates(for codes: [String], service: ExchangeRateService = ExchangeRateService()) async throws -> Int {
        let base = baseCurrency
        let wanted = Set(codes.map { $0.uppercased() }).subtracting([base.uppercased(), ""])
        guard !wanted.isEmpty else { return 0 }

        let fetched = try await service.fetch(base: base)
        var updated = 0

        for code in wanted {
            guard let value = fetched[code], value > 0, value.isFinite else { continue }
            // Six decimals keeps small rates (e.g. 1 VND) usable.
            let rounded = (value * 1_000_000).rounded() / 1_000_000
            if let existing = records.first(where: { $0.code.uppercased() == code }) {
                existing.rate = rounded
                existing.updatedAt = .now
            } else {
                repo.insert(CurrencyRate(code: code, rate: rounded))
            }
            updated += 1
        }

        if updated > 0 {
            repo.save()
            load()
        }
        return updated
    }

    func convertToBase(_ amount: Double, from code: String) -> Double {
        CurrencyConversion.convertRounded(
            amount, from: code, to: baseCurrency, rates: rates)
    }

    // MARK: - Base currency switch

    typealias RebaseError = CurrencyRebaseService.Failure

    struct RebasePreview: Equatable {
        let oldBase: String
        let newBase: String
        /// 1 old-base unit expressed in the new base.
        let factor: Double
        /// Rows whose stored amount will be converted.
        let recordCount: Int
    }

    /// Everything a base-currency switch would do, without touching the store.
    func rebasePreview(to newBase: String) -> Result<RebasePreview, RebaseError> {
        load()
        switch CurrencyRebase.plan(from: baseCurrency, to: newBase, rates: rates) {
        case .failure(.sameCurrency):
            return .failure(.sameCurrency)
        case .failure(.missingRate(let code)):
            return .failure(.missingRate(code))
        case .success(let plan):
            let transactions = repo.fetch(TransactionModel.self).count
            let budgets = repo.fetch(BudgetModel.self).count
            let mainBudgets = repo.fetch(MainBudgetModel.self).count
            let templates = repo.fetch(TemplateTransactionModel.self).count
            return .success(RebasePreview(oldBase: plan.oldBase, newBase: plan.newBase,
                                          factor: plan.factor,
                                          recordCount: transactions + budgets + mainBudgets + templates))
        }
    }

    /// Converts every frozen base-currency amount and the whole rate table, then
    /// switches the setting — in one save, so a failure leaves the store as it
    /// was. See `CurrencyRebase` for the maths and `CurrencyRebaseService` for
    /// the row-by-row part.
    @discardableResult
    func rebase(to newBase: String) throws -> RebasePreview {
        load()
        let plan: CurrencyRebase.Plan
        switch CurrencyRebase.plan(from: baseCurrency, to: newBase, rates: rates) {
        case .failure(.sameCurrency): throw RebaseError.sameCurrency
        case .failure(.missingRate(let code)): throw RebaseError.missingRate(code)
        case .success(let value): plan = value
        }

        let result = try CurrencyRebaseService.apply(plan, context: repo.context)

        UserDefaults.appGroup.set(plan.newBase, forKey: "currency")
        NSUbiquitousKeyValueStore.default.set(plan.newBase, forKey: "currency")
        applyRebaseRefresh()

        return RebasePreview(oldBase: plan.oldBase, newBase: plan.newBase,
                             factor: plan.factor,
                             recordCount: result.records)
    }

    /// Everything that cached converted numbers has to start over.
    private func applyRebaseRefresh() {
        load()
        AccountViewModel.shared.load()
        BudgetViewModel.shared.load()
        InsightsViewModel.shared.refreshAll()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension AccountModel {
    /// Empty means "use the app's base currency". Lives here rather than next
    /// to the model because the widget target compiles `Helper.swift` without
    /// the rate store.
    var resolvedCurrencyCode: String {
        currencyCode.isEmpty ? AppBaseCurrency.code : currencyCode
    }
}
