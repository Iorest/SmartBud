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
    case rates
    case weekStart
    case appearance
    case appIcon
    case language
    case upcoming
    case erase
    case export
    case importBackup
    case haptics
    case numberEntry
    case categories
    case accounts
    case books
    case templates
    case llm

    /// Stable suffix for `AccessibilityID.settingsRow(_:)`. Derived from the
    /// case name so adding a route and its row gives a UI test an anchor
    /// without touching the row call site.
    var accessibilityKey: String {
        switch self {
        case .pro: return "pro"
        case .notifications: return "notifications"
        case .currency: return "currency"
        case .rates: return "rates"
        case .weekStart: return "weekStart"
        case .appearance: return "appearance"
        case .appIcon: return "appIcon"
        case .language: return "language"
        case .upcoming: return "upcoming"
        case .erase: return "erase"
        case .export: return "export"
        case .importBackup: return "importBackup"
        case .haptics: return "haptics"
        case .numberEntry: return "numberEntry"
        case .categories: return "categories"
        case .accounts: return "accounts"
        case .books: return "books"
        case .templates: return "templates"
        case .llm: return "llm"
        }
    }
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

  /// One presentation slot for the whole screen. Two stacked
  /// `fullScreenCover` modifiers (import + the -openPro QA hook) cancel each
  /// other out on iOS, so tapping "导入数据" did nothing at all.
  @State private var activeSheet: SettingsSheet?

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
            .accessibilityIdentifier(AccessibilityID.settingsRow(SettingsRoute.pro.accessibilityKey))
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
            settingsLink(.books, "book.fill", 115, SettingsKey.rowBooks, nil)
            settingsLink(.categories, "rectangle.grid.2x2.fill", 110, SettingsKey.rowCategories, nil)
            settingsLink(.accounts, "creditcard.fill", 108, SettingsKey.rowAccounts, nil)
            settingsLink(.templates, "square.on.square", 122, SettingsKey.rowTemplates, nil)

            Button {
              activeSheet = .importData
            } label: {
              SettingsRowView(icon: "square.and.arrow.down.fill", colour: 112, title: SettingsKey.rowImportData)
                // Without this the hit area was just the icon/text: tapping
                // the empty part of the row did nothing.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.settingsImportData)

            settingsLink(.importBackup, "arrow.clockwise.icloud.fill", 105, SettingsKey.rowImportBackup, nil)
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
          case .rates: SettingsRatesView()
          case .weekStart: SettingsWeekStartView()
          case .appearance: SettingsAppearanceView()
          case .appIcon: SettingsAppIconView()
          case .language: SettingsLanguageView()
          case .upcoming: SettingsUpcomingView()
          case .erase: SettingsEraseView()
          case .export: SettingsExportView()
          case .importBackup: SettingsImportView()
          case .haptics: SettingsHapticsView()
          case .llm: SettingsLLMView()
          case .numberEntry: SettingsNumberEntryView()
          case .categories: SettingsCategoryView()
          case .accounts: AccountListView()
          case .templates: TemplatesView()
          case .books: BookManagementView()
          }
        }
        .onChange(of: appLockVM.isAppUnLocked) { _, unlocked in
            // A presented cover would sit above the lock overlay.
            if !unlocked { activeSheet = nil }
        }
        .fullScreenPresentation(item: $activeSheet) { sheet in
          switch sheet {
          case .importData: ImportDataView()
          case .pro: NavigationStack { SettingsProView() }
          }
        }
        .onAppear {
            if CommandLine.arguments.contains("-openPro") { activeSheet = .pro }
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

            Spacer(minLength: SBSpace.extraSmall)

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

// MARK: - Books

/// Which editor is open. Carrying the book in the enum keeps the presented
/// sheet and the row it edits from drifting apart.
private enum BookEditor: Identifiable {
    case create
    case rename(BookModel)
    case duplicate(BookModel)

    var id: String {
        switch self {
        case .create: return "create"
        case .rename(let book): return "rename.\(book.id.uuidString)"
        case .duplicate(let book): return "duplicate.\(book.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .create: return String.appLocalized(SettingsKey.booksNew)
        case .rename: return String.appLocalized(SettingsKey.booksRename)
        case .duplicate: return String.appLocalized(SettingsKey.booksDuplicate)
        }
    }

    var initialName: String {
        switch self {
        case .create: return ""
        case .rename(let book): return book.name
        case .duplicate(let book): return String.appFormatted(SettingsKey.booksCopyName, book.name)
        }
    }
}

/// Ledger management. Books are never deleted: archiving only removes them
/// from the switcher, and every mutation goes through `BookManager` followed
/// by the one save/refresh path below.
struct BookManagementView: View {
    @Environment(BookState.self) private var bookState
    @Environment(\.modelContext) private var modelContext

    @State private var editor: BookEditor?
    @State private var draftName = ""
    @State private var pendingArchive: BookModel?
    @State private var showArchived = false

    private var activeBooks: [BookModel] { bookState.availableBooks.filter { !$0.archived } }
    private var archivedBooks: [BookModel] { bookState.availableBooks.filter(\.archived) }
    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            Section(String.appLocalized(SettingsKey.rowBooks)) {
                ForEach(activeBooks) { book in
                    bookRow(book, archived: false)
                }
            }

            if !archivedBooks.isEmpty {
                Section {
                    if showArchived {
                        ForEach(archivedBooks) { book in
                            bookRow(book, archived: true)
                        }
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showArchived.toggle() }
                    } label: {
                        Text(showArchived
                             ? String.appLocalized("Hide")
                             : String.appLocalized("Show"))
                    }
                } header: {
                    Text(String.appLocalized("Archived"))
                }
            }
        }
        .navigationTitle(String.appLocalized(SettingsKey.rowBooks))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openEditor(.create)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String.appLocalized(SettingsKey.booksNew))
            }
        }
        .sheet(item: $editor) { mode in
            NavigationStack {
                Form {
                    TextField(String.appLocalized("Name"), text: $draftName)
                }
                .navigationTitle(mode.title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String.appLocalized("Cancel")) { closeEditor() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String.appLocalized("Save")) { saveEditor(mode) }
                            .disabled(trimmedName.isEmpty)
                    }
                }
            }
        }
        .alert(String.appLocalized(SettingsKey.booksArchiveTitle), isPresented: Binding(
            get: { pendingArchive != nil },
            set: { if !$0 { pendingArchive = nil } }
        )) {
            Button(String.appLocalized("Archive")) {
                if let pendingArchive { setArchived(pendingArchive, true) }
            }
            Button(String.appLocalized("Cancel"), role: .cancel) { pendingArchive = nil }
        } message: {
            Text(String.appLocalized(SettingsKey.booksArchiveMessage))
        }
    }

    @ViewBuilder
    private func bookRow(_ book: BookModel, archived: Bool) -> some View {
        let current = bookState.currentID == book.id
        HStack(spacing: 8) {
            Button {
                // The one switch path: it also drops cached data, updates
                // widgets and notifies observers of the selection change.
                BookState.shared.select(book.id)
            } label: {
                HStack {
                    Text(book.name.isEmpty ? BookModel.defaultName : book.name)
                        .foregroundStyle(Color.PrimaryText)
                        .lineLimit(1)
                    Spacer(minLength: SBSpace.extraSmall)
                    if current {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    } else {
                        Text(String.appLocalized(archived ? SettingsKey.booksOpen : "Switch"))
                            .font(.footnote)
                            .foregroundStyle(Color.SubtitleText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(current ? AccessibilityTraits.isSelected : [])

            Menu {
                Button(String.appLocalized(SettingsKey.booksRename)) { openEditor(.rename(book)) }
                Button(String.appLocalized(SettingsKey.booksDuplicate)) { openEditor(.duplicate(book)) }
                if archived {
                    Button(String.appLocalized("Unarchive")) { setArchived(book, false) }
                } else if book.id != BookModel.defaultID {
                    // Legacy rows fall back to this book, so there is no
                    // archive action for it (BookManager guards this too).
                    Button(String.appLocalized("Archive")) { pendingArchive = book }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Color.SubtitleText)
            }
        }
    }

    private func openEditor(_ mode: BookEditor) {
        draftName = mode.initialName
        editor = mode
    }

    private func closeEditor() {
        editor = nil
        draftName = ""
    }

    private func saveEditor(_ mode: BookEditor) {
        let name = trimmedName
        guard !name.isEmpty else { return }
        switch mode {
        case .create: BookManager.create(name: name, in: modelContext)
        case .rename(let book): BookManager.rename(book, to: name)
        case .duplicate(let book): BookManager.duplicate(book, name: name, in: modelContext)
        }
        finishMutation()
    }

    private func setArchived(_ book: BookModel, _ archived: Bool) {
        // A rejected write means the default book: nothing changed to refresh.
        guard BookManager.setArchived(book, archived: archived) else { return }
        finishMutation()
    }

    /// Every book mutation ends here: persist first, then rebuild cached view
    /// models and the book list, repaint widgets, and dismiss/reset the editor.
    private func finishMutation() {
        guard DataRepository.shared.save() else { return }
        DataRefreshCenter.refreshAll()
        WidgetCenter.shared.reloadAllTimelines()
        closeEditor()
        pendingArchive = nil
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
