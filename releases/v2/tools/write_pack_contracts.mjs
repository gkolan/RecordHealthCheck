#!/usr/bin/env node
/** Write example.yml, README.md, CHANGELOG.md for each migrated pack. */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CORE_ROOT = path.resolve(__dirname, '../../..');
const EXAMPLES_ROOT = path.resolve(CORE_ROOT, '../RecordHealthCheck-Examples');

const COMMON = {
  schemaVersion: 1,
  maturity: 'preview',
  ownership: { maintainer: 'record-health-check-community' },
  compatibility: {
    core: { minimumVersion: '2.0.0', maximumTestedVersion: '2.0.0' },
    salesforce: {
      minimumApiVersion: '66.0',
      editions: ['developer', 'enterprise', 'unlimited'],
      requiredFeatures: [],
      requiredObjects: ['Account'],
    },
  },
  dependencies: {
    core: { package: 'record-health-check', version: '>=2.0.0 <3.0.0' },
    packs: [],
  },
  distribution: { supported: ['source'], default: 'source', namespacePolicy: 'none' },
  installation: { manifest: 'manifest/package.xml' },
  removal: {
    method: 'destructive-changes',
    manifest: 'manifest/destructiveChanges.xml',
    status: 'documented',
    lastValidated: '2026-07-13',
    limitations: [
      'Remove the Check Set from Lightning record pages before deploying destructive changes.',
      'Destructive changes delete named metadata only; they are not package-uninstall semantics.',
    ],
  },
  documentation: { readme: 'README.md', changelog: 'CHANGELOG.md' },
};

