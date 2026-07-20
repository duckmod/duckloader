extends CanvasLayer

const MAX_SPAWN_COUNT: = 10000
const DEFAULT_SPAWN_DISTANCE: = 2.5
const MIN_TIME_SCALE: = 0.05
const MAX_TIME_SCALE: = 10.0
const MIN_FOV: = 10.0
const MAX_FOV: = 170.0
const NOCLIP_SPRINT_MULTIPLIER: = 2.5
const NOCLIP_MIN_SPEED: = 1.0
const NOCLIP_MAX_SPEED: = 100.0
const NOCLIP_SPEED_SCROLL_FACTOR: = 1.15

var _root: Control
var _output: RichTextLabel
var _input_line: LineEdit

var _commands: = {}
var _history: Array[String] = []
var _history_index: = 0

var _is_open: = false
var _was_paused: = false
var _was_game_paused: = false
var _prev_mouse_mode: = Input.MOUSE_MODE_VISIBLE

var _noclip_active: = false
var _noclip_speed: = 8.0

var _hud: Control
var _hud_label: Label
var _hud_visible: = false


func _ready() -> void :
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_register_commands()
	close()


func _build_ui() -> void :
	_root = Control.new()
	_root.anchor_left = 0.0
	_root.anchor_right = 1.0
	_root.anchor_top = 1.0
	_root.anchor_bottom = 1.0
	_root.offset_left = 0
	_root.offset_right = 0
	_root.offset_top = -320
	_root.offset_bottom = 0
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var bg: = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var vbox: = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	_root.add_child(vbox)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.custom_minimum_size = Vector2(0, 280)
	vbox.add_child(_output)

	_input_line = LineEdit.new()
	_input_line.placeholder_text = "type 'help' and press enter"
	_input_line.process_mode = Node.PROCESS_MODE_ALWAYS
	_input_line.text_submitted.connect(_on_text_submitted)
	_input_line.gui_input.connect(_on_input_line_gui_input)
	vbox.add_child(_input_line)

	_hud = Control.new()
	_hud.anchor_left = 0.0
	_hud.anchor_top = 0.0
	_hud.offset_left = 12
	_hud.offset_top = 12
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	_hud.hide()
	add_child(_hud)

	_hud_label = Label.new()
	_hud_label.add_theme_font_size_override("font_size", 16)
	_hud_label.add_theme_color_override("font_color", Color.WHITE)
	_hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_label.add_theme_constant_override("outline_size", 4)
	_hud.add_child(_hud_label)


func _register_commands() -> void :
	_commands["help"] = {"func": _cmd_help, "desc": ""}
	_commands["clear"] = {"func": _cmd_clear, "desc": ""}
	_commands["list"] = {"func": _cmd_list, "desc": ""}
	_commands["spawn"] = {"func": _cmd_spawn, "desc": "<name> [count] [distance=<n>] [property=value ...] [/n]name: an object pool id (see 'list') or a scene file in res://scenes/ [/n]distance: how far from the camera to spawn, along where you're looking, pitch included (default %.1f) [/n]value can be a number, true/false, text, or comma-separated numbers for a Vector2/Vector3/Color [/n]example: spawn duck 10 distance=5 value=5 scale=2,2,2" % DEFAULT_SPAWN_DISTANCE}
	_commands["speed"] = {"func": _cmd_speed, "desc": "<multiplier> [/n]changes Engine.time_scale, e.g. 'speed 0.5' for slow motion, 'speed 1' to reset"}
	_commands["money"] = {"func": _cmd_money, "desc": "<amount> : add to current money (can be negative)"}
	_commands["setmoney"] = {"func": _cmd_setmoney, "desc": "<amount> : set money to an exact value"}
	_commands["phase"] = {"func": _cmd_phase, "desc": "<0-5> : jump straight to a game phase"}
	_commands["next_phase"] = {"func": _cmd_next_phase, "desc": ": advance to the next phase"}
	_commands["unlock_all"] = {"func": _cmd_unlock_all, "desc": ": unlock every milestone/upgrade"}
	_commands["noclip"] = {"func": _cmd_noclip, "desc": ": toggle free-fly, no-collision movement (scroll wheel changes fly speed)"}
	_commands["tp"] = {"func": _cmd_teleport, "desc": "<x,y,z> : teleport the player"}
	_commands["fov"] = {"func": _cmd_fov, "desc": "<degrees> : force a fixed camera FOV"}
	_commands["clear_objects"] = {"func": _cmd_clear_objects, "desc": ": recycle every spawned pooled object"}
	_commands["pool_stats"] = {"func": _cmd_pool_stats, "desc": ": show active/available counts per pool"}
	_commands["save"] = {"func": _cmd_save, "desc": ": manual save"}
	_commands["load"] = {"func": _cmd_load, "desc": ": manual load"}
	_commands["quit"] = {"func": _cmd_quit, "desc": ": exit the game"}
	_commands["debug_hud"] = {"func": _cmd_debug_hud, "desc": ": toggle an on-screen overlay with position, speed, phase, fps..."}
	_commands["upgrade"] = {"func": _cmd_upgrade, "desc": "<name> <level> : set an upgrade's level directly (e.g. 'upgrade sprint 3')"}
	_commands["mods"] = {"func": _cmd_mods, "desc": ": list every mod loaded by DuckLoader, with its metadata"}


