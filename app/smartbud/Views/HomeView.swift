//
//  HomeView.swift
//  smartbud
//
//  Created by Iorest on 20/5/22.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
class OverallToastPresenter {
    var showToast: Bool = false
}

enum DeletionType {
    case instant
    case prompt
}

@MainActor
@Observable
class OverallTransactionManager {
    var toEdit: TransactionModel?
    var toDelete: TransactionModel?
    var showToast: Bool = false
    var showPopup: Bool = false
    var future: Bool = false
}

struct HomeView: View {
    @Environment(AppLockViewModel.self) var appLockVM

    @State var toastPresenter = OverallToastPresenter()
    @State var transactionManager = OverallTransactionManager()
    @Environment(TransactionViewModel.self) var transactionVM

    @State var currentTab = "Log"

    var topEdge: CGFloat
    var bottomEdge: CGFloat

    @State var fromURL1: Bool = false
    @State var fromURL2: Bool = false
    @State var fromURL3: Bool = false
    @State var fromURL4: Bool = false

    @State var launchAdd: Bool = false
    @State var launchSearch: Bool = false

    @State var counter = 0
    @State private var showConfetti = false

    @Environment(TabBarManager.self) var tabBarManager

    @State var showPopup = false

    // Hiding Native TabBar is now done once in `SmartBudApp.init`
    // (was previously set here, but ran every time this view was
    // reconstructed).
    init(topEdge: CGFloat, bottomEdge: CGFloat) {
        self.topEdge = topEdge
        self.bottomEdge = bottomEdge
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppGlassBackground()

            TabView(selection: $currentTab) {
                LogView(topEdge: topEdge, bottomEdge: bottomEdge, launchSearch: launchSearch)
                    .ignoresSafeArea(.all)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppGlassBackground())
                    .tag("Log")

                InsightsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppGlassBackground())
                    .tag("Insights")

                BudgetView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppGlassBackground())
                    .tag("Budget")

                SettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppGlassBackground())
                    .tag("Settings")
            }
            .allowsHitTesting(showPopup ? false : true)
            .environment(toastPresenter)
            .environment(transactionManager)

            CustomTabBar(currentTab: $currentTab, topEdge: topEdge, bottomEdge: bottomEdge, counter: $counter, launchAdd: launchAdd)
                .offset(y: tabBarManager.hideTab ? (70 + bottomEdge) : 0)

            if showPopup {
                Rectangle()
                    .fill(Color.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        transactionManager.showPopup = false
                    }
            }

            DeleteTransactionAlert()
                .offset(y: showPopup ? 0 : 300)
                .environment(transactionManager)

            if appLockVM.isAppLockEnabled && !appLockVM.isAppUnLocked {
                AppLockView()
                    .ignoresSafeArea(.all)
                    .onOpenURL { url in

                        if url.host == "newExpense" {
                            fromURL1 = true
                        } else if url.host == "search" {
                            fromURL2 = true
                        } else if url.host == "insights" {
                            fromURL3 = true
                        } else if url.host == "budget" {
                            fromURL4 = true
                        }
                    }
            }
        }
        .toast(isPresenting: $toastPresenter.showToast, duration: 4, tapToDismiss: true, offsetY: 12, alert: {
            AlertToast(displayMode: .hud, type: .systemImage("checkmark.circle.fill", Color.IncomeGreen), title: String.appLocalized("Image Saved"), subTitle: String.appLocalized("Check it out in Photos"))
        })
        .toast(isPresenting: $transactionManager.showToast, duration: 4, tapToDismiss: true, offsetY: 12, alert: {
            AlertToast(displayMode: .hud, type: .systemImage("arrow.uturn.backward.circle.fill", Color.AlertRed), title: String.appLocalized("Log Deleted"), subTitle: String.appLocalized("Tap to Undo"))
        }, onTap: {
            withAnimation(.easeInOut(duration: 0.5)) {
                transactionVM.rollback()
            }
            transactionManager.toDelete = nil
        }, completion: {
            transactionVM.commitPendingChanges()
            transactionManager.toDelete = nil
        })
        .onChange(of: transactionManager.showPopup) { _, newValue in
            withAnimation {
                showPopup = newValue
            }
        }
        .fullScreenCover(item: $transactionManager.toEdit, onDismiss: {
            transactionManager.toEdit = nil
        }) { transaction in
            TransactionView(toEdit: transaction)
        }
        .confettiOverlay(isActive: $showConfetti)
        .onChange(of: counter) { _, _ in showConfetti = true }
        .onAppear {
            if appLockVM.isAppLockEnabled && fromURL1 {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    launchAdd.toggle()
                }

                fromURL1 = false
            }

            if appLockVM.isAppLockEnabled && fromURL2 {
                currentTab = "Log"

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    launchSearch.toggle()
                }

                fromURL2 = false
            }

            if appLockVM.isAppLockEnabled && fromURL3 {
                currentTab = "Insights"
            }

            if appLockVM.isAppLockEnabled && fromURL4 {
                currentTab = "Budget"
            }
        }
        .onOpenURL { url in
            if url.host == "search" {
                currentTab = "Log"
            } else if url.host == "insights" {
                currentTab = "Insights"
            } else if url.host == "budget" {
                currentTab = "Budget"
            }
        }
    }
}

struct AppLockView: View {
    @Environment(AppLockViewModel.self) var appLockVM

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "lock.fill")
                .font(.system(size: 65))
                .foregroundStyle(Color.DarkIcon.opacity(0.7))

            Text("App Locked")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.PrimaryText)
                .padding(.bottom, 30)

            Button {
                appLockVM.appLockValidation()
            } label: {
                HStack {
                    Image(systemName: "faceid")

                    Text("Unlock App")
                }
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(Color.PrimaryText)
                .padding(.horizontal, 40)
                .padding(.vertical, 15)
                .overlay {
                    RoundedRectangle(cornerRadius: GlassRadius.card)
                        .stroke(Color.Outline)
                }
            }

            if appLockVM.enrollmentError {
                Text("Please re-enable Face ID access in the Settings app to unlock application.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.SubtitleText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.PrimaryBackground.opacity(0.3))
        .background(.ultraThinMaterial)
    }
}
