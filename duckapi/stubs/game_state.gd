extends Node
const MAX_INT_64 = 9223372036854775807
const TOOL_DEPOSIT_PERCENTAGE := 0.1

# Note: the game uses a internal called BigInt that adds
# some new stuff.
var money: int = 0
var total_money_gained: int = 0
var total_money_spent: int = 0
var total_products: float = 0
var bank: float = 0.0

@warning_ignore("unused_signal")
signal stat_changed(stat_name: String, new_value)
@warning_ignore("unused_signal")
signal new_high_combo(combo_level: int)
@warning_ignore("unused_signal")
signal money_updated(new_amount)
@warning_ignore("unused_signal")
signal bank_updated(new_amount)

# ─── Remote Channel System (shared across all remote instances) ───
var remote_max_channels: int = 1
var remote_slots_per_channel: int = 3
var remote_pulse_enabled: bool = false
var remote_channels: Array[Array] = [] # Array of arrays of node refs
var remote_channel_states: Array[bool] = [] # on/off per channel

@warning_ignore("unused_signal")
signal remote_channel_toggled(channel_idx: int, state: bool)
@warning_ignore("unused_signal")
signal remote_tier_changed

# Combos
var max_combo: int = 0
var total_combos: int = 0
var combo_bonus_total: int = 0
var total_bonus_earned: int = 0

# === NEW STATISTICS TRACKING ===

# Time tracking
var game_start_time: float = 0.0
var total_play_time: float = 0.0
var is_game_started: bool = false

# Mining puzzle 
var uv_unlocked: bool = false
var pickaxe_tier: int = 1
var pickaxe_found: bool = false
var mining_bank: int = 0
var uv_lamp_dispensed: bool = false
var elevator_hacked: bool = false
var keypad_revealed: bool = false
var secret_ending_seen: bool = false
var escape_code: String = ""

# Safety violations (deaths/falls into Maw)
var safety_violations: int = 0
var torch_unlocked: bool = false

var long_range_feeds: int = 0
var max_simultaneous_toggle_tools: int = 0
var panel_ricochet_feeds: int = 0
var cameras_destroyed: int = 0

const IS_DEMO := false
var sandbox_mode: bool = false

# Temp storage for deferred resource loading (used by UpgradeUI)
var loaded_resources: Dictionary = {}

@warning_ignore("unused_private_class_variable")
var _default_buy_prices: Dictionary = {}

# Production tracking per product type
var products_crafted := {
	"duck": 0,
	"lucky_duck": 0,
	"cash_register": 0,
	"lucky_cash_register": 0,
	"pinata": 0,
	"lucky_pinata": 0,
	"candy": 0,
	"lucky_candy": 0,
	"anomaly": 0,
	"lucky_anomaly": 0
}

var products_autocrafted := {
	"duck": 0,
	"lucky_duck": 0,
	"cash_register": 0,
	"lucky_cash_register": 0,
	"pinata": 0,
	"lucky_pinata": 0,
	"candy": 0,
	"lucky_candy": 0,
	"anomaly": 0,
	"lucky_anomaly": 0
}

var products_consumed := {
	"duck": 0,
	"lucky_duck": 0,
	"cash_register": 0,
	"lucky_cash_register": 0,
	"pinata": 0,
	"lucky_pinata": 0,
	"candy": 0,
	"lucky_candy": 0,
	"anomaly": 0,
	"lucky_anomaly": 0
}

var money_per_product := {
	"duck": 0,
	"lucky_duck": 0,
	"cash_register": 0,
	"lucky_cash_register": 0,
	"pinata": 0,
	"lucky_pinata": 0,
	"candy": 0,
	"lucky_candy": 0,
	"anomaly": 0,
	"lucky_anomaly": 0
}

# Production rate tracking
var production_samples: Array[Dictionary] = []
var peak_production_rate: float = 0.0
var last_production_time: float = 0.0
var items_in_last_minute: int = 0
var production_timestamps: Array[float] = []

# ─── Rolling 60s rate tracking (live "/min" stats; ephemeral, never saved) ───
const RATE_WINDOW := 60.0
@warning_ignore("unused_private_class_variable")
var _rate_events := {}# key -> Array of Vector2(timestamp_sec, amount)

# Efficiency tracking
var total_crafting_time: float = 0.0
var total_feeding_time: float = 0.0

var total_wodden_gambling_crates: int = 0
var total_products_consumed: int = 0

## key -> true, for tools/toys bought at least once (CONSUMERISM).
## Upgrades don't need this — upgrades[key]["level"] > 0 already persists.
var purchased_once: Dictionary = {}

# ─── Gambling buffs (temporary, stackable; one type introduced per phase) ───
const BUFF_COMBO_WINDOW := "combo_window"
const BUFF_COMBO_VALUE := "combo_value"
const BUFF_PRODUCT_VALUE := "product_value"
const BUFF_CRAFT_SPEED := "craft_speed"

var active_buffs := {}# buff_type -> {multiplier, time_remaining, duration}
var gambling_buff_seen: bool = false
@warning_ignore("unused_signal")
signal buff_updated(buff_type: String, multiplier: float, time_remaining: float, duration: float)
@warning_ignore("unused_signal")
signal buff_expired(buff_type: String)

# ─── Panel rack (carry a stack of panels) ──────────────────────────────────
const PANEL_RACK_CAPACITY := [0, 5, 10, 15]

var panel_stack: Array[String] = []
@warning_ignore("unused_signal")
signal panel_stack_changed(count: int, capacity: int)

# Equipment usage stats
var equipment_used := {
	"box": 0,
	"broom": 0,
	"magnet": 0,
	"fan": 0,
	"panel": 0,
	"piston": 0,
	"golf_club": 0,
	"basketball_hoop": 0,
	"speed_radar": 0,
	"bowling_pins": 0,
	"remote": 0,
	"bumper": 0
}

# In the game this is so BIG.
# but it's used to keep track of levels and stuff
var upgrades = {}
var combos = {}
var products = {}
var toys = {}
var tools = {}
