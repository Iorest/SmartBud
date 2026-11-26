//
//  ReceiptAttachmentTests.swift
//  SmartBudTests
//
//  The file lifecycle behind receipt photos: replace must not leave the old
//  files, deleting a transaction must leave no directory, and a prune must
//  recover from a crash between the two writes.
//

import Testing
import Foundation

@Suite("Receipt attachment lifecycle")
struct ReceiptAttachmentTests {
    @Test("Add, replace and remove leave exactly the current files")
    func lifecycle() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("sb-receipts-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let id = UUID()
        let first = try ReceiptAttachmentStore.replaceAll(
            [Data("one".utf8), Data("two".utf8), Data("three".utf8)],
            for: id, base: base)
        #expect(first.count == 3)
        #expect(first.allSatisfy {
            ReceiptAttachmentStore.hasFile(for: $0, transactionID: id, base: base)
        })

        _ = try ReceiptAttachmentStore.replaceAll([Data("one".utf8)], for: id, base: base)
        let dir = ReceiptAttachmentStore.directory(for: id, base: base)
        #expect((try? FileManager.default.contentsOfDirectory(
            at: dir!, includingPropertiesForKeys: nil))?.count == 1)

        try ReceiptAttachmentStore.replaceAll([], for: id, base: base)
        #expect(!FileManager.default.fileExists(atPath: dir!.path))
    }

    @Test("More than three photos are capped")
    func cap() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("sb-receipts-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let refs = try ReceiptAttachmentStore.replaceAll(
            (1...5).map { Data("photo\($0)".utf8) }, for: UUID(), base: base)
        #expect(refs.count == ReceiptAttachmentPolicy.maxCount)
    }

    @Test("Prune removes directories with no live transaction")
    func prune() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("sb-receipts-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let live = UUID(), orphan = UUID()
        _ = try ReceiptAttachmentStore.replaceAll([Data("a".utf8)], for: live, base: base)
        _ = try ReceiptAttachmentStore.replaceAll([Data("b".utf8)], for: orphan, base: base)

        #expect(try ReceiptAttachmentStore.pruneOrphans(valid: [live], base: base) == 1)
        #expect(FileManager.default.fileExists(
            atPath: ReceiptAttachmentStore.directory(for: live, base: base)!.path))
        #expect(!FileManager.default.fileExists(
            atPath: ReceiptAttachmentStore.directory(for: orphan, base: base)!.path))
    }

    @Test("A finished replace leaves no staging directory and names the real container")
    func stagingAndExtension() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("sb-receipts-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let id = UUID()
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) + Data("bytes".utf8)
        let refs = try ReceiptAttachmentStore.replaceAll([png], for: id, base: base)

        #expect(refs.first?.fileName.hasSuffix(".png") == true)
        let staging = ReceiptAttachmentStore.root(base: base)!
            .appendingPathComponent(".\(id.uuidString)-staging")
        #expect(!FileManager.default.fileExists(atPath: staging.path))
    }

    @Test("Reference JSON round-trips and corrupt text decodes empty")
    func references() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("sb-receipts-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let id = UUID()
        let refs = try ReceiptAttachmentStore.replaceAll([Data("round".utf8)], for: id, base: base)
        #expect(ReceiptAttachmentStore.decodeJSON(ReceiptAttachmentStore.encodeJSON(refs)!) == refs)
        #expect(ReceiptAttachmentStore.decodeJSON("not json").isEmpty)
        #expect(ReceiptAttachmentStore.decodeJSON(nil).isEmpty)
    }
}
