@tool
extends SceneTree

const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const MANIFEST := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/data/mp_isolated_conquest.game.json"
const CARRIERS := "C:/Users/mwalt/Downloads/CarrierLayouts/CarrierLayouts/Tsuru Reef/Carrier_Layout_PortalAircraftcarriersConquest.glb"
const OUTPUT_DIR := "res://mods/BF6_GameMode_Setup"
const OUTPUT := OUTPUT_DIR + "/MP_Isolated_Conquest_Verified_Preview.tscn"


func _init() -> void:
	var source := load("res://levels/MP_Isolated.tscn") as PackedScene
	if source == null:
		push_error("Could not load MP_Isolated.tscn")
		quit(1)
		return
	var map_root := source.instantiate()
	get_root().add_child(map_root)
	var message := Builder.build(map_root, "mp_isolated/conquest", {
		"manifest": MANIFEST,
		"carriers": CARRIERS,
	})
	if not message.begins_with("Tsuru Reef Conquest built"):
		push_error(message)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := PackedScene.new()
	var pack_error := packed.pack(map_root)
	if pack_error != OK:
		push_error("Could not pack preview: %s" % error_string(pack_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(packed, OUTPUT)
	if save_error != OK:
		push_error("Could not save preview: %s" % error_string(save_error))
		quit(1)
		return
	print("PREVIEW OK: %s" % ProjectSettings.globalize_path(OUTPUT))
	quit(0)
