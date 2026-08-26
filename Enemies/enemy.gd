extends CharacterBody2D

const PROJECTILE_SCRIPT := preload("res://Enemies/enemy_projectile.gd")
const AREA_ATTACK_SCRIPT := preload("res://Enemies/enemy_area_attack.gd")
const HARPOON_SCRIPT := preload("res://Enemies/enemy_harpoon.gd")
const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")
const MAX_TRANSIENT_ATTACKS := 64

# ===========================================
# ENEMY - Nemico che resta idle finché non viene colpito
# ===========================================
# Idle: animazione Idle, non fa nulla
# Dopo essere colpito: va in aggro, insegue il player, saltella e può colpire

@export_category("Movement")
@export var move_speed: float = 80.0
@export var move_acceleration: float = 460.0
@export var move_friction: float = 520.0
@export var gravity: float = 500.0
@export var jump_speed: float = 220.0
@export var melee_windup: float = 0.22
@export var patrol_range: float = 130.0
@export var patrol_speed_multiplier: float = 0.58
@export var body_world_size := Vector2(30.0, 38.0)
@export var patrol_edge_check_distance: float = 22.0

@export_category("Health")
@export var max_health: int = 6

@export_category("Aggro")
@export var aggro_range: float = 140.0   # distanza: se il player si avvicina entro questo range, diventa aggressivo
@export var wake_delay: float = 0.75      # breve telegraph prima che possa attivarsi
@export var jump_interval: float = 1.7   # secondi tra un salto e l'altro in aggro
@export var attack_range: float = 58.0   # distanza per considerare "vicino" al player
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.35
@export var knockback_speed: float = 168.0
@export var knockback_lift: float = 86.0
@export var knockback_duration: float = 0.18

@export_category("Archetype")
enum AttackPattern {
	MELEE,
	TIDE_AREA,
	AIMED_VOLLEY,
	RADIAL_BARRAGE,
	HEAVY_LEAP,
	CHARGE_BURST,
	MARKED_STRIKE,
	SPIRAL_SHOT,
	SALT_POOL,
	HARPOON_LINE,
}
@export var attack_pattern: AttackPattern = AttackPattern.MELEE
@export var variant_texture: Texture2D
@export var variant_scale_multiplier := 1.0
@export var hovering := false
@export var special_attack_range := 260.0
@export var special_attack_cooldown := 3.2
@export var special_windup := 0.65
@export var area_attack_radius := 88.0
@export_range(3, 16, 1) var projectile_count := 5
@export var projectile_speed := 135.0
@export var leash_distance := 460.0
@export var disengage_range := 560.0
@export_range(0.0, 1.0) var heavy_melee_chance := 0.32
@export var heavy_melee_damage := 2
@export var heavy_leap_damage := 2
@export var charge_speed := 340.0
@export var charge_duration := 0.42
@export var spiral_spin := 1.8

@export_category("Grace reset")
@export var post_respawn_wake_delay := 3.5
@export var activation_managed := false

@export_category("Fishing combat")
## I nemici pesanti possono essere agganciati e storditi dalla lenza, ma non trascinati.
@export var combat_hook_heavy := false
@export var combat_hook_launch_speed := 560.0
@export var combat_hook_power_launch_speed := 760.0
@export_range(0.2, 1.5, 0.05) var combat_hook_escape_ratio := 0.95
@export_range(0.2, 1.2, 0.05) var combat_hook_heavy_escape_ratio := 0.62

@export_category("Visual")
@export var sprite_node: Node2D = null
## Kit art sostituibile: still e/o sheet a clip (idle/walk/wake/windup/attack/hurt/death/jump).
@export var art_kit: EnemyArtKit
## Colore dello sprite quando viene colpito (flash molto visibile)
@export var hit_flash_color: Color = Color(2.15, 2.2, 2.25, 1.0)
@export var hit_flash_duration: float = 0.12
## Scena particelle quando colpito (es. BlackParticle); vuoto = nessuna
@export var hit_particle_scene: PackedScene = null

enum State { IDLE, AGGRO, DEAD }
var state: State = State.IDLE
var current_health: int = 6
var player: Node2D = null
var jump_timer: float = 0.0
var attack_timer: float = 0.0
var facing_right: bool = true
var _attack_hitbox_disable_timer: float = 0.0
var _knockback_timer: float = 0.0
var _hitstop_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _flip_cooldown: float = 0.0
var _attack_has_hit := false
const FLIP_MIN_INTERVAL: float = 0.2  # cooldown tra un cambio direzione e l'altro (evita glitch avanti/indietro)

var _hurtbox: Area2D = null
var _attack_hitbox: Area2D = null
var _anim: AnimationPlayer = null
var _animated: AnimatedSprite2D = null
var _using_frames := false
var _clip_lock := ""
var _clip_lock_timer := 0.0
var _original_sprite_scale: Vector2 = Vector2.ONE
var _breath_timer: float = 0.0
var _original_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
var _wake_timer := 0.0
var _home_position := Vector2.ZERO
var _special_timer := 1.0
var _special_windup_remaining := 0.0
var _special_target_direction := Vector2.RIGHT
var _base_sprite_position := Vector2.ZERO
var _attack_kick := 0.0
var _pending_melee_damage := 1
var _leap_slam_armed := false
var _leap_slam_timer := 0.0
var _charge_timer := 0.0
var _mark_position := Vector2.ZERO
var _spiral_phase := 0.0
var _melee_windup_remaining := 0.0
var _strafe_timer := 0.0
var _strafe_sign := 1.0
var _patrol_dir := 1.0
var _patrol_turn_cooldown := 0.0
var _chase_switch_cooldown := 0.0
var _chase_dir := 1.0
var _combat_hooked := false
var _stagger_timer := 0.0
var _duel_timer := 0.0
var _duel_committed := false
var _hover_timer := 0.0
var _hover_mode := 0
var _patrol_pause := 0.0
var _step_cycle := 0.0
var _combat_hook_owner: Node2D = null
var _combat_hook_pull_velocity := Vector2.ZERO
var _combat_hook_reel_active := false
var _combat_hook_previous_state := State.IDLE
var _combat_hook_previous_player: Node2D = null
var _combat_hook_previous_velocity := Vector2.ZERO
var _combat_hook_previous_facing := true

const PATROL_TURN_INTERVAL := 0.38
const CHASE_TURN_INTERVAL := 0.28
const CHASE_DEAD_ZONE := 34.0

func _ready():
	add_to_group("enemy")
	_home_position = global_position
	current_health = max_health
	_wake_timer = wake_delay
	_anim = get_node_or_null("AnimationPlayer")
	_hurtbox = get_node_or_null("Hurtbox")
	_attack_hitbox = get_node_or_null("AttackHitbox")
	_normalize_collision_to_feet()
	if sprite_node == null:
		sprite_node = get_node_or_null("Sprite2D")
	if art_kit:
		apply_art_kit(art_kit)
	elif variant_texture and sprite_node is Sprite2D:
		apply_variant_art(variant_texture)
	if variant_texture and sprite_node and not _using_frames:
		sprite_node.scale *= variant_scale_multiplier
	if sprite_node:
		_original_sprite_scale = sprite_node.scale
		_original_modulate = sprite_node.modulate
		_base_sprite_position = sprite_node.position
		# Ancora i piedi dello sprite sull'origine (niente immersione nel pavimento).
		sprite_node.position = Vector2(_base_sprite_position.x, -body_world_size.y * 0.45 / maxf(absf(scale.y), 0.001))
		_base_sprite_position = sprite_node.position
		_apply_archetype_look()
	if _hurtbox:
		_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	if _attack_hitbox:
		_attack_hitbox.body_entered.connect(_on_attack_hit_body)
		_attack_hitbox.monitoring = false
		_attack_hitbox.collision_mask = 2  # layer 2 = player, così ti colpisce anche quando salta
	# Layer 2, mask 1: collide solo con terreno (layer 1), non col player = non ti finisce sopra
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 18.0
	floor_max_angle = deg_to_rad(60.0)
	floor_constant_speed = true
	floor_stop_on_slope = false
	# Tutti gli archetipi devono stare davanti a piattaforme e fondali. Il vecchio
	# z=-1 dei gamberetti li faceva sparire dietro il bordo della banchina.
	z_index = 6
	_patrol_dir = 1.0 if randf() < 0.5 else -1.0
	_chase_dir = _patrol_dir
	play_idle()
	queue_redraw()
	if not hovering:
		call_deferred("_snap_to_floor")


