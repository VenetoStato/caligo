extends CharacterBody2D

const FISH_CATCH_EFFECT_SCRIPT := preload("res://Fx/fish_catch_effect.gd")
const FOOTSTEP_DUST := preload("res://Fx/footstep_dust.gd")
const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")

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
@export var air_acceleration: float = 1380.0
@export var air_deceleration: float = 780.0
@export var gravity: float = 1100.0
@export var fall_gravity: float = 2300.0
@export var max_fall_speed: float = 580.0

@export_category("Dash")
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var double_tap_time: float = 0.25
@export_range(0.0, 1.0) var dash_end_speed_multiplier: float = 0.45
@export var dash_cancel_on_wall: bool = true

@export_category("Jump")
@export var jump_speed: float = 520.0
@export var jump_acceleration: float = 640.0
@export var pogo_speed_scale: float = 0.8
@export var jump_amount: int = 2
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var jump_cut_multiplier: float = 0.5
## Celeste Player.cs / stessa scuola di Hollow Knight: NON 500ms.
## VarJumpTime = 0.2s. HalfGrav all'apice ~80-120ms, poi caduta secca.
@export var var_jump_time: float = 0.2
@export var apex_hang_time: float = 0.1
@export var apex_gravity_scale: float = 0.5
@export var half_grav_threshold: float = 48.0
@export var dash_invincibility: bool = true

@export_category("Water")
@export var water_bounce_speed: float = 390.0

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
## Extra peso sulla lenza quando c'e' un pesce agganciato (curva piu' realistica).
@export var fish_line_weight: float = 1.55
@export var fish_line_stiffness_extra: int = 8

@export_category("Line Colors")
@export var line_color_normal: Color = Color(0.2, 0.6, 0.3)
@export var line_color_tension: Color = Color(0.9, 0.8, 0.1)
@export var line_color_critical: Color = Color(0.9, 0.2, 0.1)
@export var line_color_reeling: Color = Color(0.3, 0.7, 0.9)
@export var line_color_wrong_reel: Color = Color(0.95, 0.2, 0.15)  # Rosso quando tiri durante la lotta
@export var line_color_reel_progress_low: Color = Color(0.25, 0.72, 0.55)
@export var line_color_reel_progress_mid: Color = Color(0.35, 0.82, 0.95)
@export var line_color_reel_progress_high: Color = Color(0.95, 0.82, 0.28)

@export_category("Line Tuning")
@export var line_out_speed: float = 900.0
@export var reel_in_speed: float = 300.0
@export var reel_pull_force: float = 680.0
@export var min_line_length_start: float = 40.0
@export var spawn_forward_push: float = 18.0
@export var min_forward_aim_dot: float = -0.05

@export_category("Grab")
@export var grab_pull_speed: float = 520.0
@export var grab_reel_in_speed: float = 260.0
@export var grab_cancel_distance: float = 18.0
@export var grab_attach_radius: float = 50.0
@export var max_grab_anchors: int = 8

@export_category("Swing")
@export var swing_control_force: float = 620.0
@export var swing_climb_speed: float = 165.0
@export var swing_min_length: float = 34.0
@export var swing_release_boost: float = 330.0
@export var swing_damping: float = 0.55

@export_category("Fishing combat")
@export var enemy_reel_pull_speed := 430.0
@export var enemy_reel_finish_distance := 74.0
@export var enemy_power_window := 0.34
@export var enemy_power_min_speed := 190.0
@export var enemy_power_damage := 3
@export var enemy_power_fail_distance := 68.0
@export var enemy_power_fail_damage := 1
@export var enemy_power_fail_knockback := 360.0
@export var power_strike_window := 1.05
@export var idle_hook_pull_ratio := 0.44
@export var heavy_reel_player_speed := 610.0
@export var heavy_reel_acceleration := 1900.0
@export var heavy_power_ready_distance := 96.0
@export var light_hook_drag_speed := 58.0
@export var light_hook_drag_acceleration := 360.0
@export var heavy_hook_drag_speed := 245.0
@export var heavy_hook_drag_acceleration := 1250.0
const POWER_STRIKE_TINT := Color(1.0, 0.72, 0.3, 1.0)

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
@export var particles_on_move: bool = true
@export var particles_on_land: bool = true
@export var move_particle_interval: float = 0.17

@export_category("Fish Struggle")
@export var fish_struggle_interval: float = 1.8
@export var fish_escape_time: float = 1.6
@export var fish_struggle_phase_duration: float = 1.8
## Stress della lenza oltre cui il pesce si libera (1.0 = rossa piena). Se la lenza diventa troppo rossa durante la lotta, il pesce scappa
@export var stress_escape_threshold: float = 0.88
## Impulso extra al tap di R (oltre al hold)
@export var reel_pulse_duration: float = 0.18
@export var fish_reel_distance: float = 42.0
@export var fish_catch_jump_distance: float = 72.0
@export var fish_pull_strength: float = 220.0
## Progresso reel richiesto prima della cattura (0–1). Il morso da solo NON basta.
@export var min_reel_progress_to_catch: float = 0.7
@export var reel_progress_per_second: float = 0.75
@export var min_hooked_time_before_catch: float = 0.85
## Sbarco: solo quando hai reelato abbastanza (niente uscita precoce).
@export var catch_jump_reel_threshold: float = 0.5
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
@export var cast_aim_max_up: float = 88.0
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
## Offset Y dal punto di respawn. last_safe è già la posizione in piedi: 0.
@export var respawn_y_offset: float = 0.0
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
var _attack_slash_timer: float = 0.0
var _attack_slash_span: float = 0.35
var _attack_cooldown: float = 0.0
var _attack_dir: Vector2 = Vector2.RIGHT
var _hitstop_timer: float = 0.0
var _pogo_grace_timer: float = 0.0
var _thorn_grace_timer: float = 0.0
var _water_hop_timer: float = 0.0
var _var_jump_timer: float = 0.0
var _var_jump_speed: float = 0.0
var _apex_hang_left: float = 0.0
var _was_rising: bool = false
var _fishing_feedback_timer := 0.0
const NAIL_DURATION := 0.35
const NAIL_COOLDOWN := 0.41

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
var is_swinging := false
var using_fishing_hook: bool = true  # Default: amo da pesca + pastura; C = altro (amo da lancio)
var current_fish: Node2D = null
var fish_hooked: bool = false
var current_hooked_enemy: CharacterBody2D = null
var enemy_hooked := false
var _enemy_power_window_left := 0.0
var _power_strike_target: CharacterBody2D = null
var _power_strike_hit := false
var _power_strike_fail_applied := false
var _power_strike_fail_armed := false
var _enemy_hook_feedback_timer := 0.0
var _power_strike_left := 0.0
var _power_tint_active := false
var fish_struggle_timer: float = 0.0
var fish_struggle_active: bool = false
var fish_escape_timer: float = 0.0
var fish_struggle_phase_timer: float = 0.0
var _fish_catch_jump_done: bool = false
var _fish_reel_progress: float = 0.0
var _fish_hooked_time: float = 0.0
var _fish_hook_start_dist: float = 0.0
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
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dash_was_invincible: bool = false
var _footstep_side := -1.0
var _player_soft_light: PointLight2D

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
	_setup_player_soft_light()
	
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
	shape.size = Vector2(80, 72)
	var col = CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(32, -30)
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
	# Solo dopo abbastanza reel: altrimenti il morso vicino al pontile catturava subito.
	if not fish_hooked or current_fish == null or body != current_fish:
		return
	if _fish_catch_jump_done or _fish_reel_progress < catch_jump_reel_threshold:
		return
	if body.has_method("do_catch_jump"):
		body.call("do_catch_jump")
		_fish_catch_jump_done = true
		_sync_line_length_for_hang()

func _resolve_nail_direction() -> Vector2:
	var up := (
		Input.is_action_pressed("ui_up")
		or Input.is_action_pressed("aim_up")
		or Input.is_physical_key_pressed(KEY_W)
	)
	var down := (
		Input.is_action_pressed("aim_down")
		or Input.is_physical_key_pressed(KEY_S)
		or Input.is_physical_key_pressed(KEY_DOWN)
	)
	if InputMap.has_action("ui_down") and Input.is_action_pressed("ui_down"):
		down = true
	if down and not is_on_floor():
		return Vector2.DOWN
	if up:
		return Vector2.UP
	return Vector2.RIGHT if facing_right else Vector2.LEFT

func _update_attack_hitbox_position():
	if _attack_hitbox == null:
		return
	var col = _attack_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return
	var shape := col.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		col.shape = shape
	if _attack_dir.y < -0.5:
		shape.size = Vector2(54, 70)
		col.position = Vector2(0, -56)
	elif _attack_dir.y > 0.5:
		shape.size = Vector2(64, 86)
		col.position = Vector2(0, 40)
	else:
		# Il colpo orizzontale copre anche il bordo superiore del nemico:
		# stare un poco sopra non deve far passare la lenza a vuoto.
		shape.size = Vector2(78, 76)
		col.position = Vector2(34 if facing_right else -34, -30)

func _enable_attack_hitbox(damage: int = 1):
	_attack_dir = _resolve_nail_direction()
	_update_attack_hitbox_position()
	_attack_hit_enemies.clear()
	_current_attack_damage = damage
	_attack_slash_span = NAIL_DURATION
	_attack_slash_timer = NAIL_DURATION
	_attack_cooldown = NAIL_COOLDOWN
	if damage >= enemy_power_damage:
		_power_strike_left = 0.0
		_request_shake(0.5)
	if _attack_hitbox:
		_attack_hitbox.collision_layer = 4
		_attack_hitbox.collision_mask = 2
		_attack_hitbox.monitoring = true
	queue_redraw()

