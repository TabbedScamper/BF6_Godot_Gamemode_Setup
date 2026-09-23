@tool
extends RefCounted

const VehicleSkin = preload("res://addons/bf6_gamemode_setup/vehicle_skin.gd")
const CarrierPreview = preload("res://addons/bf6_gamemode_setup/carrier_preview.gd")

const BUILD_META := "bf6_gamemode_setup"
const PROVENANCE_META := "bf6_source"
const TEMPLATE_NAME := "Andy Rush/Breakthrough Blockly contract"
const RETAIL_SETTINGS := "res://addons/bf6_gamemode_setup/data/retail_mode_runtime_contracts.json"
const KOTH_CANDIDATES := "res://addons/bf6_gamemode_setup/data/koth_candidates.json"
const OPERATIONS_CANDIDATES := "res://addons/bf6_gamemode_setup/data/operations_candidates.json"
const BOMB_CANDIDATES := "res://addons/bf6_gamemode_setup/data/bomb_candidates.json"
const SCENES := {
	"capture": "res://objects/gameplay/conquest/CapturePoint.tscn",
	"hq": "res://objects/gameplay/common/HQ_PlayerSpawner.tscn",
	"vehicle": "res://objects/gameplay/common/VehicleSpawner.tscn",
	"stationary": "res://objects/gameplay/common/StationaryEmplacementSpawner.tscn",
	"spawn": "res://objects/entities/SpawnPoint.tscn",
	"volume": "res://addons/bf_portal/portal_tools/types/PolygonVolume/PolygonVolume.tscn",
	"obb": "res://addons/bf_portal/portal_tools/types/OBBVolume/OBBVolume.tscn",
	"combat": "res://objects/gameplay/common/CombatArea.tscn",
	"area_trigger": "res://objects/gameplay/common/AreaTrigger.tscn",
	"deploy_cam": "res://objects/gameplay/common/DeployCam.tscn",
	"sector": "res://objects/gameplay/common/Sector.tscn",
	"resupply": "res://objects/gameplay/common/VehicleResupplyStation.tscn",
	"mcom": "res://objects/gameplay/rush/MCOM.tscn",
	"bomb": "res://objects/gameplay/obliteration/Bomb.tscn",
	"automatic_aa": "res://objects/gameplay/vehicles/VEH_Stationary_AutomaticAA.tscn",
}
const VEHICLE_NAMES := [
	"Abrams", "Leopard", "Cheetah", "CV90", "Gepard", "UH60", "Eurocopter",
	"AH6M", "AH64", "Vector", "Quadbike", "GolfCart", "Marauder", "Flyer60",
	"JAS39", "F22", "F16", "M2Bradley", "SU57", "UH60_Pax", "Marauder_Pax",
	"RHIB", "DirtBike", "DirtBike_Pax", "AH6M_Pax", "Couch",
	"RCB_90_Patrol_Boat", "RCB_90_Patrol_Boat_Pax", "F_74A_Seacat",
	"F_74A_Seacat_Pax", "FA_81F_Super_Spectre", "FA_81F_Super_Spectre_Pax",
]
# AD_Objective_Conquest maps the GEM's 0x783E16EC value to one of these retail
# class prefabs.  Each class prefab's lpf_vehiclespawner_factionpicker then
# selects a concrete vehicle for Team 1 or Team 2.  The numbers below are the
# resulting ModBuilder_Enum_VehicleList values, not guesses based on selector
# order.  Single-entry classes are shared or already faction-specific.
const VEHICLE_CLASS_NAMES := {
	0: "LightTransport", 1: "IFV", 2: "Tank", 3: "MobileAA",
	4: "AttackPlane", 5: "FighterPlane", 6: "AttackHelicopter",
	7: "TransportHelicopter", 8: "QuadBike", 9: "APC", 10: "GolfCart",
	11: "RHIB", 12: "ScoutHelicopter", 13: "DirtBike", 14: "PatrolBoat",
	15: "MultirolePlane", 16: "NavalFighterPlane",
	17: "F16CarrierLaunch", 18: "F22CarrierLaunch", 19: "JAS39CarrierLaunch",
	20: "SU57CarrierLaunch", 21: "F14CarrierLaunch",
	22: "FA18CarrierLaunchNATO", 23: "FA18CarrierLaunchPAX",
}
const VEHICLE_CLASS_TYPES := {
	0: [13, 9],  # LightTransport: Flyer60 / Vector
	1: [17, 3],  # IFV: M2Bradley / CV90
	2: [0, 1],   # Tank: Abrams / Leopard
	3: [2, 4],   # MobileAA: Cheetah / Gepard
	4: [16, 14], # AttackPlane: F16 / JAS39
	5: [15, 18], # FighterPlane: F22 / SU57
	6: [8, 6],   # AttackHelicopter: AH64 / Eurocopter
	7: [5, 19],  # TransportHelicopter: UH60 / UH60_Pax
	8: [10],     # Quadbike
	9: [12, 20], # APC: Marauder / Marauder_Pax
	10: [11],    # GolfCart
	11: [21],    # RHIB
	12: [7, 24], # ScoutHelicopter: AH6M / AH6M_Pax
	13: [22, 23],# DirtBike / DirtBike_Pax
	14: [26, 27],# PatrolBoat / PatrolBoat_Pax
	15: [30, 31],# Super Spectre / Super Spectre Pax
	16: [28, 29],# Seacat / Seacat Pax
	17: [16], 18: [15], 19: [14], 20: [18], 21: [28], 22: [30], 23: [31],
}
# AD_Objective_Conquest orders the stationary classes HMG, AntiTank, AntiAir,
# while the Portal enum orders BGM71TOW, GDF009, M2MG.
const STATIONARY_SELECTOR_TYPES := {0: 2, 1: 0, 2: 1}
const CAPTURE_POINT_MODES := {
	"conquest": true, "domination": true, "breakthrough": true,
	"operations": true, "escalation": true, "carrierstrike": true,
	"koth": true, "kingofthehill": true, "strikepoint": true,
}
const CATCH_ALL_SECTOR_MODES := {
	"conquest": true, "domination": true, "carrierstrike": true,
}
const TEAM_1_VOLUME_COLOR := Color(0.0, 0.53, 0.99, 0.42)
const TEAM_2_VOLUME_COLOR := Color(0.95, 0.23, 0.0, 0.42)
const TEAM_VOLUME_LINK_PROPERTIES := [
	&"HQArea", &"ProtectionAreaVolume", &"CaptureArea", &"Area",
]


