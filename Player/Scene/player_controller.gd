extends CharacterBody2D

# ===========================================
# PLAYER SCRIPT v3 - COMPLETO
# Include: Movimento, Dash, Pesca, Lenza dinamica, Sistema vita
# I pallini vita sono disegnati direttamente (nessun script esterno)
# ===========================================

@export_category("Setup")
@export var sprite_node: Sprite2D

@export_category("Movement")
@export var move_speed: float = 120.0
@export var deceleration: float = 0.1
@export var gravity: float = 500.0

@export_category("Dash")
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var double_tap_time: float = 0.25

@export_category("Jump")
@export var jump_speed: float = 190.0
@export var jump_acceleration: float = 290.0
@export var jump_amount: int = 2

@export_category("Fishing")
@export var hook_scene: PackedScene
@export var fishing_hook_scene: PackedScene
@export var pastura_scene: PackedScene
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
@export var fish_hooked_slack: float = 0.3

@export_category("Line Colors")
@export var line_color_normal: Color = Color(0.2, 0.6, 0.3)
@export var line_color_tension: Color = Color(0.9, 0.8, 0.1)
@export var line_color_critical: Color = Color(0.9, 0.2, 0.1)
@export var line_color_reeling: Color = Color(0.3, 0.7, 0.9)

@export_category("Line Tuning")
@export var line_out_speed: float = 900.0
@export var reel_in_speed: float = 240.0
@export var reel_pull_force: float = 550.0
@export var min_line_length_start: float = 40.0
@export var spawn_forward_push: float = 18.0
@export var min_forward_aim_dot: float = 0.15

@export_category("Grab")
@export var grab_pull_speed: float = 520.0
@export var grab_reel_in_speed: float = 260.0
@export var grab_cancel_distance: float = 18.0
@export var grab_attach_radius: float = 50.0
@export var max_grab_anchors: int = 8

@export_category("Offsets")
@export var base_axis_offset: Vector2 = Vector2(0, 0)
@export var line_origin_offset_right: Vector2 = Vector2(0, 8)
@export var line_origin_offset_left: Vector2 = Vector2(0, 8)
@export var rod_tip_offset_right: Vector2 = Vector2(-14, -2)
@export var rod_tip_offset_left: Vector2 = Vector2(14, -2)

@export_category("Particles")
@export var black_particle_scene: PackedScene
@export var particles_on_dash: bool = true
@export var particles_on_jump: bool = true
@export var particles_on_attack: bool = true
@export var particles_on_move: bool = false
@export var move_particle_interval: float = 0.03

@export_category("Fish Struggle")
@export var fish_struggle_interval: float = 2.0
@export var fish_escape_time: float = 1.5
@export var fish_reel_distance: float = 30.0
@export var fish_pull_strength: float = 150.0

@export_category("Health")
@export var max_health: int = 5
@export var invincibility_time: float = 1.5
@export var health_ui_offset: Vector2 = Vector2(0, -40)
@export var health_color_full: Color = Color(0.9, 0.2, 0.3)
@export var health_color_empty: Color = Color(0.3, 0.3, 0.3, 0.5)
@export var health_dot_size: float = 6.0
@export var health_dot_spacing: float = 14.0

# Nodi
@onready var anim: AnimationPlayer = $anim
var fishing_line: Line2D = null

# Health UI
var _health_states: Array[bool] = []
var _health_scales: Array[float] = []
var _health_pulse: Array[float] = []

# Dash
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var left_dash_available: bool = false
var right_dash_available: bool = false
var left_dash_timer: float = 0.0
var right_dash_timer: float = 0.0
var dash_particle_timer: float = 0.0

# Movimento
var movement: float = 0.0
var facing_right: bool = true

# Water
var is_in_water: bool = false
var water_gravity_multiplier: float = 1.0

# Health
var current_health: int = 5
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var blink_timer: float = 0.0

# Fishing
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
var using_fishing_hook: bool = false
var current_fish: Node2D = null
var fish_hooked: bool = false
var fish_struggle_timer: float = 0.0
var fish_struggle_active: bool = false
var fish_escape_timer: float = 0.0
var active_pastura: Node2D = null
var _effective_tension: float = 0.85
var _rope_initialized: bool = false
var _current_line_stress: float = 0.0
var _line_color_lerp_speed: float = 5.0
var move_particle_timer: float = 0.0

