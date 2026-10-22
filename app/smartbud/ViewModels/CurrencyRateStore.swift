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

    func convertToBase(_ amount: Double, from code: String) -> Double {
        CurrencyConversion.convertRounded(
            amount, from: code, to: baseCurrency, rates: rates)
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
