extends Node2D

var velocity: Vector2 = Vector2.ZERO
var player_ref: Node = null
var in_water: bool = false
var anim_player: AnimationPlayer = null

func hide_for_fish():
	visible = false

func _ready():
	anim_player = get_node_or_null("pastura/AnimationPlayer")
	if anim_player == null:
		# Cerca in altri posti
		anim_player = find_child("AnimationPlayer", true, false)

func set_velocity(vel: Vector2):
	velocity = vel

func get_velocity() -> Vector2:
	return velocity

# Restituisce la posizione globale del punto di attacco della lenza (centro visivo)
func get_line_attach_point() -> Vector2:
	var sprite = get_node_or_null("pastura") as Sprite2D
	if sprite != null:
		# Il centro dello sprite è la sua posizione globale
		return sprite.global_position
	
	# Fallback: usa la posizione globale del nodo
	return global_position

func set_player_reference(player: Node):
	player_ref = player

func get_player_ref() -> Node:
	return player_ref

func _physics_process(delta: float):
	# Movimento della pastura con gravità
	if velocity.length() > 0:
		if not in_water:
			velocity.y += 980.0 * delta  # gravità normale
		else:
			# In acqua: gravità ridotta (scende lentamente)
			velocity.y += 98.0 * delta  # 10% della gravità normale
			velocity.y = velocity.y * 0.95  # resistenza acqua
		global_position += velocity * delta
		velocity.x = velocity.x * 0.98  # attrito orizzontale
	
	# Controlla se è in una zona water
	var was_in_water = in_water
	check_water_zones()
	
	# Se entra in acqua per la prima volta, cambia animazione
	if in_water and not was_in_water:
		play_water_animation()

func play_cast_animation():
	if anim_player != null and anim_player.has_animation("pastura_lancio"):
		anim_player.play("pastura_lancio")

func play_water_animation():
	if anim_player != null and anim_player.has_animation("pastura_acqua"):
		anim_player.play("pastura_acqua")

func check_water_zones():
	# Usa l'Area2D della pastura per rilevare collisioni con zone water
	var area = get_node_or_null("Area2D")
	if area == null:
		return
	
	# Controlla se l'Area2D della pastura è dentro una zona water
	var overlapping_areas = area.get_overlapping_areas()
	var found_water = false
	for water_zone in overlapping_areas:
		# Controlla il nome dell'Area2D o del parent
		var zone_name = water_zone.name.to_lower()
		var parent_name = ""
		if water_zone.get_parent() != null:
			parent_name = water_zone.get_parent().name.to_lower()
		
		if "water" in zone_name or "water" in parent_name:
			found_water = true
			if not in_water:
				in_water = true
			# I pesci si avvicinano automaticamente (gestito da water_area.gd)
			return
	
	# Controlla anche per posizione usando i nodi nella scena
	if not found_water:
		var scene = get_tree().current_scene
		if scene != null:
			var water_zones = []
			_find_water_zones(scene, water_zones)
			
			for zone in water_zones:
				if zone is Area2D:
					var shape = zone.get_node_or_null("CollisionShape2D")
					if shape != null and shape.shape != null:
						var shape_rect = _get_shape_rect(shape)
						if shape_rect.has_point(global_position):
							found_water = true
							if not in_water:
								in_water = true
							return
	
	if not found_water:
		in_water = false

func set_in_water(value: bool):
	# Metodo chiamato da water_body.gd per sincronizzare lo stato
	in_water = value

func _find_water_zones(node: Node, zones: Array):
	if node.name.to_lower().contains("water"):
		if node is Area2D:
			zones.append(node)
	
	for child in node.get_children():
		_find_water_zones(child, zones)

func _get_shape_rect(shape_node: CollisionShape2D) -> Rect2:
	if shape_node.shape is RectangleShape2D:
		var rect_shape = shape_node.shape as RectangleShape2D
		var pos = shape_node.global_position
		var size = rect_shape.size * shape_node.scale
		return Rect2(pos - size/2, size)
	elif shape_node.shape is CircleShape2D:
		var circle_shape = shape_node.shape as CircleShape2D
		var pos = shape_node.global_position
		var radius = circle_shape.radius * max(shape_node.scale.x, shape_node.scale.y)
		return Rect2(pos - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
	return Rect2()

# La funzione spawn_fish è stata rimossa - i pesci vengono spawnati dalle zone water
