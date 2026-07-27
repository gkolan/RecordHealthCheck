#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const BLOCK = "apex.jorje.data.ast.Stmnt$BlockStmnt";
const IF_ELSE = "apex.jorje.data.ast.Stmnt$IfElseBlock";
const IF_BLOCK = "apex.jorje.data.ast.IfBlock";
const ELSE_BLOCK = "apex.jorje.data.ast.ElseBlock";

const files = process.argv.slice(2);
if (files.length === 0) {
  process.stderr.write("Usage: node add_apex_braces.mjs <Apex files...>\n");
  process.exitCode = 2;
} else {
  for (const file of files) {
    addBraces(file);
  }
}

function addBraces(file) {
  const absoluteFile = resolve(file);
  const serializer = resolve(
    "node_modules/prettier-plugin-apex/vendor/apex-ast-serializer/bin/apex-ast-serializer"
  );
  const ast = JSON.parse(
    execFileSync(serializer, ["--location", absoluteFile], {
      encoding: "utf8",
      maxBuffer: 64 * 1024 * 1024
    })
  );
  let source = readFileSync(absoluteFile, "utf8");
  const insertions = [];
  visit(ast, source, insertions);
  if (insertions.length === 0) {
    return;
  }

  insertions.sort((left, right) => right.index - left.index);
  for (const insertion of insertions) {
    source =
      source.slice(0, insertion.index) +
      insertion.text +
      source.slice(insertion.index);
  }
  writeFileSync(absoluteFile, source);
  process.stdout.write(
    `${file}: added ${insertions.length / 2} brace pair(s)\n`
  );
}

function visit(value, source, insertions) {
  if (Array.isArray(value)) {
    for (const child of value) {
      visit(child, source, insertions);
    }
    return;
  }
  if (value === null || typeof value !== "object") {
    return;
  }

  if (value["@class"] === IF_BLOCK || value["@class"] === ELSE_BLOCK) {
    addStatementInsertions(value, source, insertions);
  }
  for (const child of Object.values(value)) {
    visit(child, source, insertions);
  }
}

function addStatementInsertions(owner, source, insertions) {
  const statement = owner.stmnt;
  if (
    !statement?.loc ||
    statement["@class"] === BLOCK ||
    statement["@class"] === IF_ELSE
  ) {
    return;
  }
  const lineStart = source.lastIndexOf("\n", statement.loc.startIndex - 1) + 1;
  const firstText = source.slice(lineStart).search(/\S/);
  const startIndex =
    firstText >= 0 && owner.loc.line !== statement.loc.line
      ? lineStart + firstText
      : statement.loc.startIndex;
  const endIndex = findStatementEnd(source, startIndex);
  insertions.push({ index: endIndex, text: "}" });
  insertions.push({ index: startIndex, text: "{" });
}

function findStatementEnd(source, startIndex) {
  let quote = null;
  let escaped = false;
  let depth = 0;
  for (let index = startIndex; index < source.length; index++) {
    const character = source[index];
    if (quote !== null) {
      if (escaped) {
        escaped = false;
      } else if (character === "\\") {
        escaped = true;
      } else if (character === quote) {
        quote = null;
      }
      continue;
    }
    if (character === "'" || character === '"') {
      quote = character;
    } else if (character === "(" || character === "[") {
      depth++;
    } else if (character === ")" || character === "]") {
      depth--;
    } else if (character === ";" && depth === 0) {
      return index + 1;
    }
  }
  throw new Error(
    `Could not find the end of the statement at index ${startIndex}`
  );
}
