extends Node2D

var _age := 0.0
var _lifetime := 0.42
var _strength := 1.0
var _color := Color(0.72, 0.92, 0.96, 0.42)
var _phase := 0.0


func setup(color: Color, strength: float = 1.0) -> void:
	_color = Color(color.r, color.g, color.b, minf(color.a, 0.42))
	_strength = clampf(strength, 0.35, 1.8)
	_phase = randf_range(-0.09, 0.09)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= _lifetime:
		queue_free()


func _draw() -> void:
	var progress := clampf(_age / _lifetime, 0.0, 1.0)
	var alpha := pow(1.0 - progress, 1.75)
	var radius := lerpf(2.0, 18.0 * _strength, progress)
	var line_color := Color(_color.r, _color.g, _color.b, _color.a * alpha)
	var radius_y := maxf(0.7, radius * 0.11)
	# Two irregular fragments read as a disturbance in the water, rather than
	# a clean UI ellipse stamped onto the scene.
	_draw_ellipse_arc(radius, radius_y, PI * (1.03 + _phase), PI * 1.39, line_color, 0.85)
	_draw_ellipse_arc(radius, radius_y, PI * 1.61, PI * (1.96 + _phase), line_color, 0.85)
	if progress < 0.48:
		var side_color := Color(line_color.r, line_color.g, line_color.b, line_color.a * 0.38)
		_draw_ellipse_arc(radius * 0.7, radius_y * 0.8, PI * 0.08, PI * 0.37, side_color, 0.7)
	var crown := maxf(0.0, 1.0 - progress * 2.8)
	if crown > 0.0:
		draw_line(Vector2(-1.8, 0.0), Vector2(0.0, -3.4 * crown * _strength), line_color, 0.75)
		draw_line(Vector2(0.0, -3.4 * crown * _strength), Vector2(1.8, 0.0), line_color, 0.75)


func _draw_ellipse_arc(
	radius_x: float,
	radius_y: float,
	start_angle: float,
	end_angle: float,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()
	for index in 11:
		var angle := lerpf(start_angle, end_angle, float(index) / 10.0)
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_polyline(points, color, width, true)
