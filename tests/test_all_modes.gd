@tool
extends SceneTree

const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const DATA_DIR := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/data"
const CATALOG := DATA_DIR + "/layout_catalog.json"
const CONQUEST_IDENTITIES := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/tests/conquest_objective_identities.json"
const VEHICLE_CLASS_TYPES := {
	0: [13, 9], 1: [17, 3], 2: [0, 1], 3: [2, 4], 4: [16, 14],
	5: [15, 18], 6: [8, 6], 7: [5, 19], 8: [10], 9: [12, 20],
	10: [11], 11: [21], 12: [7, 24], 13: [22, 23], 14: [26, 27],
	15: [30, 31], 16: [28, 29], 17: [16], 18: [15], 19: [14],
	20: [18], 21: [28], 22: [30], 23: [31],
}

var failures := 0


func _init() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var conquest_identities: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(CONQUEST_IDENTITIES))
	var tested := 0
	for level in (catalog.get("maps", {}) as Dictionary):
		var map: Dictionary = catalog.maps[level]
		for mode_value in map.get("modes", []):
			var mode := str(mode_value)
			var filename := "%s_%s.layout.json" % [level, mode]
			var root := Node3D.new()
			root.name = str(level).to_upper()
			get_root().add_child(root)
			var key := "%s/%s" % [level, mode]
			var message := Builder.build(root, key, {
				"manifest": "%s/%s" % [DATA_DIR, filename],
			}, false)
			if not message.begins_with("Built "):
				failures += 1
				print("FAIL ", filename, ": ", message)
			else:
				var built := Builder.find_build(root, key)
				if built == null:
					failures += 1
					print("FAIL ", filename, ": no built root")
				else:
					var manifest: Dictionary = JSON.parse_string(
						FileAccess.get_file_as_string("%s/%s" % [DATA_DIR, filename]))
					var actual_special := _count_meta(built, "bf6_unmapped_role", "gem_specialcombatarea")
					if actual_special != 0:
						failures += 1
						print("FAIL ", filename, ": standalone special-area nodes ", actual_special)
					var expected_vehicles := int((manifest.get("counts", {}) as Dictionary).get("vehicles", 0))
					var actual_vehicles := _count_meta_key(built, "bf6_source_vehicle_record")
					if actual_vehicles != expected_vehicles:
						failures += 1
						print("FAIL ", filename, ": represented vehicle rows ", actual_vehicles, "/", expected_vehicles)
					var expected_linked_spawns := int((manifest.get("counts", {}) as Dictionary).get("spawns", 0)) \
						if mode in ["conquest", "carrierstrike", "escalation"] else 0
					if expected_linked_spawns == 0 and mode in ["conquest", "carrierstrike",
							"escalation", "domination", "breakthrough", "operations", "koth",
							"kingofthehill", "strikepoint"]:
						for object_value in manifest.get("objects", []):
							var object := object_value as Dictionary
							if int(object.get("role", 0)) == 1 and int(object.get("flag", -1)) >= 0:
								expected_linked_spawns += 1
					var actual_linked_spawns := _count_assigned_spawns(built)
					if actual_linked_spawns < expected_linked_spawns:
						failures += 1
						print("FAIL ", filename, ": assigned spawn hierarchy ", actual_linked_spawns, "/", expected_linked_spawns)
					var bad_hq_vehicle := _find_hq_vehicle_without_auto_spawn(built)
					if bad_hq_vehicle != "":
						failures += 1
						print("FAIL ", filename, ": HQ vehicle auto-spawn disabled ", bad_hq_vehicle)
					var bad_respawn_vehicle := _find_vehicle_without_45_second_respawn(built)
					if bad_respawn_vehicle != "":
						failures += 1
						print("FAIL ", filename, ": vehicle respawn is not 45 seconds ", bad_respawn_vehicle)
					var bad_required_auto_spawn := _find_required_auto_spawn_disabled(built)
					if bad_required_auto_spawn != "":
						failures += 1
						print("FAIL ", filename, ": required auto-spawn disabled ",
							bad_required_auto_spawn)
					if level == "mp_capstone" and mode == "conquest":
						_check_capstone_vehicle_mapping(built, filename)
						if _count_name_prefix(built, "CapturePoint") != 6:
							failures += 1
							print("FAIL ", filename, ": Capstone must have six retail capture points")
						if built.get_node_or_null("Play Area/OutOfBounds/AreaTrigger_OutOfBounds_Cliff") == null:
							failures += 1
							print("FAIL ", filename, ": Capstone cliff out-of-bounds trigger missing")
						_check_combat_area(built, filename,
							"fd455bd8-e5f7-4bec-8fd7-cb171926fa58",
							"7da73b7d-0f84-4842-9afc-d9fef5abde13")
						_check_capstone_flyer_overrides(built, filename)
						_check_capstone_objective_tanks(built, filename)
					if mode == "conquest" and conquest_identities.has(level):
						_check_conquest_flag_mapping(built, manifest, filename,
							conquest_identities[level] as Array)
					if mode == "rush":
						_check_rush_contract(built, manifest, filename)
					if mode == "breakthrough":
						_check_breakthrough_sectors(built, manifest, filename)
					_check_deploy_cameras(built, manifest, filename)
					if level == "mp_atoll" and mode == "conquest":
						_check_atoll_hq_areas(built, filename)
						_check_combat_area(built, filename,
							"0139a1cf-8515-44a9-b56e-adf3bbe57833",
							"adf6e4b1-5197-4dda-a6d8-3e52178fcb63")
						_check_faction_swap_roundtrip(root, built, key, filename)
					if level == "mp_eastwood" and mode == "conquest":
						_check_combat_area(built, filename,
							"3da39332-bedc-47b2-ae21-1dac5dc0be79",
							"bef00599-50ef-4b3f-b082-9c90a525a33e")
						if _count_scene(built.get_node("Play Area"), "OBBVolume.tscn") != 0:
							failures += 1
							print("FAIL ", filename,
								": unowned generated OBBs leaked into Play Area")
					if level == "mp_battery" and mode == "conquest":
						_check_combat_area(built, filename,
							"edb24581-1ad9-48b0-9a4c-907f9fde7f50")
					if mode == "conquest" and level in ["mp_dumbo", "mp_badlands"]:
						_check_no_loose_conquest_boundaries(built, filename)
					if level == "mp_aftermath" and mode == "conquest":
						_check_aftermath_hq_areas(built, filename)
					if mode == "conquest" and level in ["mp_abbasid", "mp_battery"] and \
							built.get_node_or_null("Vehicles/Unassigned") != null:
						failures += 1
						print("FAIL ", filename, ": HQ-adjacent unresolved vehicles leaked to Unassigned")
					if mode in ["conquest", "domination", "carrierstrike"] and \
							_count_name_prefix(built, "CapturePoint") > 0:
						_check_sector_order(built, filename)
					_check_mode_objective_contract(built, manifest, filename, mode)
					var generated_name := _find_generated_name(built)
					if generated_name != "":
						failures += 1
						print("FAIL ", filename, ": generated node name ", generated_name)
					_check_automatic_aa_teams(built, filename)
					_check_automatic_aa_protection_bindings(built, manifest, filename)
					_check_objective_vehicle_names(built, filename)
					_check_exact_vehicle_selectors(built, filename)
					_check_objective_vehicle_faction_pairs(built, filename)
					_check_capture_provenance(built, manifest, filename)
					_check_hq_teams(built, filename)
					_check_hq_insertion_spawns(built, manifest, filename)
					_check_vehicle_folders(built, filename)
					_check_objective_vehicle_ids(built, filename)
					_check_no_empty_generated_folders(built, filename)
					_check_root_order(built, filename)
					_check_objective_tree_order(built, filename)
					_check_expected_flight_boundary(built, manifest, filename)
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


