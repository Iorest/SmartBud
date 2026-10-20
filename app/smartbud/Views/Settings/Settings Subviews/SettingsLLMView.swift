//
//  SettingsLLMView.swift
//  smartbud
//
//  Configures the optional LLM used for ledger analysis. Provider presets
//  fill sensible defaults; base URL and model live in the app-group defaults,
//  the API key goes to the Keychain (never UserDefaults, never logs).
//

import SwiftUI

struct SettingsLLMView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var provider: LLMProvider = .openAI
    @State private var baseURL = ""
    @State private var model = ""
    @State private var apiKey = ""
    @State private var status: Status = .idle

    private enum Status: Equatable {
        case idle
        case saved
        case testing
        case success(String)
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(String.appLocalized("AI 服务"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.PrimaryText)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button { dismiss() } label: { SettingsBackButton() }
                }
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    fields
                    actions
                    statusView
                    privacyNote
                }
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .modifier(SettingsSubviewModifier())
        .onAppear {
            let config = LLMConfig.load()
            provider = config.provider
            baseURL = config.baseURL.isEmpty ? config.provider.defaultBaseURL : config.baseURL
            model = config.model.isEmpty ? config.provider.defaultModel : config.model
            apiKey = config.apiKey
        }
    }

    private var fields: some View {
        VStack(spacing: 0) {
            fieldRow {
                providerMenu
            } label: {
                Text(String.appLocalized("服务商"))
            }
            Divider().padding(.horizontal, 15)
            fieldRow {
                TextField("https://api.openai.com/v1", text: $baseURL)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .autocorrectionDisabled()
            } label: {
                Text(String.appLocalized("服务地址"))
            }
            Divider().padding(.horizontal, 15)
            fieldRow {
                TextField("gpt-4o-mini", text: $model)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            } label: {
                Text(String.appLocalized("模型"))
            }
            if provider.showsAPIKeyField {
                Divider().padding(.horizontal, 15)
                fieldRow {
                    SecureField("sk-…", text: $apiKey)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } label: {
                    Text(String.appLocalized("API Key"))
                }
            }
            Divider().padding(.horizontal, 15)
            Text(String.appLocalized(provider.hintKey))
                .font(.caption)
                .foregroundStyle(Color.SubtitleText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
        }
        .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: SBRadius.chip))
    }

    private var providerMenu: some View {
        Menu {
            ForEach(LLMProvider.allCases) { option in
                Button {
                    apply(option)
                } label: {
                    if option == provider {
                        Label(String.appLocalized(option.titleKey), systemImage: "checkmark")
                    } else {
                        Text(String.appLocalized(option.titleKey))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(String.appLocalized(provider.titleKey))
                    .font(.body)
                    .foregroundStyle(Color.PrimaryText)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(Color.SubtitleText)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(String.appLocalized("服务商")))
    }

    /// Swaps in the new provider's defaults only when the field still holds
    /// the previous provider's default (or nothing), so hand-edited values
    /// are never overwritten.
    private func apply(_ option: LLMProvider) {
        guard option != provider else { return }
        let previous = provider
        provider = option
        let currentBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !option.defaultBaseURL.isEmpty,
           currentBase.isEmpty || currentBase == previous.defaultBaseURL {
            baseURL = option.defaultBaseURL
        }
        if !option.defaultModel.isEmpty,
           currentModel.isEmpty || currentModel == previous.defaultModel {
            model = option.defaultModel
        }
        status = .idle
    }

    private func fieldRow<Content: View, Label: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label()
                .font(.caption)
                .foregroundStyle(Color.SubtitleText)
            content()
                .font(.body)
                .foregroundStyle(Color.PrimaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
    }

    private var currentConfig: LLMConfig {
        LLMConfig(provider: provider, baseURL: baseURL, model: model, apiKey: apiKey)
    }

    @ViewBuilder
    private var actions: some View {
        // Side by side the wrapped "测试连接" label makes the two pills
        // different heights at accessibility sizes, so stack them there.
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                saveButton
                testButton
            }
        } else {
            HStack(spacing: 10) {
                saveButton
                testButton
            }
        }
    }

    private var saveButton: some View {
        Button {
            currentConfig.save()
            status = .saved
        } label: {
            Text(String.appLocalized("保存"))
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
        }
        .buttonStyle(.borderedProminent)
    }

    private var testButton: some View {
        Button {
            Task { await test() }
        } label: {
            Text(String.appLocalized("测试连接"))
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
        }
        .buttonStyle(.bordered)
        .disabled(status == .testing || !currentConfig.isConfigured)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .idle:
            EmptyView()
        case .saved:
            label(String.appLocalized("已保存"), color: Color.IncomeGreen)
        case .testing:
            HStack(spacing: 8) {
                ProgressView()
                Text(String.appLocalized("正在连接…")).foregroundStyle(Color.SubtitleText)
            }
            .font(.footnote)
        case .success(let message):
            label(message, color: Color.IncomeGreen)
        case .failure(let message):
            label(message, color: Color.AlertRed)
        }
    }

    private func label(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var privacyNote: some View {
        Text(String.appLocalized("AI 分析只会发送汇总数据（总收支、分类占比），不会上传逐笔交易明细。密钥仅保存在本机钥匙串。"))
            .font(.caption)
            .foregroundStyle(Color.SubtitleText)
    }

    func test() async {
        let config = currentConfig
        guard config.isConfigured else {
            status = .failure(String.appLocalized("请先填写服务地址、模型和 API Key。"))
            return
        }
        status = .testing
        do {
            let reply = try await LLMClient(config: config).testConnection()
            status = .success(String.appLocalized("连接成功：") + reply.prefix(40))
        } catch {
            status = .failure(error.localizedDescription)
        }
    }
}
