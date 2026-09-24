#!/usr/bin/env node
// The installed catalog has both KOTH and KingOfTheHill keys on two maps,
// while the layout00-selected hill graph is in mp_koth0. Use that exact graph
// for both UI names and disclose the source alias in the generated manifest.
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const data = path.join(root, 'data');
for (const map of ['mp_atoll', 'mp_contaminated']) {
  const selected = JSON.parse(fs.readFileSync(path.join(data, `${map}_koth.layout.json`)));
  const aliasPath = path.join(data, `${map}_kingofthehill.layout.json`);
  const previous = JSON.parse(fs.readFileSync(aliasPath));
  if (previous.source?.level !== selected.source?.level) {
    throw new Error(`${map}: catalog alias crosses maps`);
  }
  selected.source = {...selected.source, mode: 'kingofthehill'};
  selected.selected_graph_alias = {
    requested_catalog_mode: 'kingofthehill',
    installed_selected_graph_mode: 'koth',
    basis: 'same map; selected KOTH layout00 controller identities',
    native_kingofthehill_export_retained: false,
  };
  fs.writeFileSync(aliasPath, JSON.stringify(selected) + '\n');
  console.log(`${map}: KingOfTheHill uses exact selected KOTH graph`);
}
