extends SceneTree

const GameSource = preload("res://addons/highpoly_toggle/highpoly_gamesource.gd")
const MAP := "mp_isolated"
const OBJECT := "gmpf_vehicleresupplystation"
const OUTPUT_DIR := "res://addons/bf6_gamemode_setup/assets"
const OUTPUT := OUTPUT_DIR + "/VehicleResupplyStation_Game.tscn"


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
	if not source.has_object(OBJECT):
		_print_candidates(source)
		push_error("The installed game has no Portal prefab for %s" % OBJECT)
		quit(1)
		return

	var model := source.object_node(OBJECT)
	if model == null:
		push_error("The Portal prefab resolved but produced no geometry")
		quit(1)
		return
	model.name = "VehicleResupplyStationModel"
	var sdk_material := StandardMaterial3D.new()
	sdk_material.albedo_color = Color(0.92, 0.92, 0.92, 1.0)
	sdk_material.roughness = 0.9
	var stats := {"meshes": 0, "surfaces": 0, "vertices": 0}
	_prepare(model, model, sdk_material, stats)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := PackedScene.new()
	var packed_error := packed.pack(model)
	if packed_error != OK:
		push_error("Could not pack the model: %s" % error_string(packed_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(packed, OUTPUT)
	if save_error != OK:
		push_error("Could not save the model: %s" % error_string(save_error))
		quit(1)
		return
	print("RESUPPLY MODEL OK: %s meshes, %s surfaces, %s vertices -> %s" % [
		stats.meshes, stats.surfaces, stats.vertices,
		ProjectSettings.globalize_path(OUTPUT)])
	quit(0)


func _print_candidates(source) -> void:
	var patterns := ["resupply", "vehicle_supply", "vehiclesupply",
		"supplystation", "supply_station", "repairstation", "repair_station"]
	var seen := {}
	for values in [source.src.ebx.keys(), source.src.res.keys(),
			source.walk.by_name.keys()]:
		for value in values:
			var candidate := str(value)
			var lower := candidate.to_lower()
			for pattern in patterns:
				if lower.contains(pattern) and not seen.has(lower):
					seen[lower] = true
					print("CANDIDATE ", candidate)
					break


func _prepare(node: Node, scene_root: Node, material: Material,
		stats: Dictionary) -> void:
	if node != scene_root:
		node.owner = scene_root
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = material
		stats.meshes += 1
		if mesh_instance.mesh != null:
			stats.surfaces += mesh_instance.mesh.get_surface_count()
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var arrays := mesh_instance.mesh.surface_get_arrays(surface)
				if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
					stats.vertices += arrays[Mesh.ARRAY_VERTEX].size()
	for child in node.get_children():
		_prepare(child, scene_root, material, stats)
