extends Node2D

# ===========================================
# FISH - Pesce che nuota e può essere pescato
# ===========================================
# Quando scappa dall'amo, torna a nuotare liberamente
# invece di sparire

@export_category("Movement")
@export var natural_swim_speed: float = 30.0
@export var attraction_speed: float = 60.0
@export var swim_change_interval: float = 2.0
@export var escape_speed: float = 120.0
@export var escape_duration: float = 2.0

@export_category("Swim Area")
## Area di nuoto orizzontale attorno alla casa
@export var swim_bounds_x: float = 160.0
## Area di nuoto verticale attorno alla casa
@export var swim_bounds_y: float = 60.0
## Offset della casa rispetto allo spawn (Y negativo = più su)
@export var home_offset: Vector2 = Vector2(0, -50)

@export_category("Physics")
@export var swim_response: float = 3.0
@export var water_damping: float = 0.98
@export var boundary_push: float = 80.0

@export_category("Struggle")
@export var struggle_strength: float = 200.0
@export var struggle_duration: float = 1.0
@export var reel_resistance: float = 0.7

@export_category("Visual")
## Colore normale del pesce
@export var normal_color: Color = Color(1, 1, 1, 1)
## Colore quando sta lottando
@export var struggle_color: Color = Color(1, 0.6, 0.6, 1)
## Colore quando scappa
@export var escape_color: Color = Color(0.8, 0.8, 1, 1)

# Riferimenti
var player_ref: Node = null
var target_hook: Node = null
var sprite: Node2D = null

# Stato movimento
var velocity: Vector2 = Vector2.ZERO
var swim_direction: Vector2 = Vector2.RIGHT
var swim_timer: float = 0.0
var home_position: Vector2 = Vector2.ZERO
var spawn_position: Vector2 = Vector2.ZERO

# Stato pesca
var in_water: bool = true
var is_hooked_to_player: bool = false
var is_attracted: bool = false
var attraction_target: Vector2 = Vector2.ZERO

# Stato lotta
var is_struggling: bool = false
var struggle_timer: float = 0.0
var struggle_direction: Vector2 = Vector2.ZERO

# Stato fuga (dopo essere scappato)
var is_escaping: bool = false
var escape_timer: float = 0.0
var escape_direction: Vector2 = Vector2.ZERO

# Forze esterne
var reel_force: Vector2 = Vector2.ZERO

# Cooldown per essere ri-agganciato
var hook_cooldown: float = 0.0
var hook_cooldown_time: float = 3.0

func _ready():
	add_to_group("fish")
	spawn_position = global_position
	home_position = global_position + home_offset
	_find_sprite()
	_setup_detection_area()
	_pick_new_swim_direction()

func _find_sprite():
	sprite = get_node_or_null("Fishes")
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if sprite == null:
		sprite = get_node_or_null("Sprite")

func _setup_detection_area():
	var existing_area = get_node_or_null("Area2D")
	var area: Area2D

	if existing_area == null:
		area = Area2D.new()
		area.name = "Area2D"
		add_child(area)

		var collision = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 25.0
		collision.shape = circle
		area.add_child(collision)
	else:
		area = existing_area

	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	if not area.area_entered.is_connected(_on_area_entered):
		area.area_entered.connect(_on_area_entered)
	if not area.area_exited.is_connected(_on_area_exited):
		area.area_exited.connect(_on_area_exited)

func _physics_process(delta: float):
	# Aggiorna cooldown
	if hook_cooldown > 0:
		hook_cooldown -= delta
	
	if in_water:
		if is_escaping:
			_process_escaping(delta)
		else:
			_process_swimming(delta)
	else:
		_process_falling(delta)

	global_position += velocity * delta
	_update_sprite_direction()
	_update_sprite_color()

func _process_swimming(delta: float):
	var desired = Vector2.ZERO

	if is_hooked_to_player:
		# Reel force (resistenza)
		if reel_force.length() > 0.0:
			desired += reel_force * reel_resistance
			reel_force = reel_force.lerp(Vector2.ZERO, delta * 3.0)

		# Struggle
		if is_struggling:
			struggle_timer -= delta
			if struggle_timer > 0.0:
				desired += struggle_direction * struggle_strength
			else:
				is_struggling = false

	elif is_attracted and attraction_target != Vector2.ZERO:
		var dir = (attraction_target - global_position).normalized()
		desired = dir * attraction_speed

		if global_position.distance_to(attraction_target) < 30.0:
			is_attracted = false
			_try_hook_to_player()

	else:
		# Nuoto normale
		swim_timer += delta
		if swim_timer >= swim_change_interval:
			swim_timer = 0.0
			_pick_new_swim_direction()

		desired = swim_direction * natural_swim_speed

	# Boundary steering
	var offset = global_position - home_position

	if offset.x > swim_bounds_x:
		desired.x -= boundary_push
	elif offset.x < -swim_bounds_x:
		desired.x += boundary_push

	if offset.y > swim_bounds_y:
		desired.y -= boundary_push
	elif offset.y < -swim_bounds_y:
		desired.y += boundary_push

	velocity = velocity.lerp(desired, delta * swim_response)
	velocity *= water_damping

func _process_escaping(delta: float):
	# Nuota velocemente nella direzione di fuga
	escape_timer -= delta
	
	var desired = escape_direction * escape_speed
	
	# Rallenta gradualmente
	var escape_progress = 1.0 - (escape_timer / escape_duration)
	desired = desired.lerp(Vector2.ZERO, escape_progress * 0.5)
	
	velocity = velocity.lerp(desired, delta * swim_response * 2.0)
	velocity *= water_damping
	
	if escape_timer <= 0:
		is_escaping = false
		# Aggiorna la home position alla nuova posizione
		home_position = global_position
		_pick_new_swim_direction()
		print("🐟 Pesce tornato a nuotare normalmente")

