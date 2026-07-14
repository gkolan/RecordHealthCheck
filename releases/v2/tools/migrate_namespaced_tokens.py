#!/usr/bin/env python3
"""Audit or convert legacy Record Health Check merge tokens to strict V2."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]  # repo root (this tool lives in releases/v2/tools/)
TOKEN = re.compile(r"\{!([A-Za-z_][A-Za-z0-9_.]*)\}")
NAMESPACES = {"record", "rhcRule", "rhcSet", "rhcResult", "rhcRun"}
COMPUTED = {
    "failCount": "rhcResult.failedRecordCount",
    "totalCount": "rhcResult.totalRecordCount",
}
TARGETS = (
    ROOT / "force-app" / "main" / "default" / "customMetadata",
    ROOT / "force-app" / "main" / "default" / "classes",
    ROOT / "docs",
)
# The v1 docs are a frozen archive: they describe the v1 product, where flat
# `{!Field}` tokens were the real syntax. They must keep it, so they are never
# scanned or rewritten. (BLK-4: policy (a) — immutable v1 archive.)
ARCHIVE = ROOT / "docs" / "v1"
# V2 docs occasionally need to *show* a rejected legacy token as an example
# (e.g. the reason-codes catalog). A line carrying this marker is left as-is so
# the gate can't be re-broken by a legitimate documentation example.
ALLOW_MARKER = "legacy-token-ok"


def replacement(body: str) -> str | None:
    head = body.split(".", 1)[0]
    if head in NAMESPACES:
        return None
    return "{!" + COMPUTED.get(body, "record." + body) + "}"


def files():
    for target in TARGETS:
        for path in target.rglob("*"):
            if ARCHIVE == path or ARCHIVE in path.parents:
                continue  # frozen v1 archive keeps its original flat-token syntax
            if path.is_file() and path.suffix in {
                ".cls",
                ".md",
                ".xml",
                ".html",
                ".json",
                ".ndjson",
            }:
                yield path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("check", "apply"))
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    changes = []
    for path in files():
        original = path.read_text()

        def convert(match: re.Match[str]) -> str:
            new = replacement(match.group(1))
            if new is None:
                return match.group(0)
            line_start = original.rfind("\n", 0, match.start()) + 1
            line_end = original.find("\n", match.end())
            line = original[line_start : line_end if line_end != -1 else None]
            if ALLOW_MARKER in line:
                return match.group(0)  # documented example of a rejected token
            changes.append(
                {
                    "file": str(path.relative_to(ROOT)),
                    "old": match.group(0),
                    "new": new,
                }
            )
            return new

        updated = TOKEN.sub(convert, original)
        if args.mode == "apply" and updated != original:
            path.write_text(updated)
    if args.manifest:
        args.manifest.write_text(json.dumps({"changes": changes}, indent=2) + "\n")
    print(json.dumps({"mode": args.mode, "legacyTokenCount": len(changes)}))
    return 1 if args.mode == "check" and changes else 0


if __name__ == "__main__":
    raise SystemExit(main())
