extends Control

const MAP_ART := preload("res://Landscape/Dogana/Generated/dogana_map_sideview_v2.png")

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
	draw_rect(bounds, Color(0.008, 0.02, 0.026, 0.98), true)
	draw_rect(Rect2(12, 12, size.x - 24, size.y - 24), Color(0.025, 0.07, 0.078, 0.98), true)
	draw_rect(Rect2(18, 18, size.x - 36, size.y - 36), Color(0.25, 0.72, 0.66, 0.38), false, 1.5)
	_draw_map_art()
	_draw_route()
	_draw_compass()
	_draw_player_marker()
	_draw_header()


func _draw_map_art() -> void:
	var target := Rect2(_p(0.035, 0.10), size * Vector2(0.93, 0.68))
	draw_texture_rect(MAP_ART, target, false, Color(0.72, 0.86, 0.86, 0.94))
	# Fascia d'acqua sotto l'illustrazione, con un solo waterfront continuo.
	draw_rect(Rect2(_p(0.035, 0.70), size * Vector2(0.93, 0.085)), Color(0.02, 0.17, 0.19, 0.42), true)


func _draw_chart_grid() -> void:
	# Reticolo sobrio: dà coordinate e scala senza sembrare una pergamena decorativa.
	for x in range(1, 10):
		var px := size.x * float(x) / 10.0
		draw_line(Vector2(px, 20), Vector2(px, size.y - 20), Color(0.22, 0.64, 0.6, 0.055), 1.0)
	for y in range(1, 8):
		var py := size.y * float(y) / 8.0
		draw_line(Vector2(20, py), Vector2(size.x - 20, py), Color(0.22, 0.64, 0.6, 0.055), 1.0)


func _draw_water_channels() -> void:
	# Vista laterale, come il livello: laguna sopra lo skyline e acqua continua
	# sotto la banchina. Niente sagome a zig-zag che suggeriscano stanze false.
	draw_rect(Rect2(_p(0.03, 0.06), size * Vector2(0.94, 0.25)), Color(0.015, 0.17, 0.2, 0.82), true)
	draw_rect(Rect2(_p(0.03, 0.71), size * Vector2(0.94, 0.24)), Color(0.01, 0.15, 0.18, 0.94), true)
	for offset in 4:
		var y := size.y * (0.77 + offset * 0.045)
		draw_line(_p(0.05, y / size.y), _p(0.95, y / size.y), Color(0.3, 0.66, 0.62, 0.07), 1.0)


func _draw_main_regions() -> void:
	# Cinque moduli contigui, tutti appoggiati alla stessa linea di banchina.
	_draw_room("arrival", Rect2(_p(0.06, 0.57), size * Vector2(0.17, 0.14)), "PUNTA / PONTILE")
	_draw_room("customs", Rect2(_p(0.23, 0.49), size * Vector2(0.27, 0.22)), "DOGANA DA MAR")
	_draw_room("canal", Rect2(_p(0.50, 0.53), size * Vector2(0.18, 0.18)), "SEMINARIO")
	_draw_room("fortuna", Rect2(_p(0.68, 0.46), size * Vector2(0.12, 0.25)), "TORRE FORTUNA")
	_draw_room("salute", Rect2(_p(0.80, 0.39), size * Vector2(0.17, 0.32)), "BASILICA SALUTE")
	if bool(_regions.get("salute", false)):
		draw_arc(_p(0.885, 0.39), 34.0, PI, TAU, 28, Color(0.72, 0.62, 0.4, 0.78), 2.8, true)
		draw_line(_p(0.885, 0.32), _p(0.885, 0.27), Color(0.72, 0.62, 0.4, 0.72), 2.0)


func _draw_secret_regions() -> void:
	pass


func _draw_route() -> void:
	var route := PackedVector2Array([_p(0.07, 0.69), _p(0.22, 0.69), _p(0.48, 0.69), _p(0.66, 0.69), _p(0.79, 0.69), _p(0.95, 0.69)])
	for index in route.size() - 1:
		var region_id: String = ["arrival", "customs", "canal", "fortuna", "salute"][index]
		if bool(_regions.get(region_id, false)):
			draw_line(route[index], route[index + 1], Color(0.38, 0.95, 0.78, 0.72), 3.0, true)


func _draw_landmarks() -> void:
	if bool(_regions.get("arrival", false)):
		var tower := _p(0.09, 0.55)
		draw_line(tower, tower + Vector2(0, -58), Color(0.67, 0.58, 0.34, 0.85), 7.0, true)
		draw_circle(tower + Vector2(0, -67), 9.0, Color(0.71, 0.58, 0.25, 0.86))


func _draw_compass() -> void:
	var center := _p(0.93, 0.84)
	draw_arc(center, 30.0, 0, TAU, 32, Color(0.36, 0.84, 0.75, 0.58), 1.2, true)
	draw_polygon(PackedVector2Array([center + Vector2(0, -30), center + Vector2(-6, 4), center, center + Vector2(6, 4)]), PackedColorArray([Color(0.76, 1.0, 0.88, 0.86)]))
	draw_line(center + Vector2(-24, 0), center + Vector2(24, 0), Color(0.36, 0.84, 0.75, 0.48), 1.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-4, -38), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.74, 0.95, 0.87, 0.82))


func _draw_header() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(32, 42), "CARTA DELLA DOGANA", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.72, 0.95, 0.86, 0.96))
	draw_string(ThemeDB.fallback_font, Vector2(32, 60), "PUNTA DELLA DOGANA  •  BACINO DI SAN MARCO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.45, 0.72, 0.67, 0.75))


func _draw_player_marker() -> void:
	var position: Vector2
	if _player_world_position.y < -100.0 and _player_world_position.x > 4000.0:
		var nave_x := clampf((_player_world_position.x - 4100.0) / 2050.0, 0.0, 1.0)
		position = Vector2(lerpf(size.x * 0.82, size.x * 0.955, nave_x), size.y * 0.69)
	else:
		var normalized_x := clampf(_player_world_position.x / 6000.0, 0.0, 1.0)
		position = Vector2(lerpf(size.x * 0.065, size.x * 0.955, normalized_x), size.y * 0.69)
	# Il punto deve orientare, non dominare la carta: un piccolo ago d'ottone
	# con alone lento e quasi trasparente, invece del vecchio pallino pulsante.
	var breath := 0.5 + sin(_time * 2.2) * 0.12
	draw_arc(position, 7.0, -PI * 0.8, PI * 0.8, 18, Color(0.55, 0.86, 0.74, 0.22 + breath * 0.16), 1.0, true)
	draw_circle(position, 3.2, Color(0.82, 0.72, 0.46, 0.88))
	draw_circle(position, 1.15, Color(0.94, 0.9, 0.74, 0.96))


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
	return Color(0.08, 0.2, 0.21, 0.98) if bool(_regions.get(region_id, false)) else Color(0.025, 0.06, 0.065, 0.9)


func _room_edge(region_id: String) -> Color:
	return Color(0.4, 0.9, 0.78, 0.9) if bool(_regions.get(region_id, false)) else Color(0.16, 0.38, 0.38, 0.48)


func _draw_label(text: String, position: Vector2) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.94, 0.86, 0.88))


func _draw_dashed_connection(from: Vector2, to: Vector2) -> void:
	for index in 6:
		var start := from.lerp(to, float(index) / 6.0)
		var end := from.lerp(to, minf(float(index) / 6.0 + 0.09, 1.0))
		draw_line(start, end, Color(0.33, 0.82, 0.7, 0.58), 2.0, true)


func _p(x: float, y: float) -> Vector2:
	return size * Vector2(x, y)
