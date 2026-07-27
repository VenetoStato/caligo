extends Area2D

const DoganaFx := preload("res://Levels/Scenes/Dogana/dogana_fx.gd")

@export var site_id := "pontile"
@export var display_name := "Pontile della Dogana"
@export var activated := false
@export var art_profile: DoganaArtProfile = preload("res://Levels/Scenes/Dogana/dogana_art_profile.tres")

var _time := 0.0
var _player_near := false
var _light: PointLight2D
var _illustration: Sprite2D
var _approach_aura: CPUParticles2D
var _idle_aura: CPUParticles2D
var _mobile := false
var _draw_budget := 0.0


func _ready() -> void:
	_mobile = DoganaFx.is_mobile()
	collision_layer = 0
	collision_mask = 2
	add_to_group("dogana_grace")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_create_illustrated_visual()
	_create_light()
	_create_auras()
	_update_prompt()
	_refresh_aura_state()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _light and not _mobile:
		var base_energy := 0.88 if activated else 0.12
		_light.energy = base_energy + sin(_time * 2.2) * (0.13 if activated else 0.025)
	if _illustration:
		var pulse := 1.0 + sin(_time * 2.1) * (0.04 if activated or _player_near else 0.015)
		var base_mod := Color(0.55, 1.05, 0.95, 1.0) if activated else Color(0.66, 0.72, 0.7, 0.9)
		if _player_near and not activated:
			base_mod = Color(0.72, 0.88, 0.82, 0.95)
		_illustration.modulate = base_mod
		var base_scale := art_profile.tide_altar_scale if art_profile else Vector2(0.145, 0.145)
		_illustration.scale = base_scale * pulse
	# Android: ridisegna meno spesso se lontano.
	_draw_budget -= delta
	if _player_near or activated or _draw_budget <= 0.0:
		_draw_budget = 0.05 if _mobile else 0.0
		queue_redraw()


func set_activated(value: bool) -> void:
	activated = value
	_update_prompt()
	_refresh_aura_state()
	queue_redraw()


func play_activation_fx() -> void:
	var scene := get_tree().current_scene
	var origin := global_position + Vector2(0, -36)
	DoganaFx.pulse_ring(scene, origin, Color(0.45, 1.0, 0.88, 0.95))
	DoganaFx.burst(scene, origin, Color(0.35, 0.95, 0.82, 0.95), 22, Vector2.UP, 40.0, 130.0, 0.85)
	DoganaFx.burst(scene, origin + Vector2(0, -12), Color(0.95, 0.78, 0.4, 0.9), 12, Vector2.UP, 20.0, 70.0, 0.65)
	var camera := get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", 0.32 if not _mobile else 0.22)
	if _illustration:
		var tween := create_tween()
		tween.tween_property(_illustration, "modulate", Color(1.4, 1.5, 1.3, 1.0), 0.08)
		tween.tween_property(_illustration, "modulate", Color(0.55, 1.05, 0.95, 1.0), 0.35)


func play_rest_fx() -> void:
	## Riposo su altare già attivo.
	var scene := get_tree().current_scene
	var origin := global_position + Vector2(0, -36)
	DoganaFx.pulse_ring(scene, origin, Color(0.55, 0.9, 0.82, 0.8))
	DoganaFx.burst(scene, origin, Color(0.4, 0.92, 0.8, 0.85), 14, Vector2.UP, 25.0, 80.0, 0.6)
	var camera := get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", 0.14)


func get_respawn_position() -> Vector2:
	return global_position + Vector2(0.0, -58.0)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		_update_prompt()
		_refresh_aura_state()
		_play_approach_fx()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		_update_prompt()
		_refresh_aura_state()


func _play_approach_fx() -> void:
	var scene := get_tree().current_scene
	DoganaFx.burst(
		scene,
		global_position + Vector2(0, -28),
		Color(0.42, 0.95, 0.85, 0.7),
		8,
		Vector2.UP,
		12.0,
		40.0,
		0.45
	)


func _update_prompt() -> void:
	var prompt := get_node_or_null("Prompt") as Label
	if prompt:
		prompt.visible = _player_near
		prompt.text = "E / ✦  RIPOSA" if activated else "E / ✦  RISVEGLIA L'ALTARE"
	var name_label := get_node_or_null("Name") as Label
	if name_label:
		name_label.text = display_name.to_upper()
		name_label.modulate = Color(0.75, 0.95, 0.88, 0.95) if activated else Color(0.76, 0.85, 0.82, 0.8)


