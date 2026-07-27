extends Node2D
## Cutscene: arriva in barca (omino DENTRO / dietro lo scafo), poi SALTA LUI sul pontile.
## La barca resta ferma all'attracco — non salta.

signal arrival_finished

const BOAT_TEXTURE := preload("res://Landscape/Sprites/barca.png")
const RIDE_SHEET := preload("res://Spritesbarcaerisveglio.png")
const AmbientScript := preload("res://Levels/Scenes/Dogana/arrival_ambient.gd")

@export var boat_start := Vector2(-440, 552)
@export var boat_dock := Vector2(-130, 552)
@export var land_position := Vector2(70, 447)
@export var approach_duration := 5.6
@export var hold_before_jump := 0.45
@export var jump_duration := 0.85
@export var hold_after_land := 0.4
@export var skip_unlock_delay := 1.4

var _player: CharacterBody2D
var _camera: Node
var _boat: Node2D
var _boat_hull: Sprite2D
var _rider: Sprite2D
var _running := false
var _finished := false
var _can_skip := false
var _elapsed := 0.0
var _ride_frame_timer := 0.0
var _ambient: Node
var _player_collision_layer := 0
var _player_collision_mask := 0
var _active_tweens: Array[Tween] = []
var _skip_label: Label
var _player_anim: AnimationPlayer
var _player_was_visible := true
var _player_base_z := 2
var _sprite_base_pos := Vector2.ZERO
var _sprite_base_scale := Vector2.ONE
## Punto di uscita: sopra il bordo della barca (niente gambe sotto lo scafo).
var _seat_offset := Vector2(8, -18)


func _ready() -> void:
	add_to_group("dogana_arrival_cutscene")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_process_unhandled_input(false)
	call_deferred("_begin")


func _begin() -> void:
	if _finished:
		return
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null:
		_player = get_parent().get_node_or_null("Player") as CharacterBody2D
	if _player == null:
		_finish()
		return
	_camera = _player.get_node_or_null("Camera2D")
	_player_anim = _player.get_node_or_null("anim") as AnimationPlayer
	_player_base_z = _player.z_index
	var sprite := _player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		_sprite_base_pos = sprite.position
		_sprite_base_scale = sprite.scale
	_lock_player(true)
	_spawn_boat_rig()
	_hide_real_player(true)
	_build_skip_hint()
	if _camera and _camera.has_method("set_camera_target"):
		_camera.call("set_camera_target", _boat, 10)
	_hide_tutorial(true)
	_running = true
	_elapsed = 0.0
	set_process(true)
	set_process_unhandled_input(true)
	_play_sequence()


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	if _elapsed >= skip_unlock_delay:
		_can_skip = true
		if _skip_label:
			_skip_label.visible = true
	# Animazione remata sul foglio (frame 0-5): omino GIÀ dentro la barca.
	if _rider and _rider.visible:
		_ride_frame_timer += delta
		if _ride_frame_timer >= 0.16:
			_ride_frame_timer = 0.0
			_rider.frame = (_rider.frame + 1) % 6


func _unhandled_input(event: InputEvent) -> void:
	if not _running or not _can_skip or _finished:
		return
	var pressed: bool = false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed:
		_skip_to_end()


func _play_sequence() -> void:
	await _drift_to_dock()
	if _finished:
		return
	_trigger_ambient()
	await _prepare_jump_from_boat()
	if _finished:
		return
	await get_tree().create_timer(hold_before_jump).timeout
	if _finished:
		return
	await _player_jumps_to_pier()
	if _finished:
		return
	await get_tree().create_timer(hold_after_land).timeout
	if _finished:
		return
	_finish()


func _drift_to_dock() -> void:
	if _boat == null:
		return
	_boat.global_position = boat_start
	var tween := create_tween()
	_track_tween(tween)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_move_boat_along_path, 0.0, 1.0, approach_duration)
	await tween.finished
	if _finished or _boat == null:
		return
	_boat.global_position = boat_dock
	_splash_near_boat(55.0)
	await get_tree().create_timer(0.25).timeout


func _move_boat_along_path(progress: float) -> void:
	if _boat == null or not is_instance_valid(_boat):
		return
	var t := clampf(progress, 0.0, 1.0)
	var x := lerpf(boat_start.x, boat_dock.x, t)
	# Leggero bob: solo la barca intera, piccolo, non un "salto".
	var y := lerpf(boat_start.y, boat_dock.y, t) + sin(t * PI * 6.0) * 2.2
	_boat.global_position = Vector2(x, y)
	if fmod(t * approach_duration, 0.9) < 0.04:
		_splash_near_boat(22.0 + t * 28.0)


func _prepare_jump_from_boat() -> void:
	if _boat == null or _player == null:
		return
	_boat.global_position = boat_dock
	# Resta sul foglio remata fino al salto: niente omino "sotto" lo scafo.
	if _rider:
		_rider.visible = true
	if _boat_hull:
		_boat_hull.visible = false
	_hide_real_player(true)
	if _camera and _camera.has_method("set_camera_target"):
		_camera.call("set_camera_target", _boat, 0)
	await get_tree().create_timer(0.25).timeout


