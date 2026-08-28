extends Node

const loader_version := "0.3.0"

const DuckModSettings: = preload("res://duckloader/duck_mod_settings.gd")
const DuckSettingTypes: = preload("res://duckloader/duck_setting_types.gd")

var _mods_dir: = ""

var _mods: Array[Node] = []
var _mod_registry: = {}
var _mod_info: = {}
var _mod_dirs: = {}
var _mod_schemas: = {}
var _mod_settings: = {}
var _close_fired: = false
var _default_icon_texture: Texture2D = null

var _keybind_pressed_state: = {}
var _keybind_pressed_prev: = {}


func _ready() -> void:
	var _game_version = ProjectSettings.get_setting("application/config/version", "0.0.0")
	ProjectSettings.set_setting("application/config/version", _game_version + " - (Duckloader " + loader_version + ")")
	clean_shader_cache()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mods_dir = OS.get_executable_path().get_base_dir().path_join("mods")
	_hook_save_events()
	_load_gd_mods()


func _hook_save_events() -> void:
	var save_manager:= get_node_or_null("/root/SaveManager")

	if save_manager and save_manager.has_signal("game_loaded"):
		save_manager.game_loaded.connect(_on_game_loaded)


func _load_gd_mods() -> void:
	var dir:= DirAccess.open(_mods_dir)

	if not dir:
		print("[DuckLoader] No mods folder found at %s" % _mods_dir)
		return

	var entry_names: Array[String] = []
	dir.list_dir_begin()
	var entry:= dir.get_next()

	while entry != "":
		if not entry.begins_with("."):
			entry_names.append(entry)

		entry = dir.get_next()

	dir.list_dir_end()
	entry_names.sort()

	var descriptors:= []

	for entry_name in entry_names:
		if entry_name.begins_with("_"):
			print("[DuckLoader] Skipping disabled mod '%s'" % entry_name)
			continue

		var full_path:= _mods_dir.path_join(entry_name)
		var descriptor: Dictionary

		if entry_name.ends_with(".pck"):
			var success = ProjectSettings.load_resource_pack(_mods_dir.path_join(entry_name))

			if !success:
				# TODO: Make a gui for when asome mod couldnt load
				# or when a error occurs after load
				# like what forge does in minecraft.
				printerr("[DuckLoader] Mod pck '%s' couldn't be loaded!" % entry_name)
				continue

			if success:
				var base_name:= entry_name.get_basename()

				var json_path := "res://mod".path_join(base_name).path_join(base_name) + ".json"
				var entry_path := "res://mod".path_join(base_name).path_join(base_name)+ ".gd"
				var mod_dir := "res://mod".path_join(base_name)
				descriptor = _build_descriptor(entry_path, json_path, base_name, true, mod_dir)

				if descriptor:
					descriptors.append(descriptor)

				continue

		if DirAccess.dir_exists_absolute(full_path):
			descriptor = _build_descriptor(full_path.path_join("mod.gd"), full_path.path_join("mod.json"), entry_name, false, full_path)

		elif entry_name.ends_with(".gd"):
			var base_name:= entry_name.get_basename()
			descriptor = _build_descriptor(full_path, _mods_dir.path_join(base_name) + ".json", base_name, false, _mods_dir)
		elif entry_name.ends_with(".json"):
			continue
		else:
			log_message("[DuckLoader] Couldn't load mod '%s': it's neither a .gd script nor a .pck mod." % entry_name)
			continue

		if descriptor:
			descriptors.append(descriptor)

	for order in _resolve_load_order(descriptors):
		_instantiate_gd_mod(order)

	print("[DuckLoader] Loaded %d mod(s)" % _mods.size())