const PACKS = [
  {
    id: 'account-data-quality',
    title: 'Account Data Quality',
    summary: 'Identifies accounts missing key address, industry, phone, and website fields.',
    facets: {
      clouds: ['base-platform', 'sales'],
      outcomes: ['improve-completeness'],
      mechanisms: ['formula'],
      scopes: ['single-record'],
      complexity: 'beginner',
    },
    checkSet: 'Account_Data_Quality',
    validation: {
      status: 'passed',
      method: 'scratch-org',
      lastValidated: '2026-07-13',
      scenarios: ['pass', 'fail'],
    },
    removalStatus: 'documented',
    readmeSections: {
      checks: 'Four formula checks on Account fields: Billing City, Industry, Phone, and Website.',
      sees: 'A card titled Account Data Quality with pass/fail rows per field.',
      useful: 'When territory assignment, outreach, or reporting depends on baseline Account completeness.',
      components: 'One Check Set (`Account_Data_Quality`) and four Rule records.',
      mechanics: 'Each rule uses Check fields on this record with a `NOT(ISBLANK(...))` pass condition.',
    },
  },
  {
    id: 'account-relationships',
    title: 'Account Relationships',
    summary: 'Verifies an account has contacts, open opportunities, and expected relationship signals.',
    facets: {
      clouds: ['sales'],
      outcomes: ['verify-consistency', 'monitor-readiness'],
      mechanisms: ['formula', 'query'],
      scopes: ['related-records'],
      complexity: 'beginner',
    },
    checkSet: 'Account_Relationships',
    validation: {
      status: 'passed',
      method: 'scratch-org',
      lastValidated: '2026-07-13',
      scenarios: ['pass', 'fail', 'skipped'],
    },
    removalStatus: 'documented',
    readmeSections: {
      checks: 'Contact presence, open opportunity presence, rating, and type population.',
      sees: 'A card titled Account Relationships with mixed formula and query results.',
      useful: 'Before handoff to sales development or account planning when relationship data must exist.',
      components: 'One Check Set (`Account_Relationships`) and four Rule records.',
      mechanics: 'Combines formula checks on Account fields with SOQL child-count queries.',
    },
  },
  {
    id: 'account-everyday-readiness',
    title: 'Account Everyday Readiness',
    summary:
      'Cross-cloud readiness checks spanning contacts, opportunities, cases, tasks, and account fields.',
    facets: {
      clouds: ['sales', 'service'],
      outcomes: ['monitor-readiness', 'detect-stale-records'],
      mechanisms: ['formula', 'query', 'compare-queries'],
      scopes: ['related-records', 'cross-object'],
      complexity: 'intermediate',
    },
    checkSet: 'Account_Everyday_Use_Cases',
    compatibility: {
      salesforce: {
        requiredObjects: ['Account', 'Contact', 'Opportunity', 'Case', 'Task'],
      },
    },
    validation: {
      status: 'passed',
      method: 'scratch-org',
      lastValidated: '2026-07-13',
      scenarios: ['pass', 'fail', 'skipped', 'unable-to-evaluate'],
    },
    removalStatus: 'documented',
    readmeSections: {
      checks:
        'Sixteen checks across Account fields, Contacts, open Opportunities, open Cases, and Tasks.',
      sees: 'A card titled Account Everyday Use Cases grouped by evaluation order.',
      useful:
        'When coordinators need one view of sales pipeline health and service case load on the same Account page.',
      components: 'One Check Set (`Account_Everyday_Use_Cases`) and sixteen Rule records.',
      mechanics:
        'Demonstrates formula, single-query, and compare-two-queries evaluators on standard objects.',
    },
  },
  {
    id: 'apex-advanced-checks',
    title: 'Apex Advanced Checks',
    summary:
      'Custom Apex checks for strategic readiness scoring and inactive approval participants.',
    facets: {
      clouds: ['base-platform', 'sales'],
      outcomes: ['monitor-readiness', 'enforce-eligibility'],
      mechanisms: ['apex', 'query'],
      scopes: ['related-records', 'cross-object'],
      complexity: 'advanced',
    },
    checkSet: 'Account_Examples_Apex',
    validation: {
      status: 'passed',
      method: 'scratch-org',
      lastValidated: '2026-07-13',
      scenarios: ['pass', 'fail', 'unable-to-evaluate'],
    },
    removalStatus: 'partial',
    extraOwns: [
      'ApexClass:AccountStrategicReadinessCheck',
      'ApexClass:ApprovalInactiveApproverCheck',
    ],
    readmeSections: {
      checks:
        'Recent activity (core Apex), open opportunity health (core Apex), strategic readiness score, and inactive approver detection.',
      sees: 'Four Apex-backed rows with parameter-driven thresholds where configured.',
      useful:
        'When declarative rules cannot express weighted scoring or approval graph inspection.',
      components:
        'One Check Set, four Rules, and two example Apex classes (strategic readiness and inactive approver). Recent activity and open opportunity checks depend on Apex shipped in core.',
      mechanics:
        'Rules reference `RecordHealthCheckRule` implementations. Strategic and inactive-approver classes ship in this pack; recent activity and open opportunity classes ship with core.',
    },
  },
  {
    id: 'grantmaking-application-readiness',
    title: 'Grantmaking Application Readiness',
    summary:
      'Scenario catalog for Nonprofit Cloud Application Form readiness checks (documentation pack).',
    facets: {
      clouds: ['nonprofit-cloud'],
      outcomes: ['monitor-readiness', 'enforce-eligibility'],
      mechanisms: ['documentation'],
      scopes: ['scenario-catalog'],
      complexity: 'advanced',
    },
    checkSet: null,
    compatibility: {
      salesforce: {
        minimumApiVersion: '66.0',
        editions: ['enterprise', 'unlimited'],
        requiredFeatures: ['Nonprofit Cloud Grantmaking'],
        requiredObjects: ['ApplicationForm'],
      },
    },
    validation: {
      status: 'documented',
      method: 'domain-review',
      lastValidated: '2026-07-13',
      scenarios: ['documented-scenarios'],
    },
    removalStatus: 'not-supported',
    noForceApp: true,
    readmeSections: {
      checks:
        'Twelve documented Application Form scenarios (intake, budget, review, award, payment phases).',
      sees: 'No runtime metadata ships in this pack — scenario shapes for implementation in an NPC org.',
      useful:
        'When grantmaking staff need advisory readiness on Application Form records beyond save-time validation.',
      components: 'Documentation under `docs/` only.',
      mechanics:
        'Each scenario names an evaluator fit, objects involved, and honest validation-rule alternative.',
    },
  },
];

function yamlQuote(s) {
  if (s.includes('\n')) return `>\n  ${s.trim().replace(/\n/g, '\n  ')}`;
  return s.includes(':') ? `"${s}"` : s;
}

function toYaml(obj, indent = 0) {
  const pad = '  '.repeat(indent);
  const lines = [];
  for (const [key, value] of Object.entries(obj)) {
    if (value === null || value === undefined) continue;
    if (Array.isArray(value)) {
      if (value.length === 0) lines.push(`${pad}${key}: []`);
      else if (typeof value[0] === 'object') {
        lines.push(`${pad}${key}:`);
        for (const item of value) lines.push(toYaml(item, indent + 1));
      } else lines.push(`${pad}${key}: [${value.join(', ')}]`);
    } else if (typeof value === 'object') {
      lines.push(`${pad}${key}:`);
      lines.push(toYaml(value, indent + 1));
    } else if (typeof value === 'string' && value.includes('\n')) {
      lines.push(`${pad}${key}: >`);
      for (const line of value.trim().split('\n')) lines.push(`${pad}  ${line}`);
    } else if (typeof value === 'string' && /[:<>=]/.test(value)) {
      lines.push(`${pad}${key}: "${value}"`);
    } else {
      lines.push(`${pad}${key}: ${value}`);
    }
  }
  return lines.join('\n');
}