func _ready():
	add_to_group("player")
	_setup_sprite()
	_setup_fishing_line()
	_setup_health()
	if anim:
		anim.animation_finished.connect(_on_anim_finished)
	current_health = max_health

func _setup_sprite():
	if sprite_node == null:
		sprite_node = get_node_or_null("Sprite2D")
		if sprite_node == null:
			sprite_node = get_node_or_null("Sprite")

func _setup_fishing_line():
	var p = get_parent()
	if p and p.has_node("FishingLine"):
		fishing_line = p.get_node("FishingLine") as Line2D
	elif get_tree().current_scene and get_tree().current_scene.has_node("FishingLine"):
		fishing_line = get_tree().current_scene.get_node("FishingLine") as Line2D
	if fishing_line:
		fishing_line.width = 2.0
		fishing_line.default_color = line_color_normal
		fishing_line.joint_mode = Line2D.LINE_JOINT_ROUND

func _setup_health():
	_health_states.clear()
	_health_scales.clear()
	_health_pulse.clear()
	for i in range(max_health):
		_health_states.append(true)
		_health_scales.append(1.0)
		_health_pulse.append(0.0)

func _on_anim_finished(anim_name: String):
	if anim_name == "Fishing":
		fishing_anim_finished = true

func _draw():
	var total_w = (max_health - 1) * health_dot_spacing
	var start_x = -total_w / 2.0
	for i in range(max_health):
		var pos = health_ui_offset + Vector2(start_x + i * health_dot_spacing, 0)
		var is_full = _health_states[i] if i < _health_states.size() else false
		var sc = _health_scales[i] if i < _health_scales.size() else 1.0
		var pulse = _health_pulse[i] if i < _health_pulse.size() else 0.0
		if is_full and pulse > 0:
			sc *= 1.0 + sin(pulse * 4.0) * 0.15
		var rad = health_dot_size * sc
		var col = health_color_full if is_full else health_color_empty
		draw_circle(pos, rad, col)
		draw_arc(pos, rad, 0, TAU, 24, col.darkened(0.3), 1.5)
		if is_full:
			draw_circle(pos + Vector2(-rad * 0.25, -rad * 0.25), rad * 0.25, Color(1, 1, 1, 0.3))

func _input(event):
	if event.is_action_pressed("change_hook"):
		using_fishing_hook = !using_fishing_hook
		return
	if event.is_action_pressed("grab"):
		if line_extended and hook_instance and line_mode == LineMode.GRAB:
			detach_grab_anchor()
			return
	if event.is_action_pressed("cast"):
		if not line_extended and hook_instance == null:
			line_mode = LineMode.FISHING
			is_charging = true
			current_charge_time = 0.0
	if event.is_action_pressed("grab"):
		if not line_extended and hook_instance == null:
			if using_fishing_hook:
				_cast_pastura()
			else:
				var a = find_nearest_grab_anchor(get_rod_tip_position(), grab_attach_radius)
				if a:
					attach_to_existing_grab_anchor(a)
				else:
					line_mode = LineMode.GRAB
					is_charging = true
					current_charge_time = 0.0
	if event.is_action_released("cast") or event.is_action_released("grab"):
		if is_charging:
			is_charging = false
			cast_hook_charged()
	if event.is_action_pressed("reel"):
		if line_extended and hook_instance:
			if fish_hooked and fish_struggle_active:
				_stop_fish_struggle()
			is_reeling = true
	if event.is_action_released("reel"):
		is_reeling = false

func _physics_process(delta: float):
	_update_dash_timers(delta)
	_check_dash_input()
	_update_invincibility(delta)
	_update_health_anims(delta)
	if _process_dash(delta):
		return
	_apply_gravity(delta)
	horizontal_movement()
	flip_logic()
	if is_charging:
		current_charge_time = min(current_charge_time + delta, max_charge_time)
	move_and_slide()
	set_animation()
	jump_logic()
	_process_fishing(delta)
	queue_redraw()

func _update_health_anims(delta: float):
	for i in range(_health_scales.size()):
		_health_scales[i] = lerp(_health_scales[i], 1.0, delta * 8.0)
		if _health_states[i] and _health_pulse[i] > 0:
			_health_pulse[i] += delta
			if _health_pulse[i] > 3.0:
				_health_pulse[i] = 0.0

