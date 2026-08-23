extends Node2D

## Parallasse world-space: sei piani con velocita' distinte, sempre ancorati alla
## camera. I layer architettonici giocabili restano fermi e sostituibili.
##
## I piani frontali sono silhouette PIENE, non veli trasparenti: un primo piano
## in trasparenza legge come una macchia sporca sopra la scena, mentre una massa
## opaca in indaco profondo separa davvero le profondita'.

## Palette dei piani: dal viola pallido della distanza all'indaco del davanti.
const FORE_WOOD := Color(0.3, 0.36, 0.42, 1.0)
const FORE_CLOSE := Color(0.18, 0.22, 0.28, 1.0)
const FOREGROUND_POLE := preload("res://Landscape/Dogana/bricola_foreground.svg")

var _camera: Camera2D
var _origin := Vector2.ZERO
var _last_camera := Vector2.ZERO

var _horizon: Node2D
var _far: Node2D
var _mid: Node2D
var _mid_near: Node2D
var _near: Node2D
var _fore: Node2D
var _fore_close: Node2D
var _fore_motes: CPUParticles2D
var _moon: Node2D
var _interior_overlay: Polygon2D
var _bokeh_far: CPUParticles2D
var _bokeh_near: CPUParticles2D
var _atmospheric_dust: CPUParticles2D
var _light_motes: CPUParticles2D
var _world_lights: Node2D


func _ready() -> void:
	add_to_group("dogana_depth_system")
	# Luna sul piano piu' lontano visibile (davanti al cielo opaco, dietro
	# fog e moduli). I poligoni geometrici di skyline/tetti/quinte sono
	# stati rimossi: i nodi restano vuoti per i gruppi di parallasse.
	_moon = _build_moon()
	_horizon = _build_empty_layer("HorizonViolet", -22, "dogana_parallax_horizon")
	_far = _build_empty_layer("FarLagoonSilhouettes", -19, "dogana_parallax_far")
	_mid = _build_mid_reflections()
	_mid_near = _build_empty_layer("MidNearRooftops", -5, "dogana_parallax_mid_near")
	_near = _build_empty_layer("NearAtmosphericFrames", 12, "dogana_parallax_near")
	_fore = _build_foreground_veils()
	_fore_close = _build_foreground_close()
	_fore_motes = _build_foreground_motes()
	_bokeh_far = _build_bokeh_layer("FarBokeh", -16, 18, Color(0.42, 0.72, 0.75, 0.18), 0.65)
	_bokeh_near = _build_bokeh_layer("NearBokeh", 11, 11, Color(0.72, 0.78, 0.62, 0.12), 1.25)
	_atmospheric_dust = _build_atmospheric_dust()
	_light_motes = _build_light_motes()
	_world_lights = _build_world_lights()
	_interior_overlay = _build_interior_depth()
	set_process(true)


