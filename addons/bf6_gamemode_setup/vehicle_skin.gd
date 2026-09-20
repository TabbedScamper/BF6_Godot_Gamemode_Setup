@tool
extends RefCounted

# Keeps each SDK VehicleSpawner's visible vehicle as a direct scene child.
# Direct SDK VEH_* instances are discoverable by BF6 High Poly; an intermediate
# preview wrapper is not.

const SKIN_META := "bf6_vehicle_skin"
const TYPE_META := "bf6_vehicle_skin_type"
const VEHICLE_KEYS := [
	"VEH_Abrams", "VEH_Leopard", "VEH_Cheetah", "VEH_CV90", "VEH_Gepard",
	"VEH_UH60", "VEH_Eurocopter", "VEH_AH6M", "VEH_AH64E", "VEH_Vector",
	"VEH_Quadbike", "VEH_Golfcart", "VEH_Marauder", "VEH_Flyer60", "VEH_JAS39",
	"VEH_F22", "VEH_F16", "VEH_Bradley", "VEH_SU57", "VEH_UH60",
	"VEH_Marauder", "VEH_RHIB", "VEH_DirtBike_M1030", "VEH_DirtBike_TMO450",
	"VEH_AH6M", "VEH_Couch", "VEH_RCB_90_Patrol_Boat",
	"VEH_RCB_90_Patrol_Boat_Pax", "VEH_F_74A_SEACAT", "VEH_F_74A_SEACAT_Pax",
	"VEH_FA_81F_Super_Spectre", "VEH_FA_81F_Super_Spectre_Pax",
]
const STATIONARY_KEYS := [
	"VEH_Stationary_BGM71TOW",
	"VEH_Stationary_GDF009",
	"VEH_M2MG",
]
const RESUPPLY_MODEL := \
	"res://addons/bf6_gamemode_setup/assets/VehicleResupplyStation_Game.tscn"


static func sync_tree(root: Node) -> bool:
	if root == null:
		return false
	var changed := false
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		changed = sync_node(node, root) or changed
		for child in node.get_children():
			pending.append(child)
	return changed


# Event-driven editor updates call this for the selected node only. Keeping the
# type dispatch here also ensures the one-time scene-open scan and an inspector
# edit use exactly the same behavior.
static func sync_node(node: Node, scene_root: Node) -> bool:
	if _is_vehicle_spawner(node):
		return sync_spawner(node as Node3D, scene_root)
	if _is_stationary_spawner(node):
		return sync_stationary(node as Node3D, scene_root)
	if _is_resupply_station(node):
		return sync_resupply(node as Node3D, scene_root)
	return false


static func sync_spawner(spawner: Node3D, _scene_root: Node) -> bool:
	var selected := int(spawner.get("VehicleType"))
	return _sync_model(spawner, selected, VEHICLE_KEYS)


static func sync_stationary(spawner: Node3D, _scene_root: Node) -> bool:
	var selected := int(spawner.get("StationaryEmplacementType"))
	return _sync_model(spawner, selected, STATIONARY_KEYS)


static func sync_resupply(station: Node3D, _scene_root: Node) -> bool:
	return _sync_path(station, 0, RESUPPLY_MODEL,
		"VehicleResupplyStationModel")


static func _sync_model(spawner: Node3D, selected: int, keys: Array) -> bool:
	var existing := _skin_child(spawner)
	if selected < 0 or selected >= keys.size():
		if existing != null:
			spawner.remove_child(existing)
			existing.free()
			_set_marker_visible(spawner, true)
			spawner.remove_meta(TYPE_META)
			return true
		return false

	var model_key := str(keys[selected])
	var expected_path := "res://objects/gameplay/vehicles/%s.tscn" % model_key
	return _sync_path(spawner, selected, expected_path, model_key)


static func _sync_path(spawner: Node3D, selected: int, expected_path: String,
		model_key: String) -> bool:
	var existing := _skin_child(spawner)
	if existing != null and str(existing.scene_file_path) == expected_path:
		_set_marker_visible(spawner, false)
		spawner.set_meta(TYPE_META, selected)
		return false

	if existing != null:
		spawner.remove_child(existing)
		existing.free()
	var packed := load(expected_path) as PackedScene
	if packed == null:
		_set_marker_visible(spawner, true)
		return false
	var skin := packed.instantiate() as Node3D
	if skin == null:
		_set_marker_visible(spawner, true)
		return false
	skin.name = model_key
	skin.set_meta(SKIN_META, true)
	spawner.add_child(skin)
	# Visual skin only: keep it outside scene ownership so Portal exports the
	# VehicleSpawner, not a second placed gameplay vehicle. The editor plug-in
	# recreates this direct child whenever the scene opens.
	skin.owner = null
	spawner.set_meta(TYPE_META, selected)
	_set_marker_visible(spawner, false)
	return true


static func _is_vehicle_spawner(node: Node) -> bool:
	if not node is Node3D:
		return false
	if str(node.scene_file_path).get_file() != "VehicleSpawner.tscn":
		return false
	for property in node.get_property_list():
		if str(property.name) == "VehicleType":
			return true
	return false


static func _is_stationary_spawner(node: Node) -> bool:
	if not node is Node3D:
		return false
	if str(node.scene_file_path).get_file() != "StationaryEmplacementSpawner.tscn":
		return false
	for property in node.get_property_list():
		if str(property.name) == "StationaryEmplacementType":
			return true
	return false


static func _is_resupply_station(node: Node) -> bool:
	return node is Node3D and \
		str(node.scene_file_path).get_file() == "VehicleResupplyStation.tscn"


static func _skin_child(spawner: Node) -> Node3D:
	for child in spawner.get_children():
		if child is Node3D and child.has_meta(SKIN_META):
			return child as Node3D
	return null


static func _set_marker_visible(spawner: Node, value: bool) -> void:
	for child in spawner.get_children():
		if child.has_meta(SKIN_META):
			continue
		_set_meshes_visible(child, value)


static func _set_meshes_visible(node: Node, value: bool) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = value
	for child in node.get_children():
		_set_meshes_visible(child, value)
