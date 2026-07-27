extends Node2D
## Anello di luce one-shot, economico (niente texture).

var _t := 0.0
var _life := 0.55
var _tint := Color(0.4, 0.95, 0.85, 0.9)
var _mobile := false


func play(tint: Color, mobile := false) -> void:
	_tint = tint
	_mobile = mobile
	_t = 0.0
	z_index = 9
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= _life:
		queue_free()


func _draw() -> void:
	var p := clampf(_t / _life, 0.0, 1.0)
	var radius := lerpf(10.0, 52.0 if not _mobile else 40.0, p)
	var a := (1.0 - p) * 0.75
	var segments := 18 if _mobile else 28
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, segments, Color(_tint.r, _tint.g, _tint.b, a), 2.2, true)
	draw_circle(Vector2.ZERO, radius * 0.22, Color(_tint.r, _tint.g, _tint.b, a * 0.25))
