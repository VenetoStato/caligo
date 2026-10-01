extends RefCounted


static var _soft_tex: GradientTexture2D


static func _soft_texture() -> GradientTexture2D:
	if _soft_tex != null:
		return _soft_tex
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 0.75, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.55),
		Color(1, 1, 1, 0.12),
		Color(1, 1, 1, 0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 48
	tex.height = 48
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_soft_tex = tex
	return _soft_tex


static func spawn(
	parent: Node,
	world_position: Vector2,
	tint: Color,
	amount := 12,
	direction := Vector2.UP,
	speed_min := 35.0,
	speed_max := 105.0,
	lifetime := 0.75
) -> CPUParticles2D:
	if parent == null:
		return null
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = maxi(4, amount / 2) if OS.get_name() == "Android" else amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.9
	particles.randomness = 0.55
	particles.direction = direction.normalized()
	particles.spread = 145.0
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max
	particles.gravity = Vector2(0, 70)
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.95
	particles.color = tint
	particles.texture = _soft_texture()
	particles.z_index = 8
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.65),
		Color(1, 1, 1, 0.0),
	])
	particles.color_ramp = fade
	parent.add_child(particles)
	particles.global_position = world_position
	particles.emitting = true
	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = lifetime + 0.35
	cleanup.autostart = true
	cleanup.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)
	particles.add_child(cleanup)
	return particles
