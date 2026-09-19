# BF6 Godot Game Mode Setup

A focused Godot editor plugin for building complete Battlefield Portal game-mode layouts from verified game data.

The first target layout is **Tsuru Reef (`MP_Isolated`) Conquest**. It is temporarily unavailable while every object and property is revalidated against shipped game data.

Community scenes are used only to reproduce the compatible hierarchy and Blockly/TypeScript setup method. They are not accepted as sources for gameplay objects, transforms, links, IDs, vehicle settings, volumes, cameras, or carrier placement. SDK scene internals remain scene-owned, so implementation nodes such as `Mesh`, `StaticBody3D`, and `CollisionShape3D` are not promoted into editable game-mode content.

## Install

1. Download the plugin ZIP from the [latest release](../../releases/latest), or clone this repository.
2. Copy `addons/bf6_gamemode_setup` into the `addons` folder of a Battlefield Portal Godot project.
3. In Godot, open **Project > Project Settings > Plugins** and enable **BF6 Game Mode Setup**.
4. Open the `MP_Isolated` map scene and use the **BF6 Game Mode Setup** dock.

## Build a game mode

When a verified layout is available, open the **Game mode** dropdown and select it. The plugin downloads the gameplay layout and optional geometry from the data release, caches them in Godot's user-data directory, creates the game-mode node, and selects it in the Scene dock. Save the map scene when satisfied.

Optional preview geometry is editor-only and can be hidden from the Scene dock. Generated mesh children are rebuilt from the downloaded asset when the scene opens and are not exported with the level.

Selecting **Off** hides layouts without deleting them or discarding edits. The plugin will not overwrite an unrelated `Conquest` node.

## Notes

- The builder is deliberately map- and mode-specific. It validates Portal SDK resources before changing the scene.
- A layout is not published until its generated objects carry game-data provenance and its Portal SDK scene validates.
- Volume elevations are preserved from game data. They are not raycast or snapped to terrain.
- Vehicle and spawn arrays are not capped.

## License

The plugin source is available under the [MIT License](LICENSE). Battlefield and Battlefield Portal are trademarks of Electronic Arts Inc. This project is unaffiliated with and not endorsed by Electronic Arts.
