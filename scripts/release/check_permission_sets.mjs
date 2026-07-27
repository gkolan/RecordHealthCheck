import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const DEFAULT = path.join(ROOT, "force-app", "main", "default");
const PERMISSION_SETS = path.join(DEFAULT, "permissionsets");
const MAX_SALESFORCE_DESCRIPTION = 255;
const PROJECT_DESCRIPTION_BUDGET = 200;

const expected = {
  Record_Health_Check_Admin: {
    classes: [
      "RecordHealthCheck",
      "RecordHealthCheckController",
      "RecordHealthCheckMetadataValidator",
      "RecordHealthCheckRunRuleFlowAction",
      "RecordHealthCheckRunSetFlowAction",
      "RecordHealthCheckSetPicklist"
    ],
    objects: [
      "Record_Health_Check_Rule_Result__e",
      "Record_Health_Check_Set_Run__e"
    ],
    customPermissions: ["Record_Health_Check_View_Diagnostics"]
  },
  Record_Health_Check_User: {
    classes: [
      "RecordHealthCheck",
      "RecordHealthCheckController",
      "RecordHealthCheckRunRuleFlowAction",
      "RecordHealthCheckRunSetFlowAction"
    ],
    objects: [
      "Record_Health_Check_Rule_Result__e",
      "Record_Health_Check_Set_Run__e"
    ],
    customPermissions: []
  }
};

const values = (xml, tag) =>
  [...xml.matchAll(new RegExp(`<${tag}>([^<]+)<\\/${tag}>`, "g"))].map(
    (match) => match[1].trim()
  );
const sorted = (items) => [...items].sort();
const same = (left, right) =>
  JSON.stringify(sorted(left)) === JSON.stringify(sorted(right));
const errors = [];

for (const [name, contract] of Object.entries(expected)) {
  const file = path.join(PERMISSION_SETS, `${name}.permissionset-meta.xml`);
  if (!fs.existsSync(file)) {
    errors.push(`Missing permission set: ${name}`);
    continue;
  }
  const xml = fs.readFileSync(file, "utf8");
  const description =
    xml.match(/<description\s*>([\s\S]*?)<\/description>/)?.[1].trim() ?? "";
  if (description.length > MAX_SALESFORCE_DESCRIPTION) {
    errors.push(
      `${name} description exceeds Salesforce's ${MAX_SALESFORCE_DESCRIPTION}-character limit (${description.length}).`
    );
  } else if (description.length > PROJECT_DESCRIPTION_BUDGET) {
    errors.push(
      `${name} description exceeds the project's ${PROJECT_DESCRIPTION_BUDGET}-character safety budget (${description.length}).`
    );
  }

  const actualClasses = values(xml, "apexClass");
  const actualObjects = values(xml, "object");
  const actualCustomPermissions = values(xml, "name");
  if (!same(actualClasses, contract.classes))
    errors.push(`${name} Apex class access is out of date.`);
  if (!same(actualObjects, contract.objects))
    errors.push(`${name} object access is out of date.`);
  if (!same(actualCustomPermissions, contract.customPermissions))
    errors.push(`${name} custom permission access is out of date.`);

  for (const apexClass of actualClasses) {
    if (!fs.existsSync(path.join(DEFAULT, "classes", `${apexClass}.cls`)))
      errors.push(`${name} references missing Apex class ${apexClass}.`);
  }
  for (const objectName of actualObjects) {
    if (
      !fs.existsSync(
        path.join(
          DEFAULT,
          "objects",
          objectName,
          `${objectName}.object-meta.xml`
        )
      )
    )
      errors.push(`${name} references missing object ${objectName}.`);
  }
  for (const permission of actualCustomPermissions) {
    if (
      !fs.existsSync(
        path.join(
          DEFAULT,
          "customPermissions",
          `${permission}.customPermission-meta.xml`
        )
      )
    )
      errors.push(
        `${name} references missing custom permission ${permission}.`
      );
  }
}

const actualNames = fs
  .readdirSync(PERMISSION_SETS)
  .map((file) => file.replace(".permissionset-meta.xml", ""));
for (const name of actualNames) {
  if (!expected[name])
    errors.push(`Permission set ${name} has no audited access contract.`);
}

if (errors.length) {
  console.error(errors.join("\n"));
  process.exitCode = 1;
} else {
  console.log(
    `Verified ${actualNames.length} permission sets; descriptions are at most ${PROJECT_DESCRIPTION_BUDGET} characters and access contracts are current.`
  );
}
