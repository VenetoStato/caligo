extends Node2D
## Burst all'attracco: stormo leggero dalle bricole + una figura che si nasconde.


func play_arrival_burst(origin: Vector2 = Vector2(80, 420)) -> void:
	_spawn_takeoff_flock(origin)
	_spawn_hiding_figure(origin + Vector2(200, 10))


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
