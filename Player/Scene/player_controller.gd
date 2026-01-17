extends CharacterBody2D

# ===========================================
# VARIABILI ESPORTATE
# ===========================================
@export_category("Setup")
@export var sprite_node: Sprite2D

@export_category("Movement Variables")
@export var move_speed: float = 120.0
@export var deceleration: float = 0.1
@export var gravity: float = 500.0

@export_category("Dash Variables")
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var double_tap_time: float = 0.25

@export_category("Jump Variables")
@export var jump_speed: float = 190.0
@export var jump_acceleration: float = 290.0
@export var jump_amount: int = 2

@export_category("Fishing Variables")
@export var hook_scene: PackedScene
@export var fishing_hook_scene: PackedScene
@export var pastura_scene: PackedScene
@export var fish_scene: PackedScene
@export var max_line_length: float = 300.0
@export var cast_speed: float = 600.0
@export var max_charge_time: float = 1.0
@export var min_cast_power: float = 0.3

@export_category("Line Physics")
@export var rope_segments: int = 20
@export var rope_gravity: float = 200.0
@export var rope_stiffness: int = 20
@export var rope_damping: float = 0.95
@export var rope_tension: float = 0.85

@export_category("Line Tuning")
@export var line_out_speed: float = 900.0
@export var reel_in_speed: float = 240.0
@export var reel_pull_force: float = 550.0
@export var min_line_length_start: float = 40.0
@export var spawn_forward_push: float = 18.0
@export var min_forward_aim_dot: float = 0.15

@export_category("Grab / Grapple")
@export var grab_pull_speed: float = 520.0
@export var grab_reel_in_speed: float = 260.0
@export var grab_cancel_distance: float = 18.0
@export var grab_attach_radius: float = 50.0
@export var max_grab_anchors: int = 8

@export_category("Offsets - Base Axis")
@export var base_axis_offset: Vector2 = Vector2(0, 0)

@export_category("Offsets - Line Origin")
@export var line_origin_offset_right: Vector2 = Vector2(0, 8)
@export var line_origin_offset_left: Vector2 = Vector2(0, 8)

@export_category("Offsets - Rod Tip")
@export var rod_tip_offset_right: Vector2 = Vector2(-14, -2)
@export var rod_tip_offset_left: Vector2 = Vector2(14, -2)

# ===========================================
# RIFERIMENTI AI NODI
# ===========================================
@onready var anim: AnimationPlayer = $anim
var fishing_line: Line2D = null

# ===========================================
# STATO DASH
# ===========================================
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var left_dash_available: bool = false
var right_dash_available: bool = false
var left_dash_timer: float = 0.0
var right_dash_timer: float = 0.0

# ===========================================
# STATO MOVIMENTO
# ===========================================
var movement: float = 0.0
var facing_right: bool = true

# ===========================================
# STATO WATER
# ===========================================
var is_in_water: bool = false
var water_gravity_multiplier: float = 1.0

# ===========================================
# STATO FISHING
# ===========================================
enum LineMode { NONE, FISHING, GRAB }
var line_mode: int = LineMode.NONE
var hook_instance: Node = null
var line_extended: bool = false
var is_reeling: bool = false
var points: Array[Vector2] = []
var old_points: Array[Vector2] = []
var current_line_length: float = 0.0
var target_line_length: float = 0.0
var segment_length: float = 0.0
var fishing_anim_started: bool = false
var fishing_anim_finished: bool = false
var is_charging: bool = false
var current_charge_time: float = 0.0
var grab_anchors: Array[RigidBody2D] = []
var current_fish: Node2D = null
var fish_hooked: bool = false
var fish_struggle_timer: float = 0.0
var fish_struggle_interval: float = 2.0
var fish_struggle_active: bool = false
var fish_escape_timer: float = 0.0
var fish_escape_time: float = 1.5
var fish_reel_distance: float = 30.0

# Pastura lanciata (senza lenza)
var active_pastura: Node2D = null

