#!/usr/bin/env node

const fs = require("fs");

const [source, ...wanted] = process.argv.slice(2);
if (!source || wanted.length === 0) {
  console.error("Usage: node tools/inspect_blockly_blocks.js <experience.json> <BlockType> [...]");
  process.exit(2);
}

const document = JSON.parse(fs.readFileSync(source, "utf8"));
const roots = document.workspace?.mod?.blocks?.blocks ?? document.mod?.blocks?.blocks ?? [];
const matches = new Map(wanted.map((type) => [type, null]));

if (matches.has("__variables__")) {
  matches.set("__variables__", document.workspace?.mod?.variables ?? document.mod?.variables ?? []);
}
if (matches.has("__rules__")) {
  const summary = [];
  (function collectRules(value) {
    if (!value || typeof value !== "object") return;
    if (value.type === "ruleBlock") {
      summary.push({
        name: value.fields?.NAME,
        event: value.fields?.EVENTTYPE,
        scope: value.fields?.OBJECTTYPE,
        has_condition: Boolean(value.inputs?.CONDITIONS),
      });
    }
    for (const child of Object.values(value)) collectRules(child);
  })(roots);
  matches.set("__rules__", summary);
}

function visit(value) {
  if (!value || typeof value !== "object") return;
  if (typeof value.type === "string" && matches.has(value.type) && matches.get(value.type) === null) {
    matches.set(value.type, value);
  }
  if (value.type === "ruleBlock" && typeof value.fields?.EVENTTYPE === "string") {
    const ruleKey = `rule:${value.fields.EVENTTYPE}`;
    if (matches.has(ruleKey) && matches.get(ruleKey) === null) matches.set(ruleKey, value);
  }
  if (Array.isArray(value)) {
    for (const item of value) visit(item);
    return;
  }
  for (const child of Object.values(value)) visit(child);
}

visit(roots);
for (const [type, block] of matches) {
  console.log(`\n=== ${type} ===`);
  if (!block) {
    console.log("NOT FOUND");
    continue;
  }
  const shown = structuredClone(block);
  (function removeChains(value) {
    if (!value || typeof value !== "object") return;
    if (!Array.isArray(value)) delete value.next;
    for (const child of Object.values(value)) removeChains(child);
  })(shown);
  console.log(JSON.stringify(shown, null, 2));
}
