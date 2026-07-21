extends CharacterBody2D

signal boss_awakened
signal boss_defeated

@export var max_health := 18
@export var move_speed := 74.0
@export var lunge_speed := 310.0
@export var aggro_range := 520.0
@export var attack_range := 150.0
@export var attack_cooldown := 2.1
@export var attack_damage := 1
@export var gravity := 620.0

enum State { DORMANT, CHASE, WINDUP, LUNGE, RECOVER, DEAD }

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _attack_hitbox: Area2D = $AttackHitbox

var state := State.DORMANT
var current_health := 18
var player: Node2D
var _state_timer := 0.0
var _attack_timer := 0.0
var _invulnerability_timer := 0.0
var _attack_has_hit := false
var _base_scale := Vector2.ONE
var _health_layer: CanvasLayer
var _health_bar: ProgressBar
var _health_panel: PanelContainer


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("dogana_boss")
	current_health = max_health
	_base_scale = _sprite.scale
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_attack_hitbox.body_entered.connect(_on_attack_hit_body)
	_attack_hitbox.monitoring = false
	_attack_hitbox.monitorable = false
	_build_health_ui()


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

	match state:
		State.DORMANT:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			_sprite.scale = _base_scale * (1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.018)
			if absf(to_player.x) <= aggro_range:
				_awaken()
		State.CHASE:
			velocity.x = signf(to_player.x) * move_speed
			_sprite.rotation = sin(Time.get_ticks_msec() * 0.009) * 0.018
			if _attack_timer <= 0.0 and absf(to_player.x) <= attack_range:
				_begin_windup()
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 1100.0 * delta)
			var pulse := 1.0 + sin(_state_timer * 38.0) * 0.035
			_sprite.scale = _base_scale * Vector2(1.0 / pulse, pulse)
			if _state_timer <= 0.0:
				_begin_lunge(to_player)
		State.LUNGE:
			if _state_timer <= 0.0:
				_begin_recovery()
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 760.0 * delta)
			_sprite.rotation = lerpf(_sprite.rotation, 0.0, delta * 8.0)
			_sprite.scale = _sprite.scale.lerp(_base_scale, delta * 9.0)
			if _state_timer <= 0.0:
				state = State.CHASE

	move_and_slide()


func _awaken() -> void:
	state = State.CHASE
	_attack_timer = 1.35
	if _health_layer:
		_health_layer.visible = true
	boss_awakened.emit()
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(0.55, 1.15, 1.05, 1.0), 0.16)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.36)


func _begin_windup() -> void:
	state = State.WINDUP
	_state_timer = 0.62
	_attack_has_hit = false
	_sprite.modulate = Color(0.58, 1.0, 0.9, 1.0)


func _begin_lunge(to_player: Vector2) -> void:
	state = State.LUNGE
	_state_timer = 0.38
	velocity.x = signf(to_player.x) * lunge_speed
	velocity.y = -75.0
	_attack_hitbox.monitorable = true
	_attack_hitbox.monitoring = true
	_sprite.modulate = Color.WHITE


func _begin_recovery() -> void:
	state = State.RECOVER
	_state_timer = 0.92
	_attack_timer = attack_cooldown
	_attack_hitbox.set_deferred("monitoring", false)
	_attack_hitbox.set_deferred("monitorable", false)


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
	_invulnerability_timer = 0.16
	current_health = maxi(0, current_health - amount)
	if _health_bar:
		_health_bar.value = current_health
	var away := signf(global_position.x - source_position.x)
	velocity.x = away * 130.0
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.6, 0.34, 0.28, 1.0), 0.05)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	if current_health <= 0:
		_die()


func _on_attack_hit_body(body: Node2D) -> void:
	if state != State.LUNGE or _attack_has_hit or not body.is_in_group("player"):
		return
	_attack_has_hit = true
	if body.has_method("take_damage"):
		body.call_deferred("take_damage", attack_damage, global_position)


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_hurtbox.set_deferred("monitoring", false)
	_attack_hitbox.set_deferred("monitoring", false)
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


func _spawn_death_motes() -> void:
	for index in 18:
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
	title.text = "IL CUSTODE SOMMERSO"
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
