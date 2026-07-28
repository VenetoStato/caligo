extends Area2D
## Altare / Site of Grace: luce stabile + particelle dorate che convergono verso l'alto.
## Niente pulse di scala, niente quadretti blu (sempre texture radiale soft).

const DoganaFx := preload("res://Levels/Scenes/Dogana/dogana_fx.gd")

@export var site_id := "pontile"
@export var display_name := "Pontile della Dogana"
@export var activated := false
@export var art_profile: DoganaArtProfile = preload("res://Levels/Scenes/Dogana/dogana_art_profile.tres")

var _time := 0.0
var _player_near := false
var _light: PointLight2D
var _illustration: Sprite2D
var _rise_column: CPUParticles2D
var _inbound_motes: CPUParticles2D
var _ember_core: CPUParticles2D
var _mote_tex: GradientTexture2D
var _mobile := false


func _ready() -> void:
	_mobile = DoganaFx.is_mobile()
	collision_layer = 0
	collision_mask = 2
	add_to_group("dogana_grace")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_mote_tex = _make_mote_texture()
	_create_illustrated_visual()
	_create_light()
	_create_grace_particles()
	_update_prompt()
	_refresh_particle_state()


func _process(delta: float) -> void:
	_time += delta
	if _light and not _mobile:
		# Luce calda stabile (micro-variazione, non pulse evidente).
		var base := 0.95 if activated else (0.35 if _player_near else 0.14)
		_light.energy = base + sin(_time * 0.7) * 0.03
	if _illustration:
		var base_mod := Color(1.05, 0.92, 0.62, 1.0) if activated else Color(0.72, 0.74, 0.7, 0.92)
		if _player_near and not activated:
			base_mod = Color(0.88, 0.82, 0.64, 0.96)
		_illustration.modulate = base_mod
		var base_scale := art_profile.tide_altar_scale if art_profile else Vector2(0.145, 0.145)
		_illustration.scale = base_scale


func set_activated(value: bool) -> void:
	activated = value
	_update_prompt()
	_refresh_particle_state()


func play_activation_fx() -> void:
	var scene := get_tree().current_scene
	var origin := global_position + Vector2(0, -36)
	DoganaFx.burst(scene, origin, Color(0.95, 0.82, 0.4, 0.95), 18, Vector2.UP, 35.0, 110.0, 0.8)
	DoganaFx.burst(scene, origin + Vector2(0, -10), Color(1.0, 0.95, 0.7, 0.9), 10, Vector2.UP, 18.0, 60.0, 0.55)
	var camera := get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", 0.28 if not _mobile else 0.18)
	if _illustration:
		var tween := create_tween()
		tween.tween_property(_illustration, "modulate", Color(1.35, 1.2, 0.75, 1.0), 0.08)
		tween.tween_property(_illustration, "modulate", Color(1.05, 0.92, 0.62, 1.0), 0.4)


func play_rest_fx() -> void:
	var scene := get_tree().current_scene
	var origin := global_position + Vector2(0, -36)
	DoganaFx.burst(scene, origin, Color(0.95, 0.85, 0.5, 0.85), 12, Vector2.UP, 22.0, 70.0, 0.55)
	var camera := get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", 0.12)


func get_respawn_position() -> Vector2:
	return global_position + Vector2(0.0, -58.0)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		_update_prompt()
		_refresh_particle_state()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		_update_prompt()
		_refresh_particle_state()


func _update_prompt() -> void:
	var prompt := get_node_or_null("Prompt") as Label
	if prompt:
		prompt.visible = _player_near
		prompt.text = "E / ✦  RIPOSA" if activated else "E / ✦  RISVEGLIA L'ALTARE"
	var name_label := get_node_or_null("Name") as Label
	if name_label:
		name_label.text = display_name.to_upper()
		name_label.modulate = Color(0.92, 0.84, 0.55, 0.95) if activated else Color(0.78, 0.8, 0.74, 0.8)


func _make_mote_texture() -> GradientTexture2D:
	# Sempre cerchio soft: niente quadretti CPUParticles default.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.95, 0.7, 1.0),
		Color(0.95, 0.78, 0.35, 0.55),
		Color(0.7, 0.45, 0.15, 0.12),
		Color(0.2, 0.1, 0.0, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 32 if _mobile else 48
	tex.height = 32 if _mobile else 48
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _create_light() -> void:
	if _mobile:
		return
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.88, 0.45, 0.75),
		Color(0.7, 0.45, 0.12, 0.2),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	_light = PointLight2D.new()
	_light.position = Vector2(0.0, -36.0)
	_light.texture = texture
	_light.texture_scale = 1.55
	_light.color = Color(1.0, 0.86, 0.5, 1.0)
	_light.energy = 0.14
	add_child(_light)


