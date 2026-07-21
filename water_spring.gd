class_name WaterSpring
extends Node2D

## Lightweight sample used by WaterBody. It intentionally owns no Area2D.

var velocity: float = 0.0
var force: float = 0.0
var height: float = 0.0
var target_height: float = 0.0
var index: int = 0


func initialize(x_position: float, id: int) -> void:
	position.x = x_position
	target_height = position.y
	height = position.y
	velocity = 0.0
	force = 0.0
	index = id


## Semi-implicit Euler integration. Coefficients are expressed per second, so
## the result does not depend on the physics tick rate.
func water_update(
	spring_constant: float,
	dampening: float,
	delta: float = 1.0 / 60.0
) -> void:
	var displacement := position.y - target_height
	force = -spring_constant * displacement - dampening * velocity
	velocity += force * delta
	position.y += velocity * delta
	height = position.y


func add_impulse(impulse: float) -> void:
	velocity += impulse


## Kept as a no-op for callers made against the old spring implementation.
func set_collision_width(_value: float) -> void:
	pass
