extends RigidBody2D

# Entità "ship moving" (pilotabile) - premendo E esci e torni alla barca still + player.

@export_category("Movement")
@export var move_force: float = 3500.0
@export var max_speed: float = 220.0
@export var drag: float = 0.98

@export_category("Buoyancy")
@export var float_offset: float = 52.0
@export var buoyancy_strength: float = 35.0
@export var max_up_force: float = 2500.0
@export var water_drag: float = 0.96
@export var surface_margin: float = 30.0

@export_category("Interaction")
@export var interaction_action: StringName = &"interact"

var _cached_water: Node = null
var _player: Node2D = null
var _boat_still: Node = null
var _water_particles: CPUParticles2D = null

func _ready():
	add_to_group("ship_moving")
	add_to_group("player") # così i sistemi che cercano il player lo trovano comunque
	lock_rotation = true
	gravity_scale = 1.0
	# Animazione: parte solo quando ci si muove (vedi _physics_process)
	var ap: AnimationPlayer = get_node_or_null("ShipMoving/AnimationPlayer")
	if ap != null and ap.has_animation("RESET"):
		ap.play("RESET")
	# Dietro l'acqua
	var spr := get_node_or_null("ShipMoving") as Sprite2D
	if spr != null:
		spr.z_index = 0
	_water_particles = get_node_or_null("WaterParticles") as CPUParticles2D

func setup(player: Node2D, boat_still: Node):
	_player = player
	_boat_still = boat_still

func _unhandled_input(event):
	if event.is_action_pressed(interaction_action):
		_exit_ship()

func _physics_process(delta: float):
	lock_rotation = true
	rotation = 0.0
	_apply_buoyancy()
	_apply_movement(delta)
	_update_sprite_direction()
	_update_animation()
	_update_water_particles()

func _apply_movement(delta: float):
	# Muove solo se è in acqua
	if not _is_in_water():
		linear_velocity *= drag
		return
	var axis = 0.0
	if Input.is_action_pressed("ui_left"):
		axis -= 1.0
	if Input.is_action_pressed("ui_right"):
		axis += 1.0
	if axis != 0.0:
		linear_velocity.x += axis * move_force * delta
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
	linear_velocity *= drag

func _is_in_water() -> bool:
	var water = _get_water()
	if water == null:
		return false
	var surface_y_v = _get_water_surface_y(water)
	if surface_y_v == null:
		return true
	var surface_y: float = float(surface_y_v)
	# Considera "in acqua" se siamo vicini alla superficie (non serve essere in bodies_in_water)
	var dy = global_position.y - surface_y
	return dy >= -surface_margin and dy <= 800.0

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

func _update_animation():
	var ap: AnimationPlayer = get_node_or_null("ShipMoving/AnimationPlayer")
	if ap == null:
		return
	var speed = abs(linear_velocity.x)
	if speed > 12.0:
		if ap.current_animation != "moving":
			ap.play("moving")
	else:
		if ap.current_animation != "RESET":
			ap.play("RESET")

func _update_water_particles():
	if _water_particles == null:
		return
	var speed = linear_velocity.length()
	if speed > 6.0:
		_water_particles.emitting = true
		# Direzione particelle: dietro la barca (opposta al movimento)
		var dir = -linear_velocity.normalized()
		_water_particles.direction = dir if dir.length() > 0.1 else Vector2.LEFT
		_water_particles.spread = 45.0
		_water_particles.initial_velocity_min = speed * 0.15
		_water_particles.initial_velocity_max = speed * 0.35
	else:
		_water_particles.emitting = false

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
	# Ripristina Camera2D, PostFX, ecc. al player PRIMA di queue_free (altrimenti vengono distrutti)
	if _player != null and is_instance_valid(_player):
		for c in get_children():
			var name_lower = c.name.to_lower()
			if name_lower == "camera2d" or name_lower == "postfx" or "pointlight" in name_lower or name_lower == "overlay":
				remove_child(c)
				_player.add_child(c)
	var pos = global_position
	if _boat_still != null and is_instance_valid(_boat_still) and _boat_still.has_method("exit_from_moving"):
		_boat_still.call("exit_from_moving", _player, pos)
	queue_free()

func _get_water() -> Node:
	var waters = get_tree().get_nodes_in_group("water")
	if waters.size() == 0:
		var scene = get_tree().current_scene
		if scene == null:
			return null
		var found = _find_water_recursive(scene)
		return found
	# Scegli l'acqua in cui siamo (bounds X contengono la barca), altrimenti la più vicina
	var my_x: float = global_position.x
	for w in waters:
		if w == null or not is_instance_valid(w):
			continue
		if not w.has_method("get_water_bounds_global_x"):
			continue
		var bounds: Vector2 = w.call("get_water_bounds_global_x")
		if my_x >= bounds.x and my_x <= bounds.y:
			_cached_water = w
			return w
	# Nessuna acqua ci contiene: usa la più vicina per X (evita blocchi quando ti sposti)
	var best: Node = null
	var best_dist: float = INF
	for w in waters:
		if w == null or not is_instance_valid(w):
			continue
		if not w.has_method("get_water_bounds_global_x"):
			continue
		var bounds: Vector2 = w.call("get_water_bounds_global_x")
		var mid: float = (bounds.x + bounds.y) * 0.5
		var d: float = abs(my_x - mid)
		if d < best_dist:
			best_dist = d
			best = w
	_cached_water = best
	return best

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

