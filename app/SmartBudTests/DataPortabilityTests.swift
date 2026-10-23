//
//  DataPortabilityTests.swift
//  SmartBudTests
//
//  CSV escaping for the spreadsheet export, plus the classification rules
//  every total in the app depends on. Import/merge tests live in
//  DataImporterTests.swift.
//

import Testing
import Foundation
import SwiftData

@MainActor
@Suite("CSV escaping")
struct CSVSupportTests {

    @Test("Plain values are not quoted")
    func plainValue() {
        #expect(CSVSupport.field("lunch") == "lunch")
    }

    @Test("Commas force quoting")
    func comma() {
        #expect(CSVSupport.field("lunch, coffee") == "\"lunch, coffee\"")
    }

    @Test("Quotes are doubled")
    func quote() {
        #expect(CSVSupport.field("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }

    @Test("Newlines force quoting")
    func newline() {
        #expect(CSVSupport.field("a\nb") == "\"a\nb\"")
    }

    @Test("Rows join escaped fields")
    func row() {
        #expect(CSVSupport.row(["a", "b,c", "d"]) == "a,\"b,c\",d")
    }
}

@Suite("Transaction classification")
struct TransactionClassificationTests {

    private func expense(_ amount: Double) -> TransactionModel {
        TransactionModel(amount: amount, date: .now)
    }

    @Test("A plain expense counts as spend")
    func plainExpense() {
        let txn = expense(20)
        #expect(txn.countsAsSpend)
        #expect(txn.signedBaseAmount == -20)
    }

    @Test("A reimbursable claim stays out of spend and of net")
    func reimbursableIsPassThrough() {
        let txn = expense(20)
        txn.reimbursable = true
        #expect(!txn.countsAsSpend)
        #expect(txn.signedBaseAmount == 0)
        #expect(txn.isPendingReimbursement)
    }

    @Test("Settling a claim still keeps it out of spend")
    func settledClaim() {
        let txn = expense(20)
        txn.reimbursable = true
        txn.reimbursedAt = .now
        #expect(!txn.isPendingReimbursement)
        #expect(!txn.countsAsSpend)
    }

    @Test("A balance adjustment is neither income nor spend")
    func adjustmentIsInvisibleToStats() {
        let txn = expense(50)
        txn.adjustment = true
        #expect(!txn.countsAsSpend)
        #expect(!txn.countsAsIncome)
        #expect(txn.signedBaseAmount == 0)
    }

    @Test("Income counts as income")
    func income() {
        let txn = expense(50)
        txn.income = true
        #expect(txn.countsAsIncome)
        #expect(txn.signedBaseAmount == 50)
    }

    @Test("A transfer fee is booked as its own expense, not into the transfer")
    func transferFee() {
        let transfer = TransferModel(amount: 100, destinationAmount: 0, fee: 2.5)
        // The fee row is charged separately, so folding it in again would
        // deduct the same 2.50 twice.
        #expect(transfer.outgoingTotal == 100)
        #expect(transfer.fee == 2.5)
        #expect(transfer.receivedAmount == 100)
    }

    @Test("A non-finite fee cannot inflate the outgoing total")
    func nonFiniteFee() {
        let transfer = TransferModel(amount: 100)
        transfer.fee = .nan
        #expect(transfer.outgoingTotal == 100)
    }

    @Test("Gross amount restores the pre-discount price")
    func grossAmount() {
        let txn = TransactionModel(amount: 80, date: .now, discount: 20)
        #expect(txn.grossAmount == 100)
    }
}