func _build_descriptor(script_path: String, meta_path: String, fallback_name: String, is_pck: bool, mod_dir) -> Dictionary:

	if not FileAccess.file_exists(script_path) and !is_pck:
		return {}

	#var script: Script = load(script_path)
	#var instance = script.new()
	#add_child(instance)
	#if instance.has_method("_mod_ready"):
		#instance._mod_ready()

	var meta:= _read_metadata(meta_path, fallback_name, is_pck)

	return {
		"id": meta.id,
		"meta": meta,
		"script_path": script_path,
		"entry_name": fallback_name,
		"load_after": meta.load_after.duplicate(),
		"mod_dir": mod_dir,
	}


func _read_metadata(meta_path: String, fallback_name: String, is_pck: bool) -> Dictionary:
	var meta:= {
		"id": fallback_name,
		"name": fallback_name,
		"version": "unknown",
		"author": "unknown",
		"description": "",
		"pck_mod": is_pck,
		"load_after": [],
		"load_before": [],
		"icon": "",
		"settings": [],
	}

	if not FileAccess.file_exists(meta_path) and !is_pck:
		return meta

	var text:= FileAccess.get_file_as_string(meta_path)
	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[DuckLoader] '%s' is not valid JSON" % meta_path)
		return meta

	for key in meta.keys():
		if parsed.has(key):
			meta[key] = parsed[key]

	if typeof(meta.id) != TYPE_STRING or meta.id.is_empty():
		push_warning("[DuckLoader] '%s' has an invalid 'id', falling back to '%s'" % [meta_path, fallback_name])
		meta.id = fallback_name

	var raw_icon = meta.icon

	if typeof(raw_icon) != TYPE_STRING:
		if raw_icon != null and str(raw_icon) != "":
			push_warning("[DuckLoader] '%s' has an invalid 'icon', ignoring it" % meta_path)
		meta.icon = ""
	else:
		var icon_str: String = raw_icon
		var is_res_path: bool = icon_str.begins_with("res://")
		var is_invalid_abs: bool = icon_str.is_absolute_path() and not is_res_path

		if icon_str.is_empty() or is_invalid_abs or ".." in icon_str:
			if icon_str != "":
				push_warning("[DuckLoader] '%s' has an invalid 'icon', ignoring it" % meta_path)
			meta.icon = ""

	if typeof(meta.settings) != TYPE_ARRAY:
		push_warning("[DuckLoader] '%s' has a non-array 'settings', ignoring it" % meta_path)
		meta.settings = []

	if typeof(meta.load_after) != TYPE_ARRAY:
		push_warning("[DuckLoader] '%s' has a non-array 'load_after', ignoring it" % meta_path)
		meta.load_after = []
	else:
		meta.load_after = meta.load_after.filter(func(x): return typeof(x) == TYPE_STRING)

	if typeof(meta.load_before) != TYPE_ARRAY:
		push_warning("[DuckLoader] '%s' has a non-array 'load_before', ignoring it" % meta_path)
		meta.load_before = []
	else:
		meta.load_before = meta.load_before.filter(func(x): return typeof(x) == TYPE_STRING)

	for str_key in ["name", "version", "author", "description"]:
		if typeof(meta[str_key]) != TYPE_STRING:
			meta[str_key] = str(meta[str_key])

	return meta


func _resolve_load_order(descriptors: Array) -> Array:
	var by_id:= {}

	for d in descriptors:
		by_id[d.id] = d

	for d in descriptors:
		for target_id in d.meta.load_before:
			if by_id.has(target_id):
				by_id[target_id].load_after.append(d.id)

	var loaded:= {}
	var result:= []
	var remaining:= descriptors.duplicate()

	while remaining.size() > 0:
		var progressed:= false

		for i in remaining.size():
			var d = remaining[i]
			var ready_to_load:= true

			for dep_id in d.load_after:
				if by_id.has(dep_id) and not loaded.has(dep_id):
					ready_to_load = false
					break

			if ready_to_load:
				result.append(d)
				loaded[d.id] = true
				remaining.remove_at(i)
				progressed = true
				break

		if not progressed:
			for d in remaining:
				push_warning("[DuckLoader] Unsatisfiable load order for '%s', loading anyway" % d.id)
				result.append(d)
				loaded[d.id] = true

			remaining.clear()

	return result


