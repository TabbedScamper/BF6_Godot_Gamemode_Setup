@tool
extends SceneTree

const BUILDER_PATH := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/addons/bf6_gamemode_setup/gamemode_builder.gd"
const MANIFEST_PATH := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/data/mp_isolated_conquest.game.json"
const CARRIER_PATH := "C:/Users/mwalt/Downloads/CarrierLayouts/CarrierLayouts/Tsuru Reef/Carrier_Layout_PortalAircraftcarriersConquest.glb"
const CARRIER_SCRIPT_PATH := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/addons/bf6_gamemode_setup/carrier_preview.gd"

var failures := 0


func _init() -> void:
	var builder = load(BUILDER_PATH)
	check_true("builder loads", builder != null)
	if builder == null:
		quit(1)
		return
	var map_root := Node3D.new()
	map_root.name = "MP_Isolated"
	get_root().add_child(map_root)
	var result: String = builder.build(map_root, "mp_isolated/conquest", {
		"manifest": MANIFEST_PATH,
		"carriers": CARRIER_PATH,
		"carrier_script": CARRIER_SCRIPT_PATH,
	})
	check_true("build result", result.begins_with("Tsuru Reef Conquest built"))
	var conquest := map_root.get_node_or_null("Conquest")
	check_true("Conquest root", conquest != null)
	if conquest == null:
		print(result)
		quit(1)
		return
	check_vec3("game-to-SDK map origin", conquest.position, Vector3.ZERO, 0.0001)

	for path in ["Play Area/CombatArea", "Play Area/Sector", "TEAM_1_HQ", "TEAM_2_HQ",
			"Vehicles/Team1", "Vehicles/Team2", "Vehicles/Objectives", "Obectives",
			"Extras/StationaryEmplacements", "Extras/VehicleResupplys",
			"Extras/AutomaticAAs"]:
		check_true("node %s" % path, conquest.get_node_or_null(path) != null)
	check_equal("no TeamSwitcher", conquest.find_child("TeamSwitcher", true, false), null)

	var captures: Array = []
	var spawns: Array = []
	var vehicles: Array = []
	var collision_fluff := 0
	var mesh_fluff := 0
	for node in walk(conquest):
		if node.get_script() != null:
			match node.get_script().get_global_name():
				"CapturePoint": captures.append(node)
				"SpawnPoint": spawns.append(node)
				"VehicleSpawner": vehicles.append(node)
		if (node is CollisionObject3D or node is CollisionShape3D) and node.owner == map_root:
			collision_fluff += 1
		if node is MeshInstance3D and node.owner == map_root:
			mesh_fluff += 1
	check_equal("capture count", captures.size(), 9)
	check_equal("spawn count", spawns.size(), 155)
	check_equal("vehicle count", vehicles.size(), 52)
	check_equal("collision/static-body fluff", collision_fluff, 0)
	check_equal("mesh fluff", mesh_fluff, 0)
	check_true("official SpawnPoint scene", not str(spawns[0].scene_file_path).is_empty())
	check_true("official VehicleSpawner scene", not str(vehicles[0].scene_file_path).is_empty())
	var vehicle_census := {}
	for vehicle in vehicles:
		var selector := int(vehicle.get("VehicleType"))
		vehicle_census[selector] = int(vehicle_census.get(selector, 0)) + 1
		check_true("%s concrete type assigned" % vehicle.name, selector >= 0)
		check_true("%s retains retail group evidence" % vehicle.name,
			vehicle.has_meta("bf6_vehicle_group"))
		var skin: Node = null
		for child in vehicle.get_children():
			if child.has_meta("bf6_vehicle_skin"):
				skin = child
				break
		check_true("%s has direct SDK vehicle skin" % vehicle.name, skin != null)
		if skin != null:
			check_true("%s skin is a normal SDK scene instance" % vehicle.name,
				str(skin.scene_file_path).begins_with("res://objects/gameplay/vehicles/VEH_"))
			check_equal("%s skin stays editor-only" % vehicle.name, skin.owner, null)
		check_equal("%s auto-spawn game default" % vehicle.name, vehicle.get("P_AutoSpawnEnabled"), false)
		check_near("%s 45-second respawn" % vehicle.name, float(vehicle.get("P_DefaultRespawnTime")), 45.0, 0.001)
		check_equal("%s abandonment damage" % vehicle.name, vehicle.get("P_ApplyDamageToAbandonVehicle"), true)
	check_equal("retail category/faction vehicle census", vehicle_census,
		{3: 2, 5: 2, 7: 1, 9: 2, 10: 6, 12: 3, 13: 2, 14: 1,
		15: 1, 16: 1, 17: 2, 18: 1, 19: 2, 20: 3, 21: 10, 22: 4,
		23: 4, 24: 1, 26: 2, 27: 2})
	var capture_a_vehicle: Node3D = conquest.get_node("Vehicles/Objectives/A/A_Flyer60_Root49_Team1")
	check_equal("A Team1 Blockly vehicle ObjId", int(capture_a_vehicle.get("ObjId")), 600)
	check_equal("A Team2 Blockly vehicle ObjId", int(conquest.get_node(
		"Vehicles/Objectives/A/A_Vector_Root49_Team2").get("ObjId")), 601)
	var expected_vehicle_ids := {
		"B/B_M2Bradley_Root20_Team1": 610,
		"B/B_CV90_Root20_Team2": 611,
		"D/D_Marauder_Root41_Team1": 630,
		"D/D_Marauder_Pax_Root41_Team2": 631,
		"E/E_AH6M_Root59_Team1": 640,
		"E/E_AH6M_Pax_Root59_Team2": 641,
		"F/F_Marauder_Root48_Team1": 650,
		"F/F_Marauder_Pax_Root48_Team2": 651,
		"H/H_Marauder_Root50_Team1": 670,
		"H/H_Marauder_Pax_Root50_Team2": 671,
		"I/I_M2Bradley_Root40_Team1": 680,
		"I/I_CV90_Root40_Team2": 681,
	}
	for relative_path in expected_vehicle_ids:
		var spawner = conquest.get_node("Vehicles/Objectives/" + relative_path)
		check_equal("%s Blockly vehicle ObjId" % relative_path,
			int(spawner.get("ObjId")), int(expected_vehicle_ids[relative_path]))
	check_vec3("Frostbite right axis", capture_a_vehicle.basis.x,
		Vector3(0.9500397, 0.0, 0.3121278), 0.0001)
	check_vec3("Frostbite forward axis", capture_a_vehicle.basis.z,
		Vector3(-0.3121278, 0.0, 0.9500397), 0.0001)

	var expected_heights := {"A": 63.1137, "B": 50.0, "C": 60.0, "D": 50.0,
		"E": 10.0, "F": 50.0, "G": 50.0, "H": 60.0, "I": 50.0}
	var expected_zone_centers := {
		"A": Vector3(-660.6190, 94.7581, -312.8120),
		"B": Vector3(-611.6810, 103.2810, -184.2482),
		"C": Vector3(-876.2536, 93.9396, -277.0894),
		"D": Vector3(-811.9929, 102.2021, -7.7625),
		"E": Vector3(-1067.5468, 105.9482, -11.7655),
		"F": Vector3(-809.0240, 102.0917, 220.5761),
		"G": Vector3(-940.8962, 92.2348, 328.5469),
		"H": Vector3(-858.5298, 99.9737, 506.9178),
		"I": Vector3(-634.0685, 95.8017, 424.5481),
	}
	for index in range(9):
		var letter := String.chr(65 + index)
		var capture = conquest.get_node("Obectives/CapturePoint%s" % letter)
		check_equal("%s ObjId" % letter, int(capture.get("ObjId")), 200 + index)
		check_vec3("%s translation-only capture parent" % letter, capture.basis.x, Vector3.RIGHT, 0.0001)
		check_near("%s volume height" % letter, float(capture.get("CaptureArea").get("height")), expected_heights[letter], 0.001)
		check_vec3("%s authored map-space zone center" % letter,
			scene_position(capture.get("CaptureArea"), map_root), expected_zone_centers[letter], 0.001)
		check_true("%s has spawns" % letter, capture.get("InfantrySpawnPoints_Team1").size() > 0)
		check_equal("%s shared team links" % letter, capture.get("InfantrySpawnPoints_Team1"), capture.get("InfantrySpawnPoints_Team2"))
		var capture_zones := 0
		for child in capture.get_children():
			if str(child.name).begins_with("Area-"):
				capture_zones += 1
				check_vec3("%s zone uses SDK-local basis" % letter, (child as Node3D).basis.x, Vector3.RIGHT, 0.0001)
				check_vec3("%s zone uses SDK-local front" % letter, (child as Node3D).basis.z, Vector3.BACK, 0.0001)
		check_equal("%s one bound capture zone" % letter, capture_zones, 1)
	check_vec3("Capture A SDK position", scene_position(conquest.get_node("Obectives/CapturePointA"), map_root),
		Vector3(-658.7562, 101.8947, -310.9256), 0.001)
	check_vec3("Capture B SDK position", scene_position(conquest.get_node("Obectives/CapturePointB"), map_root),
		Vector3(-608.7454, 103.5782, -184.9118), 0.001)

	check_equal("HQ1 spawn count", conquest.get_node("TEAM_1_HQ").get("InfantrySpawns").size(), 4)
	check_equal("HQ2 spawn count", conquest.get_node("TEAM_2_HQ").get("InfantrySpawns").size(), 4)
	check_equal("HQ1 vehicle count", conquest.get_node("TEAM_1_HQ").get("VehicleSpawners").size(), 10)
	check_equal("HQ2 vehicle count", conquest.get_node("TEAM_2_HQ").get("VehicleSpawners").size(), 10)
	check_near("HQ1 exact Y", conquest.get_node("TEAM_1_HQ").position.y, 107.832901, 0.0001)
	check_near("HQ2 exact Y", conquest.get_node("TEAM_2_HQ").position.y, 102.50631, 0.0001)

	var combat = conquest.get_node("Play Area/CombatArea")
	check_true("infantry combat volume", combat.get("CombatVolume") != null)
	check_true("aircraft combat volume", combat.get("SurroundingVolume") != null)
	check_near("air volume authored plane", combat.get("SurroundingVolume").position.y, 450.019806, 0.001)
	check_equal("stationary count", conquest.get_node("Extras/StationaryEmplacements").get_child_count(), 3)
	var stationary_census := {}
	for stationary in conquest.get_node("Extras/StationaryEmplacements").get_children():
		var stationary_type := int(stationary.get("StationaryEmplacementType"))
		stationary_census[stationary_type] = int(stationary_census.get(stationary_type, 0)) + 1
		check_equal("%s auto-spawn enabled" % stationary.name,
			stationary.get("P_AutoSpawnEnabled"), true)
		var stationary_skin: Node = null
		for child in stationary.get_children():
			if child.has_meta("bf6_vehicle_skin"):
				stationary_skin = child
				break
		check_true("%s has direct SDK emplacement skin" % stationary.name,
			stationary_skin != null)
		if stationary_skin != null:
			check_equal("%s skin stays editor-only" % stationary.name,
				stationary_skin.owner, null)
	check_equal("retail stationary class -> SDK type census", stationary_census, {0: 2, 2: 1})
	check_equal("resupply count", conquest.get_node("Extras/VehicleResupplys").get_child_count(), 2)
	for station in conquest.get_node("Extras/VehicleResupplys").get_children():
		var station_model: Node = null
		for child in station.get_children():
			if child.has_meta("bf6_vehicle_skin"):
				station_model = child
				break
		check_true("%s has installed-game station model" % station.name,
			station_model != null)
		if station_model != null:
			check_equal("%s model stays editor-only" % station.name,
				station_model.owner, null)
			check_equal("%s uses packaged untextured geometry" % station.name,
				str(station_model.scene_file_path),
				"res://addons/bf6_gamemode_setup/assets/VehicleResupplyStation_Game.tscn")
	check_equal("automatic AA count", conquest.get_node("Extras/AutomaticAAs").get_child_count(), 2)
	check_equal("standard Conquest has no carrier preview",
		conquest.get_node_or_null("AircraftCarriers"), null)
	var automatic_aas := conquest.get_node("Extras/AutomaticAAs").get_children()
	for aa in automatic_aas:
		check_true("%s protection area assigned" % aa.name,
			aa.get("ProtectionAreaVolume") != null)
		var hq_key := str(aa.get_meta("bf6_protection_hq", ""))
		check_true("%s linked to verified HQ" % aa.name, hq_key in ["HQ1", "HQ2"])
		var owner_team := int(aa.get("OwnerTeam"))
		check_equal("%s owner team" % aa.name, owner_team, 1 if hq_key == "HQ1" else 2)
		check_true("%s team visible in tree" % aa.name,
			str(aa.name).contains("Team%d" % owner_team))
		check_true("%s stable readable name" % aa.name, not str(aa.name).begins_with("@"))
		var hq_node_name := "TEAM_1_HQ" if hq_key == "HQ1" else "TEAM_2_HQ"
		check_equal("%s uses nearest HQ area" % aa.name,
			aa.get("ProtectionAreaVolume"), conquest.get_node(hq_node_name).get("HQArea"))

	print("ALL OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures else 0)


func walk(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child)
		result.append_array(walk(child))
	return result


func scene_position(node: Node3D, stop: Node) -> Vector3:
	var result := node.transform
	var parent := node.get_parent()
	while parent != null and parent != stop:
		if parent is Node3D:
			result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result.origin


func check_true(label: String, value: bool) -> void:
	check_equal(label, value, true)


func check_equal(label: String, got, expected) -> void:
	var ok: bool = got == expected
	if not ok:
		failures += 1
	print("%s %-32s got %s%s" % ["ok  " if ok else "FAIL", label, str(got), "" if ok else " expected %s" % str(expected)])


func check_near(label: String, got: float, expected: float, tolerance: float) -> void:
	var ok := absf(got - expected) <= tolerance
	if not ok:
		failures += 1
	print("%s %-32s got %s%s" % ["ok  " if ok else "FAIL", label, str(got), "" if ok else " expected %s" % str(expected)])


func check_vec3(label: String, got: Vector3, expected: Vector3, tolerance: float) -> void:
	var ok := got.distance_to(expected) <= tolerance
	if not ok:
		failures += 1
	print("%s %-32s got %s%s" % ["ok  " if ok else "FAIL", label, str(got), "" if ok else " expected %s" % str(expected)])
