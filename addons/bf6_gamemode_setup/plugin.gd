@tool
extends EditorPlugin

const Builder = preload("gamemode_builder.gd")
const Fetch = preload("layout_fetch.gd")
const VehicleSkin = preload("vehicle_skin.gd")
const TemplateAddons = preload("template_addons.gd")

var _dock: VBoxContainer
var _map_label: Label
var _layout: OptionButton
var _status: Label
var _clear_button: Button
var _template_addons_button: Button
var _progress_box: VBoxContainer
var _progress_label: Label
var _progress_bar: ProgressBar
var _fetch: Node
var _listed_map := ""
var _rows: Array = []
var _busy := false
var _vehicle_scan_elapsed := 0.0


func _enter_tree() -> void:
	_fetch = Fetch.new()
	_fetch.name = "LayoutFetch"
	add_child(_fetch)
	_create_dock()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	scene_changed.connect(_on_scene_changed)
	set_process(true)
	_refresh_map()


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
	if _fetch != null:
		_fetch.queue_free()


func _create_dock() -> void:
	_dock = VBoxContainer.new()
	_dock.name = "BF6 Game Mode Setup"
	_dock.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "BF6 Game Mode Setup"
	_dock.add_child(title)
	_map_label = Label.new()
	_map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock.add_child(_map_label)
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Game mode"
	row.add_child(label)
	_layout = OptionButton.new()
	_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layout.add_item("Off")
	_layout.tooltip_text = "Downloads and builds the complete layout published for this map. Files are verified and cached."
	_layout.get_popup().about_to_popup.connect(_fill_layouts)
	_layout.item_selected.connect(_on_layout_selected)
	row.add_child(_layout)
	_dock.add_child(row)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(220, 0)
	_dock.add_child(_status)
	_progress_box = VBoxContainer.new()
	_progress_box.visible = false
	_progress_label = Label.new()
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_box.add_child(_progress_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(220, 18)
	_progress_bar.show_percentage = true
	_progress_box.add_child(_progress_bar)
	_dock.add_child(_progress_box)
	_template_addons_button = Button.new()
	_template_addons_button.text = "Andys Template Addons"
	_template_addons_button.tooltip_text = "Add Andy's TeamSwitcher, AI Spawns, and EndGameCamera template objects at the origin."
	_template_addons_button.pressed.connect(_add_template_addons)
	_dock.add_child(_template_addons_button)
	_clear_button = Button.new()
	_clear_button.text = "Clear downloaded layouts"
	_clear_button.pressed.connect(_clear_cache)
	_dock.add_child(_clear_button)


func _root() -> Node:
	return get_editor_interface().get_edited_scene_root()


func _map_name() -> String:
	var root := _root()
	if root == null:
		return ""
	var explicit := str(root.get_meta("bf6_base_level", ""))
	if explicit.begins_with("MP_") and not explicit.contains("/") and not explicit.contains("\\"):
		return explicit
	var fallback := String(root.name)
	return fallback if fallback.begins_with("MP_") else ""


func _on_scene_changed(_scene: Node) -> void:
	_listed_map = ""
	_rows.clear()
	_layout.clear()
	_layout.add_item("Off")
	_refresh_map()
	call_deferred("_sync_vehicle_skins")


func _process(delta: float) -> void:
	_vehicle_scan_elapsed += delta
	if _vehicle_scan_elapsed < 0.25:
		return
	_vehicle_scan_elapsed = 0.0
	_sync_vehicle_skins()


func _sync_vehicle_skins() -> void:
	var root := _root()
	if root != null:
		VehicleSkin.sync_tree(root)


func _refresh_map() -> void:
	var map := _map_name()
	if map == "":
		_map_label.text = "Open a Battlefield Portal map to begin."
		_status.text = ""
	else:
		_map_label.text = "Map: %s" % map
		_status.text = "Open the Game mode list to check published layouts."
	_update_cache_button()


func _fill_layouts() -> void:
	var map := _map_name()
	if map == "" or map == _listed_map or _busy:
		return
	_busy = true
	_status.text = "Checking published layouts…"
	if not await _fetch.fetch_index():
		_status.text = "Layout list failed: " + str(_fetch.error)
		_busy = false
		return
	_rows = _fetch.layouts_for(map)
	_layout.clear()
	_layout.add_item("Off")
	for entry in _rows:
		var bytes := 0
		for file in (entry as Dictionary).get("files", []):
			bytes += int((file as Dictionary).get("bytes", 0))
		_layout.add_item("%s  (%s)" % [str(entry.get("name", "Layout")), String.humanize_size(bytes)])
	_listed_map = map
	_status.text = "%d published layout(s) for %s." % [_rows.size(), map]
	_busy = false


func _on_layout_selected(index: int) -> void:
	if _busy:
		return
	if index == 0:
		Builder.hide_all(_root())
		_status.text = "Game-mode layouts hidden."
		return
	if index - 1 >= _rows.size():
		return
	_busy = true
	_layout.disabled = true
	var entry: Dictionary = _rows[index - 1]
	_status.text = "Downloading and verifying %s…" % str(entry.get("name", "layout"))
	var paths: Dictionary = await _fetch.ensure_layout(entry)
	if paths.is_empty():
		_status.text = "Layout download failed: " + str(_fetch.error)
	else:
		_progress_box.visible = true
		_status.text = Builder.build(_root(), str(entry.get("key", "")), paths, false,
			_report_build_progress)
		_progress_box.visible = false
		if _status.text.begins_with("Tsuru Reef Conquest built") or _status.text.begins_with("Built "):
			get_editor_interface().mark_scene_as_unsaved()
			var node := Builder.find_build(_root(), str(entry.get("key", "")))
			if node != null:
				get_editor_interface().get_selection().clear()
				get_editor_interface().get_selection().add_node(node)
	_layout.disabled = false
	_busy = false
	_update_cache_button()


func _report_build_progress(message: String, current: int, total: int) -> void:
	_progress_label.text = message
	_progress_bar.max_value = maxi(total, 1)
	_progress_bar.value = clampi(current, 0, maxi(total, 1))
	# Scene construction is editor-thread-only. Force a UI repaint at each
	# checkpoint so large layouts never look like an unexplained lockup.
	DisplayServer.process_events()
	RenderingServer.force_draw(true)


func _clear_cache() -> void:
	if _busy:
		return
	_fetch.clear_cache()
	_update_cache_button()
	_status.text = "Downloaded layout files cleared. Existing scene nodes were not changed."


func _add_template_addons() -> void:
	if _busy:
		return
	var root := _root()
	var target := _selected_build(root)
	if target == null:
		_status.text = "Build or select a generated game-mode layout first."
		return
	var result := TemplateAddons.add_to(target, root)
	_status.text = str(result.get("message", "Template addons could not be added."))
	if int(result.get("added", 0)) <= 0:
		return
	get_editor_interface().mark_scene_as_unsaved()
	var added_node := result.get("node") as Node
	if added_node != null:
		get_editor_interface().get_selection().clear()
		get_editor_interface().get_selection().add_node(added_node)


func _selected_build(root: Node) -> Node:
	if root == null:
		return null
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	for selected_node in selected:
		var candidate := selected_node as Node
		while candidate != null and candidate != root:
			if candidate.has_meta(Builder.BUILD_META):
				return candidate
			candidate = candidate.get_parent()
	if _layout.selected > 0 and _layout.selected - 1 < _rows.size():
		var key := str((_rows[_layout.selected - 1] as Dictionary).get("key", ""))
		var current := Builder.find_build(root, key)
		if current != null:
			return current
	var visible_builds: Array[Node] = []
	var all_builds: Array[Node] = []
	for child in root.get_children():
		if child.has_meta(Builder.BUILD_META):
			all_builds.append(child)
			if not (child is Node3D) or (child as Node3D).visible:
				visible_builds.append(child)
	if visible_builds.size() == 1:
		return visible_builds[0]
	return all_builds[0] if all_builds.size() == 1 else null


func _update_cache_button() -> void:
	var bytes: int = int(_fetch.cache_bytes()) if _fetch != null else 0
	_clear_button.text = "Clear downloaded layouts" if bytes == 0 else "Clear downloaded layouts (%s)" % String.humanize_size(bytes)
