extends Node


@warning_ignore("unused_signal")
signal settings_changed

var current_menu: CanvasLayer = null
var previous_menu: CanvasLayer = null
var game_paused: bool = false
var upgrade_ui_displayed: bool = false
var menu_stack: Array[CanvasLayer] = []
const OPTIONS_MENU_SCENE := "res://scenes/option_menu.tscn"
const AUDIO_MENU_SCENE := "res://scenes/audio_menu.tscn"
const VISUALS_MENU_SCENE := "res://scenes/visuals_menu.tscn"
const SESSION_COMPLETE_SCENE := "res://scenes/session_complete.tscn"
const CONTROLS_MENU_SCENE := "res://scenes/controls_menu.tscn"
const CREDITS_MENU_SCENE := "res://scenes/credits.tscn"
const END_OF_GAME_SCENE := "res://scenes/end_of_game.tscn"

@warning_ignore("unused_private_class_variable")
var _menu_scene_cache: Dictionary = {}

@warning_ignore("unused_private_class_variable")
var _scaled_menu_roots: Array[Node] = []
@warning_ignore("unused_private_class_variable")
var _scaled_rects: Array[Control] = []

@warning_ignore("unused_private_class_variable")
var _ui_sound_player := AudioStreamPlayer.new()
@warning_ignore("unused_private_class_variable")
var _last_focus_owner: Control = null

var settings: Dictionary = {
	"controls": {
		"mouse_sensitivity": 0.5,
		"gamepad_sensitivity": 3.0,
		"invert_y": false,
		"invert_x": false
	},
	"audio": {
		"master_volume": 0.6,
		"sfx_volume": 1.0,
		"music_volume": 0.6,
		"ui_volume": 1.0
	},
	"ui": {
		"menu_scale": 0.8
	},
	"gameplay": {
		"autosave_enabled": true,
		"autosave_interval": 300.0,
		"auto_craft": false,
		"crouch_toggle": false,
		"sprint_toggle": false,
		"screen_shake": 1.0,
		"dynamic_fov": true
	}
}
