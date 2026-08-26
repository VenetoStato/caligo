extends CharacterBody2D

signal boss_awakened
signal boss_defeated

const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")
const AREA_ATTACK_SCRIPT := preload("res://Enemies/enemy_area_attack.gd")
const PROJECTILE_SCRIPT := preload("res://Enemies/enemy_projectile.gd")
const TELEGRAPH_SCRIPT := preload("res://Levels/Scenes/Dogana/boss_telegraph.gd")
const FOOTSTEP_DUST := preload("res://Fx/footstep_dust.gd")
const FLOOD_SURGE_SCRIPT := preload("res://Levels/Scenes/Dogana/boss_flood_surge.gd")

const MAX_BOSS_TRANSIENTS := 72
const BASE_SPRITE_POSITION := Vector2(0.0, -96.0)
const BASE_SPRITE_SCALE := Vector2(0.161, 0.161)
const BASE_BODY_SHAPE_POSITION := Vector2(0.0, -31.0)
const BASE_HURTBOX_POSITION := Vector2(0.0, -49.0)
const BASE_ATTACK_HITBOX_POSITION := Vector2(0.0, -42.0)
const BASE_CONTACT_POSITION := Vector2(0.0, -34.0)

@export var max_health := 28
@export var move_speed := 78.0
@export var lunge_speed := 330.0
@export var aggro_range := 520.0
@export var attack_range := 220.0
@export var attack_cooldown := 1.35
@export var attack_damage := 1
@export var heavy_attack_damage := 2
@export var contact_damage := 1
@export var contact_damage_cooldown := 0.72
@export var gravity := 620.0
@export var variant_texture: Texture2D
@export var art_kit: EnemyArtKit

enum State { DORMANT, CHASE, WINDUP, LUNGE, SLAM, WAVE, SWEEP, SPIRAL, RING, STREAM, CROSS, RECOVER, DEAD, FAN, PILLARS, FLOOD }
enum AttackKind { LUNGE, SLAM, WAVE, SWEEP, SPIRAL, RING, STREAM, CROSS, FAN, PILLARS, FLOOD }

const ARENA_LEFT := 4640.0
const ARENA_RIGHT := 5700.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _attack_hitbox: Area2D = $AttackHitbox
@onready var _contact_damage_area: Area2D = $ContactDamage

var state := State.DORMANT
var current_health := 28
var player: Node2D
var _state_timer := 0.0
var _attack_timer := 0.0
var _invulnerability_timer := 0.0
var _attack_has_hit := false
var _contact_damage_timer := 0.0
var _windup_duration := 0.72
var _base_scale := Vector2.ONE
var _wound_overlay: Sprite2D
var _wound_light: PointLight2D
var _wound_pulse := 0.0
var _pending_kind := AttackKind.LUNGE
var _pending_damage := 1
var _wave_shots_left := 0
var _wave_shot_timer := 0.0
var _slam_armed := false
var _slam_air_timer := 0.0
var _telegraph: Node2D
var _pattern_phase := 0.0
var _stream_shots_left := 0
var _stream_timer := 0.0
var _ring_bursts_left := 0
var _ring_timer := 0.0
var _spiral_shots_left := 0
var _spiral_timer := 0.0
var _cross_waves_left := 0
var _cross_timer := 0.0
var _fan_waves_left := 0
var _fan_timer := 0.0
var _pillar_waves_left := 0
var _pillar_timer := 0.0
var _last_attack_kind := -1
var _attack_chain_step := 0
var _phase := 1
var _phase_transitioning := false
var _home_position := Vector2.ZERO
var _base_sprite_position := Vector2.ZERO
var _anim_state := "dormant"
var _anim_phase := 0.0
var _step_phase := 0.0
var _hurt_anim := 0.0
var _art_kit: EnemyArtKit
var _animated: AnimatedSprite2D
var _using_frames := false


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("dogana_boss")
	# La scena principale conservava un override locale a (0, 0) sul figlio
	# Sprite2D dell'istanza: il Custode risultava enorme dentro il pavimento anche
	# se la sottoscena era corretta. L'allineamento runtime e' qui autoritativo.
	_sprite.position = BASE_SPRITE_POSITION
	_sprite.scale = BASE_SPRITE_SCALE
	var body_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape:
		body_shape.position = BASE_BODY_SHAPE_POSITION
	_hurtbox.position = BASE_HURTBOX_POSITION
	_attack_hitbox.position = BASE_ATTACK_HITBOX_POSITION
	_contact_damage_area.position = BASE_CONTACT_POSITION
	current_health = max_health
	_base_scale = _sprite.scale
	_base_sprite_position = _sprite.position
	_home_position = global_position
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_attack_hitbox.body_entered.connect(_on_attack_hit_body)
	_contact_damage_area.body_entered.connect(_on_contact_body_entered)
	_attack_hitbox.monitoring = false
	_attack_hitbox.monitorable = false
	_attack_hitbox.collision_mask = 2
	_build_health_ui()
	_build_telegraph()
	if _art_kit:
		apply_art_kit(_art_kit)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_invulnerability_timer = maxf(0.0, _invulnerability_timer - delta)
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_contact_damage_timer = maxf(0.0, _contact_damage_timer - delta)
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity.y += gravity * delta

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	var face_right := to_player.x > 0.0
	_sprite.flip_h = face_right
	if _animated:
		_animated.flip_h = face_right
	_update_telegraph(to_player)
	_update_contact_damage()

	match state:
		State.DORMANT:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			# Il boss vive nell'interno della Salute, sopra la mappa esterna: usare
			# solo X lo svegliava attraverso il soffitto mentre eri sul sagrato.
			if to_player.length() <= aggro_range:
				_awaken()
		State.CHASE:
			var chase_speed := move_speed * (1.22 if _is_enraged() else 1.0)
			# Il Custode non si incolla al player: mantiene una fascia di duello e
			# lascia spazio leggibile per dash, salto e contrattacco.
			var desired_distance := 150.0 if _phase == 1 else 185.0
			if absf(to_player.x) > desired_distance + 28.0:
				velocity.x = signf(to_player.x) * chase_speed
			elif absf(to_player.x) < desired_distance - 42.0:
				velocity.x = -signf(to_player.x) * chase_speed * 0.62
			else:
				velocity.x = move_toward(velocity.x, 0.0, 850.0 * delta)
			if _attack_timer <= 0.0 and absf(to_player.x) <= attack_range:
				_begin_windup(to_player)
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if _state_timer <= 0.0:
				_commit_attack(to_player)
		State.LUNGE:
			if _state_timer <= 0.0:
				_begin_recovery(0.72)
		State.SLAM:
			_slam_air_timer = maxf(0.0, _slam_air_timer - delta)
			if _slam_armed and _slam_air_timer <= 0.0 and (is_on_floor() or _state_timer <= 0.0):
				_slam_impact()
		State.WAVE:
			_update_wave(delta, to_player)
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _wave_shots_left <= 0 and _state_timer <= 0.0:
				_begin_recovery(0.7)
		State.SPIRAL:
			_update_spiral(delta)
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _spiral_shots_left <= 0 and _state_timer <= 0.0:
				_begin_recovery(0.65)
		State.RING:
			_update_ring(delta)
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _ring_bursts_left <= 0 and _state_timer <= 0.0:
				_begin_recovery(0.7)
		State.STREAM:
			_update_stream(delta, to_player)
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			if _stream_shots_left <= 0 and _state_timer <= 0.0:
				_begin_recovery(0.55)
		State.CROSS:
			_update_cross(delta)
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _cross_waves_left <= 0 and _state_timer <= 0.0:
				_begin_recovery(0.68)
		State.FAN:
			_update_fan(delta, to_player)
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			if _fan_waves_left <= 0 and _state_timer <= 0.0:
				_begin_recovery(0.62)
		State.PILLARS:
			_update_pillars(delta)
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _pillar_waves_left <= 0 and _state_timer <= 0.0:
				_begin_recovery(0.76)
		State.FLOOD:
			# Durante la marea il Custode resta piantato a invocarla: e' la
			# finestra in cui conviene appendersi e non pensare a colpirlo.
			velocity.x = move_toward(velocity.x, 0.0, 950.0 * delta)
			if _state_timer <= 0.0:
				_begin_recovery(0.8)
		State.SWEEP:
			if _state_timer <= 0.0:
				_begin_recovery(0.95)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 760.0 * delta)
			if _state_timer <= 0.0:
				_phase_transitioning = false
				state = State.CHASE

	_animate(delta)
	_update_wound_signal(delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, ARENA_LEFT, ARENA_RIGHT)


