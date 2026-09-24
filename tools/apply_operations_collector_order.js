#!/usr/bin/env node
// Apply exact Operations layout00 collector sibling-link order to the four
// populated selected sets. This is candidate order, not live phase activation.
const fs = require('fs');
const path = require('path');

const file = path.resolve(__dirname,
  '../addons/bf6_gamemode_setup/data/operations_candidates.json');
const document = JSON.parse(fs.readFileSync(file, 'utf8'));
const order = {
  mp_capstone: [
    '1b888515-cfc2-4fe9-8155-6cdec4465b8a',
    '021a7ddd-c309-4586-9ed2-ad067e0689b7',
    '21f17fc7-aa7a-4ddd-8068-065d41d1409d',
    '75f8d6ec-96db-4530-9232-bfbcc314c15b',
    '78ca4ded-2c27-4647-9790-ef772b298b54',
  ],
  mp_contaminated: [
    'dcd03683-cdbb-453e-8a26-7ecc5fe4b02f',
    'b9c98f6b-98a6-41aa-a3c4-da9f91b96481',
    '089e6c9c-123a-4507-91d5-2d8c1a062e53',
    'a5eb676b-e603-40a9-bf91-abf7c794056e',
    'fbd59704-bc46-4181-bcd8-1b2f93803a2f',
  ],
  mp_tungsten: [
    '9fc6c589-0816-4f04-ba2b-0615ce63124c',
    '846226c4-5c3d-4d6a-9aa6-396a38b9c60d',
    '5ba2f271-5f0a-4b76-9811-0ba07ce3192f',
  ],
  mp_subsurface: [
    '42ae16af-ad9d-4a2c-9ff2-a7855f3efb92',
    '4134beaf-3482-4e30-9fd9-508cae4c815d',
    '2f1cab66-284f-46bf-b2dd-afa979e63c53',
    '4dc6c3ea-c756-4ce1-8f56-9838e9bb088c',
  ],
};

for (const [map, guids] of Object.entries(order)) {
  const record = document.maps[map];
  if (!record || record.sectors.length !== guids.length) {
    throw new Error(`${map}: sector count differs from the audited collector`);
  }
  const byGuid = new Map(record.sectors.map(row => [row.sector.split('#')[1], row]));
  if (byGuid.size !== guids.length || guids.some(guid => !byGuid.has(guid))) {
    throw new Error(`${map}: exact selected sector identities differ`);
  }
  record.sectors = guids.map(guid => byGuid.get(guid));
  record.order_basis = 'installed Operations layout00 collector sibling links';
  record.order_status = 'authored candidate order; live phase and battalion order unverified';
}
document.scope = 'Exact selected membership and authored collector candidate order; live phase/battalion order unverified';
fs.writeFileSync(file, JSON.stringify(document, null, 2) + '\n');
console.log('Operations collector order applied to four selected map sets');
