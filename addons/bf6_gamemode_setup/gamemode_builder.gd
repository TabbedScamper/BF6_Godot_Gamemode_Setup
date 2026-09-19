@tool
extends RefCounted

const CarrierPreview = preload("res://addons/bf6_gamemode_setup/carrier_preview.gd")

const BUILD_META := "bf6_gamemode_setup"
const CAMERA_META := "bf6_gamemode_setup_attachment"

const REQUIRED_SDK_SCENES := [
	"res://objects/gameplay/conquest/CapturePoint.tscn",
	"res://objects/gameplay/common/HQ_PlayerSpawner.tscn",
	"res://objects/gameplay/common/VehicleSpawner.tscn",
	"res://objects/entities/SpawnPoint.tscn",
	"res://objects/gameplay/common/CombatArea.tscn",
]

const EXCLUDED_PATHS := [
	"TeamSwitcher",
	"Obectives/FiringRange_Floor_01",
]


static func validate(root: Node, paths: Dictionary) -> String:
	if root == null:
		return "Open the MP_Isolated map scene first"
	if not FileAccess.file_exists(str(paths.get("scene", ""))):
		return "The downloaded Conquest scene is missing"
	if not FileAccess.file_exists(str(paths.get("carriers", ""))):
		return "The downloaded carrier layout is missing"
	for path in REQUIRED_SDK_SCENES:
		if not ResourceLoader.exists(path):
			return "This project is missing the Battlefield Portal SDK resource: %s" % path
	return ""


