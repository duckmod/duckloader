extends Node

@warning_ignore("unused_signal")
signal save_loaded

const SAVE_FILE_PATH = "user://savegame.save"

const SAVE_TMP_PATH = "user://savegame.save.tmp" # staging file for atomic writes
const SAVE_BAK_PATH = "user://savegame.save.bak" # previous good save (rotated on each save)
const SAVE_CORRUPT_PATH = "user://savegame.save.corrupt" # quarantined unreadable save (support/recovery)
const SANDBOX_SAVE_PATH = "user://sandbox.save"
const PROFILE_PATH = "user://profile.cfg"
const MAX_SAVE_SLOTS := 10
const SAVE_PASSWORD := "" # <- this is obv not empty, its the thing that encrypts the save, please don't share online.
const IS_ENCRYPTED := true
const MIN_SAVE_INTERVAL_MS := 5000 # min gap between two saves
const RETIRED_POOL_IDS: PackedStringArray = ["debris_chunk", "debris_chunk_large"]
const MIN_SAVE_TO_LOAD_MS := 8000 # min gap between a save and a load
const MIN_LOAD_INTERVAL_MS := 8000 # min gap between two loads (anti-spam)
@warning_ignore("unused_private_class_variable")
var _last_save_tick := -1000000
@warning_ignore("unused_private_class_variable")
var _last_load_tick := -1000000
var should_load_on_ready = false
var pending_camera_data = {}
var autosave_enabled = true
var save_locked: bool = false
var autosave_interval = 300.0 # NEW: 5 minutes in seconds (300 seconds)
var autosave_timer = 0.0
var is_press_spawned:bool = false
var is_bowling_set_spawned:bool = false
@warning_ignore("unused_private_class_variable")
var _press_spawn_in_flight: bool = false
var is_trading_terminal_spawned: bool = false
@warning_ignore("unused_private_class_variable")
var _terminal_spawn_in_flight: bool = false
var is_loading := false
var pending_workbench_data := {}
var pending_pool_data := {}
var pending_minable_blocks: Dictionary = {}
var pending_pickaxe_data: Dictionary = {}
var pending_loop_puzzle: Dictionary = {}
var active_save_path: String = SAVE_FILE_PATH
var active_slot: int = 0
@warning_ignore("unused_private_class_variable")
var _game_completed_cache: int = -1 # -1 unknown, 0 false, 1 true
var pending_sandbox_grant := false # fresh sandbox: applied once world.tscn is current
var pending_player_position: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _hole_state_applied := false
@warning_ignore("unused_private_class_variable")
var _is_saving: bool = false
@warning_ignore("unused_private_class_variable")
var _save_started_tick: int = -1
@warning_ignore("unused_private_class_variable")
var _save_forced_pause: bool = false
const SAVE_WATCHDOG_MS := 30000
const AUTOSAVE_RETRY_DELAY := 15.0 # retry soon instead of burning a full interval

# Save data structure
var save_data = {
	"version": ProjectSettings.get_setting("application/config/version", "0.0.0"),
	"timestamp": 0,
	"game_state": {},
	"game_statistics": {},
	"object_pools": {},
	"player_position": Vector3.ZERO,
	"phase": 0,
	"cameras": {},
	"hole": {},
	"vertical_gates": {}
}
