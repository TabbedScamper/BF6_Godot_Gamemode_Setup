# Game-data Blockly mode prototypes

These workspaces are a creator-review handoff. They do not contain custom scene
assets or copied template logic. Map geometry, objective transforms, spawns, HQs,
vehicles, and volumes continue to come from the installed game data through the
BF6 Godot Game Mode Setup importer.

## Ready for playtesting

- `domination_game_data.workspace.json` enables every imported CapturePoint,
  applies explicit capture timing, scores each point held once per second, and
  ends at 200 points.
- `team_deathmatch_game_data.workspace.json` deliberately ignores map capture
  candidates, awards one point for an opposing-team kill, and ends at 100.
- `king_of_the_hill_game_data.workspace.json` uses the imported KOTH points,
  enables one at a time, scores its owner once per second, and rotates every 90
  seconds. Each newly activated hill is reset to neutral with `GetTeam(0)`.

The rules are intentionally small so the mode creator can inspect and replace
individual decisions without untangling presentation, bot, audio, or UI code.

## Evidence labels

- **Game-derived**: object identity, transform, volume, spawn, HQ, and vehicle
  assignment extracted from retail records.
- **Portal translation**: behavior authored with public Portal blocks where the
  retail controller or tuning is not exposed.
- **Unresolved**: a value or state machine that has not been proven. It is not
  silently filled with a guess.

`mode_contracts.json` records those labels for every currently indexed mode.

## Important review points

1. Confirm that `AllCapturePoints` returns the imported alphabetical scene order
   on every KOTH map. The current 90-second rotation depends on that order.
2. Confirm that Portal continues to resolve `GetTeam(0)` as the neutral team on
   the current runtime. This is used only when a KOTH hill activates.
3. Decide whether Domination should keep positive control scoring or be changed
   to enemy ticket drain. The shipped data identifies the objectives but does not
   expose the retail drain curve.
4. Confirm desired score and time limits; the current values are reviewable
   defaults, not claims of hidden retail constants.

## Modes intentionally not faked

- Obliteration exposes bomb pickups and M-COMs in game data, but Portal has no
  Bomb object or carry/drop API.
- Payload exposes route/checkpoint records, but Portal has no Payload object or
  movement API.
- Squad Deathmatch can read squad identity, but the public score action accepts
  Team or Player rather than Squad.
- Escalation, Strikepoint, Sabotage, Carrier Strike, and Operations have useful
  spatial records, but their authoritative progression state machines are not
  decoded far enough for a defensible workspace.

## Regeneration

Run from the repository root:

```powershell
node tools/generate_blockly_mode_prototypes.js
```

For a local API-name check against the decoded Portal schema:

```powershell
node tools/generate_blockly_mode_prototypes.js --schema C:\BF6_Dev\BF6_Frostbite_Research\data\blueprint-modBuilder.json
```

The generator validates block ID uniqueness, variable references, and the
required `modBlock` root before writing the workspaces.
