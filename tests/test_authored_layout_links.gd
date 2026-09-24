@tool
extends SceneTree

const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const DATA_DIR := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/data"
const PAYLOAD_ROUTES := "res://addons/bf6_gamemode_setup/data/payload_routes.json"
const OPERATIONS_CANDIDATES := "res://addons/bf6_gamemode_setup/data/operations_candidates.json"
const FIRST_OPERATIONS_SECTORS := {
	"mp_capstone": "1b888515-cfc2-4fe9-8155-6cdec4465b8a",
	"mp_contaminated": "dcd03683-cdbb-453e-8a26-7ecc5fe4b02f",
	"mp_tungsten": "9fc6c589-0816-4f04-ba2b-0615ce63124c",
	"mp_subsurface": "42ae16af-ad9d-4a2c-9ff2-a7855f3efb92",
}


func _init() -> void:
	var operations_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OPERATIONS_CANDIDATES))
	for level in FIRST_OPERATIONS_SECTORS:
		var operations := _build(level, "operations")
		var ordered: Array = operations_data.maps[level].sectors
		for index in range(ordered.size()):
			var sector := operations.find_child("SectorCandidate_%02d" % (index + 1), true, false)
			assert(sector != null)
			assert(str(sector.get_meta("bf6_source_identity")) == str(ordered[index].sector))
			assert(int(sector.get_meta("bf6_operations_collector_index")) == index)
			assert((sector.get("CapturePoints") as Array).size() == ordered[index].captures.size())
		assert(str(ordered[0].sector).ends_with("#" + str(FIRST_OPERATIONS_SECTORS[level])))
	var route_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PAYLOAD_ROUTES))
	assert(route_data.routes.size() == 6)
	for key in route_data.routes:
		var level := str(key).get_slice("/", 0)
		var layout := _build(level, "payload")
		var payload := layout.find_child("Payload_01", true, false) as Node3D
		assert(payload != null)
		var path := payload.get_node_or_null("Authored Spline Route") as Path3D
		assert(path != null)
		var expected: Dictionary = route_data.routes[key]
		assert(path.curve.point_count == expected.sampled_world_points.size())
		assert(str(path.get_meta("bf6_source")) == str(expected.spline))
		for endpoint in [0, path.curve.point_count - 1]:
			var point := expected.sampled_world_points[endpoint] as Array
			var world: Vector3 = payload.transform * path.curve.get_point_position(endpoint)
			assert(world.distance_to(Vector3(point[0], point[1], point[2])) < 0.001)
	for level in route_data.unlinked_selected_maps:
		var layout := _build(str(level), "payload")
		var unlinked := layout.find_child("Payload_01", true, false)
		assert(unlinked != null)
		assert(unlinked.get_node_or_null("Authored Spline Route") == null)
		assert(str(unlinked.get_meta("bf6_payload_spline_status")).contains("no exact"))
	print("authored Operations order and Payload spline links: PASS")
	quit()


func _build(level: String, mode: String) -> Node3D:
	var root := Node3D.new()
	root.name = level.to_upper()
	get_root().add_child(root)
	var key := level + "/" + mode
	var message := Builder.build(root, key, {
		"manifest": DATA_DIR + "/" + level + "_" + mode + ".layout.json",
	}, false)
	assert(message.begins_with("Built "), "%s: %s" % [key, message])
	var layout := Builder.find_build(root, key) as Node3D
	assert(layout != null)
	return layout
