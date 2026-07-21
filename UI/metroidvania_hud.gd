extends Control

@onready var _fish_label: Label = $FishLabel
@onready var _grace_label: Label = $GraceLabel

var _player: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_find_player()
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_find_player()
	var caught := int(AchievementManager.get("fish_caught_count")) if AchievementManager else 0
	_fish_label.text = "PESCA  %d   •   OGNI CATTURA +1 VITA" % caught
	var level := get_tree().current_scene
	if level and level.has_method("get_current_grace_name"):
		_grace_label.text = str(level.call("get_current_grace_name")).to_upper()
	queue_redraw()


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _draw() -> void:
	var origin := Vector2(36.0, 30.0)
	draw_polygon(
		PackedVector2Array([
			origin + Vector2(-16, 0),
			origin + Vector2(218, 0),
			origin + Vector2(234, 22),
			origin + Vector2(218, 74),
			origin + Vector2(-16, 74),
			origin + Vector2(-28, 38),
		]),
		PackedColorArray([Color(0.012, 0.025, 0.032, 0.82)])
	)
	draw_polyline(
		PackedVector2Array([
			origin + Vector2(-16, 0),
			origin + Vector2(218, 0),
			origin + Vector2(234, 22),
		]),
		Color(0.58, 0.52, 0.36, 0.65),
		2.0
	)

	var max_health := int(_player.get("max_health")) if is_instance_valid(_player) else 5
	var health := int(_player.get("current_health")) if is_instance_valid(_player) else max_health
	for index in max_health:
		var center := origin + Vector2(18.0 + index * 36.0, 31.0)
		var shape := PackedVector2Array([
			center + Vector2(-12, -11),
			center + Vector2(-7, -17),
			center + Vector2(0, -13),
			center + Vector2(7, -17),
			center + Vector2(12, -11),
			center + Vector2(10, 7),
			center + Vector2(0, 15),
			center + Vector2(-10, 7),
			center + Vector2(-12, -11),
		])
		var full := index < health
		var fill := Color(0.86, 0.92, 0.86, 0.96) if full else Color(0.11, 0.15, 0.16, 0.85)
		draw_polygon(shape, PackedColorArray([fill]))
		draw_polyline(shape, Color(0.42, 0.76, 0.7, 0.9) if full else Color(0.3, 0.34, 0.33, 0.7), 2.0)
		if full:
			draw_circle(center + Vector2(-3, -5), 2.2, Color(1, 1, 1, 0.72))