func _update_invincibility(delta: float):
	if is_invincible:
		invincibility_timer -= delta
		blink_timer += delta
		if sprite_node:
			sprite_node.modulate.a = 0.5 + 0.5 * sin(blink_timer * 15.0)
		if invincibility_timer <= 0:
			is_invincible = false
			if sprite_node:
				sprite_node.modulate.a = 1.0

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
	if Input.is_action_just_pressed("dash"):
		var dir = Vector2.ZERO
		if Input.is_action_pressed("ui_left"):
			dir = Vector2.LEFT
		elif Input.is_action_pressed("ui_right"):
			dir = Vector2.RIGHT
		else:
			dir = Vector2.RIGHT if facing_right else Vector2.LEFT
		if dir != Vector2.ZERO:
			_start_dash(dir)
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
	if Input.is_action_just_pressed("ui_right"):
		if right_dash_available and right_dash_timer > 0:
			_start_dash(Vector2.RIGHT)
			right_dash_available = false
			right_dash_timer = 0.0
		else:
			right_dash_available = true
			right_dash_timer = double_tap_time
			left_dash_available = false

func _start_dash(direction: Vector2):
	is_dashing = true
	dash_timer = dash_duration
	dash_direction = direction
	facing_right = direction.x > 0
	velocity.y = 0
	if particles_on_dash and black_particle_scene:
		_spawn_particles(global_position, -direction, 0.3)

func _process_dash(delta: float) -> bool:
	if not is_dashing:
		return false
	dash_timer -= delta
	dash_particle_timer -= delta
	if particles_on_dash and black_particle_scene and dash_particle_timer <= 0:
		dash_particle_timer = 0.015
		_spawn_particles(global_position, -dash_direction, 0.4)
	if dash_timer <= 0:
		is_dashing = false
		dash_cooldown_timer = dash_cooldown
		return false
	velocity.x = dash_direction.x * dash_speed
	velocity.y = 0
	move_and_slide()
	anim.play("Dash" if anim.has_animation("Dash") else "Walking")
	return true

func _apply_gravity(delta: float):
	velocity.y += gravity * water_gravity_multiplier * delta

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

func flip_logic():
	if movement > 0:
		facing_right = true
	elif movement < 0:
		facing_right = false
	if sprite_node:
		sprite_node.flip_h = !facing_right

func set_animation():
	if Input.is_action_just_pressed("ui_attack") and not line_extended:
		anim.play("Attack_fast")
		if particles_on_attack and black_particle_scene:
			_spawn_particles(global_position, Vector2.RIGHT if facing_right else Vector2.LEFT, 0.2)
		return
	if anim.current_animation == "Attack_fast" and anim.is_playing():
		return
	if is_charging:
		anim.play("Idle")
		return
	if line_extended:
		if line_mode == LineMode.GRAB and anim.has_animation("Grab"):
			anim.play("Grab")
			return
		if line_mode == LineMode.FISHING:
			_play_fishing_anim()
			return
	_play_locomotion()

func _play_fishing_anim():
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

func jump_logic():
	if is_on_floor():
		jump_amount = 2
		if Input.is_action_just_pressed("ui_accept"):
			jump_amount -= 1
			velocity.y -= lerp(jump_speed, jump_acceleration, 0.1)
			if particles_on_jump and black_particle_scene:
				_spawn_particles(global_position, Vector2.DOWN, 0.2)
	elif jump_amount > 0 and Input.is_action_just_pressed("ui_accept"):
		jump_amount -= 1
		velocity.y -= lerp(jump_speed, jump_acceleration, 1.0)
		if particles_on_jump and black_particle_scene:
			_spawn_particles(global_position, Vector2.DOWN, 0.2)

# ===== HEALTH =====
func take_damage(amount: int = 1):
	if is_invincible:
		return
	var old = current_health
	current_health = max(0, current_health - amount)
	for i in range(max_health):
		var was = _health_states[i]
		_health_states[i] = i < current_health
		if was and not _health_states[i]:
			_health_scales[i] = 0.3
			_health_pulse[i] = 0.0
	is_invincible = true
	invincibility_timer = invincibility_time
	blink_timer = 0.0
	print("💔 Danno! Vita: ", current_health)
	if current_health <= 0:
		_on_death()

