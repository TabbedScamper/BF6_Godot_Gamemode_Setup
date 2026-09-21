# Runtime state-machine audit

The installed layout manifests are placement records. A mode only becomes
playable when its retail simulation state is translated as well. This audit
tracks the minimum state required for start, progression, and end conditions.

Evidence comes from installed 1.4.3 `gme_sim_*`, `mi_sim_*`, and `mut_*` EBX
partitions. Raw tuning used by the generated workspaces is retained in
[`data/retail_mode_runtime_contracts.json`](../data/retail_mode_runtime_contracts.json).

| Mode | Retail state required | Portal translation status |
|---|---|---|
| Conquest | Initial tickets, death bleed, capture bleed, majority bleed timer, full-majority countdown, owner changes. | Spatial/object ownership is strong. A retail-equivalent ticket controller still needs to consume the decoded defaults. |
| Domination | Round timer, separate team score timers, current owner, held-objective-dependent scoring delay, 200 target. | Implemented with decoded capture timing and `3.5/2.5/1.5` scoring rules. Catch-up/presentation graph remains unavailable. |
| KOTH | Initial unlock, next-hill reveal, active-hill timer, neutralization rules, one-second score timer, ordered hill selection. | Timing and score defaults are decoded. Game-authored hill order is not yet exposed; `AllCapturePoints` order is the Portal substitute. |
| Breakthrough | Attacker start tickets, per-death bleed, fully-owned sector test, transition timer/index, cleanup, retreat, overtime, reinforcement count, next-sector activation. | Geometry and creator IDs are strong. The creator workspace must implement the named transition/cleanup/overtime state; placement data alone cannot. |
| Rush | Attacker reinforcement count, phase-local M-COM state, armed fuse/defuse and overtime, transition index, cleanup, next-sector HQ/spawn/vehicle activation. | Sector/M-COM hierarchy and decoded timings are available. The existing creator workspace remains the required public-API controller. |
| Escalation | Period start/end, team majority, majority tickets/time, remaining capture count, sector transition, stalemate timer, vehicle-spawner timer, phase winner. | Decoded phase schedule is implemented. Period scoring, stalemate selection, and exact removed-objective order remain incomplete. |
| Operations | Three battalions, 200 tickets per battalion, battalion activate/deplete, ticket refill, sector transition/cleanup, deaths per sector, cross-map persistence. | Battalion count, tickets, death bleed, and bounded refill are implemented. Cross-map persistence and mixed objective phase graphs remain incomplete. |
| Strikepoint | Round timer, alive players per team, team wipe, capture progress, capture lock, overtime, round reason, rounds won, side swap/reset. | Constants are decoded. The current workspace does not yet reproduce the retail round lifecycle and must remain labelled review. |
| Sabotage | Two-round side state, destructible health/value, round timer, overtime, destroyed-objective total, same-score time tiebreak. | Destructible placement and round defaults are decoded. Area-trigger hold remains an explicit substitute because Portal exposes no retail destructible objective controller. |
| Payload | Spline transform/progress, direction, steering, throttle, velocity, alive/spawned state, player count on payload, front-most payload, checkpoint count, sector elapsed time, current/furthest/total distance. | Portal has no Payload or spline objective API. Static checkpoint triggers cannot be retail-equivalent; they are only a playable scaffold. |
| Obliteration | Bomb spawn count, carry/drop timeout, pickup reset, arm/defuse/fuse, overtime, target ownership, score limit, mid-match bomb spawning. | M-COM timing and score limits are decoded. Portal has no Bomb API, so the defining carry/drop loop cannot be completed with standard blocks. |
| Carrier Strike | Ground capture ownership, VLS battery state/reload, carrier health and damage cap, light/medium/major/critical thresholds, breach state, carrier M-COM arm/defuse/fuse. | Geometry, carriers, capture/M-COM timings, and thresholds are decoded. VLS/breach/health coupling has no public Portal equivalent. |
| Squad Deathmatch | Three successive round targets/timers, round winner, four independently scored squads, overtime. | First-round target/time can be translated, but Portal score setters accept teams/players rather than squads. Four Portal teams remain the declared substitute. |
| Gauntlet | Mission selection, mission-specific objective graph, per-round score, squad elimination, zone selection, final-two resolution. | Layout rows expose candidates only. A static kill race is not a retail reconstruction and remains a scaffold. |

## Importer requirements

For a generated mode to work without manual archaeology, the importer and its
matching Blockly workspace must agree on all of the following:

1. Stable Portal object IDs and a deterministic order for HQs, sectors,
   objectives, M-COMs, triggers, spawns, vehicles, and deploy cameras.
2. Explicit sector/objective membership. Distance is only a fallback when the
   retail graph provides no recoverable link.
3. Initial team/owner/enabled state supplied by the mode contract, never by a
   neutral placement default.
4. Phase activation for HQs, spawns, objective vehicles, forward spawners,
   emplacements, and combat areas.
5. Start, transition, cleanup/retreat, overtime, and end conditions.
6. A map rotation and a game-derived spatial attachment in the experience. A
   Blockly-only experience with empty attachments is reviewable but not a
   one-click playable map.

The last item is now the largest packaging gap. The current experience files
intentionally omit map rotations and spatial attachments to avoid copying a
community template. Closing it requires a game-data scene-to-Portal-spatial
export path, not more guessed Blockly.
