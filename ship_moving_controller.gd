extends RigidBody2D

# Entità "ship moving" (pilotabile) - premendo E esci e torni alla barca still + player.

@export_category("Movement")
@export var move_force: float = 1200.0
@export var max_speed: float = 180.0
@export var drag: float = 0.96

@export_category("Buoyancy")
@export var float_offset: float = 8.0
@export var buoyancy_strength: float = 35.0
@export var max_up_force: float = 2500.0
@export var water_drag: float = 0.96
@export var surface_margin: float = 30.0

@export_category("Interaction")
@export var interaction_action: StringName = &"interact"

var _cached_water: Node = null
var _player: Node2D = null
var _boat_still: Node = null

func _ready():
	add_to_group("ship_moving")
	add_to_group("player") # così i sistemi che cercano il player lo trovano comunque
	lock_rotation = true
	gravity_scale = 1.0

	# prova ad avviare animazione
	var ap: AnimationPlayer = get_node_or_null("ShipMoving/AnimationPlayer")
	if ap != null and ap.has_animation("moving"):
		ap.play("moving")
	# Dietro l'acqua
	var spr := get_node_or_null("ShipMoving") as Sprite2D
	if spr != null:
		spr.z_index = 0

func setup(player: Node2D, boat_still: Node):
	_player = player
	_boat_still = boat_still

func _unhandled_input(event):
	if event.is_action_pressed(interaction_action):
		_exit_ship()

func _physics_process(_delta: float):
	lock_rotation = true
	rotation = 0.0
	_apply_buoyancy()
	_apply_movement()
	_update_sprite_direction()

func _apply_movement():
	var axis = Input.get_axis("ui_left", "ui_right")
	if axis != 0.0:
		apply_central_force(Vector2(axis * move_force, 0))
	# clamp speed
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
	linear_velocity *= drag

func _update_sprite_direction():
	var spr := get_node_or_null("ShipMoving") as Sprite2D
	if spr == null:
		return
	
	# Flip dello sprite basato sulla direzione di movimento
	if linear_velocity.x > 1.0:
		# Si muove a destra -> sprite normale (scale.x positivo)
		spr.scale.x = abs(spr.scale.x)
	elif linear_velocity.x < -1.0:
		# Si muove a sinistra -> flip dello sprite (scale.x negativo)
		spr.scale.x = -abs(spr.scale.x)

func _apply_buoyancy():
	var water = _get_water()
	if water == null:
		return
	var surface_y_v = _get_water_surface_y(water)
	if surface_y_v == null:
		return
	var surface_y := float(surface_y_v)
	var target_y = surface_y - float_offset
	var dy = global_position.y - target_y
	if dy < -surface_margin:
		return
	var force = clamp(dy * buoyancy_strength, -max_up_force, max_up_force)
	apply_central_force(Vector2(0, -force))
	linear_velocity *= water_drag

func _exit_ship():
	var pos = global_position
	if _boat_still != null and is_instance_valid(_boat_still) and _boat_still.has_method("exit_from_moving"):
		_boat_still.call("exit_from_moving", _player, pos)
	queue_free()

func _get_water() -> Node:
	if _cached_water != null and is_instance_valid(_cached_water):
		return _cached_water
	var waters = get_tree().get_nodes_in_group("water")
	if waters.size() > 0:
		_cached_water = waters[0]
		return _cached_water
	var scene = get_tree().current_scene
	if scene == null:
		return null
	var found = _find_water_recursive(scene)
	_cached_water = found
	return found

func _find_water_recursive(n: Node) -> Node:
	if n is Area2D and "water" in n.name.to_lower():
		return n
	for c in n.get_children():
		var r = _find_water_recursive(c)
		if r != null:
			return r
	return null

func _get_water_surface_y(water: Node) -> Variant:
	if not ("target_height" in water):
		return null
	var surface_y = water.global_position.y + float(water.target_height)
	if "springs" in water and water.springs is Array and water.springs.size() > 0:
		var closest = water.springs[0]
		var best = abs(closest.global_position.x - global_position.x)
		for s in water.springs:
			if s == null or not is_instance_valid(s):
				continue
			var d = abs(s.global_position.x - global_position.x)
			if d < best:
				best = d
				closest = s
		if closest != null and is_instance_valid(closest):
			surface_y = closest.global_position.y
	return surface_y

