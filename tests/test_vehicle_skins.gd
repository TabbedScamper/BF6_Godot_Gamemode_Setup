extends SceneTree

const VehicleSkin = preload("res://addons/bf6_gamemode_setup/vehicle_skin.gd")
const VEHICLE_SCENE := "res://objects/gameplay/common/VehicleSpawner.tscn"
const STATIONARY_SCENE := "res://objects/gameplay/common/StationaryEmplacementSpawner.tscn"
const AUTO_AA_SCENE := "res://objects/gameplay/vehicles/VEH_Stationary_AutomaticAA.tscn"

var failures := 0


func _init() -> void:
	var root := Node3D.new()
	for selected in range(VehicleSkin.VEHICLE_KEYS.size()):
		var spawner := (load(VEHICLE_SCENE) as PackedScene).instantiate() as Node3D
		root.add_child(spawner)
		spawner.set("VehicleType", selected)
		VehicleSkin.sync_spawner(spawner, root)
		_check_skin(spawner, str(VehicleSkin.VEHICLE_KEYS[selected]))
		spawner.free()

	for selected in range(VehicleSkin.STATIONARY_KEYS.size()):
		var spawner := (load(STATIONARY_SCENE) as PackedScene).instantiate() as Node3D
		root.add_child(spawner)
		spawner.set("StationaryEmplacementType", selected)
		VehicleSkin.sync_stationary(spawner, root)
		_check_skin(spawner, str(VehicleSkin.STATIONARY_KEYS[selected]))
		spawner.free()

	var automatic_aa := (load(AUTO_AA_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(automatic_aa)
	VehicleSkin.sync_automatic_aa(automatic_aa, root)
	_check_skin(automatic_aa, "VEH_Stationary_AutomaticAA")
	automatic_aa.free()
	root.free()
	if failures == 0:
		print("PASS: every SDK vehicle choice uses its bundled game model")
	quit(1 if failures else 0)


func _check_skin(spawner: Node3D, requested_key: String) -> void:
	var skin: Node3D = null
	for child in spawner.get_children():
		if child is Node3D and child.has_meta(VehicleSkin.SKIN_META):
			skin = child
			break
	_check(skin != null, "%s has a visual skin" % requested_key)
	if skin == null:
		return
	var canonical := str(VehicleSkin.MODEL_ALIASES.get(requested_key, requested_key))
	_check(str(skin.scene_file_path) == "%s/%s.glb" % [VehicleSkin.BUNDLED_DIR, canonical],
		"%s resolves to %s" % [requested_key, canonical])
	var census := {"meshes": 0, "bad_materials": 0, "physics": 0}
	_census(skin, census)
	_check(int(census.meshes) > 0, "%s contains meshes" % requested_key)
	_check(int(census.bad_materials) == 0, "%s uses the SDK-white override" % requested_key)
	_check(int(census.physics) == 0, "%s contains no collision or physics nodes" % requested_key)


func _census(node: Node, census: Dictionary) -> void:
	if node is MeshInstance3D:
		census.meshes += 1
		var material := (node as MeshInstance3D).material_override as StandardMaterial3D
		if material == null or not material.albedo_color.is_equal_approx(
				Color(0.92, 0.92, 0.92, 1.0)):
			census.bad_materials += 1
	if node is CollisionObject3D or node is CollisionShape3D:
		census.physics += 1
	for child in node.get_children():
		_census(child, census)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("ok   ", label)
	else:
		failures += 1
		print("FAIL ", label)
