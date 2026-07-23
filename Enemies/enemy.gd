extends CharacterBody2D

const PROJECTILE_SCRIPT := preload("res://Enemies/enemy_projectile.gd")
const AREA_ATTACK_SCRIPT := preload("res://Enemies/enemy_area_attack.gd")
const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")
const MAX_TRANSIENT_ATTACKS := 48

# ===========================================
# ENEMY - Nemico che resta idle finché non viene colpito
# ===========================================
# Idle: animazione Idle, non fa nulla
# Dopo essere colpito: va in aggro, insegue il player, saltella e può colpire

@export_category("Movement")
@export var move_speed: float = 80.0
@export var gravity: float = 500.0
@export var jump_speed: float = 220.0

@export_category("Health")
@export var max_health: int = 6

@export_category("Aggro")
@export var aggro_range: float = 140.0   # distanza: se il player si avvicina entro questo range, diventa aggressivo
@export var wake_delay: float = 0.75      # breve telegraph prima che possa attivarsi
@export var jump_interval: float = 1.7   # secondi tra un salto e l'altro in aggro
@export var attack_range: float = 45.0   # distanza per considerare "vicino" al player
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.35
@export var knockback_speed: float = 1020.0  # rinculo quando colpito (metà di 2040)
@export var knockback_duration: float = 0.35

@export_category("Archetype")
enum AttackPattern { MELEE, TIDE_AREA, AIMED_VOLLEY, RADIAL_BARRAGE }
@export var attack_pattern: AttackPattern = AttackPattern.MELEE
@export var variant_texture: Texture2D
@export var variant_scale_multiplier := 1.0
@export var hovering := false
@export var special_attack_range := 260.0
@export var special_attack_cooldown := 3.2
@export var special_windup := 0.65
@export var area_attack_radius := 88.0
@export_range(3, 12, 1) var projectile_count := 5
@export var projectile_speed := 135.0
@export var leash_distance := 460.0
@export var disengage_range := 560.0

@export_category("Respawn")
@export var respawn_enabled := true
@export var respawn_delay := 9.0
@export var respawn_safe_distance := 300.0
@export var post_respawn_wake_delay := 3.5
@export var activation_managed := false

@export_category("Visual")
@export var sprite_node: Node2D = null
## Colore dello sprite quando viene colpito (flash molto visibile)
@export var hit_flash_color: Color = Color(2.2, 0.25, 0.25, 1.0)
@export var hit_flash_duration: float = 0.22
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
var _hit_flash_timer: float = 0.0
var _flip_cooldown: float = 0.0
var _attack_has_hit := false
const FLIP_MIN_INTERVAL: float = 0.45  # cooldown tra un cambio direzione e l'altro (evita glitch avanti/indietro)

var _hurtbox: Area2D = null
var _attack_hitbox: Area2D = null
var _anim: AnimationPlayer = null
var _original_sprite_scale: Vector2 = Vector2.ONE
var _breath_timer: float = 0.0
var _original_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
var _wake_timer := 0.0
var _home_position := Vector2.ZERO
var _special_timer := 1.0
var _special_windup_remaining := 0.0
var _special_target_direction := Vector2.RIGHT
var _respawn_generation := 0
var _respawn_timer: Timer
var _base_sprite_position := Vector2.ZERO
var _attack_kick := 0.0