func _player_jumps_to_pier() -> void:
	if _player == null:
		return
	if _boat:
		_boat.global_position = boat_dock
	# Passaggio: foglio remata → scafo + player che ESCE verso l'alto (davanti).
	if _rider:
		_rider.visible = false
	if _boat_hull:
		_boat_hull.visible = true
		_boat_hull.z_index = 3
	_hide_real_player(false)
	_set_seated_pose(false)
	_player.z_index = 6
	_face_player(true)
	if _player_anim and _player_anim.has_animation("Jump"):
		_player_anim.play("Jump")
	if _camera and _camera.has_method("set_camera_target"):
		_camera.call("set_camera_target", _player, 0)

	# Parte dal bordo superiore della barca, non da sotto.
	var start := boat_dock + _seat_offset
	_player.global_position = start
	var rise := start + Vector2(18, -42)
	var peak := Vector2(
		lerpf(start.x, land_position.x, 0.48),
		minf(start.y, land_position.y) - 92.0
	)
	var tween := create_tween()
	_track_tween(tween)
	# Prima si alza fuori dalla barca, poi arco sul pontile.
	tween.tween_property(_player, "global_position", rise, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(p: float) -> void:
		if _player == null:
			return
		var a := (1.0 - p) * (1.0 - p)
		var b := 2.0 * (1.0 - p) * p
		var c := p * p
		_player.global_position = rise * a + peak * b + land_position * c
		_player.velocity = Vector2.ZERO
		if _boat:
			_boat.global_position = boat_dock
	, 0.0, 1.0, jump_duration)
	await tween.finished
	if _player:
		_player.global_position = land_position
		_player.velocity = Vector2.ZERO
		_player.z_index = _player_base_z
		var sprite := _player.get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			sprite.rotation = 0.0
			sprite.position = _sprite_base_pos
			sprite.scale = _sprite_base_scale
		if _player_anim and _player_anim.has_animation("Idle"):
			_player_anim.play("Idle")
	if _camera and _camera.has_method("add_shake"):
		_camera.call("add_shake", 0.12)


func _skip_to_end() -> void:
	if _finished:
		return
	_running = false
	set_process_unhandled_input(false)
	_kill_tweens()
	if _boat:
		_boat.global_position = boat_dock
	if _rider:
		_rider.visible = false
	if _boat_hull:
		_boat_hull.visible = true
	_hide_real_player(false)
	if _player:
		_set_seated_pose(false)
		_player.global_position = land_position
		_player.velocity = Vector2.ZERO
		_player.z_index = _player_base_z
	if _camera and _camera.has_method("set_camera_target") and _player:
		_camera.call("set_camera_target", _player, 0)
	_trigger_ambient()
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_running = false
	set_process(false)
	set_process_unhandled_input(false)
	_kill_tweens()
	_lock_player(false)
	if _skip_label and is_instance_valid(_skip_label):
		_skip_label.visible = false
	_hide_real_player(false)
	if _player:
		_set_seated_pose(false)
		_player.set_meta("arrival_riding", false)
		_player.set_meta("skip_initial_fade", true)
		_player.set_meta("skip_wake_animation", true)
		_player.global_position = land_position
		_player.velocity = Vector2.ZERO
		_player.z_index = _player_base_z
		var sprite := _player.get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			sprite.rotation = 0.0
			sprite.position = _sprite_base_pos
			sprite.scale = _sprite_base_scale
			sprite.visible = true
		if _player.has_method("set_checkpoint"):
			_player.call("set_checkpoint", land_position)
		if _player_anim and _player_anim.has_animation("Idle"):
			_player_anim.play("Idle")
	if _camera and _camera.has_method("set_camera_target") and _player:
		_camera.call("set_camera_target", _player, 6)
	_hide_tutorial(false)
	if _boat:
		_boat.global_position = boat_dock
	arrival_finished.emit()


func _spawn_boat_rig() -> void:
	# Nodo semplice: NESSUNA fisica. La barca non può "saltare".
	_boat = Node2D.new()
	_boat.name = "ArrivalBoat"
	_boat.z_index = 3
	var gameplay := get_parent().get_node_or_null("Gameplay")
	if gameplay:
		gameplay.add_child(_boat)
	else:
		add_child(_boat)
	_boat.global_position = boat_start

	# Foglio ufficiale: omino GIÀ dentro la barca (frame 0-5).
	_rider = Sprite2D.new()
	_rider.name = "RiderInBoat"
	_rider.texture = RIDE_SHEET
	_rider.hframes = 6
	_rider.vframes = 5
	_rider.frame = 0
	_rider.centered = true
	_rider.scale = Vector2(0.11, 0.11)
	_rider.position = Vector2(0, -8)
	_rider.z_index = 1
	_boat.add_child(_rider)

	# Scafo vuoto alla STESSA scala del foglio remata (~70px), non il barcone 0.28.
	# barca.png ha lo scafo in basso: recenter minimo + scale da dinghy.
	_boat_hull = Sprite2D.new()
	_boat_hull.name = "Hull"
	_boat_hull.texture = BOAT_TEXTURE
	_boat_hull.centered = true
	_boat_hull.scale = Vector2(0.118, 0.118)
	_boat_hull.position = Vector2(0, -22)
	_boat_hull.z_index = 4
	_boat_hull.visible = false
	_boat_hull.modulate = Color(0.9, 0.91, 0.89, 1.0)
	_boat.add_child(_boat_hull)


