extends Node

const CameraScript: = preload("res://duckapi/duckapi_camera.gd")
const VANILLA_SCRIPT_PATH: = "res://scripts/main_camera.gd"


func _ready() -> void :
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void :
	if node.name != "MainCamera":
		return

	var script = node.get_script()

	if script and script.resource_path == VANILLA_SCRIPT_PATH:
		node.set_script(CameraScript)
