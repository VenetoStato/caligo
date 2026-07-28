extends Node2D

## kind: -1 none, 0 lunge, 1 slam, 2 wave, 3 sweep, 4 spiral, 5 ring, 6 stream, 7 cross
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
		4: # SPIRAL
			for arm in 4:
				var ang := _progress * TAU * 1.4 + TAU * float(arm) / 4.0
				var tip3 := Vector2.from_angle(ang) * lerpf(30.0, 120.0, _progress)
				draw_line(Vector2(0, -60), tip3 + Vector2(0, -60), Color(0.55, 0.75, 1.0, 0.3 + _progress * 0.45), 2.0, true)
			draw_arc(Vector2(0, -60), lerpf(20.0, 70.0, _progress), 0.0, TAU * _progress, 40, Color(0.55, 0.75, 1.0, 0.35), 2.0, true)
		5: # RING
			var r := lerpf(24.0, 110.0, _progress)
			draw_arc(Vector2(0, -40), r, 0.0, TAU, 56, Color(0.35, 0.95, 0.85, 0.35 + _progress * 0.45), 2.6, true)
			draw_arc(Vector2(0, -40), r * 0.55, 0.0, TAU, 40, Color(0.35, 0.95, 0.85, 0.18), 1.6, true)
		6: # STREAM
			for i in 5:
				var tip4 := _dir * lerpf(40.0 + float(i) * 18.0, 80.0 + float(i) * 28.0, _progress)
				draw_circle(tip4 + Vector2(0, -70), 4.0 + _progress * 2.0, Color(0.4, 1.0, 0.9, 0.2 + _progress * 0.35))
			draw_line(Vector2(0, -70), _dir * lerpf(50.0, 180.0, _progress) + Vector2(0, -70), Color(0.4, 1.0, 0.9, 0.35 + _progress * 0.4), 2.4, true)
		7: # CROSS
			for ang_i in 4:
				var ang2 := float(ang_i) * PI * 0.5 + _progress * 0.35
				var tip5 := Vector2.from_angle(ang2) * lerpf(40.0, 130.0, _progress)
				draw_line(Vector2(0, -55), tip5 + Vector2(0, -55), Color(0.95, 0.7, 0.35, 0.3 + _progress * 0.45), 2.2, true)
