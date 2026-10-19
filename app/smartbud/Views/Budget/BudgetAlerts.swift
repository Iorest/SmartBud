import Foundation
import SwiftUI
import SwiftData

struct DeleteBudgetAlert: View {
    @Environment(BudgetViewModel.self) var budgetVM
    @Environment(\.dismiss) var dismiss
    let toDelete: BudgetModel
    @Environment(\.colorScheme) var systemColorScheme

    @AppStorage("bottomEdge", store: .appGroup) var bottomEdge: Double = 15

    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }

            VStack(alignment: .leading, spacing: 1.5) {
                Text(
                    String(
                        format: String.appLocalized("Delete the '%@' budget?"),
                        toDelete.category?.wrappedName ?? "")
                )
                    .font(.system(.title2, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.PrimaryText)

                Text("This action cannot be undone.")
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.SubtitleText)
                    .padding(.bottom, 25)

                Button {
                    dismiss()

                    withAnimation {
                        budgetVM.delete(toDelete)
                    }

                } label: {
                    DeleteButton(text: String.appLocalized("Delete"), red: true)
                }
                .padding(.bottom, 8)

                Button {
                    withAnimation(.easeOut(duration: 0.7)) {
                        dismiss()
                    }

                } label: {
                    DeleteButton(text: String.appLocalized("Cancel"), red: false)
                }
            }
            .padding(13)
            .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: GlassRadius.card).stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
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
                            withAnimation {
                                offset = 0
                            }
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

struct DeleteMainBudgetAlert: View {
    @Environment(BudgetViewModel.self) var budgetVM
    @Environment(\.dismiss) var dismiss
    let toDelete: MainBudgetModel
    @Environment(\.colorScheme) var systemColorScheme

    @AppStorage("bottomEdge", store: .appGroup) var bottomEdge: Double = 15

    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }

            VStack(alignment: .leading, spacing: 1.5) {
                Text("Delete your overall budget?")
                    .font(.system(.title2, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.PrimaryText)

                Text("This action cannot be undone.")
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.SubtitleText)
                    .padding(.bottom, 25)

                Button {
                    dismiss()

                    withAnimation {
                        budgetVM.deleteMain(toDelete)
                    }

                } label: {
                    DeleteButton(text: String.appLocalized("Delete"), red: true)
                }
                .padding(.bottom, 8)

                Button {
                    withAnimation(.easeOut(duration: 0.7)) {
                        dismiss()
                    }

                } label: {
                    DeleteButton(text: String.appLocalized("Cancel"), red: false)
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: GlassRadius.card).stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
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
                            withAnimation {
                                offset = 0
                            }
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

