#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const packId = process.argv[2];

if (!packId) {
  console.error('Usage: node scripts/create-validation-project.mjs <pack-id>');
  process.exit(1);
}

const packRoot = path.join(ROOT, 'packs', packId);
const forceAppSrc = path.join(packRoot, 'force-app');
if (!fs.existsSync(packRoot)) {
  console.error(`Pack not found: ${packId}`);
  process.exit(1);
}

const outRoot = path.join(ROOT, '.tmp/validation', packId);
const outForceApp = path.join(outRoot, 'force-app');

function copyRecursive(src, dest) {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dest, entry.name);
    if (entry.isDirectory()) copyRecursive(s, d);
    else fs.copyFileSync(s, d);
  }
}

fs.rmSync(outRoot, { recursive: true, force: true });
fs.mkdirSync(outRoot, { recursive: true });
copyRecursive(forceAppSrc, outForceApp);

const project = {
  packageDirectories: [{ path: 'force-app', default: true }],
  name: `rhc-examples-validate-${packId}`,
  namespace: '',
  sfdcLoginUrl: 'https://login.salesforce.com',
  sourceApiVersion: '66.0',
};

fs.writeFileSync(path.join(outRoot, 'sfdx-project.json'), JSON.stringify(project, null, 2) + '\n');
console.log(`Validation project: ${outRoot}`);
