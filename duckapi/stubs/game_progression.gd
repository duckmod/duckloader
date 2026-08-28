extends Node

@warning_ignore("unused_signal")
signal phase_changed(new_phase: int)

var track2: AudioStream = null # Populated by initialize()
var track3: AudioStream = null # Populated by initialize()
var track4: AudioStream = null # Populated by initialize()

enum Phase {
	PHASE_0 = 0, # Tutorial/intro
	PHASE_1 = 1, # Rubber ducks
	PHASE_2 = 2, # Metal crowns
	PHASE_3 = 3, # Plush bears
	PHASE_4 = 4, # Last phase
	PHASE_5 = 5 # Ending phase
}

var current_phase: Phase = Phase.PHASE_0
var elevator_exited: bool = false
var can_pause: bool = false
var demo_end_triggered: bool = false

const PHASE_3_DEBRIS_SPAWN_POINTS: Array[Vector3] = [
	Vector3(-16, 30, 10),
	Vector3(-13, 30, 18),
	Vector3(-6, 30, 7),
	Vector3(15, 30, 10),
	Vector3(11, 30, 18),
]

const PHASE_4_DEBRIS_SPAWN_POINTS: Array[Vector3] = [
	Vector3(14, 30, -10),
	Vector3(16, 30, 0),
	Vector3(1, 30, -14),
	Vector3(-16, 30, -2),
]
const PHASE_4_LARGE_DEBRIS_COUNT: int = 4

const PHASE_3_DEBRIS_COUNT: int = 12
const DEBRIS_ENABLED: bool = false
const PHASE_3_TIME_SLOW: float = 0.15
const PHASE_3_SLOWMO_DURATION: float = 8.0
const PHASE_3_PITCH_SEMITONES: float = -14.0
const PHASE_4_PIXELATION_GLITCH_MIN: float = 0.2
const PHASE_4_PIXELATION_GLITCH_MAX: float = 4.0
const PHASE_4_COLOR_LEVELS_GLITCH_MIN: int = 8
const PHASE_4_COLOR_LEVELS_GLITCH_MAX: int = 256
const PHASE_4_DITHER_GLITCH_MIN: float = 0.0
const PHASE_4_DITHER_GLITCH_MAX: float = 1.5
@warning_ignore("unused_private_class_variable")
var _phase3_rumble: AudioStreamPlayer = null
@warning_ignore("unused_private_class_variable")
var _master_pitch_effect_idx: int = -1
@warning_ignore("unused_private_class_variable")
var _maw_breath_tween: Tween = null
@warning_ignore("unused_private_class_variable")
var _time_distortion_tween: Tween = null
@warning_ignore("unused_private_class_variable")
var _phase4_psx_baseline: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _phase4_glitch_active: bool = false
@warning_ignore("unused_private_class_variable")
var _phase4_rumble: AudioStreamPlayer = null
@warning_ignore("unused_private_class_variable")
var _phase4_light_color_backup: Dictionary = {}
# ── Ending (Phase 5) ──
const ENDING_SCENE_PATH: String = "res://scenes/test_black_hole.tscn"
const ENDING_SUCTION_RAMP_TIME: float = 28.0 # seconds from first tug to irresistible
const ENDING_PLAYER_PULL_MAX: float = 10.0 # via apply_external_force (x/z)
const ENDING_BODY_ACCEL_MAX: float = 200.0 # m/s² at full ramp, mass-independent
const ENDING_WAKE_RADIUS_START: float = 20.0 # pull reaches nearest objects first…
const ENDING_WAKE_RADIUS_END: float = 100.0 # …then creeps outward = "little by little"
const STUCK_HEIGHT_THRESHOLD: float = 30.0
const PLAYER_RESPAWN_POSITION: Vector3 = Vector3(0, 6, 18) # matches BottomMaw respawn
const ENDING_CAPTURE_RADIUS: float = 14.0 # inside this, stop pulling — let it drop in

var ending_active: bool = false
@warning_ignore("unused_private_class_variable")
var _player_consumed: bool = false
@warning_ignore("unused_private_class_variable")
var _suction_active: bool = false
@warning_ignore("unused_private_class_variable")
var _suction_t: float = 0.0
@warning_ignore("unused_private_class_variable")
var _maw_center: Vector3 = Vector3.ZERO
@warning_ignore("unused_private_class_variable")
var _suction_bodies: Array[RigidBody3D] = []
@warning_ignore("unused_private_class_variable")
var _suction_scan_timer: float = 0.0
@warning_ignore("unused_private_class_variable")
var _ending_rumble: AudioStreamPlayer = null
@warning_ignore("unused_private_class_variable")
var _fixtures_devoured: bool = false
@warning_ignore("unused_private_class_variable")
var _player_last_dist: float = INF
@warning_ignore("unused_private_class_variable")
var _player_stuck_time: float = 0.0