func _ready():
	add_to_group("enemy")
	_home_position = global_position
	current_health = max_health
	_wake_timer = wake_delay
	_anim = get_node_or_null("AnimationPlayer")
	_hurtbox = get_node_or_null("Hurtbox")
	_attack_hitbox = get_node_or_null("AttackHitbox")
	if sprite_node == null:
		sprite_node = get_node_or_null("Sprite2D")
	if variant_texture and sprite_node is Sprite2D:
		var sprite := sprite_node as Sprite2D
		sprite.texture = variant_texture
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.frame = 0
		sprite.scale *= variant_scale_multiplier
		if _anim:
			_anim.active = false
	if sprite_node:
		_original_sprite_scale = sprite_node.scale
		_original_modulate = sprite_node.modulate
		_base_sprite_position = sprite_node.position
	if _hurtbox:
		_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	if _attack_hitbox:
		_attack_hitbox.body_entered.connect(_on_attack_hit_body)
		_attack_hitbox.monitoring = false
		_attack_hitbox.position.x = 20 if facing_right else -20
		_attack_hitbox.collision_mask = 2  # layer 2 = player, così ti colpisce anche quando salta
	_respawn_timer = Timer.new()
	_respawn_timer.name = "RespawnTimer"
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_on_respawn_timeout)
	add_child(_respawn_timer)
	# Layer 2, mask 1: collide solo con terreno (layer 1), non col player = non ti finisce sopra
	collision_layer = 2
	collision_mask = 1
	z_index = 5 if variant_texture else -1
	play_idle()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	# Le varianti illustrate usano animazione procedurale; i gamberetti
	# conservano le animazioni a frame del loro AnimationPlayer.
	if variant_texture:
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
		# Se il player si avvicina, diventa aggressivo
		var p = get_tree().get_first_node_in_group("player") as Node2D
		if p and is_instance_valid(p):
			var d = global_position.distance_to(p.global_position)
			if d <= aggro_range and _wake_timer <= 0.0:
				state = State.AGGRO
				player = p
				jump_timer = 0.0
		var home_delta := _home_position - global_position
		velocity.x = signf(home_delta.x) * move_speed * 0.55 if absf(home_delta.x) > 5.0 else 0.0
		if hovering:
			var hover_target := _home_position.y + sin(_breath_timer * 1.35) * 7.0
			velocity.y = clampf((hover_target - global_position.y) * 3.2, -45.0, 45.0)
		else:
			velocity.y += gravity * delta
		move_and_slide()
		return

	# Rinculo: per un breve tempo non inseguire, solo fisica del rinculo
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, knockback_speed * 5.0 * delta)
		move_and_slide()
		return

	# AGGRO: insegui il player
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			state = State.IDLE
			play_idle()
			return

	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() > disengage_range or global_position.distance_to(_home_position) > leash_distance:
		_disengage()
		return
	var dir_x: float = sign(to_player.x)
	velocity.x = dir_x * move_speed * (0.28 if _special_windup_remaining > 0.0 else 1.0)

	# Flip verso il player solo dopo cooldown (evita glitch avanti/indietro)
	_flip_cooldown -= delta
	if dir_x != 0 and _flip_cooldown <= 0.0:
		var new_facing: bool = dir_x > 0
		if new_facing != facing_right and abs(to_player.x) > 15.0:
			facing_right = new_facing
			_flip_cooldown = FLIP_MIN_INTERVAL
			if sprite_node:
				if "flip_h" in sprite_node:
					sprite_node.flip_h = !facing_right
				elif sprite_node is Sprite2D:
					sprite_node.flip_h = !facing_right
			if _attack_hitbox:
				_attack_hitbox.position.x = 20 if facing_right else -20

	# Gravità e salto periodico; gli oracoli restano sospesi e seguono in verticale.
	if hovering:
		velocity.y = clampf(to_player.y * 0.75, -70.0, 70.0)
	else:
		velocity.y += gravity * delta
		jump_timer -= delta
		if is_on_floor() and jump_timer <= 0.0:
			jump_timer = jump_interval
			velocity.y = -jump_speed
			if _anim and _anim.has_animation("Jump"):
				_anim.play("Jump")

	_update_special_attack(delta, to_player)

	# Attacco se vicino
	attack_timer -= delta
	if _attack_hitbox_disable_timer > 0.0:
		_attack_hitbox_disable_timer -= delta
		if _attack_hitbox_disable_timer <= 0.0 and _attack_hitbox:
			_attack_hitbox.monitoring = false
	var dist: float = global_position.distance_to(player.global_position)
	if dist <= attack_range and attack_timer <= 0.0 and _attack_hitbox and _attack_hitbox_disable_timer <= 0.0:
		attack_timer = attack_cooldown
		_attack_has_hit = false
		_attack_hitbox.monitoring = true
		_attack_hitbox_disable_timer = 0.25
		if _anim and _anim.has_animation("Attack"):
			_anim.play("Attack")

	move_and_slide()

	if is_on_floor() and state == State.AGGRO and (_anim == null or not _anim.is_playing() or _anim.current_animation == "Idle"):
		if _anim and _anim.has_animation("Walk"):
			_anim.play("Walk")
		elif _anim and _anim.has_animation("Idle"):
			_anim.play("Idle")

