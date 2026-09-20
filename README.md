# BF6 Godot Game Mode Setup

A focused Godot editor plugin for building editable Battlefield Portal game-mode layouts from installed-game data.

The current review release covers **184 shipped gameplay layers across 18 maps**. The dropdown includes Conquest, Breakthrough, Rush, Domination, Escalation, King of the Hill, Operations, Obliteration, Squad Obliteration, Sabotage, Strikepoint, deathmatch variants, and map-specific Carrier Strike, Gauntlet, and Payload layouts.

The supported map catalog includes Siege of Cairo, Empire State, Bellum1988's Operation Metro, Wake Island, Blackwell Fields, Iberian Offensive, Liberation Peak, Contaminated, Manhattan Bridge, Eastwood, Operation Firestorm, Railway to Golmud, Tsuru Reef, Saints Quarter, New Sobek City, Cairo Bazaar, Hagental Base, and Mirak Valley.

Community scenes are used only to reproduce the compatible hierarchy and Blockly/TypeScript setup method. They are not accepted as sources for gameplay objects, transforms, links, IDs, vehicle settings, volumes, cameras, or carrier placement. SDK scene internals remain scene-owned, so implementation nodes such as `Mesh`, `StaticBody3D`, and `CollisionShape3D` are not promoted into editable game-mode content.

## Install

1. Download the plugin ZIP from the [latest release](../../releases/latest), or clone this repository.
2. Copy `addons/bf6_gamemode_setup` into the `addons` folder of a Battlefield Portal Godot project.
3. In Godot, open **Project > Project Settings > Plugins** and enable **BF6 Game Mode Setup**.
4. Open a supported map scene and use the **BF6 Game Mode Setup** dock.

## Build a game mode

When a verified layout is available, open the **Game mode** dropdown and select it. The plugin downloads the gameplay layout and optional geometry from the data release, caches them in Godot's user-data directory, creates the game-mode node, and selects it in the Scene dock. Save the map scene when satisfied.

The plugin displays build progress in its Godot dock while it creates gameplay objects, vehicle previews, volumes, and optional carrier geometry. Large modes remain synchronous because Godot scene nodes must be authored on the editor thread, but explicit UI redraws keep the progress display visibly updating throughout the build.

Optional preview geometry is editor-only and can be hidden from the Scene dock. Generated mesh children are rebuilt from the downloaded asset when the scene opens and are not exported with the level.

Aircraft-carrier previews are mode-specific. Tsuru Reef receives carriers only for Carrier Strike. Wake Island receives the matching Conquest, Breakthrough, or Escalation carrier layout; its always-visible carrier pieces remain part of the base map. Each downloaded carrier branch is named so it can be hidden manually.

Selecting **Off** hides layouts without deleting them or discarding edits. The plugin will not overwrite an unrelated `Conquest` node.

**Andys Template Addons** adds the community builder's optional `TeamSwitcher`, `AI Spawns`, and `EndGameCamera` branches to the selected generated layout. It preserves the template's node names and ObjIds, links each AI spawner to its team's generated HQ infantry spawns, and places the editable objects at the origin for manual positioning.

## Notes

- The builder is deliberately map- and mode-specific. It validates Portal SDK resources before changing the scene.
- A layout is not published until its generated objects carry game-data provenance and its Portal SDK scene validates.
- Volume elevations are preserved from game data. They are not raycast or snapped to terrain.
- Vehicle and spawn arrays are not capped.
- Every generated SDK `VehicleSpawner` uses a 45-second `P_DefaultRespawnTime`.
- Retail vehicle records use spawn-category selectors rather than concrete Portal `VehicleType` values. The builder resolves each category to its shipped Team 1/Team 2 vehicle pair, groups HQ vehicles by team, and creates team-gated objective spawners while retaining the original selector as provenance.
- Verified mode-specific vehicle choices are keyed to their installed instance identity, so an HQ override does not alter legitimate uses of the same vehicle category at objectives or on other maps.
- Objective spawns are nested under their capture point with stable names. Wake Island Conquest restores the game's authored A-G lettering and includes its 11,251.8 m² G capture volume.
- Conquest base polygons are assigned directly to each SDK HQ's `HQArea`. Wake Island and Liberation Peak also promote their verified play-area polygons into an SDK `CombatArea` with the corresponding `CombatVolume` and, where present, `SurroundingVolume`.
- Generated scene trees group gameplay boundaries and the alphabetically linked `Sector` under `Play Area`, while secondary gameplay objects are grouped under `Extras`.
- Liberation Peak Conquest restores its six A-F objectives; the small cliff polygon that the generic classifier mistook for objective D is emitted as an SDK `AreaTrigger` under `Play Area/OutOfBounds`.
- Retail `gem_specialcombatarea` records have no Portal SDK gameplay class. Their exact transforms and provenance are preserved as marked evidence nodes instead of being silently dropped or converted into invented AreaTriggers.
- Golf Course, Defense Nexus, Downtown, Marina, Area 22B, Redline Storage, Complex 3, Portal Sandbox, and Portal Ocean currently expose no stock gameplay objects under their SDK scene roots. They remain cataloged but do not receive fabricated layouts.
- Layouts marked `review` expose the shipped layer faithfully while objective semantics that are not present in client data remain clearly provisional.

## License

The plugin source is available under the [MIT License](LICENSE). Battlefield and Battlefield Portal are trademarks of Electronic Arts Inc. This project is unaffiliated with and not endorsed by Electronic Arts.
