#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import yaml from 'yaml';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const PACKS_DIR = path.join(ROOT, 'packs');

function loadDeps(packId) {
  const data = yaml.parse(
    fs.readFileSync(path.join(PACKS_DIR, packId, 'example.yml'), 'utf8')
  );
  return (data.dependencies?.packs ?? []).map((p) => (typeof p === 'string' ? p : p.id));
}

const packs = fs.readdirSync(PACKS_DIR).filter((d) =>
  fs.statSync(path.join(PACKS_DIR, d)).isDirectory()
);
const order = [];
const visited = new Set();
const visiting = new Set();

function visit(id) {
  if (visited.has(id)) return;
  if (visiting.has(id)) throw new Error(`Cycle at ${id}`);
  visiting.add(id);
  for (const dep of loadDeps(id)) {
    if (!packs.includes(dep)) throw new Error(`${id} depends on missing pack ${dep}`);
    visit(dep);
  }
  visiting.delete(id);
  visited.add(id);
  order.push(id);
}

for (const pack of packs) visit(pack);
console.log('Valid install order:');
order.forEach((p, i) => console.log(`${i + 1}. ${p}`));
