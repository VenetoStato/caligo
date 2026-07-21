class_name BoatBuoyancy
extends RigidBody2D

## Single-owner buoyancy for boats. WaterBody detects this body and creates
## wakes, but skips its generic RigidBody buoyancy because this script marks it.

@export_category("Buoyancy")
@export var float_offset: float = 8.0
@export var buoyancy_strength: float = 38.0
@export var buoyancy_damping: float = 8.0
@export var max_up_force: float = 8000.0
@export var water_drag_per_second: float = 2.4
@export var surface_margin: float = 45.0

@export_category("Wake")
@export var wake_speed_threshold: float = 45.0
@export var wake_interval: float = 0.18
@export var wake_impulse_scale: float = 0.34
@export var wake_radius: float = 68.0

var _cached_water: Node
var _wake_cooldown: float = 0.0
var _was_near_surface: bool = false


func _ready() -> void:
	add_to_group("ship")
	set_meta("water_buoyancy_owner", self)


func _exit_tree() -> void:
	if has_meta("water_buoyancy_owner"):
		remove_meta("water_buoyancy_owner")


func _physics_process(delta: float) -> void:
	var water := _get_water()
	if water == null:
		_was_near_surface = false
		return

	var surface_y := _get_surface_height(water)
	var target_y := surface_y - float_offset
	var displacement := global_position.y - target_y
	var near_surface := displacement >= -surface_margin

	if near_surface:
		var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
		var acceleration := gravity * gravity_scale
		acceleration += displacement * buoyancy_strength
		acceleration -= linear_velocity.y * buoyancy_damping
		var upward_force := clampf(mass * acceleration, -max_up_force, max_up_force)
		apply_central_force(Vector2(0.0, -upward_force))
		linear_velocity *= exp(-water_drag_per_second * delta)

	_wake_cooldown = maxf(_wake_cooldown - delta, 0.0)
	if near_surface and not _was_near_surface:
		_send_splash(water, maxf(absf(linear_velocity.y), linear_velocity.length() * 0.5))
	elif near_surface and _wake_cooldown <= 0.0 and linear_velocity.length() >= wake_speed_threshold:
		_send_splash(water, linear_velocity.length())
	_was_near_surface = near_surface


func _send_splash(water: Node, speed: float) -> void:
	if not water.has_method("splash_at"):
		return
	var vertical_direction := signf(linear_velocity.y)
	if is_zero_approx(vertical_direction):
		vertical_direction = 1.0
	var impulse := vertical_direction * speed * sqrt(maxf(mass, 0.1)) * wake_impulse_scale
	water.call("splash_at", global_position.x, impulse, wake_radius + sqrt(maxf(mass, 0.1)) * 8.0)
	_wake_cooldown = wake_interval


func _get_water() -> Node:
	if _cached_water != null and is_instance_valid(_cached_water):
		var cached_bounds := _get_bounds(_cached_water)
		if global_position.x >= cached_bounds.x and global_position.x <= cached_bounds.y:
			return _cached_water

	var best: Node
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("water"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		var bounds := _get_bounds(candidate)
		if global_position.x >= bounds.x and global_position.x <= bounds.y:
			_cached_water = candidate
			return candidate
		var center := (bounds.x + bounds.y) * 0.5
		var distance := absf(global_position.x - center)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	_cached_water = best
	return best


func _get_bounds(water: Node) -> Vector2:
	if water.has_method("get_water_bounds_global_x"):
		return water.call("get_water_bounds_global_x")
	return Vector2(-INF, INF)


func _get_surface_height(water: Node) -> float:
	if water.has_method("get_surface_height"):
		return float(water.call("get_surface_height", global_position.x))
	if "target_height" in water:
		return water.global_position.y + float(water.target_height)
	return global_position.y
