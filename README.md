# BF6 Godot Game Mode Setup

A focused Godot editor plugin for building editable Battlefield Portal game-mode layouts from installed-game data.

The current review release covers 24 gameplay layers across **Tsuru Reef (`MP_Isolated`)** and **Wake Island (`MP_Atoll`)**. The dropdown includes Conquest, Breakthrough, Rush, Domination, Escalation, King of the Hill, Sabotage, Strikepoint, team deathmatch variants, and the map-specific Carrier Strike, Gauntlet, and Payload layouts.

Community scenes are used only to reproduce the compatible hierarchy and Blockly/TypeScript setup method. They are not accepted as sources for gameplay objects, transforms, links, IDs, vehicle settings, volumes, cameras, or carrier placement. SDK scene internals remain scene-owned, so implementation nodes such as `Mesh`, `StaticBody3D`, and `CollisionShape3D` are not promoted into editable game-mode content.

## Install

1. Download the plugin ZIP from the [latest release](../../releases/latest), or clone this repository.
2. Copy `addons/bf6_gamemode_setup` into the `addons` folder of a Battlefield Portal Godot project.
3. In Godot, open **Project > Project Settings > Plugins** and enable **BF6 Game Mode Setup**.
4. Open the `MP_Isolated` or `MP_Atoll` map scene and use the **BF6 Game Mode Setup** dock.

## Build a game mode

When a verified layout is available, open the **Game mode** dropdown and select it. The plugin downloads the gameplay layout and optional geometry from the data release, caches them in Godot's user-data directory, creates the game-mode node, and selects it in the Scene dock. Save the map scene when satisfied.

Optional preview geometry is editor-only and can be hidden from the Scene dock. Generated mesh children are rebuilt from the downloaded asset when the scene opens and are not exported with the level.

Aircraft-carrier previews are mode-specific. Tsuru Reef receives carriers only for Carrier Strike. Wake Island receives the matching Conquest, Breakthrough, or Escalation carrier layout; its always-visible carrier pieces remain part of the base map. Each downloaded carrier branch is named so it can be hidden manually.

Selecting **Off** hides layouts without deleting them or discarding edits. The plugin will not overwrite an unrelated `Conquest` node.

## Notes

- The builder is deliberately map- and mode-specific. It validates Portal SDK resources before changing the scene.
- A layout is not published until its generated objects carry game-data provenance and its Portal SDK scene validates.
- Volume elevations are preserved from game data. They are not raycast or snapped to terrain.
- Vehicle and spawn arrays are not capped.
- Layouts marked `review` expose the shipped layer faithfully while objective semantics that are not present in client data remain clearly provisional.

## License

The plugin source is available under the [MIT License](LICENSE). Battlefield and Battlefield Portal are trademarks of Electronic Arts Inc. This project is unaffiliated with and not endorsed by Electronic Arts.
