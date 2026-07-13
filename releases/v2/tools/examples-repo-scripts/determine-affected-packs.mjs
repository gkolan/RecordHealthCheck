#!/usr/bin/env node
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

const base = process.env.GITHUB_BASE_REF ?? 'main';
const head = process.env.GITHUB_SHA ?? 'HEAD';

let diff;
try {
  diff = execSync(`git diff --name-only ${base}...${head}`, {
    cwd: ROOT,
    encoding: 'utf8',
  });
} catch {
  diff = execSync('git diff --name-only HEAD', { cwd: ROOT, encoding: 'utf8' });
}

const changedFiles = diff.split('\n').filter(Boolean);
const affected = new Set();

for (const file of changedFiles) {
  const match = file.match(/^packs\/([^/]+)\//);
  if (match) affected.add(match[1]);
  if (file.startsWith('docs/facet-vocabulary.yml') || file.startsWith('docs/manifest-schema.json')) {
    const packs = execSync('ls packs', { cwd: ROOT, encoding: 'utf8' })
      .split('\n')
      .filter(Boolean);
    packs.forEach((p) => affected.add(p));
  }
  if (file.startsWith('scripts/')) {
    const packs = execSync('ls packs', { cwd: ROOT, encoding: 'utf8' })
      .split('\n')
      .filter(Boolean);
    packs.forEach((p) => affected.add(p));
  }
}

if (affected.size === 0 && changedFiles.some((f) => f.startsWith('catalog/'))) {
  console.error('Catalog changed without pack changes — regenerate with npm run catalog');
  process.exit(1);
}

const list = [...affected].sort();
console.log(list.join('\n'));
if (list.length === 0) {
  console.log('(no packs affected)');
}
