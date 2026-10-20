import CoreHaptics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct DeleteCategoryAlert: View {
    @Environment(CategoryViewModel.self) var categoryVM
    @Environment(\.dismiss) var dismiss
    let toDelete: CategoryModel
    @Binding var deleted: Bool
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
                .accessibilityAddTraits(.isButton)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(String.appFormatted("Delete '%@'?", toDelete.wrappedName))
                    .font(.title2.weight(.medium))

                    .foregroundStyle(Color.PrimaryText)

                Text(String.appLocalized("This action cannot be undone."))
                    .font(.title3.weight(.medium))

                    .foregroundStyle(Color.SubtitleText)
                    .padding(.bottom, 15)
                    .accessibilityHidden(true)

                Button {
                    deleted = true
                    dismiss()

                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        withAnimation {
                            categoryVM.delete(toDelete)
                        }
                    }

                } label: {
                    Text(String.appLocalized("Delete"))
                        .font(.title3.weight(.semibold))

                        .foregroundStyle(.white)
                        .frame(height: 45)
                        .frame(maxWidth: .infinity)
                        .background(Color.AlertRed, in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
                }
                .padding(.bottom, 8)

                Button {
                    withAnimation(.easeOut(duration: 0.7)) {
                        dismiss()
                    }

                } label: {
                    Text(String.appLocalized("Cancel"))
                        .font(.title3.weight(.semibold))

                        .foregroundStyle(Color.PrimaryText.opacity(0.9))
                        .frame(height: 45)
                        .frame(maxWidth: .infinity)
                        .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
                }
            }
            .padding(13)
            .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SBRadius.card).stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
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
//                        dismiss()
//                }))
            .padding(.horizontal, 17)
            .padding(.bottom, bottomEdge == 0 ? 13 : bottomEdge)
        }
        .ignoresSafeArea(.all)
        .background(BackgroundBlurView())
    }
}
