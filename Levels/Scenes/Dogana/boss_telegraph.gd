extends Node2D

## kind: -1 none, 0 lunge, 1 slam, 2 wave, 3 sweep, 4 spiral, 5 ring, 6 stream, 7 cross, 8 fan, 9 pillars
var _kind := -1
var _dir := Vector2.RIGHT
var _progress := 0.0
var _active := false


func set_preview(kind: int, direction: Vector2, progress: float, active := false) -> void:
	_kind = kind
	_dir = direction if direction.length_squared() > 0.01 else Vector2.RIGHT
	_progress = clampf(progress, 0.0, 1.0)
	_active = active
	visible = _kind >= 0
	queue_redraw()


func _draw() -> void:
	if _kind < 0:
		return
	match _kind:
		0: # LUNGE
			_draw_melee_zone(176.0, 78.0, Color(1.0, 0.32, 0.18, 1.0))
		1: # SLAM
			var radius := lerpf(28.0, 96.0, _progress)
			draw_circle(Vector2(0, 0), radius, Color(1.0, 0.22, 0.12, 0.07 + _progress * 0.12))
			draw_arc(Vector2(0, 0), radius, 0.0, TAU, 48, Color(1.0, 0.36, 0.2, 0.42 + _progress * 0.5), 3.0, true)
			_draw_countdown_ticks(Vector2(0, 0), radius)
		2: # WAVE
			for i in 3:
				var ang := (-0.22 + 0.22 * float(i))
				var tip2 := _dir.rotated(ang) * lerpf(50.0, 170.0, _progress)
				draw_line(Vector2(0, -70), tip2 + Vector2(0, -70), Color(0.4, 0.9, 1.0, 0.28 + _progress * 0.45), 2.2, true)
		3: # SWEEP
			_draw_melee_zone(164.0, 94.0, Color(1.0, 0.62, 0.16, 1.0))
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
		8: # FAN
			for ray in 5:
				var spread := (float(ray) - 2.0) * 0.14
				var tip6 := _dir.rotated(spread) * lerpf(55.0, 180.0, _progress)
				draw_line(Vector2(0, -65), tip6 + Vector2(0, -65), Color(0.38, 0.86, 1.0, 0.28 + _progress * 0.48), 2.0, true)
		9: # PILLARS
			for pillar in 5:
				var x := (float(pillar) - 2.0) * 42.0
				var height := lerpf(18.0, 96.0, _progress)
				draw_rect(Rect2(x - 10.0, 8.0 - height, 20.0, height), Color(0.72, 0.32, 0.95, 0.1 + _progress * 0.2), true)
				draw_line(Vector2(x, 8.0), Vector2(x, 8.0 - height), Color(0.86, 0.48, 1.0, 0.4 + _progress * 0.45), 2.4, true)
		10: # FLOOD
			var half_width := lerpf(90.0, 520.0, _progress)
			var top := lerpf(34.0, -150.0, _progress)
			var flood_rect := Rect2(-half_width, top, half_width * 2.0, 158.0 - top)
			draw_rect(flood_rect, Color(0.16, 0.58, 1.0, 0.06 + _progress * 0.12), true)
			draw_line(Vector2(-half_width, top), Vector2(half_width, top), Color(0.35, 0.78, 1.0, 0.45 + _progress * 0.45), 4.0, true)


func _draw_melee_zone(width: float, height: float, tint: Color) -> void:
	var facing := signf(_dir.x) if absf(_dir.x) > 0.01 else 1.0
	var shown_width := lerpf(width * 0.32, width, _progress)
	var left := 12.0 if facing > 0.0 else -12.0 - shown_width
	var rect := Rect2(left, -height, shown_width, height + 8.0)
	var pulse := 0.72 + sin(Time.get_ticks_msec() * 0.025) * 0.18
	var fill_alpha := 0.24 * pulse if _active else (0.07 + _progress * 0.12)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, fill_alpha), true)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, 0.95 if _active else 0.4 + _progress * 0.48), false, 3.5 if _active else 2.2)
	var stripe_x := rect.position.x + 12.0 if facing > 0.0 else rect.end.x - 12.0
	while (stripe_x < rect.end.x if facing > 0.0 else stripe_x > rect.position.x):
		draw_line(Vector2(stripe_x, rect.position.y), Vector2(stripe_x + 28.0 * facing, rect.end.y), Color(tint.r, tint.g, tint.b, 0.28 if _active else 0.13), 1.4, true)
		stripe_x += 32.0 * facing


func _draw_countdown_ticks(center: Vector2, radius: float) -> void:
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var direction := Vector2.from_angle(angle)
		var enabled := float(index) / 8.0 <= _progress
		draw_line(center + direction * (radius - 9.0), center + direction * (radius + 5.0), Color(1.0, 0.5, 0.28, 0.88 if enabled else 0.18), 2.4, true)
