#!/usr/bin/env python3
"""Validate the parsing corpus fixtures.

Standard library only. Run from anywhere:

    python3 app/SmartBudTests/Fixtures/validate_corpus.py

Exit code 0 means every check passed: schema, types, amount sanity,
category coverage, duplicates and PII patterns. Any failure prints the
offending entry id and exits 1.
"""

import json
import re
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path

FIXTURES = Path(__file__).resolve().parent
TEXT_FILE = FIXTURES / "corpus_text.json"
RECEIPT_FILE = FIXTURES / "corpus_receipts.json"
README_FILE = FIXTURES / "README.md"

# Keep in sync with ExpenseTextParser.bucketKeywords in
# app/smartbud/Services/Parsing/ExpenseTextParser.swift.
CATEGORIES = {
    "餐饮", "交通", "购物", "咖啡", "娱乐",
    "通讯", "教育", "医疗", "工资", "奖金",
}
INCOME_CATEGORIES = {"工资", "奖金"}
PLATFORMS = {"alipay", "wechat", "paper"}
MAX_AMOUNT = Decimal(100_000_000)  # Money.maxAmount
TEXT_KEYS = {"id", "text", "amount", "currency", "direction", "category",
             "merchant", "note"}
RECEIPT_KEYS = {"id", "lines", "amount", "merchant", "platform"}
EXPECTED_TEXT = 600
EXPECTED_RECEIPTS = 200

PII_PATTERNS = {
    "mobile number": re.compile(r"(?<!\d)1[3-9]\d{9}(?!\d)"),
    "card number": re.compile(r"(?<!\d)(?:\d{4}[ -]){3}\d{4}(?!\d)|(?<!\d)\d{16,19}(?!\d)"),
    "ID card": re.compile(r"(?<!\d)\d{17}[\dXx](?!\d)"),
    "email": re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
}

errors = []


def fail(entry_id, message):
    errors.append(f"{entry_id}: {message}")


def normalize(value):
    return " ".join(str(value).lower().split())


def as_decimal(value):
    try:
        return Decimal(str(value))
    except InvalidOperation:
        return None


def numbers_in(text):
    found = set()
    for raw in re.findall(r"\d[\d,]*(?:\.\d+)?", text):
        value = as_decimal(raw.replace(",", ""))
        if value is not None:
            found.add(value)
    return found


def amount_is_visible(amount, text):
    return any(number == amount for number in numbers_in(text))


def validate_text(entries):
    if not isinstance(entries, list):
        fail("corpus_text.json", "top level must be a JSON array")
        return
    if len(entries) != EXPECTED_TEXT:
        fail("corpus_text.json", f"expected {EXPECTED_TEXT} entries, found {len(entries)}")

    ids = set()
    texts = {}
    for entry in entries:
        entry_id = entry.get("id", "<missing id>")
        if not isinstance(entry, dict):
            fail(entry_id, "entry must be a JSON object")
            continue
        keys = set(entry)
        if keys != TEXT_KEYS:
            missing = TEXT_KEYS - keys
            extra = keys - TEXT_KEYS
            fail(entry_id, f"keys mismatch (missing={sorted(missing)}, extra={sorted(extra)})")
            continue
        if entry_id in ids:
            fail(entry_id, "duplicate id")
        ids.add(entry_id)
        if not re.fullmatch(r"text-\d{4}", str(entry_id)):
            fail(entry_id, "id must look like text-0001")

        text = entry["text"]
        if not isinstance(text, str) or not text.strip():
            fail(entry_id, "text must be a non-empty string")
            continue
        key = normalize(text)
        if key in texts:
            fail(entry_id, f"duplicate text (same as {texts[key]})")
        texts[key] = entry_id

        amount = entry["amount"]
        if isinstance(amount, bool) or not isinstance(amount, (int, float)):
            fail(entry_id, "amount must be a number")
            continue
        value = as_decimal(amount)
        if value is None or value <= 0:
            fail(entry_id, "amount must be > 0")
            continue
        if value > MAX_AMOUNT:
            fail(entry_id, f"amount exceeds app cap {MAX_AMOUNT}")
        if value.as_tuple().exponent < -2:
            fail(entry_id, "amount must have at most 2 decimal places")

        currency = entry["currency"]
        if not isinstance(currency, str) or not re.fullmatch(r"[A-Z]{3}", currency):
            fail(entry_id, "currency must be a 3-letter ISO code")

        direction = entry["direction"]
        if direction not in ("expense", "income"):
            fail(entry_id, "direction must be expense or income")

        category = entry["category"]
        if category not in CATEGORIES:
            fail(entry_id, f"category {category!r} is not one of the 10 buckets")
        if category in INCOME_CATEGORIES and direction != "income":
            fail(entry_id, f"{category} entries must be income")

        merchant = entry["merchant"]
        if merchant is not None and (not isinstance(merchant, str) or not merchant.strip()):
            fail(entry_id, "merchant must be a non-empty string or null")
        note = entry["note"]
        if note is not None and (not isinstance(note, str) or not note.strip()):
            fail(entry_id, "note must be a non-empty string or null")

        if value is not None and not amount_is_visible(value, text):
            fail(entry_id, f"amount {amount} does not appear in text {text!r}")

    print(f"text corpus: {len(entries)} entries, {len(texts)} unique ({len(ids)} ids)")


