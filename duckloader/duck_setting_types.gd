extends RefCounted

const SLIDER_TYPES: = ["float_slider", "int_slider"]
const INPUT_TYPES: = ["float_input", "int_input"]
const NON_VALUE_TYPES: = ["button", "label", "separator"]
const KNOWN_TYPES: = ["float_slider", "int_slider", "float_input", "int_input", "text", "checkbox", "combo_box", "color_picker", "keybind", "button", "label", "separator"]

const STEP_EPSILON: = 0.0001


static func _is_numeric(value: Variant) -> bool:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return true

	return typeof(value) == TYPE_STRING and (value as String).is_valid_float()


static func _safe_float(value: Variant, fallback: float = 0.0) -> float:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return float(value)

	if typeof(value) == TYPE_STRING and (value as String).is_valid_float():
		return (value as String).to_float()

	return fallback


static func validate_schema(entry: Dictionary, mod_id: String) -> Variant:
	var raw_id: = entry.get("id", "")
	var raw_type: = entry.get("type", "")

	if typeof(raw_id) != TYPE_STRING or raw_id.is_empty():
		push_warning("[DuckLoader] Mod '%s' has a setting with no id, ignoring it" % mod_id)
		return null

	var id: String = raw_id
	var type: = str(raw_type)

	if type not in KNOWN_TYPES:
		push_warning("[DuckLoader] Mod '%s' setting '%s' has unknown type '%s', ignoring it" % [mod_id, id, type])
		return null

	var normalized: = entry.duplicate(true)
	normalized["name"] = str(entry.get("name", id))
	normalized["tooltip"] = str(entry.get("tooltip", ""))
	normalized["category"] = str(entry.get("category", ""))

	if type in SLIDER_TYPES:
		if not (entry.has("min") and entry.has("max") and entry.has("step") and entry.has("default_value")):
			push_warning("[DuckLoader] Mod '%s' setting '%s' is missing min/max/step/default_value, ignoring it" % [mod_id, id])
			return null

		if not (_is_numeric(entry.min) and _is_numeric(entry.max) and _is_numeric(entry.step) and _is_numeric(entry.default_value)):
			push_warning("[DuckLoader] Mod '%s' setting '%s' has a non-numeric min/max/step/default_value, ignoring it" % [mod_id, id])
			return null

		var min_v: float = _safe_float(entry.min)
		var max_v: float = _safe_float(entry.max)
		var step_v: float = _safe_float(entry.step)

		if step_v <= 0.0 or min_v >= max_v:
			push_warning("[DuckLoader] Mod '%s' setting '%s' has an invalid min/max/step, ignoring it" % [mod_id, id])
			return null

		var steps: = (max_v - min_v) / step_v

		if absf(steps - roundf(steps)) > STEP_EPSILON:
			push_warning("[DuckLoader] Mod '%s' setting '%s' step %s doesn't evenly fit between min %s and max %s, ignoring it" % [mod_id, id, step_v, min_v, max_v])
			return null

		normalized["min"] = min_v
		normalized["max"] = max_v
		normalized["step"] = step_v
		normalized["default_value"] = _safe_float(entry.default_value)

	elif type in INPUT_TYPES:
		if not (entry.has("min") and entry.has("max") and entry.has("default_value")):
			push_warning("[DuckLoader] Mod '%s' setting '%s' is missing min/max/default_value, ignoring it" % [mod_id, id])
			return null

		if not (_is_numeric(entry.min) and _is_numeric(entry.max) and _is_numeric(entry.default_value)):
			push_warning("[DuckLoader] Mod '%s' setting '%s' has a non-numeric min/max/default_value, ignoring it" % [mod_id, id])
			return null

		if _safe_float(entry.min) >= _safe_float(entry.max):
			push_warning("[DuckLoader] Mod '%s' setting '%s' has min >= max, ignoring it" % [mod_id, id])
			return null

		normalized["min"] = _safe_float(entry.min)
		normalized["max"] = _safe_float(entry.max)
		normalized["default_value"] = _safe_float(entry.default_value)

	elif type == "text":
		normalized["allow_empty"] = bool(entry.get("allow_empty", true))
		normalized["max_len"] = int(_safe_float(entry.get("max_len", 255), 255))

		if normalized["max_len"] <= 0:
			push_warning("[DuckLoader] Mod '%s' setting '%s' has an invalid max_len, ignoring it" % [mod_id, id])
			return null

		if not entry.has("default_value"):
			push_warning("[DuckLoader] Mod '%s' setting '%s' is missing default_value, ignoring it" % [mod_id, id])
			return null

	elif type == "checkbox":
		if not entry.has("default_value"):
			push_warning("[DuckLoader] Mod '%s' setting '%s' is missing default_value, ignoring it" % [mod_id, id])
			return null

	elif type == "combo_box":
		if not (entry.has("values") and entry.has("default_value")):
			push_warning("[DuckLoader] Mod '%s' setting '%s' is missing values/default_value, ignoring it" % [mod_id, id])
			return null

		var raw_values = entry.values

		if typeof(raw_values) != TYPE_ARRAY or raw_values.is_empty():
			push_warning("[DuckLoader] Mod '%s' setting '%s' has an empty/invalid values list, ignoring it" % [mod_id, id])
			return null

		var options: Array[Dictionary] = []
		var default_found: = false

		for pair in raw_values:
			if typeof(pair) != TYPE_ARRAY or pair.size() != 2:
				push_warning("[DuckLoader] Mod '%s' setting '%s' has a malformed value entry, ignoring it" % [mod_id, id])
				return null

			options.append({"id": pair[0], "label": str(pair[1])})

			if pair[0] == entry.default_value:
				default_found = true

		if not default_found:
			push_warning("[DuckLoader] Mod '%s' setting '%s' default_value isn't in its values list, ignoring it" % [mod_id, id])
			return null

		normalized["values"] = options

	elif type == "color_picker":
		if not entry.has("default_value"):
			push_warning("[DuckLoader] Mod '%s' setting '%s' is missing default_value, ignoring it" % [mod_id, id])
			return null

		var hex: = str(entry.default_value)

		if not Color.html_is_valid(hex):
			push_warning("[DuckLoader] Mod '%s' setting '%s' has an invalid default_value color, ignoring it" % [mod_id, id])
			return null

		normalized["default_value"] = hex

	elif type == "keybind":
		if not entry.has("default_value") or typeof(entry.default_value) not in [TYPE_INT, TYPE_FLOAT]:
			push_warning("[DuckLoader] Mod '%s' setting '%s' is missing a valid default_value, ignoring it" % [mod_id, id])
			return null

		normalized["default_value"] = int(entry.default_value)

	elif type == "button":
		normalized["label"] = str(entry.get("label", normalized.name))

	elif type == "label":
		normalized["text"] = str(entry.get("text", ""))

	return normalized