func _disable_attack_hitbox():
	if _attack_hitbox:
		_attack_hitbox.collision_layer = 0
		_attack_hitbox.collision_mask = 0
		_attack_hitbox.monitoring = false
	queue_redraw()

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if _is_pogo_target(area):
		_try_hit_enemy(area)
		return
	var parent: Node = area.get_parent()
	_try_hit_enemy(parent)


func _try_hit_enemy(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target == self or target.is_in_group("player"):
		return
	if not target.is_in_group("enemy"):
		if _is_pogo_target(target):
			# Le spine espongono una Area2D figlia per il pogo: l'effetto visivo
			# appartiene alla radice del thorn, non alla sola hitbox.
			var effect_target := target
			if not effect_target.has_method("on_pogo_hit"):
				var target_parent := target.get_parent()
				if target_parent and target_parent.has_method("on_pogo_hit"):
					effect_target = target_parent
			if effect_target in _attack_hit_enemies:
				return
			_attack_hit_enemies.append(effect_target)
			if effect_target.has_method("on_pogo_hit"):
				effect_target.call("on_pogo_hit")
			if effect_target.has_method("_on_hit"):
				effect_target.call("_on_hit")
			_on_nail_connect(effect_target)
		return
	if target in _attack_hit_enemies:
		return
	if "state" in target and int(target.get("state")) == 2:
		return
	_attack_hit_enemies.append(target)
	if target.has_method("take_damage"):
		target.take_damage(_current_attack_damage, global_position)
	if _power_strike_left > 0.0 and target == _power_strike_target:
		_power_strike_hit = true
		_spawn_power_strike_impact(target)
	_on_nail_connect(target)


func _is_pogo_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target == self or target.is_in_group("player"):
		return false
	if target.is_in_group("enemy") or target.is_in_group("dead_enemy"):
		return true
	if target.is_in_group("pogoable") or target.is_in_group("dogana_thorn"):
		return true
	if target.is_in_group("dogana_breakable") or target.has_method("_on_hit"):
		return true
	if target.is_in_group("dogana_bricole"):
		return true
	return false


func is_pogo_grace() -> bool:
	return _pogo_grace_timer > 0.0


func is_thorn_grace() -> bool:
	return _thorn_grace_timer > 0.0


func _probe_pogo_targets() -> void:
	if _attack_dir.y <= 0.5:
		return
	var world := get_world_2d()
	if world == null:
		return
	var space := world.direct_space_state
	if space == null:
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(62.0, 80.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(0.0, 36.0))
	query.collision_mask = 1 | 2
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	for hit in space.intersect_shape(query, 14):
		var collider: Variant = hit.get("collider")
		if not (collider is Node):
			continue
		var node := collider as Node
		if _is_pogo_target(node):
			_try_hit_enemy(node)
		elif node.get_parent() != null and _is_pogo_target(node.get_parent()):
			_try_hit_enemy(node.get_parent())


func _resolve_attack_overlaps() -> void:
	if _attack_hitbox == null or not _attack_hitbox.monitoring:
		return
	for area in _attack_hitbox.get_overlapping_areas():
		_on_attack_hitbox_area_entered(area)
	for body in _attack_hitbox.get_overlapping_bodies():
		_try_hit_enemy(body)
		_on_attack_hitbox_body_entered(body)
	_probe_pogo_targets()

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if _is_pogo_target(body) and not body.is_in_group("enemy"):
		_try_hit_enemy(body)
	if body.is_in_group("dead_enemy") and body is RigidBody2D:
		_request_shake(0.28)
		var dir: Vector2 = (body.global_position - global_position).normalized()
		dir.y = min(dir.y, -0.55)
		dir = dir.normalized()
		body.apply_central_impulse(dir * 520.0)
		body.apply_torque_impulse(sign(dir.x) * 220.0)
		_on_nail_connect(body)

func _setup_health():
	_health_states.clear()
	_health_scales.clear()
	_health_pulse.clear()
	for i in range(max_health):
		_health_states.append(true)
		_health_scales.append(1.0)
		_health_pulse.append(0.0)

func _setup_transition_manager():
	# Preferisci l'autoload ufficiale: evita un secondo ColorRect che flasha.
	transition_manager = get_node_or_null("/root/autoload_transition")
	if transition_manager == null:
		transition_manager = get_tree().get_first_node_in_group("transition_manager")
	if transition_manager != null:
		return
	var tm_script = load("res://TransitionManager.gd")
	if tm_script:
		transition_manager = tm_script.new()
		transition_manager.name = "TransitionManagerFallback"
		get_tree().root.add_child(transition_manager)
	else:
		_create_simple_transition_manager()

func _create_simple_transition_manager():
	# Fallback minimo: solo se manca l'autoload.
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "TransitionManager"
	canvas.add_to_group("transition_manager")
	var rect = ColorRect.new()
	rect.name = "FadeRect"
	rect.color = Color(0.004, 0.016, 0.022, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	canvas.add_child(rect)
	get_tree().root.add_child(canvas)
	transition_manager = canvas
	if not get_meta("skip_initial_fade", false):
		rect.visible = true
		rect.color.a = 1.0
		_simple_fade_in(rect)

func _simple_fade_in(rect: ColorRect):
	var tween = create_tween()
	tween.tween_property(rect, "color:a", 0.0, 1.0)

func _on_anim_finished(anim_name: String):
	if anim_name == "Fishing":
		fishing_anim_finished = true
	if anim_name in ["Attack_fast", "Attack_strong", "Attack_up", "Attack_down"]:
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
	if _attack_slash_timer > 0.0:
		_draw_attack_slash()
	if _power_strike_left > 0.0:
		_draw_power_strike_ready()
	# La vita e' resa una sola volta nella HUD CanvasLayer. Il vecchio indicatore
	# world-space duplicava i cuori e poteva restare in una posizione percepita
	# come scollegata dal personaggio durante spawn/salti.
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

func _on_nail_connect(target: Node) -> void:
	var heavy := _current_attack_damage >= 2
	_spawn_attack_impact_blur(target)
	var freeze := 0.055 if heavy else 0.04
	_hitstop_timer = maxf(_hitstop_timer, freeze)
	if target.has_method("apply_hitstop"):
		target.call("apply_hitstop", freeze)
	if _attack_dir.y > 0.5:
		_apply_pogo()
		_request_shake(0.12)
		return
	if _attack_dir.y < -0.5:
		if not is_on_floor():
			velocity.y = maxf(velocity.y, 36.0)
		_request_shake(0.1)
		return
	var away := 1.0
	if target is Node2D:
		away = signf(global_position.x - (target as Node2D).global_position.x)
	if is_zero_approx(away):
		away = -1.0 if facing_right else 1.0
	velocity.x = away * (192.0 if heavy else 174.0)
	_knockback_timer = maxf(_knockback_timer, 0.1)
	_request_shake(0.12)


## Il blur e' applicato alle particelle generate quando la canna connette,
## incluso il pogo. Corpo, hitbox e fisica del player restano invariati.
func _spawn_attack_impact_blur(target: Node) -> void:
	if not particles_on_attack or black_particle_scene == null:
		return
	var impact_pos := global_position + _attack_dir.normalized() * 26.0
	if target is Node2D:
		impact_pos = (target as Node2D).global_position
	_spawn_particles(impact_pos, _attack_dir, 0.4, 8, true)


func _apply_pogo() -> void:
	velocity.y = -jump_speed * pogo_speed_scale
	jump_amount = 2
	dash_cooldown_timer = 0.0
	is_dashing = false
	_pogo_grace_timer = 0.22
	_begin_variable_jump(velocity.y)
	tutorial_action_performed.emit(&"pogo")


func apply_thorn_bounce(from: Vector2 = Vector2.ZERO) -> void:
	## Di lato respinge in orizzontale; da sopra (o in loop di salto) spacca verso l'alto.
	if _thorn_grace_timer > 0.0:
		return
	var away := global_position - from
	if away.length_squared() < 4.0:
		away = Vector2(-1.0 if facing_right else 1.0, -0.7)
	var side_hit := absf(away.x) > absf(away.y) * 0.52 or absf(velocity.x) > 64.0
	if side_hit:
		var hx := signf(away.x)
		if is_zero_approx(hx):
			hx = -signf(velocity.x) if absf(velocity.x) > 6.0 else (-1.0 if facing_right else 1.0)
		velocity.x = hx * jump_speed * 0.84
		velocity.y = -jump_speed * 0.78
	else:
		velocity.x *= 0.22
		velocity.y = -jump_speed * 1.14
	is_dashing = false
	jump_amount = 2
	_knockback_timer = maxf(_knockback_timer, 0.14)
	_thorn_grace_timer = 0.36
	_pogo_grace_timer = maxf(_pogo_grace_timer, 0.2)
	_begin_variable_jump(velocity.y)


func _draw_attack_slash() -> void:
	var span := _attack_slash_span if _attack_slash_span > 0.001 else NAIL_DURATION
	var t := clampf(_attack_slash_timer / span, 0.0, 1.0)
	var fade := pow(t, 0.55)
	var facing := 1.0 if facing_right else -1.0
	var empowered := _current_attack_damage >= enemy_power_damage
	var edge := Color(0.97, 0.98, 1.0, 0.1 + fade * 0.88)
	var core := Color(1.0, 1.0, 1.0, 0.08 + fade * 0.96)
	if empowered:
		edge = Color(1.0, 0.96, 0.86, 0.12 + fade * 0.9)
		core = Color(1.0, 0.99, 0.94, 0.1 + fade * 0.98)
	var origin := Vector2(10.0, -14.0)
	var reach := lerpf(24.0, 54.0, 1.0 - t)
	var a0 := -1.05
	var a1 := 0.68
	if _attack_dir.y < -0.5:
		origin = Vector2(2.0, -18.0)
		reach = lerpf(20.0, 48.0, 1.0 - t)
		a0 = -2.35
		a1 = -0.75
	elif _attack_dir.y > 0.5:
		origin = Vector2(2.0, 6.0)
		reach = lerpf(18.0, 44.0, 1.0 - t)
		a0 = 0.75
		a1 = 2.35
	var width := 4.2 if empowered else 3.4
	# Tre impronte sfalsate danno al colpo una scia morbida e leggibile, non un
	# contorno sterile. Restano solo per la finestra attiva del colpo.
	var blur_dir := Vector2(-facing * (1.0 - t) * 11.0, 4.0 if _attack_dir.y > 0.5 else 0.0)
	for blur_step in range(3, 0, -1):
		var ghost_alpha := fade * 0.055 * float(4 - blur_step)
		var ghost_origin := origin + blur_dir * float(blur_step) * 0.34
		_draw_mirrored_arc(ghost_origin, reach, a0, a1, facing, Color(edge.r, edge.g, edge.b, ghost_alpha), width + float(blur_step) * 1.3)
	_draw_mirrored_arc(origin, reach, a0, a1, facing, edge, width)
	_draw_mirrored_arc(origin, reach * 0.9, a0 + 0.05, a1 - 0.05, facing, core, 1.5)
	var tip_local := Vector2(
		origin.x + cos(lerpf(a0, a1, 0.82)) * reach,
		origin.y + sin(lerpf(a0, a1, 0.82)) * reach
	)
	draw_circle(Vector2(tip_local.x * facing, tip_local.y), 1.5 + fade * 1.3, core)
func _draw_mirrored_arc(
	origin: Vector2,
	reach: float,
	a0: float,
	a1: float,
	facing: float,
	color: Color,
	width: float
) -> void:
	var pts := PackedVector2Array()
	var steps := 18
	for i in range(steps + 1):
		var a := lerpf(a0, a1, float(i) / float(steps))
		var local := Vector2(origin.x + cos(a) * reach, origin.y + sin(a) * reach)
		pts.append(Vector2(local.x * facing, local.y))
	draw_polyline(pts, color, width, true)

# ===========================================
# CAST UI (barra caricamento + direzione)
# ===========================================
## Carica del lancio come archetto sopra la testa: leggibile ma senza
## rettangoli da interfaccia piantati nel mondo.
func _draw_cast_charge_bar():
	var progress: float = clampf(current_charge_time / maxf(max_charge_time, 0.01), 0.0, 1.0)
	var center: Vector2 = cast_bar_offset + Vector2(0, 6)
	var radius := 15.0
	var start := PI * 1.22
	var sweep := PI * 0.56
	draw_arc(center, radius, start, start + sweep, 22, Color(0.06, 0.1, 0.11, 0.5), 2.6, true)
	if progress > 0.01:
		var tint := Color(0.5, 0.92, 0.84, 0.85).lerp(Color(0.95, 0.86, 0.5, 0.95), progress)
		draw_arc(center, radius, start, start + sweep * progress, 22, tint, 2.6, true)
	if progress >= 0.999:
		draw_arc(center, radius + 3.0, start, start + sweep, 22, Color(0.95, 0.86, 0.5, 0.35), 1.2, true)


## Aura sulla canna mentre la finestra del colpo potenziato e' aperta: e' il
## segnale che il nemico appena trascinato vale il doppio se lo si colpisce ora.
func _draw_power_strike_ready() -> void:
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.018)
	var fade: float = clampf(_power_strike_left / maxf(power_strike_window, 0.01), 0.0, 1.0)
	var facing := 1.0 if facing_right else -1.0
	var center := Vector2(facing * 16.0, -10.0)
	draw_circle(center, 30.0 + pulse * 5.0, Color(1.0, 0.66, 0.24, 0.12 * fade * pulse))
	draw_arc(center, 26.0 + pulse * 4.0, 0.0, TAU, 26, Color(0.99, 0.74, 0.34, 0.6 * fade * pulse), 3.0, true)
	draw_arc(center, 19.0, -0.9, 0.9, 14, Color(1.0, 0.9, 0.6, 0.85 * fade), 3.4, true)
	# Scintille orbitanti: il colpo forte si vede anche con la scena affollata.
	var spin := Time.get_ticks_msec() * 0.004
	for i in range(3):
		var ang: float = spin + float(i) * TAU / 3.0
		var orbit: Vector2 = center + Vector2(cos(ang), sin(ang)) * (23.0 + pulse * 3.0)
		draw_circle(orbit, 2.4 + pulse * 1.1, Color(1.0, 0.88, 0.56, 0.8 * fade))


## Mira sobria: solo la traiettoria puntinata e il punto di caduta. Niente
## freccia gialla piena, che copriva la scena e stonava con la palette.
func _draw_cast_direction_indicator():
	var rod_local = base_axis_offset + (line_origin_offset_right if facing_right else line_origin_offset_left) + (rod_tip_offset_right if facing_right else rod_tip_offset_left)
	var dir = _display_cast_direction.normalized() if _display_cast_direction.length_squared() > 0.01 else Vector2.RIGHT
	var power: float = clampf(current_charge_time / maxf(max_charge_time, 0.01), min_cast_power, 1.0)
	var preview_speed: float = cast_speed * power
	var last_point: Vector2 = rod_local
	for index in range(1, 13):
		var time := float(index) * 0.062
		var preview_point: Vector2 = rod_local + dir * preview_speed * time + Vector2(0, 490.0 * time * time)
		var falloff := 1.0 - float(index - 1) / 13.0
		draw_circle(preview_point, 1.5 + falloff * 1.1, Color(0.52, 0.92, 0.84, 0.5 * falloff))
		last_point = preview_point
	# Punto di caduta: un piccolo mirino invece di una punta di freccia.
	draw_arc(last_point, 6.5, 0.0, TAU, 18, Color(0.62, 0.96, 0.86, 0.5), 1.2, true)
	draw_circle(last_point, 1.8, Color(0.78, 1.0, 0.92, 0.7))

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
		# F di nuovo sgancia subito un enemy: la canna non puo' restare bloccata
		# su un pesante o su un bersaglio che non si vuole piu' trascinare.
		if line_extended and enemy_hooked:
			_release_hooked_enemy(false)
			return
		if not line_extended and hook_instance == null:
			line_mode = LineMode.FISHING if using_fishing_hook or not grab_hook_unlocked else LineMode.GRAB
			is_charging = true
			current_charge_time = 0.0
			_reset_cast_aim_from_mouse()
	
	if event.is_action_pressed("grab"):
		if not line_extended and hook_instance == null:
			if using_fishing_hook:
				# Pastura disattivata per ora: il lancio si fa con F.
				# _cast_pastura()
				return
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
			is_reeling = true
			if enemy_hooked:
				_enemy_power_window_left = enemy_power_window
				_request_shake(0.09)
			if fish_hooked:
				# Hold R per tirare; tap aggiunge un piccolo impulso.
				reel_pulse_timer = reel_pulse_duration
				_request_shake(0.16)
	
	if event.is_action_released("reel"):
		is_reeling = false
		reel_pulse_timer = 0.0

func _physics_process(delta: float):
	# Non processare se morto
	if is_dead:
		return
	if get_meta("arrival_locked", false):
		velocity = Vector2.ZERO
		return
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(0.0, _hitstop_timer - delta)
		return
	
	_update_dash_timers(delta)
	_check_dash_input()
	_update_invincibility(delta)
	_update_health_anims(delta)
	_update_health_visibility(delta)
	_update_breathing(delta)
	_update_jump_assist_timers(delta)
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _pogo_grace_timer > 0.0:
		_pogo_grace_timer = maxf(0.0, _pogo_grace_timer - delta)
	if _thorn_grace_timer > 0.0:
		_thorn_grace_timer = maxf(0.0, _thorn_grace_timer - delta)
	if _water_hop_timer > 0.0:
		_water_hop_timer = maxf(0.0, _water_hop_timer - delta)
	if _attack_slash_timer > 0.0:
		_resolve_attack_overlaps()
		_attack_slash_timer = maxf(0.0, _attack_slash_timer - delta)
		queue_redraw()
	
	if _process_dash(delta):
		return

	if is_swinging:
		_update_swing(delta)
		if is_swinging:
			flip_logic()
			move_and_slide()
			set_animation()
			_process_fishing(delta)
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

	# Salto prima di move_and_slide: stesso frame in cui premi, senza snappare al suolo.
	# Non resettare i salti mentre si sta ancora salendo (evita snap a suolo / salti infinit).
	if is_on_floor() and velocity.y >= 0.0:
		jump_amount = 2
	jump_logic()
	
	var impact_speed := velocity.y
	move_and_slide()
	_update_footstep_fx(delta)
	if particles_on_land and not _was_on_floor and is_on_floor() and impact_speed > 95.0:
		if black_particle_scene:
			_spawn_particles(global_position + Vector2(0, 4), Vector2.UP, 0.18, 4)
		if ambient_trail_scene:
			_spawn_trail(global_position + Vector2(0, 4), Vector2.UP)
		_request_shake(minf(0.16, impact_speed / 1800.0))
	if is_on_floor() and velocity.y >= 0.0:
		_coyote_timer = coyote_time
		jump_amount = 2
		_var_jump_timer = 0.0
		_apex_hang_left = 0.0
		last_safe_ground_position = global_position
	elif _was_on_floor and not is_on_floor():
		_coyote_timer = coyote_time
	_was_on_floor = is_on_floor()
	
	set_animation()
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

func _update_jump_assist_timers(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	if not is_on_floor():
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
	if (
		Input.is_action_just_released("ui_accept")
		and velocity.y < 0.0
		and not is_dashing
	):
		velocity.y *= jump_cut_multiplier
		_var_jump_timer = 0.0
		_apex_hang_left = 0.0


func _start_dash(direction: Vector2):
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_duration + dash_cooldown
	dash_direction = direction.normalized()
	dash_particle_timer = 0.0
	facing_right = direction.x > 0
	velocity.y = 0
	if dash_invincibility:
		_dash_was_invincible = is_invincible
		is_invincible = true
		invincibility_timer = maxf(invincibility_timer, dash_duration)
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
	velocity.x *= dash_end_speed_multiplier * 0.85
	if dash_invincibility and not _dash_was_invincible and invincibility_timer <= dash_duration + 0.01:
		# Fine i-frame dash se non eravamo già in hit-invuln prolungata.
		if invincibility_timer <= 0.05:
			is_invincible = false
			if sprite_node:
				sprite_node.modulate = Color.WHITE
	_dash_was_invincible = false

func _apply_gravity(delta: float):
	var holding_jump := Input.is_action_pressed("ui_accept")
	if _was_rising and velocity.y >= 0.0 and holding_jump:
		_apex_hang_left = apex_hang_time
	_was_rising = velocity.y < 0.0

	var g := gravity
	var near_apex := absf(velocity.y) < half_grav_threshold
	if _apex_hang_left > 0.0 and holding_jump:
		g = gravity * apex_gravity_scale
		_apex_hang_left = maxf(0.0, _apex_hang_left - delta)
	elif near_apex and holding_jump:
		g = gravity * apex_gravity_scale
	elif velocity.y > 0.0:
		g = fall_gravity
		_apex_hang_left = 0.0
	else:
		_apex_hang_left = 0.0

	velocity.y += g * water_gravity_multiplier * delta
	if _var_jump_timer > 0.0:
		if holding_jump:
			velocity.y = minf(velocity.y, _var_jump_speed)
			_var_jump_timer = maxf(0.0, _var_jump_timer - delta)
		else:
			_var_jump_timer = 0.0
	var cap := max_fall_speed
	if water_gravity_multiplier < 0.95:
		cap = max_fall_speed * 0.55
	velocity.y = minf(velocity.y, cap)

func horizontal_movement(delta: float):
	if is_dashing:
		return
	# Mirare non deve inchiodare il personaggio: si continua a camminare, piu'
	# lenti, cosi' si puo' correggere la posizione mentre si carica il lancio.
	if is_charging:
		var aim_input := Input.get_axis("ui_left", "ui_right")
		var charge_deceleration := ground_deceleration if is_on_floor() else air_deceleration
		if absf(aim_input) > 0.1:
			var aim_speed := move_speed * 0.45
			var aim_accel := (ground_acceleration if is_on_floor() else air_acceleration) * 0.7
			velocity.x = move_toward(velocity.x, aim_input * aim_speed, aim_accel * delta)
		else:
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


func _update_footstep_fx(delta: float) -> void:
	move_particle_timer = maxf(0.0, move_particle_timer - delta)
	if not particles_on_move or not is_on_floor() or is_dashing or is_charging:
		return
	if absf(velocity.x) < 34.0 or move_particle_timer > 0.0:
		return
	move_particle_timer = move_particle_interval
	_footstep_side *= -1.0
	var parent := get_parent()
	if parent:
		FOOTSTEP_DUST.spawn(
			parent,
			global_position + Vector2(_footstep_side * 5.0, 13.0),
			velocity.x,
			OS.get_name() == "Android" or OS.has_feature("mobile")
		)


func _setup_player_soft_light() -> void:
	if OS.get_name() == "Android" or OS.has_feature("mobile"):
		return
	_player_soft_light = PointLight2D.new()
	_player_soft_light.name = "PlayerSoftLight"
	_player_soft_light.position = Vector2(0, -7)
	_player_soft_light.color = Color(0.48, 0.76, 0.75, 1.0)
	_player_soft_light.energy = 0.11 if OS.get_name() == "Android" else 0.17
	_player_soft_light.texture_scale = 1.9
	_player_soft_light.shadow_enabled = false
	_player_soft_light.texture = _make_player_light_texture()
	add_child(_player_soft_light)


func _make_player_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.32, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.82), Color(1, 1, 1, 0.3),
		Color(1, 1, 1, 0.06), Color(1, 1, 1, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 96
	texture.height = 96
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

func flip_logic():
	if movement > 0:
		facing_right = true
	elif movement < 0:
		facing_right = false
	if sprite_node:
		sprite_node.flip_h = !facing_right
	_update_attack_hitbox_position()

func set_animation():
	var can_nail := _attack_cooldown <= 0.0 and not line_extended
	if Input.is_action_just_pressed("ui_attack_strong") and can_nail:
		if anim.has_animation("Attack_strong"):
			anim.play("Attack_strong", -1.0, 2.05)
			_enable_attack_hitbox(2)
			tutorial_action_performed.emit(&"attack")
		return
	if Input.is_action_just_pressed("ui_attack") and can_nail:
		_enable_attack_hitbox(enemy_power_damage if _power_strike_left > 0.0 else 1)
		if _attack_dir.y < -0.5 and anim.has_animation("Attack_up"):
			anim.play("Attack_up")
		elif _attack_dir.y > 0.5 and anim.has_animation("Attack_down"):
			anim.play("Attack_down")
		else:
			anim.play("Attack_fast")
		tutorial_action_performed.emit(&"attack")
		return
	if anim.current_animation in ["Attack_fast", "Attack_strong", "Attack_up", "Attack_down"] and anim.is_playing():
		return
	if _attack_slash_timer > 0.0:
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

func _begin_variable_jump(upward_speed: float) -> void:
	_var_jump_speed = upward_speed
	_var_jump_timer = var_jump_time
	_apex_hang_left = 0.0
	_was_rising = true


func jump_logic():
	var wants_jump := _jump_buffer_timer > 0.0
	if wants_jump and _water_hop_timer > 0.0:
		_jump_buffer_timer = 0.0
		_water_hop_timer = 0.0
		jump_amount = maxi(0, jump_amount - 1)
		velocity.y = -lerp(jump_speed, jump_acceleration, 0.1)
		_begin_variable_jump(velocity.y)
		tutorial_action_performed.emit(&"jump")
		if particles_on_jump and black_particle_scene:
			_spawn_particles(global_position, Vector2.DOWN, 0.2)
		if particles_on_jump and ambient_trail_scene:
			_spawn_trail(global_position, Vector2.DOWN)
		return
	if _thorn_grace_timer > 0.0 and is_on_floor():
		return
	var can_coyote := _coyote_timer > 0.0 and jump_amount > 0
	if wants_jump and (is_on_floor() or can_coyote):
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		jump_amount = maxi(0, jump_amount - 1)
		velocity.y = -lerp(jump_speed, jump_acceleration, 0.1)
		_begin_variable_jump(velocity.y)
		tutorial_action_performed.emit(&"jump")
		if particles_on_jump and black_particle_scene:
			_spawn_particles(global_position, Vector2.DOWN, 0.2)
		if particles_on_jump and ambient_trail_scene:
			_spawn_trail(global_position, Vector2.DOWN)
	elif wants_jump and jump_amount > 0 and not is_on_floor():
		_jump_buffer_timer = 0.0
		jump_amount -= 1
		velocity.y = -lerp(jump_speed, jump_acceleration, 1.0)
		_begin_variable_jump(velocity.y)
		tutorial_action_performed.emit(&"double_jump" if jump_amount == 0 else &"jump")
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
	if get_meta("arrival_locked", false):
		return
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
	
	if current_health <= 0:
		_on_death()

func add_life_vessel() -> void:
	max_health += 1
	current_health += 1
	_health_states.append(true)
	_health_scales.append(1.0)
	_health_pulse.append(0.0)
	_show_health_ui()


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

func _on_death():
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector2.ZERO
	# Chiudi subito l'hitbox: altrimenti durante la death-cam si colpiscono
	# nemici quasi morti e al respawn risultano "già rinati".
	_disable_attack_hitbox()
	_attack_hit_enemies.clear()
	is_charging = false
	if line_extended or hook_instance != null:
		_destroy_hook()
	
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
	call_deferred("_snap_respawn_to_floor")
	# Niente sprite barca/risveglio in morte: sembrava un mezzo cerchio sospeso.


func _snap_respawn_to_floor() -> void:
	if not is_inside_tree() or is_dead:
		return
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0.0, -48.0),
		global_position + Vector2(0.0, 96.0)
	)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var collider := hit.get("collider") as Node
	var walk: Node = collider
	while walk:
		if walk.is_in_group("dogana_bricole"):
			return
		walk = walk.get_parent()
	var floor_y := (hit.position as Vector2).y
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var feet := 13.0
	if col and col.shape is RectangleShape2D:
		feet = col.position.y + (col.shape as RectangleShape2D).size.y * 0.5
	global_position.y = floor_y - feet + 1.0
	velocity = Vector2.ZERO


