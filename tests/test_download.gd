@tool
extends SceneTree

const Fetch = preload("res://addons/bf6_gamemode_setup/layout_fetch.gd")
const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")


func _init() -> void:
	var fetch := Fetch.new()
	get_root().add_child(fetch)
	await process_frame
	if not await fetch.fetch_index():
		push_error("Index download failed: %s" % fetch.error)
		quit(1)
		return
	var rows: Array = fetch.layouts_for("MP_Isolated")
	if rows.size() != 12:
		push_error("Unexpected MP_Isolated layout list: %s" % str(rows))
		quit(1)
		return
	var selected: Dictionary = {}
	for row in rows:
		if str((row as Dictionary).get("key", "")) == "mp_isolated/carrierstrike":
			selected = row
			break
	var paths: Dictionary = await fetch.ensure_layout(selected)
	if paths.size() != 2:
		push_error("Layout download failed: %s" % fetch.error)
		quit(1)
		return
	for path in paths.values():
		if not FileAccess.file_exists(str(path)):
			push_error("Downloaded path is missing: %s" % path)
			quit(1)
			return
	var level := Node3D.new()
	level.name = "MP_Isolated"
	get_root().add_child(level)
	var build_result := Builder.build(level, "mp_isolated/carrierstrike", paths)
	if not build_result.begins_with("Built mp_isolated Carrier Strike"):
		push_error("Downloaded layout did not build: %s" % build_result)
		quit(1)
		return
	print("DOWNLOAD OK: %s" % str(paths))
	quit(0)
