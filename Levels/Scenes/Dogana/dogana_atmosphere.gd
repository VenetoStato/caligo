extends Node2D
## Nebbia di laguna: nuvole soft (CPUParticles) + interazione col player.
## Niente polyline/rettangoli bianchi.

var _time := 0.0
var _player: Node2D
var _fog_layers: Array[CPUParticles2D] = []
var _wake_cooldown := 0.0
var _mobile := false
var _soft_tex: GradientTexture2D


func _ready() -> void:
	z_index = 2
	_mobile = OS.get_name() == "Android" or OS.has_feature("mobile")
	_soft_tex = _make_soft_cloud_texture()
	_build_fog_layers()
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_wake_cooldown = maxf(0.0, _wake_cooldown - delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	_interact_with_player(delta)


func _make_soft_cloud_texture() -> GradientTexture2D:
	# Texture radiale soft: aspetto "piuma di nebbia", non rettangolo.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.78, 0.88, 0.9, 0.55),
		Color(0.62, 0.78, 0.82, 0.28),
		Color(0.45, 0.62, 0.68, 0.08),
		Color(0.3, 0.4, 0.45, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 64 if _mobile else 96
	tex.height = 64 if _mobile else 96
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _build_fog_layers() -> void:
	# Tre fasce di nebbia a quote diverse (bassa / media / alta), lente e dense.
	var configs := [
		{"y": 520.0, "amount": 28, "scale": 2.8, "speed": 8.0, "alpha": 0.22, "z": 1},
		{"y": 430.0, "amount": 22, "scale": 3.4, "speed": 12.0, "alpha": 0.16, "z": 2},
		{"y": 300.0, "amount": 16, "scale": 4.0, "speed": 6.0, "alpha": 0.12, "z": 0},
	]
	for cfg in configs:
		var amount: int = int(cfg.amount)
		if _mobile:
			amount = maxi(10, amount / 2)
		var fog := CPUParticles2D.new()
		fog.name = "FogBand"
		fog.texture = _soft_tex
		fog.z_index = int(cfg.z)
		fog.amount = amount
		fog.lifetime = 14.0
		fog.preprocess = 14.0
		fog.explosiveness = 0.0
		fog.randomness = 0.85
		fog.local_coords = false
		fog.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		fog.emission_rect_extents = Vector2(3200.0, 70.0)
		fog.position = Vector2(2800.0, float(cfg.y))
		fog.direction = Vector2(1.0, 0.05)
		fog.spread = 18.0
		fog.gravity = Vector2(0.0, -1.5)
		fog.initial_velocity_min = float(cfg.speed) * 0.55
		fog.initial_velocity_max = float(cfg.speed)
		fog.angular_velocity_min = -4.0
		fog.angular_velocity_max = 4.0
		fog.scale_amount_min = float(cfg.scale) * 0.75
		fog.scale_amount_max = float(cfg.scale) * 1.35
		fog.color = Color(0.72, 0.84, 0.86, float(cfg.alpha))
		# Fade in/out vita particella
		var color_ramp := Gradient.new()
		color_ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.75, 1.0])
		color_ramp.colors = PackedColorArray([
			Color(1, 1, 1, 0.0),
			Color(1, 1, 1, 1.0),
			Color(1, 1, 1, 0.85),
			Color(1, 1, 1, 0.0),
		])
		fog.color_ramp = color_ramp
		add_child(fog)
		_fog_layers.append(fog)

	# Mote lagunari molto discreti (non "rettangoli").
	var motes := CPUParticles2D.new()
	motes.name = "LagoonMotes"
	motes.texture = _soft_tex
	motes.z_index = 3
	motes.amount = 18 if _mobile else 36
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.randomness = 0.9
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(3000.0, 380.0)
	motes.position = Vector2(2800.0, 360.0)
	motes.direction = Vector2(-0.2, -1.0)
	motes.spread = 50.0
	motes.gravity = Vector2(-1.0, -3.0)
	motes.initial_velocity_min = 2.0
	motes.initial_velocity_max = 9.0
	motes.scale_amount_min = 0.12
	motes.scale_amount_max = 0.35
	motes.color = Color(0.45, 0.85, 0.8, 0.14)
	add_child(motes)


func _interact_with_player(_delta: float) -> void:
	if _player == null or _fog_layers.is_empty():
		return
	var speed := 0.0
	if _player is CharacterBody2D:
		speed = (_player as CharacterBody2D).velocity.length()
	# Correndo nella nebbia: le bande basse si aprono / accelerano (wake).
	var near_ground_fog := _player.global_position.y > 380.0
	if near_ground_fog and speed > 40.0:
		for fog in _fog_layers:
			if fog.position.y < 480.0:
				continue
			# Leggero "soffio" nella direzione del movimento.
			var facing := 1.0
			if _player is CharacterBody2D:
				facing = signf((_player as CharacterBody2D).velocity.x)
				if is_zero_approx(facing):
					facing = 1.0
			fog.direction = Vector2(facing, -0.15).normalized()
			fog.initial_velocity_min = 14.0
			fog.initial_velocity_max = 28.0
		if _wake_cooldown <= 0.0:
			_spawn_player_wake()
			_wake_cooldown = 0.18 if _mobile else 0.12
	else:
		# Riposo: deriva lenta costante.
		for i in _fog_layers.size():
			var fog := _fog_layers[i]
			var base_speed := 8.0 + float(i) * 2.0
			fog.direction = Vector2(1.0, 0.04)
			fog.initial_velocity_min = base_speed * 0.55
			fog.initial_velocity_max = base_speed


func _spawn_player_wake() -> void:
	if _player == null:
		return
	var puff := CPUParticles2D.new()
	puff.texture = _soft_tex
	puff.one_shot = true
	puff.explosiveness = 0.85
	puff.amount = 4 if _mobile else 7
	puff.lifetime = 0.7
	puff.emitting = true
	puff.z_index = 4
	puff.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 10.0
	puff.direction = Vector2(0, -1)
	puff.spread = 160.0
	puff.gravity = Vector2(0, -8)
	puff.initial_velocity_min = 12.0
	puff.initial_velocity_max = 34.0
	puff.scale_amount_min = 1.2
	puff.scale_amount_max = 2.4
	puff.color = Color(0.75, 0.88, 0.9, 0.28)
	add_child(puff)
	puff.global_position = _player.global_position + Vector2(0, -8)
	get_tree().create_timer(1.0).timeout.connect(puff.queue_free)
