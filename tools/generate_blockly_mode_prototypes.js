#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const outputRoot = path.join(repoRoot, "handoff", "blockly_mode_prototypes");
let sequence = 0;

function id(prefix = "block") {
  sequence += 1;
  return `bf6_${prefix}_${String(sequence).padStart(4, "0")}`;
}

function block(type, options = {}) {
  return { type, id: id(type.toLowerCase()), ...options };
}

function input(value) {
  return { block: value };
}

function api(type, ...values) {
  const inputs = {};
  values.forEach((value, index) => {
    inputs[`VALUE-${index}`] = input(value);
  });
  return block(type, values.length ? { inputs } : {});
}

function number(value) {
  return block("Number", { fields: { NUM: value } });
}

function boolean(value) {
  return block("Boolean", { fields: { BOOL: value ? "TRUE" : "FALSE" } });
}

function chain(...actions) {
  const usable = actions.filter(Boolean);
  for (let index = 0; index + 1 < usable.length; index += 1) {
    usable[index].next = input(usable[index + 1]);
  }
  return usable[0];
}

function variableReference(variable, object = null) {
  const reference = block("variableReferenceBlock", {
    extraState: { isObjectVar: object !== null },
    fields: { OBJECTTYPE: variable.type, VAR: { id: variable.id } },
  });
  if (object !== null) reference.inputs = { OBJECT: input(object) };
  return reference;
}

function getVariable(variable, object = null) {
  return api("GetVariable", variableReference(variable, object));
}

function setVariable(variable, value, object = null) {
  return api("SetVariable", variableReference(variable, object), value);
}

function team(value) {
  return api("GetTeam", typeof value === "number" ? number(value) : value);
}

function allCapturePoints() {
  return api("AllCapturePoints");
}

function valueInArray(array, index) {
  return api("ValueInArray", array, index);
}

function currentHill(currentHillVariable) {
  return valueInArray(allCapturePoints(), getVariable(currentHillVariable));
}

function ifAction(condition, actions) {
  return block("If", {
    extraState: {},
    inputs: { "VALUE-0": input(condition), DO: input(actions) },
  });
}

function condition(value) {
  return block("conditionBlock", { inputs: { CONDITION: input(value) } });
}

function rule(name, eventType, actions, conditionValue = null) {
  const isOngoing = eventType === "Ongoing";
  const result = block("ruleBlock", {
    extraState: { isOngoingEvent: isOngoing },
    fields: { NAME: name, EVENTTYPE: eventType, ...(isOngoing ? { OBJECTTYPE: "Global" } : {}) },
    inputs: { ACTIONS: input(actions) },
  });
  if (conditionValue) result.inputs.CONDITIONS = input(condition(conditionValue));
  return result;
}

function workspace(variables, rules) {
  chain(...rules);
  return {
    mod: {
      blocks: {
        languageVersion: 0,
        blocks: [
          block("modBlock", {
            x: 80,
            y: 80,
            deletable: false,
            inputs: { RULES: input(rules[0]) },
          }),
        ],
      },
      variables,
    },
  };
}

function globalVariable(name) {
  return { name, id: `bf6_var_${name.toLowerCase().replace(/[^a-z0-9]+/g, "_")}`, type: "Global" };
}

function gameStartActions(targetScore, timeLimit) {
  return chain(
    api("SetGameModeScore", team(1), number(0)),
    api("SetGameModeScore", team(2), number(0)),
    api("SetGameModeTargetScore", number(targetScore)),
    api("SetGameModeTimeLimit", number(timeLimit)),
  );
}

function scoreFor(teamNumber, amount) {
  const selectedTeam = team(teamNumber);
  return api(
    "SetGameModeScore",
    selectedTeam,
    api("Add", api("GetGameModeScore", team(teamNumber)), amount),
  );
}

function victoryRules(targetScore) {
  return [1, 2].map((teamNumber) => rule(
    `Team ${teamNumber} reaches target`,
    "Ongoing",
    api("EndGameMode", team(teamNumber)),
    api("GreaterThanEqualTo", api("GetGameModeScore", team(teamNumber)), number(targetScore)),
  ));
}

function ownedCaptureCount(teamNumber) {
  return api(
    "CountOf",
    api(
      "FilteredArray",
      allCapturePoints(),
      api("Equals", api("GetCurrentOwnerTeam", api("CurrentArrayElement")), team(teamNumber)),
    ),
  );
}

