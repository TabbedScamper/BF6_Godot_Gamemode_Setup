@tool
extends RefCounted

const ADDONS_META := "bf6_andy_template_addons"
const SCENE_PATHS := {
	"ai_spawner": "res://objects/gameplay/ai/AI_Spawner.tscn",
	"interact_point": "res://objects/gameplay/common/InteractPoint.tscn",
	"mannequin": "res://objects/props/MannequinRotation_01.tscn",
	"fixed_camera": "res://objects/gameplay/common/FixedCamera.tscn",
}


static func validate(mode_root: Node) -> String:
	if mode_root == null:
		return "Build or select a game-mode layout first."
	for path in SCENE_PATHS.values():
		if not ResourceLoader.exists(path):
			return "This project is missing the Battlefield Portal SDK 1.4.3 resource: %s" % path
	return ""


static func add_to(mode_root: Node, scene_root: Node) -> Dictionary:
	var problem := validate(mode_root)
	if problem != "":
		return {"message": problem, "node": null, "added": 0}

	var added := 0
	var first_added: Node = null
	if mode_root.get_node_or_null("TeamSwitcher") == null:
		var team_switcher := _make_team_switcher()
		mode_root.add_child(team_switcher)
		_assign_owners(team_switcher, scene_root)
		first_added = team_switcher
		added += 1

	if mode_root.get_node_or_null("AI Spawns") == null:
		var ai_spawns := _make_ai_spawns(mode_root)
		mode_root.add_child(ai_spawns)
		_assign_owners(ai_spawns, scene_root)
		if first_added == null:
			first_added = ai_spawns
		added += 1

	if mode_root.get_node_or_null("EndGameCamera") == null:
		var end_camera := _make_end_game_camera()
		mode_root.add_child(end_camera)
		_assign_owners(end_camera, scene_root)
		if first_added == null:
			first_added = end_camera
		added += 1

	if added == 0:
		return {
			"message": "Andys Template Addons are already present; nothing was changed.",
			"node": mode_root.get_node_or_null("TeamSwitcher"),
			"added": 0,
		}
	return {
		"message": "Andys Template Addons added at (0, 0, 0): TeamSwitcher, AI Spawns, and EndGameCamera.",
		"node": first_added,
		"added": added,
	}


static func _make_team_switcher() -> Node3D:
	var root := Node3D.new()
	root.name = "TeamSwitcher"
	root.set_meta(ADDONS_META, true)
	for index in range(2):
		var switch := Node3D.new()
		switch.name = "Switch%d" % (index + 1)
		switch.set_meta(ADDONS_META, true)
		root.add_child(switch)

		var mannequin := _instantiate("mannequin", "MannequinRotation_01")
		switch.add_child(mannequin)

		var interact := _instantiate("interact_point", "InteractPoint")
		interact.set("ObjId", 998 + index)
		switch.add_child(interact)
	return root


static func _make_ai_spawns(mode_root: Node) -> Node3D:
	var root := Node3D.new()
	root.name = "AI Spawns"
	root.set_meta(ADDONS_META, true)
	for team in range(1, 3):
		var spawner := _instantiate("ai_spawner", "AI_Spawner - Team%d" % team)
		spawner.set("ObjId", 900 + team)
		root.add_child(spawner)
		_link_hq_spawns(spawner, _find_descendant(mode_root, "TEAM_%d_HQ" % team))
	return root


static func _make_end_game_camera() -> Camera3D:
	var root := Camera3D.new()
	root.name = "EndGameCamera"
	root.set_meta(ADDONS_META, true)
	var fixed := _instantiate("fixed_camera", "FixedCamera")
	fixed.set("ObjId", 950)
	root.add_child(fixed)
	return root


static func _instantiate(kind: String, node_name: String) -> Node3D:
	var packed := load(str(SCENE_PATHS[kind])) as PackedScene
	var node := packed.instantiate() as Node3D
	node.name = node_name
	node.transform = Transform3D.IDENTITY
	node.set_meta(ADDONS_META, true)
	return node


static func _assign_owners(node: Node, owner: Node) -> void:
	if node.has_meta(ADDONS_META):
		node.owner = owner
	for child in node.get_children():
		_assign_owners(child, owner)


static func _link_hq_spawns(spawner: Node, hq: Node) -> void:
	if hq == null:
		return
	var target: Array = spawner.get("AlternateSpawns")
	target.clear()
	var source: Array = hq.get("InfantrySpawns")
	for spawn in source:
		if spawn != null:
			target.append(spawn)
	spawner.set("AlternateSpawns", target)


static func _find_descendant(parent: Node, node_name: String) -> Node:
	if parent.name == node_name:
		return parent
	for child in parent.get_children():
		var found := _find_descendant(child, node_name)
		if found != null:
			return found
	return null
