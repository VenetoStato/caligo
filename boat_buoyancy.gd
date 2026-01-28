extends RigidBody2D

# Barca RigidBody2D: galleggia usando la superficie calcolata dal water_body.gd

@export_category("Buoyancy")
@export var float_offset: float = 8.0            # quanto sopra la superficie stare
@export var buoyancy_strength: float = 35.0      # forza molla verso la superficie
@export var max_up_force: float = 2500.0         # clamp forza
@export var water_drag: float = 0.96             # drag quando vicino/sopra acqua
@export var surface_margin: float = 30.0         # considerata "in acqua" se entro questo margine

var _cached_water: Node = null

func _ready():
	add_to_group("ship")
	lock_rotation = true
	gravity_scale = 1.0

func _physics_process(_delta: float):
	lock_rotation = true
	rotation = 0.0
	
	var water = _get_water()
	if water == null:
		return
	
	var surface_y = _get_water_surface_y(water)
	if surface_y == null:
		return
	
	# vogliamo che la barca stia un filo sopra la superficie
	var target_y = float(surface_y) - float_offset
	var dy = global_position.y - target_y
	
	# Se è troppo sopra, non spingere
	if dy < -surface_margin:
		return
	
	# Forza tipo molla: più è sotto, più spinge su
	var force = clamp(dy * buoyancy_strength, -max_up_force, max_up_force)
	apply_central_force(Vector2(0, -force))
	
	# Drag (smorza oscillazioni)
	linear_velocity *= water_drag

func _get_water() -> Node:
	if _cached_water != null and is_instance_valid(_cached_water):
		return _cached_water
	
	# Preferisci water in gruppo "water"
	var waters = get_tree().get_nodes_in_group("water")
	if waters.size() > 0:
		_cached_water = waters[0]
		return _cached_water
	
	# Fallback: cerca Area2D con "Water" nel nome
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
	# water_body.gd ha variabile target_height e array springs
	if not ("target_height" in water):
		return null
	
	var surface_y = water.global_position.y + float(water.target_height)
	
	# Se ha springs, usa il più vicino per x (come water_body.gd)
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
