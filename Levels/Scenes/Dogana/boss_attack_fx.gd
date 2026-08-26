extends Node2D

## Effetto breve, disegnato sopra il combattimento: non sostituisce le
## collisioni, ma rende leggibile il momento esatto di carica, rilascio e hit.
var direction := Vector2.RIGHT
var tint := Color(0.35, 0.95, 0.85, 1.0)
var heavy := false
var mode := 0 # 0 rilascio, 1 impatto, 2 carica
var _age := 0.0
var _duration := 0.48


func setup(facing: Vector2, effect_tint: Color, is_heavy := false, effect_mode := 0) -> void:
	direction = facing.normalized() if facing.length_squared() > 0.01 else Vector2.RIGHT
	tint = effect_tint
	heavy = is_heavy
	mode = effect_mode
	_duration = 0.58 if mode == 2 else (0.42 if heavy else 0.32)


func _ready() -> void:
	z_index = 10
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_age / maxf(_duration, 0.01), 0.0, 1.0)
	var fade := 1.0 - progress
	var side := direction.orthogonal()
	match mode:
		1:
			_draw_impact(progress, fade, side)
		2:
			_draw_charge(progress, fade, side)
		_:
			_draw_release(progress, fade, side)


func _draw_release(progress: float, fade: float, side: Vector2) -> void:
	var reach := lerpf(18.0, 76.0 if heavy else 54.0, progress)
	var spread := 24.0 if heavy else 16.0
	var wedge := PackedVector2Array([
		Vector2.ZERO,
		direction * reach + side * spread,
		direction * (reach * 1.12),
		direction * reach - side * spread,
	])
	draw_colored_polygon(wedge, Color(tint.r, tint.g, tint.b, (0.3 if heavy else 0.22) * fade))
	draw_arc(Vector2.ZERO, reach * 0.78, direction.angle() - 0.58, direction.angle() + 0.58, 16, Color(tint.r, tint.g, tint.b, 0.9 * fade), 2.8 if heavy else 2.0, true)
	for index in 3:
		var offset := (float(index) - 1.0) * (10.0 if heavy else 7.0)
		draw_line(side * offset, direction * reach + side * offset * 1.4, Color(1.0, 0.92, 0.74, 0.7 * fade), 1.4, true)


func _draw_impact(progress: float, fade: float, side: Vector2) -> void:
	var radius := lerpf(8.0, 38.0 if heavy else 26.0, progress)
	draw_circle(Vector2.ZERO, radius * 0.42, Color(tint.r, tint.g, tint.b, 0.26 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, 0.92 * fade), 2.8 if heavy else 1.8, true)
	for index in 6:
		var ray := Vector2.from_angle(TAU * float(index) / 6.0 + _age * 3.2)
		draw_line(ray * radius * 0.45, ray * radius * (1.15 if heavy else 0.92), Color(1.0, 0.82, 0.58, 0.78 * fade), 1.5, true)


func _draw_charge(progress: float, fade: float, side: Vector2) -> void:
	var radius := lerpf(12.0, 34.0 if heavy else 25.0, progress)
	var alpha := 0.24 + sin(_age * 30.0) * 0.12
	draw_arc(Vector2.ZERO, radius, direction.angle() - PI * 0.72, direction.angle() + PI * 0.72, 22, Color(tint.r, tint.g, tint.b, alpha * fade), 2.2, true)
	for index in 4:
		var offset := (float(index) - 1.5) * 0.32
		var point := direction.rotated(offset) * radius
		draw_circle(point, 2.0 + progress * 1.5, Color(1.0, 0.9, 0.7, 0.72 * fade))
