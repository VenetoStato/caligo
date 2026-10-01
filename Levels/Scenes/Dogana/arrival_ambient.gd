extends Node2D
## Burst all'attracco: stormo leggero dalle bricole + una figura che si nasconde.


func play_arrival_burst(origin: Vector2 = Vector2(80, 420)) -> void:
	_spawn_takeoff_flock(origin)
	_spawn_hiding_figure(origin + Vector2(200, 10))


func play_landing_effect(origin: Vector2) -> void:
	_spawn_landing_dust(origin)
	_spawn_landing_afterimage(origin)
	_spawn_landing_ring(origin)


func _spawn_landing_dust(origin: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.name = "ArrivalLandingDust"
	particles.z_index = 7
	particles.one_shot = true
	particles.amount = 14 if not OS.has_feature("mobile") else 8
	particles.lifetime = 0.72
	particles.explosiveness = 0.94
	particles.randomness = 0.72
	particles.direction = Vector2.UP
	particles.spread = 132.0
	particles.gravity = Vector2(0, 78)
	particles.initial_velocity_min = 34.0
	particles.initial_velocity_max = 108.0
	particles.damping_min = 8.0
	particles.damping_max = 24.0
	# 40 px di texture: scala sub-unitaria per granelli da 5-22 px, non bolle giganti.
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.55
	particles.color = Color(0.62, 0.77, 0.75, 0.62)
	particles.texture = _make_soft_disc()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.16, 0.62, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.9),
		Color(1, 1, 1, 0.34), Color(1, 1, 1, 0),
	])
	particles.color_ramp = fade
	add_child(particles)
	particles.global_position = origin + Vector2(0, 3)
	particles.emitting = true
	get_tree().create_timer(1.1).timeout.connect(particles.queue_free)


func _spawn_landing_afterimage(origin: Vector2) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var source := player.get_node_or_null("Sprite2D") as Sprite2D if player else null
	if source == null or source.texture == null:
		return
	for index in 3:
		var ghost := Sprite2D.new()
		ghost.z_index = 5
		ghost.texture = source.texture
		ghost.hframes = source.hframes
		ghost.vframes = source.vframes
		ghost.frame = source.frame
		ghost.flip_h = source.flip_h
		ghost.scale = source.scale
		ghost.position = origin + source.position + Vector2(-7.0 - index * 5.0, -2.0 - index * 2.5)
		ghost.modulate = Color(0.25, 0.62, 0.62, 0.15 - index * 0.03)
		add_child(ghost)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(ghost, "position", ghost.position + Vector2(-14, -5), 0.34 + index * 0.06)
		tween.tween_property(ghost, "modulate:a", 0.0, 0.28 + index * 0.06)
		tween.chain().tween_callback(ghost.queue_free)


func _spawn_landing_ring(origin: Vector2) -> void:
	var ring := _LandingRing.new()
	ring.z_index = 6
	ring.position = origin + Vector2(0, 3)
	add_child(ring)
	ring.play()


