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
# Retail gameplay layers store a spawn-category selector, not the Portal SDK's
# concrete VehicleType. Paired entries are the shipped Team 1 / Team 2 choices.
const VEHICLE_CATEGORY_TYPES := {
	0: [0, 1], # Tank
	1: [17, 3], # IFV
	2: [4, 2], # Mobile AA
	3: [12, 20], # APC
	4: [15, 18], # Fighter plane
	5: [16, 14], # Attack plane
	6: [8, 6], # Attack helicopter
	7: [5, 19], # Transport helicopter
	8: [22, 23], # Dirt bike
	9: [10], # Quad bike
	10: [11], # Golf cart
	11: [21], # RHIB
	12: [7, 24], # Scout helicopter
	13: [13, 9], # Light transport
	14: [26, 27], # Patrol boat
	15: [30, 31], # Multirole plane
	16: [28, 29], # Naval fighter plane
	# Carrier Strike also authors carrier launch pads. Portal has no launch
	# animation type, so these retain the pad transform with its aircraft type.
	21: [28, 29],
	22: [30],
	23: [31],
}
# The published v1.2.0 Atoll manifest carries the first recovered lettering
# table. Retail review corrected those labels without changing any transforms.
const ATOLL_CONQUEST_FLAG_REMAP := {
	0: 3, # A -> D
	1: 4, # B -> E
	2: 0, # C -> A
	3: 2, # D -> C
	4: 5, # E -> F
	5: 1, # F -> B
	6: 6, # G -> G
}


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
	var zones_root := _folder(root, "Zones", map_root)
	var spawns_root := _folder(root, "Spawns", map_root)
	var vehicles_root := _folder(root, "Vehicles", map_root)
	var vehicle_team_roots := [
		_folder(vehicles_root, "Team1", map_root),
		_folder(vehicles_root, "Team2", map_root),
	]
	var attachments_root := _folder(root, "Attachments", map_root)
	var objects: Array = document.get("objects", [])
	var progress_total := objects.size() + 2
	var progress_current := 0
	_report(progress, "Preparing %s hierarchy…" % _pretty(mode), progress_current, progress_total)
	var captures := {}
	var capture_spawns := {}
	var hqs: Array = []
	if level == "mp_capstone" and mode == "conquest":
		_build_capstone_out_of_bounds(objects, zones_root, map_root)

	for value in objects:
		var row := value as Dictionary
		if int(row.get("role", 0)) != 2:
			continue
		var flag := _normalized_flag(level, mode, row)
		if flag < 0:
			continue
		var capture := _scene("capture", "CapturePoint%s" % String.chr(65 + flag))
		capture.position = _vec3(row.get("centre", []))
		capture.set("ObjId", 200 + flag)
		capture.set_meta(PROVENANCE_META, _source(row))
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
		var hq := _scene("hq", "TEAM_%d_HQ" % (hqs.size() + 1))
		hq.transform = _raw_transform(row)
		var hq_team := hqs.size() + 1
		hq.set("Team", hq_team)
		hq.set("AltTeam", 2 if hq_team == 1 else 1)
		hq.set("ObjId", hq_team)
		hq.set_meta(PROVENANCE_META, _source(row))
		root.add_child(hq)
		hq.owner = map_root
		hqs.append(hq)
		progress_current += 1
		_report(progress, "Creating headquarters…", progress_current, progress_total)
	var claimed_zone_sources := {}
	if mode == "conquest" and _count_role(objects, 3) > hqs.size():
		claimed_zone_sources = _assign_hq_areas(objects, hqs, map_root)
	if level == "mp_atoll" and mode == "conquest":
		_build_combat_area_from_zones(objects, claimed_zone_sources, zones_root,
			map_root, "Zone 2")
	elif level == "mp_capstone" and mode == "conquest":
		_build_combat_area_from_zones(objects, claimed_zone_sources, zones_root,
			map_root, "Zone 4", "Zone 2")

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
		var point := spawn.global_position
		var nearest_flag := _nearest_capture(captures, point) if not captures.is_empty() else -1
		var capture_distance := point.distance_squared_to((captures[nearest_flag] as Node3D).global_position) \
			if nearest_flag >= 0 else INF
		var hq_index := _nearest_index(hqs, point) if not hqs.is_empty() else -1
		var hq_distance := point.distance_squared_to((hqs[hq_index] as Node3D).global_position) \
			if hq_index >= 0 else INF
		if captures_own_loose_spawns and nearest_flag >= 0 and capture_distance <= hq_distance:
			var capture := captures[nearest_flag] as Node3D
			spawn.reparent(capture, true)
			var key := "Flag_%s" % String.chr(65 + nearest_flag)
			var index := int(spawn_counts.get(key, 0)) + 1
			spawn_counts[key] = index
			spawn.name = "Spawn_%s_%02d" % [key, index]
			spawn.set_meta("bf6_capture_flag", nearest_flag)
			_append_spawn_for_team(capture_spawns, nearest_flag, spawn,
				int(spawn.get_meta("bf6_spawn_team", 0)))
		elif hq_index >= 0:
			spawn.reparent(hqs[hq_index], true)
			spawn.name = "Spawn_HQ_%d_%02d" % [hq_index + 1, hq_spawns[hq_index].size() + 1]
			hq_spawns[hq_index].append(spawn)
	for flag in captures:
		_set_array(captures[flag], "InfantrySpawnPoints_Team1", capture_spawns[flag][1])
		_set_array(captures[flag], "InfantrySpawnPoints_Team2", capture_spawns[flag][2])
	for hq_index in range(hqs.size()):
		_set_array(hqs[hq_index], "InfantrySpawns", hq_spawns[hq_index])

	var objective_pair_used := {}
	var hq_vehicle_links: Array = []
	for _index in range(hqs.size()): hq_vehicle_links.append([])
	for value in objects:
		var row := value as Dictionary
		var role := int(row.get("role", 0))
		if role == 6:
			_build_vehicle(row, vehicles_root, vehicle_team_roots, map_root, captures, hqs,
				objective_pair_used, hq_vehicle_links)
		elif role == 7:
			var resupply := _scene("resupply", str(row.get("label", "Resupply")))
			resupply.transform = _raw_transform(row)
			resupply.set_meta(PROVENANCE_META, _source(row))
			attachments_root.add_child(resupply)
			resupply.owner = map_root
			VehicleSkin.sync_resupply(resupply, map_root)
		elif role == 8:
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
			var aa := _add_plain(row, "automatic_aa", attachments_root, map_root)
			if not hqs.is_empty():
				var nearest: Node = hqs[_nearest_index(hqs, aa.position)]
				if nearest.get("HQArea") != null:
					aa.set("ProtectionAreaVolume", nearest.get("HQArea"))
		if role in [6, 7, 8, 9, 10, 101]:
			progress_current += 1
			_report(progress, "Creating vehicles and attachments…", progress_current, progress_total)

	for hq_index in range(hqs.size()):
		_set_array(hqs[hq_index], "VehicleSpawners", hq_vehicle_links[hq_index])
		hqs[hq_index].set("VehicleSpawnersEnabled", not hq_vehicle_links[hq_index].is_empty())

	for value in objects:
		var row := value as Dictionary
		match int(row.get("role", 0)):
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

	if not captures.is_empty():
		var sector := _scene("sector", "Sector")
		var ordered: Array = []
		for flag in captures.keys(): ordered.append(captures[flag])
		_set_array(sector, "CapturePoints", ordered)
		if not hqs.is_empty(): _set_array(sector, "HQs", hqs)
		root.add_child(sector)
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


