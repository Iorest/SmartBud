//
//  SettingsView.swift
//  smartbud
//
//  Created by Iorest on 20/5/22.
//

import Foundation
import StoreKit
import SwiftUI
import UserNotifications
import WidgetKit

struct SettingsView: View {
  @Environment(\.dynamicTypeSize) var dynamicTypeSize

  @AppStorage("colourScheme", store: .appGroup)
  var colourScheme: Int = 0
  var colourSchemeString: String {
    if colourScheme == 1 {
      return String(localized: "Light")
    } else if colourScheme == 2 {
      return String(localized: "Dark")
    } else {
      return String(localized: "System")
    }
  }

  @AppLanguage var appLanguage: String = ""
  var appLanguageString: String {
    settingsVM.displayName(for: appLanguage)
  }

  @AppStorage("activeIcon", store: .appGroup)
  var activeIcon: String = "AppIcon"
  var appIconString: String {
    switch activeIcon {
    case "AppIcon":  return String(localized: "Deep Sea · 深青")
    case "AppIcon1": return String(localized: "Midnight · 紫袋辉光")
    case "AppIcon2": return String(localized: "Plum · 紫袋")
    case "AppIcon3": return String(localized: "Indigo · 深紫")
    case "AppIcon4": return String(localized: "Sky · 浅蓝")
    case "AppIcon5": return String(localized: "Sunset · 黄昏")
    case "AppIcon6": return String(localized: "Aqua · 浅青辉光")
    default:         return String(localized: "Deep Sea · 深青")
    }
  }

  @AppStorage("firstWeekday", store: .appGroup)
  var firstWeekday: Int = 1
  var firstWeekdayString: String {
    if firstWeekday == 1 {
      return String(localized: "Sunday")
    } else {
      return String(localized: "Monday")
    }
  }

  @AppStorage("showNotifications", store: .appGroup)
  var showNotifications: Bool = false
  @AppStorage("notificationOption", store: .appGroup)
  var option: Int = 1
  var notificationString: String {
    if showNotifications {
      if option == 1 {
        return String(localized: "Mornings")
      } else if option == 2 {
        return String(localized: "Evenings")
      } else {
        return String(localized: "Custom")
      }
    } else {
      return String(localized: "Off")
    }
  }

  @Environment(AppLockViewModel.self) var appLockVM
  @Namespace var animation

  var iCloudString: String {
    if NSUbiquitousKeyValueStore.default.bool(forKey: "icloud_sync") {
      return String(localized: "On")
    } else {
      return String(localized: "Off")
    }
  }

  @Environment(\.openURL) var openURL
  let supportEmail = SupportEmail(toAddress: "iorest@qq.com", subject: "Support Email")
  let featureRequestEmail = SupportEmail(
    toAddress: "iorest@qq.com", subject: "Feature Request")

  @AppStorage("numberEntryType", store: .appGroup)
  var numberEntryType: Int = 2

  var numberEntryString: String {
    if numberEntryType == 1 {
      return String(localized: "Type 1")
    } else {
      return String(localized: "Type 2")
    }
  }

  @AppStorage("showCents", store: .appGroup)
  var showCents: Bool = true

  @AppStorage("animated", store: .appGroup) var animated:
    Bool = true

  @AppStorage("currency", store: .appGroup) var currency:
    String = Locale.current.currency?.identifier ?? "USD"

  @AppStorage("incomeTracking", store: .appGroup)
  var incomeTracking: Bool = true
    
  @AppStorage("showExpenseOrIncomeSign", store: .appGroup)
  var showExpenseOrIncomeSign: Bool = true

  @AppStorage(
    "showUpcomingTransactions", store: .appGroup)
  var showUpcoming: Bool = true

  var upcomingString: String {
    if showUpcoming {
      return String(localized: "Shown")
    } else {
      return String(localized: "Hidden")
    }
  }

    @AppStorage("haptics", store: .appGroup)
    var hapticType: Int = 1

