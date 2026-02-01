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

@export_category("Aggro")
@export var jump_interval: float = 1.2  # secondi tra un salto e l'altro in aggro
@export var attack_range: float = 45.0   # distanza per considerare "vicino" al player
@export var attack_damage: int = 1
@export var attack_cooldown: float = 0.8
@export var knockback_speed: float = 220.0  # rinculo quando colpito dal player
@export var knockback_duration: float = 0.15

@export_category("Visual")
@export var sprite_node: Node2D = null

enum State { IDLE, AGGRO }
var state: State = State.IDLE
var player: Node2D = null
var jump_timer: float = 0.0
var attack_timer: float = 0.0
var facing_right: bool = true
var _attack_hitbox_disable_timer: float = 0.0
var _knockback_timer: float = 0.0

var _hurtbox: Area2D = null
var _attack_hitbox: Area2D = null
var _anim: AnimationPlayer = null

func _ready():
	add_to_group("enemy")
	_anim = get_node_or_null("AnimationPlayer")
	_hurtbox = get_node_or_null("Hurtbox")
	_attack_hitbox = get_node_or_null("AttackHitbox")
	if sprite_node == null:
		sprite_node = get_node_or_null("Sprite2D")
	if _hurtbox:
		_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	if _attack_hitbox:
		_attack_hitbox.body_entered.connect(_on_attack_hit_body)
		_attack_hitbox.monitoring = false
		_attack_hitbox.position.x = 20 if facing_right else -20
	play_idle()

func _physics_process(delta: float) -> void:
	if state == State.IDLE:
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

	var to_player := player.global_position - global_position
	var dir_x := sign(to_player.x)
	velocity.x = dir_x * move_speed

	# Flip verso il player e posiziona AttackHitbox
	if dir_x != 0:
		facing_right = dir_x > 0
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
	var dist := global_position.distance_to(player.global_position)
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
	if area.is_in_group("player_attack"):
		var attacker_pos: Vector2 = area.global_position
		var parent = area.get_parent()
		if parent is Node2D:
			attacker_pos = (parent as Node2D).global_position
		take_damage(1, attacker_pos)

func take_damage(_amount: int = 1, source_position: Vector2 = Vector2.ZERO) -> void:
	# Rinculo: spinta nella direzione opposta a chi ci ha colpito
	if source_position != Vector2.ZERO:
		var dir := (global_position - source_position).normalized()
		dir.x = sign(dir.x)
		dir.y = -0.5
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

func _on_attack_hit_body(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(attack_damage, global_position)
		elif "current_health" in body:
			body.current_health = max(0, body.current_health - attack_damage)
