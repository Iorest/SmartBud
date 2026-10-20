//
//  SBDeleteSheet.swift
//  smartbud
//
//  Bottom confirmation card used by every destructive action (budget, overall
//  budget, category). Four hand-rolled copies had drifted apart; this is the
//  single implementation.
//

import SwiftUI

struct SBDeleteSheet: View {
    let title: String
    var message: String = String.appLocalized("This action cannot be undone.")
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("bottomEdge", store: .appGroup) private var bottomEdge: Double = 15

    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
                .accessibilityAddTraits(.isButton)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color.PrimaryText)

                Text(message)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.SubtitleText)
                    .padding(.bottom, 25)

                Button {
                    dismiss()
                    onDelete()
                } label: {
                    DeleteButton(text: String.appLocalized("Delete"), red: true)
                }
                .padding(.bottom, 8)

                Button {
                    withAnimation(.easeOut(duration: 0.7)) { dismiss() }
                } label: {
                    DeleteButton(text: String.appLocalized("Cancel"), red: false)
                }
            }
            .padding(13)
            .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.card)
                    .stroke(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3)
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
                            dismiss()
                        } else {
                            withAnimation { offset = 0 }
                        }
                    }
            )
            .padding(.horizontal, 17)
            .padding(.bottom, bottomEdge == 0 ? 13 : bottomEdge)
        }
        .ignoresSafeArea(.all)
        .background(BackgroundBlurView())
    }
}
