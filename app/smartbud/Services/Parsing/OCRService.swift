//
//  OCRService.swift
//  smartbud
//
//  On-device text recognition for receipt / screenshot import (Vision).
//  Ported from SmartExpense; amounts are Decimal and the Alipay/WeChat
//  targeted parser runs before the generic extraction.
//

import Vision
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

final class OCRService: @unchecked Sendable {
    static let shared = OCRService()

    struct OCRResult {
        var amounts: [Decimal] = []
        var merchant: String?
        var allText: String
        var platform: String?
        var confidence: Double?
    }

    /// Targeted Alipay/WeChat parse first, generic OCR as fallback.
    func recognize(from image: UIImage) async throws -> OCRResult {
        var result = try await recognizeText(from: image)
        let lines = result.allText
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        if let targeted = AlipayWechatParser().parse(lines: lines) {
            result.amounts.insert(targeted.amount, at: 0)
            result.merchant = targeted.merchant ?? result.merchant
            result.platform = targeted.platform.rawValue
            result.confidence = targeted.confidence
        }
        return result
    }

    func recognizeText(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "OCRService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to get image"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let request = VNRecognizeTextRequest { request, error in
                guard !resumed else { return }
                if let error {
                    resumed = true
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    resumed = true
                    continuation.resume(throwing: NSError(domain: "OCRService", code: -2,
                                                          userInfo: [NSLocalizedDescriptionKey: "Unable to recognize text"]))
                    return
                }

                var allText = ""
                var amounts: [Decimal] = []
                for observation in observations {
                    guard let text = observation.topCandidates(1).first?.string else { continue }
                    allText += text + "\n"
                    amounts.append(contentsOf: Self.extractAmounts(from: text))
                }
                let merchant = Self.extractMerchant(from: allText)
                let result = OCRResult(
                    amounts: Array(Set(amounts)),
                    merchant: merchant,
                    allText: allText
                )
                resumed = true
                continuation.resume(returning: result)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                if !resumed {
                    resumed = true
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func extractAmounts(from text: String) -> [Decimal] {
        let patterns = [
            "¥\\s*(\\d+\\.?\\d*)",
            "(\\d+\\.\\d{2})",
            "RMB\\s*(\\d+\\.?\\d*)",
            "金额[:：]\\s*(\\d+\\.?\\d*)",
            "实付[:：]\\s*(\\d+\\.?\\d*)",
            "支付[:：]\\s*(\\d+\\.?\\d*)",
            "总计[:：]\\s*(\\d+\\.?\\d*)",
            "价格[:：]\\s*(\\d+\\.?\\d*)",
        ]
        var amounts: [Decimal] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard match.numberOfRanges > 1,
                      let amountRange = Range(match.range(at: 1), in: text),
                      let amount = Decimal(string: String(text[amountRange])),
                      amount > 0, amount < 100_000 else { continue }
                amounts.append(amount)
            }
        }
        return amounts
    }

    private static func extractMerchant(from text: String) -> String? {
        let keywords = [
            "星巴克", "瑞幸", "luckin", "美团", "饿了么",
            "盒马", "永辉", "沃尔玛", "家乐福",
            "天猫", "京东", "淘宝", "拼多多",
            "滴滴", "高德", "地铁", "公交",
            "麦当劳", "肯德基", "汉堡王",
            "房租", "水电", "物业", "医院", "药店", "诊所",
        ]
        return keywords.first { text.contains($0) }
    }
}
