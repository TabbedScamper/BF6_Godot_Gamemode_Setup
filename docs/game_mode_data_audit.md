# Installed game-mode data audit

This audit records what the installed Battlefield 6 data exposes and how it
can map to Portal SDK 1.4.3 objects. Community templates are not a source for
positions, geometry, vehicle identity, or gameplay behavior.

## Shared map gameplay

The original extractor scanned playable mode layers but deliberately skipped
`Gameplay_Global`. That omitted map-wide objects used by several modes:

- `gem_specialcombatarea`: the map's surrounding combat-space controller.
- `gem_deploycam`: the authored deploy-camera placement.
- `gem_gameend` and, on some maps, `gem_gameend_scene`.
- Global stationary emplacements and automatic AA on some maps.

Wake Island (`mp_atoll`) proves the surrounding-area case. Its Conquest layer
contains three 300 m polygons: two base areas and the inner infantry boundary.
The separate `Gameplay_Global` partition contains `gem_specialcombatarea` and
the authoritative 12-point outer polygon:

- instance GUID: `adf6e4b1-5197-4dda-a6d8-3e52178fcb63`
- area: 9,459,589 m2
- authored plane: 408.430176 m
- source: `game/glaciermp/levels/mp_atoll/_layers_gameplay/gameplay_global`

The plugin maps the Conquest inner polygon to `CombatArea.CombatVolume` and
this global polygon to `CombatArea.SurroundingVolume`. It does not duplicate or
scale the inner polygon to manufacture an air boundary.

Other global special-combat polygons were found on Abbasid, Battery, and
Limestone. Aftermath and its Portal version place the special-combat GEM but do
not embed a vector polygon in the same partition, so their geometry still
requires following the controller's external/runtime shape source.

## Mode elements currently omitted by the classifier

The raw installed-data census found these high-value GEM families. Placement
counts below are across the installed maps successfully mounted by the audit.

| GEM family | Placements | Likely Portal mapping / work required |
|---|---:|---|
| `gem_insertion` | 1,484 | `SpawnPoint`; implemented as authored HQ insertion records when an HQ exists |
| `gem_sector` | 392 | `Sector`; decode sector index and area/retreat/advance bindings |
| `gem_capturepoint` | 470 | `CapturePoint`; use as identity and property authority rather than spatial lettering |
| `gem_capturepoint_outlinearea` | 166 | capture outline/additional area; determine exact SDK property binding |
| `gem_deploycam` | 50 total placements | `DeployCam`; implemented with authored transform and source identity |
| `gem_vehiclespawner_forward` | 52 | objective-controlled forward vehicle spawner; decode team/phase enable conditions |
| `gem_checkpoint` | 25 | Payload checkpoint; Portal SDK has no dedicated checkpoint class |
| `gem_payload` | 12 | Payload route/controller; Portal SDK has no dedicated payload class |
| `gem_objectivegroup` | 3 | Carrier Strike objective grouping; inspect graph pins and group membership |
| `gem_destructiblezone` | 30 | Sabotage objective zone; candidate `AreaTrigger` plus objective logic |
| `gem_reinforcement` | 18 | Operations reinforcement logic; no direct SDK class identified |
| `gem_alternatespawnarea` | 18 | Team Deathmatch alternate spawn area; candidate `AreaTrigger`/spawn set |
| `gem_phasebasedspawnarea` | 17 | King of the Hill phase spawn areas; requires phase-condition translation |

Telemetry areas are retained in the raw census but must not be promoted into
play areas. They are analytics geometry, not player boundaries.

## Portal inspector targets

Confirmed SDK fields relevant to the next decoding pass:

- `CombatArea`: `CombatVolume`, `SurroundingVolume`, `ExclusionVolume`,
  `TimeToReturn`, `TimeToReturnSurrounding`, `Team`.
- `Sector`: `SectorArea`, `RetreatArea`, `RetreatFromArea`, `AdvanceFromArea`,
  `AdvanceToArea`, `HQs`, `CapturePoints`, `MCOMs`.
- `CapturePoint`: `CaptureArea`, `AdditionalCaptureArea`, both team spawn
  arrays, `InitialOwner`, and tactical/deploy-camera properties.
- `HQ_PlayerSpawner`: `HQArea`, `HQProtectionAreaVolume`, `InfantrySpawns`,
  `ForwardSpawns`, `VehicleSpawners`.