func _create_grace_particles() -> void:
	# Colonna che sale dal suolo (Site of Grace).
	_rise_column = _make_particles("GraceRise", Vector2(0, -8))
	_rise_column.amount = 10 if _mobile else 18
	_rise_column.lifetime = 2.4
	_rise_column.preprocess = 2.4
	_rise_column.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_rise_column.emission_sphere_radius = 10.0
	_rise_column.direction = Vector2(0, -1)
	_rise_column.spread = 18.0
	_rise_column.gravity = Vector2(0, -22)
	_rise_column.initial_velocity_min = 12.0
	_rise_column.initial_velocity_max = 28.0
	_rise_column.scale_amount_min = 0.22
	_rise_column.scale_amount_max = 0.48
	_rise_column.color = Color(1.0, 0.88, 0.45, 0.7)
	_apply_fade_ramp(_rise_column)

	# Mote che arrivano da intorno e convergono verso l'altare / salgono.
	_inbound_motes = _make_particles("GraceInbound", Vector2(0, -20))
	_inbound_motes.amount = 14 if _mobile else 26
	_inbound_motes.lifetime = 2.8
	_inbound_motes.preprocess = 2.8
	_inbound_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_inbound_motes.emission_sphere_radius = 78.0
	_inbound_motes.direction = Vector2(0, -1)
	_inbound_motes.spread = 55.0
	_inbound_motes.gravity = Vector2(0, -8)
	_inbound_motes.radial_accel_min = -28.0
	_inbound_motes.radial_accel_max = -12.0
	_inbound_motes.tangential_accel_min = -6.0
	_inbound_motes.tangential_accel_max = 6.0
	_inbound_motes.initial_velocity_min = 4.0
	_inbound_motes.initial_velocity_max = 14.0
	_inbound_motes.scale_amount_min = 0.12
	_inbound_motes.scale_amount_max = 0.32
	_inbound_motes.color = Color(0.95, 0.8, 0.4, 0.55)
	_apply_fade_ramp(_inbound_motes)

	# Nucleo caldo vicino alla fiamma.
	_ember_core = _make_particles("GraceCore", Vector2(0, -34))
	_ember_core.amount = 6 if _mobile else 10
	_ember_core.lifetime = 1.6
	_ember_core.preprocess = 1.6
	_ember_core.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_ember_core.emission_sphere_radius = 6.0
	_ember_core.direction = Vector2(0, -1)
	_ember_core.spread = 25.0
	_ember_core.gravity = Vector2(0, -30)
	_ember_core.initial_velocity_min = 8.0
	_ember_core.initial_velocity_max = 20.0
	_ember_core.scale_amount_min = 0.18
	_ember_core.scale_amount_max = 0.4
	_ember_core.color = Color(1.0, 0.95, 0.7, 0.85)
	_apply_fade_ramp(_ember_core)


func _make_particles(node_name: String, local_pos: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = node_name
	p.position = local_pos
	p.texture = _mote_tex
	p.z_index = 3
	p.emitting = false
	p.local_coords = true
	p.explosiveness = 0.0
	p.randomness = 0.75
	add_child(p)
	return p


func _apply_fade_ramp(p: CPUParticles2D) -> void:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.7, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.75),
		Color(1, 1, 1, 0.0),
	])
	p.color_ramp = ramp


func _refresh_particle_state() -> void:
	# Idle: colonna + inbound leggeri. Vicino/attivo: tutto acceso, più denso.
	var idle_on := true
	var full_on := activated or _player_near
	if _rise_column:
		_rise_column.emitting = idle_on
		_rise_column.amount = (14 if full_on else 8) if _mobile else (22 if full_on else 14)
		_rise_column.color = Color(1.0, 0.9, 0.48, 0.85 if activated else 0.55)
	if _inbound_motes:
		_inbound_motes.emitting = idle_on
		_inbound_motes.amount = (18 if full_on else 10) if _mobile else (30 if full_on else 18)
		_inbound_motes.radial_accel_min = -38.0 if full_on else -22.0
		_inbound_motes.radial_accel_max = -16.0 if full_on else -10.0
	if _ember_core:
		_ember_core.emitting = activated or _player_near


func _create_illustrated_visual() -> void:
	if art_profile == null or art_profile.tide_altar == null:
		return
	_illustration = Sprite2D.new()
	_illustration.name = "IllustratedAltar"
	_illustration.texture = art_profile.tide_altar
	_illustration.position = art_profile.tide_altar_offset
	_illustration.scale = art_profile.tide_altar_scale
	_illustration.modulate = Color(0.72, 0.74, 0.7, 0.92)
	_illustration.z_index = -1
	add_child(_illustration)
