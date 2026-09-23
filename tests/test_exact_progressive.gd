extends SceneTree

const Builder = preload("res://addons/bf6_gamemode_setup/gamemode_builder.gd")
const Exact = preload("res://addons/bf6_gamemode_setup/progressive_builder.gd")
const DATA = "C:/BF6_Dev/BF6_Godot_Gamemode_Setup/data/"
var failures := 0
var checked_links := 0
var faction_previews := 0
var cross_partition_areas := 0
var hq_assignments := 0
var ordered_objectives := 0

func _init() -> void:
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Exact.LINKS))
	for key in pack.layouts:
		var evidence: Dictionary = pack.layouts[key]
		var file := DATA + str(key).replace("/", "_") + ".layout.json"
		if evidence.sectors.is_empty() or not FileAccess.file_exists(file): continue
		var host := Node3D.new()
		host.name = "ExactTestHost"
		root.add_child(host)
		var message: String = Builder.build(host, key, {"manifest": file}, true)
		check(host.get_child_count() == 1, key + ": " + message)
		if host.get_child_count() == 0:
			host.free()
			continue
		var built: Node = host.get_child(0)
		var baseline: Dictionary = built.get_meta("bf6_hq_control_baseline", {})
		check(baseline.get("InvertedHQ", true) == false, key + " inverted-HQ baseline")
		check(baseline.get("InvertTeamRoles", true) == false, key + " team-role baseline")
		check(baseline.get("GameModeControlsHQ", true) == false, key + " HQ-control baseline")
		check(int(baseline.get("attacker_team", 0)) == 1 and
			int(baseline.get("defender_team", 0)) == 2, key + " progressive team roles")
		var activation: Dictionary = built.get_meta("bf6_hq_activation_by_sector_status", {})
		check(as_int_array(activation.get("team_1_active", [])) == [0, 6, 7, 8, 9, 11],
			key + " Team 1 HQ activation states")
		check(as_int_array(activation.get("team_2_active", [])) == [0, 2, 3, 6, 11],
			key + " Team 2 HQ activation states")
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
		var rows := {}
		for row in document.elements: rows[Exact.identity(row)] = row
		for row in document.objects: rows[Exact.identity(row)] = row
		var nodes := {}
		collect(built, nodes)
		for hq_id in evidence.hq_properties:
			check(nodes.has(hq_id), key + " missing authored HQ")
			if not nodes.has(hq_id): continue
			var hq: Node = nodes[hq_id]
			check(int(hq.get("Team")) == int(evidence.hq_properties[hq_id].Team.value),
				key + " wrong HQ Team")
			check(int(hq.get("AltTeam")) == int(evidence.hq_properties[hq_id].AltTeam.value),
				key + " wrong HQ AltTeam")
			var expected_states: Array = activation.get("team_%d_active" % int(hq.get("Team")), [])
			check(hq.get_meta("bf6_active_sector_statuses", []) == expected_states,
				key + " wrong HQ activation states")
			hq_assignments += 1
		for id in evidence.get("supplemental_rows", {}):
			check(nodes.has(id), key + " missing cross-partition endpoint")
			if nodes.has(id):
				check(nodes[id].has_meta("bf6_cross_partition_sources"), key + " missing cross-partition provenance")
				cross_partition_areas += 1
		for id in nodes:
			var node: Node = nodes[id]
			if not node.has_meta("bf6_vehicle_faction_source"): continue
			var hq_id: String = node.get_meta("bf6_vehicle_faction_source")
			check(nodes.has(hq_id), key + " missing vehicle HQ")
			var hq: Node = nodes[hq_id]
			check(hq.get("VehicleSpawners").has(node), key + " vehicle faction not linked to HQ")
			var team := int(hq.get("Team"))
			var types: Array = node.get_meta("bf6_vehicle_faction_candidates")
			check(node.get("VehicleType") == types[team - 1], key + " wrong authored faction model")
			check(team == int(evidence.hq_properties[hq_id].Team.value), key + " team differs from authored evidence")
			faction_previews += 1
		for id in nodes:
			if not rows.has(id): continue
			var raw: Dictionary = rows[id].get("raw", rows[id])
			var t: Array = raw.get("transform", [])
			if t.size() != 12 or nodes[id].has_meta("bf6_shared_spawn_owners"): continue
			# Polygon rows use baked world points; actor/spawn transforms must be untouched.
			if not rows[id].get("world_points", []).is_empty(): continue
			var transform := Transform3D.IDENTITY
			var ancestor: Node = nodes[id]
			while ancestor != built:
				if ancestor is Node3D: transform = ancestor.transform * transform
				ancestor = ancestor.get_parent()
			check(transform.origin.distance_to(Vector3(t[9], t[10], t[11])) < 0.01, key + " changed authored position " + id)
		var sectors: Node = built.get_node("Objectives/Sectors")
		check(sectors.get_child_count() == evidence.sectors.size() + 2, key + " sector count")
		for index in range(evidence.sectors.size()):
			var entry: Dictionary = evidence.sectors[index]
			var sector: Node = sectors.get_node("Sector%d" % (index + 1))
			check(sector.get_meta("bf6_source_identity") == entry.id, key + " sector identity/order")
			for property in ["HQs", "CapturePoints", "MCOMs"]:
				for member in sector.get(property):
					check(entry.members.has(member.get_meta("bf6_source_identity")), key + " foreign member")
			for id in entry.members:
				var blueprint: String = evidence.entities.get(id, "")
				if not rows.has(id): continue
				for pair in [["/gem_hq.ebx#", "HQs"], ["/gem_capturepoint.ebx#", "CapturePoints"], ["/gem_objective_mcom.ebx#", "MCOMs"]]:
					if blueprint.contains(pair[0]):
						check(nodes.has(id) and sector.get(pair[1]).has(nodes.get(id)), key + " missing authored member " + id)
			var objective_property := "MCOMs" if key.ends_with("/rush") else "CapturePoints"
			var actual_objectives: Array = []
			for objective_node in sector.get(objective_property):
				actual_objectives.append(objective_node.get_meta("bf6_source_identity"))
			var expected_objectives: Array = []
			for objective in entry.objectives:
				ordered_objectives += 1
				expected_objectives.append(objective.entity)
				if nodes.has(objective.entity):
					check(int(nodes[objective.entity].get_meta("bf6_local_objective_id")) ==
						int(objective.conditional_local_objective_id), key + " wrong local objective ID")
					check(int(nodes[objective.entity].get_meta("bf6_unique_objective_id")) ==
						int(objective.conditional_unique_objective_id), key + " wrong unique objective ID")
			check(actual_objectives == expected_objectives, key + " objective runtime order")
		for edge in evidence.attachments:
			var property: String = Exact.PIN_PROPERTIES.get(int(edge.source_pin), "")
			if property.is_empty() or not nodes.has(edge.source) or not nodes.has(edge.target): continue
			var controller: Node = nodes[edge.source]
			var target: Node = nodes[edge.target]
			var found = controller.get(property)
			if controller.has_meta("bf6_unresolved_" + property):
				check(found == null, key + " ambiguous scalar must not choose first")
				check(controller.get_meta("bf6_unresolved_" + property).has(edge.target), key + " missing ambiguous candidate")
				continue
			check(found.has(target) if found is Array else found == target, key + " wrong " + property)
			checked_links += 1
		print(key, " ", message)
		if key == "mp_atoll/rush":
			var packed := PackedScene.new()
			check(packed.pack(host) == OK, "pack exact scene")
			check(ResourceSaver.save(packed, "user://exact_progressive_roundtrip.tscn") == OK, "save exact scene")
			var reloaded: PackedScene = load("user://exact_progressive_roundtrip.tscn")
			var restored: Node = reloaded.instantiate()
			var restored_nodes := {}
			collect(restored, restored_nodes)
			check(restored_nodes.size() == nodes.size(), "roundtrip preserves identities")
			for edge in evidence.attachments:
				var property: String = Exact.PIN_PROPERTIES.get(int(edge.source_pin), "")
				if property.is_empty() or not restored_nodes.has(edge.source) or not restored_nodes.has(edge.target): continue
				var value = restored_nodes[edge.source].get(property)
				check(value.has(restored_nodes[edge.target]) if value is Array else value == restored_nodes[edge.target], "roundtrip preserves reference")
			restored.free()
			# Missing required identity must preserve the old scene, not fall back.
			var broken := document.duplicate(true)
			var removed: String = evidence.sectors[0].id
			broken.elements = broken.elements.filter(func(row): return Exact.identity(row) != removed)
			broken.objects = broken.objects.filter(func(row): return Exact.identity(row) != removed)
			var result: String = Exact.build(host, key, broken, true, Callable(), load("res://addons/bf6_gamemode_setup/classified_builder.gd"))
			check(result.begins_with("Missing exact sector") and host.get_child(0) == built, "missing-sector control preserves scene")
			var signature := membership_signature(nodes, evidence)
			var shuffled := document.duplicate(true)
			shuffled.elements.reverse()
			shuffled.objects.reverse()
			# Change every placement too: no position may determine membership.
			for row in shuffled.objects:
				if row.get("raw", {}).get("transform", []).size() == 12:
					row.raw.transform[9] = float(row.raw.transform[9]) + 100000.0
			Exact.build(host, key, shuffled, true, Callable(), load("res://addons/bf6_gamemode_setup/classified_builder.gd"))
			var shuffled_nodes := {}
			collect(host.get_child(0), shuffled_nodes)
			check(membership_signature(shuffled_nodes, evidence) == signature, "row-order/position control changes membership")
		if key == "mp_aftermath/breakthrough":
			var hq_count := 0
			for id in nodes:
				if str(evidence.entities.get(id, "")).contains("/gem_hq.ebx#"): hq_count += 1
			check(hq_count == 7, "Aftermath preserves seventh HQ")
		host.free()
	print("EXACT PROGRESSIVE: ", failures, " failures; ", checked_links, " links checked")
	print("AUTHORED FACTION PREVIEWS: ", faction_previews, "; CROSS-PARTITION AREAS: ", cross_partition_areas)
	check(hq_assignments == 240, "expected all 240 authored HQ assignments")
	check(ordered_objectives == 214, "expected all 214 runtime-ordered objectives")
	print("HQ ASSIGNMENTS: ", hq_assignments, "; RUNTIME-ORDERED OBJECTIVES: ", ordered_objectives)
	quit(1 if failures else 0)

func collect(node: Node, nodes: Dictionary) -> void:
	if node.has_meta("bf6_source_identity"):
		var id: String = node.get_meta("bf6_source_identity")
		check(not nodes.has(id), "duplicate identity " + id)
		nodes[id] = node
	check(not str(node.name).begins_with("@"), "generated node name")
	for child in node.get_children(): collect(child, nodes)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func as_int_array(values: Array) -> Array:
	return values.map(func(value): return int(value))

func membership_signature(nodes: Dictionary, evidence: Dictionary) -> Array:
	var signature: Array = []
	for entry in evidence.sectors:
		var sector: Node = nodes[entry.id]
		for property in ["HQs", "MCOMs", "CapturePoints"]:
			var ids: Array = []
			for node in sector.get(property): ids.append(node.get_meta("bf6_source_identity"))
			signature.append([entry.id, property, ids])
	return signature