func _process(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_tree().get_first_node_in_group("camera") as Camera2D
		if _camera:
			_last_camera = _camera.global_position
		return
	var camera_pos := _camera.global_position
	var delta_cam := camera_pos - _last_camera
	_last_camera = camera_pos
	# Più lontano = spostamento minore. Il foreground anticipa leggermente.
	_horizon.position += delta_cam * 0.05
	_far.position += delta_cam * 0.12
	_mid.position += delta_cam * 0.26
	_mid_near.position += delta_cam * 0.42
	_near.position += delta_cam * 0.58
	# I piani frontali si muovono contro la camera: scorrono piu' veloci del mondo.
	_fore.position -= delta_cam * 0.3
	_fore_close.position -= delta_cam * 0.62
	# Deriva organica minima: profondità viva, non fondale statico.
	var t := Time.get_ticks_msec() * 0.001
	_horizon.position.y = sin(t * 0.09) * 2.5
	_far.position.y = sin(t * 0.13) * 4.0
	_mid.position.y = sin(t * 0.22 + 1.4) * 7.0
	_mid_near.position.y = sin(t * 0.27 + 2.2) * 8.5
	_near.position.y = sin(t * 0.31 + 0.7) * 10.0
	if _bokeh_far:
		_bokeh_far.position.x = sin(t * 0.08) * 22.0
	if _bokeh_near:
		_bokeh_near.position.x = sin(t * 0.12 + 2.0) * 32.0
	var inside := camera_pos.y < -100.0
	_interior_overlay.modulate.a = move_toward(_interior_overlay.modulate.a, 0.5 if inside else 0.0, delta * 0.7)
	if _moon:
		# Quasi fissa sul cielo: 1% di deriva, lontanissima, non appiccicata.
		_moon.global_position = Vector2(
			780.0 + camera_pos.x * 0.01,
			96.0 + camera_pos.y * 0.006
		)
		_moon.modulate.a = move_toward(_moon.modulate.a, 0.0 if inside else 1.0, delta * 1.4)


## I piani lontani non hanno piu' poligoni: skyline a denti, isole triangolari,
## tetti-rettangolo e quinte ai bordi leggevano come geometria di debug sopra
## l'architettura dipinta. I nodi restano vuoti perche' il test di coerenza
## conta i gruppi di parallasse.
func _build_empty_layer(layer_name: String, z: int, group_name: String) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.z_index = z
	layer.add_to_group(group_name)
	add_child(layer)
	return layer


## Luna sul piano piu' lontano visibile: dietro fog e moduli, davanti al cielo
## opaco del fondale. Disco minuscolo, alone enorme, cosi' legge come un corpo
## sfuocato nella foschia e non come un cerchio appoggiato sugli edifici.
func _build_moon() -> Node2D:
	var moon := Node2D.new()
	moon.name = "Moon"
	moon.z_index = -17
	moon.z_as_relative = false
	moon.add_to_group("dogana_moon")
	add_child(moon)
	var outer := Sprite2D.new()
	outer.texture = _make_moon_glow(0.18)
	outer.scale = Vector2(14.0, 11.0)
	outer.modulate = Color(0.72, 0.78, 0.92, 0.42)
	moon.add_child(outer)
	var halo := Sprite2D.new()
	halo.texture = _make_moon_glow(0.22)
	halo.scale = Vector2(7.2, 7.2)
	halo.modulate = Color(0.84, 0.88, 0.96, 0.5)
	moon.add_child(halo)
	var disc := Sprite2D.new()
	disc.texture = _make_moon_glow(0.2)
	disc.scale = Vector2(3.4, 3.4)
	disc.modulate = Color(0.94, 0.96, 1.0, 0.42)
	moon.add_child(disc)
	return moon


func _make_moon_glow(core: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, core * 0.45, core, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.55),
		Color(1, 1, 1, 0.18),
		Color(1, 1, 1, 0.04),
		Color(1, 1, 1, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


## Riflessi di fondo sulla laguna. Erano Line2D nette e leggevano come
## "lineette" disegnate sull'acqua: ora sono smerigliature morbide additive.
func _build_mid_reflections() -> Node2D:
	# I riflessi allungati leggevano come rettangoli in parallasse sull'acqua.
	# La superficie ha gia' caustiche e schiuma nello shader: questo piano resta
	# vuoto, il gruppo serve al test di coerenza.
	return _build_empty_layer("MidLagoonGlints", -8, "dogana_parallax_mid")


## Piano frontale: pali d'ormeggio in massa piena che passano davanti al
## personaggio. Sono opachi di proposito - una silhouette netta legge come
## "vicino", un velo semitrasparente legge come vetro sporco.
func _build_foreground_veils() -> Node2D:
	var layer := Node2D.new()
	layer.name = "ForegroundPoles"
	layer.z_index = 15
	layer.add_to_group("dogana_parallax_foreground")
	add_child(layer)
	if OS.has_feature("mobile"):
		return layer
	# Radi: con un palo ogni schermata il primo piano diventa una palizzata che
	# nasconde il gioco invece di dargli profondita'.
	for index in 3:
		var x := 640.0 + index * 2350.0
		layer.add_child(_make_foreground_pole(x, 675.0, 1.05, 1.5, FORE_WOOD))
	return layer


## Piano piu' vicino di tutti: pochissimi elementi, molto grandi, che sfiorano i
## bordi dell'inquadratura. Scorre quasi al doppio della velocita' del mondo.
func _build_foreground_close() -> Node2D:
	var layer := Node2D.new()
	layer.name = "ForegroundClose"
	layer.z_index = 17
	layer.add_to_group("dogana_parallax_foreground_close")
	add_child(layer)
	if OS.has_feature("mobile"):
		return layer
	for index in 2:
		var x := 1850.0 + index * 3450.0
		layer.add_child(_make_foreground_pole(x, 760.0, 1.5, 2.1, FORE_CLOSE))
	return layer


## Palo d'ormeggio in primo piano: la briccola dipinta, ingrandita e portata in
## ombra profonda ma OPACA. Un poligono costruito a mano leggeva come una barra;
## la texture vera conserva venature, cerchiature e testa tagliata.
func _make_foreground_pole(
	x: float,
	y: float,
	scale_x: float,
	scale_y: float,
	tint: Color
) -> Sprite2D:
	var pole := Sprite2D.new()
	pole.texture = FOREGROUND_POLE
	pole.position = Vector2(x, y)
	pole.scale = Vector2(scale_x, scale_y)
	pole.modulate = tint
	return pole


## Pulviscolo grande e vicinissimo: passa davanti a tutto e vende la profondita'.
func _build_foreground_motes() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "ForegroundMotes"
	particles.z_as_relative = false
	particles.z_index = 16
	particles.amount = 6 if OS.has_feature("mobile") else 14
	particles.lifetime = 6.0
	particles.preprocess = 6.0
	particles.emitting = true
	particles.randomness = 0.9
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(3900, 420)
	particles.position = Vector2(3250, 330)
	particles.direction = Vector2(0.4, -1.0)
	particles.spread = 42.0
	particles.gravity = Vector2(3.0, -1.5)
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 18.0
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.85
	particles.color = Color(0.5, 0.66, 0.66, 0.1)
	particles.texture = _make_bokeh_texture()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.24, 0.7, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.6),
		Color(1, 1, 1, 0.32), Color(1, 1, 1, 0),
	])
	particles.color_ramp = fade
	particles.add_to_group("dogana_foreground_motes")
	add_child(particles)
	return particles


