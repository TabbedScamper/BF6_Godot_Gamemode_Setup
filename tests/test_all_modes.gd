@tool
extends SceneTree

const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const DATA_DIR := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/data"

var failures := 0


func _init() -> void:
	var directory := DirAccess.open(DATA_DIR)
	var files := directory.get_files() if directory != null else PackedStringArray()
	var tested := 0
	for filename in files:
		if not filename.ends_with(".layout.json"):
			continue
		var stem := filename.trim_suffix(".layout.json")
		var level := "mp_isolated" if stem.begins_with("mp_isolated_") else "mp_atoll"
		var mode := stem.trim_prefix(level + "_")
		var root := Node3D.new()
		root.name = level.to_upper()
		get_root().add_child(root)
		var message := Builder.build(root, "%s/%s" % [level, mode], {
			"manifest": "%s/%s" % [DATA_DIR, filename],
		}, false)
		if not message.begins_with("Built "):
			failures += 1
			print("FAIL ", filename, ": ", message)
		else:
			var built := Builder.find_build(root, "%s/%s" % [level, mode])
			if built == null:
				failures += 1
				print("FAIL ", filename, ": no built root")
			else:
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
