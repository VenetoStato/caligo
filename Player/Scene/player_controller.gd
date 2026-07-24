extends CharacterBody2D

const FISH_CATCH_EFFECT_SCRIPT := preload("res://Fx/fish_catch_effect.gd")

signal respawned
signal fish_caught(health_restored: int)
signal tutorial_action_performed(action: StringName)
signal locked_skill_requested

# ===========================================
# PLAYER SCRIPT - VERSIONE CON DEATH SYSTEM
# ===========================================
# Fade in/out stile Hollow Knight
# Morte con freeze frame + particelle + respawn
# Vita visibile solo quando cambia

@export_category("Setup")
@export var sprite_node: Sprite2D

@export_category("Movement")
@export var move_speed: float = 120.0
@export var deceleration: float = 0.1
@export var ground_acceleration: float = 1800.0
@export var ground_deceleration: float = 2200.0
@export var air_acceleration: float = 900.0
@export var air_deceleration: float = 450.0
@export var gravity: float = 500.0

@export_category("Dash")
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var double_tap_time: float = 0.25
@export_range(0.0, 1.0) var dash_end_speed_multiplier: float = 0.45
@export var dash_cancel_on_wall: bool = true

@export_category("Jump")
@export var jump_speed: float = 190.0
@export var jump_acceleration: float = 290.0
@export var jump_amount: int = 2

@export_category("Water")
@export var water_bounce_speed: float = 190.0

@export_category("Fishing")
@export var hook_scene: PackedScene
@export var fishing_hook_scene: PackedScene
@export var pastura_scene: PackedScene
@export var max_line_length: float = 300.0
@export var cast_speed: float = 600.0
@export var max_charge_time: float = 1.0
@export var min_cast_power: float = 0.3
@export var grab_hook_unlocked := false

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
@export var line_color_wrong_reel: Color = Color(0.95, 0.2, 0.15)  # Rosso quando tiri durante la lotta

@export_category("Line Tuning")
@export var line_out_speed: float = 900.0
@export var reel_in_speed: float = 320.0
@export var reel_pull_force: float = 780.0
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
@export var ambient_trail_scene: PackedScene  # Scia solo su salto/dash (ambient particle)
@export var particles_on_dash: bool = true
@export var particles_on_jump: bool = true
@export var particles_on_attack: bool = true
@export var particles_on_move: bool = false
@export var particles_on_land: bool = true
@export var move_particle_interval: float = 0.03

@export_category("Fish Struggle")
@export var fish_struggle_interval: float = 1.2
@export var fish_escape_time: float = 1.9
@export var fish_struggle_phase_duration: float = 2.6
## Stress della lenza oltre cui il pesce si libera (1.0 = rossa piena). Se la lenza diventa troppo rossa durante la lotta, il pesce scappa
@export var stress_escape_threshold: float = 0.82
## Durata del "trascinamento" per ogni click di F (più alto = pesce si avvicina di più per click)
@export var reel_pulse_duration: float = 0.22
@export var fish_reel_distance: float = 30.0
@export var fish_catch_jump_distance: float = 50.0
@export var fish_pull_strength: float = 270.0
@export_range(1, 3, 1) var fish_health_reward: int = 1

@export_category("Health")
@export var max_health: int = 5
@export var invincibility_time: float = 1.5
@export var knockback_speed: float = 280.0
@export var knockback_duration: float = 0.2
@export var health_ui_offset: Vector2 = Vector2(0, -40)
@export var health_color_full: Color = Color(0.9, 0.2, 0.3)
@export var health_color_empty: Color = Color(0.3, 0.3, 0.3, 0.5)
@export var health_dot_size: float = 6.0
@export var health_dot_spacing: float = 14.0
@export var health_display_time: float = 3.0

@export_category("Cast UI")
## Angolo di mira durante caricamento (radianti). Positivo = su, negativo = giù. Usato quando non c'è mouse.
@export var cast_aim_angle_speed: float = 2.5
## Limite massimo angolo in su (gradi)
@export var cast_aim_max_up: float = 75.0
## Limite massimo angolo in giù (gradi)
@export var cast_aim_max_down: float = 45.0
## Barra di caricamento del lancio (visibile mentre tieni premuto F)
@export var cast_bar_offset: Vector2 = Vector2(0, -55)
@export var cast_bar_width: float = 60.0
@export var cast_bar_height: float = 6.0
@export var cast_bar_color: Color = Color(0.2, 0.7, 0.9, 0.9)
@export var cast_bar_bg_color: Color = Color(0.1, 0.1, 0.15, 0.7)
## Indicatore direzione di mira (freccia che mostra dove lancerai)
@export var direction_indicator_length: float = 85.0
@export var direction_indicator_lerp_speed: float = 5.0
## Velocità angolare max (rad/frame) - limita rotazione per evitare scatti
@export var direction_indicator_max_angular_speed: float = 0.05
@export var direction_indicator_color: Color = Color(0.95, 0.88, 0.35, 0.95)
@export var direction_indicator_outline_color: Color = Color(0.15, 0.12, 0.05, 0.9)
@export var direction_indicator_line_width: float = 3.0

@export_category("Death & Respawn")
## Gruppo dei nodi usati come checkpoint/spawn point
@export var spawn_point_group: String = "spawn_point"
## Se true, usa l'ultimo terreno toccato come respawn
@export var use_last_ground_as_respawn: bool = true
## Offset Y dal punto di respawn (per non spawnare nel terreno)
@export var respawn_y_offset: float = -20.0
## Frame preciso dello sprite da mostrare alla morte (indice del frame nello sprite sheet, es. 0-39 se 5x8)
@export var death_frame: int = 0
## Se true, alla morte il mondo si resetta (reload scena) e riparti dall'inizio (character_beginning + player)
@export var reload_scene_on_death: bool = true
## Percorso scena da ricaricare alla morte. Vuoto = usa scena corrente.
@export var reload_scene_path: String = "res://Levels/Scenes/test_area.tscn"
## Oltre questa Y (sotto questa altezza) il player muore (caduta nel vuoto). Più basso = più in alto sullo schermo.
@export var fall_death_y: float = 750.0

# Nodi
@onready var anim: AnimationPlayer = $anim
var fishing_line: Line2D = null
var transition_manager: Node = null
var _attack_hitbox: Area2D = null  # Area per colpire nemici (abilitata solo durante Attack_fast / Attack_strong)
var _attack_hit_enemies: Array[Node] = []  # nemici già colpiti in questo attacco (evita doppio danno)
var _current_attack_damage: int = 1  # 1 = attacco normale, 2 = attacco forte

