extends RigidBody2D

# ===========================================
# HOOK SCRIPT - Con punto di attacco lenza configurabile
# ===========================================
# Lo sprite ruota intorno al punto di attacco della lenza
#
# STRUTTURA SCENA CONSIGLIATA:
# Hook (RigidBody2D) <- questo script
# ├── CollisionShape2D
# └── Sprite2D (o qualsiasi nome)

@export_category("Line Attachment Point")
## PUNTO DI ATTACCO LENZA - Offset rispetto al centro del RigidBody2D
## Se c'è un PointLight2D nella scena, questo offset viene ignorato e si usa il PointLight2D
## Valori positivi Y = sopra, negativi Y = sotto
## Valori positivi X = destra, negativi X = sinistra
@export var line_attach_offset: Vector2 = Vector2(0, 0)
## Se true, usa il PointLight2D come punto di attacco (se presente)
@export var use_point_light_as_attach: bool = true

@export_category("Sprite Setup")
## Nome del nodo sprite (lasciare vuoto per ricerca automatica)
@export var sprite_node_name: String = ""
## Offset dello sprite dal centro del RigidBody2D (per centrare visivamente)
@export var sprite_offset: Vector2 = Vector2(0, 0)

@export_category("Water Physics")
@export var water_gravity_scale: float = 0.1
@export var water_drag: float = 3.0

@export_category("Hook Behavior")
## Se true, l'hook si orienta nella direzione del movimento
@export var rotate_with_velocity: bool = true
## Se true, quando attaccato alla lenza lo sprite ruota verso il punto di attacco
@export var rotate_around_attach_point: bool = true

# Riferimenti
var player_ref: Node = null
var sprite: Node2D = null
var point_light: PointLight2D = null  # Punto di attacco fisso della lenza

# Stato
var in_water: bool = false
var hook_type: String = "fishing"  # "fishing" o "grab"
var is_anchored: bool = false
var original_gravity_scale: float = 1.0

func _ready():
	original_gravity_scale = gravity_scale
	
	# Trova lo sprite
	_find_sprite()
	_find_point_light()
	
	# Imposta lo sprite offset solo se non c'è PointLight2D
	if sprite != null and point_light == null:
		sprite.position = sprite_offset
	elif sprite != null and point_light != null:
		# Se c'è PointLight2D, lo sprite dovrebbe essere centrato su di esso
		pass
	
	# Assicura che lo sprite sia visibile
	if sprite != null:
		sprite.visible = true
		print("Hook: Sprite trovato e reso visibile: ", sprite.name)
	else:
		print("Hook: ATTENZIONE - Sprite non trovato!")
	
	contact_monitor = true
	max_contacts_reported = 4

func _find_sprite():
	if sprite_node_name != "":
		sprite = get_node_or_null(sprite_node_name)
	
	if sprite == null:
		# Cerca automaticamente
		for child in get_children():
			if child is Sprite2D or child is AnimatedSprite2D:
				sprite = child
				break
	
	if sprite != null:
		sprite.visible = true

func _find_point_light():
	if use_point_light_as_attach:
		point_light = get_node_or_null("PointLight2D")
		if point_light == null:
			# Cerca ricorsivamente
			for child in get_children():
				if child is PointLight2D:
					point_light = child
					break
		
		if point_light != null:
			print("Hook: PointLight2D trovato come punto di attacco: ", point_light.position)
			# Imposta il center_of_mass al PointLight2D per la rotazione
			center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
			center_of_mass = point_light.position
			# Assicura che il PointLight2D sia centrato (0,0) se non lo è già
			if point_light.position.length() > 1.0:
				print("Hook: ATTENZIONE - PointLight2D non è centrato! Posizione: ", point_light.position)
		else:
			print("Hook: PointLight2D non trovato, uso line_attach_offset")
			# Se non c'è PointLight2D, usa il centro dello sprite come fallback
			if sprite != null:
				line_attach_offset = sprite.position
				print("Hook: Usando sprite position come offset: ", line_attach_offset)

func _physics_process(delta: float):
	if in_water and not is_anchored:
		linear_velocity *= (1.0 - water_drag * delta)
	
	# Ruota lo sprite in base alla velocità o alla direzione della lenza
	_update_sprite_rotation()

func _update_sprite_rotation():
	if sprite == null:
		return
	
	if is_anchored:
		# Se ancorato, non ruotare
		return
	
	if rotate_with_velocity and linear_velocity.length() > 10:
		# Ruota nella direzione del movimento
		var angle = linear_velocity.angle()
		sprite.rotation = angle + PI/2  # +90° perché di solito gli sprite puntano verso l'alto

# ===========================================
# PUNTO DI ATTACCO LENZA
# ===========================================
func get_line_attach_point() -> Vector2:
	# Se c'è un PointLight2D, usa sempre la sua posizione globale (punto fisso)
	if point_light != null:
		return point_light.global_position
	
	# Altrimenti usa l'offset ruotato
	return global_position + line_attach_offset.rotated(rotation)

func set_line_attach_offset(offset: Vector2):
	line_attach_offset = offset
	# Se c'è PointLight2D, aggiorna anche il center_of_mass
	if point_light != null:
		center_of_mass = point_light.position

# Ruota lo sprite per "guardare" verso un punto (es. la canna da pesca)
func orient_to_line(line_origin: Vector2):
	if sprite == null or not rotate_around_attach_point:
		return
	
	var attach_point = get_line_attach_point()
	var direction = (line_origin - attach_point).normalized()
	
	# Calcola l'angolo e ruota lo sprite
	var angle = direction.angle()
	sprite.rotation = angle + PI/2  # Aggiusta in base all'orientamento dello sprite

# ===========================================
# WATER DETECTION
# ===========================================
func _enter_water():
	if not in_water:
		in_water = true
		gravity_scale = original_gravity_scale * water_gravity_scale
		linear_damp = water_drag

func _exit_water():
	if in_water:
		in_water = false
		gravity_scale = original_gravity_scale
		linear_damp = 0.0

func is_in_water() -> bool:
	return in_water

# ===========================================
# API PER IL PLAYER
# ===========================================
func set_hook_type(type: String):
	hook_type = type

func set_player_reference(player: Node):
	player_ref = player

func get_player_reference() -> Node:
	return player_ref

func anchorize():
	is_anchored = !is_anchored
	freeze = is_anchored

func hide_for_fish():
	if sprite != null:
		sprite.visible = false

func show_hook():
	if sprite != null:
		sprite.visible = true

# ===========================================
# SEGNALI PER WATER DETECTION (opzionale)
# ===========================================
func _on_area_entered(area: Area2D):
	var area_name = area.name.to_lower()
	var parent_name = area.get_parent().name.to_lower() if area.get_parent() else ""
	
	if "water" in area_name or "water" in parent_name or area.is_in_group("water"):
		_enter_water()

func _on_area_exited(area: Area2D):
	var area_name = area.name.to_lower()
	var parent_name = area.get_parent().name.to_lower() if area.get_parent() else ""
	
	if "water" in area_name or "water" in parent_name or area.is_in_group("water"):
		_exit_water()
