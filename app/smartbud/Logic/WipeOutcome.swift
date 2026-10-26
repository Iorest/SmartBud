//
//  WipeOutcome.swift
//  smartbud
//
//  Result of "Erase all data" and the CloudKit error mapping behind it.
//  Kept outside `DataRepository` so the mapping is testable without a store.
//

import CloudKit

enum WipeOutcome: Equatable {
    /// Local store cleared and the CloudKit zone deleted (or already gone).
    case complete
    /// Local store cleared; iCloud deletion failed for a transient reason.
    /// Re-running the wipe is required — nothing removes the zone later.
    case iCloudRetryable
    /// Local store cleared, but this Apple ID cannot delete the zone.
    case iCloudAccountMismatch
    /// Local delete itself failed.
    case localFailed
    /// The local store could not be opened; nothing was deleted on purpose.
    case storageUnavailable
}

enum WipeClassifier {
    static func outcome(for error: CKError) -> WipeOutcome {
        switch error.code {
        case .zoneNotFound, .unknownItem:
            return .complete
        case .notAuthenticated, .permissionFailure:
            return .iCloudAccountMismatch
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy:
            return .iCloudRetryable
        default:
            return .iCloudRetryable
        }
    }
}
