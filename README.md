# BF6 Godot Game Mode Setup

A focused Godot editor plugin for building editable Battlefield Portal game-mode layouts from installed-game data.

The current review release covers **184 shipped gameplay layers across 18 maps**. The dropdown includes Conquest, Breakthrough, Rush, Domination, Escalation, King of the Hill, Operations, Obliteration, Squad Obliteration, Sabotage, Strikepoint, deathmatch variants, and map-specific Carrier Strike, Gauntlet, and Payload layouts.

The supported map catalog includes Siege of Cairo, Empire State, Bellum1988's Operation Metro, Wake Island, Blackwell Fields, Iberian Offensive, Liberation Peak, Contaminated, Manhattan Bridge, Eastwood, Operation Firestorm, Railway to Golmud, Tsuru Reef, Saints Quarter, New Sobek City, Cairo Bazaar, Hagental Base, and Mirak Valley.

Community scenes are used only to audit the compatible hierarchy and Blockly/TypeScript setup method. They are not accepted as sources for gameplay objects, transforms, links, vehicle settings, volumes, cameras, or carrier placement. Where Rush or Breakthrough requires a public Portal ObjId contract, the game-derived SDK object receives that compatibility ID and explicit `bf6_template_modified` metadata explaining the change. Compatibility aliases are identified as non-retail instances. SDK scene internals remain scene-owned, so implementation nodes such as `Mesh`, `StaticBody3D`, and `CollisionShape3D` are not promoted into editable game-mode content.

## Install

1. Download the plugin ZIP from the [latest release](../../releases/latest), or clone this repository.
2. Copy `addons/bf6_gamemode_setup` into the `addons` folder of a Battlefield Portal Godot project.
3. In Godot, open **Project > Project Settings > Plugins** and enable **BF6 Game Mode Setup**.
4. Open a supported map scene and use the **BF6 Game Mode Setup** dock.

## Build a game mode

When a verified layout is available, open the **Game mode** dropdown and select it. The dock shows a plain-language description of that mode's objective flow before building. The plugin downloads the gameplay layout and optional geometry from the data release, caches them in Godot's user-data directory, creates the game-mode node, and selects it in the Scene dock. Save the map scene when satisfied. The mode-specific construction rules and known evidence gaps are documented in [the behavior contract](docs/mode_behavior_contract.md); the start/progression/end requirements recovered from retail graphs are tracked in [the runtime state-machine audit](docs/runtime_state_machine_audit.md).

The plugin displays build progress in its Godot dock while it creates gameplay objects, vehicle previews, volumes, and optional carrier geometry. Large modes remain synchronous because Godot scene nodes must be authored on the editor thread, but explicit UI redraws keep the progress display visibly updating throughout the build.

The stock SDK `VEH_*` vehicle and emplacement markers are the default. Enable **High-poly vehicle and emplacement previews** in the plugin dock to replace them with bundled untextured game geometry using a neutral SDK-white material. The opt-in previews are editor-only, are not exported with the level, and are removed immediately when the toggle or addon is disabled. No SDK source scene is modified. Verified separate wheels, tank tracks, and mounted parts are assembled into their authored positions; passenger variants reuse the matching canonical vehicle model.

Aircraft-carrier previews are mode-specific. Tsuru Reef receives carriers only for Carrier Strike. Wake Island receives the matching Conquest, Breakthrough, or Escalation carrier layout; its always-visible carrier pieces remain part of the base map. Each downloaded carrier branch is named so it can be hidden manually.

Selecting **Off** hides layouts without deleting them or discarding edits. The plugin will not overwrite an unrelated `Conquest` node.

**Swap Team 1 / Team 2** reverses the imported faction sides without rebuilding the layout. It swaps HQ ownership, team spawn arrays, AA ownership, faction-specific vehicle choices, objective-vehicle team IDs, and the corresponding scene-tree labels. Pressing it again restores the original assignment.

**Andys Template Addons** adds the community builder's optional `TeamSwitcher`, `AI Spawns`, and `EndGameCamera` branches to the selected generated layout. It preserves the template's node names, ObjIds, team-switch child offsets, and FixedCamera model orientation, links each AI spawner to its team's generated HQ infantry spawns, and places the editable parent objects at the origin for manual positioning.