func _build_bokeh_layer(
	layer_name: String,
	z: int,
	amount: int,
	tint: Color,
	scale_mul: float
) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = layer_name
	particles.z_as_relative = false
	particles.z_index = z
	particles.amount = amount if not OS.has_feature("mobile") else maxi(5, amount / 2)
	particles.lifetime = 10.0
	particles.preprocess = 10.0
	particles.emitting = true
	particles.randomness = 0.86
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(3900, 520)
	particles.position = Vector2(3250, 160)
	particles.direction = Vector2(0.18, -1.0)
	particles.spread = 38.0
	particles.gravity = Vector2(2.0, -3.0)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 7.0
	# La texture e' 48 px: sopra ~1.0 di scala diventano dischi bianchi piatti
	# in cielo, che leggono come palloni e non come sfocato atmosferico.
	particles.scale_amount_min = 0.18 * scale_mul
	particles.scale_amount_max = 0.52 * scale_mul
	particles.color = tint
	particles.texture = _make_bokeh_texture()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.22, 0.72, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.8),
		Color(1, 1, 1, 0.5), Color(1, 1, 1, 0),
	])
	particles.color_ramp = fade
	particles.add_to_group("dogana_bokeh_layer")
	add_child(particles)
	return particles


func _build_atmospheric_dust() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "AtmosphericDust"
	particles.z_as_relative = false
	particles.z_index = 9
	particles.amount = 38 if not OS.has_feature("mobile") else 18
	particles.lifetime = 8.5
	particles.preprocess = 8.5
	particles.emitting = true
	particles.randomness = 0.92
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(3900, 500)
	particles.position = Vector2(3250, 120)
	particles.direction = Vector2(0.35, -1.0)
	particles.spread = 48.0
	particles.gravity = Vector2(1.4, -2.2)
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 10.0
	particles.scale_amount_min = 0.055
	particles.scale_amount_max = 0.18
	particles.color = Color(0.58, 0.78, 0.76, 0.2)
	particles.texture = _make_bokeh_texture()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.18, 0.76, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.72),
		Color(1, 1, 1, 0.38), Color(1, 1, 1, 0),
	])
	particles.color_ramp = fade
	particles.add_to_group("dogana_atmospheric_dust")
	add_child(particles)
	return particles


func _build_light_motes() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "LightMotes"
	particles.z_as_relative = false
	particles.z_index = 6
	particles.amount = 10 if OS.has_feature("mobile") else 24
	particles.lifetime = 7.2
	particles.preprocess = 7.2
	particles.emitting = true
	particles.randomness = 0.95
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(3900, 470)
	particles.position = Vector2(3250, 70)
	particles.direction = Vector2(0.2, -1.0)
	particles.spread = 58.0
	particles.gravity = Vector2(0.8, -3.6)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 8.0
	particles.scale_amount_min = 0.045
	particles.scale_amount_max = 0.13
	particles.color = Color(0.66, 0.94, 0.84, 0.24)
	particles.texture = _make_bokeh_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = additive
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.72, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.7),
		Color(1, 1, 1, 0.42), Color(1, 1, 1, 0),
	])
	particles.color_ramp = fade
	particles.add_to_group("dogana_light_motes")
	add_child(particles)
	return particles


func _build_world_lights() -> Node2D:
	var layer := Node2D.new()
	layer.name = "ArchitecturalGlowPools"
	layer.add_to_group("dogana_light_layer")
	add_child(layer)
	if OS.get_name() == "Android" or OS.has_feature("mobile"):
		return layer
	var texture := _make_light_texture()
	var positions := [
		Vector2(650, 375), Vector2(1550, 365), Vector2(2700, 320),
		Vector2(4200, 365), Vector2(5480, 375),
	]
	for index in positions.size():
		var light := PointLight2D.new()
		light.name = "Glow_%02d" % index
		light.position = positions[index]
		light.texture = texture
		light.texture_scale = 2.5
		light.energy = 0.1 if OS.has_feature("mobile") else 0.16
		light.color = Color(0.56, 0.78, 0.72, 1.0) if index % 2 == 0 else Color(0.84, 0.69, 0.43, 1.0)
		light.shadow_enabled = false
		layer.add_child(light)
	return layer


func _make_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.7, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.74), Color(1, 1, 1, 0.25),
		Color(1, 1, 1, 0.045), Color(1, 1, 1, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _make_bokeh_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.76, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.38),
		Color(1, 1, 1, 0.08), Color(1, 1, 1, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 48
	texture.height = 48
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _build_interior_depth() -> Polygon2D:
	var overlay := Polygon2D.new()
	overlay.name = "InteriorDepthWash"
	overlay.z_index = -2
	overlay.polygon = PackedVector2Array([
		Vector2(4000, -1750), Vector2(6250, -1750),
		Vector2(6250, -430), Vector2(4000, -430),
	])
	overlay.color = Color(0.035, 0.075, 0.085, 0.34)
	overlay.modulate.a = 0.0
	add_child(overlay)
	return overlay