func _is_enraged() -> bool:
	return current_health <= max_health / 2


func _is_desperate() -> bool:
	return current_health <= maxi(1, max_health / 3)


func apply_art_kit(kit: EnemyArtKit) -> void:
	if kit == null:
		return
	_art_kit = kit
	if _sprite == null:
		_sprite = get_node_or_null("Sprite2D") as Sprite2D
	var still := kit.resolved_still()
	if still:
		variant_texture = still
		if _sprite:
			_sprite.texture = still
	var sprite_frames := kit.resolved_frames()
	_using_frames = sprite_frames != null
	if not _using_frames:
		return
	_animated = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _animated == null:
		_animated = AnimatedSprite2D.new()
		_animated.name = "AnimatedSprite2D"
		add_child(_animated)
	_animated.sprite_frames = sprite_frames
	_animated.position = _sprite.position
	_animated.scale = _sprite.scale
	_animated.z_index = _sprite.z_index
	_animated.visible = true
	_sprite.visible = false


func _play_kit_clip(anim_state: String) -> void:
	if not _using_frames or _animated == null or _animated.sprite_frames == null:
		return
	var clip := "idle"
	match anim_state:
		"chase":
			clip = "walk"
		"windup":
			clip = "windup"
		"attack":
			clip = "attack"
		"hurt":
			clip = "hurt"
		"dead":
			clip = "death"
		"recover":
			clip = "idle"
		_:
			clip = "idle"
	if _animated.sprite_frames.has_animation(clip) and _animated.animation != clip:
		_animated.play(clip)


func apply_variant_art(texture: Texture2D) -> void:
	if texture == null:
		return
	if _art_kit == null:
		_art_kit = EnemyArtKit.new()
	_art_kit.still = texture
	apply_art_kit(_art_kit)


func get_animation_state() -> String:
	return _anim_state