# ===========================================
# READY
# ===========================================
func _ready():
	add_to_group("player")
	_setup_sprite()
	_setup_fishing_line()
	_connect_signals()

func _setup_sprite():
	if sprite_node == null:
		if has_node("Sprite2D"):
			sprite_node = get_node("Sprite2D")
		elif has_node("Sprite"):
			sprite_node = get_node("Sprite")
		else:
			push_error("Assegna sprite_node nell'Inspector!")

func _setup_fishing_line():
	var p = get_parent()
	if p != null and p.has_node("FishingLine"):
		fishing_line = p.get_node("FishingLine") as Line2D
	elif get_tree().current_scene != null and get_tree().current_scene.has_node("FishingLine"):
		fishing_line = get_tree().current_scene.get_node("FishingLine") as Line2D
	
	if fishing_line != null:
		fishing_line.width = 2.0
		fishing_line.default_color = Color(0.5, 0.35, 0.2)
		fishing_line.joint_mode = Line2D.LINE_JOINT_ROUND

func _connect_signals():
	if anim != null:
		anim.animation_finished.connect(_on_anim_finished)

func _on_anim_finished(anim_name: String):
	if anim_name == "Fishing":
		fishing_anim_finished = true

# ===========================================
# INPUT
# ===========================================
func _input(event):
	# CAST = Lancia fishing hook CON LENZA
	if event.is_action_pressed("cast"):
		if not line_extended and hook_instance == null:
			is_charging = true
			current_charge_time = 0.0
	
	if event.is_action_released("cast"):
		if is_charging:
			is_charging = false
			_cast_fishing_hook()
	
	# GRAB = Lancia pastura SENZA LENZA
	if event.is_action_pressed("grab"):
		_cast_pastura()
	
	# REEL
	if event.is_action_pressed("reel"):
		if line_extended and hook_instance != null:
			if fish_hooked and fish_struggle_active:
				fish_struggle_active = false
				fish_escape_timer = 0.0
				fish_struggle_timer = 0.0
				if current_fish != null and current_fish.has_method("stop_struggle"):
					current_fish.call("stop_struggle")
			is_reeling = true
	
	if event.is_action_released("reel"):
		is_reeling = false

# ===========================================
# PHYSICS PROCESS
# ===========================================
func _physics_process(delta: float) -> void:
	_update_dash_timers(delta)
	_check_dash_input()
	
	if _process_dash(delta):
		return
	
	_apply_gravity(delta)
	horizontal_movement()
	flip_logic()  # <-- AGGIUNTO! Era mancante
	_process_charge(delta)
	
	move_and_slide()
	
	set_animation()
	jump_logic()
	
	_process_fishing(delta)

func _update_dash_timers(delta: float):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if left_dash_timer > 0:
		left_dash_timer -= delta
		if left_dash_timer <= 0:
			left_dash_available = false
	
	if right_dash_timer > 0:
		right_dash_timer -= delta
		if right_dash_timer <= 0:
			right_dash_available = false

func _check_dash_input():
	if dash_cooldown_timer > 0 or is_dashing:
		return
	
	if Input.is_action_just_pressed("ui_left"):
		if left_dash_available and left_dash_timer > 0:
			_start_dash(Vector2.LEFT)
			left_dash_available = false
			left_dash_timer = 0.0
		else:
			left_dash_available = true
			left_dash_timer = double_tap_time
			right_dash_available = false
			right_dash_timer = 0.0
	
	if Input.is_action_just_pressed("ui_right"):
		if right_dash_available and right_dash_timer > 0:
			_start_dash(Vector2.RIGHT)
			right_dash_available = false
			right_dash_timer = 0.0
		else:
			right_dash_available = true
			right_dash_timer = double_tap_time
			left_dash_available = false
			left_dash_timer = 0.0

func _start_dash(direction: Vector2):
	is_dashing = true
	dash_timer = dash_duration
	dash_direction = direction
	facing_right = direction.x > 0
	velocity.y = 0

