extends Node

var default_bindings = {
	"up": KEY_W,
	"down": KEY_S,
	"left": KEY_A,
	"right": KEY_D,
	"sprint": KEY_SHIFT,
	"jump": KEY_SPACE,
	"crouch": KEY_C,
	"interact": KEY_F,
	"rotate": KEY_R,
	"equip": KEY_E,
	"action": KEY_Q,
	"reset": KEY_G,
	"torch": KEY_T,
	"rack": KEY_V,
	"lMouse": MOUSE_BUTTON_LEFT,
	"rMouse": MOUSE_BUTTON_RIGHT,
	"mMouse": MOUSE_BUTTON_MIDDLE,
	"esc": KEY_ESCAPE,
	"quick_save": KEY_F5,
	"quick_load": KEY_F9,
	"scroll_up": MOUSE_BUTTON_WHEEL_UP,
	"scroll_down": MOUSE_BUTTON_WHEEL_DOWN,
}

# ═══════════════════════════════════════════════════════════════════════════
#  GAMEPAD BINDINGS
#
#  A  = Jump          B  = Crouch/Slide      X  = Interact (F)
#  Y  = Snap mode (R) LB = Equip (E) + Action (Q)
#  RB = Free rotate (hold + right stick)
#  LS click = Sprint toggle    RS click = Reset rotation (G)
#  RT = Grab/Drop/Craft (LMB)  LT = Throw (RMB)
#  DPad Up/Down = Distance / Remote channel / Tool tune (context)
#  Select = Torch → UV lamp cycle
#  Start = Pause
#  Left stick = Move    Right stick = Camera look (+ rotation when RB held)
# ═══════════════════════════════════════════════════════════════════════════

var default_gamepad_bindings = {
	"jump": JOY_BUTTON_A,
	"crouch": JOY_BUTTON_B,
	"interact": JOY_BUTTON_X,
	"rotate": JOY_BUTTON_Y,
	"equip": JOY_BUTTON_LEFT_SHOULDER,
	"action": JOY_BUTTON_LEFT_SHOULDER,
	"mMouse": JOY_BUTTON_RIGHT_SHOULDER, # RB = free rotate
	"reset": JOY_BUTTON_RIGHT_STICK, # RS click = reset rotation
	"sprint": JOY_BUTTON_LEFT_STICK, # LS click = sprint toggle
	"torch": JOY_BUTTON_BACK, # Select / Share / − = torch → UV cycle
	"rack": JOY_BUTTON_DPAD_LEFT,
	"esc": JOY_BUTTON_START,
}

# Analog triggers registered as JoypadMotion so is_action_pressed() works everywhere
var gamepad_trigger_bindings = {
	"lMouse": JOY_AXIS_TRIGGER_RIGHT, # RT = grab/drop/craft
	"rMouse": JOY_AXIS_TRIGGER_LEFT, # LT = throw
}

# Mouse button codes occupy 1–9; no keycode falls in that range, so a raw int
# is unambiguous between the two devices.
const MOUSE_CODE_MIN := MOUSE_BUTTON_LEFT
const MOUSE_CODE_MAX := MOUSE_BUTTON_XBUTTON2

# A wheel notch emits press + release in the same input flush, so
# is_action_pressed() is never true when polled in a frame loop.
const WHEEL_CODES := [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]

# Actions polled as held — they need a code that can physically stay down.
const HOLD_ACTIONS := ["up", "down", "left", "right", "sprint", "jump",
		"crouch", "lMouse", "rMouse", "mMouse"]

#  Device detection

var using_gamepad: bool = false
var active_device: int = 0
signal input_device_changed(is_gamepad: bool)
var active_joy_device: int = 0

var current_bindings = {}
var current_gamepad_bindings = {}

signal bindings_changed

# Sprint toggle state (gamepad only)
var gamepad_sprint_toggled: bool = false

# Controler type detection

enum ControllerType {XBOX, PLAYSTATION, NINTENDO, GENERIC}

## Override mode: AUTO uses joypad name detection, others force a specific type.
## Used by the options menu so players can fix wrong auto-detection.
enum GlyphOverride {AUTO, XBOX, PLAYSTATION, NINTENDO}

var controller_type: ControllerType = ControllerType.XBOX
var glyph_override: GlyphOverride = GlyphOverride.AUTO

const VENDOR_SONY := 0x054C
const VENDOR_NINTENDO := 0x057E
const VENDOR_MICROSOFT := 0x045E
const DISCONNECT_PAUSE_DELAY := 0.75

const UI_FONT_PATH := "res://assets/PublicPixel-rv0pA.ttf"
var _ps_shapes_ok: int = -1 # -1 = unprobed, 0 = no, 1 = yes

const MOUSE_SWITCH_PX := 12.0
var _mouse_motion_accum := 0.0

signal controller_type_changed(new_type: ControllerType)
