extends RefCounted

var cancelled: = false
var data: = {}

func cancel() -> void :
	cancelled = true

func get_value(key: String, default = null):
	return data.get(key, default)

func set_value(key: String, value) -> void :
	data[key] = value