func _instantiate_gd_mod(descriptor: Dictionary) -> void:

	var script := load(descriptor.script_path)

	if not script is GDScript:
		push_warning("[DuckLoader] '%s' is not a valid script" % descriptor.script_path)
		return

	var instance = script.new()

	if not instance is Node:
		push_warning("[DuckLoader] Mod '%s' must extend Node" % descriptor.entry_name)
		return

	instance.name = descriptor.entry_name
	add_child(instance)
	_mods.append(instance)
	_mod_registry[descriptor.id] = instance
	_mod_info[descriptor.id] = descriptor.meta
	_mod_dirs[descriptor.id] = descriptor.mod_dir

	_load_mod_settings(descriptor.id, instance, descriptor.meta.settings)

	if instance.has_method("_mod_ready"):
		instance._mod_ready()

	print("[DuckLoader] Loaded mod '%s' (id=%s)" % [descriptor.entry_name, descriptor.id])


func _load_mod_settings(mod_id: String, instance: Node, raw_settings: Array) -> void :
	var schema: = DuckModSettings.build_schema(mod_id, raw_settings)
	_mod_schemas[mod_id] = schema

	if schema.is_empty():
		_mod_settings[mod_id] = {}
		return

	var values: = DuckModSettings.load_and_reconcile(mod_id, schema)

	for entry in schema:
		if entry.type in DuckSettingTypes.NON_VALUE_TYPES:
			continue

		var id: String = entry.id

		if instance.has_method("_mod_setting_update"):
			var result = instance._mod_setting_update(id, values[id])

			if typeof(result) == TYPE_DICTIONARY and not result.get("valid", true):
				push_warning("[DuckLoader] Mod '%s' rejected its own startup value for '%s' (%s), using default" % [mod_id, id, result.get("error", "")])
				var fallback: = DuckSettingTypes.coerce(entry, entry.default_value)
				values[id] = fallback.value if fallback.ok else entry.default_value

	_mod_settings[mod_id] = values
	DuckModSettings.save(mod_id, values)


func has_mod(id: String) -> bool:
	return _mod_registry.has(id)


func get_mod(id: String) -> Node:
	return _mod_registry.get(id)


func get_mod_info(id: String) -> Dictionary:
	return _mod_info.get(id, {})


func get_loaded_mod_ids() -> Array:
	return _mod_registry.keys()


func get_float(mod_id: String, setting_id: String) -> float: return float(_mod_settings.get(mod_id, {}).get(setting_id, 0.0))
func get_int(mod_id: String, setting_id: String) -> int: return int(_mod_settings.get(mod_id, {}).get(setting_id, 0))
func get_string(mod_id: String, setting_id: String) -> String: return str(_mod_settings.get(mod_id, {}).get(setting_id, ""))
func get_bool(mod_id: String, setting_id: String) -> bool: return bool(_mod_settings.get(mod_id, {}).get(setting_id, false))
func get_color(mod_id: String, setting_id: String) -> Color:
	var hex: = get_string(mod_id, setting_id)
	return Color(hex) if Color.html_is_valid(hex) else Color.WHITE

# Aliases (camelCase)
func getFloat(mod_id: String, setting_id: String) -> float: return get_float(mod_id, setting_id)
func getInt(mod_id: String, setting_id: String) -> int: return get_int(mod_id, setting_id)
func getString(mod_id: String, setting_id: String) -> String: return get_string(mod_id, setting_id)
func getBool(mod_id: String, setting_id: String) -> bool: return get_bool(mod_id, setting_id)
func getColor(mod_id: String, setting_id: String) -> Color: return get_color(mod_id, setting_id)

