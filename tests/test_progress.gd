@tool
extends SceneTree

const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const MANIFEST := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/data/mp_atoll_domination.layout.json"

var updates: Array = []


func _init() -> void:
	var root := Node3D.new()
	root.name = "MP_Atoll"
	get_root().add_child(root)
	var message := Builder.build(root, "mp_atoll/domination", {"manifest": MANIFEST}, false,
		_on_progress)
	if not message.begins_with("Built "):
		push_error("Build failed: %s" % message)
		quit(1)
		return
	if updates.size() < 2:
		push_error("Build did not report useful progress")
		quit(1)
		return
	var final: Dictionary = updates.back()
	if int(final.current) != int(final.total) or str(final.message) != "Game mode ready":
		push_error("Build progress did not complete: %s" % str(final))
		quit(1)
		return
	print("PROGRESS OK: %d updates, %s" % [updates.size(), str(final)])
	quit(0)


func _on_progress(message: String, current: int, total: int) -> void:
	updates.append({"message": message, "current": current, "total": total})