func play_altar_wake_animation() -> void:
	## Usa Spritesbarcaerisveglio frame 6→24 come in character_beginning "intro".
	if not is_inside_tree() or is_dead:
		return
	if bool(get_meta("wake_animation_playing", false)):
		return
	set_meta("wake_animation_playing", true)
	set_meta("arrival_locked", true)
	velocity = Vector2.ZERO
	if anim:
		anim.stop()
	var body_sprite := sprite_node if sprite_node else get_node_or_null("Sprite2D") as Sprite2D
	if body_sprite:
		body_sprite.visible = false
	var wake := Sprite2D.new()
	wake.name = "AltarWakeSprite"
	wake.texture = preload("res://Spritesbarcaerisveglio.png")
	wake.hframes = 6
	wake.vframes = 5
	wake.frame = 6
	wake.centered = true
	wake.position = Vector2(3, -19)
	wake.scale = Vector2(0.1, 0.1)
	wake.z_index = 8
	add_child(wake)
	# Frame 6..24 come intro originale (~3.8s, step 0.2).
	for frame_i in range(6, 25):
		if not is_instance_valid(wake) or is_dead:
			break
		wake.frame = frame_i
		await get_tree().create_timer(0.2).timeout
	if is_instance_valid(wake):
		wake.queue_free()
	if body_sprite and is_instance_valid(body_sprite):
		body_sprite.visible = true
		body_sprite.modulate = Color(1, 1, 1, 1)
	if anim and anim.has_animation("Idle") and not is_dead:
		anim.play("Idle")
	set_meta("arrival_locked", false)
	set_meta("wake_animation_playing", false)
	is_invincible = true
	invincibility_timer = maxf(invincibility_timer, 1.0)

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

