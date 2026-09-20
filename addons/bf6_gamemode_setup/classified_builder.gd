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


static func build(map_root: Node, layout_id: String, document: Dictionary,
		paths: Dictionary, replace_existing: bool, progress: Callable = Callable()) -> String:
	var source := document.get("source", {}) as Dictionary
	var level := str(source.get("level", ""))
	var mode := str(source.get("mode", ""))
	if int(document.get("schema", 0)) != 2 or level == "" or mode == "":
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
	root.set_meta(PROVENANCE_META, "installed BF6 %s/%s; classified layout schema 2" % [level, mode])
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
	var objective_vehicle_team_roots := [
		_folder(objective_vehicles_root, "Team1", map_root),
		_folder(objective_vehicles_root, "Team2", map_root),
	]
	var objective_shared_root := _folder(objective_vehicles_root, "Shared", map_root)
	var emplacements_root := _folder(vehicles_root, "Emplacements", map_root)
	var attachments_root := _folder(root, "Extras", map_root)
	var objects: Array = document.get("objects", [])
	var progress_total := objects.size() + 2
	var progress_current := 0
	_report(progress, "Preparing %s hierarchy…" % _pretty(mode), progress_current, progress_total)
	var captures := {}
	var capture_spawns := {}
	var hqs: Array = []
	if level == "mp_capstone" and mode == "conquest":
		_build_capstone_out_of_bounds(objects, zones_root, map_root)

	var capture_rows: Array = []
	for value in objects:
		var candidate := value as Dictionary
		if int(candidate.get("role", 0)) == 2 and mode != "rush" and \
				_normalized_flag(level, mode, candidate) >= 0:
			capture_rows.append(candidate)
	capture_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_flag := _normalized_flag(level, mode, a)
		var b_flag := _normalized_flag(level, mode, b)
		return a_flag < b_flag if a_flag != b_flag else _root_order(a) < _root_order(b))
	for value in capture_rows:
		var row := value as Dictionary
		if int(row.get("role", 0)) != 2:
			continue
		# Rush objectives are MCOMs. Its small unowned polygons are boundary
		# data, not CapturePoint gameplay objects.
		if mode == "rush":
			continue
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

	for value in objects:
		var row := value as Dictionary
		if int(row.get("role", 0)) != 100:
			continue
		var hq := _scene("hq", "HQ_Root%02d" % _root_order(row))
		hq.transform = _raw_transform(row)
		hq.set_meta(PROVENANCE_META, _source(row))
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
	if mode == "conquest" and _count_role(objects, 3) > hqs.size():
		claimed_zone_sources = _assign_hq_areas(objects, hqs, map_root)
	if mode == "conquest":
		_build_combat_area_from_unclaimed_zones(objects, claimed_zone_sources,
			zones_root, map_root)

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
	var hq_spawns: Array = []
	for _index in range(hqs.size()): hq_spawns.append([])
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
	for value in objects:
		var row := value as Dictionary
		var role := int(row.get("role", 0))
		if role == 6:
			_build_vehicle(row, objective_shared_root, hq_vehicle_team_roots,
				objective_vehicle_team_roots, emplacements_root, map_root, captures,
				hqs, hq_vehicle_links)
		elif role == 7:
			var resupply := _scene("resupply", str(row.get("label", "Resupply")))
			resupply.transform = _raw_transform(row)
			resupply.set_meta(PROVENANCE_META, _source(row))
			attachments_root.add_child(resupply)
			resupply.owner = map_root
			VehicleSkin.sync_resupply(resupply, map_root)
		elif role == 8:
			if mode != "rush":
				_add_plain(row, "mcom", attachments_root, map_root)
		elif role == 9:
			_add_plain(row, "bomb", attachments_root, map_root)
		elif role == 10:
			# The retail gem_specialcombatarea has no Portal SDK class. Preserve
			# its exact authored transform and source identity without inventing
			# AreaTrigger behavior that the shipped record does not declare.
			var special := Node3D.new()
			special.name = str(row.get("label", "Special Combat Area"))
			special.transform = _raw_transform(row)
			special.set_meta(PROVENANCE_META, _source(row))
			special.set_meta("bf6_unmapped_role", "gem_specialcombatarea")
			attachments_root.add_child(special)
			special.owner = map_root
		elif role == 101:
			var aa_point := _vec3(row.get("centre", []))
			var nearest_hq_index := _nearest_index(hqs, aa_point) if not hqs.is_empty() else -1
			var aa_team := _hq_faction_for_point(hqs, aa_point)
			var aa := _scene("automatic_aa", _automatic_aa_name(row, aa_team))
			aa.transform = _raw_transform(row)
			aa.set_meta(PROVENANCE_META, _source(row))
			emplacements_root.add_child(aa)
			aa.owner = map_root
			if aa_team > 0:
				aa.set("OwnerTeam", aa_team)
				aa.set_meta("bf6_owner_team", aa_team)
			if nearest_hq_index >= 0:
				var nearest: Node = hqs[nearest_hq_index]
				if nearest.get("HQArea") != null:
					aa.set("ProtectionAreaVolume", nearest.get("HQArea"))
					aa.set_meta("bf6_protection_hq", str(nearest.name))
		if role in [6, 7, 8, 9, 10, 101]:
			progress_current += 1
			_report(progress, "Creating vehicles and attachments…", progress_current, progress_total)

	for hq_index in range(hqs.size()):
		_set_array(hqs[hq_index], "VehicleSpawners", hq_vehicle_links[hq_index])
		hqs[hq_index].set("VehicleSpawnersEnabled", not hq_vehicle_links[hq_index].is_empty())
	if mode == "rush":
		_build_rush_objectives(objects, captures_root, map_root, hqs)

	for value in objects:
		var row := value as Dictionary
		match int(row.get("role", 0)):
			2:
				if mode == "rush":
					_add_polygon(row, zones_root, map_root,
						Color(0.55, 0.75, 0.95, 0.35))
			3:
				if not claimed_zone_sources.has(_row_key(row)):
					_add_polygon(row, zones_root, map_root, Color(0.55, 0.75, 0.95, 0.35))
			4:
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
				if not (level == "mp_eastwood" and mode == "conquest"):
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

	if mode == "breakthrough" and not captures.is_empty():
		_build_breakthrough_sectors(captures, captures_root, map_root)
	elif not captures.is_empty():
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
	_report(progress, "Game mode ready", progress_total, progress_total)

	var counts := document.get("counts", {}) as Dictionary
	return "Built %s %s: %d game-data objects (%d captures, %d spawns, %d vehicles)" % [
		level, _pretty(mode), int(counts.get("objects", 0)), captures.size(),
		int(counts.get("spawns", 0)), int(counts.get("vehicles", 0))]


