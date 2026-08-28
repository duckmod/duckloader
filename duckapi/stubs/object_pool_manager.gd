extends Node


const PURGE_POOL_IDS: Array[String] = [
	"duck", "duck_luck", "flat_duck", "flat_duck_luck",
	"cash_register", "cash_register_luck",
	"pinata", "pinata_luck",
	"candy", "candy_luck",
	"anomaly", "anomaly_luck",
	"debris_chunk", "debris_chunk_large",
]

const PURGE_OWNER_METAS: Array[String] = [
	"in_vacuum_bag",
	"in_cannon_barrel",
	"orbit_in_orbit",
	"consumed",
	"pending_maw_recycle",
]

# this is ultra big on the game code.
# "duck": {
		#"path": "res://scenes/duck.tscn",
		#"initial": 200,
		#"max": 3000
# },
# This is how it looks like
const POOL_CONFIG := {}
