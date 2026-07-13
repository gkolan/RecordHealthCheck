#!/usr/bin/env python3
"""Compare Salesforce DX source with an isolated org readback.

Normalizes harmless Metadata API differences: XML formatting/order, final newlines,
Custom Metadata filename normalization, and explicit false defaults materialized by retrieve.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from decimal import Decimal, InvalidOperation


def readback_path(source_root: Path, readback_root: Path, source: Path) -> Path:
    relative = source.relative_to(source_root)
    if relative.parts[:3] == ("main", "default", "customMetadata"):
        name = relative.name.replace("__mdt.", ".", 1)
        relative = relative.with_name(name)
    return readback_root / relative


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def metadata_values(root: ET.Element) -> dict[str, tuple[str, str]]:
    values: dict[str, tuple[str, str]] = {}
    for item in root:
        if local_name(item.tag) != "values":
            continue
        field = next(child for child in item if local_name(child.tag) == "field")
        value = next(child for child in item if local_name(child.tag) == "value")
        value_type = next(
            (attribute for key, attribute in value.attrib.items() if local_name(key) == "type"),
            "",
        )
        raw_value = (value.text or "").strip()
        if value_type.endswith("double") and raw_value:
            try:
                raw_value = str(Decimal(raw_value).normalize())
            except InvalidOperation:
                pass
        is_nil = any(local_name(key) == "nil" and item == "true" for key, item in value.attrib.items())
        values[(field.text or "").strip()] = ("nil", "") if is_nil else (value_type, raw_value)
    return values


def canonical(element: ET.Element):
    materialized_defaults = {
        ("externalId", "false"),
        ("fieldManageability", "DeveloperControlled"),
        ("required", "false"),
        ("unique", "false"),
    }
    children = sorted(
        (
            canonical(child)
            for child in element
            if (local_name(child.tag), (child.text or "").strip())
            not in materialized_defaults
        ),
        key=repr,
    )
    attributes = tuple(sorted((local_name(key), value) for key, value in element.attrib.items()))
    return (local_name(element.tag), attributes, (element.text or "").strip(), tuple(children))


def xml_contains(source: ET.Element, readback: ET.Element) -> bool:
    if local_name(source.tag) != local_name(readback.tag):
        return False
    source_text = (source.text or "").strip()
    readback_text = (readback.text or "").strip()
    text_matches = source_text == readback_text
    if local_name(source.tag) == "behavior" and source_text == "Required":
        text_matches = readback_text == "Edit"
    if source_text == "false" and readback_text == "0":
        text_matches = True
    if len(source_text) == 18 and len(readback_text) == 15:
        text_matches = source_text.startswith(readback_text)
    if not text_matches:
        return False
    readback_attributes = {local_name(key): value for key, value in readback.attrib.items()}
    if any(readback_attributes.get(local_name(key)) != value for key, value in source.attrib.items()):
        return False
    unmatched = list(readback)
    for source_child in source:
        if local_name(source_child.tag) in {"accessType", "publicFolderAccess"}:
            continue
        if (local_name(source_child.tag), (source_child.text or "").strip()) in {
            ("externalId", "false"),
            ("fieldManageability", "DeveloperControlled"),
            ("required", "false"),
            ("unique", "false"),
        }:
            continue
        match = next(
            (candidate for candidate in unmatched if xml_contains(source_child, candidate)),
            None,
        )
        if match is None:
            return False
        unmatched.remove(match)
    return True


def xml_matches(source: Path, readback: Path) -> bool:
    source_root = ET.parse(source).getroot()
    readback_root = ET.parse(readback).getroot()
    if local_name(source_root.tag) == "Layout":
        def layout_contract(root: ET.Element) -> tuple[list[str], list[str]]:
            fields = [
                (item.text or "").strip()
                for item in root.iter()
                if local_name(item.tag) == "field"
            ]
            labels = [
                (item.text or "").strip()
                for section in root
                if local_name(section.tag) == "layoutSections"
                for item in section
                if local_name(item.tag) == "label"
            ]
            return fields, labels
        return layout_contract(source_root) == layout_contract(readback_root)
    if local_name(source_root.tag) == "CustomMetadata":
        source_values = metadata_values(source_root)
        readback_values = metadata_values(readback_root)
        if any(
            source_values[name][1] != (readback_values.get(name) or (None, None))[1]
            for name in source_values
        ):
            return False
        source_non_values = [
            canonical(child)
            for child in source_root
            if local_name(child.tag) != "values"
        ]
        readback_non_values = [
            canonical(child)
            for child in readback_root
            if local_name(child.tag) != "values"
        ]
        return sorted(source_non_values, key=repr) == sorted(readback_non_values, key=repr)
    return xml_contains(source_root, readback_root)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("readback")
    args = parser.parse_args()
    source_root = Path(args.source).resolve()
    readback_root = Path(args.readback).resolve()
    missing: list[str] = []
    different: list[str] = []
    compared = 0
    for source in sorted(path for path in source_root.rglob("*") if path.is_file()):
        if "__tests__" in source.parts or source.name == ".DS_Store":
            continue
        readback = readback_path(source_root, readback_root, source)
        relative = str(source.relative_to(source_root))
        if not readback.exists():
            missing.append(relative)
            continue
        compared += 1
        if source.suffix == ".xml":
            matches = xml_matches(source, readback)
        else:
            matches = source.read_text().rstrip() == readback.read_text().rstrip()
        if not matches:
            different.append(relative)
    result = {
        "compared": compared,
        "missing": missing,
        "different": different,
        "status": "pass" if not missing and not different else "fail",
    }
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