func _process_dash(delta: float) -> bool:
	if not is_dashing:
		return false
	
	dash_timer -= delta
	
	if dash_timer <= 0:
		is_dashing = false
		dash_cooldown_timer = dash_cooldown
		return false
	
	velocity.x = dash_direction.x * dash_speed
	velocity.y = 0
	move_and_slide()
	
	if anim.has_animation("Dash"):
		anim.play("Dash")
	else:
		anim.play("Walking")
	
	return true

func _apply_gravity(delta: float):
	var current_gravity = gravity * water_gravity_multiplier
	velocity.y += current_gravity * delta

# ===========================================
# MOVIMENTO ORIZZONTALE - ORIGINALE
# ===========================================
func horizontal_movement():
	if is_dashing:
		return
	
	if is_charging:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * deceleration)
		return
	
	movement = Input.get_axis("ui_left", "ui_right")
	
	if movement != 0:
		velocity.x = movement * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * deceleration)

# ===========================================
# FLIP LOGIC - ORIGINALE
# ===========================================
func flip_logic():
	if movement > 0:
		facing_right = true
	elif movement < 0:
		facing_right = false
	
	if sprite_node:
		sprite_node.flip_h = !facing_right

func _process_charge(delta: float):
	if is_charging:
		current_charge_time = min(current_charge_time + delta, max_charge_time)

func _process_fishing(delta: float):
	if fish_hooked and current_fish != null:
		update_fish_struggle(delta)
	
	if line_extended and hook_instance != null:
		_update_line_length(delta)
		simulate_rope(delta)
		sync_hook_to_rope(delta)
		update_line_visual()

func _update_line_length(delta: float):
	if not is_reeling and current_line_length < target_line_length:
		current_line_length = min(target_line_length, current_line_length + line_out_speed * delta)
	
	if is_reeling:
		current_line_length -= reel_in_speed * delta
		
		if current_line_length < 20.0:
			if fish_hooked and current_fish != null:
				reel_fish_to_player()
			else:
				destroy_hook()

# ===========================================
# ANIMAZIONI
# ===========================================
func set_animation():
	if Input.is_action_just_pressed("ui_attack") and not line_extended:
		anim.play("Attack_fast")
		return
	
	if anim.current_animation == "Attack_fast" and anim.is_playing():
		return
	
	if is_charging:
		anim.play("Idle")
		return
	
	if line_extended and line_mode == LineMode.FISHING:
		_play_fishing_animation()
		return
	
	_play_locomotion()

func _play_fishing_animation():
	if velocity.y < 0:
		anim.play("Jump")
		fishing_anim_started = false
	elif velocity.y > 10:
		anim.play("Falling")
		fishing_anim_started = false
	elif velocity.x != 0:
		anim.play("Walking")
		fishing_anim_started = false
	else:
		if fishing_anim_finished:
			if anim.current_animation != "Fishing":
				anim.play("Fishing")
			anim.seek(anim.current_animation_length, true)
			anim.stop()
		elif not fishing_anim_started:
			anim.play("Fishing")
			fishing_anim_started = true

func _play_locomotion():
	if velocity.y < 0:
		anim.play("Jump")
	elif velocity.y > 10:
		anim.play("Falling")
	elif velocity.x != 0:
		anim.play("Walking")
	else:
		anim.play("Idle")

# ===========================================
# JUMP - ORIGINALE CON DOPPIO SALTO
# ===========================================
func jump_logic():
	if is_on_floor():
		jump_amount = 2
		if Input.is_action_just_pressed("ui_accept"):
			jump_amount -= 1
			velocity.y -= lerp(jump_speed, jump_acceleration, 0.1)
	
	if not is_on_floor():
		if jump_amount > 0:
			if Input.is_action_just_pressed("ui_accept"):
				jump_amount -= 1
				velocity.y -= lerp(jump_speed, jump_acceleration, 1.0)