func _count_meta(node: Node, key: String, value: String) -> int:
	var count := 1 if node.has_meta(key) and str(node.get_meta(key)) == value else 0
	for child in node.get_children():
		count += _count_meta(child, key, value)
	return count


func _count_meta_key(node: Node, key: String) -> int:
	var count := 1 if node.has_meta(key) else 0
	for child in node.get_children():
		count += _count_meta_key(child, key)
	return count


func _check_capture_provenance(built: Node, manifest: Dictionary,
		filename: String) -> void:
	for value in manifest.get("objects", []):
		var row := value as Dictionary
		var binding := row.get("capture_binding", {}) as Dictionary
		if binding.is_empty():
			continue
		var guid := str(binding.get("instance_guid", ""))
		var capture := _find_meta_value(built, "bf6_capture_instance_guid", guid) as Node3D
		if capture == null:
			failures += 1
			print("FAIL ", filename, ": missing capture provenance ", guid)
			continue
		if int(capture.get_meta("bf6_capture_root_order", -1)) != \
				int(binding.get("root_order", -2)):
			failures += 1
			print("FAIL ", filename, ": capture root order changed ", guid)
		var transform := binding.get("transform", []) as Array
		if transform.size() == 12:
			var expected := Vector3(float(transform[9]), float(transform[10]), float(transform[11]))
			if capture.global_position.distance_to(expected) > 0.001:
				failures += 1
				print("FAIL ", filename, ": capture origin changed ", guid, " ",
					capture.global_position, "/", expected)


func _find_meta_value(node: Node, key: String, value: String) -> Node:
	if node.has_meta(key) and str(node.get_meta(key)) == value:
		return node
	for child in node.get_children():
		var found := _find_meta_value(child, key, value)
		if found != null:
			return found
	return null


