extends Node2D

var _age := 0.0
var _lifetime := 0.48
var _strength := 1.0
var _color := Color(0.72, 0.92, 0.96, 0.72)


func setup(color: Color, strength: float = 1.0) -> void:
	_color = color
	_strength = clampf(strength, 0.35, 1.8)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= _lifetime:
		queue_free()


func _draw() -> void:
	var progress := clampf(_age / _lifetime, 0.0, 1.0)
	var alpha := pow(1.0 - progress, 1.45)
	var radius := lerpf(2.0, 23.0 * _strength, progress)
	var line_color := Color(_color.r, _color.g, _color.b, _color.a * alpha)
	_draw_ellipse(radius, maxf(1.0, radius * 0.19), line_color, lerpf(2.0, 0.8, progress))
	if progress < 0.62:
		var second_progress := clampf(progress * 1.55, 0.0, 1.0)
		var second_radius := lerpf(1.0, 12.0 * _strength, second_progress)
		var second_color := Color(line_color.r, line_color.g, line_color.b, line_color.a * 0.55)
		_draw_ellipse(second_radius, maxf(0.7, second_radius * 0.17), second_color, 1.0)
	var crown := maxf(0.0, 1.0 - progress * 2.8)
	if crown > 0.0:
		draw_line(Vector2(-2.5, 0.0), Vector2(0.0, -5.0 * crown * _strength), line_color, 1.2)
		draw_line(Vector2(0.0, -5.0 * crown * _strength), Vector2(2.5, 0.0), line_color, 1.2)


func _draw_ellipse(radius_x: float, radius_y: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in 33:
		var angle := TAU * float(index) / 32.0
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_polyline(points, color, width, true)