func heal(amount: int = 1):
	var old = current_health
	current_health = min(max_health, current_health + amount)
	for i in range(max_health):
		var was = _health_states[i]
		_health_states[i] = i < current_health
		if not was and _health_states[i]:
			_health_scales[i] = 1.5
			_health_pulse[i] = 0.01
	if current_health > old:
		print("💚 Curato! Vita: ", current_health)

func _on_death():
	print("☠️ GAME OVER!")
	await get_tree().create_timer(1.0).timeout
	current_health = max_health
	for i in range(max_health):
		_health_states[i] = true
		_health_scales[i] = 1.0
		_health_pulse[i] = 0.0

# ===== OFFSETS =====
func get_base_axis_position() -> Vector2:
	return to_global(base_axis_offset)

func get_line_origin_position() -> Vector2:
	return get_base_axis_position() + (line_origin_offset_right if facing_right else line_origin_offset_left)

func get_rod_tip_position() -> Vector2:
	return get_line_origin_position() + (rod_tip_offset_right if facing_right else rod_tip_offset_left)

func get_facing_vector() -> Vector2:
	return Vector2.RIGHT if facing_right else Vector2.LEFT

func get_cast_direction() -> Vector2:
	var start = get_rod_tip_position()
	var aim = get_global_mouse_position()
	var dir = (aim - start).normalized()
	var facing = get_facing_vector()
	if dir.dot(facing) < min_forward_aim_dot:
		dir = Vector2(facing.x, dir.y).normalized()
	return dir

func get_hook_center_position(hook: Node) -> Vector2:
	if hook == null:
		return Vector2.ZERO
	if hook.has_method("get_line_attach_point"):
		var pt = hook.call("get_line_attach_point")
		if pt != Vector2.ZERO:
			return pt
	return hook.global_position

func get_fish_center_position(fish: Node2D) -> Vector2:
	if fish == null:
		return Vector2.ZERO
	var spr = fish.get_node_or_null("Fishes")
	if spr == null:
		spr = fish.find_child("Fishes", true, false)
	return spr.global_position if spr else fish.global_position

# ===== GRAB ANCHORS =====
func cleanup_grab_anchors():
	for i in range(grab_anchors.size() - 1, -1, -1):
		if grab_anchors[i] == null or not is_instance_valid(grab_anchors[i]):
			grab_anchors.remove_at(i)

func register_grab_anchor(anchor: Node):
	if not (anchor is RigidBody2D):
		return
	cleanup_grab_anchors()
	if anchor in grab_anchors:
		return
	grab_anchors.append(anchor)
	while grab_anchors.size() > max_grab_anchors:
		var old = grab_anchors.pop_front()
		if old and is_instance_valid(old):
			if hook_instance == old:
				detach_grab_anchor()
			old.queue_free()

func find_nearest_grab_anchor(from: Vector2, radius: float) -> RigidBody2D:
	cleanup_grab_anchors()
	var best: RigidBody2D = null
	var best_d2 = radius * radius
	for a in grab_anchors:
		var d2 = from.distance_squared_to(a.global_position)
		if d2 <= best_d2:
			best_d2 = d2
			best = a
	return best

func attach_to_existing_grab_anchor(anchor: RigidBody2D):
	hook_instance = anchor
	line_mode = LineMode.GRAB
	line_extended = true
	is_reeling = false
	is_charging = false
	if hook_instance.has_method("set_hook_type"):
		hook_instance.call("set_hook_type", "grab")
	if hook_instance.has_method("anchorize"):
		hook_instance.call("anchorize")
	var rod = get_rod_tip_position()
	var dist = rod.distance_to(hook_instance.global_position)
	target_line_length = max_line_length
	current_line_length = clamp(dist, 10.0, max_line_length)
	_init_rope_points(rod)

func detach_grab_anchor():
	if hook_instance and is_instance_valid(hook_instance) and hook_instance.has_method("anchorize"):
		hook_instance.call("anchorize")
	_reset_line_state()

