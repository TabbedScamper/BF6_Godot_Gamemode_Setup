extends SceneTree

const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const DATA := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/data"

var failures := 0


func _init() -> void:
	_check_rush()
	_check_breakthrough()
	_check_fleet()
	if failures == 0:
		print("PROGRESSIVE LAYOUTS OK")
	quit(failures)


func _build(mode: String) -> Node:
	var path := "%s/mp_isolated_%s.layout.json" % [DATA, mode]
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var root := Node3D.new()
	get_root().add_child(root)
	var result := Builder.build(root, "mp_isolated/%s" % mode,
		{"manifest": path}, true)
	_check(not result.begins_with("Classified") and not result.begins_with("This plugin"),
		"build failed: " + result)
	return root.get_child(0)


func _check_rush() -> void:
	var built := _build("rush")
	var sectors := built.get_node("Objectives/Sectors")
	_check(sectors.get_child_count() == 5, "Rush sector shell count")
	var expected := [[23, 24], [18, 30], [28, 29]]
	for phase in range(expected.size()):
		var sector := sectors.get_node("Sector%d" % (phase + 1))
		_check(sector.get("SectorArea") != null, "Rush phase %d has no SectorArea" % phase)
		var roots: Array = []
		for mcom in sector.get("MCOMs"):
			roots.append(int((mcom as Node).get_meta("bf6_root_order", -1)))
		roots.sort()
		_check(roots == expected[phase], "Rush MCOM roots %s != %s" % [roots, expected[phase]])
	_check(_count_linked_spawns(built) > 0, "Rush has no exact linked spawns")
	_check(_count_hq_spawn_links(built) > 0, "Rush HQ InfantrySpawns arrays are empty")
	_check(_count_runtime_unassigned(built) < 14, "Rush left every vehicle RuntimeUnassigned")
	built.get_parent().queue_free()


func _check_breakthrough() -> void:
	var built := _build("breakthrough")
	var sectors := built.get_node("Objectives/Sectors")
	var expected_captures := [[25, 49], [26, 52], [28, 79], [34]]
	var expected_hqs := [[2, 3], [15, 13], [29, 30], [35, 36]]
	for phase in range(expected_captures.size()):
		var sector := sectors.get_node("Sector%d" % (phase + 1))
		_check(sector.get("SectorArea") != null,
			"Breakthrough phase %d has no SectorArea" % phase)
		var capture_roots: Array = []
		for capture in sector.get("CapturePoints"):
			capture_roots.append(int((capture as Node).get_meta("bf6_capture_root_order", -1)))
		capture_roots.sort()
		_check(capture_roots == expected_captures[phase],
			"Breakthrough capture roots %s != %s" % [capture_roots, expected_captures[phase]])
		var hq_roots: Array = []
		for hq in sector.get("HQs"):
			hq_roots.append(int((hq as Node).get_meta("bf6_root_order", -1)))
		_check(hq_roots == expected_hqs[phase],
			"Breakthrough HQ roots %s != %s (%s)" % [hq_roots, expected_hqs[phase],
			str((sector.get("HQs")[0] as Node).get_meta("bf6_progressive_phase_basis", "none"))])
		for hq in sector.get("HQs"):
			_check((hq as Node).get("HQArea") != null, "%s has no HQArea" % hq.name)
	_check(_count_linked_spawns(built) > 0, "Breakthrough has no exact linked spawns")
	_check(_count_hq_spawn_links(built) > 0,
		"Breakthrough HQ InfantrySpawns arrays are empty")
	_check(_count_runtime_unassigned(built) < 45,
		"Breakthrough left every vehicle RuntimeUnassigned")
	built.get_parent().queue_free()


func _check_fleet() -> void:
	var files := DirAccess.get_files_at(DATA)
	files.sort()
	for filename in files:
		if not filename.ends_with(".layout.json") or \
				(not filename.contains("_rush.") and not filename.contains("_breakthrough.")):
			continue
		var path := "%s/%s" % [DATA, filename]
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var mode := str((document.get("source", {}) as Dictionary).get("mode", ""))
		var level := str((document.get("source", {}) as Dictionary).get("level", ""))
		var host := Node3D.new()
		get_root().add_child(host)
		var message := Builder.build(host, "%s/%s" % [level, mode],
			{"manifest": path}, true)
		_check(host.get_child_count() == 1, "%s did not build: %s" % [filename, message])
		if host.get_child_count() == 1:
			var built := host.get_child(0)
			_check(_count_meta(built, "bf6_source_vehicle_record") ==
				int((document.get("counts", {}) as Dictionary).get("vehicles", 0)),
				"%s lost a vehicle record" % filename)
			_check(_find_generated_name(built) == "", "%s generated an @name" % filename)
		host.free()


func _count_linked_spawns(node: Node) -> int:
	var count := 0
	if str(node.scene_file_path).ends_with("SpawnPoint.tscn") and \
			node.has_meta("bf6_spawn_binding"):
		count += 1
	for child in node.get_children():
		count += _count_linked_spawns(child)
	return count


func _count_runtime_unassigned(node: Node) -> int:
	var count := 1 if str(node.name).begins_with("RuntimeUnassigned_") else 0
	for child in node.get_children():
		count += _count_runtime_unassigned(child)
	return count


func _count_meta(node: Node, key: String) -> int:
	var count := 1 if node.has_meta(key) else 0
	for child in node.get_children():
		count += _count_meta(child, key)
	return count


func _find_generated_name(node: Node) -> String:
	if str(node.name).begins_with("@"):
		return str(node.name)
	for child in node.get_children():
		var found := _find_generated_name(child)
		if found != "":
			return found
	return ""


func _count_hq_spawn_links(node: Node) -> int:
	var count := 0
	if node.name.begins_with("TEAM_"):
		var links = node.get("InfantrySpawns")
		if links is Array:
			count += links.size()
	for child in node.get_children():
		count += _count_hq_spawn_links(child)
	return count


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	print("FAIL: ", message)
