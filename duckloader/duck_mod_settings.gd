extends RefCounted

const DuckSettingTypes: = preload("res://duckloader/duck_setting_types.gd")

const SETTINGS_DIR: = "user://mod_settings"


static func build_schema(mod_id: String, raw_settings: Array) -> Array[Dictionary]:
	var schema: Array[Dictionary] = []

	for raw_entry in raw_settings:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var normalized = DuckSettingTypes.validate_schema(raw_entry, mod_id)

		if normalized:
			schema.append(normalized)

	return schema


# probably not the safest way to do this, but it works
static func _sanitize_mod_id(mod_id: String) -> String:
	var regex: = RegEx.new()
	regex.compile("[^A-Za-z0-9_-]")
	var safe: = regex.sub(mod_id, "_", true)
	return safe if not safe.is_empty() else "_mod"


static func _settings_path(mod_id: String) -> String:
	return SETTINGS_DIR.path_join(_sanitize_mod_id(mod_id) + ".json")


static func _coerced_default(entry: Dictionary) -> Variant:
	var result: = DuckSettingTypes.coerce(entry, entry.default_value)
	return result.value if result.ok else entry.default_value


static func load_and_reconcile(mod_id: String, schema: Array[Dictionary]) -> Dictionary:
	var path: = _settings_path(mod_id)
	var saved: Dictionary = {}

	if FileAccess.file_exists(path):
		var text: = FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)

		if typeof(parsed) == TYPE_DICTIONARY:
			saved = parsed
		else:
			push_warning("[DuckLoader] Settings file for '%s' is corrupt, resetting to defaults" % mod_id)

	var value_entries: = schema.filter(func(e): return e.type not in DuckSettingTypes.NON_VALUE_TYPES)
	var values: = {}
	var changed: = not saved.is_empty() and saved.size() != value_entries.size()

	for entry in value_entries:
		var id: String = entry.id

		if saved.has(id):
			var result: = DuckSettingTypes.coerce(entry, saved[id])

			if result.ok:
				values[id] = result.value

				if result.value != saved[id]:
					changed = true
			else:
				values[id] = _coerced_default(entry)
				changed = true
		else:
			values[id] = _coerced_default(entry)
			changed = true

	if changed:
		save(mod_id, values)

	return values


static func save(mod_id: String, values: Dictionary) -> void :
	DirAccess.make_dir_recursive_absolute(SETTINGS_DIR)

	var file: = FileAccess.open(_settings_path(mod_id), FileAccess.WRITE)

	if not file:
		push_warning("[DuckLoader] Failed to save settings for '%s'" % mod_id)
		return

	file.store_string(JSON.stringify(values, "\t"))
	file.close()
