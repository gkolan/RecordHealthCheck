#!/usr/bin/env python3
"""Apply the approved v2 field contract from field-migration-before-after.md."""

from __future__ import annotations

import html
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]  # repo root (this tool lives in releases/v2/tools/)
SOURCE = ROOT / "releases" / "v2" / "field-migration-before-after.md"
NS = "http://soap.sforce.com/2006/04/metadata"
M = f"{{{NS}}}"
ET.register_namespace("", NS)


def clean(value: str) -> str:
    value = re.sub(r"<br\s*/?>", "\n", value)
    value = re.sub(r"<[^>]+>", "", value)
    return html.unescape(value).replace("&nbsp;", " ").strip()


def extract(cell: str, key: str) -> str | None:
    match = re.search(rf"\*\*{re.escape(key)}:\*\*\s*(.*?)(?=<br>|$)", cell)
    return clean(match.group(1)) if match else None


def child(root: ET.Element, name: str) -> ET.Element:
    found = root.find(M + name)
    if found is None:
        found = ET.SubElement(root, M + name)
    return found


def remove(root: ET.Element, name: str) -> None:
    found = root.find(M + name)
    if found is not None:
        root.remove(found)


def parse_rows() -> list[tuple[str, dict[str, object]]]:
    rows: list[tuple[str, dict[str, object]]] = []
    for line in SOURCE.read_text().splitlines():
        if not line.startswith("| **API:**"):
            continue
        cells = line.split("|")
        if len(cells) < 4:
            continue
        after = cells[2]
        api = extract(after, "API")
        if not api:
            continue
        api = api.replace("`", "").replace(" *(unchanged)*", "").strip()
        values = []
        for value, label in re.findall(
            r"•\s*`([^`]+)`\s*—\s*([^<|]+?)(?=<br>|$)", after
        ):
            label = clean(label)
            values.append(
                {
                    "api": value.strip(),
                    "label": re.sub(r"\s*\*?\(default\)\*?\s*$", "", label).strip(),
                    "default": "default" in label.lower(),
                }
            )
        rows.append(
            (
                "Record_Health_Check_Rule__mdt" if len(rows) < 40 else "Record_Health_Check_Set__mdt",
                {
                    "api": api,
                    "label": extract(after, "Label"),
                    "type": extract(after, "Type"),
                    "default": extract(after, "Default"),
                    "description": extract(after, "Description"),
                    "help": extract(after, "Help text"),
                    "values": values,
                },
            )
        )
    if len(rows) != 51:
        raise RuntimeError(f"Expected 51 contracts; parsed {len(rows)}")
    return rows


def apply_type(root: ET.Element, contract: dict[str, object]) -> None:
    type_text = str(contract["type"] or "")
    if type_text.startswith("Picklist"):
        child(root, "type").text = "Picklist"
        remove(root, "length")
        remove(root, "precision")
        remove(root, "scale")
    elif type_text.startswith("Checkbox"):
        child(root, "type").text = "Checkbox"
    elif type_text.startswith("Metadata Relationship"):
        child(root, "type").text = "MetadataRelationship"
    elif match := re.match(r"Number\((\d+),(\d+)\)", type_text):
        child(root, "type").text = "Number"
        child(root, "precision").text = match.group(1)
        child(root, "scale").text = match.group(2)
        remove(root, "length")
    elif match := re.match(r"Text\((\d+)\)", type_text):
        child(root, "type").text = "Text"
        child(root, "length").text = match.group(1)
    elif match := re.match(r"Long Text(?:\s*\((\d+)\))?", type_text):
        length = match.group(1)
        # Metadata API enforces a minimum of 256 for LongTextArea. The approved
        # "Long Text (255)" contract therefore maps to the only deployable
        # Salesforce representation with that capacity: Text(255).
        child(root, "type").text = "Text" if length == "255" else "LongTextArea"
        child(root, "length").text = length or "32768"
        if length == "255":
            remove(root, "visibleLines")


def apply_values(root: ET.Element, values: list[dict[str, object]]) -> None:
    if not values:
        return
    value_set = child(root, "valueSet")
    definition = value_set.find(M + "valueSetDefinition")
    if definition is None:
        definition = ET.SubElement(value_set, M + "valueSetDefinition")
    for existing in list(definition.findall(M + "value")):
        definition.remove(existing)
    for value in values:
        node = ET.SubElement(definition, M + "value")
        ET.SubElement(node, M + "fullName").text = str(value["api"])
        ET.SubElement(node, M + "default").text = str(bool(value["default"])).lower()
        ET.SubElement(node, M + "label").text = str(value["label"])
    sorted_node = definition.find(M + "sorted")
    if sorted_node is None:
        sorted_node = ET.SubElement(definition, M + "sorted")
    sorted_node.text = "false"


def main() -> None:
    for object_name, contract in parse_rows():
        api = str(contract["api"])
        path = ROOT / "force-app/main/default/objects" / object_name / "fields" / f"{api}.field-meta.xml"
        tree = ET.parse(path)
        root = tree.getroot()
        child(root, "fullName").text = api
        child(root, "label").text = str(contract["label"])
        child(root, "description").text = str(contract["description"])
        child(root, "inlineHelpText").text = str(contract["help"])
        apply_type(root, contract)
        apply_values(root, contract["values"])  # type: ignore[arg-type]

        default = str(contract["default"] or "")
        required = "required" in default.lower()
        if root.find(M + "type") is not None and root.find(M + "type").text != "Checkbox":
            child(root, "required").text = str(required).lower()
        numeric = re.fullmatch(r"\s*(\d+)\s*", default)
        if numeric:
            child(root, "defaultValue").text = numeric.group(1)
        elif root.find(M + "type") is not None and root.find(M + "type").text == "Checkbox":
            if "true" in default.lower() or "false" in default.lower():
                child(root, "defaultValue").text = "true" if "true" in default.lower() else "false"

        tree.write(path, encoding="UTF-8", xml_declaration=True)


if __name__ == "__main__":
    main()