static func coerce(entry: Dictionary, raw_value: Variant) -> Dictionary:
	var type: String = entry.type

	match type:
		"float_slider":
			return _coerce_slider(entry, raw_value, false)
		"int_slider":
			return _coerce_slider(entry, raw_value, true)
		"float_input":
			return _coerce_number_input(entry, raw_value, false)
		"int_input":
			return _coerce_number_input(entry, raw_value, true)
		"text":
			return _coerce_text(entry, raw_value)
		"checkbox":
			return {"ok": true, "value": bool(raw_value), "error": ""}
		"combo_box":
			return _coerce_combo(entry, raw_value)
		"color_picker":
			return _coerce_color(entry, raw_value)
		"keybind":
			return _coerce_keybind(entry, raw_value)

	return {"ok": false, "value": entry.get("default_value"), "error": "Unknown setting type"}


static func _snap_to_step(value: float, min_v: float, max_v: float, step_v: float) -> float:
	value = clampf(value, min_v, max_v)
	var n: = roundf((value - min_v) / step_v)
	return clampf(min_v + n * step_v, min_v, max_v)


static func _coerce_slider(entry: Dictionary, raw_value: Variant, is_int: bool) -> Dictionary:
	var num: float

	if typeof(raw_value) in [TYPE_FLOAT, TYPE_INT]:
		num = float(raw_value)
	elif typeof(raw_value) == TYPE_STRING and (raw_value as String).is_valid_float():
		num = (raw_value as String).to_float()
	else:
		num = float(entry.default_value)

	var snapped: = _snap_to_step(num, entry.min, entry.max, entry.step)

	return {"ok": true, "value": (roundi(snapped) if is_int else snapped), "error": ""}


static func _coerce_number_input(entry: Dictionary, raw_value: Variant, is_int: bool) -> Dictionary:
	var text: = str(raw_value)
	var valid: = text.is_valid_int() if is_int else text.is_valid_float()

	if typeof(raw_value) in [TYPE_FLOAT, TYPE_INT]:
		valid = true

	if not valid:
		return {"ok": false, "value": null, "error": "'%s' isn't a valid number" % text}

	var num: float = float(raw_value) if typeof(raw_value) in [TYPE_FLOAT, TYPE_INT] else text.to_float()
	num = clampf(num, entry.min, entry.max)

	return {"ok": true, "value": (roundi(num) if is_int else num), "error": ""}


static func _is_valid_utf8(text: String) -> bool:
	var buffer: = text.to_utf8_buffer()
	return buffer.get_string_from_utf8() == text


static func _coerce_text(entry: Dictionary, raw_value: Variant) -> Dictionary:
	var text: = str(raw_value)

	if not _is_valid_utf8(text):
		return {"ok": true, "value": str(entry.default_value), "error": ""}

	if not entry.allow_empty and text.strip_edges().is_empty():
		return {"ok": false, "value": null, "error": "This setting can't be empty"}

	if text.length() > int(entry.max_len):
		text = text.substr(0, entry.max_len)

	return {"ok": true, "value": text, "error": ""}


static func _coerce_combo(entry: Dictionary, raw_value: Variant) -> Dictionary:
	for option in entry.values:
		if option.id == raw_value:
			return {"ok": true, "value": option.id, "error": ""}

	return {"ok": false, "value": null, "error": "'%s' isn't a valid option" % str(raw_value)}


static func _coerce_color(entry: Dictionary, raw_value: Variant) -> Dictionary:
	var hex: String

	if raw_value is Color:
		hex = (raw_value as Color).to_html(true)
	else:
		hex = str(raw_value)

	if not Color.html_is_valid(hex):
		return {"ok": false, "value": null, "error": "'%s' isn't a valid color" % hex}

	return {"ok": true, "value": hex, "error": ""}


static func _coerce_keybind(_entry: Dictionary, raw_value: Variant) -> Dictionary:
	if typeof(raw_value) not in [TYPE_INT, TYPE_FLOAT]:
		return {"ok": false, "value": null, "error": "Invalid key"}

	return {"ok": true, "value": int(raw_value), "error": ""}
