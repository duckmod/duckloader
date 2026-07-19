extends "res://scripts/game_progression.gd"

const HookEvent: = preload("res://duckapi/duckapi_event.gd")

signal before_phase_change(event)
signal phase_changed_hook(old_phase: int, new_phase: int)


func change_phase(new_phase: Phase):
	var event: = HookEvent.new()
	event.data = {"old_phase": current_phase, "new_phase": new_phase}
	before_phase_change.emit(event)

	if event.cancelled:
		return

	var old_phase: = current_phase
	super.change_phase(event.get_value("new_phase"))
	phase_changed_hook.emit(old_phase, current_phase)