## Il Custode e' un unico sprite dipinto: le animazioni sono pose procedurali
## per stato (respiro, passo, carica, affondo, colpo subito), cosi' ogni fase
## dello scontro resta leggibile senza uno spritesheet.
func _animate(delta: float) -> void:
	_hurt_anim = maxf(0.0, _hurt_anim - delta * 4.5)
	var next_state := _animation_state_for(state)
	if next_state != _anim_state:
		_anim_state = next_state
		_anim_phase = 0.0
		_play_kit_clip(_anim_state)
	_anim_phase += delta
	if _using_frames:
		return

	var facing := 1.0 if _sprite.flip_h else -1.0
	var offset := Vector2.ZERO
	var squash := Vector2.ONE
	var lean := 0.0

	match _anim_state:
		"dormant":
			var breath := sin(_anim_phase * 1.35)
			squash = Vector2(1.0 - breath * 0.014, 1.0 + breath * 0.022)
			offset.y = breath * 3.0
			lean = sin(_anim_phase * 0.6) * 0.012
		"chase":
			_advance_step_cycle(delta)
			var cycle := _step_phase * TAU
			offset = Vector2(sin(cycle) * 4.0, -absf(sin(cycle)) * 7.0)
			squash = Vector2(1.0 + absf(sin(cycle)) * 0.02, 1.0 - absf(sin(cycle)) * 0.03)
			lean = 0.05 + sin(cycle * 0.5) * 0.02
		"windup":
			var coil := clampf(_anim_phase * 3.2, 0.0, 1.0)
			squash = Vector2(1.0 + coil * 0.09, 1.0 - coil * 0.11 + sin(_anim_phase * 46.0) * 0.02 * coil)
			offset.y = coil * 12.0
			lean = -coil * 0.1
		"attack":
			var pose := _attack_pose()
			offset = pose[0]
			squash = pose[1]
			lean = pose[2]
		"recover":
			var settle := clampf(_anim_phase * 2.4, 0.0, 1.0)
			squash = Vector2.ONE.lerp(Vector2(0.97, 1.04), 1.0 - settle)
			offset.y = (1.0 - settle) * 6.0
			lean = (1.0 - settle) * -0.08

	if _hurt_anim > 0.0:
		offset.x -= _hurt_anim * 6.0
		offset.y -= _hurt_anim * 16.0
		lean += _hurt_anim * 0.08
		squash *= Vector2(1.0 + _hurt_anim * 0.04, 1.0 - _hurt_anim * 0.07)

	var blend := clampf(delta * 20.0, 0.0, 1.0)
	_sprite.position = _base_sprite_position + Vector2(offset.x * facing, offset.y)
	_sprite.scale = _sprite.scale.lerp(_base_scale * squash, blend)
	_sprite.rotation = lerpf(_sprite.rotation, lean * facing, blend)


func _attack_pose() -> Array:
	match state:
		State.LUNGE:
			return [Vector2(14.0, -4.0), Vector2(1.12, 0.9), 0.26]
		State.SWEEP:
			var swing := sin(clampf(_anim_phase / 0.42, 0.0, 1.0) * PI)
			return [Vector2(swing * 18.0, 0.0), Vector2(1.0 + swing * 0.1, 1.0 - swing * 0.08), swing * 0.34]
		State.SLAM:
			var airborne := clampf(_anim_phase * 2.6, 0.0, 1.0)
			return [Vector2(0.0, -airborne * 10.0), Vector2(1.0 - airborne * 0.08, 1.0 + airborne * 0.12), -0.18 * (1.0 - airborne)]
		State.PILLARS:
			# Braccia al cielo mentre chiama le colonne di marea.
			return [Vector2(0.0, -10.0 + sin(_anim_phase * 26.0) * 2.5), Vector2(0.9, 1.16), 0.0]
		State.FLOOD:
			# Affondato sulle ginocchia mentre richiama l'acqua alta.
			var call_pose := sin(_anim_phase * 9.0)
			return [Vector2(0.0, 6.0 + call_pose * 2.0), Vector2(1.14, 0.86 + call_pose * 0.03), 0.0]
		_:
			# Pattern a proiettili: torace aperto e respiro rapido.
			var cast := sin(_anim_phase * 14.0)
			return [Vector2(-6.0, -4.0 + cast * 2.0), Vector2(0.94 + cast * 0.03, 1.08 - cast * 0.03), -0.06]


func _animation_state_for(current: int) -> String:
	match current:
		State.DORMANT:
			return "dormant"
		State.CHASE:
			return "chase"
		State.WINDUP:
			return "windup"
		State.RECOVER:
			return "recover"
		State.DEAD:
			return "dead"
	return "attack"


func _advance_step_cycle(delta: float) -> void:
	var pace := clampf(absf(velocity.x) / maxf(move_speed, 1.0), 0.0, 1.6)
	if pace < 0.12:
		return
	var previous := _step_phase
	_step_phase = fposmod(_step_phase + delta * (1.3 + pace * 1.4), 1.0)
	if _step_phase < previous or (previous < 0.5 and _step_phase >= 0.5):
		_spawn_step_dust()


func _spawn_step_dust() -> void:
	if not is_on_floor():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	FOOTSTEP_DUST.spawn(scene, global_position + Vector2(0, -6), signf(velocity.x), OS.has_feature("mobile"))


## Morire nell'arena deve poter far ricominciare lo scontro da capo.
func reset_encounter() -> void:
	if state == State.DEAD:
		return
	for attack in get_tree().get_nodes_in_group("enemy_transient_attack"):
		if is_instance_valid(attack):
			attack.queue_free()
	state = State.DORMANT
	current_health = max_health
	_phase = 1
	_phase_transitioning = false
	_last_attack_kind = -1
	_attack_chain_step = 0
	_invulnerability_timer = 0.0
	_attack_timer = 0.0
	_contact_damage_timer = 0.0
	_state_timer = 0.0
	_hurt_anim = 0.0
	_anim_state = "dormant"
	_anim_phase = 0.0
	velocity = Vector2.ZERO
	global_position = _home_position
	_disable_melee_hitbox()
	_sprite.modulate = Color.WHITE
	_sprite.position = _base_sprite_position
	_sprite.scale = _base_scale
	_sprite.rotation = 0.0
	_wound_pulse = 0.0
	if _wound_overlay:
		_wound_overlay.modulate.a = 0.0
	if _wound_light:
		_wound_light.energy = 0.0


func _awaken() -> void:
	state = State.CHASE
	_attack_timer = 1.1
	boss_awakened.emit()
	_spawn_phase_ring(Color(0.42, 0.96, 0.82, 0.9), 105.0)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(0.55, 1.15, 1.05, 1.0), 0.16)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.36)