# ===== CAST =====
func cast_hook_charged():
	var scene = fishing_hook_scene if using_fishing_hook and fishing_hook_scene else hook_scene
	if scene == null:
		return
	var power = clamp(current_charge_time / max_charge_time, min_cast_power, 1.0)
	var rb = scene.instantiate() as RigidBody2D
	if rb == null:
		return
	hook_instance = rb
	rb.add_collision_exception_with(self)
	add_collision_exception_with(rb)
	get_tree().current_scene.add_child(hook_instance)
	var start = get_rod_tip_position()
	var dir = get_cast_direction()
	var facing = get_facing_vector()
	hook_instance.global_position = start + dir * spawn_forward_push + facing * (spawn_forward_push * 0.4)
	rb.linear_velocity = dir * (cast_speed * power)
	if hook_instance.has_method("set_hook_type"):
		hook_instance.call("set_hook_type", "grab" if line_mode == LineMode.GRAB else "fishing")
	if hook_instance.has_method("set_player_reference"):
		hook_instance.call("set_player_reference", self)
	line_extended = true
	is_reeling = false
	fishing_anim_started = false
	fishing_anim_finished = false
	target_line_length = max_line_length * power
	current_line_length = clamp(min_line_length_start, 10.0, target_line_length)
	_init_rope_points(start)
	if line_mode == LineMode.GRAB:
		register_grab_anchor(hook_instance)

func _cast_pastura():
	if pastura_scene == null:
		return
	var p = pastura_scene.instantiate() as Node2D
	if p == null:
		return
	get_tree().current_scene.add_child(p)
	var start = get_rod_tip_position()
	var dir = get_cast_direction()
	p.global_position = start + dir * spawn_forward_push
	if p.has_method("set_velocity"):
		p.call("set_velocity", dir * cast_speed * 0.8)
	if p.has_method("set_player_reference"):
		p.call("set_player_reference", self)
	active_pastura = p

# ===== ROPE =====
func _init_rope_points(start: Vector2):
	points.clear()
	old_points.clear()
	for i in range(rope_segments + 1):
		points.append(start)
		old_points.append(start)
	_rope_initialized = true
	_current_line_stress = 0.0
	_update_effective_tension()

func _update_effective_tension():
	_effective_tension = rope_tension - (fish_hooked_slack if fish_hooked else 0.0)
	_effective_tension = clamp(_effective_tension, 0.0, 1.0)

func _process_fishing(delta: float):
	if fish_hooked and current_fish:
		_update_fish_struggle(delta)
	if line_extended and hook_instance:
		_update_line_length(delta)
		_sync_hook_to_rope(delta)
		_simulate_rope(delta)
		_update_line_color(delta)
		_update_line_visual()

func _update_line_length(delta: float):
	if not is_reeling and current_line_length < target_line_length:
		current_line_length = min(target_line_length, current_line_length + line_out_speed * delta)
	if is_reeling:
		var spd = grab_reel_in_speed if line_mode == LineMode.GRAB else reel_in_speed
		current_line_length -= spd * delta
		if current_line_length < 20.0:
			if line_mode == LineMode.GRAB:
				detach_grab_anchor()
			elif fish_hooked and current_fish:
				_reel_fish_to_player()
			else:
				_destroy_hook()

func _update_line_color(delta: float):
	if fishing_line == null:
		return
	var stress: float = 0.0
	var col: Color = line_color_normal
	if fish_hooked:
		if fish_struggle_active:
			if is_reeling:
				stress = 0.3
				col = line_color_reeling
			else:
				stress = fish_escape_timer / fish_escape_time
				col = _get_stress_color(stress)
		else:
			stress = 0.3
			col = line_color_normal.lerp(line_color_tension, 0.3)
	elif is_reeling:
		stress = 0.2
		col = line_color_reeling
	_current_line_stress = lerp(_current_line_stress, stress, delta * _line_color_lerp_speed)
	fishing_line.default_color = fishing_line.default_color.lerp(col, delta * _line_color_lerp_speed)
	fishing_line.width = lerp(2.0, 4.0, _current_line_stress)

func _get_stress_color(stress: float) -> Color:
	if stress < 0.5:
		return line_color_normal.lerp(line_color_tension, stress * 2.0)
	return line_color_tension.lerp(line_color_critical, (stress - 0.5) * 2.0)

