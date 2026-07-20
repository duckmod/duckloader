extends CanvasLayer

var _background: Control
var _mod_list_box: VBoxContainer
var _detail_box: VBoxContainer
var _mod_buttons: = {}
var _mod_button_group: ButtonGroup
var _default_icon: Texture2D
var _keybind_listener: Variant = null

var _pending_mod_id: = ""
var _pending_values: = {}
var _baseline_values: = {}
var _control_refresh: = {}
var _control_errors: = {}


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	_default_icon = DuckLoader.get_default_icon_texture()
	_mod_button_group = ButtonGroup.new()
	_build_ui()
	_populate_mod_list()


func get_background() -> Control:
	return _background


func _input(event: InputEvent) -> void :
	if _keybind_listener == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var listener: = _keybind_listener
		_keybind_listener = null

		var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode

		if keycode != KEY_ESCAPE:
			_pending_values[listener.setting_id] = keycode

		listener.button.text = _key_display_text(_pending_values.get(listener.setting_id, _baseline_values.get(listener.setting_id, 0)))
		get_viewport().set_input_as_handled()


func _key_display_text(keycode: int) -> String:
	return OS.get_keycode_string(keycode) if keycode != 0 else "Unbound"


func _load_icon(mod_id: String) -> Texture2D:
	var path: = DuckLoader.get_mod_icon_path(mod_id)

	if path == "":
		return _default_icon

	var img: = Image.new()

	if img.load(path) != OK:
		return _default_icon

	img.resize(64, 64)
	return ImageTexture.create_from_image(img)


func _build_ui() -> void :
	_background = Control.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_background)

	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.add_child(dim)

	var margin: = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	_background.add_child(margin)

	var root_vbox: = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	var header: = HBoxContainer.new()
	root_vbox.add_child(header)

	var title: = Label.new()
	title.text = "Mod Settings"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn: = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): MenuManager.close_current_menu())
	header.add_child(close_btn)

	var panes: = HBoxContainer.new()
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panes.add_theme_constant_override("separation", 16)
	root_vbox.add_child(panes)

	var left_scroll: = ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(260, 0)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panes.add_child(left_scroll)

	_mod_list_box = VBoxContainer.new()
	_mod_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_mod_list_box)

	var right_scroll: = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panes.add_child(right_scroll)

	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 10)
	right_scroll.add_child(_detail_box)


func _populate_mod_list() -> void :
	for child in _mod_list_box.get_children():
		child.queue_free()

	_mod_buttons.clear()

	var ids: = DuckLoader.get_mods_with_settings()
	ids.sort()

	if ids.is_empty():
		var empty: = Label.new()
		empty.text = "No mods with settings installed."
		_mod_list_box.add_child(empty)
		return

	for mod_id in ids:
		var meta: = DuckLoader.get_mod_info(mod_id)
		var row: = Button.new()
		row.toggle_mode = true
		row.button_group = _mod_button_group
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "  " + str(meta.get("name", mod_id))
		row.icon = _load_icon(mod_id)
		row.pressed.connect(_on_mod_selected.bind(mod_id))
		_mod_list_box.add_child(row)
		_mod_buttons[mod_id] = row

	_on_mod_selected(ids[0])