func _begin_windup(to_player: Vector2) -> void:
	_pending_kind = _pick_attack(to_player)
	state = State.WINDUP
	_attack_has_hit = false
	match _pending_kind:
		AttackKind.LUNGE:
			_state_timer = 0.48
			_pending_damage = attack_damage
			_sprite.modulate = Color(0.62, 1.05, 0.92, 1.0)
		AttackKind.SLAM:
			_state_timer = 0.72
			_pending_damage = heavy_attack_damage
			_sprite.modulate = Color(1.15, 0.55, 0.4, 1.0)
		AttackKind.WAVE:
			_state_timer = 0.58
			_pending_damage = attack_damage
			_sprite.modulate = Color(0.45, 0.9, 1.15, 1.0)
		AttackKind.SWEEP:
			_state_timer = 0.66
			_pending_damage = heavy_attack_damage
			_sprite.modulate = Color(0.95, 0.75, 0.35, 1.0)
		AttackKind.SPIRAL:
			_state_timer = 0.7
			_pending_damage = attack_damage
			_sprite.modulate = Color(0.55, 0.75, 1.2, 1.0)
		AttackKind.RING:
			_state_timer = 0.62
			_pending_damage = attack_damage
			_sprite.modulate = Color(0.35, 1.05, 0.9, 1.0)
		AttackKind.STREAM:
			_state_timer = 0.52
			_pending_damage = attack_damage
			_sprite.modulate = Color(0.4, 1.1, 0.95, 1.0)
		AttackKind.CROSS:
			_state_timer = 0.68
			_pending_damage = heavy_attack_damage
			_sprite.modulate = Color(1.05, 0.72, 0.35, 1.0)
		AttackKind.FAN:
			_state_timer = 0.58
			_pending_damage = attack_damage
			_sprite.modulate = Color(0.48, 0.92, 1.18, 1.0)
		AttackKind.PILLARS:
			_state_timer = 0.78
			_pending_damage = heavy_attack_damage
			_sprite.modulate = Color(0.88, 0.42, 1.12, 1.0)
		AttackKind.FLOOD:
			_state_timer = 0.9
			_pending_damage = heavy_attack_damage
			_sprite.modulate = Color(0.3, 0.66, 1.15, 1.0)
	_windup_duration = _state_timer


func _pick_attack(to_player: Vector2) -> AttackKind:
	var dist := absf(to_player.x)
	var options: Array[AttackKind] = []
	_attack_chain_step += 1
	# Mega-attacco raro: non ogni combo, ma quando arriva dura diversi secondi.
	if _attack_chain_step >= 8:
		_attack_chain_step = 0
		_last_attack_kind = int(AttackKind.FLOOD)
		return AttackKind.FLOOD
	# Pool per fase: pochi pattern coerenti e imparabili. Le varianti dense
	# entrano solo dopo che il player ha letto il moveset base.
	if dist <= 120.0:
		options.append(AttackKind.SWEEP)
		options.append(AttackKind.LUNGE)
		options.append(AttackKind.SLAM)
	elif dist <= 240.0:
		options.append(AttackKind.LUNGE)
		options.append(AttackKind.SLAM)
		options.append(AttackKind.WAVE)
	else:
		options.append(AttackKind.WAVE)
		options.append(AttackKind.FAN)
	if _is_enraged():
		options.append(AttackKind.STREAM)
		options.append(AttackKind.RING)
		options.append(AttackKind.PILLARS)
	if _is_desperate():
		options.append(AttackKind.SPIRAL)
		options.append(AttackKind.CROSS)
	var filtered: Array[AttackKind] = []
	for kind in options:
		if int(kind) != _last_attack_kind:
			filtered.append(kind)
	if filtered.is_empty():
		filtered = options
	var chosen := filtered[randi() % filtered.size()]
	_last_attack_kind = int(chosen)
	return chosen


func _commit_attack(to_player: Vector2) -> void:
	_sprite.modulate = Color.WHITE
	_spawn_attack_release_fx(to_player)
	match _pending_kind:
		AttackKind.LUNGE:
			_begin_lunge(to_player)
		AttackKind.SLAM:
			_begin_slam(to_player)
		AttackKind.WAVE:
			_begin_wave(to_player)
		AttackKind.SWEEP:
			_begin_sweep(to_player)
		AttackKind.SPIRAL:
			_begin_spiral()
		AttackKind.RING:
			_begin_ring()
		AttackKind.STREAM:
			_begin_stream(to_player)
		AttackKind.CROSS:
			_begin_cross()
		AttackKind.FAN:
			_begin_fan(to_player)
		AttackKind.PILLARS:
			_begin_pillars()
		AttackKind.FLOOD:
			_begin_flood()


func _begin_lunge(to_player: Vector2) -> void:
	state = State.LUNGE
	_state_timer = 0.36
	velocity.x = signf(to_player.x) * lunge_speed * (1.15 if _is_enraged() else 1.0)
	velocity.y = -70.0
	_enable_melee_hitbox(1.0)


func _begin_slam(to_player: Vector2) -> void:
	state = State.SLAM
	_state_timer = 0.85
	_slam_armed = true
	# Piccolo delay per non considerare "atterrato" il frame del salto.
	_slam_air_timer = 0.12
	velocity.x = signf(to_player.x) * 90.0
	velocity.y = -320.0
	_disable_melee_hitbox()
	_shake_camera(0.18)


func _slam_impact() -> void:
	_slam_armed = false
	_state_timer = 0.05
	var radius := 118.0 if _is_enraged() else 96.0
	var area := AREA_ATTACK_SCRIPT.new() as Area2D
	area.call("setup", radius, heavy_attack_damage, Color(0.95, 0.48, 0.34, 1.0), 0.06)
	get_tree().current_scene.add_child(area)
	area.global_position = global_position + Vector2(0, 10)
	_shake_camera(0.55)
	PARTICLE_BURST.spawn(
		get_tree().current_scene,
		global_position + Vector2(0, 8),
		Color(0.28, 0.85, 0.72, 0.9),
		28,
		Vector2.UP,
		55.0,
		160.0,
		0.75
	)
	_begin_recovery(0.9)


func _begin_wave(to_player: Vector2) -> void:
	state = State.WAVE
	_wave_shots_left = 5 if _is_enraged() else 3
	_wave_shot_timer = 0.0
	_state_timer = 0.12 + float(_wave_shots_left) * 0.16
	velocity.x = 0.0
	_disable_melee_hitbox()
	_fire_wave_shot(to_player)
	_wave_shots_left -= 1


