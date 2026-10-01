extends Area2D
## Altare materico: pietra umida, AO a terra, fiamma teal della conca.
## Da lontano sobrio; vicino respira e rivela la materia del PNG.

const DoganaFx := preload("res://Levels/Scenes/Dogana/dogana_fx.gd")

# Quasi-naturali: non lavare il dettaglio del PNG.
# Conserva il linguaggio originale dell'altare: brace dorata, non una luce teal generica.
const COL_IDLE := Color(0.76, 0.74, 0.65, 0.92)
const COL_ACTIVE := Color(1.05, 0.92, 0.62, 1.0)
const COL_NEAR := Color(0.92, 0.82, 0.58, 0.97)
const COL_CHARGE := Color(1.38, 1.12, 0.62, 1.0)
const COL_MOTE := Color(1.0, 0.84, 0.4, 0.62)
const COL_MOTE_CHARGE := Color(1.0, 0.94, 0.66, 0.82)
const COL_FLAME := Color(1.0, 0.78, 0.34, 1.0)

@export var site_id := "pontile"
@export var display_name := "Pontile della Dogana"
@export var activated := false
@export var art_profile: DoganaArtProfile = preload("res://Levels/Scenes/Dogana/dogana_art_profile.tres")

var _time := 0.0
var _player_near := false
var _light: PointLight2D
var _illustration: Sprite2D
var _plinth: Node2D
var _wet_sheen: Polygon2D
var _flame_core: Polygon2D
var _rise_column: CPUParticles2D
var _inbound_motes: CPUParticles2D
var _ember_core: CPUParticles2D
var _drip: CPUParticles2D
var _mote_tex: GradientTexture2D
var _mobile := false
var _charge_progress := 0.0
var _charging := false
var _charge_pulse_cd := 0.0
var _base_scale := Vector2(0.158, 0.158)


func _ready() -> void:
	_mobile = DoganaFx.is_mobile()
	collision_layer = 0
	collision_mask = 2
	add_to_group("dogana_grace")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if art_profile:
		_base_scale = art_profile.tide_altar_scale
	_mote_tex = _make_mote_texture()
	_create_material_plinth()
	_create_illustrated_visual()
	_create_flame_core()
	_create_light()
	_create_grace_particles()
	_update_prompt()
	_refresh_particle_state()
	_sync_process()


func _process(delta: float) -> void:
	_time += delta
	if _charging:
		_charge_pulse_cd = maxf(0.0, _charge_pulse_cd - delta)
	if _light and not _mobile:
		var base := _light_base_energy()
		var pulse := sin(_time * (1.1 + _charge_progress * 2.2)) * (0.012 + _charge_progress * 0.04)
		_light.energy = maxf(0.0, base + pulse)
		_light.texture_scale = lerpf(0.7, 1.15, _charge_progress)
		_light.visible = _light.energy > 0.02
	if _illustration:
		_illustration.modulate = _illustration_modulate()
		var breath := 1.0
		if _player_near or _charging:
			breath = 1.0 + sin(_time * 1.35) * 0.008 + _charge_progress * 0.04
		_illustration.scale = _base_scale * breath
	if _wet_sheen:
		_wet_sheen.modulate.a = 0.22 + sin(_time * 1.8) * 0.06 + _charge_progress * 0.12
	if _flame_core:
		var flame_live := _player_near or _charging or activated
		_flame_core.visible = flame_live
		if flame_live:
			var flicker := 1.0 + sin(_time * 5.2) * 0.08 + sin(_time * 9.1) * 0.04
			_flame_core.scale = Vector2(1.0 / flicker, flicker)
			_flame_core.modulate.a = 0.5 + (_charge_progress * 0.35) + sin(_time * 3.0) * 0.08
	if _plinth:
		_plinth.modulate = Color(1, 1, 1, 1).lerp(Color(1.05, 1.08, 1.04, 1), _charge_progress * 0.35)
	_update_site_name(delta)
	if _player_near or _charging:
		queue_redraw()


func set_activated(value: bool) -> void:
	activated = value
	if _illustration and not _player_near and not _charging:
		_illustration.modulate = COL_ACTIVE if activated else COL_IDLE
	_update_prompt()
	_refresh_particle_state()
	_sync_process()