- `Bomb`: `AllowedBombPlayspace`.

The next reliable step is to preserve raw GEM rows and their graph bindings in
the manifest, then map fields only when a graph edge, instance parameter, or
SDK property establishes the relationship. Spatial proximity remains a
fallback and must be labeled as inference.

## Placement-binding census and the runtime boundary

A dedicated installed-data census now expands every `InstanceParameters`
entry on placed GEMs across the supported maps. It measured 1,101 bindings
(2,573 target-field rows). Every measured placement override is spatial:
capture vector shapes, automatic-AA protection cylinders, destructible zones,
psy-gas zones, and gadget-blocking geometry. No placement serializes a scalar
team, owner, enabled state, sector membership, or forward-vehicle activation.

This closes an important ambiguity. Fields such as `OwnerTeam`,
`InitialOwner`, `SectorInfo.SelectedObjectives`, and
`ForwardSpawnerEnabled` exist in the installed interfaces, but their live
values are supplied by schematic/runtime providers. They cannot be recovered
from the placed map records by reading another scalar offset. The plugin maps
what Portal can express (`SpawnIfMatchingTeam`, sector arrays, SDK team fields)
and labels spatial associations as such; it does not present those inferred
relationships as serialized retail values.

Capture points have two measured spatial parameter slots. `0x5C3A072B`
resolves to the authored `VectorShapeAsset` used for `CaptureArea`.
`0xD76BE5B2` targets the same wrapper type but is null on the measured
placements. It is therefore retained as an optional secondary/runtime slot,
not duplicated into a fabricated `AdditionalCaptureArea`.

## Mode-specific objective materialization

The builder no longer treats every objective-sized polygon as a Conquest
capture point or places every capture candidate in one catch-all sector.

- Rush uses sector-owned M-COMs only.
- Payload exposes exact payload/checkpoint transforms as runtime markers,
  because Portal SDK 1.4.3 has no matching gameplay classes.
- Sabotage exposes exact destructible-zone controllers and their matched
  authored polygons, without substituting CapturePoint behavior.
- Obliteration and Squad Obliteration place M-COMs and bomb-spawn candidates
  under Objectives; M-COMs use the SDK's carried-object arming contract.
- Carrier Strike exposes VLS batteries and objective groups as sourced runtime
  markers alongside the SDK-representable capture/M-COM objects.
- KOTH, Strikepoint, and Escalation retain exact sector placements separately
  from candidate capture points. Their live membership/activation is marked
  runtime-fed instead of being flattened into a simultaneous Conquest sector.
- Team and Squad Deathmatch never materialize CapturePoints from geometric
  classifier false positives.

## Embedded GEM inspector schemas

The installed GEM type metadata publishes its parameter names. These are not
names inferred from placement or community scenes; they are strings embedded
in the retail EBX type definitions. High-value matches to SDK 1.4.3 include:

- `gem_deploycam`: `ObjId`, `VerticalOffsetFactor`,
  `VerticalSafeAreaFactor` -- an exact SDK `DeployCam` class match.
- `gem_sector`: `SectorEnabled`, `AutoEnableVehicles`, `SectorName`, `ObjId`,
  `SectorValue`, `SecondarySectorValue`, and runtime `SectorInfo`.
- `gem_capturepoint`: `Enabled`, `InitialOwner`, `ActiveProxy`, `FlagPoleSize`,
  `ObjId`, camera/tactical fields, outline fields, and objective spawn limits.
- `gem_vehiclespawner_forward`: the normal vehicle-spawner parameter set,
  including `VehicleType`, `P_AutoSpawnEnabled`, `P_DefaultRespawnTime`,
  `SpawnIfMatchingTeam`, `MatchingTeam`, `EnableRespawn`, and
  `EnabledOverride`.
- `gem_payload`: `PayloadCaptureRadius`, `OutlineHeightMultiplier`, and
  `ObjectiveInfo`; still no Portal SDK payload class exists.
- `gem_destructiblezone`: outline controls and `ObjectiveInfo`; this establishes
  objective semantics but does not make it interchangeable with `AreaTrigger`.

Manifest schema 3 retains every retail GEM placement for the selected mode and
the map-global layer in a separate `elements` array. The builder currently
materializes only mappings with a direct SDK class match. `gem_deploycam` is the
first such mapping: a mode-local camera is preferred when authored, otherwise
the map-global camera is used, and its complete retail transform is preserved.

