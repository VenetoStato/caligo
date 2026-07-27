class_name WaterBody
extends Area2D

## Mobile-first hybrid water:
## - CPU springs define the physical surface and the polygon silhouette.
## - A GL Compatibility shader adds inexpensive detail and up to four ripples.
## - This Area2D alone detects bodies; individual springs have no collision nodes.

const SPRING_SCRIPT := preload("res://water_spring.gd")
const WATER_SHADER := preload("res://Water/water_mobile.gdshader")
const SPLASH_EFFECT_SCRIPT := preload("res://Water/water_splash_effect.gd")
const RIPPLE_COUNT := 4
const RIPPLE_UNIFORMS: PackedStringArray = ["ripple_0", "ripple_1", "ripple_2", "ripple_3"]

enum QualityPreset { AUTO, ANDROID, PC }

@export_category("Simulation")
@export_enum("Auto", "Android", "PC") var quality_preset: int = QualityPreset.AUTO
@export_range(32, 48, 1) var android_samples: int = 32
@export_range(32, 48, 1) var pc_samples: int = 48
@export_range(4, 8, 1) var android_passes: int = 4
@export_range(4, 8, 1) var pc_passes: int = 8
@export_range(1.0, 80.0, 0.5) var k: float = 22.0
@export_range(0.1, 20.0, 0.1) var d: float = 5.5
@export_range(1.0, 120.0, 0.5) var spread: float = 42.0
@export var depth: float = 1000.0
@export var max_splash_impulse: float = 480.0
@export var max_wave_height: float = 72.0
@export var max_spring_velocity: float = 360.0

@export_category("Body interaction")
@export var player_gravity_reduction: float = 0.3
@export var rigidbody_buoyancy_ratio: float = 0.92
@export var rigidbody_linear_drag: float = 2.4
@export var impact_velocity_threshold: float = 8.0
@export var impact_impulse_scale: float = 0.85
@export var interaction_interval: float = 0.1
@export var character_wake_radius: float = 84.0
@export var nominal_character_mass: float = 1.0
@export var character_buoyancy_acceleration: float = 420.0
@export var character_vertical_drag: float = 2.2

@export_category("Visual")
@export var shallow_color: Color = Color(0.08, 0.30, 0.36, 0.48)
@export var deep_color: Color = Color(0.015, 0.09, 0.16, 0.74)
@export var foam_color: Color = Color(0.52, 0.80, 0.82, 0.52)
@export_range(0.0, 0.5, 0.01) var reflection_strength: float = 0.09
@export_range(0.0, 0.04, 0.001) var refraction_strength: float = 0.012
@export var visual_splash_min_impulse: float = 42.0
@export var visual_splash_interval: float = 0.14

@export_category("Fish spawning")
@export var fish_scene: PackedScene
@export_range(0, 30, 1) var fish_count: int = 5
@export_range(0, 6, 1) var tutorial_fish_count: int = 0
@export_range(0.05, 0.95, 0.01) var tutorial_fish_center_ratio := 0.5

# Legacy-facing fields retained for existing boat/fish integrations.
var springs: Array[Node2D] = []
var passes: int = 4
var target_height: float = 0.0
var bottom: float = 0.0
var distance_between_springs: float = 32.0
var spring_number: int = 48
var border_thickness: float = 1.1

var water_polygon: Polygon2D
var water_border: Path2D
var collision_polygon: CollisionPolygon2D
var bodies_in_water: Array[Node2D] = []

var _surface_left := Vector2.ZERO
var _surface_right := Vector2.ZERO
var _velocity_deltas := PackedFloat32Array()
var _polygon_points := PackedVector2Array()
var _polygon_uvs := PackedVector2Array()
var _water_material: ShaderMaterial
var _ripples := PackedVector4Array()
var _next_ripple: int = 0
var _body_splash_cooldowns: Dictionary = {}
var _fish_textures: Array[Texture2D] = []
var _visual_splash_cooldown := 0.0

const FISH_VARIANT_PATHS: PackedStringArray = [
	"res://Landscape/Sprites/fish_boops1.png",
	"res://Landscape/Sprites/fish_boops2.png",
	"res://Landscape/Sprites/fish_boops3.png",
	"res://Landscape/Sprites/fish_sarago1.png",
	"res://Landscape/Sprites/fish_sarago2.png",
	"res://Landscape/Sprites/fish_sarago3.png",
]


