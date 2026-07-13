#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import yaml from 'yaml';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const PACKS_DIR = path.join(ROOT, 'packs');
const HEADER =
  '<!-- DO NOT EDIT. Generated from packs/*/example.yml. -->\n\n';

function loadYaml(filePath) {
  return yaml.parse(fs.readFileSync(filePath, 'utf8'));
}

function listPacks() {
  return fs
    .readdirSync(PACKS_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => {
      const manifestPath = path.join(PACKS_DIR, d.name, 'example.yml');
      return { id: d.name, data: loadYaml(manifestPath) };
    })
    .sort((a, b) => a.id.localeCompare(b.id));
}

function groupBy(packs, facet) {
  const map = new Map();
  for (const pack of packs) {
    const values = pack.data.facets?.[facet];
    const list = Array.isArray(values) ? values : [values];
    for (const value of list) {
      if (!map.has(value)) map.set(value, []);
      map.get(value).push(pack);
    }
  }
  return [...map.entries()].sort((a, b) => a[0].localeCompare(b[0]));
}

function renderFacetMd(title, facet, packs) {
  let md = HEADER + `# ${title}\n\n`;
  for (const [value, group] of groupBy(packs, facet)) {
    md += `## ${value}\n\n`;
    for (const pack of group.sort((a, b) => a.data.title.localeCompare(b.data.title))) {
      md += `- [${pack.data.title}](../packs/${pack.id}/README.md) (\`${pack.id}\`) — ${pack.data.summary.trim().replace(/\s+/g, ' ')}\n`;
    }
    md += '\n';
  }
  return md;
}

function renderMaturityMd(packs) {
  const map = new Map();
  for (const pack of packs) {
    const value = pack.data.maturity;
    if (!map.has(value)) map.set(value, []);
    map.get(value).push(pack);
  }
  let md = HEADER + '# By maturity\n\n';
  for (const [value, group] of [...map.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
    md += `## ${value}\n\n`;
    for (const pack of group.sort((a, b) => a.data.title.localeCompare(b.data.title))) {
      md += `- [${pack.data.title}](../packs/${pack.id}/README.md) (\`${pack.id}\`)\n`;
    }
    md += '\n';
  }
  return md;
}

function renderCompatibility(packs) {
  let md = HEADER + '# Compatibility\n\n';
  md += '| Pack | Core minimum | Core tested | API | Objects | Validation |\n';
  md += '| ---- | ------------ | ----------- | --- | ------- | ---------- |\n';
  for (const pack of packs) {
    const c = pack.data.compatibility;
    const v = pack.data.validation;
    md += `| [${pack.data.title}](../packs/${pack.id}/README.md) | ${c.core.minimumVersion} | ${c.core.maximumTestedVersion} | ${c.salesforce.minimumApiVersion} | ${c.salesforce.requiredObjects.join(', ')} | ${v.status} (${v.method}) |\n`;
  }
  return md + '\n';
}

function writeIfChanged(filePath, content) {
  const existing = fs.existsSync(filePath) ? fs.readFileSync(filePath, 'utf8') : null;
  if (existing === content) return false;
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, 'utf8');
  return true;
}

function main() {
  const checkOnly = process.argv.includes('--check');
  const packs = listPacks();
  const catalog = {
    generatedAt: new Date().toISOString().slice(0, 10),
    packCount: packs.length,
    packs: packs.map((p) => ({
      id: p.id,
      title: p.data.title,
      summary: p.data.summary.trim(),
      maturity: p.data.maturity,
      facets: p.data.facets,
      compatibility: p.data.compatibility,
      validation: {
        status: p.data.validation.status,
        method: p.data.validation.method,
        lastValidated: p.data.validation.lastValidated ?? null,
      },
      removal: { status: p.data.removal.status },
      distribution: p.data.distribution,
      readme: `packs/${p.id}/README.md`,
    })),
  };

  const outputs = {
    'catalog/catalog.json': JSON.stringify(catalog, null, 2) + '\n',
    'catalog/by-cloud.md': renderFacetMd('By cloud', 'clouds', packs),
    'catalog/by-outcome.md': renderFacetMd('By outcome', 'outcomes', packs),
    'catalog/by-mechanism.md': renderFacetMd('By mechanism', 'mechanisms', packs),
    'catalog/by-complexity.md': renderFacetMd('By complexity', 'complexity', packs),
    'catalog/by-maturity.md': renderMaturityMd(packs),
    'catalog/compatibility.md': renderCompatibility(packs),
  };

  let changed = 0;
  for (const [rel, content] of Object.entries(outputs)) {
    const full = path.join(ROOT, rel);
    if (checkOnly) {
      const existing = fs.existsSync(full) ? fs.readFileSync(full, 'utf8') : '';
      if (existing !== content) {
        console.error(`Catalog drift: ${rel} is stale. Run: npm run catalog`);
        process.exit(1);
      }
    } else if (writeIfChanged(full, content)) {
      changed++;
      console.log(`Wrote ${rel}`);
    }
  }
  if (checkOnly) {
    console.log('Catalog is up to date.');
  } else {
    console.log(`Catalog generation complete (${changed} file(s) updated).`);
  }
}

main();
