@tool
extends SceneTree

const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const DATA_DIR := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/data"
const CATALOG := DATA_DIR + "/layout_catalog.json"

var failures := 0


func _init() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var tested := 0
	for level in (catalog.get("maps", {}) as Dictionary):
		var map: Dictionary = catalog.maps[level]
		for mode_value in map.get("modes", []):
			var mode := str(mode_value)
			var filename := "%s_%s.layout.json" % [level, mode]
			var root := Node3D.new()
			root.name = str(level).to_upper()
			get_root().add_child(root)
			var key := "%s/%s" % [level, mode]
			var message := Builder.build(root, key, {
				"manifest": "%s/%s" % [DATA_DIR, filename],
			}, false)
			if not message.begins_with("Built "):
				failures += 1
				print("FAIL ", filename, ": ", message)
			else:
				var built := Builder.find_build(root, key)
				if built == null:
					failures += 1
					print("FAIL ", filename, ": no built root")
				else:
					var manifest: Dictionary = JSON.parse_string(
						FileAccess.get_file_as_string("%s/%s" % [DATA_DIR, filename]))
					var expected_special := int((manifest.get("counts", {}) as Dictionary).get("specialareas", 0))
					var actual_special := _count_meta(built, "bf6_unmapped_role", "gem_specialcombatarea")
					if actual_special != expected_special:
						failures += 1
						print("FAIL ", filename, ": special areas ", actual_special, "/", expected_special)
					var expected_vehicles := int((manifest.get("counts", {}) as Dictionary).get("vehicles", 0))
					var actual_vehicles := _count_meta_key(built, "bf6_retail_selector")
					if actual_vehicles != expected_vehicles:
						failures += 1
						print("FAIL ", filename, ": represented vehicle rows ", actual_vehicles, "/", expected_vehicles)
					var expected_linked_spawns := 0
					for object_value in manifest.get("objects", []):
						var object := object_value as Dictionary
						if int(object.get("role", 0)) == 1 and int(object.get("flag", -1)) >= 0:
							expected_linked_spawns += 1
					var actual_linked_spawns := _count_objective_spawns(built)
					if actual_linked_spawns != expected_linked_spawns:
						failures += 1
						print("FAIL ", filename, ": objective spawn hierarchy ", actual_linked_spawns, "/", expected_linked_spawns)
					var generated_name := _find_generated_name(built)
					if generated_name != "":
						failures += 1
						print("FAIL ", filename, ": generated node name ", generated_name)
					var packed := PackedScene.new()
					if packed.pack(root) != OK:
						failures += 1
						print("FAIL ", filename, ": scene did not pack")
					else:
						print("ok   ", filename, "  ", message)
			tested += 1
			root.queue_free()
			await process_frame
	print("ALL MODES: ", tested, " tested, ", failures, " failures")
	quit(1 if failures else 0)


func _count_meta(node: Node, key: String, value: String) -> int:
	var count := 1 if node.has_meta(key) and str(node.get_meta(key)) == value else 0
	for child in node.get_children():
		count += _count_meta(child, key, value)
	return count


func _count_meta_key(node: Node, key: String) -> int:
	var count := 1 if node.has_meta(key) else 0
	for child in node.get_children():
		count += _count_meta_key(child, key)
	return count


func _count_objective_spawns(node: Node, inside_capture := false) -> int:
	var is_capture := inside_capture or node.name.begins_with("CapturePoint")
	var count := 1 if is_capture and node.name.begins_with("Spawn_Flag_") else 0
	for child in node.get_children():
		count += _count_objective_spawns(child, is_capture)
	return count


func _find_generated_name(node: Node) -> String:
	if str(node.name).to_lower().begins_with("@spawn"):
		return str(node.name)
	for child in node.get_children():
		var found := _find_generated_name(child)
		if found != "":
			return found
	return ""
