@tool
extends RefCounted

const VehicleSkin = preload("res://addons/bf6_gamemode_setup/vehicle_skin.gd")
const ClassifiedBuilder = preload("res://addons/bf6_gamemode_setup/classified_builder.gd")

const BUILD_META := "bf6_gamemode_setup"
const PROVENANCE_META := "bf6_source"
# MP_Isolated's extracted gameplay transforms are already SDK-world transforms.
# The community scene represents the same space with offset child folders whose
# transforms cancel the Prefab offset; applying either offset alone is wrong.
const GAME_TO_SDK_ORIGIN := Vector3.ZERO

const SCENE_PATHS := {
	"capture": "res://objects/gameplay/conquest/CapturePoint.tscn",
	"hq": "res://objects/gameplay/common/HQ_PlayerSpawner.tscn",
	"vehicle": "res://objects/gameplay/common/VehicleSpawner.tscn",
	"spawn": "res://objects/entities/SpawnPoint.tscn",
	"combat": "res://objects/gameplay/common/CombatArea.tscn",
	"sector": "res://objects/gameplay/common/Sector.tscn",
	"volume": "res://addons/bf_portal/portal_tools/types/PolygonVolume/PolygonVolume.tscn",
	"stationary": "res://objects/gameplay/common/StationaryEmplacementSpawner.tscn",
	"resupply": "res://objects/gameplay/common/VehicleResupplyStation.tscn",
	"automatic_aa": "res://objects/gameplay/vehicles/VEH_Stationary_AutomaticAA.tscn",
}

# Letters and ObjIds are the community template's public Blockly contract.
# Root orders and all spatial/type data come from installed MP_Isolated.
const CAPTURE_ROOTS := {3: "A", 4: "B", 69: "C", 5: "D", 6: "E", 7: "F", 70: "G", 45: "H", 44: "I"}
const CAPTURE_IDS := {"A": 200, "B": 201, "C": 202, "D": 203, "E": 204, "F": 205, "G": 206, "H": 207, "I": 208}
# The Custom Conquest Blockly workspace addresses one faction-specific vehicle
# pair per objective as 600/601 through 680/681. Additional retail vehicle
# slots and shared vehicles intentionally retain the SDK's default ObjId.
const OBJECTIVE_VEHICLE_ID_BASE := 600
const VEHICLE_NAMES := [
	"Abrams", "Leopard", "Cheetah", "CV90", "Gepard", "UH60",
	"Eurocopter", "AH6M", "AH64", "Vector", "Quadbike", "GolfCart",
	"Marauder", "Flyer60", "JAS39", "F22", "F16", "M2Bradley",
	"SU57", "UH60_Pax", "Marauder_Pax", "RHIB", "DirtBike",
	"DirtBike_Pax", "AH6M_Pax", "Couch", "RCB_90_Patrol_Boat",
	"RCB_90_Patrol_Boat_Pax", "F_74A_Seacat", "F_74A_Seacat_Pax",
	"FA_81F_Super_Spectre", "FA_81F_Super_Spectre_Pax",
]
# MP_Isolated stores a retail spawn-group selector, not the Portal SDK's
# concrete VehicleType enum. Each pair below comes from the retail category
# prefab's faction-picker array, joined to ModBuilder_Enum_VehicleList.
const VEHICLE_GROUP_TYPES := {
	0: [13, 9], # LightTransport: Flyer60 / Vector
	1: [17, 3], # IFV: M2Bradley / CV90
	2: [0, 1], # Tank: Abrams / Leopard
	3: [2, 4], # MobileAA: Cheetah / Gepard
	4: [16, 14], # AttackPlane: F16 / JAS39
	5: [15, 18], # FighterPlane: F22 / SU57
	6: [8, 6], # AttackHelicopter: AH64 / Eurocopter
	7: [5, 19], # TransportHelicopter: UH60 / UH60_Pax
	8: [10], # Quadbike is shared
	9: [12, 20], # APC: Marauder / Marauder_Pax
	10: [11], # GolfCart is shared
	11: [21], # RHIB is shared
	12: [7, 24], # ScoutHelicopter: AH6M / AH6M_Pax
	13: [22, 23], # DirtBike / DirtBike_Pax
	14: [26, 27], # PatrolBoat / PatrolBoat_Pax
	15: [30, 31], # Super Spectre / Super Spectre Pax
	16: [28, 29], # Seacat / Seacat Pax
	17: [16], 18: [15], 19: [14], 20: [18], 21: [28], 22: [30], 23: [31],
}
const STATIONARY_SELECTOR_TYPES := {0: 2, 1: 0, 2: 1}
const COLORS := {
	"capture": Color(1.0, 0.55, 0.1, 0.42),
	"combat": Color(0.2, 0.75, 0.3, 0.3),
	"air": Color(0.2, 0.55, 1.0, 0.25),
	"hq": Color(0.3, 0.65, 1.0, 0.35),
}


