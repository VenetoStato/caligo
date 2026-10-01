extends Control

## HUD della vita: maschere discrete, una per colpo, come in Hollow Knight.
## Niente fiala/misuratore: se e' piena sei vivo, se e' vuota hai preso danno.

const MASK_W := 20.0
const MASK_H := 24.0
const MASK_GAP := 6.0
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
	visible = true
	modulate = Color.WHITE
	z_index = 60
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
	var row_w := float(max_health) * (MASK_W + MASK_GAP) - MASK_GAP
	_grace_label.position = _hud_origin + Vector2(0, MASK_H + 10.0) * _hud_scale
	_grace_label.size = Vector2(maxf(row_w + 40.0, 220.0), 22.0) * _hud_scale
	_grace_label.add_theme_font_size_override("font_size", int(11 * _hud_scale))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(_hud_origin, 0.0, Vector2.ONE * _hud_scale)
	var max_health := maxi(int(_player.get("max_health")) if is_instance_valid(_player) else 5, 1)
	var units := float(max_health)
	var low := _level <= 0.34
	for index in max_health:
		var origin := Vector2(float(index) * (MASK_W + MASK_GAP), 0.0)
		var fill := clampf(_level * units - float(index), 0.0, 1.0)
		var trail := clampf(_loss_trail * units - float(index), 0.0, 1.0)
		_draw_mask(origin, fill, trail, low)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _mask_points(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in 16:
		var angle := TAU * float(step) / 16.0 - PI * 0.5
		var bulge := 1.12 if sin(angle) > 0.0 else 1.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry * bulge))
	return points


func _draw_mask(origin: Vector2, fill: float, trail: float, low: bool) -> void:
	var center := origin + Vector2(MASK_W * 0.5, MASK_H * 0.52)
	var shell := _mask_points(center, MASK_W * 0.42, MASK_H * 0.38)
	draw_colored_polygon(_mask_points(center + Vector2(0, 1.2), MASK_W * 0.44, MASK_H * 0.4), Color(0.02, 0.04, 0.05, 0.55))
	draw_colored_polygon(shell, Color(0.06, 0.1, 0.12, 0.88))
	if trail > 0.35 and fill < 0.35:
		draw_colored_polygon(_mask_points(center, MASK_W * 0.34, MASK_H * 0.3), Color(0.78, 0.88, 0.84, 0.18))
	if fill > 0.35:
		var life := Color(0.86, 0.96, 0.92, 0.96)
		if low:
			life = life.lerp(Color(0.95, 0.62, 0.48, 0.96), 0.42 + 0.28 * sin(_time * 6.0))
		draw_colored_polygon(_mask_points(center, MASK_W * 0.34, MASK_H * 0.3), life)
		draw_circle(center + Vector2(-3.2, -4.0), 2.2, Color(1.0, 1.0, 1.0, 0.28))
	var rim := shell.duplicate()
	rim.append(shell[0])
	draw_polyline(rim, Color(0.72, 0.84, 0.8, 0.82), 1.35, true)