func apply_variant_art(texture: Texture2D) -> void:
	# Still-only swap: collisioni e hitbox restano quelle del CharacterBody2D.
	if texture == null:
		return
	if art_kit == null:
		art_kit = EnemyArtKit.new()
	art_kit.still = texture
	apply_art_kit(art_kit)


func apply_art_kit(kit: EnemyArtKit) -> void:
	# Hollow Knight: il codice chiede un nome clip; l'artista cambia pixel/sheet.
	if kit == null:
		return
	art_kit = kit
	var still := kit.resolved_still()
	if still:
		variant_texture = still
	var sprite_frames := kit.resolved_frames()
	_using_frames = sprite_frames != null
	if _using_frames:
		_ensure_animated(sprite_frames)
		if _anim:
			_anim.active = false
	elif still and sprite_node is Sprite2D:
		var sprite := sprite_node as Sprite2D
		sprite.visible = true
		sprite.texture = still
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.frame = 0
		if _animated:
			_animated.visible = false
		if _anim:
			_anim.active = false
	if sprite_node:
		_original_sprite_scale = sprite_node.scale
		_base_sprite_position = sprite_node.position
		_apply_archetype_look()
	_play_clip("idle")


func _ensure_animated(sprite_frames: SpriteFrames) -> void:
	if sprite_node == null:
		sprite_node = get_node_or_null("Sprite2D")
	_animated = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _animated == null:
		_animated = AnimatedSprite2D.new()
		_animated.name = "AnimatedSprite2D"
		add_child(_animated)
	_animated.sprite_frames = sprite_frames
	_animated.visible = true
	_animated.centered = true
	if sprite_node:
		_animated.position = sprite_node.position
		_animated.scale = sprite_node.scale
		_animated.z_index = sprite_node.z_index
		if sprite_node is CanvasItem:
			sprite_node.visible = false
	sprite_node = _animated


func _play_clip(clip_name: String, force := false) -> void:
	if _using_frames and _animated and _animated.sprite_frames and _animated.sprite_frames.has_animation(clip_name):
		if not force and _clip_lock_timer > 0.0 and _clip_lock != "" and clip_name != _clip_lock:
			if clip_name in ["idle", "walk"]:
				return
		if _animated.animation != clip_name or force:
			_animated.play(clip_name)
		var looping := _animated.sprite_frames.get_animation_loop(clip_name)
		if looping:
			_clip_lock = ""
			_clip_lock_timer = 0.0
		else:
			var frames := maxi(_animated.sprite_frames.get_frame_count(clip_name), 1)
			var fps := maxf(_animated.sprite_frames.get_animation_speed(clip_name), 1.0)
			_clip_lock = clip_name
			_clip_lock_timer = float(frames) / fps
		return
	if _anim == null or not _anim.active:
		return
	var aliases := {
		"idle": "Idle",
		"walk": "Walk",
		"jump": "Jump",
		"attack": "Attack",
		"hurt": "Hit",
		"wake": "Idle",
		"windup": "Idle",
		"death": "Hit",
	}
	var anim_name := String(aliases.get(clip_name, clip_name))
	if _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name)


func _sync_locomotion_clip() -> void:
	if _clip_lock_timer > 0.0:
		return
	if not hovering and absf(velocity.x) > 8.0:
		_play_clip("walk")
	else:
		_play_clip("idle")


