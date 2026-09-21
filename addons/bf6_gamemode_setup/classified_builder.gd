@tool
extends RefCounted

const VehicleSkin = preload("res://addons/bf6_gamemode_setup/vehicle_skin.gd")
const CarrierPreview = preload("res://addons/bf6_gamemode_setup/carrier_preview.gd")

const BUILD_META := "bf6_gamemode_setup"
const PROVENANCE_META := "bf6_source"
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
	if int(document.get("schema", 0)) not in [2, 3] or level == "" or mode == "":
		return "Classified layout manifest is invalid"
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
	if mode in ["breakthrough", "operations"]:
		capture_rows = _breakthrough_capture_rows(objects, elements)
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
			capture.set_meta("bf6_capture_volume_distance_m",
				float(capture_binding.get("distance_m", -1.0)))
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
	for value in hq_rows:
		var row := value as Dictionary
		var hq := _scene("hq", "HQ_Root%02d" % _root_order(row))
		hq.transform = _raw_transform(row)
		hq.set_meta(PROVENANCE_META, _source(row))
		hq.set_meta("bf6_source_instance_guid",
			str((row.get("raw", {}) as Dictionary).get("instance_guid", "")))
		hq.set_meta("bf6_root_order", int((row.get("raw", {}) as Dictionary).get(
			"root_order", hqs.size())))
		root.add_child(hq)
		hq.owner = map_root
		hqs.append(hq)
		progress_current += 1
		_report(progress, "Creating headquarters…", progress_current, progress_total)
	for hq_index in range(hqs.size()):
		var hq := hqs[hq_index] as Node3D
		var hq_team := hq_index + 1 if hqs.size() <= 2 else \
			_hq_faction_for_point(hqs, hq.position)
		hq.set("Team", hq_team)
		hq.set("AltTeam", 2 if hq_team == 1 else 1)
		hq.set("ObjId", hq_index + 1)
		hq.name = "TEAM_%d_HQ" % hq_team if hqs.size() <= 2 else \
			"TEAM_%d_HQ_Root%02d" % [hq_team, int(hq.get_meta("bf6_root_order", hq_index))]
		hq.set_meta("bf6_faction_assignment", "authored order" if hqs.size() <= 2 else \
			"nearest endpoint of multi-stage HQ chain")
	var claimed_zone_sources := {}
	var claimed_capture_sources := {}
	for value in capture_rows:
		var capture_row := value as Dictionary
		if int(capture_row.get("role", 0)) == 3:
			claimed_capture_sources[_row_key(capture_row)] = true
	if mode == "conquest" and not hqs.is_empty():
		claimed_zone_sources = _assign_hq_areas(objects, hqs, map_root)
	if mode == "conquest":
		_build_combat_area_from_unclaimed_zones(objects, claimed_zone_sources,
			zones_root, map_root)

	var hq_spawns: Array = []
	for _index in range(hqs.size()): hq_spawns.append([])
	var insertion_rows := _mode_elements(elements, "gem_insertion")
	insertion_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("root_order", -1)) < int(b.get("root_order", -1)))
	var has_authored_hq_insertions := not insertion_rows.is_empty() and not hqs.is_empty()
	if has_authored_hq_insertions:
		for value in insertion_rows:
			var insertion := value as Dictionary
			var insertion_transform := _element_transform(insertion)
			var hq_index := _nearest_index(hqs, insertion_transform.origin)
			if hq_index < 0:
				continue
			var hq := hqs[hq_index] as Node3D
			var spawn := _scene("spawn", "Spawn_HQ_%d_%02d" % [
				int(hq.get("Team")), hq_spawns[hq_index].size() + 1])
			spawn.transform = hq.transform.affine_inverse() * insertion_transform
			spawn.set_meta(PROVENANCE_META, "%s instance %s root %s" % [
				str(insertion.get("layer", "")), str(insertion.get("instance_guid", "?")),
				str(insertion.get("root_order", "-"))])
			spawn.set_meta("bf6_source_instance_guid", str(insertion.get("instance_guid", "")))
			spawn.set_meta("bf6_spawn_binding", "installed_gem_insertion")
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
		if captures_own_loose_spawns and nearest_flag >= 0 and capture_distance <= hq_distance:
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
				mcom.name = "MCOM_Root%02d" % _root_order(row)
				mcom.set("ObjId", 300 + maxi(_root_order(row), 0))
				if mode in ["obliteration", "squadobliteration"]:
					mcom.set("RequiresCarriableToArm", true)
					mcom.set_meta("bf6_mode_contract", "carried bomb required")
			elif mode != "rush":
				_add_plain(row, "mcom", attachments_root, map_root)
		elif role == 9:
			if mode in ["obliteration", "squadobliteration"]:
				var bombs_root := _folder(captures_root, "Bomb Spawn Candidates", map_root)
				var bomb := _add_plain(row, "bomb", bombs_root, map_root)
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
			var aa_point := _vec3(row.get("centre", []))
			var nearest_hq_index := _nearest_index(hqs, aa_point) if not hqs.is_empty() else -1
			var aa_team := _hq_faction_for_point(hqs, aa_point)
			var aa := _scene("automatic_aa", _automatic_aa_name(row, aa_team))
			aa.transform = _raw_transform(row)
			aa.set_meta(PROVENANCE_META, _source(row))
			aa_root.add_child(aa)
			aa.owner = map_root
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
			elif nearest_hq_index >= 0:
				var nearest: Node = hqs[nearest_hq_index]
				if nearest.get("HQArea") != null:
					aa.set("ProtectionAreaVolume", nearest.get("HQArea"))
					aa.set_meta("bf6_protection_hq", str(nearest.name))
					aa.set_meta("bf6_protection_binding", "legacy_nearest_hq_fallback")
			VehicleSkin.sync_automatic_aa(aa, map_root)
		if role in [6, 7, 8, 9, 10, 101]:
			progress_current += 1
			_report(progress, "Creating vehicles and attachments…", progress_current, progress_total)

	for hq_index in range(hqs.size()):
		_set_array(hqs[hq_index], "VehicleSpawners", hq_vehicle_links[hq_index])
		hqs[hq_index].set("VehicleSpawnersEnabled", not hq_vehicle_links[hq_index].is_empty())
	if mode == "rush":
		_build_rush_objectives(objects, captures_root, map_root, hqs, elements)
	elif mode == "payload":
		_build_payload_objectives(elements, captures_root, map_root)
	elif mode == "sabotage":
		_build_sabotage_objectives(objects, elements, captures_root, map_root)
	elif mode == "carrierstrike":
		_build_carrier_objectives(elements, captures_root, map_root)
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

	if mode in ["breakthrough", "operations"] and not captures.is_empty():
		_build_breakthrough_sectors(captures, captures_root, map_root, elements, hqs)
	elif CATCH_ALL_SECTOR_MODES.has(mode) and not captures.is_empty():
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
	_report(progress, "Game mode ready", progress_total, progress_total)

	var counts := document.get("counts", {}) as Dictionary
	return "Built %s %s: %d game-data objects (%d captures, %d spawns, %d vehicles)" % [
		level, _pretty(mode), int(counts.get("objects", 0)), captures.size(),
		int(counts.get("spawns", 0)), int(counts.get("vehicles", 0))]


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
		owner: Node, hqs: Array, elements: Array) -> void:
	var rows: Array = []
	for value in objects:
		if int((value as Dictionary).get("role", 0)) == 8:
			rows.append(value)
	if rows.is_empty():
		return
	var sector_rows := _mode_elements(elements, "gem_sector")
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
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _root_order(a) < _root_order(b))
	for value in rows:
		var row := value as Dictionary
		var sector_index := _nearest_element_with_capacity(sector_rows, grouped,
			_vec3(row.get("centre", [])), 2)
		if sector_index >= 0:
			(grouped[sector_index] as Array).append(row)
	var sectors_root := _folder(objectives_root, "Sectors", owner)
	sectors_root.set_meta("bf6_authored_mcom_records", rows.size())
	sectors_root.set_meta("bf6_active_sector_slots", mini(rows.size(), sector_rows.size() * 2))
	sectors_root.set_meta("bf6_selection_basis",
		"installed gem_sector placements; nearest authored MCOMs, maximum two per sector")
	var grouped_hqs := _group_nodes_by_elements(hqs, sector_rows, 2)
	var objective_index := 0
	var emitted_sector_index := 0
	for sector_index in range(sector_rows.size()):
		var members := grouped[sector_index] as Array
		if members.is_empty():
			continue
		var sector_row := sector_rows[sector_index] as Dictionary
		var sector := _scene("sector", "Sector%d" % (emitted_sector_index + 1))
		sector.transform = _element_transform(sector_row)
		sector.set("ObjId", 101 + emitted_sector_index)
		sector.set_meta("bf6_order_basis", "installed GEM root order")
		sector.set_meta("bf6_source_instance_guid", str(sector_row.get("instance_guid", "")))
		sectors_root.add_child(sector)
		sector.owner = owner
		members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _root_order(a) < _root_order(b))
		var sector_mcoms: Array = []
		for slot in range(members.size()):
			var row := members[slot] as Dictionary
			var mcom := _scene("mcom", "MCOM-%s" % String.chr(65 + slot))
			mcom.transform = sector.transform.affine_inverse() * _raw_transform(row)
			mcom.set("ObjId", 201 + objective_index)
			mcom.set_meta(PROVENANCE_META, _source(row))
			mcom.set_meta("bf6_rush_sector", emitted_sector_index + 1)
			mcom.set_meta("bf6_rush_slot", slot)
			sector.add_child(mcom)
			mcom.owner = owner
			sector_mcoms.append(mcom)
			objective_index += 1
		_set_array(sector, "MCOMs", sector_mcoms)
		_set_array(sector, "HQs", grouped_hqs[sector_index] as Array)
		emitted_sector_index += 1


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