# Health UI
var _health_states: Array[bool] = []
var _health_scales: Array[float] = []
var _health_pulse: Array[float] = []
var _health_visible: bool = true
var _health_visible_timer: float = 0.0
var _health_alpha: float = 1.0

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
var _water_owner: Node = null

# Health & Death
var current_health: int = 5
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var blink_timer: float = 0.0
var is_dead: bool = false
var _knockback_timer: float = 0.0
var last_safe_ground_position: Vector2 = Vector2.ZERO
var initial_spawn_position: Vector2 = Vector2.ZERO
var checkpoint_spawn_position: Vector2 = Vector2.ZERO
var has_active_checkpoint := false

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
var using_fishing_hook: bool = true  # Default: amo da pesca + pastura; C = altro (amo da lancio)
var current_fish: Node2D = null
var fish_hooked: bool = false
var fish_struggle_timer: float = 0.0
var fish_struggle_active: bool = false
var fish_escape_timer: float = 0.0
var fish_struggle_phase_timer: float = 0.0
var _fish_catch_jump_done: bool = false
var active_pastura: Node2D = null
var _effective_tension: float = 0.85
var _rope_initialized: bool = false
var _current_line_stress: float = 0.0
var _line_color_lerp_speed: float = 5.0
var reel_pulse_timer: float = 0.0
var _breath_timer: float = 0.0
var _breath_base_scale: Vector2 = Vector2.ONE
var _cast_aim_angle: float = 0.0  # radianti, 0=orizzontale, + = su, - = giù
var _display_cast_direction: Vector2 = Vector2.RIGHT
var _target_cast_direction: Vector2 = Vector2.RIGHT  # target filtrato (riduce jitter input)
var move_particle_timer: float = 0.0
var _was_on_floor := false

func _ready():
	add_to_group("player")
	# Fallback: se i particle (assegnati in editor) sono null, caricali da path
	if black_particle_scene == null:
		black_particle_scene = load("res://Fx/black_particle.tscn") as PackedScene
	if ambient_trail_scene == null:
		ambient_trail_scene = load("res://Fx/ambient_particle.tscn") as PackedScene
	_setup_sprite()
	_setup_fishing_line()
	_setup_health()
	_setup_transition_manager()
	_setup_attack_hitbox()
	_setup_fish_area()
	
	if anim:
		anim.animation_finished.connect(_on_anim_finished)
	
	current_health = max_health
	initial_spawn_position = global_position
	last_safe_ground_position = global_position
	_was_on_floor = is_on_floor()
	
	# La vita si mostra all'inizio (dopo il fade in)
	_show_health_ui()

func _setup_sprite():
	if sprite_node == null:
		sprite_node = get_node_or_null("Sprite2D")
		if sprite_node == null:
			sprite_node = get_node_or_null("Sprite")
	if sprite_node:
		_breath_base_scale = sprite_node.scale

func _setup_fishing_line():
	if has_node("FishingLine"):
		fishing_line = get_node("FishingLine") as Line2D
	var p = get_parent()
	if fishing_line == null and p and p.has_node("FishingLine"):
		fishing_line = p.get_node("FishingLine") as Line2D
	elif fishing_line == null and get_tree().current_scene and get_tree().current_scene.has_node("FishingLine"):
		fishing_line = get_tree().current_scene.get_node("FishingLine") as Line2D
	if fishing_line:
		fishing_line.top_level = true
		fishing_line.z_index = 20
		fishing_line.width = 3.0
		fishing_line.default_color = line_color_normal
		fishing_line.joint_mode = Line2D.LINE_JOINT_ROUND
		fishing_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		fishing_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		fishing_line.antialiased = true

func _setup_attack_hitbox():
	# Area che danneggia i nemici quando fai attacco (Z o click destro)
	_attack_hitbox = Area2D.new()
	_attack_hitbox.name = "AttackHitbox"
	_attack_hitbox.collision_layer = 4
	_attack_hitbox.collision_mask = 2
	_attack_hitbox.monitorable = true   # deve essere true così l'Hurtbox del nemico può rilevarla
	_attack_hitbox.monitoring = true
	_attack_hitbox.add_to_group("player_attack")
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 30)
	var col = CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(25, -10)
	_attack_hitbox.add_child(col)
	add_child(_attack_hitbox)
	_attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	_attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	_attack_hitbox.visible = false
	_update_attack_hitbox_position()
	_disable_attack_hitbox()
	# Player su layer 2, collide solo con layer 1 (terreno) così non si blocca col nemico
	collision_layer = 2
	collision_mask = 1

func _setup_fish_area():
	# FishArea è un Area2D solo trigger: quando il pesce agganciato entra, fa lo scatto a parabola verso il player
	var fish_area: Area2D = get_node_or_null("FishArea") as Area2D
	if fish_area != null:
		if not fish_area.body_entered.is_connected(_on_fish_area_body_entered):
			fish_area.body_entered.connect(_on_fish_area_body_entered)

func _on_fish_area_body_entered(body: Node2D):
	if not fish_hooked or current_fish == null or body != current_fish:
		return
	if _fish_catch_jump_done:
		return
	if body.has_method("do_catch_jump"):
		body.call("do_catch_jump")
		_fish_catch_jump_done = true

func _update_attack_hitbox_position():
	if _attack_hitbox == null:
		return
	var offset_x = 25 if facing_right else -25
	var col = _attack_hitbox.get_node_or_null("CollisionShape2D")
	if col:
		col.position = Vector2(offset_x, -10)

func _enable_attack_hitbox(damage: int = 1):
	_update_attack_hitbox_position()
	_attack_hit_enemies.clear()
	_current_attack_damage = damage
	if _attack_hitbox:
		_attack_hitbox.collision_layer = 4
		_attack_hitbox.collision_mask = 2
		_attack_hitbox.monitoring = true

func _disable_attack_hitbox():
	if _attack_hitbox:
		_attack_hitbox.collision_layer = 0
		_attack_hitbox.collision_mask = 0
		_attack_hitbox.monitoring = false

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	var parent: Node = area.get_parent()
	if parent.is_in_group("enemy") and parent not in _attack_hit_enemies:
		_attack_hit_enemies.append(parent)
		if parent.has_method("take_damage"):
			parent.take_damage(_current_attack_damage, global_position)
		_request_shake(0.38)
	elif parent.has_method("_on_hit"):
		_request_shake(0.35)

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("dead_enemy") and body is RigidBody2D:
		_request_shake(0.28)
		var dir: Vector2 = (body.global_position - global_position).normalized()
		dir.y = min(dir.y, -0.55)
		dir = dir.normalized()
		body.apply_central_impulse(dir * 520.0)
		body.apply_torque_impulse(sign(dir.x) * 220.0)