func set_charge_progress(progress: float) -> void:
	var previous := _charge_progress
	_charge_progress = clampf(progress, 0.0, 1.0)
	_charging = _charge_progress > 0.001
	_update_prompt()
	_refresh_particle_state()
	_sync_process()
	if _charging and _charge_progress > 0.22 and _charge_pulse_cd <= 0.0 and _charge_progress > previous:
		_charge_pulse_cd = lerpf(0.48, 0.18, _charge_progress)
		var scene := get_tree().current_scene
		if scene:
			DoganaFx.burst(
				scene,
				global_position + Vector2(randf_range(-10, 10), -40 + randf_range(-8, 4)),
				COL_MOTE_CHARGE,
				3 + int(_charge_progress * 3.0),
				Vector2.UP,
				10.0 + _charge_progress * 16.0,
				26.0 + _charge_progress * 36.0,
				0.32
			)


func cancel_charge() -> void:
	if not _charging and _charge_progress <= 0.0:
		return
	_charge_progress = 0.0
	_charging = false
	_update_prompt()
	_refresh_particle_state()
	_sync_process()


func play_activation_fx() -> void:
	var scene := get_tree().current_scene
	var origin := global_position + Vector2(0, -40)
	DoganaFx.burst(scene, origin, Color(0.4, 0.95, 0.85, 0.95), 18, Vector2.UP, 30.0, 110.0, 0.8)
	DoganaFx.burst(scene, origin + Vector2(0, -12), Color(0.85, 0.95, 0.8, 0.85), 12, Vector2.UP, 16.0, 60.0, 0.55)
	DoganaFx.pulse_ring(scene, origin, Color(0.45, 0.9, 0.8, 0.72))
	var camera := get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", 0.3 if not _mobile else 0.18)
	if _illustration:
		var tween := create_tween()
		tween.tween_property(_illustration, "modulate", Color(1.15, 1.2, 1.12, 1.0), 0.08)
		tween.tween_property(_illustration, "modulate", COL_ACTIVE, 0.6)
	_charge_progress = 0.0
	_charging = false
	_refresh_particle_state()
	_sync_process()


func play_rest_fx() -> void:
	var scene := get_tree().current_scene
	var origin := global_position + Vector2(0, -40)
	DoganaFx.burst(scene, origin, Color(0.5, 0.92, 0.84, 0.88), 14, Vector2.UP, 18.0, 70.0, 0.55)
	DoganaFx.pulse_ring(scene, origin, Color(0.42, 0.88, 0.8, 0.5))
	var camera := get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", 0.12)
	_charge_progress = 0.0
	_charging = false
	_refresh_particle_state()
	_sync_process()


func get_respawn_position() -> Vector2:
	# Parte un po' sopra il piano: lo snap ai piedi evita di spawnare dentro il dock.
	var lift := -28.0 if site_id == "fortuna" else -22.0
	return global_position + Vector2(0.0, lift)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		_update_prompt()
		_refresh_particle_state()
		_sync_process()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		cancel_charge()
		_update_prompt()
		_refresh_particle_state()
		_sync_process()


func _sync_process() -> void:
	set_process(_player_near or _charging or activated)


func _light_base_energy() -> float:
	if _charging:
		return lerpf(0.42, 1.2, _charge_progress)
	if _player_near:
		return 0.72 if activated else 0.34
	if activated:
		return 0.4
	return 0.0


func _illustration_modulate() -> Color:
	var base_mod := COL_ACTIVE if activated else COL_IDLE
	if _player_near and not activated:
		base_mod = COL_NEAR
	if _charging:
		base_mod = base_mod.lerp(COL_CHARGE, _charge_progress * 0.45)
	return base_mod


func _update_prompt() -> void:
	var prompt := get_node_or_null("Prompt") as Label
	if prompt:
		# Il nodo resta come ancora di posizione, ma non scrive piu' nulla: il
		# richiamo dell'altare e' il segno disegnato in _draw, non una lettera.
		prompt.visible = _player_near
		prompt.text = ""
	queue_redraw()