static func validate(root: Node, paths: Dictionary) -> String:
	if root == null:
		return "Open the MP_Isolated map scene first"
	if not FileAccess.file_exists(str(paths.get("manifest", ""))):
		return "The installed-game Conquest manifest is missing"
	for path in SCENE_PATHS.values():
		if not ResourceLoader.exists(path):
			return "This project is missing the Battlefield Portal SDK 1.4.3 resource: %s" % path
	return ""


static func build(root: Node, layout_id: String, paths: Dictionary, replace_existing := false,
		progress: Callable = Callable()) -> String:
	var problem := validate(root, paths)
	if problem != "":
		return problem
	var document := _read_json(str(paths["manifest"]))
	if int(document.get("schema", 0)) == 2:
		return ClassifiedBuilder.build(root, layout_id, document, paths, replace_existing, progress)
	if layout_id != "mp_isolated/conquest":
		return "This plugin version does not support %s" % layout_id
	var existing := find_build(root, layout_id)
	if existing != null:
		if not replace_existing:
			(existing as Node3D).visible = true
			return "Tsuru Reef Conquest shown; the existing editable layout was preserved"
		root.remove_child(existing)
		existing.free()
	elif root.get_node_or_null("Conquest") != null:
		return "A Conquest node already exists and was not created by this plugin"
	_remove_sdk_starter_gameplay(root)

	if document.is_empty():
		return "The installed-game Conquest manifest could not be read"
	var entities: Array = document.get("entities", [])
	if entities.size() != 271:
		return "The installed-game manifest failed its 271-entity census"
	_report(progress, "Preparing Conquest hierarchy…", 0, 10)

	var conquest := Node3D.new()
	conquest.name = "Conquest"
	conquest.position = GAME_TO_SDK_ORIGIN
	conquest.set_meta(BUILD_META, layout_id)
	conquest.set_meta(PROVENANCE_META, "installed BF6 MP_Isolated/conquest; SDK 1.4.3 output contract")
	root.add_child(conquest)
	conquest.owner = root

	var play_area := _folder(conquest, "Play Area", root)
	var objective_root := _folder(conquest, "Obectives", root) # Template spelling retained.
	var vehicle_root := _folder(conquest, "Vehicles", root)
	var team_vehicle_folders := {
		"HQ1": _folder(vehicle_root, "Team1", root),
		"HQ2": _folder(vehicle_root, "Team2", root),
	}
	var objective_vehicles := _folder(vehicle_root, "Objectives", root)
	for letter in CAPTURE_IDS:
		team_vehicle_folders[letter] = _folder(objective_vehicles, letter, root)
	var attachments := _folder(conquest, "Extras", root)

	var captures := {}
	for row in _gems(entities, "gem_capturepoint"):
		var letter: String = CAPTURE_ROOTS.get(int(row.get("root_order", -1)), "")
		if letter == "":
			continue
		var capture := _script_node("capture", "CapturePoint%s" % letter)
		# CapturePoint direction has no gameplay meaning. Keep these parents
		# translation-only, as the SDK/community hierarchy does, so child
		# PolygonVolumes retain their authored map-space X/Z without relying on
		# a counter-rotation that Portal's volume tooling may normalize.
		capture.transform = Transform3D(Basis.IDENTITY, _origin(row))
		capture.set("ObjId", CAPTURE_IDS[letter])
		capture.set_meta(PROVENANCE_META, _row_source(row))
		objective_root.add_child(capture)
		capture.owner = root
		captures[letter] = capture
	_report(progress, "Created capture points…", 1, 10)

	var hqs := {}
	for row in _gems(entities, "gem_hq"):
		var team := int(row.get("root_order", 0))
		var key := "HQ%d" % team
		var hq := _script_node("hq", "TEAM_%d_HQ" % team)
		hq.transform = _transform(row)
		hq.set("Team", team)
		hq.set("AltTeam", 2 if team == 1 else 1)
		hq.set("ObjId", team)
		hq.set_meta(PROVENANCE_META, _row_source(row))
		conquest.add_child(hq)
		hq.owner = root
		_folder(hq, "InfantrySpawns", root)
		hqs[key] = hq
	_report(progress, "Created headquarters…", 2, 10)

	var finite_volume_rows: Array = []
	var infinite_rows: Array = []
	for value in entities:
		var row := value as Dictionary
		if str(row.get("type", "")) != "VolumeVectorShapeData" or not str(row.get("layer", "")).ends_with("/conquest0"):
			continue
		if float(row.get("height", 0.0)) > 0.0:
			finite_volume_rows.append(row)
		else:
			infinite_rows.append(row)
	# The layer has 18 finite polygons: nine gameplay capture areas and nine
	# 70 m outline-helper boxes. Match each flag to the polygon whose height
	# equals that flag's own bound physics shape, consuming each row once.
	var unused_capture_rows := finite_volume_rows.duplicate()
	for letter in captures:
		var capture := captures[letter] as Node3D
		var expected_height := _capture_shape_height(_capture_row_for_letter(entities, letter))
		var best_index := -1
		var best_distance := INF
		for index in range(unused_capture_rows.size()):
			var candidate := unused_capture_rows[index] as Dictionary
			if absf(float(candidate.get("height", 0.0)) - expected_height) > 0.01:
				continue
			var distance := capture.position.distance_squared_to(_points_center(candidate))
			if distance < best_distance:
				best_distance = distance
				best_index = index
		if best_index < 0:
			continue
		var row := unused_capture_rows[best_index] as Dictionary
		unused_capture_rows.remove_at(best_index)
		var volume := _make_volume(row, "Area-%s" % letter, "capture")
		capture.add_child(volume)
		volume.owner = root
		_rebase_volume_under(volume, row, capture)
		capture.set("CaptureArea", volume)
	_report(progress, "Created capture volumes…", 3, 10)

	var combat_rows: Array = []
	for row in infinite_rows:
		var center := _points_center(row)
		var near_hq := _nearest_key(hqs, center)
		if center.distance_to((hqs[near_hq] as Node3D).position) < 450.0 and center.y < 350.0:
			var area := _make_volume(row, "HQ_Area", "hq")
			hqs[near_hq].add_child(area)
			area.owner = root
			_rebase_volume_under(area, row, hqs[near_hq] as Node3D)
			hqs[near_hq].set("HQArea", area)
		else:
			combat_rows.append(row)
	var combat := _script_node("combat", "CombatArea")
	play_area.add_child(combat)
	combat.owner = root
	for row in combat_rows:
		var is_air := _points_center(row).y > 350.0
		var volume := _make_volume(row, "AircraftCombatVolume" if is_air else "InfantryCombatVolume", "air" if is_air else "combat")
		combat.add_child(volume)
		volume.owner = root
		combat.set("SurroundingVolume" if is_air else "CombatVolume", volume)
	_report(progress, "Created combat and aircraft volumes…", 4, 10)

	var spawn_links := {}
	for letter in captures:
		spawn_links[letter] = []
		var folder := _folder(captures[letter], "Spawns%s" % letter, root)
		_folder(folder, "Shared", root)
	spawn_links["HQ1"] = []
	spawn_links["HQ2"] = []
	for value in entities:
		var row := value as Dictionary
		if str(row.get("type", "")) != "AlternateSpawnEntityData":
			continue
		var owner_key := _nearest_anchor(captures, hqs, _origin(row))
		var parent: Node
		if owner_key.begins_with("HQ"):
			parent = (hqs[owner_key] as Node).get_node("InfantrySpawns")
		else:
			parent = (captures[owner_key] as Node).get_node("Spawns%s/Shared" % owner_key)
		var spawn := _script_node("spawn", "Spawn_%s_%03d" % [owner_key, spawn_links[owner_key].size() + 1])
		spawn.transform = _transform(row)
		spawn.set_meta(PROVENANCE_META, _row_source(row))
		parent.add_child(spawn)
		spawn.owner = root
		var anchor: Node3D = hqs[owner_key] if owner_key.begins_with("HQ") else captures[owner_key]
		spawn.transform = (anchor as Node3D).transform.affine_inverse() * _transform(row)
		spawn_links[owner_key].append(spawn)
		if spawn_links[owner_key].size() % 12 == 0:
			_report(progress, "Creating infantry spawns…", 5, 10)
	for letter in captures:
		# Installed-game spawns are neutral: both teams reference one physical set.
		_set_typed_array(captures[letter], "InfantrySpawnPoints_Team1", spawn_links[letter])
		_set_typed_array(captures[letter], "InfantrySpawnPoints_Team2", spawn_links[letter])
	for key in ["HQ1", "HQ2"]:
		_set_typed_array(hqs[key], "InfantrySpawns", spawn_links[key])

	var vehicle_links := {"HQ1": [], "HQ2": []}
	var objective_vehicle_pair_assigned := {}
	for row in _gems(entities, "gem_vehiclespawner"):
		_report(progress, "Creating vehicle spawners and previews…", 6, 10)
		var owner_key := _nearest_anchor(captures, hqs, _origin(row))
		var group_id := int(row.get("gem_selector", -1))
		var vehicle_types: Array = VEHICLE_GROUP_TYPES.get(group_id, [])
		if vehicle_types.is_empty():
			continue
		if owner_key.begins_with("HQ") and vehicle_types.size() > 1:
			var fixed_team := 1 if owner_key == "HQ1" else 2
			var vehicle := _make_vehicle_spawner(row, owner_key, int(vehicle_types[fixed_team - 1]),
				fixed_team, group_id, 0)
			(team_vehicle_folders[owner_key] as Node).add_child(vehicle)
			vehicle.owner = root
			_add_vehicle_skin(vehicle, root)
			vehicle_links[owner_key].append(vehicle)
		else:
			var template_pair_base := 0
			if not owner_key.begins_with("HQ") and vehicle_types.size() > 1 \
					and not objective_vehicle_pair_assigned.has(owner_key):
				template_pair_base = OBJECTIVE_VEHICLE_ID_BASE \
					+ (int(CAPTURE_IDS[owner_key]) - 200) * 10
				objective_vehicle_pair_assigned[owner_key] = true
			for index in range(vehicle_types.size()):
				var matching_team := index + 1 if vehicle_types.size() > 1 else 0
				var template_obj_id := template_pair_base + index if template_pair_base > 0 else 0
				var vehicle := _make_vehicle_spawner(row, owner_key, int(vehicle_types[index]),
					matching_team, group_id, template_obj_id)
				(team_vehicle_folders[owner_key] as Node).add_child(vehicle)
				vehicle.owner = root
				_add_vehicle_skin(vehicle, root)
				if owner_key.begins_with("HQ"):
					vehicle_links[owner_key].append(vehicle)
	for key in ["HQ1", "HQ2"]:
		_set_typed_array(hqs[key], "VehicleSpawners", vehicle_links[key])
		hqs[key].set("VehicleSpawnersEnabled", not vehicle_links[key].is_empty())

	var sector_rows := _gems(entities, "gem_sector")
	if not sector_rows.is_empty():
		var sector := _script_node("sector", "Sector")
		sector.transform = _transform(sector_rows[0])
		_set_typed_array(sector, "HQs", [hqs["HQ1"], hqs["HQ2"]])
		var ordered_captures: Array = []
		var ordered_letters: Array = CAPTURE_IDS.keys()
		ordered_letters.sort()
		for letter in ordered_letters:
			ordered_captures.append(captures[letter])
		_set_typed_array(sector, "CapturePoints", ordered_captures)
		play_area.add_child(sector)
		sector.owner = root
	_report(progress, "Linking objectives, HQs, and sectors…", 8, 10)
	_build_attachments(entities, attachments, root, hqs)
	_report(progress, "Finishing attachments…", 9, 10)
	_report(progress, "Game mode ready", 10, 10)

	return "Tsuru Reef Conquest built from 271 installed-game records: 2 HQs, 9 objectives, 155 spawns, 40 vehicle slots, exact volumes, and attachments"