func _create_light() -> void:
	# PointLight2D è costoso su Android: solo desktop.
	if _mobile:
		return
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.35, 1.0, 0.86, 0.8),
		Color(0.1, 0.5, 0.45, 0.22),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64 if _mobile else 128
	texture.height = 64 if _mobile else 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	_light = PointLight2D.new()
	_light.position = Vector2(0.0, -32.0)
	_light.texture = texture
	_light.texture_scale = 1.65
	_light.color = Color(0.42, 1.0, 0.86, 1.0)
	add_child(_light)


func _create_auras() -> void:
	_idle_aura = DoganaFx.make_soft_aura(self, Vector2(0, -34), Color(0.35, 0.9, 0.8, 0.55), 6)
	_approach_aura = DoganaFx.make_soft_aura(self, Vector2(0, -40), Color(0.95, 0.82, 0.45, 0.65), 10)


func _refresh_aura_state() -> void:
	if _idle_aura:
		_idle_aura.emitting = activated
	if _approach_aura:
		_approach_aura.emitting = _player_near


func _create_illustrated_visual() -> void:
	if art_profile == null or art_profile.tide_altar == null:
		return
	_illustration = Sprite2D.new()
	_illustration.name = "IllustratedAltar"
	_illustration.texture = art_profile.tide_altar
	_illustration.position = art_profile.tide_altar_offset
	_illustration.scale = art_profile.tide_altar_scale
	_illustration.modulate = Color(0.66, 0.72, 0.7, 0.9)
	_illustration.z_index = -1
	add_child(_illustration)


func _draw() -> void:
	var glow := Color(0.34, 0.9, 0.84, 0.82) if activated else Color(0.48, 0.52, 0.5, 0.44)
	if _player_near and not activated:
		glow = Color(0.55, 0.92, 0.82, 0.7)
	var gold := Color(0.9, 0.72, 0.34, 0.95) if activated else Color(0.36, 0.38, 0.36, 0.8)
	var pulse := 1.0 + sin(_time * 2.4) * 0.08

	if _illustration == null:
		draw_polygon(
			PackedVector2Array([
				Vector2(-30, 2), Vector2(-22, -9), Vector2(-12, -14),
				Vector2(12, -14), Vector2(22, -9), Vector2(30, 2),
				Vector2(24, 10), Vector2(-24, 10),
			]),
			PackedColorArray([Color(0.17, 0.21, 0.21, 1.0)])
		)
		draw_arc(Vector2(0, -8), 25.0 * pulse, PI, TAU, 24 if _mobile else 30, glow, 3.0)
		draw_arc(Vector2(0, -8), 17.0 * pulse, PI, TAU, 18 if _mobile else 24, gold, 2.0)
		draw_line(Vector2(-20, 6), Vector2(20, 6), gold, 2.0)

	# Mote procedurali: meno su mobile / se lontani.
	var mote_count := 3 if _mobile else 5
	if not _player_near and not activated:
		mote_count = 2 if _mobile else 3
	for index in mote_count:
		var phase := _time * (1.2 + index * 0.11) + index * 1.37
		var x := sin(phase) * (6.0 + index * 2.0)
		var y := -20.0 - fmod(_time * (14.0 + index * 2.0) + index * 12.0, 54.0)
		var alpha := 0.25 + 0.5 * (1.0 - absf(y + 47.0) / 32.0)
		draw_circle(Vector2(x, y), 2.2 + index * 0.25, Color(glow.r, glow.g, glow.b, alpha))

	if activated:
		var flame := PackedVector2Array()
		var flame_pts := 10 if _mobile else 15
		for index in flame_pts:
			var t := float(index) / float(flame_pts - 1)
			flame.append(Vector2(
				sin(_time * 3.0 + t * 7.0) * (5.0 * (1.0 - t)),
				-16.0 - t * 37.0
			))
		draw_polyline(flame, glow, 3.5, true)
	elif _player_near:
		draw_arc(Vector2(0, -28), 34.0 + sin(_time * 5.0) * 2.0, 0.0, TAU, 20 if _mobile else 28, Color(0.95, 0.8, 0.4, 0.35), 1.6, true)
