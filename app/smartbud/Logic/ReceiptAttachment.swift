//
//  ReceiptAttachment.swift
//  smartbud
//
//  Receipt photos are small local files, one directory per transaction in the
//  App Group container. The transaction stores only the references (JSON), so
//  deleting it can clean the files up deterministically; CloudKit carries the
//  bytes as CKAsset records (see Services/ReceiptAttachmentSync.swift).
//
//  Foundation-only on purpose: the lifecycle and the JSON reference format
//  are covered by the Linux harness, SwiftUI/SwiftData are not.
//

import Foundation

struct ReceiptAttachment: Codable, Equatable, Hashable, Identifiable {
    var id: UUID = UUID()
    /// File name inside the per-transaction directory.
    var fileName: String = ""
    var byteCount: Int = 0
    /// FNV-1a of the bytes. Detects a file replaced by another with the same
    /// name and lets the backup report a missing/changed attachment.
    var checksum: String = ""

    init(id: UUID = UUID(), fileName: String = "", byteCount: Int = 0,
         checksum: String = "") {
        self.id = id
        self.fileName = fileName
        self.byteCount = byteCount
        self.checksum = checksum
    }
}

enum ReceiptAttachmentPolicy {
    /// The task asks for "up to N (3 suggested)". Three keeps the CKAsset
    /// upload bounded and the picker row compact on a phone.
    static let maxCount = 3

    static func count(for data: [Data]) -> Int {
        min(data.count, maxCount)
    }
}

enum ReceiptAttachmentStore {
    private static let folderName = "ReceiptAttachments"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// Root directory. The App Group path is shared by the app and its
    /// extension; fall back to Application Support for stores without the
    /// entitlement (previews, macOS development builds).
    static func root(base: URL? = nil) -> URL? {
        if let base { return base.appendingPathComponent(folderName, isDirectory: true) }
        if let group = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.iorest.smartbud") {
            return group.appendingPathComponent(folderName, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory,
                                        in: .userDomainMask).first?
            .appendingPathComponent(folderName, isDirectory: true)
    }

    static func directory(for transactionID: UUID, base: URL? = nil) -> URL? {
        root(base: base)?.appendingPathComponent(transactionID.uuidString, isDirectory: true)
    }
    static func hasFile(for attachment: ReceiptAttachment, transactionID: UUID,
                        base: URL? = nil) -> Bool {
        guard let url = fileURL(for: attachment, transactionID: transactionID, base: base) else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Copies a CloudKit CKAsset back into the transaction's local directory.
    @discardableResult
    static func restore(from source: URL, attachment: ReceiptAttachment,
                        transactionID: UUID, base: URL? = nil) -> Bool {
        guard let dir = directory(for: transactionID, base: base),
              let dest = fileURL(for: attachment, transactionID: transactionID, base: base) else {
            return false
        }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: source, to: dest)
            return true
        } catch {
            return false
        }
    }

    static func fileURL(for attachment: ReceiptAttachment, transactionID: UUID,
                        base: URL? = nil) -> URL? {
        directory(for: transactionID, base: base)?
            .appendingPathComponent(attachment.fileName)
    }

    /// Replaces the whole set for one transaction. Writing into a fresh
    /// directory makes "replace" atomic from the user's point of view: a
    /// failed write leaves no mixture of old and new files.
    @discardableResult
    static func replaceAll(_ data: [Data], for transactionID: UUID,
                           base: URL? = nil) throws -> [ReceiptAttachment] {
        guard root(base: base) != nil, let dir = directory(for: transactionID, base: base) else {
            return []
        }
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
        let kept = Array(data.prefix(ReceiptAttachmentPolicy.maxCount))
        guard !kept.isEmpty else { return [] } // directory already removed

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var refs: [ReceiptAttachment] = []
        for (index, bytes) in kept.enumerated() {
            let ref = ReceiptAttachment(
                fileName: "\(index)-\(checksum(bytes)).jpg",
                byteCount: bytes.count,
                checksum: checksum(bytes)
            )
            try bytes.write(to: dir.appendingPathComponent(ref.fileName), options: .atomic)
            refs.append(ref)
        }
        return refs
    }

    /// Deletes the files for one transaction. Safe to call twice.
    static func removeAll(for transactionID: UUID, base: URL? = nil) throws {
        guard let dir = directory(for: transactionID, base: base),
              FileManager.default.fileExists(atPath: dir.path) else { return }
        try FileManager.default.removeItem(at: dir)
    }

    /// Removes transaction directories no longer referenced by any row.
    /// Called after a wipe or a restore so a deleted transaction can never
    /// leave an orphan photo behind.
    @discardableResult
    static func pruneOrphans(valid transactionIDs: Set<UUID>, base: URL? = nil) throws -> Int {
        guard let root = root(base: base),
              FileManager.default.fileExists(atPath: root.path) else { return 0 }
        var removed = 0
        for url in try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ) where UUID(uuidString: url.lastPathComponent).map({ !transactionIDs.contains($0) }) ?? true {
            try FileManager.default.removeItem(at: url)
            removed += 1
        }
        return removed
    }

    static func encodeJSON(_ attachments: [ReceiptAttachment]) -> String? {
        guard !attachments.isEmpty,
              let data = try? encoder.encode(attachments) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeJSON(_ json: String?) -> [ReceiptAttachment] {
        guard let json, let data = json.data(using: .utf8),
              let refs = try? decoder.decode([ReceiptAttachment].self, from: data) else {
            return []
        }
        return refs
    }

    /// FNV-1a/64, short and dependency-free. Not cryptographic: it only needs
    /// to notice that a local file no longer matches the backed-up reference.
    private static func checksum(_ bytes: Data) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}
