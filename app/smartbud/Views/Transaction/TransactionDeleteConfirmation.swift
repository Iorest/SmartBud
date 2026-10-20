//
//  TransactionDeleteConfirmation.swift
//  smartbud
//
//  Bottom confirmation card for deleting the transaction being edited.
//  Extracted from `TransactionView`: it only needs the transaction's income
//  flag (for the wording), the bottom inset, and two callbacks.
//

import SwiftUI

struct TransactionDeleteConfirmation: View {
    let income: Bool
    let bottomEdge: Double
    let onDelete: () -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 1.5) {
                header

                Button(action: onDelete) {
                    label(String.appLocalized("Delete"), color: Color.AlertRed, textColor: .white)
                }
                .padding(.bottom, 8)

                Button {
                    withAnimation(.easeOut(duration: 0.7), onCancel)
                } label: {
                    label(String.appLocalized("Cancel"),
                          color: Color.SecondaryBackground,
                          textColor: Color.PrimaryText.opacity(0.9))
                }
            }
            .padding(13)
            .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.card).stroke(
                    colorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3)
            )
            .offset(y: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.height < 0 {
                            offset = gesture.translation.height / 3
                        } else {
                            offset = gesture.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 20 {
                            onCancel()
                        } else {
                            withAnimation { offset = 0 }
                        }
                    }
            )
            .padding(.horizontal, 17)
            .padding(.bottom, bottomEdge == 0 ? 12 : bottomEdge - 3)
        }
        .ignoresSafeArea(.all)
        .background(BackgroundBlurView())
    }

    private var header: some View {
        Group {
            Text(String.appLocalized(income ? "Delete Income?" : "Delete Expense?"))
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.PrimaryText)

            Text(String.appLocalized("This action cannot be undone."))
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.SubtitleText)
                .padding(.bottom, 15)
        }
    }

    private func label(_ text: String, color: Color, textColor: Color) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(textColor)
            .frame(height: 45)
            .frame(maxWidth: .infinity)
            .background(color, in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
    }
}
