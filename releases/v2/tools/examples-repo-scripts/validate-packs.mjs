#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import yaml from 'yaml';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const PACKS_DIR = path.join(ROOT, 'packs');
const VOCAB_PATH = path.join(ROOT, 'docs/facet-vocabulary.yml');
const SCHEMA_PATH = path.join(ROOT, 'docs/manifest-schema.json');

function loadYaml(filePath) {
  return yaml.parse(fs.readFileSync(filePath, 'utf8'));
}

function listPackDirs() {
  if (!fs.existsSync(PACKS_DIR)) return [];
  return fs
    .readdirSync(PACKS_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();
}

function loadPackManifest(packId) {
  const manifestPath = path.join(PACKS_DIR, packId, 'example.yml');
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`Missing example.yml for pack "${packId}"`);
  }
  return { packId, manifestPath, data: loadYaml(manifestPath) };
}

function validateRequired(obj, keys, label) {
  const errors = [];
  for (const key of keys) {
    if (obj[key] === undefined || obj[key] === null) {
      errors.push(`${label}: missing required field "${key}"`);
    }
  }
  return errors;
}

function validateFacets(data, vocab, packId) {
  const errors = [];
  const facets = data.facets ?? {};
  for (const [facet, allowed] of Object.entries(vocab)) {
    if (facet === 'maturity') continue;
    const values = facets[facet];
    if (facet === 'complexity') {
      if (!allowed.includes(values)) {
        errors.push(`${packId}: facets.complexity "${values}" not in vocabulary`);
      }
      continue;
    }
    if (!Array.isArray(values)) {
      errors.push(`${packId}: facets.${facet} must be an array`);
      continue;
    }
    for (const v of values) {
      if (!allowed.includes(v)) {
        errors.push(`${packId}: facets.${facet} value "${v}" not in vocabulary`);
      }
    }
  }
  return errors;
}

function deriveOwnedComponents(packId) {
  const owns = [];
  const forceApp = path.join(PACKS_DIR, packId, 'force-app/main/default');
  const cmdtDir = path.join(forceApp, 'customMetadata');
  if (fs.existsSync(cmdtDir)) {
    for (const file of fs.readdirSync(cmdtDir)) {
      if (file.endsWith('.md-meta.xml')) {
        const base = file.replace('.md-meta.xml', '');
        owns.push(`CustomMetadata:${base}`);
      }
    }
  }
  const classesDir = path.join(forceApp, 'classes');
  if (fs.existsSync(classesDir)) {
    for (const file of fs.readdirSync(classesDir)) {
      if (file.endsWith('.cls') && !file.endsWith('Test.cls')) {
        owns.push(`ApexClass:${file.replace('.cls', '')}`);
      }
    }
  }
  return owns.sort();
}

function main() {
  const errors = [];
  const vocab = loadYaml(VOCAB_PATH);
  const schema = JSON.parse(fs.readFileSync(SCHEMA_PATH, 'utf8'));
  const requiredTop = schema.required ?? [];
  const packs = listPackDirs();
  const ids = new Map();
  const ownership = new Map();

  if (packs.length === 0) {
    console.error('No packs found under packs/');
    process.exit(1);
  }

  for (const packId of packs) {
    let pack;
    try {
      pack = loadPackManifest(packId);
    } catch (e) {
      errors.push(e.message);
      continue;
    }
    const { data } = pack;
    errors.push(...validateRequired(data, requiredTop, packId).map((e) => e));
    if (data.id !== packId) {
      errors.push(`${packId}: id "${data.id}" does not match directory name`);
    }
    if (ids.has(data.id)) {
      errors.push(`Duplicate pack id "${data.id}" in ${packId} and ${ids.get(data.id)}`);
    }
    ids.set(data.id, packId);
    errors.push(...validateFacets(data, vocab, packId));

    if (data.distribution?.supported?.some((d) => d !== 'source')) {
      errors.push(`${packId}: only source distribution is supported in this repository phase`);
    }

    const derived = deriveOwnedComponents(packId);
    for (const component of derived) {
      if (ownership.has(component)) {
        errors.push(
          `Ownership collision: ${component} claimed by ${ownership.get(component)} and ${packId}`
        );
      } else {
        ownership.set(component, packId);
      }
    }
    for (const component of data.components?.owns ?? []) {
      if (ownership.has(component) && ownership.get(component) !== packId) {
        errors.push(
          `Ownership collision: ${component} declared in ${packId}, owned by ${ownership.get(component)}`
        );
      }
    }

    const installManifest = path.join(ROOT, 'packs', packId, data.installation?.manifest ?? '');
    if (!fs.existsSync(installManifest)) {
      errors.push(`${packId}: installation manifest missing at ${data.installation?.manifest}`);
    }
    const removalManifest = path.join(ROOT, 'packs', packId, data.removal?.manifest ?? '');
    if (!fs.existsSync(removalManifest)) {
      errors.push(`${packId}: removal manifest missing at ${data.removal?.manifest}`);
    }
    const readme = path.join(ROOT, 'packs', packId, data.documentation?.readme ?? 'README.md');
    if (!fs.existsSync(readme)) {
      errors.push(`${packId}: README missing`);
    }
  }

  // Dependency cycle check (pack -> pack only)
  const graph = new Map();
  for (const packId of packs) {
    try {
      const { data } = loadPackManifest(packId);
      graph.set(
        packId,
        (data.dependencies?.packs ?? []).map((p) => (typeof p === 'string' ? p : p.id))
      );
    } catch {
      // already reported
    }
  }
  const visiting = new Set();
  const visited = new Set();
  function dfs(node, stack) {
    if (visiting.has(node)) {
      errors.push(`Dependency cycle detected: ${[...stack, node].join(' -> ')}`);
      return;
    }
    if (visited.has(node)) return;
    visiting.add(node);
    for (const dep of graph.get(node) ?? []) {
      dfs(dep, [...stack, node]);
    }
    visiting.delete(node);
    visited.add(node);
  }
  for (const packId of packs) dfs(packId, []);

  if (errors.length) {
    console.error('Pack validation failed:\n' + errors.map((e) => `  - ${e}`).join('\n'));
    process.exit(1);
  }
  console.log(`Validated ${packs.length} pack(s): ${packs.join(', ')}`);
}

main();
