@tool
extends SceneTree

const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const DATA_DIR := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/data"
const CATALOG := DATA_DIR + "/layout_catalog.json"
const CONQUEST_IDENTITIES := "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/tests/conquest_objective_identities.json"
const PROGRESSIVE_LINKS := "res://addons/bf6_gamemode_setup/data/progressive_links.json"
const RETAIL_SETTINGS := "res://addons/bf6_gamemode_setup/data/retail_mode_runtime_contracts.json"
const KOTH_CANDIDATES := "res://addons/bf6_gamemode_setup/data/koth_candidates.json"
const OPERATIONS_CANDIDATES := "res://addons/bf6_gamemode_setup/data/operations_candidates.json"
const BOMB_CANDIDATES := "res://addons/bf6_gamemode_setup/data/bomb_candidates.json"
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
	var progressive_pack: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(PROGRESSIVE_LINKS))
	var retail_settings: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(RETAIL_SETTINGS))
	var koth_candidates: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(KOTH_CANDIDATES))
	var operations_candidates: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(OPERATIONS_CANDIDATES))
	var bomb_candidates: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(BOMB_CANDIDATES))
	var requested_modes := OS.get_cmdline_user_args()
	var tested := 0
	var unresolved := 0
	var rejected_koth := 0
	var unresolved_operations := 0
	for level in (catalog.get("maps", {}) as Dictionary):
		var map: Dictionary = catalog.maps[level]
		for mode_value in map.get("modes", []):
			var mode := str(mode_value)
			if not requested_modes.is_empty() and mode not in requested_modes:
				continue
			var filename := "%s_%s.layout.json" % [level, mode]
			var root := Node3D.new()
			root.name = str(level).to_upper()
			get_root().add_child(root)
			var key := "%s/%s" % [level, mode]
			var message := Builder.build(root, key, {
				"manifest": "%s/%s" % [DATA_DIR, filename],
			}, false)
			if mode in ["koth", "kingofthehill"]:
				var koth_row: Dictionary = koth_candidates.get("maps", {}).get(level, {})
				if not koth_row.is_empty():
					var koth_document: Dictionary = JSON.parse_string(
						FileAccess.get_file_as_string("%s/%s" % [DATA_DIR, filename]))
					var found_koth: Array = []
					for element in koth_document.get("elements", []):
						if str(element.get("gem", "")) == "gem_capturepoint":
							found_koth.append(str(element.get("instance_guid", "")).to_lower())
					found_koth.sort()
					var expected_koth: Array = koth_row.capture_guids.duplicate()
					expected_koth.sort()
					if found_koth != expected_koth:
						if not message.begins_with("KOTH candidate identities disagree") or root.get_child_count() != 0:
							failures += 1
							print("FAIL ", filename, ": mismatched KOTH candidate set was not refused")
						else:
							rejected_koth += 1
						tested += 1
						root.queue_free()
						await process_frame
						continue
			if mode == "operations":
				var operations_row: Dictionary = operations_candidates.get("maps", {}).get(level, {})
				if not operations_row.is_empty():
					var operations_document: Dictionary = JSON.parse_string(
						FileAccess.get_file_as_string("%s/%s" % [DATA_DIR, filename]))
					var available_operations := {}
					for element in operations_document.get("elements", []):
						available_operations[str(element.get("partition", "")) + "#" + str(element.get("instance_guid", ""))] = true
					var missing_operations := false
					for candidate in operations_row.sectors:
						if not available_operations.has(candidate.sector): missing_operations = true
						for member_id in candidate.captures + candidate.hqs:
							if not available_operations.has(member_id): missing_operations = true
					if missing_operations:
						if not message.begins_with("Operations selected ") or root.get_child_count() != 0:
							failures += 1
							print("FAIL ", filename, ": incomplete Operations export was not refused")
						else:
							unresolved_operations += 1
						tested += 1
						root.queue_free()
						await process_frame
						continue
			if mode in ["rush", "breakthrough"]:
				var evidence: Dictionary = progressive_pack.get("layouts", {}).get(key, {})
				if evidence.get("sectors", []).is_empty():
					if not message.begins_with("Exact progressive selection is unresolved"):
						failures += 1
						print("FAIL ", filename, ": unresolved selection was not refused: ", message)
					else:
						unresolved += 1
				else:
					var exact: Node = Builder.find_build(root, key)
					if exact == null or not message.begins_with("Built "):
						failures += 1
						print("FAIL ", filename, ": exact builder failed: ", message)
					else:
						if exact.get_meta("bf6_order_status", "") == "":
							failures += 1
							print("FAIL ", filename, ": exact order provenance is missing")
						if (exact.get_meta("bf6_retail_mode_defaults", {}) as Dictionary).is_empty():
							failures += 1
							print("FAIL ", filename, ": retail mode defaults are missing")
						var packed_exact := PackedScene.new()
						if packed_exact.pack(root) != OK:
							failures += 1
							print("FAIL ", filename, ": exact scene did not pack")
				tested += 1
				root.queue_free()
				await process_frame
				continue
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
					if mode in ["koth", "kingofthehill"]:
						var selected_koth: Dictionary = koth_candidates.get("maps", {}).get(level, {})
						if not selected_koth.is_empty():
							if built.get_meta("bf6_koth_candidate_guids", []) != selected_koth.capture_guids:
								failures += 1
								print("FAIL ", filename, ": authored KOTH candidate order is missing")
							var hill_sector: Node = built.get_node_or_null("Objectives/Runtime Sectors/SectorCandidate_01")
							if hill_sector == null or hill_sector.get_meta("bf6_koth_candidate_guids", []) != selected_koth.capture_guids:
								failures += 1
								print("FAIL ", filename, ": KOTH sector lost candidate link order")
					if mode == "operations":
						var selected_operations: Dictionary = operations_candidates.get("maps", {}).get(level, {})
						for candidate in selected_operations.get("sectors", []):
							var sector_node: Node = _find_meta_value(built, "bf6_source_identity", str(candidate.sector))
							if sector_node == null:
								failures += 1
								print("FAIL ", filename, ": exact Operations sector missing ", candidate.sector)
								continue
							var capture_ids: Array = (sector_node.get("CapturePoints") as Array).map(
								func(node): return str(node.get_meta("bf6_capture_instance_guid", "")))
							var hq_ids: Array = (sector_node.get("HQs") as Array).map(
								func(node): return str(node.get_meta("bf6_source_instance_guid", "")))
							if capture_ids != (candidate.captures as Array).map(func(id): return str(id).get_slice("#", 1)) or \
								hq_ids != (candidate.hqs as Array).map(func(id): return str(id).get_slice("#", 1)):
								failures += 1
								print("FAIL ", filename, ": Operations membership changed ", candidate.sector)
					if mode in ["obliteration", "squadobliteration"]:
						var selected_bomb: Dictionary = bomb_candidates.get("layouts", {}).get(key, {})
						if not selected_bomb.is_empty():
							var bomb_sector: Node = _find_meta_value(built, "bf6_source_identity", str(selected_bomb.sector))
							if bomb_sector == null:
								failures += 1
								print("FAIL ", filename, ": selected bomb-mode sector missing")
							else:
								var mcom_ids: Array = (bomb_sector.get("MCOMs") as Array).map(
									func(node): return str(node.get_meta("bf6_source_identity", "")))
								var hq_ids: Array = (bomb_sector.get("HQs") as Array).map(
									func(node): return str(node.get_meta("bf6_source_identity", "")))
								if mcom_ids != selected_bomb.mcoms or hq_ids != selected_bomb.hqs or \
										bomb_sector.get_meta("bf6_bomb_candidate_guids", []) != selected_bomb.bombs:
									failures += 1
									print("FAIL ", filename, ": bomb-mode candidate membership changed")
					var settings_key := "kingofthehill" if mode == "koth" else mode
					if retail_settings.get("modes", {}).has(settings_key) and \
							(built.get_meta("bf6_retail_mode_defaults", {}) as Dictionary).is_empty():
						failures += 1
						print("FAIL ", filename, ": decoded mode defaults are missing")
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
					if expected_linked_spawns == 0 and mode not in ["rush", "breakthrough",
							"operations"] and mode in ["conquest", "carrierstrike",
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
					if mode in ["rush", "breakthrough"]:
						_check_template_compatibility_provenance(built, filename)
					_check_deploy_cameras(built, manifest, filename)
					_check_world_horizontal_polygons(built, filename)
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
					if level in ["mp_aftermath", "mp_aftermath_portal"] and mode == "conquest":
						_check_aftermath_hq_areas(built, filename)
						_check_combat_area(built, filename,
							"5748a1d0-b891-43b4-9331-ac6a0050e046" if level == "mp_aftermath" \
							else "ea588511-aa3b-45df-830a-11243d2d223c")
						if _count_scene(built.get_node("Play Area"), "OBBVolume.tscn") != 0:
							failures += 1
							print("FAIL ", filename,
								": unowned map-global boxes leaked into Play Area")
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
	print("ALL MODES: ", tested, " tested, ", unresolved,
		" progressive selections unresolved, ", rejected_koth,
		" mismatched KOTH exports refused, ", unresolved_operations,
		" incomplete Operations exports refused, ", failures, " failures")
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
	for value in manifest.get("capture_shapes", []):
		var shape := value as Dictionary
		var guid := str(shape.get("controller_instance_guid", ""))
		var capture := _find_meta_value(built, "bf6_capture_instance_guid", guid)
		if capture == null:
			failures += 1
			print("FAIL ", filename, ": missing exact capture-shape provenance ", guid)
			continue
		if not str(capture.get_meta("bf6_capture_volume_binding", "")).begins_with(
				"installed_gem_instance_parameter_"):
			failures += 1
			print("FAIL ", filename, ": capture volume is not game-reference bound ", guid)
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
		if node.has_meta("bf6_progressive_phase"):
			var phase := int(node.get_meta("bf6_progressive_phase"))
			var minimum := 1150 + phase * 100
			if object_id < minimum or object_id > minimum + 49:
				failures += 1
				print("FAIL ", filename, ": progressive vehicle ObjId ", object_id,
					" outside ", minimum, "-", minimum + 49)
		elif team == 0:
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
	_check_linked_team_volume_colors(layout, filename, "swapped")
	Builder.swap_factions(map_root, key)
	var restored := _faction_state(layout)
	_check_linked_team_volume_colors(layout, filename, "restored")
	if before == swapped:
		failures += 1
		print("FAIL ", filename, ": faction swap changed no authored state")
	if before != restored:
		failures += 1
		print("FAIL ", filename, ": faction swap is not reversible")


func _check_linked_team_volume_colors(node: Node, filename: String,
		state: String) -> void:
	var team := _team_value(node)
	if team in [1, 2]:
		for property in [&"HQArea", &"ProtectionAreaVolume", &"CaptureArea", &"Area"]:
			if node.get(property) == null:
				continue
			var linked = node.get(property)
			if not (linked is Node) or linked.get("points") == null or linked.get("color") == null:
				continue
			var expected := Color(0.0, 0.53, 0.99, 0.42) if team == 1 \
				else Color(0.95, 0.23, 0.0, 0.42)
			if not (linked.get("color") as Color).is_equal_approx(expected):
				failures += 1
				print("FAIL ", filename, ": ", state,
					" linked team volume colour at ", node.get_path(), "/", property)
	for child in node.get_children():
		_check_linked_team_volume_colors(child, filename, state)


func _team_value(node: Node) -> int:
	for property in [&"OwnerTeam", &"Team", &"MatchingTeam",
			&"StartingOwnerTeamID", &"Attacker_TeamID"]:
		var value = node.get(property)
		if value != null and int(value) in [1, 2]:
			return int(value)
	return 0


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
		if team not in [0, 1, 2]:
			failures += 1
			print("FAIL ", filename, ": automatic AA has invalid game team ", node.name)
		var expected_owner := "Neutral" if team == 0 else "Team%d" % team
		if not str(node.name).contains(expected_owner):
			failures += 1
			print("FAIL ", filename, ": automatic AA name hides owner ", node.name)
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
	if sectors != null:
		authored_sectors = maxi(sectors.get_child_count() - 2, 0)
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
	var previous_root_order := -1
	if sectors != null:
		_check_progressive_template_shell(sectors, authored_sectors, filename, "Rush")
		for sector_index in range(sectors.get_child_count()):
			var sector := sectors.get_child(sector_index)
			if sector_index == 0 or sector_index == sectors.get_child_count() - 1:
				continue
			var mcoms = sector.get("MCOMs")
			if mcoms == null or mcoms.size() > 2:
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
				var expected_id := 201 + (sector_index - 1) * 2 + slot
				if int(mcom.get("ObjId")) != expected_id:
					failures += 1
					print("FAIL ", filename, ": Rush MCOM ObjId ",
						mcom.get("ObjId"), "/", expected_id)
			var source_guid := str(sector.get_meta("bf6_source_instance_guid", ""))
			var root_order := _element_root_order_for_guid(manifest, source_guid)
			if root_order < previous_root_order:
				failures += 1
				print("FAIL ", filename, ": Rush sectors are not in authored phase order")
			previous_root_order = root_order
			_check_progressive_hq_pair(sector, manifest, filename, "Rush")
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
		elif folder != null:
			_check_sabotage_trigger_contract(folder, manifest, filename)
	if mode in ["obliteration", "squadobliteration"]:
		if root.get_node_or_null("Objectives/MCOM Objectives") == null or \
				root.get_node_or_null("Objectives/Bomb Spawn Candidates") == null:
			failures += 1
			print("FAIL ", filename, ": Obliteration objective folders are incomplete")
	if mode in ["obliteration", "squadobliteration", "carrierstrike"]:
		_check_review_mcom_contract(root, manifest, filename, mode)
	if mode in ["escalation", "koth", "kingofthehill", "strikepoint"] and \
			_count_manifest_gem(manifest, "gem_sector") > 0 and \
			root.get_node_or_null("Objectives/Runtime Sectors") == null:
		failures += 1
		print("FAIL ", filename, ": runtime-fed sector placements are missing")


func _check_sabotage_trigger_contract(folder: Node, manifest: Dictionary,
		filename: String) -> void:
	var available_polygons := 0
	for value in manifest.get("objects", []):
		if int((value as Dictionary).get("role", 0)) == 2 and \
				((value as Dictionary).get("world_points", []) as Array).size() >= 9:
			available_polygons += 1
	var linked := 0
	for index in range(folder.get_child_count()):
		var objective := folder.get_child(index)
		var area := objective.get_node_or_null("ObjectiveArea")
		var trigger := objective.get_node_or_null("SabotageTrigger_%02d" % (index + 1))
		if trigger == null:
			continue
		linked += 1
		if area == null or int(trigger.get("ObjId")) != 701 + index or \
				trigger.get("Area") != area:
			failures += 1
			print("FAIL ", filename, ": Sabotage AreaTrigger contract ", index + 1)
	if linked != mini(folder.get_child_count(), available_polygons):
		failures += 1
		print("FAIL ", filename, ": linked Sabotage polygons ", linked, "/",
			mini(folder.get_child_count(), available_polygons))


func _check_review_mcom_contract(root: Node, manifest: Dictionary,
		filename: String, mode: String) -> void:
	var folder_name := "Carrier Objectives" if mode == "carrierstrike" else "MCOM Objectives"
	var folder := root.get_node_or_null("Objectives/" + folder_name)
	var expected := _count_manifest_gem(manifest, "gem_objective_mcom")
	if folder == null or folder.get_child_count() != expected:
		failures += 1
		print("FAIL ", filename, ": review MCOM count ",
			0 if folder == null else folder.get_child_count(), "/", expected)
		return
	var seen := {}
	for child in folder.get_children():
		var label_slot := int(str(child.name).get_slice("_", 1))
		var object_id := int(child.get("ObjId"))
		if label_slot < 1 or object_id != 300 + label_slot or seen.has(object_id) or \
				not child.has_meta("bf6_portal_translation"):
			failures += 1
			print("FAIL ", filename, ": review MCOM identity ", child.name,
				" / ", object_id)
		seen[object_id] = true


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
		if protection == null or not is_instance_valid(protection):
			failures += 1
			print("FAIL ", filename, ": AA exact protection volume is not linked ", aa.name)
			continue
		if protection.get_parent() != aa.get_parent():
			failures += 1
			print("FAIL ", filename, ": AA protection volume is outside AA-Defences ", aa.name)
		if not _polygon_points_are_world_horizontal(protection):
			failures += 1
			print("FAIL ", filename, ": AA protection volume is tilted ", aa.name)


func _polygon_points_are_world_horizontal(volume: Node3D) -> bool:
	var points = volume.get("points")
	if not (points is PackedVector2Array) or points.is_empty():
		return false
	var world_transform := volume.transform
	var ancestor := volume.get_parent()
	while ancestor != null:
		if ancestor is Node3D:
			world_transform = (ancestor as Node3D).transform * world_transform
		ancestor = ancestor.get_parent()
	var first_y := (world_transform * Vector3(points[0].x, 0.0, points[0].y)).y
	for point in points:
		if not is_equal_approx((world_transform * Vector3(point.x, 0.0, point.y)).y,
				first_y):
			return false
	return true


func _check_world_horizontal_polygons(node: Node, filename: String) -> void:
	if str(node.scene_file_path).get_file() == "PolygonVolume.tscn" and \
			not _polygon_points_are_world_horizontal(node as Node3D):
		failures += 1
		print("FAIL ", filename, ": unsupported tilted PolygonVolume ", node.get_path())
	for child in node.get_children():
		_check_world_horizontal_polygons(child, filename)


func _collect_meta_nodes(node: Node, key: String, result: Array[Node]) -> void:
	if node.has_meta(key):
		result.append(node)
	for child in node.get_children():
		_collect_meta_nodes(child, key, result)


func _check_hq_insertion_spawns(root: Node, manifest: Dictionary,
		filename: String) -> void:
	var mode := str((manifest.get("source", {}) as Dictionary).get("mode", ""))
	if mode in ["rush", "breakthrough", "operations"] and \
			_count_name_prefix(root, "Spawn_HQ_") != 0:
		failures += 1
		print("FAIL ", filename,
			": progressive mode fabricated HQ spawns from unlinked game placements")


func _check_breakthrough_sectors(root: Node, manifest: Dictionary, filename: String) -> void:
	var sectors := root.get_node_or_null("Objectives/Sectors")
	var expected := (manifest.get("capture_shapes", []) as Array).size()
	if expected > 0 and sectors == null:
		failures += 1
		print("FAIL ", filename, ": Breakthrough objectives have no sectors")
		return
	var seen := 0
	var previous_root_order := -1
	if sectors != null:
		var authored_sectors := _count_manifest_gem(manifest, "gem_sector")
		_check_progressive_template_shell(sectors, authored_sectors, filename,
			"Breakthrough")
		for sector_index in range(sectors.get_child_count()):
			var sector := sectors.get_child(sector_index)
			if sector_index == 0 or sector_index == sectors.get_child_count() - 1:
				continue
			var captures = sector.get("CapturePoints")
			if captures == null or captures.is_empty() or captures.size() > 3:
				failures += 1
				print("FAIL ", filename, ": invalid Breakthrough sector ", sector.name)
				continue
			for slot in range(captures.size()):
				seen += 1
				if str(captures[slot].get_meta("bf6_sector_binding", "")) != \
						"authored-order Portal projection; retail membership is runtime-fed":
					failures += 1
					print("FAIL ", filename,
						": Breakthrough objective used a spatial sector guess ", captures[slot].name)
				var expected_name := "CapturePoint%s" % String.chr(65 + slot)
				if str(captures[slot].name) != expected_name:
					failures += 1
					print("FAIL ", filename, ": Breakthrough local objective name ",
						captures[slot].name)
				if int(captures[slot].get("InitialOwner")) != 2:
					failures += 1
					print("FAIL ", filename,
						": Breakthrough objective does not begin owned by Team 2 ",
						captures[slot].name)
				var capture_area = captures[slot].get("CaptureArea")
				if capture_area == null or (capture_area as Node).get_parent() != captures[slot]:
					failures += 1
					print("FAIL ", filename, ": Breakthrough objective has no linked volume ",
						captures[slot].name)
				var expected_id := 1000 + sector_index * 100 + slot
				if int(captures[slot].get("ObjId")) != expected_id:
					failures += 1
					print("FAIL ", filename, ": Breakthrough capture ObjId ",
						captures[slot].get("ObjId"), "/", expected_id)
			var source_guid := str(sector.get_meta("bf6_source_instance_guid", ""))
			var root_order := _element_root_order_for_guid(manifest, source_guid)
			if root_order < previous_root_order:
				failures += 1
				print("FAIL ", filename,
					": Breakthrough sectors are not in authored phase order")
			previous_root_order = root_order
			_check_progressive_hq_pair(sector, manifest, filename, "Breakthrough")
	if seen != expected:
		failures += 1
		print("FAIL ", filename, ": Breakthrough sector objectives ", seen, "/", expected)


func _check_progressive_template_shell(sectors: Node, authored_phases: int,
		filename: String, mode_name: String) -> void:
	var expected_count := authored_phases + 2
	if sectors.get_child_count() != expected_count:
		failures += 1
		print("FAIL ", filename, ": ", mode_name, " Blockly sector shell ",
			sectors.get_child_count(), "/", expected_count)
	for index in range(sectors.get_child_count()):
		var sector := sectors.get_child(index)
		if str(sector.name) != "Sector%d" % index or int(sector.get("ObjId")) != 100 + index:
			failures += 1
			print("FAIL ", filename, ": ", mode_name,
				" sector identity ", sector.name, " / ", sector.get("ObjId"))
		var area = sector.get("SectorArea")
		if area != null:
			var trigger := sector.get_node_or_null("AreaTrigger")
			if trigger == null or int(trigger.get("ObjId")) != 600 + index or \
					trigger.get("Area") != area:
				failures += 1
				print("FAIL ", filename, ": ", mode_name,
					" sector AreaTrigger contract ", sector.name)
		if index > 0 and index < sectors.get_child_count() - 1:
			var hqs = sector.get("HQs")
			if hqs != null:
				for hq in hqs:
					if (hq as Node).get_parent() != sector:
						failures += 1
						print("FAIL ", filename, ": ", mode_name,
							" HQ is outside its phase sector ", (hq as Node).name)
					var team := int((hq as Node).get("Team"))
					var adjacent := sectors.get_child(index - 1 if team == 1 else index + 1)
					if adjacent.get("SectorArea") != null and \
							(hq as Node).get("HQArea") != adjacent.get("SectorArea"):
						failures += 1
						print("FAIL ", filename, ": ", mode_name,
							" HQ area is not the adjacent sector area ", (hq as Node).name)
	var progressive_vehicles: Array[Node] = []
	_collect_progressive_vehicles(sectors.get_parent().get_parent(), progressive_vehicles)
	var used_ids := {}
	for vehicle in progressive_vehicles:
		var phase := int(vehicle.get_meta("bf6_progressive_phase", -1))
		var object_id := int(vehicle.get("ObjId"))
		var minimum := 1150 + phase * 100
		if phase < 0 or object_id < minimum or object_id > minimum + 49 or \
				used_ids.has(object_id):
			failures += 1
			print("FAIL ", filename, ": ", mode_name,
				" progressive vehicle identity ", vehicle.name, " / ", object_id)
		used_ids[object_id] = true


func _check_template_compatibility_provenance(root: Node, filename: String) -> void:
	if not root.has_meta("bf6_template_compatibility") or \
			int(root.get_meta("bf6_template_adjustment_count", 0)) <= 0:
		failures += 1
		print("FAIL ", filename, ": progressive template adjustments are not disclosed")
	for branch in ["TeamSwitcher", "AI Spawns", "EndGameCamera"]:
		if root.get_node_or_null(branch) != null:
			failures += 1
			print("FAIL ", filename, ": optional Andy asset leaked into core build: ", branch)
	var aliases: Array[Node] = []
	_collect_meta_nodes(root, "bf6_template_hq_alias", aliases)
	if not aliases.is_empty():
		failures += 1
		print("FAIL ", filename, ": core build contains synthetic HQ aliases")


func _collect_progressive_vehicles(node: Node, result: Array[Node]) -> void:
	if str(node.scene_file_path).get_file() == "VehicleSpawner.tscn" and \
			node.has_meta("bf6_progressive_phase"):
		result.append(node)
	for child in node.get_children():
		_collect_progressive_vehicles(child, result)


func _check_progressive_hq_pair(sector: Node, manifest: Dictionary,
		filename: String, mode_name: String) -> void:
	var hqs = sector.get("HQs")
	if hqs == null or hqs.is_empty():
		return
	var sector_phase := int(sector.get_meta("bf6_progressive_phase", -1))
	var teams := {}
	for value in hqs:
		var hq := value as Node
		var team := int(hq.get("Team"))
		if team not in [1, 2] or teams.has(team):
			failures += 1
			print("FAIL ", filename, ": ", mode_name,
				" sector has invalid/duplicate HQ team ", sector.name)
		teams[team] = true
		if int(hq.get_meta("bf6_progressive_phase", -1)) != sector_phase:
			failures += 1
			print("FAIL ", filename, ": ", mode_name,
				" HQ phase does not match sector ", hq.name)
		var expected_id := (300 if team == 1 else 400) + sector_phase + 1
		if int(hq.get("ObjId")) != expected_id:
			failures += 1
			print("FAIL ", filename, ": ", mode_name,
				" HQ ObjId ", hq.get("ObjId"), "/", expected_id)


func _element_root_order_for_guid(manifest: Dictionary, guid: String) -> int:
	for value in manifest.get("elements", []):
		var element := value as Dictionary
		if str(element.get("instance_guid", "")) == guid:
			return int(element.get("root_order", -1))
	return -1


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
	var expected_retail := {
		"TEAM_1_HQ": ["9cc81e7a-279c-4130-9020-13b1d3626edb",
			"661a59ab-36df-4c95-bbcb-a27814f12c7a"],
		"TEAM_2_HQ": ["bb62d3c6-f20e-4f79-996b-e5fd922f3126",
			"a440a878-ea10-433d-81e0-8887593a3b43"],
	}
	var expected_portal := {
		"TEAM_1_HQ": ["cdf7cc38-48f3-4fa9-b25d-2a2b4cdc2b6f",
			"d5c6264e-117a-44e7-a5fd-a5f3304e633b"],
		"TEAM_2_HQ": ["3961f648-3b29-4203-baa4-7db42ef60319",
			"e4d3e2c2-804c-40e7-a5d5-64af8107b6c5"],
	}
	var expected := expected_portal if filename.begins_with("mp_aftermath_portal_") \
		else expected_retail
	var hq_count := 0
	for child in root.get_children():
		if str(child.name).begins_with("TEAM_"):
			hq_count += 1
	if hq_count != 2:
		failures += 1
		print("FAIL ", filename, ": Aftermath must have two insertion-backed HQs")
	for node_name in expected:
		var hq := root.get_node_or_null(node_name)
		var area: Node = hq.get("HQArea") if hq != null else null
		if hq == null or area == null or \
				str(hq.get_meta("bf6_source_instance_guid", "")) != expected[node_name][0] or \
				str(area.get_meta("bf6_source_instance_guid", "")) != expected[node_name][1]:
			failures += 1
			print("FAIL ", filename, ": ", node_name,
				" does not use its insertion-backed HQ and authored base area")


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
