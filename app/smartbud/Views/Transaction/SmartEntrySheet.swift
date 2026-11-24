//
//  SmartEntrySheet.swift
//  smartbud
//
//  One-sheet smart entry: typed phrase, dictated phrase, or receipt screenshot.
//  Rules → confirmed merchant history → an opt-in LLM candidate. Always shows
//  a preview and only fills the form on confirmation — nothing is saved here.


import SwiftUI
import PhotosUI

struct SmartEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let expenseCategories: [CategoryModel]
    let incomeCategories: [CategoryModel]
    let onApply: (ParsedExpense) -> Void
    let history: [ParseHistoryEntry]

    @State private var text = ""
    @State private var parsed: ParsedExpense?
    @State private var errorMessage: String?
    @State private var isParsingImage = false
    @State private var photoItem: PhotosPickerItem?
    @State private var speech = SpeechService()
    @State private var isParsing = false
    @State private var showLLMConsent = false
    @State private var pendingLLMText: String?

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
        .alert(String.appLocalized(SmartEntryKey.consentTitle), isPresented: $showLLMConsent) {
            Button(String.appLocalized(SmartEntryKey.consentAccept)) {
                LLMParsePreferences.accept()
                let input = pendingLLMText
                pendingLLMText = nil
                if let input {
                    Task { await apply(nil, text: input, config: LLMConfig.load(), allowLLM: true) }
                }
            }
            Button(String.appLocalized(SmartEntryKey.consentDecline), role: .cancel) {
                LLMParsePreferences.decline()
                pendingLLMText = nil
                errorMessage = String.appLocalized(SmartEntryKey.noAmount)
            }
        } message: {
            Text(String.appLocalized(SmartEntryKey.consentMessage))
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
            .accessibilityHint(Text(String.appLocalized("Close the smart entry panel")))
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
            .accessibilityHint(Text(String.appLocalized("Generate a transaction from text")))
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

            if isParsingImage || isParsing {
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
            }
            if let category = resolvedCategory(parsed) {
                Text(category.fullName)
                    .font(.subheadline)
                    .foregroundStyle(Color.SubtitleText)
            }
            if let merchant = parsed.merchant {
                Text(merchant)
                    .font(.subheadline)
                    .foregroundStyle(Color.SubtitleText)
            }
            if parsed.source != .rule && parsed.source != .ocr {
                Text(String.appLocalized(
                    parsed.source == .llm ? SmartEntryKey.sourceLLM : SmartEntryKey.sourceHistory
                ))
                .font(.caption2)
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
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
    }

    // MARK: - Actions

    private func parseText() {
        let input = text
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task { await parse(input) }
    }

    private func parse(_ input: String) async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let rule = ExpenseTextParser.parse(trimmed)
        let config = LLMConfig.load()
        let optedIn = LLMParsePreferences.enabled && config.isConfigured
        // The rule path is unchanged: only a failed parse can reach the LLM,
        // and the first use of that path needs an explicit, informed opt-in.
        if rule == nil, optedIn, !LLMParsePreferences.noticeShown {
            pendingLLMText = trimmed
            showLLMConsent = true
            return
        }
        await apply(rule, text: trimmed, config: config, allowLLM: optedIn)
    }

    private func apply(
        _ rule: ParsedExpense?,
        text: String,
        config: LLMConfig,
        allowLLM: Bool
    ) async {
        isParsing = true
        defer { isParsing = false }
        let llm: (any LLMCandidateParsing)? = allowLLM ? LLMClient(config: config) : nil
        let outcome = await SmartEntryParser(llm: llm).parse(
            text: text,
            rule: rule,
            history: history,
            allowedCategories: (expenseCategories + incomeCategories).map(\.name)
        )
        parsed = outcome.candidate
        errorMessage = outcome.failureKey.map { String.appLocalized($0) }
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
        let pool = parsed.isIncome ? incomeCategories : expenseCategories
        if let name = parsed.categoryName,
           let match = pool.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return match
        }
        return ExpenseTextParser.resolveCategory(parsed.categoryHint, from: pool)
    }
}
