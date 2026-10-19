//
//  SettingsLLMView.swift
//  smartbud
//
//  Configures the optional OpenAI-compatible LLM used for ledger analysis.
//  Base URL and model live in the app-group defaults; the API key goes to the
//  Keychain (never UserDefaults, never logs).
//

import SwiftUI

struct SettingsLLMView: View {
    @Environment(\.dismiss) var dismiss

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
                .font(.system(.title3, design: .rounded).weight(.semibold))
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
            baseURL = config.baseURL
            model = config.model
            apiKey = config.apiKey
        }
    }

    private var fields: some View {
        VStack(spacing: 0) {
            fieldRow {
                TextField("https://api.openai.com/v1", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } label: {
                Text(String.appLocalized("服务地址"))
            }
            Divider().padding(.horizontal, 15)
            fieldRow {
                TextField("gpt-4o-mini", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } label: {
                Text(String.appLocalized("模型"))
            }
            Divider().padding(.horizontal, 15)
            fieldRow {
                SecureField("sk-…", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } label: {
                Text(String.appLocalized("API Key"))
            }
        }
        .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: GlassRadius.chip))
    }

    private func fieldRow<Content: View, Label: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label()
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.SubtitleText)
            content()
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.PrimaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                LLMConfig(baseURL: baseURL, model: model, apiKey: apiKey).save()
                status = .saved
            } label: {
                Text(String.appLocalized("保存"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)

            Button {
                Task { await test() }
            } label: {
                Text(String.appLocalized("测试连接"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.bordered)
            .disabled(status == .testing)
        }
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
            .font(.system(.footnote, design: .rounded))
        case .success(let message):
            label(message, color: Color.IncomeGreen)
        case .failure(let message):
            label(message, color: Color.AlertRed)
        }
    }

    private func label(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var privacyNote: some View {
        Text(String.appLocalized("AI 分析只会发送汇总数据（总收支、分类占比），不会上传逐笔交易明细。密钥仅保存在本机钥匙串。"))
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(Color.SubtitleText)
    }

    private func test() async {
        let config = LLMConfig(baseURL: baseURL, model: model, apiKey: apiKey)
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
