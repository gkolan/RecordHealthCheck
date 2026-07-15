#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const docsRoot = path.join(root, "docs/v2");
const markdownFiles = [];
const narrativeHeaders = /^(notes?|description|purpose|detail)$/i;
const apiName = /\b[A-Za-z][A-Za-z0-9_]*__(?:c|mdt|e)\b/g;

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(entryPath);
    else if (entry.name.endsWith(".md")) markdownFiles.push(entryPath);
  }
}

function slug(heading) {
  return heading
    .toLowerCase()
    .trim()
    .replace(/<[^>]*>/g, "")
    .replace(/[`*~]/g, "")
    .replace(/\s+/g, "-")
    .replace(/[^\p{L}\p{N}_-]/gu, "");
}

function headings(markdown) {
  return new Set(
    [...markdown.matchAll(/^#{1,6}\s+(.+)$/gm)].map((match) => slug(match[1]))
  );
}

walk(docsRoot);
const failures = [];

const canonicalFieldAnchors = new Map();
for (const reference of [
  path.join(docsRoot, "metadata/rule-fields.md"),
  path.join(docsRoot, "metadata/check-set.md")
]) {
  const markdown = fs.readFileSync(reference, "utf8");
  for (const match of markdown.matchAll(/^###\s+.+\s+\(`([^`]+)`\)$/gm)) {
    canonicalFieldAnchors.set(
      `${reference}:${match[1]}`,
      slug(match[0].replace(/^###\s+/, ""))
    );
  }
}

for (const base of ["formula", "query", "compare-two-queries"]) {
  for (const suffix of ["example", "reference"]) {
    const expected = path.join(docsRoot, "checks", `${base}-${suffix}.md`);
    if (!fs.existsSync(expected))
      failures.push(`missing ${base} ${suffix} page`);
  }
}
for (const expected of ["apex/apex-example.md", "apex/apex-reference.md"]) {
  if (!fs.existsSync(path.join(docsRoot, expected)))
    failures.push(`missing ${expected}`);
}

for (const [objectName, referenceName] of [
  ["Record_Health_Check_Rule__mdt", "rule-fields.md"],
  ["Record_Health_Check_Set__mdt", "check-set.md"]
]) {
  const reference = path.join(docsRoot, "metadata", referenceName);
  const fieldsDirectory = path.join(
    root,
    "force-app/main/default/objects",
    objectName,
    "fields"
  );
  for (const fieldFile of fs.readdirSync(fieldsDirectory)) {
    if (!fieldFile.endsWith(".field-meta.xml")) continue;
    const api = fieldFile.replace(/\.field-meta\.xml$/, "");
    if (!canonicalFieldAnchors.has(`${reference}:${api}`))
      failures.push(`${referenceName}: missing shipped field ${api}`);
  }
}

const lifecycleReference = fs.readFileSync(
  path.join(docsRoot, "reference/lifecycle-events.md"),
  "utf8"
);
for (const eventName of [
  "Record_Health_Check_Set_Run__e",
  "Record_Health_Check_Rule_Result__e"
]) {
  const fieldsDirectory = path.join(
    root,
    "force-app/main/default/objects",
    eventName,
    "fields"
  );
  for (const fieldFile of fs.readdirSync(fieldsDirectory)) {
    if (!fieldFile.endsWith(".field-meta.xml")) continue;
    const api = fieldFile.replace(/\.field-meta\.xml$/, "");
    if (!lifecycleReference.includes(`\`${api}\``))
      failures.push(`lifecycle-events.md: missing shipped event field ${api}`);
  }
}

for (const file of markdownFiles) {
  const markdown = fs.readFileSync(file, "utf8");
  const relativeFile = path.relative(root, file);

  if (/-example\.md$/.test(file)) {
    const opening = markdown.split(/^##\s/m, 1)[0];
    if (
      !/> \[!NOTE\]/.test(opening) ||
      !/> \*\*In one line\*\*/.test(opening) ||
      !/> \*\*Reference\*\*/.test(opening)
    ) {
      failures.push(
        `${relativeFile}: example must open with In one line and Reference note`
      );
    }
  }

  if (/metadata\/(rule-fields|check-set)\.md$/.test(file)) {
    const sections = markdown.split(/^###\s+/m).slice(1);
    const requiredAttributes = [
      "Setup label",
      "API name",
      "Type",
      "Capacity",
      "Always required",
      "Default",
      "Used when",
      "Description",
      "Help text",
      "Allowed values"
    ];
    for (const section of sections) {
      const heading = section.split(/\r?\n/, 1)[0];
      for (const attribute of requiredAttributes) {
        if (
          !new RegExp(
            `^\\| ${attribute.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")} \\|`,
            "m"
          ).test(section)
        ) {
          failures.push(`${relativeFile}: ${heading} missing ${attribute}`);
        }
      }
      const type = section.match(/^\| Type \| ([^|]+) \|/m)?.[1]?.trim();
      if (
        /^(Picklist|Checkbox)$/.test(type || "") &&
        /^\| Examples? \|/m.test(section)
      ) {
        failures.push(
          `${relativeFile}: ${heading} duplicates allowed values as an example`
        );
      }
      if (type === "Picklist") {
        const allowed =
          section.match(/^\| Allowed values \| (.+) \|/m)?.[1] || "";
        if (!/\*\*.+\*\* — `.+`/.test(allowed))
          failures.push(
            `${relativeFile}: ${heading} picklist values need labels and API values`
          );
        const defaultValue =
          section.match(/^\| Default \| (.+) \|/m)?.[1] || "";
        if (
          defaultValue !== "No default" &&
          !/\*\*.+\*\* — `.+`/.test(defaultValue)
        )
          failures.push(
            `${relativeFile}: ${heading} picklist default needs label and API value`
          );
      }
      if (type === "Checkbox") {
        const allowed =
          section.match(/^\| Allowed values \| (.+) \|/m)?.[1] || "";
        if (
          !/\*\*Checked\*\* — `true`.*\*\*Unchecked\*\* — `false`/.test(allowed)
        )
          failures.push(
            `${relativeFile}: ${heading} checkbox values need labels and Boolean values`
          );
        const defaultValue =
          section.match(/^\| Default \| (.+) \|/m)?.[1] || "";
        if (!/\*\*(Checked|Unchecked)\*\* — `(true|false)`/.test(defaultValue))
          failures.push(
            `${relativeFile}: ${heading} checkbox default needs label and Boolean value`
          );
      }
    }
  }

  if (file !== path.join(docsRoot, "README.md")) {
    const hasNavigation =
      /^## (Related|Related documentation|Related guides|Next steps|See also)$/m.test(
        markdown
      );
    if (!hasNavigation)
      failures.push(`${relativeFile}: missing final navigation section`);
  }

  const lines = markdown.split(/\r?\n/);
  let inCodeFence = false;
  for (let index = 0; index < lines.length - 1; index += 1) {
    if (/^```/.test(lines[index])) {
      inCodeFence = !inCodeFence;
      continue;
    }
    if (!inCodeFence && /^#{2,6} .*: [a-z]/.test(lines[index])) {
      failures.push(
        `${relativeFile}:${index + 1}: capitalize the first word after a heading colon`
      );
    }
    if (
      !/^\|.*\|$/.test(lines[index]) ||
      !/^\|[ :|-]+\|$/.test(lines[index + 1])
    ) {
      continue;
    }
    const headers = lines[index]
      .split("|")
      .slice(1, -1)
      .map((cell) => cell.trim());

    const exampleApiColumn =
      headers[0] === "Setup field" && headers[1] === "API name" ? 1 : -1;
    if (headers.length > 6) {
      failures.push(
        `${relativeFile}:${index + 1}: table has more than six columns`
      );
    }
    const narrativeIndex = headers.findIndex((header) =>
      narrativeHeaders.test(header)
    );
    if (narrativeIndex !== -1 && narrativeIndex !== headers.length - 1) {
      failures.push(
        `${relativeFile}:${index + 1}: explanatory column must be last`
      );
    }

    let rowIndex = index + 2;
    while (rowIndex < lines.length && /^\|.*\|$/.test(lines[rowIndex])) {
      const cells = lines[rowIndex].split("|").slice(1, -1);
      if (exampleApiColumn !== -1) {
        const cell = cells[exampleApiColumn] || "";
        const api = cell.match(/`([^`]+)`/)?.[1];
        const link = cell.match(/\]\(([^)]+)\)/)?.[1];
        const [targetPart, anchor] = (link || "").split("#");
        const target = targetPart
          ? path.resolve(path.dirname(file), targetPart)
          : "";
        const canonical = api
          ? canonicalFieldAnchors.get(`${target}:${api}`)
          : null;
        if (!api || !link || !canonical) {
          failures.push(
            `${relativeFile}:${rowIndex + 1}: example API name must link to its canonical field section`
          );
        } else {
          if (anchor !== canonical) {
            failures.push(
              `${relativeFile}:${rowIndex + 1}: ${api} must link to #${canonical}`
            );
          }
        }
      }
      for (const cell of cells) {
        const visibleCell = cell.replace(/\]\([^)]+\)/g, "]");
        for (const match of visibleCell.matchAll(apiName)) {
          const before = visibleCell.slice(0, match.index);
          const isInsideCode = (before.match(/`/g) || []).length % 2 === 1;
          if (!isInsideCode) {
            failures.push(
              `${relativeFile}:${rowIndex + 1}: API name ${match[0]} must use backticks`
            );
          }
        }
      }
      rowIndex += 1;
    }
    index = rowIndex - 1;
  }

  for (const match of markdown.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
    const link = match[1];
    if (/^(https?:|mailto:)/.test(link)) continue;
    const [relativeTarget, anchor] = link.split("#");
    const target = path.resolve(
      path.dirname(file),
      relativeTarget || path.basename(file)
    );
    if (!fs.existsSync(target)) {
      failures.push(`${relativeFile}: missing local target ${link}`);
      continue;
    }
    if (anchor && target.endsWith(".md")) {
      const targetHeadings = headings(fs.readFileSync(target, "utf8"));
      if (!targetHeadings.has(anchor.toLowerCase())) {
        failures.push(`${relativeFile}: missing heading anchor ${link}`);
      }
    }
  }
}

if (failures.length > 0) {
  process.stderr.write(`${failures.join("\n")}\n`);
  process.exit(1);
}

process.stdout.write(
  `Verified ${markdownFiles.length} V2 Markdown files: tables, local targets, heading anchors, and navigation.\n`
);
