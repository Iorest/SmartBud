//
//  SettingsView.swift
//  smartbud
//
//  Created by Iorest on 20/5/22.
//

import Foundation
import StoreKit
import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Navigation routes for `SettingsView`. The 12 leaf screens in Settings are
/// all `View` types with no parameters, so a single `Hashable` enum covers
/// every value-based `NavigationLink` in the screen. The `navigationDestination`
/// resolver lives at the bottom of `SettingsView` and dispatches the case to
/// the matching subview.
enum SettingsRoute: Hashable {
    case pro
    case notifications
    case currency
    case weekStart
    case appearance
    case appIcon
    case language
    case upcoming
    case erase
    case export
    case haptics
    case numberEntry
    case categories
    case templates
    case llm
}

struct SettingsView: View {

  @AppStorage("colourScheme", store: .appGroup)
  var colourScheme: Int = 0
  var colourSchemeString: String {
    if colourScheme == 1 {
      return String.appLocalized(SettingsKey.themeLight)
    } else if colourScheme == 2 {
      return String.appLocalized(SettingsKey.themeDark)
    } else {
      return String.appLocalized(SettingsKey.themeSystem)
    }
  }

  @AppStorage(AppDefaultsKey.appLanguage, store: .appGroup) var appLanguage: String = ""
  var appLanguageString: String {
    settingsVM.displayName(for: appLanguage)
  }

  @AppStorage("activeIcon", store: .appGroup)
  var activeIcon: String = "AppIcon"
  var appIconString: String {
    switch activeIcon {
    case "AppIcon":  return String.appLocalized(SettingsKey.iconDeepSea)
    case "AppIcon1": return String.appLocalized(SettingsKey.iconMidnight)
    case "AppIcon2": return String.appLocalized(SettingsKey.iconPlum)
    case "AppIcon3": return String.appLocalized(SettingsKey.iconIndigo)
    case "AppIcon4": return String.appLocalized(SettingsKey.iconSky)
    case "AppIcon5": return String.appLocalized(SettingsKey.iconSunset)
    case "AppIcon6": return String.appLocalized(SettingsKey.iconAqua)
    default:         return String.appLocalized(SettingsKey.iconDeepSea)
    }
  }

  @AppStorage("firstWeekday", store: .appGroup)
  var firstWeekday: Int = 1

  @AppStorage("showNotifications", store: .appGroup)
  var showNotifications: Bool = false
  @AppStorage("notificationOption", store: .appGroup)
  var option: Int = 1
  var notificationString: String {
    if showNotifications {
      if option == 1 {
        return String.appLocalized(SettingsKey.notificationMornings)
      } else if option == 2 {
        return String.appLocalized(SettingsKey.notificationEvenings)
      } else {
        return String.appLocalized(SettingsKey.notificationCustom)
      }
    } else {
      return String.appLocalized(SettingsKey.toggleOff)
    }
  }

  @Environment(AppLockViewModel.self) var appLockVM

  @Environment(\.openURL) var openURL
  let supportEmail = SupportEmail(toAddress: "iorest@qq.com", subject: "Support Email")
  let featureRequestEmail = SupportEmail(
    toAddress: "iorest@qq.com", subject: "Feature Request")

  @AppStorage("numberEntryType", store: .appGroup)
  var numberEntryType: Int = 2

  var numberEntryString: String {
    if numberEntryType == 1 {
      return String.appLocalized(SettingsKey.numberEntryType1)
    } else {
      return String.appLocalized(SettingsKey.numberEntryType2)
    }
  }

  @AppStorage("showCents", store: .appGroup)
  var showCents: Bool = true

  @AppStorage("animated", store: .appGroup) var animated:
    Bool = true

  @AppStorage("currency", store: .appGroup) var currency:
    String = Locale.current.currency?.identifier ?? "USD"

  @AppStorage("showExpenseOrIncomeSign", store: .appGroup)
  var showExpenseOrIncomeSign: Bool = true

  @AppStorage(
    "showUpcomingTransactions", store: .appGroup)
  var showUpcoming: Bool = true

