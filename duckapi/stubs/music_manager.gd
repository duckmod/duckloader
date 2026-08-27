extends Node

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var high_pass_filter: AudioEffectHighPassFilter = AudioEffectHighPassFilter.new()

var current_track: AudioStream
var fade_time := 2.0 # default fade time in seconds
var first_play := true

var music_bus_index: int = -1
var filter_effect_index: int = -1

# Filter settings
var normal_cutoff := 1.0 # Normal frequency (barely audible)
var paused_cutoff := 2000.0 # High-pass cutoff when paused (muffled sound)
var filter_transition_time := 0.3 # How fast to transition the filter

var was_paused := false

var no_filter := true
