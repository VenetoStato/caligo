extends Node2D

const STONE := Color(0.095, 0.125, 0.13, 1.0)
const STONE_LIGHT := Color(0.28, 0.34, 0.32, 1.0)
const EDGE := Color(0.58, 0.56, 0.45, 0.74)
const DEPTH := Color(0.025, 0.045, 0.052, 1.0)
const TEAL := Color(0.22, 0.7, 0.62, 0.46)


func _ready() -> void:
	z_index = -1
	queue_redraw()


func _draw() -> void:
	_draw_quay(Rect2(15, 472, 1010, 120), 7)
	_draw_quay(Rect2(1190, 485, 790, 125), 6)
	_draw_dogana_wedge()
	for platform in [
		Rect2(2165, 396, 190, 28), Rect2(2535, 166, 190, 28), Rect2(2905, 396, 190, 28),
		Rect2(3265, 491, 190, 28), Rect2(3505, 411, 190, 28), Rect2(3735, 331, 190, 28),
	]:
		_draw_platform(platform, true)
	for platform in [
		Rect2(4056, 521, 168, 28), Rect2(4206, 441, 168, 28), Rect2(4036, 361, 168, 28),
		Rect2(4206, 281, 168, 28), Rect2(4046, 201, 168, 28), Rect2(4206, 121, 168, 28),
		Rect2(4146, 41, 168, 28),
	]:
		_draw_platform(platform, false)
	_draw_wedge_rosettes()
	_draw_foreground_frames()


func _draw_quay(rect: Rect2, arch_count: int) -> void:
	draw_rect(rect, STONE, true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 13)), STONE_LIGHT, true)
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), EDGE, 4.0, true)
	var arch_width := rect.size.x / float(arch_count)
	for index in arch_count:
		var center := Vector2(rect.position.x + arch_width * (index + 0.5), rect.position.y + 78)
		draw_arc(center, arch_width * 0.31, PI, TAU, 18, Color(0.21, 0.26, 0.25), 8.0, true)
		draw_rect(Rect2(center.x - arch_width * 0.31, center.y, arch_width * 0.62, rect.end.y - center.y), DEPTH, true)
	for row in 3:
		var y := rect.position.y + 20 + row * 24
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.54, 0.53, 0.46, 0.12), 1.0)


func _draw_dogana_wedge() -> void:
	var wedge := PackedVector2Array([
		Vector2(1980, 538), Vector2(2630, 148), Vector2(3260, 538), Vector2(3260, 650), Vector2(1980, 650),
	])
	draw_polygon(wedge, PackedColorArray([STONE]))
	draw_polyline(PackedVector2Array([Vector2(1980, 538), Vector2(2630, 148), Vector2(3260, 538)]), EDGE, 5.0, true)
	for row in 7:
		var y := 238.0 + row * 50.0
		var half_width := (y - 148.0) * 1.67
		draw_line(Vector2(2630 - half_width, y), Vector2(2630 + half_width, y), Color(0.63, 0.6, 0.5, 0.12), 1.5)
	for x in [2180.0, 2350.0, 2910.0, 3080.0]:
		draw_arc(Vector2(x, 523), 46.0, PI, TAU, 20, Color(0.42, 0.44, 0.39, 0.42), 5.0, true)
		draw_rect(Rect2(x - 46, 523, 92, 127), DEPTH, true)
	draw_arc(Vector2(2630, 495), 70.0, PI, TAU, 24, Color(0.5, 0.49, 0.4, 0.5), 6.0, true)
	draw_rect(Rect2(2560, 495, 140, 155), DEPTH, true)
	var rose := Vector2(2630, 292)
	draw_circle(rose, 38.0, Color(0.035, 0.085, 0.09, 0.94))
	draw_arc(rose, 38.0, 0, TAU, 32, Color(0.48, 0.5, 0.42, 0.65), 3.0, true)
	draw_arc(rose, 22.0, 0, TAU, 24, Color(0.24, 0.62, 0.56, 0.48), 2.0, true)
	for ray in 12:
		var direction := Vector2.from_angle(float(ray) / 12.0 * TAU)
		draw_line(rose + direction * 8.0, rose + direction * 34.0, Color(0.4, 0.44, 0.38, 0.42), 1.4)


func _draw_platform(rect: Rect2, hanging_net: bool) -> void:
	draw_rect(rect, STONE, true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7)), STONE_LIGHT, true)
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), EDGE, 3.0, true)
	var bottom_y := rect.end.y
	draw_polygon(
		PackedVector2Array([
			Vector2(rect.position.x + 8, bottom_y),
			Vector2(rect.end.x - 8, bottom_y),
			Vector2(rect.end.x - 22, bottom_y + 24),
			Vector2(rect.position.x + 22, bottom_y + 24),
		]),
		PackedColorArray([Color(0.035, 0.06, 0.065, 0.92)])
	)
	if hanging_net:
		for index in 4:
			var x := rect.position.x + 24 + index * 42
			draw_line(Vector2(x, rect.end.y), Vector2(x + 8, rect.end.y + 24), Color(0.5, 0.48, 0.38, 0.26), 1.2, true)


func _draw_wedge_rosettes() -> void:
	for at in [Vector2(2260, 355), Vector2(3000, 355)]:
		draw_arc(at, 18.0, 0, TAU, 22, Color(TEAL, 0.42), 2.0, true)
		for ray in 8:
			var direction := Vector2.from_angle(float(ray) / 8.0 * TAU)
			draw_line(at + direction * 7.0, at + direction * 14.0, Color(TEAL, 0.35), 1.4)


func _draw_foreground_frames() -> void:
	draw_polygon(PackedVector2Array([Vector2(-80, -200), Vector2(90, -200), Vector2(45, 220), Vector2(-80, 360)]), PackedColorArray([Color(0.008, 0.015, 0.018, 0.92)]))
	draw_polygon(PackedVector2Array([Vector2(6030, -200), Vector2(6220, -200), Vector2(6220, 560), Vector2(6080, 300)]), PackedColorArray([Color(0.008, 0.015, 0.018, 0.92)]))