func _setup_health():
	_health_states.clear()
	_health_scales.clear()
	_health_pulse.clear()
	for i in range(max_health):
		_health_states.append(true)
		_health_scales.append(1.0)
		_health_pulse.append(0.0)

func _setup_transition_manager():
	# Cerca il TransitionManager nella scena
	transition_manager = get_tree().get_first_node_in_group("transition_manager")
	
	# Se non esiste, crealo
	if transition_manager == null:
		var tm_script = load("res://scripts/transition_manager.gd")
		if tm_script:
			transition_manager = tm_script.new()
			transition_manager.add_to_group("transition_manager")
			get_tree().root.add_child(transition_manager)
		else:
			# Crea un TransitionManager inline semplificato
			_create_simple_transition_manager()

func _create_simple_transition_manager():
	# Versione semplificata se lo script non è trovato
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "TransitionManager"
	canvas.add_to_group("transition_manager")
	
	var rect = ColorRect.new()
	rect.name = "FadeRect"
	rect.color = Color(0, 0, 0, 1)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)
	
	get_tree().root.add_child(canvas)
	transition_manager = canvas
	
	# Salta il fade in se siamo appena passati da Character Beginning (stessa scena)
	if get_meta("skip_initial_fade", false):
		rect.color.a = 0.0
	else:
		_simple_fade_in(rect)

func _simple_fade_in(rect: ColorRect):
	var tween = create_tween()
	tween.tween_property(rect, "color:a", 0.0, 1.0)

func _on_anim_finished(anim_name: String):
	if anim_name == "Fishing":
		fishing_anim_finished = true
	if anim_name == "Attack_fast" or anim_name == "Attack_strong":
		_disable_attack_hitbox()
		_attack_hit_enemies.clear()

# ===========================================
# SCREEN SHAKE
# ===========================================
func _request_shake(intensity: float):
	var cam = get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("add_shake"):
		cam.add_shake(intensity)

# ===========================================
# HEALTH UI
# ===========================================
func _show_health_ui():
	_health_visible = true
	_health_visible_timer = health_display_time
	_health_alpha = 1.0

func _update_breathing(delta: float):
	if sprite_node and not is_dead:
		_breath_timer += delta
		var t = sin(_breath_timer * 2.2)
		# Respiro ridotto: solo parte alta (pivot ai piedi via offset), ampiezza minore
		var breath_y = 1.0 + 0.035 * t
		var breath_x = 1.0 - 0.012 * t
		sprite_node.scale = Vector2(_breath_base_scale.x * breath_x, _breath_base_scale.y * breath_y)

func _update_health_visibility(delta: float):
	if _health_visible:
		_health_visible_timer -= delta
		if _health_visible_timer <= 0.5:
			_health_alpha = max(0.0, _health_visible_timer / 0.5)
		else:
			_health_alpha = 1.0
		if _health_visible_timer <= 0:
			_health_visible = false
			_health_alpha = 0.0

func _draw():
	# Barra di caricamento del lancio (visibile mentre tieni premuto F o Grab)
	if is_charging:
		_draw_cast_charge_bar()
		_draw_cast_direction_indicator()
	
	if _health_alpha <= 0.01:
		return
	
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
		col.a *= _health_alpha
		
		draw_circle(pos, rad, col)
		
		var border_col = col.darkened(0.3)
		border_col.a = col.a
		draw_arc(pos, rad, 0, TAU, 24, border_col, 1.5)
		
		if is_full:
			var highlight = Color(1, 1, 1, 0.3 * _health_alpha)
			draw_circle(pos + Vector2(-rad * 0.25, -rad * 0.25), rad * 0.25, highlight)

# ===========================================
# CAST UI (barra caricamento + direzione)
# ===========================================
func _draw_cast_charge_bar():
	var progress = clamp(current_charge_time / max_charge_time, 0.0, 1.0)
	var half_w = cast_bar_width / 2.0
	var pos = cast_bar_offset
	# Sfondo
	draw_rect(Rect2(pos.x - half_w, pos.y - cast_bar_height / 2, cast_bar_width, cast_bar_height), cast_bar_bg_color)
	draw_rect(Rect2(pos.x - half_w + 1, pos.y - cast_bar_height / 2 + 1, cast_bar_width - 2, cast_bar_height - 2), cast_bar_bg_color.darkened(0.2))
	# Riempimento
	var fill_w = (cast_bar_width - 4) * progress
	if fill_w > 1.0:
		draw_rect(Rect2(pos.x - half_w + 2, pos.y - cast_bar_height / 2 + 2, fill_w, cast_bar_height - 4), cast_bar_color)

func _draw_cast_direction_indicator():
	var rod_local = base_axis_offset + (line_origin_offset_right if facing_right else line_origin_offset_left) + (rod_tip_offset_right if facing_right else rod_tip_offset_left)
	var dir = _display_cast_direction.normalized() if _display_cast_direction.length_squared() > 0.01 else Vector2.RIGHT
	var power: float = clampf(current_charge_time / maxf(max_charge_time, 0.01), min_cast_power, 1.0)
	var preview_speed: float = cast_speed * power
	for index in range(1, 9):
		var time := float(index) * 0.075
		var preview_point: Vector2 = rod_local + dir * preview_speed * time + Vector2(0, 490.0 * time * time)
		var alpha := 0.62 * (1.0 - float(index - 1) / 10.0)
		draw_circle(preview_point, 2.8 if index < 5 else 2.1, Color(0.45, 0.95, 0.78, alpha))
	var shaft_end = rod_local + dir * (direction_indicator_length - 22.0)
	var end = rod_local + dir * direction_indicator_length
	var perp = Vector2(-dir.y, dir.x)
	var w = direction_indicator_line_width * 0.5
	# Linea principale con contorno
	draw_line(rod_local - perp * (w + 1.0), shaft_end - perp * (w + 1.0), direction_indicator_outline_color)
	draw_line(rod_local + perp * (w + 1.0), shaft_end + perp * (w + 1.0), direction_indicator_outline_color)
	draw_line(rod_local, shaft_end, direction_indicator_color)
	draw_line(rod_local - perp * w, shaft_end - perp * w, direction_indicator_color)
	draw_line(rod_local + perp * w, shaft_end + perp * w, direction_indicator_color)
	# Freccetta (triangolo pieno con bordo)
	var arrow_len = 22.0
	var arrow_w = 16.0
	var tip = end
	var base_center = end - dir * arrow_len
	var p1 = base_center + perp * arrow_w * 0.5
	var p2 = base_center - perp * arrow_w * 0.5
	var arrow_pts: PackedVector2Array = [tip, p1, p2]
	draw_colored_polygon(arrow_pts, direction_indicator_outline_color)
	var tip_in = end - dir * 3.0
	var p1_in = base_center + perp * arrow_w * 0.32
	var p2_in = base_center - perp * arrow_w * 0.32
	var arrow_inner: PackedVector2Array = [tip_in, p1_in, p2_in]
	draw_colored_polygon(arrow_inner, direction_indicator_color)

