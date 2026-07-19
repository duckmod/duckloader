extends "res://scripts/workbench_spawning.gd"

const HookEvent: = preload("res://duckapi/duckapi_event.gd")

signal before_workbench_spawn(event)
signal workbench_spawned(kind: String, workbench_type: String)


func spawn_auto_workbench(product_type: String, skip_ceremony: = false):
	var event: = HookEvent.new()
	event.data = {"kind": "auto", "workbench_type": product_type, "skip_ceremony": skip_ceremony}
	before_workbench_spawn.emit(event)

	if event.cancelled:
		return

	await super.spawn_auto_workbench(event.get_value("workbench_type"), event.get_value("skip_ceremony"))
	workbench_spawned.emit("auto", event.get_value("workbench_type"))


func spawn_manual_workbench(workbench_type: String, skip_ceremony: = false):
	var event: = HookEvent.new()
	event.data = {"kind": "manual", "workbench_type": workbench_type, "skip_ceremony": skip_ceremony}
	before_workbench_spawn.emit(event)

	if event.cancelled:
		return

	await super.spawn_manual_workbench(event.get_value("workbench_type"), event.get_value("skip_ceremony"))
	workbench_spawned.emit("manual", event.get_value("workbench_type"))