static func build(map_root: Node, layout_id: String, document: Dictionary,
		paths: Dictionary, replace_existing: bool, progress: Callable = Callable()) -> String:
	var source := document.get("source", {}) as Dictionary
	var level := str(source.get("level", ""))
	var mode := str(source.get("mode", ""))
	if mode in ["rush", "breakthrough"]:
		return preload("res://addons/bf6_gamemode_setup/progressive_builder.gd").build(
			map_root, layout_id, document, replace_existing, progress,
			load("res://addons/bf6_gamemode_setup/classified_builder.gd"), paths)
	if int(document.get("schema", 0)) not in [2, 3, 4] or level == "" or mode == "":
		return "Classified layout manifest is invalid"
	var koth_evidence := {}
	if mode in ["koth", "kingofthehill"]:
		var koth_package = JSON.parse_string(FileAccess.get_file_as_string(KOTH_CANDIDATES))
		if koth_package is Dictionary:
			koth_evidence = koth_package.get("maps", {}).get(level.to_lower(), {})
		if not koth_evidence.is_empty():
			var expected: Array = koth_evidence.get("capture_guids", [])
			var found: Array = []
			for element in document.get("elements", []):
				if str(element.get("gem", "")) == "gem_capturepoint":
					found.append(str(element.get("instance_guid", "")).to_lower())
			found.sort()
			var sorted_expected := expected.duplicate()
			sorted_expected.sort()
			if found != sorted_expected:
				return "KOTH candidate identities disagree with the selected game layout for %s; existing scene preserved." % level
	var operations_evidence := {}
	if mode == "operations":
		var operations_package = JSON.parse_string(FileAccess.get_file_as_string(OPERATIONS_CANDIDATES))
		if operations_package is Dictionary:
			operations_evidence = operations_package.get("maps", {}).get(level.to_lower(), {})
		if not operations_evidence.is_empty():
			var available := {}
			for element in document.get("elements", []):
				available[str(element.get("partition", "")) + "#" + str(element.get("instance_guid", ""))] = true
			var shapes := {}
			for shape in document.get("capture_shapes", []):
				shapes[str(shape.get("controller_instance_guid", ""))] = true
			for candidate in operations_evidence.sectors:
				if not available.has(candidate.sector):
					return "Operations selected sector is absent from this export; existing scene preserved: " + str(candidate.sector)
				for member_id in candidate.captures:
					if not available.has(member_id) or not shapes.has(str(member_id).get_slice("#", 1)):
						return "Operations selected capture or area is absent from this export; existing scene preserved: " + str(member_id)
				for member_id in candidate.hqs:
					if not available.has(member_id):
						return "Operations selected HQ is absent from this export; existing scene preserved: " + str(member_id)
	var bomb_evidence := {}
	if mode in ["obliteration", "squadobliteration"]:
		var bomb_package = JSON.parse_string(FileAccess.get_file_as_string(BOMB_CANDIDATES))
		if bomb_package is Dictionary:
			bomb_evidence = bomb_package.get("layouts", {}).get(level.to_lower() + "/" + mode, {})
		if not bomb_evidence.is_empty():
			var sector_found := false
			for element in document.get("elements", []):
				if str(element.get("partition", "")) + "#" + str(element.get("instance_guid", "")) == bomb_evidence.sector:
					sector_found = true
			if not sector_found:
				return "Bomb-mode selected sector is absent from this export; existing scene preserved."
			for spec in [[8, "mcoms"], [9, "bombs"], [100, "hqs"]]:
				var found_members: Array = []
				for object in document.get("objects", []):
					if int(object.get("role", 0)) != spec[0]: continue
					var raw: Dictionary = object.get("raw", {})
					found_members.append(str(raw.get("partition", "")) + "#" + str(raw.get("instance_guid", "")))
				found_members.sort()
				var expected_members: Array = bomb_evidence[spec[1]].duplicate()
				expected_members.sort()
				if found_members != expected_members:
					return "Bomb-mode selected %s disagree with the game layout; existing scene preserved." % spec[1]
	var existing := _find(map_root, layout_id)
	if existing != null:
		if not replace_existing:
			(existing as Node3D).visible = true
			return "Shown existing %s layout" % _pretty(mode)
		map_root.remove_child(existing)
		existing.free()

	var root := Node3D.new()
	root.name = _pretty(mode).replace(" ", "")
	root.set_meta(BUILD_META, layout_id)
	root.set_meta(PROVENANCE_META, "installed BF6 %s/%s; classified layout schema %d" % [
		level, mode, int(document.get("schema", 0))])
	root.set_meta("bf6_relationship_status",
		"game-derived placements; mode-specific relationships may be classified or incomplete")
	if mode in ["koth", "kingofthehill"]:
		if koth_evidence.is_empty():
			root.set_meta("bf6_koth_candidate_status", "retail selected candidate graph unavailable for this map")
		else:
			root.set_meta("bf6_koth_candidate_status",
				"exact selected candidate identities and authored link order; live hill rotation unverified")
			root.set_meta("bf6_koth_candidate_guids", koth_evidence.capture_guids)
			root.set_meta("bf6_koth_candidate_link_indices", koth_evidence.link_indices)
			root.set_meta("bf6_koth_layout_identity", koth_evidence.layout)
	if mode == "operations" and not operations_evidence.is_empty():
		root.set_meta("bf6_operations_candidate_status",
			"exact selected sector/HQ/capture membership; gameplay phase and battalion order unverified")
		root.set_meta("bf6_operations_layout_identity", operations_evidence.layout)
	if mode in ["obliteration", "squadobliteration"] and not bomb_evidence.is_empty():
		root.set_meta("bf6_bomb_candidate_status",
			"exact selected bomb/MCOM/HQ sites; live bomb selection and activation unverified")
		root.set_meta("bf6_bomb_layout_identity", bomb_evidence.layout)
	_apply_retail_mode_settings(root, mode)
	if mode in ["rush", "breakthrough"]:
		root.set_meta("bf6_template_compatibility", TEMPLATE_NAME)
		root.set_meta("bf6_template_compatibility_policy",
			"Game-derived spatial/type data is retained; marked IDs, hierarchy, teams, " +
			"and aliases are compatibility adjustments and are not claimed as retail instances.")
	map_root.add_child(root)
	root.owner = map_root
	var captures_root := _folder(root, "Objectives", map_root)
	var zones_root := _folder(root, "Play Area", map_root)
	var spawns_root := _folder(root, "Spawns", map_root)
	var vehicles_root := _folder(root, "Vehicles", map_root)
	var hq_vehicles_root := _folder(vehicles_root, "HQ", map_root)
	var hq_vehicle_team_roots := [
		_folder(hq_vehicles_root, "Team1", map_root),
		_folder(hq_vehicles_root, "Team2", map_root),
	]
	var objective_vehicles_root := _folder(vehicles_root, "Objectives", map_root)
	var objective_shared_root := _folder(vehicles_root, "Unassigned", map_root)
	var emplacements_root := _folder(root, "Emplacements", map_root)
	var resupply_root := _folder(root, "Resupply", map_root)
	var aa_root := _folder(root, "AA-Defences", map_root)
	var attachments_root := _folder(root, "Extras", map_root)
	var objects: Array = document.get("objects", [])
	var elements: Array = document.get("elements", [])
	var progress_total := objects.size() + 2
	var progress_current := 0
	_report(progress, "Preparing %s hierarchy…" % _pretty(mode), progress_current, progress_total)
	var captures := {}
	var capture_spawns := {}
	var hqs: Array = []
	if level == "mp_capstone" and mode == "conquest":
		_build_capstone_out_of_bounds(objects, zones_root, map_root)

	var capture_rows: Array = []
	if mode in ["conquest", "breakthrough", "operations"] and \
			not (document.get("capture_shapes", []) as Array).is_empty():
		capture_rows = _exact_capture_rows(document, elements, mode)
	else:
		for value in objects:
			var candidate := value as Dictionary
			if int(candidate.get("role", 0)) == 2 and CAPTURE_POINT_MODES.has(mode) and \
					_normalized_flag(level, mode, candidate) >= 0:
				capture_rows.append(candidate)
	capture_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_flag := _normalized_flag(level, mode, a)
		var b_flag := _normalized_flag(level, mode, b)
		return a_flag < b_flag if a_flag != b_flag else _root_order(a) < _root_order(b))
	for value in capture_rows:
		var row := value as Dictionary
		var flag := _normalized_flag(level, mode, row)
		if flag < 0:
			continue
		var capture := _scene("capture", "CapturePoint%s" % String.chr(65 + flag))
		capture.position = _vec3(row.get("centre", []))
		var exact_binding := row.get("capture_binding", {}) as Dictionary
		var capture_source := row.get("raw", {}) as Dictionary
		var capture_transform := capture_source.get("transform", []) as Array
		if str(exact_binding.get("method", "")).begins_with(
				"installed_gem_instance_parameter_") and \
				capture_transform.size() == 12:
			# Keep the placed controller at its exact game transform. Its attached
			# polygon can have a different centroid and floor elevation.
			capture.position = _vec3(capture_transform.slice(9, 12))
		capture.set("ObjId", 200 + flag)
		capture.set_meta(PROVENANCE_META, _source(row))
		var capture_binding := row.get("capture_binding", {}) as Dictionary
		if not capture_binding.is_empty():
			capture.set_meta("bf6_capture_instance_guid",
				str(capture_binding.get("instance_guid", "")))
			capture.set_meta("bf6_capture_root_order",
				int(capture_binding.get("root_order", -1)))
			capture.set_meta("bf6_capture_volume_binding",
				str(capture_binding.get("method", "")))
		captures_root.add_child(capture)
		capture.owner = map_root
		var area := _polygon(row, "Area-%s" % String.chr(65 + flag), Color(1.0, 0.55, 0.1, 0.42))
		capture.add_child(area)
		area.owner = map_root
		area.position -= capture.position
		capture.set("CaptureArea", area)
		captures[flag] = capture
		capture_spawns[flag] = {1: [], 2: []}
		progress_current += 1
		_report(progress, "Creating objectives…", progress_current, progress_total)

	var hq_rows: Array = []
	for value in objects:
		var candidate := value as Dictionary
		if int(candidate.get("role", 0)) == 100:
			hq_rows.append(candidate)
	if mode == "conquest" and hq_rows.size() > 2:
		hq_rows = _conquest_hqs_with_authored_insertions(hq_rows, elements)
	elif mode in ["rush", "breakthrough", "operations"]:
		hq_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _root_order(a) < _root_order(b))
	for value in hq_rows:
		var row := value as Dictionary
		var hq := _scene("hq", "HQ_Root%02d" % _root_order(row))
		hq.transform = _raw_transform(row)
		hq.set_meta(PROVENANCE_META, _source(row))
		hq.set_meta("bf6_source_instance_guid",
			str((row.get("raw", {}) as Dictionary).get("instance_guid", "")))
		var hq_raw: Dictionary = row.get("raw", {})
		hq.set_meta("bf6_source_identity",
			str(hq_raw.get("partition", "")) + "#" + str(hq_raw.get("instance_guid", "")))
		hq.set_meta("bf6_root_order", int((row.get("raw", {}) as Dictionary).get(
			"root_order", hqs.size())))
		root.add_child(hq)
		hq.owner = map_root
		hqs.append(hq)
		progress_current += 1
		_report(progress, "Creating headquarters…", progress_current, progress_total)
	if mode in ["rush", "breakthrough", "operations"]:
		var progressive_sectors := _progressive_sector_rows(mode, elements, objects)
		var progressive_hq_groups := _group_progressive_hqs(hqs, progressive_sectors, objects)
		_assign_progressive_hq_teams(progressive_hq_groups, progressive_sectors)
	for hq_index in range(hqs.size()):
		var hq := hqs[hq_index] as Node3D
		var hq_team := int(hq.get_meta("bf6_progressive_team", 0))
		if hq_team == 0:
			# Progressive retail ownership is runtime-fed. When a Portal template
			# requires a team, use its documented Team-1-attacks alternating slot
			# contract in authored order, never map position.
			hq_team = (hq_index % 2) + 1 if mode in ["rush", "breakthrough", "operations"] \
				else (hq_index + 1 if hqs.size() <= 2 else _hq_faction_for_point(hqs, hq.position))
			if mode in ["rush", "breakthrough", "operations"]:
				hq.set_meta("bf6_progressive_team_basis",
					"Portal template contract; authored HQ order retained")
		hq.set("Team", hq_team)
		hq.set("AltTeam", 2 if hq_team == 1 else 1)
		if hq.has_meta("bf6_progressive_phase"):
			var phase := int(hq.get_meta("bf6_progressive_phase"))
			hq.set("ObjId", (300 if hq_team == 1 else 400) + phase + 1)
			hq.name = "TEAM_%d_HQ%d" % [hq_team, phase + 1]
			_mark_template_adjustment(hq,
				"Portal HQ ObjId, team, and phase hierarchy assigned for the Blockly contract; " +
				"transform and spawn data remain game-derived.")
			hq.set_meta("bf6_faction_assignment",
				"Portal Team-1-attacks contract applied to authored HQ order")
		else:
			hq.set("ObjId", hq_index + 1)
			hq.name = "TEAM_%d_HQ" % hq_team if hqs.size() <= 2 else \
				"TEAM_%d_HQ_Root%02d" % [hq_team,
					int(hq.get_meta("bf6_root_order", hq_index))]
			hq.set_meta("bf6_faction_assignment", "authored order" if hqs.size() <= 2 else \
				("unassigned progressive HQ; authored order only" if mode in \
				["rush", "breakthrough", "operations"] else \
				"nearest endpoint fallback; no staged sector assignment"))
	var claimed_zone_sources := {}
	var claimed_capture_sources := {}
	for value in capture_rows:
		var capture_row := value as Dictionary
		if int(capture_row.get("role", 0)) == 3:
			claimed_capture_sources[_row_key(capture_row)] = true
	if mode == "conquest" and not hqs.is_empty():
		claimed_zone_sources = _assign_hq_areas(objects, hqs, map_root)
	elif mode in ["rush", "breakthrough", "operations"] and not hqs.is_empty():
		claimed_zone_sources = _assign_hq_areas(objects, hqs, map_root, true)
	if mode == "conquest":
		_build_combat_area_from_unclaimed_zones(objects, claimed_zone_sources,
			zones_root, map_root)

	var hq_spawns: Array = []
	for _index in range(hqs.size()): hq_spawns.append([])
	var insertion_rows := _mode_elements(elements, "gem_insertion")
	insertion_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("root_order", -1)) < int(b.get("root_order", -1)))
	# An insertion marker is not itself a player spawn. The generic Operations
	# path has no exact insertion-to-HQ spawn link, so do not materialize one.
	# Rush/Breakthrough use their separate exact-link importer.
	var has_authored_hq_insertions := mode not in ["operations", "rush", "breakthrough"] and \
		 not insertion_rows.is_empty() and not hqs.is_empty()
	if has_authored_hq_insertions:
		for value in insertion_rows:
			var insertion := value as Dictionary
			var insertion_transform := _element_transform(insertion)
			var hq_index := _containing_hq(hqs, insertion_transform.origin) \
				if mode in ["rush", "breakthrough", "operations"] else \
				_nearest_index(hqs, insertion_transform.origin)
			if hq_index < 0:
				continue
			var hq := hqs[hq_index] as Node3D
			var spawn := _scene("spawn", "Spawn_HQ_%d_%02d" % [
				int(hq.get("Team")), hq_spawns[hq_index].size() + 1])
			spawn.transform = hq.transform.affine_inverse() * insertion_transform
			spawn.set_meta(PROVENANCE_META, "%s instance %s root %s" % [
				str(insertion.get("layer", "")), str(insertion.get("instance_guid", "?")),
				str(insertion.get("root_order", "-"))])
			spawn.set_meta("bf6_spawn_binding", "inside exact installed HQ polygon" \
				if mode in ["rush", "breakthrough", "operations"] else "nearest HQ")
			spawn.set_meta("bf6_spawn_team", int(hq.get("Team")))
			hq.add_child(spawn)
			spawn.owner = map_root
			hq_spawns[hq_index].append(spawn)

	var loose_spawns: Array = []
	var spawn_counts := {}
	for value in objects:
		var row := value as Dictionary
		if int(row.get("role", 0)) != 1:
			continue
		# Progressive AlternateSpawn records are emitted only when an exact game
		# CaptureArea or HQArea contains them. Uncontained records remain omitted;
		# they are never assigned using distance.
		if mode in ["rush", "breakthrough", "operations"]:
			var progressive_point := _vec3(row.get("centre", []))
			var progressive_flag := _containing_capture(captures, progressive_point)
			var progressive_hq := _containing_hq(hqs, progressive_point)
			if progressive_flag < 0 and progressive_hq < 0:
				continue
			var spawn_guid := str((row.get("raw", {}) as Dictionary).get(
				"instance_guid", "unknown")).left(8)
			var progressive_spawn := _scene("spawn", "Spawn_Game_%s" % spawn_guid)
			progressive_spawn.transform = _raw_transform(row)
			progressive_spawn.set_meta(PROVENANCE_META, _source(row))
			progressive_spawn.set_meta("bf6_spawn_team", int(row.get("team", 0)))
			progressive_spawn.set_meta("bf6_spawn_binding",
				"inside exact installed %s polygon" % ("capture" if progressive_flag >= 0 else "HQ"))
			if progressive_flag >= 0:
				var progressive_capture := captures[progressive_flag] as Node3D
				_reparent_new_layout_node(progressive_spawn, progressive_capture, map_root)
				_append_spawn_for_team(capture_spawns, progressive_flag, progressive_spawn,
					int(row.get("team", 0)))
			else:
				var progressive_hq_node := hqs[progressive_hq] as Node3D
				_reparent_new_layout_node(progressive_spawn, progressive_hq_node, map_root)
				hq_spawns[progressive_hq].append(progressive_spawn)
			continue
		var flag := _normalized_flag(level, mode, row)
		var spawn_key := "Flag_%s" % String.chr(65 + flag) if flag >= 0 else "Unassigned"
		var spawn_index := int(spawn_counts.get(spawn_key, 0)) + 1
		spawn_counts[spawn_key] = spawn_index
		var spawn := _scene("spawn", "Spawn_%s_%02d" % [spawn_key, spawn_index])
		spawn.transform = _raw_transform(row)
		spawn.set_meta(PROVENANCE_META, _source(row))
		spawn.set_meta("bf6_spawn_team", int(row.get("team", 0)))
		var parent: Node = captures.get(flag, spawns_root)
		parent.add_child(spawn)
		spawn.owner = map_root
		if parent != spawns_root:
			spawn.transform = (parent as Node3D).transform.affine_inverse() * spawn.transform
			_append_spawn_for_team(capture_spawns, flag, spawn, int(row.get("team", 0)))
		else:
			loose_spawns.append(spawn)
		progress_current += 1
		_report(progress, "Creating infantry spawns…", progress_current, progress_total)
	# Progressive capture controllers do not carry a flag number on their retail
	# AlternateSpawnEntityData records. They still belong to the nearby live
	# objective and must populate both Portal team arrays when the game record is
	# neutral, exactly like the template contract.
	var captures_own_loose_spawns := mode in ["conquest", "carrierstrike", "escalation"]
	for spawn_value in loose_spawns:
		var spawn := spawn_value as Node3D
		# These nodes are assembled before the generated branch enters the scene
		# tree.  global_position is undefined in that state and Godot returns a
		# zero transform, which used to send otherwise-authored spawns to arbitrary
		# objectives.  The folder nodes are identity transforms, so every position
		# in this pass is already in the common layout coordinate system.
		var point := spawn.position
		var nearest_flag := _nearest_capture(captures, point) if not captures.is_empty() else -1
		var capture_distance := point.distance_squared_to((captures[nearest_flag] as Node3D).position) \
			if nearest_flag >= 0 else INF
		var hq_index := _nearest_index(hqs, point) if not hqs.is_empty() else -1
		var hq_distance := point.distance_squared_to((hqs[hq_index] as Node3D).position) \
			if hq_index >= 0 else INF
		if captures_own_loose_spawns and nearest_flag >= 0 and \
				capture_distance <= hq_distance:
			var capture := captures[nearest_flag] as Node3D
			_reparent_from_layout_space(spawn, capture, map_root)
			var key := "Flag_%s" % String.chr(65 + nearest_flag)
			var index := int(spawn_counts.get(key, 0)) + 1
			spawn_counts[key] = index
			spawn.name = "Spawn_%s_%02d" % [key, index]
			spawn.set_meta("bf6_capture_flag", nearest_flag)
			_append_spawn_for_team(capture_spawns, nearest_flag, spawn,
				int(spawn.get_meta("bf6_spawn_team", 0)))
		elif hq_index >= 0:
			_reparent_from_layout_space(spawn, hqs[hq_index], map_root)
			spawn.name = "Spawn_HQ_%d_%02d" % [hq_index + 1, hq_spawns[hq_index].size() + 1]
			hq_spawns[hq_index].append(spawn)
	for flag in captures:
		_set_array(captures[flag], "InfantrySpawnPoints_Team1", capture_spawns[flag][1])
		_set_array(captures[flag], "InfantrySpawnPoints_Team2", capture_spawns[flag][2])
	for hq_index in range(hqs.size()):
		_set_array(hqs[hq_index], "InfantrySpawns", hq_spawns[hq_index])

	var hq_vehicle_links: Array = []
	for _index in range(hqs.size()): hq_vehicle_links.append([])
	var objective_vehicle_counts := {}
	var bomb_nodes := {}
	var mcom_nodes := {}
	for value in objects:
		var row := value as Dictionary
		var role := int(row.get("role", 0))
		if role == 6:
			_build_vehicle(row, objective_shared_root, hq_vehicle_team_roots,
				objective_vehicles_root, emplacements_root, map_root, captures,
				hqs, hq_vehicle_links, objective_vehicle_counts, level, mode)
		elif role == 7:
			var resupply := _scene("resupply", str(row.get("label", "Resupply")))
			resupply.transform = _raw_transform(row)
			resupply.set_meta(PROVENANCE_META, _source(row))
			resupply_root.add_child(resupply)
			resupply.owner = map_root
			VehicleSkin.sync_resupply(resupply, map_root)
		elif role == 8:
			if mode in ["obliteration", "squadobliteration", "carrierstrike"]:
				var folder_name := "Carrier Objectives" if mode == "carrierstrike" else "MCOM Objectives"
				var mcom_root := _folder(captures_root, folder_name, map_root)
				var mcom := _add_plain(row, "mcom", mcom_root, map_root)
				mcom_nodes[mcom.get_meta("bf6_source_identity")] = mcom
				var mcom_slot := maxi(str(row.get("label", "MCOM 1")).get_slice(" ", 1).to_int(), 1)
				mcom.name = "MCOM_%02d_Root%02d" % [mcom_slot, _root_order(row)]
				mcom.set("ObjId", 300 + mcom_slot)
				mcom.set_meta("bf6_portal_translation",
					"Stable 301+ label-order identity for the review Blockly workspace; " +
					"M-COM transform and sequence label are game-derived.")
				if mode in ["obliteration", "squadobliteration"]:
					mcom.set("RequiresCarriableToArm", true)
					mcom.set_meta("bf6_mode_contract", "carried bomb required")
			elif mode != "rush":
				_add_plain(row, "mcom", attachments_root, map_root)
		elif role == 9:
			if mode in ["obliteration", "squadobliteration"]:
				var bombs_root := _folder(captures_root, "Bomb Spawn Candidates", map_root)
				var bomb := _add_plain(row, "bomb", bombs_root, map_root)
				bomb_nodes[bomb.get_meta("bf6_source_identity")] = bomb
				bomb.name = "BombCandidate_Root%02d" % _root_order(row)
				bomb.set("ObjId", 400 + maxi(_root_order(row), 0))
				bomb.set_meta("bf6_runtime_activation",
					"retail graph selects the active bomb; placement data has no scalar active flag")
			else:
				_add_plain(row, "bomb", attachments_root, map_root)
		elif role == 10:
			# gem_specialcombatarea is the controller used to find the outer
			# SurroundingVolume. It has no standalone Portal object and should not
			# appear as a misleading "Special Area 1" scene node.
			pass
		elif role == 101:
			var authored_team := int(row.get("team", 0))
			var team_choice := _automatic_aa_team(hqs, _vec3(row.get("centre", []))) \
				if authored_team == 0 else {"team": authored_team, "basis": "authored placement"}
			var aa_team := int(team_choice.team)
			var aa := _scene("automatic_aa", _automatic_aa_name(row, aa_team))
			aa.transform = _raw_transform(row)
			aa.set_meta(PROVENANCE_META, _source(row))
			aa_root.add_child(aa)
			aa.owner = map_root
			aa.set_meta("bf6_owner_team_basis", str(team_choice.basis))
			aa.set_meta("bf6_authored_owner_team", authored_team)
			if aa_team > 0:
				aa.set("OwnerTeam", aa_team)
				aa.set_meta("bf6_owner_team", aa_team)
			var protection_shape := row.get("protection_shape", {}) as Dictionary
			if not protection_shape.is_empty():
				var protection := _spatial_protection_polygon(protection_shape,
					"ProtectionArea_Root%02d_%s" % [_root_order(row),
						str(protection_shape.get("kind", "Shape")).capitalize()])
				# PolygonVolume only supports a world-horizontal XZ plane. Keeping it
				# below a terrain-aligned AA turret makes it inherit the turret's pitch
				# and roll even though its own script clamps local pitch/roll. Store the
				# volume beside the turret and retain the inspector reference instead.
				aa_root.add_child(protection)
				protection.owner = map_root
				aa.set("ProtectionAreaVolume", protection)
				aa.set_meta("bf6_protection_binding", "installed_gem_instance_parameter")
				aa.set_meta("bf6_protection_instance_guid",
					str(protection_shape.get("instance_guid", "")))
			VehicleSkin.sync_automatic_aa(aa, map_root)
		if role in [6, 7, 8, 9, 10, 101]:
			progress_current += 1
			_report(progress, "Creating vehicles and attachments…", progress_current, progress_total)

	for hq_index in range(hqs.size()):
		_set_array(hqs[hq_index], "VehicleSpawners", hq_vehicle_links[hq_index])
		hqs[hq_index].set("VehicleSpawnersEnabled", not hq_vehicle_links[hq_index].is_empty())
	if mode == "rush":
		var rush_claimed := _build_rush_objectives(objects, captures_root,
			map_root, hqs, elements)
		for key in rush_claimed:
			claimed_zone_sources[key] = true
	elif mode == "operations" and not operations_evidence.is_empty():
		_build_operations_candidate_sectors(operations_evidence, elements,
			captures, hqs, captures_root, map_root)
	elif mode in ["breakthrough", "operations"] and not captures.is_empty():
		var breakthrough_claimed := _build_breakthrough_sectors(captures,
			captures_root, map_root, elements, hqs, objects, mode,
			claimed_capture_sources)
		for key in breakthrough_claimed:
			claimed_zone_sources[key] = true
	elif mode == "payload":
		_build_payload_objectives(elements, captures_root, map_root)
	elif mode == "sabotage":
		_build_sabotage_objectives(objects, elements, captures_root, map_root)
	elif mode == "carrierstrike":
		_build_carrier_objectives(elements, captures_root, map_root)
	elif mode in ["obliteration", "squadobliteration"] and not bomb_evidence.is_empty():
		_build_bomb_candidate_sector(bomb_evidence, elements, hqs,
			mcom_nodes, bomb_nodes, captures_root, map_root)
	_build_deploy_cameras(elements, attachments_root, map_root)

	for value in objects:
		var row := value as Dictionary
		match int(row.get("role", 0)):
			2:
				if mode == "rush":
					_add_polygon(row, zones_root, map_root,
						Color(0.55, 0.75, 0.95, 0.35))
			3:
				if not claimed_zone_sources.has(_row_key(row)) and \
						not claimed_capture_sources.has(_row_key(row)):
					if level == "mp_dumbo" and mode == "conquest":
						continue
					_add_polygon(row, zones_root, map_root, Color(0.55, 0.75, 0.95, 0.35))
			4:
				if claimed_zone_sources.has(_row_key(row)):
					continue
				var combat := _scene("combat", str(row.get("label", "Combat Area")))
				combat.position = _vec3(row.get("centre", []))
				zones_root.add_child(combat)
				combat.owner = map_root
				var volume := _polygon(row, "CombatVolume", Color(0.2, 0.75, 0.3, 0.3))
				combat.add_child(volume)
				volume.owner = map_root
				volume.position -= combat.position
				combat.set("CombatVolume", volume)
			5:
				# Eastwood's generated Conquest volume partition contains fourteen
				# tiny, unowned OBB records clustered around the two bases.  Nothing
				# in the gameplay graph assigns them as a play/combat area, so do not
				# present them to creators as meaningful playable boundaries.
				if not (mode == "conquest" and level in ["mp_eastwood", "mp_dumbo",
						"mp_badlands", "mp_aftermath", "mp_aftermath_portal"]):
					var obb := _scene("obb", str(row.get("label", "Box")))
					obb.transform = _raw_transform(row)
					var half: Array = (row.get("raw", {}) as Dictionary).get("half_extents", [])
					if half.size() == 3:
						obb.set("size", _vec3(half) * 2.0)
					obb.set_meta(PROVENANCE_META, _source(row))
					zones_root.add_child(obb)
					obb.owner = map_root
		if int(row.get("role", 0)) in [3, 4, 5]:
			progress_current += 1
			_report(progress, "Creating gameplay volumes…", progress_current, progress_total)

	if CATCH_ALL_SECTOR_MODES.has(mode) and not captures.is_empty():
		var sector := _scene("sector", "Sector")
		var ordered: Array = []
		var ordered_flags: Array = captures.keys()
		ordered_flags.sort()
		for flag in ordered_flags:
			ordered.append(captures[flag])
		_set_array(sector, "CapturePoints", ordered)
		if not hqs.is_empty(): _set_array(sector, "HQs", hqs)
		zones_root.add_child(sector)
		sector.owner = map_root
	elif mode in ["escalation", "koth", "kingofthehill", "strikepoint", "payload", "sabotage"]:
		_build_runtime_sectors(elements, captures_root, map_root, mode)
		if mode in ["koth", "kingofthehill"] and not koth_evidence.is_empty():
			var candidates_sector: Node = captures_root.get_node_or_null("Runtime Sectors/SectorCandidate_01")
			if candidates_sector != null:
				candidates_sector.set_meta("bf6_koth_candidate_guids", koth_evidence.capture_guids)
				candidates_sector.set_meta("bf6_koth_candidate_link_indices", koth_evidence.link_indices)

	var carrier_path := str(paths.get("carriers", ""))
	if carrier_path != "":
		_report(progress, "Loading aircraft carrier geometry…", progress_total - 1, progress_total)
		var carrier := CarrierPreview.new()
		carrier.name = "Aircraft Carriers (hide to disable preview)"
		carrier.source_path = carrier_path
		carrier.set_meta(PROVENANCE_META, "game-extracted carrier geometry for %s/%s" % [level, mode])
		root.add_child(carrier)
		carrier.owner = map_root
		carrier.rebuild()
	_refresh_team_volume_colors(root)
	_prune_empty_folders(root)
	_sort_generated_hierarchy(root)
	_humanize_tree_names(root)
	var compatibility := _template_compatibility_summary(root)
	if int(compatibility.adjustments) > 0:
		root.set_meta("bf6_template_adjustment_count", int(compatibility.adjustments))
		root.set_meta("bf6_template_alias_count", int(compatibility.aliases))
	_report(progress, "Game mode ready", progress_total, progress_total)

	var counts := document.get("counts", {}) as Dictionary
	var message := "Built %s %s: %d game-data objects (%d captures, %d spawns, %d vehicles)" % [
		level, _pretty(mode), int(counts.get("objects", 0)), captures.size(),
		int(counts.get("spawns", 0)), int(counts.get("vehicles", 0))]
	if int(compatibility.adjustments) > 0:
		message += "; Andy compatibility: %d marked adjustments, %d marked aliases" % [
			int(compatibility.adjustments), int(compatibility.aliases)]
	return message