func _update_special_attack(delta: float, to_player: Vector2) -> void:
	if attack_pattern == AttackPattern.MELEE:
		return
	_special_timer = maxf(0.0, _special_timer - delta)
	if _special_windup_remaining > 0.0:
		_special_windup_remaining -= delta
		queue_redraw()
		if _special_windup_remaining <= 0.0:
			_fire_special_attack()
		return
	var distance := to_player.length()
	var can_start := distance <= special_attack_range
	if attack_pattern == AttackPattern.TIDE_AREA:
		can_start = distance <= area_attack_radius + 52.0
	if can_start and _special_timer <= 0.0:
		_special_target_direction = to_player.normalized() if distance > 0.01 else Vector2.RIGHT
		_special_windup_remaining = special_windup
		_special_timer = special_attack_cooldown
		velocity.x *= 0.2
		queue_redraw()


func _fire_special_attack() -> void:
	_attack_kick = 1.0
	queue_redraw()
	if attack_pattern == AttackPattern.TIDE_AREA:
		var area := AREA_ATTACK_SCRIPT.new() as Area2D
		area.call("setup", area_attack_radius, attack_damage, Color(0.24, 0.92, 0.78, 1.0), special_windup)
		get_tree().current_scene.add_child(area)
		area.global_position = global_position
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


func _spawn_projectile(direction: Vector2, shot_speed: float, color: Color, shot_radius: float) -> void:
	if get_tree().get_nodes_in_group("enemy_transient_attack").size() >= MAX_TRANSIENT_ATTACKS:
		return
	var projectile := PROJECTILE_SCRIPT.new() as Area2D
	projectile.call("setup", direction, shot_speed, attack_damage, color, shot_radius, 3.2)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 24.0


func _draw() -> void:
	if _special_windup_remaining <= 0.0 or special_windup <= 0.0:
		return
	var progress := 1.0 - _special_windup_remaining / special_windup
	var color := Color(0.3, 0.95, 0.78, 0.32 + progress * 0.55)
	var radius := lerpf(18.0, 34.0, progress)
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 30, color, 2.0 + progress * 2.0, true)
	for ray in 6:
		var direction := Vector2.from_angle(float(ray) / 6.0 * TAU)
		draw_line(direction * 12.0, direction * radius, Color(color.r, color.g, color.b, color.a * 0.55), 1.4, true)


func _update_variant_animation(delta: float) -> void:
	if sprite_node == null:
		return
	_breath_timer += delta
	_attack_kick = move_toward(_attack_kick, 0.0, delta * 3.8)
	var moving := state == State.AGGRO and absf(velocity.x) > 4.0
	var cadence := 5.4 if moving else 2.25
	var wave := sin(_breath_timer * cadence)
	var bob := sin(_breath_timer * (2.0 if hovering else cadence)) * (4.5 if hovering else 1.8)
	var squash := absf(wave) * 0.045 if moving and not hovering else 0.018 * wave
	var windup_progress := 0.0
	if _special_windup_remaining > 0.0:
		windup_progress = 1.0 - _special_windup_remaining / maxf(special_windup, 0.01)
	var pulse := sin(windup_progress * PI * 4.0) * windup_progress * 0.055
	var kick_offset := -_special_target_direction * _attack_kick * 8.0
	sprite_node.position = _base_sprite_position + Vector2(0, bob) + kick_offset
	sprite_node.rotation = sin(_breath_timer * 1.65) * (0.035 if hovering else 0.018)
	sprite_node.scale = Vector2(
		_original_sprite_scale.x * (1.0 + squash + pulse + _attack_kick * 0.05),
		_original_sprite_scale.y * (1.0 - squash + pulse - _attack_kick * 0.035)
	)


func play_idle() -> void:
	if _anim and _anim.has_animation("Idle"):
		_anim.play("Idle")

func _on_hurtbox_area_entered(area: Area2D) -> void:
	# Il danno lo applica solo il player nel suo _on_attack_hitbox_area_entered (1 o 2).
	# Qui non chiamiamo take_damage per evitare doppio danno e colpi "a caso" quando
	# il player non sta attaccando (l'hitbox del player ora ha layer 0 quando disabilitata).
	pass

