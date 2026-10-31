//
//  AppLockView.swift
//  smartbud
//
//  Passcode gate shown over the whole app when the lock is on.
//

import SwiftUI

struct AppLockView: View {
    @Environment(AppLockViewModel.self) var appLockVM

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "lock.fill")
                .font(.system(size: 65))
                .foregroundStyle(Color.DarkIcon.opacity(0.7))

            Text("App Locked")
                .font(.title.weight(.semibold))
                .foregroundStyle(Color.PrimaryText)
                .padding(.bottom, 30)

            Button {
                appLockVM.appLockValidation()
            } label: {
                HStack {
                    Image(systemName: "faceid")

                    Text("Unlock App")
                }
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.PrimaryText)
                .padding(.horizontal, 40)
                .padding(.vertical, 15)
                .overlay {
                    RoundedRectangle(cornerRadius: SBRadius.card)
                        .stroke(Color.Outline)
                }
            }
            .accessibilityIdentifier(AccessibilityID.lockUnlockButton)

            if appLockVM.enrollmentError {
                Text("Please re-enable Face ID access in the Settings app to unlock application.")
                    .font(.subheadline)
                    .foregroundStyle(Color.SubtitleText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.PrimaryBackground.opacity(0.3))
        .background(.ultraThinMaterial)
        .accessibilityIdentifier(AccessibilityID.lockScreen)
    }
}