static func _build_rush_objectives(objects: Array, objectives_root: Node,
		owner: Node, hqs: Array) -> void:
	var rows: Array = []
	for value in objects:
		if int((value as Dictionary).get("role", 0)) == 8:
			rows.append(value)
	if rows.is_empty():
		return
	var attack_origin := Vector3.ZERO
	if not hqs.is_empty():
		var first_hq := hqs[0] as Node3D
		var first_root := int(first_hq.get_meta("bf6_root_order", 2147483647))
		for value in hqs:
			var hq := value as Node3D
			var root_order := int(hq.get_meta("bf6_root_order", 2147483647))
			if root_order < first_root:
				first_root = root_order
				first_hq = hq
		attack_origin = first_hq.position
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_distance := attack_origin.distance_squared_to(_vec3(a.get("centre", [])))
		var b_distance := attack_origin.distance_squared_to(_vec3(b.get("centre", [])))
		if not is_equal_approx(a_distance, b_distance):
			return a_distance < b_distance
		return _root_order(a) < _root_order(b))
	var sectors_root := _folder(objectives_root, "Sectors", owner)
	for objective_index in range(rows.size()):
		var sector_index := objective_index / 2
		var sector_name := "Sector%d" % (sector_index + 1)
		var sector := sectors_root.get_node_or_null(sector_name) as Node3D
		if sector == null:
			sector = _scene("sector", sector_name)
			sector.set("ObjId", 101 + sector_index)
			sector.set_meta("bf6_order_basis", "distance from earliest authored HQ")
			sectors_root.add_child(sector)
			sector.owner = owner
		var slot := objective_index % 2
		var row := rows[objective_index] as Dictionary
		var mcom := _scene("mcom", "MCOM-%s" % ("A" if slot == 0 else "B"))
		mcom.transform = _raw_transform(row)
		mcom.set("ObjId", 201 + objective_index)
		mcom.set_meta(PROVENANCE_META, _source(row))
		mcom.set_meta("bf6_rush_sector", sector_index + 1)
		mcom.set_meta("bf6_rush_slot", slot)
		sector.add_child(mcom)
		mcom.owner = owner
		var sector_mcoms: Array = []
		var existing = sector.get("MCOMs")
		if existing != null:
			for item in existing:
				if item != null:
					sector_mcoms.append(item)
		sector_mcoms.append(mcom)
		_set_array(sector, "MCOMs", sector_mcoms)