func _input(event):
	# Ignora input se morto
	if is_dead:
		return
	
	if event.is_action_pressed("change_hook"):
		if not grab_hook_unlocked:
			using_fishing_hook = true
			locked_skill_requested.emit()
			return
		if line_extended:
			return
		using_fishing_hook = !using_fishing_hook
		return
	
	if event.is_action_pressed("grab"):
		if line_extended and hook_instance and line_mode == LineMode.GRAB:
			detach_grab_anchor()
			return
	
	if event.is_action_pressed("cast"):
		if not line_extended and hook_instance == null:
			line_mode = LineMode.FISHING if using_fishing_hook or not grab_hook_unlocked else LineMode.GRAB
			is_charging = true
			current_charge_time = 0.0
			_reset_cast_aim_from_mouse()
	
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
					_reset_cast_aim_from_mouse()
	
	if event.is_action_released("cast") or event.is_action_released("grab"):
		if is_charging:
			is_charging = false
			cast_hook_charged()
	
	if event.is_action_pressed("reel"):
		if line_extended and hook_instance:
			tutorial_action_performed.emit(&"reel")
			if fish_hooked:
				# Pesca: click per trascinare (non tenere premuto). Ogni click = breve impulso di reel
				reel_pulse_timer = reel_pulse_duration
				_request_shake(0.22)
			else:
				# Grab: tenere premuto per riavvolgere
				is_reeling = true
	
	if event.is_action_released("reel"):
		if not fish_hooked:
			is_reeling = false

func _physics_process(delta: float):
	# Non processare se morto
	if is_dead:
		return
	
	_update_dash_timers(delta)
	_check_dash_input()
	_update_invincibility(delta)
	_update_health_anims(delta)
	_update_health_visibility(delta)
	_update_breathing(delta)
	
	if _process_dash(delta):
		return
	
	_apply_gravity(delta)
	# Durante il rinculo non applicare movimento orizzontale da input
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, knockback_speed * 4.0 * delta)
	else:
		horizontal_movement(delta)
	flip_logic()
	
	if is_charging:
		current_charge_time = min(current_charge_time + delta, max_charge_time)
		_update_cast_aim(delta)
	
	# Caduta oltre fall_death_y = morte (non cadere all'infinito)
	if global_position.y > fall_death_y:
		_on_death()
		return
	
	var impact_speed := velocity.y
	move_and_slide()
	if particles_on_land and not _was_on_floor and is_on_floor() and impact_speed > 95.0:
		if black_particle_scene:
			_spawn_particles(global_position + Vector2(0, 4), Vector2.UP, 0.18, 4)
		if ambient_trail_scene:
			_spawn_trail(global_position + Vector2(0, 4), Vector2.UP)
		_request_shake(minf(0.16, impact_speed / 1800.0))
	_was_on_floor = is_on_floor()
	
	# Aggiorna l'ultima posizione sicura sul terreno
	if is_on_floor():
		last_safe_ground_position = global_position
	
	set_animation()
	jump_logic()
	_process_fishing(delta)
	queue_redraw()

func _process(delta: float) -> void:
	# Freccia aggiornata ogni frame (non solo physics) = più fluida
	if is_charging:
		var raw := get_cast_direction()
		if raw.length_squared() > 0.01:
			# 1) Filtra il target per ridurre jitter da joystick/touch
			_target_cast_direction = _target_cast_direction.lerp(raw.normalized(), clampf(1.0 - exp(-12.0 * delta), 0.0, 1.0))
			_target_cast_direction = _target_cast_direction.normalized()
			# 2) Rotazione con cap velocità angolare (smooth, niente scatti)
			var cur_angle := atan2(_display_cast_direction.y, _display_cast_direction.x) if _display_cast_direction.length_squared() > 0.001 else atan2(_target_cast_direction.y, _target_cast_direction.x)
			var tar_angle := atan2(_target_cast_direction.y, _target_cast_direction.x)
			var diff := angle_difference(cur_angle, tar_angle)
			var max_step := direction_indicator_max_angular_speed * (delta * 60.0)  # invariante al framerate
			var step := clampf(diff, -max_step, max_step)
			var new_angle := cur_angle + step
			_display_cast_direction = Vector2(cos(new_angle), sin(new_angle))
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
			# Lampeggio leggero: alterna tra colore normale e lieve flash bianco/rosso
			var t: float = 0.5 + 0.5 * sin(blink_timer * 14.0)
			sprite_node.modulate = Color(lerp(0.85, 1.35, t), lerp(0.75, 1.0, t), lerp(0.75, 1.0, t), lerp(0.55, 1.0, t))
		if invincibility_timer <= 0:
			is_invincible = false
			if sprite_node:
				sprite_node.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _update_dash_timers(delta: float):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
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
	dash_cooldown_timer = dash_duration + dash_cooldown
	dash_direction = direction.normalized()
	dash_particle_timer = 0.0
	facing_right = direction.x > 0
	velocity.y = 0
	tutorial_action_performed.emit(&"dash")
	if particles_on_dash and black_particle_scene:
		_spawn_particles(global_position, -direction, 0.3, 2)
	if particles_on_dash and ambient_trail_scene:
		_spawn_trail(global_position, -direction)

