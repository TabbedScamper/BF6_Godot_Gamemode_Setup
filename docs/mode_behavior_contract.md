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

| Layout key | Gameplay contract | Required Godot structure | Current alignment |
|---|---|---|---|
| `conquest` | Two teams capture and hold persistent lettered control points; HQ and objective vehicles are valid. | HQs, one Sector containing ordered CapturePoints, capture/HQ spawns, team-aware vehicle spawners, combat areas. | Strong; map-specific identity and vehicle audits exist. |
| `breakthrough` | Attackers must hold every control point in the current sector simultaneously, then the frontline advances. Team 2 begins as defender. Objective labels restart locally as A/B/C (or the authored subset). | Andy-compatible `Sector0` attacker boundary, active `Sector1..N`, and terminal defender boundary; active sectors own one to three CapturePoints and a phased HQ pair. | Strong. Installed phase polygons determine membership where unambiguous; bounded proximity is the fallback. IDs follow the workspace contract: sectors `100+n`, triggers `600+n`, HQs `300+n`/`400+n`, captures in each phase's `1100/1200/...` band, and vehicles at offset `+50`. If the install has fewer HQ placements than the workspace addresses, the missing API identity is an explicitly marked alias of a same-team game-authored transform/spawn set. |
| `rush` | Attackers destroy the active sector's M-COMs before their tickets run out; there are no CapturePoints. Vehicles belong to HQ/phase supply, not capture points. | Andy-compatible boundary/active/boundary Sector shell; `MCOM-A|B` under each active sector; staged HQ pairs and HQ-linked vehicles. | Strong. The workspace's `CountOf(Sectors)-2` and ID arithmetic are reproduced. MCOM IDs remain phase-paired (`201/202`, `203/204`, ...), including reserved gaps when a phase has only one live objective. Dormant retail sector records are excluded by their distance from live MCOMs. No CapturePoint is synthesized. |
| `escalation` | Two teams capture territory while the active control-point set shrinks over successive stages. | CapturePoints plus stage/activation grouping, multiple phase HQ positions, stage-aware vehicles. | Partial. Spatial objects exist, but stage ownership/activation is not represented yet. |
| `domination` | Infantry teams capture and hold several persistent control points. | Ordered CapturePoints and infantry spawns; no invented HQ vehicles. | Mostly aligned spatially; mode logic is outside this addon. |
| `kingofthehill`, `koth` | One active hill moves during the match. | Candidate hill areas plus one-at-a-time activation/order metadata, not a Conquest sector containing every point simultaneously. | Not aligned. Candidate polygons currently become ordinary CapturePoints. |
| `teamdeathmatch` | Kill-count mode with no map objective. | Team spawns and combat bounds only. | Needs a hard no-objective gate; one map currently has a geometric false positive. |
| `squaddeathmatch` | Four squads race to the kill target; no map objective. | Squad spawn groups and combat bounds only. | Objective-free, but squad ownership is not yet modeled. |
| `strikepoint` | Round-based infantry elimination/capture mode with halftime/side swap. | Round objective area, team insertion spawns, no persistent Conquest sector. | Partial/uncertain. Candidate areas exist but round selection and side swap are not represented. |
| `sabotage` | Teams swap attack/defense and destroy cargo at sites A-C; cargo is damaged directly. | Destructible cargo objectives and round-side metadata, not CapturePoints. | Not aligned. Capture-like polygons are currently misclassified; the SDK-equivalent cargo object still needs identification. |
| `obliteration` | Teams carry a bomb to hostile M-COM targets. | Bomb pickup plus ordered/team-owned MCOM objectives. | Not aligned. Installed Bomb/MCOM rows exist but are still placed as generic Extras. |
| `squadobliteration` | Smaller squad version of bomb-to-MCOM play. | Bomb pickup plus squad-owned MCOM objectives. | Not aligned for the same reason as Obliteration. |
| `carrierstrike` | Teams seize the route to and destroy the opposing carrier, ending with an interior carrier objective. | Required carrier layout, ground objectives, carrier objectives/MCOMs, naval/air combat volumes and carrier/HQ vehicles. | Partial. Carrier preview and extracted spatial rows exist; staged carrier damage/objective ownership is not wired. |
| `operations` | Sector-based attacker/defender progression related to Breakthrough; official patch data refers to Objective A in Sector 2. | Ordered sectors with capture/MCOM objectives as authored per map. | Not aligned. Mixed installed rows are currently flattened. |
| `gauntlet` | Multi-squad elimination series with randomized mission types and combat zones. | Mission candidates and per-round zone/objective sets, not one static conventional mode. | Not representable by the current flat builder. Rows should be exposed as mission candidates until mission graphs are mined. |
| `payload` | Installed layout key; no sufficiently specific official BF6 rules reference has been verified. | Do not infer an objective type from polygon size alone. | Unverified. HQ/zone rows can be shown, but a playable objective hierarchy must wait for game-data identification. |

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
