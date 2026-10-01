extends Area2D

## Marea fisica del Custode. Non usa sprite: la superficie e' una catena di
## molle 2D collegate, il volume sale dal pavimento e la collisione segue il
## pelo dell'acqua simulato.

const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")
const DESKTOP_SPRING_COUNT := 49
const MOBILE_SPRING_COUNT := 33
const SPRING_K := 34.0
const SPRING_DAMPING := 7.2
const SPREAD := 24.0

var span := Vector2(1320.0, 150.0)
var damage := 1
var windup := 1.5
var active_time := 4.0
var tint := Color(0.11, 0.48, 0.56, 0.94)

var _elapsed := 0.0
var _active := false
var _damage_timer := 0.0
var _splash_timer := 0.0
var _shape: RectangleShape2D
var _collision: CollisionShape2D
var _water_polygon: Polygon2D
var _surface_line: Line2D
var _bloom_line: Line2D
var _droplets: CPUParticles2D
var _heights := PackedFloat32Array()
var _velocities := PackedFloat32Array()
var _left_deltas := PackedFloat32Array()
var _right_deltas := PackedFloat32Array()
var _spring_count := DESKTOP_SPRING_COUNT


func setup(area_span: Vector2, attack_damage: int, attack_windup: float, attack_active: float) -> void:
	span = area_span
	damage = attack_damage
	windup = attack_windup
	active_time = attack_active


func _ready() -> void:
	add_to_group("enemy_transient_attack")
	add_to_group("boss_environment_attack")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	monitoring = false
	z_index = 7
	_shape = RectangleShape2D.new()
	_shape.size = Vector2(span.x, 4.0)
	_collision = CollisionShape2D.new()
	_collision.name = "FloodCollision"
	_collision.shape = _shape
	add_child(_collision)
	_build_physical_water()


func _build_physical_water() -> void:
	_spring_count = MOBILE_SPRING_COUNT if OS.has_feature("mobile") or OS.get_name() == "Android" else DESKTOP_SPRING_COUNT
	_heights.resize(_spring_count)
	_velocities.resize(_spring_count)
	_left_deltas.resize(_spring_count)
	_right_deltas.resize(_spring_count)
	var floor_y := span.y * 0.5
	for index in _spring_count:
		_heights[index] = floor_y
		_velocities[index] = 0.0

	_water_polygon = Polygon2D.new()
	_water_polygon.name = "PhysicalFloodVolume"
	add_child(_water_polygon)

	_surface_line = Line2D.new()
	_surface_line.name = "PhysicalFloodSurface"
	_surface_line.width = 4.0
	_surface_line.default_color = Color(0.48, 0.9, 0.88, 0.9)
	_surface_line.antialiased = true
	_surface_line.z_index = 2
	add_child(_surface_line)

	_bloom_line = Line2D.new()
	_bloom_line.name = "FloodBloom"
	_bloom_line.width = 13.0
	_bloom_line.default_color = Color(0.2, 0.78, 0.82, 0.22)
	_bloom_line.antialiased = true
	_bloom_line.z_index = 1
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bloom_line.material = additive
	add_child(_bloom_line)

	_droplets = CPUParticles2D.new()
	_droplets.name = "FloodDroplets"
	_droplets.amount = 36 if _spring_count == MOBILE_SPRING_COUNT else 72
	_droplets.lifetime = 0.82
	_droplets.one_shot = false
	_droplets.explosiveness = 0.2
	_droplets.randomness = 0.72
	_droplets.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_droplets.emission_rect_extents = Vector2(span.x * 0.48, 3.0)
	_droplets.direction = Vector2.UP
	_droplets.spread = 38.0
	_droplets.gravity = Vector2(0.0, 520.0)
	_droplets.initial_velocity_min = 75.0
	_droplets.initial_velocity_max = 210.0
	_droplets.scale_amount_min = 1.4
	_droplets.scale_amount_max = 4.2
	_droplets.color = Color(0.52, 0.92, 0.9, 0.72)
	_droplets.emitting = false
	_droplets.z_index = 3
	add_child(_droplets)
	_update_water_geometry()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var warning := clampf(_elapsed / maxf(windup, 0.01), 0.0, 1.0)
	var eased_rise := warning * warning * (3.0 - 2.0 * warning)
	var floor_y := span.y * 0.5
	var full_surface_y := -span.y * 0.5
	var target_height := lerpf(floor_y, full_surface_y, eased_rise)
	_simulate_surface(minf(delta, 1.0 / 20.0), target_height)
	_update_water_geometry()

	if not _active and _elapsed >= windup:
		_activate_flood()
	if _active:
		_splash_timer -= delta
		if _splash_timer <= 0.0:
			_splash_timer = 0.09
			_impulse_spring(randi_range(2, _spring_count - 3), randf_range(-95.0, -38.0))
		_damage_timer -= delta
		if _damage_timer <= 0.0:
			_damage_timer = 0.82
			_damage_overlaps()
	if _elapsed >= windup + active_time:
		queue_free()


