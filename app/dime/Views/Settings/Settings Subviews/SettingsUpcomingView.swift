//
//  SettingsUpcomingView.swift
//  dime
//
//  Created by Rafael Soh on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsUpcomingView: View {
  @Environment(\.dismiss) var dismiss
  @State private var showFuture: Bool = true

  @State private var showSoon: Bool = false

  @Namespace var animation

  var body: some View {
    VStack(spacing: 10) {
      Text("Upcoming Logs")
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

      VStack(spacing: 0) {
        Button {
          showFuture.toggle()
        } label: {
          HStack {
            Text("Display on Log Page")
              .font(.system(.body, design: .rounded))
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
          UserDefaults.appGroup.set(
            newValue, forKey: "showUpcomingTransactions")

          if !newValue {
            showSoon = false
            UserDefaults.appGroup.set(
              false, forKey: "showUpcomingTransactionsWhenUpcoming")
          }
        }

        Button {
          showSoon.toggle()
        } label: {
          HStack {
            Text("Limit to 14-Day Outlook")
              .font(.system(.body, design: .rounded))
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
        .onChange(of: showSoon) { _, newValue in
          UserDefaults.appGroup.set(
            newValue, forKey: "showUpcomingTransactionsWhenUpcoming")
        }
      }
      .padding(.horizontal, 15)
      .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: 9))

      Text(
        "Don't worry, even if you do hide them there, you will aways be able to find all upcoming transactions right here."
      )
      .font(.system(.caption, design: .rounded).weight(.medium))
      .multilineTextAlignment(.leading)
      .foregroundStyle(Color.SubtitleText)
      .padding(.horizontal, 15)
      .padding(.bottom, 30)
      .frame(maxWidth: .infinity, alignment: .leading)

      ScrollView(showsIndicators: false) {
        FutureListView(filterMode: false, limitedMode: false)
          .padding(.bottom, 70)
      }
    }
    .modifier(SettingsSubviewModifier())
    .onAppear {
      showFuture = UserDefaults.appGroup.bool(
        forKey: "showUpcomingTransactions")
      showSoon = UserDefaults.appGroup.bool(
        forKey: "showUpcomingTransactionsWhenUpcoming")
    }
  }
}