    var hapticString: String {
      if hapticType == 0 {
        return String(localized: "None")
      } else if hapticType == 1 {
        return String(localized: "Subtle")
      } else {
        return String(localized: "Excessive")
      }
    }

  // popups

  @State var showImportGuide = false
  @State var showExportError = false
  @State var exportErrorMessage = ""

  @Environment(TabBarManager.self) var tabBarManager

  @Environment(\.modelContext) var modelContext

  @State var settingsVM = SettingsViewModel.shared

    /// Cap each settings card at this many points. Used inside the
    /// `cardMaxWidthFrame` modifier so the cap is applied as a container-
    /// relative frame (full width on iPhone, capped on iPad/Pro Max).
    /// iPhone screens are already under this, so visible behaviour is
    /// unchanged there.
    private static let cardMaxWidth: CGFloat = 540

    /// Relative-to-container width cap. Returns the container's full width,
    /// but never more than `cardMaxWidth`. Use as:
    ///   `.containerRelativeFrame(.horizontal, alignment: .center) { w, _ in
    ///       cardMaxWidthFrame(width: w) }`
    private func cardMaxWidthFrame(width: CGFloat) -> CGFloat {
        min(width, Self.cardMaxWidth)
    }

    var body: some View {
      NavigationStack {
      VStack {
        HStack {
          Text(String(localized: "Settings"))
            .font(.system(.title, design: .rounded).weight(.semibold))

            //                        .font(.system(size: 25, weight: .semibold, design: .rounded))
            .accessibility(addTraits: .isHeader)
          Spacer()
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
        .padding(.bottom, 10)

        ScrollView(showsIndicators: false) {
          VStack(spacing: 5) {
            Text("PRO")
              .font(.system(.footnote, design: .rounded).weight(.semibold))
              .foregroundStyle(Color.SubtitleText)
              .padding(.horizontal, 10)
              .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
              NavigationLink(destination: SettingsProView()) {
                HStack(spacing: 12) {
                  Image(systemName: "crown.fill")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(
                      width: dynamicTypeSize > .xLarge ? 40 : 30,
                      height: dynamicTypeSize > .xLarge ? 40 : 30,
                      alignment: .center
                    )
                    .background(Color("200"), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                  VStack(alignment: .leading, spacing: 2) {
                    Text("SmartBud Pro")
                      .font(.system(.body, design: .rounded).weight(.semibold))
                      .foregroundStyle(Color.PrimaryText)
                      .lineLimit(1)

                    Text(settingsVM.proCardSubtitle)
                      .font(.system(.footnote, design: .rounded))
                      .foregroundStyle(Color.SubtitleText)
                      .lineLimit(1)
                  }

                  Spacer()

                  Image(systemName: "chevron.forward")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.DarkIcon.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
              }
            }
            .padding(10)
            .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 25)
          .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
              cardMaxWidthFrame(width: width)
          }

          VStack(spacing: 5) {
            Text("GENERAL")
              .font(.system(.footnote, design: .rounded).weight(.semibold))

              //                            .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(Color.SubtitleText)
              .padding(.horizontal, 10)
              .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 13) {

              NavigationLink(destination: SettingsNotificationsView()) {
                SettingsRowView(
                  systemImage: "bell.fill", title: "Notifications", colour: 102,
                  optionalText: notificationString)
              }

              NavigationLink(destination: SettingsCurrencyView()) {
                SettingsRowView(
                  systemImage: "coloncurrencysign.square.fill", title: "Currency", colour: 103,
                  optionalText: currency)
              }

              NavigationLink(
                destination: SettingsNumberEntryView()
                  .onAppear {
                    withAnimation(.easeOut.speed(1.5)) {
                      tabBarManager.navigationHideTab()
                    }
                  }
                  .onDisappear {
                    withAnimation(.easeOut.speed(1.5)) {
                      tabBarManager.navigationShowTab()
                    }
                  }
              ) {
                SettingsRowView(
                  systemImage: "keyboard.fill", title: "Number Entry", colour: 104,
                  optionalText: numberEntryString)
              }

              ToggleRow(
                icon: "faceid", color: "105", text: "Authentication",
                bool: appLockVM.isAppLockEnabled,
                onTap: {
                  appLockVM.appLockStateChange(appLockState: !appLockVM.isAppLockEnabled)
                })

              ToggleRow(
                icon: "banknote.fill", color: "106", text: "Income Tracking", bool: incomeTracking,
                onTap: {
                  incomeTracking.toggle()

                  if !incomeTracking {
                    UserDefaults.appGroup.set(
                      false, forKey: "insightsViewIncomeFiltering")
                    UserDefaults.appGroup.set(
                      3, forKey: "logInsightsType")
                  }
                })

              NavigationLink(destination: SettingsWeekStartView()) {
                SettingsRowView(systemImage: "calendar", title: "Time Frames", colour: 109)
              }
                
            }
            .padding(10)
            .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 25)
          .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
              cardMaxWidthFrame(width: width)
          }
          .onChange(of: currency) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
          }
          .onChange(of: firstWeekday) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
          }
          .onChange(of: showCents) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
          }

