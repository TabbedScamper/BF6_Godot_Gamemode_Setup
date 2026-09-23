# Battlefield mode behavior contract

This is the semantic gate between installed-layout classification and Godot
scene construction. Geometry alone does not decide an objective type. A small
polygon in Rush is not a CapturePoint merely because it resembles a Conquest
capture area.

Primary references:

- [Battlefield 6 modes](https://www.ea.com/en/games/battlefield/battlefield-6/news/modes)
- [Sabotage rules](https://www.ea.com/games/battlefield/battlefield-6/news/battlefield-6-season-1-free-trial-details-tips-tricks)
- [Carrier Strike overview](https://www.ea.com/games/battlefield/battlefield-6/news/battlefield-6-community-update-top-gun-incoming)
- [Gauntlet overview](https://www.ea.com/games/battlefield/news/community-update-introducing-redsec-battle-royale-gauntlet-and-portal)
- [SDK/mode fixes in update 1.4.1](https://www.ea.com/games/battlefield/redsec/news/battlefield-6-game-update-1-4-1-0)
- [Operations/Breakthrough sector evidence in update 1.4.2](https://www.ea.com/games/battlefield/redsec/news/battlefield-6-game-update-1-4-2-0)

`Game evidence` below means installed 1.4.3 layout rows and SDK classes, not a
community-authored position or vehicle choice.

## Runtime evidence layer

Spatial manifests answer **where** an object is. They do not serialize the live
owner, current sector, active phase, forward-spawner enable state, or the mode's
score machine. Those values are supplied by the retail schematic/provider graph.

The decoded mutator defaults needed by the Portal translation are checked in at
[`data/retail_mode_runtime_contracts.json`](../data/retail_mode_runtime_contracts.json).
This closes several earlier guesses:

| Mode | Decoded retail contract now used |
|---|---|
| Domination | 200 target; 10-second capture/neutralize; 15-minute round; scoring delays `0, 3.5, 2.5, 1.5` for zero through three held objectives. |
| KOTH | 250 target; 20-second initial unlock; 10-second next-hill reveal; 90-second active hill; one-second scoring delay. |
| TDM | 100 target; 15-minute round; one-minute overtime default. |
| Escalation | Five phases; phase lengths `90, 162, 252, 3600`; 40-second transition; 20-second capture/neutralize. |
| Breakthrough | 30-second capture/neutralize; max capture multiplier 5; 40-second advance; 15-45 second cleanup; one ticket per death. |
| Rush | 75 initial tickets; one ticket per death; 2-second arm; 5-second defuse; 30-second fuse; 40-second advance. |
| Operations | Three battalions of 200 tickets; one ticket per death; 100/75 sector refills; 30-second capture/neutralize; 40-second advance. |
| Strikepoint | Six rounds to win; three-minute rounds; capture target 25; 30-second lock. |
| Sabotage | Six-minute round; 15.4-second overtime; destructible health multiplier 5; each objective value 1. |
| Payload | Automatic time system; 15-second unlock; 20-second open; 3-second close; 2-second checkpoint pause; 10-second retreat. |
| Obliteration | Score limit 3; one opening and two mid-match bombs; 2-second arm; 4-second defuse; 35-second fuse. |
| Squad Obliteration | Score limit 2; one bomb; 4-second arm/defuse; 50-second fuse. |
| Carrier Strike | 100 initial carrier score; 30-second capture/neutralize; 4-second arm; 8-second defuse; 40-second fuse; four decoded carrier damage thresholds. |

These defaults do not, by themselves, define the state machine. `gme_sim_*`
expression graphs additionally name the state the importer must preserve:
sector transition and cleanup, ownership, majority timers, battalion activation,
round reasons, overtime, payload direction/distance, and objective activation.
When Portal has no matching object or action, the addon labels the substitution
instead of presenting it as retail-equivalent behavior.

| Layout key | Gameplay contract | Required Godot structure | Current alignment |
|---|---|---|---|
| `conquest` | Two teams capture and hold persistent lettered control points; HQ and objective vehicles are valid. | HQs, one Sector containing ordered CapturePoints, capture/HQ spawns, team-aware vehicle spawners, combat areas. | Strong; map-specific identity and vehicle audits exist. |
| `breakthrough` | Team 1 attackers must hold every control point in the current sector simultaneously, then the frontline advances against Team 2 defenders. Objective labels restart locally as A/B/C (or the authored subset). | Andy-compatible `Sector0` attacker boundary, active `Sector1..N`, and terminal defender boundary; active sectors own their game-authored CapturePoints and HQs. | Selected sector and objective order, membership, HQ teams, spawn/area links, and vehicle ancestry now come from exact installed identities and pins. Empty/unresolved selections are refused. IDs and initial capture ownership remain labeled Blockly compatibility choices; live activation and playlist overrides are not inferred. |
| `rush` | Team 1 attackers destroy the active sector's M-COMs before their tickets run out; there are no CapturePoints. Vehicles belong to HQ/phase supply, not capture points. | Andy-compatible boundary/active/boundary Sector shell; `MCOM-A|B` under each active sector; staged HQs and HQ-linked vehicles. | Selected sector/MCOM order, membership, HQ teams, spawn/area links, and vehicle ancestry now come from exact installed identities and pins. No CapturePoint or missing sector is synthesized. Phase-paired ObjIds are labeled Blockly compatibility choices; live activation and playlist overrides are not inferred. |
| `escalation` | Two teams capture territory while the active control-point set shrinks over successive stages. | CapturePoints plus stage/activation grouping, multiple phase HQ positions, stage-aware vehicles. | Partial. Spatial objects and decoded phase durations exist; exact majority/stalemate resolution and game-authored removal order remain in the expression graph. |
| `domination` | Infantry teams capture and hold several persistent control points. | Ordered CapturePoints and infantry spawns; no invented HQ vehicles. | Strong Portal translation: decoded target, round/capture timing, and held-objective score cadence are generated. |
| `kingofthehill`, `koth` | One active hill moves during the match. | Candidate hill areas plus one-at-a-time activation/order metadata, not a Conquest sector containing every point simultaneously. | Exact selected candidate GUID set and sector-link order are retained for 15 maps, and three mismatched/empty alias exports are refused. This is authored candidate order, not proof of the live hill-rotation schedule or a polygon-to-GEM link; Portal rotation remains a labeled substitute. |
| `teamdeathmatch` | Kill-count mode with no map objective. | Team spawns and combat bounds only. | Needs a hard no-objective gate; one map currently has a geometric false positive. |
| `squaddeathmatch` | Four squads race to the kill target; no map objective. | Squad spawn groups and combat bounds only. | Objective-free, but squad ownership is not yet modeled. |
| `strikepoint` | Round-based infantry elimination/capture mode with halftime/side swap. | Round objective area, team insertion spawns, no persistent Conquest sector. | Partial. Six-round target, three-minute timer, capture target, lock timer, and round-reason inputs are decoded; reset, wipe, overtime, and side swap still need translation. |
| `sabotage` | Teams swap attack/defense and destroy cargo at sites A-C; cargo is damaged directly. | Destructible cargo objectives and round-side metadata, not CapturePoints. | Not aligned. Capture-like polygons are currently misclassified; the SDK-equivalent cargo object still needs identification. |
| `obliteration` | Teams carry a bomb to hostile M-COM targets. | Bomb pickup candidates and MCOM objectives beneath one selected sector. | Exact selected sector/HQ/MCOM inspector links and 12 authored bomb-site candidates per map now build on three maps. The live bomb site, carry/drop/plant sequence, and team ownership remain unresolved. |
| `squadobliteration` | Smaller squad version of bomb-to-MCOM play. | One bomb pickup candidate and six MCOMs beneath one selected sector. | Exact selected sector/HQ/MCOM inspector links and one authored bomb site now build on four maps. Live activation and squad-specific rules remain unresolved. |
| `carrierstrike` | Teams seize the route to and destroy the opposing carrier, ending with an interior carrier objective. | Required carrier layout, ground objectives, carrier objectives/MCOMs, naval/air combat volumes and carrier/HQ vehicles. | Partial. Carrier preview and extracted spatial rows exist; staged carrier damage/objective ownership is not wired. |
| `operations` | Sector-based attacker/defender progression related to Breakthrough; official patch data refers to Objective A in Sector 2. | Selected sector/HQ/capture candidate graph; live phase and battalion sequence must be modeled separately. | Exact selected sector-to-HQ and sector-to-capture inspector arrays now build on Capstone and Tungsten. Contaminated and Subsurface are refused because their exports omit cross-partition selected objects. Three battalions, ticket defaults, and timing are decoded, but gameplay phase order, activation, and cross-map persistence remain incomplete. |
| `gauntlet` | Multi-squad elimination series with randomized mission types and combat zones. | Mission candidates and per-round zone/objective sets, not one static conventional mode. | Not representable by the current flat builder. Rows should be exposed as mission candidates until mission graphs are mined. |
| `payload` | Escort payloads along authored splines through ordered checkpoints and sectors. | Payload roots, spline/route state, ordered checkpoints, team control, and phase timing; do not infer the route from polygon size. | Identified but not publicly reproducible. The retail interfaces expose transform, velocity, direction, control, distance, and checkpoint state, while Portal exposes no Payload/spline objective API. |

## Builder rules

1. Mode semantics gate classifier roles before nodes are created.
2. A node is an objective only when both the mode contract and installed row
   identity support it.
3. Sequential modes require separate ordered Sector nodes; a single catch-all
   Sector is invalid.
4. Objective labels are local to their sector where the mode says so.
5. Vehicle ownership follows the mode: Conquest may bind to HQs or captured
   objectives; Rush vehicles bind only to HQ/phase infrastructure.
6. Unknown objective types remain labeled game-data geometry. They are not
   silently converted into CapturePoints.
7. Community templates may audit hierarchy and public Blockly IDs, but game
   positions, types, teams, vehicle choices, and activation rules require game
   evidence.
8. The supplied Blockly workspaces and `.tscn` files are compatibility oracles,
   not redistributable layout sources. The addon stores no community-authored
   coordinates, polygons, spawns, or vehicle choices.
9. Rush/Breakthrough nodes whose Portal ObjId, team, hierarchy, or wrapper was
   adjusted for the Blockly contract carry `bf6_template_modified`, a plain-text
   `bf6_template_adjustment`, and the assigned ID in their Godot metadata. A
   duplicated HQ required only to satisfy a per-phase Blockly lookup is also
   marked as a compatibility alias and is never described as a distinct retail
   instance.
10. A normal game-mode build contains no creator-authored asset branches. The
    TeamSwitcher, AI spawners, and EndGameCamera are added only when the user
    explicitly presses **Andys Template Addons**.
