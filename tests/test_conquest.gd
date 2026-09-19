@tool
extends SceneTree

const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")

var failures := 0


func _init() -> void:
	var root := Node3D.new()
	root.name = "MP_Isolated"
	get_root().add_child(root)
	var paths := {
		"scene": "res://bf6_gamemode_test/mp_isolated_conquest.tscn",
		"carriers": "res://bf6_gamemode_test/mp_isolated_conquest_carriers.glb",
	}
	var result := Builder.build(root, "mp_isolated/conquest", paths)
	check_true("build result", result.begins_with("Tsuru Reef Conquest built"))
	var conquest := Builder.find_build(root, "mp_isolated/conquest") as Node3D
	check_true("Conquest root", conquest != null)
	if conquest == null:
		quit(1)
		return

	for path in ["Play Area", "TEAM_1_HQ", "TEAM_2_HQ", "Vehicles",
			"Obectives", "AI_Spawners", "EndGameCamera", "AA-Defences",
			"CarrierVolumes", "AircraftCarriers"]:
		check_true("folder %s" % path, conquest.get_node_or_null(path) != null)
	check_equal("team switch excluded", conquest.get_node_or_null("TeamSwitcher"), null)
	check_equal("floor excluded", conquest.get_node_or_null("Obectives/FiringRange_Floor_01"), null)

	var captures := 0
	var capture_heights: Array[float] = []
	var vehicles := 0
	var objective_gated := 0
	var authored_physics := 0
	for node in walk(conquest):
		if node is CapturePoint:
			captures += 1
			capture_heights.append(float(node.get("CaptureArea").get("height")))
		if node is VehicleSpawner:
			vehicles += 1
			var object_id := int(node.get("ObjId"))
			if object_id >= 600 and object_id <= 699:
				objective_gated += 1
				check_equal("%s matching gate" % node.name, node.get("SpawnIfMatchingTeam"), true)
				check_equal("%s matching team" % node.name, int(node.get("MatchingTeam")), object_id % 10 + 1)
		if (node is CollisionObject3D or node is CollisionShape3D) and node.owner == root:
			authored_physics += 1
	capture_heights.sort()
	check_equal("capture count", captures, 9)
	check_equal("capture heights", capture_heights, [9.0, 20.0, 20.0, 25.0, 25.0, 30.0, 30.0, 30.0, 30.0])
	check_equal("vehicle count", vehicles, 38)
	check_equal("objective-gated vehicles", objective_gated, 8)
	check_equal("promoted physics nodes", authored_physics, 0)

	for team in [1, 2]:
		var hq = conquest.get_node("TEAM_%d_HQ" % team)
		check_equal("HQ%d infantry" % team, hq.get("InfantrySpawns").size(), 4)
		check_equal("HQ%d vehicles" % team, hq.get("VehicleSpawners").size(), 11)
		for vehicle in hq.get("VehicleSpawners"):
			check_equal("HQ%d %s gate" % [team, vehicle.name], vehicle.get("SpawnIfMatchingTeam"), true)
			check_equal("HQ%d %s team" % [team, vehicle.name], int(vehicle.get("MatchingTeam")), team)

	var combat = conquest.get_node("Play Area/CombatArea")
	check_true("infantry combat volume", combat.get("CombatVolume") != null)
	check_true("air combat volume", combat.get("SurroundingVolume") != null)
	check_equal("carrier volumes", conquest.get_node("CarrierVolumes").get_child_count(), 2)
	check_true("deploy camera", root.find_child("DeployCam", true, false) != null)
	check_near("Conquest elevation", conquest.position.y, -257.09125)
	check_near("Team 1 HQ elevation", world_transform(conquest.get_node("TEAM_1_HQ"), root).origin.y, 120.68048)
	check_near("aircraft elevation", world_transform(conquest.get_node("Vehicles/Team1/FA18-PAX2"), root).origin.y, 121.60626)

	var carrier_holder := conquest.get_node("AircraftCarriers") as Node3D
	var geometry := carrier_holder.get_node_or_null("Geometry")
	check_true("carrier geometry", geometry != null)
	if geometry != null:
		var meshes := 0
		var materials := 0
		var physics := 0
		for node in [geometry] + walk(geometry):
			if node is MeshInstance3D:
				meshes += 1
				var mesh := (node as MeshInstance3D).mesh
				if mesh != null:
					for surface in range(mesh.get_surface_count()):
						materials += 1 if mesh.surface_get_material(surface) != null else 0
			physics += 1 if node is CollisionObject3D or node is CollisionShape3D else 0
		check_equal("carrier mesh count", meshes, 1814)
		check_equal("carrier materials", materials, 0)
		check_equal("carrier physics", physics, 0)
		check_equal("carrier geometry owner", geometry.owner, null)

	print("ALL OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures else 0)


func walk(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child)
		result.append_array(walk(child))
	return result


func world_transform(node: Node3D, stop: Node) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != null and parent != stop:
		if parent is Node3D:
			result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result


func check_true(label: String, value: bool) -> void:
	check_equal(label, value, true)


func check_equal(label: String, got, expected) -> void:
	var ok: bool = got == expected
	if not ok:
		failures += 1
	print("%s %-32s got %s%s" % ["ok  " if ok else "FAIL", label, str(got), "" if ok else " expected %s" % str(expected)])


func check_near(label: String, got: float, expected: float) -> void:
	var ok := is_equal_approx(got, expected)
	if not ok:
		failures += 1
	print("%s %-32s got %s%s" % ["ok  " if ok else "FAIL", label, str(got), "" if ok else " expected %s" % str(expected)])