func _ready() -> void:
	add_to_group("water")
	collision_mask |= 3
	monitoring = true

	collision_polygon = get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if collision_polygon == null or collision_polygon.polygon.size() < 4:
		push_error("WaterBody requires a CollisionPolygon2D with at least four points.")
		set_physics_process(false)
		return

	_select_quality()
	if not _find_surface_endpoints():
		push_error("WaterBody could not determine its surface.")
		set_physics_process(false)
		return

	_create_visuals()
	_create_springs()
	_build_surface_visual()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_cache_fish_textures()
	if fish_count > 0:
		call_deferred("spawn_fish_in_water")


func _select_quality() -> void:
	var use_android := quality_preset == QualityPreset.ANDROID
	if quality_preset == QualityPreset.AUTO:
		use_android = OS.has_feature("mobile") or OS.get_name() == "Android"
	spring_number = clampi(android_samples if use_android else pc_samples, 32, 48)
	passes = clampi(android_passes if use_android else pc_passes, 4, 8)


func _find_surface_endpoints() -> bool:
	var first := Vector2.ZERO
	var second := Vector2.ZERO
	var first_y := INF
	var second_y := INF
	for point in collision_polygon.polygon:
		var local_point: Vector2 = collision_polygon.transform * point
		if local_point.y < first_y:
			second = first
			second_y = first_y
			first = local_point
			first_y = local_point.y
		elif local_point.y < second_y:
			second = local_point
			second_y = local_point.y

	if not is_finite(first_y) or not is_finite(second_y):
		return false
	if first.x <= second.x:
		_surface_left = first
		_surface_right = second
	else:
		_surface_left = second
		_surface_right = first
	target_height = (_surface_left.y + _surface_right.y) * 0.5
	bottom = max(_surface_left.y, _surface_right.y) + maxf(depth, 1.0)
	distance_between_springs = absf(_surface_right.x - _surface_left.x) / float(spring_number - 1)
	return absf(_surface_right.x - _surface_left.x) > 0.001


func _create_visuals() -> void:
	water_polygon = Polygon2D.new()
	water_polygon.name = "DynamicWaterPolygon"
	water_polygon.z_index = 10
	_water_material = ShaderMaterial.new()
	_water_material.shader = WATER_SHADER
	_water_material.set_shader_parameter("shallow_color", shallow_color)
	_water_material.set_shader_parameter("deep_color", deep_color)
	_water_material.set_shader_parameter("foam_color", foam_color)
	_water_material.set_shader_parameter("reflection_strength", reflection_strength)
	_water_material.set_shader_parameter("refraction_strength", refraction_strength)
	water_polygon.material = _water_material
	add_child(water_polygon)

	water_border = Path2D.new()
	water_border.name = "DynamicWaterSurface"
	water_border.curve = Curve2D.new()
	add_child(water_border)

	_ripples.resize(RIPPLE_COUNT)
	for i in RIPPLE_COUNT:
		_ripples[i] = Vector4(0.0, -1.0, 0.0, 0.1)
		_water_material.set_shader_parameter(RIPPLE_UNIFORMS[i], _ripples[i])


func set_tuning_parameter(property_name: StringName, value: float) -> void:
	const TUNABLE: Array[StringName] = [
		&"k",
		&"d",
		&"spread",
		&"impact_impulse_scale",
		&"character_buoyancy_acceleration",
		&"reflection_strength",
		&"refraction_strength",
	]
	if not TUNABLE.has(property_name):
		return
	set(property_name, value)
	if _water_material != null and (
		property_name == &"reflection_strength" or property_name == &"refraction_strength"
	):
		_water_material.set_shader_parameter(property_name, value)


func _create_springs() -> void:
	springs.resize(spring_number)
	_velocity_deltas.resize(spring_number)
	for i in spring_number:
		var amount := float(i) / float(spring_number - 1)
		var spring := Node2D.new()
		spring.name = "WaterSpring_%d" % i
		spring.set_script(SPRING_SCRIPT)
		spring.position = _surface_left.lerp(_surface_right, amount)
		add_child(spring)
		spring.call("initialize", spring.position.x, i)
		springs[i] = spring
		water_border.curve.add_point(spring.position)

	_polygon_points.resize(spring_number + 2)
	_polygon_uvs.resize(spring_number + 2)