func _aim_angle_from_vector(diff: Vector2) -> float:
	var facing := get_facing_vector()
	var forward := maxf(absf(diff.x * facing.x), 0.04)
	var angle := atan2(-diff.y, forward)
	return clampf(angle, -deg_to_rad(cast_aim_max_down), deg_to_rad(cast_aim_max_up))


func _direction_from_aim_angle() -> Vector2:
	var facing := get_facing_vector()
	return Vector2(cos(_cast_aim_angle) * facing.x, -sin(_cast_aim_angle)).normalized()


func _reset_cast_aim_from_mouse():
	## Inizializza _cast_aim_angle dalla posizione mouse (o default se non disponibile)
	var aim = get_global_mouse_position()
	# La direzione di mira deve anche girare il personaggio: altrimenti il
	# calcolo usa ancora il lato precedente e la canna resta bloccata lì.
	_face_toward_aim(aim.x - global_position.x)
	var start = get_rod_tip_position()
	var diff = aim - start
	if diff.length_squared() > 400.0:  # min 20px di distanza per considerare il mouse valido
		_cast_aim_angle = _aim_angle_from_vector(diff)
	else:
		_cast_aim_angle = deg_to_rad(35.0)
	var d := get_cast_direction()
	_display_cast_direction = d
	_target_cast_direction = d

