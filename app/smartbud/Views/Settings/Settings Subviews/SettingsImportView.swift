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
                performImport(from: url)
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
        .disabled(isImporting)
    }

    private func resultCard(_ summary: DataImporter.Summary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                summary.isEmpty
                    ? String.appLocalized(SettingsKey.importEmpty)
                    : String.appFormatted(SettingsKey.importSuccess, summary.imported),
                systemImage: summary.isEmpty ? "info.circle" : "checkmark.circle.fill"
            )
            .font(.body.weight(.medium))
            .foregroundStyle(summary.isEmpty ? Color.SubtitleText : Color.PrimaryText)

            if summary.skipped > 0 {
                Text(String.appFormatted(SettingsKey.importSkipped, summary.skipped))
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
    }

    private func performImport(from url: URL) {
        guard !isImporting else { return }
        isImporting = true
        result = nil

        Task { @MainActor in
            defer { isImporting = false }
            do {
                let summary = try DataImporter.importFile(at: url, context: DataRepository.shared.context)
                result = summary
                // Every screen reads from the same store; refresh the ones
                // that cache fetched rows so the imported data shows up
                // without needing a relaunch.
                AccountViewModel.shared.load()
                CategoryViewModel.shared.load()
                InsightsViewModel.shared.refreshAll()
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