function dominationWorkspace() {
  sequence = 0;
  const iterator = globalVariable("ObjectiveIterator");
  const targetScore = 200;
  const setupObjective = chain(
    api("EnableGameModeObjective", valueInArray(allCapturePoints(), getVariable(iterator)), boolean(true)),
    api("SetCapturePointCapturingTime", valueInArray(allCapturePoints(), getVariable(iterator)), number(20)),
    api("SetCapturePointNeutralizationTime", valueInArray(allCapturePoints(), getVariable(iterator)), number(15)),
    api("SetMaxCaptureMultiplier", valueInArray(allCapturePoints(), getVariable(iterator)), number(3)),
  );
  const objectiveLoop = block("ForVariable", {
    inputs: {
      "VALUE-0": input(variableReference(iterator)),
      "VALUE-1": input(number(0)),
      "VALUE-2": input(api("CountOf", allCapturePoints())),
      "VALUE-3": input(number(1)),
      DO: input(setupObjective),
    },
  });
  const start = gameStartActions(targetScore, 1200);
  let tail = start;
  while (tail.next) tail = tail.next.block;
  tail.next = input(objectiveLoop);

  const scoreTick = rule(
    "Score controlled objectives once per second",
    "Ongoing",
    chain(
      api("Wait", number(1)),
      scoreFor(1, ownedCaptureCount(1)),
      scoreFor(2, ownedCaptureCount(2)),
    ),
    api("GreaterThan", api("CountOf", allCapturePoints()), number(0)),
  );

  return workspace([iterator], [
    rule("Initialize Domination", "OnGameModeStarted", start),
    scoreTick,
    ...victoryRules(targetScore),
  ]);
}

function teamDeathmatchWorkspace() {
  sequence = 0;
  const targetScore = 100;
  const killerTeam = () => team(api("EventPlayer"));
  const victimTeam = () => team(api("EventOtherPlayer"));
  const killScore = api(
    "SetGameModeScore",
    killerTeam(),
    api("Add", api("GetGameModeScore", team(api("EventPlayer"))), number(1)),
  );
  return workspace([], [
    rule("Initialize Team Deathmatch", "OnGameModeStarted", gameStartActions(targetScore, 1200)),
    rule(
      "Award opposing-team kill",
      "OnPlayerEarnedKill",
      killScore,
      api("NotEqualTo", killerTeam(), victimTeam()),
    ),
    ...victoryRules(targetScore),
  ]);
}

function kingOfTheHillWorkspace() {
  sequence = 0;
  const iterator = globalVariable("ObjectiveIterator");
  const current = globalVariable("CurrentHillIndex");
  const elapsed = globalVariable("HillElapsedSeconds");
  const duration = globalVariable("HillDurationSeconds");
  const targetScore = 250;

  const disableLoop = block("ForVariable", {
    inputs: {
      "VALUE-0": input(variableReference(iterator)),
      "VALUE-1": input(number(0)),
      "VALUE-2": input(api("CountOf", allCapturePoints())),
      "VALUE-3": input(number(1)),
      DO: input(chain(
        api(
          "EnableGameModeObjective",
          valueInArray(allCapturePoints(), getVariable(iterator)),
          boolean(false),
        ),
        api("SetCapturePointCapturingTime", valueInArray(allCapturePoints(), getVariable(iterator)), number(15)),
        api("SetCapturePointNeutralizationTime", valueInArray(allCapturePoints(), getVariable(iterator)), number(10)),
        api("SetMaxCaptureMultiplier", valueInArray(allCapturePoints(), getVariable(iterator)), number(3)),
      )),
    },
  });
  const setup = gameStartActions(targetScore, 1200);
  let tail = setup;
  while (tail.next) tail = tail.next.block;
  tail.next = input(chain(
    setVariable(current, number(0)),
    setVariable(elapsed, number(0)),
    setVariable(duration, number(90)),
    disableLoop,
    ifAction(
      api("GreaterThan", api("CountOf", allCapturePoints()), number(0)),
      chain(
        api("SetCapturePointOwner", currentHill(current), team(0)),
        api("EnableGameModeObjective", currentHill(current), boolean(true)),
      ),
    ),
  ));

  const owner = () => api("GetCurrentOwnerTeam", currentHill(current));
  const rotate = ifAction(
    api("GreaterThanEqualTo", getVariable(elapsed), getVariable(duration)),
    chain(
      api("EnableGameModeObjective", currentHill(current), boolean(false)),
      setVariable(
        current,
        api("Modulo", api("Add", getVariable(current), number(1)), api("CountOf", allCapturePoints())),
      ),
      api("SetCapturePointOwner", currentHill(current), team(0)),
      api("EnableGameModeObjective", currentHill(current), boolean(true)),
      setVariable(elapsed, number(0)),
    ),
  );
  const tick = chain(
    api("Wait", number(1)),
    ifAction(api("Equals", owner(), team(1)), scoreFor(1, number(1))),
    ifAction(api("Equals", owner(), team(2)), scoreFor(2, number(1))),
    setVariable(elapsed, api("Add", getVariable(elapsed), number(1))),
    rotate,
  );

  return workspace([iterator, current, elapsed, duration], [
    rule("Initialize King of the Hill", "OnGameModeStarted", setup),
    rule(
      "Score and rotate active hill",
      "Ongoing",
      tick,
      api("GreaterThan", api("CountOf", allCapturePoints()), number(0)),
    ),
    ...victoryRules(targetScore),
  ]);
}

