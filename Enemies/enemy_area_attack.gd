extends Area2D

const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")

var radius := 84.0
var damage := 1
var windup := 0.68
var active_time := 0.16
var tint := Color(0.22, 0.88, 0.72, 1.0)
var _elapsed := 0.0
var _fired := false
var _damaged: Array[Node2D] = []


func setup(attack_radius: float, attack_damage: int, attack_tint: Color, attack_windup := 0.68, attack_active := 0.16) -> void:
	radius = attack_radius
	damage = attack_damage
	tint = attack_tint
	windup = attack_windup
	active_time = attack_active


func _ready() -> void:
	add_to_group("enemy_transient_attack")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	monitoring = false
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	z_index = 6
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _fired and _elapsed >= windup:
		_fired = true
		monitoring = true
		PARTICLE_BURST.spawn(
			get_tree().current_scene,
			global_position,
			Color(tint.r, tint.g, tint.b, 0.82),
			22,
			Vector2.UP,
			45.0,
			135.0,
			0.7
		)
		call_deferred("_damage_overlaps")
	elif _fired and active_time > 0.35 and fmod(_elapsed, 0.35) < delta:
		# Pozze persistenti: tick ripetuti.
		_damaged.clear()
		call_deferred("_damage_overlaps")
	if _fired and _elapsed >= windup + active_time:
		queue_free()
		return
	queue_redraw()


func _damage_overlaps() -> void:
	for body in get_overlapping_bodies():
		if body is Node2D and body.is_in_group("player") and body not in _damaged:
			_damaged.append(body)
			if body.has_method("take_damage"):
				body.call_deferred("take_damage", damage, global_position)


func _draw() -> void:
	if not _fired:
		var progress := clampf(_elapsed / maxf(windup, 0.01), 0.0, 1.0)
		var pulse_radius := lerpf(radius * 0.28, radius, progress)
		draw_circle(Vector2.ZERO, pulse_radius, Color(tint.r, tint.g, tint.b, 0.04 + progress * 0.08))
		draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, 0.35 + progress * 0.5), 2.0 + progress * 2.0, true)
		for ray in 8:
			var direction := Vector2.from_angle(TAU * float(ray) / 8.0)
			draw_line(direction * radius * 0.28, direction * pulse_radius, Color(tint.r, tint.g, tint.b, progress * 0.48), 1.5, true)
	else:
		var fade := 1.0 - clampf((_elapsed - windup) / active_time, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, fade * 0.13))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(tint.r, tint.g, tint.b, fade), 6.0 * fade, true)
