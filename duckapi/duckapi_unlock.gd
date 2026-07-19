extends "res://scripts/unlock_manager.gd"

const HookEvent: = preload("res://duckapi/duckapi_event.gd")

signal before_milestone_unlock(event)


func _trigger_milestone(id: String, m: Dictionary) -> void :
	var event: = HookEvent.new()
	event.data = {"id": id, "milestone": m}
	before_milestone_unlock.emit(event)

	if event.cancelled:
		return

	super._trigger_milestone(event.get_value("id"), event.get_value("milestone"))
