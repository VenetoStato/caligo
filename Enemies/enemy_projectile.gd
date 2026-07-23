extends Area2D

const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")

var direction := Vector2.RIGHT
var speed := 135.0
var damage := 1
var lifetime := 3.0
var radius := 6.0
var tint := Color(0.26, 0.94, 0.8, 1.0)
var _trail: Array[Vector2] = []
var _hit := false


func setup(
	travel_direction: Vector2,
	projectile_speed: float,
	projectile_damage: int,
	projectile_tint: Color,
	projectile_radius := 6.0,
	projectile_lifetime := 3.0
) -> void:
	direction = travel_direction.normalized()
	speed = projectile_speed
	damage = projectile_damage
	tint = projectile_tint
	radius = projectile_radius
	lifetime = projectile_lifetime


func _ready() -> void:
	add_to_group("enemy_transient_attack")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	z_index = 7
	queue_redraw()


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var next_position := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next_position, 1)
	query.exclude = [get_rid()]
	var terrain_hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not terrain_hit.is_empty():
		_spawn_impact(terrain_hit.position as Vector2, -direction)
		queue_free()
		return
	global_position = next_position
	_trail.push_front(Vector2.ZERO)
	for index in range(1, _trail.size()):
		_trail[index] -= direction * speed * delta
	if _trail.size() > 6:
		_trail.pop_back()
	queue_redraw()


func _draw() -> void:
	for index in range(_trail.size() - 1, -1, -1):
		var alpha := (1.0 - float(index) / maxf(1.0, _trail.size())) * 0.28
		draw_circle(_trail[index], radius * (0.35 + alpha), Color(tint.r, tint.g, tint.b, alpha))
	draw_circle(Vector2.ZERO, radius * 1.7, Color(tint.r, tint.g, tint.b, 0.14))
	draw_circle(Vector2.ZERO, radius, tint)
	draw_circle(-direction * radius * 0.25, radius * 0.32, Color(0.94, 1.0, 0.83, 0.9))


func _on_body_entered(body: Node2D) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	if body.has_method("take_damage"):
		body.call_deferred("take_damage", damage, global_position)
	_spawn_impact(global_position, -direction)
	queue_free()


func _spawn_impact(at: Vector2, normal: Vector2) -> void:
	PARTICLE_BURST.spawn(
		get_tree().current_scene,
		at,
		Color(tint.r, tint.g, tint.b, 0.86),
		7,
		normal,
		25.0,
		80.0,
		0.48
	)