func _normalize_collision_to_feet() -> void:
	# Gli enemy in scena usano scale ~0.04–0.09 su shape enormi: senza normalizzare
	# i piedi affondano nel pavimento quando li ingrandisci.
	var sx := maxf(absf(scale.x), 0.001)
	var sy := maxf(absf(scale.y), 0.001)
	var body := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(body_world_size.x / sx, body_world_size.y / sy)
		body.shape = shape
		body.position = Vector2(0.0, -body_world_size.y * 0.5 / sy)
	if _hurtbox:
		var hcol := _hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if hcol:
			var hshape := RectangleShape2D.new()
			var hurt := body_world_size * (Vector2(2.05, 2.35) if hovering else Vector2(1.85, 1.4))
			hshape.size = Vector2(hurt.x / sx, hurt.y / sy)
			hcol.shape = hshape
			hcol.position = Vector2(0.0, -hurt.y * (0.62 if hovering else 0.5) / sy)
			hcol.disabled = false
		_hurtbox.monitorable = true
		_hurtbox.monitoring = true
		_hurtbox.collision_layer = 2
		_hurtbox.collision_mask = 4
	if _attack_hitbox:
		var acol := _attack_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if acol:
			var ashape := RectangleShape2D.new()
			var atk := Vector2(34.0, 28.0)
			ashape.size = Vector2(atk.x / sx, atk.y / sy)
			acol.shape = ashape
			acol.position = Vector2((22.0 if facing_right else -22.0) / sx, -body_world_size.y * 0.35 / sy)
		_attack_hitbox.position = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(0.0, _hitstop_timer - delta)
		queue_redraw()
		return
	_patrol_turn_cooldown = maxf(0.0, _patrol_turn_cooldown - delta)
	_chase_switch_cooldown = maxf(0.0, _chase_switch_cooldown - delta)
	# La lenza limita il combattimento, ma non cancella la volonta' di movimento.
	# L'avversario continua a fuggire e la tensione risultante viene trasferita
	# al player dal controller della pesca.
	if _stagger_timer > 0.0 and not _combat_hooked:
		_stagger_timer = maxf(0.0, _stagger_timer - delta)
		velocity.x = move_toward(velocity.x, 0.0, move_friction * 1.6 * delta)
		if not hovering:
			velocity.y += gravity * delta
		if sprite_node:
			var wobble := sin(Time.get_ticks_msec() * 0.021) * 0.14 * _stagger_timer
			sprite_node.rotation = wobble
			# Vira in ambra acceso: e' l'unico segnale che dice "colpiscimi ora".
			var flash: float = 0.62 + 0.38 * sin(Time.get_ticks_msec() * 0.017)
			sprite_node.modulate = _original_modulate.lerp(
				Color(1.35, 0.86, 0.4, 1.0), clampf(_stagger_timer * 1.6, 0.0, 1.0) * flash
			)
		move_and_slide()
		queue_redraw()
		return
	if sprite_node and _stagger_timer <= 0.0:
		if not is_zero_approx(sprite_node.rotation):
			sprite_node.rotation = move_toward(sprite_node.rotation, 0.0, delta * 3.0)
		if not sprite_node.modulate.is_equal_approx(_original_modulate) and _hit_flash_timer <= 0.0:
			sprite_node.modulate = sprite_node.modulate.lerp(_original_modulate, delta * 6.0)
	if _combat_hooked:
		_update_combat_hook_escape(delta)
		move_and_slide()
		queue_redraw()
		return
	if _clip_lock_timer > 0.0:
		_clip_lock_timer = maxf(0.0, _clip_lock_timer - delta)
		if _clip_lock_timer <= 0.0:
			_clip_lock = ""
	# Still-only: respiro procedurale. Con uno sheet si guidano le clip per nome.
	if variant_texture and not _using_frames:
		_update_variant_animation(delta)
	elif sprite_node and state != State.DEAD:
		_breath_timer += delta
		var t = sin(_breath_timer * 2.4)
		var breath_y = 1.0 + 0.09 * t
		var breath_x = 1.0 - 0.025 * t
		sprite_node.scale = Vector2(_original_sprite_scale.x * breath_x, _original_sprite_scale.y * breath_y)
	# Flash colore quando colpito
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if sprite_node:
			if _hit_flash_timer <= 0.0:
				sprite_node.modulate = _original_modulate
			else:
				sprite_node.modulate = hit_flash_color

	if state == State.IDLE:
		_wake_timer = maxf(0.0, _wake_timer - delta)
		# Se il player si avvicina, diventa aggressivo (mai vicino a un Altare della Marea)
		var p = get_tree().get_first_node_in_group("player") as Node2D
		if p and is_instance_valid(p) and not _is_player_sanctuary_safe(p):
			var d = global_position.distance_to(p.global_position)
			if d <= aggro_range and _wake_timer <= 0.0:
				state = State.AGGRO
				player = p
				jump_timer = 0.0
				_play_clip("wake", true)
		_update_patrol(delta)
		if hovering:
			var hover_target := _home_position.y + sin(_breath_timer * 1.35) * 7.0
			velocity.y = clampf((hover_target - global_position.y) * 3.2, -45.0, 45.0)
		else:
			velocity.y += gravity * delta
		move_and_slide()
		if is_on_wall():
			_turn_patrol()
		_flip_patrol_facing()
		if not hovering and _melee_windup_remaining <= 0.0:
			_sync_locomotion_clip()
		queue_redraw()
		return

	# Rinculo: arco breve, poi ricade. Niente inseguimento finché è in aria.
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity.y += gravity * 1.55 * delta
		velocity.x = move_toward(velocity.x, 0.0, 640.0 * delta)
		move_and_slide()
		queue_redraw()
		return

	# AGGRO: insegui il player
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			state = State.IDLE
			play_idle()
			return
	if _is_player_sanctuary_safe(player):
		_disengage()
		return

	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() > disengage_range or global_position.distance_to(_home_position) > leash_distance:
		_disengage()
		return
	var wanted_chase_dir := signf(to_player.x)
	if (
		absf(to_player.x) > CHASE_DEAD_ZONE
		and wanted_chase_dir != 0.0
		and wanted_chase_dir != _chase_dir
		and _chase_switch_cooldown <= 0.0
	):
		_chase_dir = wanted_chase_dir
		_chase_switch_cooldown = CHASE_TURN_INTERVAL
	var dir_x: float = _chase_dir
	var dist: float = to_player.length()
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(0.55, 1.15)
		_strafe_sign = -_strafe_sign if randf() < 0.55 else _strafe_sign

	if _charge_timer > 0.0:
		_charge_timer -= delta
		velocity.x = signf(_special_target_direction.x) * charge_speed
		if _charge_timer <= 0.0 and _attack_hitbox:
			_attack_hitbox.set_deferred("monitoring", false)
			_attack_hitbox.set_deferred("monitorable", false)
			if sprite_node and _hit_flash_timer <= 0.0:
				sprite_node.modulate = _original_modulate
	else:
		var desired_x := 0.0
		var windup_slow := _special_windup_remaining > 0.0 or _melee_windup_remaining > 0.0
		if attack_pattern in [
			AttackPattern.AIMED_VOLLEY,
			AttackPattern.RADIAL_BARRAGE,
			AttackPattern.SPIRAL_SHOT,
			AttackPattern.HARPOON_LINE,
		]:
			# Ranged: mantieni distanza e strafe.
			if dist < special_attack_range * 0.45:
				desired_x = -dir_x * move_speed * 0.85
			elif dist > special_attack_range * 0.85:
				desired_x = dir_x * move_speed * 0.7
			else:
				desired_x = _strafe_sign * move_speed * 0.55
		elif attack_pattern == AttackPattern.CHARGE_BURST and dist < 90.0:
			desired_x = -dir_x * move_speed * 0.4
		else:
			# Duello invece di corsa frontale: entra in misura, la tiene
			# girandoci intorno, arretra e ogni tanto affonda davvero.
			_duel_timer -= delta
			if _duel_timer <= 0.0:
				_duel_committed = not _duel_committed
				_duel_timer = randf_range(0.45, 0.75) if _duel_committed else randf_range(0.9, 1.8)
			if _duel_committed or dist > attack_range * 1.5:
				desired_x = dir_x * move_speed
			elif dist < attack_range * 0.62:
				desired_x = -dir_x * move_speed * 0.6
			else:
				desired_x = _strafe_sign * move_speed * 0.45
		if windup_slow:
			desired_x *= 0.22
		var accel := move_acceleration if absf(desired_x) > 1.0 else move_friction
		velocity.x = move_toward(velocity.x, desired_x, accel * delta)

	# Flip verso il player solo dopo cooldown (evita glitch avanti/indietro)
	_flip_cooldown -= delta
	if dir_x != 0 and _flip_cooldown <= 0.0 and _charge_timer <= 0.0:
		var new_facing: bool = dir_x > 0
		if new_facing != facing_right and abs(to_player.x) > 18.0:
			facing_right = new_facing
			_flip_cooldown = FLIP_MIN_INTERVAL
			if sprite_node:
				if "flip_h" in sprite_node:
					sprite_node.flip_h = !facing_right
				elif sprite_node is Sprite2D:
					sprite_node.flip_h = !facing_right
			_sync_attack_hitbox_facing()

	# Gravità e salto periodico; gli oracoli restano sospesi e seguono in verticale.
	if hovering:
		# Ciclo di volo: pedina in quota, sale a prendere aria, poi picchia.
		# Prima stava semplicemente all'altezza del player, ed era piatto.
		_hover_timer -= delta
		if _hover_timer <= 0.0:
			match _hover_mode:
				0:
					_hover_mode = 1
					_hover_timer = randf_range(0.7, 1.1)
				1:
					_hover_mode = 2
					_hover_timer = randf_range(0.55, 0.85)
				_:
					_hover_mode = 0
					_hover_timer = randf_range(1.4, 2.4)
		var hover_amp := 9.0 if state == State.AGGRO else 6.0
		var hover_offset := -28.0
		var vertical_speed := 2.8
		match _hover_mode:
			1:
				hover_offset = -132.0
				vertical_speed = 3.4
			2:
				hover_offset = 6.0
				vertical_speed = 5.6
		var hover_target := (
			player.global_position.y + hover_offset + sin(_breath_timer * 1.7) * hover_amp
		)
		var limit := 190.0 if _hover_mode == 2 else 95.0
		velocity.y = clampf((hover_target - global_position.y) * vertical_speed, -limit, limit)
	else:
		velocity.y += gravity * delta
		jump_timer -= delta
		if is_on_floor() and jump_timer <= 0.0 and _melee_windup_remaining <= 0.0:
			# Salto più intenzionale: spesso verso il player o per chiudere gap.
			jump_timer = jump_interval * randf_range(0.75, 1.2)
			var leap_boost := 1.0
			if dist > attack_range * 1.6 and dist < 180.0:
				leap_boost = 1.15
			velocity.y = -jump_speed * leap_boost
			velocity.x += dir_x * move_speed * 0.35
			_play_clip("jump", true)

	_update_special_attack(delta, to_player)
	_update_leap_slam(delta)
	_update_melee_attack(delta, dist)

	move_and_slide()

	if (
		is_on_floor()
		and state == State.AGGRO
		and _melee_windup_remaining <= 0.0
		and (_anim == null or not _anim.is_playing() or _anim.current_animation == "Idle")
	):
		_sync_locomotion_clip()
	queue_redraw()


func _update_melee_attack(delta: float, dist: float) -> void:
	attack_timer -= delta
	if _attack_hitbox_disable_timer > 0.0:
		_attack_hitbox_disable_timer -= delta
		if _attack_hitbox_disable_timer <= 0.0 and _attack_hitbox:
			_attack_hitbox.monitoring = false
	if _melee_windup_remaining > 0.0:
		_melee_windup_remaining -= delta
		queue_redraw()
		if _melee_windup_remaining > 0.0:
			return
		# Colpo dopo telegraph.
		_attack_has_hit = false
		if _attack_hitbox:
			_attack_hitbox.monitoring = true
			_attack_hitbox_disable_timer = 0.34 if _pending_melee_damage > attack_damage else 0.24
		_attack_kick = 1.0
		# Un colpo deve avere peso anche senza mostrare hitbox di debug.
		PARTICLE_BURST.spawn(
			get_tree().current_scene,
			global_position + Vector2(30.0 if facing_right else -30.0, -12.0),
			Color(0.95, 0.58, 0.34, 0.82),
			7 if _pending_melee_damage <= attack_damage else 12,
			Vector2.RIGHT if facing_right else Vector2.LEFT,
			28.0,
			82.0,
			0.34
		)
		_play_clip("attack", true)
		return
	if (
		dist <= attack_range
		and attack_timer <= 0.0
		and _attack_hitbox
		and _attack_hitbox_disable_timer <= 0.0
		and _special_windup_remaining <= 0.0
		and _charge_timer <= 0.0
	):
		attack_timer = attack_cooldown
		if player and is_instance_valid(player):
			var face_x := player.global_position.x - global_position.x
			if absf(face_x) > 4.0:
				facing_right = face_x > 0.0
				if sprite_node:
					sprite_node.flip_h = not facing_right
				_sync_attack_hitbox_facing()
		var heavy := attack_pattern == AttackPattern.MELEE and randf() < heavy_melee_chance
		_pending_melee_damage = heavy_melee_damage if heavy else attack_damage
		_melee_windup_remaining = melee_windup * (1.25 if heavy else 1.0)
		_hit_flash_timer = 0.1 if heavy else 0.0
		_play_clip("windup", true)
		if sprite_node:
			sprite_node.modulate = Color(1.4, 0.5, 0.38, 1.0) if heavy else Color(1.15, 0.85, 0.7, 1.0)
		queue_redraw()

