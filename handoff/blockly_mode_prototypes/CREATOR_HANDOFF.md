# Game-data Blockly mode prototypes

These workspaces are a creator-review handoff. They do not contain custom scene
assets or copied template logic. Map geometry, objective transforms, spawns, HQs,
vehicles, and volumes continue to come from the installed game data through the
BF6 Godot Game Mode Setup importer.

## Generated workspaces

- `domination_game_data.workspace.json` enables every imported CapturePoint,
  applies explicit capture timing, scores each point held once per second, and
  ends at 200 points.
- `team_deathmatch_game_data.workspace.json` deliberately ignores map capture
  candidates, awards one point for an opposing-team kill, and ends at 100.
- `king_of_the_hill_game_data.workspace.json` uses the imported KOTH points,
  enables one at a time, scores its owner once per second, and rotates every 90
  seconds. Each newly activated hill is reset to neutral with `GetTeam(0)`.
- `escalation_review.workspace.json` shrinks the active objective set from both
  ends on a readable timer.
- `operations_review.workspace.json` advances through imported objectives in
  order for an attacker/defender review flow.
- `strikepoint_review.workspace.json` combines a central objective and short
  elimination score race while leaving round reset for creator review.
- `squad_deathmatch_review.workspace.json` and `gauntlet_review.workspace.json`
  use four Portal teams because the score API cannot score a Squad directly.
- `obliteration_review.workspace.json` and
  `squad_obliteration_review.workspace.json` wire the imported M-COMs, but
  cannot reproduce bomb carry/drop because Portal has no Bomb API.
- `sabotage_review.workspace.json` uses the first three available game-derived
  objective polygons through AreaTrigger IDs 701-703 and a ten-second attack
  hold. Imported maps may expose two to six sites; adapting that count is an
  explicit creator review item.
- `payload_review.workspace.json` is a clearly marked manual scaffold expecting
  AreaTrigger IDs 801-805 at the imported checkpoint markers.
- `carrier_strike_review.workspace.json` exposes ground objectives and carrier
  M-COMs while leaving the unavailable VLS/breach controller for review.

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
5. Adapt Sabotage's three-site generic rule group for maps exposing two, four,
   five, or six game-derived destructible sites. Eastwood currently exposes only
   two decoded polygon shapes for its three controller records, so its third
   site remains unlinked rather than receiving invented geometry.

## Deliberate API substitutions

- Every substitution is named `review` or `scaffold` in its file and rule names.
- No Bomb, Payload, VLS, cargo-damage, squad-score, or Gauntlet mission block is
  invented. The public Portal replacement is stated in `mode_contracts.json`.
- `koth` and `kingofthehill` share the same workspace. Conquest, Breakthrough,
  and Rush are omitted because creator templates already exist for them.

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
