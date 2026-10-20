//
//  SettingsUpcomingView.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsUpcomingView: View {
  @Environment(\.dismiss) var dismiss
  @AppStorage("showUpcomingTransactions", store: .appGroup)
  var showFuture: Bool = true

  @AppStorage("showUpcomingTransactionsWhenUpcoming", store: .appGroup)
  var showSoon: Bool = false

  @Namespace var animation

  var body: some View {
    VStack(spacing: 10) {
      Text(String.appLocalized("Upcoming Logs"))
        .font(.title3.weight(.semibold))
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

      VStack(spacing: 0) {
        Button {
          showFuture.toggle()
        } label: {
          HStack {
            Text(String.appLocalized("Display on Log Page"))
              .font(.body)
              .foregroundStyle(Color.PrimaryText)

            Spacer()

            ZStack(alignment: showFuture ? .trailing : .leading) {
              Capsule()
                .frame(width: 42, height: 28)
                .foregroundStyle(showFuture ? .green : .gray.opacity(0.8))

              Circle()
                .foregroundStyle(Color.white)
                .padding(2)
                .frame(width: 28, height: 28)
                .matchedGeometryEffect(id: "toggle1", in: animation)
            }
          }
          .frame(maxWidth: .infinity)
          .contentShape(Rectangle())
          .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(showFuture ? [.isButton, .isSelected] : .isButton)
        .onChange(of: showFuture) { _, newValue in
          // Cross-toggle: hiding all upcoming transactions also turns off
          // the 14-day outlook filter.
          if !newValue && showSoon {
            showSoon = false
          }
        }

        Button {
          showSoon.toggle()
        } label: {
          HStack {
            Text(String.appLocalized("Limit to 14-Day Outlook"))
              .font(.body)
              .foregroundStyle(Color.PrimaryText)

            Spacer()

            ZStack(alignment: showSoon ? .trailing : .leading) {
              Capsule()
                .frame(width: 42, height: 28)
                .foregroundStyle(showSoon ? .green : .gray.opacity(0.8))

              Circle()
                .foregroundStyle(Color.white)
                .padding(2)
                .frame(width: 28, height: 28)
                .matchedGeometryEffect(id: "toggle2", in: animation)
            }
          }
          .frame(maxWidth: .infinity)
          .contentShape(Rectangle())
          .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(showSoon ? [.isButton, .isSelected] : .isButton)
      }
      .padding(.horizontal, 15)
      .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: SBRadius.chip))

      Text(
        String.appLocalized("Don't worry, even if you do hide them there, you will aways be able to find all upcoming transactions right here.")
      )
      .font(.caption.weight(.medium))
      .multilineTextAlignment(.leading)
      .foregroundStyle(Color.SubtitleText)
      .padding(.horizontal, 15)
      .padding(.bottom, 30)
      .frame(maxWidth: .infinity, alignment: .leading)

      ScrollView {
        FutureListView(filterMode: false, limitedMode: false)
          .padding(.bottom, 70)
      }
      .scrollIndicators(.hidden)
    }
    .modifier(SettingsSubviewModifier())
  }
}