func _update_special_attack(delta: float, to_player: Vector2) -> void:
	if attack_pattern == AttackPattern.MELEE:
		return
	_special_timer = maxf(0.0, _special_timer - delta)
	_spiral_phase += delta
	if _special_windup_remaining > 0.0:
		_special_windup_remaining -= delta
		if (
			(attack_pattern == AttackPattern.MARKED_STRIKE or attack_pattern == AttackPattern.SALT_POOL)
			and player
			and is_instance_valid(player)
		):
			_mark_position = player.global_position + Vector2(0, 10)
		queue_redraw()
		if _special_windup_remaining <= 0.0:
			_fire_special_attack()
		return
	var distance := to_player.length()
	var can_start := distance <= special_attack_range
	if attack_pattern == AttackPattern.TIDE_AREA:
		can_start = distance <= area_attack_radius + 52.0
	elif attack_pattern == AttackPattern.HEAVY_LEAP:
		can_start = distance <= 210.0 and distance >= 48.0
	elif attack_pattern == AttackPattern.CHARGE_BURST:
		can_start = distance <= 240.0 and distance >= 40.0 and _charge_timer <= 0.0
	elif attack_pattern == AttackPattern.MARKED_STRIKE:
		can_start = distance <= special_attack_range and distance >= 60.0
	elif attack_pattern == AttackPattern.SPIRAL_SHOT:
		can_start = distance <= special_attack_range
	elif attack_pattern == AttackPattern.SALT_POOL:
		can_start = distance <= special_attack_range and distance >= 40.0
	elif attack_pattern == AttackPattern.HARPOON_LINE:
		can_start = distance <= special_attack_range and distance >= 70.0
	if can_start and _special_timer <= 0.0:
		_special_target_direction = to_player.normalized() if distance > 0.01 else Vector2.RIGHT
		if attack_pattern == AttackPattern.MARKED_STRIKE or attack_pattern == AttackPattern.SALT_POOL:
			_mark_position = player.global_position + Vector2(0, 10)
		var windup_scale := 1.0
		if attack_pattern == AttackPattern.HEAVY_LEAP:
			windup_scale = 0.75
		elif attack_pattern == AttackPattern.CHARGE_BURST:
			windup_scale = 0.85
		elif attack_pattern == AttackPattern.HARPOON_LINE:
			windup_scale = 0.7
		_special_windup_remaining = special_windup * windup_scale
		_special_timer = special_attack_cooldown
		_play_clip("windup", true)
		velocity.x *= 0.15
		queue_redraw()


func _fire_special_attack() -> void:
	_attack_kick = 1.0
	_play_clip("attack", true)
	queue_redraw()
	if attack_pattern == AttackPattern.TIDE_AREA:
		# Windup già fatto sul nemico: l'area esplode subito (solo breve flash).
		var area := AREA_ATTACK_SCRIPT.new() as Area2D
		area.call("setup", area_attack_radius, maxi(attack_damage, 2), Color(0.24, 0.92, 0.78, 1.0), 0.12)
		get_tree().current_scene.add_child(area)
		area.global_position = global_position
		_shake_camera(0.28)
		return
	if attack_pattern == AttackPattern.HEAVY_LEAP:
		velocity = Vector2(_special_target_direction.x * 260.0, -240.0)
		_leap_slam_armed = true
		# Tempo minimo in aria prima dello slam (evita detonazione a terra nello stesso frame).
		_leap_slam_timer = 0.18
		if sprite_node:
			sprite_node.modulate = Color(1.4, 0.5, 0.4, 1.0)
		return
	if attack_pattern == AttackPattern.CHARGE_BURST:
		_charge_timer = charge_duration
		velocity = Vector2(signf(_special_target_direction.x) * charge_speed, -40.0)
		_pending_melee_damage = heavy_melee_damage
		_attack_has_hit = false
		if _attack_hitbox:
			_attack_hitbox.monitoring = true
			_attack_hitbox.monitorable = true
			_sync_attack_hitbox_facing()
		_shake_camera(0.22)
		if sprite_node:
			sprite_node.modulate = Color(1.25, 0.85, 0.35, 1.0)
		return
	if attack_pattern == AttackPattern.MARKED_STRIKE:
		var strike := AREA_ATTACK_SCRIPT.new() as Area2D
		strike.call("setup", area_attack_radius * 0.85, maxi(attack_damage, 2), Color(0.95, 0.55, 0.28, 1.0), 0.42)
		get_tree().current_scene.add_child(strike)
		strike.global_position = _mark_position
		_shake_camera(0.2)
		return
	if attack_pattern == AttackPattern.AIMED_VOLLEY:
		var count := maxi(3, projectile_count)
		for index in count:
			var offset := float(index) - float(count - 1) * 0.5
			var direction := _special_target_direction.rotated(offset * 0.13)
			_spawn_projectile(direction, projectile_speed, Color(0.35, 0.94, 0.78, 1.0), 5.5)
		return
	if attack_pattern == AttackPattern.RADIAL_BARRAGE:
		var count := maxi(8, projectile_count)
		var phase := _breath_timer * 0.7
		for index in count:
			var direction := Vector2.from_angle(phase + TAU * float(index) / float(count))
			var speed_scale := 0.82 if index % 2 == 0 else 1.08
			_spawn_projectile(direction, projectile_speed * speed_scale, Color(0.42, 0.82, 1.0, 1.0), 5.0)
		return
	if attack_pattern == AttackPattern.SPIRAL_SHOT:
		var arms := 3
		var beads := maxi(4, projectile_count)
		for arm in arms:
			var base_ang := _spiral_phase * 1.4 + TAU * float(arm) / float(arms)
			for bead in beads:
				var ang := base_ang + float(bead) * 0.28
				var direction := Vector2.from_angle(ang)
				var shot_speed := projectile_speed * (0.7 + float(bead) * 0.08)
				_spawn_projectile(
					direction,
					shot_speed,
					Color(0.55, 0.72, 1.0, 1.0) if arm % 2 == 0 else Color(0.35, 0.95, 0.82, 1.0),
					4.8,
					2.8,
					spiral_spin * (1.0 if arm % 2 == 0 else -1.0),
					1
				)
		_shake_camera(0.16)
		return
	if attack_pattern == AttackPattern.SALT_POOL:
		var pool := AREA_ATTACK_SCRIPT.new() as Area2D
		pool.call("setup", area_attack_radius * 0.9, attack_damage, Color(0.75, 0.85, 0.55, 1.0), 0.35, 1.35)
		get_tree().current_scene.add_child(pool)
		pool.global_position = _mark_position
		_shake_camera(0.18)
		return
	if attack_pattern == AttackPattern.HARPOON_LINE:
		if get_tree().get_nodes_in_group("enemy_transient_attack").size() >= MAX_TRANSIENT_ATTACKS:
			return
		var harpoon := HARPOON_SCRIPT.new() as Area2D
		harpoon.call(
			"setup",
			_special_target_direction,
			projectile_speed * 1.55,
			attack_damage,
			global_position + Vector2(0, -20),
			Color(0.95, 0.78, 0.35, 1.0),
			460.0
		)
		get_tree().current_scene.add_child(harpoon)
		harpoon.global_position = global_position + _special_target_direction * 28.0 + Vector2(0, -20)
		_shake_camera(0.2)