  var upcomingString: String {
    if showUpcoming {
      return String.appLocalized(SettingsKey.upcomingShown)
    } else {
      return String.appLocalized(SettingsKey.upcomingHidden)
    }
  }

    @AppStorage("haptics", store: .appGroup)
    var hapticType: Int = 1

    var hapticString: String {
      if hapticType == 0 {
        return String.appLocalized(SettingsKey.hapticsNone)
      } else if hapticType == 1 {
        return String.appLocalized(SettingsKey.hapticsSubtle)
      } else {
        return String.appLocalized(SettingsKey.hapticsExcessive)
      }
    }

  // popups

  @State var showImportGuide = false

  @State var settingsVM = SettingsViewModel.shared

    var body: some View {
      NavigationStack {
        List {
          Section {
            NavigationLink(value: SettingsRoute.pro) {
              HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                  .font(.body)
                  .foregroundStyle(.white)
                  .frame(width: 30, height: 30)
                  .background(Color("200"), in: RoundedRectangle(cornerRadius: SBRadius.pill, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                  Text(String.appLocalized(SettingsKey.proTitle))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.PrimaryText)

                  Text(settingsVM.proCardSubtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.SubtitleText)
                }
              }
              .padding(.vertical, 2)
            }
          }

          Section(String.appLocalized(SettingsKey.sectionGeneral)) {
            settingsLink(.notifications, "bell.fill", 102, SettingsKey.rowNotifications, notificationString)
            settingsLink(.currency, "coloncurrencysign.square.fill", 103, SettingsKey.rowCurrency, currency)
            settingsLink(.numberEntry, "keyboard.fill", 104, SettingsKey.rowNumberEntry, numberEntryString)

            Toggle(isOn: Binding(
              get: { appLockVM.isAppLockEnabled },
              set: { appLockVM.appLockStateChange(appLockState: $0) }
            )) {
              SettingsRowView(icon: "faceid", colour: 105, title: SettingsKey.rowAuthentication)
            }

            settingsLink(.weekStart, "calendar", 109, SettingsKey.rowTimeFrames, nil)
          }

          Section(String.appLocalized(SettingsKey.sectionAppearance)) {
            settingsLink(.appearance, "circle.righthalf.filled", 100, SettingsKey.rowTheme, colourSchemeString)

            #if !os(macOS)
            settingsLink(.appIcon, "app.badge.fill", 101, SettingsKey.rowAppIcon, appIconString)
            #endif

            settingsLink(.language, "globe", 132, SettingsKey.rowLanguage, appLanguageString)

            Toggle(isOn: $showCents) {
              SettingsRowView(icon: "centsign.circle.fill", colour: 107, title: SettingsKey.rowDisplayCents)
            }

            settingsLink(.upcoming, "sun.min.fill", 108, SettingsKey.rowUpcomingLogs, upcomingString)
            settingsLink(.llm, "sparkles", 110, "AI 服务", nil)

            Toggle(isOn: $showExpenseOrIncomeSign) {
              SettingsRowView(icon: "plusminus", colour: 123, title: SettingsKey.rowDisplaySign)
            }

            Toggle(isOn: $animated) {
              SettingsRowView(icon: "hare.fill", colour: 121, title: SettingsKey.rowAnimatedCharts)
            }
          }

          Section(String.appLocalized(SettingsKey.sectionData)) {
            settingsLink(.categories, "rectangle.grid.2x2.fill", 110, SettingsKey.rowCategories, nil)
            settingsLink(.templates, "square.on.square", 122, SettingsKey.rowTemplates, nil)

            Button {
              showImportGuide = true
            } label: {
              SettingsRowView(icon: "square.and.arrow.down.fill", colour: 112, title: SettingsKey.rowImportData)
            }
            .buttonStyle(.plain)

            settingsLink(.export, "square.and.arrow.up.fill", 113, SettingsKey.rowExportData, nil)
            settingsLink(.erase, "xmark.bin.fill", 114, SettingsKey.rowEraseData, nil)
          }

          Section(String.appLocalized(SettingsKey.sectionOthers)) {
            settingsLink(.haptics, "hand.tap.fill", 100, SettingsKey.rowHaptics, hapticString)

            Button {
              supportEmail.send(openURL: openURL)
            } label: {
              SettingsRowView(icon: "ladybug.fill", colour: 124, title: SettingsKey.rowReportBug)
            }
            .buttonStyle(.plain)

            Button {
              featureRequestEmail.send(openURL: openURL)
            } label: {
              SettingsRowView(icon: "hand.wave.fill", colour: 125, title: SettingsKey.rowFeatureRequest)
            }
            .buttonStyle(.plain)

            Button {
              // The listing ID lives in Info.plist so a new App Store
              // Connect listing can be adopted without a code change.
              let storeID = Bundle.main.object(forInfoDictionaryKey: "SmartBudAppStoreID") as? String
                ?? "1635280255"
              if let writeReviewURL = URL(string: "https://apps.apple.com/app/id\(storeID)?action=write-review") {
                openURL(writeReviewURL)
              }
            } label: {
              SettingsRowView(icon: "star.fill", colour: 126, title: SettingsKey.rowRateAppStore)
            }
            .buttonStyle(.plain)
          }
        }
        #if os(macOS)
        .listStyle(.inset)
        .toggleStyle(.switch)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(String.appLocalized(SettingsKey.title))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .onChange(of: currency) { _, _ in
          WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: firstWeekday) { _, _ in
          WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: showCents) { _, _ in
          WidgetCenter.shared.reloadAllTimelines()
        }
        .navigationDestination(for: SettingsRoute.self) { route in
          switch route {
          case .pro: SettingsProView()
          case .notifications: SettingsNotificationsView()
          case .currency: SettingsCurrencyView()
          case .weekStart: SettingsWeekStartView()
          case .appearance: SettingsAppearanceView()
          case .appIcon: SettingsAppIconView()
          case .language: SettingsLanguageView()
          case .upcoming: SettingsUpcomingView()
          case .erase: SettingsEraseView()
          case .export: SettingsExportView()
          case .haptics: SettingsHapticsView()
          case .llm: SettingsLLMView()
          case .numberEntry: SettingsNumberEntryView()
          case .categories: SettingsCategoryView()
          case .templates: TemplatesView()
          }
        }
        .fullScreenPresentation(isPresented: $showImportGuide) {
          ImportDataView()
        }
        .fullScreenPresentation(isPresented: .constant(CommandLine.arguments.contains("-openPro"))) {
          NavigationStack { SettingsProView() }
        }
      }
    }

    @ViewBuilder
    private func settingsLink(_ route: SettingsRoute, _ icon: String, _ colour: Int, _ title: String, _ value: String?) -> some View {
      NavigationLink(value: route) {
        HStack(spacing: 0) {
          SettingsRowView(icon: icon, colour: colour, title: title, value: value)
          #if os(macOS)
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.SubtitleText)
            .padding(.leading, 8)
          #endif
        }
      }
    }
}

struct SettingsRowView: View {
    var icon: String
    var colour: Int
    var title: String
    var value: String?

    init(icon: String, colour: Int, title: String, value: String? = nil) {
        self.icon = icon
        self.colour = colour
        self.title = title
        self.value = value
    }

    private var iconBackground: Color {
        #if os(iOS)
        let exists = UIColor(named: "\(colour)") != nil
        #else
        let exists = NSColor(named: "\(colour)") != nil
        #endif
        return exists ? Color("\(colour)") : Color.accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30, alignment: .center)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: SBRadius.pill, style: .continuous))
                .accessibilityHidden(true)

            Text(String.appLocalized(title))
                .font(.body)
                .foregroundStyle(Color.PrimaryText)
                .lineLimit(2)

            Spacer(minLength: SBSpace.xs)

            if let value, !value.isEmpty {
                Text(value)
                    .font(.body)
                    .foregroundStyle(Color.SubtitleText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingsCategoryView: View {

  var body: some View {
      CategoryView(mode: .settings, income: false)
      .hiddenNavigationBackButton()
      .hiddenNavigationBar()
      .background(Color.clear)
  }
}
