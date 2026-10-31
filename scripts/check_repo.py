#!/usr/bin/env python3
"""Offline structural gate for the SmartBud repo.

Runs on plain Python 3 with no Xcode and no network, so the checks that CI
used to provide keep working while GitHub Actions is unavailable:

  1. project.pbxproj -- every file reference resolves to a file on disk, and
     every Swift file under app/ is referenced (a missing `smartbud/` prefix
     or an unregistered new file is caught here instead of by a red build).
  2. accessibility identifiers -- every identifier the UI tests drive exists in
     the app sources, every AccessibilityID constant the tests use is declared,
     and no placeholder/lint bait is left in an identifier.
  3. docs -- relative links in README.md and docs/*.md resolve.

Usage:
    python3 scripts/check_repo.py            # check the current checkout
    python3 scripts/check_repo.py --root .   # explicit repo root

Exit code 0 = clean, 1 = findings.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

PBXPROJ = os.path.join("app", "SmartBud.xcodeproj", "project.pbxproj")
APP_DIR = os.path.join("app")
IDENT_SWIFT = os.path.join("app", "smartbud", "Utilities", "AccessibilityID.swift")
UITEST_DIR = os.path.join("app", "SmartBudUITests")

OBJ_HEAD_RE = re.compile(r"^\t\t([0-9A-F]{24,32})(?: /\*.*?\*/)? = \{")
OBJ_END_RE = re.compile(r"^\t\t\};")
ISA_RE = re.compile(r"isa = ([A-Za-z]+);")
PATH_RE = re.compile(r"\bpath = \"?([^\";]+)\"?;")
NAME_RE = re.compile(r"\bname = \"?([^\";]+)\"?;")
TREE_RE = re.compile(r"sourceTree = \"?([^\";]+)\"?;")
CHILDREN_RE = re.compile(r"children = \((.*?)\);", re.S)
BUILD_FILES_RE = re.compile(r"\bfiles = \((.*?)\);", re.S)
ID_REF_RE = re.compile(r"([0-9A-F]{24,32})")
PLACEHOLDER_RE = re.compile(r"DELIBERATELY|BROKEN|TODO|FIXME|XXX", re.I)

IDENT_CONST_RE = re.compile(r'static let (\w+)\s*=\s*"(.*?)"')
IDENT_FUNC_RE = re.compile(r'static func (\w+)\s*\([^)]*\)\s*->\s*String\s*\{\s*"(sb\.[^"\\]*)')
IDENT_LITERAL_RE = re.compile(r'"(sb\.[^"\\]*)"')
IDENT_USAGE_RE = re.compile(r"AccessibilityID\.(\w+)")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def parse_pbxproj(text):
    """Object bodies, tolerating both one-line and multi-line entries."""
    objects = {}
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        head = OBJ_HEAD_RE.match(lines[i])
        if not head:
            i += 1
            continue
        oid = head.group(1)
        if lines[i].rstrip().endswith("};"):
            body = lines[i]
            i += 1
        else:
            body_lines = [lines[i]]
            i += 1
            while i < len(lines) and not OBJ_END_RE.match(lines[i]):
                body_lines.append(lines[i])
                i += 1
            i += 1
            body = "\n".join(body_lines)
        isa = ISA_RE.search(body)
        path = PATH_RE.search(body)
        name = NAME_RE.search(body)
        tree = TREE_RE.search(body)
        objects[oid] = {
            "isa": isa.group(1) if isa else "",
            "body": body,
            "path": path.group(1) if path else None,
            "name": name.group(1) if name else None,
            "tree": tree.group(1) if tree else None,
        }
    parents = {}
    for oid, obj in objects.items():
        if obj["isa"] not in ("PBXGroup", "PBXVariantGroup"):
            continue
        children = CHILDREN_RE.search(obj["body"])
        if not children:
            continue
        for child in ID_REF_RE.findall(children.group(1)):
            parents.setdefault(child, oid)
    return objects, parents


def resolve_file_ref(objects, parents, oid):
    obj = objects[oid]
    tree = obj["tree"] or "<group>"
    path = obj["path"] or obj["name"]
    if not path:
        return None
    if tree == "SOURCE_ROOT":
        return os.path.join(APP_DIR, path)
    if tree != "<group>":
        return None  # <absolute> / SDKROOT / BUILT_PRODUCTS_DIR: not our business
    parts = [path]
    cur = parents.get(oid)
    seen = set()
    while cur and cur not in seen:
        seen.add(cur)
        parent = objects.get(cur)
        if parent is None:
            break
        if parent["path"]:
            parts.insert(0, parent["path"])
        cur = parents.get(cur)
    return os.path.join(APP_DIR, *parts)


def check_pbxproj(root, problems):
    pbx_path = os.path.join(root, PBXPROJ)
    if not os.path.exists(pbx_path):
        problems.append(f"pbxproj: {PBXPROJ} not found")
        return
    objects, parents = parse_pbxproj(read(pbx_path))

    refs = {oid for oid, o in objects.items() if o["isa"] == "PBXFileReference"}
    resolved = {}
    for oid in refs:
        full = resolve_file_ref(objects, parents, oid)
        if full is None:
            continue
        obj = objects[oid]
        if obj["tree"] == "<group>" and not parents.get(oid):
            # A <group> reference with no parent group cannot be placed.
            problems.append(f"pbxproj: {obj['path'] or obj['name']} is not attached to a group")
            continue
        resolved[oid] = full
        if not os.path.exists(os.path.join(root, full)):
            hint = ""
            named = obj["name"] or ""
            if named and named != obj["path"]:
                hint = f" (name = {named})"
            problems.append(f"pbxproj: missing file for reference -> {full}{hint}")

    # Sources build phases must point at real, resolvable files.
    for oid, obj in objects.items():
        if obj["isa"] != "PBXSourcesBuildPhase":
            continue
        files = BUILD_FILES_RE.search(obj["body"])
        if not files:
            continue
        for build_id in ID_REF_RE.findall(files.group(1)):
            build = objects.get(build_id)
            if not build or build["isa"] != "PBXBuildFile":
                problems.append(f"pbxproj: sources phase references unknown build file {build_id}")
                continue
            ref = re.search(r"fileRef = ([0-9A-F]{24,32})", build["body"])
            if not ref:
                continue
            if ref.group(1) not in resolved:
                problems.append(
                    f"pbxproj: build file {build_id} points at fileRef {ref.group(1)} "
                    "that does not resolve to a path"
                )

    # Every Swift file on disk should be registered (Xcode lists files explicitly).
    registered = {
        os.path.normpath(p)
        for p in resolved.values()
        if p and p.endswith(".swift")
    }
    for dirpath, dirnames, filenames in os.walk(os.path.join(root, APP_DIR)):
        dirnames[:] = [d for d in dirnames if not d.endswith(".xcodeproj") and d != ".git"]
        for fname in filenames:
            if not fname.endswith(".swift"):
                continue
            rel = os.path.normpath(os.path.relpath(os.path.join(dirpath, fname), root))
            if rel not in registered:
                problems.append(f"pbxproj: {rel} is on disk but not in the project file")
    return objects


def check_identifiers(root, problems, notes):
    ident_path = os.path.join(root, IDENT_SWIFT)
    if not os.path.exists(ident_path):
        problems.append(f"identifiers: {IDENT_SWIFT} not found")
        return
    ident_source = read(ident_path)
    constants = dict(IDENT_CONST_RE.findall(ident_source))
    # Parameterised identifiers ("sb.pad.digit.\(n)") are factories, not constants.
    constants.update(dict(IDENT_FUNC_RE.findall(ident_source)))

    app_literals = set()
    for dirpath, _dirnames, filenames in os.walk(os.path.join(root, APP_DIR)):
        if ".xcodeproj" in dirpath or dirpath.startswith(os.path.join(root, UITEST_DIR)):
            continue
        for fname in filenames:
            if not fname.endswith(".swift"):
                continue
            app_literals.update(IDENT_LITERAL_RE.findall(read(os.path.join(dirpath, fname))))
    app_literals.update(constants.values())

    for name, value in constants.items():
        if PLACEHOLDER_RE.search(value):
            problems.append(f"identifiers: constant {name} holds placeholder value {value!r}")

    for literal in sorted(app_literals):
        if PLACEHOLDER_RE.search(literal):
            problems.append(f"identifiers: app source carries placeholder identifier {literal!r}")

    used = set()
    for dirpath, _dirnames, filenames in os.walk(os.path.join(root, UITEST_DIR)):
        for fname in filenames:
            if not fname.endswith(".swift"):
                continue
            text = read(os.path.join(dirpath, fname))
            for name in IDENT_USAGE_RE.findall(text):
                used.add(name)
                if name not in constants:
                    problems.append(
                        f"identifiers: UI test uses AccessibilityID.{name} "
                        "that is not declared in AccessibilityID.swift"
                    )
            for literal in IDENT_LITERAL_RE.findall(text):
                if PLACEHOLDER_RE.search(literal):
                    problems.append(f"identifiers: UI test carries placeholder identifier {literal!r}")
                if literal in app_literals:
                    continue
                if any(lit.startswith(literal) for lit in app_literals):
                    continue
                problems.append(
                    f"identifiers: UI test queries {literal!r} which no app source declares"
                )

    unused = sorted(set(constants) - used)
    if unused:
        notes.append(f"identifiers: {len(unused)} constant(s) not driven by UI tests: {', '.join(unused)}")


def check_docs(root, problems):
    targets = [os.path.join(root, "README.md")]
    docs_dir = os.path.join(root, "docs")
    if os.path.isdir(docs_dir):
        targets += [
            os.path.join(docs_dir, f) for f in sorted(os.listdir(docs_dir)) if f.endswith(".md")
        ]
    for path in targets:
        if not os.path.exists(path):
            continue
        base = os.path.dirname(path)
        for link in LINK_RE.findall(read(path)):
            link = link.split("#")[0].strip()
            if not link or "://" in link or link.startswith("mailto:"):
                continue
            if not os.path.exists(os.path.normpath(os.path.join(base, link))):
                problems.append(f"docs: {os.path.relpath(path, root)} links to missing {link}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    root = os.path.abspath(args.root)

    problems, notes = [], []
    check_pbxproj(root, problems)
    check_identifiers(root, problems, notes)
    check_docs(root, problems)

    for note in notes:
        print(f"note: {note}")
    for problem in problems:
        print(f"FAIL: {problem}")
    if problems:
        print(f"\n{len(problems)} problem(s)")
        return 1
    print("ok: project file, identifiers and docs are consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