static func _report(progress: Callable, message: String, current: int, total: int) -> void:
	if progress.is_valid():
		progress.call(message, current, total)


static func _normalized_flag(level: String, mode: String, row: Dictionary) -> int:
	var flag := int(row.get("flag", -1))
	if level == "mp_atoll" and mode == "conquest":
		return int(ATOLL_CONQUEST_FLAG_REMAP.get(flag, flag))
	if level != "mp_capstone" or mode != "conquest":
		return flag
	var raw := row.get("raw", {}) as Dictionary
	if str(raw.get("instance_guid", "")) == "79cbf770-5961-492c-80ae-ce142f99683f":
		return -1
	# The small cliff exclusion was promoted to slot D by the generic polygon
	# classifier. Remove that false slot and restore the shipped A-F sequence.
	if flag == 3:
		return -1
	if flag == 4:
		return 3
	if flag == 6:
		return 4
	return flag


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


static func _build_combat_area_from_zones(objects: Array, used: Dictionary,
		parent: Node, owner: Node, combat_label: String,
		surrounding_label := "") -> void:
	var combat_row := _zone_by_label(objects, used, combat_label)
	if combat_row.is_empty():
		return
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
	if surrounding_label == "":
		return
	var surrounding_row := _zone_by_label(objects, used, surrounding_label)
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


