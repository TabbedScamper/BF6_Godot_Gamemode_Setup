@tool
extends SceneTree

const Fetch = preload("res://addons/bf6_gamemode_setup/layout_fetch.gd")
const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const EXPECTED_GUIDS := {
	0: "0110efce-cec2-4619-ab13-59957dcf397c",
	1: "5119911c-3e48-4f74-adc3-296a5fd026af",
	2: "e1d6a53b-b739-4a0d-97bc-4ab3f214c3b2",
	3: "f82ac26e-80d4-441b-8487-509af6833c37",
	4: "d000740b-5b9a-48db-bec4-1aaa7a2c02a4",
	5: "e931291b-2785-47b1-b67e-72045e63a9b1",
	6: "dc35642b-df23-44be-b375-222ada842bf7",
}


func _init() -> void:
	var fetch := Fetch.new()
	get_root().add_child(fetch)
	await process_frame
	if not await fetch.fetch_index():
		_fail("Index download failed: %s" % fetch.error)
		return
	var selected: Dictionary = {}
	for row in fetch.layouts_for("MP_Atoll"):
		if str((row as Dictionary).get("key", "")) == "mp_atoll/conquest":
			selected = row
			break
	var paths := await fetch.ensure_layout(selected)
	if paths.is_empty():
		_fail("Atoll layout download failed: %s" % fetch.error)
		return
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(paths.manifest)))
	var seen := 0
	for value in document.get("objects", []):
		var row := value as Dictionary
		if int(row.get("role", 0)) != 2:
			continue
		var flag := int(row.get("flag", -1))
		var guid := str((row.get("raw", {}) as Dictionary).get("instance_guid", ""))
		if guid != str(EXPECTED_GUIDS.get(flag, "")):
			_fail("Downloaded Atoll identity is wrong for flag %s" % String.chr(65 + flag))
			return
		seen += 1
	if seen != 7:
		_fail("Downloaded Atoll manifest has %d captures, expected 7" % seen)
		return
	var level := Node3D.new()
	level.name = "MP_Atoll"
	get_root().add_child(level)
	var result := Builder.build(level, "mp_atoll/conquest", paths)
	if not result.begins_with("Built mp_atoll Conquest"):
		_fail("Downloaded Atoll manifest did not build: %s" % result)
		return
	print("ATOLL DOWNLOAD OK: seven game-root-derived flag identities")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