func _update_leap_slam(delta: float) -> void:
	if not _leap_slam_armed:
		return
	_leap_slam_timer -= delta
	if _leap_slam_timer > 0.0:
		return
	# Dopo il delay minimo: slam al contatto col suolo, o fallback hard a 0.55s totali.
	if not is_on_floor() and _leap_slam_timer > -0.37:
		return
	_leap_slam_armed = false
	_leap_slam_timer = 0.0
	var slam := AREA_ATTACK_SCRIPT.new() as Area2D
	slam.call("setup", 72.0, heavy_leap_damage, Color(0.95, 0.45, 0.32, 1.0), 0.08)
	get_tree().current_scene.add_child(slam)
	slam.global_position = global_position + Vector2(0, 8)
	_shake_camera(0.42)
	if sprite_node:
		sprite_node.modulate = _original_modulate


func _shake_camera(intensity: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("add_shake"):
		cam.call("add_shake", intensity)


func _spawn_projectile(
	direction: Vector2,
	shot_speed: float,
	color: Color,
	shot_radius: float,
	shot_lifetime := 3.2,
	spin := 0.0,
	bounces := 0
) -> void:
	if get_tree().get_nodes_in_group("enemy_transient_attack").size() >= MAX_TRANSIENT_ATTACKS:
		return
	var projectile := PROJECTILE_SCRIPT.new() as Area2D
	projectile.call("setup", direction, shot_speed, attack_damage, color, shot_radius, shot_lifetime, spin, bounces)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 24.0


func _apply_archetype_look() -> void:
	if sprite_node == null:
		return
	# Tinta leggera per distinguere archetipi anche con stessa silhouette.
	match attack_pattern:
		AttackPattern.TIDE_AREA, AttackPattern.SALT_POOL:
			_original_modulate = Color(0.78, 1.05, 0.92, 1.0)
		AttackPattern.AIMED_VOLLEY, AttackPattern.RADIAL_BARRAGE, AttackPattern.SPIRAL_SHOT:
			_original_modulate = Color(0.82, 0.95, 1.15, 1.0)
		AttackPattern.HEAVY_LEAP, AttackPattern.CHARGE_BURST:
			_original_modulate = Color(1.12, 0.88, 0.78, 1.0)
		AttackPattern.MARKED_STRIKE, AttackPattern.HARPOON_LINE:
			_original_modulate = Color(1.1, 0.95, 0.7, 1.0)
		_:
			_original_modulate = Color(1.0, 1.0, 1.0, 1.0)
	if not variant_texture:
		# Gambero base: contrasto lagunare più leggibile.
		_original_modulate *= Color(1.05, 0.98, 0.92, 1.0)
	sprite_node.modulate = _original_modulate


func _update_patrol(_delta: float) -> void:
	# Ronda con soste: si ferma, si guarda intorno e riparte. Il pendolo
	# continuo a velocita' fissa era la cosa che leggeva piu' meccanica.
	if _patrol_pause > 0.0:
		_patrol_pause = maxf(0.0, _patrol_pause - _delta)
		velocity.x = move_toward(velocity.x, 0.0, move_friction * _delta)
		if hovering:
			velocity.y = sin(_breath_timer * 1.9) * 22.0
		return
	var target_x := _home_position.x + _patrol_dir * patrol_range
	if hovering:
		# Oracoli: pendolo orizzontale intorno alla casa.
		if absf(global_position.x - target_x) < 10.0:
			_turn_patrol()
		velocity.x = _patrol_dir * move_speed * patrol_speed_multiplier
		return
	if absf(global_position.x - target_x) < 12.0:
		_turn_patrol()
	elif _patrol_edge_ahead():
		_turn_patrol()
	var desired := _patrol_dir * move_speed * patrol_speed_multiplier
	# Se troppo fuori dal tratto, tira verso il bordo del patrol.
	if absf(global_position.x - _home_position.x) > patrol_range + 24.0:
		desired = signf(_home_position.x - global_position.x) * move_speed * patrol_speed_multiplier
		_patrol_dir = signf(desired) if absf(desired) > 0.01 else _patrol_dir
	velocity.x = desired


func _patrol_edge_ahead() -> bool:
	# Evita di camminare nel vuoto: se davanti non c'è pavimento, gira.
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	var from := global_position + Vector2(_patrol_dir * patrol_edge_check_distance, -18.0)
	var to := from + Vector2(0.0, 104.0)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	query.exclude = [self]
	var hit := space.intersect_ray(query)
	return hit.is_empty()


func _turn_patrol() -> bool:
	if _patrol_turn_cooldown > 0.0:
		return false
	_patrol_dir *= -1.0
	_patrol_turn_cooldown = PATROL_TURN_INTERVAL
	if randf() < 0.45:
		_patrol_pause = randf_range(0.6, 1.5)
	return true


func _snap_to_floor() -> void:
	if hovering or state == State.DEAD:
		return
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var from := global_position + Vector2(0.0, -80.0)
	var to := global_position + Vector2(0.0, 160.0)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	query.exclude = [self]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	global_position.y = (hit.position as Vector2).y
	_home_position.y = global_position.y


func _flip_patrol_facing() -> void:
	if absf(velocity.x) < 4.0:
		return
	var want_right := velocity.x > 0.0
	if want_right == facing_right:
		return
	facing_right = want_right
	if sprite_node:
		sprite_node.flip_h = not facing_right
	_sync_attack_hitbox_facing()


func _sync_attack_hitbox_facing() -> void:
	if _attack_hitbox == null:
		return
	var sx := maxf(absf(scale.x), 0.001)
	var acol := _attack_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if acol:
		acol.position.x = (22.0 if facing_right else -22.0) / sx
	_attack_hitbox.position = Vector2.ZERO


func _is_player_sanctuary_safe(p: Node2D) -> bool:
	# Zona sicura intorno agli Altari: niente aggro / niente chase.
	const SANCTUARY_RADIUS := 118.0
	for node in get_tree().get_nodes_in_group("dogana_grace"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var grace := node as Node2D
		if grace.global_position.distance_to(p.global_position) <= SANCTUARY_RADIUS:
			return true
		if node is Area2D and (node as Area2D).overlaps_body(p):
			return true
	return false


func _draw() -> void:
	# Le hitbox sono solo collisioni: non devono mai comparire nel gioco.
	if _melee_windup_remaining > 0.0:
		var mprog := 1.0 - _melee_windup_remaining / maxf(melee_windup * 1.25, 0.01)
		var mcolor := Color(0.95, 0.45, 0.3, 0.35 + mprog * 0.5)
		draw_arc(Vector2(0, -8), lerpf(14.0, 28.0, mprog), -PI * 0.5, -PI * 0.5 + TAU * mprog, 24, mcolor, 2.2, true)
		var slash := Vector2(22 if facing_right else -22, -6) * lerpf(0.4, 1.0, mprog)
		draw_line(Vector2(0, -8), slash, mcolor, 2.0, true)
	if _special_windup_remaining <= 0.0 or special_windup <= 0.0:
		return
	var windup_scale := 1.0
	if attack_pattern == AttackPattern.HEAVY_LEAP:
		windup_scale = 0.75
	elif attack_pattern == AttackPattern.CHARGE_BURST:
		windup_scale = 0.85
	var windup_total := special_windup * windup_scale
	var progress := 1.0 - _special_windup_remaining / maxf(windup_total, 0.01)
	var color := Color(0.3, 0.95, 0.78, 0.32 + progress * 0.55)
	if attack_pattern == AttackPattern.HEAVY_LEAP:
		color = Color(0.95, 0.42, 0.28, 0.35 + progress * 0.55)
	elif attack_pattern == AttackPattern.TIDE_AREA:
		color = Color(0.22, 0.9, 0.82, 0.28 + progress * 0.5)
	elif attack_pattern == AttackPattern.CHARGE_BURST:
		color = Color(0.95, 0.78, 0.28, 0.35 + progress * 0.55)
	elif attack_pattern == AttackPattern.MARKED_STRIKE:
		color = Color(0.95, 0.5, 0.25, 0.35 + progress * 0.5)
	elif attack_pattern == AttackPattern.SPIRAL_SHOT:
		color = Color(0.45, 0.7, 1.0, 0.32 + progress * 0.55)
	elif attack_pattern == AttackPattern.SALT_POOL:
		color = Color(0.75, 0.85, 0.45, 0.35 + progress * 0.5)
	elif attack_pattern == AttackPattern.HARPOON_LINE:
		color = Color(0.95, 0.75, 0.3, 0.35 + progress * 0.55)
	var radius := lerpf(18.0, 34.0, progress)
	if attack_pattern == AttackPattern.TIDE_AREA:
		radius = lerpf(area_attack_radius * 0.35, area_attack_radius, progress)
	# Disco a terra più leggibile nell'ultimo quarto del windup.
	if progress > 0.75 and attack_pattern in [
		AttackPattern.TIDE_AREA,
		AttackPattern.SALT_POOL,
		AttackPattern.MARKED_STRIKE,
	]:
		var danger_center := to_local(_mark_position) if attack_pattern != AttackPattern.TIDE_AREA else Vector2.ZERO
		var danger_r := radius if attack_pattern == AttackPattern.TIDE_AREA else lerpf(18.0, area_attack_radius * 0.85, progress)
		draw_circle(danger_center, danger_r, Color(color.r, color.g, color.b, 0.10 + (progress - 0.75) * 0.55))
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 30, color, 2.0 + progress * 2.0, true)
	for ray in 6:
		var direction := Vector2.from_angle(float(ray) / 6.0 * TAU)
		draw_line(direction * 12.0, direction * radius, Color(color.r, color.g, color.b, color.a * 0.55), 1.4, true)
	if attack_pattern == AttackPattern.HEAVY_LEAP or attack_pattern == AttackPattern.CHARGE_BURST:
		var leap_dir := _special_target_direction if _special_target_direction.length_squared() > 0.01 else Vector2.RIGHT
		draw_line(Vector2.ZERO, leap_dir * lerpf(28.0, 90.0, progress), color, 2.4, true)
	if attack_pattern == AttackPattern.MARKED_STRIKE or attack_pattern == AttackPattern.SALT_POOL:
		var mark_local := to_local(_mark_position)
		var mark_r := lerpf(18.0, area_attack_radius * 0.85, progress)
		draw_arc(mark_local, mark_r, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.25 + progress * 0.45), 2.0, true)
		draw_circle(mark_local, 4.0 + progress * 3.0, Color(color.r, color.g, color.b, 0.55))
	if attack_pattern == AttackPattern.HARPOON_LINE:
		var tip := _special_target_direction * lerpf(40.0, 160.0, progress)
		draw_line(Vector2(0, -16), tip + Vector2(0, -16), color, 2.4, true)
		draw_circle(tip + Vector2(0, -16), 5.0 + progress * 3.0, color)
	if attack_pattern == AttackPattern.SPIRAL_SHOT:
		for arm in 3:
			var ang := _spiral_phase * 1.4 + TAU * float(arm) / 3.0
			var tip2 := Vector2.from_angle(ang) * lerpf(24.0, 70.0, progress)
			draw_line(Vector2.ZERO, tip2, color, 1.8, true)


