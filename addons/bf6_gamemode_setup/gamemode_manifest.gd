@tool
extends RefCounted

const EXPECTED_COUNTS := {
	"gem_hq": 2,
	"gem_capturepoint": 9,
	"gem_vehiclespawner": 40,
	"gem_insertion": 16,
	"gem_stationaryspawner": 3,
	"gem_vehicleresupplystation": 2,
	"gem_automaticaa": 2,
	"gem_specialcombatarea": 1,
	"gem_sector": 1,
}

const VEHICLE_NAMES := [
	"Abrams", "Leopard", "Cheetah", "CV90", "Gepard", "UH60",
	"Eurocopter", "AH6M", "AH64", "Vector", "Quadbike", "GolfCart",
	"Marauder", "Flyer60", "JAS39", "F22", "F16", "M2Bradley", "SU57",
	"UH60_Pax", "Marauder_Pax", "RHIB", "DirtBike", "DirtBike_Pax",
	"AH6M_Pax", "Couch", "RCB_90_Patrol_Boat",
	"RCB_90_Patrol_Boat_Pax", "F_74A_Seacat", "F_74A_Seacat_Pax",
	"FA_81F_Super_Spectre", "FA_81F_Super_Spectre_Pax",
]

var error := ""
var document: Dictionary = {}
var entities: Array = []


func load_file(path: String) -> bool:
	error = ""
	document = {}
	entities = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "could not read the game-data manifest"
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		error = "the game-data manifest is not valid JSON"
		return false
	document = parsed
	return _validate()


func gems(blueprint := "") -> Array:
	var result: Array = []
	for value in entities:
		var row := value as Dictionary
		var raw := row.get("raw", {}) as Dictionary
		var blueprint_value: Variant = row.get("gem_blueprint", null)
		if blueprint_value == null:
			blueprint_value = raw.get("gem_blueprint", null)
		var gem_blueprint := "" if blueprint_value == null else str(blueprint_value)
		if gem_blueprint == "" and int(document.get("schema", 0)) in [2, 3, 4]:
			gem_blueprint = str({2: "gem_capturepoint", 6: "gem_vehiclespawner",
				7: "gem_vehicleresupplystation", 10: "gem_specialcombatarea",
				100: "gem_hq", 101: "gem_automaticaa"}.get(int(row.get("role", 0)), ""))
		if gem_blueprint == "":
			continue
		if blueprint == "" or gem_blueprint == blueprint:
			result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var ar := a.get("raw", {}) as Dictionary
		var br := b.get("raw", {}) as Dictionary
		return int(a.get("root_order", ar.get("root_order", -1))) < \
			int(b.get("root_order", br.get("root_order", -1))))
	return result


static func vehicle_name(selector: int) -> String:
	return VEHICLE_NAMES[selector] if selector >= 0 and selector < VEHICLE_NAMES.size() else "Vehicle%d" % selector


func _validate() -> bool:
	var schema := int(document.get("schema", 0))
	if schema in [2, 3, 4]:
		return _validate_layout()
	if schema != 1:
		return _fail("unsupported game-data manifest schema")
	return _validate_legacy()


func _validate_layout() -> bool:
	var source := document.get("source", {}) as Dictionary
	if str(source.get("kind", "")) != "installed_bf6":
		return _fail("manifest provenance is not an installed BF6 build")
	entities = document.get("objects", []) as Array
	if entities.is_empty():
		return _fail("layout contains no installed game-data objects")
	for value in entities:
		if not (value is Dictionary):
			return _fail("layout contains a non-object entity")
		var row := value as Dictionary
		var raw := row.get("raw", {}) as Dictionary
		var transform := raw.get("transform", []) as Array
		if transform.size() != 12:
			return _fail("layout object has no exact 3x4 transform")
	return true


func _validate_legacy() -> bool:
	var source := document.get("source", {}) as Dictionary
	if str(source.get("kind", "")) != "installed_bf6":
		return _fail("manifest provenance is not an installed BF6 build")
	if str(source.get("level", "")).to_lower() != "mp_isolated" or str(source.get("mode", "")).to_lower() != "conquest":
		return _fail("manifest is not MP_Isolated Conquest")
	entities = document.get("entities", []) as Array
	if entities.size() != 271:
		return _fail("manifest entity census changed: expected 271, got %d" % entities.size())

	var blueprint_counts := {}
	var root_orders := {}
	var alternate_spawns := 0
	var capture_shapes := 0
	for value in entities:
		if not (value is Dictionary):
			return _fail("manifest contains a non-object entity")
		var row := value as Dictionary
		var transform := row.get("transform", []) as Array
		if transform.size() != 12:
			return _fail("entity %s has no exact 3x4 transform" % str(row.get("instance_guid", "?")))
		if str(row.get("type", "")) == "AlternateSpawnEntityData":
			alternate_spawns += 1
		var blueprint := str(row.get("gem_blueprint", ""))
		if blueprint == "":
			continue
		blueprint_counts[blueprint] = int(blueprint_counts.get(blueprint, 0)) + 1
		var order := int(row.get("root_order", -1))
		if order < 0 or root_orders.has(order):
			return _fail("GEM root order is missing or duplicated")
		root_orders[order] = true
		if blueprint == "gem_capturepoint" and row.has("gem_shape_physics"):
			capture_shapes += 1

	if alternate_spawns != 155:
		return _fail("spawn census changed: expected 155, got %d" % alternate_spawns)
	if root_orders.size() != 94 or not root_orders.has(0) or not root_orders.has(93):
		return _fail("expected all 94 authored GEM root-order slots")
	for blueprint in EXPECTED_COUNTS:
		var got := int(blueprint_counts.get(blueprint, 0))
		if got != int(EXPECTED_COUNTS[blueprint]):
			return _fail("%s census changed: expected %d, got %d" % [blueprint, EXPECTED_COUNTS[blueprint], got])
	if capture_shapes != 9:
		return _fail("not all capture points carry their bound game shape")
	var hq_rows := gems("gem_hq")
	if [int(hq_rows[0].root_order), int(hq_rows[1].root_order)] != [1, 2]:
		return _fail("HQ authored order changed")
	var capture_order: Array[int] = []
	for capture in gems("gem_capturepoint"):
		capture_order.append(int((capture as Dictionary).root_order))
	if capture_order != [3, 4, 5, 6, 7, 44, 45, 69, 70]:
		return _fail("capture-point authored order changed")
	return true


func _fail(message: String) -> bool:
	error = message
	return false
