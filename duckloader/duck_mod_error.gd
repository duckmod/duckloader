extends CanvasLayer

var _background: ColorRect
var _vbox: VBoxContainer
var _button_grid: GridContainer
var _error_log: VBoxContainer
var _header_subtitle: Label
var _error_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func get_background() -> Control:
	return _background

func _build_ui() -> void:
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0.18, 0.05, 0.05, 0.8)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_background.theme = load("res://assets/main_menu.tres")
	add_child(_background)

	var main_margin := MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 40)
	main_margin.add_theme_constant_override("margin_top", 40)
	main_margin.add_theme_constant_override("margin_right", 40)
	main_margin.add_theme_constant_override("margin_bottom", 40)
	_background.add_child(main_margin)

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	main_margin.add_child(_vbox)

	var header_title := Label.new()
	header_title.text = "Error loading mods"
	header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_title.add_theme_color_override("font_color", Color(1.0, 0, 0))
	header_title.add_theme_font_size_override("font_size", 42)
	_vbox.add_child(header_title)

	_header_subtitle = Label.new()
	_update_header_text()
	_header_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_subtitle.add_theme_color_override("font_color", Color(1.0, 0, 0))
	_header_subtitle.add_theme_font_size_override("font_size", 30)
	_vbox.add_child(_header_subtitle)

	var separator_top := HSeparator.new()
	_vbox.add_child(separator_top)

	var spacer_top := Control.new()
	spacer_top.custom_minimum_size.y = 15
	_vbox.add_child(spacer_top)
	
	var scroll_container := ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_vbox.add_child(scroll_container)

	_error_log = VBoxContainer.new()
	_error_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_error_log.add_theme_constant_override("v_separation", 16)
	scroll_container.add_child(_error_log)
	
	var separator_bottom := HSeparator.new()
	_vbox.add_child(separator_bottom)

	_button_grid = GridContainer.new()
	_button_grid.columns = 2
	_button_grid.add_theme_constant_override("h_separation", 20)
	_button_grid.add_theme_constant_override("v_separation", 16)
	_vbox.add_child(_button_grid)

	var btn_mods := _create_button("Open Mods Folder", open_mods_folder)
	var btn_log := _create_button("Open logs folder", open_logs_folder)
	var btn_crash := _create_button("Continue (Ignore)", func(): print("hi"))
	var btn_quit := _create_button("Quit Game", func(): print("hi"))

	_button_grid.add_child(btn_mods)
	_button_grid.add_child(btn_log)
	_button_grid.add_child(btn_crash)
	_button_grid.add_child(btn_quit)

func _create_button(label_text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(32, 56) 
	btn.add_theme_font_size_override("font_size", 32)
	btn.pressed.connect(callback)
	return btn
	
func _add_error(title: String, subtitle: String) -> void:
	_error_count += 1
	_update_header_text()

	var error_line := RichTextLabel.new()
	error_line.bbcode_enabled = true
	error_line.fit_content = true
	error_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	error_line.add_theme_font_size_override("normal_font_size", 22)
	error_line.text = "[color=#ffffff]" + title + "[/color]\n[color=#cccccc]" + subtitle + "[/color]"
	_error_log.add_child(error_line)

func _update_header_text() -> void:
	if _header_subtitle:
		var plural := "s" if _error_count != 1 else ""
		_header_subtitle.text = "%d error%s has occurred during loading\n" % [_error_count, plural]

func open_mods_folder() -> void:
	var exec_dir: String = OS.get_executable_path().get_base_dir()
	var global_path: String = ProjectSettings.globalize_path(exec_dir)
	
	var err := OS.shell_open(global_path.path_join("mods"))
	if err != OK:
		push_error("Failed to open mods folder. Error code: %d" % err)

func open_logs_folder() -> void:
	var logs_dir: String = OS.get_user_data_dir().path_join("logs")
	
	if not DirAccess.dir_exists_absolute(logs_dir):
		DirAccess.make_dir_recursive_absolute(logs_dir)
		
	var err := OS.shell_open(logs_dir)
	if err != OK:
		push_error("Failed to open logs folder. Error code: %d" % err)