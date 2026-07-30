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

func add_spawnable(pool_id: String, scene_path: String, initial_count: int, max_count: int) -> bool:
	if not ResourceLoader.exists(scene_path):
		push_error("[DuckAPI] Path does not exist: " + scene_path)
		return false
		
	var scene_res = load(scene_path) as PackedScene
	if not scene_res:
		push_error("[DuckAPI] Failed to load PackedScene: " + scene_path)
		return false

	if ObjectPoolManager._pools.has(pool_id):
		push_warning("[DuckAPI] Pool ID already exists: " + pool_id)
		return false

	var new_pool = ObjectPoolManager.Pool.new()
	new_pool.scene = scene_res
	new_pool.max_size = max_count
	
	ObjectPoolManager._pools[pool_id] = new_pool

	for i in range(initial_count):
		var obj = ObjectPoolManager._instantiate(new_pool)
		ObjectPoolManager._deactivate(obj)
		new_pool.available.append(obj)

	print("[DuckAPI] Successfully registered modded pool: %s" % pool_id)
	return true