static func build(root: Node, layout_id: String, paths: Dictionary, replace_existing := false) -> String:
	if layout_id != "mp_isolated/conquest":
		return "This plugin version does not support %s" % layout_id
	var problem := validate(root, paths)
	if problem != "":
		return problem
	var existing := find_build(root, layout_id)
	if existing != null:
		if not replace_existing:
			(existing as Node3D).visible = true
			return "Tsuru Reef Conquest shown; the existing editable layout was preserved"
		root.remove_child(existing)
		existing.free()
		_remove_generated_cameras(root)
	elif root.get_node_or_null("Conquest") != null:
		return "A Conquest node already exists and was not created by this plugin"

	var packed := ResourceLoader.load(str(paths["scene"]), "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if packed == null:
		return "The selected Conquest reference scene could not be loaded"
	var source := packed.instantiate()
	if source == null:
		return "The selected Conquest reference scene could not be instantiated"
	var conquest := source.get_node_or_null("Prefab") as Node3D
	if conquest == null:
		source.free()
		return "The reference scene does not contain a Prefab gameplay root"

	conquest.owner = null
	source.remove_child(conquest)
	_prune_excluded_content(conquest)
	conquest.name = "Conquest"
	root.add_child(conquest)
	conquest.owner = root
	conquest.set_meta(BUILD_META, layout_id)
	_transfer_authored_owners(conquest, source, root)
	_repair_hq_vehicle_links(conquest)
	_repair_objective_vehicle_gating(conquest)
	_move_carrier_volumes(source, conquest, root)
	_move_deploy_camera(source, root)
	_add_carrier_preview(conquest, root, str(paths["carriers"]))
	source.free()
	return "Tsuru Reef Conquest built: gameplay, HQs, spawns, vehicles, volumes, cameras, AA defences, and carriers"


static func find_build(root: Node, layout_id: String) -> Node:
	if root == null:
		return null
	for child in root.get_children():
		if child.has_meta(BUILD_META) and str(child.get_meta(BUILD_META)) == layout_id:
			return child
	return null


static func hide_all(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is Node3D and child.has_meta(BUILD_META):
			(child as Node3D).visible = false


static func _prune_excluded_content(conquest: Node) -> void:
	for path in EXCLUDED_PATHS:
		var unwanted := conquest.get_node_or_null(path)
		if unwanted == null:
			continue
		var parent := unwanted.get_parent()
		if parent != null:
			parent.remove_child(unwanted)
		unwanted.free()


static func _transfer_authored_owners(node: Node, old_owner: Node, new_owner: Node) -> void:
	# Only promote nodes authored by the reference scene. SDK scene internals
	# remain owned by their scene instance and stay folded in the Scene dock.
	if node.owner == old_owner:
		node.owner = new_owner
	for child in node.get_children():
		_transfer_authored_owners(child, old_owner, new_owner)


static func _repair_hq_vehicle_links(conquest: Node) -> void:
	var vehicles := conquest.get_node_or_null("Vehicles")
	if vehicles == null:
		return
	for team in [1, 2]:
		var hq := conquest.get_node_or_null("TEAM_%d_HQ" % team)
		var folder := vehicles.get_node_or_null("Team%d" % team)
		if hq == null or folder == null:
			continue
		var links: Array[VehicleSpawner] = []
		for child in folder.get_children():
			if child is VehicleSpawner:
				child.set("SpawnIfMatchingTeam", true)
				child.set("MatchingTeam", team)
				links.append(child)
		hq.set("VehicleSpawnersEnabled", not links.is_empty())
		hq.set("VehicleSpawners", links)


static func _repair_objective_vehicle_gating(conquest: Node) -> void:
	# Objective-owned faction pairs use the layout's ID convention:
	# CapturePoint ObjId 20N -> VehicleSpawner ObjIds 6N0 (Team 1) and 6N1
	# (Team 2). Both occupy the same authored transform; the matching-team gate
	# makes the correct faction vehicle active for the team holding that point.
	var objectives := {}
	var objective_root := conquest.get_node_or_null("Obectives")
	if objective_root != null:
		for child in objective_root.get_children():
			if child is CapturePoint:
				objectives[int(child.get("ObjId")) % 100] = child
	var vehicles := conquest.get_node_or_null("Vehicles")
	if vehicles == null:
		return
	for child in vehicles.get_children():
		if not (child is VehicleSpawner):
			continue
		var object_id := int(child.get("ObjId"))
		if object_id < 600 or object_id > 699:
			continue
		var objective_index := int(object_id / 10) % 10
		if not objectives.has(objective_index):
			continue
		var team := (object_id % 10) + 1
		if team < 1 or team > 2:
			continue
		child.set("SpawnIfMatchingTeam", true)
		child.set("MatchingTeam", team)


static func _move_carrier_volumes(source: Node, conquest: Node3D, root: Node) -> void:
	var volumes: Array[Node] = []
	for child in source.get_children():
		if child is Node3D and String(child.name).begins_with("Carrier"):
			volumes.append(child)
	if volumes.is_empty():
		return
	var folder := Node3D.new()
	folder.name = "CarrierVolumes"
	conquest.add_child(folder)
	folder.owner = root
	for volume in volumes:
		volume.owner = null
		source.remove_child(volume)
		folder.add_child(volume)
		volume.owner = root
		_transfer_authored_owners(volume, source, root)


static func _move_deploy_camera(source: Node, root: Node) -> void:
	if root.find_child("DeployCam", true, false) != null:
		return
	var camera := source.get_node_or_null("Camera3D") as Node3D
	if camera == null:
		return
	camera.owner = null
	source.remove_child(camera)
	root.add_child(camera)
	camera.owner = root
	camera.set_meta(CAMERA_META, true)
	_transfer_authored_owners(camera, source, root)


static func _remove_generated_cameras(root: Node) -> void:
	var remove: Array[Node] = []
	for child in root.get_children():
		if child.has_meta(CAMERA_META):
			remove.append(child)
	for child in remove:
		root.remove_child(child)
		child.free()


static func _add_carrier_preview(conquest: Node3D, root: Node, carrier_path: String) -> void:
	var carriers := Node3D.new()
	carriers.name = "AircraftCarriers"
	carriers.set_script(CarrierPreview)
	carriers.set("source_path", carrier_path)
	conquest.add_child(carriers)
	carriers.owner = root
	carriers.call("rebuild")