function collectBlocks(value, blocks = []) {
  if (!value || typeof value !== "object") return blocks;
  if (typeof value.type === "string" && typeof value.id === "string") blocks.push(value);
  for (const child of Object.values(value)) collectBlocks(child, blocks);
  return blocks;
}

function validate(name, document) {
  const blocks = collectBlocks(document.mod.blocks);
  const ids = new Set();
  for (const item of blocks) {
    if (ids.has(item.id)) throw new Error(`${name}: duplicate block id ${item.id}`);
    ids.add(item.id);
  }
  const variables = document.mod.variables;
  const variableIds = new Set(variables.map((variable) => variable.id));
  for (const item of blocks.filter((entry) => entry.type === "variableReferenceBlock")) {
    const variableId = item.fields?.VAR?.id;
    if (!variableIds.has(variableId)) throw new Error(`${name}: unknown variable id ${variableId}`);
  }
  if (document.mod.blocks.blocks[0]?.type !== "modBlock") throw new Error(`${name}: missing modBlock root`);
  return { blockCount: blocks.length, variableCount: variables.length };
}

function validateAgainstPortalSchema(name, document, schema) {
  const portalTypes = new Set();
  const portalDefinitions = new Map();
  for (const section of Object.values(schema)) {
    if (!Array.isArray(section)) continue;
    for (const entry of section) {
      if (typeof entry?.name === "string") {
        portalTypes.add(entry.name);
        if (!portalDefinitions.has(entry.name)) portalDefinitions.set(entry.name, entry);
      }
    }
  }
  const blocklyTypes = new Set([
    "modBlock", "ruleBlock", "conditionBlock", "variableReferenceBlock",
    "Number", "Boolean", "If", "ForVariable",
  ]);
  const unknown = [...new Set(
    collectBlocks(document.mod.blocks)
      .map((entry) => entry.type)
      .filter((type) => !portalTypes.has(type) && !blocklyTypes.has(type)),
  )].sort();
  if (unknown.length) throw new Error(`${name}: types absent from Portal schema: ${unknown.join(", ")}`);

  for (const item of collectBlocks(document.mod.blocks)) {
    const definition = portalDefinitions.get(item.type);
    if (!definition) continue;
    const actualCount = Object.keys(item.inputs ?? {}).filter((key) => /^VALUE-\d+$/.test(key)).length;
    const expectedCounts = Array.isArray(definition.functionSignatures)
      ? definition.functionSignatures.map((signature) => signature.parameterTypes?.length ?? 0)
      : Array.isArray(definition.parameters)
        ? [definition.parameters.length]
        : [];
    if (expectedCounts.length && !expectedCounts.includes(actualCount)) {
      throw new Error(
        `${name}: ${item.type} ${item.id} has ${actualCount} values; Portal schema expects ${expectedCounts.join(" or ")}`,
      );
    }
  }

  const eventNames = new Set((schema.events ?? []).map((entry) => entry.name));
  const unknownEvents = [...new Set(
    collectBlocks(document.mod.blocks)
      .filter((entry) => entry.type === "ruleBlock" && entry.fields?.EVENTTYPE !== "Ongoing")
      .map((entry) => entry.fields.EVENTTYPE)
      .filter((eventType) => !eventNames.has(eventType)),
  )];
  if (unknownEvents.length) throw new Error(`${name}: events absent from Portal schema: ${unknownEvents.join(", ")}`);
}

