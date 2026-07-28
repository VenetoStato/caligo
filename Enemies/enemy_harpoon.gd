extends Area2D
## Rampino / arpione: proiettile lineare che tira il player verso l'origine.

const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")

var direction := Vector2.RIGHT
var speed := 220.0
var damage := 1
var lifetime := 1.1
var pull_strength := 420.0
var origin := Vector2.ZERO
var tint := Color(0.95, 0.78, 0.35, 1.0)
var _hit := false
var _length := 0.0


func setup(
	travel_direction: Vector2,
	projectile_speed: float,
	projectile_damage: int,
	from: Vector2,
	projectile_tint: Color = Color(0.95, 0.78, 0.35, 1.0),
	pull := 420.0
) -> void:
	direction = travel_direction.normalized()
	speed = projectile_speed
	damage = projectile_damage
	origin = from
	tint = projectile_tint
	pull_strength = pull


func _ready() -> void:
	add_to_group("enemy_transient_attack")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	z_index = 8
	queue_redraw()


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	global_position += direction * speed * delta
	_length = global_position.distance_to(origin)
	queue_redraw()


func _draw() -> void:
	var local_origin := to_local(origin)
	draw_line(local_origin, Vector2.ZERO, Color(tint.r, tint.g, tint.b, 0.55), 2.0, true)
	draw_circle(Vector2.ZERO, 5.5, tint)
	draw_circle(Vector2.ZERO, 2.2, Color(1.0, 0.95, 0.75, 0.95))


func _on_body_entered(body: Node2D) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	if body.has_method("take_damage"):
		body.call_deferred("take_damage", damage, global_position)
	if body is CharacterBody2D:
		var pull_dir := (origin - body.global_position).normalized()
		(body as CharacterBody2D).velocity = pull_dir * pull_strength + Vector2(0, -80)
	PARTICLE_BURST.spawn(get_tree().current_scene, global_position, tint, 8, -direction, 30.0, 90.0, 0.4)
	queue_free()
