extends Control

var _time := 0.0
var _redraw_accumulator := 0.0
var _regions: Dictionary = {"arrival": true}
var _player_world_position := Vector2(330, 425)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_redraw_accumulator += delta
	if _redraw_accumulator >= 0.1:
		_redraw_accumulator = 0.0
		queue_redraw()


func set_map_state(regions: Dictionary, player_world_position: Vector2) -> void:
	_regions = regions.duplicate()
	_player_world_position = player_world_position
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.055, 0.066, 0.064, 1.0), true)
	draw_rect(Rect2(10, 10, size.x - 20, size.y - 20), Color(0.12, 0.125, 0.11, 1.0), true)
	draw_rect(Rect2(15, 15, size.x - 30, size.y - 30), Color(0.57, 0.5, 0.34, 0.48), false, 2.0)
	_draw_paper_texture()
	_draw_water_channels()
	_draw_main_regions()
	_draw_secret_regions()
	_draw_route()
	_draw_landmarks()
	_draw_compass()
	_draw_player_marker()


func _draw_paper_texture() -> void:
	for index in 26:
		var y := 24.0 + index * 18.0
		var wave := PackedVector2Array()
		for sample in 18:
			wave.append(Vector2(20.0 + sample * 54.0, y + sin(sample * 0.81 + index) * 1.8))
		draw_polyline(wave, Color(0.72, 0.66, 0.48, 0.025), 1.0, true)


func _draw_water_channels() -> void:
	var upper := PackedVector2Array([
		_p(0.03, 0.28), _p(0.25, 0.36), _p(0.48, 0.28), _p(0.72, 0.37), _p(0.97, 0.22),
		_p(0.97, 0.04), _p(0.03, 0.04),
	])
	var lower := PackedVector2Array([
		_p(0.03, 0.74), _p(0.24, 0.71), _p(0.46, 0.76), _p(0.68, 0.66), _p(0.97, 0.72),
		_p(0.97, 0.96), _p(0.03, 0.96),
	])
	draw_polygon(upper, PackedColorArray([Color(0.035, 0.12, 0.135, 0.78)]))
	draw_polygon(lower, PackedColorArray([Color(0.025, 0.105, 0.12, 0.82)]))
	for offset in 5:
		var y := size.y * (0.79 + offset * 0.025)
		draw_arc(Vector2(size.x * 0.52, y), size.x * (0.18 + offset * 0.07), PI * 1.08, PI * 1.9, 48, Color(0.32, 0.58, 0.56, 0.06), 1.0, true)


func _draw_main_regions() -> void:
	_draw_room("arrival", Rect2(_p(0.06, 0.57), size * Vector2(0.19, 0.14)), "PONTILE")
	var customs := PackedVector2Array([
		_p(0.25, 0.57), _p(0.42, 0.42), _p(0.59, 0.57), _p(0.55, 0.66), _p(0.29, 0.66),
	])
	_draw_polygon_room("customs", customs, "DOGANA DA MAR", _p(0.355, 0.58))
	var palace := Rect2(_p(0.37, 0.08), size * Vector2(0.19, 0.31))
	_draw_room("palace", palace, "PALAZZO DEI TRIBUTI")
	for step in 6:
		var y := 0.345 - step * 0.042
		var x := 0.385 if step % 2 == 0 else 0.455
		var rect := Rect2(_p(x, y), size * Vector2(0.085, 0.018))
		draw_rect(rect, _room_fill("palace"), true)
		draw_rect(rect, _room_edge("palace"), false, 1.1)
	_draw_room("canal", Rect2(_p(0.59, 0.48), size * Vector2(0.18, 0.12)), "CANALE")
	_draw_room("fortuna", Rect2(_p(0.74, 0.29), size * Vector2(0.12, 0.27)), "FORTUNA")
	_draw_room("salute", Rect2(_p(0.86, 0.34), size * Vector2(0.11, 0.28)), "SALUTE")
	# Cupola semplificata sulla mappa.
	if bool(_regions.get("salute", false)):
		draw_arc(_p(0.915, 0.4), 18.0, PI, TAU, 20, Color(0.72, 0.62, 0.4, 0.7), 2.4, true)
	for step in 4:
		var rect := Rect2(_p(0.69 + step * 0.035, 0.49 - step * 0.055), size * Vector2(0.05, 0.035))
		draw_rect(rect, _room_fill("canal"), true)
		draw_rect(rect, _room_edge("canal"), false, 1.4)


func _draw_secret_regions() -> void:
	if bool(_regions.get("archive", false)):
		var archive := Rect2(_p(0.2, 0.77), size * Vector2(0.25, 0.11))
		_draw_room("archive", archive, "ARCHIVIO SOMMERSO")
		_draw_dashed_connection(_p(0.42, 0.66), _p(0.42, 0.78))
	if bool(_regions.get("ossuary", false)):
		var ossuary := Rect2(_p(0.68, 0.17), size * Vector2(0.18, 0.09))
		_draw_room("ossuary", ossuary, "OSSARIO")
		_draw_dashed_connection(_p(0.8, 0.29), _p(0.8, 0.25))
	if bool(_regions.get("palace_vault", false)):
		var vault := Rect2(_p(0.22, 0.12), size * Vector2(0.13, 0.09))
		_draw_room("palace_vault", vault, "CAVEAU")
		_draw_dashed_connection(_p(0.37, 0.17), _p(0.35, 0.17))


