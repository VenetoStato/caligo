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
	_draw_attack_name()
	match _kind:
		0: # LUNGE
			_draw_melee_zone(176.0, 78.0, Color(1.0, 0.32, 0.18, 1.0))
		1: # SLAM
			var radius := lerpf(28.0, 96.0, _progress)
			draw_circle(Vector2(0, 0), radius, Color(1.0, 0.22, 0.12, 0.07 + _progress * 0.12))
			draw_arc(Vector2(0, 0), radius, 0.0, TAU, 48, Color(1.0, 0.36, 0.2, 0.42 + _progress * 0.5), 3.0, true)
			_draw_countdown_ticks(Vector2(0, 0), radius)
		2: # WAVE
			# Tre parabole discrete: anticipano esattamente le piastrelle senza
			# coprire il pavimento con un laser vistoso.
			for i in 3:
				var spread := (float(i) - 1.0) * 0.16
				var tip2 := _dir.rotated(spread) * lerpf(52.0, 188.0, _progress)
				var midpoint := Vector2(0, -70).lerp(tip2 + Vector2(0, -70), 0.5) + Vector2(0, -34.0 * _progress)
				draw_arc(midpoint, midpoint.distance_to(Vector2(0, -70)), PI * 0.12, PI * 0.88, 16, Color(0.58, 0.78, 0.68, 0.2 + _progress * 0.42), 1.7, true)
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
			var crest := PackedVector2Array()
			for point_index in 15:
				var t := float(point_index) / 14.0
				crest.append(Vector2(lerpf(-half_width, half_width, t), top + sin(t * 17.0) * 3.0))
			draw_polyline(crest, Color(0.35, 0.86, 0.94, 0.45 + _progress * 0.45), 3.0, true)


func _draw_attack_name() -> void:
	var names := {
		0: "AFFONDO",
		1: "SCHIANTO",
		2: "PIASTRELLE",
		10: "MAREA",
	}
	var attack_name := str(names.get(_kind, ""))
	if attack_name.is_empty():
		return
	var alpha := 0.38 + _progress * 0.45
	var tint := Color(0.72, 0.94, 0.88, alpha)
	if _kind == 1:
		tint = Color(1.0, 0.66, 0.42, alpha)
	elif _kind == 10:
		tint = Color(0.5, 0.9, 1.0, alpha)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(attack_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(-width * 0.5, -152.0), attack_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint)


func _draw_melee_zone(width: float, height: float, tint: Color) -> void:
	var facing := signf(_dir.x) if absf(_dir.x) > 0.01 else 1.0
	# L'arco e' volutamente piu' stretto della vecchia versione e corrisponde
	# alla collisione (nessun danno oltre il bordo mostrato).
	var shown_width := lerpf(width * 0.32, width * 0.72, _progress)
	var center := Vector2(0.0, -36.0)
	var base_angle := 0.0 if facing > 0.0 else PI
	var half_angle := 0.54 if height < 90.0 else 0.68
	var pulse := 0.72 + sin(Time.get_ticks_msec() * 0.025) * 0.18
	var fill_alpha := 0.24 * pulse if _active else (0.07 + _progress * 0.12)
	var wedge := PackedVector2Array([center])
	for point_index in 13:
		var t := float(point_index) / 12.0
		var angle := base_angle + lerpf(-half_angle, half_angle, t)
		wedge.append(center + Vector2.from_angle(angle) * shown_width)
	draw_colored_polygon(wedge, Color(tint.r, tint.g, tint.b, fill_alpha))
	draw_arc(center, shown_width, base_angle - half_angle, base_angle + half_angle, 24, Color(tint.r, tint.g, tint.b, 0.96 if _active else 0.4 + _progress * 0.48), 3.4 if _active else 2.2, true)
	draw_arc(center, shown_width * 0.56, base_angle - half_angle, base_angle + half_angle, 18, Color(tint.r, tint.g, tint.b, 0.38 if _active else 0.18), 1.4, true)
	for ray_index in 4:
		var ray_t := (float(ray_index) + 1.0) / 5.0
		var ray_angle := base_angle + lerpf(-half_angle * 0.86, half_angle * 0.86, ray_t)
		var ray := Vector2.from_angle(ray_angle)
		draw_line(center + ray * 14.0, center + ray * shown_width, Color(tint.r, tint.g, tint.b, 0.22 if _active else 0.1), 1.15, true)


func _draw_countdown_ticks(center: Vector2, radius: float) -> void:
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var direction := Vector2.from_angle(angle)
		var enabled := float(index) / 8.0 <= _progress
		draw_line(center + direction * (radius - 9.0), center + direction * (radius + 5.0), Color(1.0, 0.5, 0.28, 0.88 if enabled else 0.18), 2.4, true)