static func _build_breakthrough_sectors(captures: Dictionary,
		objectives_root: Node, owner: Node, elements: Array, hqs: Array) -> void:
	var sector_rows := _mode_elements(elements, "gem_sector")
	_sort_mode_elements_by_root_order(sector_rows)
	if sector_rows.is_empty():
		return
	var grouped: Array = []
	for _sector in sector_rows:
		grouped.append([])
	var ordered_flags: Array = captures.keys()
	ordered_flags.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((captures[a] as Node).get_meta("bf6_capture_root_order", -1)) < \
			int((captures[b] as Node).get_meta("bf6_capture_root_order", -1)))
	for flag in ordered_flags:
		var capture := captures[flag] as Node3D
		var sector_index := _nearest_element_with_capacity(sector_rows, grouped,
			capture.position, 3)
		if sector_index >= 0:
			(grouped[sector_index] as Array).append({"flag": flag, "node": capture})
	var sectors_root := _folder(objectives_root, "Sectors", owner)
	sectors_root.set_meta("bf6_authored_capture_controllers",
		_mode_elements(elements, "gem_capturepoint").size())
	sectors_root.set_meta("bf6_active_capture_records", captures.size())
	sectors_root.set_meta("bf6_selection_basis",
		"one-to-one game capture-controller/polygon join; maximum three objectives per sector")
	var grouped_hqs := _group_nodes_by_elements(hqs, sector_rows, 2)
	var emitted_sector_index := 0
	for sector_index in range(sector_rows.size()):
		var members := grouped[sector_index] as Array
		if members.is_empty():
			continue
		var sector_row := sector_rows[sector_index] as Dictionary
		var sector := _scene("sector", "Sector%d" % (emitted_sector_index + 1))
		sector.transform = _element_transform(sector_row)
		sector.set("ObjId", 101 + emitted_sector_index)
		sector.set_meta("bf6_order_basis", "installed GEM root order")
		sector.set_meta("bf6_source_instance_guid", str(sector_row.get("instance_guid", "")))
		sectors_root.add_child(sector)
		sector.owner = owner
		members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int((a.get("node") as Node).get_meta("bf6_capture_root_order", -1)) < \
				int((b.get("node") as Node).get_meta("bf6_capture_root_order", -1)))
		var sector_captures: Array = []
		for slot in range(members.size()):
			var member := members[slot] as Dictionary
			var capture := member.get("node") as Node3D
			_reparent_from_layout_space(capture, sector, owner)
			capture.name = "CapturePoint%s" % String.chr(65 + slot)
			capture.set("ObjId", 1100 + emitted_sector_index * 100 + slot)
			capture.set("InitialOwner", 2)
			capture.set_meta("bf6_breakthrough_source_flag", int(member.get("flag", -1)))
			sector_captures.append(capture)
		_set_array(sector, "CapturePoints", sector_captures)
		_set_array(sector, "HQs", grouped_hqs[sector_index] as Array)
		emitted_sector_index += 1