static func _conquest_hqs_with_authored_insertions(hq_rows: Array,
		elements: Array) -> Array:
	# A normal Conquest layer has two playable HQs. Some installed layers retain
	# an inactive gem_hq candidate. Playable records have authored gem_insertion
	# clusters; do not turn an unlinked candidate into a third faction slot.
	var insertions: Array[Vector3] = []
	for value in elements:
		var element := value as Dictionary
		if str(element.get("gem", "")) == "gem_insertion":
			insertions.append(_element_transform(element).origin)
	var ranked: Array = []
	for value in hq_rows:
		var row := value as Dictionary
		var point := _vec3(row.get("centre", []))
		var nearby := 0
		var nearest := INF
		for insertion in insertions:
			var distance := point.distance_to(insertion)
			nearest = minf(nearest, distance)
			if distance < 80.0:
				nearby += 1
		ranked.append({"row": row, "nearby": nearby, "nearest": nearest})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_nearby := int(a.get("nearby", 0))
		var b_nearby := int(b.get("nearby", 0))
		if a_nearby != b_nearby:
			return a_nearby > b_nearby
		return float(a.get("nearest", INF)) < float(b.get("nearest", INF)))
	if ranked.size() < 2 or int((ranked[1] as Dictionary).get("nearby", 0)) == 0:
		return hq_rows
	var selected: Array = [
		(ranked[0] as Dictionary).get("row", {}),
		(ranked[1] as Dictionary).get("row", {}),
	]
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _root_order(a) < _root_order(b))
	return selected


static func swap_factions(layout: Node, owner: Node) -> String:
	if layout == null:
		return "Build or select a game-mode layout first."
	_swap_faction_properties(layout)
	_refresh_team_volume_colors(layout)
	_swap_named_team_nodes(layout)
	layout.set_meta("bf6_factions_swapped",
		not bool(layout.get_meta("bf6_factions_swapped", false)))
	_sort_generated_hierarchy(layout)
	return "Faction sides, linked volume colours, and faction-specific vehicle previews swapped."


static func _refresh_team_volume_colors(node: Node) -> void:
	var team := _team_value(node)
	if team in [1, 2]:
		for property in TEAM_VOLUME_LINK_PROPERTIES:
			if not _has_property(node, property):
				continue
			var linked = node.get(property)
			if linked is Node and _has_property(linked, "points") and \
					_has_property(linked, "color"):
				linked.set("color", TEAM_1_VOLUME_COLOR if team == 1 \
					else TEAM_2_VOLUME_COLOR)
				linked.set_meta("bf6_team_volume", team)
	for child in node.get_children():
		_refresh_team_volume_colors(child)


static func _team_value(node: Node) -> int:
	for property in [&"OwnerTeam", &"Team", &"MatchingTeam", \
			&"StartingOwnerTeamID", &"Attacker_TeamID"]:
		if not _has_property(node, property):
			continue
		var value := int(node.get(property))
		if value in [1, 2]:
			return value
	return 0


static func _swap_faction_properties(node: Node) -> void:
	if _has_property(node, "Team"):
		var team := int(node.get("Team"))
		if team in [1, 2]: node.set("Team", 3 - team)
	if _has_property(node, "AltTeam"):
		var alt_team := int(node.get("AltTeam"))
		if alt_team in [1, 2]: node.set("AltTeam", 3 - alt_team)
	if _has_property(node, "OwnerTeam"):
		var owner_team := int(node.get("OwnerTeam"))
		if owner_team in [1, 2]: node.set("OwnerTeam", 3 - owner_team)
	if _has_property(node, "MatchingTeam"):
		var matching_team := int(node.get("MatchingTeam"))
		if matching_team in [1, 2]: node.set("MatchingTeam", 3 - matching_team)
	for property in [&"StartingOwnerTeamID", &"Attacker_TeamID"]:
		if _has_property(node, property):
			var value := int(node.get(property))
			if value in [1, 2]: node.set(property, 3 - value)
	if _has_property(node, "ObjId"):
		var object_id := int(node.get("ObjId"))
		if object_id >= 600:
			var slot := (object_id - 600) % 10
			if slot < 5:
				node.set("ObjId", object_id + 5)
			elif slot < 10:
				node.set("ObjId", object_id - 5)
	if node.has_meta("bf6_spawn_team"):
		var spawn_team := int(node.get_meta("bf6_spawn_team"))
		if spawn_team in [1, 2]: node.set_meta("bf6_spawn_team", 3 - spawn_team)
	if _has_property(node, "InfantrySpawnPoints_Team1") and \
			_has_property(node, "InfantrySpawnPoints_Team2"):
		var team_1 = node.get("InfantrySpawnPoints_Team1")
		node.set("InfantrySpawnPoints_Team1", node.get("InfantrySpawnPoints_Team2"))
		node.set("InfantrySpawnPoints_Team2", team_1)
	if _has_property(node, "VehicleType"):
		var vehicle_type := int(node.get("VehicleType"))
		for pair in VEHICLE_CLASS_TYPES.values():
			if (pair as Array).size() == 2:
				if vehicle_type == int(pair[0]):
					node.set("VehicleType", int(pair[1]))
					break
				if vehicle_type == int(pair[1]):
					node.set("VehicleType", int(pair[0]))
					break
	if node.has_meta("bf6_runtime_association"):
		node.set_meta("bf6_runtime_association",
			_swap_team_text(str(node.get_meta("bf6_runtime_association"))))
	for child in node.get_children():
		_swap_faction_properties(child)


static func _swap_named_team_nodes(root: Node) -> void:
	var team_1: Array = []
	var team_2: Array = []
	_collect_named_team_nodes(root, team_1, team_2)
	for node in team_1:
		(node as Node).name = str((node as Node).name).replace("TEAM_1", "TEAM_SWAP") \
			.replace("Team1", "TeamSwap")
	for node in team_2:
		(node as Node).name = str((node as Node).name).replace("TEAM_2", "TEAM_1") \
			.replace("Team2", "Team1")
	for node in team_1:
		(node as Node).name = str((node as Node).name).replace("TEAM_SWAP", "TEAM_2") \
			.replace("TeamSwap", "Team2")


static func _collect_named_team_nodes(node: Node, team_1: Array, team_2: Array) -> void:
	var name_text := str(node.name)
	if name_text.contains("TEAM_1") or name_text.contains("Team1"):
		team_1.append(node)
	elif name_text.contains("TEAM_2") or name_text.contains("Team2"):
		team_2.append(node)
	for child in node.get_children():
		_collect_named_team_nodes(child, team_1, team_2)


static func _swap_team_text(value: String) -> String:
	return value.replace("Team1", "TeamSwap").replace("Team2", "Team1") \
		.replace("TeamSwap", "Team2")


static func _has_property(object: Object, property: StringName) -> bool:
	for descriptor in object.get_property_list():
		if StringName(descriptor.name) == property:
			return true
	return false


