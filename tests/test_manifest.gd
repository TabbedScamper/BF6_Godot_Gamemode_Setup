extends SceneTree

const Manifest = preload("res://addons/bf6_gamemode_setup/gamemode_manifest.gd")


func _init() -> void:
	var manifest := Manifest.new()
	if not manifest.load_file("res://data/mp_isolated_conquest.game.json"):
		push_error(manifest.error)
		quit(1)
		return
	if manifest.gems("gem_hq").size() != 2:
		push_error("HQ query failed")
		quit(1)
		return
	if manifest.gems("gem_capturepoint").size() != 9:
		push_error("capture query failed")
		quit(1)
		return
	if manifest.gems("gem_vehiclespawner").size() != 40:
		push_error("vehicle query failed")
		quit(1)
		return
	print("MANIFEST OK: 271 entities, 2 HQs, 9 captures, 40 vehicles, 155 spawns")
	quit(0)
