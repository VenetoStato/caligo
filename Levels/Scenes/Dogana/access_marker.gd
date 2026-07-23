extends Node2D

@export var access_id := ""
@export var marker_color := Color(0.3, 0.92, 0.76, 1.0)
@export var marker_scale := 1.0

var _time := 0.0


func _ready() -> void:
	add_to_group("dogana_access_marker")
	z_index = 8


func _process(delta: float) -> void:
	_time += delta
	if fmod(_time, 1.0 / 24.0) < delta:
		queue_redraw()


func mark_open() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.55)
	tween.tween_callback(func() -> void: set_process(false))


func _draw() -> void:
	var pulse := 0.7 + sin(_time * 2.4) * 0.22
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * marker_scale)
	for index in 3:
		var y := -18.0 + index * 12.0
		var offset := sin(_time * 2.0 + index) * 2.0
		draw_polyline(
			PackedVector2Array([
				Vector2(-18 + offset, y - 6),
				Vector2(0 + offset, y),
				Vector2(-18 + offset, y + 6),
			]),
			Color(marker_color.r, marker_color.g, marker_color.b, pulse - index * 0.12),
			2.4,
			true
		)
	draw_arc(Vector2(9, 0), 13.0 + pulse * 2.0, 0.25, TAU - 0.25, 24, Color(marker_color.r, marker_color.g, marker_color.b, pulse * 0.62), 2.0, true)
	for index in 4:
		var phase := _time * (1.1 + index * 0.08) + index * 1.7
		var mote := Vector2(8 + sin(phase) * 13.0, -25.0 - fmod(_time * 12.0 + index * 13.0, 42.0))
		draw_circle(mote, 1.5 + index * 0.25, Color(marker_color.r, marker_color.g, marker_color.b, 0.25 + pulse * 0.25))
	draw_set_transform(Vector2.ZERO)