          VStack(spacing: 5) {
            Text("APPEARANCE")
              .font(.system(.footnote, design: .rounded).weight(.semibold))

              //                            .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(Color.SubtitleText)
              .padding(.horizontal, 10)
              .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 13) {
              NavigationLink(destination: SettingsAppearanceView()) {
                SettingsRowView(
                  systemImage: "circle.righthalf.filled", title: "Theme", colour: 100,
                  optionalText: colourSchemeString)
              }

              NavigationLink(destination: SettingsAppIconView()) {
                SettingsRowView(
                  systemImage: "app.badge.fill", title: "App Icon", colour: 101,
                  optionalText: appIconString)
              }

              NavigationLink(destination: SettingsLanguageView()) {
                SettingsRowView(
                  systemImage: "globe", title: "Language", colour: 132,
                  optionalText: appLanguageString)
              }

              ToggleRow(
                icon: "centsign.circle.fill", color: "107", text: "Display Cents", bool: showCents,
                onTap: {
                  showCents.toggle()
                })

              NavigationLink(destination: SettingsUpcomingView()) {
                SettingsRowView(
                  systemImage: "sun.min.fill", title: "Upcoming Logs", colour: 108,
                  optionalText: upcomingString)
              }
                
              ToggleRow(
                icon: "plusminus", color: "123", text: "Display +/- Symbol", bool: showExpenseOrIncomeSign,
                onTap: {
                    showExpenseOrIncomeSign.toggle()
                })

              ToggleRow(
                icon: "hare.fill", color: "121", text: "Animated Charts", bool: animated, smaller: true,
                onTap: {
                  animated.toggle()
                })

            }
            .padding(10)
            .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 25)
          .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
              cardMaxWidthFrame(width: width)
          }
          .onChange(of: currency) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
          }
          .onChange(of: firstWeekday) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
          }
          .onChange(of: showCents) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
          }

          VStack(spacing: 5) {
            Text("DATA")
              .font(.system(.footnote, design: .rounded).weight(.semibold))

              //                            .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(Color.SubtitleText)
              .padding(.horizontal, 10)
              .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 13) {
              NavigationLink(
                destination: SettingsCategoryView()
                  .onAppear {
                    withAnimation(.easeOut.speed(1.5)) {
                      tabBarManager.navigationHideTab()
                    }
                  }
                  .onDisappear {
                    withAnimation(.easeOut.speed(1.5)) {
                      tabBarManager.navigationShowTab()
                    }
                  }

              ) {
                SettingsRowView(
                  systemImage: "rectangle.grid.2x2.fill", title: "Categories", colour: 110)
              }

              NavigationLink(destination: SettingsCloudView()) {
                SettingsRowView(
                  systemImage: "icloud.fill", title: "iCloud Sync", colour: 111,
                  optionalText: iCloudString)
              }

              //
              //                            NavigationLink(destination: SettingsQuickAddWidgetView()) {
              //                                SettingsRowView(systemImage: "bolt.square.fill", title: "Quick-Add Widget", colour: 115)
              //                            }

              Button {
                showImportGuide = true
              } label: {
                SettingsRowView(
                  systemImage: "square.and.arrow.down.fill", title: "Import Data", colour: 112)
              }

              Button {
                exportData()
              } label: {
                SettingsRowView(
                  systemImage: "square.and.arrow.up.fill", title: "Export Data", colour: 113)
              }

              NavigationLink(destination: SettingsEraseView()) {
                SettingsRowView(systemImage: "xmark.bin.fill", title: "Erase Data", colour: 114)
              }
            }
            .padding(10)
            .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 25)
          .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
              cardMaxWidthFrame(width: width)
          }

          VStack(spacing: 5) {
            Text("OTHERS")
              .font(.system(.footnote, design: .rounded).weight(.semibold))

              //                            .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(Color.SubtitleText)
              .padding(.horizontal, 10)
              .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 13) {

                NavigationLink(destination: SettingsHapticsView()) {
                  SettingsRowView(
                    systemImage: "hand.tap.fill", title: "Haptics", colour: 100,
                    optionalText: hapticString)
                }

              NavigationLink(destination: SettingsGoofyView()) {
                SettingsRowView(systemImage: "flame.fill", title: "Feature Lab", colour: 122)
              }

              Button {
                supportEmail.send(openURL: openURL)
              } label: {
                SettingsRowView(systemImage: "ladybug.fill", title: "Report Bug", colour: 124)
              }

              Button {
                featureRequestEmail.send(openURL: openURL)
              } label: {
                SettingsRowView(
                  systemImage: "hand.wave.fill", title: "Feature Request", colour: 125)
              }

              Button {
                // TODO: Replace `id1635280255` with SmartBud's App Store ID
                // once SmartBud is published as a new App Store Connect listing.
                // The current ID points to the legacy listing, which keeps the
                // "Rate on App Store" link functional for users on the old listing.
                let url = "https://apps.apple.com/app/id1635280255?action=write-review"
                if let writeReviewURL = URL(string: url) {
                    UIApplication.shared.open(writeReviewURL, options: [:], completionHandler: nil)
                }
              } label: {
                SettingsRowView(systemImage: "star.fill", title: "Rate on App Store", colour: 126)
              }

            }
            .padding(10)
            .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 15)
          .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
              cardMaxWidthFrame(width: width)
          }
          .padding(.bottom, 95)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
      }
      .background(AppGlassBackground())
      .fullScreenCover(isPresented: $showImportGuide) {
        ImportDataView()
      }
      .fullScreenCover(isPresented: .constant(CommandLine.arguments.contains("-openPro"))) {
        NavigationStack { SettingsProView() }
      }
      .alert(String(localized: "Export Failed"), isPresented: $showExportError) {
        Button(String(localized: "OK"), role: .cancel) {}
      } message: {
        Text(exportErrorMessage)
      }
    }
  }

  @ViewBuilder
    func ToggleRow(icon: String, color: String, text: String, bool: Bool, smaller: Bool = false, onTap: @escaping () -> Void)
    -> some View {
    Button {
      withAnimation {
        onTap()
      }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(smaller ? .subheadline : .body, design: .rounded))
          .foregroundStyle(.white)
          .frame(
            width: dynamicTypeSize > .xLarge ? 40 : 30, height: dynamicTypeSize > .xLarge ? 40 : 30,
            alignment: .center
          )
          .background(Color(color), in: RoundedRectangle(cornerRadius: 6))
          .accessibilityHidden(true)

        Text(LocalizedStringKey(text))
          .font(.system(.body, design: .rounded).weight(.medium))
          .lineLimit(1)
          .foregroundStyle(Color.PrimaryText)

        Spacer()

        ZStack(alignment: bool ? .trailing : .leading) {
          Capsule()
            .frame(width: 42, height: 28)
            .foregroundStyle(bool ? .green : .gray.opacity(0.8))

          Circle()
            .foregroundStyle(Color.white)
            .padding(2)
            .frame(width: 28, height: 28)
            .matchedGeometryEffect(id: "toggle\(color)", in: animation)
        }
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(LocalizedStringKey(text))
    .accessibilityAddTraits(bool ? [.isButton, .isSelected] : .isButton)
  }

  func shareSheet(url: String) {
    let url = URL(string: url)
    let activityView = UIActivityViewController(activityItems: [url!], applicationActivities: nil)

    let allScenes = UIApplication.shared.connectedScenes
    let scene = allScenes.first { $0.activationState == .foregroundActive }

    if let windowScene = scene as? UIWindowScene {
      windowScene.keyWindow?.rootViewController?.present(
        activityView, animated: true, completion: nil)
    }
  }

  func exportData() {
    let transactions = settingsVM.fetchAllTransactions()

    let fileName = "export.csv"
    let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
    var csvText = String(localized: "Date,Note,Amount,Category,Type\n")

    for transaction in transactions {
      var string = transaction.wrappedNote
      let type: String

      if transaction.income {
        type = String(localized: "Income")
      } else {
        type = String(localized: "Expense")
      }

      string.removeAll(where: { $0 == "," })

      csvText +=
        "\(transaction.wrappedDate),\(string),\(transaction.wrappedAmount.formatted(.number.precision(.fractionLength(2)))),\(transaction.category?.wrappedName ?? ""),\(type)\n"
    }

    var writeSucceeded = false
    do {
        try csvText.write(to: path!, atomically: true, encoding: String.Encoding.utf8)
        writeSucceeded = true
    } catch {
        exportErrorMessage = error.localizedDescription
        showExportError = true
    }

    guard writeSucceeded else {
        return
    }

    var filesToShare = [Any]()
    filesToShare.append(path!)

    let av = UIActivityViewController(activityItems: filesToShare, applicationActivities: nil)

    let allScenes = UIApplication.shared.connectedScenes
    let scene = allScenes.first { $0.activationState == .foregroundActive }

    if let windowScene = scene as? UIWindowScene {
      windowScene.keyWindow?.rootViewController?.present(av, animated: true, completion: nil)
    }
  }
}