## Decoded-name impact and Rush selection

The research repository's current TypeInfo corpus materially improves this
audit. All but one of the eight formerly anonymous shape-owner GUIDs observed
in the game-mode census now have useful identities. They include
`SoundLabelAreaEntityData`, `SoundContextEntityData`,
`DynamicDestructionDepthEntityData`, `GameplayVolumeEntityData`,
`DiceObstacleEntityData`, `DiceObstacleComponentData`, and
`GeometryTriggerEntityData`. These names prevent audio, destruction,
pathfinding, and generic trigger geometry from being mislabeled as a Portal
play area merely because it contains a polygon.

The same corpus confirms that `gem_sector` exposes `SectorInfo`, whose nested
`SelectedObjectives` member is supplied by the runtime graph. It is not an
instance parameter on each placed sector. Mirak Valley (`mp_tungsten`) is the
important control case: its Rush placement layer retains 15 MCOM GEM records
(13 unique positions), while its enclosing Rush interface publishes eight
live links and the map has four sector GEMs. The generated Portal layout thus
uses at most two nearest authored MCOMs per authored sector (eight live slots),
retains every raw candidate in manifest schema 3, and records the selection
basis as metadata. This is explicitly a graph-bounded spatial inference; the
retail graph does not publish a direct candidate-GUID-to-sector array.

Sector order is no longer taken from arbitrary root-array order. Rush and
Breakthrough sectors are sorted outward from the earliest authored HQ-chain
endpoint, then their A/B objectives are assigned. This uses game-authored HQ
and sector placement/order data and avoids importing any community-authored
spatial values.

## Automatic-AA protection binding

Decoded names corrected an earlier geometric assumption here. The
`gem_automaticaa` instance parameter whose property hash is `0xD7DAD1C4`
targets a local wrapper. Its `AdditionalShapes` field points to
`CylinderData`, not `OBBData`. On Atoll Conquest, for example, both authored
cylinders have 157.883636 m X/Z radii and a 33.6062012 m half-height, and each
has its own installed instance GUID.

The extractor now retains this exact GEM-parameter-to-cylinder edge. The
builder converts the authored cylinder transform, radius, and height into a
32-sided SDK `PolygonVolume`, parents it beneath the corresponding automatic
AA, and assigns the result to `ProtectionAreaVolume`. Portal SDK 1.4.3 exposes
no cylinder-volume class, so polygon tessellation is the only representation
conversion in that chain. The former nearest-HQ-area assignment remains only
as a labeled fallback for older manifests with no retained binding.

`OwnerTeam` is a decoded automatic-AA interface field, but it is not stored as
a scalar override on the measured Atoll placements. The generated team value
therefore remains a labeled HQ-anchor inference until the selector/runtime
route that supplies `OwnerTeam` is proven. A decoded field name establishes
the destination contract; it does not by itself establish a placed value.

## HQ insertion spawns

`gem_insertion` exposes `TeamId`, `SquadId`, `SnapToTerrain`, and `LightType` in
its installed interface contract. The placement distribution supplies the
missing structural evidence: every supported Conquest map has exactly 16 such
records, arranged as two eight-point clusters around its authored HQs. Atoll's
older nearest-spawn pass selected only four `AlternateSpawnEntityData` rows per
HQ, which reproduces the reported four-spawn symptom.

The builder now materializes each `gem_insertion` transform as an SDK
`SpawnPoint`, assigns it to its nearest authored HQ, and includes it in that
HQ's `InfantrySpawns` array. It also retains the lower-level alternate-spawn
rows because they are distinct installed records; those continue to populate
capture/HQ arrays through their existing authored flag or spatial association.
The insertion transform and instance GUID are exact. The HQ association is
recorded as an authored-cluster spatial join because the measured placement
does not serialize `TeamId` as a scalar override.

## Complete measured GEM-family disposition

The supported installed-map census contains 48 named GEM families. “Retained”
means the schema-3 manifest preserves the placement and provenance but the
builder does not pretend that an SDK class with different behavior is an exact
replacement.

