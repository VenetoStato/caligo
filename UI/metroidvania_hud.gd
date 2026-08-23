extends Control

## HUD della vita: una fila di fiale. Ogni fiala e' un colpo.
## L'acqua sta in piedi e scende dal basso, come in un'ampolla vera.

const VIAL_W := 14.0
const VIAL_H := 28.0
const VIAL_GAP := 7.0
const LOSS_TRAIL_SPEED := 0.85
const LEVEL_SPEED := 8.0

@onready var _grace_label: Label = $GraceLabel

var _player: Node
var _hud_origin := Vector2(36.0, 28.0)
var _hud_scale := 1.0
var _level := 1.0
var _loss_trail := 1.0
var _slosh := 0.0
var _slosh_velocity := 0.0
var _time := 0.0
var _grace_name := ""
var _grace_reveal := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_find_player()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(_player):
		_find_player()
	_update_level(delta)
	_update_grace_banner(delta)
	queue_redraw()


func _update_level(delta: float) -> void:
	var max_health := maxi(int(_player.get("max_health")) if is_instance_valid(_player) else 5, 1)
	var health := int(_player.get("current_health")) if is_instance_valid(_player) else max_health
	var target := clampf(float(health) / float(max_health), 0.0, 1.0)
	if target < _level - 0.001:
		_slosh_velocity -= (_level - target) * 22.0
	_level = move_toward(_level, target, delta * LEVEL_SPEED * maxf(absf(_level - target), 0.15))
	_loss_trail = maxf(_level, _loss_trail - delta * LOSS_TRAIL_SPEED)
	if _loss_trail < _level:
		_loss_trail = _level
	_slosh_velocity -= _slosh * 70.0 * delta
	_slosh_velocity = move_toward(_slosh_velocity, 0.0, 38.0 * delta)
	_slosh += _slosh_velocity * delta


func _update_grace_banner(delta: float) -> void:
	var level_node := get_tree().current_scene
	if level_node and level_node.has_method("get_current_grace_name"):
		var name := str(level_node.call("get_current_grace_name"))
		if name != _grace_name:
			_grace_name = name
			_grace_reveal = 3.4
			_grace_label.text = name.to_upper()
	_grace_reveal = maxf(0.0, _grace_reveal - delta)
	var alpha := clampf(_grace_reveal, 0.0, 1.0) * 0.72
	_grace_label.modulate.a = move_toward(_grace_label.modulate.a, alpha, delta * 1.6)


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _apply_responsive_layout() -> void:
	var viewport_size := CaligoResponsiveLayout.viewport_size(self)
	_hud_scale = clampf(viewport_size.x / 900.0, 0.72, 1.0)
	var margin := clampf(viewport_size.x * 0.028, 10.0, 36.0)
	_hud_origin = Vector2(margin, clampf(viewport_size.y * 0.038, 12.0, 28.0))
	var max_health := maxi(int(_player.get("max_health")) if is_instance_valid(_player) else 5, 1)
	var row_w := float(max_health) * (VIAL_W + VIAL_GAP) - VIAL_GAP
	_grace_label.position = _hud_origin + Vector2(0, VIAL_H + 10.0) * _hud_scale
	_grace_label.size = Vector2(maxf(row_w + 40.0, 220.0), 22.0) * _hud_scale
	_grace_label.add_theme_font_size_override("font_size", int(11 * _hud_scale))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(_hud_origin, 0.0, Vector2.ONE * _hud_scale)
	var max_health := maxi(int(_player.get("max_health")) if is_instance_valid(_player) else 5, 1)
	var units := float(max_health)
	var low := _level <= 0.34
	for index in max_health:
		var origin := Vector2(float(index) * (VIAL_W + VIAL_GAP), 0.0)
		var fill := clampf(_level * units - float(index), 0.0, 1.0)
		var trail := clampf(_loss_trail * units - float(index), 0.0, 1.0)
		_draw_vial(origin, fill, trail, low)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_vial(origin: Vector2, fill: float, trail: float, low: bool) -> void:
	var body := Rect2(origin.x, origin.y + 5.0, VIAL_W, VIAL_H - 5.0)
	draw_colored_polygon(_vial_outline(body, -2.2), Color(0.012, 0.03, 0.034, 0.82))
	draw_colored_polygon(_vial_outline(body, 0.0), Color(0.045, 0.1, 0.11, 0.78))
	if trail > 0.04:
		_draw_vial_water(body, trail, Color(0.7, 0.86, 0.8, 0.22))
	if fill > 0.04:
		var water := Color(0.34, 0.82, 0.76, 0.92)
		if low:
			water = water.lerp(Color(0.9, 0.58, 0.4, 0.94), 0.48 + 0.32 * sin(_time * 6.0))
		_draw_vial_water(body, fill, water)
	_draw_vial_glass_edge(body)
	_draw_vial_neck(origin)


