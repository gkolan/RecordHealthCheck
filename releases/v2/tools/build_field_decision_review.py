from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]  # repo root (this tool lives in releases/v2/tools/)
OUT = ROOT / "docs/reviews/custom-metadata-field-assistant-comparison.md"
NS = {"m": "http://soap.sforce.com/2006/04/metadata"}


def clean(s):
    return re.sub(r"\*+", "", s.strip()).replace("→", "→")


def cells(line):
    return [clean(x) for x in line.strip().strip("|").split("|")]


def md_tables(text):
    lines = text.splitlines()
    tables = []
    i = 0
    while i < len(lines) - 1:
        if lines[i].lstrip().startswith("|") and lines[i + 1].lstrip().startswith("|") and "---" in lines[i + 1]:
            header = cells(lines[i])
            rows = []
            i += 2
            while i < len(lines) and lines[i].lstrip().startswith("|"):
                row = cells(lines[i])
                if len(row) == len(header):
                    rows.append(dict(zip(header, row)))
                i += 1
            tables.append((header, rows))
            continue
        i += 1
    return tables


def xml_text(root, name, default="—"):
    node = root.find(f"m:{name}", NS)
    return node.text.strip() if node is not None and node.text else default


def current_fields():
    result = []
    base = ROOT / "force-app/main/default/objects"
    for obj in sorted(base.glob("Record_Health_Check_*__mdt")):
        for path in sorted((obj / "fields").glob("*.field-meta.xml")):
            root = ET.parse(path).getroot()
            vals = []
            for val in root.findall("m:valueSet/m:valueSetDefinition/m:value", NS):
                api = xml_text(val, "fullName", "")
                label = xml_text(val, "label", api)
                is_default = xml_text(val, "default", "false") == "true"
                vals.append((api, label, is_default))
            result.append({
                "object": obj.name.replace("__mdt", "").replace("_", " "),
                "api": path.name.replace(".field-meta.xml", ""),
                "label": xml_text(root, "label"),
                "type": xml_text(root, "type"),
                "required": xml_text(root, "required", "false"),
                "default": xml_text(root, "defaultValue", "None specified"),
                "values": vals,
            })
    return result


def row_containing(tables, api, required_headers=()):
    matches = []
    for header, rows in tables:
        if required_headers and not all(any(x.lower() in h.lower() for h in header) for x in required_headers):
            continue
        for row in rows:
            if any(f"`{api}`" in value for value in row.values()):
                matches.append((header, row))
    return matches


def explicit_reason(text, api):
    token = f"`{api}`"
    lines = text.splitlines()
    candidates = []
    for i, line in enumerate(lines):
        if token not in line or line.lstrip().startswith("|"):
            continue
        paragraph = clean(re.sub(r"^[#>\-\s]+", "", line))
        j = i + 1
        while j < len(lines) and lines[j].strip() and not lines[j].startswith("#") and not lines[j].lstrip().startswith("|"):
            paragraph += " " + clean(lines[j])
            j += 1
        if (35 <= len(paragraph) <= 700 and not re.match(r"^\d+(?:\.\d+)*(?:\.|)\s", paragraph)
                and not ("→" in paragraph and len(paragraph) < 120)):
            candidates.append(paragraph)
    return min(candidates, key=len) if candidates else None


def normalize_api(value, current):
    value = clean(value).replace("(keep)", "").strip()
    if not value or value in {"—", "*(keep)*", "(keep)"} or "keep field" in value.lower():
        return current
    if "Remove; use" in value:
        return value
    found = re.findall(r"`([^`]+)`", value)
    return found[-1] if found else value


