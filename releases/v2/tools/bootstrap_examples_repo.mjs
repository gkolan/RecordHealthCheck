#!/usr/bin/env node
/**
 * Bootstrap RecordHealthCheck-Examples repository structure and migrate initial packs.
 * Run from RecordHealthCheck repo root:
 *   node releases/v2/tools/bootstrap_examples_repo.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CORE_ROOT = path.resolve(__dirname, '../../..');
const EXAMPLES_ROOT = path.resolve(CORE_ROOT, '../RecordHealthCheck-Examples');
const CORE_CMDT = path.join(CORE_ROOT, 'force-app/main/default/customMetadata');
const CORE_CLASSES = path.join(CORE_ROOT, 'force-app/main/default/classes');

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function write(filePath, content) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, content, 'utf8');
}

function copyFile(src, dest) {
  ensureDir(path.dirname(dest));
  fs.copyFileSync(src, dest);
}

function copyCmdtRecords(destDir, records) {
  for (const record of records) {
    const src = path.join(CORE_CMDT, `Record_Health_Check_Rule__mdt.${record}.md-meta.xml`);
    const dest = path.join(destDir, `Record_Health_Check_Rule__mdt.${record}.md-meta.xml`);
    if (!fs.existsSync(src)) {
      throw new Error(`Missing CMDT record: ${src}`);
    }
    copyFile(src, dest);
  }
}

function copyCheckSet(destDir, setName) {
  const src = path.join(CORE_CMDT, `Record_Health_Check_Set__mdt.${setName}.md-meta.xml`);
  const dest = path.join(destDir, `Record_Health_Check_Set__mdt.${setName}.md-meta.xml`);
  copyFile(src, dest);
}

function buildPackageXml(members) {
  const lines = members
    .map((m) => `        <members>${m}</members>`)
    .join('\n');
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
${lines}
        <name>CustomMetadata</name>
    </types>
    <version>66.0</version>
</Package>
`;
}

function buildDestructiveXml(members, extraTypes = []) {
  let types = '';
  if (members.length) {
    types += `    <types>\n${members.map((m) => `        <members>${m}</members>`).join('\n')}\n        <name>CustomMetadata</name>\n    </types>\n`;
  }
  for (const t of extraTypes) {
    types += `    <types>\n${t.members.map((m) => `        <members>${m}</members>`).join('\n')}\n        <name>${t.name}</name>\n    </types>\n`;
  }
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
${types}    <version>66.0</version>
</Package>
`;
}

const PACKS = [
  {
    id: 'account-data-quality',
    checkSet: 'Account_Data_Quality',
    rules: [
      'Account_DQ_BillingCity',
      'Account_DQ_Industry',
      'Account_DQ_Phone',
      'Account_DQ_Website',
    ],
    apex: [],
  },
  {
    id: 'account-relationships',
    checkSet: 'Account_Relationships',
    rules: [
      'Account_Rel_HasContact',
      'Account_Rel_HasOpenOpp',
      'Account_Rel_Rating',
      'Account_Rel_TypeSet',
    ],
    apex: [],
  },
  {
    id: 'account-everyday-readiness',
    checkSet: 'Account_Everyday_Use_Cases',
    rules: [
      'Account_EU_AccountPhoneIsSet',
      'Account_EU_AllContactsHaveEmail',
      'Account_EU_AllContactsHavePhone',
      'Account_EU_AllContactsHaveTitle',
      'Account_EU_AtLeastOneContactHasEmail',
      'Account_EU_HasAtLeastOneContact',
      'Account_EU_NoOpenCases',
      'Account_EU_NoOverdueOpenTasks',
      'Account_EU_NoPastDueOpenOpps',
      'Account_EU_NoUnreachableContacts',
      'Account_EU_OpenOppsFutureClose',
      'Account_EU_OwnerIsActive',
      'Account_EU_PhoneWellFormed',
      'Account_EU_RecentAccountActivity',
      'Account_EU_ShippingAddressComplete',
      'Account_EU_WebsiteValidUrl',
    ],
    apex: [],
  },
  {
    id: 'apex-advanced-checks',
    checkSet: 'Account_Examples_Apex',
    rules: [
      'Has_Recent_Activity',
      'Open_Opportunities_Are_Healthy',
      'Strategic_Account_Is_Ready',
      'Approval_No_Inactive_Approvers',
    ],
    apex: [
      'AccountStrategicReadinessCheck.cls',
      'AccountStrategicReadinessCheck.cls-meta.xml',
      'AccountStrategicReadinessCheckTest.cls',
      'AccountStrategicReadinessCheckTest.cls-meta.xml',
      'ApprovalInactiveApproverCheck.cls',
      'ApprovalInactiveApproverCheck.cls-meta.xml',
      'ApprovalInactiveApproverCheckTest.cls',
      'ApprovalInactiveApproverCheckTest.cls-meta.xml',
    ],
  },
];

console.log(`Bootstrapping ${EXAMPLES_ROOT}`);

// Migrate pack metadata
for (const pack of PACKS) {
  const forceApp = path.join(EXAMPLES_ROOT, 'packs', pack.id, 'force-app/main/default');
  const cmdtDir = path.join(forceApp, 'customMetadata');
  const classesDir = path.join(forceApp, 'classes');
  copyCheckSet(cmdtDir, pack.checkSet);
  copyCmdtRecords(cmdtDir, pack.rules);
  for (const cls of pack.apex) {
    copyFile(path.join(CORE_CLASSES, cls), path.join(classesDir, cls));
  }
  const cmdtMembers = [
    `Record_Health_Check_Set__mdt.${pack.checkSet}`,
    ...pack.rules.map((r) => `Record_Health_Check_Rule__mdt.${r}`),
  ];
  const manifestDir = path.join(EXAMPLES_ROOT, 'packs', pack.id, 'manifest');
  write(path.join(manifestDir, 'package.xml'), buildPackageXml(cmdtMembers));
  const destructiveMembers = cmdtMembers;
  const extraDestructive =
    pack.apex.length > 0
      ? [
          {
            name: 'ApexClass',
            members: [
              'AccountStrategicReadinessCheck',
              'AccountStrategicReadinessCheckTest',
              'ApprovalInactiveApproverCheck',
              'ApprovalInactiveApproverCheckTest',
            ],
          },
        ]
      : [];
  write(
    path.join(manifestDir, 'destructiveChanges.xml'),
    buildDestructiveXml(destructiveMembers, extraDestructive)
  );
}

// Copy examples docs to docs/pattern-library
const examplesSrc = path.join(EXAMPLES_ROOT, 'examples');
const patternDest = path.join(EXAMPLES_ROOT, 'docs/pattern-library');
if (fs.existsSync(examplesSrc)) {
  ensureDir(patternDest);
  execSync(`cp -R "${examplesSrc}/." "${patternDest}/"`, { stdio: 'inherit' });
}

// Copy nonprofit industry docs into grantmaking pack
const grantmakingDocs = path.join(EXAMPLES_ROOT, 'packs/grantmaking-application-readiness/docs');
ensureDir(grantmakingDocs);
for (const f of ['cursor-grantmaking-examples.md', 'codex-grantmaking-examples.md']) {
  const src = path.join(examplesSrc, 'non-profit-cloud', f);
  if (fs.existsSync(src)) {
    copyFile(src, path.join(grantmakingDocs, f));
  }
}

console.log('Pack metadata migration complete.');
console.log('Run: cd RecordHealthCheck-Examples && npm run validate && npm run catalog');
