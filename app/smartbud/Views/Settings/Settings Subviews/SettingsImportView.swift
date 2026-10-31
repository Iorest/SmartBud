//
//  SettingsImportView.swift
//  smartbud
//
//  Restore screen for the JSON file written by Settings → Export Data.
//  Picks a file with the native document picker, merges it into the local
//  store (ids already present are skipped) and reports what landed.
//

import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct SettingsImportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isPresentingPicker = false
    @State private var isImporting = false
    @State private var result: DataImporter.Summary?
    @State private var pendingPayload: ExportSchema.Payload?
    @State private var pendingSummary: DataImporter.Summary?
    @State private var showImportConfirmation = false

    @AppStorage("currency", store: .appGroup) private var currency: String = AppBaseCurrency.code
    @AppStorage("firstDayOfMonth", store: .appGroup) private var firstDayOfMonth: Int = 1
    @AppStorage("firstWeekday", store: .appGroup) private var firstWeekday: Int = 1
    @State private var errorMessage: String?
    @State private var isPresentingError = false

    var body: some View {
        VStack(spacing: 10) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String.appLocalized(SettingsKey.importSubtitle))
                        .font(.body)
                        .foregroundStyle(Color.SubtitleText)
                        .fixedSize(horizontal: false, vertical: true)

                    importButton

                    if isImporting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                            Text(String.appLocalized(SettingsKey.importProgress))
                                .font(.subheadline)
                                .foregroundStyle(Color.SubtitleText)
                        }
                    }

                    if let result {
                        resultCard(result)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .modifier(SettingsSubviewModifier())
        .fileImporter(
            isPresented: $isPresentingPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { pickerResult in
            switch pickerResult {
            case .success(let urls):
                guard let url = urls.first else { return }
                loadForPreview(from: url)
            case .failure:
                errorMessage = DataImporter.ImportError.unreadable.errorDescription
                isPresentingError = true
            }
        }
        .alert(
            String.appLocalized(SettingsKey.importTitle),
            isPresented: $isPresentingError
        ) {
            Button(String.appLocalized(SettingsKey.importDone), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(String.appLocalized(SettingsKey.importConfirmTitle),
               isPresented: $showImportConfirmation,
               presenting: pendingSummary) { _ in
            Button(String.appLocalized(SettingsKey.importConfirmAction)) { applyPendingImport() }
            Button(String.appLocalized("Cancel"), role: .cancel) {
                pendingPayload = nil
                pendingSummary = nil
            }
        } message: { summary in
            Text(String.appFormatted(SettingsKey.importConfirmMessage,
                                     previewDateText, summary.imported))
        }
    }

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: { SettingsBackButton() }
            Spacer()
        }
        .overlay(alignment: .center) {
            Text(String.appLocalized(SettingsKey.importTitle))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.PrimaryText)
        }
        .padding(.bottom, 20)
    }

    private var importButton: some View {
        Button {
            #if DEBUG
            // QA hook: the system file picker cannot be steered by XCUITest,
            // so under `-importBackupFromDocuments` the button reads the file
            // the export hook parked in the app container instead. Every step
            // after the picker is the production path.
            if UITestFixture.importsFromDocuments,
               let url = UITestFixture.documentsBackupURL,
               FileManager.default.fileExists(atPath: url.path) {
                loadForPreview(from: url)
                return
            }
            #endif
            isPresentingPicker = true
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.down.fill")
                Text(String.appLocalized(SettingsKey.importAction))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier(AccessibilityID.importBackupChooseFile)
        .disabled(isImporting)
    }

    private func resultCard(_ summary: DataImporter.Summary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(resultTitle(summary),
                  systemImage: summary.isEmpty ? "info.circle" : "checkmark.circle.fill")
            .font(.body.weight(.medium))
            .foregroundStyle(summary.isEmpty ? Color.SubtitleText : Color.PrimaryText)

            if summary.skipped > 0 {
                Text(String.appFormatted(SettingsKey.importSkipped, summary.skipped))
                    .font(.footnote)
                    .foregroundStyle(Color.SubtitleText)
            }

            if let settings = summary.settingsToApply, let code = settings.baseCurrency {
                Text(String.appFormatted(SettingsKey.importSettingsApplied, code))
                    .font(.footnote)
                    .foregroundStyle(Color.SubtitleText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.SecondaryBackground,
                    in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.importBackupResult)
    }

    /// A backup restores the currency its amounts were frozen in. Only applied
    /// when this device had no data (the importer decides that), so a restore
    /// never rewrites an existing ledger's base currency.
    private func applySettings(_ settings: ExportSchema.SettingsDTO?) {
        guard let settings else { return }
        if let code = settings.baseCurrency, !code.isEmpty {
            currency = code
            NSUbiquitousKeyValueStore.default.set(code, forKey: "currency")
        }
        if let day = settings.firstDayOfMonth { firstDayOfMonth = day }
        if let weekday = settings.firstWeekday { firstWeekday = weekday }
    }

    /// Reads the file first so the user sees how much is inside before it is
    /// merged. Nothing is written until the confirmation.
    private func loadForPreview(from url: URL) {
        do {
            let payload = try DataImporter.decodeFile(at: url)
            pendingPayload = payload
            pendingSummary = DataImporter.preview(payload)
            showImportConfirmation = true
        } catch let error as DataImporter.ImportError {
            errorMessage = error.errorDescription
            isPresentingError = true
        } catch {
            errorMessage = DataImporter.ImportError.notABackup.errorDescription
            isPresentingError = true
        }
    }

    private var previewDateText: String {
        guard let payload = pendingPayload else { return "" }
        return payload.exportDate.formatted(
            Date.FormatStyle(locale: .appLocale).year().month().day())
    }

    /// "Nothing to import" means the file itself is empty; "nothing new" means
    /// every record was already here. Different situations, different copy.
    private func resultTitle(_ summary: DataImporter.Summary) -> String {
        if !summary.isEmpty {
            return String.appFormatted(SettingsKey.importSuccess, summary.imported)
        }
        return summary.skipped > 0
            ? String.appLocalized(SettingsKey.importAllSkipped)
            : String.appLocalized(SettingsKey.importEmpty)
    }

    private func applyPendingImport() {
        guard let payload = pendingPayload else { return }
        pendingPayload = nil
        pendingSummary = nil
        guard !isImporting else { return }
        isImporting = true
        result = nil

        Task { @MainActor in
            defer { isImporting = false }
            do {
                let summary = try DataImporter.apply(payload, context: DataRepository.shared.context)
                applySettings(summary.settingsToApply)
                result = summary
                // Every screen reads from the same store; refresh the ones
                // that cache fetched rows so the imported data shows up
                // without needing a relaunch.
                // The fee row's base amount converts with the *imported*
                // rates, so the rate cache has to catch up before the repair
                // runs; otherwise a missing rate falls back to 1:1 and the
                // fee is frozen at the wrong scale.
                CurrencyRateStore.shared.load()
                // Older backups carry transfers whose fee has no expense row;
                // write the missing rows so the imported balances add up.
                TransferFeeLedger.migrate(in: DataRepository.shared.context)
                // The JSON contract carries no merchant field: the imported
                // notes are the only source, so derive it the same way a
                // launched legacy store does.
                MerchantMigration.migrate(in: DataRepository.shared.context)
                // One list for every cache — rates and budgets included, which
                // the old ad-hoc calls here missed until the next screen visit.
                DataRefreshCenter.refreshAll()
                // The import saves the context directly (one transaction for
                // the whole file), which bypasses the repository's own
                // timeline reload.
                WidgetCenter.shared.reloadAllTimelines()
            } catch let error as DataImporter.ImportError {
                errorMessage = error.errorDescription
                isPresentingError = true
            } catch {
                errorMessage = DataImporter.ImportError.notABackup.errorDescription
                isPresentingError = true
            }
        }
    }
}
