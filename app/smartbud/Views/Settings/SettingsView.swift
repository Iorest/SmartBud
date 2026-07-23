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
    case cloud
    case erase
    case export
    case haptics
    case featureLab
    case numberEntry
    case categories
}

struct SettingsView: View {
  @Environment(\.dynamicTypeSize) var dynamicTypeSize

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
  var firstWeekdayString: String {
    if firstWeekday == 1 {
      return String.appLocalized(SettingsKey.weekdaySunday)
    } else {
      return String.appLocalized(SettingsKey.weekdayMonday)
    }
  }

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
  @Namespace var animation

  var iCloudString: String {
    if NSUbiquitousKeyValueStore.default.bool(forKey: "icloud_sync") {
      return String.appLocalized(SettingsKey.toggleOn)
    } else {
      return String.appLocalized(SettingsKey.toggleOff)
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

  @AppStorage("incomeTracking", store: .appGroup)
  var incomeTracking: Bool = true

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
          Text(String.appLocalized(SettingsKey.title))
            .font(.system(.title, design: .rounded).weight(.semibold))

            //                        .font(.system(size: 25, weight: .semibold, design: .rounded))
            .accessibility(addTraits: .isHeader)
          Spacer()
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
        .padding(.bottom, 10)

        ScrollView {
          VStack(spacing: 5) {
            Text(String.appLocalized(SettingsKey.sectionPro))
              .font(.system(.footnote, design: .rounded).weight(.semibold))
              .foregroundStyle(Color.SubtitleText)
              .padding(.horizontal, 10)
              .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
              NavigationLink(value: SettingsRoute.pro) {
                HStack(spacing: 12) {
                  Image(systemName: "crown.fill")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(
                      width: dynamicTypeSize > .xLarge ? 40 : 30,
                      height: dynamicTypeSize > .xLarge ? 40 : 30,
                      alignment: .center
                    )
                    .background(Color("200"), in: RoundedRectangle(cornerRadius: GlassRadius.pill, style: .continuous))

                  VStack(alignment: .leading, spacing: 2) {
                    Text(String.appLocalized(SettingsKey.proTitle))
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
            Text(String.appLocalized(SettingsKey.sectionGeneral))
              .font(.system(.footnote, design: .rounded).weight(.semibold))

              //                            .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(Color.SubtitleText)
              .padding(.horizontal, 10)
              .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 13) {

              NavigationLink(value: SettingsRoute.notifications) {
                SettingsRowView(
                  systemImage: "bell.fill",
                  title: SettingsKey.rowNotifications,
                  colour: 102,
                  optionalText: notificationString)
              }

              NavigationLink(value: SettingsRoute.currency) {
                SettingsRowView(
                  systemImage: "coloncurrencysign.square.fill",
                  title: SettingsKey.rowCurrency,
                  colour: 103,
                  optionalText: currency)
              }

              NavigationLink(value: SettingsRoute.numberEntry) {
                SettingsRowView(
                  systemImage: "keyboard.fill",
                  title: SettingsKey.rowNumberEntry,
                  colour: 104,
                  optionalText: numberEntryString)
              }

              ToggleRow(
                icon: "faceid", color: "105", text: SettingsKey.rowAuthentication,
                bool: appLockVM.isAppLockEnabled,
                onTap: {
                  appLockVM.appLockStateChange(appLockState: !appLockVM.isAppLockEnabled)
                })

              ToggleRow(
                icon: "banknote.fill", color: "106", text: SettingsKey.rowIncomeTracking, bool: incomeTracking,
                onTap: {
                  incomeTracking.toggle()

                  if !incomeTracking {
                    UserDefaults.appGroup.set(
                      false, forKey: "insightsViewIncomeFiltering")
                    UserDefaults.appGroup.set(
                      3, forKey: "logInsightsType")
                  }
                })

              NavigationLink(value: SettingsRoute.weekStart) {
                SettingsRowView(
                  systemImage: "calendar",
                  title: SettingsKey.rowTimeFrames,
                  colour: 109)
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
            Text(String.appLocalized(SettingsKey.sectionAppearance))
              .font(.system(.footnote, design: .rounded).weight(.semibold))

              //                            .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(Color.SubtitleText)
              .padding(.horizontal, 10)
              .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 13) {
              NavigationLink(value: SettingsRoute.appearance) {
                SettingsRowView(
                  systemImage: "circle.righthalf.filled",
                  title: SettingsKey.rowTheme,
                  colour: 100,
                  optionalText: colourSchemeString)
              }

              NavigationLink(value: SettingsRoute.appIcon) {
                SettingsRowView(
                  systemImage: "app.badge.fill",
                  title: SettingsKey.rowAppIcon,
                  colour: 101,
                  optionalText: appIconString)
              }

              NavigationLink(value: SettingsRoute.language) {
                SettingsRowView(
                  systemImage: "globe",
                  title: SettingsKey.rowLanguage,
                  colour: 132,
                  optionalText: appLanguageString)
              }

              ToggleRow(
                icon: "centsign.circle.fill", color: "107", text: SettingsKey.rowDisplayCents, bool: showCents,
                onTap: {
                  showCents.toggle()
                })

              NavigationLink(value: SettingsRoute.upcoming) {
                SettingsRowView(
                  systemImage: "sun.min.fill",
                  title: SettingsKey.rowUpcomingLogs,
                  colour: 108,
                  optionalText: upcomingString)
              }

              ToggleRow(
                icon: "plusminus", color: "123", text: SettingsKey.rowDisplaySign, bool: showExpenseOrIncomeSign,
                onTap: {
                    showExpenseOrIncomeSign.toggle()
                })

              ToggleRow(
                icon: "hare.fill", color: "121", text: SettingsKey.rowAnimatedCharts, bool: animated, smaller: true,
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
            Text(String.appLocalized(SettingsKey.sectionData))
              .font(.system(.footnote, design: .rounded).weight(.semibold))

              //                            .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(Color.SubtitleText)
              .padding(.horizontal, 10)
              .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 13) {
              NavigationLink(value: SettingsRoute.categories) {
                SettingsRowView(
                  systemImage: "rectangle.grid.2x2.fill",
                  title: SettingsKey.rowCategories,
                  colour: 110)
              }

              NavigationLink(value: SettingsRoute.cloud) {
                SettingsRowView(
                  systemImage: "icloud.fill",
                  title: SettingsKey.rowICloudSync,
                  colour: 111,
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
                  systemImage: "square.and.arrow.down.fill",
                  title: SettingsKey.rowImportData,
                  colour: 112)
              }

              NavigationLink(value: SettingsRoute.export) {
                SettingsRowView(
                  systemImage: "square.and.arrow.up.fill",
                  title: SettingsKey.rowExportData,
                  colour: 113)
              }

              NavigationLink(value: SettingsRoute.erase) {
                SettingsRowView(
                  systemImage: "xmark.bin.fill",
                  title: SettingsKey.rowEraseData,
                  colour: 114)
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
            Text(String.appLocalized(SettingsKey.sectionOthers))
              .font(.system(.footnote, design: .rounded).weight(.semibold))

              //                            .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(Color.SubtitleText)
              .padding(.horizontal, 10)
              .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 13) {

                NavigationLink(value: SettingsRoute.haptics) {
                  SettingsRowView(
                    systemImage: "hand.tap.fill",
                    title: SettingsKey.rowHaptics,
                    colour: 100,
                    optionalText: hapticString)
                }

              NavigationLink(value: SettingsRoute.featureLab) {
                SettingsRowView(
                  systemImage: "flame.fill",
                  title: SettingsKey.rowFeatureLab,
                  colour: 122)
              }

              Button {
                supportEmail.send(openURL: openURL)
              } label: {
                SettingsRowView(
                  systemImage: "ladybug.fill",
                  title: SettingsKey.rowReportBug,
                  colour: 124)
              }

              Button {
                featureRequestEmail.send(openURL: openURL)
              } label: {
                SettingsRowView(
                  systemImage: "hand.wave.fill",
                  title: SettingsKey.rowFeatureRequest,
                  colour: 125)
              }

              Button {
                // TODO: Replace `id1635280255` with SmartBud's App Store ID
                // once SmartBud is published as a new App Store Connect listing.
                // The current ID points to the legacy listing, which keeps the
                // "Rate on App Store" link functional for users on the old listing.
                if let writeReviewURL = URL(string: "https://apps.apple.com/app/id1635280255?action=write-review") {
                  openURL(writeReviewURL)
                }
              } label: {
                SettingsRowView(
                  systemImage: "star.fill",
                  title: SettingsKey.rowRateAppStore,
                  colour: 126)
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
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .background(AppGlassBackground())
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
          case .cloud: SettingsCloudView()
          case .erase: SettingsEraseView()
          case .export: SettingsExportView()
          case .haptics: SettingsHapticsView()
          case .featureLab: SettingsGoofyView()
          case .numberEntry:
            SettingsNumberEntryView()
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
          case .categories:
            SettingsCategoryView()
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
          }
      }
      .fullScreenCover(isPresented: $showImportGuide) {
        ImportDataView()
      }
      .fullScreenCover(isPresented: .constant(CommandLine.arguments.contains("-openPro"))) {
        NavigationStack { SettingsProView() }
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
          .background(Color(color), in: RoundedRectangle(cornerRadius: GlassRadius.pill))
          .accessibilityHidden(true)

        Text(String.appLocalized(text))
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
    .accessibilityLabel(String.appLocalized(text))
    .accessibilityValue(bool ? String.appLocalized(SettingsKey.toggleOn) : String.appLocalized(SettingsKey.toggleOff))
    .accessibilityAddTraits(bool ? [.isButton, .isSelected] : .isButton)
  }

  func exportData() {
    // Replaced by SettingsExportView (GDPR Article 20 — full JSON
    // export including categories, budgets and templates; not just
    // the transaction CSV this function used to produce). The row
    // in the Settings data section now navigates to that view
    // instead of calling this stub.
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
        .background(Color("\(colour)"), in: RoundedRectangle(cornerRadius: GlassRadius.pill, style: .continuous))

      Text(String.appLocalized(title))
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
