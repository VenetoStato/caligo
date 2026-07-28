extends Node2D
## Nebbia ambientale Dogana: volumi world-space (shader) + mote discreti.
## Interazione locale col player (foro/scia), senza far seguire la nebbia al personaggio.

const FOG_SHADER := preload("res://Levels/Scenes/Dogana/dogana_fog.gdshader")

var _time := 0.0
var _player: CharacterBody2D
var _fog_mats: Array[ShaderMaterial] = []
var _mobile := false
var _soft_tex: GradientTexture2D
var _wake_cooldown := 0.0
var _motes: CPUParticles2D

# Copertura mondo Dogana (allineata ai room_limits camera).
const WORLD_RECT := Rect2(-700.0, -1500.0, 7200.0, 2600.0)


func _ready() -> void:
	z_index = -1
	_mobile = OS.get_name() == "Android" or OS.has_feature("mobile")
	_soft_tex = _make_soft_cloud_texture()
	_build_fog_volumes()
	_build_ambient_motes()
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_wake_cooldown = maxf(0.0, _wake_cooldown - delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_update_fog_interaction(delta)


func _make_soft_cloud_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 0.75, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.78, 0.9, 0.92, 0.5),
		Color(0.6, 0.78, 0.82, 0.22),
		Color(0.4, 0.58, 0.64, 0.05),
		Color(0.25, 0.35, 0.4, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 48 if _mobile else 72
	tex.height = 48 if _mobile else 72
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _build_fog_volumes() -> void:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var white_tex := ImageTexture.create_from_image(img)
	# Tre piani di profondità: fondo (lento), medio, primo piano (più interattivo).
	var layers := [
		{
			"name": "FogFar",
			"z": -3,
			"density": 0.42,
			"scale": 0.0024,
			"wind": Vector2(0.012, 0.003),
			"color": Color(0.62, 0.78, 0.84, 0.55),
			"layer": 0.0,
			"disturb": 0.28,
			"radius": 160.0,
			"octaves": 3 if _mobile else 4,
		},
		{
			"name": "FogMid",
			"z": 1,
			"density": 0.58,
			"scale": 0.0034,
			"wind": Vector2(0.02, 0.005),
			"color": Color(0.72, 0.86, 0.88, 0.62),
			"layer": 0.45,
			"disturb": 0.55,
			"radius": 130.0,
			"octaves": 3 if _mobile else 4,
		},
		{
			"name": "FogNear",
			"z": 6,
			"density": 0.34,
			"scale": 0.0046,
			"wind": Vector2(0.028, 0.006),
			"color": Color(0.78, 0.9, 0.92, 0.48),
			"layer": 1.0,
			"disturb": 0.72,
			"radius": 110.0,
			"octaves": 3,
		},
	]
	for cfg in layers:
		var poly := Polygon2D.new()
		poly.name = str(cfg.name)
		poly.z_index = int(cfg.z)
		poly.polygon = PackedVector2Array([
			WORLD_RECT.position,
			Vector2(WORLD_RECT.end.x, WORLD_RECT.position.y),
			WORLD_RECT.end,
			Vector2(WORLD_RECT.position.x, WORLD_RECT.end.y),
		])
		poly.uv = PackedVector2Array([
			Vector2(0, 0),
			Vector2(1, 0),
			Vector2(1, 1),
			Vector2(0, 1),
		])
		poly.color = Color.WHITE
		poly.texture = white_tex
		var mat := ShaderMaterial.new()
		mat.shader = FOG_SHADER
		mat.set_shader_parameter("u_color", cfg.color)
		mat.set_shader_parameter("u_density", cfg.density)
		mat.set_shader_parameter("u_scale", cfg.scale)
		mat.set_shader_parameter("u_wind", cfg.wind)
		mat.set_shader_parameter("u_layer", cfg.layer)
		mat.set_shader_parameter("u_disturb_strength", cfg.disturb)
		mat.set_shader_parameter("u_disturb_radius", cfg.radius)
		mat.set_shader_parameter("u_octaves", cfg.octaves)
		mat.set_shader_parameter("u_ground_y", 560.0)
		mat.set_shader_parameter("u_ceiling_y", -900.0)
		mat.set_shader_parameter("u_height_soft", 0.62)
		poly.material = mat
		add_child(poly)
		_fog_mats.append(mat)


func _build_ambient_motes() -> void:
	# Particelle WORLD-fixed: non vengono riorientate dal player.
	_motes = CPUParticles2D.new()
	_motes.name = "LagoonMotes"
	_motes.texture = _soft_tex
	_motes.z_index = 2
	_motes.amount = 14 if _mobile else 28
	_motes.lifetime = 9.0
	_motes.preprocess = 9.0
	_motes.randomness = 0.92
	_motes.local_coords = false
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(WORLD_RECT.size.x * 0.5, WORLD_RECT.size.y * 0.28)
	_motes.position = WORLD_RECT.get_center() + Vector2(0, 80)
	_motes.direction = Vector2(0.35, -0.15)
	_motes.spread = 35.0
	_motes.gravity = Vector2(-0.4, -1.2)
	_motes.initial_velocity_min = 3.0
	_motes.initial_velocity_max = 8.0
	_motes.scale_amount_min = 0.15
	_motes.scale_amount_max = 0.4
	_motes.color = Color(0.55, 0.88, 0.84, 0.12)
	add_child(_motes)


func _update_fog_interaction(delta: float) -> void:
	var player_pos := Vector2(-99999.0, -99999.0)
	var player_vel := Vector2.ZERO
	var speed := 0.0
	if _player:
		player_pos = _player.global_position
		player_vel = _player.velocity
		speed = player_vel.length()
	for mat in _fog_mats:
		mat.set_shader_parameter("u_player_world", player_pos)
		mat.set_shader_parameter("u_player_vel", player_vel)

	# Scia locale: poche piume che muoiono subito (non muove l'intera atmosfera).
	if _player == null or speed < 55.0 or _wake_cooldown > 0.0:
		return
	if player_pos.y < 200.0:
		return
	_wake_cooldown = 0.22 if _mobile else 0.14
	_spawn_local_wake(player_pos, player_vel)


func _spawn_local_wake(at: Vector2, vel: Vector2) -> void:
	var puff := CPUParticles2D.new()
	puff.texture = _soft_tex
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.amount = 3 if _mobile else 5
	puff.lifetime = 0.55
	puff.emitting = true
	puff.z_index = 5
	puff.local_coords = false
	puff.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 8.0
	var back := -vel.normalized() if vel.length_squared() > 0.01 else Vector2.LEFT
	puff.direction = back
	puff.spread = 70.0
	puff.gravity = Vector2(0, -6)
	puff.initial_velocity_min = 8.0
	puff.initial_velocity_max = 22.0
	puff.scale_amount_min = 0.7
	puff.scale_amount_max = 1.5
	puff.color = Color(0.78, 0.9, 0.92, 0.18)
	add_child(puff)
	puff.global_position = at + Vector2(0, 6) + back * 12.0
	get_tree().create_timer(0.8).timeout.connect(puff.queue_free)