func _draw_route() -> void:
	var route := PackedVector2Array([_p(0.09, 0.64), _p(0.25, 0.61), _p(0.42, 0.49), _p(0.59, 0.55), _p(0.69, 0.52), _p(0.78, 0.44), _p(0.86, 0.42), _p(0.92, 0.48)])
	for index in route.size() - 1:
		var region_id: String = ["arrival", "customs", "customs", "canal", "canal", "fortuna", "salute"][index]
		if bool(_regions.get(region_id, false)):
			draw_line(route[index], route[index + 1], Color(0.78, 0.65, 0.36, 0.62), 2.4, true)
	if bool(_regions.get("palace", false)):
		var ascent := PackedVector2Array([
			_p(0.42, 0.49), _p(0.4, 0.36), _p(0.5, 0.31), _p(0.4, 0.25),
			_p(0.5, 0.19), _p(0.44, 0.1),
		])
		draw_polyline(ascent, Color(0.33, 0.82, 0.7, 0.64), 2.2, true)


func _draw_landmarks() -> void:
	if bool(_regions.get("arrival", false)):
		var dome := _p(0.14, 0.48)
		draw_arc(dome, 24.0, PI, TAU, 24, Color(0.64, 0.58, 0.41, 0.75), 3.0, true)
		draw_line(dome + Vector2(0, -24), dome + Vector2(0, -42), Color(0.64, 0.58, 0.41, 0.75), 2.0)
	if bool(_regions.get("fortuna", false)):
		var tower := _p(0.865, 0.27)
		draw_line(tower, tower + Vector2(0, -72), Color(0.67, 0.58, 0.34, 0.85), 8.0, true)
		draw_circle(tower + Vector2(0, -82), 12.0, Color(0.71, 0.58, 0.25, 0.86))


func _draw_compass() -> void:
	var center := _p(0.93, 0.84)
	draw_arc(center, 30.0, 0, TAU, 32, Color(0.64, 0.58, 0.42, 0.42), 1.2, true)
	draw_polygon(PackedVector2Array([center + Vector2(0, -30), center + Vector2(-6, 4), center, center + Vector2(6, 4)]), PackedColorArray([Color(0.78, 0.67, 0.4, 0.72)]))
	draw_line(center + Vector2(-24, 0), center + Vector2(24, 0), Color(0.64, 0.58, 0.42, 0.35), 1.0)


func _draw_player_marker() -> void:
	var position: Vector2
	if _player_world_position.y < -100.0 and _player_world_position.x > 2000.0 and _player_world_position.x < 3340.0:
		var palace_x := clampf((_player_world_position.x - 2020.0) / 1300.0, 0.0, 1.0)
		var palace_y := clampf((_player_world_position.y + 1160.0) / 1060.0, 0.0, 1.0)
		position = Vector2(
			lerpf(size.x * 0.385, size.x * 0.545, palace_x),
			lerpf(size.y * 0.1, size.y * 0.38, palace_y)
		)
	else:
		var normalized_x := clampf(_player_world_position.x / 6000.0, 0.0, 1.0)
		var normalized_y := clampf((_player_world_position.y + 180.0) / 1100.0, 0.0, 1.0)
		position = Vector2(
			lerpf(size.x * 0.075, size.x * 0.91, normalized_x),
			lerpf(size.y * 0.2, size.y * 0.86, normalized_y)
		)
	var pulse := 7.0 + sin(_time * 4.0) * 1.6
	draw_circle(position, pulse + 5.0, Color(0.2, 0.9, 0.76, 0.13))
	draw_circle(position, pulse, Color(0.28, 0.92, 0.78, 0.92))
	draw_circle(position, 2.5, Color(0.93, 0.82, 0.48, 1.0))


func _draw_room(region_id: String, rect: Rect2, label: String) -> void:
	var discovered := bool(_regions.get(region_id, false))
	draw_rect(rect, _room_fill(region_id), true)
	draw_rect(rect, _room_edge(region_id), false, 2.0 if discovered else 1.0)
	if discovered:
		_draw_label(label, rect.position + Vector2(10, rect.size.y - 10))


func _draw_polygon_room(region_id: String, polygon: PackedVector2Array, label: String, label_position: Vector2) -> void:
	draw_polygon(polygon, PackedColorArray([_room_fill(region_id)]))
	draw_polyline(polygon, _room_edge(region_id), 2.0 if bool(_regions.get(region_id, false)) else 1.0, true)
	if bool(_regions.get(region_id, false)):
		_draw_label(label, label_position)


func _room_fill(region_id: String) -> Color:
	return Color(0.19, 0.24, 0.22, 0.96) if bool(_regions.get(region_id, false)) else Color(0.075, 0.085, 0.08, 0.72)


func _room_edge(region_id: String) -> Color:
	return Color(0.7, 0.62, 0.42, 0.82) if bool(_regions.get(region_id, false)) else Color(0.28, 0.29, 0.25, 0.35)


func _draw_label(text: String, position: Vector2) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.72, 0.59, 0.72))


func _draw_dashed_connection(from: Vector2, to: Vector2) -> void:
	for index in 6:
		var start := from.lerp(to, float(index) / 6.0)
		var end := from.lerp(to, minf(float(index) / 6.0 + 0.09, 1.0))
		draw_line(start, end, Color(0.33, 0.82, 0.7, 0.58), 2.0, true)


func _p(x: float, y: float) -> Vector2:
	return size * Vector2(x, y)