## Segno di richiamo e anello di carica, entrambi disegnati sull'altare.
func _draw() -> void:
	var center := Vector2(0, -34)
	var radius := 15.0
	# Niente rombo sopra l'altare: il prompt e' solo il tasto E del tutorial,
	# e anche quello senza icona. L'altare si legge dalla luce della conca.
	if _charge_progress <= 0.01:
		return
	draw_arc(center, radius, -PI * 0.5, TAU - PI * 0.5, 30, Color(0.05, 0.08, 0.08, 0.35), 2.0, true)
	draw_arc(
		center,
		radius,
		-PI * 0.5,
		-PI * 0.5 + TAU * _charge_progress,
		30,
		COL_CHARGE,
		2.4,
		true
	)


## Il nome inciso si legge solo quando gli sei accanto, e sfuma da solo.
func _update_site_name(delta: float) -> void:
	var name_label := get_node_or_null("Name") as Label
	if name_label == null:
		return
	name_label.text = display_name.to_upper()
	var tint := Color(0.72, 0.9, 0.86, 0.9) if activated else Color(0.62, 0.74, 0.72, 0.75)
	tint.a *= 1.0 if _player_near else 0.0
	name_label.modulate = name_label.modulate.lerp(tint, clampf(delta * 3.4, 0.0, 1.0))


