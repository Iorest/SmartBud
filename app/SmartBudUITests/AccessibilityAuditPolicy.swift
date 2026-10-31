//
//  AccessibilityAuditPolicy.swift
//  SmartBudUITests
//
//  Which `performAccessibilityAudit` categories the smoke tests enforce.
//
//  The audit runs on every smoke test. A category that reports issues we have
//  knowingly deferred must be listed in `ignoredTypes` with a reason in
//  docs/engineering.md — never dropped silently, and never by matching on
//  localized copy.
//

import XCTest

enum AccessibilityAuditPolicy {

    /// Categories intentionally not enforced yet. Keep this empty unless the
    /// corresponding entry exists in docs/engineering.md.
    static let ignoredTypes: XCUIAccessibilityAuditType = []

    /// Everything the audit can check, minus the documented exceptions.
    static let auditedTypes: XCUIAccessibilityAuditType =
        XCUIAccessibilityAuditType.all.subtracting(ignoredTypes)
}
