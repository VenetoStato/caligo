extends CharacterBody2D

signal boss_awakened
signal boss_defeated

const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")
const AREA_ATTACK_SCRIPT := preload("res://Enemies/enemy_area_attack.gd")
const PROJECTILE_SCRIPT := preload("res://Enemies/enemy_projectile.gd")
const TELEGRAPH_SCRIPT := preload("res://Levels/Scenes/Dogana/boss_telegraph.gd")

const MAX_BOSS_TRANSIENTS := 72

@export var max_health := 28
@export var move_speed := 78.0
@export var lunge_speed := 330.0
@export var aggro_range := 520.0
@export var attack_range := 220.0
@export var attack_cooldown := 1.35
@export var attack_damage := 1
@export var heavy_attack_damage := 2
@export var gravity := 620.0

enum State { DORMANT, CHASE, WINDUP, LUNGE, SLAM, WAVE, SWEEP, SPIRAL, RING, STREAM, CROSS, RECOVER, DEAD }
enum AttackKind { LUNGE, SLAM, WAVE, SWEEP, SPIRAL, RING, STREAM, CROSS }

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _attack_hitbox: Area2D = $AttackHitbox

var state := State.DORMANT
var current_health := 28
var player: Node2D
var _state_timer := 0.0
var _attack_timer := 0.0
var _invulnerability_timer := 0.0
var _attack_has_hit := false
var _base_scale := Vector2.ONE
var _health_layer: CanvasLayer
var _health_bar: ProgressBar
var _health_panel: PanelContainer
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


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("dogana_boss")
	current_health = max_health
	_base_scale = _sprite.scale
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_attack_hitbox.body_entered.connect(_on_attack_hit_body)
	_attack_hitbox.monitoring = false
	_attack_hitbox.monitorable = false
	_attack_hitbox.collision_mask = 2
	_build_health_ui()
	_build_telegraph()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_invulnerability_timer = maxf(0.0, _invulnerability_timer - delta)
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity.y += gravity * delta

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	_sprite.flip_h = to_player.x > 0.0
	_update_telegraph(to_player)

	match state:
		State.DORMANT:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			_sprite.scale = _base_scale * (1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.018)
			if absf(to_player.x) <= aggro_range:
				_awaken()
		State.CHASE:
			var chase_speed := move_speed * (1.22 if _is_enraged() else 1.0)
			velocity.x = signf(to_player.x) * chase_speed
			_sprite.rotation = sin(Time.get_ticks_msec() * 0.009) * 0.018
			if _attack_timer <= 0.0 and absf(to_player.x) <= attack_range:
				_begin_windup(to_player)
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			var pulse := 1.0 + sin(_state_timer * 40.0) * 0.04
			_sprite.scale = _base_scale * Vector2(1.0 / pulse, pulse)
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
		State.SWEEP:
			if _state_timer <= 0.0:
				_begin_recovery(0.95)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 760.0 * delta)
			_sprite.rotation = lerpf(_sprite.rotation, 0.0, delta * 8.0)
			_sprite.scale = _sprite.scale.lerp(_base_scale, delta * 9.0)
			if _state_timer <= 0.0:
				state = State.CHASE

	move_and_slide()


func _is_enraged() -> bool:
	return current_health <= max_health / 2


func _is_desperate() -> bool:
	return current_health <= maxi(1, max_health / 3)


func _awaken() -> void:
	state = State.CHASE
	_attack_timer = 1.1
	if _health_layer:
		_health_layer.visible = true
	boss_awakened.emit()
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


func _pick_attack(to_player: Vector2) -> AttackKind:
	var dist := absf(to_player.x)
	var options: Array[AttackKind] = []
	if dist <= 120.0:
		options.append(AttackKind.SWEEP)
		options.append(AttackKind.LUNGE)
		options.append(AttackKind.SLAM)
		options.append(AttackKind.RING)
	elif dist <= 240.0:
		options.append(AttackKind.LUNGE)
		options.append(AttackKind.SLAM)
		options.append(AttackKind.WAVE)
		options.append(AttackKind.STREAM)
		options.append(AttackKind.CROSS)
	else:
		options.append(AttackKind.WAVE)
		options.append(AttackKind.SPIRAL)
		options.append(AttackKind.STREAM)
		options.append(AttackKind.CROSS)
		if _is_enraged():
			options.append(AttackKind.RING)
	if _is_enraged():
		options.append(AttackKind.SPIRAL)
		options.append(AttackKind.STREAM)
		options.append(AttackKind.RING)
	if _is_desperate():
		options.append(AttackKind.SPIRAL)
		options.append(AttackKind.CROSS)
		options.append(AttackKind.STREAM)
	return options[randi() % options.size()]


func _commit_attack(to_player: Vector2) -> void:
	_sprite.modulate = Color.WHITE
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
	_sprite.rotation = signf(to_player.x) * 0.18
	_shake_camera(0.2)