func _simulate_rope(delta: float):
	if hook_instance == null or not _rope_initialized or points.size() < 2:
		return
	var rod = get_rod_tip_position()
	var end = _get_line_end_position()
	points[0] = rod
	old_points[0] = rod
	points[points.size() - 1] = end
	old_points[old_points.size() - 1] = end
	var dist = rod.distance_to(end)
	var slack = clamp(dist / current_line_length, 0.5, 1.0) if dist < current_line_length else 1.0
	segment_length = max(1.0, (current_line_length / (points.size() - 1)) * slack)
	var grav = rope_gravity * (1.0 - _effective_tension)
	for i in range(1, points.size() - 1):
		var cur = points[i]
		var old = old_points[i]
		var vel = (cur - old) * rope_damping
		old_points[i] = cur
		points[i] = cur + vel + Vector2(0, grav * delta * delta)
	for _it in range(rope_stiffness):
		_apply_rope_constraints(rod, end)

func _get_line_end_position() -> Vector2:
	if fish_hooked and is_instance_valid(current_fish):
		return get_fish_center_position(current_fish)
	if hook_instance:
		return get_hook_center_position(hook_instance)
	return get_rod_tip_position()

func _apply_rope_constraints(rod: Vector2, end: Vector2):
	points[0] = rod
	points[points.size() - 1] = end
	for i in range(points.size() - 1):
		var diff = points[i + 1] - points[i]
		var d = diff.length()
		if d < 0.001:
			continue
		var err = d - segment_length
		if abs(err) < 0.5:
			continue
		var cor = diff.normalized() * err
		if i == 0:
			points[i + 1] -= cor
		elif i == points.size() - 2:
			points[i] += cor
		else:
			points[i] += cor * 0.5
			points[i + 1] -= cor * 0.5

func _sync_hook_to_rope(delta: float):
	if hook_instance == null:
		return
	var rod = get_rod_tip_position()
	var target = _get_line_end_position()
	var dist = rod.distance_to(target)
	if dist > current_line_length and not fish_hooked:
		var dir = (rod - target).normalized()
		var over = dist - current_line_length
		if hook_instance is RigidBody2D:
			hook_instance.global_position += dir * over
			var vt = hook_instance.linear_velocity.dot(dir)
			if vt < 0:
				hook_instance.linear_velocity -= dir * vt
		elif hook_instance is Node2D:
			hook_instance.global_position += dir * over
		target = _get_line_end_position()
	if is_reeling:
		_handle_reel(delta, rod)
	if points.size() >= 2:
		points[points.size() - 1] = target
		old_points[old_points.size() - 1] = target

func _handle_reel(delta: float, rod: Vector2):
	if line_mode == LineMode.GRAB:
		var hc = get_hook_center_position(hook_instance)
		var dir = (hc - global_position).normalized()
		velocity.x = move_toward(velocity.x, dir.x * grab_pull_speed, grab_pull_speed * 6.0 * delta)
		velocity.y = move_toward(velocity.y, dir.y * grab_pull_speed, grab_pull_speed * 6.0 * delta)
		current_line_length = max(current_line_length, rod.distance_to(hc))
		if global_position.distance_to(hc) < grab_cancel_distance:
			detach_grab_anchor()
	else:
		_reel_fishing_target(rod)

func _reel_fishing_target(rod: Vector2):
	var target: Node2D = null
	var pos: Vector2
	if fish_hooked and current_fish and is_instance_valid(current_fish):
		target = current_fish
		pos = get_fish_center_position(current_fish)
	elif hook_instance is RigidBody2D:
		target = hook_instance
		pos = get_hook_center_position(hook_instance)
	if target == null:
		return
	var dir = (rod - pos).normalized()
	if target.has_method("apply_reel_force"):
		target.call("apply_reel_force", dir * reel_pull_force)
	elif target is RigidBody2D:
		target.apply_central_force(dir * reel_pull_force)

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
	_update_effective_tension()
	if hook_instance and is_instance_valid(hook_instance):
		var hide = false
		if hook_instance.has_method("get_hook_type"):
			hide = str(hook_instance.call("get_hook_type")) == "fishing"
		else:
			hide = using_fishing_hook and line_mode == LineMode.FISHING
		if hide and hook_instance.has_method("hide_for_fish"):
			hook_instance.call("hide_for_fish")

func on_fish_spawned(fish: Node2D):
	on_fish_hooked(fish)

