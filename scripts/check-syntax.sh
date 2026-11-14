#!/usr/bin/env bash
#
# Parses every Swift source in the repo — no Xcode, no simulator, no SDK.
#
# Why this exists: `swiftc -parse` runs the parser only. It resolves no
# imports and needs no SDK, so it works on Linux with a plain swift.org
# toolchain and on a macOS runner before the build starts. What it proves is
# narrow but real: a file that no longer parses fails here in seconds instead
# of after a six-minute xcodebuild. What it does NOT prove is type correctness
# — a renamed symbol or a changed signature still needs the macOS job.
#
# Usage:
#   scripts/check-syntax.sh
#
# Toolchain resolution matches scripts/linux-tests.sh: $SMARTBUD_SWIFT_HOME
# first, then `swiftc` on PATH. No toolchain exits 2, so a machine without
# Swift skips this check instead of reporting a false failure.
#
# swift.org tarball (Linux; Arch/Manjaro needs the ncurses + libxml2 names
# fixed up, see docs/engineering.md § Linux 逻辑测试):
#   https://download.swift.org/swift-6.4.2-release/ubuntu2404/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE-ubuntu24.04.tar.gz

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

swiftc_bin=""
if [ -n "${SMARTBUD_SWIFT_HOME:-}" ] && [ -x "$SMARTBUD_SWIFT_HOME/usr/bin/swiftc" ]; then
    swiftc_bin="$SMARTBUD_SWIFT_HOME/usr/bin/swiftc"
elif command -v swiftc >/dev/null 2>&1; then
    swiftc_bin=$(command -v swiftc)
fi

if [ -z "$swiftc_bin" ]; then
    cat >&2 <<'MSG'
No Swift toolchain found; skipping the syntax check.

Install a Linux toolchain from https://swift.org/download/ and either put it on
PATH or point SMARTBUD_SWIFT_HOME at the unpacked directory:

    export SMARTBUD_SWIFT_HOME=/opt/swift-6.4.2-RELEASE-ubuntu24.04
MSG
    exit 2
fi

# Every target in the project: app, unit tests, UI tests, widget, macOS shell.
# Generated build trees are pruned because a stale .build copy would otherwise
# double the file count and report errors in code nobody edits.
sources=()
while IFS= read -r -d '' file; do
    sources+=("${file#"$root"/}")
done < <(find "$root/app" \
    \( -name .build -o -name DerivedData -o -name .swiftpm \) -prune -o \
    -name '*.swift' -print0 | sort -z)

if [ "${#sources[@]}" -eq 0 ]; then
    echo "FAIL: no Swift sources found under app/ — wrong checkout?" >&2
    exit 1
fi

echo "Parsing ${#sources[@]} Swift file(s) with $("$swiftc_bin" --version 2>/dev/null | head -1)..."

if ! "$swiftc_bin" -parse -swift-version 6 "${sources[@]}"; then
    echo "FAIL: at least one Swift file does not parse; see the file:line errors above." >&2
    exit 1
fi

echo "ok: ${#sources[@]} Swift file(s) parse"