func take_damage(amount: int = 1, source_position: Vector2 = Vector2.ZERO) -> void:
	current_health = max(0, current_health - amount)
	# Flash colore per far vedere che è stato colpito
	_hit_flash_timer = hit_flash_duration
	if sprite_node:
		sprite_node.modulate = hit_flash_color
	# Particelle al colpo
	_spawn_hit_particles(source_position)
	# Quando colpisci uno, tutti i gamberetti (gruppo "enemy") vanno in aggro (anche se questo muore)
	_alert_nearby_enemies()

	if current_health <= 0:
		_die()
		return

	# Rinculo: prevalentemente orizzontale (sinistra/destra), al massimo un lieve stacco
	if source_position != Vector2.ZERO:
		var dir: Vector2 = (global_position - source_position).normalized()
		dir.x = sign(dir.x)
		dir.y = -0.2
		dir = dir.normalized()
		velocity = dir * knockback_speed
		_knockback_timer = knockback_duration

	if state == State.IDLE:
		state = State.AGGRO
		player = get_tree().get_first_node_in_group("player") as Node2D
		jump_timer = 0.0
		if _anim and _anim.has_animation("Hit"):
			_anim.play("Hit")
		elif _anim and _anim.has_animation("Walk"):
			_anim.play("Walk")

## Raggio entro cui un nemico colpito "allerta" gli altri (solo questi vanno in aggro)
const ALERT_NEARBY_RADIUS: float = 220.0

func _alert_nearby_enemies() -> void:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
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
		if "state" in n:
			n.set("state", State.AGGRO)
		if "player" in n:
			n.set("player", p)
		if "jump_timer" in n:
			n.set("jump_timer", 0.0)

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
		p.call("set_color", Color(0.9, 0.35, 0.2, 0.9))
	if p.has_method("set_amount"):
		p.call("set_amount", 8)
	if p.has_method("play"):
		p.call("play")

func _die() -> void:
	state = State.DEAD
	if _hurtbox:
		_hurtbox.set_deferred("monitoring", false)
	if _attack_hitbox:
		_attack_hitbox.set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask = 0
	# Crea un RigidBody2D "Dead Gamberetto" spostabile (attacco e hook possono spingerlo)
	# Aggiungilo in deferred per evitare "Can't change this state while flushing queries"
	var parent_node: Node = get_parent()
	var pos_global: Vector2 = global_position
	const DEAD_GAMBERETTO_PATH := "res://Landscape/Sprites/dead gamberetto.png"
	var tex: Texture2D = variant_texture if variant_texture else load(DEAD_GAMBERETTO_PATH) as Texture2D
	var dead_scale: Vector2 = Vector2(0.08, 0.08)

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
	col_shape.size = Vector2(16, 16)
	var col_node: CollisionShape2D = CollisionShape2D.new()
	col_node.shape = col_shape
	rb.add_child(col_node)

	if tex != null:
		var spr: Sprite2D = Sprite2D.new()
		spr.texture = tex
		spr.scale = dead_scale
		rb.add_child(spr)

	rb.z_index = -1
	# Posizione in coordinate locali del parent, così quando viene aggiunto è già al posto giusto
	rb.position = parent_node.to_local(pos_global)
	parent_node.call_deferred("add_child", rb)
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
	if respawn_enabled:
		call_deferred("_schedule_respawn")
	else:
		queue_free()


func _schedule_respawn() -> void:
	_respawn_generation += 1
	_respawn_timer.start(respawn_delay)


func _on_respawn_timeout() -> void:
	var current_player := get_tree().get_first_node_in_group("player") as Node2D
	if current_player and current_player.global_position.distance_to(_home_position) < respawn_safe_distance:
		_respawn_timer.start(0.75)
		return
	reset_to_home()


func reset_to_home() -> void:
	_respawn_generation += 1
	if _respawn_timer:
		_respawn_timer.stop()
	global_position = _home_position
	velocity = Vector2.ZERO
	state = State.IDLE
	player = null
	current_health = max_health
	_wake_timer = post_respawn_wake_delay
	_special_timer = special_attack_cooldown * 0.65
	_special_windup_remaining = 0.0
	_knockback_timer = 0.0
	_hit_flash_timer = 0.0
	_attack_has_hit = false
	collision_layer = 2
	collision_mask = 1
	visible = true
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
		_anim.active = variant_texture == null
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
	# Deferred evita mutazioni del player/death sequence durante il flush della query fisica.
	if body.has_method("take_damage"):
		body.call_deferred("take_damage", attack_damage, global_position)
	elif "current_health" in body:
		body.set_deferred("current_health", maxi(0, int(body.get("current_health")) - attack_damage))