func _physics_process(delta: float) -> void:
	if springs.is_empty():
		return
	var safe_delta := minf(delta, 1.0 / 20.0)
	_visual_splash_cooldown = maxf(0.0, _visual_splash_cooldown - safe_delta)
	var pass_delta := safe_delta / float(passes)
	for _pass_index in passes:
		for spring in springs:
			spring.call("water_update", k, d, pass_delta)
			var rest_height: float = float(spring.get("target_height"))
			spring.position.y = clampf(
				spring.position.y,
				rest_height - max_wave_height,
				rest_height + max_wave_height
			)
			spring.set(
				"velocity",
				clampf(float(spring.get("velocity")), -max_spring_velocity, max_spring_velocity)
			)
		for i in spring_number:
			_velocity_deltas[i] = 0.0
		for i in spring_number - 1:
			var height_delta: float = springs[i].position.y - springs[i + 1].position.y
			var transfer := height_delta * spread * pass_delta
			_velocity_deltas[i] -= transfer
			_velocity_deltas[i + 1] += transfer
		for i in spring_number:
			var velocity: float = float(springs[i].get("velocity")) + _velocity_deltas[i]
			springs[i].set("velocity", clampf(velocity, -max_spring_velocity, max_spring_velocity))

	_update_body_interactions(safe_delta)
	_update_ripples(safe_delta)
	_build_surface_visual()


func _build_surface_visual() -> void:
	if water_polygon == null:
		return
	var width := maxf(absf(_surface_right.x - _surface_left.x), 1.0)
	var curve := water_border.curve

	for i in spring_number:
		var point: Vector2 = springs[i].position
		_polygon_points[i] = point
		_polygon_uvs[i] = Vector2((point.x - _surface_left.x) / width, 0.0)
		curve.set_point_position(i, point)

	_polygon_points[spring_number] = Vector2(_surface_right.x, bottom)
	_polygon_points[spring_number + 1] = Vector2(_surface_left.x, bottom)
	_polygon_uvs[spring_number] = Vector2(1.0, 1.0)
	_polygon_uvs[spring_number + 1] = Vector2(0.0, 1.0)
	water_polygon.polygon = _polygon_points
	water_polygon.uv = _polygon_uvs


## Adds a radial impulse to the physical samples and reserves one of four
## shader ripples. Positive impulses move the surface downward in Godot's 2D Y.
func splash_at(global_x: float, impulse: float, radius: float = 48.0) -> void:
	if springs.is_empty() or radius <= 0.0:
		return
	var bounds := get_water_bounds_global_x()
	if global_x < bounds.x - radius or global_x > bounds.y + radius:
		return

	var clamped_impulse := clampf(impulse, -max_splash_impulse, max_splash_impulse)
	var touched := false
	for spring in springs:
		var distance := absf(spring.global_position.x - global_x)
		if distance > radius:
			continue
		var normalized := 1.0 - distance / radius
		var weight := normalized * normalized * (3.0 - 2.0 * normalized)
		spring.call("add_impulse", clamped_impulse * weight)
		touched = true

	if touched:
		var width := maxf(bounds.y - bounds.x, 1.0)
		var center_uv := clampf((global_x - bounds.x) / width, 0.0, 1.0)
		var amplitude := clampf(absf(clamped_impulse) / maxf(max_splash_impulse, 1.0), 0.04, 1.0) * 0.11
		_ripples[_next_ripple] = Vector4(center_uv, 0.0, amplitude, clampf(radius / width, 0.01, 0.25))
		_next_ripple = (_next_ripple + 1) % RIPPLE_COUNT
		if absf(clamped_impulse) >= visual_splash_min_impulse and _visual_splash_cooldown <= 0.0:
			_spawn_visual_splash(global_x, clamped_impulse)
			_visual_splash_cooldown = visual_splash_interval


func _spawn_visual_splash(global_x: float, impulse: float) -> void:
	var splash := Node2D.new()
	splash.name = "WaterSplash"
	splash.set_script(SPLASH_EFFECT_SCRIPT)
	add_child(splash)
	splash.global_position = Vector2(global_x, get_surface_height(global_x))
	splash.z_index = 14
	splash.call("setup", impulse, foam_color)


## Returns the interpolated physical surface Y in global coordinates.
func get_surface_height(global_x: float) -> float:
	if springs.is_empty():
		return global_position.y + target_height
	if global_x <= springs[0].global_position.x:
		return springs[0].global_position.y
	var last_index := springs.size() - 1
	if global_x >= springs[last_index].global_position.x:
		return springs[last_index].global_position.y

	var local_x := to_local(Vector2(global_x, global_position.y)).x
	var width := maxf(_surface_right.x - _surface_left.x, 0.001)
	var sample_position := clampf((local_x - _surface_left.x) / width, 0.0, 1.0) * float(last_index)
	var left_index := mini(int(floor(sample_position)), last_index - 1)
	var amount := sample_position - float(left_index)
	var left_y: float = springs[left_index].global_position.y
	var right_y: float = springs[left_index + 1].global_position.y
	return lerpf(left_y, right_y, amount)


