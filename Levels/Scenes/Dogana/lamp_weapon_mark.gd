extends Node2D

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.72 + sin(_time * 3.2) * 0.18
	var tint := Color(0.74, 0.94, 0.82, pulse)
	draw_arc(Vector2.ZERO, 36.0, 0.18, PI - 0.18, 28, tint, 2.0, true)
	draw_line(Vector2(-26, -25), Vector2(-34, -34), tint, 2.0, true)
	draw_line(Vector2(26, -25), Vector2(34, -34), tint, 2.0, true)
	draw_circle(Vector2.ZERO, 4.0, Color(0.92, 0.76, 0.36, pulse))
