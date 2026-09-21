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

function captureSetupLoop(iterator, enabled = true) {
  return block("ForVariable", {
    inputs: {
      "VALUE-0": input(variableReference(iterator)),
      "VALUE-1": input(number(0)),
      "VALUE-2": input(api("CountOf", allCapturePoints())),
      "VALUE-3": input(number(1)),
      DO: input(chain(
        api("EnableGameModeObjective", valueInArray(allCapturePoints(), getVariable(iterator)), boolean(enabled)),
        api("SetCapturePointCapturingTime", valueInArray(allCapturePoints(), getVariable(iterator)), number(20)),
        api("SetCapturePointNeutralizationTime", valueInArray(allCapturePoints(), getVariable(iterator)), number(15)),
        api("SetMaxCaptureMultiplier", valueInArray(allCapturePoints(), getVariable(iterator)), number(3)),
      )),
    },
  });
}

function multiTeamDeathmatchWorkspace(modeName, teamCount, targetScore) {
  sequence = 0;
  const startActions = [];
  for (let teamNumber = 1; teamNumber <= teamCount; teamNumber += 1) {
    startActions.push(api("SetGameModeScore", team(teamNumber), number(0)));
  }
  startActions.push(api("SetGameModeTargetScore", number(targetScore)));
  startActions.push(api("SetGameModeTimeLimit", number(1200)));
  const killerTeam = () => team(api("EventPlayer"));
  const victimTeam = () => team(api("EventOtherPlayer"));
  const rules = [
    rule(`Initialize ${modeName}`, "OnGameModeStarted", chain(...startActions)),
    rule(
      "Award opposing-team kill",
      "OnPlayerEarnedKill",
      api(
        "SetGameModeScore",
        killerTeam(),
        api("Add", api("GetGameModeScore", killerTeam()), number(1)),
      ),
      api("NotEqualTo", killerTeam(), victimTeam()),
    ),
  ];
  for (let teamNumber = 1; teamNumber <= teamCount; teamNumber += 1) {
    rules.push(...victoryRulesForTeam(teamNumber, targetScore));
  }
  return workspace([], rules);
}

function victoryRulesForTeam(teamNumber, targetScore) {
  return [rule(
    `Team ${teamNumber} reaches target`,
    "Ongoing",
    api("EndGameMode", team(teamNumber)),
    api("GreaterThanEqualTo", api("GetGameModeScore", team(teamNumber)), number(targetScore)),
  )];
}

function escalationWorkspace() {
  sequence = 0;
  const iterator = globalVariable("ObjectiveIterator");
  const stage = globalVariable("EscalationStage");
  const elapsed = globalVariable("StageElapsedSeconds");
  const targetScore = 100;
  const setup = gameStartActions(targetScore, 1200);
  let tail = setup;
  while (tail.next) tail = tail.next.block;
  tail.next = input(chain(
    setVariable(stage, number(0)),
    setVariable(elapsed, number(0)),
    captureSetupLoop(iterator, true),
  ));
  const captureScore = rule(
    "Award captured-objective score",
    "OnCapturePointCaptured",
    api(
      "SetGameModeScore",
      api("EventTeam"),
      api("Add", api("GetGameModeScore", api("EventTeam")), number(5)),
    ),
  );
  const canShrink = api(
    "LessThan",
    api("Add", getVariable(stage), getVariable(stage)),
    api("Subtract", api("CountOf", allCapturePoints()), number(1)),
  );
  const shrink = ifAction(
    api("And", api("GreaterThanEqualTo", getVariable(elapsed), number(180)), canShrink),
    chain(
      api("EnableGameModeObjective", valueInArray(allCapturePoints(), getVariable(stage)), boolean(false)),
      api(
        "EnableGameModeObjective",
        valueInArray(
          allCapturePoints(),
          api("Subtract", api("Subtract", api("CountOf", allCapturePoints()), number(1)), getVariable(stage)),
        ),
        boolean(false),
      ),
      setVariable(stage, api("Add", getVariable(stage), number(1))),
      setVariable(elapsed, number(0)),
    ),
  );
  return workspace([iterator, stage, elapsed], [
    rule("Initialize Escalation", "OnGameModeStarted", setup),
    captureScore,
    rule(
      "Advance escalation stage",
      "Ongoing",
      chain(
        api("Wait", number(1)),
        setVariable(elapsed, api("Add", getVariable(elapsed), number(1))),
        shrink,
      ),
      api("GreaterThan", api("CountOf", allCapturePoints()), number(1)),
    ),
    ...victoryRules(targetScore),
  ]);
}