struct SettingsRowView: View {
  var systemImage: String
  var title: String
  var colour: Int
  var optionalText: String?

  @Environment(\.dynamicTypeSize) var dynamicTypeSize

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(.body, design: .rounded))

        //                .font(.system(size: 17))
        //                .padding(5)
        .foregroundStyle(.white)
        .frame(
          width: dynamicTypeSize > .xLarge ? 40 : 30, height: dynamicTypeSize > .xLarge ? 40 : 30,
          alignment: .center
        )
        .background(Color("\(colour)"), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

      Text(LocalizedStringKey(title))
        .font(.system(.body, design: .rounded).weight(.medium))

        //                .font(.system(size: 17, weight: .medium, design: .rounded))
        .lineLimit(1)
        .foregroundStyle(Color.PrimaryText)

      Spacer()

      if optionalText != nil {
        Text(optionalText!)
          .font(.system(.body, design: .rounded))

          //                    .font(.system(size: 17, weight: .regular, design: .rounded))
          .foregroundStyle(Color.DarkIcon.opacity(0.6))
          .layoutPriority(1)
          .padding(.trailing, -8)
      }

      Image(systemName: "chevron.forward")
        .font(.system(.subheadline, design: .rounded))
        //                .font(.system(size: 15))
        .foregroundStyle(Color.DarkIcon.opacity(0.6))
    }
    .frame(maxWidth: .infinity)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
  }
}

struct SettingsCategoryView: View {
  @Environment(\.dismiss) var dismiss

  var body: some View {
      CategoryView(mode: .settings, income: false)
      .navigationBarBackButtonHidden(true)
      .toolbar(.hidden, for: .navigationBar)
      .background(Color.clear)
  }
}