static func _build_rush_objectives(objects: Array, objectives_root: Node,
		owner: Node, hqs: Array, elements: Array) -> Dictionary:
	var rows: Array = []
	for value in objects:
		if int((value as Dictionary).get("role", 0)) == 8:
			rows.append(value)
	if rows.is_empty():
		return {}
	var sector_rows := _progressive_sector_rows("rush", elements, objects)
	# Legacy schema-2 data had no retained GEM layer. Keep its deterministic
	# ordering only as a compatibility fallback; schema 3 uses retail sectors.
	if sector_rows.is_empty():
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _root_order(a) < _root_order(b))
		for index in range(int(ceil(rows.size() / 2.0))):
			sector_rows.append({"root_order": index, "transform": [1,0,0,0,1,0,0,0,1,
				float(index) * 100000.0, 0, 0]})
	else:
		_sort_mode_elements_by_root_order(sector_rows)
	var grouped: Array = []
	for _sector in sector_rows:
		grouped.append([])
	var polygon_assignments := _progressive_object_sector_assignments(rows,
		sector_rows, objects, func(row: Dictionary) -> Vector3:
			return _vec3(row.get("centre", [])))
	if polygon_assignments.size() == rows.size():
		for row in rows:
			(grouped[int(polygon_assignments[_row_key(row)])] as Array).append(row)
	else:
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _root_order(a) < _root_order(b))
		for row_index in range(rows.size()):
			var sector_index := floori(float(row_index) / 2.0)
			if sector_index >= grouped.size():
				break
			(grouped[sector_index] as Array).append(rows[row_index])
	var sectors_root := _folder(objectives_root, "Sectors", owner)
	sectors_root.set_meta("bf6_authored_mcom_records", rows.size())
	sectors_root.set_meta("bf6_active_sector_slots", mini(rows.size(), sector_rows.size() * 2))
	sectors_root.set_meta("bf6_selection_basis", "exact installed sector-polygon containment" \
		if polygon_assignments.size() == rows.size() else \
		"authored M-COM order fallback; installed sector polygons were incomplete or ambiguous")
	var grouped_hqs := _progressive_hq_groups_from_metadata(hqs, sector_rows.size())
	var shell := _build_progressive_sector_shells(sectors_root, owner, sector_rows,
		grouped_hqs, objects, {})
	var sectors := shell.get("sectors", []) as Array
	for sector_index in range(sector_rows.size()):
		var members := grouped[sector_index] as Array
		var sector := sectors[sector_index + 1] as Node3D
		members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _root_order(a) < _root_order(b))
		var sector_mcoms: Array = []
		for slot in range(members.size()):
			var row := members[slot] as Dictionary
			var mcom := _scene("mcom", "MCOM-%s" % String.chr(65 + slot))
			mcom.transform = sector.transform.affine_inverse() * _raw_transform(row)
			# Andy's Rush workspace advances these globals by two each phase. Keep
			# the pair's IDs phase-local even when the retail data has only one live
			# MCOM in a phase; later phases must not shift down into the missing slot.
			mcom.set("ObjId", 201 + sector_index * 2 + slot)
			_mark_template_adjustment(mcom,
				"Rush phase-pair ObjId assigned for the Blockly contract; objective transform " +
				"and M-COM identity remain game-derived.")
			mcom.set_meta(PROVENANCE_META, _source(row))
			mcom.set_meta("bf6_root_order", _root_order(row))
			mcom.set_meta("bf6_rush_sector", sector_index + 1)
			mcom.set_meta("bf6_rush_slot", slot)
			sector.add_child(mcom)
			mcom.owner = owner
			sector_mcoms.append(mcom)
		_set_array(sector, "MCOMs", sector_mcoms)
	_apply_progressive_vehicle_ids(sectors, objectives_root.get_parent(), "rush")
	return shell.get("claimed", {}) as Dictionary


static func _build_payload_objectives(elements: Array, objectives_root: Node,
		owner: Node) -> void:
	var payloads := _mode_elements(elements, "gem_payload")
	var checkpoints := _mode_elements(elements, "gem_checkpoint")
	payloads.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("root_order", -1)) < int(b.get("root_order", -1)))
	checkpoints.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("root_order", -1)) < int(b.get("root_order", -1)))
	var route_root := _folder(objectives_root, "Payload Route", owner)
	route_root.set_meta("bf6_portal_limit",
		"Portal SDK 1.4.3 has no Payload or Checkpoint class; these are exact retail markers")
	for index in range(payloads.size()):
		_add_runtime_marker(payloads[index] as Dictionary, route_root, owner,
			"Payload_%02d" % (index + 1), "payload controller")
	for index in range(checkpoints.size()):
		_add_runtime_marker(checkpoints[index] as Dictionary, route_root, owner,
			"Checkpoint_%02d" % (index + 1), "payload checkpoint")


static func _build_sabotage_objectives(objects: Array, elements: Array,
		objectives_root: Node, owner: Node) -> void:
	var zones := _mode_elements(elements, "gem_destructiblezone")
	zones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("root_order", -1)) < int(b.get("root_order", -1)))
	var polygons: Array = []
	for value in objects:
		var row := value as Dictionary
		if int(row.get("role", 0)) == 2 and (row.get("world_points", []) as Array).size() >= 9:
			polygons.append(row)
	var used := {}
	var folder := _folder(objectives_root, "Destructible Objectives", owner)
	for index in range(zones.size()):
		var zone := zones[index] as Dictionary
		var objective := _add_runtime_marker(zone, folder, owner,
			"DestructibleObjective_%02d" % (index + 1), "destructible objective controller")
		var nearest := -1
		var nearest_distance := INF
		for polygon_index in range(polygons.size()):
			if used.has(polygon_index):
				continue
			var polygon_row := polygons[polygon_index] as Dictionary
			var distance := _element_transform(zone).origin.distance_squared_to(
				_vec3(polygon_row.get("centre", [])))
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = polygon_index
		if nearest < 0:
			continue
		used[nearest] = true
		var area := _polygon(polygons[nearest] as Dictionary, "ObjectiveArea",
			Color(1.0, 0.35, 0.1, 0.38))
		objective.add_child(area)
		area.owner = owner
		area.transform = objective.transform.affine_inverse() * area.transform
		var trigger := _scene("area_trigger", "SabotageTrigger_%02d" % (index + 1))
		trigger.set("ObjId", 701 + index)
		trigger.set("Area", area)
		trigger.set_meta("bf6_portal_translation",
			"AreaTrigger wrapper for the public Portal API; position and linked polygon " +
			"come from the game destructible objective data.")
		objective.add_child(trigger)
		trigger.owner = owner
		objective.set_meta("bf6_area_association",
			"nearest exact polygon to the game-bound destructible-zone transform")
		objective.set_meta("bf6_area_distance_m", sqrt(nearest_distance))


static func _build_carrier_objectives(elements: Array, objectives_root: Node,
		owner: Node) -> void:
	var folder := _folder(objectives_root, "Carrier Runtime Objectives", owner)
	folder.set_meta("bf6_portal_limit",
		"VLS batteries and objective groups have no Portal SDK 1.4.3 class")
	for gem_name in ["gem_objectivegroup", "gem_objective_vls_battery"]:
		var rows := _mode_elements(elements, gem_name)
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("root_order", -1)) < int(b.get("root_order", -1)))
		for index in range(rows.size()):
			var prefix := "ObjectiveGroup" if gem_name == "gem_objectivegroup" else "VLS_Battery"
			_add_runtime_marker(rows[index] as Dictionary, folder, owner,
				"%s_%02d" % [prefix, index + 1], gem_name.trim_prefix("gem_"))


static func _build_operations_candidate_sectors(evidence: Dictionary,
		elements: Array, captures: Dictionary, hqs: Array,
		objectives_root: Node, owner: Node) -> void:
	var element_by_id := {}
	for element in elements:
		var id := str(element.get("partition", "")) + "#" + str(element.get("instance_guid", ""))
		element_by_id[id] = element
	var capture_by_guid := {}
	for capture in captures.values():
		var guid := str((capture as Node).get_meta("bf6_capture_instance_guid", ""))
		if not guid.is_empty(): capture_by_guid[guid] = capture
	var hq_by_guid := {}
	for hq in hqs:
		var guid := str((hq as Node).get_meta("bf6_source_instance_guid", ""))
		if not guid.is_empty(): hq_by_guid[guid] = hq
	var folder := _folder(objectives_root, "Runtime Sectors", owner)
	folder.set_meta("bf6_membership_status",
		"exact selected Operations candidates; folder order is identity order, not gameplay phase order")
	for index in range(evidence.sectors.size()):
		var row: Dictionary = evidence.sectors[index]
		var sector := _scene("sector", "SectorCandidate_" + str(row.sector).get_slice("#", 1).left(8))
		sector.transform = _element_transform(element_by_id[row.sector])
		sector.set("ObjId", 500 + index)
		sector.set_meta("bf6_source_identity", row.sector)
		sector.set_meta("bf6_operations_candidate_not_phase_order", true)
		sector.set_meta("bf6_membership_link_indices", row.membership_link_indices)
		folder.add_child(sector)
		sector.owner = owner
		var linked_hqs := []
		for member_id in row.hqs:
			var hq: Node = hq_by_guid[str(member_id).get_slice("#", 1)]
			linked_hqs.append(hq)
			hq.set_meta("bf6_operations_sector_identity", row.sector)
		var linked_captures := []
		for member_id in row.captures:
			var capture: Node = capture_by_guid[str(member_id).get_slice("#", 1)]
			linked_captures.append(capture)
			capture.set_meta("bf6_operations_sector_identity", row.sector)
		_set_array(sector, "HQs", linked_hqs)
		_set_array(sector, "CapturePoints", linked_captures)


static func _build_bomb_candidate_sector(evidence: Dictionary, elements: Array,
		hqs: Array, mcom_nodes: Dictionary, bomb_nodes: Dictionary,
		objectives_root: Node, owner: Node) -> void:
	var sector_row := {}
	for element in elements:
		if str(element.get("partition", "")) + "#" + str(element.get("instance_guid", "")) == evidence.sector:
			sector_row = element
			break
	var folder := _folder(objectives_root, "Runtime Sectors", owner)
	var sector := _scene("sector", "SectorCandidate_" + str(evidence.sector).get_slice("#", 1).left(8))
	sector.transform = _element_transform(sector_row)
	sector.set("ObjId", 500)
	sector.set_meta("bf6_source_identity", evidence.sector)
	sector.set_meta("bf6_bomb_candidate_status", "authored sites; live active bomb is selected at runtime")
	sector.set_meta("bf6_bomb_candidate_guids", evidence.bombs)
	sector.set_meta("bf6_membership_link_indices", evidence.membership_link_indices)
	folder.add_child(sector)
	sector.owner = owner
	var hq_by_identity := {}
	for hq in hqs:
		hq_by_identity[(hq as Node).get_meta("bf6_source_identity")] = hq
	var linked_hqs := []
	for id in evidence.hqs:
		var hq: Node = hq_by_identity[id]
		linked_hqs.append(hq)
		hq.set_meta("bf6_bomb_sector_identity", evidence.sector)
	var linked_mcoms := []
	for id in evidence.mcoms:
		var mcom: Node = mcom_nodes[id]
		linked_mcoms.append(mcom)
		mcom.set_meta("bf6_bomb_sector_identity", evidence.sector)
	for id in evidence.bombs:
		(bomb_nodes[id] as Node).set_meta("bf6_bomb_sector_identity", evidence.sector)
	_set_array(sector, "HQs", linked_hqs)
	_set_array(sector, "MCOMs", linked_mcoms)


static func _build_runtime_sectors(elements: Array, objectives_root: Node,
		owner: Node, mode: String) -> void:
	var rows := _mode_elements(elements, "gem_sector")
	if rows.is_empty():
		return
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("root_order", -1)) < int(b.get("root_order", -1)))
	var folder := _folder(objectives_root, "Runtime Sectors", owner)
	folder.set_meta("bf6_membership_status",
		"%s sector membership and activation are supplied by the retail runtime graph" % mode)
	for index in range(rows.size()):
		var row := rows[index] as Dictionary
		var sector := _scene("sector", "SectorCandidate_%02d" % (index + 1))
		sector.transform = _element_transform(row)
		sector.set("ObjId", 500 + index)
		sector.set_meta(PROVENANCE_META, "%s instance %s root %s" % [
			str(row.get("partition", "")), str(row.get("instance_guid", "?")),
			str(row.get("root_order", "-"))])
		sector.set_meta("bf6_runtime_membership", true)
		folder.add_child(sector)
		sector.owner = owner


static func _add_runtime_marker(row: Dictionary, parent: Node, owner: Node,
		node_name: String, purpose: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.transform = _element_transform(row)
	node.set_meta(PROVENANCE_META, "%s instance %s root %s" % [
		str(row.get("partition", "")), str(row.get("instance_guid", "?")),
		str(row.get("root_order", "-"))])
	node.set_meta("bf6_gem", str(row.get("gem", "")))
	node.set_meta("bf6_runtime_only", purpose)
	parent.add_child(node)
	node.owner = owner
	return node


static func _build_deploy_cameras(elements: Array, extras_root: Node,
		owner: Node) -> void:
	var authored: Array = []
	var shared: Array = []
	for value in elements:
		var row := value as Dictionary
		if str(row.get("gem", "")) != "gem_deploycam":
			continue
		if str(row.get("layer", "")).ends_with("/gameplay_global"):
			shared.append(row)
		else:
			authored.append(row)
	var rows := authored if not authored.is_empty() else shared
	if rows.is_empty():
		return
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("root_order", -1)) < int(b.get("root_order", -1)))
	var folder := _folder(extras_root, "Deploy Cameras", owner)
	for index in range(rows.size()):
		var row := rows[index] as Dictionary
		var camera := _scene("deploy_cam", "DeployCam_%02d" % (index + 1))
		camera.transform = _element_transform(row)
		camera.set_meta(PROVENANCE_META, "%s instance %s root %s" % [
			str(row.get("partition", "")), str(row.get("instance_guid", "?")),
			str(row.get("root_order", "-"))])
		camera.set_meta("bf6_gem", "gem_deploycam")
		camera.set_meta("bf6_source_instance_guid", str(row.get("instance_guid", "")))
		folder.add_child(camera)
		camera.owner = owner


