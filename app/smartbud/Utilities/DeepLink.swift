//
//  DeepLink.swift
//  smartbud
//
//  `smartbud://` URL support, including x-callback-url replies.
//
//  ## Supported routes
//
//  - `smartbud://add?amount=12.5&type=expense&category=餐饮&note=午饭`
//    Creates one transaction. Optional: `type` (expense|income), `category`,
//    `account` (name or uuid), `date` (yyyy-MM-dd or ISO 8601), `note`,
//    `reimbursable` (1/true), `discount`.
//  - `smartbud://search?q=coffee` — opens the log with search focused.
//  - `smartbud://open?tab=insights` — switches tab (`log`/`insights`/
//    `budget`/`settings`). `smartbud://insights` and `smartbud://budget`
//    still work from the Shortcuts actions shipped earlier.
//
//  ## Callbacks
//
//  Pass `x-success` / `x-error` / `x-cancel` URLs to get a reply:
//  success appends `id`, `amount` and `date`; failure appends `error` with a
//  stable code (`invalid_amount`, `save_failed`). This is the shape
//  Shortcuts, Launcher and other automation tools expect.
//

import Foundation

/// A parsed `smartbud://` URL. Pure value type so parsing stays unit testable.
struct DeepLinkRequest: Equatable {

    enum Action: Equatable {
        case add
        case search
        case open
    }

    let action: Action
    let parameters: [String: String]
    let callbackSuccess: URL?
    let callbackError: URL?
    let callbackCancel: URL?

    init?(url: URL) {
        guard url.scheme?.lowercased() == "smartbud" else { return nil }

        let host = url.host?.lowercased() ?? ""
        switch host {
        case "add", "newtransaction":
            action = .add
        case "search":
            action = .search
        case "open", "insights", "budget", "newexpense":
            action = .open
        default:
            return nil
        }

        var parsed: [String: String] = [:]
        // Repeated keys keep the first value; later duplicates would make the
        // result depend on query order.
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        for item in items where parsed[item.name.lowercased()] == nil {
            parsed[item.name.lowercased()] = item.value ?? ""
        }
        // `smartbud://insights` carries the tab in the host, not the query.
        if parsed["tab"] == nil, ["insights", "budget", "newexpense"].contains(host) {
            parsed["tab"] = host == "newexpense" ? "log" : host
        }
        parameters = parsed

        callbackSuccess = Self.url(from: parsed["x-success"])
        callbackError = Self.url(from: parsed["x-error"])
        callbackCancel = Self.url(from: parsed["x-cancel"])
    }

    // MARK: - Typed accessors

    var amount: Double? {
        guard let raw = parameters["amount"] else { return nil }
        let cleaned = raw
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite, value > 0 else { return nil }
        return min(value, Money.maxAmount)
    }

    var discount: Double {
        guard let raw = parameters["discount"] else { return 0 }
        let cleaned = raw.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite, value > 0 else { return 0 }
        return min(value, Money.maxAmount)
    }

    var isIncome: Bool {
        let type = parameters["type"]?.lowercased() ?? ""
        if type == "income" { return true }
        if type == "expense" { return false }
        return Self.flag(parameters["income"])
    }

    var isReimbursable: Bool { Self.flag(parameters["reimbursable"]) }

    var note: String { parameters["note"] ?? "" }

    var categoryName: String? {
        let value = parameters["category"] ?? ""
        return value.isEmpty ? nil : value
    }

    /// Account name or uuid string.
    var accountHint: String? {
        let value = parameters["account"] ?? ""
        return value.isEmpty ? nil : value
    }

    var tab: String? {
        switch parameters["tab"]?.lowercased() {
        case "log": "Log"
        case "insights": "Insights"
        case "budget": "Budget"
        case "settings": "Settings"
        default: nil
        }
    }

    var date: Date {
        guard let raw = parameters["date"], !raw.isEmpty else { return .now }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = .current
        day.dateFormat = "yyyy-MM-dd"
        if let parsed = day.date(from: raw) { return parsed }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw) ?? .now
    }

    /// The search query for `smartbud://search`.
    var searchQuery: String? {
        let value = parameters["q"] ?? parameters["query"] ?? ""
        return value.isEmpty ? nil : value
    }

    // MARK: - Helpers

    /// Appends `items` to `base`'s query string, preserving whatever was there.
    static func resultURL(_ base: URL?, items: [URLQueryItem]) -> URL? {
        guard let base, var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = (components.queryItems ?? []) + items
        return components.url
    }

    private static func url(from value: String?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        return URL(string: value)
    }

    private static func flag(_ value: String?) -> Bool {
        guard let value = value?.lowercased() else { return false }
        return ["1", "true", "yes", "y"].contains(value)
    }
}
