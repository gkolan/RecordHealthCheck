#!/usr/bin/env node
/**
 * Write catalog tooling, docs, CI, and pack contracts into RecordHealthCheck-Examples.
 * Run after bootstrap_examples_repo.mjs:
 *   node releases/v2/tools/setup_examples_infrastructure.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CORE_ROOT = path.resolve(__dirname, '../../..');
const EXAMPLES_ROOT = path.resolve(CORE_ROOT, '../RecordHealthCheck-Examples');

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function write(relPath, content) {
  const full = path.join(EXAMPLES_ROOT, relPath);
  ensureDir(path.dirname(full));
  fs.writeFileSync(full, content, 'utf8');
}

write('package.json', JSON.stringify({
  name: 'record-health-check-examples',
  version: '0.1.0',
  private: true,
  type: 'module',
  description: 'Record Health Check example packs — catalog of independently deployable scenario content.',
  scripts: {
    validate: 'node scripts/validate-packs.mjs',
    catalog: 'node scripts/generate-catalog.mjs',
    'check-catalog': 'node scripts/generate-catalog.mjs --check',
    'validation-project': 'node scripts/create-validation-project.mjs',
    'affected-packs': 'node scripts/determine-affected-packs.mjs',
    'install-order': 'node scripts/validate-install-order.mjs',
    bootstrap: 'node ../RecordHealthCheck/releases/v2/tools/bootstrap_examples_repo.mjs && node ../RecordHealthCheck/releases/v2/tools/setup_examples_infrastructure.mjs',
  },
  engines: { node: '>=20' },
}, null, 2) + '\n');

write('README.md', `# Record Health Check — Examples

Independently installable **example packs** for [Record Health Check](https://github.com/gkolan/RecordHealthCheck). Core ships one hero example; this repository holds reusable scenario content classified by machine-readable facets and discovered through generated catalogs.

## Quick start

1. Install [Record Health Check core](https://github.com/gkolan/RecordHealthCheck) (\`manifest/package-core.xml\` plus \`manifest/package-Example_Account_360_Health_Check.xml\` for the hero demo).
2. Assign the \`Record_Health_Check_User\` permission set and add the **recordHealthCheck** component to a record page.
3. Browse [\`catalog/by-outcome.md\`](catalog/by-outcome.md) or [\`catalog/catalog.json\`](catalog/catalog.json).
4. Deploy one pack:

\`\`\`bash
sf project deploy start --manifest packs/account-data-quality/manifest/package.xml
\`\`\`

## Repository shape

- **\`packs/\`** — flat catalog of example packs; one canonical home per use case (\`example.yml\` + manifest + metadata).
- **\`catalog/\`** — generated discovery views (do not edit by hand).
- **\`docs/\`** — authoring guide, facet vocabulary, packaging guide, pattern library.
- **\`scripts/\`** — catalog generation, validation, isolated DX project creation.

There is **no root \`sfdx-project.json\`**. Each pack is validated through an isolated project generated on demand.

## Tooling

\`\`\`bash
npm run validate        # schema, vocabulary, ownership, dependency checks
npm run catalog         # regenerate catalog/*
npm run check-catalog   # fail if catalog is stale (CI)
\`\`\`

## Contributing

See [\`docs/authoring-guide.md\`](docs/authoring-guide.md) and copy [\`docs/pack-template/\`](docs/pack-template/).
`);

write('docs/facet-vocabulary.yml', `# Controlled vocabulary for pack facets (source of truth).
# Human-readable vocabulary pages are generated from this file.

clouds:
  - base-platform
  - sales
  - service
  - financial-services
  - nonprofit-cloud

outcomes:
  - improve-completeness
  - verify-consistency
  - detect-stale-records
  - enforce-eligibility
  - monitor-readiness

mechanisms:
  - formula
  - query
  - compare-queries
  - apex
  - documentation

scopes:
  - single-record
  - related-records
  - cross-object
  - scenario-catalog

complexity:
  - beginner
  - intermediate
  - advanced

maturity:
  - experimental
  - preview
  - supported
  - community
  - deprecated
`);

write('docs/authoring-guide.md', `# Authoring guide

## Pack identity

- Directory name = immutable use-case \`id\` in \`example.yml\`.
- Do **not** encode cloud or mechanism in the directory name.
- Classify with \`facets\` in \`example.yml\`; discovery views are generated.

## Required files

| File | Purpose |
| ---- | ------- |
| \`example.yml\` | Machine contract (validated against \`manifest-schema.json\`) |
| \`README.md\` | Ten-section human contract (see plan §3.4) |
| \`CHANGELOG.md\` | Pack-level changes |
| \`manifest/package.xml\` | Deploy manifest |
| \`manifest/destructiveChanges.xml\` | Documented removal manifest |
| \`force-app/\` | Salesforce metadata (omit for documentation-only packs) |

## README sections (in order)

1. What it checks
2. What the user sees
3. When it is useful
4. Prerequisites
5. Installed components
6. Evaluation mechanics
7. Deploy and validation steps
8. Adaptation guidance
9. Removal steps (honest \`removal.status\`)
10. Technical references

## Honest claims

- \`distribution.supported\` is \`[source]\` until a pack is promoted through a separate 2GP pipeline.
- \`removal.status\` reflects what CI actually validated — never equate \`destructiveChanges.xml\` with safe uninstall.
- \`compatibility.maximumTestedVersion\` is distinct from maximum supported.

## Foundation packs

Rare exception only. Default: depend on core, keep packs self-contained, duplicate tiny assets when needed.
`);

write('docs/packaging-guide.md', `# Packaging guide

This repository is **source-first**. Packs deploy via manifest; there is no root \`sfdx-project.json\`.

## Validation project

\`scripts/create-validation-project.mjs\` emits an isolated DX project under \`.tmp/validation/<pack-id>/\` with a single \`packageDirectory\`. Use it for scratch-org validation without deploying unrelated packs.

## Promoting to 2GP (later)

When a pack is mature enough for unlocked or managed 2GP:

1. Create a **separate packaging project** (not this catalog repo's root).
2. Record the released \`04t\` version and core dependency in that project's \`sfdx-project.json\`.
3. Update the pack's \`example.yml\` \`distribution\` block with honest supported channels.
4. A Git tag is **not** an installable Salesforce package version.

## Namespace

Namespace is a project-level packaging decision. \`example.yml\` may describe intended policy but does not make per-pack namespaces achievable inside one root DX project.
`);

// manifest-schema.json - simplified JSON Schema
write('docs/manifest-schema.json', JSON.stringify({
  $schema: 'http://json-schema.org/draft-07/schema#',
  title: 'Record Health Check example pack manifest',
  type: 'object',
  required: [
    'schemaVersion', 'id', 'title', 'summary', 'maturity', 'ownership', 'facets',
    'compatibility', 'dependencies', 'distribution', 'installation', 'removal',
    'validation', 'components', 'documentation',
  ],
  properties: {
    schemaVersion: { type: 'integer', const: 1 },
    id: { type: 'string', pattern: '^[a-z0-9]+(-[a-z0-9]+)*$' },
    title: { type: 'string', minLength: 1 },
    summary: { type: 'string', minLength: 1 },
    maturity: {
      type: 'string',
      enum: ['experimental', 'preview', 'supported', 'community', 'deprecated'],
    },
    ownership: {
      type: 'object',
      required: ['maintainer'],
      properties: { maintainer: { type: 'string' } },
    },
    facets: {
      type: 'object',
      required: ['clouds', 'outcomes', 'mechanisms', 'scopes', 'complexity'],
      properties: {
        clouds: { type: 'array', items: { type: 'string' }, minItems: 1 },
        outcomes: { type: 'array', items: { type: 'string' }, minItems: 1 },
        mechanisms: { type: 'array', items: { type: 'string' }, minItems: 1 },
        scopes: { type: 'array', items: { type: 'string' }, minItems: 1 },
        complexity: { type: 'string' },
      },
    },
    compatibility: {
      type: 'object',
      required: ['core', 'salesforce'],
      properties: {
        core: {
          type: 'object',
          required: ['minimumVersion', 'maximumTestedVersion'],
          properties: {
            minimumVersion: { type: 'string' },
            maximumTestedVersion: { type: 'string' },
          },
        },
        salesforce: {
          type: 'object',
          required: ['minimumApiVersion', 'editions', 'requiredFeatures', 'requiredObjects'],
          properties: {
            minimumApiVersion: { type: 'string' },
            editions: { type: 'array', items: { type: 'string' } },
            requiredFeatures: { type: 'array', items: { type: 'string' } },
            requiredObjects: { type: 'array', items: { type: 'string' } },
          },
        },
      },
    },
    dependencies: {
      type: 'object',
      required: ['core', 'packs'],
      properties: {
        core: {
          type: 'object',
          required: ['package', 'version'],
          properties: { package: { type: 'string' }, version: { type: 'string' } },
        },
        packs: { type: 'array', items: { type: 'object' } },
      },
    },
    distribution: {
      type: 'object',
      required: ['supported', 'default', 'namespacePolicy'],
      properties: {
        supported: { type: 'array', items: { type: 'string' } },
        default: { type: 'string' },
        namespacePolicy: { type: 'string' },
      },
    },
    installation: {
      type: 'object',
      required: ['manifest'],
      properties: { manifest: { type: 'string' }, estimatedMinutes: { type: 'integer' } },
    },
    removal: {
      type: 'object',
      required: ['method', 'manifest', 'status', 'limitations'],
      properties: {
        method: { type: 'string' },
        manifest: { type: 'string' },
        status: { type: 'string', enum: ['tested', 'documented', 'partial', 'not-supported'] },
        lastValidated: { type: 'string' },
        limitations: { type: 'array', items: { type: 'string' } },
      },
    },
    validation: {
      type: 'object',
      required: ['status', 'method', 'scenarios'],
      properties: {
        status: { type: 'string', enum: ['passed', 'documented', 'partial', 'not-run'] },
        method: { type: 'string' },
        lastValidated: { type: 'string' },
        orgShape: { type: 'string' },
        scenarios: { type: 'array', items: { type: 'string' } },
      },
    },
    components: {
      type: 'object',
      required: ['owns', 'modifiesSharedComponents'],
      properties: {
        owns: { type: 'array', items: { type: 'string' } },
        modifiesSharedComponents: { type: 'array', items: { type: 'string' } },
      },
    },
    documentation: {
      type: 'object',
      required: ['readme', 'changelog'],
      properties: { readme: { type: 'string' }, changelog: { type: 'string' } },
    },
  },
  additionalProperties: false,
}, null, 2) + '\n');

// Pack template
write('docs/pack-template/example.yml', `schemaVersion: 1

id: my-pack-id
title: My Pack Title
summary: >
  One-line description of what this pack checks.

maturity: preview

ownership:
  maintainer: record-health-check-community

facets:
  clouds: [base-platform]
  outcomes: [improve-completeness]
  mechanisms: [formula]
  scopes: [single-record]
  complexity: beginner

compatibility:
  core:
    minimumVersion: 2.0.0
    maximumTestedVersion: 2.0.0
  salesforce:
    minimumApiVersion: '66.0'
    editions: [developer, enterprise, unlimited]
    requiredFeatures: []
    requiredObjects: [Account]

dependencies:
  core:
    package: record-health-check
    version: '>=2.0.0 <3.0.0'
  packs: []

distribution:
  supported: [source]
  default: source
  namespacePolicy: none

installation:
  manifest: manifest/package.xml

removal:
  method: destructive-changes
  manifest: manifest/destructiveChanges.xml
  status: documented
  limitations:
    - Remove the component from Lightning record pages before deletion.

validation:
  status: documented
  method: scratch-org
  scenarios: [pass, fail]

components:
  owns: []
  modifiesSharedComponents: []

documentation:
  readme: README.md
  changelog: CHANGELOG.md
`);

write('docs/pack-template/README.md', `# <Pack title>

## 1. What it checks

## 2. What the user sees

## 3. When it is useful

## 4. Prerequisites

Record Health Check core deployed; \`Record_Health_Check_User\` assigned.

## 5. Installed components

## 6. Evaluation mechanics

## 7. Deploy and validation steps

\`\`\`bash
sf project deploy start --manifest manifest/package.xml
\`\`\`

## 8. Adaptation guidance

## 9. Removal steps

See \`removal.status\` in \`example.yml\`. Deploy \`manifest/destructiveChanges.xml\` after removing the Check Set from record pages.

## 10. Technical references

- [Configuration guide](https://github.com/gkolan/RecordHealthCheck/tree/main/docs/v2/guides/configuration-guide.md)
`);

write('docs/pack-template/manifest/package.xml', `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <version>66.0</version>
</Package>
`);

write('docs/pack-template/CHANGELOG.md', `# Changelog

## Unreleased
`);

console.log('Infrastructure files written to', EXAMPLES_ROOT);