# ===========================================
# OFFSETS
# ===========================================
func get_base_axis_position() -> Vector2:
	return to_global(base_axis_offset)

func get_line_origin_position() -> Vector2:
	var base_pos = get_base_axis_position()
	var off = line_origin_offset_right if facing_right else line_origin_offset_left
	return base_pos + off

func get_rod_tip_position() -> Vector2:
	var origin = get_line_origin_position()
	var off = rod_tip_offset_right if facing_right else rod_tip_offset_left
	return origin + off

func get_facing_vector() -> Vector2:
	return Vector2.RIGHT if facing_right else Vector2.LEFT

func get_cast_direction() -> Vector2:
	var start_pos = get_rod_tip_position()
	var aim_pos = get_global_mouse_position()
	var dir = (aim_pos - start_pos).normalized()
	var facing = get_facing_vector()
	
	if dir.dot(facing) < min_forward_aim_dot:
		dir = Vector2(facing.x, dir.y).normalized()
	
	return dir

func get_hook_center_position(hook: Node) -> Vector2:
	if hook == null:
		return Vector2.ZERO
	if hook.has_method("get_line_attach_point"):
		return hook.call("get_line_attach_point")
	return hook.global_position

func get_fish_center_position(fish: Node2D) -> Vector2:
	if fish == null:
		return Vector2.ZERO
	
	var sprite = fish.get_node_or_null("Fishes")
	if sprite == null:
		sprite = fish.find_child("Fishes", true, false)
	
	return sprite.global_position if sprite != null else fish.global_position

# ===========================================
# CAST FISHING HOOK - CON LENZA
# ===========================================
func _cast_fishing_hook():
	var scene_to_use = fishing_hook_scene if fishing_hook_scene != null else hook_scene
	
	if scene_to_use == null:
		push_error("fishing_hook_scene o hook_scene non assegnata!")
		return
	
	var power_ratio = clamp(current_charge_time / max_charge_time, min_cast_power, 1.0)
	
	# Crea l'hook (RigidBody2D)
	var rb = scene_to_use.instantiate() as RigidBody2D
	if rb == null:
		push_error("fishing_hook_scene deve essere un RigidBody2D")
		return
	
	rb.add_collision_exception_with(self)
	add_collision_exception_with(rb)
	
	get_tree().current_scene.add_child(rb)
	hook_instance = rb
	
	# Posiziona e lancia
	var start_pos = get_rod_tip_position()
	var direction = get_cast_direction()
	var facing = get_facing_vector()
	var spawn_pos = start_pos + direction * spawn_forward_push + facing * (spawn_forward_push * 0.4)
	
	rb.global_position = spawn_pos
	rb.linear_velocity = direction * (cast_speed * power_ratio)
	
	# Passa riferimento player
	if rb.has_method("set_player_reference"):
		rb.call("set_player_reference", self)
	
	# Setup lenza
	line_mode = LineMode.FISHING
	line_extended = true
	is_reeling = false
	fishing_anim_started = false
	fishing_anim_finished = false
	
	target_line_length = max_line_length * power_ratio
	current_line_length = clamp(min_line_length_start, 10.0, target_line_length)
	segment_length = current_line_length / rope_segments
	
	_init_rope_points(start_pos)

# ===========================================
# CAST PASTURA - SENZA LENZA
# ===========================================
func _cast_pastura():
	if pastura_scene == null:
		push_error("pastura_scene non assegnata!")
		return
	
	# Crea la pastura
	var pastura = pastura_scene.instantiate() as Node2D
	if pastura == null:
		push_error("pastura_scene deve essere un Node2D")
		return
	
	get_tree().current_scene.add_child(pastura)
	
	# Posiziona e lancia
	var start_pos = get_rod_tip_position()
	var direction = get_cast_direction()
	var facing = get_facing_vector()
	var spawn_pos = start_pos + direction * spawn_forward_push + facing * (spawn_forward_push * 0.4)
	
	pastura.global_position = spawn_pos
	
	# Imposta velocità sulla pastura
	if pastura.has_method("set_velocity"):
		pastura.call("set_velocity", direction * cast_speed * 0.8)
	
	# Passa riferimento player
	if pastura.has_method("set_player_reference"):
		pastura.call("set_player_reference", self)
	
	active_pastura = pastura