func _simulate_surface(delta: float, target_height: float) -> void:
	for index in _spring_count:
		var displacement := target_height - _heights[index]
		var acceleration := displacement * SPRING_K - _velocities[index] * SPRING_DAMPING
		_velocities[index] += acceleration * delta
		_heights[index] += _velocities[index] * delta
	for _pass in 4:
		for index in _spring_count:
			_left_deltas[index] = 0.0
			_right_deltas[index] = 0.0
			if index > 0:
				_left_deltas[index] = SPREAD * (_heights[index] - _heights[index - 1]) * delta
				_velocities[index - 1] += _left_deltas[index]
			if index < _spring_count - 1:
				_right_deltas[index] = SPREAD * (_heights[index] - _heights[index + 1]) * delta
				_velocities[index + 1] += _right_deltas[index]
		for index in _spring_count:
			if index > 0:
				_heights[index - 1] += _left_deltas[index] * delta
			if index < _spring_count - 1:
				_heights[index + 1] += _right_deltas[index] * delta


func _impulse_spring(index: int, impulse: float) -> void:
	if index < 0 or index >= _spring_count:
		return
	_velocities[index] += impulse
	if index > 0:
		_velocities[index - 1] += impulse * 0.42
	if index < _spring_count - 1:
		_velocities[index + 1] += impulse * 0.42


func _update_water_geometry() -> void:
	var surface_points := PackedVector2Array()
	var polygon_points := PackedVector2Array()
	var colors := PackedColorArray()
	var half_width := span.x * 0.5
	var bottom := span.y * 0.5 + 8.0
	var average_surface := 0.0
	for index in _spring_count:
		var ratio := float(index) / float(_spring_count - 1)
		var point := Vector2(lerpf(-half_width, half_width, ratio), _heights[index])
		surface_points.append(point)
		polygon_points.append(point)
		colors.append(Color(0.16, 0.56, 0.61, 0.82))
		average_surface += _heights[index]
	polygon_points.append(Vector2(half_width, bottom))
	polygon_points.append(Vector2(-half_width, bottom))
	colors.append(Color(0.018, 0.12, 0.19, 0.95))
	colors.append(Color(0.018, 0.12, 0.19, 0.95))
	_water_polygon.polygon = polygon_points
	_water_polygon.vertex_colors = colors
	_surface_line.points = surface_points
	_bloom_line.points = surface_points
	average_surface /= float(_spring_count)
	var depth := maxf(bottom - average_surface, 4.0)
	_shape.size = Vector2(span.x, depth)
	_collision.position.y = average_surface + depth * 0.5
	_droplets.position.y = average_surface


func _activate_flood() -> void:
	_active = true
	monitoring = true
	_damage_timer = 0.0
	_droplets.emitting = true
	for index in range(2, _spring_count - 2, 4):
		_impulse_spring(index, randf_range(-150.0, -80.0))
	PARTICLE_BURST.spawn(
		get_tree().current_scene,
		global_position + Vector2(0.0, -span.y * 0.45),
		Color(0.4, 0.88, 0.86, 0.78), 28, Vector2.UP, 55.0, 180.0, 0.82
	)
	var camera := get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", 0.32)


func _damage_overlaps() -> void:
	var surface_y := global_position.y + _average_surface_height()
	for body in get_overlapping_bodies():
		if not (body is Node2D) or not body.is_in_group("player"):
			continue
		if body.global_position.y < surface_y or bool(body.get("is_swinging")):
			continue
		if body.has_method("receive_flood_surge"):
			body.call("receive_flood_surge", damage, global_position, surface_y)
		elif body.has_method("take_damage"):
			body.call("take_damage", damage, global_position)


func _average_surface_height() -> float:
	var total := 0.0
	for height in _heights:
		total += height
	return total / maxf(float(_heights.size()), 1.0)