func _update_cast_aim(delta: float):
	## Durante il caricamento: il cursore punta la traiettoria, anche verso l'alto.
	var aim = get_global_mouse_position()
	_face_toward_aim(aim.x - global_position.x)
	var start = get_rod_tip_position()
	var diff = aim - start
	if diff.length_squared() > 400.0:
		_cast_aim_angle = _aim_angle_from_vector(diff)
	else:
		if Input.is_action_pressed("aim_up"):
			_cast_aim_angle += cast_aim_angle_speed * delta
		if Input.is_action_pressed("aim_down"):
			_cast_aim_angle -= cast_aim_angle_speed * delta
		_cast_aim_angle = clampf(_cast_aim_angle, -deg_to_rad(cast_aim_max_down), deg_to_rad(cast_aim_max_up))


func _face_toward_aim(horizontal_delta: float) -> void:
	if absf(horizontal_delta) < 18.0:
		return
	var wanted_right := horizontal_delta > 0.0
	if wanted_right == facing_right:
		return
	facing_right = wanted_right
	if sprite_node:
		sprite_node.flip_h = not facing_right
	_update_attack_hitbox_position()

func get_cast_direction() -> Vector2:
	# Joystick mobile: usa direzione se valida (anche al release, quando active=false ma direction non ancora azzerata)
	if MobileControlsManager.cast_joystick_direction.length_squared() > 0.01:
		var j := MobileControlsManager.cast_joystick_direction
		_face_toward_aim(j.x)
		_cast_aim_angle = _aim_angle_from_vector(j)
		return _direction_from_aim_angle()
	var start = get_rod_tip_position()
	var aim = get_global_mouse_position()
	var diff = aim - start
	# Mouse valido (distanza > 20px)? Usalo, anche se è quasi verticale.
	if diff.length_squared() > 400.0:
		_cast_aim_angle = _aim_angle_from_vector(diff)
		return _direction_from_aim_angle()
	return _direction_from_aim_angle()

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
	# Fuori acqua: la lenza si attacca alla bocca.
	if fish.has_method("get_line_attach_point"):
		return fish.call("get_line_attach_point")
	var spr = fish.get_node_or_null("Fishes")
	if spr == null:
		spr = fish.find_child("Fishes", true, false)
	return spr.global_position if spr else fish.global_position

# ===========================================
# GRAB ANCHORS
# ===========================================
## ===========================================
## APPIGLIO E DONDOLIO
## ===========================================
## L'amo che morde una superficie mette il personaggio in sospensione: da li'
## si dondola con i tasti di movimento, si risale con R e si stacca saltando.
## E' il modo per uscire dal raggio degli attacchi che spazzano il pavimento.
func on_grapple_latched(hook: Node) -> void:
	## L'amo da pesca ha morso una lampada: si dondola come con l'amo da trascino.
	if hook == null or hook != hook_instance:
		return
	line_mode = LineMode.GRAB
	on_grab_hook_anchored(hook)
	# Tirati su appena morsi: restare con la lenza lunga ti lascia nella marea.
	current_line_length = clampf(minf(current_line_length, 52.0), swing_min_length, 70.0)
	target_line_length = current_line_length


func on_grab_hook_anchored(hook: Node) -> void:
	if hook == null or hook != hook_instance:
		return
	var anchor := get_hook_center_position(hook)
	var distance := global_position.distance_to(anchor)
	if distance < 24.0 or distance > max_line_length:
		return
	is_swinging = true
	is_reeling = false
	current_line_length = clampf(distance, swing_min_length, max_line_length)
	target_line_length = current_line_length
	_request_shake(0.12)
	_spawn_anchor_bite_fx(anchor)


func _update_swing(delta: float) -> void:
	if not is_swinging:
		return
	if hook_instance == null or not is_instance_valid(hook_instance) or line_mode != LineMode.GRAB:
		release_swing(false)
		return
	var anchor := get_hook_center_position(hook_instance)
	var to_anchor := anchor - global_position
	var distance := to_anchor.length()
	if distance < 0.01:
		return
	var direction := to_anchor / distance

	var climb := Input.get_axis("ui_up", "ui_down")
	if Input.is_action_pressed("reel"):
		climb = -1.0
	if absf(climb) > 0.1:
		current_line_length = clampf(
			current_line_length + climb * swing_climb_speed * delta,
			swing_min_length,
			max_line_length
		)

	velocity.y += gravity * delta
	var steer := Input.get_axis("ui_left", "ui_right")
	if absf(steer) > 0.1:
		var tangent := Vector2(-direction.y, direction.x)
		if tangent.x * steer < 0.0:
			tangent = -tangent
		velocity += tangent * swing_control_force * delta

	if distance > current_line_length:
		# Vincolo della fune: si toglie la componente che allontana, resta
		# quella tangente. E' cio' che produce l'arco invece dello scatto.
		global_position = anchor - direction * current_line_length
		var radial := velocity.dot(direction)
		if radial < 0.0:
			velocity -= direction * radial
	velocity *= 1.0 - clampf(swing_damping * delta, 0.0, 0.9)

	if Input.is_action_just_pressed("ui_accept"):
		release_swing(true)


func release_swing(boosted: bool) -> void:
	if not is_swinging:
		return
	is_swinging = false
	if boosted:
		velocity.y = minf(velocity.y - swing_release_boost, -swing_release_boost * 0.6)
		velocity.x *= 1.12
		_request_shake(0.1)
	detach_grab_anchor()


func _spawn_anchor_bite_fx(anchor: Vector2) -> void:
	if black_particle_scene == null:
		return
	_spawn_particles(anchor, Vector2.UP, 0.18)


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
	is_swinging = false
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
	# Usa esattamente la direzione mostrata dall'indicatore: prima il lancio
	# rileggeva il mouse al release e poteva divergere dalla traiettoria preview.
	var dir := _display_cast_direction.normalized()
	if dir.length_squared() < 0.01:
		dir = get_cast_direction()
	hook_instance.global_position = start + dir * spawn_forward_push
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

