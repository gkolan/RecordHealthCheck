import fs from "node:fs";
import path from "node:path";

const classesDirectory = path.resolve("force-app/main/default/classes");
const factoryFile = "RecordHealthCheckTestDataFactory.cls";
const directDmlPattern =
  /\b(?:insert|upsert)\s+|\bDatabase\.(?:insert|upsert)\s*\(/g;
const failures = [];

for (const fileName of fs.readdirSync(classesDirectory).sort()) {
  if (!fileName.endsWith("Test.cls") || fileName === factoryFile) continue;

  const source = fs.readFileSync(path.join(classesDirectory, fileName), "utf8");
  for (const match of source.matchAll(directDmlPattern)) {
    const line = source.slice(0, match.index).split("\n").length;
    failures.push(
      `${fileName}:${line}: create persisted test records through ${factoryFile}`
    );
  }
}

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  `Verified Apex tests: persisted record creation is centralized in ${factoryFile}.`
);