func _hide_real_player(hidden: bool) -> void:
	if _player == null:
		return
	var sprite := _player.get_node_or_null("Sprite2D") as Sprite2D
	if hidden:
		_player_was_visible = _player.visible
		_player.visible = true
		if sprite:
			sprite.visible = false
		_player.set_meta("arrival_riding", true)
	else:
		_player.visible = true
		if sprite:
			sprite.visible = true
		_player.set_meta("arrival_riding", false)


func _set_seated_pose(sitting: bool) -> void:
	if _player == null:
		return
	var sprite := _player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	if sitting:
		sprite.position = _sprite_base_pos + Vector2(0, 10)
		sprite.scale = Vector2(_sprite_base_scale.x, _sprite_base_scale.y * 0.78)
	else:
		sprite.position = _sprite_base_pos
		sprite.scale = _sprite_base_scale
		sprite.rotation = 0.0


func _face_player(right: bool) -> void:
	if _player == null:
		return
	if "facing_right" in _player:
		_player.set("facing_right", right)
	var sprite := _player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.flip_h = not right


func _lock_player(locked: bool) -> void:
	if _player == null:
		return
	_player.set_meta("arrival_locked", locked)
	if locked:
		_player.velocity = Vector2.ZERO
		_player.set_physics_process(false)
		_player_collision_layer = _player.collision_layer
		_player_collision_mask = _player.collision_mask
		_player.collision_layer = 0
		_player.collision_mask = 0
		if "is_invincible" in _player:
			_player.set("is_invincible", true)
			_player.set("invincibility_timer", 99.0)
	else:
		_player.set_physics_process(true)
		# Mai lasciare layer 0: se il lock è partito prima del ready del player, ripristina i default.
		_player.collision_layer = _player_collision_layer if _player_collision_layer != 0 else 2
		_player.collision_mask = _player_collision_mask if _player_collision_mask != 0 else 1
		if "is_invincible" in _player:
			_player.set("is_invincible", true)
			_player.set("invincibility_timer", 1.2)


func _exit_tree() -> void:
	# Se la cutscene viene rimossa a metà (test/skip forzato), sblocca il player.
	if _player and is_instance_valid(_player) and bool(_player.get_meta("arrival_locked", false)):
		_lock_player(false)
		_hide_real_player(false)
		_player.set_meta("arrival_riding", false)
		_player.global_position = land_position
		_player.velocity = Vector2.ZERO
		_player.z_index = _player_base_z
		if _camera and is_instance_valid(_camera) and _camera.has_method("set_camera_target"):
			_camera.call("set_camera_target", _player, 0)
	if not _finished:
		_hide_tutorial(false)


func _hide_tutorial(hidden: bool) -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	if root == null:
		return
	var tutorial := root.get_node_or_null("TutorialHints")
	if tutorial == null:
		return
	if hidden:
		if tutorial.has_method("set_armed"):
			tutorial.call("set_armed", false)
		elif "visible" in tutorial:
			tutorial.visible = false
	else:
		if tutorial.has_method("arm_tutorial"):
			tutorial.call("arm_tutorial")
		else:
			tutorial.visible = true


func _trigger_ambient() -> void:
	if _ambient != null and is_instance_valid(_ambient):
		return
	_ambient = Node2D.new()
	_ambient.set_script(AmbientScript)
	_ambient.name = "ArrivalAmbient"
	var gameplay := get_parent().get_node_or_null("Gameplay")
	if gameplay:
		gameplay.add_child(_ambient)
	else:
		add_child(_ambient)
	if _ambient.has_method("play_arrival_burst"):
		# Burst dalle bricole del pontile + stormo verso la Salute.
		_ambient.call("play_arrival_burst", Vector2(120, 470))


func _splash_near_boat(impulse: float) -> void:
	var x := boat_dock.x
	if _boat:
		x = _boat.global_position.x
	for water in get_tree().get_nodes_in_group("water"):
		if water and water.has_method("splash_at"):
			water.call("splash_at", x, impulse, 58.0)
			break


func _build_skip_hint() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ArrivalSkipHint"
	layer.layer = 80
	add_child(layer)
	_skip_label = Label.new()
	_skip_label.text = "PREMI UN TASTO PER SALTARE"
	_skip_label.visible = false
	_skip_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_skip_label.offset_top = -48.0
	_skip_label.offset_bottom = -18.0
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_label.add_theme_font_size_override("font_size", 13)
	_skip_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.74, 0.72))
	_skip_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_skip_label.add_theme_constant_override("outline_size", 2)
	layer.add_child(_skip_label)


func _track_tween(tween: Tween) -> void:
	_active_tweens.append(tween)


func _kill_tweens() -> void:
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
