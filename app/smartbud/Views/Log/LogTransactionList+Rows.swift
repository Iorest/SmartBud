//
//  LogTransactionList+Rows.swift
//  smartbud
//
//  Row builders for the ledger: editable, selectable, transfer, and the
//  reimbursement actions that hang off a row's context menu.
//

import SwiftData
import SwiftUI

extension LogTransactionList {

    /// Transfers sit in the ledger but are never selectable in batch mode:
    /// they are not transactions and have no category to reassign.
    func transferRow(_ transfer: TransferModel) -> some View {
        LogTransferRow(transfer: transfer)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    transferToDelete = transfer
                } label: {
                    Label(String.appLocalized("Delete"), systemImage: "trash")
                }
            }
            .contextMenu {
                Button(role: .destructive) {
                    transferToDelete = transfer
                } label: {
                    Label(String.appLocalized("Delete"), systemImage: "trash")
                }
            }
    }

    @ViewBuilder
    func row(_ transaction: TransactionModel, isFuture: Bool? = nil) -> some View {
        let futureRow = isFuture ?? future

        if isSelecting {
            selectableRow(transaction, isFuture: futureRow)
        } else {
            editableRow(transaction, isFuture: futureRow)
        }
    }

    /// Selection mode: the row toggles a checkmark instead of opening.
    func selectableRow(_ transaction: TransactionModel, isFuture: Bool) -> some View {
        let isSelected = selection.contains(transaction.id)

        return HStack(spacing: SBSpace.small) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.SubtitleText)
                .accessibilityHidden(true)

            LogTransactionRow(transaction: transaction, future: isFuture)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selection.remove(transaction.id)
            } else {
                selection.insert(transaction.id)
            }
            selectionHaptic &+= 1
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    func editableRow(_ transaction: TransactionModel, isFuture: Bool) -> some View {
        let futureRow = isFuture
        return Button {
            transactionManager.toEdit = transaction
        } label: {
            LogTransactionRow(transaction: transaction, future: futureRow)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: !stopsRecurring(transaction, future: futureRow)) {
            Button(role: .destructive) {
                remove(transaction, future: futureRow)
            } label: {
                Label(String.appLocalized("Delete"), systemImage: "trash")
            }
            .accessibilityIdentifier(AccessibilityID.logRowDelete)

            Button {
                transactionManager.toEdit = transaction
            } label: {
                Label(String.appLocalized("Edit"), systemImage: "pencil")
            }
            .tint(.accentColor)
        }
        .contextMenu {
            if transaction.recurringType > 0 {
                Button {
                    transactionVM.stopRecurring(transaction)
                } label: {
                    Label(String.appLocalized("Stop Recurring"), systemImage: "xmark")
                }
            }

            Button {
                transactionManager.toEdit = transaction
            } label: {
                Label(String.appLocalized("Edit"), systemImage: "pencil")
            }

            if !transaction.income && !transaction.adjustment {
                reimbursementMenuItems(transaction)
            }

            if !stopsRecurring(transaction, future: futureRow) {
                Button(role: .destructive) {
                    remove(transaction, future: futureRow)
                } label: {
                    Label(String.appLocalized("Delete"), systemImage: "trash")
                }
            }
        }
    }

    /// Claim actions for an expense. Kept in one place so the context menu
    /// and the log row never disagree about the current state.
    @ViewBuilder
    func reimbursementMenuItems(_ transaction: TransactionModel) -> some View {
        if transaction.reimbursable {
            if transaction.isPendingReimbursement {
                Button {
                    transactionVM.setReimbursed(true, for: transaction)
                } label: {
                    Label(String.appLocalized("Reimbursed"), systemImage: "checkmark.circle")
                }
            } else {
                Button {
                    transactionVM.setReimbursed(false, for: transaction)
                } label: {
                    Label(String.appLocalized("Undo Reimbursement"),
                          systemImage: "arrow.uturn.backward.circle")
                }
            }
            Button {
                transactionVM.setReimbursable(false, for: transaction)
            } label: {
                Label(String.appLocalized("Remove Claim"), systemImage: "xmark.circle")
            }
        } else {
            Button {
                transactionVM.setReimbursable(true, for: transaction)
            } label: {
                Label(String.appLocalized("Mark as Reimbursable"),
                      systemImage: "arrow.uturn.backward.circle")
            }
        }
    }

    func remove(_ transaction: TransactionModel, future: Bool? = nil) {
        if stopsRecurring(transaction, future: future) {
            withAnimation {
                transactionVM.stopRecurring(transaction)
            }
        } else {
            // Staged so the undo banner can restore it; the view model owns
            // the commit timer.
            withAnimation {
                transactionVM.stageDelete(transaction)
            }
        }
    }
}
