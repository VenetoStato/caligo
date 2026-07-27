extends Node2D

## kind: -1 none, 0 lunge, 1 slam, 2 wave, 3 sweep
var _kind := -1
var _dir := Vector2.RIGHT
var _progress := 0.0


func set_preview(kind: int, direction: Vector2, progress: float) -> void:
	_kind = kind
	_dir = direction if direction.length_squared() > 0.01 else Vector2.RIGHT
	_progress = clampf(progress, 0.0, 1.0)
	visible = _kind >= 0
	queue_redraw()


func _draw() -> void:
	if _kind < 0:
		return
	match _kind:
		0: # LUNGE
			var tip := _dir * lerpf(40.0, 150.0, _progress)
			draw_line(Vector2(0, -40), tip + Vector2(0, -40), Color(0.45, 1.0, 0.86, 0.35 + _progress * 0.45), 3.0, true)
			draw_circle(tip + Vector2(0, -40), 8.0 + _progress * 6.0, Color(0.45, 1.0, 0.86, 0.25 + _progress * 0.4))
		1: # SLAM
			var radius := lerpf(28.0, 96.0, _progress)
			draw_arc(Vector2(0, 8), radius, 0.0, TAU, 48, Color(0.95, 0.45, 0.32, 0.35 + _progress * 0.5), 3.0, true)
			draw_circle(Vector2(0, 8), radius * 0.35, Color(0.95, 0.45, 0.32, 0.08 + _progress * 0.1))
		2: # WAVE
			for i in 3:
				var ang := (-0.22 + 0.22 * float(i))
				var tip2 := _dir.rotated(ang) * lerpf(50.0, 170.0, _progress)
				draw_line(Vector2(0, -70), tip2 + Vector2(0, -70), Color(0.4, 0.9, 1.0, 0.28 + _progress * 0.45), 2.2, true)
		3: # SWEEP
			var sweep_dir := signf(_dir.x) if absf(_dir.x) > 0.01 else 1.0
			var width := lerpf(60.0, 150.0, _progress)
			var rect := Rect2(minf(0.0, sweep_dir * width), -110.0, absf(width), 90.0)
			draw_rect(rect, Color(0.95, 0.75, 0.35, 0.12 + _progress * 0.18), true)
			draw_rect(rect, Color(0.95, 0.75, 0.35, 0.4 + _progress * 0.4), false, 2.0)
