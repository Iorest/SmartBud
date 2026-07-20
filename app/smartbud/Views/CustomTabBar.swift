//
//  CustomTabBar.swift
//  smartbud
//
//  Created by Rafael Soh on 20/5/22.
//

import Foundation
import SwiftUI
import SwiftData

struct CustomTabBar: View {
    @Environment(AppLockViewModel.self) var appLockVM
    @Binding var currentTab: String
    var topEdge: CGFloat
    var bottomEdge: CGFloat
    @State var addTransaction: Bool = false

    @State var checkingFace: Bool = false

    @Query private var transactions: [TransactionModel]

    @State var count = 0
    @Binding var counter: Int

    var launchAdd: Bool

    @AppStorage("confetti", store: .appGroup) var confetti: Bool = false
    @AppStorage("firstTransactionViewLaunch", store: .appGroup) var firstLaunch: Bool = true

    private var isZoomed: Bool {
        false
    }

    init(currentTab: Binding<String>, topEdge: CGFloat, bottomEdge: CGFloat, counter: Binding<Int>, launchAdd: Bool) {
        self._currentTab = currentTab
        self.topEdge = topEdge
        self.bottomEdge = bottomEdge
        self._counter = counter
        self.launchAdd = launchAdd
    }

    var body: some View {
        HStack(spacing: 4) {
            TabButton(image: "Log", zoomed: isZoomed, currentTab: $currentTab)

            TabButton(image: "Insights", zoomed: isZoomed, currentTab: $currentTab)

            Button {
                let impactMed = UIImpactFeedbackGenerator(style: .light)
                impactMed.impactOccurred()

                addTransaction = true

            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(MyButtonStyle())
            .offset(y: -12)
            .accessibilityLabel(String(localized: "Add New Transaction"))

            TabButton(image: "Budget", zoomed: isZoomed, currentTab: $currentTab)

            TabButton(image: "Settings", zoomed: isZoomed, currentTab: $currentTab)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.surface, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: GlassRadius.surface, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.bottom, bottomEdge - 10)
        .fullScreenCover(isPresented: $addTransaction, onDismiss: {
            if confetti {
                if count != transactions.count {
                    counter += 1
                }
            }

            if firstLaunch {
                firstLaunch = false
            }

        }, content: {
            TransactionView(toEdit: nil)
        })
        .onChange(of: launchAdd) { _, _ in
            addTransaction = true
        }
        .onChange(of: addTransaction) { _, _ in
            if addTransaction {
                count = transactions.count
            }
        }
        .onOpenURL { url in
            guard
                url.host == "newExpense"

            else {
                return
            }

            addTransaction = true
        }
    }
}

struct MyButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 58, height: 58)
            .background(
                Circle()
                    .fill(Color(red: 0.0, green: 0.48, blue: 1.0))
            )
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct BouncyButton: ButtonStyle {
    var duration: Double
    var scale: Double

    public func makeBody(configuration: Self.Configuration) -> some View {
        return configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: duration), value: configuration.isPressed)
    }
}

struct TabButton: View {
    var image: String
    var zoomed: Bool
    @Binding var currentTab: String

    var body: some View {
        Button {
            DispatchQueue.main.async {
                currentTab = image
            }
        } label: {
            Image(image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 28, maxHeight: 28)
                .padding(8)
                .background {
                    if currentTab == image {
                        Circle()
                            .fill(.clear)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentTab)
                .frame(maxWidth: .infinity)
                .foregroundStyle(currentTab == image ? Color.DarkIcon : Color.GreyIcon)
                .accessibilityHidden(true)
        }
        .glassChip(
            in: Circle(),
            interactive: currentTab == image
        )
        .buttonStyle(BouncyButton(duration: 0.3, scale: 0.6))
        .accessibilityLabel("\(image) tab")
        .accessibilityAddTraits(
            currentTab == image
                ? [.isButton, .isSelected]
                : .isButton
        )
    }
}