static func _build_progressive_sector_shells(sectors_root: Node, owner: Node,
		sector_rows: Array, grouped_hqs: Array, objects: Array,
		excluded_area_sources: Dictionary) -> Dictionary:
	# The custom Rush and Breakthrough workspaces use two boundary sectors in
	# addition to the live phases. Their initialise rule deliberately computes
	# TotalSectors as CountOf(All Sectors) - 2, then addresses phases as 101+n.
	# Preserve that executable contract while sourcing positions and shapes only
	# from the installed game's GEM records.
	var targets: Array[Vector3] = []
	var first_anchor := _element_transform(sector_rows[0] as Dictionary).origin
	var last_anchor := _element_transform(sector_rows[-1] as Dictionary).origin
	var start_target := first_anchor
	var end_target := last_anchor
	if not grouped_hqs.is_empty():
		var first_attacker := _progressive_hq_for_team(grouped_hqs[0] as Array, 1)
		var last_defender := _progressive_hq_for_team(grouped_hqs[-1] as Array, 2)
		if first_attacker != null:
			start_target = (first_attacker as Node3D).position
		if last_defender != null:
			end_target = (last_defender as Node3D).position
	targets.append(start_target)
	for row in sector_rows:
		targets.append(_element_transform(row as Dictionary).origin)
	targets.append(end_target)

	# These are geometric relationships in the installed layout, not serialized
	# object references: accept the smallest polygon that contains the exact GEM
	# anchor and never substitute a nearby polygon.
	var area_assignments := _progressive_sector_area_assignments(objects, targets,
		excluded_area_sources)
	var sectors: Array = []
	var claimed := {}
	for index in range(targets.size()):
		var sector := _scene("sector", "Sector%d" % index)
		sector.set("ObjId", 100 + index)
		sector.set_meta("bf6_template_contract",
			"Andy Rush/Breakthrough Blockly sector and object-ID contract")
		_mark_template_adjustment(sector,
			"Portal Sector wrapper and ObjId assigned for the Blockly contract; active " +
			"phase anchors use game GEM data and boundary wrappers are compatibility-only.")
		if index > 0 and index <= sector_rows.size():
			var source := sector_rows[index - 1] as Dictionary
			sector.transform = _element_transform(source)
			sector.set_meta("bf6_order_basis", "installed GEM root order")
			sector.set_meta("bf6_source_instance_guid",
				str(source.get("instance_guid", "")))
			sector.set_meta("bf6_progressive_phase", index - 1)
		else:
			sector.position = targets[index]
			sector.set_meta("bf6_boundary_sector", "attacker" if index == 0 else "defender")
		sectors_root.add_child(sector)
		sector.owner = owner
		var assignment := area_assignments[index] as Dictionary
		if not assignment.is_empty():
			var row := assignment.get("row", {}) as Dictionary
			var color := TEAM_1_VOLUME_COLOR if index == 0 else \
				(TEAM_2_VOLUME_COLOR if index == targets.size() - 1 else \
				Color(0.0, 0.6, 0.7, 0.42))
			var area := _polygon(row, "PolygonVolume%d" % index, color)
			_ensure_progressive_volume_height(area)
			sector.add_child(area)
			area.owner = owner
			area.transform = sector.transform.affine_inverse() * area.transform
			sector.set("SectorArea", area)
			sector.set_meta("bf6_sector_area_binding", str(assignment.get("method", "")))
			claimed[_row_key(row)] = true
			var trigger := _scene("area_trigger", "AreaTrigger")
			trigger.set("ObjId", 600 + index)
			trigger.set("Area", area)
			trigger.set_meta("bf6_template_contract", "phase out-of-bounds trigger")
			_mark_template_adjustment(trigger,
				"AreaTrigger wrapper and ObjId assigned for Blockly out-of-bounds logic; " +
				"the linked polygon remains game-derived.")
			sector.add_child(trigger)
			trigger.owner = owner
		else:
			sector.set_meta("bf6_sector_area_binding",
				"unassigned: retail sector membership/area is runtime-fed")
		sectors.append(sector)

	for phase in range(sector_rows.size()):
		var active_sector := sectors[phase + 1] as Node3D
		var phase_hqs := grouped_hqs[phase] as Array
		for value in phase_hqs:
			var hq := value as Node3D
			_reparent_from_layout_space(hq, active_sector, owner)
			# HQArea was independently selected by exact containment around the
			# authored HQ anchor. Do not overwrite it with an adjacent sector.
		_set_array(active_sector, "HQs", phase_hqs)
	return {"sectors": sectors, "claimed": claimed}


static func _progressive_hq_for_team(hqs: Array, team: int) -> Node:
	for value in hqs:
		var hq := value as Node
		if int(hq.get("Team")) == team:
			return hq
	return null


static func _progressive_sector_area_assignments(objects: Array,
		targets: Array[Vector3], excluded_sources: Dictionary) -> Array:
	var candidates: Array = []
	for value in objects:
		var row := value as Dictionary
		if int(row.get("role", 0)) != 3 or excluded_sources.has(_row_key(row)) or \
				(row.get("world_points", []) as Array).size() < 9 or \
				absf(float(row.get("height", 0.0))) > 0.001:
			continue
		candidates.append(row)
	var assignments: Array = []
	assignments.resize(targets.size())
	assignments.fill({})
	for target_index in range(targets.size()):
		var target := targets[target_index] as Vector3
		var best := -1
		var best_area := INF
		for index in range(candidates.size()):
			var row := candidates[index] as Dictionary
			if not _polygon_contains_xz(row.get("world_points", []) as Array, target):
				continue
			var area := float(row.get("area_m2", INF))
			if area < best_area:
				best = index
				best_area = area
		if best < 0:
			continue
		assignments[target_index] = {
			"row": candidates[best],
			"method": "smallest containing installed polygon; no distance fallback",
		}
	return assignments


static func _progressive_object_sector_assignments(rows: Array, sector_rows: Array,
		objects: Array, position_for_row: Callable) -> Dictionary:
	var targets: Array[Vector3] = []
	for sector in sector_rows:
		targets.append(_element_transform(sector as Dictionary).origin)
	var sector_areas := _progressive_sector_area_assignments(objects, targets, {})
	var result := {}
	for value in rows:
		var row := value as Dictionary
		var point := position_for_row.call(row) as Vector3
		var matches: Array[int] = []
		for sector_index in range(sector_areas.size()):
			var assignment := sector_areas[sector_index] as Dictionary
			if assignment.is_empty():
				continue
			var polygon := assignment.get("row", {}) as Dictionary
			if _polygon_contains_xz(polygon.get("world_points", []) as Array, point):
				matches.append(sector_index)
		if matches.size() != 1:
			return {}
		result[_row_key(row)] = matches[0]
	return result


static func _apply_progressive_vehicle_ids(sectors: Array, layout_root: Node,
		mode: String) -> void:
	for phase in range(maxi(sectors.size() - 2, 0)):
		var sector := sectors[phase + 1] as Node
		var vehicles: Array = []
		var seen := {}
		var hq_links = sector.get("HQs")
		if hq_links != null:
			for hq_value in hq_links:
				var linked = (hq_value as Node).get("VehicleSpawners")
				if linked == null:
					continue
				for vehicle in linked:
					if vehicle != null and not seen.has((vehicle as Object).get_instance_id()):
						seen[(vehicle as Object).get_instance_id()] = true
						vehicles.append(vehicle)
		if mode == "breakthrough":
			var flags := {}
			var captures = sector.get("CapturePoints")
			if captures != null:
				for capture in captures:
					flags[int((capture as Node).get_meta("bf6_breakthrough_source_flag", -1))] = true
			_collect_phase_objective_vehicles(layout_root, flags, vehicles, seen)
		vehicles.sort_custom(func(a: Node, b: Node) -> bool:
			var a_root := int(a.get_meta("bf6_root_order", 2147483647))
			var b_root := int(b.get_meta("bf6_root_order", 2147483647))
			return a_root < b_root if a_root != b_root else str(a.name) < str(b.name))
		for slot in range(vehicles.size()):
			var vehicle := vehicles[slot] as Node
			vehicle.set("ObjId", 1050 + (phase + 1) * 100 + slot)
			vehicle.set_meta("bf6_progressive_phase", phase)
			vehicle.set_meta("bf6_template_contract",
				"phase object band 1000 + sector*100 + 50")
			_mark_template_adjustment(vehicle,
				"Phase ObjId assigned for Blockly vehicle/emplacement management; game-derived " +
				"transform, selector, and concrete vehicle type are retained.")


static func _collect_phase_objective_vehicles(node: Node, flags: Dictionary,
		result: Array, seen: Dictionary) -> void:
	if node.has_meta("bf6_runtime_association"):
		var association := str(node.get_meta("bf6_runtime_association"))
		if association.begins_with("CapturePoint"):
			var letter := association.trim_prefix("CapturePoint").left(1)
			var flag := letter.unicode_at(0) - 65 if not letter.is_empty() else -1
			if flags.has(flag) and not seen.has(node.get_instance_id()):
				seen[node.get_instance_id()] = true
				result.append(node)
	for child in node.get_children():
		_collect_phase_objective_vehicles(child, flags, result, seen)


static func _build_breakthrough_sectors(captures: Dictionary,
		objectives_root: Node, owner: Node, elements: Array, hqs: Array,
		objects: Array, mode: String, excluded_area_sources: Dictionary) -> Dictionary:
	var sector_rows := _progressive_sector_rows(mode, elements, objects)
	if sector_rows.is_empty():
		return {}
	var grouped: Array = []
	for _sector in sector_rows:
		grouped.append([])
	var ordered_flags: Array = captures.keys()
	ordered_flags.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((captures[a] as Node).get_meta("bf6_capture_root_order", -1)) < \
			int((captures[b] as Node).get_meta("bf6_capture_root_order", -1)))
	var polygon_assignments := _breakthrough_polygon_sector_assignments(captures,
		sector_rows, objects)
	if polygon_assignments.size() == captures.size():
		for flag in ordered_flags:
			var sector_index := int(polygon_assignments[flag])
			var capture := captures[flag] as Node3D
			(grouped[sector_index] as Array).append({"flag": flag, "node": capture})
			capture.set_meta("bf6_sector_binding",
				"inside exact installed sector polygon; no distance fallback")
	else:
		# Some installs expose incomplete or overlapping phase polygons. Preserve
		# authored order in that case and disclose the compatibility projection.
		var capture_cursor := 0
		var base_per_sector := floori(float(ordered_flags.size()) / float(grouped.size()))
		var sectors_with_extra := ordered_flags.size() % grouped.size()
		for sector_index in range(grouped.size()):
			var sector_count := base_per_sector + (1 if sector_index < sectors_with_extra else 0)
			for _slot in range(sector_count):
				if capture_cursor >= ordered_flags.size():
					break
				var flag = ordered_flags[capture_cursor]
				capture_cursor += 1
				var capture := captures[flag] as Node3D
				(grouped[sector_index] as Array).append({"flag": flag, "node": capture})
				capture.set_meta("bf6_sector_binding",
					"authored-order fallback; installed sector polygons were incomplete or ambiguous")
	var sectors_root := _folder(objectives_root, "Sectors", owner)
	sectors_root.set_meta("bf6_authored_capture_controllers",
		_mode_elements(elements, "gem_capturepoint").size())
	sectors_root.set_meta("bf6_active_capture_records", captures.size())
	sectors_root.set_meta("bf6_selection_basis",
		"exact installed sector-polygon containment" if polygon_assignments.size() == captures.size() \
		else "exact capture controllers/shapes with disclosed authored-order fallback")
	var grouped_hqs := _progressive_hq_groups_from_metadata(hqs, sector_rows.size())
	var shell := _build_progressive_sector_shells(sectors_root, owner, sector_rows,
		grouped_hqs, objects, excluded_area_sources)
	var sectors := shell.get("sectors", []) as Array
	for sector_index in range(sector_rows.size()):
		var members := grouped[sector_index] as Array
		var sector := sectors[sector_index + 1] as Node3D
		members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int((a.get("node") as Node).get_meta("bf6_capture_root_order", -1)) < \
				int((b.get("node") as Node).get_meta("bf6_capture_root_order", -1)))
		var sector_captures: Array = []
		for slot in range(members.size()):
			var member := members[slot] as Dictionary
			var capture := member.get("node") as Node3D
			_reparent_from_layout_space(capture, sector, owner)
			capture.name = "CapturePoint%s" % String.chr(65 + slot)
			capture.set("ObjId", 1100 + sector_index * 100 + slot)
			capture.set("InitialOwner", 2)
			_mark_template_adjustment(capture,
				"Sector-local label and ObjId follow the Breakthrough Blockly contract. " +
				"Initial owner is Team 2 to match the corrected installed-map direction; " +
				"capture transform and volume remain game-derived.")
			capture.set_meta("bf6_breakthrough_source_flag", int(member.get("flag", -1)))
			sector_captures.append(capture)
		_set_array(sector, "CapturePoints", sector_captures)
	_apply_progressive_vehicle_ids(sectors, objectives_root.get_parent(), "breakthrough")
	return shell.get("claimed", {}) as Dictionary


static func _breakthrough_polygon_sector_assignments(captures: Dictionary,
		sector_rows: Array, objects: Array) -> Dictionary:
	var targets: Array[Vector3] = []
	for row in sector_rows:
		targets.append(_element_transform(row as Dictionary).origin)
	var sector_areas := _progressive_sector_area_assignments(objects, targets, {})
	var assignments := {}
	for flag in captures:
		var capture := captures[flag] as Node3D
		var matches: Array[int] = []
		for sector_index in range(sector_rows.size()):
			var assignment := sector_areas[sector_index] as Dictionary
			if assignment.is_empty():
				continue
			var polygon := assignment.get("row", {}) as Dictionary
			if _polygon_contains_xz(polygon.get("world_points", []) as Array, capture.position):
				matches.append(sector_index)
		if matches.size() != 1:
			return {}
		assignments[flag] = matches[0]
	return assignments


static func _exact_capture_rows(document: Dictionary, elements: Array, mode: String) -> Array:
	# Schema 4 preserves the placed capture controller's explicit 0x5C3A072B
	# VectorShapeAsset binding and reads that asset directly. No loose polygon is
	# selected by distance or containment.
	var controllers := {}
	for value in _mode_elements(elements, "gem_capturepoint"):
		var controller := value as Dictionary
		controllers[str(controller.get("instance_guid", ""))] = controller
	var shapes: Array = document.get("capture_shapes", [])
	var rows: Array = []
	for value in shapes:
		var shape := value as Dictionary
		var guid := str(shape.get("controller_instance_guid", ""))
		if not controllers.has(guid):
			continue
		var controller := controllers[guid] as Dictionary
		var points := shape.get("world_points", []) as Array
		if points.size() < 9:
			continue
		var centre := Vector3.ZERO
		for index in range(0, points.size(), 3):
			centre += Vector3(float(points[index]), float(points[index + 1]),
				float(points[index + 2]))
		centre /= float(points.size() / 3)
		var height := float(shape.get("height", 0.0))
		# The generated asset boundary is reported at the middle of its convex
		# extrusion. Portal's PolygonVolume origin is the bottom face.
		centre.y -= height * 0.5
		rows.append({
			"role": 2,
			"flag": int(shape.get("flag", -1)),
			"centre": [centre.x, centre.y, centre.z],
			"world_points": points,
			"height": height,
			"raw": {
				"layer": str(controller.get("layer", "")),
				"partition": str(controller.get("partition", "")),
				"instance": int(controller.get("instance", -1)),
				"root_order": int(controller.get("root_order", -1)),
				"instance_guid": guid,
				"transform": controller.get("transform", []),
			},
			"capture_binding": {
				"instance_guid": guid,
				"root_order": int(controller.get("root_order", -1)),
				"method": str(shape.get("binding", "")),
				"shape_asset": str(shape.get("shape_asset", "")),
				"shape_property": int(shape.get("shape_property", 0)),
			},
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _root_order(a) < _root_order(b))
	if mode in ["breakthrough", "operations"]:
		# Retail's sector membership is runtime-fed. Preserve exact authored
		# controller order for the Portal template's sequential A/B slots; this is
		# an ordering projection, never a spatial association.
		for index in range(rows.size()):
			(rows[index] as Dictionary)["flag"] = index
	return rows


static func _mode_elements(elements: Array, gem: String) -> Array:
	var rows: Array = []
	for value in elements:
		var row := value as Dictionary
		if str(row.get("gem", "")) == gem and \
				not str(row.get("layer", "")).ends_with("/gameplay_global"):
			rows.append(row)
	return rows


static func _progressive_sector_rows(mode: String, elements: Array,
		objects: Array) -> Array:
	var rows := _mode_elements(elements, "gem_sector")
	_sort_mode_elements_by_root_order(rows)
	if mode != "rush" or rows.is_empty():
		return rows
	var mcoms: Array = []
	for value in objects:
		if int((value as Dictionary).get("role", 0)) == 8:
			mcoms.append(value)
	var phase_count := mini(rows.size(), int(ceil(mcoms.size() / 2.0)))
	if phase_count <= 0 or phase_count >= rows.size():
		return rows
	# Some layers retain dormant sector controllers. The placement data does not
	# link an M-COM to a sector, so retain authored controller order only; never
	# choose controllers by spatial proximity.
	return rows.slice(0, phase_count)


static func _sort_mode_elements_by_root_order(rows: Array) -> void:
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("root_order", -1)) < int(b.get("root_order", -1)))


