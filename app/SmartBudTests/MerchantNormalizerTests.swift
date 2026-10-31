//
//  MerchantNormalizerTests.swift
//  SmartBudTests
//
//  The user sees one shop; the ledger sees "美团-张亮麻辣烫", "美团外卖" and
//  "美团". Every rule that decides whether those are one merchant is pinned
//  here, because a gap silently splits the merchant ranking into near
//  duplicates and nothing else in the app would notice.
//

import Testing
import Foundation

@Suite("Merchant normalisation")
struct MerchantNormalizerTests {

    @Test("The three 美团 spellings collapse to one key")
    func platformPrefixCollapses() {
        let keys = ["美团", "美团外卖", "美团-张亮麻辣烫"].compactMap {
            MerchantNormalizer.normalize($0)?.key
        }
        #expect(keys.count == 3)
        #expect(Set(keys) == Set(["美团"]))
    }

    @Test("Case and full-width spellings of one brand share a key")
    func widthAndCase() {
        let fullWidth = MerchantNormalizer.normalize("ＳＴＡＲＢＵＣＫＳ")
        let lower = MerchantNormalizer.normalize("starbucks")
        #expect(fullWidth?.key == lower?.key)
        #expect(fullWidth?.key == "星巴克")
        #expect(fullWidth?.name == "星巴克")
    }

    @Test("Company and branch suffixes are dropped")
    func suffixes() {
        #expect(MerchantNormalizer.normalize("张亮麻辣烫（望京店）有限公司")?.key == "张亮麻辣烫")
        #expect(MerchantNormalizer.normalize("瑞幸咖啡-001")?.key == "瑞幸")
    }

    @Test("Aliases unite alternative names of the same shop")
    func aliases() {
        let keys = ["滴滴", "滴滴出行", "滴滴打车", "didi"].compactMap {
            MerchantNormalizer.normalize($0)?.key
        }
        #expect(keys.count == 4)
        #expect(Set(keys) == Set(["滴滴"]))
    }

    @Test("A bare number is not a merchant")
    func numeric() {
        #expect(MerchantNormalizer.normalize("12345") == nil)
        #expect(MerchantNormalizer.derive(fromNote: "8888") == nil)
    }

    @Test("Nothing to name yields no merchant")
    func emptyInput() {
        #expect(MerchantNormalizer.normalize(nil) == nil)
        #expect(MerchantNormalizer.normalize("") == nil)
        #expect(MerchantNormalizer.normalize("   ") == nil)
        #expect(MerchantNormalizer.normalize("···") == nil)
        #expect(MerchantNormalizer.derive(fromNote: nil) == nil)
        #expect(MerchantNormalizer.derive(fromNote: "   ") == nil)
    }

    @Test("A brand in a note names the merchant, a generic note does not")
    func deriveFromNote() {
        #expect(MerchantNormalizer.derive(fromNote: "美团外卖 35")?.key == "美团")
        #expect(MerchantNormalizer.derive(fromNote: "张亮麻辣烫")?.key == "张亮麻辣烫")
        #expect(MerchantNormalizer.derive(fromNote: "午饭 35") == nil)
        #expect(MerchantNormalizer.derive(fromNote: "地铁") == nil)
    }

    @Test("A caller-supplied alias table overrides the built-in one")
    func customAliasTable() {
        let table = MerchantAliasTable(
            displayNames: ["楼下面馆": "楼下面馆"],
            aliases: ["楼下牛肉面": "楼下面馆"]
        )
        #expect(MerchantNormalizer.normalize("楼下牛肉面", aliases: table)?.key == "楼下面馆")
        // Without the override the name stays as written rather than being
        // guessed into an existing shop.
        #expect(MerchantNormalizer.normalize("楼下牛肉面")?.key == "楼下牛肉面")
    }

    @Test("A key is never produced for a name that has no merchant")
    func keyInvariant() {
        #expect(MerchantNormalizer.key(nil) == nil)
        #expect(MerchantNormalizer.key("  ") == nil)
        #expect(MerchantNormalizer.key("000000") == nil)
        #expect(MerchantNormalizer.displayName(forKey: "starbucks") == "星巴克")
    }
}
