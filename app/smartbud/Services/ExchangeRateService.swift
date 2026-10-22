//
//  ExchangeRateService.swift
//  smartbud
//
//  Reference rates from Frankfurter (ECB data, no API key, HTTPS). The API
//  answers "1 base = X quote", while this app stores "1 quote = Y base", so
//  every value is inverted on the way in.
//

import Foundation

struct ExchangeRateService {
    /// Frankfurter publishes ECB reference rates. Currencies outside that set
    /// (e.g. TWD, VND) simply come back missing and keep their manual rate.
    static let endpoint = "https://api.frankfurter.app/latest"

    enum ServiceError: Error, LocalizedError {
        case badURL
        case badStatus(Int)
        case malformed

        var errorDescription: String? {
            switch self {
            case .badURL, .malformed:
                String.appLocalized("The rate service returned an unexpected response.")
            case .badStatus:
                String.appLocalized("The rate service is unavailable right now.")
            }
        }
    }

    struct Response: Decodable {
        let base: String
        let date: String
        let rates: [String: Double]
    }

    /// Fetches rates and returns them in this app's direction:
    /// `result[code]` = how many base units one unit of `code` is worth.
    func fetch(base: String, session: URLSession = .shared) async throws -> [String: Double] {
        var components = URLComponents(string: Self.endpoint)
        components?.queryItems = [URLQueryItem(name: "from", value: base.uppercased())]
        guard let url = components?.url else { throw ServiceError.badURL }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ServiceError.badStatus(http.statusCode)
        }
        return try Self.invertedRates(from: data)
    }

    /// Pure decoding step, kept separate so it can be tested without a network.
    static func invertedRates(from data: Data) throws -> [String: Double] {
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw ServiceError.malformed
        }

        var inverted: [String: Double] = [:]
        for (code, value) in response.rates {
            guard value > 0, value.isFinite else { continue }
            inverted[code.uppercased()] = 1 / value
        }
        return inverted
    }
}
