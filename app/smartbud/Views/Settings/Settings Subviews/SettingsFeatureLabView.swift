//
//  SettingsFeatureLabView.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsGoofyView: View {
  @Environment(\.dismiss) var dismiss

  @AppStorage("confetti", store: .appGroup) var confetti:
    Bool = false

  //    @AppStorage("chromatic", store: .appGroup) var chromatic: Bool = false

  @AppStorage("logViewLineGraph", store: .appGroup)
  var lineGraph: Bool = false

  @AppStorage("budgetViewStyle", store: .appGroup)
  var budgetRows: Bool = false

  @AppStorage("swapTimeLabel", store: .appGroup)
  var swapTimeLabel: Bool = false

  @AppStorage(
    "showTransactionRecommendations", store: .appGroup)
  var showRecommendations: Bool = false

  @Namespace var animation

  var body: some View {
    VStack(spacing: 10) {
      Text(String.appLocalized("Feature Lab"))
        .font(.system(.title3, design: .rounded).weight(.semibold))
        //                .font(.system(size: 20, weight: .semibold, design: .rounded))
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

      ScrollView {
        VStack(spacing: 0) {
          ToggleRow(text: String.appLocalized("Celebrate Expenses"), bool: $confetti, id: 1)

          ToggleRow(text: String.appLocalized("Show Line Graph"), bool: $lineGraph, id: 2)

          ToggleRow(text: String.appLocalized("Budget Rows"), bool: $budgetRows, id: 3)
        }
        .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: GlassRadius.chip))

        Text(String.appLocalized("Experimental features - proceed with caution."))
          .font(.system(.caption, design: .rounded).weight(.medium))
          //                    .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(Color.SubtitleText)
          .padding(.horizontal, 15)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, 30)

        ToggleRow(text: String.appLocalized("Replace Time Label"), bool: $swapTimeLabel, id: 4)
          .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: GlassRadius.chip))

        Text(
          String.appLocalized("Swaps the time label of each transaction with its category name. However, if you do not manually input a note for each transaction - in which case the note is the category name by default - duplicate text will appear.")
        )
        .font(.system(.caption, design: .rounded).weight(.medium))
        //                    .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(Color.SubtitleText)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 30)

        ToggleRow(text: String.appLocalized("Show Note Suggestions"), bool: $showRecommendations, id: 5)
          .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: GlassRadius.chip))

        Text(
          String.appLocalized("Displays transaction suggestions whilst you type in the 'Note' field of the new transaction page.")
        )
        .font(.system(.caption, design: .rounded).weight(.medium))
        //                    .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(Color.SubtitleText)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 30)
      }

      //            ToggleRow(text: "Miles-Morales Effect", bool: $chromatic, id: 5)
      //            .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: GlassRadius.chip))
      //
      //            Text("Enables a chromatic abberation effect on the 'New Transaction' page when a future date is set.")
      //                .font(.system(size: 12, weight: .medium, design: .rounded))
      //                .foregroundStyle(Color.SubtitleText)
      //                .padding(.horizontal, 15)
      //                .frame(maxWidth: .infinity, alignment: .leading)
      //                .padding(.bottom, 30)
    }
    .modifier(SettingsSubviewModifier())
  }

  @ViewBuilder
  func ToggleRow(text: String, bool: Binding<Bool>, id: Int) -> some View {
    Button {
      withAnimation {
        bool.wrappedValue.toggle()
      }
    } label: {
      HStack {
        Text(text)
          .font(.system(.body, design: .rounded))
          //                .font(.system(size: 17, weight: .regular, design: .rounded))
          .foregroundStyle(Color.PrimaryText)

        Spacer()

        ZStack(alignment: bool.wrappedValue ? .trailing : .leading) {
          Capsule()
            .frame(width: 42, height: 28)
            .foregroundStyle(bool.wrappedValue ? .green : .gray.opacity(0.8))

          Circle()
            .foregroundStyle(Color.white)
            .padding(2)
            .frame(width: 28, height: 28)
            .matchedGeometryEffect(id: "toggle\(id)", in: animation)
        }
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
      .padding(.vertical, 9)
      .padding(.horizontal, 15)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(bool.wrappedValue ? [.isButton, .isSelected] : .isButton)
  }
}