static func _breakthrough_capture_rows(objects: Array, elements: Array) -> Array:
	# Later Breakthrough phases are commonly emitted as ordinary polygon rows;
	# only the base-template objectives retain role 2.  The installed
	# gem_capturepoint transforms identify the live meaning of those polygons.
	# Match controllers and reasonably-sized authored polygons one-to-one. This
	# also rejects superseded controllers which share a replacement's polygon.
	var controllers := _mode_elements(elements, "gem_capturepoint")
	var polygons: Array = []
	for value in objects:
		var row := value as Dictionary
		if int(row.get("role", 0)) not in [2, 3]:
			continue
		if (row.get("world_points", []) as Array).size() < 9:
			continue
		if float(row.get("area_m2", INF)) > 25000.0:
			continue
		polygons.append(row)
	var pairs: Array = []
	for controller_index in range(controllers.size()):
		var point := _element_transform(controllers[controller_index] as Dictionary).origin
		for polygon_index in range(polygons.size()):
			var row := polygons[polygon_index] as Dictionary
			pairs.append({
				"controller": controller_index,
				"polygon": polygon_index,
				"distance": point.distance_to(_vec3(row.get("centre", []))),
			})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF)))
	var used_controllers := {}
	var used_polygons := {}
	var matched: Array = []
	for value in pairs:
		var pair := value as Dictionary
		if float(pair.get("distance", INF)) > 60.0:
			break
		var controller_index := int(pair.get("controller", -1))
		var polygon_index := int(pair.get("polygon", -1))
		if used_controllers.has(controller_index) or used_polygons.has(polygon_index):
			continue
		used_controllers[controller_index] = true
		used_polygons[polygon_index] = true
		matched.append(pair)
	matched.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int((controllers[int(a.get("controller", -1))] as Dictionary).get(
			"root_order", -1)) < int((controllers[int(b.get("controller", -1))] as Dictionary).get(
			"root_order", -1)))
	var rows: Array = []
	for flag in range(matched.size()):
		var pair := matched[flag] as Dictionary
		var controller := controllers[int(pair.get("controller", -1))] as Dictionary
		var row := (polygons[int(pair.get("polygon", -1))] as Dictionary).duplicate(true)
		row["flag"] = flag
		row["capture_binding"] = {
			"instance_guid": str(controller.get("instance_guid", "")),
			"root_order": int(controller.get("root_order", -1)),
			"method": "one_to_one_spatial_gem_capturepoint",
			"distance_m": float(pair.get("distance", -1.0)),
		}
		rows.append(row)
	return rows