static func _build_breakthrough_sectors(captures: Dictionary,
		objectives_root: Node, owner: Node) -> void:
	var ordered_flags: Array = captures.keys()
	ordered_flags.sort()
	var sectors_root := _folder(objectives_root, "Sectors", owner)
	for objective_index in range(ordered_flags.size()):
		var sector_index := objective_index / 2
		var sector_name := "Sector%d" % (sector_index + 1)
		var sector := sectors_root.get_node_or_null(sector_name) as Node3D
		if sector == null:
			sector = _scene("sector", sector_name)
			sector.set("ObjId", 101 + sector_index)
			sectors_root.add_child(sector)
			sector.owner = owner
		var capture := captures[ordered_flags[objective_index]] as Node3D
		var slot := objective_index % 2
		_reparent_from_layout_space(capture, sector, owner)
		capture.name = "CapturePoint%s" % ("A" if slot == 0 else "B")
		capture.set("ObjId", 1100 + sector_index * 100 + slot)
		capture.set_meta("bf6_breakthrough_source_flag", ordered_flags[objective_index])
		var sector_captures: Array = []
		var existing = sector.get("CapturePoints")
		if existing != null:
			for item in existing:
				if item != null:
					sector_captures.append(item)
		sector_captures.append(capture)
		_set_array(sector, "CapturePoints", sector_captures)


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
			if int(row.get("role", 0)) != 3 or used.has(_row_key(row)):
				continue
			if not _polygon_contains_xz(row.get("world_points", []) as Array, hq.position):
				continue
			var area_m2 := float(row.get("area_m2", INF))
			if area_m2 < best_area:
				best = row
				best_area = area_m2
		if best.is_empty():
			continue
		var area := _polygon(best, "HQArea_Team%d" % (hq_index + 1),
			Color(0.0, 0.53, 0.99, 0.42) if hq_index == 0 else Color(0.95, 0.23, 0.0, 0.42))
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
	# Conquest authors base areas and its combat boundaries as the same
	# VolumeVectorShapeData type.  Once the smallest containing polygon has been
	# bound to each HQ, the largest remaining polygon is the surrounding flight
	# boundary and the next largest is the playable combat volume.  Infantry-only
	# maps author only one remaining polygon and therefore have no separate
	# surrounding warning boundary.
	var rows: Array = []
	for value in objects:
		var row := value as Dictionary
		if int(row.get("role", 0)) == 3 and not used.has(_row_key(row)):
			rows.append(row)
	if rows.is_empty():
		return
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("area_m2", 0.0)) > float(b.get("area_m2", 0.0)))
	var surrounding_row := rows[0] as Dictionary if rows.size() > 1 else {}
	var combat_row := rows[1] as Dictionary if rows.size() > 1 else rows[0] as Dictionary
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
		hq_team_roots: Array, objective_team_roots: Array,
		emplacements_root: Node, owner: Node, captures: Dictionary, hqs: Array,
		hq_vehicle_links: Array) -> void:
	var raw := row.get("raw", {}) as Dictionary
	var selector := int(raw.get("gem_selector", row.get("gem_value", -1)))
	var is_stationary := bool(row.get("stationary", false))
	var point := _vec3(row.get("centre", []))
	var nearest_flag := _nearest_capture(captures, point) if not captures.is_empty() else -1
	var capture_distance := point.distance_squared_to((captures[nearest_flag] as Node3D).position) \
		if nearest_flag >= 0 else INF
	var nearest_hq := _nearest_index(hqs, point) if not hqs.is_empty() else -1
	var hq_distance := point.distance_squared_to((hqs[nearest_hq] as Node3D).position) \
		if nearest_hq >= 0 else INF
	var belongs_to_hq := not is_stationary and nearest_hq >= 0 and hq_distance < capture_distance

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
		var unknown := _create_vehicle(row, objective_shared_root, owner, selector, -1,
			"UnassignedSelector%d" % selector, false, false)
		if nearest_flag >= 0:
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
		vehicle.set_meta("bf6_source_vehicle_record", true)
		return

	for index in range(vehicle_types.size()):
		var vehicle_type := int(vehicle_types[index])
		var vehicle_team := index + 1 if vehicle_types.size() > 1 else 0
		var vehicle_parent: Node = objective_team_roots[index] \
			if vehicle_team > 0 else objective_shared_root
		var vehicle := _create_vehicle(row, vehicle_parent, owner, selector, vehicle_type,
			VEHICLE_NAMES[vehicle_type], false, true)
		vehicle.set_meta("bf6_vehicle_class", vehicle_class_name)
		vehicle.set_meta("bf6_vehicle_type_status",
			"installed activity class + faction picker -> SDK VehicleType")
		if nearest_flag >= 0:
			vehicle.name = _objective_vehicle_name(nearest_flag, vehicle_team,
				VEHICLE_NAMES[vehicle_type], row)
			if vehicle_team > 0:
				vehicle.set("SpawnIfMatchingTeam", true)
				vehicle.set("MatchingTeam", vehicle_team)
			vehicle.set_meta("bf6_runtime_association", "CapturePoint%s / %s" % [
				String.chr(65 + nearest_flag),
				"Team%d" % vehicle_team if vehicle_team > 0 else "Shared"])
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


static func _scene(kind: String, node_name: String) -> Node3D:
	var packed := load(SCENES[kind]) as PackedScene
	var node := packed.instantiate() as Node3D
	node.name = node_name
	return node


static func _folder(parent: Node, node_name: String, owner: Node) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	parent.add_child(node)
	node.owner = owner
	return node


static func _raw_transform(row: Dictionary) -> Transform3D:
	var raw := row.get("raw", {}) as Dictionary
	var t: Array = raw.get("transform", [])
	if t.size() != 12:
		return Transform3D(Basis.IDENTITY, _vec3(row.get("centre", [])))
	return Transform3D(Basis(_vec3(t.slice(0, 3)), _vec3(t.slice(3, 6)), _vec3(t.slice(6, 9))), _vec3(t.slice(9, 12)))


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