Those optional branches are never included by a normal game-mode build. The
button is the explicit opt-in boundary between a game-data-first layout and the
creator-template conveniences.

## Notes

- The builder is deliberately map- and mode-specific. It validates Portal SDK resources before changing the scene.
- A layout is not published until its generated objects carry game-data provenance and its Portal SDK scene validates.
- Volume elevations are preserved from game data. They are not raycast or snapped to terrain.
- Vehicle and spawn arrays are not capped.
- Every generated SDK `VehicleSpawner` uses a 45-second `P_DefaultRespawnTime`.
- Stationary emplacements and unresolved `VehicleType = -1` spawners enable `P_AutoSpawnEnabled` by default.
- Vehicle preview skins update from inspector/selection events. The plugin does not repeatedly scan every vehicle spawner while the editor is idle.
- Vehicle preview assets contain visual meshes only. They add no `StaticBody3D`, collision shape, or physics node to the generated game mode.
- Rush and Breakthrough use exact selected game-layout identities and links for sector order, objective/MCOM membership and order, HQs, spawns, vehicles, and typed areas. The builder does not use distance, polygon containment, or root-order guesses for those relationships. Unresolved or empty selected layouts are refused rather than filled with nearby objects. Team 1 attacking and Team 2 defending are verified authored defaults for the standard layout; live playlist overrides are outside this claim. Portal sector wrappers, object IDs, Breakthrough initial ownership, and any required non-zero polygon extrusion are labeled as Blockly compatibility choices, not retail data. See [the exact-link importer contract](docs/progressive_exact_links.md) for scope and exceptions.
- Exact Rush/Breakthrough vehicle records are grouped under `Vehicles/HQ/Team1|Team2/SectorN`, `Vehicles/Objectives/SectorN/<objective>`, or `Vehicles/Sectors/SectorN` according to their authored membership ancestry. Contaminated Breakthrough's 23 vehicles without a selected HQ/sector ancestor are now grouped beneath their eight exact layout-selected schematic parents in `Vehicles/Schematic Groups`; this does not prove when those groups activate. Only genuinely unresolved or multi-owner records remain under `Vehicles/Unassigned`.
- Generated roots carry the installed game's decoded mode-mutator defaults as `bf6_retail_mode_defaults` metadata where available. These values are reference inputs for Portal logic, not silently applied to unrelated SDK properties or claimed as effective live-server settings.
- KOTH now retains the exact selected game-layout hill candidate identities and authored sector-link order for 15 maps. That order is exposed on the generated root and runtime sector as metadata; it is **not** claimed as the live hill-rotation schedule. Atoll and Contaminated's empty `kingofthehill` aliases and Limestone's extra-candidate export are refused rather than built as falsely exact layouts.
- Operations links selected sector candidates to their exact HQ and CapturePoint arrays on Capstone, Contaminated, Tungsten, and Subsurface. Cross-partition selected controllers on the latter two maps are included. The scene tree follows the installed collector's authored candidate order and labels `SectorCandidate_01`, etc.; this is not proven live gameplay phase or battalion order.
- Payload shows an exact game-spline `Path3D` beneath the selected Payload marker on Capstone, Abbasid, Badlands, Battery, Dumbo, and Outskirts. Its world-space samples keep their authored heights and exact controller attachment. Atoll, Contaminated, Plaza, and Subsurface have no proved spline attachment and get no fabricated route. These paths are editor previews, not Portal Payload gameplay objects.
- Obliteration and Squad Obliteration now link each of their seven selected sector candidates to the exact HQ and MCOM arrays and retain the authored bomb-site candidates. Twelve Obliteration bomb placements per map are candidates, not twelve simultaneously active bombs; the live selection rule remains outside the scene data.
- Retail vehicle GEM field `0x783E16EC` selects a vehicle-class prefab in the installed mode ActivityData. The builder follows that class prefab's faction picker into `ModBuilder_Enum_VehicleList`, assigns the correct concrete SDK vehicle at each HQ, and creates Team 1/Team 2 gated variants for faction-dependent objective pads.
- Objective spawns are nested under their capture point with stable names. Conquest layouts join polygons to installed `gem_capturepoint` identities and use audited game-root-to-letter mappings instead of world-position ordering. False heuristic captures are demoted, missed game capture volumes are restored, and linked spawns follow the corrected objective. Wake Island includes its 11,251.8 m² G capture volume.
- Conquest base polygons are assigned directly to each SDK HQ's `HQArea`. Wake Island and Liberation Peak also promote their verified play-area polygons into an SDK `CombatArea` with the corresponding `CombatVolume` and, where present, `SurroundingVolume`.
- Generated scene trees use the stable top-level order `Play Area`, `TEAM_1_HQ`, `TEAM_2_HQ`, `Objectives`, `Spawns`, `Vehicles`, `Emplacements`, `Resupply`, `AA-Defences`, `Extras`, and `Aircraft Carriers`. Empty generated categories are removed.
- The `Objectives` branch and objective-vehicle groups are alphabetical. HQ vehicles remain under `Vehicles/HQ/Team1|Team2`; objective vehicles use `Vehicles/Objectives/Objective_A|B|.../Team1|Team2|Shared`; stationary weapons, resupply stations, and automatic AA each have their own top-level category.
- Conquest objective vehicle IDs reserve five slots per side and objective: A uses Team 1 `600-604`, Team 2 `605-609`; B uses `610-614` and `615-619`; later objectives continue the same pattern. Shared or overflow pads use `-1` and enable `P_AutoSpawnEnabled`.
- Automatic AA keeps its game-linked protection volume. When its placement has no team value, Portal `OwnerTeam` is inferred from a containing HQ area, then the nearest assigned HQ if necessary; the choice and its basis are labeled in node metadata. It is not claimed as a serialized retail team value.
- Generated scene-tree labels omit source GUID fragments and raw root-order numbers. Team, sector, objective, and sequential duplicate numbers remain where they clarify the layout or preserve template conventions; source identities stay in metadata.
- Rush and Breakthrough polygons are grouped below their linked sector, objective, or HQ controller with role-based names. `SectorArea` is the Portal sector gameplay area; Retreat/Advance area references are retained as game-data links without claiming those SDK fields drive the sector logic.
- Aircraft-enabled Conquest layouts bind a graph-identified `gem_specialcombatarea` polygon to `CombatArea.SurroundingVolume` when the installed map provides one (including Wake Island's map-global boundary). Older manifests retain the measured area-order fallback; the inner `CombatVolume` remains separate.
- Liberation Peak Conquest restores its six A-F objectives; the small cliff polygon that the generic classifier mistook for objective D is emitted as an SDK `AreaTrigger` under `Play Area/OutOfBounds`.
- Retail `gem_specialcombatarea` records have no Portal SDK gameplay class. Their controller records are used only to identify an authored surrounding combat volume; the plugin does not add a misleading `Special Area 1` node.
- Manhattan Bridge and Blackwell Fields suppress unclaimed bridge, rooftop, and box geometry that the generic classifier previously exposed as play boundaries. Empire State selects the two playable HQ records through their authored insertion clusters, ignores the inactive third HQ candidate and unowned map-global boxes, assigns the two authored base areas, and keeps the larger combat zone separate.
- Liberation Peak objective B and E vehicle pads use the game-observed Abrams/Leopard pairing; the two HQ pads retain their game-observed Flyer 60 correction. The hidden Railway to Golmud golf cart remains because it is present in the installed layout data.
- Golf Course, Defense Nexus, Downtown, Marina, Area 22B, Redline Storage, Complex 3, Portal Sandbox, and Portal Ocean currently expose no stock gameplay objects under their SDK scene roots. They remain cataloged but do not receive fabricated layouts.
- Layouts marked `review` expose the shipped layer faithfully while objective semantics that are not present in client data remain clearly provisional.

## License

The plugin source is available under the [MIT License](LICENSE). Battlefield and Battlefield Portal are trademarks of Electronic Arts Inc. This project is unaffiliated with and not endorsed by Electronic Arts.
