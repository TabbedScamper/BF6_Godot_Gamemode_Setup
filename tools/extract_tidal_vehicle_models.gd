extends SceneTree

const GameSource = preload("res://addons/highpoly_toggle/highpoly_gamesource.gd")
const Ebx = preload("res://addons/highpoly_toggle/bf6_ebx.gd")
const MAP := "mp_atoll"
const OUTPUT_DIR := "res://addons/bf6_gamemode_setup/assets/vehicles"
const SKELETON_BONE_NAMES := 94280276
const VEHICLES := {
	"VEH_RCB_90_Patrol_Boat": "boat/cb90",
	"VEH_F_74A_SEACAT": "airplane/f14",
	"VEH_FA_81F_Super_Spectre": "airplane/fa18f",
}


func _init() -> void:
	var source = GameSource.new()
	source.build_materials = false
	# These exports intentionally use a different hidden-bone set than the map
	# geometry cache, so they must be decoded from the install for this pass.
	source.geom_cache_read = false
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
	var hidden := _intact_hidden_bones(source, vehicle_dir)
	# Playable vehicles are Skinned. Their BoneIndices are skeleton bone ids, so
	# GameSource correctly does not apply the Composite-prop destruction table.
	# Supplying the skeleton's authored state1/broken ids here selects the static
	# non-destructive rendition for these bundled editor previews.
	source._hidden_cache[resource_path] = hidden
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
	print("%s: hid %d authored damage-state bones" % [key, hidden.size()])
	return root


func _intact_hidden_bones(source, vehicle_dir: String) -> Dictionary:
	var vehicle_name := vehicle_dir.get_file()
	var vehicle_class := vehicle_dir.get_base_dir()
	var skeleton := "common/hardware/vehicles/%s/art/ske_veh_%s_%s_base" % [
		vehicle_dir, vehicle_class, vehicle_name]
	var raw: PackedByteArray = source.src.get_ebx(skeleton + ".ebx")
	if raw.is_empty():
		raw = source.src.get_ebx(skeleton)
	if raw.is_empty():
		push_error("No vehicle skeleton at %s" % skeleton)
		return {}
	var ebx = Ebx.new(source.types, source.walk.gi)
	if not ebx.parse(raw):
		push_error("Could not parse vehicle skeleton at %s" % skeleton)
		return {}
	var names: Array = []
	for i in range(ebx.instance_offsets.size()):
		var inst = ebx.read_instance(i)
		if inst is Dictionary and (inst as Dictionary).get(SKELETON_BONE_NAMES) is Array:
			names = (inst as Dictionary)[SKELETON_BONE_NAMES]
			break
	var lowered := {}
	for bone in names:
		lowered[str(bone).to_lower()] = true
	var hidden := {}
	for i in range(names.size()):
		var low := str(names[i]).to_lower()
		if low.ends_with("_state1") and lowered.has(
				low.substr(0, low.length() - 1) + "0"):
			hidden[i] = true
		elif "interior" in low and ("damage" in low or "broken" in low):
			hidden[i] = true
	return hidden
