class_name FootstepDust
extends RefCounted
## Nuvoletta corta ai piedi: world-space, CPU e con budget mobile ridotto.


static func spawn(parent: Node, origin: Vector2, travel_direction: float, mobile: bool) -> void:
	if parent == null:
		return
	var holder := Node2D.new()
	holder.name = "FootstepDust"
	holder.z_index = 7
	parent.add_child(holder)
	holder.global_position = origin

	# Una nuvoletta si legge solo se ha corpo: dischi ampi e morbidi che salgono
	# appena e svaniscono. Con scale sotto 0.5 il disco resta di pochi pixel e a
	# schermo non arriva niente.
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = 4 if mobile else 8
	particles.lifetime = 0.72
	particles.explosiveness = 0.82
	particles.randomness = 0.82
	particles.lifetime_randomness = 0.3
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 7.0
	particles.direction = Vector2(-signf(travel_direction), -0.42).normalized()
	particles.spread = 42.0
	particles.gravity = Vector2(0, -14.0)
	particles.initial_velocity_min = 16.0
	particles.initial_velocity_max = 44.0
	particles.damping_min = 26.0
	particles.damping_max = 54.0
	particles.scale_amount_min = 0.55
	particles.scale_amount_max = 1.35
	particles.scale_amount_curve = _make_growth_curve()
	particles.color = Color(0.62, 0.78, 0.76, 0.5)
	particles.texture = _make_soft_disc()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.14, 0.55, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.9),
		Color(1, 1, 1, 0.4), Color(1, 1, 1, 0),
	])
	particles.color_ramp = fade
	holder.add_child(particles)
	particles.restart()
	particles.emitting = true
	holder.get_tree().create_timer(1.0).timeout.connect(holder.queue_free)


## La nuvoletta si apre mentre sale: parte compatta e si allarga sfumando.
static func _make_growth_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.45))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1.0, 0.75))
	return curve


static func _make_soft_disc() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.46, 0.82, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.78), Color(1, 1, 1, 0.3),
		Color(1, 1, 1, 0.06), Color(1, 1, 1, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 28
	texture.height = 28
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
