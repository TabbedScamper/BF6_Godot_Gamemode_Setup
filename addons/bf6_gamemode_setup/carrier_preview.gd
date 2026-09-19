@tool
extends Node3D

const GEOMETRY_NAME := "Geometry"

@export_file("*.glb", "*.gltf") var source_path := ""


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("rebuild")


func rebuild() -> String:
	_clear_geometry()
	if not FileAccess.file_exists(source_path):
		return "Carrier layout has not been selected"
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(ProjectSettings.globalize_path(source_path), state)
	if error != OK:
		return "Could not read carrier layout (%s)" % error_string(error)
	var geometry := document.generate_scene(state) as Node3D
	if geometry == null:
		return "Carrier layout did not contain a 3D scene"
	geometry.name = GEOMETRY_NAME
	_convert_importer_meshes(geometry)
	add_child(geometry)
	geometry.owner = null
	# The export contains world-space transforms. Cancel the gameplay folder's
	# transform so both carriers remain aligned with their authored HQs.
	var gameplay := get_parent() as Node3D
	if gameplay != null:
		geometry.transform = gameplay.transform.affine_inverse()
	_strip_materials_and_physics(geometry)
	return "Carrier preview loaded"


func _convert_importer_meshes(node: Node) -> void:
	for child in node.get_children():
		_convert_importer_meshes(child)
	if not (node is ImporterMeshInstance3D):
		return
	var imported := node as ImporterMeshInstance3D
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = imported.name
	mesh_instance.transform = imported.transform
	if imported.mesh != null:
		mesh_instance.mesh = imported.mesh.get_mesh()
	imported.replace_by(mesh_instance)
	imported.free()


func _clear_geometry() -> void:
	for child in get_children():
		if child.name == GEOMETRY_NAME or child.owner == null:
			remove_child(child)
			child.free()


func _strip_materials_and_physics(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D:
			node.remove_child(child)
			child.free()
			continue
		_strip_materials_and_physics(child)
	if not (node is MeshInstance3D):
		return
	var mesh_instance := node as MeshInstance3D
	mesh_instance.material_override = null
	for index in range(mesh_instance.get_surface_override_material_count()):
		mesh_instance.set_surface_override_material(index, null)
	if mesh_instance.mesh is ArrayMesh:
		var clean_mesh := mesh_instance.mesh.duplicate() as ArrayMesh
		for surface in range(clean_mesh.get_surface_count()):
			clean_mesh.surface_set_material(surface, null)
		mesh_instance.mesh = clean_mesh