func _process_dash(delta: float) -> bool:
	if not is_dashing:
		return false
	dash_timer -= delta
	dash_particle_timer -= delta
	if dash_particle_timer <= 0:
		dash_particle_timer = 0.015
		if particles_on_dash and black_particle_scene:
			_spawn_particles(global_position, -dash_direction, 0.4, 2)
		if particles_on_dash and ambient_trail_scene:
			_spawn_trail(global_position, -dash_direction)
	if dash_timer <= 0:
		_end_dash()
		return false
	velocity.x = dash_direction.x * dash_speed
	velocity.y = 0
	move_and_slide()
	if dash_cancel_on_wall and is_on_wall():
		_end_dash()
	anim.play("Dash" if anim.has_animation("Dash") else "Walking")
	return true

func _end_dash():
	if not is_dashing:
		return
	is_dashing = false
	velocity.x *= dash_end_speed_multiplier

func _apply_gravity(delta: float):
	velocity.y += gravity * water_gravity_multiplier * delta

func horizontal_movement(delta: float):
	if is_dashing:
		return
	if is_charging:
		var charge_deceleration := ground_deceleration if is_on_floor() else air_deceleration
		velocity.x = move_toward(velocity.x, 0.0, charge_deceleration * delta)
		return
	movement = Input.get_axis("ui_left", "ui_right")
	var target_speed := movement * move_speed
	if not is_zero_approx(movement):
		var acceleration := ground_acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	else:
		var stop_rate := ground_deceleration if is_on_floor() else air_deceleration
		velocity.x = move_toward(velocity.x, 0.0, stop_rate * delta)

func flip_logic():
	if movement > 0:
		facing_right = true
	elif movement < 0:
		facing_right = false
	if sprite_node:
		sprite_node.flip_h = !facing_right
	_update_attack_hitbox_position()

func set_animation():
	if Input.is_action_just_pressed("ui_attack_strong") and not line_extended:
		if anim.has_animation("Attack_strong"):
			anim.play("Attack_strong")
			_enable_attack_hitbox(2)
			tutorial_action_performed.emit(&"attack")
			if particles_on_attack and black_particle_scene:
				_spawn_particles(global_position, Vector2.RIGHT if facing_right else Vector2.LEFT, 0.25)
		return
	if Input.is_action_just_pressed("ui_attack") and not line_extended:
		anim.play("Attack_fast")
		_enable_attack_hitbox(1)
		tutorial_action_performed.emit(&"attack")
		if particles_on_attack and black_particle_scene:
			_spawn_particles(global_position, Vector2.RIGHT if facing_right else Vector2.LEFT, 0.2)
		return
	if (anim.current_animation == "Attack_fast" or anim.current_animation == "Attack_strong") and anim.is_playing():
		return
	# Non siamo in attacco: hitbox disabilitata così il nemico non prende danno solo avvicinandosi
	_disable_attack_hitbox()
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
			tutorial_action_performed.emit(&"jump")
			if particles_on_jump and black_particle_scene:
				_spawn_particles(global_position, Vector2.DOWN, 0.2)
			if particles_on_jump and ambient_trail_scene:
				_spawn_trail(global_position, Vector2.DOWN)
	elif jump_amount > 0 and Input.is_action_just_pressed("ui_accept"):
		jump_amount -= 1
		velocity.y -= lerp(jump_speed, jump_acceleration, 1.0)
		tutorial_action_performed.emit(&"double_jump")
		if particles_on_jump and black_particle_scene:
			_spawn_particles(global_position, Vector2.DOWN, 0.2)
		if particles_on_jump and ambient_trail_scene:
			_spawn_trail(global_position, Vector2.DOWN)

# ===========================================
# HEALTH & DEATH SYSTEM
# ===========================================
func take_damage(
	amount: int = 1,
	source_position: Vector2 = Vector2.ZERO,
	ignore_invincibility: bool = false
):
	if (is_invincible and not ignore_invincibility) or is_dead:
		return
	
	# Rinculo: spinta nella direzione opposta a chi ci ha colpito
	if source_position != Vector2.ZERO:
		var dir := (global_position - source_position).normalized()
		dir.x = sign(dir.x)  # orizzontale netto
		dir.y = -0.6  # componente verso l'alto per un rinculo "rimbalzante"
		dir = dir.normalized()
		velocity = dir * knockback_speed
		_knockback_timer = knockback_duration
	
	current_health = max(0, current_health - amount)
	
	for i in range(max_health):
		var was = _health_states[i]
		_health_states[i] = i < current_health
		if was and not _health_states[i]:
			_health_scales[i] = 0.3
			_health_pulse[i] = 0.0
	
	_show_health_ui()
	
	is_invincible = true
	invincibility_timer = invincibility_time
	blink_timer = 0.0
	
	_request_shake(0.42)
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
		_show_health_ui()
		print("💚 Curato! Vita: ", current_health)

func _on_death():
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector2.ZERO
	
	print("☠️ MORTE!")
	
	# La morte usa la caduta in loop lento: evita il frame statico incoerente.
	if anim and anim.has_animation("Falling"):
		anim.play("Falling", -1.0, 0.55)
	elif sprite_node != null and "frame" in sprite_node:
		sprite_node.frame = death_frame
	
	# Reset mondo: reload scena e riparti dall'inizio
	if reload_scene_on_death:
		_run_death_then_reload_scene()
		return
	
	# Respawn nel mondo (checkpoint / ultimo terreno)
	var respawn_pos = _find_respawn_position()
	if transition_manager and transition_manager.has_method("play_death_sequence"):
		transition_manager.call("play_death_sequence", self, respawn_pos)
	else:
		await _simple_death_sequence(respawn_pos)

func _run_death_then_reload_scene():
	# Morte → particelle → fade out → reload scena (mondo resetta, riparti dall'inizio)
	_spawn_death_particles()
	Engine.time_scale = 0.2
	await get_tree().create_timer(0.35).timeout
	Engine.time_scale = 1.0
	var fade_rect = _get_or_create_fade_rect()
	if fade_rect:
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 1.0)
		await tween.finished
	await get_tree().create_timer(0.4).timeout
	# Reload scena: tutto torna com'era all'inizio (character_beginning + player dopo intro)
	var tree := get_tree()
	var path: String = reload_scene_path
	if path.is_empty() and tree.current_scene != null:
		path = tree.current_scene.scene_file_path
	# Rimuovi il fade nero dalla root, altrimenti resta lo schermo nero dopo il reload
	var tm = transition_manager
	if tm != null and is_instance_valid(tm) and tm.get_parent() == tree.root:
		tm.queue_free()
	if not path.is_empty():
		tree.call_deferred("change_scene_to_file", path)
	else:
		tree.call_deferred("reload_current_scene")

