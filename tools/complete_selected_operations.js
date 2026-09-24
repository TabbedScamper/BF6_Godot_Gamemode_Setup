#!/usr/bin/env node
// Repair mode-filtered exports using only exact Operations layout00 identities.
// The selected controllers are physically stored in Breakthrough partitions on
// two maps; no proximity or wholesale cross-mode copy is permitted here.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const evidence = JSON.parse(fs.readFileSync(path.join(root,
  'addons/bf6_gamemode_setup/data/operations_candidates.json'), 'utf8'));
const identity = row => `${row.partition}#${row.instance_guid}`;
const objectIdentity = row => identity(row.raw || {});

for (const map of ['mp_contaminated', 'mp_subsurface']) {
  const target = path.join(root, 'data', `${map}_operations.layout.json`);
  const source = path.join(root, 'data', `${map}_breakthrough.layout.json`);
  const operations = JSON.parse(fs.readFileSync(target, 'utf8'));
  const breakthrough = JSON.parse(fs.readFileSync(source, 'utf8'));
  const selected = evidence.maps[map].sectors.flatMap(sector =>
    [sector.sector, ...sector.captures, ...sector.hqs]);
  if (new Set(selected).size !== selected.length) {
    throw new Error(`${map}: selected Operations identities are duplicated`);
  }
  const elements = new Map(breakthrough.elements.map(row => [identity(row), row]));
  const objects = new Map(breakthrough.objects.map(row => [objectIdentity(row), row]));
  const currentElements = new Set(operations.elements.map(identity));
  const currentObjects = new Set(operations.objects.map(objectIdentity));
  const shapeByGuid = new Map((breakthrough.capture_shapes || [])
    .map(row => [row.controller_instance_guid, row]));
  const currentShapes = new Set((operations.capture_shapes || [])
    .map(row => row.controller_instance_guid));
  const captures = new Set(evidence.maps[map].sectors.flatMap(s => s.captures));
  for (const id of selected) {
    const element = elements.get(id);
    if (!element) throw new Error(`${map}: selected game element unavailable: ${id}`);
    if (!currentElements.has(id)) operations.elements.push(element);
    const object = objects.get(id);
    if (object && !currentObjects.has(id)) operations.objects.push(object);
    if (captures.has(id)) {
      const guid = id.split('#')[1];
      const shape = shapeByGuid.get(guid);
      if (!shape || !Array.isArray(shape.world_points) || shape.world_points.length < 9) {
        throw new Error(`${map}: exact capture boundary unavailable: ${id}`);
      }
      if (!currentShapes.has(guid)) operations.capture_shapes.push(shape);
    }
  }
  operations.cross_mode_selected_elements = {
    basis: 'Operations layout00-selected full partition#GUID identities',
    source_mode: 'breakthrough',
    selected_count: selected.length,
  };
  operations.counts.objects = operations.objects.length;
  fs.writeFileSync(target, JSON.stringify(operations) + '\n');
  console.log(`${map}: ${selected.length} selected identities, ` +
    `${captures.size} exact capture boundaries`);
}
