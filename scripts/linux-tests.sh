#!/usr/bin/env bash
#
# Runs the Foundation-only slice of SmartBudLogic on Linux.
#
# Why this exists: the full suite needs Xcode and an iOS simulator, so it only
# runs on GitHub's macOS runners. When those runners are unavailable (billing,
# outage, or a fresh machine without CI), the money / period / CSV / validation /
# merchant / deep-link logic can still be compiled and tested here — no Xcode,
# no simulator, no macOS minutes.
#
# What it does NOT cover: SwiftUI views, SwiftData models, CloudKit, StoreKit,
# natural-language merchant extraction, localized formatting, and every
# XCUITest. Those stay with the macOS job.
#
# Usage:
#   scripts/linux-tests.sh                 # build + run the Linux subset
#   scripts/linux-tests.sh --filter Money  # pass extra args through to swift test
#
# Requires a Swift toolchain for Linux (6.0+):
#   - on PATH as `swift`, or
#   - at $SMARTBUD_SWIFT_HOME/usr/bin/swift (an unpacked swift.org toolchain).
#
# swift.org tarball (Arch/Manjaro needs the ncurses + libxml2 names fixed up,
# see docs/engineering.md § Linux 逻辑测试):
#   https://download.swift.org/swift-6.4.2-release/ubuntu2404/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE-ubuntu24.04.tar.gz

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
out="$root/.linux-tests"
tests_dir="$out/Tests/SmartBudLogicTests"

swift_bin=""
if [ -n "${SMARTBUD_SWIFT_HOME:-}" ] && [ -x "$SMARTBUD_SWIFT_HOME/usr/bin/swift" ]; then
    swift_bin="$SMARTBUD_SWIFT_HOME/usr/bin/swift"
elif command -v swift >/dev/null 2>&1; then
    swift_bin=$(command -v swift)
fi

if [ -z "$swift_bin" ]; then
    cat >&2 <<'MSG'
No Swift toolchain found.

Install a Linux toolchain from https://swift.org/download/ and either put it on
PATH or point SMARTBUD_SWIFT_HOME at the unpacked directory:

    export SMARTBUD_SWIFT_HOME=/opt/swift-6.4.2-RELEASE-ubuntu24.04
MSG
    exit 2
fi

# Sources: only files whose imports are Foundation-only. Adding a file here is
# how the Linux coverage grows; anything that pulls in SwiftUI/SwiftData will
# fail to compile and belongs to the macOS job.
app_sources=(
    Logic/AccountBalance.swift
    Logic/AppPeriod.swift
    Logic/BadDebtPolicy.swift
    Logic/BudgetLogic.swift
    Logic/CSVSupport.swift
    Logic/CurrencyConversion.swift
    Logic/CurrencyRebase.swift
    Logic/ImportAmount.swift
    Logic/MerchantNormalizer.swift
    Logic/RefundPolicy.swift
    Logic/Money.swift
    Logic/TransactionValidation.swift
    Models/BudgetTimeFrame.swift
    Models/CategoryCreationErrors.swift
    Models/Currency.swift
    Models/FilterType.swift
    Services/ExportSchema.swift
    Services/Import/CSVTable.swift
    Services/LLM/LLMProvider.swift
    Utilities/AmountFormatting.swift
    Utilities/DeepLink.swift
    Utilities/ProAccess.swift
    Utilities/SettingsKeys.swift
)

test_sources=(
    AccountBalanceTests.swift
    AppPeriodTests.swift
    BadDebtPolicyTests.swift
    CSVTableTests.swift
    DeepLinkTests.swift
    LLMProviderTests.swift
    MerchantNormalizerTests.swift
    MoneyFormattingTests.swift
    RefundPolicyTests.swift
    ProAccessTests.swift
    TransactionValidationTests.swift
)

rm -rf "$out"
mkdir -p "$tests_dir"

cat > "$out/Package.swift" <<'PKG'
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SmartBudLinux",
    targets: [
        // Mirrors the Xcode layout: the unit-test target compiles the app's
        // Foundation-only sources directly, so no `@testable import` is needed.
        .testTarget(name: "SmartBudLogicTests", path: "Tests/SmartBudLogicTests")
    ]
)
PKG

for f in "${app_sources[@]}"; do
    cp "$root/app/smartbud/$f" "$tests_dir/$(basename "$f")"
done
for f in "${test_sources[@]}"; do
    cp "$root/app/SmartBudTests/$f" "$tests_dir/$f"
done
cp "$root/scripts/linux-tests/LinuxShims.swift" "$tests_dir/LinuxShims.swift"

cd "$out"
exec "$swift_bin" test "$@"
