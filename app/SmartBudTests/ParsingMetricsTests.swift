//
//  ParsingMetricsTests.swift
//  SmartBudTests
//
//  Corpus-level metrics for the text and receipt parsers. `ParsedExpense` is
//  written straight into the entry form, so a wrong amount becomes a wrong
//  ledger without the user noticing — a per-phrase unit test cannot show that
//  trend. This runs E2's fixtures and turns them into numbers CI can gate on.
//
//  Floors live in `Fixtures/metrics_baseline.json` and only ever move up: a
//  change that wants a lower floor has to change that file in the same PR, so
//  the diff shows the regression instead of hiding it behind a re-record.
//

import Testing
import Foundation
import SwiftData

@MainActor
@Suite("Parsing metrics")
struct ParsingMetricsTests {

    // MARK: - Fixtures

    private static var fixturesDirectory: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures")
    }

    private struct TextCase: Decodable {
        let id: String
        let text: String
        let amount: Double
        let direction: String
        let category: String
        let merchant: String?
    }

    private struct ReceiptCase: Decodable {
        let id: String
        let lines: [String]
        let amount: Double
    }

    private struct Baseline: Decodable {
        struct Sample: Decodable {
            let text: Int
            let receipts: Int
        }

        struct Floors: Decodable {
            let textAmount: Double
            let textDirection: Double
            let textCategory: Double
            let textEndToEnd: Double
            let receiptAmount: Double
        }

        struct Targets: Decodable {
            let textAmount: Double
        }

        let sample: Sample
        let measuredAt: String
        let floors: Floors
        let targets: Targets
    }

    /// The ten buckets the rule parser can emit, in the order the app seeds
    /// them, so `resolveCategory` resolves each hint to its own bucket.
    private static let bucketNames = [
        "餐饮", "交通", "购物", "咖啡", "娱乐",
        "通讯", "教育", "医疗", "工资", "奖金"
    ]

    /// One in-memory store per test, held for the whole test: releasing the
    /// container resets its context and the categories stop being readable.
    @MainActor
    private struct Store {
        let container: ModelContainer
        let categories: [CategoryModel]

        init(bucketNames: [String]) throws {
            container = try ModelContainer(
                for: TransactionModel.self,
                CategoryModel.self,
                BudgetModel.self,
                MainBudgetModel.self,
                TemplateTransactionModel.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            categories = bucketNames.enumerated().map { index, name in
                CategoryModel(name: name, order: index)
            }
            for category in categories {
                container.mainContext.insert(category)
            }
        }
    }

    // MARK: - Test

    @Test("Corpus metrics stay above the recorded floors")
    func corpusMetrics() throws {
        let textCases = try load([TextCase].self, from: "corpus_text.json")
        let receiptCases = try load([ReceiptCase].self, from: "corpus_receipts.json")
        let baseline = try load(Baseline.self, from: "metrics_baseline.json")
        let store = try Store(bucketNames: Self.bucketNames)
        let categories = store.categories

        var textAmountHits = 0
        var textDirectionHits = 0
        var textCategoryHits = 0
        var textEndToEndHits = 0
        var amountMisses: [String] = []
        var directionMisses: [String] = []
        var categoryMisses: [String] = []

        for entry in textCases {
            let expectedAmount = Money.cents(entry.amount)
            let expectedIncome = entry.direction == "income"
            let parsed = ExpenseTextParser.parse(entry.text)

            let amountOK = parsed?.amount == expectedAmount
            let directionOK = parsed?.isIncome == expectedIncome
            let bucket = ExpenseTextParser.resolveCategory(parsed?.categoryHint, from: categories)?.name
            let categoryOK = bucket == entry.category

            if amountOK {
                textAmountHits += 1
            } else {
                let line = "\(entry.id) 「\(entry.text)」期望 \(expectedAmount) 实得 \(amountText(parsed))"
                amountMisses.append(line)
            }
            if directionOK {
                textDirectionHits += 1
            } else {
                let line = "\(entry.id) 「\(entry.text)」期望 \(entry.direction) 实得 \(directionText(parsed))"
                directionMisses.append(line)
            }
            if categoryOK {
                textCategoryHits += 1
            } else {
                let hint = parsed?.categoryHint ?? "nil"
                let line = "\(entry.id) 「\(entry.text)」期望 \(entry.category) 实得 \(bucket ?? "nil")（hint \(hint)）"
                categoryMisses.append(line)
            }
            if amountOK && directionOK && categoryOK {
                textEndToEndHits += 1
            }
        }

        var receiptAmountHits = 0
        var receiptMisses: [String] = []
        let receiptParser = AlipayWechatParser()
        for entry in receiptCases {
            let expectedAmount = Money.cents(entry.amount)
            let parsed = receiptParser.parse(lines: entry.lines)
            if parsed?.amount == expectedAmount {
                receiptAmountHits += 1
            } else {
                let got = parsed.map { "\($0.amount)" } ?? "nil"
                let line = "\(entry.id) 期望 \(expectedAmount) 实得 \(got)"
                receiptMisses.append(line)
            }
        }

        let textAmountRate = rate(textAmountHits, of: textCases.count)
        let textDirectionRate = rate(textDirectionHits, of: textCases.count)
        let textCategoryRate = rate(textCategoryHits, of: textCases.count)
        let textEndToEndRate = rate(textEndToEndHits, of: textCases.count)
        let receiptAmountRate = rate(receiptAmountHits, of: receiptCases.count)

        let gatesPassed =
            textAmountRate >= baseline.floors.textAmount &&
            textDirectionRate >= baseline.floors.textDirection &&
            textCategoryRate >= baseline.floors.textCategory &&
            textEndToEndRate >= baseline.floors.textEndToEnd &&
            receiptAmountRate >= baseline.floors.receiptAmount &&
            textCases.count == baseline.sample.text &&
            receiptCases.count == baseline.sample.receipts

        // Printed before the expectations so a red run still reports numbers;
        // CI folds the METRICS line into the job summary. Each figure is
        // "current/floor" — see docs/ai-eval.md.
        let fields = [
            "text_amount=\(percent(textAmountRate))/\(percent(baseline.floors.textAmount))",
            "text_direction=\(percent(textDirectionRate))/\(percent(baseline.floors.textDirection))",
            "text_category=\(percent(textCategoryRate))/\(percent(baseline.floors.textCategory))",
            "text_end_to_end=\(percent(textEndToEndRate))/\(percent(baseline.floors.textEndToEnd))",
            "receipt_amount=\(percent(receiptAmountRate))/\(percent(baseline.floors.receiptAmount))",
            "target_amount=\(percent(baseline.targets.textAmount))",
            "status=\(gatesPassed ? "pass" : "fail")"
        ]
        print("METRICS " + fields.joined(separator: " "))
        print("METRICS_DETAIL corpus=\(textCases.count) receipts=\(receiptCases.count) baseline=\(baseline.measuredAt)")
        report("金额（文本）", amountMisses)
        report("方向（文本）", directionMisses)
        report("分类（文本）", categoryMisses)
        report("金额（小票）", receiptMisses)

        #expect(
            textCases.count == baseline.sample.text,
            "语料条数变了（\(baseline.sample.text) → \(textCases.count)），需同步更新 metrics_baseline.json 与 docs/ai-eval.md"
        )
        #expect(
            receiptCases.count == baseline.sample.receipts,
            "小票条数变了（\(baseline.sample.receipts) → \(receiptCases.count)），需同步更新 metrics_baseline.json 与 docs/ai-eval.md"
        )
        #expect(
            textAmountRate >= baseline.floors.textAmount,
            "金额准确率 \(percent(textAmountRate))% 低于门槛 \(percent(baseline.floors.textAmount))%：\(missSample(amountMisses))"
        )
        #expect(
            textDirectionRate >= baseline.floors.textDirection,
            "方向准确率 \(percent(textDirectionRate))% 低于门槛 \(percent(baseline.floors.textDirection))%：\(missSample(directionMisses))"
        )
        #expect(
            textCategoryRate >= baseline.floors.textCategory,
            "分类 top-1 \(percent(textCategoryRate))% 低于门槛 \(percent(baseline.floors.textCategory))%：\(missSample(categoryMisses))"
        )
        #expect(
            textEndToEndRate >= baseline.floors.textEndToEnd,
            "一次通过率 \(percent(textEndToEndRate))% 低于门槛 \(percent(baseline.floors.textEndToEnd))%"
        )
        #expect(
            receiptAmountRate >= baseline.floors.receiptAmount,
            "小票金额准确率 \(percent(receiptAmountRate))% 低于门槛 \(percent(baseline.floors.receiptAmount))%：\(missSample(receiptMisses))"
        )
    }

    /// Before/after on the same corpus and the same binary: "before" is the
    /// rule-only parse currently shipped; "after" adds the user's confirmed
    /// merchant history. The LLM is deliberately absent — it needs a network
    /// and a user key, so it cannot be a CI gate.
    @Test("Merchant history lifts end-to-end without moving amounts")
    func smartChainMetrics() async throws {
        let textCases = try load([TextCase].self, from: "corpus_text.json")
        let baseline = try load(Baseline.self, from: "metrics_baseline.json")
        let store = try Store(bucketNames: Self.bucketNames)
        let categories = store.categories
        let history = textCases.compactMap { entry -> ParseHistoryEntry? in
            guard let merchant = entry.merchant else { return nil }
            return ParseHistoryEntry(
                merchantName: merchant,
                merchantKey: MerchantNormalizer.normalize(merchant)?.key ?? merchant,
                categoryName: entry.category,
                isIncome: entry.direction == "income"
            )
        }
        let parser = SmartEntryParser(llm: nil)

        var baselineE2E = 0
        var smartE2E = 0
        var baselineAmount = 0
        var smartAmount = 0
        for entry in textCases {
            let expectedAmount = Money.cents(entry.amount)
            let expectedIncome = entry.direction == "income"
            let rule = ExpenseTextParser.parse(entry.text)
            let outcome = await parser.parse(
                text: entry.text,
                rule: rule,
                history: history,
                allowedCategories: Self.bucketNames
            )
            let beforeCategory = ExpenseTextParser.resolveCategory(
                rule?.categoryHint, from: categories)?.name
            let afterCategory = outcome.candidate.flatMap {
                resolvedName($0, from: categories)
            }
            let amountOK = rule?.amount == expectedAmount
            let directionOK = rule?.isIncome == expectedIncome
            let smartAmountOK = outcome.candidate?.amount == expectedAmount
            let smartDirectionOK = outcome.candidate?.isIncome == expectedIncome
            if amountOK { baselineAmount += 1 }
            if smartAmountOK { smartAmount += 1 }
            if amountOK && directionOK && beforeCategory == entry.category { baselineE2E += 1 }
            if smartAmountOK && smartDirectionOK && afterCategory == entry.category { smartE2E += 1 }
        }

        let before = rate(baselineE2E, of: textCases.count)
        let after = rate(smartE2E, of: textCases.count)
        let amountBefore = rate(baselineAmount, of: textCases.count)
        let amountAfter = rate(smartAmount, of: textCases.count)
        print("METRICS_SMART e2e_before=\(percent(before))/floor \(percent(baseline.floors.textEndToEnd)) e2e_after=\(percent(after)) delta_pp=\(String(format: "%.2f", (after - before) * 100)) amount_before=\(percent(amountBefore)) amount_after=\(percent(amountAfter))")

        #expect(amountBefore >= baseline.targets.textAmount,
                "金额准确率 \(percent(amountBefore))% 未达目标 \(percent(baseline.targets.textAmount))%")
        #expect(amountAfter >= amountBefore,
                "学习层不能改变金额：\(percent(amountBefore))% → \(percent(amountAfter))%")
        #expect(after - before >= 0.10,
                "端到端一次通过率只提升 \(String(format: "%.2f", (after - before) * 100)) pp，低于 10 pp 门槛")
    }

    // MARK: - Helpers


    private func resolvedName(_ candidate: ParsedExpense, from categories: [CategoryModel]) -> String? {
        if let name = candidate.categoryName,
           let match = categories.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return match.name
        }
        return ExpenseTextParser.resolveCategory(candidate.categoryHint, from: categories)?.name
    }
    private func load<T: Decodable>(_ type: T.Type, from file: String) throws -> T {
        let url = Self.fixturesDirectory.appending(path: file)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }

    private func amountText(_ parsed: ParsedExpense?) -> String {
        parsed.map { "\($0.amount)" } ?? "nil"
    }

    private func directionText(_ parsed: ParsedExpense?) -> String {
        guard let parsed else { return "nil" }
        return parsed.isIncome ? "income" : "expense"
    }

    private func rate(_ hits: Int, of total: Int) -> Double {
        total == 0 ? 0 : Double(hits) / Double(total)
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.2f", value * 100)
    }

    private func missSample(_ misses: [String]) -> String {
        let head = misses.prefix(5).joined(separator: "；")
        return misses.count > 5 ? "\(head)；…共 \(misses.count) 条" : head
    }

    private func report(_ title: String, _ misses: [String]) {
        guard !misses.isEmpty else { return }
        print("METRICS_MISS \(title) count=\(misses.count)")
        for miss in misses.prefix(10) {
            print("METRICS_MISS   \(miss)")
        }
    }
}
