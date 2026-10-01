extends Node2D

const PARTICLE_MOTIF := preload("res://Art/Editable/VFX/warden_ink_spray.png")

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
	set_process(false)
	var particles := CPUParticles2D.new()
	particles.texture = PARTICLE_MOTIF
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	particles.amount = 18 if heavy else 11
	particles.lifetime = 0.62 if mode == 2 else 0.44
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.randomness = 0.42
	particles.direction = direction
	particles.spread = 38.0 if mode == 1 else 19.0
	particles.gravity = Vector2(0.0, 42.0 if mode == 1 else -12.0)
	particles.initial_velocity_min = 38.0 if mode == 2 else 72.0
	particles.initial_velocity_max = 86.0 if mode == 2 else 154.0
	particles.angular_velocity_min = -85.0
	particles.angular_velocity_max = 85.0
	particles.scale_amount_min = 0.018
	particles.scale_amount_max = 0.052 if heavy else 0.038
	particles.color = Color(tint.r, tint.g, tint.b, 0.74)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = additive
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(queue_free)


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
	for index in 7:
		var drift := direction * lerpf(10.0, 62.0, progress) + side * sin(float(index) * 2.1) * 15.0
		draw_circle(drift, (5.0 if heavy else 3.5) * fade, Color(tint.r, tint.g, tint.b, 0.34 * fade))


func _draw_impact(progress: float, fade: float, side: Vector2) -> void:
	var radius := lerpf(8.0, 38.0 if heavy else 26.0, progress)
	draw_circle(Vector2.ZERO, radius * 0.42, Color(tint.r, tint.g, tint.b, 0.26 * fade))
	for index in 6:
		var ray := Vector2.from_angle(TAU * float(index) / 6.0 + _age * 3.2)
		draw_circle(ray * radius, 4.0 * fade, Color(1.0, 0.82, 0.58, 0.56 * fade))


func _draw_charge(progress: float, fade: float, side: Vector2) -> void:
	var radius := lerpf(12.0, 34.0 if heavy else 25.0, progress)
	var alpha := 0.24 + sin(_age * 30.0) * 0.12
	for index in 4:
		var offset := (float(index) - 1.5) * 0.32
		var point := direction.rotated(offset) * radius
		draw_circle(point, 2.0 + progress * 1.5, Color(1.0, 0.9, 0.7, 0.72 * fade))