func _update_variant_animation(delta: float) -> void:
	if sprite_node == null:
		return
	_breath_timer += delta
	_attack_kick = move_toward(_attack_kick, 0.0, delta * 3.8)
	# Le texture illustrate non hanno frame animati: niente bob/rotazioni che le fanno
	# scivolare o deformare. Solo un respiro minimo e il kick dell'attacco.
	var moving := state == State.AGGRO and absf(velocity.x) > 4.0
	var squash := sin(_breath_timer * (4.0 if moving else 2.0)) * (0.018 if moving else 0.009)
	var windup_progress := 0.0
	if _special_windup_remaining > 0.0:
		windup_progress = 1.0 - _special_windup_remaining / maxf(special_windup, 0.01)
	elif _melee_windup_remaining > 0.0:
		windup_progress = 1.0 - _melee_windup_remaining / maxf(melee_windup, 0.01)
	var pulse := sin(windup_progress * PI * 5.0) * windup_progress * 0.07
	var facing_sign := 1.0 if facing_right else -1.0
	var kick_offset := -_special_target_direction * _attack_kick * 10.0
	if _melee_windup_remaining <= 0.0 and _attack_kick > 0.0:
		kick_offset = Vector2(facing_sign * _attack_kick * 10.0, -_attack_kick * 4.0)
	# Passo: il ciclo avanza con lo spostamento reale, cosi' il rimbalzo resta
	# agganciato ai piedi invece di galleggiare a tempo fisso.
	var gait := Vector2.ZERO
	var gait_roll := 0.0
	if hovering:
		var flap := sin(_breath_timer * 8.4)
		gait = Vector2(0.0, flap * 2.2)
		gait_roll = clampf(velocity.x * 0.0011, -0.16, 0.16) + flap * 0.02
	elif absf(velocity.x) > 6.0:
		_step_cycle += delta * clampf(absf(velocity.x) / maxf(move_speed, 1.0), 0.25, 2.2) * 7.4
		gait = Vector2(0.0, -absf(sin(_step_cycle)) * 1.9)
		gait_roll = sin(_step_cycle * 0.5) * 0.035 + facing_sign * 0.03
	else:
		_step_cycle = 0.0
		# Ferma di ronda: sguardo che spazza la banchina.
		if state == State.IDLE:
			gait_roll = sin(_breath_timer * 0.9) * 0.045
	# Micro-respiro verticale: rende viva l'illustrazione senza farla fluttuare
	# rispetto ai piedi o deformarla come il vecchio bob.
	sprite_node.position = (
		_base_sprite_position + Vector2(0.0, sin(_breath_timer * 2.0) * 0.65) + gait + kick_offset
	)
	sprite_node.rotation = windup_progress * facing_sign * -0.06 + gait_roll
	sprite_node.scale = Vector2(
		_original_sprite_scale.x * (1.0 + squash + pulse + _attack_kick * 0.07),
		_original_sprite_scale.y * (1.0 - squash + pulse * 0.5 - _attack_kick * 0.045)
	)


func play_idle() -> void:
	_play_clip("idle", true)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	# Il danno lo applica solo il player nel suo _on_attack_hitbox_area_entered (1 o 2).
	# Qui non chiamiamo take_damage per evitare doppio danno e colpi "a caso" quando
	# il player non sta attaccando (l'hitbox del player ora ha layer 0 quando disabilitata).
	pass

