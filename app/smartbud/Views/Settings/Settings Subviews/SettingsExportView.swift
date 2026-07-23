//
//  SettingsExportView.swift
//  smartbud
//
//  GDPR Article 20 — "Right to data portability" UI. Generates a
//  JSON file via `DataExporter` and hands it to a share sheet so
//  the user can save it to Files, AirDrop, email, etc.
//

import SwiftUI
import UIKit

struct SettingsExportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var errorMessage: String?
    @State private var isPresentingShareSheet = false
    @State private var isPresentingError = false

    var body: some View {
        VStack(spacing: 10) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String.appLocalized(SettingsKey.exportSubtitle))
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Color.SubtitleText)
                        .fixedSize(horizontal: false, vertical: true)

                    exportButton

                    if isExporting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                            Text(String.appLocalized(SettingsKey.exportProgress))
                                .font(.system(.subheadline, design: .rounded))
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
                ShareSheet(activityItems: [url])
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
                .font(.system(.title3, design: .rounded).weight(.semibold))
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
                isPresentingShareSheet = true
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
}

// MARK: - ShareSheet (UIActivityViewController bridge)

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