func get_mods_with_settings() -> Array:
	var ids: = []

	for mod_id in _mod_schemas.keys():
		if not _mod_schemas[mod_id].is_empty():
			ids.append(mod_id)

	return ids


func get_mod_settings_schema(mod_id: String) -> Array:
	return _mod_schemas.get(mod_id, [])


func get_mod_icon_path(mod_id: String) -> String:
	var meta: = get_mod_info(mod_id)
	var dir: String = _mod_dirs.get(mod_id, "")

	if dir == "" or meta.get("icon", "") == "":
		return ""

	var raw_icon: String = meta.icon
	var path: String = ""

	if raw_icon.begins_with("res://"):
		path = raw_icon
	else:
		path = dir.path_join(raw_icon)

	if path.begins_with("res://"):
		return path if ResourceLoader.exists(path) or FileAccess.file_exists(path) else ""

	return path if FileAccess.file_exists(path) else ""


func get_default_icon_texture() -> Texture2D:
	if _default_icon_texture:
		return _default_icon_texture

	var path: = OS.get_executable_path().get_base_dir().path_join("duckloader/icon.png")

	if FileAccess.file_exists(path):
		var img: = Image.new()

		if img.load(path) == OK:
			img.resize(64, 64)
			_default_icon_texture = ImageTexture.create_from_image(img)
			return _default_icon_texture

	_default_icon_texture = _build_fallback_icon()
	return _default_icon_texture


func _build_fallback_icon() -> ImageTexture:
	var img: = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.35, 0.35, 0.4))

	for i in range(4, 60):
		img.set_pixel(i, 4, Color.WHITE)
		img.set_pixel(i, 59, Color.WHITE)
		img.set_pixel(4, i, Color.WHITE)
		img.set_pixel(59, i, Color.WHITE)

	return ImageTexture.create_from_image(img)


func set_mod_setting(mod_id: String, setting_id: String, raw_value: Variant) -> Dictionary:
	var schema: Array = _mod_schemas.get(mod_id, [])
	var entry: Variant = null

	for candidate in schema:
		if candidate.id == setting_id:
			entry = candidate
			break

	if entry == null:
		return {"valid": false, "error": "Unknown setting", "value": null}

	var old_value = _mod_settings.get(mod_id, {}).get(setting_id, entry.default_value)
	var result: = DuckSettingTypes.coerce(entry, raw_value)

	if not result.ok:
		return {"valid": false, "error": result.error, "value": old_value}

	var instance: = get_mod(mod_id)

	if instance and is_instance_valid(instance) and instance.has_method("_mod_setting_update"):
		var mod_result = instance._mod_setting_update(setting_id, result.value)

		if typeof(mod_result) == TYPE_DICTIONARY and not mod_result.get("valid", true):
			return {"valid": false, "error": mod_result.get("error", "Rejected by mod"), "value": old_value}

	if not _mod_settings.has(mod_id):
		_mod_settings[mod_id] = {}

	_mod_settings[mod_id][setting_id] = result.value
	DuckModSettings.save(mod_id, _mod_settings[mod_id])

	return {"valid": true, "error": "", "value": result.value}


func trigger_mod_action(mod_id: String, setting_id: String) -> void :
	var instance: = get_mod(mod_id)

	if instance and is_instance_valid(instance) and instance.has_method("_mod_setting_action"):
		instance._mod_setting_action(setting_id)


func open_mod_menu() -> void :
	var menu: = preload("res://duckloader/duck_mod_menu.gd").new()
	menu.ready.connect(func():
		MenuManager.register_scaled_menu(menu.get_background())
		MenuManager.open_menu(menu)
	)
	get_tree().current_scene.add_child(menu)


func _physics_process(delta: float) -> void :
	_update_keybind_states()

	for mod in _mods:
		if is_instance_valid(mod) and mod.has_method("_mod_tick"):
			mod._mod_tick(delta)


