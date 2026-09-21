extends SceneTree

const GameSource = preload("res://addons/highpoly_toggle/highpoly_gamesource.gd")
const MAP := "mp_atoll"
const OUTPUT_DIR := "res://addons/bf6_gamemode_setup/assets/vehicles"
const VEHICLES := {
	"VEH_RCB_90_Patrol_Boat": "boat/cb90",
	"VEH_F_74A_SEACAT": "airplane/f14",
	"VEH_FA_81F_Super_Spectre": "airplane/fa18f",
}


func _init() -> void:
	var source = GameSource.new()
	source.build_materials = false
	if not source.open_map(MAP,
			"C:/Program Files (x86)/Steam/steamapps/common/Battlefield 6",
			Callable(), {"placements": false}):
		push_error(source.error)
		quit(1)
		return
	if not source.upgrade_catalogue():
		push_error("Could not mount the installed-game object catalogue")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var failed := false
	for key in VEHICLES:
		var model := _build_base(source, str(key), str(VEHICLES[key]))
		if model == null:
			failed = true
			continue
		var state := GLTFState.new()
		var document := GLTFDocument.new()
		var error := document.append_from_scene(model, state)
		if error == OK:
			error = document.write_to_filesystem(state, "%s/%s.glb" % [OUTPUT_DIR, key])
		if error != OK:
			push_error("Could not export %s: %s" % [key, error_string(error)])
			failed = true
		else:
			print("VEHICLE MODEL OK: %s (%s)" % [key, VEHICLES[key]])
	quit(1 if failed else 0)


func _build_base(source, key: String, vehicle_dir: String) -> Node3D:
	var vehicle_class := vehicle_dir.get_base_dir()
	var vehicle_name := vehicle_dir.get_file()
	var base := "common/hardware/vehicles/%s/art/ob_veh_%s_%s_base" % [
		vehicle_dir, vehicle_class, vehicle_name]
	var resource_path: String = source.resolve_mesh(base)
	if resource_path == "":
		push_error("%s has no base mesh at %s" % [key, base])
		return null
	var scope: String = source._scope_of(resource_path)
	var mesh = source.mesh_for("%s|%s|0" % [resource_path, scope]) \
		if scope != "" else source.mesh_for(resource_path)
	if mesh == null:
		push_error("%s base mesh did not build: %s" % [key, resource_path])
		return null
	var root := Node3D.new()
	root.name = key
	var instance := MeshInstance3D.new()
	instance.name = "Base"
	instance.mesh = mesh
	root.add_child(instance)
	instance.owner = root
	return root
