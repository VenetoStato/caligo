extends RefCounted


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
	particles.scale_amount_min = 1.4
	particles.scale_amount_max = 3.8
	particles.color = tint
	particles.z_index = 8
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