func _update_wave(delta: float, to_player: Vector2) -> void:
	if _wave_shots_left <= 0:
		return
	_wave_shot_timer -= delta
	if _wave_shot_timer > 0.0:
		return
	_wave_shot_timer = 0.16
	_fire_wave_shot(to_player)
	_wave_shots_left -= 1


func _fire_wave_shot(to_player: Vector2) -> void:
	var base_dir := to_player.normalized() if to_player.length_squared() > 0.01 else Vector2.RIGHT
	base_dir.y = clampf(base_dir.y, -0.35, 0.15)
	base_dir = base_dir.normalized()
	var offsets := [-0.22, 0.0, 0.22] if _is_enraged() else [-0.14, 0.14]
	for offset in offsets:
		var dmg := heavy_attack_damage if absf(offset) < 0.01 and _is_enraged() else attack_damage
		_spawn_boss_projectile(
			base_dir.rotated(offset),
			155.0 if _is_enraged() else 132.0,
			dmg,
			Color(0.35, 0.92, 0.86, 1.0),
			6.5,
			3.4
		)
	_shake_camera(0.12)


func _begin_spiral() -> void:
	state = State.SPIRAL
	_spiral_shots_left = 18 if _is_desperate() else (14 if _is_enraged() else 10)
	_spiral_timer = 0.0
	_pattern_phase = randf() * TAU
	_state_timer = 0.1 + float(_spiral_shots_left) * 0.07
	_disable_melee_hitbox()
	_fire_spiral_bead()
	_spiral_shots_left -= 1


func _update_spiral(delta: float) -> void:
	if _spiral_shots_left <= 0:
		return
	_spiral_timer -= delta
	if _spiral_timer > 0.0:
		return
	_spiral_timer = 0.065 if _is_enraged() else 0.08
	_fire_spiral_bead()
	_spiral_shots_left -= 1


func _fire_spiral_bead() -> void:
	_pattern_phase += 0.55 if _is_enraged() else 0.42
	var arms := 3 if _is_desperate() else 2
	for arm in arms:
		var ang := _pattern_phase + TAU * float(arm) / float(arms)
		var dir := Vector2.from_angle(ang)
		_spawn_boss_projectile(
			dir,
			118.0 if _is_enraged() else 100.0,
			attack_damage,
			Color(0.5, 0.72, 1.0, 1.0) if arm % 2 == 0 else Color(0.3, 0.95, 0.85, 1.0),
			5.2,
			3.6,
			1.4 if arm % 2 == 0 else -1.4,
			1
		)
	_shake_camera(0.08)


func _begin_ring() -> void:
	state = State.RING
	_ring_bursts_left = 4 if _is_desperate() else (3 if _is_enraged() else 2)
	_ring_timer = 0.0
	_state_timer = 0.15 + float(_ring_bursts_left) * 0.28
	_disable_melee_hitbox()
	_fire_ring_burst()
	_ring_bursts_left -= 1


func _update_ring(delta: float) -> void:
	if _ring_bursts_left <= 0:
		return
	_ring_timer -= delta
	if _ring_timer > 0.0:
		return
	_ring_timer = 0.26
	_fire_ring_burst()
	_ring_bursts_left -= 1


func _fire_ring_burst() -> void:
	var count := 16 if _is_desperate() else (14 if _is_enraged() else 12)
	var phase := _pattern_phase
	_pattern_phase += 0.18
	for index in count:
		var dir := Vector2.from_angle(phase + TAU * float(index) / float(count))
		var speed := 95.0 + float(index % 3) * 12.0
		_spawn_boss_projectile(
			dir,
			speed * (1.15 if _is_enraged() else 1.0),
			attack_damage,
			Color(0.3, 0.95, 0.82, 1.0),
			5.0,
			3.2,
			0.0,
			1 if index % 4 == 0 else 0
		)
	_shake_camera(0.16)


## Attacco ambientale: il Custode chiama l'acqua alta e allaga la navata da
## parete a parete. Il pavimento smette di essere un posto sicuro.
func _begin_flood() -> void:
	state = State.FLOOD
	_state_timer = 5.2
	_disable_melee_hitbox()
	var floor_y := global_position.y
	var surge := FLOOD_SURGE_SCRIPT.new() as Area2D
	var span := Vector2(ARENA_RIGHT - ARENA_LEFT + 260.0, 168.0)
	surge.call("setup", span, 2, 1.05, 4.15)
	get_tree().current_scene.add_child(surge)
	surge.global_position = Vector2(
		(ARENA_LEFT + ARENA_RIGHT) * 0.5, floor_y - span.y * 0.5 + 26.0
	)
	_shake_camera(0.22)


func _begin_stream(to_player: Vector2) -> void:
	state = State.STREAM
	_stream_shots_left = 16 if _is_desperate() else (12 if _is_enraged() else 8)
	_stream_timer = 0.0
	_state_timer = 0.08 + float(_stream_shots_left) * 0.07
	_disable_melee_hitbox()
	_fire_stream_shot(to_player)
	_stream_shots_left -= 1


func _update_stream(delta: float, to_player: Vector2) -> void:
	if _stream_shots_left <= 0:
		return
	_stream_timer -= delta
	if _stream_timer > 0.0:
		return
	_stream_timer = 0.055 if _is_desperate() else 0.07
	_fire_stream_shot(to_player)
	_stream_shots_left -= 1


