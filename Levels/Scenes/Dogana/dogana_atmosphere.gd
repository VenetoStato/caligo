extends Node2D

var _time := 0.0
var _redraw_accumulator := 0.0


func _ready() -> void:
	z_index = -8
	_build_ambient_particles()


func _process(delta: float) -> void:
	_time += delta
	_redraw_accumulator += delta
	if _redraw_accumulator >= 1.0 / 24.0:
		_redraw_accumulator = 0.0
		queue_redraw()


func _draw() -> void:
	_draw_fog_banks()
	_draw_lagoon_motes()
	_draw_distant_gulls()


func _draw_fog_banks() -> void:
	for bank in 8:
		var points := PackedVector2Array()
		var base_y := 260.0 + bank * 52.0
		var drift := fmod(_time * (5.0 + bank), 460.0)
		for sample in 28:
			var x := -320.0 + sample * 210.0 + drift
			var y := base_y + sin(sample * 0.63 + bank * 1.7 + _time * 0.18) * (13.0 + bank * 1.5)
			points.append(Vector2(x, y))
		var alpha := 0.026 + bank * 0.004
		draw_polyline(points, Color(0.66, 0.81, 0.82, alpha), 24.0 + bank * 5.0, true)


func _draw_lagoon_motes() -> void:
	for index in 34:
		var seed := float(index * 149)
		var x := fmod(seed * 13.17 + _time * (2.0 + index % 4), 5120.0)
		var y := 80.0 + fmod(seed * 5.71, 760.0)
		var pulse := (sin(_time * 1.2 + index * 0.77) + 1.0) * 0.5
		draw_circle(Vector2(x, y), 0.8 + pulse * 1.4, Color(0.32, 0.88, 0.78, 0.08 + pulse * 0.12))


func _draw_distant_gulls() -> void:
	for index in 7:
		var center := Vector2(430.0 + index * 690.0, 130.0 + (index % 3) * 42.0)
		var wing := 5.0 + sin(_time * 2.0 + index) * 2.0
		var color := Color(0.68, 0.75, 0.75, 0.22)
		draw_arc(center + Vector2(-wing, 0), wing, PI * 1.15, PI * 1.88, 7, color, 1.2, true)
		draw_arc(center + Vector2(wing, 0), wing, PI * 1.12, PI * 1.85, 7, color, 1.2, true)


func _build_ambient_particles() -> void:
	var soft_dot := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.44, 0.9, 0.82, 0.0),
		Color(0.44, 0.9, 0.82, 0.72),
		Color(0.44, 0.9, 0.82, 0.0),
	])
	soft_dot.gradient = gradient
	soft_dot.width = 24
	soft_dot.height = 24
	soft_dot.fill = GradientTexture2D.FILL_RADIAL
	soft_dot.fill_from = Vector2(0.5, 0.5)
	soft_dot.fill_to = Vector2(1.0, 0.5)

	var particles := CPUParticles2D.new()
	particles.name = "LagoonDrift"
	particles.texture = soft_dot
	particles.position = Vector2(3000, 390)
	particles.amount = 34 if OS.get_name() == "Android" else 68
	particles.lifetime = 9.0
	particles.preprocess = 9.0
	particles.randomness = 0.88
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(3050, 430)
	particles.direction = Vector2(-0.25, -1.0)
	particles.spread = 58.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 12.0
	particles.gravity = Vector2(-2.0, -4.0)
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.24
	particles.color = Color(0.5, 0.92, 0.84, 0.28)
	particles.z_index = 1
	add_child(particles)