func _input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_QUOTELEFT:
		toggle()
		get_viewport().set_input_as_handled()
		return

	if _is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
		return

	if _noclip_active and not _is_open and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_noclip_speed = clampf(_noclip_speed * NOCLIP_SPEED_SCROLL_FACTOR, NOCLIP_MIN_SPEED, NOCLIP_MAX_SPEED)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_noclip_speed = clampf(_noclip_speed / NOCLIP_SPEED_SCROLL_FACTOR, NOCLIP_MIN_SPEED, NOCLIP_MAX_SPEED)
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void :
	if not _noclip_active or _is_open:
		return

	var player: = get_tree().get_first_node_in_group("player") as Node3D

	if not player:
		return

	var camera: = get_tree().get_first_node_in_group("main_camera") as Camera3D
	var basis: = camera.global_transform.basis if camera else player.global_transform.basis

	var move_input: = Input.get_vector("left", "right", "up", "down")
	var direction: = basis.x * move_input.x + basis.z * move_input.y

	if Input.is_action_pressed("jump"):
		direction += Vector3.UP

	if Input.is_action_pressed("crouch"):
		direction -= Vector3.UP

	if direction.length() > 0.001:
		direction = direction.normalized()

	var speed: = _noclip_speed * (NOCLIP_SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1.0)
	player.global_position += direction * speed * delta


func _process(_delta: float) -> void :
	if not _hud_visible:
		return

	var player: = get_tree().get_first_node_in_group("player") as Node3D
	var camera: = get_tree().get_first_node_in_group("main_camera") as Camera3D
	var pos: = player.global_position if player else Vector3.ZERO
	var vel: Vector3 = player.velocity if player and "velocity" in player else Vector3.ZERO
	var yaw: = rad_to_deg(player.rotation.y) if player else 0.0
	var pitch: = rad_to_deg(camera.rotation.x) if camera else 0.0

	var lines: = [
		"FPS: %d" % Engine.get_frames_per_second(),
		"Pos: %.2f, %.2f, %.2f" % [pos.x, pos.y, pos.z],
		"Speed: %.2f" % vel.length(),
		"Yaw: %.1f  Pitch: %.1f" % [yaw, pitch],
		"Phase: %d" % GameProgression.current_phase,
		"Time scale: %.2f" % Engine.time_scale,
	]

	if camera:
		lines.append("FOV: %.1f" % camera.fov)

	if _noclip_active:
		lines.append("Noclip speed: %.1f (scroll to adjust)" % _noclip_speed)

	_hud_label.text = "\n".join(lines)


func toggle() -> void :
	if _is_open:
		close()
	else:
		open()