func _fire_stream_shot(to_player: Vector2) -> void:
	var base_dir := to_player.normalized() if to_player.length_squared() > 0.01 else Vector2.RIGHT
	base_dir.y = clampf(base_dir.y, -0.45, 0.2)
	base_dir = base_dir.normalized()
	var wobble := sin(Time.get_ticks_msec() * 0.02) * 0.12
	_spawn_boss_projectile(
		base_dir.rotated(wobble),
		168.0 if _is_enraged() else 148.0,
		attack_damage,
		Color(0.4, 1.0, 0.9, 1.0),
		5.4,
		2.8
	)
	if _is_enraged() and _stream_shots_left % 3 == 0:
		_spawn_boss_projectile(
			base_dir.rotated(wobble + 0.22),
			150.0,
			attack_damage,
			Color(0.55, 0.9, 1.0, 1.0),
			4.8,
			2.6
		)
	_shake_camera(0.06)


func _begin_cross() -> void:
	state = State.CROSS
	_cross_waves_left = 4 if _is_desperate() else (3 if _is_enraged() else 2)
	_cross_timer = 0.0
	_pattern_phase = 0.0
	_state_timer = 0.12 + float(_cross_waves_left) * 0.3
	_disable_melee_hitbox()
	_fire_cross_wave()
	_cross_waves_left -= 1


func _update_cross(delta: float) -> void:
	if _cross_waves_left <= 0:
		return
	_cross_timer -= delta
	if _cross_timer > 0.0:
		return
	_cross_timer = 0.28
	_fire_cross_wave()
	_cross_waves_left -= 1


func _fire_cross_wave() -> void:
	_pattern_phase += PI * 0.25
	for arm in 4:
		var dir := Vector2.from_angle(_pattern_phase + float(arm) * PI * 0.5)
		for bead in 3:
			_spawn_boss_projectile(
				dir,
				110.0 + float(bead) * 18.0,
				heavy_attack_damage if bead == 1 else attack_damage,
				Color(0.95, 0.72, 0.35, 1.0) if bead == 1 else Color(0.9, 0.85, 0.45, 1.0),
				5.6 if bead == 1 else 4.8,
				3.0
			)
	_shake_camera(0.14)


func _begin_fan(to_player: Vector2) -> void:
	state = State.FAN
	_fan_waves_left = 4 if _is_desperate() else (3 if _is_enraged() else 2)
	_fan_timer = 0.0
	_state_timer = 0.14 + float(_fan_waves_left) * 0.24
	_pattern_phase = -0.08
	_disable_melee_hitbox()
	_fire_fan_wave(to_player)
	_fan_waves_left -= 1


func _update_fan(delta: float, to_player: Vector2) -> void:
	if _fan_waves_left <= 0:
		return
	_fan_timer -= delta
	if _fan_timer > 0.0:
		return
	_fan_timer = 0.22
	_pattern_phase *= -1.0
	_fire_fan_wave(to_player)
	_fan_waves_left -= 1


func _fire_fan_wave(to_player: Vector2) -> void:
	var base_dir := to_player.normalized() if to_player.length_squared() > 0.01 else Vector2.RIGHT
	base_dir.y = clampf(base_dir.y, -0.28, 0.12)
	base_dir = base_dir.normalized()
	var count := 7 if _is_desperate() else 5
	for index in count:
		var centered := float(index) - float(count - 1) * 0.5
		var offset := centered * 0.13 + _pattern_phase
		_spawn_boss_projectile(
			base_dir.rotated(offset),
			142.0 + absf(centered) * 7.0,
			attack_damage,
			Color(0.38, 0.86, 1.0, 1.0),
			5.2,
			3.1
		)
	_shake_camera(0.13)


func _begin_pillars() -> void:
	state = State.PILLARS
	_pillar_waves_left = 3 if _is_desperate() else 2
	_pillar_timer = 0.0
	_state_timer = 0.3 + float(_pillar_waves_left) * 0.5
	_disable_melee_hitbox()
	_spawn_pillar_line()
	_pillar_waves_left -= 1


func _update_pillars(delta: float) -> void:
	if _pillar_waves_left <= 0:
		return
	_pillar_timer -= delta
	if _pillar_timer > 0.0:
		return
	_pillar_timer = 0.48
	_spawn_pillar_line()
	_pillar_waves_left -= 1


func _spawn_pillar_line() -> void:
	if player == null or not is_instance_valid(player):
		return
	var spacing := 96.0
	var phase_offset := 48.0 if _pillar_waves_left % 2 == 0 else 0.0
	for index in 5:
		if get_tree().get_nodes_in_group("enemy_transient_attack").size() >= MAX_BOSS_TRANSIENTS:
			break
		var area := AREA_ATTACK_SCRIPT.new() as Area2D
		area.call("setup", 34.0, heavy_attack_damage, Color(0.72, 0.32, 0.95, 1.0), 0.62, 0.18)
		get_tree().current_scene.add_child(area)
		area.global_position = Vector2(player.global_position.x + (float(index) - 2.0) * spacing + phase_offset, player.global_position.y + 18.0)
	_shake_camera(0.18)


func _spawn_boss_projectile(
	direction: Vector2,
	shot_speed: float,
	dmg: int,
	color: Color,
	shot_radius: float,
	shot_lifetime: float,
	spin := 0.0,
	bounces := 0
) -> void:
	if get_tree().get_nodes_in_group("enemy_transient_attack").size() >= MAX_BOSS_TRANSIENTS:
		return
	var projectile := PROJECTILE_SCRIPT.new() as Area2D
	projectile.call("setup", direction, shot_speed, dmg, color, shot_radius, shot_lifetime, spin, bounces)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector2(0, -70) + direction * 36.0


func _begin_sweep(to_player: Vector2) -> void:
	state = State.SWEEP
	_state_timer = 0.42
	velocity.x = signf(to_player.x) * 140.0
	_enable_melee_hitbox(1.35)
	_shake_camera(0.2)