func _vial_outline(body: Rect2, inset: float) -> PackedVector2Array:
	var radius := body.size.x * 0.5 - inset
	var cx := body.position.x + body.size.x * 0.5
	var top := body.position.y + inset
	var bottom := body.end.y - radius
	var points := PackedVector2Array()
	for step in 11:
		var angle := lerpf(PI, TAU, float(step) / 10.0)
		points.append(Vector2(cx, bottom) + Vector2(cos(angle), sin(angle)) * radius)
	points.append(Vector2(cx + radius, top))
	points.append(Vector2(cx - radius, top))
	return points


func _draw_vial_water(body: Rect2, ratio: float, tint: Color) -> void:
	var radius := body.size.x * 0.5 - 1.15
	var cx := body.position.x + body.size.x * 0.5
	var bowl := body.end.y - body.size.x * 0.5
	var min_y := body.position.y + 1.2
	var max_y := body.end.y - 1.2
	var water_top := clampf(max_y - (max_y - min_y) * clampf(ratio, 0.0, 1.0) + _slosh * 0.45, min_y, max_y)
	var points := PackedVector2Array()
	var half_at_top := radius
	if water_top > bowl:
		half_at_top = sqrt(maxf(radius * radius - pow(water_top - bowl, 2.0), 0.0))
	points.append(Vector2(cx - half_at_top, water_top))
	for step in 10:
		var angle := lerpf(PI, TAU, float(step) / 9.0)
		var point := Vector2(cx, bowl) + Vector2(cos(angle), sin(angle)) * radius
		if point.y >= water_top - 0.01:
			points.append(point)
	points.append(Vector2(cx + half_at_top, water_top))
	if points.size() < 3:
		return
	draw_colored_polygon(points, tint)
	draw_line(
		Vector2(cx - half_at_top, water_top),
		Vector2(cx + half_at_top, water_top),
		Color(0.9, 0.99, 0.94, 0.72),
		1.1,
		true
	)


func _draw_vial_glass_edge(body: Rect2) -> void:
	var brass := Color(0.62, 0.52, 0.34, 0.92)
	var outline := _vial_outline(body, -2.2)
	outline.append(outline[0])
	draw_polyline(outline, brass, 1.35, true)
	var cx := body.position.x + body.size.x * 0.5
	draw_line(
		Vector2(cx - body.size.x * 0.22, body.position.y + 3.0),
		Vector2(cx - body.size.x * 0.18, body.end.y - 8.0),
		Color(0.86, 0.96, 0.94, 0.22),
		1.4
	)


func _draw_vial_neck(origin: Vector2) -> void:
	var cx := origin.x + VIAL_W * 0.5
	var brass := Color(0.66, 0.55, 0.36, 0.95)
	var neck := Rect2(cx - 3.2, origin.y + 1.4, 6.4, 5.2)
	draw_rect(neck, Color(0.05, 0.08, 0.09, 0.92))
	draw_rect(neck, brass, false, 1.15)
	draw_rect(Rect2(cx - 4.1, origin.y - 0.4, 8.2, 2.6), Color(0.2, 0.16, 0.1, 0.95))
	draw_rect(Rect2(cx - 4.1, origin.y - 0.4, 8.2, 2.6), brass, false, 1.1)
	draw_line(Vector2(cx - 2.4, origin.y + 0.7), Vector2(cx + 2.4, origin.y + 0.7), Color(0.86, 0.76, 0.5, 0.55), 1.0)