func _on_mod_selected(mod_id: String) -> void :
	if _mod_buttons.has(mod_id):
		_mod_buttons[mod_id].button_pressed = true

	for child in _detail_box.get_children():
		child.queue_free()

	_pending_mod_id = mod_id
	_pending_values = {}
	_baseline_values = {}
	_control_refresh = {}
	_control_errors = {}
	_keybind_listener = null

	var meta: = DuckLoader.get_mod_info(mod_id)

	var header: = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_detail_box.add_child(header)

	var icon_rect: = TextureRect.new()
	icon_rect.texture = _load_icon(mod_id)
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon_rect)

	var name_box: = VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_box)

	var name_label: = Label.new()
	name_label.text = str(meta.get("name", mod_id))
	name_label.add_theme_font_size_override("font_size", 22)
	name_box.add_child(name_label)

	var version_label: = Label.new()
	version_label.text = "v%s by %s" % [meta.get("version", "unknown"), meta.get("author", "unknown")]
	name_box.add_child(version_label)

	var save_btn: = Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_save_pending_changes)
	header.add_child(save_btn)

	_detail_box.add_child(HSeparator.new())

	var schema: = DuckLoader.get_mod_settings_schema(mod_id)
	var current_category: = ""

	for entry in schema:
		if entry.category != "" and entry.category != current_category:
			current_category = entry.category
			var cat_label: = Label.new()
			cat_label.text = entry.category
			cat_label.add_theme_font_size_override("font_size", 16)
			_detail_box.add_child(cat_label)

		_detail_box.add_child(_build_setting_control(mod_id, entry))

	_detail_box.add_child(HSeparator.new())

	var desc_label: = Label.new()
	desc_label.text = str(meta.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_box.add_child(desc_label)


func _get_current_value(mod_id: String, entry: Dictionary) -> Variant:
	match entry.type:
		"float_slider", "float_input":
			return DuckLoader.getFloat(mod_id, entry.id)
		"int_slider", "int_input", "combo_box":
			return DuckLoader.getInt(mod_id, entry.id)
		"text":
			return DuckLoader.getString(mod_id, entry.id)
		"checkbox":
			return DuckLoader.getBool(mod_id, entry.id)
		"color_picker":
			return DuckLoader.getColor(mod_id, entry.id)
		"keybind":
			return DuckLoader.getInt(mod_id, entry.id)

	return null


func _build_setting_control(mod_id: String, entry: Dictionary) -> Control:
	if entry.type == "separator":
		return HSeparator.new()

	if entry.type == "label":
		var text_label: = Label.new()
		text_label.text = entry.text
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		return text_label

	if entry.type == "button":
		var action_btn: = Button.new()
		action_btn.text = entry.label
		action_btn.pressed.connect(func(): DuckLoader.trigger_mod_action(mod_id, entry.id))
		return action_btn

	var wrapper: = VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)

	var label: = Label.new()
	label.text = entry.name

	if entry.tooltip != "":
		label.tooltip_text = entry.tooltip

	wrapper.add_child(label)

	var error_label: = Label.new()
	error_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	error_label.visible = false

	var current: Variant = _get_current_value(mod_id, entry)
	_baseline_values[entry.id] = current
	_pending_values[entry.id] = current
	_control_errors[entry.id] = error_label

	match entry.type:
		"float_slider", "int_slider":
			var is_int: bool = entry.type == "int_slider"
			var row: = HBoxContainer.new()
			var slider: = HSlider.new()
			slider.min_value = entry.min
			slider.max_value = entry.max
			slider.step = entry.step
			slider.value = current
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var value_label: = Label.new()
			value_label.custom_minimum_size = Vector2(50, 0)
			value_label.text = str(current)
			slider.value_changed.connect(func(v):
				var staged = roundi(v) if is_int else v
				_pending_values[entry.id] = staged
				value_label.text = str(staged)
			)
			row.add_child(slider)
			row.add_child(value_label)
			wrapper.add_child(row)
			_control_refresh[entry.id] = func(value):
				value_label.text = str(value)
				slider.set_value_no_signal(value)

		"float_input", "int_input":
			var line: = LineEdit.new()
			line.text = str(current)
			line.text_changed.connect(func(t): _pending_values[entry.id] = t)
			wrapper.add_child(line)
			_control_refresh[entry.id] = func(value): line.text = str(value)

		"text":
			var line: = LineEdit.new()
			line.text = current
			line.max_length = entry.max_len
			line.text_changed.connect(func(t): _pending_values[entry.id] = t)
			wrapper.add_child(line)
			_control_refresh[entry.id] = func(value): line.text = value

		"checkbox":
			var check: = CheckBox.new()
			check.button_pressed = current
			check.toggled.connect(func(pressed): _pending_values[entry.id] = pressed)
			wrapper.add_child(check)
			_control_refresh[entry.id] = func(value): check.set_pressed_no_signal(value)

		"combo_box":
			var option: = OptionButton.new()
			var select_index: = 0

			for i in entry.values.size():
				var opt: Dictionary = entry.values[i]
				option.add_item(str(opt.label))
				option.set_item_metadata(i, opt.id)

				if opt.id == current:
					select_index = i

			option.select(select_index)
			option.item_selected.connect(func(index):
				_pending_values[entry.id] = option.get_item_metadata(index)
			)
			wrapper.add_child(option)
			_control_refresh[entry.id] = func(value):
				for i in entry.values.size():
					if entry.values[i].id == value:
						option.select(i)
						break

		"color_picker":
			var picker: = ColorPickerButton.new()
			picker.color = current
			picker.custom_minimum_size = Vector2(60, 30)
			picker.color_changed.connect(func(c): _pending_values[entry.id] = c)
			wrapper.add_child(picker)
			_control_refresh[entry.id] = func(value): picker.color = Color(value)

		"keybind":
			var key_btn: = Button.new()
			key_btn.text = _key_display_text(current)
			key_btn.pressed.connect(func():
				key_btn.text = "Press a key... (Esc to cancel)"
				_keybind_listener = {"mod_id": mod_id, "setting_id": entry.id, "button": key_btn}
			)
			wrapper.add_child(key_btn)
			_control_refresh[entry.id] = func(value): key_btn.text = _key_display_text(value)

	wrapper.add_child(error_label)
	return wrapper


func _save_pending_changes() -> void :
	if _pending_mod_id == "":
		return

	for setting_id in _pending_values.keys():
		var pending = _pending_values[setting_id]
		var baseline = _baseline_values.get(setting_id)

		if pending == baseline:
			continue

		var result: = DuckLoader.set_mod_setting(_pending_mod_id, setting_id, pending)
		var error_label: Label = _control_errors.get(setting_id)

		if error_label:
			_show_error(error_label, result)

		_baseline_values[setting_id] = result.value
		_pending_values[setting_id] = result.value

		var refresh: Callable = _control_refresh.get(setting_id)

		if refresh:
			refresh.call(result.value)


func _show_error(error_label: Label, result: Dictionary) -> void :
	error_label.visible = not result.valid

	if not result.valid:
		error_label.text = result.error