static func _report(progress: Callable, message: String, current: int, total: int) -> void:
	if progress.is_valid():
		progress.call(message, current, total)


static func find_build(root: Node, layout_id: String) -> Node:
	if root == null:
		return null
	for child in root.get_children():
		if child.has_meta(BUILD_META) and str(child.get_meta(BUILD_META)) == layout_id:
			return child
	return null


static func hide_all(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is Node3D and child.has_meta(BUILD_META):
			(child as Node3D).visible = false


static func _remove_sdk_starter_gameplay(root: Node) -> void:
	# The stock map scene ships a tiny two-HQ/one-combat-area starter setup.
	# Keeping it beside a full mode exports duplicate gameplay entities. The
	# stock DeployCam, terrain, water and static map nodes are intentionally kept.
	for node_name in ["TEAM_1_HQ", "TEAM_2_HQ", "CombatArea"]:
		var node := root.get_node_or_null(node_name)
		if node == null:
			continue
		root.remove_child(node)
		node.free()


static func _build_attachments(entities: Array, parent: Node, owner: Node,
		hqs: Dictionary) -> void:
	var specs := {
		"gem_stationaryspawner": ["stationary", "StationaryEmplacement"],
		"gem_vehicleresupplystation": ["resupply", "VehicleResupply"],
		"gem_automaticaa": ["automatic_aa", "AutomaticAA"],
	}
	for blueprint in specs:
		var spec: Array = specs[blueprint]
		var folder := _folder(parent, str(spec[1]) + "s", owner)
		for row in _gems(entities, blueprint):
			var node := _script_node(str(spec[0]), "%s_Root%02d" % [spec[1], int(row.root_order)])
			node.transform = _transform(row)
			node.set_meta(PROVENANCE_META, _row_source(row))
			if blueprint == "gem_automaticaa":
				var hq_key := _nearest_key(hqs, _origin(row))
				var owner_team := 1 if hq_key == "HQ1" else 2
				node.name = "AutomaticAA_Team%d_Root%02d" % [owner_team,
					int(row.get("root_order", 0))]
				node.set("OwnerTeam", owner_team)
				var protection = hqs[hq_key].get("HQArea")
				node.set("ProtectionAreaVolume", protection)
				node.set_meta("bf6_protection_hq", hq_key)
				node.set_meta("bf6_owner_team", owner_team)
			if _has_property(node, "VehicleType") and int(row.get("gem_selector", -1)) >= 0:
				node.set("VehicleType", int(row.gem_selector))
			if blueprint == "gem_stationaryspawner":
				var retail_selector := int(row.get("gem_selector", -1))
				var stationary_type := int(STATIONARY_SELECTOR_TYPES.get(retail_selector, -1))
				if stationary_type >= 0:
					node.set("StationaryEmplacementType", stationary_type)
				node.set("P_AutoSpawnEnabled", true)
			folder.add_child(node)
			node.owner = owner
			if blueprint == "gem_stationaryspawner":
				VehicleSkin.sync_stationary(node, owner)
			elif blueprint == "gem_vehicleresupplystation":
				VehicleSkin.sync_resupply(node, owner)


static func _script_node(kind: String, node_name: String) -> Node3D:
	# Instantiate the SDK resource so its programmed editor representation and
	# packed internals remain intact. Only this instance root becomes authored.
	var packed := load(str(SCENE_PATHS[kind])) as PackedScene
	var node := packed.instantiate() as Node3D
	node.name = node_name
	return node


static func _vehicle_name(selector: int) -> String:
	if selector >= 0 and selector < VEHICLE_NAMES.size():
		return str(VEHICLE_NAMES[selector])
	return "UnknownVehicle"


static func _make_vehicle_spawner(row: Dictionary, owner_key: String, vehicle_type: int,
		matching_team: int, group_id: int, template_obj_id: int) -> Node3D:
	var suffix := "_Team%d" % matching_team if matching_team > 0 else ""
	var vehicle := _script_node("vehicle", "%s_%s_Root%02d%s" % [
		owner_key, _vehicle_name(vehicle_type), int(row.root_order), suffix])
	vehicle.transform = _transform(row)
	vehicle.set("VehicleType", vehicle_type)
	vehicle.set("P_DefaultRespawnTime", 45)
	if vehicle_type == -1:
		vehicle.set("P_AutoSpawnEnabled", true)
	if template_obj_id > 0:
		vehicle.set("ObjId", template_obj_id)
		vehicle.set_meta("bf6_template_obj_id", template_obj_id)
	if matching_team > 0:
		vehicle.set("SpawnIfMatchingTeam", true)
		vehicle.set("MatchingTeam", matching_team)
	vehicle.set_meta(PROVENANCE_META, _row_source(row))
	vehicle.set_meta("bf6_vehicle_group", group_id)
	vehicle.set_meta("bf6_vehicle_type_status", "retail category faction picker -> SDK VehicleType")
	vehicle.set_meta("bf6_runtime_association", "nearest authored HQ/objective")
	return vehicle


static func _add_vehicle_skin(vehicle: Node3D, owner: Node) -> void:
	VehicleSkin.sync_spawner(vehicle, owner)


static func _make_volume(row: Dictionary, node_name: String, color_key: String) -> Node3D:
	var node := _script_node("volume", node_name)
	var center := _points_center(row)
	node.position = center
	var source: Array = row.get("points", [])
	var points := PackedVector2Array()
	for index in range(0, source.size(), 3):
		points.append(Vector2(float(source[index]) - center.x, float(source[index + 2]) - center.z))
	node.set("points", points)
	node.set("height", float(row.get("height", 0.0)))
	node.set("color", COLORS[color_key])
	node.set_meta(PROVENANCE_META, _row_source(row))
	return node


static func _rebase_volume_under(volume: Node3D, row: Dictionary, parent: Node3D) -> void:
	# PolygonVolume deliberately strips pitch/roll from its own transform. Keep
	# its local basis identity and convert every world-space source vertex into
	# the owning gameplay node's local XZ plane.
	var inverse := parent.transform.affine_inverse()
	var center_local := inverse * _points_center(row)
	var source: Array = row.get("points", [])
	var points := PackedVector2Array()
	for index in range(0, source.size(), 3):
		var world := Vector3(float(source[index]), float(source[index + 1]), float(source[index + 2]))
		var local := inverse * world
		points.append(Vector2(local.x - center_local.x, local.z - center_local.z))
	volume.transform = Transform3D(Basis.IDENTITY, center_local)
	volume.set("points", points)


static func _folder(parent: Node, node_name: String, owner: Node) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	parent.add_child(node)
	node.owner = owner
	return node


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


static func _gems(entities: Array, blueprint: String) -> Array:
	var result: Array = []
	for value in entities:
		var row := value as Dictionary
		if str(row.get("gem_blueprint", "")) == blueprint:
			result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.root_order) < int(b.root_order))
	return result


