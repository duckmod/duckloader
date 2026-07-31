extends Node


func _ready() -> void :
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void :
	if node.name == "MainMenu":
		_inject_icon_button(node)
	elif node.name == "PauseMenu":
		_inject_text_button(node, "Background/MenuContainer/MenuButtons", "Options", "Mod Settings")


func _inject_icon_button(root: Node) -> void :
	var background: = root.get_node_or_null("Background")

	if not background:
		return

	var icon_btn: = TextureButton.new()
	icon_btn.name = "DuckModsButton"
	icon_btn.texture_normal = DuckLoader.get_default_icon_texture()
	icon_btn.ignore_texture_size = true
	icon_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	icon_btn.custom_minimum_size = Vector2(64, 64)
	icon_btn.anchor_left = 1.0
	icon_btn.anchor_top = 1.0
	icon_btn.anchor_right = 1.0
	icon_btn.anchor_bottom = 1.0
	icon_btn.offset_left = -84.0
	icon_btn.offset_top = -84.0
	icon_btn.offset_right = -20.0
	icon_btn.offset_bottom = -20.0
	icon_btn.pressed.connect(DuckLoader.open_mod_menu)
	background.add_child(icon_btn)


func _inject_text_button(root: Node, container_path: String, template_name: String, label: String) -> void :
	var container: = root.get_node_or_null(container_path)

	if not container:
		return

	var template: = container.get_node_or_null(template_name)
	var button: Button
	var insert_index: = container.get_child_count()

	if template and template is Button:
		button = template.duplicate()

		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)

		insert_index = template.get_index() + 1
	else:
		button = Button.new()

	button.name = "DuckModsButton"
	button.text = label
	button.disabled = false
	button.pressed.connect(DuckLoader.open_mod_menu)

	container.add_child(button)
	container.move_child(button, insert_index)