func _check_hq_teams(node: Node, filename: String) -> void:
	if node.get("HQArea") != null:
		var team := int(node.get("Team"))
		if team not in [1, 2]:
			failures += 1
			print("FAIL ", filename, ": invalid HQ team ", team, " on ", node.name)
	for child in node.get_children():
		_check_hq_teams(child, filename)


func _check_vehicle_folders(root: Node, filename: String) -> void:
	_check_vehicle_folder_node(root, root, filename)


func _check_vehicle_folder_node(root: Node, node: Node, filename: String) -> void:
	var relative := str(root.get_path_to(node))
	if node.has_meta("bf6_runtime_association"):
		var association := str(node.get_meta("bf6_runtime_association"))
		var expected := "Vehicles/HQ/" if association.begins_with("HQ") else \
			"Vehicles/Objectives/" if association.begins_with("CapturePoint") else ""
		if expected != "" and not relative.begins_with(expected):
			failures += 1
			print("FAIL ", filename, ": vehicle folder mismatch ", relative,
				" for ", association)
	var scene_name := str(node.scene_file_path).get_file()
	if scene_name == "StationaryEmplacementSpawner.tscn" and \
			not relative.begins_with("Emplacements/"):
		failures += 1
		print("FAIL ", filename, ": emplacement outside category ", relative)
	if scene_name == "VEH_Stationary_AutomaticAA.tscn" and \
			not relative.begins_with("AA-Defences/"):
		failures += 1
		print("FAIL ", filename, ": automatic AA outside category ", relative)
	for child in node.get_children():
		_check_vehicle_folder_node(root, child, filename)


func _check_objective_vehicle_ids(root: Node, filename: String) -> void:
	_check_objective_vehicle_id_node(root, root, filename)


func _check_objective_vehicle_id_node(root: Node, node: Node, filename: String) -> void:
	var association := str(node.get_meta("bf6_runtime_association", ""))
	if association.begins_with("CapturePoint") and node.get("ObjId") != null:
		var flag := association.unicode_at(12) - "A".unicode_at(0)
		var team := 1 if association.ends_with("Team1") else \
			2 if association.ends_with("Team2") else 0
		var object_id := int(node.get("ObjId"))
		if team == 0:
			if object_id != -1 or not bool(node.get("P_AutoSpawnEnabled")):
				failures += 1
				print("FAIL ", filename, ": shared objective vehicle contract ", node.name)
		else:
			var minimum := 600 + flag * 10 + (5 if team == 2 else 0)
			if object_id == -1 and bool(node.get("P_AutoSpawnEnabled")):
				pass # More than five authored pads: Portal's reserved range is exhausted.
			elif object_id < minimum or object_id > minimum + 4:
				failures += 1
				print("FAIL ", filename, ": objective vehicle ObjId ", object_id,
					" outside ", minimum, "-", minimum + 4)
	for child in node.get_children():
		_check_objective_vehicle_id_node(root, child, filename)


func _check_no_empty_generated_folders(node: Node, filename: String) -> void:
	if node.has_meta("bf6_generated_folder") and node.get_child_count() == 0:
		failures += 1
		print("FAIL ", filename, ": empty generated folder ", node.get_path())
	for child in node.get_children():
		_check_no_empty_generated_folders(child, filename)


func _check_root_order(root: Node, filename: String) -> void:
	var ranks := {"Play Area": 0, "Objectives": 3, "Spawns": 4, "Vehicles": 5,
		"Emplacements": 6, "Resupply": 7, "AA-Defences": 8, "Extras": 9,
		"Aircraft Carriers (hide to disable preview)": 10}
	var previous := -1
	for child in root.get_children():
		var rank := int(ranks.get(str(child.name), 100))
		if str(child.name).begins_with("TEAM_1_HQ"):
			rank = 1
		elif str(child.name).begins_with("TEAM_2_HQ"):
			rank = 2
		if rank < previous:
			failures += 1
			print("FAIL ", filename, ": root hierarchy order at ", child.name)
			return
		previous = rank


func _check_faction_swap_roundtrip(map_root: Node, layout: Node, key: String,
		filename: String) -> void:
	var before := _faction_state(layout)
	Builder.swap_factions(map_root, key)
	var swapped := _faction_state(layout)
	Builder.swap_factions(map_root, key)
	var restored := _faction_state(layout)
	if before == swapped:
		failures += 1
		print("FAIL ", filename, ": faction swap changed no authored state")
	if before != restored:
		failures += 1
		print("FAIL ", filename, ": faction swap is not reversible")


func _faction_state(root: Node) -> Array:
	var rows: Array = []
	_collect_faction_state(root, root, rows)
	rows.sort()
	return rows


func _collect_faction_state(root: Node, node: Node, rows: Array) -> void:
	var values: Array = [str(root.get_path_to(node)), str(node.name)]
	for property in ["Team", "AltTeam", "OwnerTeam", "MatchingTeam", "VehicleType", "ObjId"]:
		if node.get(property) != null:
			values.append("%s=%s" % [property, str(node.get(property))])
	if values.size() > 2 or str(node.name).contains("Team") or str(node.name).contains("TEAM_"):
		rows.append("|".join(values))
	for child in node.get_children():
		_collect_faction_state(root, child, rows)