function operationsWorkspace() {
  sequence = 0;
  const iterator = globalVariable("ObjectiveIterator");
  const current = globalVariable("CurrentObjectiveIndex");
  const setup = chain(
    api("SetGameModeScore", team(1), number(0)),
    api("SetGameModeScore", team(2), number(0)),
    api("SetGameModeTimeLimit", number(1500)),
    setVariable(current, number(0)),
    captureSetupLoop(iterator, false),
    ifAction(
      api("GreaterThan", api("CountOf", allCapturePoints()), number(0)),
      chain(
        api("SetCapturePointOwner", valueInArray(allCapturePoints(), number(0)), team(0)),
        api("EnableGameModeObjective", valueInArray(allCapturePoints(), number(0)), boolean(true)),
      ),
    ),
  );
  const advance = chain(
    api("EnableGameModeObjective", valueInArray(allCapturePoints(), getVariable(current)), boolean(false)),
    setVariable(current, api("Add", getVariable(current), number(1))),
    api("SetGameModeScore", team(1), getVariable(current)),
    ifAction(
      api("LessThan", getVariable(current), api("CountOf", allCapturePoints())),
      chain(
        api("SetCapturePointOwner", valueInArray(allCapturePoints(), getVariable(current)), team(0)),
        api("EnableGameModeObjective", valueInArray(allCapturePoints(), getVariable(current)), boolean(true)),
      ),
    ),
    ifAction(
      api("GreaterThanEqualTo", getVariable(current), api("CountOf", allCapturePoints())),
      api("EndGameMode", team(1)),
    ),
  );
  return workspace([iterator, current], [
    rule("Initialize Operations review flow", "OnGameModeStarted", setup),
    rule(
      "Advance after attacker capture",
      "OnCapturePointCaptured",
      advance,
      api(
        "And",
        api("Equals", api("EventTeam"), team(1)),
        api("Equals", api("EventCapturePoint"), valueInArray(allCapturePoints(), getVariable(current))),
      ),
    ),
  ]);
}

function strikepointWorkspace() {
  sequence = 0;
  const iterator = globalVariable("ObjectiveIterator");
  const targetScore = 15;
  const setup = gameStartActions(targetScore, 600);
  let tail = setup;
  while (tail.next) tail = tail.next.block;
  tail.next = input(chain(
    captureSetupLoop(iterator, false),
    ifAction(
      api("GreaterThan", api("CountOf", allCapturePoints()), number(0)),
      api("EnableGameModeObjective", valueInArray(allCapturePoints(), number(0)), boolean(true)),
    ),
  ));
  const killerTeam = () => team(api("EventPlayer"));
  return workspace([iterator], [
    rule("Initialize Strikepoint review round", "OnGameModeStarted", setup),
    rule(
      "Award elimination point",
      "OnPlayerEarnedKill",
      api("SetGameModeScore", killerTeam(), api("Add", api("GetGameModeScore", killerTeam()), number(1))),
      api("NotEqualTo", killerTeam(), team(api("EventOtherPlayer"))),
    ),
    rule(
      "Award central objective capture",
      "OnCapturePointCaptured",
      api(
        "SetGameModeScore",
        api("EventTeam"),
        api("Add", api("GetGameModeScore", api("EventTeam")), number(3)),
      ),
    ),
    ...victoryRules(targetScore),
  ]);
}

function mcom(idValue) {
  return api("GetMCOM", number(idValue));
}

function mcomGroupCondition(ids) {
  const comparisons = ids.map((mcomId) => api("Equals", api("EventMCOM"), mcom(mcomId)));
  let result = comparisons.shift();
  for (const comparison of comparisons) result = api("Or", result, comparison);
  return result;
}