func take_damage(amount: int = 1, source_position: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return
	current_health = max(0, current_health - amount)
	_hit_flash_timer = hit_flash_duration
	_attack_kick = 0.55
	if sprite_node:
		sprite_node.modulate = hit_flash_color
		sprite_node.scale = _original_sprite_scale * Vector2(1.12, 0.88)
	_spawn_hit_particles(source_position)
	_alert_nearby_enemies()
	queue_redraw()

	var pop := _nail_pop_velocity(source_position)
	if current_health <= 0:
		_die(pop)
		return

	velocity = pop
	_knockback_timer = knockback_duration
	apply_hitstop(0.05)

	_play_clip("hurt", true)
	if state == State.IDLE:
		state = State.AGGRO
		player = get_tree().get_first_node_in_group("player") as Node2D
		jump_timer = 0.0


func _nail_pop_velocity(source_position: Vector2) -> Vector2:
	var away := 1.0
	if source_position != Vector2.ZERO:
		away = signf(global_position.x - source_position.x)
		if is_zero_approx(away):
			away = 1.0
	var nail := Vector2(away, 0.0)
	if source_position != Vector2.ZERO:
		var attacker := get_tree().get_first_node_in_group("player")
		if attacker and attacker.get("_attack_dir") != null:
			nail = attacker.get("_attack_dir")
	if nail.y < -0.5:
		return Vector2(away * knockback_speed * 0.35, -knockback_lift * 2.6)
	if nail.y > 0.5:
		return Vector2(away * knockback_speed * 0.5, 70.0)
	return Vector2(away * knockback_speed, -knockback_lift)


func apply_hitstop(duration: float) -> void:
	_hitstop_timer = maxf(_hitstop_timer, duration)


func can_be_combat_hooked() -> bool:
	return state != State.DEAD and visible


func is_combat_hook_heavy() -> bool:
	return combat_hook_heavy


func begin_combat_hook(owner: Node2D) -> bool:
	if not can_be_combat_hooked() or owner == null or _combat_hooked:
		return false
	_combat_hook_previous_state = state
	_combat_hook_previous_player = player
	_combat_hook_previous_velocity = velocity
	_combat_hook_previous_facing = facing_right
	_combat_hooked = true
	_combat_hook_owner = owner
	_combat_hook_pull_velocity = Vector2.ZERO
	_combat_hook_reel_active = false
	state = State.AGGRO
	player = owner
	_special_windup_remaining = 0.0
	_melee_windup_remaining = 0.0
	if _attack_hitbox:
		_attack_hitbox.set_deferred("monitoring", false)
	_hit_flash_timer = maxf(_hit_flash_timer, 0.16)
	if sprite_node:
		sprite_node.modulate = Color(0.62, 1.08, 1.02, 1.0)
	PARTICLE_BURST.spawn(
		get_tree().current_scene,
		global_position + Vector2(0.0, -14.0),
		Color(0.44, 0.92, 0.84, 0.78),
		7, Vector2.UP, 18.0, 58.0, 0.42
	)
	_play_clip("hurt", true)
	queue_redraw()
	return true


func apply_combat_hook_pull(target: Vector2, pull_speed: float) -> bool:
	if not _combat_hooked or state == State.DEAD:
		return false
	if combat_hook_heavy:
		_combat_hook_pull_velocity = Vector2.ZERO
		return false
	var to_target := target - global_position
	if to_target.length_squared() < 1.0:
		_combat_hook_pull_velocity = Vector2.ZERO
		return true
	var direction := to_target.normalized()
	# Una componente verticale controllata crea un arco leggibile senza far
	# attraversare soffitti o piattaforme sottili.
	direction.y = minf(direction.y, -0.18)
	_combat_hook_pull_velocity = direction.normalized() * pull_speed
	_combat_hook_reel_active = pull_speed > 0.0
	return true


func set_combat_hook_reeling(active: bool) -> void:
	_combat_hook_reel_active = active
	if not active:
		_combat_hook_pull_velocity = Vector2.ZERO


func _update_combat_hook_escape(delta: float) -> void:
	if _combat_hook_owner == null or not is_instance_valid(_combat_hook_owner):
		release_combat_hook()
		return
	var away := global_position - _combat_hook_owner.global_position
	var escape_sign := signf(away.x)
	if is_zero_approx(escape_sign):
		escape_sign = 1.0 if facing_right else -1.0
	var escape_ratio := combat_hook_heavy_escape_ratio if combat_hook_heavy else combat_hook_escape_ratio
	var escape_x := escape_sign * move_speed * escape_ratio
	var target_x := escape_x
	if _combat_hook_reel_active and not combat_hook_heavy:
		# The enemy still pushes against the reel; the player's pull wins only
		# when its force exceeds this escape intent.
		target_x += _combat_hook_pull_velocity.x
	velocity.x = move_toward(velocity.x, target_x, move_acceleration * 1.45 * delta)
	if hovering:
		var hover_target := _home_position.y + sin(Time.get_ticks_msec() * 0.0032) * 7.0
		var target_y := clampf((hover_target - global_position.y) * 3.2, -45.0, 45.0)
		if _combat_hook_reel_active and not combat_hook_heavy:
			# I volanti devono seguire davvero la lenza, non solo oscillare:
			# la componente del reel prevale sul semplice hover.
			target_y = clampf(target_y + _combat_hook_pull_velocity.y * 1.35, -260.0, 260.0)
		velocity.y = move_toward(velocity.y, target_y, move_acceleration * 1.2 * delta)
	else:
		if _combat_hook_reel_active and not combat_hook_heavy and _combat_hook_pull_velocity.y < -1.0:
			# Anche un nemico leggero a terra può essere schiodato: il reel
			# applica una trazione verticale, poi la gravità lo fa ricadere.
			velocity.y = move_toward(
				velocity.y,
				_combat_hook_pull_velocity.y * 1.15,
				move_acceleration * 1.25 * delta
			)
		else:
			velocity.y += gravity * 0.72 * delta
	facing_right = velocity.x >= 0.0
	if sprite_node:
		sprite_node.flip_h = not facing_right
	_sync_locomotion_clip()


func release_combat_hook(launch_direction := Vector2.ZERO, powered := false) -> void:
	if not _combat_hooked:
		return
	_combat_hooked = false
	_combat_hook_owner = null
	_combat_hook_pull_velocity = Vector2.ZERO
	_combat_hook_reel_active = false
	if state == State.DEAD:
		return
	# Un rilascio manuale chiude il duello e restituisce il nemico al suo
	# pattugliamento, invece di lasciare l'AGGRO congelato dal trascinamento.
	state = State.IDLE
	player = null
	_wake_timer = maxf(_wake_timer, 0.75)
	# Riparti dal ciclo AI normale: il trascinamento può aver lasciato windup,
	# strafe o salto a metà. Non cambiamo lo stato precedente, ma eliminiamo
	# solo i residui temporanei dell'aggancio.
	jump_timer = 0.0
	attack_timer = 0.0
	_strafe_timer = 0.0
	_melee_windup_remaining = 0.0
	_special_windup_remaining = 0.0
	_charge_timer = 0.0
	if state == State.IDLE:
		play_idle()
	facing_right = _combat_hook_previous_facing
	if powered and not combat_hook_heavy and launch_direction.length_squared() > 0.01:
		var direction := launch_direction.normalized()
		direction.y = minf(direction.y, -0.28)
		velocity = direction.normalized() * combat_hook_power_launch_speed
		_knockback_timer = 0.42
	elif _stagger_timer > 0.0:
		velocity = Vector2.ZERO
	elif state == State.IDLE:
		# Non trascinare nel patrol la velocità di fuga accumulata durante il
		# gancio: al rilascio il gamberetto riparte dalla sua attività normale.
		velocity = Vector2.ZERO
	else:
		velocity = _combat_hook_previous_velocity
	if sprite_node:
		sprite_node.flip_h = not facing_right
	_sync_locomotion_clip()


func is_combat_hooked() -> bool:
	return _combat_hooked


## Sbilanciamento dopo essere stato trascinato sotto la canna: il nemico resta
## scoperto e lo dichiara con la posa, cosi' il colpo forte diventa leggibile.
func stagger(duration: float) -> void:
	if state == State.DEAD:
		return
	_stagger_timer = maxf(_stagger_timer, duration)
	_melee_windup_remaining = 0.0
	_special_windup_remaining = 0.0
	velocity.x *= 0.2
	if _attack_hitbox:
		_attack_hitbox.set_deferred("monitoring", false)
	_play_clip("hurt", true)


func is_staggered() -> bool:
	return _stagger_timer > 0.0

## Raggio entro cui un nemico colpito "allerta" gli altri (solo questi vanno in aggro)
const ALERT_NEARBY_RADIUS: float = 220.0

func _alert_nearby_enemies() -> void:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if p == null or _is_player_sanctuary_safe(p):
		return
	var my_pos: Vector2 = global_position
	for n in get_tree().get_nodes_in_group("enemy"):
		if n == self:
			continue
		if not is_instance_valid(n):
			continue
		if "state" in n and int(n.get("state")) == State.DEAD:
			continue
		var other_node = n as Node2D
		if other_node and my_pos.distance_to(other_node.global_position) > ALERT_NEARBY_RADIUS:
			continue
		# Non svegliare nemici che "guardano" un altare se il player è in sanctuary.
		if other_node and other_node.has_method("_is_player_sanctuary_safe") and other_node.call("_is_player_sanctuary_safe", p):
			continue
		if "state" in n:
			n.set("state", State.AGGRO)
		if "player" in n:
			n.set("player", p)
		if "jump_timer" in n:
			n.set("jump_timer", 0.0)


func _draw_hurtbox_silhouette() -> void:
	# Solo in combattimento / colpo: niente overlay debug in idle.
	var combat_visible := (
		state == State.AGGRO
		or _hit_flash_timer > 0.0
		or _melee_windup_remaining > 0.0
		or _special_windup_remaining > 0.0
		or (_attack_hitbox != null and _attack_hitbox.monitoring)
	)
	if not combat_visible:
		return
	var scale_safe := maxf(absf(scale.x), 0.001)
	var half := Vector2(22.0, 28.0 if hovering else 22.0) / scale_safe
	var center := Vector2(0.0, (-18.0 if hovering else -10.0) / scale_safe)
	var fill := Color(0.95, 0.28, 0.22, 0.12)
	var edge := Color(1.0, 0.45, 0.32, 0.55)
	if _hit_flash_timer > 0.0:
		fill = Color(1.0, 1.0, 1.0, 0.22)
		edge = Color(0.96, 0.98, 1.0, 0.85)
	draw_rect(Rect2(center - half, half * 2.0), fill, true)
	draw_rect(Rect2(center - half, half * 2.0), edge, false, 1.6 / scale_safe)
	draw_circle(center, 2.6 / scale_safe, Color(edge.r, edge.g, edge.b, edge.a * 0.75))
	if _attack_hitbox and _attack_hitbox.monitoring:
		var atk_center := Vector2((28.0 if facing_right else -28.0) / scale_safe, -8.0 / scale_safe)
		var atk_half := Vector2(16.0, 14.0) / scale_safe
		draw_rect(
			Rect2(atk_center - atk_half, atk_half * 2.0),
			Color(1.0, 0.55, 0.2, 0.35),
			false,
			2.0 / scale_safe
		)

func _spawn_hit_particles(source_position: Vector2) -> void:
	var scene: PackedScene = hit_particle_scene
	if scene == null:
		scene = load("res://Fx/black_particle.tscn") as PackedScene
	if scene == null:
		return
	var container: Node = get_parent() if get_parent() else get_tree().current_scene
	var p: Node2D = scene.instantiate() as Node2D
	container.add_child(p)
	p.global_position = global_position
	var dir: Vector2 = Vector2.RIGHT
	if source_position != Vector2.ZERO:
		dir = (global_position - source_position).normalized()
	if p.has_method("set_direction"):
		p.call("set_direction", dir)
	if p.has_method("set_color"):
		p.call("set_color", Color(0.94, 0.96, 1.0, 0.92))
	if p.has_method("set_amount"):
		p.call("set_amount", 8)
	if p.has_method("play"):
		p.call("play")

func _die(launch_velocity: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_play_clip("death", true)
	_combat_hooked = false
	_combat_hook_owner = null
	if _hurtbox:
		_hurtbox.monitoring = false
		_hurtbox.set_deferred("monitoring", false)
	if _attack_hitbox:
		_attack_hitbox.monitoring = false
		_attack_hitbox.set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask = 0
	# Crea un RigidBody2D "Dead Gamberetto" spostabile (attacco e hook possono spingerlo)
	# Aggiungilo in deferred per evitare "Can't change this state while flushing queries"
	var parent_node: Node = get_parent()
	var pos_global: Vector2 = global_position
	const DEAD_GAMBERETTO_PATH := "res://Landscape/Sprites/dead gamberetto.png"
	var tex: Texture2D = variant_texture if variant_texture else load(DEAD_GAMBERETTO_PATH) as Texture2D
	# Mantieni la stessa taglia del vivo (niente clamp che gonfia/restringe il cadavere).
	var live_scale_x := absf(scale.x) * (absf(_original_sprite_scale.x) if _original_sprite_scale.x != 0.0 else 1.0)
	var live_scale_y := absf(scale.y) * (absf(_original_sprite_scale.y) if _original_sprite_scale.y != 0.0 else 1.0)
	var dead_scale := Vector2(maxf(live_scale_x, 0.04), maxf(live_scale_y, 0.04))

	var rb: RigidBody2D = RigidBody2D.new()
	rb.name = "Dead Gamberetto"
	rb.collision_layer = 2
	rb.collision_mask = 1
	rb.gravity_scale = 1.0
	rb.mass = 1.0
	rb.linear_damp = 2.0
	rb.angular_damp = 3.0
	rb.add_to_group("dead_enemy")

	var col_shape: RectangleShape2D = RectangleShape2D.new()
	col_shape.size = Vector2(body_world_size.x * 0.85, body_world_size.y * 0.55)
	var col_node: CollisionShape2D = CollisionShape2D.new()
	col_node.shape = col_shape
	rb.add_child(col_node)

	if tex != null:
		var spr: Sprite2D = Sprite2D.new()
		spr.texture = tex
		spr.scale = dead_scale
		rb.add_child(spr)

	rb.z_index = 5
	# Posizione in coordinate locali del parent, così quando viene aggiunto è già al posto giusto
	rb.position = parent_node.to_local(pos_global)
	parent_node.call_deferred("add_child", rb)
	if launch_velocity.length_squared() > 1.0:
		rb.tree_entered.connect(
			func() -> void:
				if is_instance_valid(rb):
					rb.apply_central_impulse(launch_velocity * rb.mass)
					rb.apply_torque_impulse(signf(launch_velocity.x) * 90.0),
			CONNECT_ONE_SHOT
		)
	var cleanup_timer := Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = 12.0
	cleanup_timer.autostart = true
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(rb):
			rb.queue_free()
	)
	rb.add_child(cleanup_timer)
	visible = false
	set_physics_process(false)
	# Rimane dormiente dove e stato sconfitto. Solo dogana_level, quando il
	# giocatore usa una grazia, puo richiamare reset_to_home().


func reset_to_home() -> void:
	global_position = _home_position
	velocity = Vector2.ZERO
	state = State.IDLE
	player = null
	_combat_hooked = false
	_combat_hook_owner = null
	_combat_hook_pull_velocity = Vector2.ZERO
	_combat_hook_reel_active = false
	_combat_hook_previous_state = State.IDLE
	_combat_hook_previous_player = null
	_combat_hook_previous_velocity = Vector2.ZERO
	current_health = max_health
	_wake_timer = post_respawn_wake_delay
	_special_timer = special_attack_cooldown * 0.65
	_special_windup_remaining = 0.0
	_leap_slam_armed = false
	_leap_slam_timer = 0.0
	_charge_timer = 0.0
	_knockback_timer = 0.0
	_hitstop_timer = 0.0
	_hit_flash_timer = 0.0
	_attack_has_hit = false
	_combat_hooked = false
	_combat_hook_owner = null
	_combat_hook_pull_velocity = Vector2.ZERO
	collision_layer = 2
	collision_mask = 1
	visible = not activation_managed
	if sprite_node:
		sprite_node.modulate = _original_modulate
		sprite_node.scale = _original_sprite_scale
		sprite_node.position = _base_sprite_position
		sprite_node.rotation = 0.0
	if _hurtbox:
		_hurtbox.set_deferred("monitoring", true)
	if _attack_hitbox:
		_attack_hitbox.set_deferred("monitoring", false)
	if _anim:
		_anim.active = not _using_frames and variant_texture == null
		play_idle()
	set_physics_process(not activation_managed)
	PARTICLE_BURST.spawn(
		get_tree().current_scene,
		global_position,
		Color(0.3, 0.9, 0.76, 0.68),
		12,
		Vector2.UP,
		30.0,
		90.0,
		0.65
	)
	queue_redraw()


func _disengage() -> void:
	state = State.IDLE
	player = null
	_wake_timer = post_respawn_wake_delay
	_special_windup_remaining = 0.0
	_special_timer = special_attack_cooldown * 0.65
	if _attack_hitbox:
		_attack_hitbox.set_deferred("monitoring", false)
	_attack_hitbox_disable_timer = 0.0
	_attack_has_hit = false
	play_idle()

func _on_attack_hit_body(body: Node2D) -> void:
	if state == State.DEAD or _attack_has_hit or body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("player"):
		return
	_attack_has_hit = true
	var dealt := maxi(1, _pending_melee_damage)
	# Deferred evita mutazioni del player/death sequence durante il flush della query fisica.
	if body.has_method("take_damage"):
		body.call_deferred("take_damage", dealt, global_position)
	elif "current_health" in body:
		body.set_deferred("current_health", maxi(0, int(body.get("current_health")) - dealt))
	_shake_camera(0.22 if dealt >= 2 else 0.12)
	_pending_melee_damage = attack_damage