def claude_proposals(fields):
    text = (ROOT / "recycle-bin/claude-custom-metadata-fields-proposal.md").read_text()
    tables = md_tables(text)
    result = {}
    for f in fields:
        api = f["api"]
        proposal = {"api": api, "label": f["label"], "type_default": "No type/default change stated", "reason": None}
        matches = row_containing(tables, api)
        # Prefer the main field-by-field table with Current/Proposed columns.
        for header, row in matches:
            if "Current API" in header and any("Proposed API" in h for h in header):
                p_api = next((row[h] for h in header if "Proposed API" in h), api)
                p_label = next((row[h] for h in header if "Proposed Label" in h), f["label"])
                proposal["api"] = normalize_api(p_api, api)
                proposal["label"] = clean(p_label).replace("(keep)", "").strip()
                if "Type" in row:
                    proposal["type_default"] = row["Type"] + " / default not stated here"
                if "Reason" in row:
                    proposal["reason"] = row["Reason"]
                break
        proposal["reason"] = explicit_reason(text, api) or proposal["reason"]
        result[api] = proposal

    # Claude's Part C explicitly overrides earlier sections.
    result["CheckMethod__c"].update(api="EvaluationType__c", label="Evaluation Type", reason="Final amendment aligns the metadata field with the engine and extension contract term evaluatorType.")
    result["Severity__c"]["reason"] = "Keep the field, but replace severity value Error with Critical (or High) so Error remains reserved for the system ERROR status."
    result["WhenZeroRows__c"]["type_default"] = "Picklist / no default; require an explicit choice"
    result["PrimaryActionLabel__c"]["label"] = "Action Label"
    result["PrimaryActionUrl__c"]["label"] = "Action URL"
    return result


def cursor_proposals(fields):
    text = (ROOT / "recycle-bin/cursor-custom-metadata-fields-proposal.md").read_text()
    tables = md_tables(text)
    result = {}
    # Final master mapping is authoritative for API names.
    master = {}
    for header, rows in tables:
        if header == ["Current API", "Proposed API"]:
            for row in rows:
                old = re.findall(r"`([^`]+)`", row["Current API"])
                if old:
                    master[old[0]] = normalize_api(row["Proposed API"], old[0])
    lines = text.splitlines()
    for f in fields:
        api = f["api"]
        p_api = master.get(api, api)
        label = f["label"]
        td = "No type/default change stated"
        reason = None
        # Use the dedicated field subsection when present.
        starts = [i for i, line in enumerate(lines) if line.startswith("####") and f"`{api}`" in line]
        if starts:
            i = starts[-1]
            block = lines[i + 1:]
            end = next((j for j, line in enumerate(block) if line.startswith("###")), len(block))
            block = block[:end]
            for line in block:
                if line.lstrip().startswith("|"):
                    cs = cells(line)
                    if len(cs) == 2:
                        key, value = cs
                        kl = key.lower()
                        if "label" == kl:
                            label = value
                        elif "default" in kl:
                            td = "Default: " + value
                        elif kl.startswith("why"):
                            reason = value
        # Grouped mapping rows can provide a clean proposed label.
        for header, row in row_containing(tables, api):
            if "Current" in header and "Proposed API" in header and "Proposed label" in header:
                label = row["Proposed label"]
        reason = reason or explicit_reason(text, api)
        result[api] = {"api": p_api, "label": label, "type_default": td, "reason": reason}
    return result


def codex_proposals(fields):
    text = (ROOT / "recycle-bin/codex-custom-metadata-fields-proposal.md").read_text()
    tables = md_tables(text)
    result = {}
    for f in fields:
        api = f["api"]
        proposal = {"api": api, "label": f["label"], "type_default": "No type/default change stated", "reason": None}
        candidates = []
        for header, row in row_containing(tables, api):
            if "Current API name" in header and "Proposed API name" in header:
                candidates.append(row)
        if candidates:
            row = candidates[-1]
            proposal.update(
                api=normalize_api(row["Proposed API name"], api),
                label=row["Proposed label"],
                type_default=row["Proposed type / default"],
                reason=row["Why change"],
            )
        result[api] = proposal
    # Later authoritative simplified table overrides the earlier matrix.
    for header, rows in tables:
        if header[:2] == ["Current API", "Current label"] and "Final proposed API" in header:
            for row in rows:
                old = re.findall(r"`([^`]+)`", row["Current API"])
                if old and old[0] in result:
                    result[old[0]].update(
                        api=normalize_api(row["Final proposed API"], old[0]),
                        label=row["Final proposed label"],
                        type_default=row["Type/default"],
                        reason=row["Reason"],
                    )
    return result