# Pastura disattivata per ora. Tenere il codice, non cancellare.
# func _cast_pastura():
# 	if pastura_scene == null:
# 		return
# 	var p = pastura_scene.instantiate() as Node2D
# 	if p == null:
# 		return
# 	get_tree().current_scene.add_child(p)
# 	var start = get_rod_tip_position()
# 	var dir = get_cast_direction()
# 	p.global_position = start + dir * spawn_forward_push
# 	if p.has_method("set_velocity"):
# 		p.call("set_velocity", dir * cast_speed * 0.8)
# 	if p.has_method("set_player_reference"):
# 		p.call("set_player_reference", self)
# 	active_pastura = p
func _cast_pastura():
	return

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
	_enemy_power_window_left = maxf(0.0, _enemy_power_window_left - delta)
	_enemy_hook_feedback_timer = maxf(0.0, _enemy_hook_feedback_timer - delta)
	# Hold R (o impulso tap): durante la pesca is_reeling guida la tirata.
	if fish_hooked:
		if reel_pulse_timer > 0.0:
			reel_pulse_timer = maxf(0.0, reel_pulse_timer - delta)
		if Input.is_action_pressed("reel") or reel_pulse_timer > 0.0:
			is_reeling = true
		elif not Input.is_action_pressed("reel"):
			is_reeling = false
	if fish_hooked and current_fish:
		_update_fish_struggle(delta)
	_power_strike_left = maxf(0.0, _power_strike_left - delta)
	_update_power_strike_tint()
	if enemy_hooked and not is_instance_valid(current_hooked_enemy):
		_release_hooked_enemy(false)
	if enemy_hooked and is_instance_valid(current_hooked_enemy):
		if current_hooked_enemy.has_method("set_combat_hook_reeling"):
			current_hooked_enemy.call("set_combat_hook_reeling", is_reeling)
		_apply_enemy_hook_resistance(delta)
	_check_power_strike_miss()
	if line_extended and hook_instance:
		_update_line_length(delta)
		_sync_hook_to_rope(delta)
		_simulate_rope(delta)
		_update_line_color(delta)
		_update_line_visual()
	# Aggiorna solo l'ancora della lenza sul pesce.
	if fish_hooked and is_instance_valid(current_fish):
		var rod_tip: Vector2 = get_rod_tip_position()
		if current_fish.has_method("set_line_tether"):
			current_fish.call("set_line_tether", rod_tip, current_line_length)

func _update_line_length(delta: float):
	if not is_reeling and current_line_length < target_line_length:
		current_line_length = min(target_line_length, current_line_length + line_out_speed * delta)
	if is_reeling:
		var spd = grab_reel_in_speed if line_mode == LineMode.GRAB else reel_in_speed
		if enemy_hooked and is_instance_valid(current_hooked_enemy):
			current_line_length = maxf(28.0, current_line_length - spd * delta)
			_reel_enemy_to_player(delta)
		elif fish_hooked and is_instance_valid(current_fish):
			var fish_out_now := (
				current_fish.has_method("is_hanging") and bool(current_fish.call("is_hanging"))
			) or (
				current_fish.has_method("is_in_water") and not bool(current_fish.call("is_in_water"))
			)
			# Fuori acqua: accorcia la lenza piu' piano = issaggio smooth.
			var reel_mul := 0.45 if fish_out_now else 1.0
			current_line_length = maxf(24.0, current_line_length - spd * reel_mul * delta)
			_reel_fish_to_player(delta)
		else:
			current_line_length -= spd * delta
			if current_line_length < 20.0:
				if line_mode == LineMode.GRAB:
					detach_grab_anchor()
				else:
					_destroy_hook()

## Colore, non parole: mentre la finestra del colpo forte e' aperta il
## personaggio vira in ambra e torna bianco appena scade.
func _update_power_strike_tint() -> void:
	if sprite_node == null or is_invincible or is_dead:
		return
	if _power_strike_left > 0.0:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.019)
		sprite_node.modulate = Color.WHITE.lerp(POWER_STRIKE_TINT, 0.4 + pulse * 0.35)
		_power_tint_active = true
	elif _power_tint_active:
		_power_tint_active = false
		sprite_node.modulate = Color.WHITE


func _update_line_color(delta: float):
	if fishing_line == null:
		return
	var stress: float = 0.0
	var col: Color = line_color_normal
	if _power_strike_left > 0.0:
		fishing_line.default_color = POWER_STRIKE_TINT
		_current_line_stress = 0.35
		return
	if fish_hooked:
		var progress := clampf(_fish_reel_progress / maxf(min_reel_progress_to_catch, 0.01), 0.0, 1.0)
		if fish_struggle_active:
			if is_reeling:
				# Tirare durante la lotta = lenza rossa, pesce si stacca
				stress = 1.0
				col = line_color_wrong_reel
			else:
				stress = fish_escape_timer / fish_escape_time
				col = _get_stress_color(stress)
		else:
			# Feedback progresso reel sulla lenza (niente barra sopra il player).
			if progress < 0.45:
				col = line_color_reel_progress_low.lerp(line_color_reel_progress_mid, progress / 0.45)
			else:
				col = line_color_reel_progress_mid.lerp(line_color_reel_progress_high, (progress - 0.45) / 0.55)
			if is_reeling:
				col = col.lightened(0.12)
				stress = 0.25 + progress * 0.35
			else:
				stress = 0.12 + progress * 0.25
	elif is_reeling:
		stress = 0.2
		col = line_color_reeling
	_current_line_stress = lerp(_current_line_stress, stress, delta * _line_color_lerp_speed)
	fishing_line.default_color = fishing_line.default_color.lerp(col, delta * _line_color_lerp_speed)
	fishing_line.width = lerp(2.8, 4.6, _current_line_stress)
	# Se la lenza diventa troppo rossa durante la lotta IN ACQUA, il pesce si libera.
	if (
		fish_hooked
		and fish_struggle_active
		and not _fish_catch_jump_done
		and not _is_current_fish_out_of_water()
		and _current_line_stress >= stress_escape_threshold
	):
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
	var fish_hanging := (
		fish_hooked
		and is_instance_valid(current_fish)
		and current_fish.has_method("is_hanging")
		and bool(current_fish.call("is_hanging"))
	)
	# Pesce appeso: lenza sulla distanza reale (niente stiramento visuale).
	if fish_hanging:
		current_line_length = minf(current_line_length, maxf(28.0, dist))
		segment_length = max(1.0, dist / float(points.size() - 1))
		var iters_hang := rope_stiffness + 6
		var grav_hang := rope_gravity * 0.35
		for i in range(1, points.size() - 1):
			var cur = points[i]
			var old = old_points[i]
			var vel = (cur - old) * 0.9
			old_points[i] = cur
			points[i] = cur + vel + Vector2(0, grav_hang * delta * delta)
		for _it in range(iters_hang):
			_apply_rope_constraints(rod, end)
		points[points.size() - 1] = end
		old_points[old_points.size() - 1] = end
		return
	# Lasca se piu' corta della lenza; tesa se allungata.
	var slack := 1.0
	if dist < current_line_length:
		slack = clampf(dist / maxf(current_line_length, 1.0), 0.6, 1.0)
	segment_length = max(1.0, (current_line_length / (points.size() - 1)) * slack)
	var weight := (fish_line_weight if fish_hooked else 1.0)
	var taut: bool = dist >= current_line_length * 0.92
	var tension_factor := clampf(_effective_tension + (0.2 if is_reeling else 0.0) + (0.3 if taut else 0.0), 0.0, 1.0)
	var grav = rope_gravity * weight * (1.0 - tension_factor * 0.7)
	for i in range(1, points.size() - 1):
		var cur = points[i]
		var old = old_points[i]
		var vel = (cur - old) * rope_damping
		old_points[i] = cur
		points[i] = cur + vel + Vector2(0, grav * delta * delta)
	var iters := rope_stiffness + (fish_line_stiffness_extra if (fish_hooked and taut) else 0)
	for _it in range(iters):
		_apply_rope_constraints(rod, end)
	points[points.size() - 1] = end
	old_points[old_points.size() - 1] = end

func _get_line_end_position() -> Vector2:
	if enemy_hooked and is_instance_valid(current_hooked_enemy):
		return current_hooked_enemy.global_position + Vector2(0.0, -14.0)
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
	if dist > current_line_length and not fish_hooked and not enemy_hooked:
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
	if is_swinging:
		# In sospensione R e' la risalita lungo la fune, non lo strappo verso
		# l'ancora: se ne occupa _update_swing.
		return
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
	# Pesce agganciato: la tirata e' gia' gestita in _reel_fish_to_player (lenza tesa + no levitazione).
	if fish_hooked:
		return
	if hook_instance == null or not (hook_instance is RigidBody2D):
		return
	var pos: Vector2 = get_hook_center_position(hook_instance)
	var dir = (rod - pos).normalized()
	if hook_instance.has_method("apply_reel_force"):
		hook_instance.call("apply_reel_force", dir * reel_pull_force)
	else:
		hook_instance.apply_central_force(dir * reel_pull_force)


func on_enemy_hooked(enemy: CharacterBody2D, source_hook: Node = null) -> void:
	if enemy == null or enemy_hooked or fish_hooked:
		return
	if not enemy.has_method("begin_combat_hook") or not bool(enemy.call("begin_combat_hook", self)):
		return
	current_hooked_enemy = enemy
	enemy_hooked = true
	_enemy_power_window_left = 0.0
	current_line_length = clampf(get_rod_tip_position().distance_to(enemy.global_position), 28.0, max_line_length)
	target_line_length = current_line_length
	if source_hook != null:
		hook_instance = source_hook
	_request_shake(0.14)


