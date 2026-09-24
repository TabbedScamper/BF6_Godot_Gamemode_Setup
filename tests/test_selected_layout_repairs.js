const assert = require('assert');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const read = relative => JSON.parse(fs.readFileSync(path.join(root, relative), 'utf8'));
const candidates = read('addons/bf6_gamemode_setup/data/operations_candidates.json').maps;
const koth = read('addons/bf6_gamemode_setup/data/koth_candidates.json').maps;
const progressive = read('addons/bf6_gamemode_setup/data/progressive_links.json').layouts;
const id = row => `${row.partition}#${row.instance_guid}`;

for (const mode of ['rush', 'breakthrough']) {
  const key = `mp_aftermath_portal/${mode}`;
  assert.strictEqual(progressive[key].sectors.length, 3, key);
  const doc = read(`data/mp_aftermath_portal_${mode}.layout.json`);
  const manifestIds = new Set(doc.elements.map(id));
  for (const sector of progressive[key].sectors) {
    assert(manifestIds.has(sector.id), `${key}: selected sector absent from export`);
    assert(sector.objectives.length > 0, `${key}: empty selected sector`);
    for (const objective of sector.objectives) {
      assert(sector.members.includes(objective.entity), `${key}: unlinked objective`);
      assert(manifestIds.has(objective.entity), `${key}: selected objective absent from export`);
    }
  }
}
for (const map of ['mp_contaminated', 'mp_subsurface']) {
  const doc = read(`data/${map}_operations.layout.json`);
  const elements = new Set(doc.elements.map(id));
  const objects = new Set(doc.objects.map(row => id(row.raw || {})));
  const shapes = new Set(doc.capture_shapes.map(row => row.controller_instance_guid));
  let captureCount = 0;
  for (const sector of candidates[map].sectors) {
    assert(elements.has(sector.sector), `${map}: missing sector`);
    for (const member of sector.hqs) {
      assert(elements.has(member) && objects.has(member), `${map}: missing selected HQ ${member}`);
    }
    for (const member of sector.captures) {
      assert(elements.has(member) && shapes.has(member.split('#')[1]),
        `${map}: missing selected capture/area ${member}`);
      captureCount++;
    }
  }
  assert.strictEqual(doc.cross_mode_selected_elements.selected_count,
    candidates[map].sectors.reduce((n, s) => n + 1 + s.captures.length + s.hqs.length, 0));
  console.log(`${map} Operations: ${candidates[map].sectors.length} sectors, ${captureCount} exact areas`);
}
for (const map of ['mp_atoll', 'mp_contaminated', 'mp_limestone']) {
  const mode = map === 'mp_limestone' ? 'kingofthehill' : 'koth';
  const doc = read(`data/${map}_${mode}.layout.json`);
  const controllers = new Set(doc.elements.filter(row => row.gem === 'gem_capturepoint')
    .map(row => row.instance_guid.toLowerCase()));
  for (const guid of koth[map].capture_guids) {
    assert(controllers.has(guid), `${map}: selected hill missing ${guid}`);
  }
  if (map !== 'mp_limestone') {
    const alias = read(`data/${map}_kingofthehill.layout.json`);
    assert.strictEqual(alias.selected_graph_alias.installed_selected_graph_mode, 'koth');
    assert.deepStrictEqual(alias.objects, doc.objects);
    assert.deepStrictEqual(alias.elements, doc.elements);
  }
  console.log(`${map} KOTH: ${koth[map].capture_guids.length} selected hills`);
}
console.log('Selected layout repairs: PASS');