static func _mode_elements(elements: Array, gem: String) -> Array:
	var rows: Array = []
	for value in elements:
		var row := value as Dictionary
		if str(row.get("gem", "")) == gem and \
				not str(row.get("layer", "")).ends_with("/gameplay_global"):
			rows.append(row)
	return rows


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


static func _assign_hq_areas(objects: Array, hqs: Array, owner: Node) -> Dictionary:
	var used := {}
	for hq_index in range(hqs.size()):
		var hq := hqs[hq_index] as Node3D
		var best: Dictionary = {}
		var best_area := INF
		for value in objects:
			var row := value as Dictionary
			if int(row.get("role", 0)) != 3:
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
		hq.add_child(area)
		area.owner = owner
		area.transform = hq.transform.affine_inverse() * area.transform
		area.set_meta("bf6_source_instance_guid",
			str((best.get("raw", {}) as Dictionary).get("instance_guid", "")))
		hq.set("HQArea", area)
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
	combat.position = _vec3(combat_row.get("centre", []))
	combat.set_meta(PROVENANCE_META, _source(combat_row))
	parent.add_child(combat)
	combat.owner = owner
	var volume := _polygon(combat_row, "CombatVolume", Color(0.2, 0.75, 0.3, 0.3))
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
	var belongs_to_hq := not is_stationary and nearest_hq >= 0 and \
		(contained_hq >= 0 or (contained_flag < 0 and hq_distance < capture_distance))

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


static func _source(row: Dictionary) -> String:
	var binding := row.get("capture_binding", {}) as Dictionary
	if not binding.is_empty():
		return "%s capture instance %s root %s; volume from nearest containing installed polygon" % [
			str(binding.get("partition", "")), str(binding.get("instance_guid", "?")),
			str(binding.get("root_order", "-"))]
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