function buildOwns(pack) {
  const owns = [];
  if (pack.checkSet) {
    owns.push(`CustomMetadata:Record_Health_Check_Set__mdt.${pack.checkSet}`);
  }
  if (!pack.noForceApp) {
    // filled by validator from filesystem; declare check set at minimum
  }
  if (pack.extraOwns) owns.push(...pack.extraOwns);
  return owns;
}

function buildReadme(pack) {
  const s = pack.readmeSections;
  const deploy = pack.noForceApp
    ? 'This pack is documentation-only. Implement scenarios in your Nonprofit Cloud org using the shapes in `docs/`.'
    : `\`\`\`bash\nsf project deploy start --manifest packs/${pack.id}/manifest/package.xml\n\`\`\``;
  const removal =
    pack.removalStatus === 'not-supported'
      ? 'No automated removal — no metadata is deployed by this pack.'
      : `Deploy \`manifest/destructiveChanges.xml\` after removing the Check Set from record pages. Status: **${pack.removalStatus}**.`;
  return `# ${pack.title}

## 1. What it checks

${s.checks}

## 2. What the user sees

${s.sees}

## 3. When it is useful

${s.useful}

## 4. Prerequisites

- Record Health Check core (\`manifest/package-core.xml\`) deployed
- \`Record_Health_Check_User\` permission set assigned
${pack.id === 'grantmaking-application-readiness' ? '- Nonprofit Cloud Grantmaking provisioned for implementation orgs' : ''}

## 5. Installed components

${s.components}

## 6. Evaluation mechanics

${s.mechanics}

## 7. Deploy and validation steps

${deploy}

## 8. Adaptation guidance

Clone the pack directory, assign a new immutable \`id\`, and adjust Rule messages, thresholds, or applicability formulas to match your org's fields.

## 9. Removal steps

${removal}

## 10. Technical references

- [Record Health Check configuration guide](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/guides/configuration-guide.md)
- [Pattern library](../../docs/pattern-library/index.md)
- Pack contract: \`example.yml\`
`;
}

for (const pack of PACKS) {
  const root = path.join(EXAMPLES_ROOT, 'packs', pack.id);
  const manifest = {
    schemaVersion: COMMON.schemaVersion,
    id: pack.id,
    title: pack.title,
    summary: pack.summary,
    maturity: COMMON.maturity,
    ownership: COMMON.ownership,
    facets: pack.facets,
    compatibility: {
      ...COMMON.compatibility,
      salesforce: {
        ...COMMON.compatibility.salesforce,
        ...(pack.compatibility?.salesforce ?? {}),
      },
    },
    dependencies: COMMON.dependencies,
    distribution: COMMON.distribution,
    installation: pack.noForceApp
      ? { manifest: 'manifest/package.xml', estimatedMinutes: 0 }
      : COMMON.installation,
    removal: { ...COMMON.removal, status: pack.removalStatus },
    validation: pack.validation,
    components: { owns: buildOwns(pack), modifiesSharedComponents: [] },
    documentation: COMMON.documentation,
  };

  fs.mkdirSync(root, { recursive: true });
  fs.writeFileSync(path.join(root, 'example.yml'), toYaml(manifest) + '\n');
  fs.writeFileSync(path.join(root, 'README.md'), buildReadme(pack));
  fs.writeFileSync(
    path.join(root, 'CHANGELOG.md'),
    `# Changelog\n\n## 0.1.0 — 2026-07-13\n\n- Initial migration from Record Health Check core sample content.\n`
  );

  if (pack.noForceApp) {
    const manifestDir = path.join(root, 'manifest');
    fs.mkdirSync(manifestDir, { recursive: true });
    fs.writeFileSync(
      path.join(manifestDir, 'package.xml'),
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n    <version>66.0</version>\n</Package>\n`
    );
    fs.writeFileSync(
      path.join(manifestDir, 'destructiveChanges.xml'),
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n    <version>66.0</version>\n</Package>\n`
    );
  }
}

console.log('Pack contracts written.');
