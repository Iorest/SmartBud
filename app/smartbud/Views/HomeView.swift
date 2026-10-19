//
//  HomeView.swift
//  smartbud
//
//  Created by Iorest on 20/5/22.
//

import Foundation
import Observation
import SwiftData
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

    // Floating add button (replaces the custom tab bar's centre button).
    @State private var addTransaction = false
    @State private var transactionCountBeforeAdd = 0
    @State private var lightHaptic = 0
    @Query private var transactions: [TransactionModel]
    @AppStorage("confetti", store: .appGroup) private var confetti: Bool = false
    @AppStorage("firstTransactionViewLaunch", store: .appGroup) private var firstLaunch: Bool = true

    init(topEdge: CGFloat, bottomEdge: CGFloat) {
        self.topEdge = topEdge
        self.bottomEdge = bottomEdge
        #if DEBUG
        // QA hook: `SIMCTL_CHILD_START_TAB=Insights` opens straight on a tab
        // for screenshot/UI verification. Debug builds only.
        if let tab = ProcessInfo.processInfo.environment["START_TAB"],
           ["Log", "Insights", "Budget", "Settings"].contains(tab) {
            _currentTab = State(initialValue: tab)
        }
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppGlassBackground()

            // Native TabView: one navigation shell that adapts to iPhone,
            // iPad and Mac (Designed for iPad) without a custom tab bar.
            TabView(selection: $currentTab) {
                LogView(topEdge: topEdge, bottomEdge: bottomEdge, launchSearch: launchSearch,
                        onAdd: { addTransaction = true })
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .background(AppGlassBackground())
                    .tag("Log")
                    .tabItem {
                        Label(String.appLocalized("Log"), systemImage: "list.bullet")
                    }

                InsightsView()
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .background(AppGlassBackground())
                    .tag("Insights")
                    .tabItem {
                        Label(String.appLocalized("Insights"), systemImage: "chart.bar.fill")
                    }

                BudgetView()
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .background(AppGlassBackground())
                    .tag("Budget")
                    .tabItem {
                        Label(String.appLocalized("Budget"), systemImage: "chart.pie.fill")
                    }

                SettingsView()
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .background(AppGlassBackground())
                    .tag("Settings")
                    .tabItem {
                        Label(String.appLocalized("Settings"), systemImage: "gearshape.fill")
                    }
            }
            .allowsHitTesting(showPopup ? false : true)
            .environment(toastPresenter)
            .environment(transactionManager)

            // The add button is only meaningful on data screens; on Settings
            // it used to overlap the last rows and steal their taps.
            if currentTab != "Settings" {
                Button {
                    lightHaptic &+= 1
                    transactionCountBeforeAdd = transactions.count
                    addTransaction = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(MyButtonStyle())
                .padding(.trailing, 22)
                .padding(.bottom, bottomEdge + 46)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .accessibilityLabel(String.appLocalized("Add New Transaction"))
            }

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
        .fullScreenCover(isPresented: $addTransaction, onDismiss: {
            if confetti && transactionCountBeforeAdd != transactions.count {
                counter += 1
            }
            if firstLaunch {
                firstLaunch = false
            }
        }) {
            TransactionView(toEdit: nil)
        }
        .onChange(of: launchAdd) { _, _ in
            addTransaction = true
        }
        .onOpenURL { url in
            if url.host == "newExpense" {
                addTransaction = true
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lightHaptic)
        .confettiOverlay(isActive: $showConfetti)
        .onChange(of: counter) { _, _ in showConfetti = true }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["START_CREATE"] == "1" {
                addTransaction = true
            }
            #endif
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
