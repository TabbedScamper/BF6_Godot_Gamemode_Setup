@tool
extends RefCounted

# Keeps each SDK VehicleSpawner's visible vehicle as a direct scene child.
# Direct SDK VEH_* instances are discoverable by BF6 High Poly; an intermediate
# preview wrapper is not.

const SKIN_META := "bf6_vehicle_skin"
const TYPE_META := "bf6_vehicle_skin_type"
const MARKER_META := "bf6_sdk_marker_reserved"
const SDK_MARKER_NAME := "SDKMarker"
const BUNDLED_DIR := "res://addons/bf6_gamemode_setup/assets/vehicles"
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
const MODEL_ALIASES := {
	"VEH_RCB_90_Patrol_Boat_Pax": "VEH_RCB_90_Patrol_Boat",
	"VEH_F_74A_SEACAT_Pax": "VEH_F_74A_SEACAT",
	"VEH_FA_81F_Super_Spectre_Pax": "VEH_FA_81F_Super_Spectre",
}
const RESUPPLY_MODEL := \
	"res://addons/bf6_gamemode_setup/assets/VehicleResupplyStation_Game.tscn"
static var previews_enabled := false


static func sync_tree(root: Node) -> bool:
	if root == null:
		return false
	if not previews_enabled:
		return restore_tree(root)
	var changed := false
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		changed = sync_node(node, root) or changed
		for child in node.get_children():
			pending.append(child)
	return changed


# Undo every editor-only preview mutation when the addon is disabled.  The SDK
# PackedScenes are never edited: only their live instances are adjusted while
# this plugin is active.
static func restore_tree(root: Node) -> bool:
	if root == null:
		return false
	var changed := false
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		for child in node.get_children():
			# restore_node() frees preview children below, so never retain one in
			# the traversal stack after its parent has restored it.
			if not child.has_meta(SKIN_META):
				pending.append(child)
		changed = restore_node(node) or changed
	return changed


static func restore_node(node: Node) -> bool:
	var changed := false
	for child in node.get_children():
		if child.has_meta(SKIN_META):
			node.remove_child(child)
			child.free()
			changed = true
	_set_marker_visible(node, true)
	changed = _restore_sdk_marker_name(node) or changed
	if node.has_meta(TYPE_META):
		node.remove_meta(TYPE_META)
	return changed


# Event-driven editor updates call this for the selected node only. Keeping the
# type dispatch here also ensures the one-time scene-open scan and an inspector
# edit use exactly the same behavior.
static func sync_node(node: Node, scene_root: Node) -> bool:
	if _is_vehicle_spawner(node):
		return sync_spawner(node as Node3D, scene_root)
	if _is_stationary_spawner(node):
		return sync_stationary(node as Node3D, scene_root)
	if _is_automatic_aa(node):
		return sync_automatic_aa(node as Node3D, scene_root)
	if _is_resupply_station(node):
		return sync_resupply(node as Node3D, scene_root)
	return false


static func sync_spawner(spawner: Node3D, _scene_root: Node) -> bool:
	var selected := int(spawner.get("VehicleType"))
	return _sync_model(spawner, selected, VEHICLE_KEYS)


static func sync_stationary(spawner: Node3D, _scene_root: Node) -> bool:
	var selected := int(spawner.get("StationaryEmplacementType"))
	return _sync_model(spawner, selected, STATIONARY_KEYS)


static func sync_automatic_aa(spawner: Node3D, _scene_root: Node) -> bool:
	return _sync_path(spawner, 0,
		_packaged_model_path("VEH_Stationary_AutomaticAA"),
		"VEH_Stationary_AutomaticAA")


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
			_restore_sdk_marker_name(spawner)
			spawner.remove_meta(TYPE_META)
			return true
		return false

	var model_key := str(keys[selected])
	var expected_path := _packaged_model_path(model_key)
	return _sync_path(spawner, selected, expected_path, model_key)


static func _packaged_model_path(model_key: String) -> String:
	var canonical := str(MODEL_ALIASES.get(model_key, model_key))
	var packaged := "%s/%s.glb" % [BUNDLED_DIR, canonical]
	if ResourceLoader.exists(packaged):
		return packaged
	return "res://objects/gameplay/vehicles/%s.tscn" % model_key


static func _sync_path(spawner: Node3D, selected: int, expected_path: String,
		model_key: String) -> bool:
	if not previews_enabled:
		return restore_node(spawner)
	var existing := _skin_child(spawner)
	if existing != null and str(existing.scene_file_path) == expected_path:
		if expected_path.get_extension().to_lower() == "glb":
			_reserve_sdk_marker_name(spawner)
		_set_marker_visible(spawner, false)
		spawner.set_meta(TYPE_META, selected)
		return false

	if existing != null:
		spawner.remove_child(existing)
		existing.free()
	var packed := load(expected_path) as PackedScene
	if packed == null:
		_set_marker_visible(spawner, true)
		_restore_sdk_marker_name(spawner)
		return false
	var skin := packed.instantiate() as Node3D
	if skin == null:
		_set_marker_visible(spawner, true)
		_restore_sdk_marker_name(spawner)
		return false
	# Portal's level validator intentionally permits imported GLB instances only
	# when their root is named Mesh.  Any vehicle/type name here produces a modal
	# "mesh file should not be directly added" warning on every selection change.
	if expected_path.get_extension().to_lower() == "glb":
		# SDK spawners already contain a child named Mesh. Godot otherwise renames
		# this GLB to Mesh2 during add_child(), after which Portal's validator emits
		# the modal "mesh file should not be directly added" alert.
		_reserve_sdk_marker_name(spawner)
	skin.name = "Mesh"
	skin.set_meta(SKIN_META, true)
	if expected_path.begins_with(BUNDLED_DIR + "/"):
		_apply_sdk_material(skin)
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


static func _is_automatic_aa(node: Node) -> bool:
	return node is Node3D and \
		str(node.scene_file_path).get_file() == "VEH_Stationary_AutomaticAA.tscn"


static func _apply_sdk_material(node: Node) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.92, 0.92, 1.0)
	material.roughness = 0.9
	_apply_material_recursive(node, material)


static func _apply_material_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply_material_recursive(child, material)


static func _skin_child(spawner: Node) -> Node3D:
	for child in spawner.get_children():
		if child is Node3D and child.has_meta(SKIN_META):
			return child as Node3D
	return null


static func _reserve_sdk_marker_name(spawner: Node) -> void:
	for child in spawner.get_children():
		if child.has_meta(SKIN_META) or child.name != "Mesh":
			continue
		child.name = SDK_MARKER_NAME
		child.set_meta(MARKER_META, true)
		return


static func _restore_sdk_marker_name(spawner: Node) -> bool:
	for child in spawner.get_children():
		if not child.has_meta(MARKER_META):
			continue
		child.name = "Mesh"
		child.remove_meta(MARKER_META)
		return true
	return false


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
