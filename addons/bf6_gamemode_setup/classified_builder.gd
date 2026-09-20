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
	"sector": "res://objects/gameplay/common/Sector.tscn",
	"resupply": "res://objects/gameplay/common/VehicleResupplyStation.tscn",
	"mcom": "res://objects/gameplay/rush/MCOM.tscn",
	"bomb": "res://objects/gameplay/obliteration/Bomb.tscn",
	"automatic_aa": "res://objects/gameplay/vehicles/VEH_Stationary_AutomaticAA.tscn",
}
const VEHICLE_GROUP_TYPES := {
	0: [12, 20], 1: [17, 3], 4: [15, 18], 5: [16, 14], 7: [5, 19],
	8: [22, 23], 9: [10], 11: [21], 12: [7, 24], 13: [13, 9], 14: [26, 27],
}
const VEHICLE_NAMES := [
	"Abrams", "Leopard", "Cheetah", "CV90", "Gepard", "UH60", "Eurocopter",
	"AH6M", "AH64", "Vector", "Quadbike", "GolfCart", "Marauder", "Flyer60",
	"JAS39", "F22", "F16", "M2Bradley", "SU57", "UH60_Pax", "Marauder_Pax",
	"RHIB", "DirtBike", "DirtBike_Pax", "AH6M_Pax", "Couch",
	"RCB_90_Patrol_Boat", "RCB_90_Patrol_Boat_Pax", "F_74A_Seacat",
	"F_74A_Seacat_Pax", "FA_81F_Super_Spectre", "FA_81F_Super_Spectre_Pax",
]


static func build(map_root: Node, layout_id: String, document: Dictionary,
		paths: Dictionary, replace_existing: bool) -> String:
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
	var attachments_root := _folder(root, "Attachments", map_root)
	var objects: Array = document.get("objects", [])
	var captures := {}
	var capture_spawns := {}
	var hqs: Array = []

	for value in objects:
		var row := value as Dictionary
		if int(row.get("role", 0)) != 2:
			continue
		var flag := int(row.get("flag", captures.size()))
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

	for value in objects:
		var row := value as Dictionary
		if int(row.get("role", 0)) != 100:
			continue
		var hq := _scene("hq", "TEAM_%d_HQ" % (hqs.size() + 1))
		hq.transform = _raw_transform(row)
		hq.set("ObjId", hqs.size() + 1)
		hq.set_meta(PROVENANCE_META, _source(row))
		root.add_child(hq)
		hq.owner = map_root
		hqs.append(hq)

	var loose_spawns: Array = []
	for value in objects:
		var row := value as Dictionary
		if int(row.get("role", 0)) != 1:
			continue
		var flag := int(row.get("flag", -1))
		var spawn := _scene("spawn", str(row.get("label", "Spawn")))
		spawn.transform = _raw_transform(row)
		spawn.set_meta(PROVENANCE_META, _source(row))
		var parent: Node = captures.get(flag, spawns_root)
		parent.add_child(spawn)
		spawn.owner = map_root
		if parent != spawns_root:
			spawn.transform = (parent as Node3D).transform.affine_inverse() * spawn.transform
			var team := int(row.get("team", 0))
			if team == 1 or team == 2:
				capture_spawns[flag][team].append(spawn)
			else:
				capture_spawns[flag][1].append(spawn)
				capture_spawns[flag][2].append(spawn)
		else:
			loose_spawns.append(spawn)
	for flag in captures:
		_set_array(captures[flag], "InfantrySpawnPoints_Team1", capture_spawns[flag][1])
		_set_array(captures[flag], "InfantrySpawnPoints_Team2", capture_spawns[flag][2])
	for hq_index in range(hqs.size()):
		var linked: Array = []
		for spawn in loose_spawns:
			if _nearest_index(hqs, (spawn as Node3D).position) == hq_index:
				linked.append(spawn)
		_set_array(hqs[hq_index], "InfantrySpawns", linked)

	var objective_pair_used := {}
	for value in objects:
		var row := value as Dictionary
		var role := int(row.get("role", 0))
		if role == 6:
			_build_vehicle(row, vehicles_root, map_root, captures, objective_pair_used)
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
		elif role == 101:
			var aa := _add_plain(row, "automatic_aa", attachments_root, map_root)
			if not hqs.is_empty():
				var nearest: Node = hqs[_nearest_index(hqs, aa.position)]
				if nearest.get("HQArea") != null:
					aa.set("ProtectionAreaVolume", nearest.get("HQArea"))

	for value in objects:
		var row := value as Dictionary
		match int(row.get("role", 0)):
			3:
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
		var carrier := CarrierPreview.new()
		carrier.name = "Aircraft Carriers (hide to disable preview)"
		carrier.source_path = carrier_path
		carrier.set_meta(PROVENANCE_META, "game-extracted carrier geometry for %s/%s" % [level, mode])
		root.add_child(carrier)
		carrier.owner = map_root
		carrier.rebuild()

	var counts := document.get("counts", {}) as Dictionary
	return "Built %s %s: %d game-data objects (%d captures, %d spawns, %d vehicles)" % [
		level, _pretty(mode), int(counts.get("objects", 0)), int(counts.get("captures", 0)),
		int(counts.get("spawns", 0)), int(counts.get("vehicles", 0))]


static func _build_vehicle(row: Dictionary, parent: Node, owner: Node, captures: Dictionary,
		pair_used: Dictionary) -> void:
	var raw := row.get("raw", {}) as Dictionary
	var group := int(raw.get("gem_selector", row.get("gem_value", -1)))
	var types: Array = VEHICLE_GROUP_TYPES.get(group, [])
	if types.is_empty():
		return
	var nearest_flag := _nearest_capture(captures, _vec3(row.get("centre", [])))
	var pair_base := 0
	if types.size() > 1 and nearest_flag >= 0 and not pair_used.has(nearest_flag):
		pair_base = 600 + nearest_flag * 10
		pair_used[nearest_flag] = true
	for index in range(types.size()):
		var selector := int(types[index])
		var vehicle := _scene("stationary" if bool(row.get("stationary", false)) else "vehicle",
			"%s_%s" % [str(row.get("label", "Vehicle")), VEHICLE_NAMES[selector]])
		vehicle.transform = _raw_transform(row)
		if bool(row.get("stationary", false)):
			vehicle.set("StationaryEmplacementType", max(group, 0))
		else:
			vehicle.set("VehicleType", selector)
			if types.size() > 1:
				vehicle.set("SpawnIfMatchingTeam", true)
				vehicle.set("MatchingTeam", index + 1)
			if pair_base > 0: vehicle.set("ObjId", pair_base + index)
		vehicle.set_meta(PROVENANCE_META, _source(row))
		parent.add_child(vehicle)
		vehicle.owner = owner
		if bool(row.get("stationary", false)): VehicleSkin.sync_stationary(vehicle, owner)
		else: VehicleSkin.sync_spawner(vehicle, owner)


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
