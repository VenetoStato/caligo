extends Node2D

const BONE := Color(0.68, 0.66, 0.54, 1.0)
const STONE := Color(0.13, 0.18, 0.19, 1.0)
const STONE_EDGE := Color(0.32, 0.42, 0.40, 1.0)
const WOOD := Color(0.19, 0.13, 0.10, 1.0)
const BRASS := Color(0.62, 0.48, 0.24, 1.0)
const GLOW := Color(0.24, 0.88, 0.76, 1.0)

var _time := 0.0
var _redraw_accumulator := 0.0


func _ready() -> void:
	z_index = -2


func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	_time += delta
	_redraw_accumulator += delta
	if _redraw_accumulator >= 1.0 / 30.0:
		_redraw_accumulator = 0.0
		queue_redraw()


func _draw() -> void:
	_draw_motes()


func _draw_tide_idol(at: Vector2, prop_scale: float) -> void:
	draw_set_transform(at, 0.0, Vector2.ONE * prop_scale)
	draw_polygon(
		PackedVector2Array([Vector2(-43, 0), Vector2(-35, -72), Vector2(-17, -105), Vector2(0, -120), Vector2(17, -105), Vector2(35, -72), Vector2(43, 0)]),
		PackedColorArray([STONE])
	)
	draw_polyline(PackedVector2Array([Vector2(-43, 0), Vector2(-35, -72), Vector2(0, -120), Vector2(35, -72), Vector2(43, 0)]), STONE_EDGE, 4.0, true)
	var pulse := 0.75 + sin(_time * 2.2 + at.x) * 0.18
	draw_circle(Vector2(0, -72), 18.0, Color(0.01, 0.05, 0.055, 1.0))
	draw_circle(Vector2(0, -72), 11.0 + pulse * 2.0, Color(GLOW, pulse))
	draw_circle(Vector2(3, -76), 3.0, Color(0.9, 1.0, 0.88, pulse))
	draw_arc(Vector2.ZERO, 29.0, PI, TAU, 22, STONE_EDGE, 3.0, true)
	for side in [-1.0, 1.0]:
		var points := PackedVector2Array()
		for index in 7:
			var y := -48.0 + index * 9.0
			points.append(Vector2(side * (12.0 + index * 6.0), y + sin(_time * 1.3 + index) * 2.0))
		draw_polyline(points, BONE, 3.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_bricola_lantern(at: Vector2, prop_scale: float) -> void:
	draw_set_transform(at, 0.0, Vector2.ONE * prop_scale)
	for offset in [-12.0, 0.0, 12.0]:
		draw_line(Vector2(offset, 5), Vector2(offset + 3, -93), WOOD, 9.0, true)
		draw_line(Vector2(offset + 3, -93), Vector2(offset + 8, -108), Color(0.08, 0.06, 0.05), 5.0, true)
	draw_line(Vector2(-23, -76), Vector2(26, -72), BRASS, 4.0, true)
	draw_polygon(PackedVector2Array([Vector2(-17, -119), Vector2(17, -119), Vector2(13, -91), Vector2(-13, -91)]), PackedColorArray([Color(0.08, 0.13, 0.12, 0.96)]))
	var pulse := 0.72 + sin(_time * 3.1 + at.x) * 0.2
	draw_circle(Vector2(0, -105), 8.0, Color(GLOW, pulse))
	draw_arc(Vector2(0, -105), 19.0, 0, TAU, 28, Color(BRASS, 0.8), 3.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_cursed_net(at: Vector2, prop_scale: float) -> void:
	draw_set_transform(at, -0.08, Vector2.ONE * prop_scale)
	draw_line(Vector2(-65, -112), Vector2(67, -115), WOOD, 7.0, true)
	for index in 7:
		var x := -55.0 + index * 18.0
		draw_line(Vector2(x, -108), Vector2(x * 0.76, -13), Color(BONE, 0.65), 2.0, true)
	for row in 6:
		var y := -98.0 + row * 16.0
		draw_line(Vector2(-53 + row * 2, y), Vector2(53 - row * 2, y + 2), Color(BONE, 0.52), 2.0, true)
	for fish_pos in [Vector2(-25, -61), Vector2(18, -42), Vector2(40, -79)]:
		draw_polygon(PackedVector2Array([fish_pos + Vector2(-13, 0), fish_pos + Vector2(0, -7), fish_pos + Vector2(16, 0), fish_pos + Vector2(0, 7)]), PackedColorArray([Color(0.18, 0.52, 0.48, 0.9)]))
		draw_circle(fish_pos + Vector2(8, -1), 1.8, Color(0.85, 0.95, 0.72))
	draw_set_transform(Vector2.ZERO)


func _draw_fishmonger_crates(at: Vector2, prop_scale: float) -> void:
	draw_set_transform(at, 0.0, Vector2.ONE * prop_scale)
	for crate in [Rect2(-64, -50, 66, 50), Rect2(3, -66, 73, 66)]:
		draw_rect(crate, WOOD, true)
		draw_rect(crate, BRASS, false, 3.0)
		draw_line(crate.position, crate.end, Color(BRASS, 0.55), 2.0)
		draw_line(Vector2(crate.end.x, crate.position.y), Vector2(crate.position.x, crate.end.y), Color(BRASS, 0.55), 2.0)
	var eel := PackedVector2Array()
	for index in 12:
		eel.append(Vector2(-42 + index * 9, -65 + sin(index * 0.85 + _time * 1.7) * 7))
	draw_polyline(eel, Color(0.27, 0.68, 0.61), 5.0, true)
	draw_circle(Vector2(57, eel[-1].y - 1), 2.0, Color(0.95, 0.86, 0.46))
	draw_set_transform(Vector2.ZERO)


func _draw_bone_wind_chime(at: Vector2, prop_scale: float) -> void:
	draw_set_transform(at, 0.0, Vector2.ONE * prop_scale)
	draw_line(Vector2(-44, -92), Vector2(44, -92), WOOD, 6.0, true)
	for index in 5:
		var x := -32.0 + index * 16.0
		var sway := sin(_time * 1.8 + index) * 3.0
		draw_line(Vector2(x, -90), Vector2(x + sway, -54 + index % 2 * 8), Color(BONE, 0.75), 1.5, true)
		draw_arc(Vector2(x + sway, -43 + index % 2 * 8), 9.0, 0.15, PI - 0.15, 12, BONE, 4.0, true)
	draw_polygon(PackedVector2Array([Vector2(-15, -105), Vector2(0, -124), Vector2(15, -105), Vector2(0, -99)]), PackedColorArray([Color(0.2, 0.5, 0.47, 0.8)]))
	draw_set_transform(Vector2.ZERO)


func _draw_secret_glyph(at: Vector2, prop_scale: float) -> void:
	draw_set_transform(at, 0.0, Vector2.ONE * prop_scale)
	var pulse := 0.4 + (sin(_time * 2.4 + at.x) + 1.0) * 0.18
	draw_arc(Vector2.ZERO, 17.0, 0.25, TAU - 0.25, 22, Color(GLOW, pulse), 2.4, true)
	draw_polygon(
		PackedVector2Array([Vector2(-14, 0), Vector2(-3, -8), Vector2(11, 0), Vector2(-3, 8)]),
		PackedColorArray([Color(0.14, 0.48, 0.45, pulse)])
	)
	draw_circle(Vector2(5, -1), 2.2, Color(0.84, 0.93, 0.65, pulse))
	draw_line(Vector2(-15, 0), Vector2(-25, -9), Color(BONE, pulse * 0.8), 2.0, true)
	draw_line(Vector2(-15, 0), Vector2(-25, 9), Color(BONE, pulse * 0.8), 2.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_motes() -> void:
	# Riflessi minuti confinati all'acqua: non devono sembrare oggetti sospesi
	# davanti a tetti e facciate.
	for index in 10:
		var seed := float(index * 379)
		var x := 650.0 + fmod(seed * 7.13, 3700.0)
		var y := 585.0 + fmod(seed * 3.71, 115.0) + sin(_time * 0.7 + index) * 5.0
		var alpha := 0.05 + (sin(_time * 1.8 + index * 2.1) + 1.0) * 0.035
		draw_circle(Vector2(x, y), 1.0 + float(index % 2), Color(GLOW, alpha))


func _create_lantern_light(at: Vector2, energy: float) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.3, 0.95, 0.78, 0.7))
	gradient.set_color(1, Color(0.02, 0.08, 0.07, 0.0))
	var texture := GradientTexture2D.new()
	texture.width = 192
	texture.height = 192
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	var light := PointLight2D.new()
	light.position = at
	light.texture = texture
	light.energy = energy
	light.texture_scale = 1.5
	light.color = Color(0.45, 0.95, 0.81)
	add_child(light)