# ===========================================
# ROPE POINTS INIT
# ===========================================
func _init_rope_points(start_pos: Vector2):
	points.clear()
	old_points.clear()
	for i in range(rope_segments + 1):
		points.append(start_pos)
		old_points.append(start_pos)

# ===========================================
# ROPE PHYSICS (VERLET - SENZA GOBBA)
# ===========================================
func simulate_rope(delta: float):
	if hook_instance == null or points.size() < 2:
		return
	
	var rod_pos = get_rod_tip_position()
	var end_pos = _get_line_end_position()
	
	# Fissa i punti estremi
	points[0] = rod_pos
	old_points[0] = rod_pos
	points[points.size() - 1] = end_pos
	old_points[points.size() - 1] = end_pos
	
	# Calcola la lunghezza ideale del segmento
	var actual_distance = rod_pos.distance_to(end_pos)
	segment_length = min(actual_distance, current_line_length) / (points.size() - 1)
	
	# Verlet integration per i punti intermedi
	var tension_factor = 1.0 - rope_tension
	var adjusted_gravity = rope_gravity * tension_factor
	
	for i in range(1, points.size() - 1):
		var current = points[i]
		var old = old_points[i]
		
		var vel = (current - old) * rope_damping
		var grav = Vector2(0, adjusted_gravity * delta * delta)
		
		old_points[i] = current
		points[i] = current + vel + grav
	
	# Applica constraints multipli per rigidità
	for _iter in range(rope_stiffness):
		_apply_rope_constraints(rod_pos, end_pos)

func _get_line_end_position() -> Vector2:
	if fish_hooked and is_instance_valid(current_fish):
		return get_fish_center_position(current_fish)
	return get_hook_center_position(hook_instance)

func _apply_rope_constraints(rod_pos: Vector2, end_pos: Vector2):
	points[0] = rod_pos
	points[points.size() - 1] = end_pos
	
	# Constraint da canna verso hook
	for i in range(points.size() - 1):
		var p1 = points[i]
		var p2 = points[i + 1]
		var diff = p2 - p1
		var distance = diff.length()
		
		if distance < 0.001:
			continue
		
		var error = distance - segment_length
		if abs(error) < 0.5:
			continue
		
		var correction = diff.normalized() * error
		
		if i == 0:
			points[i + 1] -= correction
		elif i == points.size() - 2:
			points[i] += correction
		else:
			points[i] += correction * 0.5
			points[i + 1] -= correction * 0.5
	
	# Constraint inverso per stabilità
	for i in range(points.size() - 1, 0, -1):
		var p1 = points[i]
		var p2 = points[i - 1]
		var diff = p2 - p1
		var distance = diff.length()
		
		if distance < 0.001:
			continue
		
		var error = distance - segment_length
		if abs(error) < 0.5:
			continue
		
		var correction = diff.normalized() * error
		
		if i == points.size() - 1:
			points[i - 1] -= correction
		elif i == 1:
			points[i] += correction
		else:
			points[i] += correction * 0.5
			points[i - 1] -= correction * 0.5

func sync_hook_to_rope(delta: float):
	if hook_instance == null:
		return
	
	var target_pos = _get_line_end_position()
	var rod_pos = get_rod_tip_position()
	var dist = rod_pos.distance_to(target_pos)
	
	# Mantieni lunghezza lenza
	if dist > current_line_length and not (fish_hooked and current_fish != null):
		var dir_to_rod = (rod_pos - target_pos).normalized()
		var overshoot = dist - current_line_length
		
		if hook_instance is RigidBody2D:
			hook_instance.global_position += dir_to_rod * overshoot
			var vel_toward = hook_instance.linear_velocity.dot(dir_to_rod)
			if vel_toward < 0:
				hook_instance.linear_velocity -= dir_to_rod * vel_toward
	
	if is_reeling:
		_handle_reel(delta, rod_pos)
	
	points[points.size() - 1] = target_pos

