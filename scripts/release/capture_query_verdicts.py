#!/usr/bin/env python3
"""Capture normalized verdicts for every query-bearing Rule in a scratch org.

The committed bulk-query inventory is the coverage contract. This tool reads the
exhaustive smoke results persisted by the integration-test harness, keeps only
verdict fields that T4-T6 must preserve, and fails if any inventoried Rule is
missing. Run it before and after the evaluator rewrite and diff the JSON files.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
INVENTORY = ROOT / "scripts/release/generated/bulk-query-shape-inventory.json"
DEFAULT_OUTPUT = ROOT / "scripts/release/generated/query-verdict-baseline.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-org", required=True, help="Scratch-org alias or username")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--namespace",
        default="",
        help="Optional namespace prefix used by the target org, without trailing separators",
    )
    parser.add_argument(
        "--compare-to",
        type=Path,
        help="Fail when the captured normalized verdicts differ from this baseline",
    )
    return parser.parse_args()


def query_smoke_results(target_org: str, namespace: str) -> list[dict[str, object]]:
    prefix = f"{namespace}__" if namespace else ""
    event_field = f"{prefix}EventId__c"
    verdict_fields = [
        f"{prefix}RuleName__c",
        f"{prefix}Status__c",
        f"{prefix}ReasonCode__c",
        f"{prefix}Threw__c",
        f"{prefix}ExceptionType__c",
    ]
    export_object = f"{prefix}RHC_Event_Export__c"
    soql = (
        f"SELECT {event_field}, {', '.join(verdict_fields)} FROM {export_object} "
        f"WHERE {event_field} LIKE 'RULE:%' ORDER BY {event_field}"
    )
    command = [
        "sf",
        "data",
        "query",
        "--target-org",
        target_org,
        "--query",
        soql,
        "--json",
    ]
    completed = subprocess.run(command, check=False, capture_output=True, text=True)
    if completed.returncode != 0:
        sys.stderr.write(completed.stderr)
        sys.stderr.write(completed.stdout)
        raise SystemExit(completed.returncode)

    response = json.loads(completed.stdout)
    if response.get("status") != 0:
        raise SystemExit(json.dumps(response, indent=2))
    return response["result"]["records"]


def normalized_result(payload: dict[str, object]) -> dict[str, object]:
    result: dict[str, object] = {"rule": payload["name"]}
    for key in ("status", "reasonCode", "threw", "exceptionType"):
        if payload.get(key) is not None and not (key == "threw" and payload[key] is False):
            result[key] = payload[key]
    return result


def main() -> int:
    args = parse_args()
    comparison_baseline = (
        json.loads(args.compare_to.read_text())
        if args.compare_to is not None
        else None
    )
    inventory_bytes = INVENTORY.read_bytes()
    inventory = json.loads(inventory_bytes)

    fields_by_rule: dict[str, list[str]] = {}
    for item in inventory:
        fields_by_rule.setdefault(item["rule"], []).append(item["field"])

    smoke_by_rule: dict[str, dict[str, object]] = {}
    prefix = f"{args.namespace}__" if args.namespace else ""
    smoke_rows = query_smoke_results(args.target_org, args.namespace)
    for row in smoke_rows:
        rule_name = str(row[f"{prefix}RuleName__c"]).split("__", 1)[-1]
        payload: dict[str, object] = {"name": rule_name}
        for key, field in (
            ("status", "Status__c"),
            ("reasonCode", "ReasonCode__c"),
            ("threw", "Threw__c"),
            ("exceptionType", "ExceptionType__c"),
        ):
            payload[key] = row.get(f"{prefix}{field}")
        smoke_by_rule[rule_name] = payload

    expected_rules = set(fields_by_rule)
    missing = sorted(expected_rules - set(smoke_by_rule))
    if missing:
        print(
            "Missing exhaustive-smoke results for query-bearing Rules: "
            + ", ".join(missing),
            file=sys.stderr,
        )
        return 1

    results = []
    for rule in sorted(expected_rules):
        result = normalized_result(smoke_by_rule[rule])
        result["queryFields"] = sorted(fields_by_rule[rule])
        results.append(result)

    output = {
        "schemaVersion": 1,
        "inventorySha256": hashlib.sha256(inventory_bytes).hexdigest(),
        "templateCount": len(inventory),
        "ruleCount": len(expected_rules),
        "results": results,
    }
    if args.compare_to is not None:
        if output != comparison_baseline:
            print(
                f"Verdict parity failed against {args.compare_to}: captured output differs.",
                file=sys.stderr,
            )
            return 1
        print(f"Verdict parity passed against {args.compare_to}")
    if args.compare_to is None or args.output.resolve() != args.compare_to.resolve():
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
        try:
            display_path = args.output.relative_to(ROOT)
        except ValueError:
            display_path = args.output
        print(
            f"Captured {len(expected_rules)} Rule verdicts covering "
            f"{len(inventory)} query templates to {display_path}"
        )
    else:
        print(
            f"Verified {len(expected_rules)} Rule verdicts covering "
            f"{len(inventory)} query templates without modifying the baseline."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