func _begin_recovery(duration: float) -> void:
	state = State.RECOVER
	# Finestra punibile sempre presente; l'ultima fase accelera la cadenza ma
	# non cancella la possibilita' di rispondere.
	_state_timer = maxf(0.48, duration * (0.82 if _is_desperate() else (0.9 if _is_enraged() else 1.0)))
	_attack_timer = attack_cooldown * (0.62 if _is_desperate() else (0.72 if _is_enraged() else 1.0))
	_disable_melee_hitbox()
	_slam_armed = false
	_wave_shots_left = 0
	_spiral_shots_left = 0
	_ring_bursts_left = 0
	_stream_shots_left = 0
	_cross_waves_left = 0
	_fan_waves_left = 0
	_pillar_waves_left = 0
	_sprite.modulate = Color.WHITE


func _enable_melee_hitbox(scale_x: float) -> void:
	_attack_has_hit = false
	_attack_hitbox.monitoring = true
	_attack_hitbox.monitorable = true
	_attack_hitbox.scale = Vector2(0.76 * scale_x, 0.72)
	var facing := 1.0 if _sprite.flip_h else -1.0
	_attack_hitbox.position = Vector2(58.0 * facing, BASE_ATTACK_HITBOX_POSITION.y)


func _disable_melee_hitbox() -> void:
	_attack_hitbox.set_deferred("monitoring", false)
	_attack_hitbox.set_deferred("monitorable", false)
	_attack_hitbox.scale = Vector2(0.76, 0.72)
	_attack_hitbox.position = BASE_ATTACK_HITBOX_POSITION


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		var amount := 1
		var attacker := area.get_parent()
		if attacker and attacker.get("_current_attack_damage") != null:
			amount = int(attacker.get("_current_attack_damage"))
		take_damage(amount, area.global_position)


func take_damage(amount: int = 1, source_position: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD or _invulnerability_timer > 0.0 or _phase_transitioning:
		return
	if state == State.DORMANT:
		_awaken()
	_invulnerability_timer = 0.14
	_hurt_anim = 1.0
	current_health = maxi(0, current_health - amount)
	if current_health <= 0:
		_die()
		return
	var next_phase := 3 if _is_desperate() else (2 if _is_enraged() else 1)
	if next_phase > _phase:
		_phase = next_phase
		_begin_phase_transition()
	var away := signf(global_position.x - source_position.x)
	if is_zero_approx(away):
		away = 1.0
	velocity.x = away * 90.0
	velocity.y = minf(velocity.y, -160.0)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(2.1, 2.15, 2.2, 1.0), 0.04)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	_shake_camera(0.12)


func _begin_phase_transition() -> void:
	if state == State.DEAD:
		return
	_phase_transitioning = true
	_disable_melee_hitbox()
	state = State.RECOVER
	_state_timer = 1.05
	_attack_timer = 1.15
	velocity = Vector2.ZERO
	for attack in get_tree().get_nodes_in_group("enemy_transient_attack"):
		if is_instance_valid(attack):
			attack.queue_free()
	var tint := Color(0.32, 0.94, 0.82, 0.95) if _phase == 2 else Color(0.82, 0.46, 1.0, 0.95)
	_spawn_phase_ring(tint, 155.0 if _phase == 2 else 205.0)
	_shake_camera(0.48 if _phase == 2 else 0.65)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", tint * 1.25, 0.18)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.72)
	tween.tween_callback(func(): _phase_transitioning = false)


func _spawn_phase_ring(tint: Color, radius: float) -> void:
	var ring := AREA_ATTACK_SCRIPT.new() as Area2D
	# Solo spettacolo/respinta leggibile: danno zero durante la transizione.
	ring.call("setup", radius, 0, tint, 0.72, 0.12)
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position + Vector2(0, -48)


func _on_attack_hit_body(body: Node2D) -> void:
	if state != State.LUNGE and state != State.SWEEP:
		return
	if _attack_has_hit or not body.is_in_group("player"):
		return
	_attack_has_hit = true
	if body.has_method("take_damage"):
		body.call_deferred("take_damage", _pending_damage, global_position)
	_spawn_damage_impact(body.global_position, _pending_damage >= 2)
	_shake_camera(0.28 if _pending_damage >= 2 else 0.16)


func _on_contact_body_entered(body: Node2D) -> void:
	_try_contact_damage(body)


func _update_contact_damage() -> void:
	if _contact_damage_timer > 0.0 or state == State.DORMANT or state == State.DEAD:
		return
	for body in _contact_damage_area.get_overlapping_bodies():
		if body is Node2D and _try_contact_damage(body as Node2D):
			return


func _try_contact_damage(body: Node2D) -> bool:
	if _contact_damage_timer > 0.0 or state == State.DORMANT or state == State.DEAD:
		return false
	if not body.is_in_group("player") or not body.has_method("take_damage"):
		return false
	_contact_damage_timer = contact_damage_cooldown
	body.call_deferred("take_damage", contact_damage, global_position)
	_spawn_damage_impact(body.global_position, false)
	_shake_camera(0.12)
	return true