def verdict(current, proposal):
    if proposal["api"].lower().startswith("remove"):
        return "REMOVE"
    api_same = proposal["api"] == current["api"]
    label_same = clean(proposal["label"]).lower() == clean(current["label"]).lower()
    if api_same and label_same:
        return "KEEP"
    if api_same:
        return "CHANGE LABEL/BEHAVIOR"
    return "RENAME"


def safe_reason(name, current, proposal):
    if proposal["reason"]:
        return proposal["reason"]
    v = verdict(current, proposal)
    if v == "KEEP":
        return f"No change proposed. {name} retains the current API name and label."
    return f"{name} proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it."


def esc(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


def main():
    fields = current_fields()
    proposals = {
        "Claude": claude_proposals(fields),
        "Cursor": cursor_proposals(fields),
        "Codex": codex_proposals(fields),
    }
    out = [
        "# Record Health Check field proposal decision review",
        "",
        "This document compares the **final recommendation** from Claude, Cursor, and Codex for every current custom metadata field. It is designed for printing and decision-making—not as a transcript of the source proposals.",
        "",
        "## Reading rules",
        "",
        "- **KEEP** means the assistant proposes no API-name or label change. Any separate value/default change is called out explicitly.",
        "- **RENAME** means the API name changes.",
        "- **CHANGE LABEL/BEHAVIOR** means the API stays but the label, default, type, or picklist contract changes.",
        "- **REMOVE** means the field is replaced by a standard field or eliminated.",
        "- Later amendments in a proposal override its earlier tables.",
        "- If a proposal does not give a field-specific reason, this document says so explicitly rather than guessing.",
        "",
        "## Suggested decision test",
        "",
        "Choose a change only if it makes the field clearer in both Salesforce Setup and code, remains valid outside the current UI, and does not introduce an unsafe default or unnecessary migration cost.",
        "",
        "---",
    ]
    obj = None
    n = 0
    for f in fields:
        if f["object"] != obj:
            obj = f["object"]
            out += ["", f"# {obj}", ""]
        n += 1
        out += ["", f"## {n}. {f['label']} — `{f['api']}`", ""]
        values = "; ".join(f"`{a}` = {l}" + (" (default)" if d else "") for a, l, d in f["values"]) or "Not a picklist"
        out += [
            "### Current definition",
            "",
            "| API name | Label | Type | Required | Default |",
            "|---|---|---|---:|---|",
            f"| `{f['api']}` | {esc(f['label'])} | {f['type']} | {f['required']} | `{f['default']}` |",
            "",
        ]
        if f["values"]:
            out += [f"**Current picklist contract:** {values}", ""]
        out += [
            "### Proposal comparison",
            "",
            "| Source | Decision | Proposed API name | Proposed label | Type/default position |",
            "|---|---|---|---|---|",
        ]
        for name in ("Claude", "Cursor", "Codex"):
            p = proposals[name][f["api"]]
            out.append(f"| **{name}** | **{verdict(f, p)}** | `{esc(p['api'])}` | {esc(p['label'])} | {esc(p['type_default'])} |")
        out += ["", "### Reasoning that matters", ""]
        for name in ("Claude", "Cursor", "Codex"):
            p = proposals[name][f["api"]]
            out.append(f"- **{name} — {verdict(f, p)}:** {safe_reason(name, f, p)}")
        decisions = [verdict(f, proposals[name][f["api"]]) for name in proposals]
        same_api = len({proposals[name][f["api"]]["api"] for name in proposals}) == 1
        if all(x == "KEEP" for x in decisions):
            assessment = "All three assistants keep the API name and label. Only adopt a change if a value/default note above requires it."
        elif same_api:
            assessment = "The assistants converge on the same API outcome; compare label and behavioral details before accepting it."
        else:
            assessment = "The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions."
        out += [
            "",
            f"**Decision focus:** {assessment}",
            "",
            "**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision",
            "",
            "**Notes:** ____________________________________________________________________________",
            "",
            "---",
        ]
    OUT.write_text("\n".join(out) + "\n")
    print(OUT)


if __name__ == "__main__":
    main()
