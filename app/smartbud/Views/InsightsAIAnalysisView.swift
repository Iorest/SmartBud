//
//  InsightsAIAnalysisView.swift
//  smartbud
//
//  Sends the current period's aggregate figures to the user-configured LLM and
//  shows the returned commentary. No per-transaction data leaves the device.
//

import SwiftUI

struct InsightsAIAnalysisView: View {
    @Environment(InsightsViewModel.self) private var insightsVM
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var needsSetup = false

    var body: some View {
        VStack(spacing: 16) {
            header
            content
            Spacer(minLength: 0)
            if !needsSetup {
                footer
            }
        }
        .padding(20)
        .appBackground()
        .accessibilityIdentifier(AccessibilityID.aiScreen)
        .task { await analyze() }
    }

    private var header: some View {
        HStack {
            Text(String.appLocalized("AI 账单分析"))
                .font(.headline)
                .foregroundStyle(Color.PrimaryText)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.SubtitleText.opacity(0.7))
            }
            .accessibilityLabel(Text(String.appLocalized("关闭")))
            .accessibilityIdentifier(AccessibilityID.aiClose)
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                    Text(String.appLocalized("正在分析本期账单…"))
                        .font(.footnote)
                        .foregroundStyle(Color.SubtitleText)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else if let errorMessage {
                VStack(spacing: SBSpace.small) {
                    Image(systemName: needsSetup ? "sparkles" : "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(Color.SubtitleText)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(needsSetup ? Color.SubtitleText : Color.AlertRed)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(AccessibilityID.aiMessage)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                SBCard {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(Color.PrimaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var footer: some View {
        Button {
            Task { await analyze() }
        } label: {
            Text(String.appLocalized("重新分析"))
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading || !LLMConfig.load().isConfigured || needsSetup)
    }

    private func analyze() async {
        errorMessage = nil
        let config = LLMConfig.load()
        guard config.isConfigured else {
            // One clear message; the error text alone already tells the user
            // where to configure it.
            needsSetup = true
            errorMessage = String.appLocalized("请先到 设置 → AI 服务 配置服务地址、模型和 API Key。")
            return
        }
        needsSetup = false
        isLoading = true
        text = ""
        defer { isLoading = false }
        do {
            text = try await LLMClient(config: config).analyze(summary())
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Aggregate-only payload for the current Insights period.
    private func summary() -> LedgerSummary {
        let categoryTotals = insightsVM.categoryBreakdown.prefix(6).map { item in
            LedgerSummary.CategoryTotal(
                name: item.category.name,
                amount: insightsVM.formattedCurrency(item.amount),
                share: "\(Int((item.percent * 100).rounded()))%"
            )
        }
        return LedgerSummary(
            period: insightsVM.periodDateRangeText,
            currency: insightsVM.currency,
            totalIncome: insightsVM.formattedCurrency(insightsVM.periodTotalIncome),
            totalSpent: insightsVM.formattedCurrency(insightsVM.periodTotalSpent),
            // `periodTotalNet` is an absolute value; the sign lives in
            // `periodNetPositive`. Passing the magnitude lost the minus and
            // told the model a spending month ended in surplus.
            net: insightsVM.formattedCurrency(
                insightsVM.periodNetPositive ? insightsVM.periodTotalNet : -insightsVM.periodTotalNet,
                sign: true),
            topCategories: Array(categoryTotals),
            pendingReimbursement: insightsVM.pendingReimbursementTotal > 0
                ? insightsVM.formattedCurrency(insightsVM.pendingReimbursementTotal)
                : nil,
            language: Locale.appLocale.identifier
        )
    }
}
