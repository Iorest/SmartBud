//
//  UpdateSheet.swift
//  smartbud
//
//  Created by Iorest on 13/9/23.
//

import Foundation
import SwiftUI

struct UpdateAlert: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme

    @State private var offset: CGFloat = 0

    @AppStorage("bottomEdge", store: .appGroup) var bottomEdge: Double = 15

    @State var opacity = 0.0

    let welcomeFeatures = [
        WelcomeSheetFeatureRow(icon: "appclip", header: String.appLocalized("Siri Shorcuts"), subtitle: String.appLocalized("3 new Siri shortcuts allow you to conveniently add new transactions or access insights.")),
        WelcomeSheetFeatureRow(icon: "arrow.down.doc.fill", header: String.appLocalized("Data Import"), subtitle: String.appLocalized("Transfer pre-existing logs from other applications with a step-by-step guide.")),
        WelcomeSheetFeatureRow(icon: "sun.haze.fill", header: String.appLocalized("Future Transactions"), subtitle: String.appLocalized("With date restrictions lifted, log and view upcoming expenses/incomes.")),
        WelcomeSheetFeatureRow(icon: "circle.grid.2x2.fill", header: String.appLocalized("Re-designed Screens"), subtitle: String.appLocalized("Budget and category creation screens have been completely reworked.")),
        WelcomeSheetFeatureRow(icon: "swatchpalette.fill", header: String.appLocalized("Custom Category Colors"), subtitle: String.appLocalized("Using the stock iOS color picker, give your categories a long-awaited aesthetic refresh.")),
        WelcomeSheetFeatureRow(icon: "exclamationmark.octagon.fill", header: String.appLocalized("New Toasts"), subtitle: String.appLocalized("Similarly, alert toasts across the app have been re-designed.")),
        WelcomeSheetFeatureRow(icon: "calendar", header: String.appLocalized("Custom Time Frames"), subtitle: String.appLocalized("Change the start of a month's cycle to align with payday."))
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear.opacity(opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissSheet()
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(String.appLocalized("Close"))
                .onAppear {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(150))
                        withAnimation {
                            opacity = 0.4
                        }
                    }
                }

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(.callout, design: .rounded))
//                            .font(.system(size: 16))
                        Text("What's New?")
                            .font(.system(.title2, design: .rounded).weight(.medium))
//                            .font(.system(size: 22, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.PrimaryText)

                    Text(
                        String(
                            format: String.appLocalized("Version %@ (%@) · 18 Sep 2023"),
                            UIApplication.appVersion,
                            UIApplication.buildNumber)
                    )
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
//                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.SubtitleText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    Button {
                        dismissSheet()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
//                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.SubtitleText)
                            .padding(7)
                            .background(Color.SecondaryBackground, in: Circle())
                            .contentShape(Circle())
                    }
                    .accessibilityLabel(String.appLocalized("Close"))
                    .offset(x: 5, y: -5)
                }
                .padding(.bottom, 15)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(welcomeFeatures, id: \.self) { row in
                            HStack(alignment: .top, spacing: 15) {
                                Image(systemName: row.icon)
                                    .font(.system(.title2, design: .rounded))
//                                    .font(.system(size: 24, weight: .regular))
                                    .foregroundStyle(Color.SubtitleText)
                                    .frame(width: 35, alignment: .leading)
                                    .offset(y: 2)

                                VStack(alignment: .leading, spacing: 3.5) {
                                    Text(LocalizedStringKey(row.header))
                                        .font(.system(.body, design: .rounded).weight(.medium))
//                                        .font(.system(size: 18, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.PrimaryText)

                                    Text(LocalizedStringKey(row.subtitle))
                                        .font(.system(.subheadline, design: .rounded).weight(.medium))
//                                        .font(.system(size: 16, weight: .regular, design: .rounded))
//                                            .lineSpacing(0.6)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .foregroundStyle(Color.SubtitleText)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .scrollIndicators(.hidden)
                .frame(height: 300)

                Text(
                    AttributedString(String.appLocalized("Special thanks to "))
                        + makeAttributedString()
                        + AttributedString(String.appLocalized(" for contributing"))
                )
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.SubtitleText)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(18)
            .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: GlassRadius.card).stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
            .offset(y: offset)
            .padding(.horizontal, 17)
            .padding(.bottom, bottomEdge == 0 ? 13 : bottomEdge)
            
        }
        .ignoresSafeArea(.all)
        .background(BackgroundBlurView())
    }

    func makeAttributedString() -> AttributedString {
        var string = AttributedString("Yumi")
        string.foregroundColor = Color.PrimaryText
        string.link = URL(string: "https://yumiizumi.com/")

        return string
    }

    private func dismissSheet() {
        withAnimation(.easeIn(duration: 0.15)) {
            opacity = 0
            offset += 300
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            dismiss()
        }
    }
}
