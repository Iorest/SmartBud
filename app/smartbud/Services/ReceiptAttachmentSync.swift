//
//  ReceiptAttachmentSync.swift
//  smartbud
//
//  SwiftData syncs model fields, not files next to the store. Receipt bytes
//  are local files (see Logic/ReceiptAttachment.swift), so their CloudKit
//  counterpart is an explicit CKRecord carrying a CKAsset. The record name is
//  the attachment id, which makes upload/delete idempotent and lets another
//  device restore a photo whose metadata arrived through SwiftData but whose
//  file has not been downloaded yet.
//
//  Every operation is best effort: a failed upload never rolls back a ledger
//  write, and a signed-out device simply keeps its local copy.
//

import Foundation
import CloudKit
import os

private let attachmentLogger = Logger(
    subsystem: "com.iorest.smartbud", category: "receipt-attachments")

enum ReceiptAttachmentSync {
    static let recordType = "ReceiptAttachment"
    private static let containerID = "iCloud.com.iorest.smartbud"
    private static let transactionKey = "transactionID"
    private static let checksumKey = "checksum"
    private static let assetKey = "asset"

    private static var database: CKDatabase {
        CKContainer(identifier: containerID).privateCloudDatabase
    }

    /// Uploads or replaces the assets for one transaction. The CKAsset keeps
    /// reading from `fileURL` until the save returns, so call this while the
    /// local files are still in place.
    static func upload(_ attachments: [ReceiptAttachment], transactionID: UUID,
                       base: URL? = nil) async {
        #if os(macOS)
        // The macOS target has no CloudKit entitlement; enabling it traps in
        // PFCloudKitContainerProvider (see SwiftDataCore.appGroupContainer).
        return
        #else
        for attachment in attachments {
            guard let file = ReceiptAttachmentStore.fileURL(
                for: attachment, transactionID: transactionID, base: base),
                FileManager.default.fileExists(atPath: file.path) else { continue }
            let record = CKRecord(
                recordType: Self.recordType,
                recordID: CKRecord.ID(recordName: attachment.id.uuidString))
            record[transactionKey] = transactionID.uuidString as CKRecordValue
            record[checksumKey] = attachment.checksum as CKRecordValue
            record[assetKey] = CKAsset(fileURL: file)
            do {
                _ = try await database.save(record)
            } catch {
                attachmentLogger.error(
                    "Receipt asset upload failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        #endif
    }

    /// Removes the CKAssets for attachments that were replaced or deleted.
    static func remove(attachmentIDs: [UUID]) async {
        #if os(macOS)
        return
        #else
        for id in attachmentIDs {
            do {
                _ = try await database.deleteRecord(
                    withID: CKRecord.ID(recordName: id.uuidString))
            } catch {
                attachmentLogger.error(
                    "Receipt asset delete failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        #endif
    }

    /// Restores any referenced photo whose local file is missing (e.g. after
    /// a restore onto a device that had not downloaded it yet).
    /// Returns how many files came back from iCloud.
    @discardableResult
    static func downloadMissing(_ attachments: [ReceiptAttachment], transactionID: UUID,
                                base: URL? = nil) async -> Int {
        #if os(macOS)
        return 0
        #else
        var restored = 0
        for attachment in attachments {
            guard !ReceiptAttachmentStore.hasFile(
                for: attachment, transactionID: transactionID, base: base) else { continue }
            do {
                let record = try await database.record(
                    for: CKRecord.ID(recordName: attachment.id.uuidString))
                guard let asset = record[assetKey] as? CKAsset, let source = asset.fileURL else {
                    continue
                }
                if ReceiptAttachmentStore.restore(
                    from: source, attachment: attachment,
                    transactionID: transactionID, base: base) {
                    restored += 1
                }
            } catch {
                attachmentLogger.error(
                    "Receipt asset download failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return restored
        #endif
    }

    /// Used by "Erase All Data": the SwiftData zone delete does not touch
    /// records in the database's default zone.
    static func removeAll() async {
        #if os(macOS)
        return
        #else
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        guard let records = try? await database.perform(query, inZoneWith: nil) else { return }
        for record in records {
            _ = try? await database.deleteRecord(withID: record.recordID)
        }
        #endif
    }
}