func _check_objective_tree_order(root: Node, filename: String) -> void:
	var objectives := root.get_node_or_null("Objectives")
	if objectives == null:
		return
	var previous := ""
	for child in objectives.get_children():
		if not str(child.name).begins_with("CapturePoint"):
			continue
		var current := str(child.name)
		if previous != "" and current < previous:
			failures += 1
			print("FAIL ", filename, ": objective scene tree is not alphabetical")
			return
		previous = current
	var vehicle_objectives := root.get_node_or_null("Vehicles/Objectives")
	if vehicle_objectives == null:
		return
	previous = ""
	for child in vehicle_objectives.get_children():
		var current := str(child.name)
		if previous != "" and current < previous:
			failures += 1
			print("FAIL ", filename, ": objective vehicle folders are not alphabetical")
			return
		previous = current


func _check_expected_flight_boundary(root: Node, manifest: Dictionary,
		filename: String) -> void:
	if str((manifest.get("source", {}) as Dictionary).get("mode", "")) != "conquest":
		return
	var air_classes := [4, 5, 6, 7, 12, 15, 16, 17, 18, 19, 20, 21, 22, 23]
	var has_aircraft := false
	for value in manifest.get("objects", []):
		var row := value as Dictionary
		if int(row.get("role", 0)) == 6 and air_classes.has(
				int((row.get("raw", {}) as Dictionary).get("gem_selector", -1))):
			has_aircraft = true
	if not has_aircraft:
		return
	var combat := root.get_node_or_null("Play Area/CombatArea")
	if combat == null or combat.get("SurroundingVolume") == null:
		failures += 1
		print("FAIL ", filename, ": aircraft layout has no surrounding flight boundary")


