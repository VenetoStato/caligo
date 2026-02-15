extends CharacterBody2D

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
@export var jump_interval: float = 1.2   # secondi tra un salto e l'altro in aggro
@export var attack_range: float = 45.0   # distanza per considerare "vicino" al player
@export var attack_damage: int = 1
@export var attack_cooldown: float = 0.8
@export var knockback_speed: float = 1020.0  # rinculo quando colpito (metà di 2040)
@export var knockback_duration: float = 0.35

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
const FLIP_MIN_INTERVAL: float = 0.45  # cooldown tra un cambio direzione e l'altro (evita glitch avanti/indietro)

var _hurtbox: Area2D = null
var _attack_hitbox: Area2D = null
var _anim: AnimationPlayer = null
var _original_sprite_scale: Vector2 = Vector2.ONE
var _breath_timer: float = 0.0
var _original_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready():
	add_to_group("enemy")
	current_health = max_health
	_anim = get_node_or_null("AnimationPlayer")
	_hurtbox = get_node_or_null("Hurtbox")
	_attack_hitbox = get_node_or_null("AttackHitbox")
	if sprite_node == null:
		sprite_node = get_node_or_null("Sprite2D")
	if sprite_node:
		_original_sprite_scale = sprite_node.scale
		_original_modulate = sprite_node.modulate
	if _hurtbox:
		_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	if _attack_hitbox:
		_attack_hitbox.body_entered.connect(_on_attack_hit_body)
		_attack_hitbox.monitoring = false
		_attack_hitbox.position.x = 20 if facing_right else -20
		_attack_hitbox.collision_mask = 2  # layer 2 = player, così ti colpisce anche quando salta
	# Layer 2, mask 1: collide solo con terreno (layer 1), non col player = non ti finisce sopra
	collision_layer = 2
	collision_mask = 1
	z_index = -1  # disegnato dietro al player
	play_idle()

func _physics_process(delta: float) -> void:
	# Respiro: espansione verticale leggera, poca compressione orizzontale
	if sprite_node and state != State.DEAD:
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
		# Se il player si avvicina, diventa aggressivo
		var p = get_tree().get_first_node_in_group("player") as Node2D
		if p and is_instance_valid(p):
			var d = global_position.distance_to(p.global_position)
			if d <= aggro_range:
				state = State.AGGRO
				player = p
				jump_timer = 0.0
		velocity.x = 0.0
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
	var dir_x: float = sign(to_player.x)
	velocity.x = dir_x * move_speed

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

	# Gravità e salto periodico
	velocity.y += gravity * delta
	jump_timer -= delta
	if is_on_floor() and jump_timer <= 0.0:
		jump_timer = jump_interval
		velocity.y = -jump_speed
		if _anim and _anim.has_animation("Jump"):
			_anim.play("Jump")

	# Attacco se vicino
	attack_timer -= delta
	if _attack_hitbox_disable_timer > 0.0:
		_attack_hitbox_disable_timer -= delta
		if _attack_hitbox_disable_timer <= 0.0 and _attack_hitbox:
			_attack_hitbox.monitoring = false
	var dist: float = global_position.distance_to(player.global_position)
	if dist <= attack_range and attack_timer <= 0.0 and _attack_hitbox and _attack_hitbox_disable_timer <= 0.0:
		attack_timer = attack_cooldown
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

func _alert_nearby_enemies() -> void:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	for n in get_tree().get_nodes_in_group("enemy"):
		if n == self:
			continue
		if not is_instance_valid(n):
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
	# Crea un RigidBody2D "Dead Gamberetto" spostabile (attacco e hook possono spingerlo)
	# Aggiungilo in deferred per evitare "Can't change this state while flushing queries"
	var parent_node: Node = get_parent()
	var pos_global: Vector2 = global_position
	const DEAD_GAMBERETTO_PATH := "res://Landscape/Sprites/dead gamberetto.png"
	var tex: Texture2D = load(DEAD_GAMBERETTO_PATH) as Texture2D
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
	queue_free()

func _on_attack_hit_body(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(attack_damage, global_position)
		elif "current_health" in body:
			body.current_health = max(0, body.current_health - attack_damage)