func _simple_death_sequence(respawn_pos: Vector2):
	# Spawn particelle di morte
	_spawn_death_particles()
	
	# Slow-mo death cam (più lungo)
	Engine.time_scale = 0.18
	await get_tree().create_timer(0.25).timeout
	Engine.time_scale = 1.0
	
	# Fade out
	var fade_rect = _get_or_create_fade_rect()
	if fade_rect:
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 0.9)
		await tween.finished
	
	# Respawn
	global_position = respawn_pos
	_on_respawn()
	
	# Pausa al nero
	await get_tree().create_timer(0.5).timeout
	
	# Fade in
	if fade_rect:
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 0.0, 1.0)
		await tween.finished

func _get_or_create_fade_rect() -> ColorRect:
	if transition_manager:
		var rect = transition_manager.get_node_or_null("FadeRect")
		if rect:
			rect.visible = true
			return rect
	return null

func _spawn_death_particles():
	if black_particle_scene == null:
		return
	
	var count = 12
	var container = get_parent() if get_parent() else get_tree().current_scene
	for i in range(count):
		var p = black_particle_scene.instantiate()
		container.add_child(p)
		p.global_position = global_position
		
		var angle = (float(i) / count) * TAU
		var dir = Vector2(cos(angle), sin(angle))
		
		if p.has_method("set_direction"):
			p.call("set_direction", dir)
		if p.has_method("play"):
			p.call("play")

func _find_respawn_position() -> Vector2:
	# 1. Un checkpoint esplicito deve avere precedenza sul terreno e sullo spawn.
	if has_active_checkpoint:
		return checkpoint_spawn_position

	# 2. Cerca spawn point nella scena
	var spawn_points = get_tree().get_nodes_in_group(spawn_point_group)
	if spawn_points.size() > 0:
		# Trova lo spawn point più vicino
		var closest: Node2D = null
		var closest_dist = INF
		for sp in spawn_points:
			if sp is Node2D:
				var dist = global_position.distance_to(sp.global_position)
				if dist < closest_dist:
					closest_dist = dist
					closest = sp
		if closest:
			return closest.global_position + Vector2(0, respawn_y_offset)
	
	# 3. Usa l'ultima posizione sicura sul terreno
	if use_last_ground_as_respawn and last_safe_ground_position != Vector2.ZERO:
		return last_safe_ground_position + Vector2(0, respawn_y_offset)
	
	# 4. Fallback: posizione iniziale
	return initial_spawn_position

func _on_respawn():
	# Reset dello stato
	is_dead = false
	current_health = max_health
	velocity = Vector2.ZERO
	is_invincible = true
	invincibility_timer = invincibility_time
	blink_timer = 0.0
	
	# Reset vita UI
	for i in range(max_health):
		_health_states[i] = true
		_health_scales[i] = 1.0
		_health_pulse[i] = 0.0
	
	# Reset fishing
	if line_extended:
		_destroy_hook()
	
	# Riprendi animazione
	if anim:
		anim.play("Idle")
	
	# Reset sprite (colore normale; il lampeggio invincibilità parte subito dopo)
	if sprite_node:
		sprite_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	_show_health_ui()
	respawned.emit()
	
	print("🔄 Respawn!")

# ===========================================
# OFFSETS
# ===========================================
func get_base_axis_position() -> Vector2:
	return to_global(base_axis_offset)

func get_line_origin_position() -> Vector2:
	return get_base_axis_position() + (line_origin_offset_right if facing_right else line_origin_offset_left)

func get_rod_tip_position() -> Vector2:
	return get_line_origin_position() + (rod_tip_offset_right if facing_right else rod_tip_offset_left)

func get_facing_vector() -> Vector2:
	return Vector2.RIGHT if facing_right else Vector2.LEFT

func _reset_cast_aim_from_mouse():
	## Inizializza _cast_aim_angle dalla posizione mouse (o default se non disponibile)
	var start = get_rod_tip_position()
	var aim = get_global_mouse_position()
	var diff = aim - start
	if diff.length_squared() > 400.0:  # min 20px di distanza per considerare il mouse valido
		diff = diff.normalized()
		var facing = get_facing_vector()
		if diff.dot(facing) >= min_forward_aim_dot:
			_cast_aim_angle = atan2(-diff.y, diff.x * facing.x)
		else:
			_cast_aim_angle = atan2(-diff.y, 0.01) * sign(facing.x)
	else:
		_cast_aim_angle = -deg_to_rad(25.0) * sign(get_facing_vector().x)  # default leggermente verso l'alto
	var d := get_cast_direction()
	_display_cast_direction = d
	_target_cast_direction = d

func _update_cast_aim(delta: float):
	## Durante il caricamento: mouse ha priorità, altrimenti aim_up/aim_down
	var start = get_rod_tip_position()
	var aim = get_global_mouse_position()
	var diff = aim - start
	if diff.length_squared() > 400.0:
		diff = diff.normalized()
		var facing = get_facing_vector()
		if diff.dot(facing) >= min_forward_aim_dot:
			_cast_aim_angle = atan2(-diff.y, diff.x * facing.x)
	else:
		var max_up_rad = deg_to_rad(cast_aim_max_up)
		var max_down_rad = deg_to_rad(cast_aim_max_down)
		if Input.is_action_pressed("aim_up"):
			_cast_aim_angle += cast_aim_angle_speed * delta
		if Input.is_action_pressed("aim_down"):
			_cast_aim_angle -= cast_aim_angle_speed * delta
		_cast_aim_angle = clampf(_cast_aim_angle, -max_down_rad, max_up_rad)

func get_cast_direction() -> Vector2:
	var facing = get_facing_vector()
	# Joystick mobile: usa direzione se valida (anche al release, quando active=false ma direction non ancora azzerata)
	if MobileControlsManager.cast_joystick_direction.length_squared() > 0.01:
		var j := MobileControlsManager.cast_joystick_direction
		var dir := j.normalized()
		if dir.dot(facing) < min_forward_aim_dot:
			dir = Vector2(facing.x, dir.y).normalized()
		return dir
	var start = get_rod_tip_position()
	var aim = get_global_mouse_position()
	var diff = aim - start
	# Mouse valido (distanza > 20px)? Usalo
	if diff.length_squared() > 400.0:
		var dir = diff.normalized()
		if dir.dot(facing) < min_forward_aim_dot:
			dir = Vector2(facing.x, dir.y).normalized()
		return dir
	# Altrimenti usa _cast_aim_angle (su = -y in world space)
	var dir = Vector2(cos(_cast_aim_angle), -sin(_cast_aim_angle)) * facing.x
	return dir.normalized()

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