func _count_name_prefix(node: Node, prefix: String) -> int:
	var count := 1 if str(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_name_prefix(child, prefix)
	return count


func _count_assigned_spawns(node: Node, inside_anchor := false) -> int:
	var is_anchor := inside_anchor or node.name.begins_with("CapturePoint") or \
		node.name.begins_with("TEAM_")
	var count := 1 if is_anchor and node.has_meta("bf6_spawn_team") else 0
	for child in node.get_children():
		count += _count_assigned_spawns(child, is_anchor)
	return count


func _find_hq_vehicle_without_auto_spawn(node: Node) -> String:
	if node.name.begins_with("TEAM_"):
		var spawners = node.get("VehicleSpawners")
		if spawners != null:
			for spawner in spawners:
				if not bool(spawner.get("P_AutoSpawnEnabled")):
					return str(spawner.name)
	for child in node.get_children():
		var found := _find_hq_vehicle_without_auto_spawn(child)
		if found != "":
			return found
	return ""


func _find_vehicle_without_45_second_respawn(node: Node) -> String:
	if str(node.scene_file_path).get_file() == "VehicleSpawner.tscn" \
			and not is_equal_approx(float(node.get("P_DefaultRespawnTime")), 45.0):
		return str(node.name)
	for child in node.get_children():
		var found := _find_vehicle_without_45_second_respawn(child)
		if found != "":
			return found
	return ""


func _find_required_auto_spawn_disabled(node: Node) -> String:
	var scene_name := str(node.scene_file_path).get_file()
	var required := scene_name == "StationaryEmplacementSpawner.tscn" or \
		(scene_name == "VehicleSpawner.tscn" and int(node.get("VehicleType")) == -1)
	if required and not bool(node.get("P_AutoSpawnEnabled")):
		return str(node.name)
	for child in node.get_children():
		var found := _find_required_auto_spawn_disabled(child)
		if found != "":
			return found
	return ""


func _find_generated_name(node: Node) -> String:
	if str(node.name).to_lower().begins_with("@spawn"):
		return str(node.name)
	for child in node.get_children():
		var found := _find_generated_name(child)
		if found != "":
			return found
	return ""


func _check_automatic_aa_teams(node: Node, filename: String) -> void:
	if str(node.scene_file_path).get_file() == "VEH_Stationary_AutomaticAA.tscn":
		var team := int(node.get("OwnerTeam"))
		if str(node.name).begins_with("@"):
			failures += 1
			print("FAIL ", filename, ": automatic AA has generated name ", node.name)
		if team not in [1, 2]:
			failures += 1
			print("FAIL ", filename, ": automatic AA has no team ", node.name)
		if not str(node.name).contains("Team%d" % team):
			failures += 1
			print("FAIL ", filename, ": automatic AA name hides team ", node.name)
	for child in node.get_children():
		_check_automatic_aa_teams(child, filename)


func _check_objective_vehicle_names(node: Node, filename: String) -> void:
	if node.has_meta("bf6_runtime_association"):
		var association := str(node.get_meta("bf6_runtime_association"))
		if association.begins_with("CapturePoint"):
			var expected_objective := association.get_slice(" ", 0).trim_prefix("CapturePoint")
			var expected_team := association.get_slice(" / ", 1)
			var visible := str(node.name)
			if not visible.begins_with("Objective_%s_" % expected_objective) or \
					not visible.contains("_%s_" % expected_team):
				failures += 1
				print("FAIL ", filename, ": objective vehicle name hides association ",
					visible, " -> ", association)
	for child in node.get_children():
		_check_objective_vehicle_names(child, filename)


func _check_rush_contract(root: Node, manifest: Dictionary, filename: String) -> void:
	if _count_scene(root, "CapturePoint.tscn") != 0:
		failures += 1
		print("FAIL ", filename, ": Rush contains CapturePoint objectives")
	var sectors := root.get_node_or_null("Objectives/Sectors")
	var authored_mcoms := int((manifest.get("counts", {}) as Dictionary).get("mcoms", 0))
	var authored_sectors := 0
	for value in manifest.get("elements", []):
		var element := value as Dictionary
		if str(element.get("gem", "")) == "gem_sector" and \
				not str(element.get("layer", "")).ends_with("/gameplay_global"):
			authored_sectors += 1
	# Sector.MCOMs is the live Portal contract. Retail may retain dormant or
	# alternate MCOM GEM placements (MP_Tungsten has 13 unique records while
	# its Rush layer exposes eight live slots), so raw placement count is only
	# an upper bound.
	var expected_mcoms := mini(authored_mcoms, authored_sectors * 2) \
		if authored_sectors > 0 else authored_mcoms
	if expected_mcoms > 0 and sectors == null:
		failures += 1
		print("FAIL ", filename, ": Rush MCOM objectives are not under Objectives/Sectors")
		return
	var seen_mcoms := 0
	if sectors != null:
		for sector_index in range(sectors.get_child_count()):
			var sector := sectors.get_child(sector_index)
			var mcoms = sector.get("MCOMs")
			if mcoms == null or mcoms.size() < 1 or mcoms.size() > 2:
				failures += 1
				print("FAIL ", filename, ": invalid Rush MCOM sector ", sector.name)
				continue
			for slot in range(mcoms.size()):
				var mcom := mcoms[slot] as Node
				seen_mcoms += 1
				var expected_name := "MCOM-%s" % ("A" if slot == 0 else "B")
				if str(mcom.name) != expected_name:
					failures += 1
					print("FAIL ", filename, ": Rush MCOM slot name ", mcom.name)
	if seen_mcoms != expected_mcoms:
		failures += 1
		print("FAIL ", filename, ": Rush MCOM count ", seen_mcoms, "/", expected_mcoms)
	if _has_capture_vehicle_association(root):
		failures += 1
		print("FAIL ", filename, ": Rush vehicle assigned to a capture point")


func _check_mode_objective_contract(root: Node, manifest: Dictionary,
		filename: String, mode: String) -> void:
	if mode in ["rush", "payload", "sabotage", "obliteration", "squadobliteration",
			"teamdeathmatch", "squaddeathmatch", "gauntlet"] and \
			_count_scene(root, "CapturePoint.tscn") != 0:
		failures += 1
		print("FAIL ", filename, ": mode must not contain CapturePoint objectives")
	if mode == "payload":
		var expected := _count_manifest_gem(manifest, "gem_payload") + \
			_count_manifest_gem(manifest, "gem_checkpoint")
		var folder := root.get_node_or_null("Objectives/Payload Route")
		if folder == null or folder.get_child_count() != expected:
			failures += 1
			print("FAIL ", filename, ": payload markers ",
				0 if folder == null else folder.get_child_count(), "/", expected)
	if mode == "sabotage":
		var expected := _count_manifest_gem(manifest, "gem_destructiblezone")
		var folder := root.get_node_or_null("Objectives/Destructible Objectives")
		if folder == null or folder.get_child_count() != expected:
			failures += 1
			print("FAIL ", filename, ": destructible objectives ",
				0 if folder == null else folder.get_child_count(), "/", expected)
	if mode in ["obliteration", "squadobliteration"]:
		if root.get_node_or_null("Objectives/MCOM Objectives") == null or \
				root.get_node_or_null("Objectives/Bomb Spawn Candidates") == null:
			failures += 1
			print("FAIL ", filename, ": Obliteration objective folders are incomplete")
	if mode in ["escalation", "koth", "kingofthehill", "strikepoint"] and \
			_count_manifest_gem(manifest, "gem_sector") > 0 and \
			root.get_node_or_null("Objectives/Runtime Sectors") == null:
		failures += 1
		print("FAIL ", filename, ": runtime-fed sector placements are missing")


func _count_manifest_gem(manifest: Dictionary, gem_name: String) -> int:
	var count := 0
	for value in manifest.get("elements", []):
		if str((value as Dictionary).get("gem", "")) == gem_name and \
				not str((value as Dictionary).get("layer", "")).ends_with("/gameplay_global"):
			count += 1
	return count


func _check_deploy_cameras(root: Node, manifest: Dictionary, filename: String) -> void:
	var local: Array = []
	var shared: Array = []
	for value in manifest.get("elements", []):
		var element := value as Dictionary
		if str(element.get("gem", "")) != "gem_deploycam":
			continue
		if str(element.get("layer", "")).ends_with("/gameplay_global"):
			shared.append(element)
		else:
			local.append(element)
	var expected := local if not local.is_empty() else shared
	var folder := root.get_node_or_null("Extras/Deploy Cameras")
	var actual := 0 if folder == null else folder.get_child_count()
	if actual != expected.size():
		failures += 1
		print("FAIL ", filename, ": deploy cameras ", actual, "/", expected.size())
		return
	for child in folder.get_children() if folder != null else []:
		var source_guid := str(child.get_meta("bf6_source_instance_guid", ""))
		var matched := false
		for value in expected:
			if source_guid == str((value as Dictionary).get("instance_guid", "")):
				matched = true
				break
		if not matched:
			failures += 1
			print("FAIL ", filename, ": deploy camera source is not authored ", source_guid)


func _check_automatic_aa_protection_bindings(root: Node, manifest: Dictionary,
		filename: String) -> void:
	var expected := {}
	for value in manifest.get("objects", []):
		var row := value as Dictionary
		if int(row.get("role", 0)) != 101:
			continue
		var shape := row.get("protection_shape", {}) as Dictionary
		if not shape.is_empty():
			expected[str(shape.get("instance_guid", ""))] = true
	var found: Array[Node] = []
	_collect_meta_nodes(root, "bf6_protection_instance_guid", found)
	if found.size() != expected.size():
		failures += 1
		print("FAIL ", filename, ": exact AA protection bindings ",
			found.size(), "/", expected.size())
	for aa in found:
		var guid := str(aa.get_meta("bf6_protection_instance_guid", ""))
		if not expected.has(guid):
			failures += 1
			print("FAIL ", filename, ": AA protection source is not authored ", guid)
		var protection = aa.get("ProtectionAreaVolume")
		if protection == null or not is_instance_valid(protection) or protection.get_parent() != aa:
			failures += 1
			print("FAIL ", filename, ": AA exact protection volume is not attached ", aa.name)


func _collect_meta_nodes(node: Node, key: String, result: Array[Node]) -> void:
	if node.has_meta(key):
		result.append(node)
	for child in node.get_children():
		_collect_meta_nodes(child, key, result)


func _check_hq_insertion_spawns(root: Node, manifest: Dictionary,
		filename: String) -> void:
	var expected := 0
	for value in manifest.get("elements", []):
		var row := value as Dictionary
		if str(row.get("gem", "")) == "gem_insertion" and \
				not str(row.get("layer", "")).ends_with("/gameplay_global"):
			expected += 1
	var hq_count := _count_name_prefix(root, "TEAM_")
	var actual := _count_meta(root, "bf6_spawn_binding", "installed_gem_insertion")
	if hq_count > 0 and actual != expected:
		failures += 1
		print("FAIL ", filename, ": authored HQ insertion spawns ", actual, "/", expected)
	if filename == "mp_atoll_conquest.layout.json":
		for team in [1, 2]:
			var hq := root.get_node_or_null("TEAM_%d_HQ" % team)
			var count := 0 if hq == null else \
				_count_meta(hq, "bf6_spawn_binding", "installed_gem_insertion")
			if count != 8:
				failures += 1
				print("FAIL ", filename, ": Team ", team, " HQ insertion count ", count, "/8")


func _check_breakthrough_sectors(root: Node, manifest: Dictionary, filename: String) -> void:
	var expected := int((manifest.get("counts", {}) as Dictionary).get("captures", 0))
	var sectors := root.get_node_or_null("Objectives/Sectors")
	if expected > 0 and sectors == null:
		failures += 1
		print("FAIL ", filename, ": Breakthrough objectives have no sectors")
		return
	var seen := 0
	if sectors != null:
		for sector in sectors.get_children():
			var captures = sector.get("CapturePoints")
			if captures == null or captures.size() < 1 or captures.size() > 2:
				failures += 1
				print("FAIL ", filename, ": invalid Breakthrough sector ", sector.name)
				continue
			for slot in range(captures.size()):
				seen += 1
				var expected_name := "CapturePoint%s" % ("A" if slot == 0 else "B")
				if str(captures[slot].name) != expected_name:
					failures += 1
					print("FAIL ", filename, ": Breakthrough local objective name ",
						captures[slot].name)
	if seen != expected:
		failures += 1
		print("FAIL ", filename, ": Breakthrough sector objectives ", seen, "/", expected)


func _count_scene(node: Node, scene_name: String) -> int:
	var count := 1 if str(node.scene_file_path).get_file() == scene_name else 0
	for child in node.get_children():
		count += _count_scene(child, scene_name)
	return count


func _has_capture_vehicle_association(node: Node) -> bool:
	if node.has_meta("bf6_runtime_association") and \
			str(node.get_meta("bf6_runtime_association")).begins_with("CapturePoint"):
		return true
	for child in node.get_children():
		if _has_capture_vehicle_association(child):
			return true
	return false


func _check_capstone_vehicle_mapping(root: Node, filename: String) -> void:
	var expected := {
		0: [13, 9], 1: [17, 3], 2: [0, 1], 4: [16, 14],
		5: [15, 18], 6: [8, 6], 8: [10], 13: [22, 23],
	}
	var seen := {}
	_collect_vehicle_types(root, seen)
	for selector in expected:
		for vehicle_type in expected[selector]:
			if not (seen.get(selector, []) as Array).has(vehicle_type):
				failures += 1
				print("FAIL ", filename, ": selector ", selector,
					" missing VehicleType ", vehicle_type)


func _collect_vehicle_types(node: Node, seen: Dictionary) -> void:
	if node.has_meta("bf6_retail_selector") and node.get("VehicleType") != null:
		var selector := int(node.get_meta("bf6_retail_selector"))
		if not seen.has(selector):
			seen[selector] = []
		(seen[selector] as Array).append(int(node.get("VehicleType")))
	for child in node.get_children():
		_collect_vehicle_types(child, seen)


func _check_exact_vehicle_selectors(node: Node, filename: String) -> void:
	if node.has_meta("bf6_retail_selector") and node.get("VehicleType") != null:
		var selector := int(node.get_meta("bf6_retail_selector"))
		var vehicle_type := int(node.get("VehicleType"))
		var allowed: Array = [0, 1] if node.has_meta("bf6_vehicle_override") else \
			VEHICLE_CLASS_TYPES.get(selector, [])
		if not allowed.is_empty() and not allowed.has(vehicle_type):
			failures += 1
			print("FAIL ", filename, ": retail class selector ", selector,
				" resolved to invalid VehicleType ", vehicle_type, " expected ", allowed)
	for child in node.get_children():
		_check_exact_vehicle_selectors(child, filename)


func _check_objective_vehicle_faction_pairs(root: Node, filename: String) -> void:
	var records := {}
	_collect_objective_vehicle_records(root, records)
	for guid in records:
		var record := records[guid] as Dictionary
		var expected: Array = [0, 1] if bool(record.get("override", false)) else \
			VEHICLE_CLASS_TYPES.get(int(record.selector), [])
		if expected.size() != 2:
			continue
		var actual: Array = record.types
		actual.sort()
		var sorted_expected := expected.duplicate()
		sorted_expected.sort()
		if actual != sorted_expected:
			failures += 1
			print("FAIL ", filename, ": objective pad ", guid,
				" faction vehicles ", actual, " expected ", sorted_expected)


func _collect_objective_vehicle_records(node: Node, records: Dictionary) -> void:
	if node.has_meta("bf6_source_instance_guid") and node.get("VehicleType") != null and \
			str(node.get_meta("bf6_runtime_association", "")).begins_with("CapturePoint"):
		var guid := str(node.get_meta("bf6_source_instance_guid"))
		if not records.has(guid):
			records[guid] = {
				"selector": int(node.get_meta("bf6_retail_selector", -1)),
				"override": node.has_meta("bf6_vehicle_override"),
				"types": [],
			}
		(records[guid].types as Array).append(int(node.get("VehicleType")))
	for child in node.get_children():
		_collect_objective_vehicle_records(child, records)


func _check_conquest_flag_mapping(root: Node, manifest: Dictionary, filename: String,
		expected_guids: Array) -> void:
	var seen := 0
	for value in manifest.get("objects", []):
		var row := value as Dictionary
		if int(row.get("role", 0)) != 2:
			continue
		var source_flag := int(row.get("flag", -1))
		seen += 1
		if source_flag < 0 or source_flag >= expected_guids.size() or \
				str((row.get("raw", {}) as Dictionary).get("instance_guid", "")) != \
				str(expected_guids[source_flag]):
			failures += 1
			print("FAIL ", filename, ": Conquest manifest flag identity is wrong for ",
				String.chr(65 + source_flag))
		var capture := root.get_node_or_null("Objectives/CapturePoint%s" % String.chr(65 + source_flag)) as Node3D
		var expected := Vector3(float(row.centre[0]), float(row.centre[1]), float(row.centre[2]))
		if capture == null or not capture.position.is_equal_approx(expected):
			failures += 1
			print("FAIL ", filename, ": Conquest flag ", String.chr(65 + source_flag),
				" was remapped after manifest classification")
	if seen != expected_guids.size():
		failures += 1
		print("FAIL ", filename, ": Conquest capture identity count ", seen, "/",
			expected_guids.size())


func _check_atoll_hq_areas(root: Node, filename: String) -> void:
	var expected_guids := [
		"98bff49d-cfdf-4e6a-947f-f7858a4be14d",
		"af1d74e3-82f6-42c8-b9ed-c13216c6df5f",
	]
	for team_index in range(2):
		var hq := root.get_node_or_null("TEAM_%d_HQ" % (team_index + 1))
		var area: Node = hq.get("HQArea") if hq != null else null
		if area == null or area.get_parent() != hq or \
				str(area.get_meta("bf6_source_instance_guid", "")) != expected_guids[team_index]:
			failures += 1
			print("FAIL ", filename, ": Team ", team_index + 1,
				" HQ does not own its retail base zone")


func _check_combat_area(root: Node, filename: String, combat_guid: String,
		surrounding_guid := "") -> void:
	var combat := root.get_node_or_null("Play Area/CombatArea")
	var volume: Node = combat.get("CombatVolume") if combat != null else null
	if volume == null or str(volume.get_meta("bf6_source_instance_guid", "")) != combat_guid:
		failures += 1
		print("FAIL ", filename, ": CombatArea does not own the retail combat zone")
	if surrounding_guid != "":
		var surrounding: Node = combat.get("SurroundingVolume") if combat != null else null
		if surrounding == null or str(surrounding.get_meta("bf6_source_instance_guid", "")) != surrounding_guid:
			failures += 1
			print("FAIL ", filename, ": CombatArea does not own the retail surrounding zone")


func _check_no_loose_conquest_boundaries(root: Node, filename: String) -> void:
	var play_area := root.get_node_or_null("Play Area")
	if play_area == null:
		return
	for child in play_area.get_children():
		var scene_name := str(child.scene_file_path).get_file()
		if scene_name in ["PolygonVolume.tscn", "OBBVolume.tscn"]:
			failures += 1
			print("FAIL ", filename, ": loose bridge/rooftop boundary ", child.name)


func _check_aftermath_hq_areas(root: Node, filename: String) -> void:
	var hq_count := 0
	var area_count := 0
	for child in root.get_children():
		if not str(child.name).begins_with("TEAM_"):
			continue
		hq_count += 1
		if child.get("HQArea") != null:
			area_count += 1
	if hq_count != 3 or area_count != 3:
		failures += 1
		print("FAIL ", filename, ": Aftermath HQ areas ", area_count, "/3")


func _check_capstone_flyer_overrides(root: Node, filename: String) -> void:
	var expected := {
		"31426ce7-ee3a-4827-8a12-6d4034036fde": 13,
		"fccb3aae-d90b-4606-852c-f10dccd337fb": 13,
	}
	var found := {}
	_collect_vehicle_guid_types(root, found)
	for guid in expected:
		if int(found.get(guid, -1)) != int(expected[guid]):
			failures += 1
			print("FAIL ", filename, ": Capstone HQ slot ", guid,
				" must use Flyer 60")


func _check_capstone_objective_tanks(root: Node, filename: String) -> void:
	var expected := {
		"f2f47407-2dbb-4637-9a97-49aafd0f96d6": true,
		"8ccc0aab-7d71-47e2-8ad5-4ca2195b3df2": true,
	}
	var found := {}
	_collect_capstone_objective_tanks(root, expected, found)
	for guid in expected:
		if not found.has(guid):
			failures += 1
			print("FAIL ", filename, ": Capstone objective B/E tank missing ", guid)


func _collect_capstone_objective_tanks(node: Node, expected: Dictionary,
		found: Dictionary) -> void:
	var guid := str(node.get_meta("bf6_source_instance_guid", ""))
	if expected.has(guid) and node.get("VehicleType") != null:
		if int(node.get("VehicleType")) in [0, 1]:
			found[guid] = true
		else:
			failures += 1
			print("FAIL Capstone objective B/E is not Abrams/Leopard: ", node.name)
	for child in node.get_children():
		_collect_capstone_objective_tanks(child, expected, found)


func _collect_vehicle_guid_types(node: Node, found: Dictionary) -> void:
	if node.has_meta("bf6_source_instance_guid") and node.get("VehicleType") != null:
		found[str(node.get_meta("bf6_source_instance_guid"))] = int(node.get("VehicleType"))
	for child in node.get_children():
		_collect_vehicle_guid_types(child, found)


func _check_sector_order(root: Node, filename: String) -> void:
	var sector := root.get_node_or_null("Play Area/Sector")
	if sector == null:
		failures += 1
		print("FAIL ", filename, ": Sector is missing from Play Area")
		return
	var capture_points: Array = sector.get("CapturePoints")
	var previous := ""
	for capture in capture_points:
		var current := str((capture as Node).name)
		if previous != "" and current < previous:
			failures += 1
			print("FAIL ", filename, ": Sector capture index is not alphabetical")
			return
		previous = current
