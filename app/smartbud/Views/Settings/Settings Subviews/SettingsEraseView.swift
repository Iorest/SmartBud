//
//  SettingsEraseView.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//
//  "Erase All Data" screen. The long-press confirmation calls
//  `SettingsViewModel.wipeAllData()`, which deletes the local store
//  AND the CloudKit record zone — required for App Store Guideline
//  5.1.1(v), since the data lives in the user's iCloud private
//  database and would otherwise linger there even after the local
//  copy is gone.
//

import Foundation
import SwiftUI

struct SettingsEraseView: View {
  @Environment(\.dismiss) var dismiss

  @State var showAlert = false

  var body: some View {
    VStack(spacing: 10) {
      Text(String.appLocalized("Erase Data"))
        .font(.system(.title3, design: .rounded).weight(.semibold))
        .foregroundStyle(Color.PrimaryText)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
          Button {
            dismiss()
          } label: {
            SettingsBackButton()
          }
        }
        .padding(.bottom, 20)

      Button {
        showAlert = true
      } label: {
            Text(String.appLocalized("Permanently Delete Everythin'"))
              .font(.system(.body, design: .rounded))
          .foregroundStyle(Color.PrimaryText)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 12)
          .padding(.horizontal, 15)
          .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: GlassRadius.chip))
      }

      Text(
        String.appLocalized("This action would delete all existing transactions, categories, and budgets, and cannot be undone.")
      )
      .font(.system(.caption, design: .rounded).weight(.medium))
      .multilineTextAlignment(.leading)
      .foregroundStyle(Color.SubtitleText)
      .padding(.horizontal, 15)
      .frame(maxWidth: .infinity, alignment: .leading)

      // 5.1.1(v) hint: data also lives in the user's iCloud.
      Text(
        String.appLocalized("Erasing also removes your data from iCloud. If you're not signed in, the next online sync will clear it on Apple's servers.")
      )
      .font(.system(.caption, design: .rounded).weight(.regular))
      .multilineTextAlignment(.leading)
      .foregroundStyle(Color.SubtitleText.opacity(0.85))
      .padding(.horizontal, 15)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 4)
    }
    .modifier(SettingsSubviewModifier())
    .fullScreenCover(isPresented: $showAlert) {
      DeleteAllAlert()
    }
  }
}

struct DeleteAllAlert: View {
  @Environment(\.modelContext) var modelContext
  @Environment(\.dismiss) var dismiss
  @Environment(\.colorScheme) var systemColorScheme
  @State var settingsVM = SettingsViewModel.shared

  @AppStorage("bottomEdge", store: .appGroup)
  var bottomEdge: Double = 15

  @State private var offset: CGFloat = 0

  @GestureState var isDetectingLongPress = false
  @State var completedLongPress = false
  @State private var heavyHaptic = 0
  @State private var isWiping = false
  @State private var wipeResult: DataRepository.WipeOutcome?

  var longPress: some Gesture {
    LongPressGesture(minimumDuration: 2)
      .updating($isDetectingLongPress) {
        currentState, gestureState,
        _ in
        gestureState = currentState
      }
      .onEnded { finished in
        self.completedLongPress = finished
      }
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      Color.clear
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
          if !isWiping { dismiss() }
        }

      VStack(alignment: .leading, spacing: 1.5) {
        HStack(spacing: 7) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(.callout, design: .rounded).weight(.medium))

          Text(String.appLocalized("Danger Zone"))
            .font(.system(.title2, design: .rounded).weight(.medium))
        }
        .foregroundStyle(Color.PrimaryText)

        Text(String.appLocalized("This action genuinely cannot be undone. Long press to confirm."))
          .font(.system(.title3, design: .rounded).weight(.medium))
          .foregroundStyle(Color.SubtitleText)
          .padding(.bottom, 15)

        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Rectangle()
              .fill(Color.AlertRed.opacity(0.23))
              .frame(width: proxy.size.width)

            Rectangle()
              .fill(Color.AlertRed)
              .frame(width: proxy.size.width, height: 100)
              .offset(x: completedLongPress ? 0 : (isDetectingLongPress ? 0 : -(proxy.size.width)))
              .animation(.easeInOut(duration: 2), value: isDetectingLongPress)

            if isWiping {
              ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .frame(width: proxy.size.width, alignment: .center)
            } else {
              Text(String.appLocalized("Delete Literally Everything"))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: proxy.size.width, alignment: .center)
            }
          }
          .frame(height: proxy.size.height)
          .clipShape(RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
        }
        .frame(height: 45)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
        .gesture(
          LongPressGesture(minimumDuration: 2)
            .updating(
              $isDetectingLongPress,
              body: { currentState, state, _ in
                state = currentState
              }
            )
            .onEnded { _ in
              self.completedLongPress.toggle()
            }
        )
        .onChange(of: completedLongPress) { _, _ in
          if completedLongPress && !isWiping {
            heavyHaptic &+= 1
            isWiping = true
            Task { @MainActor in
              let outcome = await settingsVM.wipeAllData()
              wipeResult = outcome
              isWiping = false
              dismiss()
            }
          }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: heavyHaptic)

        Button {
          if !isWiping {
            withAnimation(.easeOut(duration: 0.7)) {
              dismiss()
            }
          }

        } label: {
            DeleteButton(text: String.appLocalized("Back Out"), red: false)
        }
      }
      .padding(13)
      .background(
        RoundedRectangle(cornerRadius: GlassRadius.card).fill(Color.PrimaryBackground).shadow(
          color: systemColorScheme == .dark ? Color.clear : Color.gray.opacity(0.25), radius: 6)
      )
      .overlay(
        RoundedRectangle(cornerRadius: GlassRadius.card).stroke(
          systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3)
      )
      .offset(y: offset)
      .gesture(
        DragGesture()
          .onChanged { gesture in
            if !isWiping, gesture.translation.height < 0 {
              offset = gesture.translation.height / 3
            } else if !isWiping {
              offset = gesture.translation.height
            }
          }
          .onEnded { value in
            if !isWiping, value.translation.height > 20 {
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
    .alert(
      wipeResultTitle,
      isPresented: Binding(
        get: { wipeResult != nil },
        set: { if !$0 { wipeResult = nil } }
      ),
      actions: {
        Button(String.appLocalized("alert.ok"), role: .cancel) {
          wipeResult = nil
        }
      },
      message: { Text(wipeResultBody) }
    )
  }

  private var wipeResultTitle: String {
    switch wipeResult {
    case .complete, .partial:
      String.appLocalized(SettingsKey.eraseTitle)
    case .localFailed, .none:
      String.appLocalized(SettingsKey.proErrorTitle)
    }
  }

  private var wipeResultBody: String {
    switch wipeResult {
    case .complete:
      String.appLocalized(SettingsKey.eraseSuccess)
    case .partial:
      String.appLocalized(SettingsKey.erasePartial)
    case .localFailed:
      String.appLocalized(SettingsKey.eraseFailure)
    case .none:
      ""
    }
  }
}
