//
//  SettingsExportView.swift
//  smartbud
//
//  GDPR Article 20 — "Right to data portability" UI. Generates a
//  JSON file via `DataExporter` and hands it to a share sheet so
//  the user can save it to Files, AirDrop, email, etc.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct SettingsExportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var errorMessage: String?
    @State private var isPresentingShareSheet = false
    @State private var isPresentingError = false
    /// DEBUG-only: record count of the file just written. Export deliberately
    /// has no preview screen, so a test could otherwise only assert that the
    /// share sheet came up.
    @State private var exportedRecordCount: Int?

    var body: some View {
        VStack(spacing: 10) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String.appLocalized(SettingsKey.exportSubtitle))
                        .font(.body)
                        .foregroundStyle(Color.SubtitleText)
                        .fixedSize(horizontal: false, vertical: true)

                    exportButton

                    VStack(alignment: .leading, spacing: 6) {
                        csvButton
                        Text(String.appLocalized(SettingsKey.exportCSVHint))
                            .font(.footnote)
                            .foregroundStyle(Color.SubtitleText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    #if DEBUG
                    if UITestFixture.isStoreRequested, let exportedRecordCount {
                        Text(String.appFormatted("Exported %lld records.", exportedRecordCount))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)
                            .accessibilityIdentifier(AccessibilityID.exportSummary)
                    }
                    #endif

                    if isExporting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                            Text(String.appLocalized(SettingsKey.exportProgress))
                                .font(.subheadline)
                                .foregroundStyle(Color.SubtitleText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .modifier(SettingsSubviewModifier())
        .sheet(isPresented: $isPresentingShareSheet) {
            if let url = exportedFileURL {
                #if os(macOS)
                VStack(spacing: 16) {
                    Text(url.lastPathComponent)
                        .font(.body.weight(.semibold))
                    ShareLink(item: url)
                }
                .padding(24)
                #else
                ShareSheet(activityItems: [url])
                #endif
            }
        }
        .alert(
            String.appLocalized(SettingsKey.proErrorTitle),
            isPresented: $isPresentingError,
            actions: {
                Button(String.appLocalized(SettingsKey.proErrorDismiss), role: .cancel) {}
            },
            message: { Text(errorMessage ?? "") }
        )
    }

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: { SettingsBackButton() }
            Spacer()
        }
        .overlay(alignment: .center) {
            Text(String.appLocalized(SettingsKey.exportTitle))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.PrimaryText)
        }
        .padding(.bottom, 20)
    }

    private var exportButton: some View {
        Button {
            generateExport()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up.fill")
                Text(String.appLocalized(SettingsKey.exportAction))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier(AccessibilityID.exportJSONButton)
        .disabled(isExporting)
    }

    private var csvButton: some View {
        Button {
            generateCSV()
        } label: {
            HStack {
                Image(systemName: "tablecells")
                Text(String.appLocalized(SettingsKey.exportCSVAction))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .disabled(isExporting)
    }

    private func generateExport() {
        guard !isExporting else { return }
        isExporting = true
        errorMessage = nil

        // Defer to next runloop tick so the disabled-state + spinner
        // paint before the (potentially slow) SwiftData fetch runs.
        Task { @MainActor in
            do {
                let url = try DataExporter.exportToFile()
                exportedFileURL = url
                isExporting = false
                #if DEBUG
                if UITestFixture.isStoreRequested {
                    exportedRecordCount = Self.recordCount(of: url)
                }
                // QA hook: `SmartBudUITests` cannot steer the share sheet, so
                // the file it would have shared is parked in the app container
                // and imported by the next launch of the same case. The sheet
                // itself is skipped: it is a system surface and it would cover
                // the recorded count.
                if UITestFixture.exportsToDocuments,
                   let destination = UITestFixture.documentsBackupURL {
                    try? FileManager.default.removeItem(at: destination)
                    try? FileManager.default.copyItem(at: url, to: destination)
                }
                if !UITestFixture.exportsToDocuments {
                    isPresentingShareSheet = true
                }
                #else
                isPresentingShareSheet = true
                #endif
            } catch let error as DataExporter.ExportError {
                isExporting = false
                if case .noData = error {
                    // Empty-state is not really an error — just tell
                    // the user there's nothing to export.
                    errorMessage = String.appLocalized(SettingsKey.exportEmpty)
                } else {
                    errorMessage = error.errorDescription
                }
                isPresentingError = true
            } catch {
                isExporting = false
                errorMessage = String.appLocalized(SettingsKey.exportFailure)
                isPresentingError = true
            }
        }
    }

    /// How many records the file carries, read back through the same decoder
    /// the restore screen uses. Returns nil rather than a wrong number if the
    /// file cannot be read — a test then fails on the missing line.
    private static func recordCount(of url: URL) -> Int? {
        guard let payload = try? DataImporter.decodeFile(at: url) else { return nil }
        return DataImporter.preview(payload).imported
    }

    private func generateCSV() {
        guard !isExporting else { return }
        isExporting = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let url = try DataExporter.exportCSVToFile()
                exportedFileURL = url
                isExporting = false
                isPresentingShareSheet = true
            } catch let error as DataExporter.ExportError {
                isExporting = false
                if case .noData = error {
                    errorMessage = String.appLocalized(SettingsKey.exportEmpty)
                } else {
                    errorMessage = error.errorDescription
                }
                isPresentingError = true
            } catch {
                isExporting = false
                errorMessage = String.appLocalized(SettingsKey.exportFailure)
                isPresentingError = true
            }
        }
    }
}

// MARK: - ShareSheet (UIActivityViewController bridge)

#if !os(macOS)
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
