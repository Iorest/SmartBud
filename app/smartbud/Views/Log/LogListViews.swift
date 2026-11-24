//
//  LogListViews.swift
//  smartbud
//
//  Upcoming list used by the Log (inside its native `List`) and by the
//  Settings screen (inside a plain `ScrollView`, where a nested `List` is not
//  allowed). Rows are the shared `LogTransactionRow`; there is no bespoke
//  swipe gesture here.
//

import Foundation
import SwiftData
import SwiftUI

struct FutureListView: View {
    @Query private var fetchedResults: [TransactionModel]
    @Environment(BookState.self) private var bookState

    /// Upcoming rows from another book must never appear in this ledger.
    private var scopedResults: [TransactionModel] {
        BookScope.scoped(fetchedResults, \.bookID, selected: bookState.currentID)
    }

    var filterMode: Bool
    var limitedMode: Bool

    @Environment(OverallTransactionManager.self) private var transactionManager

    var transactions: [TransactionModel] {
        let items: [TransactionModel]

        if limitedMode {
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date.now)
            let horizon = calendar.date(byAdding: .weekOfYear, value: 2, to: startOfToday) ?? .distantFuture

            items = scopedResults.filter {
                let date = $0.wrappedDate > Date.now ? $0.wrappedDate : $0.nextTransactionDate
                return date < horizon
            }
        } else {
            items = scopedResults
        }

        return items.sorted {
            let first = $0.wrappedDate > Date.now ? $0.wrappedDate : $0.nextTransactionDate
            let second = $1.wrappedDate > Date.now ? $1.wrappedDate : $1.nextTransactionDate
            return first > second
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if transactions.isEmpty {
                if filterMode {
                    ContentUnavailableView(
                        String.appLocalized("No upcoming entries"),
                        systemImage: "clock",
                        description: Text(String.appLocalized("Repeating and future entries show up here."))
                    )
                    .frame(maxWidth: .infinity)
                }
            } else {
                Text(String.appLocalized("UPCOMING"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SBSpace.extraSmall)
                    .padding(.top, SBSpace.small)
                    .padding(.bottom, SBSpace.xxs)

                ForEach(transactions) { transaction in
                    Button {
                        transactionManager.toEdit = transaction
                    } label: {
                        LogTransactionRow(transaction: transaction, future: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    init(filterMode: Bool, limitedMode: Bool) {
        let now = Date.now
        let past = Date.distantPast
        _fetchedResults = Query(filter: #Predicate<TransactionModel> {
            $0.recurringType > 0 || ($0.date ?? past) > now
        })

        self.filterMode = filterMode
        self.limitedMode = limitedMode
    }
}
