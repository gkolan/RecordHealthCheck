import fs from "node:fs";
import path from "node:path";

const roots = [
  "force-app/main/default/classes",
  "integration-tests/main/default/classes",
  "scripts/templates"
];

function classify(source) {
  const declarations = [
    ...source.matchAll(
      /\b(global|public|private)\s+(?:(with|without|inherited)\s+sharing\s+)?class\s+(\w+)[^{]*\bimplements\s+RecordHealthCheckRule\b/g
    )
  ];
  return declarations.map((match) => ({
    visibility: match[1],
    sharing: match[2] ?? "omitted",
    name: match[3]
  }));
}

if (process.argv.includes("--self-test")) {
  const hostile = classify(
    "global without sharing class HostileRule implements RecordHealthCheckRule {}"
  );
  if (hostile[0]?.sharing !== "without") {
    throw new Error(
      "Plugin sharing scanner failed its without-sharing fixture."
    );
  }
  console.log(
    "Plugin sharing scanner rejected the synthetic without-sharing fixture."
  );
  process.exit(0);
}

const findings = [];
for (const root of roots) {
  for (const file of fs
    .readdirSync(root)
    .filter((name) => name.endsWith(".cls"))) {
    const relative = path.join(root, file);
    const source = fs.readFileSync(relative, "utf8");
    if (/@IsTest\b/i.test(source)) continue;
    for (const declaration of classify(source)) {
      if (declaration.visibility !== "global") continue;
      if (declaration.sharing === "without") {
        findings.push(
          `${relative}: ${declaration.name} must not declare without sharing.`
        );
      } else if (declaration.sharing !== "with") {
        findings.push(
          `${relative}: ${declaration.name} must explicitly declare with sharing; ${declaration.sharing} sharing requires review.`
        );
      }
    }
  }
}

if (findings.length) {
  console.error(findings.join("\n"));
  process.exit(1);
}
console.log(
  "Verified all global RecordHealthCheckRule implementations declare with sharing."
);