function mcomObjectiveWorkspace(modeName, objectiveCount, splitIndex, fuseTime = 30) {
  sequence = 0;
  const targetScore = splitIndex;
  const team1Objectives = [];
  const team2Objectives = [];
  const setup = [
    api("SetGameModeScore", team(1), number(0)),
    api("SetGameModeScore", team(2), number(0)),
    api("SetGameModeTargetScore", number(targetScore)),
    api("SetGameModeTimeLimit", number(1200)),
  ];
  for (let index = 1; index <= objectiveCount; index += 1) {
    const owner = index <= splitIndex ? 1 : 2;
    const objectiveId = 300 + index;
    (owner === 1 ? team1Objectives : team2Objectives).push(objectiveId);
    setup.push(api("SetMCOMOwner", mcom(objectiveId), team(owner)));
    setup.push(api("SetMCOMFuseTime", mcom(objectiveId), number(fuseTime)));
    setup.push(api("EnableGameModeObjective", mcom(objectiveId), boolean(true)));
  }
  return workspace([], [
    rule(`Initialize ${modeName} M-COM review flow`, "OnGameModeStarted", chain(...setup)),
    rule(
      "Team 2 destroys Team 1 objective",
      "OnMCOMDestroyed",
      scoreFor(2, number(1)),
      mcomGroupCondition(team1Objectives),
    ),
    rule(
      "Team 1 destroys Team 2 objective",
      "OnMCOMDestroyed",
      scoreFor(1, number(1)),
      mcomGroupCondition(team2Objectives),
    ),
    ...victoryRules(targetScore),
  ]);
}

function sabotageWorkspace() {
  sequence = 0;
  const planting = { name: "PlantingObjective", id: "bf6_var_plantingobjective", type: "Player" };
  const destroyed = [1, 2, 3].map((site) => globalVariable(`Site${site}Destroyed`));
  const setup = [
    api("SetGameModeScore", team(1), number(0)),
    api("SetGameModeScore", team(2), number(2)),
    api("SetGameModeTargetScore", number(3)),
    api("SetGameModeTimeLimit", number(900)),
  ];
  for (let site = 1; site <= 3; site += 1) {
    setup.push(setVariable(destroyed[site - 1], boolean(false)));
    setup.push(api("EnableAreaTrigger", api("GetAreaTrigger", number(700 + site)), boolean(true)));
  }
  const rules = [rule("Initialize Sabotage review round", "OnGameModeStarted", chain(...setup))];
  for (let site = 1; site <= 3; site += 1) {
    const siteDestroyed = destroyed[site - 1];
    rules.push(rule(
      `Attack Site ${site}`,
      "OnPlayerEnterAreaTrigger",
      chain(
        setVariable(planting, boolean(true), api("EventPlayer")),
        api("Wait", number(10)),
        ifAction(
          api(
            "And",
            getVariable(planting, api("EventPlayer")),
            api("Not", getVariable(siteDestroyed)),
          ),
          chain(
            setVariable(siteDestroyed, boolean(true)),
            api("EnableAreaTrigger", api("GetAreaTrigger", number(700 + site)), boolean(false)),
            scoreFor(1, number(1)),
          ),
        ),
      ),
      api(
        "And",
        api("Equals", api("EventAreaTrigger"), api("GetAreaTrigger", number(700 + site))),
        api("Equals", team(api("EventPlayer")), team(1)),
      ),
    ));
  }
  rules.push(rule(
    "Cancel plant when attacker leaves",
    "OnPlayerExitAreaTrigger",
    setVariable(planting, boolean(false), api("EventPlayer")),
  ));
  rules.push(...victoryRulesForTeam(1, 3));
  return workspace([planting, ...destroyed], rules);
}

function payloadWorkspace() {
  sequence = 0;
  const iterator = globalVariable("CheckpointIterator");
  const current = globalVariable("CurrentCheckpoint");
  const count = globalVariable("CheckpointCount");
  const triggerLoop = block("ForVariable", {
    inputs: {
      "VALUE-0": input(variableReference(iterator)),
      "VALUE-1": input(number(0)),
      "VALUE-2": input(getVariable(count)),
      "VALUE-3": input(number(1)),
      DO: input(api(
        "EnableAreaTrigger",
        api("GetAreaTrigger", api("Add", number(801), getVariable(iterator))),
        boolean(true),
      )),
    },
  });
  const setup = chain(
    api("SetGameModeScore", team(1), number(0)),
    api("SetGameModeScore", team(2), number(4)),
    api("SetGameModeTargetScore", number(5)),
    api("SetGameModeTimeLimit", number(1200)),
    setVariable(current, number(0)),
    setVariable(count, number(5)),
    triggerLoop,
  );
  return workspace([iterator, current, count], [
    rule("Initialize Payload checkpoint scaffold", "OnGameModeStarted", setup),
    rule(
      "Advance ordered checkpoint",
      "OnPlayerEnterAreaTrigger",
      chain(
        api("EnableAreaTrigger", api("EventAreaTrigger"), boolean(false)),
        setVariable(current, api("Add", getVariable(current), number(1))),
        api("SetGameModeScore", team(1), getVariable(current)),
        ifAction(api("GreaterThanEqualTo", getVariable(current), getVariable(count)), api("EndGameMode", team(1))),
      ),
      api(
        "And",
        api("Equals", team(api("EventPlayer")), team(1)),
        api(
          "Equals",
          api("EventAreaTrigger"),
          api("GetAreaTrigger", api("Add", number(801), getVariable(current))),
        ),
      ),
    ),
  ]);
}

