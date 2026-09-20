@tool
extends Node

const REPO := "TabbedScamper/BF6_Godot_Gamemode_Setup"
const INDEX_URL := "https://raw.githubusercontent.com/%s/main/gamemode_index.json"
const DATA_TAG := "layouts-v1.1.0"
const RELEASE_API := "https://api.github.com/repos/%s/releases/tags/%s"
const CACHE_DIR := "user://bf6_gamemode_setup/layouts"
const USER_AGENT := "BF6-Game-Mode-Setup"

var error := ""
var _index: Dictionary = {}
var _assets: Dictionary = {}
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 0.0
	add_child(_http)


func fetch_index() -> bool:
	error = ""
	var body := await _http_get(INDEX_URL % REPO)
	if body.is_empty():
		error = "could not reach the game-mode index"
		return false
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("layouts"):
		error = "the game-mode index is not valid"
		return false
	_index = (parsed as Dictionary)["layouts"]
	return true


func layouts_for(level: String) -> Array:
	var rows: Array = []
	for key in _index:
		var entry: Dictionary = _index[key]
		if str(entry.get("level", "")).to_lower() != level.to_lower():
			continue
		var row := entry.duplicate(true)
		row["key"] = key
		rows.append(row)
	rows.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return rows


func ensure_layout(entry: Dictionary) -> Dictionary:
	error = ""
	var result := {}
	for part in ["manifest", "carriers"]:
		var asset := str(entry.get(part, ""))
		if asset == "":
			continue
		var path := await ensure(asset)
		if path == "":
			return {}
		result[part] = path
	return result


func ensure(asset: String) -> String:
	error = ""
	if is_cached(asset):
		return cached_path(asset)
	if _assets.is_empty() and not await _fetch_asset_urls():
		return ""
	if not _assets.has(asset):
		error = "%s is not published in %s" % [asset, DATA_TAG]
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	var destination := cached_path(asset)
	var partial := destination + ".part"
	if not await _get_to_file(str(_assets[asset]), partial):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(partial))
		error = "the %s download did not complete" % asset
		return ""
	var expected: Dictionary = _file_entry(asset)
	var file := FileAccess.open(partial, FileAccess.READ)
	var bytes := file.get_length() if file != null else -1
	if file != null:
		file.close()
	if bytes != int(expected.get("bytes", -1)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(partial))
		error = "%s has the wrong file size" % asset
		return ""
	var checksum := str(expected.get("sha256", ""))
	if checksum != "" and sha256_of(partial) != checksum:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(partial))
		error = "%s failed checksum verification" % asset
		return ""
	var absolute_destination := ProjectSettings.globalize_path(destination)
	DirAccess.remove_absolute(absolute_destination)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(partial), absolute_destination) != OK:
		error = "could not move %s into the cache" % asset
		return ""
	return destination


func cached_path(asset: String) -> String:
	return "%s/%s" % [CACHE_DIR, asset]


func is_cached(asset: String) -> bool:
	var path := cached_path(asset)
	if not FileAccess.file_exists(path):
		return false
	var expected := _file_entry(asset)
	if expected.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	var bytes := file.get_length() if file != null else -1
	if file != null:
		file.close()
	if bytes != int(expected.get("bytes", -1)):
		return false
	var checksum := str(expected.get("sha256", ""))
	return checksum == "" or sha256_of(path) == checksum


func clear_cache() -> void:
	var directory := DirAccess.open(CACHE_DIR)
	if directory == null:
		return
	for filename in directory.get_files():
		directory.remove(filename)


func cache_bytes() -> int:
	var total := 0
	var directory := DirAccess.open(CACHE_DIR)
	if directory == null:
		return total
	for filename in directory.get_files():
		var file := FileAccess.open("%s/%s" % [CACHE_DIR, filename], FileAccess.READ)
		if file != null:
			total += file.get_length()
			file.close()
	return total


func _file_entry(asset: String) -> Dictionary:
	for entry in _index.values():
		for file in (entry as Dictionary).get("files", []):
			if file is Dictionary and str(file.get("name", "")) == asset:
				return file
	return {}


func _fetch_asset_urls() -> bool:
	var body := await _http_get(RELEASE_API % [REPO, DATA_TAG])
	if body.is_empty():
		error = "could not read the %s layout release" % DATA_TAG
		return false
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		error = "the layout release listing is not valid JSON"
		return false
	for asset in (parsed as Dictionary).get("assets", []):
		if asset is Dictionary:
			_assets[str(asset.get("name", ""))] = str(asset.get("browser_download_url", ""))
	if _assets.is_empty():
		error = "the layout release has no assets"
		return false
	return true


func _http_get(url: String) -> PackedByteArray:
	_http.download_file = ""
	for attempt in range(4):
		if attempt > 0:
			await get_tree().create_timer(0.4 * pow(2.0, attempt - 1)).timeout
		if _http.request(url, _headers(), HTTPClient.METHOD_GET) != OK:
			continue
		var response: Array = await _http.request_completed
		if int(response[0]) == HTTPRequest.RESULT_SUCCESS and int(response[1]) == 200:
			return response[3]
	return PackedByteArray()


func _get_to_file(url: String, destination: String) -> bool:
	for attempt in range(4):
		if attempt > 0:
			await get_tree().create_timer(0.4 * pow(2.0, attempt - 1)).timeout
		_http.download_file = ProjectSettings.globalize_path(destination)
		if _http.request(url, _headers(), HTTPClient.METHOD_GET) != OK:
			continue
		var response: Array = await _http.request_completed
		_http.download_file = ""
		if int(response[0]) == HTTPRequest.RESULT_SUCCESS and int(response[1]) == 200:
			return true
	_http.download_file = ""
	return false


func _headers() -> PackedStringArray:
	return PackedStringArray(["User-Agent: " + USER_AGENT, "Accept: */*"])


static func sha256_of(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var chunk := file.get_buffer(1 << 22)
		if chunk.is_empty():
			break
		context.update(chunk)
	file.close()
	return context.finish().hex_encode()
