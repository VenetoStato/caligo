extends RefCounted
## FX leggeri per Dogana: CPUParticles, budget ridotto su Android.

const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")
const RING_SCRIPT := preload("res://Levels/Scenes/Dogana/dogana_ring_flash.gd")


static func is_mobile() -> bool:
	return OS.get_name() == "Android" or OS.has_feature("mobile")


static func budget(amount: int) -> int:
	if is_mobile():
		return maxi(3, amount / 2)
	return amount


static func burst(
	parent: Node,
	world_position: Vector2,
	tint: Color,
	amount := 14,
	direction := Vector2.UP,
	speed_min := 28.0,
	speed_max := 95.0,
	lifetime := 0.7
) -> void:
	PARTICLE_BURST.spawn(
		parent,
		world_position,
		tint,
		budget(amount),
		direction,
		speed_min,
		speed_max,
		lifetime
	)


static func make_soft_aura(parent: Node, local_position: Vector2, tint: Color, amount := 8) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "SoftAura"
	particles.position = local_position
	particles.amount = budget(amount)
	particles.lifetime = 1.4
	particles.preprocess = 0.35
	particles.emitting = false
	particles.one_shot = false
	particles.explosiveness = 0.05
	particles.randomness = 0.7
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 18.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, -12)
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 18.0
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.75
	particles.color = tint
	particles.z_index = 4
	# Texture radiale: evita i quadretti bianchi/blu del default CPUParticles.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.35),
		Color(1, 1, 1, 0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	particles.texture = tex
	parent.add_child(particles)
	return particles


static func pulse_ring(parent: Node, world_position: Vector2, tint: Color) -> void:
	if parent == null:
		return
	var ring := Node2D.new()
	ring.set_script(RING_SCRIPT)
	parent.add_child(ring)
	ring.global_position = world_position
	ring.call("play", tint, is_mobile())
