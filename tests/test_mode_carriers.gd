@tool
extends SceneTree

const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const REPO := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup"
const CARRIERS := {
	"mp_isolated/carrierstrike": "C:/BF6_Dev/CarrierLayouts/Tsuru Reef/Carrier_Layout_Carrierstrike.glb",
	"mp_atoll/breakthrough": "C:/BF6_Dev/CarrierLayouts/Wake Island/Carrier_Layout_Breakthrough.glb",
	"mp_atoll/conquest": "C:/BF6_Dev/CarrierLayouts/Wake Island/Carrier_Layout_Conquest.glb",
	"mp_atoll/escalation": "C:/BF6_Dev/CarrierLayouts/Wake Island/Carrier_Layout_Escalation.glb",
}


func _init() -> void:
	var failures := 0
	for key in CARRIERS:
		var parts := str(key).split("/")
		var root := Node3D.new()
		root.name = parts[0]
		get_root().add_child(root)
		var message := Builder.build(root, key, {
			"manifest": "%s/data/%s_%s.layout.json" % [REPO, parts[0], parts[1]],
			"carriers": CARRIERS[key],
		}, false)
		var built := Builder.find_build(root, key)
		var carrier := built.get_node_or_null("Aircraft Carriers (hide to disable preview)") if built else null
		var geometry := carrier.get_node_or_null("Geometry") if carrier else null
		if not message.begins_with("Built ") or geometry == null:
			failures += 1
			print("FAIL ", key, ": ", message)
		else:
			print("ok   ", key, " carrier geometry loaded")
		root.queue_free()
		await process_frame
	print("MODE CARRIERS: ", CARRIERS.size(), " tested, ", failures, " failures")
	quit(1 if failures else 0)