func open() -> void :
	if _is_open:
		return

	_is_open = true
	_root.show()

	_was_paused = get_tree().paused
	get_tree().paused = true

	_was_game_paused = MenuManager.game_paused
	MenuManager.game_paused = true

	_prev_mouse_mode = Input.mouse_mode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_input_line.text = ""
	_input_line.grab_focus.call_deferred()


func close() -> void :
	_is_open = false
	_root.hide()

	if not _was_paused:
		get_tree().paused = false

	MenuManager.game_paused = _was_game_paused

	Input.set_mouse_mode(_prev_mouse_mode)
	_input_line.release_focus()


func log_line(text: String) -> void :
	_output.append_text(text + "\n")

func add_command(name: String, function: Callable, desc: String = "") -> void:
	if not name.is_empty() and function.is_valid():
		_commands[name] = {
			"func": function,
			"desc": desc
		}

func _on_input_line_gui_input(event: InputEvent) -> void :
	if not (event is InputEventKey and event.pressed):
		return

	if event.keycode == KEY_UP:
		_navigate_history(-1)
		_input_line.accept_event()
	elif event.keycode == KEY_DOWN:
		_navigate_history(1)
		_input_line.accept_event()


func _navigate_history(direction: int) -> void :
	if _history.is_empty():
		return

	_history_index = clamp(_history_index + direction, 0, _history.size())

	if _history_index == _history.size():
		_input_line.text = ""
	else:
		_input_line.text = _history[_history_index]
		_input_line.caret_column = _input_line.text.length()


func _on_text_submitted(text: String) -> void :
	var trimmed: = text.strip_edges()
	_input_line.text = ""

	if trimmed.is_empty():
		return

	_history.append(trimmed)
	_history_index = _history.size()

	log_line("[color=gray]> %s[/color]" % trimmed)
	_execute(trimmed)

	if _is_open:
		_input_line.grab_focus.call_deferred()


func _execute(line: String) -> void :
	var args: = line.split(" ", false)
	var command_name: = args[0].to_lower()
	args.remove_at(0)

	if not _commands.has(command_name):
		log_line("[color=red]Unknown command: %s[/color]" % command_name)
		return

	_commands[command_name]["func"].call(args)


func _cmd_help(_args: PackedStringArray) -> void:
	for command_name in _commands:
		var desc: String = _commands[command_name].get("desc", "")
		
		if not desc.is_empty():
			var lines: PackedStringArray = desc.split("[/n]")
			log_line("  " + command_name + " " + lines[0])
			
			for i in range(1, lines.size()):
				log_line("     " + lines[i])
		else:
			log_line("  " + command_name)


func _cmd_clear(_args: PackedStringArray) -> void :
	_output.clear()


func _cmd_list(_args: PackedStringArray) -> void :
	var ids: = ObjectPoolManager.POOL_CONFIG.keys()
	ids.sort()
	log_line("[b]Pool objects:[/b] " + ", ".join(ids))


func _cmd_spawn(args: PackedStringArray) -> void :
	if args.size() < 1:
		log_line("[color=red]Usage: spawn <name> [count] [property=value ...][/color]")
		return

	var object_name: = args[0]
	var count: = 1
	var prop_start: = 1

	if args.size() > 1 and args[1].is_valid_int():
		count = clampi(int(args[1]), 1, MAX_SPAWN_COUNT)
		prop_start = 2

	var properties: = {}

	for i in range(prop_start, args.size()):
		var token: String = args[i]
		var eq: = token.find("=")

		if eq == -1:
			continue

		properties[token.substr(0, eq)] = _parse_value(token.substr(eq + 1))

	var distance: = DEFAULT_SPAWN_DISTANCE

	if properties.has("distance"):
		distance = float(properties["distance"])
		properties.erase("distance")

	var camera: = get_tree().get_first_node_in_group("main_camera") as Camera3D

	if not camera:
		log_line("[color=red]No active camera found.[/color]")
		return

	var origin: = camera.global_transform.origin
	var forward: = -camera.global_transform.basis.z

	var spawn_pos: = origin + forward * distance

	var scene: PackedScene = null

	if not ObjectPoolManager.POOL_CONFIG.has(object_name):
		var scene_path: = "res://scenes/%s.tscn" % object_name

		if not ResourceLoader.exists(scene_path):
			log_line("[color=red]Unknown object '%s'. Use 'list' to see pool ids.[/color]" % object_name)
			return

		scene = load(scene_path)

	for i in count:
		var node: Node3D

		if scene:
			node = scene.instantiate()
			get_tree().current_scene.add_child(node)
			node.global_position = spawn_pos
		else:
			node = ObjectPoolManager.spawn(object_name, spawn_pos)

		if not node:
			continue

		for key in properties:
			_apply_property(node, key, properties[key])

	log_line("Spawned %d x '%s' at distance %.1f" % [count, object_name, distance])