## Returns dy/dx of the physical surface around global_x.
func get_surface_slope(global_x: float) -> float:
	if springs.size() < 2:
		return 0.0
	var spacing := maxf(absf(springs[1].global_position.x - springs[0].global_position.x), 1.0)
	var left_x := global_x - spacing
	var right_x := global_x + spacing
	return (get_surface_height(right_x) - get_surface_height(left_x)) / (right_x - left_x)


func get_water_bounds_global_x() -> Vector2:
	var rect := get_water_bounds_global_rect()
	return Vector2(rect.position.x, rect.end.x)


func get_water_bounds_global_rect() -> Rect2:
	if collision_polygon == null or collision_polygon.polygon.is_empty():
		return Rect2(-10000.0, -10000.0, 20000.0, 20000.0)
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for point in collision_polygon.polygon:
		var global_point := to_global(collision_polygon.transform * point)
		min_point.x = minf(min_point.x, global_point.x)
		min_point.y = minf(min_point.y, global_point.y)
		max_point.x = maxf(max_point.x, global_point.x)
		max_point.y = maxf(max_point.y, global_point.y)
	return Rect2(min_point, max_point - min_point)


func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	if not bodies_in_water.has(body):
		bodies_in_water.append(body)
	if body is CharacterBody2D and body.has_method("set_in_water"):
		body.call("set_in_water", true, player_gravity_reduction, self)
	elif body.has_method("in_water"):
		body.call("in_water")
	elif body.has_method("set_in_water"):
		body.call("set_in_water", true)
	_emit_body_splash(body, true)


func _on_body_exited(body: Node2D) -> void:
	var index := bodies_in_water.find(body)
	if index >= 0:
		bodies_in_water.remove_at(index)
	if body != null:
		_body_splash_cooldowns.erase(body.get_instance_id())
		if body.has_method("exit_water"):
			body.call("exit_water")
		elif body.has_method("set_in_water"):
			body.call("set_in_water", false)


func _update_body_interactions(delta: float) -> void:
	for i in range(bodies_in_water.size() - 1, -1, -1):
		var body := bodies_in_water[i]
		if body == null or not is_instance_valid(body):
			bodies_in_water.remove_at(i)
			continue

		var id := body.get_instance_id()
		var cooldown: float = maxf(float(_body_splash_cooldowns.get(id, 0.0)) - delta, 0.0)
		_body_splash_cooldowns[id] = cooldown

		if body is CharacterBody2D:
			_apply_character_buoyancy(body as CharacterBody2D, delta)
			if cooldown <= 0.0:
				_emit_body_splash(body, false)
			continue

		if body is RigidBody2D:
			var rigid := body as RigidBody2D
			if not rigid.is_in_group("fish") and not rigid.is_in_group("ship") and not rigid.is_in_group("ship_moving"):
				_apply_rigid_buoyancy(rigid)
			if cooldown <= 0.0:
				_emit_body_splash(rigid, false)


func _apply_character_buoyancy(body: CharacterBody2D, delta: float) -> void:
	var surface_y := get_surface_height(body.global_position.x)
	var submersion := clampf((body.global_position.y - surface_y + 18.0) / 72.0, 0.0, 1.0)
	# Ribattono sulla superficie (cadendo): nuovo bounce + salto/doppio salto.
	if body.velocity.y > 40.0 and body.global_position.y >= surface_y - 10.0 and body.global_position.y <= surface_y + 28.0:
		var id := body.get_instance_id()
		var cooldown: float = float(_body_splash_cooldowns.get(id, 0.0))
		if cooldown <= 0.05 and body.has_method("refresh_jumps_from_water_surface"):
			body.call("refresh_jumps_from_water_surface")
			_emit_body_splash(body, true)
			_body_splash_cooldowns[id] = maxf(interaction_interval, 0.22)
	if submersion <= 0.0:
		return
	var buoyancy := character_buoyancy_acceleration * submersion
	var drag := body.velocity.y * character_vertical_drag * submersion
	body.velocity.y += (-buoyancy - drag) * delta


func _apply_rigid_buoyancy(body: RigidBody2D) -> void:
	if body.has_meta("water_buoyancy_owner"):
		return
	var surface_y := get_surface_height(body.global_position.x)
	var submersion := clampf((body.global_position.y - surface_y + 12.0) / 48.0, 0.0, 1.0)
	if submersion <= 0.0 or body.gravity_scale <= 0.0:
		return
	var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	var upward_force := body.mass * gravity * body.gravity_scale * rigidbody_buoyancy_ratio * submersion
	var drag_force := -body.linear_velocity * body.mass * rigidbody_linear_drag * submersion
	body.apply_central_force(Vector2(drag_force.x, drag_force.y - upward_force))


