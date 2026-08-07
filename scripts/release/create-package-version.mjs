#!/usr/bin/env node

import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";
import { readPackageReleases } from "../lib/package-releases.mjs";
import { run, runJson } from "../lib/run.mjs";

const { values } = parseArgs({
  options: {
    "dev-hub": { type: "string", default: process.env.DEV_HUB_ALIAS ?? "" },
    "version-number": { type: "string" },
    wait: { type: "string", default: "120" }
  }
});

if (!values["dev-hub"]) {
  console.error(
    "Pass --dev-hub (or set DEV_HUB_ALIAS). Example: npm run package:create -- --dev-hub my-dev-hub"
  );
  process.exit(1);
}

const releases = readPackageReleases();
// Only pass --version-number when the caller asks for a specific line. A
// hardcoded default silently overrides packageDirectories[].versionNumber in
// sfdx-project.json, so a stale constant here builds the wrong version line
// (2.0.0.NEXT long after the project moved to 2.0.1).
const versionNumber = values["version-number"];

console.log(
  `Creating package version for ${releases.packageName} (${releases.package2Id}) from force-app` +
    `${versionNumber ? ` at ${versionNumber}` : " (version from sfdx-project.json)"}...`
);

run(
  "sf",
  [
    "package",
    "version",
    "create",
    "--package",
    releases.package2Id,
    "--path",
    "force-app",
    "--definition-file",
    "config/project-scratch-def.json",
    "--version-number",
    versionNumber,
    "--code-coverage",
    "--installation-key-bypass",
    "--wait",
    values.wait,
    "--target-dev-hub",
    values["dev-hub"]
  ],
  { cwd: paths.packageRoot }
);

const versions = runJson(
  "sf",
  [
    "package",
    "version",
    "list",
    "--packages",
    releases.package2Id,
    "--target-dev-hub",
    values["dev-hub"],
    "--created-last-days",
    "1",
    "--order-by",
    "CreatedDate",
    "--concise"
  ],
  { cwd: paths.packageRoot }
);

const records = versions.result ?? [];
const latest = records[records.length - 1];
if (!latest?.SubscriberPackageVersionId) {
  console.error("Package version create finished but no new 04t was found.");
  process.exit(1);
}

console.log("");
console.log("Candidate package version created.");
console.log(`Version: ${latest.Version ?? latest.version ?? "unknown"}`);
console.log(`04t: ${latest.SubscriberPackageVersionId}`);
console.log("");
console.log(
  "Next: npm run package:verify -- --package " +
    latest.SubscriberPackageVersionId
);
console.log(
  "Do not update config/package-releases.json until clean install, upgrade, and promote gates pass."
);
