extends Node2D

# Spring per simulazione acqua - versione originale tutorial convertita per Godot 4
# Basato su: C:\Users\Utente\Downloads\Water_Tutorial\Water_Tutorial\Scenes\Water_Spring.gd

var velocity: float = 0.0
var force: float = 0.0
var height: float = 0.0
var target_height: float = 0.0
var index: int = 0
var motion_factor: float = 0.015
var collided_with: Node = null

signal splash(index: int, speed: float)

func water_update(spring_constant: float, dampening: float):
	# Hooke's law: F = -K * x (come nel tutorial originale)
	height = position.y
	var x = height - target_height
	var loss = -dampening * velocity
	force = -spring_constant * x + loss
	velocity += force
	position.y += velocity

func initialize(x_position: float, id: int):
	# Come nel tutorial originale
	height = position.y
	target_height = position.y
	velocity = 0.0
	position.x = x_position
	index = id

func set_collision_width(value: float):
	# Come nel tutorial originale, ma adattato per Godot 4
	var area = get_node_or_null("Area2D")
	if area == null:
		return
	
	var collision = area.get_node_or_null("CollisionShape2D")
	if collision == null or collision.shape == null:
		return
	
	# Godot 4: usa size invece di extents
	if collision.shape is RectangleShape2D:
		var rect = collision.shape as RectangleShape2D
		var new_size = Vector2(value, rect.size.y)
		rect.size = new_size

func _on_Area2D_body_entered(body: Node2D):
	# Come nel tutorial originale, ma adattato per Godot 4
	if body == collided_with:
		return
	
	collided_with = body
	
	# Godot 4: CharacterBody2D usa velocity invece di motion
	var speed: float = 0.0
	if body is RigidBody2D:
		speed = body.linear_velocity.y * motion_factor
	elif body is CharacterBody2D:
		speed = body.velocity.y * motion_factor
	
	emit_signal("splash", index, speed)
