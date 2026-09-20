@tool
extends SceneTree

const Fetch = preload("res://addons/bf6_gamemode_setup/layout_fetch.gd")
const IDENTITIES := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/tests/conquest_objective_identities.json"


func _init() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(IDENTITIES))
	var fetch := Fetch.new()
	get_root().add_child(fetch)
	await process_frame
	if not await fetch.fetch_index():
		_fail("Index download failed: %s" % fetch.error)
		return
	var checked := 0
	for map_value in expected:
		var map := str(map_value)
		var selected: Dictionary = {}
		for row in fetch.layouts_for(map):
			if str((row as Dictionary).get("key", "")) == "%s/conquest" % map:
				selected = row
				break
		var paths := await fetch.ensure_layout(selected)
		if paths.is_empty():
			_fail("%s download failed: %s" % [map, fetch.error])
			return
		var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(str(paths.manifest)))
		var expected_guids := expected[map] as Array
		var seen := 0
		for value in document.get("objects", []):
			var object := value as Dictionary
			if int(object.get("role", 0)) != 2:
				continue
			var flag := int(object.get("flag", -1))
			var guid := str((object.get("raw", {}) as Dictionary).get("instance_guid", ""))
			if flag < 0 or flag >= expected_guids.size() or guid != str(expected_guids[flag]):
				_fail("%s downloaded identity is wrong for flag index %d" % [map, flag])
				return
			seen += 1
		if seen != expected_guids.size():
			_fail("%s downloaded %d captures, expected %d" % [map, seen, expected_guids.size()])
			return
		checked += 1
	print("CONQUEST DOWNLOADS OK: %d maps match audited objective identities" % checked)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
