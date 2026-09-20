@tool
extends SceneTree

const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const TemplateAddons = preload("res://addons/bf6_gamemode_setup/template_addons.gd")
const MANIFEST := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/data/mp_atoll_conquest.layout.json"


func _init() -> void:
	var root := Node3D.new()
	root.name = "MP_Atoll"
	get_root().add_child(root)
	var message := Builder.build(root, "mp_atoll/conquest", {"manifest": MANIFEST})
	if not message.begins_with("Built "):
		_fail("Build failed: %s" % message)
		return
	var mode := Builder.find_build(root, "mp_atoll/conquest")
	var result := TemplateAddons.add_to(mode, root)
	if int(result.get("added", 0)) != 3:
		_fail("Expected three addon branches: %s" % str(result))
		return

	var expected_ids := {
		"TeamSwitcher/Switch1/InteractPoint": 998,
		"TeamSwitcher/Switch2/InteractPoint": 999,
		"AI Spawns/AI_Spawner - Team1": 901,
		"AI Spawns/AI_Spawner - Team2": 902,
		"EndGameCamera/FixedCamera": 950,
	}
	for path in expected_ids:
		var node := mode.get_node_or_null(path)
		if node == null or int(node.get("ObjId")) != int(expected_ids[path]):
			_fail("Missing or incorrect template node: %s" % path)
			return

	for path in ["TeamSwitcher", "TeamSwitcher/Switch1", "TeamSwitcher/Switch2",
			"AI Spawns", "EndGameCamera"]:
		var node := mode.get_node(path) as Node3D
		if node.position != Vector3.ZERO:
			_fail("Template branch is not at the origin: %s" % path)
			return

	for switch_index in range(1, 3):
		var switch_path := "TeamSwitcher/Switch%d" % switch_index
		var mannequin := mode.get_node("%s/MannequinRotation_01" % switch_path) as Node3D
		var interact := mode.get_node("%s/InteractPoint" % switch_path) as Node3D
		if not mannequin.position.is_equal_approx(TemplateAddons.TEAM_SWITCH_MANNEQUIN_OFFSET):
			_fail("Switch %d mannequin offset is incorrect" % switch_index)
			return
		if not interact.position.is_equal_approx(TemplateAddons.TEAM_SWITCH_INTERACT_OFFSET):
			_fail("Switch %d interaction offset is incorrect" % switch_index)
			return

	for team in range(1, 3):
		var ai := mode.get_node("AI Spawns/AI_Spawner - Team%d" % team)
		var hq := _find_descendant(mode, "TEAM_%d_HQ" % team)
		if hq == null or (ai.get("AlternateSpawns") as Array).size() != (hq.get("InfantrySpawns") as Array).size():
			_fail("Team %d AI spawns were not linked to its HQ" % team)
			return

	var existing_mannequin := mode.get_node("TeamSwitcher/Switch1/MannequinRotation_01") as Node3D
	var existing_interact := mode.get_node("TeamSwitcher/Switch1/InteractPoint") as Node3D
	existing_mannequin.position = Vector3.ZERO
	existing_interact.position = Vector3.ZERO
	var repaired := TemplateAddons.add_to(mode, root)
	if int(repaired.get("added", -1)) != 0 or not bool(repaired.get("changed", false)):
		_fail("Existing TeamSwitcher offsets were not repaired in place")
		return
	if not existing_mannequin.position.is_equal_approx(TemplateAddons.TEAM_SWITCH_MANNEQUIN_OFFSET) \
			or not existing_interact.position.is_equal_approx(TemplateAddons.TEAM_SWITCH_INTERACT_OFFSET):
		_fail("Repaired TeamSwitcher offsets are incorrect")
		return

	var repeated := TemplateAddons.add_to(mode, root)
	if int(repeated.get("added", -1)) != 0 or bool(repeated.get("changed", true)):
		_fail("Second import was not idempotent")
		return

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		_fail("Added template branches could not be packed")
		return
	print("TEMPLATE ADDONS OK")
	quit(0)


func _find_descendant(parent: Node, node_name: String) -> Node:
	if parent.name == node_name:
		return parent
	for child in parent.get_children():
		var found := _find_descendant(child, node_name)
		if found != null:
			return found
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