static func _group_nodes_by_elements(nodes: Array, rows: Array, capacity: int) -> Array:
	var grouped: Array = []
	for _row in rows:
		grouped.append([])
	var ordered := nodes.duplicate()
	ordered.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get_meta("bf6_root_order", -1)) < \
			int(b.get_meta("bf6_root_order", -1)))
	for value in ordered:
		var node := value as Node3D
		var index := _nearest_element_with_capacity(rows, grouped, node.position, capacity)
		if index >= 0:
			(grouped[index] as Array).append(node)
	return grouped


static func _group_progressive_hqs(hqs: Array, sector_rows: Array,
		objects: Array) -> Array:
	var grouped: Array = []
	for _row in sector_rows:
		grouped.append([])
	if hqs.is_empty() or sector_rows.is_empty():
		return grouped
	var ordered := hqs.duplicate()
	ordered.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get_meta("bf6_root_order", -1)) < int(b.get_meta("bf6_root_order", -1)))
	# Progressive layouts commonly author two coincident HQ controllers at every
	# phase boundary: the lower root is the current defender and the higher root
	# is the next attacker. Recover that chain only when installed polygons prove
	# every internal boundary and leave exactly two endpoints.
	var boundary_pairs: Array = []
	var claimed := {}
	var valid_chain := true
	for phase in range(maxi(sector_rows.size() - 1, 0)):
		var anchor := _element_transform(sector_rows[phase] as Dictionary).origin
		var best_members: Array = []
		var best_area := INF
		for value in objects:
			var polygon := value as Dictionary
			if int(polygon.get("role", 0)) != 3 or \
					(polygon.get("world_points", []) as Array).size() < 9 or \
					absf(float(polygon.get("height", 0.0))) > 0.001 or \
					not _polygon_contains_xz(polygon.get("world_points", []) as Array, anchor):
				continue
			var members: Array = []
			for hq_value in ordered:
				var hq := hq_value as Node3D
				if _polygon_contains_xz(polygon.get("world_points", []) as Array, hq.position):
					members.append(hq)
			if members.size() != 2:
				continue
			var area := float(polygon.get("area_m2", INF))
			if area < best_area:
				best_area = area
				best_members = members
		if best_members.size() != 2:
			valid_chain = false
			break
		best_members.sort_custom(func(a: Node, b: Node) -> bool:
			return int(a.get_meta("bf6_root_order", -1)) < int(b.get_meta("bf6_root_order", -1)))
		for member in best_members:
			var root := int((member as Node).get_meta("bf6_root_order", -1))
			if claimed.has(root):
				valid_chain = false
				break
		if not valid_chain:
			break
		for member in best_members:
			claimed[int((member as Node).get_meta("bf6_root_order", -1))] = true
		boundary_pairs.append(best_members)
	var endpoints: Array = []
	for hq_value in ordered:
		if not claimed.has(int((hq_value as Node).get_meta("bf6_root_order", -1))):
			endpoints.append(hq_value)
	if valid_chain and sector_rows.size() == 1 and endpoints.size() == 2:
		(grouped[0] as Array).assign(endpoints)
		for hq in endpoints:
			(hq as Node).set_meta("bf6_progressive_phase_basis",
				"single installed phase; authored endpoint order")
		return grouped
	if valid_chain and boundary_pairs.size() == sector_rows.size() - 1 and endpoints.size() == 2:
		(grouped[0] as Array).append(endpoints[0])
		(grouped[0] as Array).append((boundary_pairs[0] as Array)[0])
		for phase in range(1, sector_rows.size() - 1):
			(grouped[phase] as Array).append((boundary_pairs[phase - 1] as Array)[1])
			(grouped[phase] as Array).append((boundary_pairs[phase] as Array)[0])
		(grouped[-1] as Array).append((boundary_pairs[-1] as Array)[1])
		(grouped[-1] as Array).append(endpoints[1])
		for phase_hqs in grouped:
			for hq in phase_hqs:
				(hq as Node).set_meta("bf6_progressive_phase_basis",
					"exact installed boundary-polygon chain; no distance fallback")
		return grouped
	# The static data is incomplete on some maps. Preserve authored root order as
	# a disclosed Blockly compatibility fallback; never infer phases by distance.
	for hq_index in range(ordered.size()):
		var sector_index := floori(float(hq_index) / 2.0)
		if sector_index >= grouped.size():
			break
		(ordered[hq_index] as Node).set_meta("bf6_progressive_phase_basis",
			"authored root-order fallback; boundary chain incomplete")
		(grouped[sector_index] as Array).append(ordered[hq_index])
	return grouped


static func _progressive_hq_groups_from_metadata(hqs: Array, phase_count: int) -> Array:
	var grouped: Array = []
	for _phase in range(phase_count):
		grouped.append([])
	for value in hqs:
		var hq := value as Node
		var phase := int(hq.get_meta("bf6_progressive_phase", -1))
		if phase >= 0 and phase < phase_count:
			(grouped[phase] as Array).append(hq)
	for phase_hqs in grouped:
		(phase_hqs as Array).sort_custom(func(a: Node, b: Node) -> bool:
			return int(a.get_meta("bf6_progressive_team", 0)) < \
				int(b.get_meta("bf6_progressive_team", 0)))
	return grouped


static func _assign_progressive_hq_teams(grouped: Array, sector_rows: Array) -> void:
	for phase in range(grouped.size()):
		var phase_hqs := grouped[phase] as Array
		if phase_hqs.is_empty():
			continue
		for local_index in range(phase_hqs.size()):
			var hq := phase_hqs[local_index] as Node3D
			hq.set_meta("bf6_progressive_phase", phase)
			# Team polarity is the Portal/Blockly contract, not a spatial inference:
			# Team 1 attacks and Team 2 defends.
			hq.set_meta("bf6_progressive_team", 1 if local_index == 0 else 2)
			hq.set_meta("bf6_progressive_team_basis",
				"Portal template contract; authored HQ order retained")


static func _nearest_element_index(rows: Array, point: Vector3) -> int:
	var best := 0
	var distance := INF
	for index in range(rows.size()):
		var transform := _element_transform(rows[index] as Dictionary)
		var candidate := point.distance_squared_to(transform.origin)
		if candidate < distance:
			distance = candidate
			best = index
	return best


static func _nearest_element_with_capacity(rows: Array, grouped: Array,
		point: Vector3, capacity: int) -> int:
	var best := -1
	var distance := INF
	for index in range(rows.size()):
		if (grouped[index] as Array).size() >= capacity:
			continue
		var transform := _element_transform(rows[index] as Dictionary)
		var candidate := point.distance_squared_to(transform.origin)
		if candidate < distance:
			distance = candidate
			best = index
	return best


static func _report(progress: Callable, message: String, current: int, total: int) -> void:
	if progress.is_valid():
		progress.call(message, current, total)


static func _reparent_from_layout_space(node: Node3D, parent: Node3D,
		owner: Node) -> void:
	# node.transform is expressed in the generated layout's coordinate system;
	# parent.transform maps the new parent into that same system.  Compose the
	# local transform explicitly so this works before either node is in a tree.
	var layout_transform := node.transform
	node.owner = null
	node.get_parent().remove_child(node)
	parent.add_child(node)
	node.transform = parent.transform.affine_inverse() * layout_transform
	node.owner = owner


static func _reparent_new_layout_node(node: Node3D, parent: Node3D,
		owner: Node) -> void:
	var layout_transform := node.transform
	parent.add_child(node)
	node.transform = parent.transform.affine_inverse() * layout_transform
	node.owner = owner


static func _normalized_flag(level: String, mode: String, row: Dictionary) -> int:
	# Exported manifests already carry their game-root-derived objective index.
	# Applying map-specific remaps here would shift correctly classified flags.
	return int(row.get("flag", -1))


static func _build_capstone_out_of_bounds(objects: Array, parent: Node,
		owner: Node) -> void:
	for value in objects:
		var row := value as Dictionary
		var raw := row.get("raw", {}) as Dictionary
		if str(raw.get("instance_guid", "")) != "79cbf770-5961-492c-80ae-ce142f99683f":
			continue
		var folder := _folder(parent, "OutOfBounds", owner)
		var trigger := _scene("area_trigger", "AreaTrigger_OutOfBounds_Cliff")
		trigger.position = _vec3(row.get("centre", []))
		trigger.set("ObjId", 1302)
		trigger.set_meta(PROVENANCE_META, _source(row))
		folder.add_child(trigger)
		trigger.owner = owner
		var area := _polygon(row, "PolygonVolume_Cliff", Color(0.95, 0.0, 0.58, 0.42))
		trigger.add_child(area)
		area.owner = owner
		area.position -= trigger.position
		trigger.set("Area", area)
		return


static func _assign_hq_areas(objects: Array, hqs: Array, owner: Node,
		progressive := false) -> Dictionary:
	var used := {}
	for hq_index in range(hqs.size()):
		var hq := hqs[hq_index] as Node3D
		var best: Dictionary = {}
		var best_area := INF
		for value in objects:
			var row := value as Dictionary
			if int(row.get("role", 0)) != 3:
				continue
			if progressive and absf(float(row.get("height", 0.0))) > 0.001:
				continue
			if not _polygon_contains_xz(row.get("world_points", []) as Array, hq.position):
				continue
			var area_m2 := float(row.get("area_m2", INF))
			if area_m2 < best_area:
				best = row
				best_area = area_m2
		if best.is_empty():
			continue
		var team := int(hq.get("Team"))
		var area := _polygon(best, "HQArea_Team%d" % team,
			TEAM_1_VOLUME_COLOR if team == 1 else TEAM_2_VOLUME_COLOR)
		if not progressive and absf(float(best.get("height", 0.0))) < 0.001:
			if (best.get("land", []) as Array).size() == 3:
				area.position.y = _volume_preview_center(best).y
			else:
				# An infinite-height ocean polygon has no terrain sample. Its
				# explicitly attached HQ supplies a game-authored preview height.
				area.position.y = hq.position.y
			area.set_meta("bf6_portal_preview_translation",
				"Infinite-height HQ polygon shown at installed terrain or HQ elevation")
		if progressive:
			_ensure_progressive_volume_height(area)
		hq.add_child(area)
		area.owner = owner
		area.transform = hq.transform.affine_inverse() * area.transform
		area.set_meta("bf6_source_instance_guid",
			str((best.get("raw", {}) as Dictionary).get("instance_guid", "")))
		hq.set("HQArea", area)
		hq.set_meta("bf6_hq_area_binding",
			"smallest containing installed polygon; no distance fallback")
		used[_row_key(best)] = true
	return used


static func _build_combat_area_from_unclaimed_zones(objects: Array, used: Dictionary,
		parent: Node, owner: Node) -> void:
	# Conquest authors base areas and its inner combat boundary as ordinary
	# VolumeVectorShapeData rows. The map-wide aircraft boundary is separate:
	# Gameplay_Global places gem_specialcombatarea and its exact outer polygon.
	# Prefer that graph-derived row whenever present; the area-order fallback is
	# retained for older manifests that predate shared-layer extraction.
	var rows: Array = []
	var authored_surrounding := {}
	for value in objects:
		var row := value as Dictionary
		if int(row.get("role", 0)) == 3 and not used.has(_row_key(row)):
			rows.append(row)
		elif int(row.get("role", 0)) == 4 and not used.has(_row_key(row)) and \
				str((row.get("raw", {}) as Dictionary).get("owner_type", "")) == \
				"gem_specialcombatarea":
			authored_surrounding = row
	if rows.is_empty():
		return
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("area_m2", 0.0)) > float(b.get("area_m2", 0.0)))
	var surrounding_row := authored_surrounding
	var combat_row := rows[0] as Dictionary
	if surrounding_row.is_empty() and rows.size() > 1:
		surrounding_row = rows[0] as Dictionary
		combat_row = rows[1] as Dictionary
	_build_combat_area_rows(combat_row, surrounding_row, used, parent, owner)


static func _build_combat_area_from_zones(objects: Array, used: Dictionary,
		parent: Node, owner: Node, combat_label: String,
		surrounding_label := "") -> void:
	var combat_row := _zone_by_label(objects, used, combat_label)
	if combat_row.is_empty():
		return
	var surrounding_row := _zone_by_label(objects, used, surrounding_label) \
		if surrounding_label != "" else {}
	_build_combat_area_rows(combat_row, surrounding_row, used, parent, owner)


static func _build_combat_area_rows(combat_row: Dictionary,
		surrounding_row: Dictionary, used: Dictionary, parent: Node,
		owner: Node) -> void:
	var combat := _scene("combat", "CombatArea")
	combat.position = _volume_preview_center(combat_row)
	combat.set_meta(PROVENANCE_META, _source(combat_row))
	parent.add_child(combat)
	combat.owner = owner
	var volume := _polygon(combat_row, "CombatVolume", Color(0.2, 0.75, 0.3, 0.3))
	if absf(float(combat_row.get("height", 0.0))) < 0.001 and \
			(combat_row.get("land", []) as Array).size() == 3:
		volume.position.y = _volume_preview_center(combat_row).y
		volume.set_meta("bf6_portal_preview_translation",
			"Infinite-height combat polygon shown at installed terrain sample")
	combat.add_child(volume)
	volume.owner = owner
	volume.position -= combat.position
	volume.set_meta("bf6_source_instance_guid",
		str((combat_row.get("raw", {}) as Dictionary).get("instance_guid", "")))
	combat.set("CombatVolume", volume)
	used[_row_key(combat_row)] = true
	if surrounding_row.is_empty():
		return
	var surrounding := _polygon(surrounding_row, "SurroundingVolume",
		Color(0.2, 0.55, 0.95, 0.22))
	if float(surrounding_row.get("height", 0.0)) == 0.0 and \
			(surrounding_row.get("land", []) as Array).size() != 3 and \
			(combat_row.get("land", []) as Array).size() == 3:
		# Both polygons are infinite-height in Portal. The outer shared-layer
		# polygon has no terrain sample; borrow the inner area's game-derived
		# sample solely to make its editor gizmo visible at the play surface.
		surrounding.position.y = _volume_preview_center(combat_row).y
		surrounding.set_meta("bf6_portal_preview_translation",
			"Infinite-height polygon shown at game-derived combat-area terrain sample")
	combat.add_child(surrounding)
	surrounding.owner = owner
	surrounding.position -= combat.position
	surrounding.set_meta("bf6_source_instance_guid",
		str((surrounding_row.get("raw", {}) as Dictionary).get("instance_guid", "")))
	combat.set("SurroundingVolume", surrounding)
	used[_row_key(surrounding_row)] = true


