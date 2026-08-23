extends Area2D

## Marea che il Custode richiama nella navata: sale dal pavimento e lo spazza
## da parete a parete. Non si schiva correndo, si schiva staccandosi da terra —
## per questo la volta e' piena di anelli a cui appendersi con la canna.

const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")

var span := Vector2(1060.0, 96.0)
var damage := 1
var windup := 1.15
var active_time := 1.05
var tint := Color(0.32, 0.78, 0.82, 1.0)

var _elapsed := 0.0
var _fired := false
var _damaged: Array[Node2D] = []
var _shape: RectangleShape2D


func setup(area_span: Vector2, attack_damage: int, attack_windup: float, attack_active: float) -> void:
	span = area_span
	damage = attack_damage
	windup = attack_windup
	active_time = attack_active


func _ready() -> void:
	add_to_group("enemy_transient_attack")
	add_to_group("boss_environment_attack")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	monitoring = false
	z_index = 7
	_shape = RectangleShape2D.new()
	_shape.size = span
	var collision := CollisionShape2D.new()
	collision.shape = _shape
	add_child(collision)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _fired and _elapsed >= windup:
		_fired = true
		monitoring = true
		PARTICLE_BURST.spawn(
			get_tree().current_scene,
			global_position,
			Color(tint.r, tint.g, tint.b, 0.8),
			30,
			Vector2.UP,
			70.0,
			220.0,
			0.85
		)
		var camera := get_tree().get_first_node_in_group("camera")
		if camera and camera.has_method("add_shake"):
			camera.call("add_shake", 0.5)
		call_deferred("_damage_overlaps")
	elif _fired and fmod(_elapsed, 0.3) < delta:
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
			if damage > 0 and body.has_method("take_damage"):
				body.call_deferred("take_damage", damage, global_position)


func _draw() -> void:
	var half := span * 0.5
	if not _fired:
		# Preavviso: la linea d'acqua si accende e sale. Il tempo di reazione
		# deve bastare a lanciare l'amo verso un anello.
		var progress := clampf(_elapsed / maxf(windup, 0.01), 0.0, 1.0)
		var height := span.y * progress
		draw_rect(
			Rect2(-half.x, half.y - height, span.x, height),
			Color(tint.r, tint.g, tint.b, 0.07 + progress * 0.14)
		)
		draw_line(
			Vector2(-half.x, half.y - height),
			Vector2(half.x, half.y - height),
			Color(tint.r, tint.g, tint.b, 0.4 + progress * 0.5),
			2.0 + progress * 2.0,
			true
		)
		return
	var fade := 1.0 - clampf((_elapsed - windup) / maxf(active_time, 0.01), 0.0, 1.0)
	draw_rect(Rect2(-half.x, -half.y, span.x, span.y), Color(tint.r, tint.g, tint.b, 0.22 * fade))
	var crest := PackedVector2Array()
	var steps := 40
	for index in steps + 1:
		var t := float(index) / float(steps)
		var x := lerpf(-half.x, half.x, t)
		var wave := sin(t * 26.0 + _elapsed * 12.0) * 5.0 + sin(t * 9.0 - _elapsed * 7.0) * 3.5
		crest.append(Vector2(x, -half.y + wave))
	draw_polyline(crest, Color(0.82, 0.96, 0.94, 0.85 * fade), 3.0, true)
	for index in steps:
		if index % 3 != 0:
			continue
		var point: Vector2 = crest[index]
		draw_circle(point + Vector2(0, -6.0 - fade * 5.0), 2.0 * fade, Color(0.9, 1.0, 0.96, 0.5 * fade))