func _make_mote_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.85, 1.0, 0.95, 1.0),
		Color(0.35, 0.9, 0.8, 0.55),
		Color(0.12, 0.4, 0.38, 0.12),
		Color(0.02, 0.06, 0.06, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 28 if _mobile else 44
	tex.height = 28 if _mobile else 44
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _create_material_plinth() -> void:
	_plinth = Node2D.new()
	_plinth.name = "MaterialPlinth"
	_plinth.z_index = 1
	# Il basamento occupa lo spazio sopra la quota di collisione, non sotto il pontile.
	_plinth.position = Vector2(0, -16)
	add_child(_plinth)

	# AO morbido a terra (più anelli = contatto materico).
	for i in 3:
		var ao := Polygon2D.new()
		var w := 38.0 + float(i) * 14.0
		var h := 5.0 + float(i) * 3.0
		ao.polygon = PackedVector2Array([
			Vector2(-w, 0), Vector2(w, 0), Vector2(w * 0.72, h), Vector2(-w * 0.72, h),
		])
		ao.color = Color(0.01, 0.03, 0.035, 0.38 - float(i) * 0.1)
		ao.z_index = -1
		_plinth.add_child(ao)

	# Basamento pietra: volume sotto i piedi dell'altare.
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([
		Vector2(-46, -2), Vector2(46, -2), Vector2(52, 10), Vector2(40, 16),
		Vector2(-40, 16), Vector2(-52, 10),
	])
	base.color = Color(0.14, 0.18, 0.17, 1.0)
	_plinth.add_child(base)

	var face := Polygon2D.new()
	face.polygon = PackedVector2Array([
		Vector2(-40, 4), Vector2(40, 4), Vector2(36, 14), Vector2(-36, 14),
	])
	face.color = Color(0.08, 0.11, 0.11, 1.0)
	_plinth.add_child(face)

	# Giunti pietra.
	for x in [-22.0, 0.0, 22.0]:
		var joint := Line2D.new()
		joint.width = 1.2
		joint.default_color = Color(0.04, 0.06, 0.06, 0.7)
		joint.points = PackedVector2Array([Vector2(x, 4), Vector2(x * 0.92, 14)])
		_plinth.add_child(joint)

	# Bordo umido / sale sulla faccia superiore.
	var top_edge := Line2D.new()
	top_edge.width = 2.4
	top_edge.default_color = Color(0.55, 0.62, 0.58, 0.55)
	top_edge.points = PackedVector2Array([Vector2(-44, -1), Vector2(44, -1)])
	_plinth.add_child(top_edge)

	_wet_sheen = Polygon2D.new()
	_wet_sheen.polygon = PackedVector2Array([
		Vector2(-34, -1), Vector2(34, -1), Vector2(28, 3), Vector2(-28, 3),
	])
	_wet_sheen.color = Color(0.55, 0.85, 0.8, 0.25)
	_plinth.add_child(_wet_sheen)

	# Anelli di ormeggio laterali (dettaglio materico).
	for side in [-1.0, 1.0]:
		var ring := Line2D.new()
		ring.width = 2.0
		ring.default_color = Color(0.42, 0.36, 0.22, 0.85)
		var cx: float = side * 48.0
		ring.points = PackedVector2Array([
			Vector2(cx, 2), Vector2(cx + side * 6, 6), Vector2(cx + side * 4, 12), Vector2(cx, 10),
		])
		_plinth.add_child(ring)

	# Pozzanghera riflesso laguna sotto il basamento.
	var puddle := Polygon2D.new()
	puddle.z_index = -2
	puddle.polygon = PackedVector2Array([
		Vector2(-56, 12), Vector2(56, 12), Vector2(42, 20), Vector2(-42, 20),
	])
	puddle.color = Color(0.08, 0.22, 0.24, 0.35)
	_plinth.add_child(puddle)

	var puddle_shine := Polygon2D.new()
	puddle_shine.z_index = -1
	puddle_shine.polygon = PackedVector2Array([
		Vector2(-18, 13), Vector2(22, 13), Vector2(14, 16), Vector2(-12, 16),
	])
	puddle_shine.color = Color(0.45, 0.8, 0.78, 0.18)
	_plinth.add_child(puddle_shine)


func _create_light() -> void:
	if _mobile:
		return
	var gradient := Gradient.new()
	# Brace dorata nella conca: ricca da vicino, ma limitata alla base dell'altare.
	gradient.colors = PackedColorArray([
		Color(1.0, 0.84, 0.4, 0.72),
		Color(0.88, 0.48, 0.12, 0.16),
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
	_light.position = Vector2(0.0, -52.0)
	_light.texture = texture
	_light.texture_scale = 1.12
	_light.color = COL_FLAME
	_light.energy = 0.0
	_light.visible = false
	_light.z_index = 1
	_light.shadow_enabled = false
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(_light)


func _create_flame_core() -> void:
	# Fiamma piccola e materica: il punto d'interazione resta leggibile senza alone enorme.
	_flame_core = Polygon2D.new()
	_flame_core.name = "GraceFlameCore"
	_flame_core.position = Vector2(0, -50)
	_flame_core.polygon = PackedVector2Array([
		Vector2(0, -18), Vector2(8, -4), Vector2(5, 8), Vector2(0, 12), Vector2(-5, 8), Vector2(-8, -4),
	])
	_flame_core.color = Color(1.0, 0.82, 0.38, 0.78)
	_flame_core.z_index = 4
	_flame_core.visible = false
	add_child(_flame_core)


func _create_grace_particles() -> void:
	_rise_column = _make_particles("GraceRise", Vector2(0, -42))
	_rise_column.amount = 5 if _mobile else 9
	_rise_column.lifetime = 1.6
	_rise_column.preprocess = 0.4 if activated else 0.0
	_rise_column.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_rise_column.emission_sphere_radius = 6.0
	_rise_column.direction = Vector2(0, -1)
	_rise_column.spread = 14.0
	_rise_column.gravity = Vector2(0, -16)
	_rise_column.initial_velocity_min = 7.0
	_rise_column.initial_velocity_max = 16.0
	_rise_column.scale_amount_min = 0.1
	_rise_column.scale_amount_max = 0.26
	_rise_column.color = COL_MOTE
	_apply_fade_ramp(_rise_column)

	_inbound_motes = _make_particles("GraceInbound", Vector2(0, -28))
	_inbound_motes.amount = 6 if _mobile else 10
	_inbound_motes.lifetime = 1.7
	_inbound_motes.preprocess = 0.0
	_inbound_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_inbound_motes.emission_sphere_radius = 32.0
	_inbound_motes.direction = Vector2(0, -1)
	_inbound_motes.spread = 40.0
	_inbound_motes.gravity = Vector2(0, -5)
	_inbound_motes.radial_accel_min = -20.0
	_inbound_motes.radial_accel_max = -9.0
	_inbound_motes.tangential_accel_min = -4.0
	_inbound_motes.tangential_accel_max = 4.0
	_inbound_motes.initial_velocity_min = 2.0
	_inbound_motes.initial_velocity_max = 9.0
	_inbound_motes.scale_amount_min = 0.07
	_inbound_motes.scale_amount_max = 0.18
	_inbound_motes.color = COL_MOTE
	_apply_fade_ramp(_inbound_motes)

	_ember_core = _make_particles("GraceCore", Vector2(0, -48))
	_ember_core.amount = 3 if _mobile else 5
	_ember_core.lifetime = 1.15
	_ember_core.preprocess = 0.0
	_ember_core.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_ember_core.emission_sphere_radius = 4.0
	_ember_core.direction = Vector2(0, -1)
	_ember_core.spread = 18.0
	_ember_core.gravity = Vector2(0, -22)
	_ember_core.initial_velocity_min = 5.0
	_ember_core.initial_velocity_max = 12.0
	_ember_core.scale_amount_min = 0.1
	_ember_core.scale_amount_max = 0.22
	_ember_core.color = Color(1.0, 0.9, 0.58, 0.72)
	_apply_fade_ramp(_ember_core)

	# Gocce/sale dalla pietra umida — solo vicino.
	_drip = _make_particles("GraceDrip", Vector2(0, -8))
	_drip.amount = 2 if _mobile else 4
	_drip.lifetime = 1.8
	_drip.preprocess = 0.0
	_drip.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_drip.emission_sphere_radius = 26.0
	_drip.direction = Vector2(0, 1)
	_drip.spread = 8.0
	_drip.gravity = Vector2(0, 28)
	_drip.initial_velocity_min = 4.0
	_drip.initial_velocity_max = 10.0
	_drip.scale_amount_min = 0.06
	_drip.scale_amount_max = 0.12
	_drip.color = Color(0.55, 0.78, 0.74, 0.35)
	_apply_fade_ramp(_drip)


func _make_particles(node_name: String, local_pos: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = node_name
	p.position = local_pos
	p.texture = _mote_tex
	p.z_index = 3
	p.emitting = false
	p.local_coords = true
	p.explosiveness = 0.0
	p.randomness = 0.72
	add_child(p)
	return p


func _apply_fade_ramp(p: CPUParticles2D) -> void:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.7, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.7),
		Color(1, 1, 1, 0.0),
	])
	p.color_ramp = ramp


func _refresh_particle_state() -> void:
	var near_fx := _player_near or _charging
	var idle_flame := activated and not _mobile
	var charge := _charge_progress
	var tint := COL_MOTE.lerp(COL_MOTE_CHARGE, charge)
	if _rise_column:
		_rise_column.emitting = near_fx or idle_flame
		if _charging:
			_rise_column.amount = mini(20 if _mobile else 26, (5 if _mobile else 9) + int(charge * 12.0))
			_rise_column.initial_velocity_min = 7.0 + charge * 20.0
			_rise_column.initial_velocity_max = 16.0 + charge * 34.0
		elif near_fx:
			_rise_column.amount = 5 if _mobile else 8
		else:
			_rise_column.amount = 3 if _mobile else 5
		_rise_column.color = tint if near_fx else Color(0.4, 0.85, 0.78, 0.35)
	if _inbound_motes:
		_inbound_motes.emitting = near_fx
		if _charging:
			_inbound_motes.amount = mini(20 if _mobile else 24, (6 if _mobile else 10) + int(charge * 10.0))
			_inbound_motes.emission_sphere_radius = lerpf(32.0, 52.0, charge)
		else:
			_inbound_motes.amount = 5 if _mobile else 8
			_inbound_motes.emission_sphere_radius = 32.0
		_inbound_motes.color = tint
	if _ember_core:
		_ember_core.emitting = near_fx or idle_flame
		_ember_core.amount = (4 if _charging else (3 if near_fx else 2)) + int(charge * 4.0)
		_ember_core.scale_amount_max = lerpf(0.2, 0.34, charge)
	if _drip:
		_drip.emitting = _player_near and not _charging


func _create_illustrated_visual() -> void:
	if art_profile == null or art_profile.tide_altar == null:
		return
	_illustration = Sprite2D.new()
	_illustration.name = "IllustratedAltar"
	_illustration.texture = art_profile.tide_altar
	var offset := art_profile.tide_altar_offset
	# Pianta il basamento PNG sul plinth locale.
	_illustration.position = Vector2(offset.x, offset.y)
	_illustration.scale = _base_scale
	_illustration.modulate = COL_IDLE
	_illustration.z_index = 2
	_illustration.centered = true
	add_child(_illustration)
