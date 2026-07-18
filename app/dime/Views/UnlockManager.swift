//
//  UnlockManager.swift
//  dime
//
//  Created by Rafael Soh on 15/9/22.
//

import Foundation
import StoreKit

@MainActor
final class UnlockManager: ObservableObject {
    enum RequestState {
        case loading
        case loaded
        case failed
    }

    var canMakePayments: Bool {
        AppStore.canMakePayments
    }

    @Published var requestState = RequestState.loading
    @Published var purchaseCount: Int
    @Published var failedTransaction = false

    var loadedProducts = [Product]()

    private let productIDs = [
        "com.rafaelsoh.dime.smalltip",
        "com.rafaelsoh.dime.mediumtip",
        "com.rafaelsoh.dime.largetip",
    ]

    init() {
        purchaseCount = UserDefaults(suiteName: "group.com.rafaelsoh.dime")?.integer(forKey: "tipCounter") ?? 0

        Task {
            await loadProducts()
        }
    }

    func loadProducts() async {
        do {
            loadedProducts = try await Product.products(for: productIDs)
            requestState = loadedProducts.isEmpty ? .failed : .loaded
        } catch {
            requestState = .failed
        }
    }

    func buy(product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success:
                purchaseCount += 1
                UserDefaults(suiteName: "group.com.rafaelsoh.dime")?.set(purchaseCount, forKey: "tipCounter")
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            failedTransaction = true
            revertBool()
        }
    }

    func restore() async {
        try? await AppStore.sync()
    }

    private func revertBool() {
        Task {
            try? await Task.sleep(for: .seconds(4))
            failedTransaction = false
        }
    }
}
