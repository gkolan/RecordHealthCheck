#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const coreDirectory = path.join(root, "force-app/main/default/customMetadata");
const fixtureDirectory = path.join(
  root,
  "integration-tests/main/default/customMetadata"
);
const examplePattern =
  /^Record_Health_Check_(?:Set|Rule)__mdt\.Example_.+\.md-meta\.xml$/;

const files = (directory) =>
  fs.existsSync(directory)
    ? fs.readdirSync(directory).filter((name) => name.endsWith(".md-meta.xml"))
    : [];

const coreRecords = files(coreDirectory);
const fixtureExamples = files(fixtureDirectory).filter((name) =>
  examplePattern.test(name)
);
const failures = [];

if (coreRecords.length > 0) {
  failures.push(
    `force-app must contain no Custom Metadata records; found: ${coreRecords.sort().join(", ")}`
  );
}

if (fixtureExamples.length !== 25) {
  failures.push(
    `integration-tests must retain 25 optional core-example fixtures; found ${fixtureExamples.length}`
  );
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  `Verified package boundary: 0 core Custom Metadata records and ${fixtureExamples.length} retained example fixtures.`
);