func _begin_recovery(duration: float) -> void:
	state = State.RECOVER
	_state_timer = duration * (0.7 if _is_desperate() else (0.78 if _is_enraged() else 1.0))
	_attack_timer = attack_cooldown * (0.62 if _is_desperate() else (0.72 if _is_enraged() else 1.0))
	_disable_melee_hitbox()
	_slam_armed = false
	_wave_shots_left = 0
	_spiral_shots_left = 0
	_ring_bursts_left = 0
	_stream_shots_left = 0
	_cross_waves_left = 0
	_sprite.modulate = Color.WHITE


func _enable_melee_hitbox(scale_x: float) -> void:
	_attack_has_hit = false
	_attack_hitbox.monitoring = true
	_attack_hitbox.monitorable = true
	_attack_hitbox.scale = Vector2(scale_x, 1.0)
	var facing := 1.0 if _sprite.flip_h else -1.0
	_attack_hitbox.position.x = 36.0 * facing


func _disable_melee_hitbox() -> void:
	_attack_hitbox.set_deferred("monitoring", false)
	_attack_hitbox.set_deferred("monitorable", false)
	_attack_hitbox.scale = Vector2.ONE


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		var amount := 1
		var attacker := area.get_parent()
		if attacker and attacker.get("_current_attack_damage") != null:
			amount = int(attacker.get("_current_attack_damage"))
		take_damage(amount, area.global_position)


func take_damage(amount: int = 1, source_position: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD or _invulnerability_timer > 0.0:
		return
	if state == State.DORMANT:
		_awaken()
	_invulnerability_timer = 0.14
	current_health = maxi(0, current_health - amount)
	if _health_bar:
		_health_bar.value = current_health
	var away := signf(global_position.x - source_position.x)
	velocity.x = away * 130.0
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.6, 0.34, 0.28, 1.0), 0.05)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	_shake_camera(0.16)
	if current_health <= 0:
		_die()


func _on_attack_hit_body(body: Node2D) -> void:
	if state != State.LUNGE and state != State.SWEEP:
		return
	if _attack_has_hit or not body.is_in_group("player"):
		return
	_attack_has_hit = true
	if body.has_method("take_damage"):
		body.call_deferred("take_damage", _pending_damage, global_position)
	_shake_camera(0.28 if _pending_damage >= 2 else 0.16)


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_hurtbox.set_deferred("monitoring", false)
	_attack_hitbox.set_deferred("monitoring", false)
	if _telegraph:
		_telegraph.visible = false
	_spawn_death_motes()
	boss_defeated.emit()
	if _health_panel:
		var ui_tween := create_tween()
		ui_tween.tween_property(_health_panel, "position:y", 8.0, 0.4)
		ui_tween.parallel().tween_property(_health_panel, "modulate:a", 0.0, 0.4)
		ui_tween.tween_callback(_health_layer.queue_free)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "modulate:a", 0.0, 1.0)
	tween.tween_property(_sprite, "scale", _base_scale * 1.22, 1.0)
	tween.tween_property(_sprite, "rotation", -0.12, 1.0)
	tween.chain().tween_callback(queue_free)


func restore_defeated() -> void:
	state = State.DEAD
	current_health = 0
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_hurtbox.set_deferred("monitoring", false)
	_attack_hitbox.set_deferred("monitoring", false)
	_attack_hitbox.set_deferred("monitorable", false)
	_sprite.hide()
	if _telegraph:
		_telegraph.visible = false
	if _health_layer:
		_health_layer.queue_free()
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
	if state != State.WINDUP:
		_telegraph.call("set_preview", -1, Vector2.ZERO, 0.0)
		return
	var progress := 1.0 - clampf(_state_timer / 0.72, 0.0, 1.0)
	_telegraph.call("set_preview", int(_pending_kind), to_player.normalized(), progress)


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


func _build_health_ui() -> void:
	_health_layer = CanvasLayer.new()
	_health_layer.layer = 28
	_health_layer.visible = false
	add_child(_health_layer)

	_health_panel = PanelContainer.new()
	_health_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_health_panel.position = Vector2(-240.0, 42.0)
	_health_panel.custom_minimum_size = Vector2(480.0, 66.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.035, 0.04, 0.92)
	panel_style.border_color = Color(0.52, 0.48, 0.34, 0.86)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(3)
	panel_style.set_content_margin_all(10)
	_health_panel.add_theme_stylebox_override("panel", panel_style)
	_health_layer.add_child(_health_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	_health_panel.add_child(column)
	var title := Label.new()
	title.text = "IL CUSTODE DELLA SALUTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.78, 0.73, 0.57, 1.0))
	column.add_child(title)

	_health_bar = ProgressBar.new()
	_health_bar.max_value = max_health
	_health_bar.value = current_health
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(450.0, 13.0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.08, 0.09, 1.0)
	background.border_color = Color(0.17, 0.25, 0.24, 1.0)
	background.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.18, 0.68, 0.59, 0.96)
	fill.border_color = Color(0.56, 0.82, 0.7, 1.0)
	fill.set_border_width_all(1)
	_health_bar.add_theme_stylebox_override("background", background)
	_health_bar.add_theme_stylebox_override("fill", fill)
	column.add_child(_health_bar)