func _reel_enemy_to_player(delta: float, pull_ratio := 1.0) -> void:
	if not is_instance_valid(current_hooked_enemy):
		_release_hooked_enemy(false)
		return
	var rod := get_rod_tip_position()
	var to_enemy := current_hooked_enemy.global_position - global_position
	var dist := to_enemy.length()
	var heavy := bool(current_hooked_enemy.call("is_combat_hook_heavy"))
	if heavy:
		current_hooked_enemy.call("apply_combat_hook_pull", rod, 0.0)
		if not is_reeling:
			return
		var toward_heavy := to_enemy.normalized() if dist > 0.01 else Vector2.ZERO
		# Il peso resta fermo: il reel trasforma la lenza in una carrucola e
		# lancia il player verso il bersaglio.
		velocity = velocity.move_toward(
			toward_heavy * heavy_reel_player_speed,
			heavy_reel_acceleration * delta * maxf(pull_ratio, 0.35)
		)
		current_line_length = maxf(28.0, minf(current_line_length, dist))
		if _enemy_hook_feedback_timer <= 0.0:
			_request_shake(0.045)
			_enemy_hook_feedback_timer = 0.14
		if dist <= heavy_power_ready_distance:
			_open_enemy_power_window(current_hooked_enemy)
		return
	current_hooked_enemy.call("apply_combat_hook_pull", rod, enemy_reel_pull_speed * pull_ratio)
	if dist <= enemy_reel_finish_distance:
		_land_reeled_enemy()


func _apply_enemy_hook_resistance(delta: float) -> void:
	if not enemy_hooked or not is_instance_valid(current_hooked_enemy):
		return
	var to_enemy := current_hooked_enemy.global_position - global_position
	var distance := to_enemy.length()
	if distance <= 0.01:
		return
	# A little slack remains after attachment. Drag ramps in progressively as
	# the enemy moves away instead of snapping the player on the first frame.
	var taut_ratio := distance / maxf(current_line_length, 1.0)
	var tension := smoothstep(0.86, 1.08, taut_ratio)
	if tension <= 0.0:
		return
	var heavy := bool(current_hooked_enemy.call("is_combat_hook_heavy"))
	var direction := to_enemy / distance
	var enemy_escape_speed := maxf(current_hooked_enemy.velocity.dot(direction), 0.0)
	var drag_speed := (
		minf(heavy_hook_drag_speed + enemy_escape_speed * 0.38, heavy_hook_drag_speed * 1.35)
		if heavy else
		minf(light_hook_drag_speed + enemy_escape_speed * 0.18, light_hook_drag_speed * 1.3)
	)
	var acceleration := heavy_hook_drag_acceleration if heavy else light_hook_drag_acceleration
	velocity.x = move_toward(velocity.x, direction.x * drag_speed, acceleration * tension * delta)
	# Heavy targets pull in their actual direction. Light ones mostly scuff the
	# player horizontally and only influence Y while airborne.
	if heavy and (not is_on_floor() or absf(to_enemy.y) > 34.0):
		velocity.y = move_toward(velocity.y, direction.y * drag_speed, acceleration * 0.62 * tension * delta)
	elif not heavy and not is_on_floor():
		velocity.y = move_toward(velocity.y, direction.y * drag_speed * 0.18, acceleration * 0.12 * tension * delta)


## Il nemico tirato sotto la canna arriva sbilanciato e resta scoperto: e'
## il momento in cui il colpo vale doppio. Lo dicono la posa del nemico e
## l'aura sulla canna, non una riga di testo.
func _land_reeled_enemy() -> void:
	_open_enemy_power_window(current_hooked_enemy)


func _open_enemy_power_window(enemy: CharacterBody2D) -> void:
	if not is_instance_valid(enemy):
		return
	var impact_position := enemy.global_position + Vector2(0.0, -18.0)
	if enemy.has_method("stagger"):
		enemy.call("stagger", power_strike_window)
	_power_strike_left = power_strike_window
	_power_strike_target = enemy
	_power_strike_hit = false
	_power_strike_fail_applied = false
	_power_strike_fail_armed = false
	PARTICLE_BURST.spawn(
		get_tree().current_scene, impact_position,
		Color(1.0, 0.72, 0.3, 0.84), 9, Vector2.UP, 24.0, 74.0, 0.52
	)
	_release_hooked_enemy(false)
	_request_shake(0.28)


