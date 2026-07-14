#!/usr/bin/env python3
"""Generate docs/v2/reference/field-size-registry.md from shipped CMDT XML.

Run from the repository root with:
  python3 releases/v2/tools/generate_field_size_registry.py

The script reads metadata and rewrites only the generated registry. It has no
network dependencies and is idempotent.
"""

from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
OBJECTS = ROOT / "force-app/main/default/objects"
OUTPUT = ROOT / "docs/v2/reference/field-size-registry.md"
NS = {"m": "http://soap.sforce.com/2006/04/metadata"}


def text(root, name, default=""):
    node = root.find(f"m:{name}", NS)
    return node.text.strip() if node is not None and node.text else default


def behavior(field):
    if field == "ActionUrl__c":
        return ("2,000", "Error; resolved URL is sanitized and rejected when too long")
    if field in {
        "CardSubtitle__c", "CheckDescription__c", "FailureMessage__c",
        "UnableToEvaluateMessage__c", "FixMessage__c", "ActionLabel__c",
        "DisplayFoundText__c", "DisplayExpectedText__c",
    }:
        return ("2,048", "Error; runtime never silently truncates resolved text")
    return ("N/A", "Metadata API enforces the stored value; no runtime truncation")


rows = []
for object_name in ("Record_Health_Check_Set__mdt", "Record_Health_Check_Rule__mdt"):
    for path in sorted((OBJECTS / object_name / "fields").glob("*.field-meta.xml")):
        root = ET.parse(path).getroot()
        field = text(root, "fullName")
        field_type = text(root, "type")
        length = text(root, "length")
        precision = text(root, "precision")
        scale = text(root, "scale")
        if length:
            maximum = length
        elif precision:
            maximum = f"{precision} digits, {scale or '0'} decimal places"
        elif field_type == "Checkbox":
            maximum = "true/false"
        elif field_type == "Picklist":
            maximum = "Restricted value set"
        elif field_type == "MetadataRelationship":
            maximum = "Metadata relationship"
        else:
            maximum = "Platform-defined"
        resolved, handling = behavior(field)
        rows.append((object_name, field, field_type, maximum, resolved, handling))

lines = [
    "# Record Health Check field-size registry",
    "",
    "> Generated from shipped metadata by `releases/v2/tools/generate_field_size_registry.py`. Do not edit by hand.",
    "",
    "Character limits are not byte guarantees. Post-resolution limits apply after merge-token resolution; fields marked N/A are never resolved.",
    "",
    "| Custom metadata type | Field | Storage type | Stored maximum | Post-resolution maximum | Overflow behavior |",
    "| --- | --- | --- | ---: | ---: | --- |",
]
for row in rows:
    lines.append("| " + " | ".join(row) + " |")
lines += ["", f"Total fields: **{len(rows)}**.", ""]
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text("\n".join(lines), encoding="utf-8")
print(f"Wrote {OUTPUT.relative_to(ROOT)} with {len(rows)} fields")
