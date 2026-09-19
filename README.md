# BF6 Godot Game Mode Setup

A focused Godot editor plugin for building complete Battlefield Portal game-mode layouts from verified local reference scenes.

The first supported layout is **Tsuru Reef (`MP_Isolated`) Conquest**. It brings the game-mode hierarchy into the open map with authored transforms and inspector properties intact:

- infantry and aircraft combat volumes
- both carrier HQs and their infantry spawns
- all capture points, flags, capture-zone heights, and linked spawns
- objective and HQ vehicle spawners with their vehicle, respawn, destruction, and abandonment settings
- objective vehicle pairs gated to the team that owns B, D, F, or I
- HQ-to-vehicle links
- carrier gameplay volumes
- deploy and end-game cameras
- automatic AA defences and their linked volumes
- optional material-free carrier geometry

The setup intentionally excludes the reference scene's team-switch testing branch and firing-range floor workaround. SDK scene internals remain scene-owned, so implementation nodes such as `Mesh`, `StaticBody3D`, and `CollisionShape3D` are not promoted into editable game-mode content.

## Install

1. Download the plugin ZIP from the [latest release](../../releases/latest), or clone this repository.
2. Copy `addons/bf6_gamemode_setup` into the `addons` folder of a Battlefield Portal Godot project.
3. In Godot, open **Project > Project Settings > Plugins** and enable **BF6 Game Mode Setup**.
4. Open the `MP_Isolated` map scene and use the **BF6 Game Mode Setup** dock.

## Build Tsuru Reef Conquest

Open the **Game mode** dropdown and select **Conquest**. The plugin downloads the verified gameplay layout and carrier geometry from the data release, caches them in Godot's user-data directory, creates a `Conquest` node, and selects it in the Scene dock. Save the map scene when satisfied.

`Conquest/AircraftCarriers` contains editor-only, material-free carrier geometry. Use its eye icon to show or hide both ships. Only the `AircraftCarriers` holder is saved; generated mesh children are rebuilt from the local GLB when the scene opens and are not exported with the level.

Selecting **Off** hides layouts without deleting them or discarding edits. The plugin will not overwrite an unrelated `Conquest` node.

## Notes

- The current builder is deliberately map- and mode-specific. It validates Portal SDK resources before changing the scene.
- Volume elevations come from the authored reference hierarchy. They are not raycast or snapped to terrain.
- Vehicle and spawn arrays are not capped. The included Tsuru Reef setup links all authored entries.
- The source scene's existing `Obectives` spelling is preserved to avoid gratuitous hierarchy changes.

## License

The plugin source is available under the [MIT License](LICENSE). Battlefield and Battlefield Portal are trademarks of Electronic Arts Inc. This project is unaffiliated with and not endorsed by Electronic Arts.