func _update_keybind_states() -> void :
	for mod_id in _mod_schemas.keys():
		for entry in _mod_schemas[mod_id]:
			if entry.type != "keybind":
				continue

			var key: String = mod_id + ":" + str(entry.id)
			var keycode: = get_int(mod_id, entry.id)
			var pressed: = keycode != 0 and Input.is_physical_key_pressed(keycode)

			_keybind_pressed_prev[key] = _keybind_pressed_state.get(key, false)
			_keybind_pressed_state[key] = pressed


func get_keybind(mod_id: String, setting_id: String) -> int:
	return get_int(mod_id, setting_id)


func get_keybind_name(mod_id: String, setting_id: String) -> String:
	var keycode: = get_keybind(mod_id, setting_id)

	if keycode == 0:
		return "Unbound"

	var label: = DisplayServer.keyboard_get_label_from_physical(keycode)
	return OS.get_keycode_string(label if label != KEY_NONE else keycode)


func is_keybind_pressed(mod_id: String, setting_id: String) -> bool:
	return _keybind_pressed_state.get(mod_id + ":" + setting_id, false)


func is_keybind_just_pressed(mod_id: String, setting_id: String) -> bool:
	var key: = mod_id + ":" + setting_id
	return _keybind_pressed_state.get(key, false) and not _keybind_pressed_prev.get(key, false)


func is_keybind_just_released(mod_id: String, setting_id: String) -> bool:
	var key: = mod_id + ":" + setting_id
	return _keybind_pressed_prev.get(key, false) and not _keybind_pressed_state.get(key, false)


func _process(delta: float) -> void:
	for mod in _mods:
		if is_instance_valid(mod) and mod.has_method("_mod_render"):
			mod._mod_render(delta)


func _on_game_loaded(success: bool) -> void:
	for mod in _mods:
		if is_instance_valid(mod) and mod.has_method("_on_game_loaded"):
			mod._on_game_loaded(success)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_fire_game_close()


func _exit_tree() -> void:
	_fire_game_close()


func log_message(message: String) -> void:
	print(message)

	var console:= get_node_or_null("/root/DebugConsole")

	if console and console.has_method("log_line"):
		console.log_line(message)


func add_command(name: String, function: Callable, desc="") -> void:
	var console:= get_node_or_null("/root/DebugConsole")

	if console and console.has_method("add_command"):
		console.add_command(name, function, desc)


func _fire_game_close() -> void:
	if _close_fired:
		return

	_close_fired = true

	for mod in _mods:
		if is_instance_valid(mod) and mod.has_method("_on_game_close"):
			mod._on_game_close()

func clean_shader_cache(app_id: String = "4026250", max_age_days: int = 1):
	log_message("start cleanup")
	var exe_path = OS.get_executable_path()
	
	var steamapps_idx = exe_path.to_lower().find("steamapps")
	
	var cache_path = ""
	
	if steamapps_idx != -1:
		var base_steamapps_path = exe_path.substr(0, steamapps_idx + 9)
		cache_path = base_steamapps_path.path_join("shadercache").path_join(app_id).path_join("fozpipelinesv6")
	else:
		log_message("[DuckLoader] 'steamapps' not found in path. Using standard user cache.")
		cache_path = "user://shader_cache"
	
	var dir = DirAccess.open(cache_path)
	
	if dir:
		var current_time = Time.get_unix_time_from_system()
		var max_age_seconds = max_age_days * 24 * 60 * 60
		var deleted_count = 0
		
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			var file_time
			if !dir.current_is_dir():
				var full_file_path = cache_path + "/" + file_name
				file_time = FileAccess.get_modified_time(full_file_path)
				
			if (current_time - file_time) > max_age_seconds:
					dir.remove(file_name) 
					deleted_count += 1
					
			file_name = dir.get_next()
			
		log_message("[DuckLoader] Cleared " + str(deleted_count) + " old shader files from: " + cache_path)
	else:
		log_message("[DuckLoader] Could not open shader cache directory at: " + cache_path)
