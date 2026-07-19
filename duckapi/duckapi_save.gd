extends "res://scripts/save_manager.gd"

const HookEvent: = preload("res://duckapi/duckapi_event.gd")

signal before_save(event)
signal game_saved(success: bool)

signal before_load(event)
signal game_loaded(success: bool)


func save_game() -> bool:
	var event: = HookEvent.new()
	before_save.emit(event)

	if event.cancelled:
		return false

	var result: = super.save_game()
	game_saved.emit(result)
	return result


func load_game() -> bool:
	var event: = HookEvent.new()
	before_load.emit(event)

	if event.cancelled:
		return false

	var result: = super.load_game()
	game_loaded.emit(result)
	return result