static func _zone_by_label(objects: Array, used: Dictionary, label: String) -> Dictionary:
	for value in objects:
		var row := value as Dictionary
		if int(row.get("role", 0)) == 3 and str(row.get("label", "")) == label \
				and not used.has(_row_key(row)):
			return row
	return {}


static func _polygon_contains_xz(points: Array, point: Vector3) -> bool:
	var count := int(points.size() / 3)
	if count < 3:
		return false
	var inside := false
	var previous := count - 1
	for index in range(count):
		var x := float(points[index * 3])
		var z := float(points[index * 3 + 2])
		var previous_x := float(points[previous * 3])
		var previous_z := float(points[previous * 3 + 2])
		if (z > point.z) != (previous_z > point.z) and \
				point.x < (previous_x - x) * (point.z - z) / (previous_z - z) + x:
			inside = not inside
		previous = index
	return inside


static func _row_key(row: Dictionary) -> String:
	var raw := row.get("raw", {}) as Dictionary
	return "%s#%s#%s" % [str(raw.get("layer", "")), str(raw.get("instance", "")),
		str(raw.get("instance_guid", ""))]


static func _count_role(objects: Array, role: int) -> int:
	var count := 0
	for value in objects:
		if int((value as Dictionary).get("role", 0)) == role:
			count += 1
	return count


static func _build_vehicle(row: Dictionary, objective_shared_root: Node,
		hq_team_roots: Array, objective_vehicles_root: Node,
		emplacements_root: Node, owner: Node, captures: Dictionary, hqs: Array,
		hq_vehicle_links: Array, objective_vehicle_counts: Dictionary,
		level: String, mode: String) -> void:
	var raw := row.get("raw", {}) as Dictionary
	var selector := int(raw.get("gem_selector", row.get("gem_value", -1)))
	var is_stationary := bool(row.get("stationary", false))
	if is_stationary:
		var stationary_type := int(STATIONARY_SELECTOR_TYPES.get(selector, -1))
		var valid_stationary := stationary_type >= 0
		var stationary_name: String = ["BGM71TOW", "GDF009", "M2MG"][stationary_type] \
			if valid_stationary else "Unassigned"
		var stationary := _create_vehicle(row, emplacements_root, owner, selector, stationary_type,
			stationary_name, true, valid_stationary)
		stationary.set_meta("bf6_vehicle_type_status",
			"installed activity class -> SDK stationary type")
		stationary.set_meta("bf6_source_vehicle_record", true)
		return

	var vehicle_types: Array = VEHICLE_CLASS_TYPES.get(selector, [])
	var vehicle_class_name := str(VEHICLE_CLASS_NAMES.get(selector,
		"UnknownClass%d" % selector))
	if mode in ["rush", "breakthrough", "operations"]:
		var point := _vec3(row.get("centre", []))
		var hq_index := _containing_hq(hqs, point)
		if hq_index >= 0 and not vehicle_types.is_empty():
			var team_index := clampi(int((hqs[hq_index] as Node).get("Team")) - 1, 0, 1)
			var vehicle_type := int(vehicle_types[team_index] if vehicle_types.size() > 1 \
				else vehicle_types[0])
			var vehicle := _create_vehicle(row, hq_team_roots[team_index], owner, selector,
				vehicle_type, VEHICLE_NAMES[vehicle_type], false, true)
			vehicle.set("P_AutoSpawnEnabled", true)
			vehicle.set_meta("bf6_vehicle_class", vehicle_class_name)
			vehicle.set_meta("bf6_vehicle_type_status",
				"installed activity class + exact containing HQ faction")
			vehicle.set_meta("bf6_runtime_association", "HQ%d / Team%d" % [hq_index + 1,
				team_index + 1])
			vehicle.set_meta("bf6_association_basis",
				"inside exact installed HQ polygon; no distance fallback")
			hq_vehicle_links[hq_index].append(vehicle)
			vehicle.set_meta("bf6_source_vehicle_record", true)
			return
		# Preserve exact unmatched records for inspection, but do not fabricate an
		# HQ/objective association when no installed polygon proves one.
		var exact_type := int(vehicle_types[0]) if not vehicle_types.is_empty() else -1
		var exact_name: String = str(VEHICLE_NAMES[exact_type]) if exact_type >= 0 else \
			"UnassignedSelector%d" % selector
		var unassigned := _create_vehicle(row, objective_shared_root, owner, selector,
			exact_type, exact_name, false, exact_type >= 0)
		unassigned.set("ObjId", -1)
		unassigned.set("P_AutoSpawnEnabled", true)
		unassigned.name = "RuntimeUnassigned_%s_Root%02d" % [exact_name, _root_order(row)]
		unassigned.set_meta("bf6_runtime_association",
			"unassigned: no containing installed HQ polygon; no distance fallback")
		unassigned.set_meta("bf6_source_vehicle_record", true)
		return
	var point := _vec3(row.get("centre", []))
	var contained_flag := _containing_capture(captures, point)
	var nearest_flag := contained_flag if contained_flag >= 0 else \
		(_nearest_capture(captures, point) if not captures.is_empty() else -1)
	var capture_distance := point.distance_squared_to((captures[nearest_flag] as Node3D).position) \
		if nearest_flag >= 0 else INF
	var nearest_hq := _nearest_index(hqs, point) if not hqs.is_empty() else -1
	var contained_hq := _containing_hq(hqs, point)
	var hq_distance := point.distance_squared_to((hqs[nearest_hq] as Node3D).position) \
		if nearest_hq >= 0 else INF
	if contained_hq >= 0:
		nearest_hq = contained_hq
	var belongs_to_hq := nearest_hq >= 0 and \
		(contained_hq >= 0 or (contained_flag < 0 and hq_distance < capture_distance))
	if vehicle_types.is_empty():
		var unknown_parent: Node = objective_shared_root
		var unknown_team_index := -1
		if belongs_to_hq:
			unknown_team_index = clampi(int((hqs[nearest_hq] as Node).get("Team")) - 1, 0, 1)
			unknown_parent = hq_team_roots[unknown_team_index]
		elif nearest_flag >= 0:
			unknown_parent = _objective_vehicle_folder(objective_vehicles_root,
				nearest_flag, 0, owner)
		var unknown := _create_vehicle(row, unknown_parent, owner, selector, -1,
			"UnassignedSelector%d" % selector, false, false)
		unknown.set("ObjId", -1)
		unknown.set("P_AutoSpawnEnabled", true)
		if belongs_to_hq:
			unknown.name = "HQ_Team%d_Unresolved_Root%02d" % [unknown_team_index + 1,
				_root_order(row)]
			unknown.set_meta("bf6_runtime_association", "HQ%d / Team%d" % [
				nearest_hq + 1, unknown_team_index + 1])
			hq_vehicle_links[nearest_hq].append(unknown)
		elif nearest_flag >= 0:
			unknown.name = _objective_vehicle_name(nearest_flag, 0,
				"UnassignedSelector%d" % selector, row)
			unknown.set_meta("bf6_runtime_association", "CapturePoint%s / Shared" %
				String.chr(65 + nearest_flag))
		unknown.set_meta("bf6_source_vehicle_record", true)
		return

	if belongs_to_hq:
		var team_index := clampi(int((hqs[nearest_hq] as Node).get("Team")) - 1, 0, 1)
		var vehicle_type := int(vehicle_types[team_index] if vehicle_types.size() > 1 \
			else vehicle_types[0])
		var vehicle := _create_vehicle(row, hq_team_roots[team_index], owner, selector,
			vehicle_type, VEHICLE_NAMES[vehicle_type], false, true)
		vehicle.set_meta("bf6_vehicle_class", vehicle_class_name)
		vehicle.set_meta("bf6_vehicle_type_status",
			"installed activity class + faction picker -> SDK VehicleType")
		vehicle.set("P_AutoSpawnEnabled", true)
		hq_vehicle_links[nearest_hq].append(vehicle)
		vehicle.set_meta("bf6_runtime_association", "HQ%d / Team%d" % [nearest_hq + 1,
			team_index + 1])
		vehicle.set_meta("bf6_association_basis", "inside authored HQArea" \
			if contained_hq >= 0 else "nearest HQ versus capture anchor")
		vehicle.set_meta("bf6_source_vehicle_record", true)
		return

	for index in range(vehicle_types.size()):
		var vehicle_team := index + 1 if vehicle_types.size() > 1 else 0
		var vehicle_type := int(vehicle_types[index])
		if level == "mp_capstone" and mode == "conquest" and \
				nearest_flag in [1, 4] and selector == 0 and vehicle_types.size() > 1:
			vehicle_type = int(VEHICLE_CLASS_TYPES[2][index])
			vehicle_class_name = "Tank"
		var vehicle_parent: Node = _objective_vehicle_folder(objective_vehicles_root,
			nearest_flag, vehicle_team, owner) if nearest_flag >= 0 else objective_shared_root
		var vehicle := _create_vehicle(row, vehicle_parent, owner, selector, vehicle_type,
			VEHICLE_NAMES[vehicle_type], false, true)
		vehicle.set_meta("bf6_vehicle_class", vehicle_class_name)
		vehicle.set_meta("bf6_vehicle_type_status",
			"installed activity class + faction picker -> SDK VehicleType")
		if nearest_flag >= 0:
			var counter_key := "%d/%d" % [nearest_flag, vehicle_team]
			var slot := int(objective_vehicle_counts.get(counter_key, 0))
			objective_vehicle_counts[counter_key] = slot + 1
			var objective_id := -1 if vehicle_team == 0 or slot >= 5 else \
				600 + nearest_flag * 10 + (5 if vehicle_team == 2 else 0) + slot
			vehicle.set("ObjId", objective_id)
			if objective_id == -1:
				vehicle.set("P_AutoSpawnEnabled", true)
			vehicle.name = _objective_vehicle_name(nearest_flag, vehicle_team,
				VEHICLE_NAMES[vehicle_type], row)
			if vehicle_team > 0:
				vehicle.set("SpawnIfMatchingTeam", true)
				vehicle.set("MatchingTeam", vehicle_team)
			vehicle.set_meta("bf6_runtime_association", "CapturePoint%s / %s" % [
				String.chr(65 + nearest_flag),
				"Team%d" % vehicle_team if vehicle_team > 0 else "Shared"])
			vehicle.set_meta("bf6_association_basis", "inside authored CaptureArea" \
				if contained_flag >= 0 else "nearest capture versus HQ anchor")
			vehicle.set_meta("bf6_activation_source",
				"retail ForwardSpawnerEnabled is runtime-fed; Portal uses SpawnIfMatchingTeam")
			if level == "mp_capstone" and mode == "conquest" and \
					nearest_flag in [1, 4] and selector == 0:
				vehicle.set_meta("bf6_vehicle_override",
					"in-game verified Capstone objectives B/E use the Tank faction pair")
		# A faction pair represents one authored retail pad. Mark only its first
		# SDK variant so manifest census tests continue to count source records.
		if index == 0:
			vehicle.set_meta("bf6_source_vehicle_record", true)


static func _objective_vehicle_name(flag: int, team: int, type_name: String,
		row: Dictionary) -> String:
	var ownership := "Team%d" % team if team > 0 else "Shared"
	return "Objective_%s_%s_%s_Root%02d" % [String.chr(65 + flag), ownership,
		type_name, _root_order(row)]


static func _automatic_aa_name(row: Dictionary, team: int) -> String:
	var ownership := "Team%d" % team if team > 0 else "Neutral"
	return "AutomaticAA_%s_Root%02d" % [ownership, _root_order(row)]


static func _automatic_aa_team(hqs: Array, point: Vector3) -> Dictionary:
	var containing: Array = []
	for hq in hqs:
		var area := hq.get("HQArea") as Node3D
		if area != null and _volume_contains_layout_point(hq, area, point):
			containing.append(hq)
	if not containing.is_empty():
		var team := int(containing[0].get("Team"))
		var single_team := team in [1, 2]
		for hq in containing:
			if int(hq.get("Team")) != team: single_team = false
		if single_team:
			return {"team": team, "basis": "inferred from containing game-derived HQArea"}
	var nearest: Node3D = null
	var best_distance := INF
	for hq in hqs:
		if int(hq.get("Team")) not in [1, 2]: continue
		var distance: float = point.distance_squared_to(hq.position)
		if distance < best_distance:
			best_distance = distance
			nearest = hq
	if nearest != null:
		return {"team": int(nearest.get("Team")),
			"basis": "inferred from nearest game-derived HQ position"}
	return {"team": 0, "basis": "unresolved: no assigned HQ"}


static func _hq_faction_for_point(hqs: Array, point: Vector3) -> int:
	if hqs.is_empty():
		return 0
	if hqs.size() <= 2:
		return _nearest_index(hqs, point) + 1
	# Multi-stage modes retain several HQ positions for each faction. The
	# earliest authored HQ is Team 1's anchor; the most distant HQ is the other
	# faction's anchor. Assigning every phase location to its nearer endpoint
	# keeps AA OwnerTeam in the SDK's valid 1..2 range.
	var team_1_index := 0
	var lowest_root := int((hqs[0] as Node).get_meta("bf6_root_order", 2147483647))
	for index in range(1, hqs.size()):
		var root_order := int((hqs[index] as Node).get_meta("bf6_root_order", 2147483647))
		if root_order < lowest_root:
			lowest_root = root_order
			team_1_index = index
	var team_1_anchor := hqs[team_1_index] as Node3D
	var team_2_index := team_1_index
	var greatest_distance := -1.0
	for index in range(hqs.size()):
		var distance := team_1_anchor.position.distance_squared_to((hqs[index] as Node3D).position)
		if distance > greatest_distance:
			greatest_distance = distance
			team_2_index = index
	var team_2_anchor := hqs[team_2_index] as Node3D
	return 1 if point.distance_squared_to(team_1_anchor.position) <= \
		point.distance_squared_to(team_2_anchor.position) else 2


static func _root_order(row: Dictionary) -> int:
	var raw := row.get("raw", {}) as Dictionary
	var root_order := int(raw.get("root_order", -1))
	return root_order if root_order >= 0 else int(raw.get("instance", 0))


static func _create_vehicle(row: Dictionary, parent: Node, owner: Node, selector: int,
		vehicle_type: int, type_name: String, is_stationary: bool, resolved: bool) -> Node3D:
	var raw := row.get("raw", {}) as Dictionary
	var vehicle := _scene("stationary" if is_stationary else "vehicle",
		"%s_%s" % [str(row.get("label", "Vehicle")), type_name])
	vehicle.transform = _raw_transform(row)
	if not is_stationary:
		vehicle.set("P_DefaultRespawnTime", 45)
	# Stationary emplacements must exist without a separate spawn request. An
	# unresolved VehicleType (-1) needs the same behavior so the placeholder is
	# active and can be configured in the editor.
	if is_stationary or vehicle_type == -1:
		vehicle.set("P_AutoSpawnEnabled", true)
	if resolved:
		vehicle.set("StationaryEmplacementType" if is_stationary else "VehicleType", vehicle_type)
	vehicle.set_meta(PROVENANCE_META, _source(row))
	vehicle.set_meta("bf6_source_instance_guid", str(raw.get("instance_guid", "")))
	vehicle.set_meta("bf6_root_order", _root_order(row))
	vehicle.set_meta("bf6_retail_selector", selector)
	vehicle.set_meta("bf6_vehicle_type_status", "resolved retail vehicle class" \
		if resolved else "retail vehicle class is unresolved; SDK default retained")
	parent.add_child(vehicle)
	vehicle.owner = owner
	if resolved:
		if is_stationary:
			VehicleSkin.sync_stationary(vehicle, owner)
		else:
			VehicleSkin.sync_spawner(vehicle, owner)
	return vehicle


