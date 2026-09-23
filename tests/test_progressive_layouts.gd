extends SceneTree

# Fleet smoke test. Detailed identity, order, and attachment assertions live in
# test_exact_progressive.gd; this test rejects any return to spatial grouping.
const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const DATA := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/data"
const LINKS := "res://addons/bf6_gamemode_setup/data/progressive_links.json"

var failures := 0


func _init() -> void:
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LINKS))
	var built_count := 0
	var unresolved_count := 0
	var files := DirAccess.get_files_at(DATA)
	files.sort()
	for filename in files:
		if not filename.ends_with(".layout.json") or \
				(not filename.contains("_rush.") and not filename.contains("_breakthrough.")):
			continue
		var path := "%s/%s" % [DATA, filename]
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var source: Dictionary = document.get("source", {})
		var key := str(source.get("level", "")).to_lower() + "/" + str(source.get("mode", ""))
		var evidence: Dictionary = pack.get("layouts", {}).get(key, {})
		var host := Node3D.new()
		get_root().add_child(host)
		var message := Builder.build(host, key, {"manifest": path}, true)
		if evidence.get("sectors", []).is_empty():
			check(host.get_child_count() == 0 and message.begins_with(
				"Exact progressive selection is unresolved"), key + " must not guess a layout")
			unresolved_count += 1
		else:
			check(host.get_child_count() == 1 and message.begins_with("Built "),
				key + " exact build failed: " + message)
			if host.get_child_count() == 1:
				var built: Node = host.get_child(0)
				var sectors: Node = built.get_node_or_null("Objectives/Sectors")
				check(sectors != null and sectors.get_child_count() == evidence.sectors.size() + 2,
					key + " sector shell differs from selected game layout")
				check(built.has_meta("bf6_order_status") and
					built.has_meta("bf6_hq_control_baseline"), key + " missing exact provenance")
				check(not has_generated_name(built), key + " leaked an @name")
				built_count += 1
		host.free()
	print("PROGRESSIVE LAYOUTS: ", built_count, " exact builds, ",
		unresolved_count, " unresolved, ", failures, " failures")
	quit(1 if failures else 0)


func check(ok: bool, message: String) -> void:
	if ok: return
	failures += 1
	print("FAIL: ", message)


func has_generated_name(node: Node) -> bool:
	if str(node.name).begins_with("@"): return true
	for child in node.get_children():
		if has_generated_name(child): return true
	return false