def validate_receipts(entries):
    if not isinstance(entries, list):
        fail("corpus_receipts.json", "top level must be a JSON array")
        return
    if len(entries) != EXPECTED_RECEIPTS:
        fail("corpus_receipts.json",
             f"expected {EXPECTED_RECEIPTS} entries, found {len(entries)}")

    ids = set()
    signatures = {}
    platforms = set()
    for entry in entries:
        entry_id = entry.get("id", "<missing id>")
        if not isinstance(entry, dict):
            fail(entry_id, "entry must be a JSON object")
            continue
        keys = set(entry)
        if keys != RECEIPT_KEYS:
            missing = RECEIPT_KEYS - keys
            extra = keys - RECEIPT_KEYS
            fail(entry_id, f"keys mismatch (missing={sorted(missing)}, extra={sorted(extra)})")
            continue
        if entry_id in ids:
            fail(entry_id, "duplicate id")
        ids.add(entry_id)
        if not re.fullmatch(r"rcpt-\d{3}", str(entry_id)):
            fail(entry_id, "id must look like rcpt-001")

        lines = entry["lines"]
        if not isinstance(lines, list) or not lines:
            fail(entry_id, "lines must be a non-empty array")
            continue
        if not all(isinstance(line, str) and line.strip() for line in lines):
            fail(entry_id, "every line must be a non-empty string")
            continue
        signature = normalize("\n".join(lines))
        if signature in signatures:
            fail(entry_id, f"duplicate receipt (same as {signatures[signature]})")
        signatures[signature] = entry_id

        amount = entry["amount"]
        if isinstance(amount, bool) or not isinstance(amount, (int, float)):
            fail(entry_id, "amount must be a number")
            continue
        value = as_decimal(amount)
        if value is None or value <= 0:
            fail(entry_id, "amount must be > 0")
            continue
        if value > MAX_AMOUNT:
            fail(entry_id, f"amount exceeds app cap {MAX_AMOUNT}")
        if value.as_tuple().exponent < -2:
            fail(entry_id, "amount must have at most 2 decimal places")
        if not amount_is_visible(value, "\n".join(lines)):
            fail(entry_id, f"amount {amount} does not appear in lines")

        merchant = entry["merchant"]
        if not isinstance(merchant, str) or not merchant.strip():
            fail(entry_id, "merchant must be a non-empty string")

        platform = entry["platform"]
        if platform not in PLATFORMS:
            fail(entry_id, f"platform {platform!r} must be one of {sorted(PLATFORMS)}")
        platforms.add(platform)

    for platform in PLATFORMS - platforms:
        fail("corpus_receipts.json", f"no receipts for platform {platform}")

    print(f"receipt corpus: {len(entries)} entries, {len(signatures)} unique "
          f"(platforms: {', '.join(sorted(platforms))})")


def scan_pii(entries):
    """Scan every string in the fixtures and the README for PII patterns."""
    def strings_in(value):
        if isinstance(value, str):
            yield value
        elif isinstance(value, dict):
            for item in value.values():
                yield from strings_in(item)
        elif isinstance(value, list):
            for item in value:
                yield from strings_in(item)

    sources = []
    for path in (TEXT_FILE, RECEIPT_FILE):
        sources.append((path.name, json.loads(path.read_text(encoding="utf-8"))))
    if README_FILE.exists():
        sources.append((README_FILE.name, README_FILE.read_text(encoding="utf-8")))

    hits = 0
    for name, payload in sources:
        for value in strings_in(payload):
            for label, pattern in PII_PATTERNS.items():
                match = pattern.search(value)
                if match:
                    hits += 1
                    fail(name, f"possible {label}: {match.group(0)!r} in {value[:60]!r}")
    print(f"PII scan: {len(sources)} files, {hits} hit(s)")


def main():
    for path in (TEXT_FILE, RECEIPT_FILE):
        if not path.exists():
            print(f"missing fixture: {path}", file=sys.stderr)
            return 1
    text_entries = json.loads(TEXT_FILE.read_text(encoding="utf-8"))
    receipt_entries = json.loads(RECEIPT_FILE.read_text(encoding="utf-8"))
    validate_text(text_entries)
    validate_receipts(receipt_entries)
    scan_pii([text_entries, receipt_entries])

    if errors:
        print(f"\n{len(errors)} error(s):", file=sys.stderr)
        for message in errors:
            print(f"  - {message}", file=sys.stderr)
        return 1
    print("\nOK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