func _emit_body_splash(body: Node2D, entering: bool) -> void:
	var velocity := Vector2.ZERO
	var mass := nominal_character_mass
	if body is RigidBody2D:
		velocity = (body as RigidBody2D).linear_velocity
		mass = maxf((body as RigidBody2D).mass, 0.1)
	elif body is CharacterBody2D:
		velocity = (body as CharacterBody2D).velocity

	var impact_speed := maxf(absf(velocity.y), velocity.length() * (0.45 if entering else 0.28))
	if body is CharacterBody2D:
		impact_speed = maxf(impact_speed, absf(velocity.x) * 0.7)
	if entering:
		impact_speed = maxf(impact_speed, 110.0)
	if impact_speed < impact_velocity_threshold:
		return
	var direction := signf(velocity.y)
	if is_zero_approx(direction):
		direction = 1.0
	var impulse := direction * impact_speed * sqrt(mass) * impact_impulse_scale
	var radius := character_wake_radius if body is CharacterBody2D else clampf(42.0 + sqrt(mass) * 18.0, 48.0, 140.0)
	splash_at(body.global_position.x, impulse, radius)
	_body_splash_cooldowns[body.get_instance_id()] = interaction_interval


func _update_ripples(delta: float) -> void:
	if _water_material == null:
		return
	for i in RIPPLE_COUNT:
		var ripple := _ripples[i]
		if ripple.y >= 0.0:
			ripple.y += delta
			if ripple.y > 1.4:
				ripple.y = -1.0
				ripple.z = 0.0
			_ripples[i] = ripple
		_water_material.set_shader_parameter(RIPPLE_UNIFORMS[i], ripple)


func _cache_fish_textures() -> void:
	for path in FISH_VARIANT_PATHS:
		var texture := load(path) as Texture2D
		if texture != null:
			_fish_textures.append(texture)


func spawn_fish_in_water() -> void:
	if fish_scene == null:
		fish_scene = load("res://fish.tscn") as PackedScene
	if fish_scene == null or collision_polygon == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return

	var bounds := get_water_bounds_global_rect()
	for i in fish_count:
		var fish := fish_scene.instantiate()
		if fish == null:
			continue
		var use_variant := not _fish_textures.is_empty() and randf() < 0.5 and fish.has_method("set_fish_texture")
		var fish_scale := 0.06 if use_variant else 0.1
		if use_variant:
			fish.call("set_fish_texture", _fish_textures[randi() % _fish_textures.size()], fish_scale)

		# Il corpo resta a scala 1: scalare il root riduceva anche l'Area di
		# abboccata fino a circa un pixel, rendendo la pesca quasi impossibile.
		fish.scale = Vector2.ONE
		var sprite := fish.get_node_or_null("Fishes")
		if sprite == null:
			sprite = fish.get_node_or_null("Sprite2D")
		if sprite != null and not use_variant:
			sprite.scale = Vector2.ONE * 0.1
		var collision := fish.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null:
			collision.scale = Vector2.ONE * 0.62

		var spawn_position: Vector2
		if i < tutorial_fish_count:
			var cluster_offset := (float(i) - float(tutorial_fish_count - 1) * 0.5) * 58.0
			spawn_position = Vector2(
				lerpf(bounds.position.x, bounds.end.x, tutorial_fish_center_ratio) + cluster_offset,
				bounds.position.y + 48.0 + float(i % 2) * 24.0
			)
			fish.set_meta("tutorial_fish", true)
		else:
			spawn_position = Vector2(
				randf_range(bounds.position.x + 20.0, bounds.end.x - 20.0),
				randf_range(bounds.position.y + bounds.size.y * 0.2, bounds.position.y + bounds.size.y * 0.65)
			)
		call_deferred("_add_fish_to_scene", fish, scene, spawn_position)


func _add_fish_to_scene(fish: Node, scene: Node, spawn_position: Vector2) -> void:
	if fish == null or scene == null or not is_instance_valid(fish) or not is_instance_valid(scene):
		return
	if fish.has_method("set_water_body"):
		fish.call("set_water_body", self)
	if fish is Node2D:
		var fish_2d := fish as Node2D
		var scene_2d := scene as Node2D
		fish_2d.position = scene_2d.to_local(spawn_position) if scene_2d else spawn_position
	scene.add_child(fish)