static func _capture_row_for_letter(entities: Array, letter: String) -> Dictionary:
	for row in _gems(entities, "gem_capturepoint"):
		if str(CAPTURE_ROOTS.get(int(row.get("root_order", -1)), "")) == letter:
			return row
	return {}


static func _capture_shape_height(row: Dictionary) -> float:
	var physics := row.get("gem_shape_physics", {}) as Dictionary
	var vertices := physics.get("vertices", []) as Array
	var minimum := INF
	var maximum := -INF
	for index in range(1, vertices.size(), 3):
		var y := float(vertices[index])
		minimum = minf(minimum, y)
		maximum = maxf(maximum, y)
	return maximum - minimum if not vertices.is_empty() else 0.0


static func _transform(row: Dictionary) -> Transform3D:
	var t: Array = row.get("transform", [])
	# Frostbite LinearTransform serializes its right, up and forward axes in
	# sequence. Those are already the axis columns expected by Godot's Basis.
	return Transform3D(Basis(
		Vector3(float(t[0]), float(t[1]), float(t[2])),
		Vector3(float(t[3]), float(t[4]), float(t[5])),
		Vector3(float(t[6]), float(t[7]), float(t[8]))),
		Vector3(float(t[9]), float(t[10]), float(t[11])))


static func _origin(row: Dictionary) -> Vector3:
	var t: Array = row.get("transform", [])
	return Vector3(float(t[9]), float(t[10]), float(t[11]))