func _handle_reel(delta: float, rod_pos: Vector2):
	var target: Node2D
	var target_pos: Vector2
	
	if fish_hooked and current_fish != null:
		target = current_fish
		target_pos = get_fish_center_position(current_fish)
	elif hook_instance is RigidBody2D:
		target = hook_instance
		target_pos = get_hook_center_position(hook_instance)
	else:
		return
	
	var dir = (rod_pos - target_pos).normalized()
	
	if target.has_method("apply_reel_force"):
		target.call("apply_reel_force", dir * reel_pull_force)
	elif target is RigidBody2D:
		target.apply_central_force(dir * reel_pull_force)

func destroy_hook():
	if hook_instance != null:
		hook_instance.queue_free()
	_reset_line_state()

func _reset_line_state():
	hook_instance = null
	points.clear()
	old_points.clear()
	is_reeling = false
	line_extended = false
	current_line_length = 0.0
	target_line_length = 0.0
	line_mode = LineMode.NONE
	fish_hooked = false
	current_fish = null
	
	if fishing_line != null:
		fishing_line.clear_points()

func update_line_visual():
	if fishing_line == null:
		return
	
	fishing_line.clear_points()
	
	if points.size() < 2:
		return
	
	for p in points:
		fishing_line.add_point(p)

# ===========================================
# FISHING SYSTEM
# ===========================================
func on_fish_hooked(fish: Node2D):
	if fish == null or fish_hooked:
		return
	
	current_fish = fish
	fish_hooked = true
	fish_struggle_timer = 0.0
	fish_escape_timer = 0.0
	fish_struggle_active = false
	
	if fish.has_method("set_player_reference"):
		fish.call("set_player_reference", self)
	
	if hook_instance != null and hook_instance.has_method("hide_for_fish"):
		hook_instance.call("hide_for_fish")

func on_fish_spawned(fish: Node2D):
	on_fish_hooked(fish)

func update_fish_struggle(delta: float):
	if not is_instance_valid(current_fish):
		fish_hooked = false
		current_fish = null
		return
	
	fish_struggle_timer += delta
	
	if fish_struggle_timer >= fish_struggle_interval and not fish_struggle_active:
		fish_struggle_timer = 0.0
		fish_struggle_active = true
		fish_escape_timer = 0.0
		
		if current_fish.has_method("start_struggle"):
			current_fish.call("start_struggle")
	
	if fish_struggle_active:
		fish_escape_timer += delta
		
		if fish_escape_timer >= fish_escape_time:
			if is_instance_valid(current_fish):
				current_fish.queue_free()
			fish_hooked = false
			current_fish = null
			destroy_hook()

func reel_fish_to_player():
	if not is_instance_valid(current_fish):
		fish_hooked = false
		current_fish = null
		destroy_hook()
		return
	
	var dist = global_position.distance_to(current_fish.global_position)
	
	if dist < fish_reel_distance:
		if is_instance_valid(current_fish):
			current_fish.queue_free()
		fish_hooked = false
		current_fish = null
		destroy_hook()
	else:
		var rod_pos = get_rod_tip_position()
		var fish_pos = current_fish.global_position
		var dir = (rod_pos - fish_pos).normalized()
		
		if current_fish.has_method("apply_reel_force"):
			current_fish.call("apply_reel_force", dir * reel_pull_force * 1.5)

# ===========================================
# WATER PHYSICS
# ===========================================
func set_in_water(in_water: bool, gravity_reduction: float = 0.3):
	is_in_water = in_water
	water_gravity_multiplier = gravity_reduction if in_water else 1.0

func in_water():
	set_in_water(true, 0.3)

func exit_water():
	set_in_water(false)