func _cmd_speed(args: PackedStringArray) -> void :
	if args.size() < 1:
		log_line("Current game speed: %.2f" % Engine.time_scale)
		return

	if not args[0].is_valid_float():
		log_line("[color=red]Usage: speed <multiplier>[/color]")
		return

	var value: = clampf(args[0].to_float(), MIN_TIME_SCALE, MAX_TIME_SCALE)
	Engine.time_scale = value
	log_line("Game speed set to %.2f" % value)


func _cmd_money(args: PackedStringArray) -> void :
	if args.size() < 1 or not args[0].is_valid_float():
		log_line("[color=red]Usage: money <amount>[/color]")
		return

	GameState.add_money(args[0].to_float())
	log_line("Money is now %s" % GameState.money.to_plain_string())


func _cmd_setmoney(args: PackedStringArray) -> void :
	if args.size() < 1 or not args[0].is_valid_int():
		log_line("[color=red]Usage: setmoney <amount>[/color]")
		return

	GameState.money = BigInt.from_int(int(args[0]))
	GameState.money_updated.emit(GameState.money)
	log_line("Money set to %s" % GameState.money.to_plain_string())


func _cmd_phase(args: PackedStringArray) -> void :
	if args.size() < 1 or not args[0].is_valid_int():
		log_line("[color=red]Usage: phase <0-5>[/color]")
		return

	var phase: = clampi(int(args[0]), 0, 5)
	GameProgression.change_phase(phase as GameProgression.Phase)
	log_line("Phase set to %d" % phase)


func _cmd_next_phase(_args: PackedStringArray) -> void :
	GameProgression.next_phase()
	log_line("Advanced to phase %d" % GameProgression.current_phase)


func _cmd_unlock_all(_args: PackedStringArray) -> void :
	UnlockManager.debug_apply_all(true)
	log_line("All milestones unlocked.")


func _cmd_noclip(_args: PackedStringArray) -> void :
	var player: = get_tree().get_first_node_in_group("player") as CharacterBody3D

	if not player:
		log_line("[color=red]Player not found.[/color]")
		return

	_noclip_active = not _noclip_active
	player.set_physics_process(not _noclip_active)
	player.velocity = Vector3.ZERO

	var collision_shape: = player.get_node_or_null("CollisionShape3D")

	if collision_shape:
		collision_shape.disabled = _noclip_active

	if _noclip_active:
		log_line("Noclip enabled (speed %.1f, scroll wheel to adjust)" % _noclip_speed)
	else:
		log_line("Noclip disabled")


func _cmd_teleport(args: PackedStringArray) -> void :
	if args.size() < 1:
		log_line("[color=red]Usage: tp <x,y,z>[/color]")
		return

	var value = _parse_value(args[0])

	if not (value is Vector3):
		log_line("[color=red]Usage: tp <x,y,z>[/color]")
		return

	var player: = get_tree().get_first_node_in_group("player") as CharacterBody3D

	if not player:
		log_line("[color=red]Player not found.[/color]")
		return

	player.global_position = value
	player.velocity = Vector3.ZERO
	log_line("Teleported to %s" % value)


