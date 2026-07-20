extends Node

const loader_version := "0.0.1"

var _mods_dir: = ""

var _mods: Array[Node] = []
var _mod_registry: = {}
var _mod_info: = {}
var _close_fired: = false

func _ready() -> void :
	var _game_version = ProjectSettings.get_setting("application/config/version", "0.0.0")
	ProjectSettings.set_setting("application/config/version", _game_version + " - (Duckloaded " + loader_version" )")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mods_dir = OS.get_executable_path().get_base_dir().path_join("mods")
	_hook_save_events()
	_load_gd_mods()


func _hook_save_events() -> void :
	var save_manager: = get_node_or_null("/root/SaveManager")

	if save_manager and save_manager.has_signal("game_loaded"):
		save_manager.game_loaded.connect(_on_game_loaded)


func _load_gd_mods() -> void :
	var dir: = DirAccess.open(_mods_dir)

	if not dir:
		print("[DuckLoader] No mods folder found at %s" % _mods_dir)
		return

	var entry_names: Array[String] = []
	dir.list_dir_begin()
	var entry: = dir.get_next()

	while entry != "":
		if not entry.begins_with("."):
			entry_names.append(entry)

		entry = dir.get_next()

	dir.list_dir_end()
	entry_names.sort()

	var descriptors: = []

	for entry_name in entry_names:
		if entry_name.begins_with("_"):
			print("[DuckLoader] Skipping disabled mod '%s'" % entry_name)
			continue

		var full_path: = _mods_dir.path_join(entry_name)
		var descriptor: Dictionary

		if DirAccess.dir_exists_absolute(full_path):
			descriptor = _build_descriptor(full_path.path_join("mod.gd"), full_path.path_join("mod.json"), entry_name)
		elif entry_name.ends_with(".gd"):
			var base_name: = entry_name.get_basename()
			descriptor = _build_descriptor(full_path, _mods_dir.path_join(base_name) + ".json", base_name)
		else:
			continue

		if descriptor:
			descriptors.append(descriptor)

	for order in _resolve_load_order(descriptors):
		_instantiate_gd_mod(order)

	print("[DuckLoader] Loaded %d mod(s)" % _mods.size())


func _build_descriptor(script_path: String, meta_path: String, fallback_name: String) -> Dictionary:
	if not FileAccess.file_exists(script_path):
		return {}

	var meta: = _read_metadata(meta_path, fallback_name)

	return {
		"id": meta.id,
		"meta": meta,
		"script_path": script_path,
		"entry_name": fallback_name,
		"load_after": meta.load_after.duplicate(),
	}


func _read_metadata(meta_path: String, fallback_name: String) -> Dictionary:
	var meta: = {
		"id": fallback_name,
		"name": fallback_name,
		"version": "unknown",
		"author": "unknown",
		"description": "",
		"load_after": [],
		"load_before": [],
	}

	if not FileAccess.file_exists(meta_path):
		return meta

	var text: = FileAccess.get_file_as_string(meta_path)
	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[DuckLoader] '%s' is not valid JSON" % meta_path)
		return meta

	for key in meta.keys():
		if parsed.has(key):
			meta[key] = parsed[key]

	return meta


func _resolve_load_order(descriptors: Array) -> Array:
	var by_id: = {}

	for d in descriptors:
		by_id[d.id] = d

	for d in descriptors:
		for target_id in d.meta.load_before:
			if by_id.has(target_id):
				by_id[target_id].load_after.append(d.id)

	var loaded: = {}
	var result: = []
	var remaining: = descriptors.duplicate()

	while remaining.size() > 0:
		var progressed: = false

		for i in remaining.size():
			var d = remaining[i]
			var ready_to_load: = true

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


func _instantiate_gd_mod(descriptor: Dictionary) -> void :
	var script: = load(descriptor.script_path)

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

	if instance.has_method("_mod_ready"):
		instance._mod_ready()

	print("[DuckLoader] Loaded mod '%s' (id=%s)" % [descriptor.entry_name, descriptor.id])


func has_mod(id: String) -> bool:
	return _mod_registry.has(id)


func get_mod(id: String) -> Node:
	return _mod_registry.get(id)


func get_mod_info(id: String) -> Dictionary:
	return _mod_info.get(id, {})


func get_loaded_mod_ids() -> Array:
	return _mod_registry.keys()


func _physics_process(delta: float) -> void :
	for mod in _mods:
		if is_instance_valid(mod) and mod.has_method("_mod_tick"):
			mod._mod_tick(delta)


func _process(delta: float) -> void :
	for mod in _mods:
		if is_instance_valid(mod) and mod.has_method("_mod_render"):
			mod._mod_render(delta)


func _on_game_loaded(success: bool) -> void :
	for mod in _mods:
		if is_instance_valid(mod) and mod.has_method("_on_game_loaded"):
			mod._on_game_loaded(success)


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_fire_game_close()


func _exit_tree() -> void :
	_fire_game_close()


func log_message(message: String) -> void :
	print(message)

	var console: = get_node_or_null("/root/DebugConsole")

	if console and console.has_method("log_line"):
		console.log_line(message)

func add_command(name: String, function: Callable, desc="") -> void:
	var console: = get_node_or_null("/root/DebugConsole")

	if console and console.has_method("add_command"):
		console.add_command(name, function, desc)

func _fire_game_close() -> void :
	if _close_fired:
		return

	_close_fired = true
 
	for mod in _mods:
		if is_instance_valid(mod) and mod.has_method("_on_game_close"):
			mod._on_game_close()