func _spawn_damage_impact(at: Vector2, heavy: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	PARTICLE_BURST.spawn(
		scene,
		at,
		Color(1.0, 0.38, 0.22, 0.9),
		18 if heavy else 10,
		Vector2.UP,
		38.0,
		145.0 if heavy else 96.0,
		0.58
	)


func _spawn_attack_release_fx(to_player: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var direction := to_player.normalized() if to_player.length_squared() > 0.01 else Vector2.RIGHT
	var heavy := _pending_damage >= 2
	var tint := Color(1.0, 0.38, 0.2, 0.92) if heavy else Color(0.32, 0.95, 0.84, 0.9)
	PARTICLE_BURST.spawn(
		scene,
		global_position + Vector2(0.0, -42.0) + direction * 18.0,
		tint,
		18 if heavy else 12,
		direction,
		44.0,
		132.0 if heavy else 96.0,
		0.52
	)


func _die() -> void:
	state = State.DEAD
	_anim_state = "dead"
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_hurtbox.set_deferred("monitoring", false)
	_attack_hitbox.set_deferred("monitoring", false)
	_contact_damage_area.set_deferred("monitoring", false)
	if _telegraph:
		_telegraph.visible = false
	_spawn_death_motes()
	_spawn_extra_life_orb()
	boss_defeated.emit()
	if _wound_light:
		var glow_tween := create_tween()
		glow_tween.tween_property(_wound_light, "energy", 2.4, 0.22)
		glow_tween.tween_property(_wound_light, "energy", 0.0, 0.9)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "modulate:a", 0.0, 1.0)
	tween.tween_property(_sprite, "scale", _base_scale * 1.22, 1.0)
	tween.tween_property(_sprite, "rotation", -0.12, 1.0)
	tween.chain().tween_callback(queue_free)


func _spawn_extra_life_orb() -> void:
	var orb_script := load("res://Levels/Scenes/Dogana/extra_life_orb.gd") as Script
	if orb_script == null:
		return
	var host := get_tree().current_scene
	if host == null:
		return
	var orb := Area2D.new()
	orb.set_script(orb_script)
	host.add_child(orb)
	orb.global_position = global_position + Vector2(0.0, -92.0)
	orb.set("_home", orb.global_position)


func restore_defeated() -> void:
	state = State.DEAD
	current_health = 0
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_hurtbox.set_deferred("monitoring", false)
	_attack_hitbox.set_deferred("monitoring", false)
	_attack_hitbox.set_deferred("monitorable", false)
	_contact_damage_area.set_deferred("monitoring", false)
	_sprite.hide()
	if _telegraph:
		_telegraph.visible = false
	if _wound_light:
		_wound_light.queue_free()
	set_physics_process(false)


func _shake_camera(intensity: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("add_shake"):
		cam.call("add_shake", intensity)


func _build_telegraph() -> void:
	_telegraph = Node2D.new()
	_telegraph.name = "Telegraph"
	_telegraph.z_index = 8
	_telegraph.set_script(TELEGRAPH_SCRIPT)
	add_child(_telegraph)


func _update_telegraph(to_player: Vector2) -> void:
	if _telegraph == null or not _telegraph.has_method("set_preview"):
		return
	if state == State.WINDUP:
		var progress := 1.0 - clampf(_state_timer / maxf(_windup_duration, 0.01), 0.0, 1.0)
		_telegraph.call("set_preview", int(_pending_kind), to_player.normalized(), progress, false)
		return
	if state == State.LUNGE or state == State.SWEEP:
		var active_kind := AttackKind.LUNGE if state == State.LUNGE else AttackKind.SWEEP
		var facing := Vector2.RIGHT if _sprite.flip_h else Vector2.LEFT
		_telegraph.call("set_preview", int(active_kind), facing, 1.0, true)
		return
	_telegraph.call("set_preview", -1, Vector2.ZERO, 0.0, false)


func _spawn_death_motes() -> void:
	PARTICLE_BURST.spawn(
		get_tree().current_scene,
		global_position + Vector2(0, -52),
		Color(0.22, 0.86, 0.74, 0.92),
		34,
		Vector2.UP,
		70.0,
		220.0,
		1.1
	)
	for index in 8:
		var mote := Polygon2D.new()
		var radius := randf_range(3.0, 8.0)
		mote.polygon = PackedVector2Array([
			Vector2(0, -radius),
			Vector2(radius, 0),
			Vector2(0, radius),
			Vector2(-radius, 0),
		])
		mote.color = Color(0.22, 0.86, 0.74, 0.88) if index % 3 == 0 else Color(0.08, 0.1, 0.1, 0.92)
		mote.position = Vector2(randf_range(-90.0, 90.0), randf_range(-130.0, 40.0))
		add_child(mote)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(mote, "position", mote.position + Vector2(randf_range(-110.0, 110.0), randf_range(-150.0, -35.0)), randf_range(0.7, 1.2))
		tween.tween_property(mote, "modulate:a", 0.0, 1.1)
		tween.chain().tween_callback(mote.queue_free)


## Niente barra: il Custode dichiara le proprie condizioni col corpo. Le
## fratture luminose si aprono man mano che incassa e l'alone vira dal verde
## d'acqua all'ambra, cosi' si legge quanto manca guardando lui, non la UI.
func _build_health_ui() -> void:
	_wound_overlay = Sprite2D.new()
	_wound_overlay.name = "WoundGlow"
	_wound_overlay.texture = _sprite.texture
	_wound_overlay.hframes = _sprite.hframes
	_wound_overlay.vframes = _sprite.vframes
	_wound_overlay.frame = _sprite.frame
	_wound_overlay.region_enabled = _sprite.region_enabled
	_wound_overlay.region_rect = _sprite.region_rect
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_wound_overlay.material = additive
	_wound_overlay.modulate = Color(0.3, 0.72, 0.6, 0.0)
	_sprite.add_child(_wound_overlay)

	_wound_light = PointLight2D.new()
	_wound_light.name = "WoundLight"
	_wound_light.texture = _make_glow_texture()
	_wound_light.texture_scale = 2.6
	_wound_light.energy = 0.0
	_wound_light.shadow_enabled = false
	add_child(_wound_light)


func _make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.24), Color(1, 1, 1, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _update_wound_signal(delta: float) -> void:
	if _wound_overlay == null:
		return
	var wear := 1.0 - clampf(float(current_health) / float(maxi(max_health, 1)), 0.0, 1.0)
	_wound_pulse += delta * (2.4 + wear * 5.0)
	var breath := 0.6 + 0.4 * sin(_wound_pulse)
	var tint := Color(0.24, 0.7, 0.62).lerp(Color(0.92, 0.46, 0.2), wear)
	_wound_overlay.modulate = Color(
		tint.r, tint.g, tint.b, (0.06 + wear * 0.62) * breath + _hurt_anim * 0.5
	)
	if _wound_light:
		_wound_light.color = tint
		_wound_light.energy = (0.15 + wear * 0.95) * breath
		_wound_light.enabled = state != State.DORMANT