func _make_soft_disc() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.86), Color(1, 1, 1, 0.36),
		Color(1, 1, 1, 0.08), Color(1, 1, 1, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 40
	texture.height = 40
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _spawn_takeoff_flock(origin: Vector2) -> void:
	for index in 8:
		var bird := _FlightBird.new()
		bird.name = "TakeoffBird_%d" % index
		bird.z_index = 7
		var tint := Color(0.9, 0.9, 0.88, 0.95) if index % 3 == 0 else Color(0.78, 0.8, 0.76, 0.95)
		bird.setup(randf_range(0.9, 1.2), tint, index % 4 == 0)
		var roost := origin + Vector2(
			randf_range(-20.0, 120.0) + float(index % 4) * 16.0,
			randf_range(6.0, 28.0)
		)
		bird.position = roost
		add_child(bird)
		var delay := 0.05 + float(index) * 0.06
		var end := roost + Vector2(randf_range(180.0, 420.0), randf_range(-240.0, -130.0))
		var mid := roost.lerp(end, 0.45) + Vector2(0.0, randf_range(-50.0, -15.0))
		_animate_arc_flight(bird, roost, mid, end, delay, randf_range(1.7, 2.5), randf_range(1.5, 2.2))


func _animate_arc_flight(
	bird: Node2D,
	start: Vector2,
	mid: Vector2,
	end: Vector2,
	delay: float,
	fly_time: float,
	fade_time: float
) -> void:
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(bird.set.bind("flapping", true))
	tween.tween_method(_arc_sample.bind(bird, start, mid, end), 0.0, 1.0, fly_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bird, "modulate:a", 0.0, fade_time).set_delay(0.45)
	tween.tween_callback(bird.queue_free)


func _arc_sample(progress: float, bird: Node2D, start: Vector2, mid: Vector2, end: Vector2) -> void:
	if bird == null or not is_instance_valid(bird):
		return
	var a := (1.0 - progress) * (1.0 - progress)
	var b := 2.0 * (1.0 - progress) * progress
	var c := progress * progress
	bird.position = start * a + mid * b + end * c


func _spawn_hiding_figure(near: Vector2) -> void:
	var figure := _HidingSilhouette.new()
	figure.z_index = 5
	figure.position = near
	figure.modulate.a = 0.0
	add_child(figure)
	var hide_x := near.x + 80.0
	var tween := create_tween()
	tween.tween_property(figure, "modulate:a", 0.88, 0.3)
	tween.tween_interval(0.28)
	tween.tween_property(figure, "position:x", hide_x, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(figure, "modulate:a", 0.0, 0.7)
	tween.tween_callback(figure.queue_free)


class _FlightBird extends Node2D:
	var _time := 0.0
	var _phase := 0.0
	var flapping := false
	var _size := 1.0
	var _tint := Color(0.8, 0.8, 0.78, 0.95)
	var _gull := false

	func setup(size_mul: float, tint: Color, gull: bool) -> void:
		_size = size_mul
		_tint = tint
		_gull = gull
		_phase = randf() * TAU

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var flap := 1.0
		if flapping:
			flap = 0.55 + absf(sin(_time * (16.0 if not _gull else 11.0) + _phase))
		var wing := (6.5 if _gull else 5.0) * _size * flap
		var body_r := (2.8 if _gull else 2.2) * _size
		draw_circle(Vector2.ZERO, body_r, _tint)
		draw_circle(Vector2(body_r * 0.9, -0.6 * _size), body_r * 0.45, _tint)
		var left := PackedVector2Array([
			Vector2(0, 0),
			Vector2(-wing, -wing * 0.55),
			Vector2(-wing * 0.35, 0.5),
		])
		var right := PackedVector2Array([
			Vector2(0, 0),
			Vector2(wing, -wing * 0.55),
			Vector2(wing * 0.35, 0.5),
		])
		var wing_col := Color(_tint.r, _tint.g, _tint.b, _tint.a * 0.9)
		draw_colored_polygon(left, wing_col)
		draw_colored_polygon(right, wing_col)


class _HidingSilhouette extends Node2D:
	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var cloak := Color(0.05, 0.08, 0.1, 0.9)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-8, 18), Vector2(-6, -10), Vector2(0, -22),
				Vector2(6, -10), Vector2(8, 18),
			]),
			cloak
		)
		draw_circle(Vector2(0, -16), 5.5, cloak)


class _LandingRing extends Node2D:
	var _progress := 0.0

	func play() -> void:
		var tween := create_tween()
		tween.tween_method(_set_progress, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(queue_free)

	func _set_progress(value: float) -> void:
		_progress = value
		queue_redraw()

	func _draw() -> void:
		var width := lerpf(10.0, 72.0, _progress)
		var alpha := (1.0 - _progress) * 0.48
		draw_arc(Vector2.ZERO, width, PI + 0.18, TAU - 0.18, 28, Color(0.56, 0.82, 0.78, alpha), lerpf(3.2, 0.8, _progress), true)