func _update_fish_struggle(delta: float):
	if not is_instance_valid(current_fish):
		_on_fish_lost(false)
		return
	fish_struggle_timer += delta
	if fish_struggle_timer >= fish_struggle_interval and not fish_struggle_active:
		fish_struggle_timer = 0.0
		fish_struggle_active = true
		fish_escape_timer = 0.0
		if current_fish.has_method("start_struggle"):
			current_fish.call("start_struggle")
	if fish_struggle_active:
		if not is_reeling:
			fish_escape_timer += delta
			if current_fish.has_method("apply_struggle_force"):
				var rod = get_rod_tip_position()
				var fp = get_fish_center_position(current_fish)
				current_fish.call("apply_struggle_force", (fp - rod).normalized() * fish_pull_strength * delta)
		else:
			fish_escape_timer = max(fish_escape_timer - delta * 0.5, 0.0)
		if fish_escape_timer >= fish_escape_time:
			_on_fish_escaped()

func _stop_fish_struggle():
	fish_struggle_active = false
	fish_escape_timer = 0.0
	fish_struggle_timer = 0.0
	if current_fish and is_instance_valid(current_fish) and current_fish.has_method("stop_struggle"):
		current_fish.call("stop_struggle")

func _on_fish_escaped():
	if is_instance_valid(current_fish):
		current_fish.queue_free()
	_on_fish_lost(true)

func _on_fish_lost(_escaped: bool):
	fish_hooked = false
	current_fish = null
	fish_struggle_active = false
	fish_escape_timer = 0.0
	fish_struggle_timer = 0.0
	_update_effective_tension()
	if hook_instance and is_instance_valid(hook_instance) and hook_instance.has_method("show_hook"):
		hook_instance.call("show_hook")

func _reel_fish_to_player():
	if not is_instance_valid(current_fish):
		fish_hooked = false
		current_fish = null
		_destroy_hook()
		return
	if global_position.distance_to(current_fish.global_position) < fish_reel_distance:
		heal(1)
		current_fish.queue_free()
		fish_hooked = false
		current_fish = null
		_destroy_hook()
	else:
		var rod = get_rod_tip_position()
		var dir = (rod - current_fish.global_position).normalized()
		if current_fish.has_method("apply_reel_force"):
			current_fish.call("apply_reel_force", dir * reel_pull_force * 1.5)

func _destroy_hook():
	if hook_instance and is_instance_valid(hook_instance):
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
	fish_struggle_active = false
	fish_escape_timer = 0.0
	fish_struggle_timer = 0.0
	_rope_initialized = false
	_effective_tension = rope_tension
	_current_line_stress = 0.0
	if fishing_line:
		fishing_line.clear_points()
		fishing_line.default_color = line_color_normal
		fishing_line.width = 2.0

func _update_line_visual():
	if fishing_line == null or points.size() < 2:
		return
	fishing_line.clear_points()
	for p in points:
		fishing_line.add_point(p)

func _spawn_particles(pos: Vector2, direction: Vector2, duration: float = 0.3):
	if black_particle_scene == null:
		return
	var p = black_particle_scene.instantiate()
	if p == null:
		return
	p.use_player_layer = true
	var scene = get_tree().current_scene
	if scene == null:
		scene = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	scene.add_child(p)
	p.global_position = pos
	if p.has_method("set_direction"):
		p.call("set_direction", direction)
	if p.has_method("play"):
		p.call("play")

# ===== WATER =====
func set_in_water(in_w: bool, grav_red: float = 0.3):
	var was = is_in_water
	is_in_water = in_w
	water_gravity_multiplier = grav_red if in_w else 1.0
	if in_w and not was:
		take_damage(1)

func in_water():
	set_in_water(true, 0.3)

func exit_water():
	set_in_water(false)

# ===== API =====
func has_fish_hooked() -> bool:
	return fish_hooked and current_fish != null and is_instance_valid(current_fish)
func is_line_extended() -> bool:
	return line_extended
func is_fish_struggling() -> bool:
	return fish_struggle_active
func get_current_health() -> int:
	return current_health
func get_max_health() -> int:
	return max_health
func release_fish():
	if fish_hooked and current_fish:
		if is_instance_valid(current_fish):
			current_fish.queue_free()
		_on_fish_lost(false)
func retract_line():
	if line_extended:
		if fish_hooked:
			release_fish()
		_destroy_hook()