# ===========================================
# GRAB ANCHORS
# ===========================================
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

# ===========================================
# CAST
# ===========================================
func cast_hook_charged():
	# C = toggle PESCA ↔ HOOK TRASCINO. F lancia il tipo selezionato.
	# PESCA (using_fishing_hook=true) → fishing hook | TRASCINO (false) → grab hook
	var scene: PackedScene
	if line_mode == LineMode.GRAB:
		scene = hook_scene
	else:
		scene = fishing_hook_scene if using_fishing_hook and fishing_hook_scene else hook_scene
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
	tutorial_action_performed.emit(&"cast")
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

# ===========================================
# ROPE
# ===========================================
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
	# Pesca: reel a click (pulse) invece di hold
	if fish_hooked:
		if reel_pulse_timer > 0:
			reel_pulse_timer -= delta
			is_reeling = reel_pulse_timer > 0
		else:
			is_reeling = false
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
		if fish_hooked and is_instance_valid(current_fish):
			# Pesce agganciato: la corda non può essere più corta della distanza rod–pesce, così si accorcia fino al pesce
			var rod := get_rod_tip_position()
			var fish_pos := get_fish_center_position(current_fish)
			var actual_dist := rod.distance_to(fish_pos)
			current_line_length = max(actual_dist, current_line_length - spd * delta)
			_reel_fish_to_player()
		else:
			current_line_length -= spd * delta
			if current_line_length < 20.0:
				if line_mode == LineMode.GRAB:
					detach_grab_anchor()
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
				# Tirare durante la lotta = lenza rossa, pesce si stacca
				stress = 1.0
				col = line_color_wrong_reel
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
	fishing_line.width = lerp(2.8, 4.6, _current_line_stress)
	# Se la lenza diventa troppo rossa durante la lotta, il pesce si libera
	if fish_hooked and fish_struggle_active and _current_line_stress >= stress_escape_threshold:
		_on_fish_escaped()

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
	# Durante la lotta non tirare: se tiri lo stesso, la lenza va rossa e il pesce scappa (gestito in _update_fish_struggle)
	if fish_hooked and fish_struggle_active:
		return
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

# ===========================================
# FISH SYSTEM
# ===========================================
func on_fish_hooked(fish: Node2D):
	if fish == null or fish_hooked:
		return
	current_fish = fish
	fish_hooked = true
	fish_struggle_timer = 0.0
	fish_escape_timer = 0.0
	fish_struggle_active = false
	_fish_catch_jump_done = false
	if fish.has_method("set_player_reference"):
		fish.call("set_player_reference", self)
	_update_effective_tension()
	if hook_instance and is_instance_valid(hook_instance):
		if hook_instance.has_method("set_hooked_fish"):
			hook_instance.call("set_hooked_fish", fish)
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
	# Pesce rosso quando tiri durante la lotta
	if current_fish.has_method("set_wrong_reel"):
		current_fish.call("set_wrong_reel", fish_struggle_active and is_reeling)
	fish_struggle_timer += delta
	if fish_struggle_timer >= fish_struggle_interval and not fish_struggle_active:
		fish_struggle_timer = 0.0
		fish_struggle_active = true
		fish_escape_timer = 0.0
		fish_struggle_phase_timer = 0.0
		if current_fish.has_method("start_struggle"):
			current_fish.call("start_struggle")
	if fish_struggle_active:
		if is_reeling:
			# Tirare durante la lotta = sbagliato: il pesce scappa più velocemente se tiri
			fish_escape_timer += delta * 0.6
			if fish_escape_timer >= fish_escape_time:
				_on_fish_escaped()
		else:
			# Non tiri: la fase di lotta dopo un po' finisce e puoi reelare di nuovo (più reel!)
			fish_struggle_phase_timer += delta
			if fish_struggle_phase_timer >= fish_struggle_phase_duration:
				_stop_fish_struggle()
			else:
				fish_escape_timer += delta * 0.5
				if current_fish.has_method("apply_struggle_force"):
					var rod = get_rod_tip_position()
					var fp = get_fish_center_position(current_fish)
					current_fish.call("apply_struggle_force", (fp - rod).normalized() * fish_pull_strength * delta)
				if fish_escape_timer >= fish_escape_time:
					_on_fish_escaped()

func _stop_fish_struggle():
	fish_struggle_active = false
	fish_escape_timer = 0.0
	fish_struggle_phase_timer = 0.0
	fish_struggle_timer = 0.0
	if current_fish and is_instance_valid(current_fish) and current_fish.has_method("stop_struggle"):
		current_fish.call("stop_struggle")

func _on_fish_escaped():
	print("💨 Pesce scappato!")
	# L'amo resta dove il pesce si è staccato (non torna al punto del morso)
	if current_fish and is_instance_valid(current_fish) and hook_instance and is_instance_valid(hook_instance):
		var fish_pos: Vector2 = get_fish_center_position(current_fish)
		if hook_instance is RigidBody2D:
			hook_instance.global_position = fish_pos
			hook_instance.linear_velocity = Vector2.ZERO
		elif hook_instance is Node2D:
			hook_instance.global_position = fish_pos
		# Allinea la corda all'amo nella nuova posizione
		if points.size() >= 2:
			points[points.size() - 1] = fish_pos
			if old_points.size() >= 2:
				old_points[old_points.size() - 1] = fish_pos
	if current_fish and is_instance_valid(current_fish):
		if current_fish.has_method("release_from_hook"):
			current_fish.call("release_from_hook")
	_on_fish_lost(true)

func _on_fish_lost(_escaped: bool):
	fish_hooked = false
	current_fish = null
	fish_struggle_active = false
	fish_escape_timer = 0.0
	fish_struggle_phase_timer = 0.0
	fish_struggle_timer = 0.0
	reel_pulse_timer = 0.0
	is_reeling = false
	_update_effective_tension()
	if hook_instance and is_instance_valid(hook_instance):
		if hook_instance.has_method("set_hooked_fish"):
			hook_instance.call("set_hooked_fish", null)
		if hook_instance.has_method("show_hook"):
			hook_instance.call("show_hook")