func _cmd_fov(args: PackedStringArray) -> void :
	if args.size() < 1 or not args[0].is_valid_float():
		log_line("[color=red]Usage: fov <degrees>[/color]")
		return

	var value: = clampf(args[0].to_float(), MIN_FOV, MAX_FOV)
	MenuManager.settings.gameplay.dynamic_fov = false
	PostProcessManager.fov_value = value

	var camera: = get_tree().get_first_node_in_group("main_camera") as Camera3D

	if camera:
		camera.fov = value

	log_line("FOV set to %.1f (dynamic FOV disabled)" % value)


func _cmd_clear_objects(_args: PackedStringArray) -> void :
	ObjectPoolManager.recycle_all_active()
	log_line("All active pooled objects recycled.")


func _cmd_pool_stats(_args: PackedStringArray) -> void :
	var ids: = ObjectPoolManager._pools.keys()
	ids.sort()

	for id in ids:
		var pool = ObjectPoolManager._pools[id]
		log_line("%s | active: %d | available: %d | max: %d" % [id, pool.active.size(), pool.available.size(), pool.max_size])


func _cmd_save(_args: PackedStringArray) -> void :
	if SaveManager.save_game():
		log_line("Game saved.")
	else:
		log_line("[color=red]Save failed.[/color]")


func _cmd_load(_args: PackedStringArray) -> void :
	if SaveManager.begin_load_reload():
		log_line("Loading save...")
	else:
		log_line("[color=red]Load failed.[/color]")


func _cmd_quit(_args: PackedStringArray) -> void :
	get_tree().quit()


func _cmd_debug_hud(_args: PackedStringArray) -> void :
	_hud_visible = not _hud_visible
	_hud.visible = _hud_visible
	log_line("Debug HUD " + ("enabled" if _hud_visible else "disabled"))


func _cmd_upgrade(args: PackedStringArray) -> void :
	if args.size() < 2 or not args[1].is_valid_int():
		log_line("[color=red]Usage: upgrade <name> <level>[/color]")
		return

	var upgrade_name: = args[0]

	if not GameState.upgrades.has(upgrade_name):
		var names: = GameState.upgrades.keys()
		names.sort()
		log_line("[color=red]Unknown upgrade '%s'. Options: %s[/color]" % [upgrade_name, ", ".join(names)])
		return

	var level: = int(args[1])
	GameState.upgrades[upgrade_name]["level"] = level
	GameState.upgrades[upgrade_name]["enabled"] = true
	log_line("Upgrade '%s' set to level %d" % [upgrade_name, level])


func _cmd_mods(_args: PackedStringArray) -> void :
	var loader: = get_node_or_null("/root/DuckLoader")

	if not loader:
		log_line("[color=red]DuckLoader is not installed.[/color]")
		return

	var ids = loader.get_loaded_mod_ids()

	if ids.is_empty():
		log_line("No mods loaded.")
		return

	ids.sort()
	log_line("[b]Loaded mods (%d):[/b]" % ids.size())

	for id in ids:
		var info: Dictionary = loader.get_mod_info(id)
		log_line("  [b]%s[/b] (id=%s) v%s by %s" % [info.get("name", id), id, info.get("version", "unknown"), info.get("author", "unknown")])

		var description: = String(info.get("description", ""))

		if not description.is_empty():
			log_line("    %s" % description)


func _apply_property(node: Node, key: String, value) -> void :
	if key in node:
		node.set(key, value)
	else:
		log_line("[color=orange]'%s' has no property '%s'[/color]" % [node.name, key])


func _parse_value(raw: String):
	if "," in raw:
		var parts: = raw.split(",")
		var numbers: Array[float] = []
		var all_numeric: = true

		for part in parts:
			if part.is_valid_float():
				numbers.append(part.to_float())
			else:
				all_numeric = false
				break

		if all_numeric:
			match numbers.size():
				2: return Vector2(numbers[0], numbers[1])
				3: return Vector3(numbers[0], numbers[1], numbers[2])
				4: return Color(numbers[0], numbers[1], numbers[2], numbers[3])

	if raw == "true":
		return true

	if raw == "false":
		return false

	if raw.is_valid_int():
		return int(raw)

	if raw.is_valid_float():
		return float(raw)

	return raw
