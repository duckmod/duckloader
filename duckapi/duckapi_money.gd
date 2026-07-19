extends "res://scripts/game_state.gd"

const HookEvent: = preload("res://duckapi/duckapi_event.gd")

signal before_money_added(event)
signal money_added(amount, product_type: String)

signal before_bonus_added(event)
signal bonus_added(amount)

signal before_money_spent(event)
signal money_spent(amount)

signal before_purchase(event)
signal purchase_made(category: String, key: String, subkey: String)

signal before_product_added(event)
signal product_added(product_type: String)

signal buff_activated(buff_type: String, multiplier: float, duration: float)


func add_money(amount, product_type: String = ""):
	var event: = HookEvent.new()
	event.data = {"amount": amount, "product_type": product_type}
	before_money_added.emit(event)

	if event.cancelled:
		return

	super.add_money(event.get_value("amount"), event.get_value("product_type"))
	money_added.emit(event.get_value("amount"), event.get_value("product_type"))


func add_bonus(amount):
	var event: = HookEvent.new()
	event.data = {"amount": amount}
	before_bonus_added.emit(event)

	if event.cancelled:
		return

	super.add_bonus(event.get_value("amount"))
	bonus_added.emit(event.get_value("amount"))


func spend(amount):
	var event: = HookEvent.new()
	event.data = {"amount": amount}
	before_money_spent.emit(event)

	if event.cancelled:
		return

	super.spend(event.get_value("amount"))
	money_spent.emit(event.get_value("amount"))


func buy(category: String, key: String, subkey: = "") -> bool:
	var event: = HookEvent.new()
	event.data = {"category": category, "key": key, "subkey": subkey}
	before_purchase.emit(event)

	if event.cancelled:
		return false

	var result: = super.buy(event.get_value("category"), event.get_value("key"), event.get_value("subkey"))

	if result:
		purchase_made.emit(event.get_value("category"), event.get_value("key"), event.get_value("subkey"))

	return result


func add_product(product_type: String = ""):
	var event: = HookEvent.new()
	event.data = {"product_type": product_type}
	before_product_added.emit(event)

	if event.cancelled:
		return

	super.add_product(event.get_value("product_type"))
	product_added.emit(event.get_value("product_type"))


func activate_buff(buff_type: String, multiplier: float, duration: float) -> void :
	super.activate_buff(buff_type, multiplier, duration)
	buff_activated.emit(buff_type, multiplier, duration)