func _reel_fish_to_player():
	if not is_instance_valid(current_fish):
		fish_hooked = false
		current_fish = null
		_destroy_hook()
		return
	var dist = global_position.distance_to(current_fish.global_position)
	var horizontal_dist := absf(global_position.x - current_fish.global_position.x)
	# Salto: quando il pesce è in FishArea, O entro fish_catch_jump_distance, O vicino al player E vicino alla superficie (può uscire anche con collider)
	var fish_area: Area2D = get_node_or_null("FishArea") as Area2D
	var in_area: bool = fish_area != null and current_fish in fish_area.get_overlapping_bodies()
	var near_surface: bool = current_fish.has_method("is_near_surface") and current_fish.call("is_near_surface")
	var reel_zone_dist: float = 100.0
	if not _fish_catch_jump_done and current_fish.has_method("do_catch_jump"):
		if in_area:
			current_fish.call("do_catch_jump")
			_fish_catch_jump_done = true
		elif dist < fish_catch_jump_distance and dist >= fish_reel_distance:
			current_fish.call("do_catch_jump")
			_fish_catch_jump_done = true
		elif horizontal_dist < reel_zone_dist and near_surface:
			current_fish.call("do_catch_jump")
			_fish_catch_jump_done = true
	var reached_pontile_edge := (
		_fish_catch_jump_done
		and horizontal_dist < fish_reel_distance
		and (near_surface or not bool(current_fish.call("is_in_water")))
	)
	if dist < fish_reel_distance or reached_pontile_edge:
		_complete_fish_catch(current_fish)
	else:
		var rod = get_rod_tip_position()
		var dir = (rod - current_fish.global_position).normalized()
		if current_fish.has_method("apply_reel_force"):
			current_fish.call("apply_reel_force", dir * reel_pull_force * 1.5)


func _complete_fish_catch(fish: Node2D) -> void:
	if fish == null or not is_instance_valid(fish):
		return
	print("🏆 Pesce catturato: nutrimento recuperato!")
	var health_before := current_health
	heal(fish_health_reward)
	var health_restored := current_health - health_before
	_spawn_fish_catch_effect(fish.global_position, health_restored)
	fish_caught.emit(health_restored)
	var am := get_node_or_null("/root/AchievementManager")
	if am != null and am.has_method("add_fish_caught"):
		am.call("add_fish_caught")
	fish.queue_free()
	fish_hooked = false
	current_fish = null
	_destroy_hook()


func _spawn_fish_catch_effect(world_position: Vector2, health_restored: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var effect := Node2D.new()
	effect.name = "FishCatchEffect"
	effect.set_script(FISH_CATCH_EFFECT_SCRIPT)
	scene.add_child(effect)
	effect.global_position = world_position
	effect.call("setup", health_restored)


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
	fish_struggle_phase_timer = 0.0
	fish_struggle_timer = 0.0
	_rope_initialized = false
	_effective_tension = rope_tension
	_current_line_stress = 0.0
	if fishing_line:
		fishing_line.clear_points()
		fishing_line.default_color = line_color_normal
		fishing_line.width = 3.0

func _update_line_visual():
	if fishing_line == null or points.size() < 2:
		return
	fishing_line.clear_points()
	for p in points:
		fishing_line.add_point(p)

func _spawn_particles(pos: Vector2, direction: Vector2, _duration: float = 0.3, amount_override: int = -1):
	if black_particle_scene == null:
		return
	var p = black_particle_scene.instantiate()
	if p == null:
		return
	p.use_player_layer = true
	if amount_override > 0 and p.has_method("set_amount"):
		p.set_amount(amount_override)
	# Aggiungi come sibling del player (stesso parent) così z/draw order è corretto
	var container = get_parent()
	if container == null:
		container = get_tree().current_scene
	if container == null:
		container = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	container.add_child(p)
	p.global_position = pos
	if p.has_method("set_direction"):
		p.call("set_direction", direction)
	if p.has_method("play"):
		p.call("play")

func _spawn_trail(pos: Vector2, direction: Vector2):
	"""Scia ambient particle solo su salto/dash"""
	if ambient_trail_scene == null:
		return
	var p = ambient_trail_scene.instantiate()
	if p == null:
		return
	var container = get_parent()
	if container == null:
		container = get_tree().current_scene
	if container == null:
		container = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	container.add_child(p)
	p.global_position = pos
	if p.has_method("set_direction"):
		p.call("set_direction", direction)
	if p.has_method("play"):
		p.call("play")

# ===========================================
# WATER
# ===========================================
func set_in_water(in_w: bool, grav_red: float = 0.3, water_owner: Node = null):
	var was := is_in_water
	is_in_water = in_w
	water_gravity_multiplier = clampf(grav_red, 0.0, 1.0) if in_w else 1.0
	if in_w and not was:
		_water_owner = water_owner
		velocity.y = -water_bounce_speed
		take_damage(1, Vector2.ZERO, true)
	elif not in_w:
		_water_owner = null

func in_water(water_owner: Node = null):
	set_in_water(true, 0.3, water_owner)

func exit_water():
	if is_in_water:
		_request_water_splash()
	set_in_water(false)

func _request_water_splash():
	if is_instance_valid(_water_owner) and _water_owner.has_method("splash_at"):
		var direction := 1.0 if velocity.y > 0.0 else -1.0
		var impulse := direction * maxf(absf(velocity.y), 90.0) * 0.65
		_water_owner.call_deferred("splash_at", global_position.x, impulse, 72.0)

# ===========================================
# API
# ===========================================
func has_fish_hooked() -> bool:
	return fish_hooked and current_fish != null and is_instance_valid(current_fish)

func is_line_extended() -> bool:
	return line_extended


func unlock_grab_hook() -> void:
	grab_hook_unlocked = true
	using_fishing_hook = true


func is_grab_hook_unlocked() -> bool:
	return grab_hook_unlocked


func is_fish_struggling() -> bool:
	return fish_struggle_active

func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_player_dead() -> bool:
	return is_dead

func release_fish():
	if fish_hooked and current_fish:
		if is_instance_valid(current_fish) and current_fish.has_method("release_from_hook"):
			current_fish.call("release_from_hook")
		_on_fish_lost(false)

func retract_line():
	if line_extended:
		if fish_hooked:
			release_fish()
		_destroy_hook()

# Imposta un checkpoint manuale
func set_checkpoint(pos: Vector2):
	checkpoint_spawn_position = pos
	has_active_checkpoint = true
	last_safe_ground_position = pos