func _spawn_power_strike_impact(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var at := (target as Node2D).global_position + Vector2(0.0, -18.0) if target is Node2D else global_position
	# Effetto dedicato della finestra riuscita: ambra + scintille chiare,
	# distinto dal normale colpo della canna.
	PARTICLE_BURST.spawn(get_tree().current_scene, at, Color(1.0, 0.78, 0.32, 0.95), 16, Vector2.UP, 34.0, 118.0, 0.46)


func _check_power_strike_miss() -> void:
	if _power_strike_left <= 0.0 or _power_strike_hit or _power_strike_fail_applied:
		return
	if _power_strike_target == null or not is_instance_valid(_power_strike_target):
		return
	var distance := global_position.distance_to(_power_strike_target.global_position)
	# L'enemy viene già portato vicino quando si apre la finestra: non è un
	# fallimento istantaneo. Il contraccolpo si arma solo dopo che il player si
	# è allontanato e rientra troppo vicino senza colpire.
	if distance > enemy_power_fail_distance:
		_power_strike_fail_armed = true
		return
	if not _power_strike_fail_armed:
		return
	_power_strike_fail_applied = true
	var away := (global_position - _power_strike_target.global_position).normalized()
	if away.length_squared() < 0.01:
		away = Vector2(-1.0 if facing_right else 1.0, -0.35)
	take_damage(enemy_power_fail_damage, _power_strike_target.global_position)
	velocity = away * enemy_power_fail_knockback
	velocity.y = minf(velocity.y, -enemy_power_fail_knockback * 0.34)
	_release_hooked_enemy(false)


func _release_hooked_enemy(powered: bool) -> void:
	if is_instance_valid(current_hooked_enemy):
		var launch := get_rod_tip_position() - current_hooked_enemy.global_position
		if launch.length_squared() < 0.01:
			launch = Vector2.LEFT if facing_right else Vector2.RIGHT
		current_hooked_enemy.call("release_combat_hook", launch, powered)
	if hook_instance and is_instance_valid(hook_instance) and hook_instance.has_method("set_hooked_enemy"):
		hook_instance.call("set_hooked_enemy", null)
	current_hooked_enemy = null
	enemy_hooked = false
	_enemy_power_window_left = 0.0
	if hook_instance and is_instance_valid(hook_instance):
		_destroy_hook()

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
	_fish_reel_progress = 0.0
	_fish_hooked_time = 0.0
	_fish_hook_start_dist = global_position.distance_to(fish.global_position)
	if fish.has_method("set_player_reference"):
		fish.call("set_player_reference", self)
	_update_effective_tension()
	# Solo una risposta tattile alla prima abboccata: la pesca resta invariata.
	_request_shake(0.075)
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
	_fish_hooked_time += delta
	_fishing_feedback_timer = maxf(0.0, _fishing_feedback_timer - delta)
	if is_reeling and _fishing_feedback_timer <= 0.0:
		# Micro impulso, non un camera shake invasivo: rende leggibile la tirata.
		_request_shake(0.035 if not fish_struggle_active else 0.055)
		_fishing_feedback_timer = 0.16 if not fish_struggle_active else 0.11

	var fish_out := _is_current_fish_out_of_water()
	# Fuori acqua / in uscita: niente lotta ne' fuga — solo issaggio.
	if fish_out or _fish_catch_jump_done:
		if fish_struggle_active:
			_stop_fish_struggle()
		if current_fish.has_method("set_wrong_reel"):
			current_fish.call("set_wrong_reel", false)
		if is_reeling:
			_fish_reel_progress = minf(1.25, _fish_reel_progress + reel_progress_per_second * 1.2 * delta)
		return

	# Progresso reel solo fuori lotta: serve a "guadagnare" la cattura.
	if is_reeling and not fish_struggle_active:
		var dist_now := global_position.distance_to(current_fish.global_position)
		var close_bonus := 1.15 if dist_now < _fish_hook_start_dist * 0.85 else 1.0
		_fish_reel_progress = minf(1.25, _fish_reel_progress + reel_progress_per_second * close_bonus * delta)
	elif fish_struggle_active and is_reeling:
		_fish_reel_progress = maxf(0.0, _fish_reel_progress - delta * 0.4)
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
			# Tirare durante la lotta = sbagliato: stress e rischio fuga.
			fish_escape_timer += delta
			if fish_escape_timer >= fish_escape_time:
				_on_fish_escaped()
		else:
			# Aspetti: la lotta finisce da sola, senza consumare la fuga.
			fish_escape_timer = maxf(0.0, fish_escape_timer - delta * 0.35)
			fish_struggle_phase_timer += delta
			if current_fish.has_method("apply_struggle_force"):
				var rod = get_rod_tip_position()
				var fp = get_fish_center_position(current_fish)
				current_fish.call("apply_struggle_force", (fp - rod).normalized() * fish_pull_strength * delta)
			if fish_struggle_phase_timer >= fish_struggle_phase_duration:
				_stop_fish_struggle()


func _is_current_fish_out_of_water() -> bool:
	if not is_instance_valid(current_fish):
		return false
	if current_fish.has_method("is_hanging") and bool(current_fish.call("is_hanging")):
		return true
	if current_fish.has_method("is_in_water") and not bool(current_fish.call("is_in_water")):
		return true
	return false

func _stop_fish_struggle():
	fish_struggle_active = false
	fish_escape_timer = 0.0
	fish_struggle_phase_timer = 0.0
	fish_struggle_timer = 0.0
	if current_fish and is_instance_valid(current_fish) and current_fish.has_method("stop_struggle"):
		current_fish.call("stop_struggle")

func _on_fish_escaped():
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
	_fish_reel_progress = 0.0
	_fish_hooked_time = 0.0
	_fish_catch_jump_done = false
	_update_effective_tension()
	if hook_instance and is_instance_valid(hook_instance):
		if hook_instance.has_method("set_hooked_fish"):
			hook_instance.call("set_hooked_fish", null)
		if hook_instance.has_method("show_hook"):
			hook_instance.call("show_hook")

func _can_finish_fish_catch(dist: float) -> bool:
	if fish_struggle_active:
		return false
	if _fish_hooked_time < min_hooked_time_before_catch:
		return false
	if _fish_reel_progress < min_reel_progress_to_catch:
		return false
	if dist < fish_reel_distance:
		return true
	# Dopo lo sbarco: cattura anche un po' piu' lontano.
	if _fish_catch_jump_done and dist < fish_reel_distance * 1.8:
		return true
	if (
		is_instance_valid(current_fish)
		and current_fish.has_method("is_in_water")
		and not bool(current_fish.call("is_in_water"))
		and dist < 70.0
	):
		return true
	return false


func _reel_fish_to_player(delta: float = 0.016) -> void:
	if not is_instance_valid(current_fish):
		fish_hooked = false
		current_fish = null
		_destroy_hook()
		return
	var rod: Vector2 = get_rod_tip_position()
	var fish_pos: Vector2 = get_fish_center_position(current_fish)
	var to_rod := Vector2(rod.x - fish_pos.x, rod.y - fish_pos.y)
	var dist := to_rod.length()
	var horizontal_dist := absf(to_rod.x)
	var fish_area: Area2D = get_node_or_null("FishArea") as Area2D
	var in_area: bool = fish_area != null and current_fish in fish_area.get_overlapping_bodies()
	var near_surface: bool = current_fish.has_method("is_near_surface") and current_fish.call("is_near_surface")
	var fish_out := _is_current_fish_out_of_water()
	# Se rientra in acqua dopo lo sbarco, torna la fase in-acqua.
	if (
		_fish_catch_jump_done
		and not fish_out
		and current_fish.has_method("is_in_water")
		and bool(current_fish.call("is_in_water"))
	):
		_fish_catch_jump_done = false

	# --- Due dinamiche distinte ---
	# IN ACQUA: lotta + progresso + tiro orizzontale (resta sotto).
	# USCITA / FUORI: niente lotta, tiro verso canna, pendolo.
	var can_start_exit := (
		not fish_struggle_active
		and not fish_out
		and not _fish_catch_jump_done
		and _fish_reel_progress >= catch_jump_reel_threshold
	)

	# Non spegnere mai l'uscita una volta iniziata.
	if current_fish.has_method("set_allow_surface_exit"):
		if fish_out or _fish_catch_jump_done or can_start_exit:
			current_fish.call("set_allow_surface_exit", true)
		else:
			current_fish.call("set_allow_surface_exit", false)

	if (
		can_start_exit
		and is_reeling
		and current_fish.has_method("do_catch_jump")
	):
		# Uscita solo vicino al player / FishArea (niente trigger solo per near_surface).
		if (
			in_area
			or dist < fish_catch_jump_distance
			or (
				near_surface
				and horizontal_dist < 70.0
				and dist < 100.0
				and _fish_reel_progress >= catch_jump_reel_threshold + 0.12
			)
		):
			current_fish.call("do_catch_jump")
			_fish_catch_jump_done = true
			_stop_fish_struggle()
			_sync_line_length_for_hang()

	if current_fish.has_method("set_line_tether"):
		current_fish.call("set_line_tether", rod, current_line_length)
	if fish_out and current_fish.has_method("get_hang_tether_length"):
		var fish_len := float(current_fish.call("get_hang_tether_length"))
		if fish_len > 1.0 and fish_len < current_line_length:
			current_line_length = maxf(28.0, fish_len)
			current_fish.call("set_line_tether", rod, current_line_length)

	fish_pos = get_fish_center_position(current_fish)
	to_rod = Vector2(rod.x - fish_pos.x, rod.y - fish_pos.y)
	dist = to_rod.length()

	if _can_finish_fish_catch(dist):
		_complete_fish_catch(current_fish)
		return

	# Lotta in acqua: non trascinare (ma non annullare un'uscita gia' partita).
	if fish_struggle_active and not fish_out and not _fish_catch_jump_done:
		return

	var dir: Vector2 = to_rod.normalized() if to_rod.length_squared() > 0.0001 else Vector2.UP
	var pull: float
	var haul_mul: float
	var allow_exit_pull := fish_out or _fish_catch_jump_done or can_start_exit

	if fish_out or _fish_catch_jump_done:
		# Fuori dall'acqua: verso la canna, ma lento. Prima veniva succhiato
		# in un attimo e spariva nel player.
		dir = Vector2(dir.x * 0.5, minf(dir.y, -0.75)).normalized()
		pull = reel_pull_force * (0.42 + _fish_reel_progress * 0.12)
		haul_mul = 0.38
	else:
		# MODO IN ACQUA: avvicina al player, resta sott'acqua.
		dir = Vector2(to_rod.x, to_rod.y * 0.35)
		if dir.length_squared() > 0.0001:
			dir = dir.normalized()
		pull = reel_pull_force * (0.55 + _fish_reel_progress * 0.2)
		haul_mul = 0.55
		# Se sbarco sbloccato e stai reelando: inizia a salire.
		if can_start_exit and is_reeling:
			dir = Vector2(dir.x * 0.6, minf(dir.y, -0.65)).normalized()
			pull = reel_pull_force * 0.48
			haul_mul = 0.42

	if current_fish.has_method("apply_reel_force"):
		current_fish.call("apply_reel_force", dir * pull)
	var haul := reel_in_speed * delta * haul_mul
	if current_fish.has_method("pull_along_line"):
		current_fish.call("pull_along_line", rod, haul, allow_exit_pull)


func _sync_line_length_for_hang() -> void:
	if not is_instance_valid(current_fish):
		return
	var rod: Vector2 = get_rod_tip_position()
	var d := rod.distance_to(get_fish_center_position(current_fish))
	# Mai allungare: all'uscita la lenza si accorcia alla distanza reale.
	current_line_length = clampf(minf(current_line_length, d), 28.0, max_line_length)
	if current_fish.has_method("set_line_tether"):
		current_fish.call("set_line_tether", rod, current_line_length)
	if current_fish.has_method("get_hang_tether_length"):
		var fish_len := float(current_fish.call("get_hang_tether_length"))
		if fish_len > 1.0:
			current_line_length = minf(current_line_length, maxf(28.0, fish_len))
			current_fish.call("set_line_tether", rod, current_line_length)


func _tether_fish_to_line(rod: Vector2, max_len: float) -> void:
	if not is_instance_valid(current_fish):
		return
	var fish_pos: Vector2 = get_fish_center_position(current_fish)
	var offset: Vector2 = fish_pos - rod
	var dist := offset.length()
	var limit := maxf(max_len, 28.0)
	if dist <= limit or dist < 0.001:
		return
	var clamped_pos: Vector2 = rod + offset.normalized() * limit
	current_fish.global_position = clamped_pos
	if "velocity" in current_fish:
		var outward := offset.normalized()
		var radial: float = current_fish.velocity.dot(outward)
		if radial > 0.0:
			current_fish.velocity -= outward * radial


func _complete_fish_catch(fish: Node2D) -> void:
	if fish == null or not is_instance_valid(fish):
		return
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
	_fish_reel_progress = 0.0
	_fish_hooked_time = 0.0
	_fish_catch_jump_done = false
	_destroy_hook()


func _notify_gameplay(text: String) -> void:
	var level := get_tree().current_scene
	if level and level.has_method("_show_message"):
		level.call("_show_message", text)
	elif OS.is_debug_build():
		print(text)


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
	is_swinging = false
	if enemy_hooked and is_instance_valid(current_hooked_enemy):
		current_hooked_enemy.call("release_combat_hook", Vector2.ZERO, false)
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
	enemy_hooked = false
	current_hooked_enemy = null
	_enemy_power_window_left = 0.0
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

func _spawn_particles(pos: Vector2, direction: Vector2, _duration: float = 0.3, amount_override: int = -1, attack_impact: bool = false) -> Node2D:
	if black_particle_scene == null:
		return null
	var p = black_particle_scene.instantiate()
	if p == null:
		return null
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
	if attack_impact and p.has_method("set_attack_impact_blur"):
		p.call("set_attack_impact_blur", direction)
	if p.has_method("play"):
		p.call("play")
	return p as Node2D

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
		_bounce_off_water()
		take_damage(1, Vector2.ZERO, true)
	elif not in_w:
		_water_owner = null


func _bounce_off_water() -> void:
	## Colpo d'acqua: slancio dedicato verso l'alto, poi Space conferma il salto.
	var hop := maxf(water_bounce_speed, jump_speed * 1.12)
	velocity.y = -hop
	jump_amount = 2
	_water_hop_timer = 0.42
	_begin_variable_jump(velocity.y)
	if particles_on_jump and black_particle_scene:
		_spawn_particles(global_position, Vector2.UP, 0.22, 3)
	if particles_on_land and ambient_trail_scene:
		_spawn_trail(global_position, Vector2.UP)


func refresh_jumps_from_water_surface() -> void:
	## Chiamato dall'acqua se si ribatte sulla superficie restando in overlap.
	if is_dead or get_meta("arrival_locked", false):
		return
	if _water_hop_timer > 0.0:
		return
	_bounce_off_water()


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
