//
//  SmartEntrySheet.swift
//  smartbud
//
//  One-sheet smart entry: typed phrase, dictated phrase, or receipt screenshot.
//  Always shows a preview and only fills the form on confirmation — nothing is
//  saved without the user submitting the normal form.
//

import SwiftUI
import PhotosUI

struct SmartEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let expenseCategories: [CategoryModel]
    let incomeCategories: [CategoryModel]
    let onApply: (ParsedExpense) -> Void

    @State private var text = ""
    @State private var parsed: ParsedExpense?
    @State private var errorMessage: String?
    @State private var isParsingImage = false
    @State private var photoItem: PhotosPickerItem?
    @State private var speech = SpeechService()

    var body: some View {
        VStack(spacing: 14) {
            header
            inputRow
            actionRow
            if let parsed { preview(parsed) }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.AlertRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .appBackground()
        .onDisappear {
            // Closing the sheet mid-recording used to leave the audio session
            // ducking other apps.
            speech.cancelRecording()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await parseImage(item) }
        }
    }

    private var header: some View {
        HStack {
            Text(String.appLocalized("智能记账"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.PrimaryText)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.SubtitleText.opacity(0.7))
            }
            .accessibilityLabel(Text(String.appLocalized("关闭")))
            .accessibilityIdentifier(AccessibilityID.smartEntryClose)
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField(String.appLocalized("例如：午餐 35 元"), text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: SBRadius.chip))
                .submitLabel(.done)
                .onSubmit(parseText)
                .accessibilityIdentifier(AccessibilityID.smartEntryField)

            Button(action: parseText) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.PrimaryText)
            }
            .accessibilityLabel(Text(String.appLocalized("解析")))
            .accessibilityIdentifier(AccessibilityID.smartEntryParse)
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                toggleSpeech()
            } label: {
                Label(
                    speech.isRecording ? String.appLocalized("停止") : String.appLocalized("语音"),
                    systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(speech.isRecording ? Color.AlertRed : Color.PrimaryText)

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(String.appLocalized("截图"), systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(Color.PrimaryText)

            if isParsingImage {
                ProgressView()
            }
        }
    }

    private func preview(_ parsed: ParsedExpense) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(parsed.isIncome ? String.appLocalized("Income") : String.appLocalized("Expense"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)
                Spacer()
                Text(parsed.amount.formatted(.number.precision(.fractionLength(2))))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.PrimaryText)
                    .accessibilityIdentifier(AccessibilityID.smartEntryPreviewAmount)
            }
            if let category = resolvedCategory(parsed) {
                Text(category.fullName)
                    .font(.subheadline)
                    .foregroundStyle(Color.SubtitleText)
                    .accessibilityIdentifier(AccessibilityID.smartEntryPreviewCategory)
            }
            if let merchant = parsed.merchant {
                Text(merchant)
                    .font(.subheadline)
                    .foregroundStyle(Color.SubtitleText)
            }
            Button {
                onApply(parsed)
                dismiss()
            } label: {
                Text(String.appLocalized("填入表单"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(AccessibilityID.smartEntryApply)
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
        .accessibilityIdentifier(AccessibilityID.smartEntryPreview)
    }

    // MARK: - Actions

    private func parseText() {
        guard let result = ExpenseTextParser.parse(text) else {
            errorMessage = String.appLocalized("没有识别到金额，请说明金额，例如「午餐 35 元」。")
            parsed = nil
            return
        }
        errorMessage = nil
        parsed = result
    }

    private func toggleSpeech() {
        if speech.isRecording {
            speech.stopRecording()
            return
        }
        Task {
            let authorized = await speech.requestAuthorization()
            guard authorized else {
                errorMessage = speech.errorMessage ?? String.appLocalized("没有语音识别权限，请到系统设置开启。")
                return
            }
            speech.startRecording { transcript in
                text = transcript
                parseText()
            }
        }
    }

    private func parseImage(_ item: PhotosPickerItem) async {
        isParsingImage = true
        defer { isParsingImage = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = String.appLocalized("无法读取这张图片。")
                return
            }
            let result = try await OCRService.shared.recognize(from: image)
            let hintFromText = ExpenseTextParser.parse(result.allText)
            guard let amount = result.amounts.first ?? hintFromText?.amount else {
                errorMessage = String.appLocalized("图片里没有识别到金额。")
                return
            }
            errorMessage = nil
            parsed = ParsedExpense(
                amount: amount,
                isIncome: hintFromText?.isIncome ?? false,
                merchant: result.merchant ?? hintFromText?.merchant,
                categoryHint: hintFromText?.categoryHint
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolvedCategory(_ parsed: ParsedExpense) -> CategoryModel? {
        ExpenseTextParser.resolveCategory(
            parsed.categoryHint,
            from: parsed.isIncome ? incomeCategories : expenseCategories
        )
    }
}