| Family | Count | Portal SDK disposition |
|---|---:|---|
| `gem_vehiclespawner` | 1,675 | `VehicleSpawner`, implemented; class selector is game-derived, ownership association may be spatial/runtime-fed |
| `gem_insertion` | 1,484 | `SpawnPoint`, implemented as HQ insertion records |
| `gem_telemetryarea` | 690 | excluded analytics geometry |
| `gem_hq` | 594 | `HQ_PlayerSpawner`, implemented |
| `gem_capturepoint` | 470 | `CapturePoint`, implemented where the mode uses capture objectives |
| `gem_sector` | 392 | `Sector`, implemented for Rush/Breakthrough with documented runtime-fed membership gap |
| `gem_destructible` | 384 | retained; no dedicated SDK gameplay class |
| `gem_stationaryspawner` | 325 | `StationaryEmplacementSpawner`, implemented |
| `gem_vehicleresupplystation` | 194 | `VehicleResupplyStation`, implemented |
| `gem_objective_mcom` | 186 | `MCOM`, implemented for Rush |
| `gem_capturepoint_outlinearea` | 166 | retained; parameter contract decoded, no standalone SDK node |
| `gem_battle_pickup` | 141 | retained; SDK `LootSpawner` cannot express the authored pickup identity |
| `gem_psygaszone` | 81 | retained; no proven SDK equivalent |
| `gem_specialcombatarea` | 68 | exact surrounding-volume source where its polygon resolves; no standalone SDK class |
| `gem_vehiclespawner_forward` | 52 | `VehicleSpawner`, implemented; capture-state enabling is runtime-fed |
| `gem_gauntlet_jetsonly_stockpile` | 51 | retained; mode-specific runtime logic |
| `gem_deploycam` | 50 | `DeployCam`, implemented exactly by transform/source identity |
| `gem_bomb_pickup` | 40 | `Bomb`, implemented |
| `gem_automaticaa` | 36 | SDK automatic AA, implemented; exact bound protection shape when resolvable |
| `gem_mine` | 31 | retained; no SDK class |
| `gem_destructiblezone` | 30 | retained; objective semantics decoded, no equivalent SDK objective class |
| `gem_collection_event` | 28 | retained runtime event logic |
| `gem_checkpoint` | 25 | retained; no SDK checkpoint class |
| `gem_gauntlet_jetsonly_cloudvfx` | 23 | retained; `VL7Cloud` equivalence is not proven |
| `gem_safespawnarea` | 22 | retained; possible `PlayerSpawner` behavior is not graph-proven |
| `gem_reinforcement_intro` | 22 | retained runtime mode logic |
| `gem_combatarea` | 21 | `CombatArea`, implemented through its graph-owned polygon |
| `gem_gameend` | 20 | retained runtime end-state logic |
| `gem_combatarea_default` | 20 | retained controller; typed combat-area geometry is materialized separately |
| `gem_psygas_activator` | 19 | retained runtime gas-state logic |
| `gem_reinforcement` | 18 | retained; ownership/battalion fields decoded, no SDK class |
| `gem_sectorspawns` | 18 | retained runtime sector-spawn controller |
| `gem_strikepoint_tweaks` | 18 | retained mode tuning |
| `gem_alternatespawnarea` | 18 | retained; area-to-spawn behavior is not directly representable |
| `gem_phasebasedspawnarea` | 17 | retained; phase condition is runtime-fed |
| `gem_gadgetblocking` | 14 | retained; bound OBB/polygon/cylinder set is not equivalent to SDK `BlockingSphere` |
| `gem_freeroam_tweaks` | 13 | retained mode tuning |
| `gem_payload` | 12 | retained; route/parameters decoded, no SDK payload class |
| `gem_psygasartillerystrike` | 11 | retained runtime event logic |
| `gem_objective_vls_battery` | 8 | retained; no proven SDK objective class |
| `gem_insertion_event` | 5 | retained runtime event logic |
| `gem_granite_preround` | 4 | retained preround logic |
| `gem_objectivegroup` | 3 | retained Carrier Strike runtime grouping |
| `gem_swaplevel` | 3 | retained runtime level transition logic |
| `gem_destructibleproxy` | 2 | retained; no SDK class |
| `gem_gameend_scene` | 2 | retained; camera/end-scene behavior is runtime-fed |
| `gem_mapbriefingoverride` | 2 | retained presentation metadata |
| `gem_proximityspawns` | 1 | retained runtime spawn controller |
