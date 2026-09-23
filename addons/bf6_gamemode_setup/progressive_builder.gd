@tool
extends RefCounted

# Identity-only progressive import. No distance, containment or root-order joins.
const LINKS := "res://addons/bf6_gamemode_setup/data/progressive_links.json"
const PIN_PROPERTIES := {
	0xB545C66B: "HQArea", 0x3CA9EBF6: "CaptureArea", 0x95A790AE: "SectorArea",
	0xDCF5607C: "InfantrySpawns", 0x8FF15F16: "ForwardSpawns",
	0x28E44183: "InfantrySpawnPoints_Team1", 0x28E44180: "InfantrySpawnPoints_Team2",
	0x28560453: "RetreatArea", 0xA35AD585: "RetreatFromArea",
	0xFF7B1F9E: "AdvanceFromArea", 0xEA60BA73: "AdvanceToArea",
}
const ARRAY_PROPERTIES := ["InfantrySpawns", "ForwardSpawns",
	"InfantrySpawnPoints_Team1", "InfantrySpawnPoints_Team2"]

static func identity(row: Dictionary) -> String:
	var raw: Dictionary = row.get("raw", row)
	return str(raw.get("partition", "")) + "#" + str(raw.get("instance_guid", ""))

static func build(owner: Node, layout_id: String, document: Dictionary,
		replace_existing: bool, progress: Callable, helper, paths: Dictionary = {}) -> String:
	var pack = JSON.parse_string(FileAccess.get_file_as_string(LINKS))
	if not pack is Dictionary:
		return "Exact progressive links are unavailable; no heuristic layout was built."
	var source: Dictionary = document.get("source", {})
	var key: String = str(source.get("level", "")).to_lower() + "/" + str(source.get("mode", ""))
	if str(source.get("mode", "")) not in ["rush", "breakthrough"]:
		return "Exact progressive importer only accepts Rush or Breakthrough."
	var evidence: Dictionary = pack.get("layouts", {}).get(key, {})
	if evidence.is_empty() or evidence.get("sectors", []).is_empty():
		return "Exact progressive selection is unresolved for %s; existing scene preserved." % key
	var rows := {}
	for row in document.get("elements", []):
		rows[identity(row)] = {"raw": row}
	for row in document.get("objects", []):
		rows[identity(row)] = row
	for id in evidence.get("supplemental_rows", {}):
		var supplement: Dictionary = evidence.supplemental_rows[id]
		if identity(supplement.row) != id:
			return "Invalid cross-partition endpoint identity; existing scene preserved."
		if not rows.has(id): rows[id] = supplement.row
	# Refuse partial sector identities before replacing an existing layout.
	for sector in evidence.sectors:
		if not rows.has(sector.id):
			return "Missing exact sector %s; existing scene preserved." % sector.id
		var objective_ids := {}
		for objective in sector.get("objectives", []):
			var objective_id: String = str(objective.get("entity", ""))
			if objective_id.is_empty() or objective_ids.has(objective_id) or \
					int(objective.get("conditional_local_objective_id", 0)) <= 0 or \
					int(objective.get("conditional_unique_objective_id", 0)) <= 0:
				return "Invalid exact objective order for %s; existing scene preserved." % sector.id
			objective_ids[objective_id] = true
			if not sector.members.has(objective_id):
				return "Ordered objective is not a sector member; existing scene preserved."
		for member_id in sector.members:
			var blueprint: String = str(evidence.get("entities", {}).get(member_id, ""))
			if blueprint.contains("/gem_hq.ebx#"):
				var properties: Dictionary = evidence.get("hq_properties", {}).get(member_id, {})
				if not properties.has("Team") or not properties.has("AltTeam") or \
						int(properties.Team.get("value", 0)) not in [1, 2] or \
						int(properties.AltTeam.get("value", 0)) not in [1, 2]:
					return "Missing exact HQ team evidence for %s; existing scene preserved." % member_id
	var existing: Node = helper._find(owner, layout_id)
	if existing != null:
		if not replace_existing:
			existing.visible = true
			return "Shown existing layout"
		owner.remove_child(existing)
		existing.free()
	var root := Node3D.new()
	root.name = "Rush" if source.mode == "rush" else "Breakthrough"
	owner.add_child(root)
	root.owner = owner
	root.set_meta("bf6_gamemode_setup", layout_id)
	root.set_meta("bf6_source", "installed game links: " + str(evidence.layout))
	root.set_meta("bf6_order_status", str(pack.status))
	root.set_meta("bf6_order_conditions", pack.conditions)
	root.set_meta("bf6_hq_control_baseline", pack.get("hq_control_baseline", {}))
	root.set_meta("bf6_hq_activation_by_sector_status",
		pack.get("hq_activation_by_sector_status", {}))
	root.set_meta("bf6_objective_order_finding", str(pack.get("objective_order_finding", "")))
	root.set_meta("bf6_template_compatibility", "Andy Rush/Breakthrough Blockly contract")
	var objectives: Node = helper._folder(root, "Objectives", owner)
	var sector_folder: Node = helper._folder(objectives, "Sectors", owner)
	var nodes := {}
	var warnings: Array[String] = []
	var sector_nodes: Array = []
	var entities: Dictionary = evidence.entities
	# Boundary wrappers are Portal compatibility objects, not fabricated game sectors.
	for index in range(evidence.sectors.size() + 2):
		var sector: Node3D = helper._scene("sector", "Sector%d" % index)
		sector.set("ObjId", 100 + index)
		sector.set_meta("bf6_template_contract", "Portal sector wrapper/ObjId")
		sector_folder.add_child(sector)
		sector.owner = owner
		sector_nodes.append(sector)
		if index == 0 or index == evidence.sectors.size() + 1:
			sector.set_meta("bf6_boundary_sector", "compatibility-only; no inferred volume")
			continue
		var entry: Dictionary = evidence.sectors[index - 1]
		sector.transform = helper._raw_transform(rows[entry.id])
		register_node(sector, entry.id, nodes)
		sector.set_meta("bf6_order_basis", "selected layout graph/link order")
		sector.set_meta("bf6_progressive_phase", index - 1)
		var hqs: Array = []
		var captures: Array = []
		var mcoms: Array = []
		var objective_records := {}
		var ordered_objective_ids: Array = []
		for objective in entry.get("objectives", []):
			var objective_id: String = str(objective.get("entity", ""))
			objective_records[objective_id] = objective
			ordered_objective_ids.append(objective_id)
		var ordered_members: Array = []
		for member_id in entry.members:
			if not ordered_objective_ids.has(member_id): ordered_members.append(member_id)
		ordered_members.append_array(ordered_objective_ids)
		for id in ordered_members:
			var blueprint: String = str(entities.get(id, ""))
			var kind := ""
			if blueprint.contains("/gem_hq.ebx#"): kind = "hq"
			elif blueprint.contains("/gem_capturepoint.ebx#"): kind = "capture"
			elif blueprint.contains("/gem_objective_mcom.ebx#"): kind = "mcom"
			if kind.is_empty(): continue
			if not rows.has(id):
				warnings.append("Missing %s controller: %s" % [kind, id])
				continue
			var node: Node3D = nodes.get(id)
			if node == null:
				node = helper._scene(kind, "%s_%s" % [kind, str(id).get_slice("#", 1).left(8)])
				sector.add_child(node)
				node.owner = owner
				node.transform = sector.transform.affine_inverse() * helper._raw_transform(rows[id])
				register_node(node, id, nodes)
				node.set_meta("bf6_root_order", helper._root_order(rows[id]))
				node.set_meta("bf6_template_contract", "IDs/initial teams are Portal compatibility, not retail activation")
				if kind == "hq":
					node.set("ObjId", -1)
					var properties: Dictionary = evidence.get("hq_properties", {}).get(id, {})
					for property in ["Team", "AltTeam"]:
						node.set(property, int(properties.get(property, {}).get("value", 0)))
						node.set_meta("bf6_authored_" + property, properties.get(property, {}))
					node.set_meta("bf6_team_status",
						"standard authored baseline: Team 1 attacks, Team 2 defends")
					node.set_meta("bf6_hq_control_baseline", pack.get("hq_control_baseline", {}))
				elif kind == "mcom":
					var objective: Dictionary = objective_records.get(id, {})
					var local_id := int(objective.conditional_local_objective_id)
					node.name = "MCOM-%s" % String.chr(64 + local_id)
					node.set("ObjId", 200 + (index - 1) * 2 + local_id if local_id <= 2 else -1)
					node.set_meta("bf6_local_objective_id", local_id)
					node.set_meta("bf6_unique_objective_id",
						int(objective.get("conditional_unique_objective_id", -1)))
					if local_id > 2: warnings.append("More than two MCOMs in template phase; extra ObjId left -1")
				else:
					var objective: Dictionary = objective_records.get(id, {})
					var local_id := int(objective.conditional_local_objective_id)
					node.name = "CapturePoint%s" % String.chr(64 + local_id)
					node.set("ObjId", 1099 + (index - 1) * 100 + local_id)
					node.set_meta("bf6_local_objective_id", local_id)
					node.set_meta("bf6_unique_objective_id",
						int(objective.get("conditional_unique_objective_id", -1)))
					node.set("InitialOwner", 2)
					node.set_meta("bf6_template_adjustment", "InitialOwner Team 2 and 1100+ phase IDs are Blockly compatibility")
					node.set_meta("bf6_capture_root_order", helper._root_order(rows[id]))
			if kind == "hq": hqs.append(node)
			elif kind == "capture": captures.append(node)
			else: mcoms.append(node)
		for property in ["HQs", "CapturePoints", "MCOMs"]:
			helper._set_array(sector, property, hqs if property == "HQs" else (captures if property == "CapturePoints" else mcoms))
		for hq in hqs:
			var team := int(hq.get("Team"))
			var activation: Dictionary = pack.get("hq_activation_by_sector_status", {})
			hq.set_meta("bf6_active_sector_statuses",
				activation.get("team_%d_active" % team, []))
			hq.set_meta("bf6_sector_status_names", activation.get("status_names", {}))
			var same_team := 0
			for candidate in hqs:
				if int(candidate.get("Team")) == team: same_team += 1
			if same_team == 1 and team in [1, 2]:
				hq.set("ObjId", (300 if team == 1 else 400) + index)
				hq.name = "TEAM_%d_HQ%d" % [team, index]
			else:
				warnings.append("Ambiguous template HQ slot; ObjId left -1: " + str(hq.get_meta("bf6_source_identity")))
		if progress.is_valid(): progress.call("Linking game sectors", index, evidence.sectors.size())
	var arrays := {}
	var spawn_owners := {}
	var scalar_targets := {}
	for edge in evidence.attachments:
		var property: String = PIN_PROPERTIES.get(int(edge.source_pin), "")
		if property.is_empty() or property in ARRAY_PROPERTIES: continue
		var scalar_key: String = str(edge.source) + "/" + property
		if not scalar_targets.has(scalar_key): scalar_targets[scalar_key] = []
		if not scalar_targets[scalar_key].has(edge.target): scalar_targets[scalar_key].append(edge.target)
	var linked_count := 0
	for edge in evidence.attachments:
		var property: String = PIN_PROPERTIES.get(int(edge.source_pin), "")
		if property.is_empty() or not nodes.has(edge.source): continue
		var controller: Node = nodes[edge.source]
		if not helper._has_property(controller, property):
			warnings.append("SDK property unavailable: %s on %s" % [property, edge.source])
			continue
		if not rows.has(edge.target):
			warnings.append("Missing %s endpoint: %s" % [property, edge.target])
			continue
		var target: Node3D = nodes.get(edge.target)
		if target == null:
			var row: Dictionary = rows[edge.target]
			var target_name: String = str(edge.target).get_slice("#", 1).left(8)
			if edge.target_kind == "player_spawn":
				target = helper._scene("spawn", "Spawn_" + target_name)
				target.transform = helper._raw_transform(row)
				target.set_meta("bf6_spawn_binding", "authored attachment pin")
			elif edge.target_kind == "polygon_volume" and row.get("world_points", []).size() >= 9:
				target = helper._polygon(row, "Area_" + target_name, Color(0.2, 0.65, 0.8, 0.35))
			else:
				warnings.append("Unsupported/missing geometry: " + str(edge.target))
				continue
			# Neutral layout-space parent avoids inherited HQ pitch/roll; shared targets
			# remain one object with multiple inspector references.
			var parent: Node = helper._folder(root, "Spawns" if edge.target_kind == "player_spawn" else "Play Area", owner)
			parent.add_child(target)
			target.owner = owner
			register_node(target, edge.target, nodes)
			if evidence.get("supplemental_rows", {}).has(edge.target):
				target.set_meta("bf6_cross_partition_sources", evidence.supplemental_rows[edge.target].source_layouts)
		var array_key: String = str(edge.source) + "/" + property
		if not property in ARRAY_PROPERTIES and scalar_targets.get(array_key, []).size() > 1:
			controller.set(property, null)
			controller.set_meta("bf6_unresolved_" + property, scalar_targets[array_key])
			warnings.append("Multiple game targets cannot fit Portal scalar " + array_key)
			continue
		if property in ARRAY_PROPERTIES:
			if not arrays.has(array_key): arrays[array_key] = []
			if not arrays[array_key].has(target): arrays[array_key].append(target)
			helper._set_array(controller, property, arrays[array_key])
		elif controller.get(property) == null or controller.get(property) == target:
			controller.set(property, target)
		else:
			warnings.append("Multiple distinct targets for scalar " + array_key)
			continue
		linked_count += 1
		if edge.target_kind == "player_spawn":
			if not spawn_owners.has(edge.target): spawn_owners[edge.target] = []
			if not spawn_owners[edge.target].has(controller): spawn_owners[edge.target].append(controller)
	for id in spawn_owners:
		var spawn: Node3D = nodes[id]
		if spawn_owners[id].size() == 1:
			var parent: Node3D = spawn_owners[id][0]
			# Builders also run before nodes enter SceneTree. Do not read global_transform.
			var authored: Transform3D = helper._raw_transform(rows[id])
			var parent_transform := Transform3D.IDENTITY
			var ancestor: Node = parent
			while ancestor != root:
				if ancestor is Node3D: parent_transform = ancestor.transform * parent_transform
				ancestor = ancestor.get_parent()
			spawn.owner = null
			spawn.get_parent().remove_child(spawn)
			parent.add_child(spawn)
			spawn.transform = parent_transform.affine_inverse() * authored
			spawn.owner = owner
		else:
			spawn.set_meta("bf6_shared_spawn_owners", spawn_owners[id].map(func(node): return node.get_meta("bf6_source_identity")))
	# Preserve exact selected vehicle records without inventing faction choice.
	for id in entities:
		if not rows.has(id): continue
		var row: Dictionary = rows[id]
		if int(row.get("role", 0)) != 6: continue
		var stationary: bool = row.get("stationary", false)
		var selector: int = row.get("gem_value", -1)
		var types: Array = helper.VEHICLE_CLASS_TYPES.get(selector, [])
		var vehicle_type: int = helper.STATIONARY_SELECTOR_TYPES.get(selector, -1) if stationary else (int(types[0]) if types.size() == 1 else -1)
		var parent: Node = helper._folder(root, "Emplacements" if stationary else "Vehicles", owner)
		var vehicle: Node3D = helper._create_vehicle(row, parent, owner, selector, vehicle_type,
			"Class%d" % selector, stationary, vehicle_type >= 0)
		register_node(vehicle, id, nodes)
		vehicle.set("ObjId", -1)
		vehicle.set("P_AutoSpawnEnabled", true)
		vehicle.set_meta("bf6_source_vehicle_record", true)
		vehicle.set_meta("bf6_vehicle_type_status", "exact class; faction unresolved" if vehicle_type < 0 else "single concrete type")
		if vehicle_type < 0: warnings.append("Vehicle faction requires runtime-role mapping: " + str(id))
	# Other selected placements keep their existing SDK rendering helpers.
	for id in entities:
		if nodes.has(id) or not rows.has(id): continue
		var row: Dictionary = rows[id]
		var role := int(row.get("role", 0))
		if role == 7:
			var parent: Node = helper._folder(root, "Resupply", owner)
			var resupply: Node3D = helper._add_plain(row, "resupply", parent, owner)
			register_node(resupply, id, nodes)
			helper.VehicleSkin.sync_resupply(resupply, owner)
		elif role == 101:
			var parent: Node = helper._folder(root, "AA-Defences", owner)
			var aa: Node3D = helper._add_plain(row, "automatic_aa", parent, owner)
			register_node(aa, id, nodes)
			if int(row.get("team", 0)) > 0: aa.set("OwnerTeam", int(row.team))
			var shape: Dictionary = row.get("protection_shape", {})
			if not shape.is_empty():
				var protection: Node3D = helper._spatial_protection_polygon(shape, "Protection_" + str(id).get_slice("#", 1).left(8))
				parent.add_child(protection)
				protection.owner = owner
				aa.set("ProtectionAreaVolume", protection)
			helper.VehicleSkin.sync_automatic_aa(aa, owner)
	# Vehicle ownership follows the recovered membership graph, never area overlap.
	var adjacency := {}
	var vehicle_owners := {}
	for edge in evidence.memberships:
		if not adjacency.has(edge.source): adjacency[edge.source] = []
		adjacency[edge.source].append(edge.target)
	for id in nodes:
		var node: Node = nodes[id]
		if not str(entities.get(id, "")).contains("/gem_hq.ebx#"): continue
		var pending: Array = adjacency.get(id, []).duplicate()
		var seen := {}
		var vehicles: Array = []
		while not pending.is_empty():
			var child: String = pending.pop_back()
			if seen.has(child): continue
			seen[child] = true
			pending.append_array(adjacency.get(child, []))
			if nodes.has(child) and str(entities.get(child, "")).contains("/gem_vehiclespawner.ebx#"):
				vehicles.append(nodes[child])
				if not vehicle_owners.has(child): vehicle_owners[child] = []
				vehicle_owners[child].append(node)
		helper._set_array(node, "VehicleSpawners", vehicles)
		node.set("VehicleSpawnersEnabled", not vehicles.is_empty())
		node.set_meta("bf6_vehicle_membership", "selected GEM membership graph; activation remains runtime-fed")
	for id in vehicle_owners:
		var owners: Array = vehicle_owners[id]
		# A unique graph owner supplies an authored faction preview. Shared owners
		# must not silently choose one of their potentially different factions.
		if owners.size() != 1: continue
		var team := int(owners[0].get("Team"))
		if team not in [1, 2]: continue
		var vehicle: Node3D = nodes[id]
		var selector := int(vehicle.get_meta("bf6_retail_selector", -1))
		var types: Array = helper.VEHICLE_CLASS_TYPES.get(selector, [])
		if types.size() != 2: continue
		var vehicle_type := int(types[team - 1])
		vehicle.set("VehicleType", vehicle_type)
		vehicle.set_meta("bf6_vehicle_type_status", "authored HQ Team + faction class; not live activation")
		vehicle.set_meta("bf6_vehicle_faction_source", owners[0].get_meta("bf6_source_identity"))
		vehicle.set_meta("bf6_vehicle_faction_team", team)
		vehicle.set_meta("bf6_vehicle_faction_candidates", types)
		helper.VehicleSkin.sync_spawner(vehicle, owner)
		warnings.erase("Vehicle faction requires runtime-role mapping: " + str(id))
	var camera_elements: Array = []
	for element in document.get("elements", []):
		if entities.has(identity(element)): camera_elements.append(element)
	if not camera_elements.is_empty():
		var extras: Node = helper._folder(root, "Extras", owner)
		helper._build_deploy_cameras(camera_elements, extras, owner)
		if extras.get_child_count() == 0: extras.free()
	root.set_meta("bf6_exact_attachment_count", linked_count)
	root.set_meta("bf6_import_warnings", warnings)
	if not str(paths.get("carriers", "")).is_empty():
		var carrier = helper.CarrierPreview.new()
		carrier.name = "Aircraft Carriers (hide to disable preview)"
		carrier.source_path = str(paths.carriers)
		root.add_child(carrier)
		carrier.owner = owner
		carrier.rebuild()
	helper._refresh_team_volume_colors(root)
	helper._prune_empty_folders(root)
	helper._sort_generated_hierarchy(root)
	return "Built %s: %d exact sectors, %d attachment links; %d unresolved records (see bf6_import_warnings)." % [key, evidence.sectors.size(), linked_count, warnings.size()]

static func register_node(node: Node, id: String, nodes: Dictionary) -> void:
	nodes[id] = node
	node.set_meta("bf6_source_identity", id)
	node.set_meta("bf6_source_instance_guid", id.get_slice("#", 1))
