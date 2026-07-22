extends "res://scripts/object_pool_manager.gd"

const HookEvent: = preload("res://duckapi/duckapi_event.gd")

signal before_spawn(event)
signal object_spawned(pool_id: String, node: Node3D)

signal before_recycle(event)
signal object_recycled(pool_id: String, node: Node3D)


func spawn(pool_id: String, position: = Vector3.ZERO, rotation: = Vector3.ZERO) -> Node3D:
	var event: = HookEvent.new()
	event.data = {"pool_id": pool_id, "position": position, "rotation": rotation}
	before_spawn.emit(event)

	if event.cancelled:
		return null

	var node: = super.spawn(event.get_value("pool_id"), event.get_value("position"), event.get_value("rotation"))

	if node:
		object_spawned.emit(event.get_value("pool_id"), node)

	return node


func recycle(obj: Node3D) -> void :
	var pool_id: = _find_pool_id(obj)

	var event: = HookEvent.new()
	event.data = {"pool_id": pool_id, "object": obj}
	before_recycle.emit(event)

	if event.cancelled:
		return

	super.recycle(obj)
	object_recycled.emit(pool_id, obj)


func _find_pool_id(obj: Node3D) -> String:
	for id in _pools.keys():
		var pool = _pools[id]

		if obj in pool.active:
			return id

	return ""

func add_spawnable(obj: Node3D, initial: int, max_size: int, custom_pool_id: String = "") -> bool:
	var pool_id: String = custom_pool_id
	if pool_id.is_empty():
		pool_id = obj.name
	
	if pool_id.is_empty():
		push_error("[DuckAPI] Cannot add spawnable: Node3D has no name and no custom ID was provided.")
		return false

	if _pools.has(pool_id):
		push_warning("[DuckAPI] A pool with ID '%s' already exists." % pool_id)
		return false

	var scene := PackedScene.new()
	var err := scene.pack(obj)
    
	if err != OK:
		push_error("[DuckAPI] Failed to pack Node3D '%s' into a scene. Error code: %d" % [pool_id, err])
		return false

	var cfg := {
        "scene": scene,
        "initial": initial,
        "max": max_size
    }

	_create_pool(pool_id, cfg, false)

	print("[DuckAPI] Successfully added new spawnable: %s (Initial: %d, Max: %d)" % [pool_id, initial, max_size])
	return true