const contracts = {
  schema_version: 1,
  principle: "Retail game data supplies map objects and transforms. Blockly only translates behavior exposed by Portal.",
  modes: {
    domination: {
      delivery: "playable_prototype",
      spatial_source: "game-derived gem_capturepoint records imported with ObjId 200 + alphabetical flag index",
      portal_translation: "Each owned point awards one team point per second; first to 200 wins.",
      unresolved: ["Retail ticket-drain curve and catch-up tuning are not exposed in Portal data."],
      workspace: "domination_game_data.workspace.json",
    },
    teamdeathmatch: {
      delivery: "playable_prototype",
      spatial_source: "game-derived HQ/spawn/combat-area layout; capture-like false positives are intentionally ignored",
      portal_translation: "Opposing-team kills award one point; first to 100 wins.",
      unresolved: ["Retail assist weighting and hidden score modifiers are not represented."],
      workspace: "team_deathmatch_game_data.workspace.json",
    },
    kingofthehill: {
      delivery: "playable_portal_translation",
      spatial_source: "game-derived KOTH capture points in importer-created alphabetical scene order",
      portal_translation: "One hill is enabled for 90 seconds, then rotation advances through AllCapturePoints; owner earns one point per second.",
      unresolved: [
        "Retail phase order and phase duration have not been decoded from the runtime controller.",
        "AllCapturePoints ordering must be confirmed in Portal after importing each scene.",
      ],
      workspace: "king_of_the_hill_game_data.workspace.json",
    },
    conquest: { delivery: "existing_plugin_contract", unresolved: [] },
    breakthrough: { delivery: "existing_template_compatibility_contract", unresolved: ["Retail reinforcement and sector-transition tuning remains runtime-authored."] },
    rush: { delivery: "existing_template_compatibility_contract", unresolved: ["Retail reinforcement and overtime tuning remains runtime-authored."] },
    escalation: { delivery: "research_only", unresolved: ["gem_collection_event meaning and authored stage activation order are not decoded."] },
    strikepoint: { delivery: "research_only", unresolved: ["Many maps expose no stable capture object; round/elimination behavior remains runtime-authored."] },
    obliteration: { delivery: "blocked_by_portal_api", unresolved: ["Game data has gem_bomb_pickup and M-COM records, but Portal exposes no Bomb object or carry/drop API."] },
    payload: { delivery: "blocked_by_portal_api", unresolved: ["Game data has payload/checkpoint markers, but Portal exposes no Payload object or motion API."] },
    sabotage: { delivery: "research_only", unresolved: ["Cargo/objective semantics and state transitions are not decoded into Portal-addressable objects."] },
    carrierstrike: { delivery: "research_only", unresolved: ["VLS batteries and destructible proxies lack a complete Portal behavior mapping."] },
    operations: { delivery: "research_only", unresolved: ["Cross-mode sector/capture/M-COM progression is not fully decoded."] },
    squaddeathmatch: { delivery: "blocked_by_portal_api", unresolved: ["Portal can read squads but SetGameModeScore accepts Team or Player, not Squad."] },
  },
};

const outputs = {
  "domination_game_data.workspace.json": dominationWorkspace(),
  "team_deathmatch_game_data.workspace.json": teamDeathmatchWorkspace(),
  "king_of_the_hill_game_data.workspace.json": kingOfTheHillWorkspace(),
  "mode_contracts.json": contracts,
};

const schemaArgument = process.argv.indexOf("--schema");
const schemaPath = schemaArgument >= 0 ? process.argv[schemaArgument + 1] : null;
const portalSchema = schemaPath ? JSON.parse(fs.readFileSync(schemaPath, "utf8")) : null;

fs.mkdirSync(outputRoot, { recursive: true });
for (const [filename, document] of Object.entries(outputs)) {
  if (filename.endsWith(".workspace.json")) {
    const result = validate(filename, document);
    if (portalSchema) validateAgainstPortalSchema(filename, document, portalSchema);
    console.log(`${filename}: ${result.blockCount} blocks, ${result.variableCount} variables`);
  }
  fs.writeFileSync(path.join(outputRoot, filename), `${JSON.stringify(document, null, 2)}\n`, "utf8");
}
