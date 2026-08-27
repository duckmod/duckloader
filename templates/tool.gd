extends RigidBody3D

@export var this_name: String = "OBJ_CUSTOM_TOOL"
@export var pool_id: String = "custom_tool"

@export_group("Equip Properties")
@export var is_equipped: bool = false
@export var equipped_offset: Vector3 = Vector3(0, -0.5, -1.0)
@export var equipped_rotation: Vector3 = Vector3(0, -90, 0)
@export var reset_rotation_offset: Vector3 = Vector3(0, 180, 0)

@onready var outline_mesh: MeshInstance3D = $MeshInstance3D

var verbosity = 2

var _original_collision_layer: int = collision_layer
var _original_collision_mask: int = collision_mask

func _ready() -> void:
	sleeping = false
	add_to_group("equipable")
	add_to_group("draggable")
	add_to_group("tool")
	add_to_group("custom_tool")
	
	_log(this_name + " is ready", 2)

func equip(camera: Camera3D) -> void:
	if is_equipped:
		return

	is_equipped = true
	_original_collision_layer = collision_layer
	_original_collision_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	var old_parent = get_parent()
	if old_parent:
		old_parent.remove_child(self)

	camera.add_child(self)

	transform = Transform3D.IDENTITY
	position = equipped_offset
	rotation_degrees = equipped_rotation
	
	_log("Equiped " + this_name, 1)

func unequip(world: Node3D, drop_pos: Vector3) -> void:
	if not is_equipped:
		return

	is_equipped = false

	var old_parent = get_parent()
	if old_parent:
		old_parent.remove_child(self)

	world.add_child(self)
	global_transform.origin = drop_pos

	if old_parent is Camera3D:
		var forward: Vector3 = -old_parent.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()

		look_at(global_transform.origin + forward, Vector3.UP)
		rotate_y(deg_to_rad(180))

	freeze = false
	collision_layer = _original_collision_layer
	collision_mask = _original_collision_mask
	
	_log("Unequiped " + this_name, 1)

func interact() -> void:
	_log("Interacted with " + this_name, 1)
	pass

func get_equipped_controls_text(ctrl_func: Callable, _looking_at_toggle: bool, _looking_at_linked: bool) -> String:
	return ctrl_func.call("CTRL_UNEQUIP") + " | " + ctrl_func.call("CTRL_INTERACT")

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
		
	_log("Setting outline for " + this_name + " to " + str(active), 2)

func object_name() -> String:
	return tr(this_name)

func get_reset_basis() -> Basis:
	return Basis.from_euler(reset_rotation_offset * PI / 180.0)

func on_pool_spawn() -> void:
	is_equipped = false
	freeze = false
	collision_layer = _original_collision_layer
	collision_mask = _original_collision_mask
	
	_log("Spawned " + this_name, 2)

func on_pool_recycle() -> void:
	_log("Recycled " + this_name, 2)

func _log(msg: String, lvl: int) -> void:
	if verbosity >= lvl:
		DuckLoader.log_message(msg)
