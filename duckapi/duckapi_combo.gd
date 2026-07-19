extends "res://scripts/combo_system.gd"

const HookEvent: = preload("res://duckapi/duckapi_event.gd")

signal before_combo_hit(event)
signal combo_hit(product_type: String, item_value: float, bonus: int)


func add_to_combo(product_type: String = "unknown", item_value: float = 0.0) -> int:
	var event: = HookEvent.new()
	event.data = {"product_type": product_type, "item_value": item_value}
	before_combo_hit.emit(event)

	if event.cancelled:
		return 0

	var bonus: = super.add_to_combo(event.get_value("product_type"), event.get_value("item_value"))
	combo_hit.emit(event.get_value("product_type"), event.get_value("item_value"), bonus)
	return bonus