func _process_falling(delta: float):
	velocity.y += 980.0 * delta
	velocity.x *= 0.98

func _pick_new_swim_direction():
	var angle = randf() * TAU
	swim_direction = Vector2(cos(angle), sin(angle) * 0.35).normalized()

func _update_sprite_direction():
	if sprite == null:
		return

	if velocity.x > 1.0:
		sprite.scale.x = abs(sprite.scale.x)
	elif velocity.x < -1.0:
		sprite.scale.x = -abs(sprite.scale.x)

func _update_sprite_color():
	if sprite == null:
		return
	
	var target_color = normal_color
	
	if is_escaping:
		target_color = escape_color
	elif is_struggling:
		target_color = struggle_color
	elif is_hooked_to_player:
		target_color = normal_color.lerp(struggle_color, 0.3)
	
	sprite.modulate = sprite.modulate.lerp(target_color, 0.1)

func _try_hook_to_player():
	# Non può essere agganciato durante il cooldown
	if hook_cooldown > 0:
		return
	
	if player_ref != null:
		if player_ref.has_method("on_fish_hooked"):
			player_ref.call("on_fish_hooked", self)
		elif player_ref.has_method("on_fish_spawned"):
			player_ref.call("on_fish_spawned", self)
		is_hooked_to_player = true
		print("🎣 Pesce agganciato!")

# ===========================================
# COLLISION
# ===========================================
func _on_body_entered(body: Node2D):
	if is_hooked_to_player or is_escaping or hook_cooldown > 0:
		return

	if body is RigidBody2D:
		if body.has_method("get_line_attach_point") or "hook" in body.name.to_lower():
			_on_hook_detected(body)

func _on_area_entered(area: Area2D):
	if is_hooked_to_player or is_escaping or hook_cooldown > 0:
		return

	var an = area.name.to_lower()
	var pn = area.get_parent().name.to_lower() if area.get_parent() else ""
	if "water" in an or "water" in pn or area.is_in_group("water"):
		in_water = true
		return

	var parent = area.get_parent()
	if parent != null:
		if parent is RigidBody2D or parent.has_method("get_line_attach_point"):
			_on_hook_detected(parent)

func _on_area_exited(area: Area2D):
	var an = area.name.to_lower()
	var pn = area.get_parent().name.to_lower() if area.get_parent() else ""
	if "water" in an or "water" in pn or area.is_in_group("water"):
		in_water = false

func _on_hook_detected(hook: Node):
	# Non reagire se in cooldown o già agganciato
	if hook_cooldown > 0 or is_hooked_to_player or is_escaping:
		return
	
	target_hook = hook

	if hook.has_method("get_player_reference"):
		player_ref = hook.call("get_player_reference")
	elif "player_ref" in hook:
		player_ref = hook.player_ref

	attract_to(hook.global_position)

# ===========================================
# RELEASE - Chiamato quando il pesce scappa
# ===========================================
func release_from_hook():
	print("🐟 Pesce liberato! Scappa via...")
	
	is_hooked_to_player = false
	is_attracted = false
	is_struggling = false
	struggle_timer = 0.0
	reel_force = Vector2.ZERO
	player_ref = null
	target_hook = null
	
	# Inizia la fuga
	is_escaping = true
	escape_timer = escape_duration
	
	# Direzione di fuga: opposta al player o random
	if player_ref and is_instance_valid(player_ref):
		escape_direction = (global_position - player_ref.global_position).normalized()
	else:
		var angle = randf() * TAU
		escape_direction = Vector2(cos(angle), sin(angle) * 0.5).normalized()
	
	# Aggiungi una componente verticale casuale
	escape_direction.y += randf_range(-0.3, 0.3)
	escape_direction = escape_direction.normalized()
	
	# Imposta cooldown per non essere ri-agganciato subito
	hook_cooldown = hook_cooldown_time
	
	# Dai una spinta iniziale
	velocity = escape_direction * escape_speed * 0.8

# ===========================================
# API
# ===========================================
func set_player_reference(player: Node):
	player_ref = player
	is_hooked_to_player = true
	is_attracted = false
	is_escaping = false

func attract_to(target_pos: Vector2):
	if hook_cooldown > 0 or is_escaping:
		return
	attraction_target = target_pos
	is_attracted = true

func apply_reel_force(force: Vector2):
	reel_force = force

func apply_struggle_force(force: Vector2):
	# Forza applicata dal player durante lo struggle
	if is_hooked_to_player:
		velocity += force

func start_struggle():
	is_struggling = true
	struggle_timer = struggle_duration
	var angle = randf() * TAU
	struggle_direction = Vector2(cos(angle), sin(angle)).normalized()
	print("🐟 Il pesce lotta!")

func stop_struggle():
	is_struggling = false
	struggle_timer = 0.0

func is_hooked() -> bool:
	return is_hooked_to_player

func is_in_water() -> bool:
	return in_water

func set_in_water(water: bool):
	in_water = water

func is_available_for_hook() -> bool:
	return not is_hooked_to_player and not is_escaping and hook_cooldown <= 0

# ===========================================
# DEBUG
# ===========================================
func get_status() -> String:
	if is_hooked_to_player:
		if is_struggling:
			return "LOTTA"
		return "AGGANCIATO"
	if is_escaping:
		return "SCAPPA"
	if is_attracted:
		return "ATTRATTO"
	if hook_cooldown > 0:
		return "COOLDOWN"
	return "NUOTA"