function carrierStrikeWorkspace() {
  sequence = 0;
  const base = mcomObjectiveWorkspace("Carrier Strike", 4, 2, 35);
  const iterator = globalVariable("CaptureIterator");
  base.mod.variables.push(iterator);
  const firstRule = base.mod.blocks.blocks[0].inputs.RULES.block;
  let tail = firstRule.inputs.ACTIONS.block;
  while (tail.next) tail = tail.next.block;
  tail.next = input(captureSetupLoop(iterator, true));
  firstRule.fields.NAME = "Initialize Carrier Strike review flow";
  return base;
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
    koth: {
      delivery: "playable_portal_translation",
      spatial_source: "game-derived KOTH capture points in importer-created alphabetical scene order",
      portal_translation: "Uses the same review workspace as kingofthehill because both catalog keys resolve the same public Portal behavior.",
      unresolved: ["Retail phase order and phase duration have not been decoded from the runtime controller."],
      workspace: "king_of_the_hill_game_data.workspace.json",
    },
    conquest: { delivery: "existing_plugin_contract", unresolved: [] },
    breakthrough: { delivery: "existing_template_compatibility_contract", unresolved: ["Retail reinforcement and sector-transition tuning remains runtime-authored."] },
    rush: { delivery: "existing_template_compatibility_contract", unresolved: ["Retail reinforcement and overtime tuning remains runtime-authored."] },
    escalation: {
      delivery: "playable_portal_translation",
      portal_translation: "Capture events score points and outer objectives disable every 180 seconds.",
      unresolved: ["gem_collection_event timing and exact authored stage activation order are not decoded."],
      workspace: "escalation_review.workspace.json",
    },
    strikepoint: {
      delivery: "playable_review_scaffold",
      portal_translation: "The first imported capture point is the central objective; kills and captures feed a short score race.",
      unresolved: ["Limited lives, round reset, side swap, and per-map round objective selection remain runtime-authored."],
      workspace: "strikepoint_review.workspace.json",
    },
    obliteration: {
      delivery: "playable_without_bomb_carry",
      portal_translation: "Stable M-COM IDs 301-306 are armed directly; destruction of enemy-owned targets scores.",
      unresolved: ["Portal exposes no Bomb object or carry/drop API, so the defining bomb loop is absent."],
      workspace: "obliteration_review.workspace.json",
    },
    squadobliteration: {
      delivery: "playable_without_bomb_carry",
      portal_translation: "Uses the same stable M-COM review flow with the smaller-mode layout.",
      unresolved: ["Portal exposes no Bomb object or carry/drop API."],
      workspace: "squad_obliteration_review.workspace.json",
    },
    payload: {
      delivery: "manual_trigger_scaffold",
      portal_translation: "Sequential AreaTrigger IDs 801-805 stand in for ordered checkpoints.",
      unresolved: ["Portal exposes no Payload object or motion API; the creator must place/size triggers on the imported checkpoint markers."],
      workspace: "payload_review.workspace.json",
    },
    sabotage: {
      delivery: "playable_area_trigger_translation",
      portal_translation: "Available game-derived destructible polygons receive AreaTrigger wrappers 701+; the generic review workspace consumes sites 701-703 and attackers hold a site for ten seconds.",
      unresolved: ["Direct cargo damage, variable objective counts, two-round side swap, and time tiebreak remain runtime-authored."],
      workspace: "sabotage_review.workspace.json",
    },
    carrierstrike: {
      delivery: "playable_review_scaffold",
      portal_translation: "Ground capture points and stable carrier M-COM IDs 301-304 are enabled together.",
      unresolved: ["VLS battery gating, carrier breach sequence, and destructible proxies lack public Portal equivalents."],
      workspace: "carrier_strike_review.workspace.json",
    },
    operations: {
      delivery: "playable_portal_translation",
      portal_translation: "Imported capture points advance sequentially for Team 1.",
      unresolved: ["Retail mixed sector/capture/M-COM phase graph and reinforcement tuning are not fully decoded."],
      workspace: "operations_review.workspace.json",
    },
    squaddeathmatch: {
      delivery: "playable_four_team_translation",
      portal_translation: "Four Portal teams stand in for four independently scored squads.",
      unresolved: ["Portal can read squad identity but SetGameModeScore accepts Team or Player, not Squad."],
      workspace: "squad_deathmatch_review.workspace.json",
    },
    gauntlet: {
      delivery: "playable_elimination_scaffold",
      portal_translation: "Four-team kill race provides a readable base for round/elimination work.",
      unresolved: ["Random mission selection, squad elimination, BR state, and game-authored mission controllers are not exposed as public Portal objects."],
      workspace: "gauntlet_review.workspace.json",
    },
  },
};

