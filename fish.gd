extends Node2D

# ===========================================
# FISH - Pesce che nuota e può essere pescato
# ===========================================

@export_category("Movement")
@export var natural_swim_speed: float = 30.0
@export var attraction_speed: float = 60.0
@export var swim_change_interval: float = 2.0

@export_category("Struggle")
@export var struggle_strength: float = 200.0
@export var struggle_duration: float = 1.0
@export var reel_resistance: float = 0.7

# Riferimenti
var player_ref: Node = null
var target_hook: Node = null
var sprite: Node2D = null

# Stato movimento
var velocity: Vector2 = Vector2.ZERO
var swim_direction: Vector2 = Vector2.ZERO
var swim_timer: float = 0.0
var home_position: Vector2 = Vector2.ZERO

# Stato pesca
var in_water: bool = true
var is_hooked_to_player: bool = false
var is_attracted: bool = false
var attraction_target: Vector2 = Vector2.ZERO

# Stato lotta
var is_struggling: bool = false
var struggle_timer: float = 0.0
var struggle_direction: Vector2 = Vector2.ZERO

# Forze esterne
var reel_force: Vector2 = Vector2.ZERO

func _ready():
	home_position = global_position
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
	if existing_area == null:
		var area = Area2D.new()
		area.name = "Area2D"
		add_child(area)
		
		var collision = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 25.0
		collision.shape = circle
		area.add_child(collision)
		
		area.body_entered.connect(_on_body_entered)
		area.area_entered.connect(_on_area_entered)
	else:
		if not existing_area.body_entered.is_connected(_on_body_entered):
			existing_area.body_entered.connect(_on_body_entered)
		if not existing_area.area_entered.is_connected(_on_area_entered):
			existing_area.area_entered.connect(_on_area_entered)

func _physics_process(delta: float):
	if in_water:
		_process_swimming(delta)
	else:
		_process_falling(delta)
	
	global_position += velocity * delta
	_update_sprite_direction()

func _process_swimming(delta: float):
	var total_force = Vector2.ZERO
	
	if is_hooked_to_player:
		if reel_force.length() > 0:
			total_force += reel_force * reel_resistance
			reel_force = reel_force.lerp(Vector2.ZERO, delta * 3.0)
		
		if is_struggling:
			struggle_timer -= delta
			if struggle_timer > 0:
				total_force += struggle_direction * struggle_strength
			else:
				is_struggling = false
	
	elif is_attracted and attraction_target != Vector2.ZERO:
		var dir = (attraction_target - global_position).normalized()
		total_force = dir * attraction_speed
		
		if global_position.distance_to(attraction_target) < 30.0:
			is_attracted = false
			_try_hook_to_player()
	
	elif not is_hooked_to_player:
		swim_timer += delta
		if swim_timer >= swim_change_interval:
			swim_timer = 0.0
			_pick_new_swim_direction()
		
		total_force = swim_direction * natural_swim_speed
		
		var dist_from_home = global_position.distance_to(home_position)
		if dist_from_home > 150.0:
			var return_dir = (home_position - global_position).normalized()
			total_force += return_dir * natural_swim_speed * 0.5
	
	velocity = velocity.lerp(total_force, delta * 3.0)
	velocity *= 0.98

func _process_falling(delta: float):
	velocity.y += 980.0 * delta
	velocity.x *= 0.98

func _pick_new_swim_direction():
	var angle = randf() * TAU
	swim_direction = Vector2(cos(angle), sin(angle) * 0.3)

func _update_sprite_direction():
	if sprite == null:
		return
	
	if velocity.x > 1.0:
		sprite.scale.x = abs(sprite.scale.x)
	elif velocity.x < -1.0:
		sprite.scale.x = -abs(sprite.scale.x)

func _try_hook_to_player():
	if player_ref != null:
		if player_ref.has_method("on_fish_hooked"):
			player_ref.call("on_fish_hooked", self)
		elif player_ref.has_method("on_fish_spawned"):
			player_ref.call("on_fish_spawned", self)
		is_hooked_to_player = true

# ===========================================
# COLLISION
# ===========================================
func _on_body_entered(body: Node2D):
	if is_hooked_to_player:
		return
	
	if body is RigidBody2D:
		if body.has_method("get_line_attach_point") or "hook" in body.name.to_lower():
			_on_hook_detected(body)

func _on_area_entered(area: Area2D):
	if is_hooked_to_player:
		return
	
	var parent = area.get_parent()
	if parent != null:
		if parent is RigidBody2D or parent.has_method("get_line_attach_point"):
			_on_hook_detected(parent)

func _on_hook_detected(hook: Node):
	target_hook = hook
	
	if hook.has_method("get_player_reference"):
		player_ref = hook.call("get_player_reference")
	elif "player_ref" in hook:
		player_ref = hook.player_ref
	
	attract_to(hook.global_position)

# ===========================================
# API
# ===========================================
func set_player_reference(player: Node):
	player_ref = player
	is_hooked_to_player = true
	is_attracted = false

func attract_to(target_pos: Vector2):
	attraction_target = target_pos
	is_attracted = true

func apply_attraction_force(force: Vector2):
	velocity += force * 0.1

func apply_reel_force(force: Vector2):
	reel_force = force

func start_struggle():
	is_struggling = true
	struggle_timer = struggle_duration
	var angle = randf() * TAU
	struggle_direction = Vector2(cos(angle), sin(angle))

func stop_struggle():
	is_struggling = false
	struggle_timer = 0.0

func is_hooked() -> bool:
	return is_hooked_to_player

func is_in_water() -> bool:
	return in_water

func get_velocity() -> Vector2:
	return velocity

func set_in_water(water: bool):
	in_water = water

func set_out_of_water(out: bool):
	in_water = not out