static func _points_center(row: Dictionary) -> Vector3:
	var values: Array = row.get("points", [])
	var center := Vector3.ZERO
	for index in range(0, values.size(), 3):
		center += Vector3(float(values[index]), float(values[index + 1]), float(values[index + 2]))
	return center / float(values.size() / 3)


static func _nearest_key(nodes: Dictionary, point: Vector3) -> String:
	var best := ""
	var distance := INF
	for key in nodes:
		var candidate := (nodes[key] as Node3D).position.distance_squared_to(point)
		if candidate < distance:
			distance = candidate
			best = str(key)
	return best


static func _nearest_anchor(captures: Dictionary, hqs: Dictionary, point: Vector3) -> String:
	var combined := captures.duplicate()
	combined.merge(hqs)
	return _nearest_key(combined, point)


static func _row_source(row: Dictionary) -> String:
	return "%s instance %s root %s" % [str(row.get("layer", "")), str(row.get("instance", "?")), str(row.get("root_order", "-"))]


static func _has_property(node: Object, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.name) == property_name:
			return true
	return false


static func _set_typed_array(node: Object, property_name: String, values: Array) -> void:
	# SDK exports use Array[SpecificClass]. Mutating a copy of that property
	# preserves its element type; assigning an untyped JSON-era Array does not.
	var target: Array = node.get(property_name)
	target.clear()
	for value in values:
		target.append(value)
	node.set(property_name, target)
