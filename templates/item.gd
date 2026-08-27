extends RigidBody3D

@export var this_name: String = "OBJ_CUSTOM_ITEM"
@export var pool_id: = "custom_item"
@export var value: = 1
@export var collision_sounds: Array[AudioStream] = []
@onready var outline_mesh: MeshInstance3D = $MeshInstance3D
@onready var spawn_audio: AudioStreamPlayer3D = $SpawnAudio3D
@onready var collision_audio: AudioStreamPlayer3D = $CollisionAudio3D

@export var min_collision_force: = 0.5

@export var max_collision_force: = 10.0

@export var min_volume_db: = -20.0
@export var max_volume_db: = 0.0

var draggable = true

var last_velocity: Vector3 = Vector3.ZERO

var collision_cooldown: = 0.0

func _ready() -> void:
	if draggable:
		add_to_group("draggable")

func _physics_process(_delta: float) -> void :
	last_velocity = linear_velocity

func _process(delta):

	if collision_cooldown > 0:
		collision_cooldown -= delta

func _on_body_entered(_body):
	if not is_instance_valid(collision_audio) or collision_audio.is_queued_for_deletion():
		return

	var impact_force = (last_velocity - linear_velocity).length()

	if collision_cooldown <= 0 and impact_force > min_collision_force:
		if not ImpactAudio.request(impact_force):
			return

		if collision_audio:

			if collision_sounds.size() > 0:
				collision_audio.stream = collision_sounds[randi() % collision_sounds.size()]


			var volume = calculate_collision_volume(impact_force)
			collision_audio.volume_db = volume


			var pitch_variation = remap(impact_force, min_collision_force, max_collision_force, 0.9, 1.1)
			collision_audio.pitch_scale = clamp(pitch_variation, 0.5, 10.0)

			collision_audio.play()


		collision_cooldown = 0.2

	if _body.is_in_group("tool"):
		set_meta("panel_ricochet", true)


func calculate_collision_volume(impact_force: float) -> float:

	var normalized_force = clamp((impact_force - min_collision_force) / (max_collision_force - min_collision_force), 0.0, 1.0)

	var volume = lerp(min_volume_db, max_volume_db, normalized_force)

	return volume


func set_highlight(active: bool, grabbed: bool = false) -> void :

	if not outline_mesh:
		return

	if active:
		outline_mesh.visible = true
		var mat: = outline_mesh.material_override as StandardMaterial3D

		if grabbed:
			mat.albedo_color = Color(0, 1, 0)
		else:
			mat.albedo_color = Color(1, 1, 1)
	else:
		outline_mesh.visible = false


func object_name():
	return tr(this_name)

func on_pool_spawn():
	if not SaveManager.is_loading and spawn_audio and spawn_audio.stream:
		spawn_audio.play()

	if SaveManager.is_loading:
		collision_cooldown = 0.5

	set_meta("player_throw_time", 0.0)
	set_meta("player_throw_position", Vector3.ZERO)