const outputs = {
  "domination_game_data.workspace.json": dominationWorkspace(),
  "team_deathmatch_game_data.workspace.json": teamDeathmatchWorkspace(),
  "king_of_the_hill_game_data.workspace.json": kingOfTheHillWorkspace(),
  "escalation_review.workspace.json": escalationWorkspace(),
  "operations_review.workspace.json": operationsWorkspace(),
  "strikepoint_review.workspace.json": strikepointWorkspace(),
  "squad_deathmatch_review.workspace.json": multiTeamDeathmatchWorkspace("Squad Deathmatch", 4, 50),
  "gauntlet_review.workspace.json": multiTeamDeathmatchWorkspace("Gauntlet elimination scaffold", 4, 20),
  "obliteration_review.workspace.json": mcomObjectiveWorkspace("Obliteration", 6, 3, 30),
  "squad_obliteration_review.workspace.json": mcomObjectiveWorkspace("Squad Obliteration", 6, 3, 25),
  "sabotage_review.workspace.json": sabotageWorkspace(),
  "payload_review.workspace.json": payloadWorkspace(),
  "carrier_strike_review.workspace.json": carrierStrikeWorkspace(),
  "mode_contracts.json": contracts,
};

const schemaArgument = process.argv.indexOf("--schema");
const schemaPath = schemaArgument >= 0 ? process.argv[schemaArgument + 1] : null;
const portalSchema = schemaPath ? JSON.parse(fs.readFileSync(schemaPath, "utf8")) : null;

validateCatalogCoverage();

fs.mkdirSync(outputRoot, { recursive: true });
for (const [filename, document] of Object.entries(outputs)) {
  if (filename.endsWith(".workspace.json")) {
    const result = validate(filename, document);
    if (portalSchema) validateAgainstPortalSchema(filename, document, portalSchema);
    console.log(`${filename}: ${result.blockCount} blocks, ${result.variableCount} variables`);
  }
  fs.writeFileSync(path.join(outputRoot, filename), `${JSON.stringify(document, null, 2)}\n`, "utf8");
}

function validateCatalogCoverage() {
  const catalog = JSON.parse(fs.readFileSync(path.join(repoRoot, "data", "layout_catalog.json"), "utf8"));
  const indexedModes = new Set();
  for (const map of Object.values(catalog.maps || {})) {
    for (const mode of map.modes || []) indexedModes.add(mode);
  }
  const missingContracts = [...indexedModes].filter((mode) => !contracts.modes[mode]);
  const existingCreatorTemplates = new Set(["conquest", "breakthrough", "rush"]);
  const missingWorkspaces = [...indexedModes].filter((mode) => {
    const contract = contracts.modes[mode];
    return !existingCreatorTemplates.has(mode) && (!contract || !contract.workspace || !outputs[contract.workspace]);
  });
  if (missingContracts.length || missingWorkspaces.length) {
    throw new Error(`Catalog coverage failed; missing contracts: ${missingContracts.join(", ") || "none"}; missing workspaces: ${missingWorkspaces.join(", ") || "none"}`);
  }
  console.log(`catalog coverage: ${indexedModes.size} modes, ${indexedModes.size - existingCreatorTemplates.size} workspace-backed modes, 3 existing creator templates`);
}