static func _build_vehicle(row: Dictionary, parent: Node, team_roots: Array, owner: Node,
		captures: Dictionary, hqs: Array, pair_used: Dictionary,
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
		var valid_stationary := selector >= 0 and selector < 3
		var stationary_name: String = ["BGM71TOW", "GDF009", "M2MG"][selector] \
			if valid_stationary else "Unassigned"
		var stationary := _create_vehicle(row, parent, owner, selector, selector,
			stationary_name, true, valid_stationary)
		stationary.set_meta("bf6_source_vehicle_record", true)
		return

	var vehicle_types: Array = VEHICLE_CATEGORY_TYPES.get(selector, [])
	if vehicle_types.is_empty():
		var unknown := _create_vehicle(row, parent, owner, selector, -1,
			"UnassignedCategory%d" % selector, false, false)
		unknown.set_meta("bf6_source_vehicle_record", true)
		return

	if belongs_to_hq:
		var team_index := mini(nearest_hq, 1)
		if selector == 23:
			team_index = 1
		var type_index := mini(team_index, vehicle_types.size() - 1)
		var vehicle_type := int(vehicle_types[type_index])
		var vehicle := _create_vehicle(row, team_roots[team_index], owner, selector,
			vehicle_type, VEHICLE_NAMES[vehicle_type], false, true)
		vehicle.set("P_AutoSpawnEnabled", true)
		hq_vehicle_links[nearest_hq].append(vehicle)
		vehicle.set_meta("bf6_runtime_association", "HQ%d / Team%d" % [nearest_hq + 1, team_index + 1])
		vehicle.set_meta("bf6_source_vehicle_record", true)
		return

	if vehicle_types.size() == 2 and nearest_flag >= 0:
		var has_template_ids := not pair_used.has(nearest_flag)
		for team_index in range(2):
			var vehicle_type := int(vehicle_types[team_index])
			var vehicle := _create_vehicle(row, parent, owner, selector, vehicle_type,
				VEHICLE_NAMES[vehicle_type], false, true)
			vehicle.set("SpawnIfMatchingTeam", true)
			vehicle.set("MatchingTeam", team_index + 1)
			if has_template_ids:
				vehicle.set("ObjId", 600 + nearest_flag * 10 + team_index)
			vehicle.set_meta("bf6_runtime_association", "CapturePoint%s / Team%d" % [
				String.chr(65 + nearest_flag), team_index + 1])
			if team_index == 0:
				vehicle.set_meta("bf6_source_vehicle_record", true)
		if has_template_ids:
			pair_used[nearest_flag] = true
		return

	var vehicle_type := int(vehicle_types[0])
	var shared := _create_vehicle(row, parent, owner, selector, vehicle_type,
		VEHICLE_NAMES[vehicle_type], false, true)
	shared.set_meta("bf6_source_vehicle_record", true)


static func _create_vehicle(row: Dictionary, parent: Node, owner: Node, selector: int,
		vehicle_type: int, type_name: String, is_stationary: bool, resolved: bool) -> Node3D:
	var raw := row.get("raw", {}) as Dictionary
	var vehicle := _scene("stationary" if is_stationary else "vehicle",
		"%s_%s" % [str(row.get("label", "Vehicle")), type_name])
	vehicle.transform = _raw_transform(row)
	if resolved:
		vehicle.set("StationaryEmplacementType" if is_stationary else "VehicleType", vehicle_type)
	vehicle.set_meta(PROVENANCE_META, _source(row))
	vehicle.set_meta("bf6_source_instance_guid", str(raw.get("instance_guid", "")))
	vehicle.set_meta("bf6_retail_selector", selector)
	vehicle.set_meta("bf6_vehicle_type_status", "retail category resolved through faction picker" \
		if resolved else "retail category is unresolved; SDK default retained")
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
