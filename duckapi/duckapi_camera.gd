extends "res://scripts/main_camera.gd"

const HookEvent: = preload("res://duckapi/duckapi_event.gd")

signal before_pick(event)
signal object_picked(object: RigidBody3D)

signal before_drop(event)
signal object_dropped(object: RigidBody3D)


func pick_object():
	var event: = HookEvent.new()
	event.data = {"collider": interact_ray.get_collider()}
	before_pick.emit(event)

	if event.cancelled:
		return

	super.pick_object()

	if picked_object:
		object_picked.emit(picked_object)


func drop_object(force: bool = false):
	var event: = HookEvent.new()
	event.data = {"object": picked_object, "force": force}
	before_drop.emit(event)

	if event.cancelled:
		return

	var dropped_object: = picked_object
	super.drop_object(event.get_value("force"))

	if dropped_object:
		object_dropped.emit(dropped_object)