static func _add_plain(row: Dictionary, kind: String, parent: Node, owner: Node) -> Node3D:
	var node := _scene(kind, str(row.get("label", kind.capitalize())))
	node.transform = _raw_transform(row)
	node.set_meta(PROVENANCE_META, _source(row))
	var raw: Dictionary = row.get("raw", {})
	node.set_meta("bf6_source_identity",
		str(raw.get("partition", "")) + "#" + str(raw.get("instance_guid", "")))
	parent.add_child(node)
	node.owner = owner
	return node


static func _add_polygon(row: Dictionary, parent: Node, owner: Node, color: Color) -> void:
	var node := _polygon(row, str(row.get("label", "Zone")), color)
	parent.add_child(node)
	node.owner = owner


static func _polygon(row: Dictionary, node_name: String, color: Color) -> Node3D:
	var node := _scene("volume", node_name)
	var center := _vec3(row.get("centre", []))
	node.position = center
	var source: Array = row.get("world_points", [])
	var points := PackedVector2Array()
	for index in range(0, source.size(), 3):
		points.append(Vector2(float(source[index]) - center.x, float(source[index + 2]) - center.z))
	node.set("points", points)
	node.set("height", float(row.get("height", 0.0)))
	node.set("color", color)
	node.set_meta(PROVENANCE_META, _source(row))
	return node


static func _volume_preview_center(row: Dictionary) -> Vector3:
	var center := _vec3(row.get("centre", []))
	# Portal defines height 0 as infinite, so moving its editor gizmo in Y
	# cannot change gameplay. The classified row retains the installed source
	# transform and a separate game-terrain sample for this exact footprint.
	var land := row.get("land", []) as Array
	if absf(float(row.get("height", 0.0))) < 0.001 and land.size() == 3:
		center.y = float(land[1])
	return center


static func _ensure_progressive_volume_height(volume: Node) -> void:
	if float(volume.get("height")) > 0.0:
		return
	# The installed boundary row provides an exact horizontal footprint but some
	# progressive VectorShapeData rows serialize no extrusion. Portal requires a
	# non-zero PolygonVolume height; 100 m is the creator template's disclosed SDK
	# compatibility extrusion, not a claimed retail measurement.
	volume.set("height", 100.0)
	volume.set_meta("bf6_portal_height_translation",
		"100 m Blockly-template extrusion; installed polygon serialized height 0")


static func _spatial_protection_polygon(shape: Dictionary, node_name: String) -> Node3D:
	var node := _scene("volume", node_name)
	var transform_values: Array = shape.get("transform", [])
	if transform_values.size() == 12:
		var source_basis := Basis(_vec3(transform_values.slice(0, 3)),
			_vec3(transform_values.slice(3, 6)), _vec3(transform_values.slice(6, 9)))
		node.transform = Transform3D(_upright_basis(source_basis),
			_vec3(transform_values.slice(9, 12)))
	var extents := _vec3(shape.get("half_extents", []))
	var points := PackedVector2Array()
	if str(shape.get("kind", "")) == "cylinder":
		# Portal exposes PolygonVolume but no cylinder volume. A 32-sided authored-
		# radius polygon is the closest lossless SDK representation of CylinderData.
		for index in range(32):
			var angle := TAU * float(index) / 32.0
			points.append(Vector2(cos(angle) * extents.x, sin(angle) * extents.z))
	else:
		points = PackedVector2Array([
			Vector2(-extents.x, -extents.z), Vector2(-extents.x, extents.z),
			Vector2(extents.x, extents.z), Vector2(extents.x, -extents.z),
		])
	node.set("points", points)
	node.set("height", extents.y * 2.0)
	node.set("color", Color(0.9, 0.12, 0.12, 0.32))
	node.set_meta(PROVENANCE_META, "installed_bf6:%s#%s" % [
		str(shape.get("partition", "")), str(shape.get("instance_guid", ""))])
	return node


static func _upright_basis(source: Basis) -> Basis:
	var x_axis := source.x
	x_axis.y = 0.0
	if x_axis.length_squared() < 0.000001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	return Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP).normalized())


static func _scene(kind: String, node_name: String) -> Node3D:
	var packed := load(SCENES[kind]) as PackedScene
	var node := packed.instantiate() as Node3D
	node.name = node_name
	return node


static func _objective_vehicle_folder(parent: Node, flag: int, team: int,
		owner: Node) -> Node3D:
	var objective := _folder(parent, "Objective_%s" % String.chr(65 + flag), owner)
	return _folder(objective, "Team%d" % team if team > 0 else "Shared", owner)


static func _folder(parent: Node, node_name: String, owner: Node) -> Node3D:
	var existing := parent.get_node_or_null(NodePath(node_name)) as Node3D
	if existing != null:
		return existing
	var node := Node3D.new()
	node.name = node_name
	node.set_meta("bf6_generated_folder", true)
	parent.add_child(node)
	node.owner = owner
	return node


static func _apply_retail_mode_settings(root: Node, mode: String) -> void:
	# These are authored mutator defaults, not Portal SDK gameplay properties.
	# Keep the names/values intact so a Blockly/TypeScript builder can translate
	# only the fields that Portal actually exposes.
	var package = JSON.parse_string(FileAccess.get_file_as_string(RETAIL_SETTINGS))
	if not package is Dictionary:
		root.set_meta("bf6_retail_settings_status", "missing or invalid decoded defaults")
		return
	var key := "kingofthehill" if mode == "koth" else mode
	var record: Dictionary = package.get("modes", {}).get(key, {})
	if record.is_empty():
		root.set_meta("bf6_retail_settings_status", "no decoded mutator defaults for this mode")
		return
	root.set_meta("bf6_retail_mode_defaults", record.get("values", {}))
	root.set_meta("bf6_retail_mode_defaults_partition", str(record.get("partition", "")))
	root.set_meta("bf6_retail_settings_status",
		"installed-game mutator defaults; not live server values or applied SDK properties")


static func _prune_empty_folders(node: Node) -> void:
	for child in node.get_children():
		_prune_empty_folders(child)
	for child in node.get_children():
		if child.has_meta("bf6_generated_folder") and child.get_child_count() == 0:
			node.remove_child(child)
			child.free()


static func _sort_generated_hierarchy(root: Node) -> void:
	var objectives := root.get_node_or_null("Vehicles/Objectives")
	if objectives != null:
		_sort_children_by_name(objectives)
		for objective in objectives.get_children():
			_sort_children_by_rank(objective, {"Team1": 0, "Team2": 1, "Shared": 2})
	var order := {
		"Play Area": 0, "TEAM_1_HQ": 1, "TEAM_2_HQ": 2, "Objectives": 3,
		"Spawns": 4, "Vehicles": 5, "Emplacements": 6, "Resupply": 7,
		"AA-Defences": 8, "Extras": 9,
		"Aircraft Carriers (hide to disable preview)": 10,
	}
	for child in root.get_children():
		if str(child.name).begins_with("TEAM_1_HQ"):
			order[str(child.name)] = 1
		elif str(child.name).begins_with("TEAM_2_HQ"):
			order[str(child.name)] = 2
	_sort_children_by_rank(root, order)


static func _humanize_tree_names(parent: Node) -> void:
	var replacements := {}
	var reserved := {}
	for child in parent.get_children():
		if _readable_node_base(child) == str(child.name): reserved[str(child.name)] = true
	for child in parent.get_children():
		var base := _readable_node_base(child)
		if base == str(child.name): continue
		var candidate := base
		var ordinal := 2
		while reserved.has(candidate):
			candidate = "%s_%02d" % [base, ordinal]
			ordinal += 1
		reserved[candidate] = true
		replacements[child] = candidate
	var temporary := 0
	for child in replacements:
		var placeholder := "__bf6_rename_%d" % temporary
		while parent.has_node(placeholder):
			temporary += 1
			placeholder = "__bf6_rename_%d" % temporary
		child.name = placeholder
		temporary += 1
	for child in replacements: child.name = replacements[child]
	for child in parent.get_children(): _humanize_tree_names(child)


static func _readable_node_base(node: Node) -> String:
	var name := str(node.name)
	var root_at := name.find("_Root")
	if root_at >= 0:
		var end := root_at + 5
		if end < name.length() and name[end] == "-": end += 1
		while end < name.length() and name[end] in "0123456789": end += 1
		if end > root_at + 5 and name[end - 1] in "0123456789":
			name = name.left(root_at) + name.substr(end)
			name = name.trim_suffix("_")
	var cut := name.rfind("_")
	if cut < 0 or name.length() - cut != 9: return name
	var suffix := name.substr(cut + 1)
	for character in suffix:
		if not character in "0123456789abcdefABCDEF": return name
	var prefix := name.left(cut)
	if prefix == "hq":
		var team := int(node.get("Team"))
		return "TEAM_%d_HQ_Additional" % team if team in [1, 2] else "HQ_Unassigned"
	if prefix.begins_with("Spawn"): return "Spawn"
	if prefix == "Area": return "UnassignedArea"
	if prefix == "Protection": return "ProtectionArea"
	if prefix == "Group": return "SchematicGroup"
	return prefix


static func _sort_children_by_name(parent: Node) -> void:
	var children := parent.get_children()
	children.sort_custom(func(a: Node, b: Node) -> bool:
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	for index in range(children.size()):
		parent.move_child(children[index], index)


static func _sort_children_by_rank(parent: Node, ranks: Dictionary) -> void:
	var children := parent.get_children()
	children.sort_custom(func(a: Node, b: Node) -> bool:
		var ar := int(ranks.get(str(a.name), 100))
		var br := int(ranks.get(str(b.name), 100))
		return ar < br if ar != br else str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	for index in range(children.size()):
		parent.move_child(children[index], index)


static func _raw_transform(row: Dictionary) -> Transform3D:
	var raw := row.get("raw", {}) as Dictionary
	var t: Array = raw.get("transform", [])
	if t.size() != 12:
		return Transform3D(Basis.IDENTITY, _vec3(row.get("centre", [])))
	return Transform3D(Basis(_vec3(t.slice(0, 3)), _vec3(t.slice(3, 6)), _vec3(t.slice(6, 9))), _vec3(t.slice(9, 12)))


static func _element_transform(row: Dictionary) -> Transform3D:
	var t: Array = row.get("transform", [])
	if t.size() != 12:
		return Transform3D.IDENTITY
	return Transform3D(Basis(_vec3(t.slice(0, 3)), _vec3(t.slice(3, 6)),
		_vec3(t.slice(6, 9))), _vec3(t.slice(9, 12)))


static func _vec3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2])) if value.size() >= 3 else Vector3.ZERO


static func _append_spawn_for_team(spawn_sets: Dictionary, flag: int, spawn: Node,
		team: int) -> void:
	if team == 1 or team == 2:
		spawn_sets[flag][team].append(spawn)
	else:
		spawn_sets[flag][1].append(spawn)
		spawn_sets[flag][2].append(spawn)


static func _set_array(node: Object, property: String, values: Array) -> void:
	var current = node.get(property)
	if current is Array:
		var typed: Array = current
		typed.assign(values)
		node.set(property, typed)
	else:
		node.set(property, values)


static func _nearest_capture(captures: Dictionary, point: Vector3) -> int:
	var best := -1
	var distance := INF
	for flag in captures:
		var d := point.distance_squared_to((captures[flag] as Node3D).position)
		if d < distance: distance = d; best = int(flag)
	return best


static func _containing_capture(captures: Dictionary, point: Vector3) -> int:
	for flag in captures:
		var capture := captures[flag] as Node3D
		var area := capture.get("CaptureArea") as Node3D
		if area != null and _volume_contains_layout_point(capture, area, point):
			return int(flag)
	return -1


static func _containing_hq(hqs: Array, point: Vector3) -> int:
	for index in range(hqs.size()):
		var hq := hqs[index] as Node3D
		var area := hq.get("HQArea") as Node3D
		if area != null and _volume_contains_layout_point(hq, area, point):
			return index
	return -1


static func _volume_contains_layout_point(parent: Node3D, volume: Node3D,
		point: Vector3) -> bool:
	var local := (parent.transform * volume.transform).affine_inverse() * point
	var source = volume.get("points")
	if not (source is PackedVector2Array) or source.size() < 3:
		return false
	var polygon := source as PackedVector2Array
	var inside := false
	var previous := polygon.size() - 1
	for index in range(polygon.size()):
		var current := polygon[index]
		var before := polygon[previous]
		if (current.y > local.z) != (before.y > local.z) and \
				local.x < (before.x - current.x) * (local.z - current.y) / \
				(before.y - current.y) + current.x:
			inside = not inside
		previous = index
	return inside


static func _nearest_index(nodes: Array, point: Vector3) -> int:
	var best := 0
	var distance := INF
	for index in range(nodes.size()):
		var d := point.distance_squared_to((nodes[index] as Node3D).position)
		if d < distance: distance = d; best = index
	return best


static func _mark_template_adjustment(node: Node, reason: String) -> void:
	node.set_meta("bf6_template_modified", true)
	node.set_meta("bf6_template_name", TEMPLATE_NAME)
	node.set_meta("bf6_template_adjustment", reason)
	node.set_meta("bf6_template_asset_status",
		"No creator-authored asset included. Spatial/type data is game-derived where " +
		"present; the marked SDK wrapper or identity may exist only for compatibility.")
	if _has_property(node, "ObjId"):
		node.set_meta("bf6_template_assigned_obj_id", int(node.get("ObjId")))


static func _template_compatibility_summary(node: Node) -> Dictionary:
	var adjustments := 1 if bool(node.get_meta("bf6_template_modified", false)) else 0
	var aliases := 1 if bool(node.get_meta("bf6_template_hq_alias", false)) else 0
	for child in node.get_children():
		var child_summary := _template_compatibility_summary(child)
		adjustments += int(child_summary.adjustments)
		aliases += int(child_summary.aliases)
	return {"adjustments": adjustments, "aliases": aliases}


static func _source(row: Dictionary) -> String:
	var binding := row.get("capture_binding", {}) as Dictionary
	if not binding.is_empty():
		return "%s capture instance %s root %s; volume binding %s" % [
			str(binding.get("partition", "")), str(binding.get("instance_guid", "?")),
			str(binding.get("root_order", "-")), str(binding.get("method", "unknown"))]
	var raw := row.get("raw", {}) as Dictionary
	return "%s instance %s root %s" % [str(raw.get("layer", "")), str(raw.get("instance", "?")), str(raw.get("root_order", "-"))]


static func _pretty(mode: String) -> String:
	var names := {"carrierstrike": "Carrier Strike", "kingofthehill": "King of the Hill",
		"koth": "KOTH", "squaddeathmatch": "Squad Deathmatch", "teamdeathmatch": "Team Deathmatch"}
	return str(names.get(mode, mode.capitalize()))


static func _find(root: Node, layout_id: String) -> Node:
	for child in root.get_children():
		if child.has_meta(BUILD_META) and str(child.get_meta(BUILD_META)) == layout_id:
			return child
	return null
